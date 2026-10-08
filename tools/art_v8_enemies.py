"""Vijanden voor 'De Vergeten Bibliotheek' (v8), eigen werk. Ze kijken naar links.

Zelfde regels als v7 (tools/art_v7_enemies.py, waarvan we de hulpfuncties gebruiken):
1 art-pixel = 1 pixel op het 768x432-raster, voeten midden onderaan.
v8-wijzigingen (naar de mockup):
  kennis_beest.png  groter (±185 px, de helden zijn ±155) en veel meer boek-detail:
                    vergulde ruggen, bladwijzerlinten, perkamentrollen met schrift om de
                    armen, beschreven bladzijden, losse vellen.
  papiergeest.png   GEEN lief lakengeestje meer maar een kluwen verfrommelde bladzijden met
                    binaire tekst, donkere ogen en een scheurgrijns (zoals in de mockup).
  glitchmot.png     ongewijzigd (v7).
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw

import art_battle as ab
from art_battle import Canvas, lerp, add
import art_v7_enemies as v7
from art_v7_enemies import _book, _digits, _rim, _fragments, _glitch_rows, INK
from art_v7_common import (PAGE, PARCHMENT, BOOK_BROWN, BOOK_RED, BOOK_SLATE, BOOK_GREEN, CORE, WOOD,
                           ARMOR, NEON_MAGENTA, MAGENTA, CYAN, CYAN_HOT, STONE, rgb, ramp)

# warmer dan v7 (de mockup heeft echt bruin leer en vergeeld papier)
PAGE8 = ramp("3c362c", "6a6254", "968c78", "bcb29a", "dcd3bc", "f2ecda")
PARCH8 = ramp("2e2418", "54442e", "7c6844", "a48e62", "c6b282", "e0d0a4")
GILT = ramp("2a1c08", "5a3e12", "8a6420", "b88e34", "dcb456", "f4dc90")
RIBBON = ramp("1e0608", "400c10", "64161a", "8a2226", "ac3634", "cc5448")
COV_BROWN = ramp("1a0e08", "341c10", "52301c", "70442a", "8e5a3a", "ae7850")
COV_RED = ramp("1c080a", "381014", "561c20", "742a2c", "923c3a", "b0544c")
COV_SLATE = ramp("10141a", "1e252e", "2e3742", "404b58", "56626f", "707d8a")
COV_GREEN = ramp("0c140e", "18261a", "263828", "364c38", "4a624a", "627c60")


def _ink_lines(img, color_sets, rnd, density=0.55, step=3):
    """'Handschrift': korte donkere streepjes op de lichte papierpixels."""
    a = np.array(img)
    H, W = a.shape[:2]
    paper = np.zeros((H, W), bool)
    for col in color_sets:
        paper |= np.all(a[..., :3] == np.array(col), axis=-1)
    p = img.load()
    for y in range(1, H - 1, step):
        x = 0
        while x < W - 1:
            if paper[y, x] and rnd.random() < density:
                run = rnd.randint(2, 6)
                for k in range(run):
                    if x + k < W and paper[y, x + k]:
                        p[x + k, y] = PAGE8[1] + (255,)
                x += run + rnd.randint(1, 3)
            else:
                x += 1
    return img


# ================================================================ Het Kennis-Beest
def make_kennis_beest(seed=5):
    rnd = random.Random(seed)
    W, H = 124, 134
    S = 1.38      # past met de voeten op y 90 precies onder de bovenrand (autotest)
    c = Canvas(W, H, S)
    c.ambient = 0.13
    covers = [COV_BROWN, COV_RED, COV_SLATE, COV_GREEN]

    def book(center, w, h, ang, cover, gilt=None, **kw):
        front = _book(c, center, w, h, ang, cover, **kw)
        if gilt is None:
            gilt = min(w, h) >= 9 and rnd.random() < 0.6
        if gilt:   # vergulde bandjes op de rug + titelveldje
            for k in (0.18, 0.82):
                a0 = lerp(front[0], front[1], k)
                a1 = lerp(front[3], front[2], k)
                c.capsule(a0, a1, 0.45, 0.45, GILT, bias=0.15, outline=False)
            mid = lerp(lerp(front[0], front[1], 0.5), lerp(front[3], front[2], 0.5), 0.5)
            c.capsule(lerp(mid, lerp(front[0], front[1], 0.5), 0.5), lerp(mid, lerp(front[3], front[2], 0.5), 0.5),
                      0.6, 0.6, GILT, bias=0.05, outline=False)
        return front

    # --- verre arm: perkamentrol + boekenhand
    c.capsule((90, 56), (100, 76), 6.2, 5.4, PARCH8, bias=-0.16)
    c.capsule((100, 76), (98, 94), 5.4, 4.8, PARCH8, bias=-0.16)
    for t in (0.2, 0.45, 0.7):
        p = lerp((90, 56), (100, 76), t)
        c.crease([add(p, (-6, 1)), add(p, (6, -1))], 0.3, light=False)
    book((98, 100), 13, 9, 80, COV_SLATE, bias=-0.15)
    # --- benen: stapels boeken (meer, scheef)
    for (x, b) in ((80, -0.14), (46, 0.0)):
        for k, (yy, w) in enumerate(((121, 19), (113, 17), (105, 16), (98, 14))):
            book((x + rnd.uniform(-2, 2), yy), w, 7.5, rnd.uniform(-8, 8), covers[(k + int(x)) % 4], bias=b)
    # --- heup: dikke foliant met slot
    f = book((62, 91), 48, 11, -3, COV_BROWN, depth=(3, -2.5))
    c.ellipse(lerp(f[1], f[2], 0.5), 2.2, 2.6, GILT, bias=0.1)
    # --- romp
    c.ellipse((62, 69), 21, 20, CORE, bias=0.05)
    for (cx, cy, w, h, ang, cov) in ((43, 61, 15, 31, -12, COV_RED), (81, 63, 15, 31, 10, COV_SLATE),
                                     (62, 49, 36, 10, 2, COV_BROWN), (62, 84, 32, 9, -4, COV_GREEN),
                                     (48, 80, 12, 14, 18, COV_BROWN), (77, 80, 12, 14, -14, COV_RED)):
        book((cx, cy), w, h, ang, cov)
    # bladwijzerlinten die uit de romp hangen
    for (a, b_) in (((52, 50), (50, 64)), ((70, 50), (73, 62)), ((44, 76), (41, 92))):
        c.capsule(a, b_, 0.9, 0.7, RIBBON, bias=0.05)
    # --- schouders: zware banden + losse vellen
    book((33, 49), 21, 12, -20, COV_SLATE, depth=(2.5, -3))
    book((91, 49), 19, 11, 18, COV_BROWN, depth=(2.5, -3), bias=-0.1)
    book((30, 40), 15, 7, -8, COV_GREEN, depth=(2, -2))
    for (pts, b_) in (([(22, 44), (14, 38), (18, 33), (27, 39)], 0.0), ([(98, 42), (108, 36), (110, 42), (100, 47)], -0.1)):
        c.polygon(pts, PAGE8, curve=0.2, tilt=-0.4, bias=b_)
    # --- hoofd: open boek (V) met waaierende bladzijden
    hx, hy = 60, 35
    c.polygon([(hx, hy + 8), (hx - 19, hy - 6), (hx - 17, hy - 11), (hx, hy + 1)], PAGE8, curve=0.4, tilt=-0.5)
    c.polygon([(hx, hy + 8), (hx + 18, hy - 7), (hx + 16, hy - 12), (hx, hy + 1)], PAGE8, curve=0.4, tilt=-0.5, bias=-0.1)
    for k in range(5):
        a0 = -152 + k * 12
        a1 = -28 - k * 12
        for (a, b_) in ((a0, -0.04), (a1, -0.12)):
            d = ab._dir(a)
            c.polygon([(hx, hy + 2), (hx + d[0] * (19 + k), hy + d[1] * (15 + k) - 2),
                       (hx + d[0] * (17 + k) + 2, hy + d[1] * (13 + k) - 5), (hx + 1, hy)], PAGE8,
                      curve=0.3, tilt=-0.4, bias=b_ + 0.03 * k)
    c.polygon([(hx - 20, hy - 5), (hx, hy + 10), (hx + 19, hy - 6), (hx + 19, hy - 3), (hx, hy + 13), (hx - 20, hy - 2)],
              COV_BROWN, curve=0.3, tilt=0.2)
    c.capsule((hx, hy + 9), (hx + 1, hy + 22), 0.9, 0.7, RIBBON, bias=0.1)           # lint uit het hoofd
    c.ellipse((hx - 1, hy + 4), 6.8, 4.4, INK, bias=0.0)
    # --- nabije arm met boekenhamer; perkament gewikkeld
    c.capsule((36, 54), (26, 70), 6.6, 5.8, PARCH8, bias=0.02)
    c.capsule((26, 70), (24, 84), 5.8, 5.2, PARCH8)
    for t in (0.2, 0.45, 0.7):
        p = lerp((36, 54), (26, 70), t)
        c.crease([add(p, (-6, -1)), add(p, (6, 1))], 0.3, light=False)
    c.crease([(19, 76), (30, 78)], 0.3, light=False)
    c.capsule((32, 100), (12, 57), 2.1, 2.1, WOOD, bias=0.02)
    c.capsule((12, 57), (10, 53), 2.7, 2.7, ARMOR)
    hf = book((12, 45), 23, 17, -24, COV_RED, depth=(3.5, -3), pages="top", gilt=False)
    c.capsule(add(hf[0], (1, 1)), add(hf[3], (1, -1)), 1.3, 1.3, GILT, bias=0.1)
    c.capsule(add(hf[1], (-1, 1)), add(hf[2], (-1, -1)), 1.3, 1.3, GILT, bias=0.1)
    c.ellipse((24, 84), 5.8, 5.4, PARCH8, bias=0.04)
    book((24, 86), 10, 6, 70, COV_BROWN, bias=0.05)
    img = _rim(c.render())
    PW, PH = img.size
    # schrift op bladzijden en perkament
    img = _ink_lines(img, PAGE8[3:] + PARCH8[3:], rnd, density=0.5, step=3)
    arr = np.array(img)
    yy, xx = np.mgrid[0:PH, 0:PW]
    core_mask = (((xx + 0.5) / S - 62) / 16.5) ** 2 + (((yy + 0.5) / S - 69) / 16) ** 2 < 1
    is_core = np.zeros((PH, PW), bool)
    for col in CORE:
        is_core |= np.all(arr[..., :3] == np.array(col), axis=-1)
    _digits(img, int(43 * S), int(54 * S), 14, 6, rnd, [NEON_MAGENTA[3], NEON_MAGENTA[4], NEON_MAGENTA[2]],
            mask=is_core & core_mask, step=4, line=6)
    p = img.load()
    ex, ey = int((hx - 4) * S), int((hy + 3.6) * S)
    for (ox, oy, col) in ((0, 0, CYAN_HOT), (1, 0, CYAN), (8, -1, CYAN_HOT), (9, -1, CYAN), (0, 1, CYAN), (8, 0, CYAN)):
        p[ex + ox, ey + oy] = col + (255,)
    # runenraster op de hamerkop
    hc = (12 * S, 45 * S)
    for i in range(-3, 4):
        for j in range(-2, 3):
            u, v = i * 3.4, j * 3.4
            a = math.radians(-24)
            x = hc[0] + u * math.cos(a) - v * math.sin(a)
            y = hc[1] + u * math.sin(a) + v * math.cos(a)
            if (i + j) % 2 == 0:
                for (ox, oy) in ((0, 0), (1, 0), (0, 1), (1, 1)):
                    xx_, yy_ = int(x) + ox, int(y) + oy
                    if 0 <= xx_ < PW and 0 <= yy_ < PH and p[xx_, yy_][3] > 0:
                        p[xx_, yy_] = (NEON_MAGENTA[3] if (i + j) % 4 == 0 else NEON_MAGENTA[2]) + (255,)
    img = _glitch_rows(img, rnd, 10, 4)
    out = ab.ground_shadow(PW, PH, 62 * S, 127.5 * S, 46 * S, 5.0 * S, alpha=130)
    out.alpha_composite(img)
    _fragments(out, rnd, (62 * S, 6 * S, 118 * S, 58 * S), 46, [INK[0], INK[1], PAGE8[4], PAGE8[3], STONE[6]],
               sizes=(1, 2, 2, 3))
    _fragments(out, rnd, (0, 20 * S, 30 * S, 70 * S), 14, [INK[0], PAGE8[4], MAGENTA])
    d = ImageDraw.Draw(out)
    for (x, y, a) in ((106, 30, 20), (112, 12, -15), (6, 22, 35), (98, 6, 5), (116, 52, 40)):     # losse vellen
        x, y = x * S, y * S
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        q = [(0, 0), (10, 0), (10, 7), (0, 7)]
        pts = [(x + u * ca - v * sa, y + u * sa + v * ca) for u, v in q]
        d.polygon(pts, fill=PAGE8[4] + (255,), outline=PAGE8[1] + (255,))
        for k in (2, 4):
            u0, u1, vv = 2, 8, k
            d.line([(x + u0 * ca - vv * sa, y + u0 * sa + vv * ca), (x + u1 * ca - vv * sa, y + u1 * sa + vv * ca)],
                   fill=PAGE8[1] + (255,))
    return out


# ================================================================ Papiergeest (v8)
def _crumpled_sheet(c, center, w, h, ang, rnd, bias=0.0, rmp=PAGE8):
    """Een verfrommeld vel: onregelmatige veelhoek met kreukels."""
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    # vel = rechthoek met scherpe, verbogen hoeken en een paar knikken in de randen
    hw, hh = w / 2, h / 2
    base = [(-hw, -hh), (0, -hh * rnd.uniform(0.75, 1.1)), (hw, -hh), (hw * rnd.uniform(0.8, 1.1), 0),
            (hw, hh), (0, hh * rnd.uniform(0.8, 1.1)), (-hw, hh), (-hw * rnd.uniform(0.8, 1.1), 0)]
    pts = []
    for (u, v) in base:
        u += rnd.uniform(-1.5, 1.5)
        v += rnd.uniform(-1.5, 1.5)
        pts.append((center[0] + u * ca - v * sa, center[1] + u * sa + v * ca))
    n = len(pts)
    c.polygon(pts, rmp, curve=0.35, tilt=-0.35, bias=bias, vgrad=0.45)
    for i in range(3):                                   # kreukels
        p0 = pts[rnd.randrange(n)]
        p1 = (center[0] + rnd.uniform(-2, 2), center[1] + rnd.uniform(-2, 2))
        c.crease([p0, lerp(p0, p1, 0.6)], 0.22)
    return pts


def make_papiergeest(seed=9):
    rnd = random.Random(seed)
    W, H = 92, 84
    S = 1.0
    c = Canvas(W, H, S)
    c.ambient = 0.16
    # achterste vellen (steken alle kanten op)
    for (cx, cy, w, h, ang, b_) in ((62, 22, 26, 20, 28, -0.16), (22, 26, 22, 18, -30, -0.14),
                                    (72, 50, 22, 18, 62, -0.16), (16, 52, 20, 16, -58, -0.12),
                                    (46, 12, 24, 16, -8, -0.1)):
        _crumpled_sheet(c, (cx, cy), w, h, ang, rnd, b_, PARCH8)
    # de kluwen zelf: veel vellen op elkaar
    for i, (cx, cy, w, h, ang) in enumerate(((44, 46, 46, 40, 4), (32, 32, 28, 22, -24), (58, 34, 28, 20, 26),
                                             (40, 62, 32, 18, -8), (60, 58, 24, 18, 18), (28, 52, 20, 16, -34),
                                             (46, 24, 24, 16, 10), (66, 44, 18, 14, 48))):
        _crumpled_sheet(c, (cx, cy), w, h, ang, rnd, rnd.uniform(-0.06, 0.06), PAGE8 if i % 3 else PARCH8)
    # 'pootjes': opgerolde punten onderaan
    for (x, ang) in ((30, -14), (44, 4), (58, 16)):
        _crumpled_sheet(c, (x, 72), 10, 9, ang, rnd, -0.06)
    # gezicht (naar links): diepe ogen en een gescheurde grijns
    for (ex, ey, rx, ry) in ((30, 40, 4.4, 5.2), (44, 39, 3.8, 4.8)):
        c.ellipse((ex, ey), rx, ry, INK, outline=False)
    mouth = [(24, 52), (30, 57), (38, 59), (46, 57), (52, 52), (46, 54), (38, 55), (30, 54)]
    c.polygon(mouth, INK, curve=0.1, tilt=0.0, outline=False)
    img = _rim(c.render(), 0.25)
    # tanden (papieren puntjes) en glans in de ogen
    p = img.load()
    for x in (29, 33, 37, 41, 45):
        for (ox, oy) in ((0, 0), (1, 0), (0, 1)):
            p[x + ox, 54 + oy + (1 if x in (37,) else 0)] = PAGE8[5] + (255,)
    for (ex, ey) in ((28, 37), (42, 36)):
        p[ex, ey] = (246, 242, 230, 255)
        p[ex + 1, ey] = (200, 196, 186, 255)
    # schrift: binaire code in inkt, plus regels 'handschrift'
    arr = np.array(img)
    paper = np.zeros(arr.shape[:2], bool)
    for col in PAGE8[3:] + PARCH8[3:]:
        paper |= np.all(arr[..., :3] == np.array(col), axis=-1)
    _digits(img, 54, 26, 6, 5, rnd, [PAGE8[1], INK[3], PAGE8[1]], mask=paper, step=4, line=7)
    _digits(img, 12, 60, 4, 2, rnd, [PAGE8[1], INK[3]], mask=paper, step=4, line=7)
    _digits(img, 36, 14, 4, 1, rnd, [INK[3]], mask=paper, step=4, line=7)
    img = _ink_lines(img, PAGE8[3:] + PARCH8[3:], rnd, density=0.25, step=4)
    img = _glitch_rows(img, rnd, 5, 3)
    out = ab.ground_shadow(W, H, 44, 80.5, 24, 2.8, alpha=95)
    out.alpha_composite(img)
    _fragments(out, rnd, (60, 0, 92, 30), 12, [PAGE8[4], INK[0], PAGE8[3]], sizes=(1, 2, 2, 3))
    _fragments(out, rnd, (6, 66, 86, 78), 9, [INK[0], PAGE8[3], CYAN], sizes=(1, 2))
    d = ImageDraw.Draw(out)
    for (x, y, a) in ((80, 8, 25), (6, 10, -20), (84, 32, -35)):        # vellen die eraf waaien
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        q = [(0, 0), (8, 0), (8, 6), (0, 6)]
        pts = [(x + u * ca - v * sa, y + u * sa + v * ca) for u, v in q]
        d.polygon(pts, fill=PAGE8[4] + (255,), outline=PAGE8[1] + (255,))
    return out


def save_all(root):
    import os
    d = os.path.join(root, "assets", "sprites", "enemies")
    os.makedirs(d, exist_ok=True)
    make_kennis_beest().save(os.path.join(d, "kennis_beest.png"))
    make_papiergeest().save(os.path.join(d, "papiergeest.png"))
    v7.make_glitchmot().save(os.path.join(d, "glitchmot.png"))


if __name__ == "__main__":
    import os
    save_all(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
