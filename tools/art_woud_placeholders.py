#!/usr/bin/env python3
"""v0.17 PLACEHOLDERS voor het Donker Woud en Esdoorn (gegenereerd in code, GEEN handwerk).

RPG ART tekent de echte art (forest-tegelset, gevechtsachtergrond, 3 bosmonsters + de baas
De Wortelkoning, 'Noor in wortelcocon'). Tot die er is maakt dit script duidelijk gemarkeerde
placeholders OP DE DEFINITIEVE BESTANDSNAMEN, zodat de echte art er later 1-op-1 overheen kan
(zelfde naam, zelfde maat; daarna de naam in tools/handwerk.txt zetten). Overzicht van alle
slots: /workspace/v17_ART_SLOTS.md en docs/HANDOFF_WOUD.md.

Markering: losse sprites (vijanden, map-sprites, cocon, iconen) krijgen magenta hoekjes
(zelfde conventie als tools/art_map_monsters.py); de gevechtsachtergrond magenta hoekhaken.
De tegelset is een gewone volle atlas (geen markering in beeld), maar staat in
tools/placeholders_v17.txt.

Veiligheid: een bestand dat in tools/handwerk.txt staat wordt NOOIT overschreven (dus zodra
de echte art erin staat, kan dit script veilig opnieuw draaien). Bestaande niet-handwerk
bestanden worden wel opnieuw gemaakt.
Gebruik:  python3 tools/art_woud_placeholders.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)

# ------------------------------------------------------------------ palet
INK = (12, 14, 12, 255)
SOIL = [(14, 18, 14), (20, 26, 19), (26, 33, 24), (33, 42, 30), (42, 54, 37)]
MOSS = [(30, 46, 30), (40, 62, 38), (54, 80, 46), (72, 102, 58)]
LEAF = [(8, 14, 11), (13, 23, 17), (19, 33, 24), (27, 45, 32), (38, 60, 42), (52, 78, 54)]
BARK = [(18, 14, 12), (28, 22, 18), (40, 31, 24), (54, 42, 32), (70, 56, 42), (88, 72, 54)]
MIST = [(84, 98, 96), (112, 126, 122), (146, 158, 152), (186, 196, 188)]
CAP = [(92, 70, 74), (138, 98, 104), (176, 134, 138), (214, 186, 176)]
MAG = [(70, 8, 64), (138, 12, 132), (200, 22, 182), (255, 30, 230), (255, 120, 240)]
CYA = [(8, 60, 66), (8, 112, 122), (60, 170, 176), (117, 196, 196), (170, 236, 236)]
HAIR = [(150, 118, 52), (204, 170, 84), (236, 210, 128), (250, 236, 180)]   # Noor: blond
SKIN = [(150, 104, 84), (204, 156, 128), (232, 194, 166)]
MARK = (255, 30, 230, 255)


def handwerk():
    out = set()
    for line in open(P("tools", "handwerk.txt"), encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            out.add(line)
    return out


HW = handwerk()
WRITTEN = []


def save(im, rel):
    if rel in HW:
        print("OVERGESLAGEN (handwerk):", rel)
        return
    os.makedirs(os.path.dirname(P(rel)), exist_ok=True)
    im.save(P(rel))
    WRITTEN.append((rel, im.size))
    print("geschreven:", rel, im.size)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def mark_corners(im, n=3):
    """Magenta hoekjes = placeholder (zoals tools/art_map_monsters.py)."""
    w, h = im.size
    px = im.load()
    for i in range(n):
        for (x, y) in [(i, 0), (0, i), (w - 1 - i, 0), (w - 1, i), (i, h - 1), (0, h - 1 - i),
                       (w - 1 - i, h - 1), (w - 1, h - 1 - i)]:
            px[x, y] = MARK


def outline(im, col=INK):
    """1px donkere rand rond alle dekkende pixels (buitenkant)."""
    w, h = im.size
    src = im.copy().load()
    px = im.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] == 255:
                    px[x, y] = col
                    break


# ================================================================== tegelset (256x80)
T = 16
R = random.Random(1717)


def new_tile(c=(0, 0, 0)):
    return Image.new("RGBA", (T, T), rgba(c))


def floor(seed, dark=0):
    r = random.Random(seed)
    t = new_tile(SOIL[2 - dark if dark < 2 else 0])
    px = t.load()
    for y in range(T):
        for x in range(T):
            v = r.random()
            if v < 0.18:
                px[x, y] = rgba(SOIL[max(0, 1 - dark)])
            elif v < 0.30:
                px[x, y] = rgba(SOIL[min(4, 3 - dark)])
            elif v < 0.34:
                px[x, y] = rgba(MOSS[max(0, 1 - dark)])
    # paar mosplukjes
    for _ in range(2):
        cx, cy = r.randrange(2, 14), r.randrange(2, 14)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0)):
            px[(cx + dx) % T, (cy + dy) % T] = rgba(MOSS[max(0, 2 - dark)])
    return t


def shade(t, rows=(), cols=(), k=0.55):
    px = t.load()
    for y in range(T):
        for x in range(T):
            f = 1.0
            if y in rows:
                f *= k + (1 - k) * (rows.index(y) / max(1, len(rows)))
            if x in cols:
                f *= k + (1 - k) * (cols.index(x) / max(1, len(cols)))
            if f < 1.0:
                c = px[x, y]
                px[x, y] = (int(c[0] * f), int(c[1] * f), int(c[2] * f), 255)
    return t


def canopy(seed, open_sides="", corner=""):
    """Bladerdak (muurtop). open_sides: N/E/S/W kant grenst aan vloer -> lichte rand.
    corner: NW/NE/SW/SE = alleen dat hoekje open (binnenhoek)."""
    r = random.Random(seed)
    t = new_tile(LEAF[0])
    d = ImageDraw.Draw(t)
    for _ in range(9):
        cx, cy = r.randrange(-2, 18), r.randrange(-2, 18)
        rad = r.randrange(3, 6)
        d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=rgba(LEAF[r.choice([1, 1, 2])]))
        d.point([(cx - 1, cy - 2), (cx, cy - 2), (cx - 2, cy - 1)], fill=rgba(LEAF[3]))
    px = t.load()
    def rim(x, y):
        px[x, y] = rgba(LEAF[4] if (x + y) % 3 else LEAF[5])
    for s in open_sides:
        for i in range(T):
            j = 1 if r.random() < 0.4 else 0
            if s == "N":
                rim(i, 0); px[i, 1 + j] = rgba(LEAF[3])
            if s == "S":
                rim(i, T - 1); px[i, T - 2 - j] = rgba(LEAF[3])
            if s == "W":
                rim(0, i); px[1 + j, i] = rgba(LEAF[3])
            if s == "E":
                rim(T - 1, i); px[T - 2 - j, i] = rgba(LEAF[3])
    if corner:
        x0 = 0 if "W" in corner else T - 3
        y0 = 0 if "N" in corner else T - 3
        for y in range(y0, y0 + 3):
            for x in range(x0, x0 + 3):
                rim(x, y)
    return t


def trunks(part, seed, end="", glitch=False, moss=False):
    """Muurvoorkant = rij boomstammen. part 'top' (onder het bladerdak) of 'bot' (wortels)."""
    r = random.Random(seed)
    t = new_tile(BARK[0])
    px = t.load()
    d = ImageDraw.Draw(t)
    # stammen: 2 per tegel
    for x0, w in ((1, 6), (9, 6)):
        if end == "L" and x0 == 1:
            continue
        if end == "R" and x0 == 9:
            continue
        for x in range(x0, x0 + w):
            for y in range(T):
                k = 2 + (1 if x == x0 + 1 else 0) + (1 if x == x0 + 2 else 0) - (1 if x == x0 + w - 1 else 0)
                if r.random() < 0.12:
                    k -= 1
                px[x, y] = rgba(BARK[max(0, min(5, k))])
        for _ in range(3):
            yy = r.randrange(0, T)
            d.line([(x0 + 1, yy), (x0 + w - 2, yy)], fill=rgba(BARK[1]))
    if part == "top":
        for y in range(4):
            for x in range(T):
                c = px[x, y]
                f = 0.35 + 0.16 * y
                px[x, y] = (int(c[0] * f), int(c[1] * f), int(c[2] * f), 255)
        for x in range(T):
            if r.random() < 0.5:
                px[x, 0] = rgba(LEAF[2])
    else:
        # wortels naar de vloer
        for y in range(12, T):
            for x in range(T):
                if px[x, y][:3] == BARK[0]:
                    px[x, y] = rgba(SOIL[1])
        for _ in range(4):
            x = r.randrange(0, T)
            d.line([(x, 10), (x + r.choice([-3, -2, 2, 3]), 15)], fill=rgba(BARK[3]))
    if moss:
        for _ in range(10):
            x, y = r.randrange(0, T), r.randrange(4 if part == "top" else 0, T)
            px[x, y] = rgba(CYA[1] if r.random() < 0.35 else MOSS[2])
        px[r.randrange(2, 14), r.randrange(6, 14)] = rgba(CYA[3])
    if glitch:
        x = r.randrange(4, 12)
        for y in range(T):
            if r.random() < 0.7:
                px[x, y] = rgba(MAG[3] if y % 3 else MAG[4])
                if r.random() < 0.3:
                    px[(x + 1) % T, y] = rgba(MAG[1])
    if end:
        cols = list(range(0, 3)) if end == "L" else list(range(T - 1, T - 4, -1))
        for i, x in enumerate(cols):
            for y in range(T):
                c = px[x, y]
                f = 0.35 + 0.2 * i
                px[x, y] = (int(c[0] * f), int(c[1] * f), int(c[2] * f), 255)
    return t


def hollow(part, seed):
    t = trunks(part, seed)
    d = ImageDraw.Draw(t)
    if part == "top":
        d.ellipse([4, 6, 11, 17], fill=rgba((4, 5, 4)))
        d.point([(6, 10), (9, 10)], fill=rgba(MAG[3]))   # ogen in de holte
    else:
        d.rectangle([4, 0, 11, 7], fill=rgba((4, 5, 4)))
        d.ellipse([4, -4, 11, 9], fill=rgba((4, 5, 4)))
    return t


def path_tile(seed, light=True):
    t = floor(seed)
    px = t.load()
    r = random.Random(seed + 9)
    for y in range(T):
        for x in range(4, 12):
            if r.random() < 0.8:
                px[x, y] = rgba(BARK[4] if r.random() < 0.3 else BARK[3]) if light else rgba(SOIL[3])
    return t


def decor(base, kind, seed):
    r = random.Random(seed)
    t = base.copy()
    d = ImageDraw.Draw(t)
    px = t.load()
    if kind == "fern":
        for a in range(-60, 61, 30):
            x2 = 8 + int(6 * math.sin(math.radians(a)))
            y2 = 12 - int(7 * math.cos(math.radians(a)))
            d.line([(8, 13), (x2, y2)], fill=rgba(MOSS[2]))
            px[x2, y2] = rgba(MOSS[3])
    elif kind == "roots":
        for _ in range(3):
            pts = [(r.randrange(0, 4), r.randrange(0, T))]
            for _ in range(4):
                pts.append((pts[-1][0] + r.randrange(3, 6), max(0, min(15, pts[-1][1] + r.randrange(-3, 4)))))
            d.line(pts, fill=rgba(BARK[3]))
            d.line([(x, y - 1) for x, y in pts], fill=rgba(BARK[5]))
    elif kind == "leaves":
        for _ in range(9):
            x, y = r.randrange(1, 15), r.randrange(1, 15)
            c = r.choice([(96, 64, 36), (120, 82, 40), (72, 50, 32), (110, 46, 52)])
            px[x, y] = rgba(c); px[x + 1, y] = rgba(c)
    elif kind == "shrooms":
        for _ in range(3):
            x, y = r.randrange(3, 13), r.randrange(6, 14)
            d.line([(x, y), (x, y - 2)], fill=rgba(CAP[3]))
            d.line([(x - 1, y - 3), (x + 1, y - 3)], fill=rgba(CAP[1]))
            px[x, y - 4] = rgba(CAP[2])
    elif kind == "ring":
        for i in range(10):
            a = i * 36
            x = 8 + int(5 * math.cos(math.radians(a)))
            y = 8 + int(4 * math.sin(math.radians(a)))
            px[x, y] = rgba(CAP[2]); px[x, y - 1] = rgba(MAG[2] if i % 3 == 0 else CAP[1])
    elif kind == "rune":
        d.ellipse([3, 3, 12, 12], outline=rgba(CYA[1]))
        d.line([(8, 4), (8, 11)], fill=rgba(CYA[2]))
        d.line([(5, 8), (11, 8)], fill=rgba(CYA[1]))
        px[8, 8] = rgba(CYA[4])
    elif kind == "glitch":
        y = r.randrange(5, 11)
        for x in range(2, 14):
            if r.random() < 0.8:
                px[x, y + (1 if x % 4 == 0 else 0)] = rgba(MAG[3])
        px[7, y - 1] = rgba(MAG[4]); px[11, y + 1] = rgba(CYA[3])
        for _ in range(3):
            px[r.randrange(0, 16), r.randrange(0, 16)] = rgba((0, 0, 0))
    return t


def solid_decor(kind, seed):
    t = floor(seed)
    d = ImageDraw.Draw(t)
    if kind == "boulder":
        d.ellipse([1, 4, 14, 15], fill=rgba(MIST[0]), outline=rgba(INK))
        d.ellipse([3, 5, 10, 10], fill=rgba(MIST[1]))
        d.point([(5, 7), (6, 6)], fill=rgba(MIST[2]))
        d.line([(3, 12), (12, 12)], fill=rgba(MOSS[2]))
    elif kind == "log":
        d.rectangle([0, 6, 15, 13], fill=rgba(BARK[3]), outline=rgba(INK))
        d.line([(1, 7), (14, 7)], fill=rgba(BARK[5]))
        d.ellipse([11, 6, 15, 13], fill=rgba(BARK[4]), outline=rgba(INK))
        d.point([(13, 9)], fill=rgba(BARK[1]))
        d.point([(4, 6), (7, 5)], fill=rgba(MOSS[3]))
    elif kind == "bigshroom":
        for x, y, s in ((5, 14, 4), (11, 13, 3), (8, 9, 5)):
            d.line([(x, y), (x, y - s)], fill=rgba(CAP[3]))
            d.ellipse([x - s, y - s - 3, x + s, y - s + 1], fill=rgba(CAP[1]), outline=rgba(INK))
            d.point([(x - 1, y - s - 2)], fill=rgba(MAG[3]))
    elif kind == "stump":
        d.ellipse([2, 3, 13, 9], fill=rgba(BARK[4]), outline=rgba(INK))
        d.rectangle([2, 6, 13, 14], fill=rgba(BARK[2]))
        d.ellipse([2, 3, 13, 9], fill=rgba(BARK[4]), outline=rgba(INK))
        d.ellipse([5, 5, 10, 7], outline=rgba(BARK[2]))
        d.line([(2, 6), (2, 14)], fill=rgba(INK)); d.line([(13, 6), (13, 14)], fill=rgba(INK))
    return t


def mound(edge, seed):
    """Platform 48-56: verhoogde wortelheuvel (open plek van de baas)."""
    r = random.Random(seed)
    t = new_tile(MOSS[0])
    px = t.load()
    for y in range(T):
        for x in range(T):
            v = r.random()
            if v < 0.2:
                px[x, y] = rgba(MOSS[1])
            elif v < 0.24:
                px[x, y] = rgba(BARK[3])
    d = ImageDraw.Draw(t)
    if "N" in edge:
        d.line([(0, 0), (15, 0)], fill=rgba(MOSS[3]))
    if "W" in edge:
        d.line([(0, 0), (0, 15)], fill=rgba(MOSS[2]))
    if "E" in edge:
        d.line([(15, 0), (15, 15)], fill=rgba(LEAF[1]))
    if "S" in edge:     # richel (solid): wortels hangen naar beneden
        for y in range(8, T):
            for x in range(T):
                px[x, y] = rgba(BARK[1] if (x + y) % 5 else BARK[2])
        for x in range(0, T, 3):
            d.line([(x, 8), (x + 1, 15)], fill=rgba(BARK[3]))
        d.line([(0, 8), (15, 8)], fill=rgba(MOSS[2]))
    return t


def build_tiles():
    atlas = Image.new("RGBA", (256, 80), (0, 0, 0, 255))
    def put(n, t):
        atlas.paste(t, ((n % 16) * T, (n // 16) * T))
    put(0, floor(1)); put(1, floor(2)); put(2, floor(3))
    put(3, decor(floor(4), "fern", 4))
    put(4, decor(floor(5), "roots", 5))
    put(5, decor(floor(6), "leaves", 6))
    put(6, decor(floor(7), "shrooms", 7))
    put(7, decor(floor(8), "ring", 8))
    put(8, shade(floor(9), rows=[0, 1, 2, 3]))
    put(9, shade(floor(10), cols=[0, 1, 2]))
    put(10, shade(floor(11), rows=[0, 1, 2, 3], cols=[0, 1, 2]))
    put(11, decor(floor(12), "rune", 12))
    put(12, solid_decor("stump", 13))
    put(13, new_tile((2, 3, 2)))
    e = floor(14); ImageDraw.Draw(e).rectangle([0, 9, 15, 15], fill=rgba((2, 3, 2))); put(14, e)
    put(15, decor(floor(15), "glitch", 15))
    tops = {16: ("NW", ""), 17: ("N", ""), 18: ("NE", ""), 19: ("W", ""), 20: ("", ""), 21: ("E", ""),
            22: ("SW", ""), 23: ("S", ""), 24: ("SE", ""), 25: ("", "NW"), 26: ("", "NE"), 27: ("", "SW"), 28: ("", "SE")}
    for n, (s, c) in tops.items():
        put(n, canopy(100 + n, s, c))
    put(29, trunks("bot", 29, end="R"))
    put(30, path_tile(30))
    put(31, trunks("bot", 31, end="L"))
    put(32, trunks("top", 32)); put(33, trunks("bot", 33))
    put(34, trunks("top", 34, end="L")); put(35, trunks("bot", 35, end="L"))
    put(36, trunks("top", 36, end="R")); put(37, trunks("bot", 37, end="R"))
    put(38, trunks("top", 38, glitch=True)); put(39, trunks("bot", 39, glitch=True))
    put(40, hollow("top", 40)); put(41, hollow("bot", 41))
    a = trunks("top", 42); ImageDraw.Draw(a).rectangle([4, 6, 11, 15], fill=rgba((6, 8, 6))); put(42, a)
    b = path_tile(43, light=False)
    bd = ImageDraw.Draw(b)
    bd.rectangle([0, 0, 2, 15], fill=rgba(BARK[2])); bd.rectangle([13, 0, 15, 15], fill=rgba(BARK[2]))
    put(43, b)
    for n, part in ((44, "top"), (45, "bot")):
        v = trunks(part, n)
        vd = ImageDraw.Draw(v)
        vd.line([(6, 0), (6, 15)], fill=rgba(MOSS[2])); vd.line([(9, 0), (9, 15)], fill=rgba(MOSS[2]))
        for y in range(1, 16, 3):
            vd.line([(6, y), (9, y)], fill=rgba(MOSS[3]))
        put(n, v)
    put(46, trunks("top", 46, moss=True)); put(47, trunks("bot", 47, moss=True))
    for n, edge in ((48, "NW"), (49, "N"), (50, "NE"), (51, "W"), (52, ""), (53, "E"), (54, "SW"), (55, "S"), (56, "SE")):
        put(n, mound(edge, n))
    st = mound("S", 57)
    sd = ImageDraw.Draw(st)
    for y in (9, 12):
        sd.rectangle([3, y, 12, y + 2], fill=rgba(BARK[4]), outline=rgba(INK))
    put(57, st)
    h = floor(58); hd = ImageDraw.Draw(h)
    hd.ellipse([2, 3, 13, 13], fill=rgba((3, 3, 3)), outline=rgba(BARK[3]))
    hd.line([(4, 4), (2, 1)], fill=rgba(BARK[4])); hd.line([(11, 4), (14, 1)], fill=rgba(BARK[4]))
    put(58, h)
    put(59, solid_decor("boulder", 59))
    put(60, solid_decor("log", 60))
    put(61, solid_decor("bigshroom", 61))
    for n in (62, 63):
        g = mound("", n); gd = ImageDraw.Draw(g)
        if n == 62:
            gd.arc([4, 2, 27, 13], 90, 270, fill=rgba(MAG[2]))
        else:
            gd.arc([-12, 2, 11, 13], 270, 90, fill=rgba(MAG[2]))
        put(n, g)
    o = floor(64)
    op = o.load()
    for y in range(T):
        for x in range(T):
            c = op[x, y]
            f = max(0.0, 1.0 - y / 15.0)
            op[x, y] = (int(c[0] * f), int(c[1] * f), int(c[2] * f), 255)
    put(64, o)
    for n in range(65, 80):
        put(n, canopy(300 + n, "", ""))
    save(atlas, "assets/tiles/dungeon/donker_woud_tiles.png")


# ================================================================== gevechtsachtergrond
def build_backdrop():
    W, H = 1280, 432
    r = random.Random(4242)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    px = im.load()
    horizon = 250
    for y in range(H):
        if y < horizon:
            k = y / horizon
            c = (int(10 + 14 * k), int(18 + 26 * k), int(20 + 20 * k))
        else:
            k = (y - horizon) / (H - horizon)
            c = (int(16 + 10 * k), int(22 + 12 * k), int(17 + 8 * k))
        for x in range(W):
            px[x, y] = (*c, 255)
    d = ImageDraw.Draw(im)
    # 3 lagen boomsilhouetten met mist ertussen
    for layer, (col, base, hmin, hmax, step) in enumerate([
            ((14, 24, 22), horizon - 10, 120, 200, 22),
            ((10, 18, 15), horizon + 5, 150, 240, 34),
            ((6, 11, 9), horizon + 20, 190, 260, 54)]):
        x = -20
        while x < W + 20:
            hgt = r.randrange(hmin, hmax)
            w = r.randrange(step // 2, step)
            d.rectangle([x + w // 2 - 3 - layer, base - hgt // 2, x + w // 2 + 3 + layer, base], fill=(*col, 255))
            d.polygon([(x, base - hgt // 3), (x + w // 2, base - hgt), (x + w, base - hgt // 3)], fill=(*col, 255))
            d.ellipse([x - 6, base - hgt + 10, x + w + 6, base - hgt // 3 + 20], fill=(*col, 255))
            x += w
        # mistband
        my = base - 30 + layer * 18
        for y in range(my - 14, my + 14):
            a = 1.0 - abs(y - my) / 14.0
            for x in range(0, W):
                if 0 <= y < H:
                    c = px[x, y]
                    m = MIST[1]
                    f = 0.10 * a * (0.7 + 0.3 * math.sin(x / 37.0 + layer))
                    px[x, y] = (int(c[0] + (m[0] - c[0]) * f), int(c[1] + (m[1] - c[1]) * f), int(c[2] + (m[2] - c[2]) * f), 255)
    # grond: wortels en paddenstoelen
    for _ in range(60):
        x0, y0 = r.randrange(0, W), r.randrange(horizon + 10, H)
        pts = [(x0, y0)]
        for _ in range(6):
            pts.append((pts[-1][0] + r.randrange(-30, 31), pts[-1][1] + r.randrange(-4, 8)))
        d.line(pts, fill=(*BARK[2], 255), width=r.choice([2, 3, 4]))
    for _ in range(40):
        x, y = r.randrange(0, W), r.randrange(horizon + 20, H - 4)
        s = r.randrange(3, 9)
        d.line([(x, y), (x, y - s)], fill=(*CAP[2], 255), width=2)
        d.ellipse([x - s, y - s - 4, x + s, y - s + 2], fill=(*CAP[1], 255))
        if r.random() < 0.3:
            d.point([(x - 1, y - s - 2)], fill=(*MAG[3], 255))
    # open plek (waar de vijanden staan): iets lichter, ronde vlek
    cx, cy = 800, 350
    for y in range(cy - 50, cy + 50):
        for x in range(cx - 260, cx + 260):
            if 0 <= x < W and 0 <= y < H:
                dd = ((x - cx) / 260.0) ** 2 + ((y - cy) / 50.0) ** 2
                if dd < 1:
                    c = px[x, y]
                    f = 0.25 * (1 - dd)
                    px[x, y] = (int(c[0] + 30 * f), int(c[1] + 40 * f), int(c[2] + 26 * f), 255)
    # grote voorgrondstammen
    for x0, w in ((0, 70), (1180, 100)):
        d.rectangle([x0, 0, x0 + w, H], fill=(*BARK[1], 255))
        for x in range(x0, x0 + w, 6):
            d.line([(x, 0), (x + 2, H)], fill=(*BARK[2], 255))
        d.polygon([(x0 - 20, H), (x0 + w // 2, H - 60), (x0 + w + 30, H)], fill=(*BARK[1], 255))
    # digitaal verval: zwarte pixelblokjes en een paar glitch-banden
    for _ in range(70):
        x, y = r.randrange(0, W), r.randrange(0, H)
        s = r.choice([2, 4, 6])
        d.rectangle([x, y, x + s, y + s], fill=(0, 0, 0, 255))
    for _ in range(5):
        y = r.randrange(20, H - 20)
        sh = r.randrange(-12, 13)
        band = im.crop((0, y, W, y + 3))
        im.paste(band, (sh, y))
        gx = r.randrange(0, W - 120)
        d.line([(gx, y), (gx + r.randrange(20, 120), y)], fill=(*MAG[2], 255))
    for _ in range(30):
        d.point([(r.randrange(0, W), r.randrange(0, horizon))], fill=(*(CYA[3] if r.random() < 0.5 else MAG[3]), 255))
    # placeholder-markering: magenta hoekhaken
    for (x, y, sx, sy) in ((4, 4, 1, 1), (W - 5, 4, -1, 1), (4, H - 5, 1, -1), (W - 5, H - 5, -1, -1)):
        d.line([(x, y), (x + 24 * sx, y)], fill=MARK, width=3)
        d.line([(x, y), (x, y + 24 * sy)], fill=MARK, width=3)
    save(im.convert("RGB"), "assets/battle/donker_woud.png")


# ================================================================== vijanden (vooraanzicht + rug)
def eyes(d, pts, col=MAG[3], r=2):
    for (x, y) in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=rgba(col))
        d.point([(x - 1, y - 1)], fill=rgba(MAG[4] if col == MAG[3] else (255, 255, 255)))


def creature(kind, back=False):
    if kind == "wortelkruiper":
        W, H = 104, 84
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        r = random.Random(11)
        # poten van wortels
        for i in range(6):
            x = 14 + i * 15
            d.line([(x + 6, 48), (x - 6 + r.randrange(-4, 5), H - 4)], fill=rgba(BARK[3]), width=5)
            d.line([(x + 6, 48), (x - 6, H - 4)], fill=rgba(BARK[4]), width=2)
        d.ellipse([12, 16, 92, 64], fill=rgba(BARK[2]))
        d.ellipse([18, 18, 84, 50], fill=rgba(BARK[3]))
        for i in range(7):
            d.line([(20 + i * 10, 22), (26 + i * 10, 46)], fill=rgba(BARK[1]), width=2)
        d.ellipse([28, 10, 54, 30], fill=rgba(MOSS[1]))
        d.ellipse([56, 12, 80, 30], fill=rgba(MOSS[2]))
        if not back:
            d.ellipse([30, 34, 74, 58], fill=rgba((10, 8, 8)))
            eyes(d, [(42, 42), (62, 42)], r=3)
            for x in range(36, 70, 6):
                d.polygon([(x, 52), (x + 3, 58), (x + 6, 52)], fill=rgba(CAP[3]))
        else:
            d.line([(52, 20), (52, 58)], fill=rgba(BARK[1]), width=3)
            d.point([(40, 30), (66, 28)], fill=rgba(CYA[2]))
    elif kind == "mistuil":
        W, H = 88, 104
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.ellipse([14, 28, 74, 96], fill=rgba(MIST[1]))
        d.ellipse([18, 8, 70, 54], fill=rgba(MIST[1]))
        d.polygon([(20, 14), (24, 0), (34, 12)], fill=rgba(MIST[0]))
        d.polygon([(68, 14), (64, 0), (54, 12)], fill=rgba(MIST[0]))
        d.polygon([(14, 50), (0, 82), (24, 74)], fill=rgba(MIST[0]))
        d.polygon([(74, 50), (88, 82), (64, 74)], fill=rgba(MIST[0]))
        for y in range(56, 92, 6):
            d.arc([24, y, 64, y + 10], 20, 160, fill=rgba(MIST[2]))
        if not back:
            d.ellipse([22, 18, 44, 40], fill=rgba(MIST[3]))
            d.ellipse([44, 18, 66, 40], fill=rgba(MIST[3]))
            eyes(d, [(33, 29), (55, 29)], col=CYA[4], r=5)
            d.point([(33, 29), (55, 29)], fill=rgba((10, 10, 14)))
            d.polygon([(40, 38), (48, 38), (44, 48)], fill=rgba(CAP[1]))
        else:
            for y in range(16, 50, 7):
                d.arc([24, y, 64, y + 12], 20, 160, fill=rgba(MIST[0]))
        d.line([(30, 96), (26, H - 3)], fill=rgba(BARK[4]), width=3)
        d.line([(58, 96), (62, H - 3)], fill=rgba(BARK[4]), width=3)
        # mist-slierten
        im2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d2 = ImageDraw.Draw(im2)
        for i in range(5):
            d2.ellipse([4 + i * 14, 80 + (i % 2) * 6, 24 + i * 14, 92 + (i % 2) * 6], fill=(*MIST[2], 120))
        im = Image.alpha_composite(im2, im)
    elif kind == "sporenzwam":
        W, H = 84, 100
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rectangle([28, 44, 56, 90], fill=rgba(CAP[3]))
        d.ellipse([22, 80, 62, 98], fill=rgba(CAP[3]))
        d.ellipse([4, 8, 80, 56], fill=rgba(CAP[1]))
        d.ellipse([10, 10, 74, 40], fill=rgba(CAP[2]))
        for (x, y, s) in ((20, 18, 5), (44, 14, 7), (62, 24, 5), (32, 32, 4)):
            d.ellipse([x - s, y - s, x + s, y + s], fill=rgba(MAG[2] if (x + y) % 3 else CAP[3]))
        d.line([(10, 50), (74, 50)], fill=rgba(CAP[0]), width=2)
        d.line([(26, 60), (8, 76)], fill=rgba(CAP[2]), width=4)
        d.line([(58, 60), (76, 76)], fill=rgba(CAP[2]), width=4)
        if not back:
            eyes(d, [(36, 62), (50, 62)], col=(20, 10, 16), r=3)
            d.line([(37, 72), (49, 72)], fill=rgba((40, 16, 30)), width=2)
        for i in range(14):
            x, y = 6 + (i * 37) % 74, 2 + (i * 23) % 30
            d.point([(x, y), (x + 1, y)], fill=rgba(MAG[4] if i % 2 else CYA[3]))
    else:  # wortelkoning (baas)
        W, H = 200, 192
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        r = random.Random(77)
        for i in range(9):
            x = 20 + i * 20
            d.line([(100, 140), (x + r.randrange(-8, 9), H - 4)], fill=rgba(BARK[2]), width=9)
            d.line([(100, 140), (x, H - 4)], fill=rgba(BARK[3]), width=3)
        d.polygon([(64, 150), (70, 50), (130, 50), (136, 150)], fill=rgba(BARK[2]))
        for x in range(72, 130, 8):
            d.line([(x, 52), (x + r.randrange(-4, 5), 148)], fill=rgba(BARK[1]), width=2)
        d.line([(70, 70), (18, 30)], fill=rgba(BARK[3]), width=12)
        d.line([(130, 70), (182, 30)], fill=rgba(BARK[3]), width=12)
        for (sx, sy) in ((18, 30), (182, 30)):
            for a in (-40, 0, 40):
                d.line([(sx, sy), (sx + int(18 * math.sin(math.radians(a))), sy - int(18 * math.cos(math.radians(a))))],
                       fill=rgba(BARK[4]), width=4)
        d.ellipse([60, 6, 140, 70], fill=rgba(LEAF[2]))
        d.ellipse([70, 10, 130, 50], fill=rgba(LEAF[3]))
        for i in range(7):                        # kroon van wortels
            x = 66 + i * 11
            d.polygon([(x, 18), (x + 5, -2 + (i % 2) * 6), (x + 10, 18)], fill=rgba(BARK[4]))
            d.point([(x + 5, 2 + (i % 2) * 6)], fill=rgba(MAG[3]))
        if not back:
            d.ellipse([78, 36, 122, 64], fill=rgba((8, 6, 6)))
            eyes(d, [(90, 48), (110, 48)], r=4)
            # magenta kern in de borst
            d.ellipse([88, 92, 112, 116], fill=rgba(MAG[1]))
            d.ellipse([93, 97, 107, 111], fill=rgba(MAG[3]))
            d.point([(97, 100)], fill=rgba(MAG[4]))
        else:
            d.line([(100, 20), (100, 150)], fill=rgba(BARK[1]), width=4)
            for y in range(60, 150, 18):
                d.point([(84, y), (116, y + 9)], fill=rgba(CYA[2]))
        for _ in range(30):
            d.point([(r.randrange(60, 140), r.randrange(50, 150))], fill=rgba(MOSS[2]))
    outline(im)
    mark_corners(im, 4)
    return im


# ================================================================== map-sprites (16x16 frames)
def mini(kind, frame, direction):
    """Kleine map-figuur 16x16 (voeten onderaan), bobbing per frame."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    b = frame          # 1 px op/neer
    if kind == "wortelkruiper":
        for i in range(4):
            x = 3 + i * 3
            d.line([(x, 10 - b), (x + (-1 if frame else 1), 15)], fill=rgba(BARK[4]))
        d.ellipse([2, 4 - b, 13, 11 - b], fill=rgba(BARK[3]))
        d.ellipse([4, 4 - b, 9, 7 - b], fill=rgba(MOSS[2]))
        if direction != 3:
            ex = {0: (6, 9), 1: (4, 5), 2: (10, 11)}[direction]
            d.point([(ex[0], 8 - b), (ex[1], 8 - b)], fill=rgba(MAG[3]))
    elif kind == "mistuil":
        d.ellipse([3, 3 - b, 12, 14 - b], fill=rgba(MIST[1]))
        d.point([(4, 2 - b), (11, 2 - b)], fill=rgba(MIST[0]))
        if direction != 3:
            ex = {0: (6, 9), 1: (4, 7), 2: (8, 11)}[direction]
            d.point([(ex[0], 6 - b), (ex[1], 6 - b)], fill=rgba(CYA[4]))
        d.line([(6, 15), (6, 14 - b)], fill=rgba(BARK[4])); d.line([(9, 15), (9, 14 - b)], fill=rgba(BARK[4]))
    elif kind == "sporenzwam":
        d.rectangle([6, 8 - b, 9, 14], fill=rgba(CAP[3]))
        d.ellipse([2, 2 - b, 13, 9 - b], fill=rgba(CAP[1]))
        d.point([(5, 4 - b), (9, 3 - b)], fill=rgba(MAG[3]))
        if direction != 3:
            ex = {0: (7, 8), 1: (6, 6), 2: (9, 9)}[direction]
            d.point([(ex[0], 11 - b), (ex[1] + (1 if ex[0] == ex[1] else 0), 11 - b)], fill=rgba(INK))
        d.point([(3 + frame * 9, 1)], fill=rgba(MAG[4]))
    outline(im)
    return im


