'use strict';
const { WebSocket } = require('ws');
const { createRelay } = require('../src/relay');

async function startRelay(overrides = {}) {
  const relay = createRelay({ quiet: true, sweepMs: 20, closeLingerMs: 20, ...overrides });
  const addr = await relay.listen(0, '127.0.0.1');
  return { relay, url: `ws://127.0.0.1:${addr.port}`, port: addr.port };
}

// Test-client: bewaart alle berichten in volgorde, zodat tests erop kunnen wachten.
class Client {
  constructor(url) {
    this.log = [];
    this.waiters = [];
    this.closed = null;
    this.ws = new WebSocket(url);
    this.ws.on('message', (data, isBinary) => {
      const item = isBinary
        ? { bin: true, from: data.readUInt16BE(0), payload: data.subarray(2) }
        : { bin: false, ...JSON.parse(data.toString('utf8')) };
      this.log.push(item);
      this._wake();
    });
    this.ws.on('close', (code, reason) => {
      this.closed = { code, reason: reason.toString() };
      this._wake();
    });
    this.ws.on('error', () => {});
    this.opened = new Promise((resolve) => this.ws.once('open', resolve));
  }

  _wake() {
    for (const w of [...this.waiters]) w();
  }

  async next(pred, ms = 2000) {
    const deadline = Date.now() + ms;
    for (;;) {
      const i = this.log.findIndex(pred);
      if (i >= 0) return this.log.splice(i, 1)[0];
      if (Date.now() > deadline) throw new Error(`timeout; log=${JSON.stringify(this.log)}`);
      await new Promise((resolve) => {
        const t = setTimeout(resolve, 20);
        const w = () => {
          clearTimeout(t);
          this.waiters.splice(this.waiters.indexOf(w), 1);
          resolve();
        };
        this.waiters.push(w);
      });
    }
  }

  ctl(t) {
    return this.next((m) => !m.bin && m.t === t);
  }

  data() {
    return this.next((m) => m.bin);
  }

  async waitClosed(ms = 2000) {
    const deadline = Date.now() + ms;
    while (!this.closed) {
      if (Date.now() > deadline) throw new Error('niet gesloten');
      await new Promise((r) => setTimeout(r, 10));
    }
    return this.closed;
  }

  send(obj) {
    this.ws.send(JSON.stringify(obj));
  }

  sendData(target, bytes) {
    const buf = Buffer.alloc(2 + bytes.length);
    buf.writeUInt16BE(target, 0);
    Buffer.from(bytes).copy(buf, 2);
    this.ws.send(buf, { binary: true });
  }

  close() {
    this.ws.close();
  }
}

async function connect(url) {
  const c = new Client(url);
  await c.opened;
  return c;
}

async function createRoom(url) {
  const host = await connect(url);
  host.send({ t: 'create', v: 1 });
  const created = await host.ctl('created');
  return { host, code: created.code, created };
}

async function joinRoom(url, code) {
  const guest = await connect(url);
  guest.send({ t: 'join', v: 1, code });
  const joined = await guest.next((m) => !m.bin && (m.t === 'joined' || m.t === 'error'));
  return { guest, joined };
}

module.exports = { startRelay, connect, createRoom, joinRoom, Client };
