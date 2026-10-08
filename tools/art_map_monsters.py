#!/usr/bin/env python3
"""v0.13 PLACEHOLDERS voor zichtbare map-monsters (dungeons, Lufia 2-stijl).

De echte art komt van RPG ART en staat in assets/map_monsters/<enemy_id>.png (in
tools/handwerk.txt). Voor elke vijand uit scripts/data/game_data.gd ZONDER eigen bestand maakt
dit script een duidelijk gemarkeerde placeholder: het gevechtsplaatje verkleind tot 16x16, met
magenta hoekjes (= 'nog geen echte art'). Bestaande bestanden worden NOOIT overschreven,
behalve met --force (en ook dan nooit iets uit tools/handwerk.txt).

Formaat (zelfde als mosslijm.png / moskonijn.png van RPG ART):
  32x64 = 2 kolommen (stap A, stap B) x 4 rijen (onder, links, rechts, boven), frames 16x16,
  voeten onderaan het frame. Echte art kan er zo overheen (zelfde bestandsnaam).
Gebruik:  python3 tools/art_map_monsters.py [--force]
"""
import os
import re
import sys
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "map_monsters")
FORCE = "--force" in sys.argv
MAGENTA = (255, 30, 230, 255)
OUTLINE = (22, 18, 26, 255)
FRAME = 16
INNER = 12          # verkleind plaatje past in 14x14 (1 px rand voor de hoekjes)


def handwerk():
    p = os.path.join(ROOT, "tools", "handwerk.txt")
    out = set()
    for line in open(p, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            out.add(line)
    return out


def enemies():
    """{id: res-pad van het gevechtsplaatje} uit game_data.gd (ENEMIES)."""
    src = open(os.path.join(ROOT, "scripts", "data", "game_data.gd"), encoding="utf-8").read()
    block = src[src.index("const ENEMIES"):]
    block = block[:block.index("\n}\n")]
    return dict(re.findall(r'"(\w+)":\s*\{\s*(?:#[^\n]*\n\s*)*"name":\s*"[^"]*",\s*"sprite":\s*"res://([^"]+)"', block))


def shrink(img):
    img = img.crop(img.getbbox())
    w, h = img.size
    k = INNER / max(w, h)
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    small = img.resize((nw, nh), Image.LANCZOS)
    # harde alfa (pixel-art), geen halfdoorzichtige randen
    px = small.load()
    for y in range(nh):
        for x in range(nw):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    return small


def frame(small, dy=0, mirror=False, dark=False):
    f = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    s = ImageOps.mirror(small) if mirror else small
    if dark:
        s = Image.eval(s, lambda v: v)  # kopie
        p = s.load()
        for y in range(s.height):
            for x in range(s.width):
                r, g, b, a = p[x, y]
                if a:
                    p[x, y] = (r * 7 // 10, g * 7 // 10, b * 7 // 10, a)
    x = (FRAME - s.width) // 2
    y = FRAME - 1 - s.height + dy
    f.alpha_composite(s, (x, max(0, y)))
    # donkere omlijning (leesbaar op de donkere dungeonvloer, zoals de echte map-sprites)
    p = f.load()
    solid = {(x, y) for y in range(FRAME) for x in range(FRAME) if p[x, y][3]}
    for (x, y) in list(solid):
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < FRAME and 0 <= ny < FRAME and (nx, ny) not in solid:
                p[nx, ny] = OUTLINE
    # magenta hoekjes = PLACEHOLDER
    for (cx, cy, sx, sy) in ((0, 0, 1, 1), (15, 0, -1, 1), (0, 15, 1, -1), (15, 15, -1, -1)):
        p[cx, cy] = MAGENTA
        p[cx + sx, cy] = MAGENTA
        p[cx, cy + sy] = MAGENTA
    return f


def make(src_png):
    small = shrink(Image.open(src_png).convert("RGBA"))
    sheet = Image.new("RGBA", (FRAME * 2, FRAME * 4), (0, 0, 0, 0))
    # rij 0 onder, 1 links, 2 rechts (gespiegeld), 3 boven (iets donkerder = rug)
    rows = [dict(), dict(), dict(mirror=True), dict(dark=True)]
    for r, kw in enumerate(rows):
        sheet.alpha_composite(frame(small, 0, **kw), (0, r * FRAME))
        sheet.alpha_composite(frame(small, -1, **kw), (FRAME, r * FRAME))
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    keep = handwerk()
    for eid, rel in enemies().items():
        dst = os.path.join(OUT, eid + ".png")
        rel_dst = os.path.relpath(dst, ROOT)
        if rel_dst in keep:
            print("handwerk, overgeslagen:", rel_dst)
            continue
        if os.path.exists(dst) and not FORCE:
            print("bestaat al:", rel_dst)
            continue
        make(os.path.join(ROOT, rel)).save(dst)
        print("placeholder:", rel_dst)


if __name__ == "__main__":
    main()
