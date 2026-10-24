'use strict';
const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const { startRelay, connect, createRoom, joinRoom } = require('../test-support/helpers');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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

test('healthz antwoordt 200', async () => {
  await withRelay({}, async ({ port }) => {
    const body = await new Promise((resolve, reject) => {
      http.get({ host: '127.0.0.1', port, path: '/healthz' }, (res) => {
        let s = '';
        res.on('data', (d) => (s += d));
        res.on('end', () => resolve({ status: res.statusCode, s }));
      }).on('error', reject);
    });
    assert.deepStrictEqual(body, { status: 200, s: 'ok' });
  });
});

test('create geeft een geldige code en peer 1; join geeft peer 2 en meldt de host', async () => {
  await withRelay({}, async ({ url, track, relay }) => {
    const { host, code, created } = await createRoom(url);
    track(host);
    assert.match(code, /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/);
    assert.strictEqual(created.peer, 1);
    assert.strictEqual(created.max, 4);
    assert.ok(relay.hasRoom(code));
    const { guest, joined } = await joinRoom(url, code.toLowerCase());
    track(guest);
    assert.strictEqual(joined.t, 'joined');
    assert.strictEqual(joined.peer, 2);
    assert.strictEqual(joined.host, 1);
    const pj = await host.ctl('peer_joined');
    assert.strictEqual(pj.peer, 2);
  });
});

test('doorsturen: host-broadcast, host-naar-een-gast, gast-naar-host', async () => {
  await withRelay({}, async ({ url, track }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const g = [];
    for (let i = 0; i < 3; i++) {
      const { guest } = await joinRoom(url, code);
      track(guest);
      g.push(guest);
    }
    host.sendData(0, [1, 2, 3]);
    for (const guest of g) {
      const m = await guest.data();
      assert.strictEqual(m.from, 1);
      assert.deepStrictEqual([...m.payload], [1, 2, 3]);
    }
    host.sendData(3, [9, 9]);
    const only = await g[1].data();
    assert.deepStrictEqual([...only.payload], [9, 9]);
    await sleep(60);
    assert.ok(!g[0].log.some((m) => m.bin), 'gast 2 kreeg niets');
    assert.ok(!g[2].log.some((m) => m.bin), 'gast 4 kreeg niets');
    g[2].sendData(1, [7]);
    const up = await host.data();
    assert.strictEqual(up.from, 4);
    assert.deepStrictEqual([...up.payload], [7]);
  });
});

test('gasten kunnen niet naar elkaar of broadcasten (host blijft autoritair)', async () => {
  await withRelay({}, async ({ url, track }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const { guest: a } = await joinRoom(url, code);
    const { guest: b } = await joinRoom(url, code);
    track(a);
    track(b);
    a.sendData(3, [5]);
    a.sendData(0, [5]);
    await sleep(80);
    assert.ok(!b.log.some((m) => m.bin));
    assert.ok(!host.log.some((m) => m.bin));
  });
});

test('geen echo naar de afzender en kamers zijn gescheiden', async () => {
  await withRelay({}, async ({ url, track }) => {
    const r1 = await createRoom(url);
    const r2 = await createRoom(url);
    track(r1.host);
    track(r2.host);
    assert.notStrictEqual(r1.code, r2.code);
    const { guest: g2 } = await joinRoom(url, r2.code);
    track(g2);
    r1.host.sendData(0, [1]);
    await sleep(60);
    assert.ok(!g2.log.some((m) => m.bin));
    assert.ok(!r1.host.log.some((m) => m.bin));
  });
});

test('kamer is vol bij 4 spelers, een plek komt vrij na vertrek', async () => {
  await withRelay({}, async ({ url, track }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const guests = [];
    for (let i = 0; i < 3; i++) {
      const { guest } = await joinRoom(url, code);
      track(guest);
      guests.push(guest);
    }
    const { guest: fifth, joined } = await joinRoom(url, code);
    track(fifth);
    assert.deepStrictEqual([joined.t, joined.reason], ['error', 'room_full']);
    await fifth.waitClosed();
    guests[0].close();
    const left = await host.next((m) => m.t === 'peer_left' && m.peer === 2);
    assert.strictEqual(left.t, 'peer_left');
    const { guest: again, joined: j2 } = await joinRoom(url, code);
    track(again);
    assert.strictEqual(j2.t, 'joined');
    assert.strictEqual(j2.peer, 5, 'peer-id wordt niet hergebruikt');
  });
});

