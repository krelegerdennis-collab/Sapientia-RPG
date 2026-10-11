#!/usr/bin/env python3
"""Synthetische PLACEHOLDER-sfx voor de algemene manifest-set.

Leest assets/audio/audio_manifest.json en schrijft elk ontbrekend sfx-wav
plat naar assets/audio/sfx/ (nooit naar helden/ of monsters/). Formaat: mono,
16-bit, 22050 Hz, ruwweg 0.1–0.6 s. Daarnaast een Godot-4 .import-sidecar en
de lijst tools/placeholders_algemene_sfx.txt.

Dit is geen sounddesign. Zelfde bestandsnaam vervangen en de regel in de
placeholderlijst weghalen als er een echte opname is.

Bestaande bestanden worden niet overschreven (idempotent). Alleen paden die
het manifest noemt.

Gebruik (vanuit de repo-root):
    python3 tools/gen_algemene_sfx.py
"""

from __future__ import annotations

import array
import hashlib
import io
import json
import math
import os
import random
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "audio", "audio_manifest.json")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
PLACEHOLDER_LIST = os.path.join(ROOT, "tools", "placeholders_algemene_sfx.txt")
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")

SR = 22050
MIN_RMS = 0.02

# Godot 4.3 ResourceUID: char_count is ('z'-'a') en dus off-by-one (geen 'z'/'9').
_UID_CHAR_COUNT = ord("z") - ord("a")
_UID_BASE = _UID_CHAR_COUNT + (ord("9") - ord("0"))


def _n(dur: float) -> int:
    return max(1, int(SR * dur))


def _buf(dur: float) -> list[float]:
    return [0.0] * _n(dur)


def _accum(buf: list[float], samples: list[float], amp: float = 1.0, at: float = 0.0) -> None:
    start = _n(at) if at > 0.0 else 0
    limit = len(buf)
    for i, sample in enumerate(samples):
        j = start + i
        if j >= limit:
            break
        buf[j] += sample * amp


def _finish(buf: list[float]) -> list[float]:
    peak = max((abs(sample) for sample in buf), default=0.0) or 1.0
    gain = 0.82 / peak
    return [sample * gain for sample in buf]


def _env(samples: list[float], attack: float, release: float) -> list[float]:
    n = len(samples)
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    out: list[float] = []
    for i, sample in enumerate(samples):
        if i < a:
            e = i / a
        elif i > n - r:
            e = max(0.0, (n - i) / r)
        else:
            e = 1.0
        out.append(sample * e)
    return out


def _decay(samples: list[float], attack: float, tau: float) -> list[float]:
    a = max(1, int(SR * attack))
    d = max(1.0, tau * SR)
    out: list[float] = []
    for i, sample in enumerate(samples):
        if i < a:
            e = i / a
        else:
            e = math.exp(-(i - a) / d)
        out.append(sample * e)
    return out


def _wave(t: float, name: str) -> float:
    if name == "square":
        return 1.0 if t < 0.5 else -1.0
    if name == "tri":
        return 1.0 - 4.0 * abs(t - 0.5)
    if name == "saw":
        return 2.0 * t - 1.0
    return math.sin(2.0 * math.pi * t)


def _tone(freq: float, dur: float, name: str = "sine", amp: float = 1.0) -> list[float]:
    n = _n(dur)
    out: list[float] = []
    phase = 0.0
    step = freq / SR
    for _i in range(n):
        phase += step
        out.append(_wave(phase % 1.0, name) * amp)
    return out


def _sweep(f0: float, f1: float, dur: float, name: str = "sine", amp: float = 1.0) -> list[float]:
    n = _n(dur)
    out: list[float] = []
    phase = 0.0
    for i in range(n):
        k = i / max(n - 1, 1)
        phase += (f0 + (f1 - f0) * k) / SR
        out.append(_wave(phase % 1.0, name) * amp)
    return out


def _noise(dur: float, seed: int, amp: float = 1.0) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) * amp for _i in range(_n(dur))]


def _lowpass(samples: list[float], cutoff: float) -> list[float]:
    rc = 1.0 / (2.0 * math.pi * max(cutoff, 1.0))
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = 0.0
    out: list[float] = []
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def _highpass(samples: list[float], cutoff: float) -> list[float]:
    low = _lowpass(samples, cutoff)
    return [a - b for a, b in zip(samples, low)]


def _scale(samples: list[float], amp: float) -> list[float]:
    return [s * amp for s in samples]


def _semi(freq: float, steps: float) -> float:
    return freq * (2.0 ** (steps / 12.0))


def _click(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "square", 0.45), 0.001, 0.012))
    _accum(buf, _decay(_tone(f0 * 2.4, dur, "sine", 0.35), 0.001, 0.008))
    _accum(buf, _decay(_highpass(_noise(0.045, seed), 2200), 0.001, 0.006), 0.55)
    return _finish(buf)


def _soft_tick(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.001, 0.018))
    _accum(buf, _decay(_highpass(_noise(0.03, seed), 3000), 0.001, 0.006), 0.18)
    return _finish(buf)


def _two_tone(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    half = dur * 0.5
    second = f1 if f1 > 0.0 else f0
    _accum(buf, _decay(_tone(f0, half, "tri"), 0.004, 0.05))
    _accum(buf, _decay(_tone(second, half, "tri"), 0.004, 0.06), 1.0, half * 0.8)
    return _finish(buf)


def _buzz(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_tone(f0, dur, "square", 0.7), 0.01, dur * 0.25))
    _accum(buf, _env(_lowpass(_noise(dur, seed), 400), 0.008, dur * 0.2), 0.35)
    return _finish(buf)


def _slide(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 0.5
    _accum(buf, _env(_sweep(f0, end, dur, "saw", 0.45), 0.01, dur * 0.3))
    _accum(buf, _env(_lowpass(_noise(dur, seed), 900), 0.02, dur * 0.35), 0.4)
    return _finish(buf)


def _blip(dur: float, f0: float, _f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.002, 0.02))
    _accum(buf, _decay(_tone(f0 * 2.0, dur, "sine", 0.25), 0.002, 0.012))
    return _finish(buf)


def _chime(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    top = f1 if f1 > 0.0 else f0 * 1.5
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.008, 0.16))
    _accum(buf, _decay(_tone(top, dur, "sine", 0.55), 0.01, 0.14), 0.7, 0.08)
    _accum(buf, _decay(_tone(f0 * 2.0, dur * 0.5, "sine", 0.3), 0.004, 0.08), 0.5, dur * 0.42)
    _accum(buf, _decay(_highpass(_noise(0.04, seed), 2500), 0.001, 0.008), 0.35, dur * 0.4)
    return _finish(buf)


