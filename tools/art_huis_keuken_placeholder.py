#!/usr/bin/env python3
"""Placeholder-fornuis voor het Wachtershuis. Geen definitieve art.
24x32, magenta hoekjes, het woord PH. Echte art: zelfde naam + maat."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "sprites" / "binnen"
MAGENTA = (255, 0, 255, 255)
INK = (255, 232, 120, 255)


def corners(img: Image.Image) -> None:
    w, h = img.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel((x, y), MAGENTA)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    drw = ImageDraw.Draw(img)
    drw.rectangle([2, 10, 21, 30], fill=(72, 48, 36, 255), outline=(40, 24, 16, 255))
    drw.rectangle([4, 12, 10, 17], fill=(48, 32, 24, 255))
    drw.rectangle([13, 12, 19, 17], fill=(48, 32, 24, 255))
    drw.ellipse([5, 13, 9, 16], fill=(220, 96, 40, 255))
    drw.ellipse([14, 13, 18, 16], fill=(220, 96, 40, 255))
    drw.rectangle([6, 20, 17, 28], fill=(36, 28, 24, 255))
    drw.text((7, 2), "PH", fill=INK)
    corners(img)
    img.save(OUT / "keuken_fornuis_PLACEHOLDER.png")


if __name__ == "__main__":
    main()