test('onbekende of ongeldige code geeft no_room', async () => {
  await withRelay({}, async ({ url, track }) => {
    for (const code of ['ZZZZZZ', 'abc', '', 'ABC0O1', null, 42]) {
      const { guest, joined } = await joinRoom(url, code);
      track(guest);
      assert.strictEqual(joined.reason, 'no_room', `code ${code}`);
      await guest.waitClosed();
    }
  });
});

test('host weg sluit de kamer en alle gasten', async () => {
  await withRelay({}, async ({ url, track, relay }) => {
    const { host, code } = await createRoom(url);
    const { guest: a } = await joinRoom(url, code);
    const { guest: b } = await joinRoom(url, code);
    track(a);
    track(b);
    host.close();
    for (const g of [a, b]) {
      const closed = await g.ctl('closed');
      assert.strictEqual(closed.reason, 'host_left');
      await g.waitClosed();
    }
    assert.ok(!relay.hasRoom(code));
    const { guest: late, joined } = await joinRoom(url, code);
    track(late);
    assert.strictEqual(joined.reason, 'no_room');
  });
});

test('gast weg laat de kamer open en meldt peer_left', async () => {
  await withRelay({}, async ({ url, track, relay }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const { guest } = await joinRoom(url, code);
    guest.close();
    const left = await host.ctl('peer_left');
    assert.strictEqual(left.peer, 2);
    assert.ok(relay.hasRoom(code));
    const { guest: back, joined } = await joinRoom(url, code);
    track(back);
    assert.strictEqual(joined.t, 'joined');
  });
});

test('kick: de host zet een gast eruit, de rest blijft', async () => {
  await withRelay({}, async ({ url, track }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const { guest: a } = await joinRoom(url, code);
    const { guest: b } = await joinRoom(url, code);
    track(a);
    track(b);
    host.sendData(2, [4, 4]);
    await a.data();
    host.send({ t: 'kick', peer: 2 });
    const closed = await a.ctl('closed');
    assert.strictEqual(closed.reason, 'kicked');
    await a.waitClosed();
    await host.next((m) => m.t === 'peer_left' && m.peer === 2);
    host.sendData(0, [8]);
    assert.deepStrictEqual([...(await b.data()).payload], [8]);
    b.send({ t: 'kick', peer: 1 });
    await b.next((m) => m.t === 'error');
  });
});

test('slechte berichten: rommel, onbekend type, data voor de handshake, verkeerde versie', async () => {
  await withRelay({}, async ({ url, track }) => {
    const c1 = track(await connect(url));
    c1.ws.send('{{{ geen json');
    assert.strictEqual((await c1.ctl('error')).reason, 'bad_message');
    await c1.waitClosed();
    const c2 = track(await connect(url));
    c2.send({ t: 'explode' });
    assert.strictEqual((await c2.ctl('error')).reason, 'bad_message');
    const c3 = track(await connect(url));
    c3.sendData(1, [1]);
    assert.strictEqual((await c3.ctl('error')).reason, 'bad_message');
    const c4 = track(await connect(url));
    c4.send({ t: 'create', v: 99 });
    assert.strictEqual((await c4.ctl('error')).reason, 'bad_version');
    const c5 = track(await connect(url));
    c5.ws.send('42');
    assert.strictEqual((await c5.ctl('error')).reason, 'bad_message');
  });
});

test('een verbinding mag maar een kamer hebben', async () => {
  await withRelay({}, async ({ url, track }) => {
    const { host } = await createRoom(url);
    track(host);
    host.send({ t: 'create', v: 1 });
    assert.strictEqual((await host.ctl('error')).reason, 'busy');
  });
});