def _windup(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 3.0
    _accum(buf, _env(_sweep(f0, end, dur * 0.75, "tri", 0.7), 0.01, 0.04))
    _accum(buf, _decay(_tone(end, dur * 0.3, "sine"), 0.002, 0.04), 0.8, dur * 0.7)
    _accum(buf, _decay(_highpass(_noise(0.05, seed), 1800), 0.001, 0.01), 0.4, dur * 0.72)
    return _finish(buf)


def _ping(dur: float, f0: float, _f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.002, 0.05))
    _accum(buf, _decay(_tone(f0 * 2.01, dur, "sine", 0.35), 0.002, 0.03))
    _accum(buf, _decay(_tone(f0 * 3.0, dur, "tri", 0.15), 0.001, 0.02))
    return _finish(buf)


def _clang(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.002, 0.06))
    _accum(buf, _decay(_tone(f0 * 2.7, dur, "tri", 0.45), 0.001, 0.04))
    _accum(buf, _decay(_tone(f0 * 4.2, dur, "sine", 0.2), 0.001, 0.025))
    _accum(buf, _decay(_highpass(_noise(0.04, seed), 2500), 0.001, 0.008), 0.45)
    return _finish(buf)


def _gulp(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_highpass(_noise(0.05, seed), 1600), 0.001, 0.012), 0.7)
    _accum(buf, _env(_lowpass(_noise(dur * 0.7, seed + 3), 500), 0.02, 0.08), 0.8, 0.06)
    _accum(buf, _decay(_sweep(f0 * 2.0, f0, dur * 0.4, "sine", 0.4), 0.01, 0.08), 0.5, 0.08)
    return _finish(buf)


def _coins(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    rng = random.Random(seed)
    t = 0.0
    for i in range(6):
        freq = f0 * rng.uniform(0.75, 1.55)
        _accum(buf, _decay(_tone(freq, 0.09, "sine"), 0.001, 0.028), 0.7, t)
        _accum(buf, _decay(_tone(freq * 2.5, 0.06, "tri", 0.3), 0.001, 0.02), 0.4, t)
        t += dur / 7.0 + i * 0.004
    return _finish(buf)


def _creak(dur: float, f0: float, _f1: float, _seed: int) -> list[float]:
    n = _n(dur)
    raw: list[float] = []
    phase = 0.0
    for i in range(n):
        k = i / SR
        freq = f0 * (1.0 + 0.22 * math.sin(2.0 * math.pi * 7.0 * k))
        phase += freq / SR
        raw.append(math.sin(2.0 * math.pi * phase))
    return _finish(_env(raw, 0.02, dur * 0.25))


def _rustle(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_highpass(_noise(dur, seed), f0), 0.008, dur * 0.35))
    return _finish(buf)


def _arpeggio(dur: float, f0: float, _f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    steps = (0, 4, 7, 12)
    gap = dur / (len(steps) + 0.6)
    for i, step in enumerate(steps):
        _accum(buf, _decay(_tone(_semi(f0, step), 0.18, "sine"), 0.004, 0.07), 0.9, i * gap)
    _accum(buf, _env(_tone(f0 * 0.5, dur, "tri", 0.15), 0.02, dur * 0.3), 0.35)
    return _finish(buf)


def _fanfare(dur: float, f0: float, _f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    for i, step in enumerate((0, 4, 7, 12, 7)):
        _accum(buf, _decay(_tone(_semi(f0, step), 0.12, "tri"), 0.003, 0.05), 0.85, i * dur * 0.16)
    return _finish(buf)


def _gong(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.004, 0.2))
    _accum(buf, _decay(_tone(f0 * 2.01, dur, "sine", 0.4), 0.004, 0.12))
    _accum(buf, _decay(_tone(f0 * 2.98, dur, "tri", 0.2), 0.004, 0.08))
    _accum(buf, _decay(_lowpass(_noise(0.08, seed), 300), 0.001, 0.02), 0.25)
    return _finish(buf)


def _step(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    bright = f1 if f1 > 0.0 else 800.0
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.002, 0.03))
    _accum(buf, _decay(_highpass(_noise(0.07, seed), bright), 0.001, 0.016), 0.8)
    _accum(buf, _decay(_tone(f0 * 1.8, dur, "tri", 0.25), 0.002, 0.04), 0.45)
    return _finish(buf)


def _step_wood(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _step(dur, f0, f1, seed))
    n = len(buf)
    phase = 0.0
    for i in range(n):
        freq = 90.0 * (1.0 + 0.15 * math.sin(2.0 * math.pi * 14.0 * i / SR))
        phase += freq / SR
        buf[i] += 0.35 * math.sin(2.0 * math.pi * phase) * math.exp(-i / (0.04 * SR))
    return _finish(buf)


def _splash(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_lowpass(_noise(dur, seed), 700), 0.002, 0.04))
    _accum(buf, _decay(_tone(f0, dur * 0.5, "sine", 0.3), 0.004, 0.03), 0.4)
    rng = random.Random(seed)
    t = 0.02
    for _i in range(3):
        _accum(buf, _decay(_tone(f0 * rng.uniform(2.0, 4.0), 0.06, "sine"), 0.001, 0.02), 0.25, t)
        t += 0.03
    return _finish(buf)


def _land(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.001, 0.045))
    _accum(buf, _decay(_lowpass(_noise(0.08, seed), 400), 0.001, 0.03), 0.7)
    return _finish(buf)


def _slam(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.001, 0.05))
    _accum(buf, _decay(_lowpass(_noise(0.1, seed), 500), 0.001, 0.04), 0.85)
    _accum(buf, _decay(_tone(f0 * 3.0, 0.08, "square", 0.2), 0.001, 0.015), 0.4)
    return _finish(buf)


def _iron(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_lowpass(_noise(dur, seed), 900), dur * 0.15, dur * 0.25))
    _accum(buf, _env(_tone(f0, dur, "saw", 0.25), 0.04, dur * 0.2), 0.5)
    _accum(buf, _decay(_tone(f0 * 6.0, 0.12, "sine"), 0.002, 0.04), 0.35, dur * 0.55)
    return _finish(buf)


def _mech_door(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_sweep(f0, f0 * 2.2, dur * 0.7, "saw", 0.4), 0.02, 0.05))
    _accum(buf, _env(_lowpass(_noise(dur, seed), 1200), 0.03, dur * 0.2), 0.55)
    _accum(buf, _decay(_tone(f0 * 4.0, 0.1, "square", 0.3), 0.001, 0.02), 0.4, dur * 0.72)
    return _finish(buf)


