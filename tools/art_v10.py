"""
v0.10 – PLACEHOLDER-art (tot de art director 'RPG ART' de echte levert):
  (assets/tiles/binnen.png en assets/sprites/save_book.png: nu echte art van RPG ART;
   make_interior()/make_save_book() hieronder zijn de oude placeholders, niet meer gebruikt)
  art/battle_bg/gras.png        1280x432 gevechtsachtergrond gras/vlakte/bos   (nu: echte art RPG ART)
  art/battle_bg/zand.png        1280x432 gevechtsachtergrond zand/strand/woestijn (nu: echte art)
  art/battle_bg/boss.png        1280x432 gevechtsachtergrond baas            (nu: echte art)
  art/enemies/mosslijm.png        80x56  vooraanzicht, grondschaduw midden onderaan (2x-raster)
  art/enemies/moskonijn.png       80x100 idem
Stijl 'De Vergeten Bibliotheek': donkergrijs/bruin, magenta/cyaan alleen als accent.
Bestanden die in tools/handwerk.txt staan en al bestaan worden NIET overschreven
(echte art van de art director gaat dus altijd voor).
Starten (vanuit de projectmap):  python3 tools/art_v10.py   [--ook-handwerk]
"""
import os
import random
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = 16


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


MAG = hx("ff1ee6")
MAG_D = hx("8a0c84")
CYA = hx("19ecf6")
CYA_D = hx("08707a")
OUT = hx("0c0b0d")
WOOD = [hx(c) for c in ("1e1612", "2e221a", "3e2e22", "4f3b2b", "634a36", "7a5c44")]
STONE = [hx(c) for c in ("141518", "1e2024", "2a2c31", "373a40", "464a51", "5a5e66")]
PARCH = [hx(c) for c in ("6e6452", "9a8e74", "c4b898", "e2d8bc")]
GREEN = [hx(c) for c in ("17231b", "223328", "2f4436", "3e5646")]
RED = [hx(c) for c in ("2a1416", "44201f", "5e2c2a")]
FLAME = [hx(c) for c in ("8a4a10", "e0a040", "ffe6a0")]
BOOKS = [hx(c) for c in ("4a3a2c", "3a4a3c", "5c4632", "4a4250", "604c3c", "394a52", "6a5a44")]


def handwerk():
    p = os.path.join(ROOT, "tools", "handwerk.txt")
    out = set()
    if os.path.exists(p):
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#"):
                out.add(line)
    return out


def save(img, rel):
    full = os.path.join(ROOT, rel)
    if rel in handwerk() and os.path.exists(full) and "--ook-handwerk" not in sys.argv:
        print("overgeslagen (handwerk, zie tools/handwerk.txt):", rel)
        return
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)
    print("opgeslagen:", rel, img.size)


# ================================================================ binnen-tiles
class Tile:
    def __init__(self):
        self.im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        self.px = self.im.load()

    def p(self, x, y, c):
        if 0 <= x < T and 0 <= y < T:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):   # inclusief
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.p(x, y, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)


def floor(t, variant=0):
    # houten planken, 4 px hoog, versprongen naden
    for y in range(T):
        for x in range(T):
            row = y // 4
            shade = WOOD[2] if row % 2 == 0 else WOOD[3]
            if (x * 7 + y * 3 + row * 5) % 11 == 0:
                shade = WOOD[2]
            t.p(x, y, shade)
        if y % 4 == 3:
            t.hline(0, 15, y, WOOD[1])
    for row in range(4):
        sx = (row * 6 + 3) % 16
        t.vline(sx, row * 4, row * 4 + 2, WOOD[1])
    t.hline(0, 15, 0, WOOD[4]) if False else None
    if variant == 1:   # kwast + kras
        t.rect(9, 5, 10, 6, WOOD[1])
        t.p(10, 5, WOOD[0])
        t.hline(2, 5, 10, WOOD[4])