def map_sheet(kind):
    sheet = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    for row in range(4):
        for col in range(2):
            sheet.paste(mini(kind, col, row), (col * 16, row * 16))
    mark_corners(sheet, 2)
    return sheet


def boss_map():
    sheet = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for f in range(2):
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for x in (4, 10, 16, 22, 28):
            d.line([(16, 22), (x, 31)], fill=rgba(BARK[3]), width=2)
        d.rectangle([10, 10, 22, 24], fill=rgba(BARK[2]))
        d.ellipse([7, 2, 25, 16], fill=rgba(LEAF[3]))
        for x in (9, 13, 17, 21):
            d.polygon([(x, 5), (x + 2, 0), (x + 4, 5)], fill=rgba(BARK[4]))
        d.point([(13, 10), (18, 10)], fill=rgba(MAG[3] if f == 0 else MAG[4]))
        d.ellipse([14, 15, 18, 19], fill=rgba(MAG[2] if f == 0 else MAG[3]))
        d.line([(10, 12), (2, 6 - f)], fill=rgba(BARK[3]), width=2)
        d.line([(22, 12), (30, 6 - f)], fill=rgba(BARK[3]), width=2)
        outline(im)
        sheet.paste(im, (f * 32, 0))
    mark_corners(sheet, 3)
    return sheet


