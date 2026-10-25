#!/usr/bin/env python3
"""Placeholders voor het Wachtershuis. Geen definitieve art.
24x32, magenta hoekjes, het woord PH. Echte art: zelfde naam + maat."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "sprites" / "binnen"
MAGENTA = (255, 0, 255, 255)
INK = (255, 232, 120, 255)
HOUT = (92, 58, 38, 255)
DONKER = (48, 28, 18, 255)
LICHT = (128, 84, 52, 255)


def corners(img: Image.Image) -> None:
    w, h = img.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel((x, y), MAGENTA)


def fornuis() -> Image.Image:
    img = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    drw = ImageDraw.Draw(img)
    drw.rectangle([2, 10, 21, 30], fill=(72, 48, 36, 255), outline=DONKER)
    drw.rectangle([4, 12, 10, 17], fill=(48, 32, 24, 255))
    drw.rectangle([13, 12, 19, 17], fill=(48, 32, 24, 255))
    drw.ellipse([5, 13, 9, 16], fill=(220, 96, 40, 255))
    drw.ellipse([14, 13, 18, 16], fill=(220, 96, 40, 255))
    drw.rectangle([6, 20, 17, 28], fill=(36, 28, 24, 255))
    drw.text((7, 2), "PH", fill=INK)
    corners(img)
    return img


def deurkozijn() -> Image.Image:
    img = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    drw = ImageDraw.Draw(img)
    drw.rectangle([0, 0, 23, 6], fill=HOUT, outline=DONKER)
    drw.rectangle([0, 6, 4, 31], fill=HOUT, outline=DONKER)
    drw.rectangle([19, 6, 23, 31], fill=HOUT, outline=DONKER)
    drw.rectangle([1, 1, 22, 5], fill=LICHT)
    drw.rectangle([1, 7, 3, 30], fill=LICHT)
    drw.rectangle([20, 7, 22, 30], fill=LICHT)
    drw.text((8, 1), "PH", fill=INK)
    corners(img)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fornuis().save(OUT / "keuken_fornuis_PLACEHOLDER.png")
    deurkozijn().save(OUT / "deurkozijn_PLACEHOLDER.png")


if __name__ == "__main__":
    main()
