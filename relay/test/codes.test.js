'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { CODE_ALPHABET, CODE_LENGTH, generateCode, normalizeCode } = require('../src/codes');

test('alfabet bevat geen dubbelzinnige tekens', () => {
  for (const ch of '01OIL') assert.ok(!CODE_ALPHABET.includes(ch), `${ch} hoort er niet in`);
  assert.strictEqual(new Set(CODE_ALPHABET).size, CODE_ALPHABET.length);
  assert.strictEqual(CODE_ALPHABET.length, 31);
});

test('generateCode: 6 tekens uit het alfabet', () => {
  for (let i = 0; i < 500; i++) {
    const code = generateCode();
    assert.strictEqual(code.length, CODE_LENGTH);
    for (const ch of code) assert.ok(CODE_ALPHABET.includes(ch));
  }
});

test('generateCode: gebruikt het hele alfabet en geeft geen vaste uitkomst', () => {
  const seen = new Set();
  const codes = new Set();
  for (let i = 0; i < 2000; i++) {
    const code = generateCode();
    codes.add(code);
    for (const ch of code) seen.add(ch);
  }
  assert.strictEqual(seen.size, CODE_ALPHABET.length);
  assert.ok(codes.size > 1990);
});

test('normalizeCode: hoofdletters, spaties, ongeldige invoer', () => {
  assert.strictEqual(normalizeCode('abc234'), 'ABC234');
  assert.strictEqual(normalizeCode('  ABC234 '), 'ABC234');
  assert.strictEqual(normalizeCode('ABC23'), null);
  assert.strictEqual(normalizeCode('ABC2345'), null);
  assert.strictEqual(normalizeCode('ABC230'), null);
  assert.strictEqual(normalizeCode('ABCI23'), null);
  assert.strictEqual(normalizeCode(123456), null);
  assert.strictEqual(normalizeCode(null), null);
  assert.strictEqual(normalizeCode({}), null);
});
