#!/usr/bin/env python3
"""PLACEHOLDERS voor de vier winkels van Wilgendal. Geen definitieve art.

Magenta hoekjes en de letters PH. Silhouetten blijven grof, zodat ze niet als
af pixel-art gelezen worden. Een pad uit tools/handwerk.txt wordt nooit
overschreven.
"""
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "wilgendal"
HANDWERK = ROOT / "tools" / "handwerk.txt"
PLACEHOLDER_LIST = ROOT / "tools" / "placeholders_v17.txt"
MAGENTA = (255, 0, 255, 255)
INK = (255, 232, 120, 255)

FONT = {
    "P": ["111", "101", "111", "100", "100"],
    "H": ["101", "101", "111", "101", "101"],
}

# Handtekening-pixel per soort, zodat de vier looks uit elkaar te houden zijn.
ACCENT = {
    "wapen": (140, 80, 30, 255),
    "pantser": (168, 176, 186, 255),
    "accessoire": (212, 168, 64, 255),
    "magie": (64, 220, 200, 255),
}
BODY = {
    "wapen": (110, 68, 36, 255),
    "pantser": (78, 84, 96, 255),
    "accessoire": (186, 142, 150, 255),
    "magie": (62, 32, 108, 255),
}
SKIN = (214, 170, 132, 255)
LEG = (46, 36, 28, 255)

FILES = [
    ("wapen_shopkeeper.png", 48, 96, "winkelier wapen, ambachtelijk (3x4 frames van 16x24)"),
    ("wapen_toonbank.png", 48, 16, "toonbank wapen, ambachtelijk"),
    ("wapen_display.png", 32, 32, "uitstalling wapen, ambachtelijk"),
    ("pantser_shopkeeper.png", 48, 96, "winkelier pantser, stoer (3x4 frames van 16x24)"),
    ("pantser_toonbank.png", 48, 16, "toonbank pantser, stoer"),
    ("pantser_display.png", 32, 32, "uitstalling pantser, stoer"),
    ("accessoire_shopkeeper.png", 48, 96, "winkelier accessoire, sierlijk (3x4 frames van 16x24)"),
    ("accessoire_toonbank.png", 48, 16, "toonbank accessoire, sierlijk"),
    ("accessoire_display.png", 32, 32, "uitstalling accessoire, sierlijk"),
    ("magie_shopkeeper.png", 48, 96, "winkelier magie, mystiek (3x4 frames van 16x24)"),
    ("magie_toonbank.png", 48, 16, "toonbank magie, mystiek"),
    ("magie_display.png", 32, 32, "uitstalling magie, mystiek"),
]


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
                    drw.point((x + gx, oy + gy), fill=MAGENTA)
        x += 4


def _rect(drw: ImageDraw.ImageDraw, box, fill) -> None:
    drw.rectangle(box, fill=fill)


def keeper(kind: str) -> Image.Image:
    img = Image.new("RGBA", (48, 96), (0, 0, 0, 0))
    drw = ImageDraw.Draw(img)
    body = BODY[kind]
    accent = ACCENT[kind]
    for row in range(4):
        for col in range(3):
            ox, oy = col * 16, row * 24
            hx = ox + 5
            if row == 1:
                hx = ox + 3
            elif row == 2:
                hx = ox + 7
            bw = 8
            if kind == "pantser":
                bw = 12
            elif kind == "accessoire":
                bw = 6
            bx = ox + (16 - bw) // 2
            if row == 1:
                bx -= 1
            elif row == 2:
                bx += 1
            _rect(drw, [hx, oy + 6, hx + 5, oy + 11], SKIN)
            _rect(drw, [bx, oy + 12, bx + bw - 1, oy + 18], body)
            if kind == "wapen":
                _rect(drw, [ox + 11, oy + 11, ox + 14, oy + 13], accent)
                _rect(drw, [ox + 12, oy + 13, ox + 13, oy + 18], accent)
            elif kind == "pantser":
                _rect(drw, [bx - 1, oy + 11, bx + bw, oy + 13], accent)
                _rect(drw, [ox + 1, oy + 14, ox + 3, oy + 18], accent)
            elif kind == "accessoire":
                _rect(drw, [ox + 7, oy + 14, ox + 8, oy + 15], accent)
            else:
                _rect(drw, [hx - 1, oy + 4, hx + 6, oy + 8], (36, 16, 64, 255))
                drw.point((ox + 8, oy + 16), fill=accent)
            shift = -1 if col == 1 else (1 if col == 2 else 0)
            _rect(drw, [bx + shift, oy + 19, bx + 2 + shift, oy + 22], LEG)
            _rect(drw, [bx + bw - 3 - shift, oy + 19, bx + bw - 1 - shift, oy + 22], LEG)
            text(img, "PH", ox + 1, oy + 1)
    img.putpixel((24, 40), accent)
    corners(img)
    return img


