#!/usr/bin/env python3
"""Lore-notitie op de vloer van een Empty Room in de Diepe Grot (Dungeon100).

Maakt assets/sprites/dungeon/grot_notitie.png (16x16): een los, verfrommeld blaadje met
inktregels en een kleine magenta vlek, in het 64-kleurenpalet (tools/art_v7_common.py).
Een bestand in tools/handwerk.txt wordt nooit overschreven.
Gebruik:  python3 tools/art_grot_notitie.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from art_v7_common import PAGE, PARCHMENT, CHARCOAL, MAGENTA_DIM  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = "assets/sprites/dungeon/grot_notitie.png"
OUT = os.path.join(ROOT, REL)
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")


def rgba(c):
    return tuple(c[:3]) + (255,)


def build() -> Image.Image:
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    shadow = rgba(CHARCOAL[1])
    # schaduw onder het blaadje
    for x in range(4, 14):
        px[x, 13] = shadow
    # blaadje (scheef: rechtsboven een omgevouwen hoek)
    for y in range(4, 13):
        for x in range(3, 13):
            px[x, y] = rgba(PAGE[3])
    for y in range(4, 13):
        px[3, y] = rgba(PAGE[2])
        px[12, y] = rgba(PARCHMENT[3])
    for x in range(3, 13):
        px[x, 12] = rgba(PARCHMENT[3])
        px[x, 4] = rgba(PAGE[4])
    # omgevouwen hoek
    px[12, 4] = (0, 0, 0, 0)
    px[11, 4] = rgba(PARCHMENT[2])
    px[12, 5] = rgba(PARCHMENT[2])
    px[11, 5] = rgba(PARCHMENT[4])
    # inktregels
    ink = rgba(CHARCOAL[3])
    for y, (a, b) in zip((6, 8, 10), ((5, 10), (5, 11), (5, 8))):
        for x in range(a, b):
            px[x, y] = ink
    # vlekje
    px[10, 10] = rgba(MAGENTA_DIM)
    return im


def main() -> None:
    if os.path.exists(HANDWERK) and REL in open(HANDWERK, encoding="utf-8").read():
        print("overgeslagen (handwerk):", REL)
        return
    build().save(OUT)
    print("geschreven:", REL)


if __name__ == "__main__":
    main()
