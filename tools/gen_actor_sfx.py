#!/usr/bin/env python3
"""Synthetische PLACEHOLDER-sfx per held en monster.

Leest assets/audio/actor_sfx.json en schrijft voor elke id en elk slot een
mono 16-bit wav (22050 Hz) naar assets/audio/sfx/helden/<id>/ en
assets/audio/sfx/monsters/<id>/. Ook een LEESMIJ.md per map en de lijst
tools/placeholders_sfx.txt.

Dit zijn geen definitieve geluiden. Zelfde bestandsnaam vervangen en de regel
in tools/placeholders_sfx.txt weghalen als er een echte opname is.

Gebruik (vanuit de repo-root):
    python3 tools/gen_actor_sfx.py
"""

from __future__ import annotations

import json
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "assets", "audio", "actor_sfx.json")
SFX_ROOT = os.path.join(ROOT, "assets", "audio", "sfx")
PLACEHOLDER_LIST = os.path.join(ROOT, "tools", "placeholders_sfx.txt")

SR = 22050
SLOTS = ("aanval", "raak", "dood", "vaardigheid")


def _n(dur: float) -> int:
	return max(1, int(SR * dur))


def _mix(*layers: list[float]) -> list[float]:
	length = max((len(layer) for layer in layers), default=0)
	out = [0.0] * length
	for layer in layers:
		for i, sample in enumerate(layer):
			out[i] += sample
	peak = max((abs(sample) for sample in out), default=1.0) or 1.0
	gain = 0.82 / peak
	return [sample * gain for sample in out]


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


def _tone(freq: float, dur: float, wave_name: str = "sine", amp: float = 1.0) -> list[float]:
	n = _n(dur)
	out: list[float] = []
	phase = 0.0
	for _i in range(n):
		phase += freq / SR
		t = phase % 1.0
		if wave_name == "square":
			s = 1.0 if t < 0.5 else -1.0
		elif wave_name == "tri":
			s = 1.0 - 4.0 * abs(t - 0.5)
		elif wave_name == "saw":
			s = 2.0 * t - 1.0
		else:
			s = math.sin(2.0 * math.pi * t)
		out.append(s * amp)
	return out


def _sweep(f0: float, f1: float, dur: float, wave_name: str = "sine", amp: float = 1.0) -> list[float]:
	n = _n(dur)
	out: list[float] = []
	phase = 0.0
	for i in range(n):
		k = i / max(n - 1, 1)
		freq = f0 + (f1 - f0) * k
		phase += freq / SR
		t = phase % 1.0
		if wave_name == "square":
			s = 1.0 if t < 0.5 else -1.0
		elif wave_name == "tri":
			s = 1.0 - 4.0 * abs(t - 0.5)
		else:
			s = math.sin(2.0 * math.pi * t)
		out.append(s * amp)
	return out


def _noise(dur: float, seed: int, amp: float = 1.0) -> list[float]:
	rng = random.Random(seed)
	return [rng.uniform(-1.0, 1.0) * amp for _i in range(_n(dur))]


def _lowpass(samples: list[float], cutoff: float) -> list[float]:
	rc = 1.0 / (2.0 * math.pi * max(cutoff, 1.0))
	dt = 1.0 / SR
	a = dt / (rc + dt)
	y = 0.0
	out: list[float] = []
	for x in samples:
		y += a * (x - y)
		out.append(y)
	return out


def _highpass(samples: list[float], cutoff: float) -> list[float]:
	low = _lowpass(samples, cutoff)
	return [a - b for a, b in zip(samples, low)]


def _delay(samples: list[float], seconds: float) -> list[float]:
	pad = _n(seconds)
	return [0.0] * pad + samples


def _scale(samples: list[float], amp: float) -> list[float]:
	return [s * amp for s in samples]


def _crush(samples: list[float], hold: int, steps: int) -> list[float]:
	out: list[float] = []
	acc = 0.0
	for i, sample in enumerate(samples):
		if i % hold == 0:
			acc = round(sample * steps) / steps
		out.append(acc)
	return out


def _whoosh(dur: float, seed: int, cutoff: float) -> list[float]:
	body = _env(_highpass(_noise(dur, seed), cutoff), dur * 0.25, dur * 0.35)
	return body


