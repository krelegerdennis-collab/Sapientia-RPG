#!/usr/bin/env python3
"""PLACEHOLDER voor de Mimic (Het Gesimuleerde Archief, zie HANDOFF_DUNGEON100_BLUECHEST.md).

Maakt assets/sprites/enemies/mimic.png (80x64): een kist met tanden en een tong, met magenta
hoekjes (zelfde conventie als tools/art_map_monsters.py). GEEN definitieve art: RPG ART tekent
de echte Mimic op dezelfde bestandsnaam en maat. Een bestand in tools/handwerk.txt wordt
nooit overschreven.
Gebruik:  python3 tools/art_mimic_placeholder.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "enemies", "mimic.png")
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")

INK = (18, 14, 20, 255)
WOOD = (122, 78, 46, 255)
WOOD_DARK = (84, 50, 30, 255)
GOLD = (214, 170, 72, 255)
MAGENTA = (255, 30, 230, 255)
TOOTH = (238, 232, 214, 255)
TONGUE = (196, 64, 92, 255)
MOUTH = (60, 16, 28, 255)
EYE = (255, 214, 64, 255)


def build() -> Image.Image:
    im = Image.new("RGBA", (80, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([6, 30, 73, 60], fill=WOOD, outline=INK)
    d.rectangle([6, 44, 73, 47], fill=WOOD_DARK)
    d.rectangle([34, 50, 45, 57], fill=GOLD, outline=INK)
    d.polygon([(6, 30), (73, 30), (66, 8), (13, 8)], fill=WOOD_DARK, outline=INK)
    d.rectangle([6, 28, 73, 34], fill=MOUTH, outline=INK)
    for x in range(10, 70, 9):
        d.polygon([(x, 29), (x + 6, 29), (x + 3, 38)], fill=TOOTH, outline=INK)
    for x in range(14, 66, 9):
        d.polygon([(x, 33), (x + 6, 33), (x + 3, 25)], fill=TOOTH, outline=INK)
    d.ellipse([30, 34, 50, 46], fill=TONGUE, outline=INK)
    d.ellipse([22, 14, 30, 22], fill=EYE, outline=INK)
    d.ellipse([50, 14, 58, 22], fill=EYE, outline=INK)
    d.rectangle([25, 16, 27, 20], fill=INK)
    d.rectangle([53, 16, 55, 20], fill=INK)
    for x, y in ((0, 0), (78, 0), (0, 62), (78, 62)):
        d.rectangle([x, y, x + 1, y + 1], fill=MAGENTA)
    return im


def main() -> None:
    rel = "assets/sprites/enemies/mimic.png"
    if os.path.exists(HANDWERK) and rel in open(HANDWERK, encoding="utf-8").read():
        print("mimic.png staat in handwerk.txt: niet overschreven")
        return
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    build().save(OUT)
    print("geschreven:", OUT)


if __name__ == "__main__":
    main()
