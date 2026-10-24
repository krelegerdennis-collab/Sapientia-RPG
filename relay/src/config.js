'use strict';

const DEFAULTS = Object.freeze({
  host: '0.0.0.0',
  port: 8080,
  maxPlayers: 4,
  maxRooms: 500,
  maxConnections: 2000,
  maxConnectionsPerIp: 32,
  // Eén WebSocket-frame. Lobby-JSON blijft onder 1 KiB, een snapshot is ~130 bytes.
  maxMessageBytes: 2048,
  // Per verbinding: berichten/s en bytes/s (de host stuurt ~20 snapshots/s, een gast ~30 inputs/s).
  msgRate: 120,
  msgBurst: 240,
  byteRate: 32768,
  byteBurst: 65536,
  maxViolations: 20,
  createPerMinute: 10,
  joinPerMinute: 30,
  handshakeMs: 10000,
  closeLingerMs: 300,
  roomIdleMs: 10 * 60 * 1000,
  roomMaxAgeMs: 4 * 60 * 60 * 1000,
  pingMs: 15000,
  sweepMs: 5000,
  maxBufferedBytes: 256 * 1024,
  trustProxyHops: 0,
  quiet: false,
});

function intFromEnv(env, key, fallback) {
  const raw = env[key];
  if (raw === undefined || raw === '') return fallback;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

function configFromEnv(env = process.env) {
  const cfg = { ...DEFAULTS };
  cfg.host = env.HOST || DEFAULTS.host;
  cfg.port = intFromEnv(env, 'PORT', DEFAULTS.port);
  cfg.maxRooms = intFromEnv(env, 'MAX_ROOMS', DEFAULTS.maxRooms);
  cfg.maxConnections = intFromEnv(env, 'MAX_CONNECTIONS', DEFAULTS.maxConnections);
  cfg.maxConnectionsPerIp = intFromEnv(env, 'MAX_CONNECTIONS_PER_IP', DEFAULTS.maxConnectionsPerIp);
  cfg.maxMessageBytes = intFromEnv(env, 'MAX_MESSAGE_BYTES', DEFAULTS.maxMessageBytes);
  cfg.roomIdleMs = intFromEnv(env, 'ROOM_IDLE_MS', DEFAULTS.roomIdleMs);
  cfg.roomMaxAgeMs = intFromEnv(env, 'ROOM_MAX_AGE_MS', DEFAULTS.roomMaxAgeMs);
  cfg.trustProxyHops = intFromEnv(env, 'TRUST_PROXY_HOPS', DEFAULTS.trustProxyHops);
  cfg.quiet = env.RELAY_QUIET === '1';
  return cfg;
}

module.exports = { DEFAULTS, configFromEnv };
