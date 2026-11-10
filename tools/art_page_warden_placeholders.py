#!/usr/bin/env python3
"""Placeholders voor de realtime Page Warden (M9a).

Geen definitieve art. Elk blad heeft magenta hoekpixels (#ff1ee6) en het label PH.
De bestaande page_warden.png / _rug / kaartsprite blijven onaangeroerd (handwerk).

  page_warden_attack_ph.png   512x200  2 frames van 256x200 (windup, treffer)
  page_warden_hit_ph.png      256x200  1 frame, flits over het lichaam
  page_warden_phase2_ph.png   256x200  1 frame, fase 2
  page_warden_page_ph.png      16x16   1 frame, vliegende pagina
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "bosses"
MAGENTA = (255, 30, 230, 255)
INK = (20, 16, 32, 255)
PAPER = (232, 220, 186, 255)
EDGE = (90, 70, 48, 255)


def _corners(im: Image.Image) -> None:
    w, h = im.size
    px = im.load()
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        px[x, y] = MAGENTA


def _ph(draw: ImageDraw.ImageDraw, xy, scale: int) -> None:
    x, y = xy
    # Blokletters P H, zonder fontbestand.
    p = [
        (0, 0), (0, 5), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2),
    ]
    h = [
        (4, 0), (4, 5), (5, 0), (5, 2), (6, 0), (6, 1), (6, 2), (6, 3), (6, 4), (6, 5),
    ]
    for col, row in p + h:
        draw.rectangle(
            [x + col * scale, y + row * scale, x + col * scale + scale - 1, y + row * scale + scale - 1],
            fill=MAGENTA,
        )


def _body(w: int, h: int, phase2: bool, strike: bool) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([8, 8, w - 9, h - 9], outline=MAGENTA, width=2)
    d.rectangle([36, 28, w - 37, h - 36], fill=PAPER, outline=EDGE)
    d.line([48, 48, w - 48, 48], fill=EDGE, width=2)
    d.line([48, 64, w - 70, 64], fill=EDGE, width=2)
    d.line([48, 80, w - 48, 80], fill=EDGE, width=2)
    if phase2:
        d.line([40, 30, w - 30, h - 40], fill=(140, 40, 48, 255), width=3)
        d.line([w - 40, 30, 40, h - 40], fill=(140, 40, 48, 255), width=3)
    if strike:
        d.polygon([(w // 2, 20), (w - 24, h // 2), (w // 2, h - 24), (24, h // 2)], outline=MAGENTA)
    _ph(d, (w // 2 - 28, h // 2 - 18), 6)
    d.rectangle([4, h - 18, w - 5, h - 6], fill=INK)
    _corners(im)
    return im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    wind = _body(256, 200, False, False)
    hitf = _body(256, 200, False, True)
    sheet = Image.new("RGBA", (512, 200), (0, 0, 0, 0))
    sheet.paste(wind, (0, 0))
    sheet.paste(hitf, (256, 0))
    _corners(sheet)
    sheet.save(OUT / "page_warden_attack_ph.png")
    flash = _body(256, 200, False, True)
    overlay = Image.new("RGBA", (256, 200), (255, 40, 60, 70))
    flash = Image.alpha_composite(flash, overlay)
    _corners(flash)
    flash.save(OUT / "page_warden_hit_ph.png")
    _body(256, 200, True, False).save(OUT / "page_warden_phase2_ph.png")
    page = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pd = ImageDraw.Draw(page)
    pd.rectangle([1, 1, 14, 14], fill=PAPER, outline=MAGENTA)
    pd.line([3, 4, 12, 4], fill=EDGE)
    pd.line([3, 7, 12, 7], fill=EDGE)
    pd.line([3, 10, 10, 10], fill=EDGE)
    _corners(page)
    _ph(pd, (4, 5), 1)
    page.save(OUT / "page_warden_page_ph.png")
    print("placeholders geschreven in", OUT)


if __name__ == "__main__":
    main()
