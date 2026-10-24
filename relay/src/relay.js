'use strict';
// SAPIENTIA relay: stuurt berichten door tussen de peers van een kamer. Geen game-logica,
// geen opslag. De host-telefoon blijft autoritair; de relay kijkt nooit in de payload.
//
// Protocol v1 (zie relay/README.md):
//   tekstframe  = besturing (JSON)  {"t": "create" | "join" | "kick" | "leave", ...}
//   binair      = data. Client -> relay: [doel u16 BE][payload]. Relay -> client: [van u16 BE][payload].
const http = require('node:http');
const { WebSocketServer, WebSocket } = require('ws');
const { DEFAULTS } = require('./config');
const { generateCode, normalizeCode } = require('./codes');
const { TokenBucket, WindowCounter } = require('./limits');

const PROTOCOL_VERSION = 1;
const HOST_PEER_ID = 1;
const TARGET_ALL = 0;
const HEADER_BYTES = 2;

const noop = () => {};

function createRelay(userConfig = {}) {
  const cfg = { ...DEFAULTS, ...userConfig };
  const rooms = new Map();
  const conns = new Set();
  const connsPerIp = new Map();
  const createWindow = new WindowCounter(cfg.createPerMinute, 60000);
  const joinWindow = new WindowCounter(cfg.joinPerMinute, 60000);
  let sweepTimer = null;
  let closing = false;

  const log = (event, fields = {}) => {
    if (cfg.quiet) return;
    process.stdout.write(`${JSON.stringify({ ts: new Date().toISOString(), event, ...fields })}\n`);
  };

  const server = http.createServer((req, res) => {
    if (req.url === '/healthz') {
      res.writeHead(200, { 'content-type': 'text/plain' });
      res.end('ok');
      return;
    }
    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end('SAPIENTIA relay. Connect with a WebSocket.');
  });

  const wss = new WebSocketServer({
    server,
    maxPayload: cfg.maxMessageBytes,
    perMessageDeflate: false,
    clientTracking: false,
  });

  function clientIp(req) {
    const hops = cfg.trustProxyHops;
    if (hops > 0) {
      const xff = String(req.headers['x-forwarded-for'] || '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
      // Rechtse hop = wat onze eigen proxy toevoegde; links is door de client te vervalsen.
      if (xff.length >= hops) return xff[xff.length - hops];
    }
    return req.socket.remoteAddress || 'unknown';
  }

  function sendJson(conn, obj) {
    if (conn.ws.readyState === WebSocket.OPEN) conn.ws.send(JSON.stringify(obj), noop);
  }

  function sendBinary(conn, buf) {
    if (conn.ws.readyState !== WebSocket.OPEN) return;
    if (conn.ws.bufferedAmount > cfg.maxBufferedBytes) {
      closeConn(conn, 1013, 'slow_consumer');
      return;
    }
    conn.ws.send(buf, { binary: true }, noop);
  }

  function closeConn(conn, code, reason) {
    clearTimeout(conn.handshakeTimer);
    if (conn.ws.readyState === WebSocket.OPEN || conn.ws.readyState === WebSocket.CONNECTING) {
      conn.ws.close(code, reason);
    }
  }

  // Sluit pas na een korte wachttijd: Godot (WebSocketPeer) gooit de ontvangstrij weg zodra
  // de verbinding in dezelfde poll sluit, en dan komt de laatste melding (reden) nooit aan.
  function lingerClose(conn, code, reason) {
    if (cfg.closeLingerMs <= 0) {
      closeConn(conn, code, reason);
      return;
    }
    clearTimeout(conn.handshakeTimer);
    conn.lingering = true;
    const t = setTimeout(() => closeConn(conn, code, reason), cfg.closeLingerMs);
    t.unref();
  }

  function fail(conn, reason, code = 1000) {
    sendJson(conn, { t: 'error', reason });
    lingerClose(conn, code, reason);
  }

  function touch(room) {
    room.lastActivity = Date.now();
  }

  function newRoom(host) {
    let code = generateCode();
    for (let i = 0; i < 20 && rooms.has(code); i++) code = generateCode();
    if (rooms.has(code)) return null;
    const room = {
      code,
      host,
      members: new Map([[HOST_PEER_ID, host]]),
      nextId: HOST_PEER_ID + 1,
      createdAt: Date.now(),
      lastActivity: Date.now(),
    };
    rooms.set(code, room);
    return room;
  }

  function closeRoom(room, reason) {
    if (!rooms.delete(room.code)) return;
    for (const conn of room.members.values()) {
      conn.room = null;
      sendJson(conn, { t: 'closed', reason });
      lingerClose(conn, 1000, reason);
    }
    room.members.clear();
    log('room_closed', { reason });
  }

  function handleCreate(conn, msg) {
    if (conn.room) return fail(conn, 'busy');
    if (msg.v !== PROTOCOL_VERSION) return fail(conn, 'bad_version');
    if (!createWindow.hit(conn.ip)) return fail(conn, 'rate_limited', 1008);
    if (rooms.size >= cfg.maxRooms) return fail(conn, 'too_many_rooms');
    const room = newRoom(conn);
    if (!room) return fail(conn, 'too_many_rooms');
    conn.room = room;
    conn.peerId = HOST_PEER_ID;
    clearTimeout(conn.handshakeTimer);
    sendJson(conn, { t: 'created', code: room.code, peer: HOST_PEER_ID, max: cfg.maxPlayers });
    log('room_created', { rooms: rooms.size });
    return undefined;
  }

  function handleJoin(conn, msg) {
    if (conn.room) return fail(conn, 'busy');
    if (msg.v !== PROTOCOL_VERSION) return fail(conn, 'bad_version');
    if (!joinWindow.hit(conn.ip)) return fail(conn, 'rate_limited', 1008);
    const code = normalizeCode(msg.code);
    const room = code ? rooms.get(code) : undefined;
    if (!room) return fail(conn, 'no_room');
    if (room.members.size >= cfg.maxPlayers) return fail(conn, 'room_full');
    const id = room.nextId++;
    room.members.set(id, conn);
    conn.room = room;
    conn.peerId = id;
    clearTimeout(conn.handshakeTimer);
    touch(room);
    sendJson(conn, { t: 'joined', peer: id, host: HOST_PEER_ID, max: cfg.maxPlayers });
    sendJson(room.host, { t: 'peer_joined', peer: id });
    return undefined;
  }

  function handleKick(conn, msg) {
    const room = conn.room;
    if (!room || conn.peerId !== HOST_PEER_ID) return fail(conn, 'bad_message');
    const target = room.members.get(Number(msg.peer));
    if (!target || target === conn) return undefined;
    leaveRoom(target);
    sendJson(target, { t: 'closed', reason: 'kicked' });
    lingerClose(target, 1000, 'kicked');
    return undefined;
  }

  function handleControl(conn, text) {
    let msg;
    try {
      msg = JSON.parse(text);
    } catch {
      return fail(conn, 'bad_message');
    }
    if (msg === null || typeof msg !== 'object' || typeof msg.t !== 'string') {
      return fail(conn, 'bad_message');
    }
    switch (msg.t) {
      case 'create':
        return handleCreate(conn, msg);
      case 'join':
        return handleJoin(conn, msg);
      case 'kick':
        return handleKick(conn, msg);
      case 'leave':
        return closeConn(conn, 1000, 'leave');
      default:
        return fail(conn, 'bad_message');
    }
  }

  function handleData(conn, buf) {
    const room = conn.room;
    if (!room) return fail(conn, 'bad_message');
    if (buf.length <= HEADER_BYTES) return noteViolation(conn);
    const target = buf.readUInt16BE(0);
    const framed = Buffer.allocUnsafe(buf.length);
    framed.writeUInt16BE(conn.peerId, 0);
    buf.copy(framed, HEADER_BYTES, HEADER_BYTES);
    if (conn.peerId === HOST_PEER_ID) {
      if (target === TARGET_ALL) {
        for (const [id, peer] of room.members) {
          if (id !== HOST_PEER_ID) sendBinary(peer, framed);
        }
      } else if (target !== HOST_PEER_ID) {
        const peer = room.members.get(target);
        if (peer) sendBinary(peer, framed);
      }
    } else if (target === HOST_PEER_ID) {
      // Gasten praten alleen met de host: geen gast-naar-gast en geen gast-broadcast.
      sendBinary(room.host, framed);
    } else {
      return noteViolation(conn);
    }
    touch(room);
    return undefined;
  }

  function noteViolation(conn) {
    conn.violations += 1;
    if (conn.violations >= cfg.maxViolations) fail(conn, 'rate_limited', 1008);
  }

  function onMessage(conn, data, isBinary) {
    if (conn.lingering) return;
    conn.alive = true;
    const size = data.length;
    if (!conn.msgBucket.take(1) || !conn.byteBucket.take(size)) {
      noteViolation(conn);
      return;
    }
    if (isBinary) handleData(conn, data);
    else handleControl(conn, data.toString('utf8'));
  }

  // Haalt de verbinding uit zijn kamer: host weg = kamer dicht, gast weg = peer_left naar de host.
  function leaveRoom(conn) {
    const room = conn.room;
    if (!room) return;
    conn.room = null;
    if (conn.peerId === HOST_PEER_ID) {
      closeRoom(room, 'host_left');
      return;
    }
    if (room.members.get(conn.peerId) === conn) {
      room.members.delete(conn.peerId);
      touch(room);
      sendJson(room.host, { t: 'peer_left', peer: conn.peerId });
    }
  }

  function onClose(conn) {
    clearTimeout(conn.handshakeTimer);
    conns.delete(conn);
    const n = (connsPerIp.get(conn.ip) || 1) - 1;
    if (n <= 0) connsPerIp.delete(conn.ip);
    else connsPerIp.set(conn.ip, n);
    leaveRoom(conn);
  }

  wss.on('connection', (ws, req) => {
    const ip = clientIp(req);
    const conn = {
      ws,
      ip,
      room: null,
      peerId: 0,
      alive: true,
      violations: 0,
      lingering: false,
      msgBucket: new TokenBucket(cfg.msgRate, cfg.msgBurst),
      byteBucket: new TokenBucket(cfg.byteRate, cfg.byteBurst),
      handshakeTimer: null,
    };
    ws.on('error', noop);
    if (closing || conns.size >= cfg.maxConnections) {
      fail(conn, 'busy');
      return;
    }
    if ((connsPerIp.get(ip) || 0) >= cfg.maxConnectionsPerIp) {
      fail(conn, 'rate_limited', 1008);
      return;
    }
    conns.add(conn);
    connsPerIp.set(ip, (connsPerIp.get(ip) || 0) + 1);
    conn.handshakeTimer = setTimeout(() => {
      if (!conn.room) fail(conn, 'handshake_timeout');
    }, cfg.handshakeMs);
    ws.on('message', (data, isBinary) => onMessage(conn, data, isBinary));
    ws.on('pong', () => {
      conn.alive = true;
    });
    ws.on('close', () => onClose(conn));
  });

  let lastPing = Date.now();
  let lastViolationReset = Date.now();

  function sweep() {
    const now = Date.now();
    for (const room of [...rooms.values()]) {
      if (now - room.lastActivity > cfg.roomIdleMs) closeRoom(room, 'idle');
      else if (now - room.createdAt > cfg.roomMaxAgeMs) closeRoom(room, 'max_age');
    }
    if (now - lastViolationReset >= 5000) {
      lastViolationReset = now;
      for (const conn of conns) conn.violations = 0;
    }
    if (now - lastPing >= cfg.pingMs) {
      lastPing = now;
      for (const conn of conns) {
        if (!conn.alive) {
          conn.ws.terminate();
          continue;
        }
        conn.alive = false;
        if (conn.ws.readyState === WebSocket.OPEN) conn.ws.ping(noop);
      }
    }
    createWindow.sweep();
    joinWindow.sweep();
  }

  function listen(port = cfg.port, host = cfg.host) {
    return new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(port, host, () => {
        server.off('error', reject);
        sweepTimer = setInterval(sweep, cfg.sweepMs);
        sweepTimer.unref();
        resolve(server.address());
      });
    });
  }

  function close() {
    closing = true;
    clearInterval(sweepTimer);
    for (const room of [...rooms.values()]) closeRoom(room, 'shutdown');
    for (const conn of conns) conn.ws.terminate();
    return new Promise((resolve) => {
      wss.close(() => {
        server.close(() => resolve());
        server.closeAllConnections();
      });
    });
  }

  return {
    server,
    listen,
    close,
    sweep,
    stats: () => ({ rooms: rooms.size, connections: conns.size }),
    hasRoom: (code) => rooms.has(code),
    roomCodes: () => [...rooms.keys()],
  };
}

module.exports = { createRelay, PROTOCOL_VERSION, HOST_PEER_ID, TARGET_ALL };