test('te groot bericht sluit de verbinding (1009)', async () => {
  await withRelay({ maxMessageBytes: 256 }, async ({ url, track }) => {
    const { host } = await createRoom(url);
    track(host);
    host.sendData(0, new Array(400).fill(1));
    const closed = await host.waitClosed();
    assert.strictEqual(closed.code, 1009);
  });
});

test('ratelimit: berichtenstroom wordt gedropt en daarna gesloten', async () => {
  await withRelay({ msgRate: 5, msgBurst: 10, maxViolations: 10 }, async ({ url, track }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const { guest } = await joinRoom(url, code);
    track(guest);
    for (let i = 0; i < 200; i++) host.sendData(0, [i & 255]);
    const closed = await host.waitClosed();
    assert.strictEqual(closed.code, 1008);
    const got = guest.log.filter((m) => m.bin).length;
    assert.ok(got <= 15, `gast kreeg ${got} berichten (burst 10)`);
    assert.ok(got >= 5);
  });
});

test('ratelimit: bytes per seconde', async () => {
  await withRelay({ byteRate: 100, byteBurst: 300, maxViolations: 1000 }, async ({ url, track }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const { guest } = await joinRoom(url, code);
    track(guest);
    for (let i = 0; i < 20; i++) host.sendData(0, new Array(100).fill(1));
    await sleep(150);
    const got = guest.log.filter((m) => m.bin).length;
    assert.ok(got >= 2 && got <= 4, `gast kreeg ${got}`);
  });
});

test('ratelimit: te veel kamers per IP per minuut', async () => {
  await withRelay({ createPerMinute: 3 }, async ({ url, track }) => {
    for (let i = 0; i < 3; i++) track((await createRoom(url)).host);
    const extra = track(await connect(url));
    extra.send({ t: 'create', v: 1 });
    assert.strictEqual((await extra.ctl('error')).reason, 'rate_limited');
  });
});

test('ratelimit: join-pogingen per IP (code raden)', async () => {
  await withRelay({ joinPerMinute: 4 }, async ({ url, track }) => {
    const reasons = [];
    for (let i = 0; i < 6; i++) {
      const { guest, joined } = await joinRoom(url, 'ZZZZZZ');
      track(guest);
      reasons.push(joined.reason);
    }
    assert.deepStrictEqual(reasons, ['no_room', 'no_room', 'no_room', 'no_room', 'rate_limited', 'rate_limited']);
  });
});

test('limiet op verbindingen per IP en op kamers', async () => {
  await withRelay({ maxConnectionsPerIp: 2 }, async ({ url, track }) => {
    track(await connect(url));
    track(await connect(url));
    const third = track(await connect(url));
    assert.strictEqual((await third.ctl('error')).reason, 'rate_limited');
  });
  await withRelay({ maxRooms: 2 }, async ({ url, track }) => {
    track((await createRoom(url)).host);
    track((await createRoom(url)).host);
    const c = track(await connect(url));
    c.send({ t: 'create', v: 1 });
    assert.strictEqual((await c.ctl('error')).reason, 'too_many_rooms');
  });
});

test('handshake-timeout: stille verbinding wordt gesloten', async () => {
  await withRelay({ handshakeMs: 100 }, async ({ url, track }) => {
    const c = track(await connect(url));
    assert.strictEqual((await c.ctl('error')).reason, 'handshake_timeout');
    await c.waitClosed();
  });
});

test('inactieve kamer verloopt; verkeer houdt hem levend', async () => {
  await withRelay({ roomIdleMs: 250 }, async ({ url, track, relay }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const { guest } = await joinRoom(url, code);
    track(guest);
    const quiet = await createRoom(url);
    track(quiet.host);
    for (let i = 0; i < 8; i++) {
      host.sendData(0, [i]);
      await sleep(60);
    }
    assert.ok(relay.hasRoom(code), 'kamer met verkeer leeft nog');
    assert.ok(!relay.hasRoom(quiet.code), 'stille kamer is verlopen');
    assert.strictEqual((await quiet.host.ctl('closed')).reason, 'idle');
    await quiet.host.waitClosed();
    await sleep(400);
    assert.ok(!relay.hasRoom(code), 'ook de oude kamer verloopt zonder verkeer');
    assert.strictEqual((await guest.ctl('closed')).reason, 'idle');
  });
});