def _clang(freq: float, dur: float) -> list[float]:
	body = _decay(_tone(freq, dur, "sine"), 0.004, 0.06)
	over = _decay(_tone(freq * 2.02, dur, "sine", 0.45), 0.002, 0.04)
	ring = _decay(_tone(freq * 3.4, dur, "tri", 0.2), 0.001, 0.03)
	click = _decay(_highpass(_noise(0.05, int(freq)), 2000), 0.001, 0.008)
	return _mix(body, over, ring, _scale(click, 0.5))


def _cry(f0: float, f1: float, dur: float, seed: int, grit: float) -> list[float]:
	body = _decay(_sweep(f0, f1, dur, "sine"), 0.012, dur * 0.45)
	form = _decay(_sweep(f0 * 2.3, f1 * 2.1, dur, "sine", 0.35), 0.01, dur * 0.3)
	air = _scale(_decay(_lowpass(_noise(dur, seed), 900), 0.01, dur * 0.25), grit)
	return _mix(body, form, air)


def _shimmer(f0: float, f1: float, dur: float) -> list[float]:
	a = _env(_sweep(f0, f1, dur, "sine"), 0.02, dur * 0.4)
	b = _env(_sweep(f0 * 1.5, f1 * 1.25, dur, "tri", 0.4), 0.03, dur * 0.35)
	return _mix(a, b)


def _bubbles(seed: int, count: int, f0: float) -> list[float]:
	rng = random.Random(seed)
	layers: list[list[float]] = []
	t = 0.0
	for i in range(count):
		freq = f0 * rng.uniform(0.8, 1.6) * (1.0 + i * 0.08)
		blip = _decay(_tone(freq, 0.12, "sine"), 0.004, 0.04)
		layers.append(_delay(blip, t))
		t += rng.uniform(0.05, 0.09)
	return _mix(*layers)


def _rustle(dur: float, seed: int, brightness: float) -> list[float]:
	return _env(_highpass(_noise(dur, seed), brightness), 0.01, dur * 0.3)


def _creak(f0: float, dur: float, wobble: float) -> list[float]:
	n = _n(dur)
	out: list[float] = []
	phase = 0.0
	for i in range(n):
		k = i / SR
		freq = f0 * (1.0 + wobble * math.sin(2.0 * math.pi * 6.0 * k))
		phase += freq / SR
		out.append(math.sin(2.0 * math.pi * phase))
	return _env(out, 0.03, dur * 0.25)


def _puff(dur: float, seed: int, cutoff: float) -> list[float]:
	return _decay(_lowpass(_noise(dur, seed), cutoff), 0.005, dur * 0.35)


def _glitch(dur: float, seed: int, f0: float) -> list[float]:
	rng = random.Random(seed)
	n = _n(dur)
	out: list[float] = []
	phase = 0.0
	freq = f0
	for i in range(n):
		if i % int(SR * 0.018) == 0:
			freq = f0 * rng.choice((0.5, 1.0, 1.5, 2.0, 0.25))
		phase += freq / SR
		s = 1.0 if (phase % 1.0) < 0.5 else -1.0
		out.append(s)
	return _env(_crush(out, 4, 6), 0.005, 0.04)


def _hoot(f0: float, f1: float, dur: float, seed: int) -> list[float]:
	body = _env(_sweep(f0, f1, dur, "sine"), 0.03, dur * 0.45)
	air = _scale(_env(_highpass(_noise(dur, seed), 1500), 0.02, dur * 0.4), 0.25)
	n = len(body)
	trem: list[float] = []
	for i, sample in enumerate(body):
		trem.append(sample * (0.75 + 0.25 * math.sin(2.0 * math.pi * 8.0 * i / SR)))
	return _mix(trem, air)


