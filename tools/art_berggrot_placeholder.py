#!/usr/bin/env python3
"""PLACEHOLDER voor de berggrot naar het Levende Archief.

Koud steenblauw over de grijze archief-atlassen, plus grove vijand- en
kaartplaatjes. Magenta hoekjes en het woord PLACEHOLDER. Geen definitieve art.
Een pad in tools/handwerk.txt wordt nooit overschreven.

  assets/tiles/dungeon/berggrot_tiles.png            256x80
  assets/tiles/dungeon/berggrot_bibliotheek.png      256x64
  assets/sprites/enemies/steenluis.png               90x90
  assets/sprites/enemies/steenluis_rug.png           90x90
  assets/sprites/enemies/druipslak.png               90x90
  assets/sprites/enemies/druipslak_rug.png           90x90
  assets/sprites/enemies/adermot.png                 90x90
  assets/sprites/enemies/adermot_rug.png             90x90
  assets/map_monsters/steenluis.png                  32x64
  assets/map_monsters/druipslak.png                  32x64
  assets/map_monsters/adermot.png                    32x64

Gebruik:  python3 tools/art_berggrot_placeholder.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")
MAGENTA = (255, 30, 230, 255)

ATLAS = {
    "assets/tiles/dungeon/berggrot_tiles.png": (
        "assets/tiles/dungeon/archief_grijs_tiles.png",
        (256, 80),
    ),
    "assets/tiles/dungeon/berggrot_bibliotheek.png": (
        "assets/tiles/dungeon/archief_grijs_bibliotheek.png",
        (256, 64),
    ),
}

# id, vulkleur, vlek
ENEMIES = (
    ("steenluis", (120, 128, 142, 255), (70, 78, 96, 255)),
    ("druipslak", (64, 110, 130, 255), (150, 190, 200, 255)),
    ("adermot", (150, 130, 70, 255), (40, 48, 70, 255)),
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


def _stone(src: Image.Image) -> Image.Image:
    im = src.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (
                int(r * 0.55 + 28),
                int(g * 0.62 + 36),
                min(255, int(b * 0.55 + 70)),
                a,
            )
    _stamp(im)
    return im


def _label(im: Image.Image, text: str) -> None:
    draw = ImageDraw.Draw(im)
    font = ImageFont.load_default()
    draw.text((4, im.size[1] - 14), text, fill=(255, 244, 220, 255), font=font)


def _enemy(kleur, vlek, rug: bool) -> Image.Image:
    im = Image.new("RGBA", (90, 90), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    draw.ellipse((18, 22, 72, 78), fill=kleur)
    draw.rectangle((30, 34, 60, 52), fill=vlek)
    if rug:
        draw.line((24, 30, 66, 70), fill=MAGENTA)
        draw.line((66, 30, 24, 70), fill=MAGENTA)
    else:
        draw.ellipse((34, 40, 42, 48), fill=(20, 16, 28, 255))
        draw.ellipse((50, 40, 58, 48), fill=(20, 16, 28, 255))
    _stamp(im)
    _label(im, "PLACEHOLDER")
    return im


def _map(kleur) -> Image.Image:
    im = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    for row in range(4):
        for col in range(2):
            x = col * 16
            y = row * 16
            draw.ellipse((x + 3, y + 2, x + 12, y + 13), fill=kleur)
    _stamp(im)
    return im


def main() -> None:
    for rel, (src_rel, size) in ATLAS.items():
        _refuse(rel)
        src = Image.open(os.path.join(ROOT, src_rel))
        if src.size != size:
            raise SystemExit("bronmaat klopt niet: %s %s" % (src_rel, src.size))
        out = _stone(src)
        dest = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        out.save(dest)
        print(rel, out.size)
    for eid, kleur, vlek in ENEMIES:
        for rug in (False, True):
            naam = eid + ("_rug" if rug else "")
            rel = "assets/sprites/enemies/%s.png" % naam
            _refuse(rel)
            im = _enemy(kleur, vlek, rug)
            dest = os.path.join(ROOT, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            im.save(dest)
            print(rel, im.size)
        rel_map = "assets/map_monsters/%s.png" % eid
        _refuse(rel_map)
        mp = _map(kleur)
        dest_map = os.path.join(ROOT, rel_map)
        os.makedirs(os.path.dirname(dest_map), exist_ok=True)
        mp.save(dest_map)
        print(rel_map, mp.size)


if __name__ == "__main__":
    main()
