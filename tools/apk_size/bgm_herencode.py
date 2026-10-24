#!/usr/bin/env python3
"""Herencodeer de BGM-oggs naar Ogg Vorbis (libvorbis, -q:a 3) zonder de loop te verschuiven.

Waarom: de muziek is ~43 MiB van de APK. Vijf bestanden bevatten een Theora-coverbeeld
(1500x692) dat de game nooit gebruikt, en de bitrates (120/160 kbps) liggen boven wat
telefoonspeakers/oordopjes nodig hebben.

Veiligheid:
- Het aantal gedecodeerde samples moet EXACT gelijk blijven (loop-punten, "staart in de kop
  gemengd" blijft naadloos). Zo niet: bestand blijft ongemoeid en het script faalt.
- Idempotent: bestanden die al <= 115 kbps zijn en geen videostream hebben worden overgeslagen
  (nooit twee keer generatieverlies).
- Bestandsnamen en .import-bestanden blijven gelijk; manifest en tests hoeven niet aan.

Gebruik:  python3 tools/apk_size/bgm_herencode.py [--q 3] [--dry-run]
Vereist: ffmpeg met libvorbis, ffprobe.
"""
import argparse
import glob
import os
import subprocess
import sys
import tempfile

BGM_MAP = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "bgm")
DREMPEL_BPS = 115000


def probe(pad: str) -> dict:
    uit = subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "stream=codec_type,codec_name:format=bit_rate,duration",
         "-of", "json", pad], text=True)
    import json
    d = json.loads(uit)
    types = [s["codec_type"] for s in d["streams"]]
    return {"video": "video" in types, "bps": int(d["format"].get("bit_rate", 0)), "streams": types}


def aantal_samples(pad: str) -> int:
    """Telt de gedecodeerde PCM-bytes (s16le) van de audiostream."""
    p = subprocess.run(["ffmpeg", "-v", "error", "-i", pad, "-map", "0:a", "-f", "s16le", "-"],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True)
    return len(p.stdout)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--q", default="3")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    fout = 0
    totaal_voor = totaal_na = 0
    for pad in sorted(glob.glob(os.path.join(BGM_MAP, "*.ogg"))):
        info = probe(pad)
        voor = os.path.getsize(pad)
        totaal_voor += voor
        if not info["video"] and info["bps"] <= DREMPEL_BPS:
            print(f"SKIP {os.path.basename(pad)} ({info['bps'] // 1000} kbps, geen video)")
            totaal_na += voor
            continue
        with tempfile.TemporaryDirectory() as tmp:
            uit = os.path.join(tmp, "uit.ogg")
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", pad, "-map", "0:a", "-map_metadata", "-1",
                            "-c:a", "libvorbis", "-q:a", a.q, uit], check=True)
            n_voor, n_na = aantal_samples(pad), aantal_samples(uit)
            ok = n_voor == n_na
            na = os.path.getsize(uit)
            print(f"{'OK  ' if ok else 'FAIL'} {os.path.basename(pad)}: {voor} -> {na} bytes, "
                  f"samples {n_voor // 4} -> {n_na // 4}")
            if not ok:
                fout += 1
                totaal_na += voor
                continue
            totaal_na += na
            if not a.dry_run:
                with open(uit, "rb") as f, open(pad, "wb") as g:
                    g.write(f.read())
    print(f"TOTAAL {totaal_voor} -> {totaal_na} bytes ({(totaal_voor - totaal_na) / 1048576:.2f} MiB minder)")
    return 1 if fout else 0


if __name__ == "__main__":
    sys.exit(main())
