'use strict';
const crypto = require('node:crypto');

// Geen 0/O en 1/I/L: die lees je op een telefoonscherm of hoor je aan de telefoon verkeerd.
const CODE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const CODE_LENGTH = 6;
const CODE_PATTERN = new RegExp(`^[${CODE_ALPHABET}]{${CODE_LENGTH}}$`);

function generateCode(randomInt = crypto.randomInt) {
  let out = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += CODE_ALPHABET[randomInt(0, CODE_ALPHABET.length)];
  }
  return out;
}

// Geeft de genormaliseerde code (hoofdletters, zonder spaties) of null als hij niet klopt.
function normalizeCode(raw) {
  if (typeof raw !== 'string') return null;
  const code = raw.trim().toUpperCase();
  return CODE_PATTERN.test(code) ? code : null;
}

module.exports = { CODE_ALPHABET, CODE_LENGTH, generateCode, normalizeCode };