def render(actor_id: str, slot: str) -> list[float]:
	"""Eén placeholder. Elke id+slot is een eigen recept, zodat ze uit elkaar te houden zijn."""
	seed = _stable_seed(actor_id, slot)
	if actor_id == "dennis":
		if slot == "aanval":
			return _mix(_whoosh(0.16, seed, 900), _scale(_clang(240, 0.2), 0.7))
		if slot == "raak":
			return _cry(170, 95, 0.24, seed, 0.25)
		if slot == "dood":
			return _mix(_cry(140, 55, 0.5, seed, 0.3), _delay(_scale(_clang(70, 0.35), 0.8), 0.18))
		return _mix(_whoosh(0.26, seed, 500), _clang(110, 0.34))
	if actor_id == "noor":
		if slot == "aanval":
			return _shimmer(680, 1400, 0.22)
		if slot == "raak":
			return _cry(420, 240, 0.2, seed, 0.08)
		if slot == "dood":
			return _shimmer(980, 220, 0.48)
		zap = _decay(_sweep(400, 1900, 0.28, "saw", 0.6), 0.01, 0.08)
		crackle = _scale(_env(_highpass(_noise(0.2, seed), 2500), 0.01, 0.05), 0.45)
		return _mix(zap, crackle)
	if actor_id == "kael":
		if slot == "aanval":
			return _mix(_decay(_sweep(900, 2600, 0.18, "sine", 0.5), 0.005, 0.08), _scale(_clang(1300, 0.1), 0.4))
		if slot == "raak":
			return _cry(210, 130, 0.22, seed, 0.15)
		if slot == "dood":
			return _mix(_shimmer(1500, 300, 0.5), _delay(_scale(_clang(900, 0.25), 0.5), 0.12))
		return _mix(_decay(_tone(660, 0.3, "sine"), 0.01, 0.1), _delay(_decay(_tone(880, 0.3, "sine", 0.7), 0.01, 0.1), 0.06),
				_delay(_decay(_tone(1100, 0.3, "sine", 0.5), 0.01, 0.1), 0.12))
	if actor_id == "orion":
		if slot == "aanval":
			return _mix(_decay(_tone(196, 0.2, "saw", 0.6), 0.002, 0.1), _delay(_whoosh(0.18, seed, 1600), 0.04))
		if slot == "raak":
			return _cry(190, 120, 0.2, seed, 0.2)
		if slot == "dood":
			return _mix(_cry(160, 70, 0.45, seed, 0.25), _delay(_scale(_clang(150, 0.3), 0.6), 0.2))
		return _mix(_decay(_tone(147, 0.28, "saw", 0.7), 0.002, 0.12), _delay(_whoosh(0.2, seed, 2200), 0.03), _delay(_scale(_clang(400, 0.2), 0.7), 0.2))
	if actor_id == "lotte":
		if slot == "aanval":
			return _mix(_scale(_clang(520, 0.16), 0.5), _decay(_tone(440, 0.25, "sine"), 0.01, 0.12))
		if slot == "raak":
			return _cry(280, 170, 0.22, seed, 0.1)
		if slot == "dood":
			return _mix(_decay(_tone(523, 0.45, "sine"), 0.02, 0.2), _delay(_decay(_tone(392, 0.4, "sine", 0.6), 0.02, 0.2), 0.08))
		return _mix(
			_decay(_tone(523, 0.4, "sine"), 0.01, 0.16),
			_delay(_decay(_tone(659, 0.36, "sine", 0.7), 0.01, 0.14), 0.08),
			_delay(_decay(_tone(784, 0.34, "sine", 0.55), 0.01, 0.14), 0.16),
		)
	if actor_id == "mosslijm":
		if slot == "aanval":
			return _mix(_puff(0.2, seed, 280), _scale(_cry(90, 70, 0.18, seed, 0.4), 0.5))
		if slot == "raak":
			return _puff(0.12, seed, 500)
		if slot == "dood":
			return _puff(0.45, seed, 180)
		return _bubbles(seed, 4, 180)
	if actor_id == "moskonijn":
		if slot == "aanval":
			return _mix(_scale(_whoosh(0.08, seed, 1400), 0.4), _cry(980, 1400, 0.1, seed, 0.05))
		if slot == "raak":
			return _cry(1400, 800, 0.12, seed, 0.05)
		if slot == "dood":
			return _cry(1100, 220, 0.36, seed, 0.08)
		return _mix(_cry(1200, 900, 0.08, seed, 0.04), _delay(_cry(1500, 1000, 0.08, seed + 1, 0.04), 0.09))
	if actor_id == "papiergeest":
		if slot == "aanval":
			return _rustle(0.22, seed, 1800)
		if slot == "raak":
			return _rustle(0.1, seed, 2800)
		if slot == "dood":
			return _mix(_rustle(0.35, seed, 1200), _delay(_scale(_puff(0.2, seed, 200), 0.4), 0.12))
		return _rustle(0.4, seed, 2200)
	if actor_id == "glitchmot":
		if slot == "aanval":
			return _mix(_glitch(0.16, seed, 640), _scale(_whoosh(0.12, seed, 2000), 0.3))
		if slot == "raak":
			return _glitch(0.08, seed, 900)
		if slot == "dood":
			return _glitch(0.4, seed, 500)
		return _mix(_glitch(0.22, seed, 300), _scale(_clang(1800, 0.12), 0.35))
	if actor_id == "mech_wachter":
		if slot == "aanval":
			servo = _env(_sweep(180, 90, 0.16, "saw", 0.4), 0.01, 0.05)
			return _mix(servo, _clang(160, 0.22))
		if slot == "raak":
			return _clang(220, 0.16)
		if slot == "dood":
			return _mix(
				_clang(300, 0.2),
				_delay(_clang(180, 0.22), 0.08),
				_delay(_clang(90, 0.3), 0.16),
				_delay(_scale(_glitch(0.2, seed, 80), 0.3), 0.1),
			)
		return _mix(_clang(90, 0.32), _scale(_whoosh(0.18, seed, 400), 0.35))
	if actor_id == "kennis_beest":
		if slot == "aanval":
			return _mix(_clang(55, 0.3), _scale(_rustle(0.25, seed, 900), 0.35))
		if slot == "raak":
			return _mix(_clang(80, 0.2), _scale(_noise(0.08, seed), 0.2))
		if slot == "dood":
			return _mix(_puff(0.6, seed, 120), _clang(40, 0.5), _delay(_rustle(0.4, seed, 700), 0.1))
		return _mix(_clang(48, 0.4), _delay(_clang(70, 0.25), 0.06))
	if actor_id == "wortelkruiper":
		if slot == "aanval":
			return _creak(140, 0.22, 0.18)
		if slot == "raak":
			return _mix(_creak(220, 0.08, 0.05), _scale(_clang(400, 0.08), 0.3))
		if slot == "dood":
			return _creak(100, 0.45, 0.25)
		return _creak(90, 0.36, 0.3)
	if actor_id == "mistuil":
		if slot == "aanval":
			return _mix(_hoot(480, 520, 0.18, seed), _scale(_whoosh(0.14, seed, 1600), 0.35))
		if slot == "raak":
			return _hoot(760, 640, 0.14, seed)
		if slot == "dood":
			return _hoot(540, 180, 0.5, seed)
		return _hoot(500, 1100, 0.34, seed)
	if actor_id == "sporenzwam":
		if slot == "aanval":
			return _puff(0.16, seed, 350)
		if slot == "raak":
			return _bubbles(seed, 1, 260)
		if slot == "dood":
			return _puff(0.5, seed, 160)
		return _mix(_puff(0.14, seed, 400), _delay(_puff(0.16, seed + 3, 280), 0.1), _delay(_puff(0.18, seed + 7, 200), 0.2))
	if actor_id == "wortelkoning":
		if slot == "aanval":
			return _mix(_creak(48, 0.34, 0.12), _clang(40, 0.4))
		if slot == "raak":
			return _mix(_clang(55, 0.28), _scale(_creak(70, 0.2, 0.08), 0.5))
		if slot == "dood":
			return _mix(_creak(36, 0.7, 0.15), _puff(0.7, seed, 90), _delay(_clang(30, 0.5), 0.2))
		return _mix(_creak(42, 0.5, 0.22), _clang(36, 0.45))
	if actor_id == "mimic":
		if slot == "aanval":
			return _mix(_creak(180, 0.14, 0.1), _delay(_clang(140, 0.12), 0.1))
		if slot == "raak":
			return _clang(200, 0.1)
		if slot == "dood":
			return _mix(_clang(90, 0.3), _delay(_creak(80, 0.3, 0.05), 0.05))
		return _mix(_clang(120, 0.1), _delay(_clang(80, 0.16), 0.06), _scale(_noise(0.05, seed), 0.25))
	if actor_id == "inktwurm":
		if slot == "aanval":
			return _mix(_puff(0.18, seed, 140), _scale(_bubbles(seed, 3, 90), 0.55))
		if slot == "raak":
			return _bubbles(seed, 2, 160)
		if slot == "dood":
			return _mix(_puff(0.5, seed, 80), _delay(_bubbles(seed, 4, 70), 0.12))
		return _mix(_bubbles(seed, 5, 110), _scale(_puff(0.22, seed, 200), 0.4))
	if actor_id == "lotte_glitch":
		if slot == "aanval":
			return _mix(_glitch(0.16, seed, 420), _scale(_shimmer(520, 780, 0.12), 0.35))
		if slot == "raak":
			return _glitch(0.1, seed, 300)
		if slot == "dood":
			return _mix(_glitch(0.4, seed, 180), _delay(_tone(220, 0.3, "sine", 0.4), 0.05))
		return _mix(_shimmer(400, 900, 0.28), _scale(_glitch(0.2, seed, 600), 0.4))
	if actor_id == "wurger":
		if slot == "aanval":
			return _mix(_creak(70, 0.28, 0.2), _whoosh(0.16, seed, 500))
		if slot == "raak":
			return _creak(90, 0.16, 0.08)
		if slot == "dood":
			return _mix(_creak(40, 0.6, 0.15), _puff(0.4, seed, 120))
		return _mix(_creak(55, 0.4, 0.25), _delay(_creak(80, 0.2, 0.1), 0.12))
	if actor_id == "genezer":
		if slot == "aanval":
			return _mix(_clang(180, 0.16), _scale(_puff(0.18, seed, 240), 0.45))
		if slot == "raak":
			return _clang(240, 0.1)
		if slot == "dood":
			return _mix(_clang(90, 0.35), _delay(_puff(0.4, seed, 100), 0.08))
		return _mix(_shimmer(300, 520, 0.3), _scale(_clang(140, 0.2), 0.4))
	if actor_id == "woudgeest":
		# Wind: korte vlaag, dunne tik, wegvallende zucht, langere vlaag.
		if slot == "aanval":
			return _whoosh(0.16, seed, 900)
		if slot == "raak":
			return _mix(_scale(_whoosh(0.05, seed, 2800), 0.45), _clang(1600, 0.05))
		if slot == "dood":
			return _whoosh(0.48, seed, 280)
		return _whoosh(0.34, seed, 640)
	raise SystemExit("Geen recept voor %s/%s" % (actor_id, slot))