def wall_upper(t, cornice=False):
    t.rect(0, 0, 15, 15, STONE[2])
    for y in range(0, 16, 4):   # blokken steen
        t.hline(0, 15, y, STONE[1])
        off = 0 if (y // 4) % 2 == 0 else 4
        for x in range(off, 16, 8):
            t.vline(x, y, y + 3, STONE[1])
    for (x, y) in ((3, 2), (11, 6), (6, 10), (13, 13)):
        t.p(x, y, STONE[3])
    if cornice:
        t.rect(0, 0, 15, 15, STONE[0])
        t.rect(0, 10, 15, 13, STONE[3])
        t.hline(0, 15, 10, STONE[4])
        t.hline(0, 15, 14, STONE[1])
        t.hline(0, 15, 15, STONE[2])
        for x in range(1, 16, 4):
            t.p(x, 12, STONE[2])


def wall_lower(t):
    wall_upper(t)
    t.rect(0, 7, 15, 15, WOOD[1])   # lambrisering
    t.hline(0, 15, 7, WOOD[4])
    t.hline(0, 15, 8, WOOD[3])
    for x in (0, 8):
        t.rect(x + 2, 10, x + 5, 13, WOOD[2])
        t.hline(x + 2, x + 5, 10, WOOD[3])
    t.hline(0, 15, 15, OUT)


def shelf(t, lower):
    t.rect(0, 0, 15, 15, WOOD[1])
    t.vline(0, 0, 15, WOOD[3])
    t.vline(15, 0, 15, WOOD[0])
    rnd = random.Random(7 if lower else 3)
    for sy in ((1, 7), (9, 14)) if not lower else ((0, 5), (8, 13)):
        y0, y1 = sy
        t.rect(1, y0, 14, y1, hx("100c0a"))
        x = 1
        while x < 15:
            w = rnd.choice((1, 2, 2, 3))
            h = rnd.randint(y1 - y0 - 2, y1 - y0)
            col = rnd.choice(BOOKS)
            for bx in range(x, min(15, x + w)):
                t.vline(bx, y1 - h, y1, col)
            t.p(x, y1 - h, PARCH[0])
            if rnd.random() < 0.08:
                t.p(x, y1 - h + 2, MAG if rnd.random() < 0.5 else CYA)   # glitch-rug
            x += w
        t.hline(0, 15, y1 + 1, WOOD[4])
        t.hline(0, 15, y1 + 2 if y1 + 2 < 16 else y1 + 1, WOOD[0])
    if lower:
        t.hline(0, 15, 15, OUT)


def window(t, lower):
    wall_upper(t)
    if not lower:
        t.rect(3, 3, 12, 15, STONE[0])
        t.rect(4, 4, 11, 15, hx("16222c"))
        t.rect(5, 2, 10, 2, STONE[0])
        t.vline(7, 4, 15, STONE[1])
        t.vline(8, 4, 15, STONE[1])
        t.p(5, 6, CYA_D)
        t.p(10, 9, hx("2c4452"))
        t.p(6, 12, hx("2c4452"))
        t.p(10, 5, CYA)
    else:
        t.rect(3, 0, 12, 5, STONE[0])
        t.rect(4, 0, 11, 4, hx("16222c"))
        t.vline(7, 0, 4, STONE[1])
        t.vline(8, 0, 4, STONE[1])
        t.rect(2, 5, 13, 6, STONE[4])   # vensterbank
        t.hline(2, 13, 7, STONE[1])
        t.rect(0, 9, 15, 15, WOOD[1])
        t.hline(0, 15, 9, WOOD[4])
        t.hline(0, 15, 15, OUT)


def side(t, right):
    floor(t)
    xs = range(10, 16) if right else range(0, 6)
    for x in xs:
        t.vline(x, 0, 15, STONE[1])
    edge = 10 if right else 5
    t.vline(edge, 0, 15, STONE[3])
    t.vline(15 if right else 0, 0, 15, STONE[0])
    for y in range(2, 16, 5):
        t.p(12 if right else 3, y, STONE[2])


def bottom_wall(t):
    t.rect(0, 0, 15, 15, STONE[0])
    t.rect(0, 0, 15, 4, STONE[2])
    t.hline(0, 15, 0, STONE[4])
    t.hline(0, 15, 5, OUT)


def door(t):
    floor(t)
    t.rect(0, 0, 1, 15, STONE[1])
    t.rect(14, 0, 15, 15, STONE[1])
    t.rect(2, 8, 13, 15, hx("0a0a0c"))
    t.hline(2, 13, 8, STONE[4])
    t.rect(3, 2, 12, 6, GREEN[1])   # deurmat
    t.hline(3, 12, 2, GREEN[3])
    t.p(7, 4, MAG_D)
    t.p(8, 4, MAG_D)


def rug(t, pos):
    # pos: 'tl','t','tr','bl','b','br' (3x2 tapijt)
    floor(t)
    top = pos[0] == "t"
    xl = 2 if pos.endswith("l") else 0
    xr = 13 if pos.endswith("r") else 15
    y0 = 3 if top else 0
    y1 = 15 if top else 12
    t.rect(xl, y0, xr, y1, GREEN[2])
    # rand
    if top:
        t.hline(xl, xr, y0, PARCH[0])
        t.hline(xl, xr, y0 + 1, GREEN[0])
    else:
        t.hline(xl, xr, y1, PARCH[0])
        t.hline(xl, xr, y1 - 1, GREEN[0])
    if pos.endswith("l"):
        t.vline(xl, y0, y1, PARCH[0])
        t.vline(xl + 1, y0, y1, GREEN[0])
    if pos.endswith("r"):
        t.vline(xr, y0, y1, PARCH[0])
        t.vline(xr - 1, y0, y1, GREEN[0])
    # patroon
    for y in range(y0 + 3, y1 - 1, 3):
        for x in range(xl + 3, xr - 1, 4):
            t.p(x + (y // 3) % 2, y, GREEN[3])
    if pos in ("t", "b"):
        cy = 15 if top else 0
        t.p(7, cy, MAG)
        t.p(8, cy, MAG)
        t.p(6, cy, MAG_D)
        t.p(9, cy, MAG_D)


def bed(t, top):
    floor(t)
    t.rect(1, 0 if not top else 1, 14, 15 if not top else 15, WOOD[1])
    if top:
        t.rect(1, 1, 14, 3, WOOD[4])   # hoofdeinde
        t.hline(1, 14, 1, WOOD[5])
        t.rect(3, 5, 12, 9, PARCH[2])  # kussen
        t.hline(3, 12, 5, PARCH[3])
        t.hline(3, 12, 9, PARCH[1])
        t.rect(2, 11, 13, 15, RED[1])  # deken begint
        t.hline(2, 13, 11, RED[2])
        t.hline(2, 13, 12, PARCH[1])
    else:
        t.rect(2, 0, 13, 12, RED[1])
        for y in range(2, 12, 3):
            t.hline(2, 13, y, RED[0])
        t.vline(2, 0, 12, RED[2])
        t.p(9, 6, MAG_D)
        t.rect(1, 13, 14, 14, WOOD[3])
        t.hline(1, 14, 15, OUT)


def table(t, right):
    floor(t)
    x0, x1 = (0, 14) if right else (1, 15)
    t.rect(x0, 3, x1, 9, WOOD[4])
    t.hline(x0, x1, 3, WOOD[5])
    t.hline(x0, x1, 9, WOOD[2])
    t.rect(x0, 10, x1, 11, WOOD[1])
    leg = 12 if right else 3
    t.rect(leg, 12, leg + 1, 15, WOOD[1])
    if right:   # kaars + boek
        t.rect(5, 5, 6, 8, PARCH[3])
        t.p(5, 4, FLAME[1])
        t.p(5, 3, FLAME[2])
        t.p(6, 4, FLAME[0])
        t.rect(9, 6, 12, 8, BOOKS[1])
        t.hline(9, 12, 6, PARCH[1])
    else:       # stapel papier met code
        t.rect(5, 4, 10, 7, PARCH[2])
        t.hline(6, 9, 5, PARCH[0])
        t.p(7, 6, CYA_D)


def lamp(t):
    floor(t)
    t.rect(6, 13, 9, 14, STONE[1])   # voet
    t.vline(7, 4, 13, STONE[3])
    t.vline(8, 4, 13, STONE[1])
    t.rect(4, 4, 11, 5, STONE[3])
    for x in (4, 11):
        t.rect(x, 2, x, 3, PARCH[3])
        t.p(x, 1, FLAME[1])
        t.p(x, 0, FLAME[2])
    t.rect(7, 1, 8, 3, PARCH[3])
    t.p(7, 0, FLAME[2])
    t.hline(6, 9, 15, hx("000000", 90))


INTERIOR_TILES = [
    ("vloer", False, lambda t: floor(t, 0)),
    ("vloer_kwast", False, lambda t: floor(t, 1)),
    ("muur_kroonlijst", True, lambda t: wall_upper(t, True)),
    ("muur_boven", True, lambda t: wall_upper(t)),
    ("muur_onder", True, wall_lower),
    ("kast_boven", True, lambda t: shelf(t, False)),
    ("kast_onder", True, lambda t: shelf(t, True)),
    ("raam_boven", True, lambda t: window(t, False)),
    ("raam_onder", True, lambda t: window(t, True)),
    ("zijmuur_links", True, lambda t: side(t, False)),
    ("zijmuur_rechts", True, lambda t: side(t, True)),
    ("muur_voor", True, bottom_wall),
    ("deur", False, door),
    ("tapijt_lb", False, lambda t: rug(t, "tl")),
    ("tapijt_b", False, lambda t: rug(t, "t")),
    ("tapijt_rb", False, lambda t: rug(t, "tr")),
    ("tapijt_lo", False, lambda t: rug(t, "bl")),
    ("tapijt_o", False, lambda t: rug(t, "b")),
    ("tapijt_ro", False, lambda t: rug(t, "br")),
    ("bed_boven", True, lambda t: bed(t, True)),
    ("bed_onder", True, lambda t: bed(t, False)),
    ("tafel_links", True, lambda t: table(t, False)),
    ("tafel_rechts", True, lambda t: table(t, True)),
    ("kandelaar", True, lamp),
]


def make_interior():
    sheet = Image.new("RGBA", (T * len(INTERIOR_TILES), T), (0, 0, 0, 0))
    for i, (_, _, fn) in enumerate(INTERIOR_TILES):
        t = Tile()
        fn(t)
        sheet.paste(t.im, (i * T, 0))
    return sheet


def make_save_book():
    frames = []
    glow = [0.35, 0.6, 0.9, 0.6]
    for f in range(4):
        t = Tile()
        g = glow[f]
        # gloed (halo) achter het boek
        for y in range(0, 10):
            for x in range(1, 15):
                d = ((x - 7.5) / 7.0) ** 2 + ((y - 5) / 5.0) ** 2
                if d < 1.0 and (x + y + f) % 2 == 0:
                    a = int(110 * g * (1 - d))
                    if a > 12:
                        t.p(x, y, (MAG[0], MAG[1], MAG[2], a))
        # lessenaar
        t.rect(7, 9, 8, 13, WOOD[2])
        t.vline(7, 9, 13, WOOD[3])
        t.rect(5, 14, 10, 14, WOOD[3])
        t.hline(4, 11, 15, WOOD[1])
        t.rect(2, 7, 13, 9, WOOD[1])   # schuin blad
        t.hline(2, 13, 9, WOOD[0])
        t.hline(3, 12, 7, WOOD[3])
        # open boek
        t.rect(2, 4, 7, 7, PARCH[2])
        t.rect(8, 4, 13, 7, PARCH[2])
        t.hline(2, 7, 4, PARCH[3])
        t.hline(8, 13, 4, PARCH[3])
        t.vline(7, 4, 7, PARCH[0])
        t.vline(8, 4, 7, PARCH[1])
        for y in (5, 6):   # tekstregels (lichten op)
            for x in range(3, 7):
                if (x + y) % 3:
                    t.p(x, y, CYA_D if g < 0.8 else CYA)
            for x in range(9, 13):
                if (x + y + 1) % 3:
                    t.p(x, y, PARCH[0])
        if f == 2:   # bladzijde gaat omhoog (flikkering)
            t.rect(9, 1, 12, 3, PARCH[3])
            t.p(13, 3, PARCH[1])
            t.p(8, 3, PARCH[1])
            t.p(11, 0, MAG)
        if f in (1, 3):
            t.p(10, 2, CYA)
        t.p(5, 2 - (f % 2), MAG)
        frames.append(t.im)
    sheet = Image.new("RGBA", (T * 4, T), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        sheet.paste(im, (i * T, 0))
    return sheet


# ================================================================ gevechtsachtergronden
W, H = 1280, 432
HORIZON = 168          # horizon op het 2x-raster (vijanden: voeten rond y 204)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def lerp(a, b, t):
    return a + (b - a) * t


def grad(img, y0, y1, c0, c1, steps=6):
    """Verticale overgang in een paar vaste tinten, met Bayer-dither (pixel-look)."""
    for y in range(y0, y1):
        t = (y - y0) / max(1, (y1 - y0 - 1)) * (steps - 1)
        for x in range(W):
            k = int(t + BAYER[y % 4, x % 4])
            k = min(steps - 1, k)
            img[y, x] = lerp(np.array(c0, float), np.array(c1, float), k / (steps - 1))


def rgb(s):
    s = s.lstrip("#")
    return [int(s[i:i + 2], 16) for i in (0, 2, 4)]


def silhouette(img, rnd, base_y, col, kind):
    """Verre ruïnes van de bibliotheek op de horizon."""
    x = 0
    while x < W:
        w = rnd.randint(40, 120)
        h = rnd.randint(16, 60)
        if kind == "pillars" and rnd.random() < 0.6:
            w = rnd.randint(10, 18)
            h = rnd.randint(20, 70)
        if rnd.random() < 0.35:
            x += w
            continue
        img[base_y - h:base_y, x:x + w] = col
        if kind != "pillars" and w > 50:   # boogramen
            for wx in range(x + 8, x + w - 8, 14):
                img[base_y - h + 6:base_y - h + 18, wx:wx + 5] = [c * 0.6 for c in col]
        if rnd.random() < 0.5:   # kapotte rand
            for k in range(rnd.randint(3, 8)):
                kx = min(W - 1, rnd.randint(x, x + w - 1))
                img[base_y - h:base_y - h + rnd.randint(2, 8), kx:kx + rnd.randint(2, 6)] = img[base_y - h - 1, kx]
        x += w + rnd.randint(4, 30)


def glitch(img, rnd, n, y0, y1):
    for _ in range(n):
        x = rnd.randrange(W - 6)
        y = rnd.randrange(y0, y1)
        c = rgb("ff1ee6") if rnd.random() < 0.5 else rgb("19ecf6")
        s = rnd.choice((2, 2, 4))
        img[y:y + s, x:x + s] = c
    for _ in range(n // 3):   # binaire 'sneeuw' (donkere blokjes)
        x = rnd.randrange(W - 12)
        y = rnd.randrange(y0, y1)
        img[y:y + 2, x:x + rnd.randint(4, 12)] = [c * 0.55 for c in img[y, x]]


def ground_bands(img, rnd, c_far, c_near, tufts, tuft_col):
    grad(img, HORIZON, H, c_far, c_near, steps=7)
    # perspectief-lijnen (paden/voegen) naar het midden
    for i in range(-8, 9):
        for y in range(HORIZON, H, 1):
            t = (y - HORIZON) / (H - HORIZON)
            x = int(W / 2 + i * 90 * t * 1.6)
            if 0 <= x < W and (y // 2) % 3 != 0:
                img[y, x] = [c * 0.82 for c in img[y, x]]
    for _ in range(tufts):
        y = rnd.randrange(HORIZON + 6, H - 2)
        t = (y - HORIZON) / (H - HORIZON)
        x = rnd.randrange(W)
        h = 1 + int(t * 6)
        for k in range(-1 - int(t * 2), 2 + int(t * 2)):
            xx = x + k * 2
            if 0 <= xx < W:
                img[max(HORIZON, y - h + abs(k)):y, xx] = tuft_col


def make_bg(kind):
    rnd = random.Random({"grass": 11, "sand": 23, "boss": 37}[kind])
    img = np.zeros((H, W, 3), float)
    if kind == "grass":
        grad(img, 0, HORIZON, rgb("0e1012"), rgb("2a3030"), steps=6)
        silhouette(img, rnd, HORIZON, rgb("181c1c"), "ruins")
        ground_bands(img, rnd, rgb("26332a"), rgb("121a14"), 900, rgb("3a4d3e"))
        for _ in range(60):   # papiersnippers in het gras
            x, y = rnd.randrange(W - 4), rnd.randrange(HORIZON + 20, H - 4)
            img[y:y + 2, x:x + 3] = rgb("8a8478")
        glitch(img, rnd, 70, 0, HORIZON)
    elif kind == "sand":
        grad(img, 0, HORIZON, rgb("141312"), rgb("3a3631"), steps=6)
        silhouette(img, rnd, HORIZON, rgb("221f1c"), "pillars")
        grad(img, HORIZON, H, rgb("6a6152"), rgb("2e2a24"), steps=7)
        for d in range(9):   # duinen
            y0 = HORIZON + 14 + d * 30
            amp = 4 + d * 2
            ph = rnd.random() * 6.28
            for x in range(W):
                y = int(y0 + amp * np.sin(x / (90 + d * 25) + ph))
                if HORIZON < y < H - 3:
                    img[y:y + 2 + d // 3, x] = [c * 0.8 for c in img[min(H - 1, y), x]]
                    img[y - 1, x] = [min(255, c * 1.12) for c in img[y - 1, x]]
        for _ in range(16):   # half begraven boeken/stenen
            x, y = rnd.randrange(20, W - 40), rnd.randrange(HORIZON + 30, H - 20)
            s = 4 + int((y - HORIZON) / 20)
            img[y:y + s // 2, x:x + s] = rgb("2a2622")
            img[y, x:x + s] = rgb("8a7e66")
        glitch(img, rnd, 50, 0, HORIZON)
    else:   # boss
        grad(img, 0, HORIZON + 30, rgb("08070a"), rgb("1c1420"), steps=6)
        silhouette(img, rnd, HORIZON + 30, rgb("120e14"), "pillars")
        grad(img, HORIZON + 30, H, rgb("241c26"), rgb("0a080c"), steps=7)
        cx, cy = W // 2, 214     # glyphen-ring onder de vijanden
        for a in np.linspace(0, 2 * np.pi, 1400):
            for rr, col in ((300, rgb("ff1ee6")), (270, rgb("8a0c84")), (330, rgb("4a0a46"))):
                x = int(cx + rr * np.cos(a))
                y = int(cy + rr * 0.22 * np.sin(a))
                if 0 <= x < W - 2 and 0 <= y < H - 2:
                    img[y:y + 2, x:x + 2] = col
        for k in range(24):     # tekens op de ring
            a = k / 24 * 2 * np.pi
            x = int(cx + 285 * np.cos(a))
            y = int(cy + 285 * 0.22 * np.sin(a))
            img[y - 3:y + 3, x - 2:x + 2] = rgb("19ecf6") if k % 6 == 0 else rgb("ff8af4")
        glitch(img, rnd, 120, 0, H)
    # donkere rand (vignet) onderaan voor de statusvakken
    for y in range(H - 60, H):
        img[y] *= 1 - 0.5 * (y - (H - 60)) / 60
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


# ================================================================ vijanden (vooraanzicht)
MOSS = [hx(c) for c in ("16241a", "1f3324", "2b4630", "3a5c3e", "4f7650", "6c9668")]
FUR = [hx(c) for c in ("2a2522", "3d3631", "544a42", "6e6257", "8a7d70", "a89a8a")]


def _canvas(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, im.load()


def _ellipse(px, w, h, cx, cy, rx, ry, col_fn):
    for y in range(h):
        for x in range(w):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d <= 1.0:
                c = col_fn(x, y, d)
                if c is not None:
                    px[x, y] = c


def _shadow(px, w, h, cx, cy, rx, ry):
    _ellipse(px, w, h, cx, cy, rx, ry, lambda x, y, d: (0, 0, 0, int(120 * (1 - d * 0.6))))


def _outline(im):
    px = im.load()
    w, h = im.size
    src = im.copy().load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0 or src[x, y][3] < 200:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and src[xx, yy][3] >= 250:
                        px[x, y] = OUT
                        break


def make_mosslijm():
    w, h = 80, 56
    body, bp = _canvas(w, h)
    rnd = random.Random(5)

    def slime(x, y, d):
        k = 4 if y < 22 else 3 if y < 34 else 2
        if d > 0.8:
            k -= 1
        if (x * 3 + y * 5) % 7 == 0 and y > 18:
            k -= 1
        return MOSS[max(0, min(5, k))]
    _ellipse(bp, w, h, 40, 44, 32, 30, lambda x, y, d: slime(x, y, d) if y <= 50 else None)
    for _ in range(22):   # mosplukjes bovenop
        x = rnd.randint(16, 63)
        y = rnd.randint(14, 30)
        if bp[x, y][3] == 255:
            bp[x, y] = MOSS[5]
            if y > 0 and bp[x, y - 1][3] == 0:
                bp[x, y - 1] = MOSS[4]
    for ex in (30, 50):   # ogen (kijken naar de camera)
        for yy in range(30, 37):
            for xx in range(ex - 3, ex + 3):
                bp[xx, yy] = hx("0a0d0b")
        bp[ex - 2, 31] = CYA
        bp[ex - 1, 31] = hx("c8feff")
    for xx in range(36, 45):   # mond
        bp[xx, 41] = MOSS[0]
    bp[58, 24] = MAG
    bp[59, 24] = MAG_D
    _outline(body)
    out, op = _canvas(w, h)
    _shadow(op, w, h, 40, 51, 30, 4)
    out.alpha_composite(body)
    return out


def make_moskonijn():
    w, h = 80, 100
    body, bp = _canvas(w, h)
    rnd = random.Random(9)

    def fur(x, y, d):
        k = 3 if d < 0.5 else 2
        if x < 36:
            k += 1
        if (x + y * 2) % 9 == 0:
            k -= 1
        return FUR[max(0, min(5, k))]
    _ellipse(bp, w, h, 40, 72, 22, 22, lambda x, y, d: fur(x, y, d) if y <= 94 else None)   # lijf
    _ellipse(bp, w, h, 40, 44, 17, 15, fur)                                                 # kop
    for ex, tilt in ((32, -2), (48, 2)):                                                     # oren
        _ellipse(bp, w, h, ex + tilt, 18, 5, 16, lambda x, y, d: FUR[4] if d < 0.45 else FUR[2])
    for fx in (28, 52):                                                                      # pootjes
        _ellipse(bp, w, h, fx, 92, 8, 4, lambda x, y, d: FUR[3])
    for _ in range(70):                                                                      # mos in de vacht
        x = rnd.randint(18, 62)
        y = rnd.randint(30, 92)
        if bp[x, y][3] == 255:
            bp[x, y] = MOSS[rnd.choice((2, 3, 4))]
            if x + 1 < w and bp[x + 1, y][3] == 255:
                bp[x + 1, y] = MOSS[3]
    for ex in (33, 47):   # ogen
        for yy in range(40, 46):
            for xx in range(ex - 2, ex + 3):
                bp[xx, yy] = hx("0b0a0a")
        bp[ex - 1, 41] = hx("e8e0d0")
    bp[40, 49] = hx("6a3a3a")   # neus
    bp[39, 49] = hx("6a3a3a")
    for k in range(3):          # varen op de kop
        bp[38 + k, 30 - k] = MOSS[4]
        bp[41 + k, 29 - k] = MOSS[5]
    bp[52, 66] = CYA
    _outline(body)
    out, op = _canvas(w, h)
    _shadow(op, w, h, 40, 95, 26, 4)
    out.alpha_composite(body)
    return out


def main():
    # binnen.png en save_book.png zijn sinds v0.10 echte art van RPG ART (andere indeling
    # dan de oude placeholder hieronder): NIET meer genereren.
    for k, f in (("grass", "gras"), ("sand", "zand"), ("boss", "boss")):
        save(make_bg(k), "art/battle_bg/%s.png" % f)
    save(make_mosslijm(), "art/enemies/mosslijm.png")
    save(make_moskonijn(), "art/enemies/moskonijn.png")


if __name__ == "__main__":
    main()
