#!/usr/bin/env python3
"""PLACEHOLDERS voor Archief 2 (Het Levende Archief). Geen definitieve art.

Magenta hoekjes + het woord PLACEHOLDER. Een pad in tools/handwerk.txt wordt nooit
overschreven. Registratie: tools/placeholders_v17.txt.
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDWERK = os.path.join(ROOT, "tools", "handwerk.txt")
PLACEHOLDER_LIST = os.path.join(ROOT, "tools", "placeholders_v17.txt")
MAGENTA = (255, 30, 230, 255)
INK = (20, 16, 28, 255)


def _handwerk() -> set:
    if not os.path.isfile(HANDWERK):
        return set()
    out = set()
    for line in open(HANDWERK, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            out.add(line.replace("\\", "/"))
    return out


def _mark(im: Image.Image, label: str) -> None:
    d = ImageDraw.Draw(im)
    w, h = im.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        im.putpixel((x, y), MAGENTA)
    text = "PLACEHOLDER" if w >= 48 else "PH"
    d.text((2, 2), text, fill=MAGENTA)


def _save(rel: str, im: Image.Image, blocked: set) -> None:
    rel = rel.replace("\\", "/")
    if rel in blocked:
        raise SystemExit("handwerk, niet overschrijven: %s" % rel)
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print(rel, im.size)


def _sheet(w: int, h: int, fill) -> Image.Image:
    im = Image.new("RGBA", (w, h), fill)
    return im


def build(blocked: set) -> list:
    made = []

    def add(rel: str, im: Image.Image, note: str) -> None:
        _mark(im, note)
        _save(rel, im, blocked)
        made.append((rel, im.size[0], im.size[1], note))

    src = os.path.join(ROOT, "assets/tiles/dungeon/archief_grijs_tiles.png")
    tiles = Image.open(src).convert("RGBA")
    if tiles.size != (256, 80):
        raise SystemExit("tegels niet 256x80: %s" % (tiles.size,))
    px = tiles.load()
    for y in range(tiles.size[1]):
        for x in range(tiles.size[0]):
            r, g, b, a = px[x, y]
            px[x, y] = (min(255, int(r * 0.45)), min(255, int(g * 1.25) + 20), min(255, int(b * 0.55)), a)
    d = ImageDraw.Draw(tiles)
    d.rectangle([4, 4, 40, 18], outline=MAGENTA)
    add("assets/tiles/dungeon/archief2_kas_tiles.png", tiles, "tileset kas 256x80")

    lotte = _sheet(48, 96, (0, 0, 0, 0))
    d = ImageDraw.Draw(lotte)
    for col in range(3):
        for row in range(4):
            x, y = col * 16, row * 24
            d.rectangle([x + 4, y + 6, x + 11, y + 20], fill=(214, 206, 168, 255), outline=INK)
            d.rectangle([x + 5, y + 2, x + 10, y + 7], fill=(232, 196, 140, 255), outline=INK)
    add("assets/sprites/archief2/lotte_veld.png", lotte, "Lotte priester, veld 48x96")

    glitch = _sheet(64, 80, (28, 12, 48, 255))
    d = ImageDraw.Draw(glitch)
    d.rectangle([22, 16, 42, 70], fill=(150, 90, 210, 255), outline=INK)
    d.rectangle([8, 30, 56, 34], fill=MAGENTA)
    d.rectangle([12, 48, 50, 51], fill=(40, 255, 180, 255))
    add("assets/sprites/archief2/lotte_glitch.png", glitch, "Lotte glitch 64x80")

    genezer = _sheet(64, 80, (18, 28, 22, 255))
    d = ImageDraw.Draw(genezer)
    d.rectangle([10, 14, 32, 70], fill=(70, 150, 80, 255), outline=INK)
    d.rectangle([32, 14, 54, 70], fill=(140, 148, 156, 255), outline=INK)
    d.rectangle([24, 28, 40, 36], fill=(200, 210, 220, 255), outline=INK)
    add("assets/sprites/archief2/genezer.png", genezer, "De Genezer 64x80")

    wurger = _sheet(80, 96, (12, 36, 18, 255))
    d = ImageDraw.Draw(wurger)
    d.ellipse([16, 10, 64, 86], fill=(40, 120, 50, 255), outline=INK)
    d.line([(20, 20), (8, 70)], fill=(20, 80, 30, 255), width=3)
    d.line([(60, 24), (74, 78)], fill=(20, 80, 30, 255), width=3)
    add("assets/sprites/archief2/wurger.png", wurger, "De Wurger 80x96")

    for name, color, extra in (
        ("plaat_zaad", (90, 60, 30, 255), "zaad"),
        ("plaat_scheut", (40, 140, 50, 255), "scheut"),
        ("plaat_volgroeid", (20, 160, 60, 255), "volgroeid"),
    ):
        p = _sheet(16, 16, (20, 50, 24, 255))
        d = ImageDraw.Draw(p)
        if extra == "zaad":
            d.ellipse([5, 6, 10, 11], fill=color, outline=INK)
        elif extra == "scheut":
            d.line([(8, 13), (8, 4)], fill=color, width=2)
            d.ellipse([6, 2, 11, 7], fill=(80, 190, 70, 255))
        else:
            d.ellipse([2, 2, 13, 13], fill=color, outline=INK)
        add("assets/sprites/archief2/%s.png" % name, p, "groei-plaat %s 16x16" % extra)

    kern = _sheet(16, 16, (0, 0, 0, 0))
    d = ImageDraw.Draw(kern)
    d.ellipse([2, 2, 13, 13], fill=(40, 180, 90, 255), outline=INK)
    d.rectangle([7, 4, 9, 12], fill=(210, 255, 220, 255))
    add("assets/ui/icons/levenskern.png", kern, "kern-item Archief 2 16x16")

    ww = _sheet(128, 64, (16, 10, 32, 255))
    d = ImageDraw.Draw(ww)
    d.polygon([(20, 50), (108, 50), (96, 18), (32, 18)], fill=(90, 70, 140, 255), outline=MAGENTA)
    d.rectangle([48, 28, 80, 40], fill=(180, 140, 255, 255), outline=INK)
    add("assets/sprites/archief2/world_warper.png", ww, "World Warper exterieur 128x64")

    echo = _sheet(32, 48, (0, 0, 0, 0))
    d = ImageDraw.Draw(echo)
    d.rectangle([10, 6, 22, 40], fill=(80, 220, 230, 180), outline=(180, 255, 255, 255))
    d.ellipse([12, 8, 20, 16], fill=(200, 255, 255, 220))
    add("assets/sprites/archief2/echo.png", echo, "ECHO hologram 32x48")

    sap = _sheet(48, 48, (8, 0, 12, 255))
    d = ImageDraw.Draw(sap)
    d.rectangle([8, 8, 40, 40], outline=MAGENTA)
    for y in range(10, 40, 6):
        d.line([(6, y), (42, y + 2)], fill=MAGENTA)
    add("assets/sprites/archief2/sapientia_glitch.png", sap, "Sapientia glitch 48x48")
    return made


def register(made: list) -> None:
    lines = []
    if os.path.isfile(PLACEHOLDER_LIST):
        lines = open(PLACEHOLDER_LIST, encoding="utf-8").read().splitlines()
    have = set()
    for line in lines:
        part = line.split()
        if part:
            have.add(part[0])
    extra = ["", "# Archief 2, Het Levende Archief (tools/art_archief2_placeholders.py). PLACEHOLDER, geen definitieve art."]
    for rel, w, h, note in made:
        row = "%s   %dx%d   %s" % (rel, w, h, note)
        if rel not in have:
            extra.append(row)
    if len(extra) > 2:
        with open(PLACEHOLDER_LIST, "a", encoding="utf-8") as handle:
            handle.write("\n".join(extra) + "\n")


def main() -> None:
    blocked = _handwerk()
    made = build(blocked)
    register(made)


if __name__ == "__main__":
    main()
