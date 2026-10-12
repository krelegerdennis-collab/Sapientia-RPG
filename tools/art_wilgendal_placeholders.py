#!/usr/bin/env python3
"""Placeholders voor de winkelpanden van Wilgendal. Geen definitieve art.
Gekleurd vlak, magenta hoekjes, het woord PLACEHOLDER.
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "sprites" / "buiten"
MAGENTA = (255, 0, 255, 255)
INK = (255, 232, 120, 255)
FONT = {
    "P": ["111", "101", "111", "100", "100"],
    "L": ["100", "100", "100", "100", "111"],
    "A": ["010", "101", "111", "101", "101"],
    "C": ["011", "100", "100", "100", "011"],
    "E": ["111", "100", "110", "100", "111"],
    "H": ["101", "101", "111", "101", "101"],
    "O": ["111", "101", "101", "101", "111"],
    "D": ["110", "101", "101", "101", "110"],
    "R": ["110", "101", "110", "101", "101"],
}


def corners(img: Image.Image) -> None:
    w, h = img.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel((x, y), MAGENTA)


def text(img: Image.Image, words: str, ox: int, oy: int) -> None:
    drw = ImageDraw.Draw(img)
    x = ox
    for ch in words:
        glyph = FONT.get(ch)
        if glyph is None:
            x += 4
            continue
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    drw.point((x + gx, oy + gy), fill=INK)
        x += 4


def pand(fill, dak) -> Image.Image:
    img = Image.new("RGBA", (48, 48), fill)
    drw = ImageDraw.Draw(img)
    drw.polygon([(4, 18), (24, 6), (44, 18)], fill=dak)
    drw.rectangle([8, 18, 40, 44], fill=fill)
    drw.rectangle([20, 30, 28, 44], fill=(24, 16, 16, 255))
    text(img, "PLACEHOLDER", 2, 2)
    corners(img)
    return img


def bord(fill, icoon: str) -> Image.Image:
    img = Image.new("RGBA", (48, 16), fill)
    drw = ImageDraw.Draw(img)
    if icoon == "schild":
        drw.polygon([(6, 8), (14, 8), (14, 12), (10, 14), (6, 12)], fill=INK)
    elif icoon == "zwaard":
        drw.line([(10, 8), (10, 14)], fill=INK, width=1)
        drw.line([(7, 10), (13, 10)], fill=INK, width=1)
    elif icoon == "ring":
        drw.ellipse([5, 8, 14, 14], outline=INK)
    elif icoon == "ster":
        drw.line([(10, 8), (10, 14)], fill=INK, width=1)
        drw.line([(6, 11), (14, 11)], fill=INK, width=1)
        drw.line([(7, 9), (13, 13)], fill=INK, width=1)
        drw.line([(13, 9), (7, 13)], fill=INK, width=1)
    text(img, "PLACEHOLDER", 2, 2)
    corners(img)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pand((78, 88, 104, 255), (48, 54, 68, 255)).save(OUT / "wilgendal_pantser.png")
    pand((128, 78, 42, 255), (84, 46, 24, 255)).save(OUT / "wilgendal_wapen.png")
    pand((156, 96, 118, 255), (110, 60, 80, 255)).save(OUT / "wilgendal_accessoire.png")
    pand((78, 48, 120, 255), (46, 24, 84, 255)).save(OUT / "wilgendal_magie.png")
    pand((150, 124, 86, 255), (96, 72, 44, 255)).save(OUT / "wilgendal_huis.png")
    pand((96, 86, 74, 255), (60, 52, 44, 255)).save(OUT / "wilgendal_huis_dicht.png")
    bord((78, 88, 104, 255), "schild").save(OUT / "wilgendal_schild.png")
    bord((128, 78, 42, 255), "zwaard").save(OUT / "wilgendal_zwaard.png")
    bord((156, 96, 118, 255), "ring").save(OUT / "wilgendal_ring.png")
    bord((78, 48, 120, 255), "ster").save(OUT / "wilgendal_ster.png")
    toon = Image.new("RGBA", (48, 16), (92, 58, 36, 255))
    ImageDraw.Draw(toon).rectangle([2, 10, 46, 14], fill=(60, 36, 22, 255))
    text(toon, "PLACEHOLDER", 2, 2)
    corners(toon)
    toon.save(OUT / "wilgendal_toonbank.png")
    vit = Image.new("RGBA", (48, 16), (64, 110, 120, 255))
    ImageDraw.Draw(vit).rectangle([4, 8, 14, 14], outline=INK)
    text(vit, "PLACEHOLDER", 2, 2)
    corners(vit)
    vit.save(OUT / "wilgendal_vitrine.png")


if __name__ == "__main__":
    main()