def _stable_seed(actor_id: str, slot: str) -> int:
	value = 2166136261
	for ch in ("%s:%s" % (actor_id, slot)).encode():
		value ^= ch
		value = (value * 16777619) & 0xFFFFFFFF
	return value


def _write_wav(path: str, samples: list[float]) -> None:
	os.makedirs(os.path.dirname(path), exist_ok=True)
	peak = max((abs(s) for s in samples), default=0.0) or 1.0
	samples = [s / peak * 0.82 for s in samples]
	rms = math.sqrt(sum(s * s for s in samples) / len(samples))
	if rms < 0.02:
		raise SystemExit("%s klinkt leeg (rms %.3f)" % (path, rms))
	frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767.0)))) for s in samples)
	with wave.open(path, "w") as handle:
		handle.setnchannels(1)
		handle.setsampwidth(2)
		handle.setframerate(SR)
		handle.writeframes(frames)


def _leesmij(folder: str, naam: str, stem: str, slots: dict) -> None:
	os.makedirs(folder, exist_ok=True)
	lines = [
		"# %s — placeholder-sfx" % naam,
		"",
		"Synthetische placeholders uit `tools/gen_actor_sfx.py`. Geen definitief geluid.",
		"Vervang het wav-bestand en houd de bestandsnaam. Daarna de regel in",
		"`tools/placeholders_sfx.txt` weghalen.",
		"",
		stem,
		"",
	]
	for slot in SLOTS:
		lines.append("- `%s.wav` — %s" % (slot, slots[slot]))
	lines.append("")
	with open(os.path.join(folder, "LEESMIJ.md"), "w", encoding="utf-8") as handle:
		handle.write("\n".join(lines))


