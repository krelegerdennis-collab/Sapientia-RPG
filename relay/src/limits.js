'use strict';

// Token bucket: `rate` tokens per seconde, tot `burst` achter elkaar.
class TokenBucket {
  constructor(rate, burst, now = Date.now) {
    this.rate = rate;
    this.burst = burst;
    this.now = now;
    this.tokens = burst;
    this.last = now();
  }

  take(amount = 1) {
    const t = this.now();
    this.tokens = Math.min(this.burst, this.tokens + ((t - this.last) / 1000) * this.rate);
    this.last = t;
    if (this.tokens < amount) return false;
    this.tokens -= amount;
    return true;
  }
}

// Schuivend venster per sleutel (bv. IP): hoogstens `max` treffers per `windowMs`.
class WindowCounter {
  constructor(max, windowMs, now = Date.now) {
    this.max = max;
    this.windowMs = windowMs;
    this.now = now;
    this.hits = new Map();
  }

  // true = toegestaan (en geteld), false = over de limiet (niet geteld).
  hit(key) {
    const t = this.now();
    const list = (this.hits.get(key) || []).filter((x) => t - x < this.windowMs);
    if (list.length >= this.max) {
      this.hits.set(key, list);
      return false;
    }
    list.push(t);
    this.hits.set(key, list);
    return true;
  }

  sweep() {
    const t = this.now();
    for (const [key, list] of this.hits) {
      const fresh = list.filter((x) => t - x < this.windowMs);
      if (fresh.length === 0) this.hits.delete(key);
      else this.hits.set(key, fresh);
    }
  }
}

module.exports = { TokenBucket, WindowCounter };