def counter(kind: str) -> Image.Image:
    img = Image.new("RGBA", (48, 16), (0, 0, 0, 0))
    drw = ImageDraw.Draw(img)
    body = BODY[kind]
    accent = ACCENT[kind]
    _rect(drw, [1, 4, 46, 14], body)
    if kind == "wapen":
        _rect(drw, [18, 2, 30, 8], (70, 72, 78, 255))
        _rect(drw, [22, 6, 26, 12], accent)
    elif kind == "pantser":
        for x in (8, 20, 32):
            _rect(drw, [x, 6, x + 2, 8], accent)
        _rect(drw, [1, 4, 46, 6], accent)
    elif kind == "accessoire":
        _rect(drw, [6, 6, 14, 12], (230, 210, 216, 255))
        drw.ellipse([20, 6, 26, 12], outline=accent)
        drw.ellipse([30, 7, 34, 11], outline=accent)
    else:
        _rect(drw, [4, 8, 44, 10], accent)
        drw.ellipse([20, 3, 28, 11], fill=accent)
    img.putpixel((24, 8), accent)
    text(img, "PH", 2, 1)
    corners(img)
    return img


def display(kind: str) -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    drw = ImageDraw.Draw(img)
    body = BODY[kind]
    accent = ACCENT[kind]
    _rect(drw, [4, 22, 27, 28], body)
    if kind == "wapen":
        _rect(drw, [8, 6, 11, 22], (180, 186, 190, 255))
        _rect(drw, [18, 8, 21, 22], accent)
        _rect(drw, [7, 4, 12, 7], (90, 70, 40, 255))
    elif kind == "pantser":
        _rect(drw, [10, 6, 22, 20], accent)
        drw.ellipse([12, 4, 20, 10], fill=(60, 64, 72, 255))
    elif kind == "accessoire":
        drw.ellipse([7, 10, 13, 16], outline=accent)
        drw.ellipse([14, 8, 22, 16], outline=accent)
        drw.ellipse([18, 14, 24, 20], outline=(230, 210, 216, 255))
    else:
        drw.ellipse([10, 6, 22, 18], fill=accent)
        _rect(drw, [8, 16, 14, 22], (40, 24, 70, 255))
    img.putpixel((16, 16), accent)
    text(img, "PH", 2, 2)
    corners(img)
    return img


def _blocked(rel: str) -> bool:
    if not HANDWERK.is_file():
        return False
    for line in HANDWERK.read_text(encoding="utf-8").splitlines():
        raw = line.split("#", 1)[0].strip()
        if raw == rel:
            return True
    return False


def _register() -> None:
    lines = []
    if PLACEHOLDER_LIST.is_file():
        lines = PLACEHOLDER_LIST.read_text(encoding="utf-8").splitlines()
    if any("wilgendal/wapen_shopkeeper.png" in line for line in lines):
        return
    extra = [
        "",
        "# Wilgendal, vier winkelpanden (tools/art_wilgendal_winkels.py). PLACEHOLDER, magenta hoekjes, letters PH. Geen definitieve art.",
    ]
    for name, w, h, desc in FILES:
        extra.append("assets/sprites/wilgendal/%-24s %dx%d   %s" % (name, w, h, desc))
    with PLACEHOLDER_LIST.open("a", encoding="utf-8") as handle:
        handle.write("\n".join(extra) + "\n")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    made = {
        "shopkeeper": keeper,
        "toonbank": counter,
        "display": display,
    }
    for name, w, h, _desc in FILES:
        rel = "assets/sprites/wilgendal/" + name
        if _blocked(rel):
            raise SystemExit("handwerk, niet overschrijven: " + rel)
        kind = name.split("_", 1)[0]
        part = name.split("_", 1)[1].replace(".png", "")
        img = made[part](kind)
        if img.size != (w, h):
            raise SystemExit("verkeerde maat %s %s" % (name, img.size))
        img.save(OUT / name)
    _register()
    print("placeholders in", OUT)


if __name__ == "__main__":
    main()