test('maximale leeftijd van een kamer', async () => {
  await withRelay({ roomMaxAgeMs: 150, roomIdleMs: 60000 }, async ({ url, track, relay }) => {
    const { host, code } = await createRoom(url);
    track(host);
    await sleep(300);
    assert.ok(!relay.hasRoom(code));
    assert.strictEqual((await host.ctl('closed')).reason, 'max_age');
  });
});

test('dode verbinding wordt na ping zonder pong opgeruimd', async () => {
  await withRelay({ pingMs: 50 }, async ({ url, track, relay }) => {
    const { host, code } = await createRoom(url);
    track(host);
    host.ws.pause();
    await sleep(500);
    assert.ok(!relay.hasRoom(code), 'host zonder pong: kamer dicht');
    host.ws.terminate();
  });
});

test('nieuwe code voor elke kamer; stats kloppen na opruimen', async () => {
  await withRelay({ createPerMinute: 100 }, async ({ url, track, relay }) => {
    const codes = new Set();
    const hosts = [];
    for (let i = 0; i < 20; i++) {
      const r = await createRoom(url);
      hosts.push(track(r.host));
      codes.add(r.code);
    }
    assert.strictEqual(codes.size, 20);
    assert.strictEqual(relay.stats().rooms, 20);
    for (const h of hosts) h.close();
    await sleep(200);
    assert.deepStrictEqual(relay.stats(), { rooms: 0, connections: 0 });
  });
});

test('X-Forwarded-For met TRUST_PROXY_HOPS telt de rechtse hop', async () => {
  const { WebSocket } = require('ws');
  await withRelay({ trustProxyHops: 1, maxConnectionsPerIp: 1 }, async ({ url, track }) => {
    const open = (xff) =>
      new Promise((resolve) => {
        const ws = new WebSocket(url, { headers: { 'x-forwarded-for': xff } });
        const msgs = [];
        ws.on('message', (d) => msgs.push(JSON.parse(d.toString())));
        ws.on('open', () => setTimeout(() => resolve({ ws, msgs }), 80));
        ws.on('error', () => {});
      });
    const a = await open('1.1.1.1, 9.9.9.9');
    const b = await open('2.2.2.2, 9.9.9.9');
    track({ close: () => a.ws.close() });
    track({ close: () => b.ws.close() });
    assert.strictEqual(a.msgs.length, 0);
    assert.strictEqual(b.msgs[0] && b.msgs[0].reason, 'rate_limited', 'zelfde rechtse hop = zelfde IP');
  });
});

test('de relay sluit pas na een korte wachttijd, zodat de laatste melding aankomt', async () => {
  await withRelay({ closeLingerMs: 250 }, async ({ url, track }) => {
    const c = track(await connect(url));
    c.send({ t: 'join', v: 1, code: 'ZZZZZZ' });
    const t0 = Date.now();
    assert.strictEqual((await c.ctl('error')).reason, 'no_room');
    assert.ok(!c.closed, 'nog niet gesloten bij de melding');
    await c.waitClosed();
    assert.ok(Date.now() - t0 >= 200, 'sluiten wachtte op de lingertijd');
  });
});

test('een weggestuurde gast kan geen data meer sturen', async () => {
  await withRelay({ closeLingerMs: 300 }, async ({ url, track }) => {
    const { host, code } = await createRoom(url);
    track(host);
    const { guest } = await joinRoom(url, code);
    track(guest);
    host.send({ t: 'kick', peer: 2 });
    await guest.ctl('closed');
    guest.sendData(1, [1, 2, 3]);
    await sleep(100);
    assert.ok(!host.log.some((m) => m.bin), 'host kreeg niets van de verwijderde gast');
  });
});
