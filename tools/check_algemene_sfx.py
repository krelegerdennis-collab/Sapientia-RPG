#!/usr/bin/env python3
"""Controleert de algemene placeholder-sfx uit het audio-manifest.

Elk sfx-bestand uit assets/audio/audio_manifest.json moet bestaan als plat wav
in assets/audio/sfx/: geldige header, mono, 16-bit, 22050 Hz, korte duur,
niet stil. Bestaande bgm en acteur-mappen (helden/, monsters/) blijven buiten
deze check.

Gebruik (vanuit de repo-root):
    python3 tools/check_algemene_sfx.py
"""

from __future__ import annotations

import array
import hashlib
import json
import math
import os
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "audio", "audio_manifest.json")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")

SR = 22050
MIN_DUR = 0.09
MAX_DUR = 0.60
MIN_RMS = 0.02

EXAMPLES = (
    "sfx_menu_click_01.wav",
    "sfx_footstep_stone_01.wav",
    "sfx_door_open_wood_01.wav",
    "sfx_sword_swing_01.wav",
    "sfx_spell_fire_01.wav",
    "sfx_enemy_growl_01.wav",
    "sfx_golem_roar_01.wav",
    "sfx_sapientia_awaken_01.wav",
)


def _fail(message: str, failures: list[str]) -> None:
    print("FAIL %s" % message)
    failures.append(message)


def _zcr(raw: bytes) -> float:
    pcm = array.array("h")
    pcm.frombytes(raw)
    if len(pcm) < 2:
        return 0.0
    crossings = 0
    prev = pcm[0]
    for sample in pcm[1:]:
        if (prev >= 0) != (sample >= 0):
            crossings += 1
        prev = sample
    return crossings / float(len(pcm) - 1)


def _rms(raw: bytes) -> float:
    pcm = array.array("h")
    pcm.frombytes(raw)
    if not pcm:
        return 0.0
    total = 0.0
    for sample in pcm:
        v = sample / 32767.0
        total += v * v
    return math.sqrt(total / len(pcm))


def main() -> None:
    failures: list[str] = []
    with open(MANIFEST, encoding="utf-8") as handle:
        data = json.load(handle)
    entries: list[tuple[str, str, str]] = []
    for key, entry in data["sfx"].items():
        cat = str(entry.get("categorie", ""))
        for filename in entry.get("bestanden", []):
            entries.append((cat, key, str(filename)))
    if not entries:
        _fail("manifest heeft geen sfx-bestanden", failures)

    blobs: dict[bytes, str] = {}
    stats: dict[str, list[tuple[float, float]]] = {}
    durations: dict[str, float] = {}
    for cat, key, filename in entries:
        if "/" in filename or "\\" in filename or not filename.endswith(".wav"):
            _fail("%s/%s geen plat wav: %s" % (cat, key, filename), failures)
            continue
        path = os.path.join(SFX_DIR, filename)
        if not os.path.isfile(path):
            _fail("%s ontbreekt" % filename, failures)
            continue
        try:
            with wave.open(path, "rb") as handle:
                channels = handle.getnchannels()
                width = handle.getsampwidth()
                rate = handle.getframerate()
                frames = handle.getnframes()
                raw = handle.readframes(frames)
                comptype = handle.getcomptype()
        except wave.Error as exc:
            _fail("%s ongeldige header (%s)" % (filename, exc), failures)
            continue
        dur = frames / float(rate) if rate else 0.0
        if width == 2 and len(raw) % 2 == 0:
            rms = _rms(raw)
            zcr = _zcr(raw)
        else:
            rms = 0.0
            zcr = 0.0
        problems: list[str] = []
        if channels != 1:
            problems.append("kanalen=%d" % channels)
        if width != 2:
            problems.append("breedte=%d" % width)
        if rate != SR:
            problems.append("rate=%d" % rate)
        if comptype != "NONE":
            problems.append("compressie=%s" % comptype)
        if frames <= 0:
            problems.append("leeg")
        if dur < MIN_DUR or dur > MAX_DUR:
            problems.append("duur=%.3fs" % dur)
        if rms < MIN_RMS:
            problems.append("rms=%.4f" % rms)
        with open(path, "rb") as handle:
            blob = handle.read()
        if not blob.startswith(b"RIFF") or b"WAVE" not in blob[:12]:
            problems.append("geen RIFF/WAVE")
        if blob in blobs:
            problems.append("identiek aan %s" % blobs[blob])
        else:
            blobs[blob] = filename
        import_path = path + ".import"
        if not os.path.isfile(import_path):
            problems.append("geen .import")
        else:
            text = open(import_path, encoding="utf-8").read()
            res_path = "res://assets/audio/sfx/" + filename
            digest = hashlib.md5(res_path.encode("utf-8")).hexdigest()
            if 'source_file="%s"' % res_path not in text:
                problems.append("import-bron")
            if digest not in text or 'importer="wav"' not in text:
                problems.append("import-vorm")
        if problems:
            _fail("%s %s" % (filename, ", ".join(problems)), failures)
        else:
            print("PASS %s %.3fs rms=%.3f mono 16-bit %dHz" % (filename, dur, rms, rate))
        stats.setdefault(cat, []).append((rms, zcr))
        durations[filename] = dur

    print("SAMENVATTING bestanden=%d categorieen=%d" % (len(entries), len(stats)))
    for cat in sorted(stats):
        values = stats[cat]
        n = len(values)
        mean_rms = sum(item[0] for item in values) / n
        mean_zcr = sum(item[1] for item in values) / n
        print("CATEGORIE %s n=%d rms-gem=%.3f nuldoorgangen=%.3f" % (cat, n, mean_rms, mean_zcr))
    for name in EXAMPLES:
        if name in durations:
            print("VOORBEELD %s %.3fs" % (name, durations[name]))
    if failures:
        print("RESULT FAIL (%d)" % len(failures))
        sys.exit(1)
    print("RESULT OK (%d)" % len(entries))


if __name__ == "__main__":
    main()
