'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { startRelay, createRoom, joinRoom, connect } = require('../test-support/helpers');

async function withRelay(overrides, fn) {
  const ctx = await startRelay(overrides);
  const clients = [];
  const track = (c) => {
    clients.push(c);
    return c;
  };
  try {
    await fn({ ...ctx, track });
  } finally {
    for (const c of clients) c.close();
    await ctx.relay.close();
  }
}

test('70k join/leave-cycli: geen throw en peer-ids blijven onder 65536', async () => {
  await withRelay(
    {
      joinPerMinute: 1_000_000,
      createPerMinute: 1_000_000,
      maxConnectionsPerIp: 100_000,
      maxConnections: 100_000,
      sweepMs: 60_000,
      roomIdleMs: 600_000,
      closeLingerMs: 0,
    },
    async ({ url, track }) => {
      const { host, code } = await createRoom(url);
      track(host);
      let maxPeer = 1;
      const cycles = 70_000;
      for (let i = 0; i < cycles; i++) {
        const { guest, joined } = await joinRoom(url, code);
        if (joined.t !== 'joined') {
          guest.close();
          throw new Error(`join faalde op iteratie ${i}: ${JSON.stringify(joined)}`);
        }
        maxPeer = Math.max(maxPeer, joined.peer);
        await new Promise((resolve, reject) => {
          guest.ws.once('close', resolve);
          guest.ws.once('error', reject);
          guest.close();
        });
      }
      assert.ok(maxPeer < 65536, `max peer-id was ${maxPeer}`);
      assert.ok(maxPeer <= 4, `hergebruik houdt ids klein; max was ${maxPeer}`);
      const { guest: tail, joined: j } = await joinRoom(url, code);
      track(tail);
      assert.strictEqual(j.t, 'joined');
      assert.ok(j.peer >= 2 && j.peer <= 4);
    },
  );
}, { timeout: 300_000 });

test('een gooierende handler laat het relay-proces doorlopen', async () => {
  await withRelay({ _testInjectThrow: true }, async ({ url, track }) => {
    const c = track(await connect(url));
    c.send({ t: '_test_throw' });
    const err = await c.ctl('error');
    assert.strictEqual(err.reason, 'bad_message');
    await c.waitClosed();
    const { host, code } = await createRoom(url);
    track(host);
    const { guest, joined } = await joinRoom(url, code);
    track(guest);
    assert.strictEqual(joined.t, 'joined');
    host.sendData(0, [1, 2]);
    const m = await guest.data();
    assert.deepStrictEqual([...m.payload], [1, 2]);
  });
});