def _rattle(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    rng = random.Random(seed)
    t = 0.0
    for _i in range(5):
        _accum(buf, _decay(_tone(f0 * rng.uniform(0.8, 1.6), 0.05, "square", 0.4), 0.001, 0.012), 0.6, t)
        _accum(buf, _decay(_highpass(_noise(0.03, seed + int(t * 1000)), 1500), 0.001, 0.008), 0.4, t)
        t += dur / 6.0
    return _finish(buf)


def _lever(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_sweep(f0 * 2.0, f0, dur * 0.65, "saw", 0.6), 0.01, 0.05))
    _accum(buf, _decay(_tone(f0 * 5.0, 0.08, "sine"), 0.001, 0.02), 0.7, dur * 0.62)
    _accum(buf, _decay(_highpass(_noise(0.04, seed), 1800), 0.001, 0.01), 0.35, dur * 0.6)
    return _finish(buf)


def _steam(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    cutoff = f0 if f0 > 50.0 else 800.0
    _accum(buf, _env(_lowpass(_noise(dur, seed), cutoff), 0.015, dur * 0.3))
    _accum(buf, _env(_highpass(_noise(dur, seed + 9), cutoff * 1.8), 0.02, dur * 0.25), 0.35)
    return _finish(buf)


def _elevator(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_tone(f0, dur, "saw", 0.35), 0.03, dur * 0.2))
    rng = random.Random(seed)
    t = 0.04
    while t < dur * 0.9:
        _accum(buf, _decay(_tone(f0 * rng.uniform(3.0, 6.0), 0.06, "square", 0.35), 0.001, 0.015), 0.45, t)
        t += 0.09
    return _finish(buf)


def _secret(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    top = f1 if f1 > 0.0 else f0 * 2.0
    _accum(buf, _env(_sweep(f0, top, dur * 0.7, "sine"), 0.02, 0.08))
    _accum(buf, _decay(_tone(top, dur * 0.4, "tri", 0.4), 0.004, 0.08), 0.6, dur * 0.45)
    _accum(buf, _decay(_highpass(_noise(0.04, seed), 2000), 0.001, 0.01), 0.3, dur * 0.5)
    return _finish(buf)


def _rune(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 3.0
    _accum(buf, _env(_sweep(f0, end, dur, "saw", 0.45), 0.03, dur * 0.25))
    _accum(buf, _env(_highpass(_noise(dur, seed), 2000), 0.02, dur * 0.3), 0.3)
    _accum(buf, _decay(_tone(end, dur * 0.35, "sine"), 0.004, 0.06), 0.4, dur * 0.55)
    return _finish(buf)


def _bell(dur: float, f0: float, _f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.003, 0.18))
    _accum(buf, _decay(_tone(f0 * 2.0, dur, "sine", 0.45), 0.002, 0.1))
    _accum(buf, _decay(_tone(f0 * 2.76, dur, "sine", 0.25), 0.002, 0.08))
    _accum(buf, _decay(_tone(f0 * 4.1, dur, "tri", 0.12), 0.001, 0.05))
    return _finish(buf)


def _stinger(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    second = f1 if f1 > 0.0 else f0 * 1.5
    _accum(buf, _env(_tone(f0, dur, "saw", 0.6), 0.01, dur * 0.35))
    _accum(buf, _env(_tone(second, dur, "square", 0.35), 0.015, dur * 0.3))
    _accum(buf, _decay(_tone(f0 * 0.5, dur, "sine", 0.5), 0.005, 0.16))
    return _finish(buf)


def _whoosh(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    body = _env(_highpass(_noise(dur, seed), f0), dur * 0.2, dur * 0.3)
    _accum(buf, body)
    return _finish(buf)


def _flesh(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_lowpass(_noise(dur, seed), 600), 0.001, 0.03))
    _accum(buf, _decay(_tone(f0, dur, "sine", 0.35), 0.002, 0.025), 0.5)
    _accum(buf, _decay(_highpass(_noise(0.04, seed + 4), 1800), 0.001, 0.008), 0.25)
    return _finish(buf)


def _armor(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _clang(dur, f0, 0.0, seed))
    _accum(buf, _decay(_highpass(_noise(0.05, seed + 2), 3000), 0.001, 0.01), 0.35)
    return _finish(buf)


def _crit(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.001, 0.08))
    _accum(buf, _decay(_lowpass(_noise(0.1, seed), 500), 0.001, 0.04), 0.8)
    _accum(buf, _decay(_tone(f0 * 4.0, dur, "sine", 0.4), 0.004, 0.1), 0.55, 0.02)
    return _finish(buf)


def _block(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "square", 0.5), 0.001, 0.03))
    _accum(buf, _decay(_tone(f0 * 1.5, dur, "sine", 0.4), 0.002, 0.05))
    _accum(buf, _decay(_lowpass(_noise(0.06, seed), 700), 0.001, 0.02), 0.4)
    return _finish(buf)


