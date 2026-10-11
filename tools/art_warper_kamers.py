#!/usr/bin/env python3
"""Lelijke placeholders voor de extra World Warper-kamers. Geen definitieve art.
Magenta hoekjes. Het woord PLACEHOLDER staat op elk blad, voor zover het past.
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "world_warper" / "art"
MAGENTA = (255, 0, 255, 255)
INK = (255, 232, 120, 255)
# 3x5 blokletters, alleen wat we nodig hebben.
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
    "W": ["101", "101", "101", "111", "101"],
    "K": ["101", "101", "110", "101", "101"],
    "M": ["101", "111", "101", "101", "101"],
    "S": ["111", "100", "111", "001", "111"],
    "T": ["111", "010", "010", "010", "010"],
    "F": ["111", "100", "110", "100", "100"],
}


def corners(img: Image.Image) -> None:
    w, h = img.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel((x, y), MAGENTA)


def text(img: Image.Image, words: str, ox: int, oy: int, scale: int = 1) -> None:
    drw = ImageDraw.Draw(img)
    x = ox
    for ch in words:
        glyph = FONT.get(ch)
        if glyph is None:
            x += 4 * scale
            continue
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    drw.rectangle(
                        [x + gx * scale, oy + gy * scale, x + (gx + 1) * scale - 1, oy + (gy + 1) * scale - 1],
                        fill=INK,
                    )
        x += 4 * scale


def sheet(w: int, h: int, fill, words: str, scale: int = 1) -> Image.Image:
    img = Image.new("RGBA", (w, h), fill)
    text(img, words, 2, 2, scale)
    corners(img)
    return img


def echo(path: Path, body) -> None:
    img = Image.new("RGBA", (48, 96), (20, 8, 32, 255))
    drw = ImageDraw.Draw(img)
    for col in range(3):
        for row in range(4):
            ox, oy = col * 16, row * 32
            drw.rectangle([ox + 4, oy + 6, ox + 11, oy + 14], fill=body)
            drw.rectangle([ox + 6, oy + 16, ox + 9, oy + 26], fill=body)
            drw.rectangle([ox + 3, oy + 18, ox + 6, oy + 21], fill=body)
            drw.rectangle([ox + 9, oy + 18, ox + 12, oy + 21], fill=body)
    text(img, "PLACEHOLDER", 2, 2, 1)
    corners(img)
    img.save(path)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    echo(OUT / "echo_placeholder.png", (180, 90, 220, 255))
    echo(OUT / "party_placeholder.png", (70, 160, 90, 255))
    sheet(32, 32, (30, 40, 70, 255), "PC", 2).save(OUT / "pc_placeholder.png")
    sheet(32, 16, (40, 20, 70, 255), "WARP", 1).save(OUT / "warp_platform.png")
    sheet(32, 16, (90, 60, 30, 255), "TAFEL", 1).save(OUT / "tafel_placeholder.png")
    sheet(48, 16, (50, 40, 30, 255), "TOONBANK", 1).save(OUT / "toonbank_placeholder.png")
    sheet(32, 16, (90, 20, 70, 255), "KAMERS", 1).save(OUT / "bord_kamers.png")
    print("placeholders in", OUT)


if __name__ == "__main__":
    main()
