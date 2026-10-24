'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { TokenBucket, WindowCounter } = require('../src/limits');

test('TokenBucket: burst, leeg, daarna aanvullen met de tijd', () => {
  let t = 0;
  const b = new TokenBucket(10, 5, () => t);
  for (let i = 0; i < 5; i++) assert.ok(b.take(1));
  assert.ok(!b.take(1));
  t += 100;
  assert.ok(b.take(1));
  assert.ok(!b.take(1));
  t += 10000;
  assert.ok(b.take(5));
  assert.ok(!b.take(1), 'nooit boven burst');
});

test('TokenBucket: grote bericht-grootte telt mee', () => {
  let t = 0;
  const b = new TokenBucket(100, 1000, () => t);
  assert.ok(b.take(900));
  assert.ok(!b.take(200));
});

test('WindowCounter: per sleutel, venster schuift op', () => {
  let t = 0;
  const w = new WindowCounter(2, 1000, () => t);
  assert.ok(w.hit('a'));
  assert.ok(w.hit('a'));
  assert.ok(!w.hit('a'));
  assert.ok(w.hit('b'));
  t += 1001;
  assert.ok(w.hit('a'));
  w.sweep();
  t += 5000;
  w.sweep();
  assert.strictEqual(w.hits.size, 0);
});