def main() -> None:
	with open(CATALOG, encoding="utf-8") as handle:
		catalog = json.load(handle)
	if list(catalog["slots"]) != list(SLOTS):
		raise SystemExit("slots in de catalogus wijken af van het script")
	written: list[str] = []
	hashes: dict[bytes, str] = {}
	for soort in ("helden", "monsters"):
		for actor_id, entry in catalog[soort].items():
			folder = os.path.join(SFX_ROOT, soort, actor_id)
			_leesmij(folder, entry["naam"], entry["stem"], entry["slots"])
			for slot in SLOTS:
				if slot not in entry["slots"]:
					raise SystemExit("%s/%s mist slot %s" % (soort, actor_id, slot))
				samples = render(actor_id, slot)
				rel = os.path.join("assets", "audio", "sfx", soort, actor_id, slot + ".wav")
				path = os.path.join(ROOT, rel)
				_write_wav(path, samples)
				blob = open(path, "rb").read()
				if blob in hashes:
					raise SystemExit("%s is identiek aan %s" % (rel, hashes[blob]))
				hashes[blob] = rel
				written.append(rel.replace(os.sep, "/"))
	lines = [
		"# PLACEHOLDER-SFX (tools/gen_actor_sfx.py). Synthetisch, geen definitief geluid.",
		"# Vervang het wav-bestand (zelfde naam) en haal de regel hier weg.",
		"# Mappen: assets/audio/sfx/helden/<id>/ en assets/audio/sfx/monsters/<id>/.",
		"# Slots: aanval, raak, dood, vaardigheid. Catalogus: assets/audio/actor_sfx.json.",
	]
	for rel in written:
		lines.append(rel)
	with open(PLACEHOLDER_LIST, "w", encoding="utf-8") as handle:
		handle.write("\n".join(lines) + "\n")
	print("geschreven: %d wavs" % len(written))