def _cry(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 0.6
    _accum(buf, _decay(_sweep(f0, end, dur, "sine"), 0.01, dur * 0.4))
    _accum(buf, _decay(_sweep(f0 * 2.1, end * 2.0, dur, "sine", 0.3), 0.01, dur * 0.3), 0.6)
    _accum(buf, _scale(_decay(_lowpass(_noise(dur, seed), 900), 0.01, dur * 0.25), 0.25))
    return _finish(buf)


def _death(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 0.4
    _accum(buf, _decay(_sweep(f0, end, dur * 0.7, "sine"), 0.015, dur * 0.35))
    _accum(buf, _decay(_tone(end, dur, "sine", 0.4), 0.02, 0.12), 0.5, dur * 0.35)
    _accum(buf, _decay(_lowpass(_noise(0.12, seed), 350), 0.001, 0.05), 0.65, dur * 0.45)
    return _finish(buf)


def _mech_break(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    rng = random.Random(seed)
    t = 0.0
    for _i in range(4):
        _accum(buf, _decay(_tone(f0 * rng.uniform(0.5, 1.4), 0.12, "square", 0.4), 0.001, 0.03), 0.6, t)
        t += dur * 0.16
    _accum(buf, _env(_highpass(_noise(dur * 0.5, seed), 2000), 0.005, 0.05), 0.4, dur * 0.2)
    _accum(buf, _decay(_tone(f0 * 0.25, dur, "saw", 0.4), 0.01, 0.1), 0.5, dur * 0.4)
    return _finish(buf)


def _heal(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    top = f1 if f1 > 0.0 else f0 * 2.0
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.01, 0.12))
    _accum(buf, _decay(_tone(_semi(f0, 4), dur, "sine", 0.7), 0.01, 0.1), 0.8, 0.08)
    _accum(buf, _decay(_tone(top, dur, "sine", 0.55), 0.01, 0.1), 0.7, 0.16)
    return _finish(buf)


def _buff(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 2.0
    _accum(buf, _env(_sweep(f0, end, dur, "sine"), 0.01, dur * 0.3))
    _accum(buf, _decay(_tone(end * 1.5, dur * 0.5, "tri", 0.35), 0.004, 0.06), 0.5, dur * 0.35)
    return _finish(buf)


def _debuff(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 0.5
    _accum(buf, _env(_sweep(f0, end, dur, "saw", 0.6), 0.008, dur * 0.3))
    _accum(buf, _env(_tone(end * 1.06, dur, "square", 0.25), 0.01, dur * 0.25), 0.5)
    return _finish(buf)


def _bubbles(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    rng = random.Random(seed)
    t = 0.0
    for _i in range(5):
        freq = f0 * rng.uniform(1.5, 3.2)
        _accum(buf, _decay(_tone(freq, 0.1, "sine"), 0.003, 0.03), 0.8, t)
        t += dur / 6.0
    _accum(buf, _env(_lowpass(_noise(dur, seed), 400), 0.02, dur * 0.3), 0.25)
    return _finish(buf)


def _fire(dur: float, _f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_lowpass(_noise(dur, seed), 900), 0.01, dur * 0.25))
    crackle = _highpass(_noise(dur, seed + 5), 2500)
    rng = random.Random(seed + 1)
    gated: list[float] = []
    for i, sample in enumerate(crackle):
        if i % int(SR * 0.012) == 0:
            gate = 1.0 if rng.random() > 0.45 else 0.15
        gated.append(sample * gate)
    _accum(buf, _env(gated, 0.005, dur * 0.2), 0.45)
    _accum(buf, _decay(_tone(90.0, dur, "sine", 0.3), 0.01, 0.08), 0.4)
    return _finish(buf)


def _stun(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    for i, step in enumerate((0, 4, 7, 12)):
        _accum(buf, _decay(_tone(_semi(f0, step), 0.1, "sine"), 0.002, 0.04), 0.6, i * 0.05)
    _accum(buf, _decay(_tone(80.0, dur, "sine"), 0.002, 0.05), 0.45, dur * 0.35)
    _accum(buf, _decay(_lowpass(_noise(0.06, seed), 300), 0.001, 0.02), 0.3, dur * 0.4)
    return _finish(buf)


def _flee(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    t = 0.0
    amp = 1.0
    step_i = 0
    while t < dur * 0.92:
        _accum(buf, _decay(_tone(f0, 0.08, "sine"), 0.001, 0.02), amp, t)
        _accum(buf, _decay(_highpass(_noise(0.05, seed + step_i), 1200), 0.001, 0.012), amp * 0.7, t)
        t += 0.07
        amp *= 0.72
        step_i += 1
    return _finish(buf)


def _stumble(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_lowpass(_noise(0.1, seed), 600), 0.001, 0.03), 0.8)
    _accum(buf, _decay(_sweep(f0 * 2.0, f0 * 0.7, dur * 0.6, "square", 0.4), 0.005, 0.06), 0.6, 0.08)
    return _finish(buf)


def _charge(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 4.0
    _accum(buf, _env(_sweep(f0, end, dur, "saw", 0.55), 0.02, 0.04))
    t = 0.0
    k = 0
    while t < dur * 0.85:
        _accum(buf, _decay(_tone(f0 * (2.0 + k), 0.04, "square", 0.25), 0.001, 0.01), 0.35, t)
        t += max(0.03, 0.08 - k * 0.01)
        k += 1
    _accum(buf, _env(_highpass(_noise(dur, seed), 1500), 0.02, 0.05), 0.2)
    return _finish(buf)


def _burst(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_lowpass(_noise(dur, seed), 1500), 0.001, 0.05))
    rng = random.Random(seed)
    for i in range(4):
        _accum(
            buf,
            _decay(_tone(f0 * rng.uniform(0.6, 1.8), 0.1, "square", 0.35), 0.001, 0.025),
            0.45,
            i * 0.03,
        )
    return _finish(buf)


def _lightning(dur: float, _f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    rng = random.Random(seed)
    t = 0.0
    for i in range(6):
        burst = _highpass(_noise(0.03, seed + i * 13), 2500)
        _accum(buf, _decay(burst, 0.0005, 0.008), 1.0, t)
        _accum(buf, _decay(_tone(rng.uniform(900, 2200), 0.04, "square", 0.3), 0.0005, 0.008), 0.4, t)
        t += rng.uniform(0.02, 0.05)
    return _finish(buf)


def _ice(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_sweep(f0 * 0.6, f0, dur * 0.55, "sine", 0.5), 0.02, 0.05))
    _accum(buf, _decay(_tone(f0 * 2.2, dur * 0.4, "tri", 0.4), 0.002, 0.04), 0.5, dur * 0.25)
    _accum(buf, _decay(_highpass(_noise(0.1, seed), 3000), 0.001, 0.02), 0.7, dur * 0.45)
    return _finish(buf)


def _beam(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_tone(f0, dur, "saw", 0.45), 0.01, dur * 0.15))
    _accum(buf, _env(_tone(f0 * 2.0, dur, "sine", 0.25), 0.015, dur * 0.15), 0.6)
    _accum(buf, _env(_highpass(_noise(dur, seed), 4000), 0.01, dur * 0.15), 0.2)
    return _finish(buf)


def _shield(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 2.0
    _accum(buf, _env(_sweep(f0, end, dur, "sine"), 0.03, dur * 0.35))
    _accum(buf, _env(_tone(end * 1.5, dur, "tri", 0.3), 0.04, dur * 0.3), 0.5)
    return _finish(buf)


def _summon(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_sweep(f0, f0 * 3.0, dur * 0.6, "saw", 0.4), 0.02, 0.06))
    _accum(buf, _decay(_tone(f0 * 2.0, dur, "sine"), 0.02, 0.12), 0.6, dur * 0.25)
    _accum(buf, _decay(_tone(f0 * 3.0, dur, "sine", 0.4), 0.02, 0.1), 0.5, dur * 0.35)
    _accum(buf, _decay(_tone(f0 * 8.0, 0.1, "square", 0.3), 0.001, 0.02), 0.35, dur * 0.55)
    _accum(buf, _decay(_lowpass(_noise(0.08, seed), 400), 0.001, 0.03), 0.25, dur * 0.5)
    return _finish(buf)


def _overload(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    rng = random.Random(seed)
    n = len(buf)
    phase = 0.0
    freq = f0
    for i in range(n):
        if i % int(SR * 0.016) == 0:
            freq = f0 * rng.choice((0.5, 1.0, 2.0, 3.0, 0.25))
        phase += freq / SR
        s = 1.0 if (phase % 1.0) < 0.5 else -1.0
        if i % 4 == 0:
            s = round(s * 5.0) / 5.0
        buf[i] += s * (1.0 if i < n * 0.75 else math.exp(-(i - n * 0.75) / (0.05 * SR)))
    _accum(buf, _decay(_tone(f0 * 0.5, dur, "sine", 0.4), 0.01, 0.08), 0.4)
    return _finish(buf)


def _claw(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_highpass(_noise(dur, seed), f0), dur * 0.15, dur * 0.25))
    _accum(buf, _decay(_tone(f0 * 0.4, dur, "saw", 0.2), 0.005, 0.03), 0.3)
    return _finish(buf)


def _bite(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_highpass(_noise(0.05, seed), 800), 0.001, 0.01))
    _accum(buf, _decay(_sweep(f0 * 1.4, f0, dur, "sine", 0.45), 0.008, 0.04), 0.7)
    return _finish(buf)


def _punch(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_lowpass(_noise(dur * 0.45, seed), 1000), 0.01, 0.05), 0.6)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.001, 0.05), 0.9, dur * 0.28)
    _accum(buf, _decay(_highpass(_noise(0.05, seed + 2), 2000), 0.001, 0.012), 0.4, dur * 0.3)
    return _finish(buf)


