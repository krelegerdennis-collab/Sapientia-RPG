"""Vijanden voor 'De Vergeten Bibliotheek' (v7), eigen werk. Ze kijken naar links.

Op 2x-resolutie getekend (1 art-pixel = 1 pixel op het 768x432-raster; het spel toont ze
op schaal 0.5). Voeten = midden onderaan, vlak boven de rand (zie battle.gd enemy_feet).
  kennis_beest.png  golem van boeken, perkament en glitchende binaire code, met een
                    boekenhamer. Baasformaat: ±150 px hoog (helden ±110).
  papiergeest.png   geest van losse bladzijden met binaire tekst (±70 px).
  glitchmot.png     vliegende mot met kapotte, glitchende vleugels (±75 px breed).
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw

import art_battle as ab
from art_battle import Canvas, lerp, add, rot_pt
from art_v7_common import (PAGE, PARCHMENT, BOOK_BROWN, BOOK_RED, BOOK_SLATE, BOOK_GREEN, CORE, WOOD,
                           LEATHER, ARMOR, NEON_MAGENTA, NEON_CYAN, MAGENTA, MAGENTA_HOT, CYAN, CYAN_HOT,
                           STONE, DIGITS, rgb, ramp)

INK = ramp("060608", "0c0c0e", "141416", "1c1c1f", "242427", "2e2e31")


def _book(c, center, w, h, ang, cover, depth=(2.6, -2.2), bias=0.0, pages="top"):
    """Een boek als blokje: kaft (voorvlak) + bladzijden (bovenvlak). ang in graden."""
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    def P(u, v):
        return (center[0] + u * ca - v * sa, center[1] + u * sa + v * ca)
    hw, hh = w / 2, h / 2
    front = [P(-hw, -hh), P(hw, -hh), P(hw, hh), P(-hw, hh)]
    dx, dy = depth
    if pages == "top":
        top = [front[0], front[1], add(front[1], (dx, dy)), add(front[0], (dx, dy))]
        side = [front[1], add(front[1], (dx, dy)), add(front[2], (dx, dy)), front[2]]
        c.polygon(side, cover, curve=0.2, tilt=0.0, bias=bias - 0.18)
        c.polygon(top, PAGE, curve=0.15, tilt=-0.6, bias=bias + 0.02)
        # bladzijdenlijntjes
        for k in (0.33, 0.66):
            c.crease([lerp(front[0], front[1], 0.0 + 0.04) if False else lerp(front[0], add(front[0], (dx, dy)), k),
                      lerp(front[1], add(front[1], (dx, dy)), k)], 0.12, light=False)
    c.polygon(front, cover, curve=0.35, tilt=-0.15, bias=bias)
    # rug-bandjes
    for k in (0.2, 0.8):
        c.crease([lerp(front[0], front[3], 0.15) if False else lerp(front[0], front[1], k),
                  lerp(front[3], front[2], k)], -0.18, light=False)
    return front


def _digits(img, x, y, cols, rows, rnd, colors, S=1.0, mask=None, step=4, line=7):
    p = img.load()
    for r in range(rows):
        for k in range(cols):
            if rnd.random() < 0.18:
                continue
            ch = DIGITS[rnd.choice("01")]
            col = rnd.choice(colors)
            for gy in range(5):
                for gx in range(3):
                    if ch[gy][gx] == "#":
                        xx, yy = int(x + k * step + gx), int(y + r * line + gy)
                        if 0 <= xx < img.width and 0 <= yy < img.height:
                            if mask is None or mask[yy, xx]:
                                p[xx, yy] = col + (255,)


def _rim(img, strength=0.3):
    """Randlicht van linksboven (zelfde idee als bij de helden): los van de grijze zaal."""
    a = np.array(img).astype(np.float32)
    al = a[:, :, 3]
    solid = al > 200
    empty = al < 40
    left = np.zeros_like(solid); left[:, 1:] = empty[:, :-1]; left[:, 0] = True
    up = np.zeros_like(solid); up[1:, :] = empty[:-1, :]; up[0, :] = True
    lit = solid & (left | up)
    a[lit, :3] = a[lit, :3] * (1 - strength) + np.array((206, 206, 214), np.float32) * strength
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA").copy()


def _fragments(img, rnd, area, n, colors, sizes=(1, 2, 2, 3, 4)):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = area
    for i in range(n):
        s = rnd.choice(sizes)
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        d.rectangle((int(x), int(y), int(x) + s - 1, int(y) + s - 1), fill=rnd.choice(colors) + (255,))


def _glitch_rows(img, rnd, n, max_shift=5, tint=True):
    a = np.array(img)
    H, W = a.shape[:2]
    for i in range(n):
        y = rnd.randint(0, H - 4)
        h = rnd.choice([1, 1, 2, 3])
        s = rnd.choice([-1, 1]) * rnd.randint(2, max_shift)
        a[y:y + h] = np.roll(a[y:y + h], s, axis=1)
        if tint and rnd.random() < 0.35:
            row = a[y:y + h]
            sel = row[..., 3] > 0
            col = np.array(MAGENTA if rnd.random() < 0.6 else CYAN)
            # alleen een paar pixels aan de rand kleuren (chromatische rand)
            idx = np.argwhere(sel)
            for (yy, xx) in idx[:: max(1, len(idx) // 6)][:6]:
                a[y + yy, xx, :3] = col
    return Image.fromarray(a, "RGBA")


# ================================================================ Het Kennis-Beest
KB_S = 1.2


def make_kennis_beest(seed=5):
    rnd = random.Random(seed)
    W, H = 124, 132
    S = KB_S
    c = Canvas(W, H, S)
    c.ambient = 0.12
    covers = [BOOK_BROWN, BOOK_RED, BOOK_SLATE, BOOK_GREEN]
    # --- verre arm (rechts, achter het lijf): rollen perkament, hand van boekblokjes
    c.capsule((90, 56), (100, 76), 6.0, 5.2, PARCHMENT, bias=-0.16)
    c.capsule((100, 76), (98, 94), 5.2, 4.6, PARCHMENT, bias=-0.16)
    for t in (0.3, 0.6):
        p = lerp((90, 56), (100, 76), t)
        c.crease([add(p, (-5, 1)), add(p, (5, -1))], 0.25, light=False)
    _book(c, (98, 100), 12, 9, 80, BOOK_SLATE, bias=-0.15)
    # --- benen: stapels boeken
    for (x, b) in ((80, -0.14), (46, 0.0)):
        for k, (yy, w) in enumerate(((119, 18), (110, 16), (101, 15))):
            _book(c, (x + rnd.uniform(-1.5, 1.5), yy), w, 8, rnd.uniform(-6, 6), covers[(k + int(x)) % 4], bias=b)
    # --- heup: dikke foliant
    _book(c, (62, 92), 46, 11, -3, BOOK_BROWN, depth=(3, -2.5))
    # --- romp: grote boeken rond een glitch-kern
    core = c.ellipse((62, 70), 20, 19, CORE, bias=0.05)
    for (cx, cy, w, h, ang, cov) in ((44, 62, 14, 30, -12, BOOK_RED), (80, 64, 14, 30, 10, BOOK_SLATE),
                                     (62, 50, 34, 10, 2, BOOK_BROWN), (62, 84, 30, 9, -4, BOOK_GREEN),
                                     (49, 80, 12, 14, 18, BOOK_BROWN), (77, 80, 12, 14, -14, BOOK_RED)):
        _book(c, (cx, cy), w, h, ang, cov)
    # --- schouders: zware banden
    _book(c, (34, 50), 20, 12, -20, BOOK_SLATE, depth=(2.5, -3))
    _book(c, (90, 50), 18, 11, 18, BOOK_BROWN, depth=(2.5, -3), bias=-0.1)
    # --- hoofd: een open boek (V), bladzijden wijd uit
    hx, hy = 60, 36
    c.polygon([(hx, hy + 8), (hx - 18, hy - 6), (hx - 16, hy - 10), (hx, hy + 1)], PAGE, curve=0.4, tilt=-0.5)
    c.polygon([(hx, hy + 8), (hx + 17, hy - 7), (hx + 15, hy - 11), (hx, hy + 1)], PAGE, curve=0.4, tilt=-0.5, bias=-0.1)
    for k in range(4):                                       # waaierende bladzijden
        a0 = -150 + k * 14
        a1 = -30 - k * 13
        for (a, b) in ((a0, -0.04), (a1, -0.12)):
            d = ab._dir(a)
            c.polygon([(hx, hy + 2), (hx + d[0] * (18 + k), hy + d[1] * (14 + k) - 2),
                       (hx + d[0] * (16 + k) + 2, hy + d[1] * (12 + k) - 5), (hx + 1, hy)], PAGE,
                      curve=0.3, tilt=-0.4, bias=b + 0.03 * k)
    c.polygon([(hx - 19, hy - 5), (hx, hy + 10), (hx + 18, hy - 6), (hx + 18, hy - 3), (hx, hy + 13), (hx - 19, hy - 2)],
              BOOK_BROWN, curve=0.3, tilt=0.2)                 # kaft eronder
    c.ellipse((hx - 1, hy + 4), 6.5, 4.2, INK, bias=0.0)          # donkere spleet (gezicht)
    # --- nabije arm (links) met de boekenhamer
    c.capsule((36, 54), (26, 70), 6.4, 5.6, PARCHMENT, bias=0.02)
    c.capsule((26, 70), (24, 84), 5.6, 5.0, PARCHMENT)
    for t in (0.35, 0.7):
        p = lerp((36, 54), (26, 70), t)
        c.crease([add(p, (-5, -1)), add(p, (5, 1))], 0.25, light=False)
    c.crease([(20, 76), (29, 78)], 0.25, light=False)
    # hamer: steel schuin naar linksonder-voor, kop = een groot beslagen boek
    c.capsule((32, 100), (12, 58), 2.0, 2.0, WOOD, bias=0.02)
    c.capsule((12, 58), (10, 54), 2.6, 2.6, ARMOR)
    head_front = _book(c, (12, 46), 22, 16, -24, BOOK_RED, depth=(3.5, -3), pages="top")
    c.capsule(add(head_front[0], (1, 1)), add(head_front[3], (1, -1)), 1.2, 1.2, ARMOR, bias=0.1)
    c.capsule(add(head_front[1], (-1, 1)), add(head_front[2], (-1, -1)), 1.2, 1.2, ARMOR, bias=0.1)
    c.ellipse((24, 84), 5.6, 5.2, PARCHMENT, bias=0.04)            # vuist
    _book(c, (24, 86), 10, 6, 70, BOOK_BROWN, bias=0.05)
    img = _rim(c.render())
    PW, PH = img.size
    # binaire code in de kern (magenta op paars-zwart) + gloeiende ogen
    arr = np.array(img)
    core_mask = np.zeros((PH, PW), bool)
    yy, xx = np.mgrid[0:PH, 0:PW]
    core_mask = (((xx + 0.5) / S - 62) / 15.5) ** 2 + (((yy + 0.5) / S - 70) / 15) ** 2 < 1
    core_mask &= arr[..., 3] > 0
    # alleen waar de kern zichtbaar is (niet onder een boek): kern-tinten herkennen
    core_cols = np.array(CORE)
    is_core = np.zeros((PH, PW), bool)
    for col in core_cols:
        is_core |= np.all(arr[..., :3] == col, axis=-1)
    _digits(img, int(44 * S), int(56 * S), 11, 5, rnd, [NEON_MAGENTA[3], NEON_MAGENTA[4], NEON_MAGENTA[2]],
            mask=is_core & core_mask, step=4, line=6)
    p = img.load()
    ex, ey = int((hx - 4) * S), int((hy + 3.6) * S)
    for (ox, oy, col) in ((0, 0, CYAN_HOT), (1, 0, CYAN), (6, -1, CYAN_HOT), (7, -1, CYAN), (0, 1, CYAN), (6, 0, CYAN)):
        p[ex + ox, ey + oy] = col + (255,)
    # tekst op de hamerkop: magenta raster (zoals een runenpatroon)
    hc = (12 * S, 46 * S)
    for i in range(-3, 4):
        for j in range(-2, 3):
            u, v = i * 3.2, j * 3.2
            a = math.radians(-24)
            x = hc[0] + u * math.cos(a) - v * math.sin(a)
            y = hc[1] + u * math.sin(a) + v * math.cos(a)
            if (i + j) % 2 == 0:
                for (ox, oy) in ((0, 0), (1, 0), (0, 1)):
                    xx_, yy_ = int(x) + ox, int(y) + oy
                    if p[xx_, yy_][3] > 0:
                        p[xx_, yy_] = (NEON_MAGENTA[3] if (i + j) % 4 == 0 else NEON_MAGENTA[2]) + (255,)
    # glitch: verschoven rijen, losse pixels en bladzijden die eraf waaien
    img = _glitch_rows(img, rnd, 9, 4)
    out = ab.ground_shadow(PW, PH, 62 * S, 125.5 * S, 44 * S, 5.0 * S, alpha=130)
    out.alpha_composite(img)
    _fragments(out, rnd, (60 * S, 8 * S, 118 * S, 60 * S), 40, [INK[0], INK[1], PAGE[4], PAGE[3], STONE[6]],
               sizes=(1, 2, 2, 3))
    _fragments(out, rnd, (0, 20 * S, 30 * S, 70 * S), 12, [INK[0], PAGE[4], MAGENTA])
    d = ImageDraw.Draw(out)
    for (x, y, a) in ((104, 30, 20), (110, 14, -15), (8, 22, 35), (98, 8, 5)):       # losse blaadjes
        x, y = x * S, y * S
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        q = [(0, 0), (8, 0), (8, 6), (0, 6)]
        pts = [(x + u * ca - v * sa, y + u * sa + v * ca) for u, v in q]
        d.polygon(pts, fill=PAGE[4] + (255,), outline=PAGE[1] + (255,))
        d.line([pts[0], pts[1]], fill=PAGE[2] + (255,))
    return out


# ================================================================ Papiergeest
def make_papiergeest(seed=9):
    rnd = random.Random(seed)
    W, H = 74, 74
    S = 1.0
    c = Canvas(W, H, S)
    c.ambient = 0.16
    body = [(36, 6), (48, 9), (56, 18), (60, 32), (62, 46), (66, 56), (60, 55), (58, 62), (52, 57), (48, 64),
            (42, 58), (36, 64), (31, 57), (25, 63), (21, 55), (14, 58), (16, 46), (13, 32), (18, 18), (26, 9)]
    # achterste bladzijden (steken uit)
    for (pts, b) in (([(50, 14), (66, 10), (68, 26), (56, 30)], -0.14), ([(16, 22), (6, 30), (10, 42), (20, 38)], -0.1),
                     ([(54, 40), (70, 44), (66, 58), (56, 54)], -0.12)):
        c.polygon(pts, PAGE, curve=0.2, tilt=-0.3, bias=b)
    c.polygon(body, PAGE, curve=0.9, tilt=-0.35, vgrad=0.35)
    # lagen papier: randen van bladzijden
    for (a, b) in (((18, 30), (44, 24)), ((16, 42), (50, 36)), ((20, 50), (58, 46)), ((30, 16), (54, 22))):
        c.crease([a, b], 0.2)
    # gezicht (naar links): grote donkere ogen, scheve grijns
    for (ex, ey, rx, ry) in ((26, 30, 3.6, 4.6), (38, 29, 3.2, 4.2)):
        c.ellipse((ex, ey), rx, ry, INK, outline=False)
    c.crease([(22, 41), (27, 45), (34, 46), (41, 43), (44, 40)], 0.9, light=False, width=2)
    img = _rim(c.render())
    p = img.load()
    for (ex, ey) in ((25, 28), (37, 27)):                       # glinster in de ogen
        p[ex, ey] = (240, 240, 236, 255)
    # tekstregels: binaire code in donkergrijs op het papier
    arr = np.array(img)
    paper = np.zeros(arr.shape[:2], bool)
    for col in PAGE[2:]:
        paper |= np.all(arr[..., :3] == np.array(col), axis=-1)
    _digits(img, 44, 12, 4, 6, rnd, [PAGE[1], PAGE[2], PAGE[1]], mask=paper, step=4, line=7)
    _digits(img, 14, 50, 9, 1, rnd, [PAGE[1], PAGE[2]], mask=paper, step=4, line=7)
    img = _glitch_rows(img, rnd, 4, 3)
    out = ab.ground_shadow(W, H, 40, 71.5, 18, 2.6, alpha=90)
    out.alpha_composite(img)
    _fragments(out, rnd, (52, 0, 74, 30), 10, [PAGE[4], INK[0], PAGE[3]], sizes=(1, 2, 2))
    _fragments(out, rnd, (8, 58, 70, 68), 8, [INK[0], PAGE[3], CYAN], sizes=(1, 2))
    return out


# ================================================================ Glitchmot
def make_glitchmot(seed=13):
    rnd = random.Random(seed)
    W, H = 96, 84
    S = 0.82
    c = Canvas(W, H, S)
    c.ambient = 0.14
    # vleugels van oud, vergeeld papier (lichter dan de zaal, zodat hij goed te zien is),
    # lijf donker
    WING = ramp("27241f", "45403a", "665f55", "8a8274", "aca393", "cbc3b1")
    FUR = ramp("0e0e10", "1a1a1d", "29292d", "3a3a3f", "4f4f55", "68686e")

    def wing(pts, bias):
        c.polygon(pts, WING, curve=0.3, tilt=-0.3, bias=bias)
    # verre vleugels (rechts)
    wing([(54, 34), (80, 6), (94, 12), (90, 30), (70, 42)], -0.16)
    wing([(54, 42), (82, 44), (86, 58), (68, 62), (56, 50)], -0.18)
    # lijf
    c.ellipse((52, 46), 8, 9, FUR)                                    # borststuk
    for k in range(4):                                                # achterlijf
        c.ellipse((60 + k * 5, 52 + k * 3.2), 6 - k * 0.8, 5 - k * 0.6, FUR, bias=-0.04 * k)
    c.ellipse((42, 40), 6.2, 5.8, FUR, bias=0.04)                     # kop
    # voelsprieten (veerachtig)
    for (a, b, bias) in (((40, 35), (28, 16), 0.0), ((44, 34), (40, 12), -0.1)):
        c.capsule(a, b, 0.9, 0.6, FUR, bias=bias)
        for t in (0.3, 0.5, 0.7, 0.9):
            q = lerp(a, b, t)
            c.capsule(q, add(q, (-3, 1.5)), 0.5, 0.4, FUR, bias=bias)
    # nabije vleugels (links, groot)
    wing([(48, 40), (12, 8), (2, 20), (8, 40), (30, 50)], 0.02)
    wing([(48, 48), (16, 54), (14, 70), (32, 74), (46, 58)], -0.04)
    for (a, b) in (((48, 40), (8, 18)), ((46, 42), (6, 36)), ((46, 50), (18, 64)), ((48, 40), (24, 10)),
                   ((54, 36), (86, 12)), ((56, 44), (82, 52))):
        c.crease([a, b], 0.35, light=False)                            # nerven
    # poten
    for (a, b) in (((48, 54), (44, 64)), ((52, 55), (52, 66)), ((56, 55), (60, 64))):
        c.capsule(a, b, 0.8, 0.6, FUR, bias=-0.1)
    img = _rim(c.render())
    p = img.load()
    PW, PH = img.size
    P_ = lambda x, y: (int(x * S), int(y * S))
    # cyaan oogvlekken op de vleugels + magenta ogen
    for (x, y, r) in ((22, 26, 4.2), (26, 62, 3.0), (80, 20, 2.6)):
        cx, cy = x * S, y * S
        rr = r * S
        for yy in range(int(cy - rr) - 1, int(cy + rr) + 2):
            for xx in range(int(cx - rr) - 1, int(cx + rr) + 2):
                dd = math.hypot(xx + 0.5 - cx, yy + 0.5 - cy) / rr
                if dd < 1 and p[xx, yy][3] > 0:
                    p[xx, yy] = (NEON_CYAN[4] if dd < 0.35 else (NEON_CYAN[2] if dd < 0.7 else (10, 10, 12))) + (255,)
    for (ox, oy) in ((0, 0), (1, 0)):
        x, y = P_(38, 39)
        p[x + ox, y + oy] = MAGENTA + (255,)
    # binaire tekst op de vleugels (alleen waar vleugel is)
    mask = img.copy()
    _digits(img, 6, 14, 5, 2, rnd, [INK[0], INK[1]], step=4, line=7)
    _digits(img, 14, 46, 3, 1, rnd, [INK[0]], step=4, line=7)
    a_new = np.array(img); a_old = np.array(mask)
    a_new[a_old[:, :, 3] < 200] = a_old[a_old[:, :, 3] < 200]
    img = Image.fromarray(a_new, "RGBA").copy()
    p = img.load()
    # vleugelranden vallen uiteen in pixelblokjes + verschoven rijen
    img = _glitch_rows(img, rnd, 10, 6)
    out = Image.new("RGBA", (PW, PH + 14), (0, 0, 0, 0))
    sh = ab.ground_shadow(PW, PH + 14, 52 * S, PH + 10.5, 22 * S, 2.6, alpha=80)
    out.alpha_composite(sh)
    out.alpha_composite(img, (0, 0))
    _fragments(out, rnd, (0, 0, 22 * S, 50 * S), 18, [INK[0], WING[3], CYAN, INK[1]], sizes=(1, 2, 2, 3))
    _fragments(out, rnd, (70 * S, 0, 96 * S, 30 * S), 10, [INK[0], WING[4], MAGENTA])
    return out


def save_all(root):
    import os
    d = os.path.join(root, "assets", "sprites", "enemies")
    os.makedirs(d, exist_ok=True)
    make_kennis_beest().save(os.path.join(d, "kennis_beest.png"))
    make_papiergeest().save(os.path.join(d, "papiergeest.png"))
    make_glitchmot().save(os.path.join(d, "glitchmot.png"))


if __name__ == "__main__":
    import os
    save_all(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