def write_only(ids: list[str], soort: str = "monsters") -> None:
	"""Schrijf alleen deze monster-wavs. main() herschrijft alles; die niet aanroepen."""
	with open(CATALOG, encoding="utf-8") as handle:
		catalog = json.load(handle)
	hashes: dict[bytes, str] = {}
	for dirpath, _dirs, files in os.walk(SFX_ROOT):
		for name in files:
			if not name.endswith(".wav"):
				continue
			path = os.path.join(dirpath, name)
			blob = open(path, "rb").read()
			hashes[blob] = path
	written = []
	for actor_id in ids:
		entry = catalog[soort][actor_id]
		folder = os.path.join(SFX_ROOT, soort, actor_id)
		_leesmij(folder, entry["naam"], entry["stem"], entry["slots"])
		for slot in SLOTS:
			samples = render(actor_id, slot)
			rel = "assets/audio/sfx/%s/%s/%s.wav" % (soort, actor_id, slot)
			path = os.path.join(ROOT, rel)
			_write_wav(path, samples)
			blob = open(path, "rb").read()
			if blob in hashes and hashes[blob] != path:
				raise SystemExit("%s is identiek aan %s" % (rel, hashes[blob]))
			hashes[blob] = path
			written.append(rel)
	have = set()
	if os.path.isfile(PLACEHOLDER_LIST):
		for line in open(PLACEHOLDER_LIST, encoding="utf-8"):
			part = line.split()
			if part:
				have.add(part[0])
	with open(PLACEHOLDER_LIST, "a", encoding="utf-8") as handle:
		for rel in written:
			if rel not in have:
				handle.write(rel + "\n")
	print("alleen geschreven: %d" % len(written))


if __name__ == "__main__":
	import sys
	if len(sys.argv) > 2 and sys.argv[1] == "--alleen-helden":
		write_only(sys.argv[2:], "helden")
	elif len(sys.argv) > 1 and sys.argv[1] == "--alleen":
		write_only(sys.argv[2:])
	else:
		main()
