"""Gevechtsachtergrond 'De Vergeten Bibliotheek' (v7), 1280x432 (getoond op schaal 0.5).

Werkwijze:
  1. Een grote bibliotheekzaal in echt perspectief (één verdwijnpunt): per pixel wordt een
     'straal' geschoten in een doos (vloer, twee boekenwanden, plafond, achterwand).
     Elk vlak heeft een eigen procedurele textuur: stenen tegels, boekenkasten met
     planken en boeken, zuilen, een balkon met balustrade, bogen, en achteraan een
     lichte poort met een roosvenster. Nevel neemt toe met de afstand.
  2. Alles is eerst grijswaarde (0..1) en wordt daarna afgerond naar een vaste grijze
     ramp van 12 tinten (geen blur, geen dithering).
  3. Digitaal verval erboven: zwevende zwarte pixelblokjes, '0101'-fragmenten,
     verschoven glitch-banden, wegvallende boekenplanken, een gescheurde vloerrand
     met binaire 'tekstregels'. Neon (magenta/cyaan) alleen op een paar pixels.
  4. Donkere voorgrond: varens/bladeren en puin (stenen, boeken, losse bladzijden) in de
     hoeken.
De belangrijke strook is het midden (x 256..1024): dat zie je op een 16:9-scherm.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

from art_v7_common import rgb, DIGITS

W, H = 1280, 432
CX, CY = 640.0, 96.0          # verdwijnpunt
F = 540.0                     # brandpuntsafstand (pixels)
CAM_H = 2.1                   # ooghoogte (m)
HALF_W = 4.6                  # halve zaalbreedte (m)
CEIL = 12.5
Z_FAR = 30.0
BAY = 3.6                     # afstand tussen zuilen (m)

# Grijze ramp (12 tinten, iets koel in de schaduw, iets warm in het licht)
GREYS = [rgb(h) for h in ("070709", "0e0e11", "151518", "1d1d21", "26262a", "303034",
                          "3c3c3f", "4a4a4c", "5c5b5b", "71706e", "8c8a86", "aeaba5")]
GREY_TOP = rgb("d2cfc8")
LEAF = [rgb(h) for h in ("07090a", "0d1110", "141a17", "1c241f", "263029", "323d34")]


def _hash(*a):
    """Snelle herhaalbare 'random' per cel (numpy-arrays of getallen)."""
    v = np.zeros_like(np.asarray(a[0], dtype=np.float64))
    for k, x in enumerate(a):
        v = v + np.asarray(x, dtype=np.float64) * (12.9898 + 31.7 * k)
    return np.modf(np.abs(np.sin(v) * 43758.5453))[0]


def _shelves(u, v, seed, lo, hi, shelf_h=0.62):
    """Boekenkast-textuur. u = horizontale coördinaat langs de wand (m), v = hoogte (m)."""
    out = np.full(u.shape, 0.16)
    inside = (v >= lo) & (v < hi)
    row = np.floor((v - lo) / shelf_h)
    fv = (v - lo) / shelf_h - row                    # 0 onder .. 1 boven in een vak
    # boeken: breedte varieert per 'slot'
    bw = 0.13
    slot = np.floor(u / bw + row * 0.37)
    fu = u / bw + row * 0.37 - slot
    r = _hash(slot, row, seed)
    r2 = _hash(slot + 7.0, row * 3.0, seed + 1)
    book_h = 0.62 + 0.3 * r2                         # hoogte als deel van het vak
    is_book = (fv > 0.1) & (fv < 0.1 + book_h * 0.86) & (r > 0.07)
    tone = 0.22 + 0.42 * r                           # elke rug een eigen grijs
    # rug: lichte rand links, donker rechts; twee bandjes
    spine = np.where(fu < 0.18, tone + 0.10, np.where(fu > 0.82, tone - 0.12, tone))
    band = (np.abs(fv - (0.1 + book_h * 0.2)) < 0.035) | (np.abs(fv - (0.1 + book_h * 0.66)) < 0.03)
    spine = np.where(band & (r2 > 0.35), spine + 0.16, spine)
    gap = (fu < 0.06)                                # donkere naad tussen boeken
    val = np.where(is_book, np.where(gap, 0.08, spine), 0.07)   # leeg = donker achterin
    # schuin hangend boek hier en daar
    lean = (r > 0.93) & (fv > 0.1) & (fv < 0.55) & (np.abs(fu - (fv - 0.1) * 1.2) < 0.4)
    val = np.where(lean, tone + 0.05, val)
    # plank (hout, lichte bovenkant)
    board = fv < 0.1
    val = np.where(board, np.where(fv > 0.07, 0.42, 0.24), val)
    out = np.where(inside, val, out)
    return out


def _wall_tex(z, y, side):
    """Zijwand: z = diepte (m), y = hoogte (m)."""
    seed = 3.0 if side < 0 else 11.0
    val = _shelves(z * 1.0, y, seed, 0.45, 4.15)
    upper = _shelves(z * 1.0 + 0.5, y, seed + 5, 5.2, 9.0)
    val = np.where(y >= 5.2, upper, val)
    # plint
    val = np.where(y < 0.45, np.where(y > 0.38, 0.38, 0.2), val)
    # balkon: vloerplaat + balustrade
    slab = (y >= 4.15) & (y < 4.55)
    val = np.where(slab, np.where(y > 4.45, 0.5, 0.3), val)
    rail_zone = (y >= 4.55) & (y < 5.2)
    bal = np.modf(z / 0.28)[0]
    baluster = (bal > 0.35) & (bal < 0.62)
    top_rail = y > 5.08
    val = np.where(rail_zone & (baluster | top_rail), np.where(bal < 0.45, 0.46, 0.3), val)
    # bovenaan: bogen tussen de zuilen + kroonlijst
    bz = np.modf(z / BAY)[0] * BAY                 # 0..BAY binnen een travee
    dx = (bz - BAY / 2) / (BAY / 2 - 0.5)
    arch_top = 9.4 + 1.9 * np.sqrt(np.clip(1 - dx * dx, 0, 1))
    upper_zone = y >= 9.0
    in_arch = upper_zone & (y < arch_top) & (np.abs(dx) < 1)
    val = np.where(upper_zone, 0.3, val)
    val = np.where(in_arch, 0.1 + 0.05 * (y - 9.0), val)
    rim = upper_zone & (np.abs(y - arch_top) < 0.18) & (np.abs(dx) < 1)
    val = np.where(rim, 0.5, val)
    cornice = (y >= 8.95) & (y < 9.2)
    val = np.where(cornice, np.where(y < 9.05, 0.55, 0.26), val)
    # zuilen (pilasters) op elke travee-grens, met groeven
    col = (bz < 0.55) | (bz > BAY - 0.55)
    cz = np.where(bz < 0.55, bz + 0.55, bz - (BAY - 0.55)) / 1.1    # 0..1 over de zuil
    flute = np.modf(cz * 5)[0]
    colval = 0.34 + 0.22 * np.sin(cz * math.pi) * (1 if side > 0 else 1)
    colval = np.where(flute < 0.18, colval - 0.12, colval)
    capital = (y > 8.6) & (y < 9.3)
    base = y < 0.7
    colval = np.where(capital | base, 0.52 - 0.1 * (cz > 0.6), colval)
    val = np.where(col & (y < 12), colval, val)
    return val


def _far_tex(x, y):
    """Achterwand (lichte poort, galerij, roosvenster)."""
    val = _shelves(x + 50, y, 21.0, 0.45, 4.15)
    val = np.where(y >= 5.2, _shelves(x + 51, y, 25.0, 5.2, 9.0), val)
    val = np.where((y >= 4.15) & (y < 4.55), 0.45, val)
    val = np.where(y >= 9.0, 0.3, val)
    # grote boogpoort met licht
    door = (np.abs(x) < 1.7) & ((y < 3.6) | (((x / 1.7) ** 2 + ((y - 3.6) / 1.8) ** 2) < 1))
    frame = (np.abs(x) < 2.1) & ((y < 3.9) | (((x / 2.1) ** 2 + ((y - 3.6) / 2.2) ** 2) < 1)) & ~door
    val = np.where(frame, 0.55, val)
    glow = 0.97 - 0.06 * np.clip(y / 6, 0, 1)
    val = np.where(door, glow, val)
    # verre kasten in de poort (silhouet)
    deep = door & (y < 2.2) & (np.abs(x) > 0.7) & (np.modf(np.abs(x) * 3)[0] > 0.3)
    val = np.where(deep, 0.74, val)
    # roosvenster boven de poort
    rx, ry = x, y - 7.6
    rr = np.sqrt(rx * rx + ry * ry)
    ang = np.arctan2(ry, rx)
    rose = rr < 1.4
    spokes = np.abs(np.modf((ang / (2 * math.pi)) * 12 + 12)[0] - 0.5) > 0.42
    ring = np.abs(rr - 0.8) < 0.08
    val = np.where(rose, np.where(spokes | ring | (rr < 0.3), 0.4, 0.9), val)
    val = np.where((rr >= 1.4) & (rr < 1.6), 0.5, val)
    return val


def _floor_tex(x, z):
    tile = 1.1
    tx, tz = np.floor(x / tile), np.floor(z / tile)
    fx, fz = x / tile - tx, z / tile - tz
    r = _hash(tx, tz, 5.0)
    val = 0.36 + 0.12 * r
    grout = (fx < 0.05) | (fz < 0.05)
    val = np.where(grout, 0.27, val)
    val = np.where((fx > 0.05) & (fx < 0.12) & ~grout, val + 0.06, val)   # licht randje
    # loper in het midden (iets lichter, met rand)
    run = np.abs(x) < 1.4
    val = np.where(run & ~grout, val + 0.04, val)
    val = np.where(np.abs(np.abs(x) - 1.4) < 0.05, 0.24, val)
    # barsten
    crack = (r > 0.82) & (np.abs((fx - 0.5) - (fz - 0.5) * (0.6 + r)) < 0.02)
    val = np.where(crack, 0.14, val)
    return val


def _ceil_tex(x, z):
    bz = np.modf(z / BAY)[0]
    rib = (bz < 0.07) | (bz > 0.93)
    diag = np.abs(np.abs(x) / HALF_W - np.abs(bz - 0.5) * 2) < 0.04
    val = np.where(rib | diag, 0.3, 0.12)
    return val


def render_room():
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float64) + 0.5
    dx = (xs - CX) / F
    dy = -(ys - CY) / F
    INF = 1e9
    best = np.full((H, W), INF)
    val = np.zeros((H, W))
    # vloer en plafond
    with np.errstate(divide="ignore", invalid="ignore"):
        zf = np.where(dy < 0, -CAM_H / dy, INF)
        zc = np.where(dy > 0, (CEIL - CAM_H) / dy, INF)
        zl = np.where(dx < 0, -HALF_W / dx, INF)
        zr = np.where(dx > 0, HALF_W / dx, INF)
    zfar = np.full((H, W), Z_FAR)
    cands = [("vloer", zf), ("plafond", zc), ("links", zl), ("rechts", zr), ("achter", zfar)]
    for name, z in cands:
        z = np.where(z > Z_FAR, INF, z) if name != "achter" else z
        take = z < best
        best = np.where(take, z, best)
    z = best
    x = dx * z
    y = CAM_H + dy * z
    surf = np.full((H, W), 4)
    surf = np.where(np.isclose(z, zl), 2, surf)
    surf = np.where(np.isclose(z, zr), 3, surf)
    surf = np.where(np.isclose(z, zc), 1, surf)
    surf = np.where(np.isclose(z, zf), 0, surf)
    val = np.where(surf == 0, _floor_tex(x, z), val)
    val = np.where(surf == 1, _ceil_tex(x, z), val)
    val = np.where(surf == 2, _wall_tex(z, y, -1), val)
    val = np.where(surf == 3, _wall_tex(z + 2.5, y, 1), val)
    val = np.where(surf == 4, _far_tex(x, y), val)
    # licht: van de poort achteraan (midden), wanden donkerder naar voren toe
    light = 0.55 + 0.45 * np.exp(-((xs - CX) / 420.0) ** 2)
    light *= np.where(surf >= 2, 0.85 + 0.15 * np.clip(z / 30, 0, 1), 1.0)
    val = val * light
    # nevel naar achteren
    fog = 1 - np.exp(-z / 24.0)
    val = val * (1 - fog * 0.75) + 0.66 * fog * 0.75
    # boven donkerder (gewelf in schaduw), lichtbaan op de vloer
    val *= np.clip(0.55 + ys / 260.0, 0, 1)
    pool = np.exp(-(((xs - CX) / 240.0) ** 2) - (((ys - 170) / 50.0) ** 2))
    val += np.where(surf == 0, 0.08 * pool, 0)
    # vooraan wordt de vloer donker (puin en schaduw, zoals de mockup)
    val *= np.clip(1.0 - (ys - 215) / 300.0, 0.32, 1.0)
    return np.clip(val, 0, 1), surf, z


def quantize(val):
    idx = np.clip((val * len(GREYS)).astype(int), 0, len(GREYS) - 1)
    pal = np.array(GREYS, np.uint8)
    img = pal[idx]
    top = val > 0.93
    img[top] = GREY_TOP
    return img


# ---------------------------------------------------------------- digitaal verval
def _px_square(arr, x, y, s, col):
    x, y = int(x), int(y)
    if x >= W or y >= H or x + s <= 0 or y + s <= 0:
        return
    arr[max(0, y):min(H, y + s), max(0, x):min(W, x + s)] = col


def corruption(img, rnd, z, surf, intensity=1.0):
    BLACK = rgb("060608")
    LIGHT = GREYS[10]
    MAG, CY_ = rgb("ff1ee6"), rgb("19ecf6")
    # 1) wegvallende boekenplanken: rechthoekige stukken worden een raster van blokjes
    for k in range(int(10 * intensity)):
        x0 = rnd.choice([rnd.randint(60, 480), rnd.randint(800, 1220)])
        y0 = rnd.randint(10, 150)
        w, h = rnd.randint(30, 90), rnd.randint(20, 60)
        for yy in range(y0, y0 + h, 4):
            for xx in range(x0, x0 + w, 4):
                p = rnd.random()
                edge = min(xx - x0, x0 + w - xx, yy - y0, y0 + h - yy) / 12.0
                if p < 0.55 * min(1, edge + 0.3):
                    _px_square(img, xx, yy, 4, BLACK if p < 0.45 else GREYS[2])
    # 2) zwevende pixelblokjes in zwermen (vooral bovenin het midden, zoals in de mockup)
    swarms = [(640, 40, 160, 60, 90), (560, 90, 60, 40, 30), (760, 80, 90, 50, 40),
              (300, 60, 80, 70, 40), (1000, 50, 90, 80, 45), (180, 170, 60, 40, 25),
              (1110, 150, 80, 60, 30), (470, 20, 60, 30, 25)]
    for (sx, sy, rx, ry, n) in swarms:
        for i in range(int(n * intensity)):
            x = sx + rnd.gauss(0, rx * 0.5)
            y = sy + rnd.gauss(0, ry * 0.5)
            s = rnd.choice([2, 2, 3, 3, 4, 4, 5, 6, 8])
            r = rnd.random()
            col = BLACK if r < 0.72 else (GREYS[9] if r < 0.94 else (MAG if r < 0.97 else CY_))
            _px_square(img, x, y, s, col)
            if s >= 6 and rnd.random() < 0.5:        # holle blokjes
                _px_square(img, x + 1, y + 1, s - 2, GREYS[3])
    # 3) binaire code-fragmenten (rijen '0101', soms als een kolom 'tekst')
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            img[y, x] = c
    blocks = [(590, 10, 6), (690, 26, 4), (1040, 70, 5), (240, 40, 3), (880, 18, 3), (130, 120, 2), (1150, 110, 4)]
    for (bx, by, lines) in blocks:
        for li in range(lines):
            n = rnd.randint(4, 12)
            txt = "".join(rnd.choice("01") for _ in range(n))
            col = GREYS[11] if rnd.random() < 0.6 else GREYS[9]
            if rnd.random() < 0.12:
                col = MAG if rnd.random() < 0.6 else CY_
            ox = bx + rnd.randint(-10, 10)
            # donkere ondergrond (zoals een terminal)
            _px_square(img, ox - 1, by + li * 7 - 1, n * 4 + 1, BLACK) if False else None
            img[max(0, by + li * 7 - 1):by + li * 7 + 6, max(0, ox - 1):ox + n * 4] = BLACK
            for k, ch in enumerate(txt):
                g = DIGITS[ch]
                for gy, row in enumerate(g):
                    for gx, c in enumerate(row):
                        if c == "#":
                            put(ox + k * 4 + gx, by + li * 7 + gy, col)
    # 4) glitch-banden: horizontale stroken verschoven, soms met een neon-randje
    for k in range(int(14 * intensity)):
        y = rnd.randint(4, 260)
        h = rnd.choice([1, 2, 2, 3, 4, 6])
        x0 = rnd.randint(0, W - 200)
        w = rnd.randint(60, 320)
        shift = rnd.choice([-1, 1]) * rnd.randint(6, 28)
        band = img[y:y + h, x0:x0 + w].copy()
        img[y:y + h, max(0, x0 + shift):min(W, x0 + w + shift)] = band[:, :min(W, x0 + w + shift) - max(0, x0 + shift)]
        if rnd.random() < 0.25:
            col = MAG if rnd.random() < 0.5 else CY_
            img[y, x0 + shift:x0 + shift + rnd.randint(4, 20)] = col
        elif rnd.random() < 0.4:
            img[y:y + h, x0:x0 + w] = (img[y:y + h, x0:x0 + w] * 0.55).astype(np.uint8)


def floor_tear(img, rnd, y0=192, y1=214):
    """Gescheurde vloerrand vooraan: blokjes en regels met 'kapotte tekst'."""
    BLACK = rgb("060608")
    for y in range(y0, y1, 5):
        x = rnd.randint(0, 40)
        while x < W:
            if rnd.random() < 0.25:
                x += rnd.randint(20, 90)
                continue
            n = rnd.randint(2, 9)
            gap = rnd.randint(2, 18)
            dens = 0.75 - 0.5 * abs((y - y0) / (y1 - y0) - 0.5)
            if rnd.random() < dens:
                img[y:y + 4, x:x + n * 4] = BLACK
                for k in range(n):        # binaire 'letters' licht op zwart
                    if rnd.random() < 0.7:
                        ch = DIGITS[rnd.choice("01")]
                        for gy in range(3):
                            for gx in range(3):
                                if ch[gy + 1][gx] == "#" and 0 <= x + k * 4 + gx < W:
                                    img[y + gy, x + k * 4 + gx] = GREYS[7]
            x += n * 4 + gap


# ---------------------------------------------------------------- voorgrond
def foreground(img, rnd, overgrown=False):
    im = Image.fromarray(img)
    d = ImageDraw.Draw(im)

    def leaf(x, y, ang, L, wdt, t):
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for i in range(9):
            s = i / 8
            r = math.sin(s * math.pi) * wdt
            pts.append((x + ca * L * s - sa * r, y + sa * L * s + ca * r))
        for i in range(8, -1, -1):
            s = i / 8
            r = -math.sin(s * math.pi) * wdt * 0.8
            pts.append((x + ca * L * s - sa * r, y + sa * L * s + ca * r))
        d.polygon(pts, fill=LEAF[t])
        d.line([(x, y), (x + ca * L * 0.9, y + sa * L * 0.9)], fill=LEAF[max(0, t - 1)], width=1)

    def fern(x, y, size, a0, a1, n):
        for i in range(n):
            a = math.radians(a0 + (a1 - a0) * i / max(1, n - 1)) + rnd.uniform(-0.1, 0.1)
            L = size * rnd.uniform(0.7, 1.0)
            # blaadjes langs de nerf
            for k in range(1, 9):
                s = k / 9
                px, py = x + math.cos(a) * L * s, y + math.sin(a) * L * s
                for side in (-1, 1):
                    leaf(px, py, a + side * 1.0, L * 0.22 * (1 - s * 0.6), 2.4 * (1 - s * 0.5),
                         rnd.choice([2, 3, 3, 4]) if k < 7 else 2)
            d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=LEAF[1], width=2)

    def rock(x, y, w, h, t):
        pts = [(x - w, y), (x - w * 0.8, y - h * 0.7), (x - w * 0.2, y - h), (x + w * 0.6, y - h * 0.85),
               (x + w, y - h * 0.3), (x + w * 0.9, y)]
        d.polygon(pts, fill=GREYS[t])
        d.line(pts[1:4], fill=GREYS[t + 2], width=1)
        d.line([pts[4], pts[5]], fill=GREYS[max(0, t - 2)], width=1)

    def book(x, y, w, h, ang, t):
        ca, sa = math.cos(ang), math.sin(ang)
        q = [(0, 0), (w, 0), (w, -h), (0, -h)]
        pts = [(x + a * ca - b * sa, y + a * sa + b * ca) for a, b in q]
        d.polygon(pts, fill=GREYS[t])
        d.line([pts[0], pts[1]], fill=GREYS[t + 3], width=1)     # bladzijden-rand

    def page(x, y, ang):
        ca, sa = math.cos(ang), math.sin(ang)
        q = [(0, 0), (9, 1), (8, -6), (-1, -5)]
        pts = [(x + a * ca - b * sa, y + a * sa + b * ca) for a, b in q]
        d.polygon(pts, fill=GREYS[9])
        d.line([pts[0], pts[1]], fill=GREYS[7])

    # puin langs de onderkant (tussen de UI door zichtbaar)
    for i in range(46):
        x = rnd.uniform(0, W)
        y = rnd.uniform(300, 432)
        rock(x, y, rnd.uniform(8, 26), rnd.uniform(6, 16), rnd.choice([1, 2, 2, 3]))
    for i in range(18):
        book(rnd.uniform(0, W), rnd.uniform(290, 420), rnd.uniform(14, 24), rnd.uniform(4, 7),
             rnd.uniform(-0.5, 0.5), rnd.choice([2, 3, 4]))
    for i in range(26):
        page(rnd.uniform(0, W), rnd.uniform(250, 420), rnd.uniform(-1, 1))
    # varens in de hoeken (linksonder en rechtsonder) + wat bladeren
    for (x, y, s, a0, a1, n) in ((40, 432, 150, -150, -40, 7), (180, 440, 110, -120, -50, 5),
                                 (1260, 432, 170, -150, -40, 8), (1080, 445, 120, -140, -40, 6),
                                 (940, 440, 90, -130, -60, 4), (380, 450, 80, -130, -50, 4)):
        fern(x, y, s, a0, a1, n)
    if overgrown:
        # klimop die van de kasten hangt
        for i in range(30):
            x = rnd.choice([rnd.uniform(0, 470), rnd.uniform(810, W)])
            y = rnd.uniform(0, 60)
            L = rnd.uniform(40, 150)
            for k in range(int(L / 6)):
                leaf(x + math.sin(k * 0.7 + i) * 3, y + k * 6, math.radians(80 + rnd.uniform(-60, 60)),
                     rnd.uniform(6, 10), 2.6, rnd.choice([2, 3, 4]))
        for (x, y, s, a0, a1, n) in ((560, 440, 100, -140, -40, 5), (760, 440, 90, -140, -40, 5)):
            fern(x, y, s, a0, a1, n)
    return np.array(im)


def make_library(seed=7, overgrown=False):
    rnd = random.Random(seed)
    val, surf, z = render_room()
    if overgrown:
        val = val * 0.86
    img = quantize(val)
    corruption(img, rnd, z, surf, 1.0)
    floor_tear(img, rnd)
    img = foreground(img, rnd, overgrown)
    if overgrown:
        # een vleugje groen-grijs in de schaduwen (ontkleurd)
        f = img.astype(np.int16)
        dark = f.sum(axis=2) < 150
        f[dark, 1] += 4
        img = np.clip(f, 0, 255).astype(np.uint8)
    return Image.fromarray(img, "RGB")


def save_all(root):
    out = os.path.join(root, "assets", "battle")
    os.makedirs(out, exist_ok=True)
    make_library(7).save(os.path.join(out, "bibliotheek.png"))
    make_library(19, overgrown=True).save(os.path.join(out, "bibliotheek_overwoekerd.png"))


if __name__ == "__main__":
    save_all(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