# ================================================================== Noor in de wortelcocon (32x48)
def cocoon():
    im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([5, 6, 26, 46], fill=rgba(BARK[2]))
    # blond haar + gezicht van Noor zichtbaar bovenin
    d.ellipse([10, 4, 21, 16], fill=rgba(HAIR[1]))
    d.rectangle([12, 9, 19, 15], fill=rgba(SKIN[2]))
    d.point([(14, 12), (17, 12)], fill=rgba(INK))
    d.line([(10, 8), (21, 8)], fill=rgba(HAIR[2]))
    d.line([(10, 10), (10, 18)], fill=rgba(HAIR[1])); d.line([(21, 10), (21, 18)], fill=rgba(HAIR[1]))
    # wortels om haar heen
    for y in range(16, 46, 5):
        d.arc([4, y - 4, 27, y + 6], 0, 180, fill=rgba(BARK[4]), width=2)
    d.line([(8, 14), (24, 30)], fill=rgba(BARK[3]), width=2)
    d.line([(24, 16), (8, 34)], fill=rgba(BARK[3]), width=2)
    for (x, y) in ((9, 24), (22, 28), (15, 36), (12, 41), (20, 20)):
        d.point([(x, y)], fill=rgba(MAG[3]))
    d.line([(6, 47), (2, 44)], fill=rgba(BARK[3])); d.line([(25, 47), (30, 44)], fill=rgba(BARK[3]))
    outline(im)
    mark_corners(im, 2)
    return im


