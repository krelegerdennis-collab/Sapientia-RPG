#!/usr/bin/env python3
"""Placeholder-art voor het puzzelsysteem (De Vergeten Archieven).

ALLEEN EEN TERUGVAL: RPG ART heeft de echte art geleverd (art_puzzle_v11/out, nu in
assets/puzzle/). Dit script schrijft standaard alleen bestanden die nog ONTBREKEN in
assets/puzzle/. Met --force overschrijft het alles, met --out=map schrijft het ergens anders.

Formaat (alle frames 16x16, horizontale strook, transparant):
  hendel.png       32x16  frame 0 = uit, 1 = aan
  drukplaat.png    32x16  frame 0 = omhoog, 1 = ingedrukt
  poort.png        64x16  frame 0 = dicht .. 3 = open (achtergrond transparant)
  herstelsteen.png 32x16  2 gloei-frames (magenta)
  kast_duwbaar.png 16x32  duwbare boekenkast (bovenste helft steekt boven de tile uit)
Gebruik:  python3 tools/art_puzzle_placeholders.py [--force] [--out=pad]
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "puzzle")
FORCE = "--force" in sys.argv
for a in sys.argv[1:]:
    if a.startswith("--out="):
        OUT = a.split("=", 1)[1]

# Ruw het projectpalet: dark academia (hout, steen, perkament) + neon accenten.
STONE_D = (38, 36, 44, 255)
STONE = (74, 72, 82, 255)
STONE_L = (112, 110, 120, 255)
WOOD_D = (52, 32, 24, 255)
WOOD = (96, 62, 40, 255)
BRASS = (176, 132, 64, 255)
IRON = (58, 60, 68, 255)
IRON_L = (120, 124, 134, 255)
RED = (176, 48, 56, 255)
CYAN = (25, 236, 246, 255)
CYAN_D = (8, 112, 122, 255)
MAGENTA = (255, 30, 230, 255)
MAGENTA_D = (138, 12, 132, 255)
DARK = (11, 10, 16, 255)


def save(img, name):
    path = os.path.join(OUT, name)
    if os.path.exists(path) and not FORCE:
        print("bestaat al (overgeslagen):", path)
        return
    os.makedirs(OUT, exist_ok=True)
    img.save(path)
    print("geschreven:", path)


def hendel():
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for f in range(2):
        ox = f * 16
        d.rectangle([ox + 4, 11, ox + 11, 14], fill=STONE_D, outline=STONE)
        if f == 0:   # uit: hendel naar links, rode knop
            d.line([ox + 8, 11, ox + 4, 4], fill=IRON_L)
            d.rectangle([ox + 3, 2, ox + 5, 4], fill=RED)
        else:        # aan: hendel naar rechts, cyaan knop + rune
            d.line([ox + 8, 11, ox + 12, 4], fill=IRON_L)
            d.rectangle([ox + 11, 2, ox + 13, 4], fill=CYAN)
            d.point([ox + 7, 13], fill=CYAN)
            d.point([ox + 8, 13], fill=CYAN)
    return img


def drukplaat():
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for f in range(2):
        ox = f * 16
        if f == 0:
            d.rectangle([ox + 2, 2, ox + 13, 13], fill=STONE_L, outline=STONE_D)
            d.rectangle([ox + 3, 12, ox + 13, 13], fill=STONE)
        else:
            d.rectangle([ox + 2, 3, ox + 13, 13], fill=STONE, outline=STONE_D)
            d.line([ox + 7, 5, ox + 4, 8], fill=CYAN)
            d.line([ox + 4, 8, ox + 7, 11], fill=CYAN)
            d.line([ox + 8, 5, ox + 11, 8], fill=CYAN)
            d.line([ox + 11, 8, ox + 8, 11], fill=CYAN)
    return img


def poort():
    img = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for f in range(4):
        ox = f * 16
        d.rectangle([ox, 0, ox + 15, 1], fill=IRON)        # bovenbalk
        lift = f * 4                                           # hek schuift omhoog
        bottom = 15 - lift
        if bottom > 2:
            for x in (2, 5, 8, 11, 14):
                d.line([ox + x, 2, ox + x, bottom], fill=IRON_L)
            d.line([ox + 1, max(2, bottom - 1), ox + 14, max(2, bottom - 1)], fill=IRON)
        d.point([ox + 8, 0], fill=MAGENTA)
    return img


def herstelsteen():
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for f in range(2):
        ox = f * 16
        d.rectangle([ox + 3, 3, ox + 12, 14], fill=STONE, outline=STONE_D)
        c = MAGENTA if f == 1 else MAGENTA_D
        d.arc([ox + 5, 5, ox + 10, 11], 30, 330, fill=c)
        d.point([ox + 10, 6], fill=c)
        if f == 1:
            d.point([ox + 2, 2], fill=MAGENTA)
            d.point([ox + 13, 4], fill=MAGENTA)
    return img


def kast():
    img = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 2, 14, 30], fill=WOOD, outline=WOOD_D)
    cols = [RED, (60, 90, 140, 255), (70, 120, 70, 255), BRASS]
    for row, y in enumerate((4, 11, 18)):
        d.line([2, y + 6, 13, y + 6], fill=WOOD_D)
        for i in range(10):
            d.line([3 + i, y, 3 + i, y + 5], fill=cols[(i + row) % 4])
    for (x, y) in ((1, 2), (14, 2), (1, 30), (14, 30)):
        d.point([x, y], fill=BRASS)
    d.point([7, 28], fill=CYAN)
    d.point([8, 28], fill=CYAN)
    d.point([2, 31], fill=WOOD_D)
    d.point([13, 31], fill=WOOD_D)
    return img


if __name__ == "__main__":
    save(hendel(), "hendel.png")
    save(drukplaat(), "drukplaat.png")
    save(poort(), "poort.png")
    save(herstelsteen(), "herstelsteen.png")
    save(kast(), "kast_duwbaar.png")
