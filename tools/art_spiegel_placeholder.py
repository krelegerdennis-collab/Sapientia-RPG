#!/usr/bin/env python3
"""PLACEHOLDER: kamer van De Spiegel (Archief 4).

Een kamer vol spiegelende vlakken, en dezelfde kamer nadat de spiegel breekt.
Magenta hoekjes (2x2 per tegel van 16) en het woord PLACEHOLDER. Geen definitieve art.
Een pad in tools/handwerk.txt wordt nooit overschreven.

  assets/bg/spiegel_kamer.png            384x216
  assets/bg/spiegel_kamer_gebroken.png   384x216

Gebruik:  python3 tools/art_spiegel_placeholder.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")
W, H = 384, 216
MAGENTA = (255, 30, 230, 255)
WALL = (36, 42, 58, 255)
FLOOR = (22, 24, 32, 255)
FRAME = (150, 160, 175, 255)
GLASS = (176, 208, 216, 255)
HIGH = (232, 246, 250, 255)
CRACK = (16, 12, 22, 255)
CRACK_EDGE = (236, 236, 242, 255)

# x, y, w, h — spiegelende vlakken in de kamer
SPIEGELS = (
    (12, 18, 64, 96),
    (88, 28, 48, 80),
    (148, 14, 72, 110),
    (232, 22, 40, 70),
    (284, 16, 84, 104),
    (40, 156, 96, 40),
    (188, 148, 132, 48),
)

OUTS = (
    "assets/bg/spiegel_kamer.png",
    "assets/bg/spiegel_kamer_gebroken.png",
)


def _handwerk() -> str:
    with open(HANDWERK, encoding="utf-8") as f:
        return f.read()


def _refuse(rel: str) -> None:
    if rel in _handwerk():
        raise SystemExit("handwerk, niet overschrijven: %s" % rel)


def _stamp(im: Image.Image) -> None:
    px = im.load()
    w, h = im.size
    for ty in range(0, h, 16):
        for tx in range(0, w, 16):
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                x, y = tx + dx, ty + dy
                if x < w and y < h:
                    px[x, y] = MAGENTA


def _spiegel(draw: ImageDraw.ImageDraw, rect: tuple) -> None:
    x, y, w, h = rect
    draw.rectangle((x, y, x + w - 1, y + h - 1), fill=FRAME)
    draw.rectangle((x + 2, y + 2, x + w - 3, y + h - 3), fill=GLASS)
    draw.line((x + 4, y + 4, x + 4, y + h - 8), fill=HIGH)
    draw.line((x + 4, y + 4, x + w // 3, y + 4), fill=HIGH)


def _scheuren(draw: ImageDraw.ImageDraw, rect: tuple) -> None:
    x, y, w, h = rect
    punten = [
        (x + 4, y + 3),
        (x + w // 3, y + h // 3),
        (x + w // 2, y + h // 2 + 4),
        (x + w - 5, y + h - 4),
    ]
    draw.line(punten, fill=CRACK, width=1)
    draw.line([(p[0] + 1, p[1]) for p in punten], fill=CRACK_EDGE)
    tak = (x + w // 2, y + h // 2 + 4)
    draw.line((tak, (x + w - 6, y + 8)), fill=CRACK)


def _kamer(gebroken: bool) -> Image.Image:
    im = Image.new("RGBA", (W, H), WALL)
    draw = ImageDraw.Draw(im)
    draw.rectangle((0, 150, W - 1, H - 1), fill=FLOOR)
    for rect in SPIEGELS:
        _spiegel(draw, rect)
        if gebroken:
            _scheuren(draw, rect)
    draw.text((128, 198), "PLACEHOLDER", fill=MAGENTA)
    _stamp(im)
    return im


def main() -> None:
    for rel in OUTS:
        _refuse(rel)
    os.makedirs(os.path.join(ROOT, "assets", "bg"), exist_ok=True)
    heel = _kamer(False)
    kapot = _kamer(True)
    heel.save(os.path.join(ROOT, OUTS[0]))
    kapot.save(os.path.join(ROOT, OUTS[1]))
    print("geschreven", OUTS[0], heel.size)
    print("geschreven", OUTS[1], kapot.size)


if __name__ == "__main__":
    main()