# ================================================================== wereldkaart-iconen
def world_icons():
    """5 tegels 16x16: 0..3 = Esdoorn (2x2: LB, RB, LO, RO), 4 = ingang Donker Woud.
    Esdoorn = het dorpsicoon van RPG ART (wereld_v14.png #134-#137) met esdoorn-rode daken
    (afgeleid, nieuw bestand; het origineel blijft onaangeroerd)."""
    src = Image.open(P("assets", "tiles", "wereld_v14.png")).convert("RGBA")
    out = Image.new("RGBA", (80, 16), (0, 0, 0, 0))
    for i in range(4):
        n = 134 + i
        t = src.crop(((n % 16) * 16, (n // 16) * 16, (n % 16) * 16 + 16, (n // 16) * 16 + 16))
        px = t.load()
        for y in range(16):
            for x in range(16):
                r_, g, b, a = px[x, y]
                # blauwgrijze/paarse daken -> esdoorn-rood
                if b > r_ + 8 and b > g and a > 0 and (i < 2 or y < 8):
                    lum = (r_ + g + b) / 3
                    px[x, y] = (int(min(255, lum * 1.5 + 30)), int(lum * 0.55), int(lum * 0.45), a)
        out.paste(t, (i * 16, 0))
    # tile 4: Donker Woud (gras-ondergrond van tegel 0 + donkere bomen met een poort van wortels)
    g = src.crop((0, 0, 16, 16))
    t = g.copy()
    d = ImageDraw.Draw(t)
    for (x, y, s) in ((3, 6, 4), (12, 5, 4), (8, 3, 5)):
        d.ellipse([x - s, y - s, x + s, y + s], fill=rgba(LEAF[1]), outline=rgba(INK))
    d.rectangle([5, 8, 10, 15], fill=rgba((4, 5, 4)))
    d.arc([4, 6, 11, 14], 180, 360, fill=rgba(BARK[4]))
    d.point([(6, 11), (9, 11)], fill=rgba(MAG[3]))
    out.paste(t, (64, 0))
    save(out, "assets/tiles/wereld_v17_iconen.png")


def main():
    build_tiles()
    build_backdrop()
    for k in ("wortelkruiper", "mistuil", "sporenzwam", "wortelkoning"):
        save(creature(k), "assets/sprites/enemies/%s.png" % k)
        save(creature(k, back=True), "assets/sprites/enemies/%s_rug.png" % k)
    for k in ("wortelkruiper", "mistuil", "sporenzwam"):
        save(map_sheet(k), "assets/map_monsters/%s.png" % k)
    save(boss_map(), "assets/map_monsters/wortelkoning.png")
    save(cocoon(), "assets/sprites/woud/noor_cocon.png")
    world_icons()
    with open(P("tools", "placeholders_v17.txt"), "w", encoding="utf-8") as f:
        f.write("# v0.17 PLACEHOLDERS (tools/art_woud_placeholders.py). Echte art: zelfde naam + maat erover,\n")
        f.write("# daarna de regel hier weghalen en in tools/handwerk.txt zetten. Zie /workspace/v17_ART_SLOTS.md.\n")
        for rel, size in WRITTEN:
            f.write("%s  %dx%d\n" % (rel, size[0], size[1]))


if __name__ == "__main__":
    main()