def _laser(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 4.0
    _accum(buf, _env(_sweep(f0, end, dur * 0.55, "saw", 0.4), 0.02, 0.02))
    _accum(buf, _decay(_tone(end, dur * 0.4, "square", 0.45), 0.001, 0.02), 0.8, dur * 0.5)
    _accum(buf, _decay(_highpass(_noise(0.04, seed), 4000), 0.001, 0.008), 0.3, dur * 0.52)
    return _finish(buf)


def _growl(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0
    n = _n(dur)
    raw: list[float] = []
    phase = 0.0
    for i in range(n):
        k = i / max(n - 1, 1)
        freq = f0 + (end - f0) * k
        phase += freq / SR
        trem = 0.65 + 0.35 * math.sin(2.0 * math.pi * 18.0 * i / SR)
        raw.append(math.sin(2.0 * math.pi * phase) * trem)
    _accum(buf, _env(raw, 0.02, dur * 0.25))
    _accum(buf, _env(_lowpass(_noise(dur, seed), 500), 0.02, dur * 0.25), 0.45)
    return _finish(buf)


def _alarm(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    second = f1 if f1 > 0.0 else f0 * 0.75
    half = dur * 0.45
    _accum(buf, _env(_tone(f0, half, "square"), 0.005, 0.02))
    _accum(buf, _env(_tone(second, half, "square"), 0.005, 0.02), 1.0, half)
    return _finish(buf)


def _roar(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    end = f1 if f1 > 0.0 else f0 * 0.75
    body = _decay(_sweep(f0, end, dur, "saw", 0.7), 0.02, dur * 0.4)
    clipped = [math.tanh(s * 2.2) for s in body]
    _accum(buf, clipped)
    _accum(buf, _decay(_lowpass(_noise(dur, seed), 400), 0.015, dur * 0.35), 0.55)
    _accum(buf, _env(_highpass(_noise(dur * 0.5, seed + 3), 1800), 0.05, 0.08), 0.2, dur * 0.1)
    return _finish(buf)


def _heavy_step(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.002, 0.08))
    _accum(buf, _decay(_lowpass(_noise(0.12, seed), 250), 0.001, 0.06), 0.9)
    _accum(buf, _decay(_tone(f0 * 2.2, dur, "tri", 0.25), 0.004, 0.05), 0.35)
    return _finish(buf)


def _phase(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_sweep(f0 * 3.0, f0, dur * 0.45, "saw", 0.5), 0.01, 0.04))
    _accum(buf, _decay(_sweep(f0 * 2.0, f0 * 0.7, dur * 0.4, "sine"), 0.01, 0.08), 0.7, dur * 0.3)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.002, 0.06), 0.8, dur * 0.55)
    _accum(buf, _decay(_lowpass(_noise(0.1, seed), 400), 0.001, 0.04), 0.4, dur * 0.55)
    return _finish(buf)


def _collapse(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    rng = random.Random(seed)
    t = 0.0
    amp = 1.0
    for _i in range(4):
        _accum(buf, _decay(_tone(f0 * rng.uniform(0.7, 1.5), 0.14, "sine"), 0.002, 0.05), amp, t)
        _accum(buf, _decay(_lowpass(_noise(0.08, seed + int(t * 100)), 400), 0.001, 0.03), amp * 0.6, t)
        t += dur * 0.16
        amp *= 0.8
    return _finish(buf)


def _clock_collapse(dur: float, f0: float, _f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0 * 4.0, dur * 0.4, "sine"), 0.003, 0.08))
    _accum(buf, _decay(_tone(f0 * 3.0, dur * 0.4, "sine", 0.7), 0.003, 0.08), 0.8, 0.1)
    t = 0.22
    gap = 0.06
    for _i in range(5):
        _accum(buf, _decay(_tone(f0 * 8.0, 0.04, "square", 0.35), 0.001, 0.01), 0.5, t)
        t += gap
        gap += 0.025
    _accum(buf, _decay(_tone(f0, dur, "sine", 0.5), 0.01, 0.1), 0.6, dur * 0.45)
    return _finish(buf)


def _awaken(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    voice = f1 if f1 > 0.0 else f0 * 4.0
    _accum(buf, _env(_sweep(f0, f0 * 2.5, dur * 0.45, "saw", 0.5), 0.03, 0.04))
    _accum(buf, _decay(_tone(voice, dur, "sine"), 0.02, 0.14), 0.7, dur * 0.32)
    _accum(buf, _decay(_tone(voice * 1.5, dur, "sine", 0.4), 0.03, 0.12), 0.45, dur * 0.4)
    _accum(buf, _decay(_tone(voice * 2.0, dur, "tri", 0.25), 0.03, 0.1), 0.35, dur * 0.46)
    _accum(buf, _env(_lowpass(_noise(dur * 0.3, seed), 500), 0.02, 0.05), 0.2)
    return _finish(buf)


def _whisper(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _env(_highpass(_noise(dur, seed), 1200), 0.04, dur * 0.4), 0.55)
    _accum(buf, _env(_tone(f0, dur, "sine", 0.35), 0.05, dur * 0.4), 0.7)
    _accum(buf, _env(_tone(f0 * 1.02, dur, "sine", 0.2), 0.06, dur * 0.35), 0.4)
    return _finish(buf)


def _sapi_blip(dur: float, f0: float, _f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.004, 0.03))
    _accum(buf, _decay(_tone(f0 * 1.5, dur, "sine", 0.3), 0.004, 0.02))
    return _finish(buf)


