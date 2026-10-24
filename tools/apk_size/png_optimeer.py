#!/usr/bin/env python3
"""Verliesvrije PNG-optimalisatie (oxipng) met pixel-verificatie.

- Slaat alles uit `tools/handwerk.txt` over (handgetekende art: nooit aanraken).
- Schrijft een bestand alleen terug als het kleiner wordt EN de gedecodeerde RGBA-pixels
  byte-voor-byte gelijk zijn (plus gelijke afmetingen). Anders blijft het origineel staan.
- Verandert niets aan de pixels: alleen compressie/filters/metadata-chunks (safe strip). Kleurtype
  en bitdiepte blijven gelijk (geen RGBA->RGB/palet): anders ziet Godot een ander bronformaat
  en schrijft het een andere .ctex-header (zelfde beeld, andere bytes).

Let op: voor de APK maakt dit GEEN verschil. Godot importeert PNG's naar .ctex (lossless) in
`.godot/imported/`; de bron-PNG zit niet in de APK. Het scheelt alleen repo-grootte.

Gebruik:  python3 tools/apk_size/png_optimeer.py [--root DIR] [--dry-run] [--level 4]
Vereist: pip install pyoxipng pillow
"""
import argparse
import io
import os
import sys

import oxipng
from PIL import Image


def handwerk(root: str) -> set:
    pad = os.path.join(root, "tools", "handwerk.txt")
    uit = set()
    if os.path.exists(pad):
        for regel in open(pad, encoding="utf-8"):
            r = regel.strip()
            if r and not r.startswith("#"):
                uit.add(r.replace("\\", "/"))
    return uit


def pixels(data: bytes) -> tuple:
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    return im.size, im.tobytes()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.join(os.path.dirname(__file__), "..", ".."))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--level", type=int, default=4)
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    skip = handwerk(root)
    n = n_kleiner = n_handwerk = n_fout = 0
    voor_tot = na_tot = 0
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in (".git", ".godot", "wacht", "docs", "tools")]
        for fn in fns:
            if not fn.lower().endswith(".png"):
                continue
            vol = os.path.join(dp, fn)
            rel = os.path.relpath(vol, root).replace(os.sep, "/")
            if rel in skip:
                n_handwerk += 1
                continue
            n += 1
            data = open(vol, "rb").read()
            nieuw = oxipng.optimize_from_memory(
                data, level=a.level, strip=oxipng.StripChunks.safe(),
                bit_depth_reduction=False, color_type_reduction=False,
                palette_reduction=False, grayscale_reduction=False)
            voor_tot += len(data)
            if len(nieuw) >= len(data):
                na_tot += len(data)
                continue
            if pixels(data) != pixels(nieuw):
                print("FAIL pixels verschillen, overgeslagen:", rel)
                n_fout += 1
                na_tot += len(data)
                continue
            na_tot += len(nieuw)
            n_kleiner += 1
            if not a.dry_run:
                with open(vol, "wb") as f:
                    f.write(nieuw)
    print(f"PNG's gecontroleerd: {n}, kleiner: {n_kleiner}, handwerk overgeslagen: {n_handwerk}, pixelfouten: {n_fout}")
    print(f"bytes {voor_tot} -> {na_tot} ({(voor_tot - na_tot)} bytes minder)")
    return 1 if n_fout else 0


if __name__ == "__main__":
    sys.exit(main())
