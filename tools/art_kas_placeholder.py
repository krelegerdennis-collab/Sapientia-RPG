#!/usr/bin/env python3
"""PLACEHOLDER voor verdieping 1 van Het Levende Archief (overwoekerde kas).

Groen-getinte kopie van de grijze archief-atlassen, plus een groei-plaat in drie
stadia en een wereldkaart-icoon. Magenta hoekjes (2x2) op elke tegel: dit is geen
definitieve art. Een pad in tools/handwerk.txt wordt nooit overschreven.

  assets/tiles/dungeon/kas_tiles.png            256x80
  assets/tiles/dungeon/kas_bibliotheek.png      256x64
  assets/puzzle/groei_plaat.png                 48x16   (zaad, scheut, volgroeid)
  assets/sprites/buiten/kas_ingang.png          16x16

Gebruik:  python3 tools/art_kas_placeholder.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")
MAGENTA = (255, 30, 230, 255)
INK = (24, 36, 28, 255)
SOIL = (92, 64, 40, 255)
LEAF = (46, 150, 62, 255)
LEAF_DARK = (22, 96, 48, 255)
SPROUT = (120, 200, 80, 255)
GLASS = (150, 210, 170, 255)

OUTS = {
    "assets/tiles/dungeon/kas_tiles.png": (
        "assets/tiles/dungeon/archief_grijs_tiles.png",
        (256, 80),
    ),
    "assets/tiles/dungeon/kas_bibliotheek.png": (
        "assets/tiles/dungeon/archief_grijs_bibliotheek.png",
        (256, 64),
    ),
}


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
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1),
                           (14, 0), (15, 0), (14, 1), (15, 1),
                           (0, 14), (1, 14), (0, 15), (1, 15),
                           (14, 14), (15, 14), (14, 15), (15, 15)):
                px[tx + dx, ty + dy] = MAGENTA


def _greenify(src: Image.Image) -> Image.Image:
    im = src.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (
                int(r * 0.45),
                min(255, int(g * 0.75 + 78)),
                int(b * 0.55),
                a,
            )
    _stamp(im)
    return im


def _frame(draw: ImageDraw.ImageDraw, x0: int) -> None:
    draw.rectangle([x0 + 2, 10, x0 + 13, 14], fill=SOIL, outline=INK)
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1),
                   (14, 0), (15, 0), (14, 1), (15, 1),
                   (0, 14), (1, 14), (0, 15), (1, 15),
                   (14, 14), (15, 14), (14, 15), (15, 15)):
        draw.point((x0 + dx, dy), fill=MAGENTA)


def _grow() -> Image.Image:
    im = Image.new("RGBA", (48, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    _frame(d, 0)
    d.ellipse([6, 8, 9, 11], fill=SPROUT, outline=INK)
    _frame(d, 16)
    d.line([(23, 12), (23, 5)], fill=LEAF_DARK, width=1)
    d.ellipse([20, 3, 26, 8], fill=SPROUT, outline=INK)
    _frame(d, 32)
    d.rectangle([34, 6, 45, 13], fill=LEAF, outline=INK)
    d.polygon([(34, 8), (40, 2), (45, 8)], fill=LEAF_DARK, outline=INK)
    d.ellipse([37, 8, 42, 13], fill=SPROUT, outline=INK)
    return im


def _icon() -> Image.Image:
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([2, 7, 13, 14], fill=GLASS, outline=INK)
    d.polygon([(1, 7), (8, 2), (14, 7)], fill=LEAF, outline=INK)
    d.line([(8, 7), (8, 14)], fill=INK)
    d.line([(2, 10), (13, 10)], fill=INK)
    _stamp(im)
    return im


def main() -> None:
    for rel, (src_rel, size) in OUTS.items():
        _refuse(rel)
        src = Image.open(os.path.join(ROOT, src_rel))
        im = _greenify(src)
        if im.size != size:
            raise SystemExit("%s is %s, verwacht %s" % (rel, im.size, size))
        dest = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        im.save(dest)
        print(rel, im.size)
    for rel, im in (
        ("assets/puzzle/groei_plaat.png", _grow()),
        ("assets/sprites/buiten/kas_ingang.png", _icon()),
    ):
        _refuse(rel)
        dest = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        im.save(dest)
        print(rel, im.size)


if __name__ == "__main__":
    main()
