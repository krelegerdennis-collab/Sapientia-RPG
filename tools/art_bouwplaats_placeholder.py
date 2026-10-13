#!/usr/bin/env python3
"""PLACEHOLDER-props voor de bouwplaats voor de berggrot-tunnel (worldmap 1, tegel 21,17).

Grove vormen, magenta hoekjes = placeholder. Geen definitieve art.
Een pad in tools/handwerk.txt wordt nooit overschreven.

  assets/sprites/buiten/bouw_hek.png         32x16  afzetting (rood-wit), 2 tegels breed
  assets/sprites/buiten/bouw_karretje.png    16x16  mijnkarretje met stenen
  assets/sprites/buiten/bouw_gereedschap.png 16x16  houweel en schep tegen een kist
  assets/sprites/buiten/bouw_balken.png      16x16  stapel stutbalken

Gebruik:  python3 tools/art_bouwplaats_placeholder.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")
MAGENTA = (255, 30, 230, 255)
HOUT = (0x6B, 0x45, 0x2A, 255)
HOUT_D = (0x45, 0x2C, 0x1B, 255)
IJZER = (0x5A, 0x5E, 0x66, 255)
STEEN = (0x7A, 0x74, 0x70, 255)
ROOD = (0xB8, 0x32, 0x2E, 255)
WIT = (0xE8, 0xE2, 0xD4, 255)


def handwerk() -> set:
    if not os.path.exists(HANDWERK):
        return set()
    with open(HANDWERK, encoding="utf-8") as f:
        return {r.split()[0] for r in f if r.strip() and not r.startswith("#")}


def hoekjes(img):
    w, h = img.size
    for p in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        img.putpixel(p, MAGENTA)


def hek():
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 6, 3, 15], fill=HOUT_D)
    d.rectangle([28, 6, 29, 15], fill=HOUT_D)
    for x in range(1, 31):
        d.line([x, 5, x, 9], fill=ROOD if (x // 4) % 2 == 0 else WIT)
    return img


def karretje():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([3, 5, 12, 9], fill=STEEN)
    d.polygon([(1, 7), (14, 7), (12, 13), (3, 13)], fill=IJZER)
    d.ellipse([3, 12, 6, 15], fill=HOUT_D)
    d.ellipse([9, 12, 12, 15], fill=HOUT_D)
    return img


def gereedschap():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 9, 13, 15], fill=HOUT)
    d.line([4, 1, 9, 10], fill=HOUT_D, width=1)
    d.line([2, 2, 7, 0], fill=IJZER, width=2)
    d.line([12, 1, 11, 9], fill=HOUT_D)
    d.rectangle([10, 0, 13, 3], fill=IJZER)
    return img


def balken():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, y in enumerate([12, 9, 6]):
        d.rectangle([1 + i, y, 14 - i, y + 2], fill=HOUT if i % 2 == 0 else HOUT_D)
    return img


def main() -> None:
    hw = handwerk()
    for pad, maak in [("assets/sprites/buiten/bouw_hek.png", hek), ("assets/sprites/buiten/bouw_karretje.png", karretje),
                      ("assets/sprites/buiten/bouw_gereedschap.png", gereedschap), ("assets/sprites/buiten/bouw_balken.png", balken)]:
        if pad in hw:
            print("overgeslagen (handwerk):", pad)
            continue
        img = maak()
        hoekjes(img)
        img.save(os.path.join(ROOT, pad))
        print("geschreven:", pad)


if __name__ == "__main__":
    main()
