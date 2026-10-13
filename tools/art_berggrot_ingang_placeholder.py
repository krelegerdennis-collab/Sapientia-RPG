#!/usr/bin/env python3
"""PLACEHOLDER voor de grotmond van de berggrot op worldmap 1 (weg naar Archief 2).

Donkere boog in de bergwand, ruwe rand in grotrots-kleuren (ARTSTYLE 'grotrots').
Magenta hoekjes = placeholder. Geen definitieve art.
Een pad in tools/handwerk.txt wordt nooit overschreven.

  assets/sprites/buiten/berggrot_ingang.png   16x16

Gebruik:  python3 tools/art_berggrot_ingang_placeholder.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")
DOEL = "assets/sprites/buiten/berggrot_ingang.png"
MAGENTA = (255, 30, 230, 255)
ROTS = [(0x25, 0x1B, 0x1C, 255), (0x2F, 0x26, 0x2A, 255), (0x4A, 0x3D, 0x3E, 255)]
ZWART = (0x0B, 0x0A, 0x0A, 255)


def handwerk() -> set:
    if not os.path.exists(HANDWERK):
        return set()
    with open(HANDWERK, encoding="utf-8") as f:
        return {r.split()[0] for r in f if r.strip() and not r.startswith("#")}


def main() -> None:
    if DOEL in handwerk():
        print("overgeslagen (handwerk):", DOEL)
        return
    w, h = 16, 16
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cx = 7.5
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / 7.5
            dy = (h - 1 - y) / 15.0
            r = dx * dx + dy * dy
            if r <= 1.0:
                # buitenrand rots, binnen een donkere mond
                binnen = (dx / 0.68) ** 2 + (dy / 0.8) ** 2
                if binnen <= 1.0:
                    px[x, y] = ZWART
                else:
                    px[x, y] = ROTS[(x * 7 + y * 3) % 3]
    for x, y in [(0, h - 1), (w - 1, h - 1)]:
        px[x, y] = MAGENTA
    pad = os.path.join(ROOT, DOEL)
    img.save(pad)
    print("geschreven:", DOEL)


if __name__ == "__main__":
    main()