def _warning(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    second = f1 if f1 > 0.0 else f0 * 0.94
    _accum(buf, _env(_tone(f0, dur, "sine"), 0.02, dur * 0.2))
    _accum(buf, _env(_tone(second, dur, "sine", 0.85), 0.02, dur * 0.2), 0.9)
    half = dur * 0.5
    _accum(buf, _env(_tone(f0 * 2.0, half * 0.4, "square", 0.25), 0.005, 0.02), 0.5, 0.05)
    _accum(buf, _env(_tone(f0 * 2.0, half * 0.4, "square", 0.25), 0.005, 0.02), 0.5, half)
    return _finish(buf)


def _glitch(dur: float, f0: float, _f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    rng = random.Random(seed)
    n = len(buf)
    phase = 0.0
    freq = f0
    held = 0.0
    for i in range(n):
        if i % int(SR * 0.014) == 0:
            freq = f0 * rng.choice((0.25, 0.5, 1.0, 1.5, 2.0, 3.0))
        phase += freq / SR
        s = 1.0 if (phase % 1.0) < 0.5 else -1.0
        if i % 5 == 0:
            held = round(s * 4.0) / 4.0
        buf[i] = held
    return _finish(_env(buf, 0.004, 0.03))


def _surge(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    top = f1 if f1 > 0.0 else f0 * 3.0
    _accum(buf, _env(_sweep(f0, top, dur, "sine"), 0.03, dur * 0.25))
    _accum(buf, _env(_tone(top, dur, "sine", 0.45), 0.05, dur * 0.2), 0.6, dur * 0.2)
    _accum(buf, _env(_tone(top * 1.25, dur, "tri", 0.3), 0.05, dur * 0.2), 0.45, dur * 0.28)
    _accum(buf, _decay(_highpass(_noise(0.1, seed), 2000), 0.01, 0.04), 0.3, dur * 0.35)
    return _finish(buf)


def _approve(dur: float, f0: float, f1: float, _seed: int) -> list[float]:
    buf = _buf(dur)
    second = f1 if f1 > 0.0 else _semi(f0, 4)
    _accum(buf, _decay(_tone(f0, dur, "sine"), 0.006, 0.08))
    _accum(buf, _decay(_tone(second, dur, "sine", 0.75), 0.006, 0.09), 0.9, dur * 0.32)
    return _finish(buf)


def _sparkle_creak(dur: float, f0: float, f1: float, seed: int) -> list[float]:
    buf = _buf(dur)
    creak = _creak(dur * 0.7, f0, 0.0, seed)
    _accum(buf, creak, 0.8)
    top = f1 if f1 > 0.0 else 1400.0
    _accum(buf, _decay(_tone(top, dur * 0.4, "sine"), 0.004, 0.06), 0.55, dur * 0.4)
    _accum(buf, _decay(_tone(top * 1.5, dur * 0.3, "tri", 0.3), 0.004, 0.05), 0.4, dur * 0.5)
    return _finish(buf)


# kind, duur (s), f0, f1. f1 = 0 als het recept maar één toonhoogte gebruikt.
SPEC: dict[str, tuple[str, float, float, float]] = {
    "menu_click": ("click", 0.10, 1500, 0),
    "menu_hover": ("soft_tick", 0.10, 2400, 0),
    "menu_confirm": ("two_tone", 0.20, 660, 990),
    "menu_cancel": ("two_tone", 0.18, 520, 310),
    "menu_error": ("buzz", 0.24, 98, 0),
    "menu_open": ("slide", 0.28, 380, 980),
    "menu_close": ("slide", 0.26, 820, 260),
    "tab_switch": ("slide", 0.12, 1100, 1700),
    "dialogue_blip": ("blip", 0.10, 780, 0),
    "dialogue_advance": ("click", 0.10, 920, 0),
    "save_game": ("chime", 0.46, 523, 784),
    "load_game": ("windup", 0.40, 180, 720),
    "item_pickup": ("ping", 0.16, 1480, 0),
    "item_equip": ("clang", 0.18, 360, 0),
    "item_unequip": ("clang", 0.16, 240, 0),
    "item_use_potion": ("gulp", 0.32, 160, 0),
    "gold_coins": ("coins", 0.30, 1700, 0),
    "chest_open": ("sparkle_creak", 0.42, 150, 1320),
    "chest_locked": ("rattle", 0.22, 210, 0),
    "book_page_turn": ("rustle", 0.20, 2200, 0),
    "level_up": ("arpeggio", 0.50, 523, 0),
    "quest_accept": ("gong", 0.48, 98, 0),
    "quest_complete": ("fanfare", 0.42, 698, 0),
    "footstep_stone": ("step", 0.14, 110, 480),
    "footstep_wood": ("step_wood", 0.14, 150, 420),
    "footstep_metal": ("step", 0.12, 280, 2600),
    "footstep_marble": ("step", 0.16, 220, 1900),
    "footstep_water": ("splash", 0.18, 240, 0),
    "jump_land": ("land", 0.16, 85, 0),
    "door_open_wood": ("creak", 0.40, 140, 0),
    "door_close_wood": ("slam", 0.20, 100, 0),
    "door_open_iron": ("iron", 0.48, 70, 0),
    "door_open_mechanical": ("mech_door", 0.50, 75, 0),
    "door_locked": ("rattle", 0.18, 260, 0),
    "lever_pull": ("lever", 0.32, 80, 0),
    "switch_press": ("click", 0.10, 480, 0),
    "steam_vent": ("steam", 0.36, 650, 0),
    "elevator_mechanical": ("elevator", 0.56, 62, 0),
    "secret_discovered": ("secret", 0.42, 440, 880),
    "rune_activate": ("rune", 0.38, 280, 960),
    "clock_chime": ("bell", 0.56, 196, 0),
    "battle_start": ("stinger", 0.40, 98, 147),
    "turn_start": ("bell", 0.16, 880, 0),
    "command_select": ("click", 0.10, 1250, 0),
    "target_select": ("blip", 0.10, 1320, 0),
    "sword_swing": ("whoosh", 0.16, 1400, 0),
    "sword_hit_flesh": ("flesh", 0.14, 160, 0),
    "sword_hit_armor": ("armor", 0.18, 640, 0),
    "critical_hit": ("crit", 0.28, 180, 0),
    "block": ("block", 0.16, 520, 0),
    "dodge": ("whoosh", 0.12, 2200, 0),
    "miss": ("whoosh", 0.14, 700, 0),
    "player_hurt": ("cry", 0.22, 320, 180),
    "player_death": ("death", 0.48, 240, 80),
    "enemy_hurt": ("cry", 0.20, 170, 95),
    "enemy_death_organic": ("death", 0.46, 130, 55),
    "enemy_death_mechanical": ("mech_break", 0.50, 280, 0),
    "heal": ("heal", 0.40, 523, 1046),
    "buff_apply": ("buff", 0.28, 620, 1240),
    "debuff_apply": ("debuff", 0.28, 420, 190),
    "status_poison": ("bubbles", 0.36, 180, 0),
    "status_burn": ("fire", 0.30, 0, 0),
    "status_stun": ("stun", 0.36, 1500, 0),
    "flee_success": ("flee", 0.42, 140, 0),
    "flee_fail": ("stumble", 0.32, 200, 0),
    "spell_charge": ("charge", 0.42, 160, 980),
    "spell_cog_burst": ("burst", 0.32, 420, 0),
    "spell_fire": ("fire", 0.34, 0, 0),
    "spell_lightning": ("lightning", 0.28, 0, 0),
    "spell_ice": ("ice", 0.30, 1680, 0),
    "spell_arcane_beam": ("beam", 0.36, 740, 0),
    "spell_steam": ("steam", 0.34, 1400, 0),
    "spell_shield": ("shield", 0.36, 280, 640),
    "spell_summon": ("summon", 0.56, 90, 0),
    "spell_overload": ("overload", 0.48, 80, 0),
    "enemy_attack_claw": ("claw", 0.16, 1800, 0),
    "enemy_attack_bite": ("bite", 0.14, 210, 0),
    "enemy_attack_mech_punch": ("punch", 0.24, 70, 0),
    "enemy_attack_steam_blast": ("steam", 0.30, 420, 0),
    "enemy_attack_laser": ("laser", 0.32, 360, 2400),
    "enemy_growl": ("growl", 0.36, 85, 62),
    "enemy_alert": ("alarm", 0.40, 880, 659),
    "golem_roar": ("roar", 0.56, 48, 36),
    "golem_step": ("heavy_step", 0.28, 46, 0),
    "golem_slam": ("slam", 0.36, 38, 0),
    "golem_hurt": ("roar", 0.32, 70, 48),
    "golem_death": ("collapse", 0.58, 42, 0),
    "boss_intro_stinger": ("stinger", 0.50, 65, 98),
    "boss_phase_change": ("phase", 0.56, 55, 0),
    "finalboss_roar": ("roar", 0.58, 40, 70),
    "finalboss_defeat": ("clock_collapse", 0.58, 49, 0),
    "sapientia_awaken": ("awaken", 0.58, 70, 494),
    "sapientia_whisper": ("whisper", 0.40, 466, 0),
    "sapientia_speak_blip": ("sapi_blip", 0.10, 640, 0),
    "sapientia_warning": ("warning", 0.48, 196, 185),
    "sapientia_glitch": ("glitch", 0.32, 280, 0),
    "sapientia_power_surge": ("surge", 0.50, 220, 880),
    "sapientia_approve": ("approve", 0.28, 523, 659),
    "molen_zang": ("two_tone", 0.50, 392, 494),
}

KINDS = {
    "click": _click,
    "soft_tick": _soft_tick,
    "two_tone": _two_tone,
    "buzz": _buzz,
    "slide": _slide,
    "blip": _blip,
    "chime": _chime,
    "windup": _windup,
    "ping": _ping,
    "clang": _clang,
    "gulp": _gulp,
    "coins": _coins,
    "creak": _creak,
    "rustle": _rustle,
    "arpeggio": _arpeggio,
    "fanfare": _fanfare,
    "gong": _gong,
    "step": _step,
    "step_wood": _step_wood,
    "splash": _splash,
    "land": _land,
    "slam": _slam,
    "iron": _iron,
    "mech_door": _mech_door,
    "rattle": _rattle,
    "lever": _lever,
    "steam": _steam,
    "elevator": _elevator,
    "secret": _secret,
    "rune": _rune,
    "bell": _bell,
    "stinger": _stinger,
    "whoosh": _whoosh,
    "flesh": _flesh,
    "armor": _armor,
    "crit": _crit,
    "block": _block,
    "cry": _cry,
    "death": _death,
    "mech_break": _mech_break,
    "heal": _heal,
    "buff": _buff,
    "debuff": _debuff,
    "bubbles": _bubbles,
    "fire": _fire,
    "stun": _stun,
    "flee": _flee,
    "stumble": _stumble,
    "charge": _charge,
    "burst": _burst,
    "lightning": _lightning,
    "ice": _ice,
    "beam": _beam,
    "shield": _shield,
    "summon": _summon,
    "overload": _overload,
    "claw": _claw,
    "bite": _bite,
    "punch": _punch,
    "laser": _laser,
    "growl": _growl,
    "alarm": _alarm,
    "roar": _roar,
    "heavy_step": _heavy_step,
    "phase": _phase,
    "collapse": _collapse,
    "clock_collapse": _clock_collapse,
    "awaken": _awaken,
    "whisper": _whisper,
    "sapi_blip": _sapi_blip,
    "warning": _warning,
    "glitch": _glitch,
    "surge": _surge,
    "approve": _approve,
    "sparkle_creak": _sparkle_creak,
}


def _seed(key: str, variant: int) -> int:
    value = 2166136261
    for ch in ("%s:%d" % (key, variant)).encode():
        value ^= ch
        value = (value * 16777619) & 0xFFFFFFFF
    return value


def _variant(filename: str) -> int:
    stem = filename[:-4] if filename.endswith(".wav") else filename
    tail = stem.rsplit("_", 1)[-1]
    if not tail.isdigit():
        raise SystemExit("geen variantnummer in %s" % filename)
    return int(tail)


def render(key: str, variant: int) -> list[float]:
    kind, dur, f0, f1 = SPEC[key]
    seed = _seed(key, variant)
    pitch = (1.0 + (variant - 1) * 0.08) * (1.0 + ((seed % 9) - 4) * 0.008)
    f0_p = f0 * pitch
    f1_p = f1 * pitch if f1 else 0.0
    fn = KINDS[kind]
    return fn(dur, f0_p, f1_p, seed)


def _rms(samples: list[float]) -> float:
    if not samples:
        return 0.0
    return math.sqrt(sum(s * s for s in samples) / len(samples))


def _write_wav(path: str, samples: list[float]) -> None:
    rms = _rms(samples)
    if rms < MIN_RMS:
        raise SystemExit("%s klinkt leeg (rms %.4f)" % (path, rms))
    pcm = array.array("h", (max(-32767, min(32767, int(s * 32767.0))) for s in samples))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


def _uid_text(res_path: str) -> str:
    digest = hashlib.sha256(res_path.encode("utf-8")).digest()
    value = int.from_bytes(digest[:8], "big") & 0x7FFFFFFFFFFFFFFF
    if value <= 0:
        value = 1
    txt: list[str] = []
    while value:
        c = value % _UID_BASE
        if c < _UID_CHAR_COUNT:
            txt.append(chr(ord("a") + c))
        else:
            txt.append(chr(ord("0") + (c - _UID_CHAR_COUNT)))
        value //= _UID_BASE
    return "uid://" + "".join(reversed(txt))


def _write_import(wav_name: str) -> None:
    res_path = "res://assets/audio/sfx/" + wav_name
    digest = hashlib.md5(res_path.encode("utf-8")).hexdigest()
    dest = "res://.godot/imported/%s-%s.sample" % (wav_name, digest)
    text = "\n".join([
        "[remap]",
        "",
        'importer="wav"',
        'type="AudioStreamWAV"',
        'uid="%s"' % _uid_text(res_path),
        'path="%s"' % dest,
        "",
        "[deps]",
        "",
        'source_file="%s"' % res_path,
        'dest_files=["%s"]' % dest,
        "",
        "[params]",
        "",
        "force/8_bit=false",
        "force/mono=false",
        "force/max_rate=false",
        "force/max_rate_hz=44100",
        "edit/trim=false",
        "edit/normalize=false",
        "edit/loop_mode=0",
        "edit/loop_begin=0",
        "edit/loop_end=-1",
        "compress/mode=0",
        "",
    ])
    import_path = os.path.join(SFX_DIR, wav_name + ".import")
    if os.path.exists(import_path):
        return
    with open(import_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def _handwerk() -> set[str]:
    found: set[str] = set()
    if not os.path.exists(HANDWERK):
        return found
    with open(HANDWERK, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#", 1)[0].strip().replace("\\", "/")
            if line:
                found.add(line)
    return found


def _manifest_entries() -> list[dict[str, str]]:
    with open(MANIFEST, encoding="utf-8") as handle:
        data = json.load(handle)
    entries: list[dict[str, str]] = []
    for key, entry in data["sfx"].items():
        files = entry.get("bestanden", [])
        if not files:
            raise SystemExit("sfx-sleutel zonder bestanden: %s" % key)
        for filename in files:
            if not isinstance(filename, str) or "/" in filename or "\\" in filename:
                raise SystemExit("sfx-pad moet een platte bestandsnaam zijn: %s" % filename)
            if not filename.endswith(".wav"):
                raise SystemExit("sfx is geen wav: %s" % filename)
            entries.append({
                "key": key,
                "filename": filename,
                "categorie": str(entry.get("categorie", "")),
                "beschrijving": " ".join(str(entry.get("beschrijving", "")).split()),
            })
    return entries


def _write_placeholder(entries: list[dict[str, str]]) -> None:
    lines = [
        "# PLACEHOLDER-SFX algemeen (tools/gen_algemene_sfx.py). Synthetisch, geen definitief geluid.",
        "# Patroon als tools/placeholders_v17.txt: pad, soort, omschrijving.",
        "# Bron: assets/audio/audio_manifest.json sectie sfx. Plat in assets/audio/sfx/.",
        "# Vervang het wav-bestand (zelfde naam) en haal de regel hier weg.",
        "# Acteur-sfx (helden/ en monsters/) staan niet in deze lijst.",
    ]
    for entry in entries:
        rel = "assets/audio/sfx/" + entry["filename"]
        lines.append("%s   wav   %s/%s: %s" % (
            rel, entry["categorie"], entry["key"], entry["beschrijving"],
        ))
    with open(PLACEHOLDER_LIST, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def main() -> None:
    missing_kinds = {spec[0] for spec in SPEC.values()} - set(KINDS)
    if missing_kinds:
        raise SystemExit("onbekende kinds: %s" % ", ".join(sorted(missing_kinds)))
    entries = _manifest_entries()
    keys = {entry["key"] for entry in entries}
    extra = set(SPEC) - keys
    absent = keys - set(SPEC)
    if extra or absent:
        raise SystemExit("SPEC wijkt af van het manifest (extra=%s afwezig=%s)" % (
            ", ".join(sorted(extra)) or "-",
            ", ".join(sorted(absent)) or "-",
        ))
    blocked = _handwerk()
    targets = ["assets/audio/sfx/" + entry["filename"] for entry in entries]
    hit = [rel for rel in targets if rel in blocked]
    if hit:
        raise SystemExit("handwerk.txt blokkeert: %s" % ", ".join(hit))
    os.makedirs(SFX_DIR, exist_ok=True)
    written = 0
    skipped = 0
    blobs: dict[bytes, str] = {}
    min_rms = 1.0
    min_dur = 99.0
    max_dur = 0.0
    for entry in entries:
        filename = entry["filename"]
        path = os.path.join(SFX_DIR, filename)
        if os.path.exists(path):
            skipped += 1
        else:
            samples = render(entry["key"], _variant(filename))
            _write_wav(path, samples)
            written += 1
        _write_import(filename)
        with open(path, "rb") as handle:
            blob = handle.read()
        if blob in blobs:
            raise SystemExit("%s is identiek aan %s" % (filename, blobs[blob]))
        blobs[blob] = filename
        with wave.open(path, "rb") as handle:
            dur = handle.getnframes() / float(handle.getframerate())
        frames = _wav_rms(blob)
        if frames < MIN_RMS:
            raise SystemExit("%s te stil na schrijven (rms %.4f)" % (filename, frames))
        min_rms = min(min_rms, frames)
        min_dur = min(min_dur, dur)
        max_dur = max(max_dur, dur)
    _write_placeholder(entries)
    print("geschreven: %d wavs" % written)
    print("overgeslagen: %d (bestonden al)" % skipped)
    print("totaal: %d" % len(entries))
    print("duur %.3f..%.3f s, rms-min %.3f" % (min_dur, max_dur, min_rms))
    print("placeholders: tools/placeholders_algemene_sfx.txt")


def _wav_rms(blob: bytes) -> float:
    with wave.open(io.BytesIO(blob), "rb") as handle:
        raw = handle.readframes(handle.getnframes())
    count = len(raw) // 2
    if count == 0:
        return 0.0
    pcm = array.array("h")
    pcm.frombytes(raw)
    total = 0.0
    for sample in pcm:
        v = sample / 32767.0
        total += v * v
    return math.sqrt(total / count)


if __name__ == "__main__":
    main()
