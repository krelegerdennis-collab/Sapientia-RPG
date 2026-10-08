"""Gevechtshelden voor 'De Vergeten Bibliotheek' (v8), eigen werk.

v8: GROTER en LEVENDIGER, dichter bij de mockup:
  - frame 210x210 art-pixels (op schaal 0.5 op het 768x432-raster); de figuur is ±150 fijne
    pixels hoog = ±35% van de schermhoogte (zoals de mockup)
  - warmer palet: echte huidtint, bruin leer, haarkleur, donkere/rode capes, metaal met glans
  - dynamischere houding: leunt naar voren, wapen geheven
  - 2 extra 'adem'-frames voor een rustige idle-animatie (op en neer, cape zwaait, bol pulseert)
Voeten (midden van de grondschaduw) op (105, 203) in elk frame.
Strook: 10 frames naast elkaar = 2100x210:
    0 stil, 1 klaar, 2 aanval A, 3 aanval B, 4 spreuk A, 5 spreuk B, 6 geraakt, 7 KO,
    8 stil-inademen (iets hoger, cape naar rechts), 9 stil-uitademen (cape naar links)

We gebruiken de rasterizer en de gewrichts-poses van v6 (art_battle.py), maar:
  - langere lijven (x1,2 in de hoogte) en een kleiner hoofd: ±4,5 hoofden hoog
  - ontkleurd palet (grijs, bruin, leer); neon alleen op magie en wapens
  - Dennis: donker haar, donkere cape met embleem, grijs harnas, zwaard dat in pixels uiteenvalt
  - Noor: bruine paardenstaart, donkere kapmantel, staf met gloeiende magenta bol
  - Lotte: grijs-wit gewaad met cyaan accenten, as-blonde vlecht, staf met cyaan kristal
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw

import art_battle as ab
from art_battle import Canvas, lerp, add, rot_pt
from art_v7_common import (SKIN, HAIR_BLACK, HAIR_BROWN, HAIR_ASH, CAPE_DARK, ARMOR, LEATHER,
                           CLOTH, WOOD, BRONZE, NEON_MAGENTA, NEON_CYAN, MAGENTA,
                           MAGENTA_HOT, CYAN, CYAN_HOT, rgb, ramp)

DW = DH = 100                 # ontwerp-maat (eenheden)
S = 2.1                       # art-pixels per eenheid -> frame 210x210
F = int(DW * S)
FEET = (105, 203)             # in art-pixels (zie battle_hero.gd)
HS = 1.12                     # hoofd iets groter (mockup: stoerder, 'heroïsch-chibi')
K = S / 1.4                   # effecten (gloed, schaduw) waren gemaakt voor S = 1.4
VS = 1.2                      # lijf langer dan v6
ROBE_PALE = ramp("232327", "3e3e44", "5c5c63", "7e7e85", "a2a2a7", "c4c4c7")
HAIR_DARK = ramp("0d0a0a", "1c1614", "2c221e", "3d2f29", "533f35", "6c5446")   # Dennis: bijna zwart, bruine glans
CAPE_DARK2 = ramp("0c0c10", "17171c", "222228", "2f2f36", "3e3e46", "54545c")
RIM = (226, 218, 206)         # warm randlicht van linksboven
# ---- v8: warm, leesbaar palet (overschrijft de grauwe v7-ramps in dit bestand)
SKIN = ramp("3a2018", "6a3a2a", "9a5c44", "c4805e", "e0a47c", "f4c8a0")
LEATHER = ramp("1c100a", "382014", "583420", "784a2e", "9a6442", "bc845a")
CLOTH = ramp("15110e", "28201a", "3c3027", "524335", "6a5845", "847058")
ARMOR = ramp("121419", "282c33", "444a53", "6a717b", "9ca3ad", "dce1e8")
BRONZE = ramp("2a1a0a", "543614", "845a22", "b08434", "d4ac52", "f0d488")
WOOD = ramp("1c1009", "382012", "583520", "784c2e", "9a6640", "bc8656")
WOOD_PALE = ramp("2a2018", "4a3a2c", "6c5a46", "8e7a60", "b09a7c", "d0bc9c")
HAIR_DARK = ramp("100a08", "22150e", "382216", "513220", "6e482e", "8e6442")      # Dennis: donkerbruin
HAIR_BROWN = ramp("1c0e08", "3c1e0e", "5c3216", "7e4820", "a0622c", "c08446")     # Noor: kastanje
HAIR_ASH = ramp("3e301a", "6a5428", "927a3a", "b89c52", "d6be70", "eedc98")       # Lotte: warm blond
CAPE_DARK2 = ramp("0b0c11", "171a23", "252935", "363b49", "4b5162", "68708a")     # Dennis: antraciet cape
CAPE_GREY = ramp("120e14", "211a25", "312736", "43374a", "584a60", "74647e")      # Noor: donker pruim-grijs
ROBE_PALE = ramp("3a322a", "5e5446", "847866", "a89c86", "c8bea6", "e6dcc4")      # Lotte: crème gewaad
MANTLE_RED = ramp("1c080a", "3c1014", "5e1a1e", "80262a", "a23a38", "c4584c")     # Lotte: rood manteltje
TROUSERS = ramp("131216", "221f27", "332e39", "453e4c", "585062", "6e667a")         # randlicht van linksboven (losser van de grijze achtergrond)
# iteratie 2: capes donkerder en warmer (minder blauwgrijs), zodat leer/haar/huid eruit springen
CAPE_DARK2 = ramp("08080a", "121216", "1c1c22", "28282f", "36363e", "4a4a52")     # Dennis: bijna zwarte cape
CAPE_GREY = ramp("0e0b10", "1a151d", "282030", "372c40", "4a3c54", "62526c")      # Noor: donker pruim
CAPE_LINING = ramp("1c0606", "3a0c0e", "581416", "761e20", "962c2c", "b44040")    # rode voering


def _stretch(P):
    """v6-pose (voeten op y=92) -> v7: 1,2x zo lang, voeten op y=97."""
    Q = {}
    for k, v in P.items():
        if isinstance(v, tuple) and len(v) == 2 and k != "fx":
            Q[k] = (v[0] + 2, 97 - (92 - v[1]) * VS)
        else:
            Q[k] = v
    # hoofd en nek blijven op dezelfde afstand van de schouders (geen giraffennek)
    sh = (P["sh_n"][1] + P["sh_f"][1]) / 2
    sh2 = (Q["sh_n"][1] + Q["sh_f"][1]) / 2
    for k in ("head", "neck"):
        Q[k] = (P[k][0] + 2, P[k][1] + (sh2 - sh) + (1.2 if k == "head" else 0.6))
    return Q


# v8-poses: leunen naar voren (richting de vijand), wapen geheven, bredere stand.
# Zelfde gewrichten als v6 (art_battle.BASE_POSE), daarna _stretch naar v7/v8-verhoudingen.
_P = ab._pose
_WIDE = dict(kn_n=(32, 65), ft_n=(29, 74), kn_f=(48, 64), ft_f=(52, 73))
SWORD_V8 = [
    _P(upper=(4, 2), el_f=(58, 43), ha_f=(63, 40), weapon=-48, el_n=(33, 46), ha_n=(38, 50), tilt=0.08, **_WIDE),   # stil
    _P(shift=(1, 1), upper=(6, 3), el_f=(61, 42), ha_f=(67, 41), weapon=-30, tilt=0.12,
       el_n=(35, 46), ha_n=(40, 51), kn_n=(32, 65), ft_n=(28, 74), kn_f=(50, 64), ft_f=(55, 73)),       # klaar
    _P(upper=(-1, 0), el_f=(50, 30), ha_f=(45, 20), weapon=-150, wz=0,
       el_n=(26, 43), ha_n=(26, 50), **_WIDE),                                                          # aanval A
    _P(shift=(6, 1), upper=(5, 2), el_f=(62, 41), ha_f=(68, 45), weapon=28, wz=2,
       el_n=(31, 46), ha_n=(30, 53), ft_f=(57, 73), kn_f=(53, 64), ft_n=(27, 74),
       kn_n=(31, 65), fx="zwaai"),                                                                       # aanval B
    _P(upper=(2, 0), el_f=(53, 34), ha_f=(55, 24), weapon=-88, **_WIDE),                                # spreuk A
    _P(upper=(2, 0), el_f=(53, 34), ha_f=(55, 24), weapon=-88, fx="glinster", **_WIDE),                 # spreuk B
    _P(shift=(-4, 0), upper=(-3, 1), el_n=(24, 41), ha_n=(19, 45), el_f=(51, 41),
       ha_f=(56, 37), weapon=-20, tilt=-0.18, fx="raak"),                                               # geraakt
]
STAFF_V8 = [
    _P(upper=(4, 2), el_f=(58, 41), ha_f=(62, 38), weapon=-76, el_n=(33, 46), ha_n=(38, 49), tilt=0.08, **_WIDE),   # stil
    _P(shift=(1, 1), upper=(6, 3), el_f=(61, 40), ha_f=(66, 38), weapon=-62, tilt=0.12,
       el_n=(35, 46), ha_n=(40, 50), kn_f=(50, 64), ft_f=(55, 73), kn_n=(32, 65), ft_n=(28, 74)),       # klaar
    _P(upper=(-1, 0), el_f=(51, 34), ha_f=(50, 25), weapon=-115, wz=0,
       el_n=(26, 43), ha_n=(26, 50), **_WIDE),
    _P(shift=(5, 1), upper=(5, 2), el_f=(62, 40), ha_f=(68, 43), weapon=-20, wz=2,
       ft_f=(56, 73), kn_f=(52, 64), ft_n=(28, 74), fx="zwaai"),
    _P(upper=(2, 0), el_f=(53, 33), ha_f=(57, 24), weapon=-84, el_n=(26, 40), ha_n=(25, 32), **_WIDE),
    _P(upper=(2, 0), el_f=(53, 33), ha_f=(57, 24), weapon=-84, el_n=(26, 40), ha_n=(25, 32), fx="gloed", **_WIDE),
    _P(shift=(-4, 0), upper=(-3, 1), el_n=(24, 41), ha_n=(19, 45), el_f=(51, 41),
       ha_f=(56, 38), weapon=-60, tilt=-0.18, fx="raak"),
]
SWORD = [_stretch(p) for p in SWORD_V8]
STAFF = [_stretch(p) for p in STAFF_V8]


def _breathe(P, dy, sway):
    """Adem-frame: bovenlijf dy eenheden omhoog/omlaag, cape zwaait 'sway'."""
    Q = dict(P)
    for k in ("head", "neck", "sh_n", "sh_f", "el_n", "ha_n", "el_f", "ha_f"):
        Q[k] = (P[k][0], P[k][1] + dy)
    for k in ("hip_n", "hip_f"):
        Q[k] = (P[k][0], P[k][1] + dy * 0.4)
    Q["sway"] = sway
    return Q


# ---------------------------------------------------------------- hoofd en haar
def _head(c, P, kind):
    h = P["head"]
    t = P["tilt"]
    R = lambda d: rot_pt(add(h, (d[0] * HS, d[1] * HS)), h, t)
    _c_ellipse, _c_capsule = c.ellipse, c.capsule
    # alle hoofd-vormen een tikje groter (HS)
    c.ellipse = lambda cc, rx, ry, rmp, **kw: _c_ellipse(cc, rx * HS, ry * HS, rmp, **kw)
    c.capsule = lambda a, b, r0, r1, rmp, *ar, **kw: _c_capsule(a, b, r0 * HS, r1 * HS, rmp, *ar, **kw)
    c.capsule(R((1.5, 5.5)), P["neck"], 2.6, 3.0, SKIN, bias=-0.12)
    c.ellipse(h, 6.9, 7.4, SKIN, rot=t)
    c.ellipse(R((4.5, 2.6)), 2.6, 3.2, SKIN, bias=0.06)                 # wang / kaak (3/4 achter: je ziet de wang)
    if kind == "dennis":
        hair = HAIR_DARK
        c.ellipse(R((-2.0, -2.0)), 7.2, 7.5, hair, rot=t, bias=0.04)
        for (a_, b_, r, bias) in (((0, 3), (-1.0, 8.0), 3.0, -0.04), ((-3, 2), (-8.0, 5.5), 3.0, -0.02),
                                  ((-3, -1), (-9.0, -1.0), 3.2, 0.0), ((-2, -3), (-7.0, -6.8), 3.4, 0.03),
                                  ((1, -4), (1.5, -8.2), 3.2, 0.05), ((-1, -4), (-3.8, -8.6), 3.5, 0.06),
                                  ((3.5, -2.0), (7.0, 1.0), 2.3, 0.0), ((2.5, -4), (6.0, -7.5), 2.6, 0.05),
                                  ((-4, 4), (-6.5, 9.0), 2.6, -0.06)):
            c.capsule(R(a_), R(b_), r, 1.0, hair, bias=bias)
        for st in (((1, -5), (-2, -9)), ((-4, -3), (-8, -5)), ((-3, 1), (-8, 1)), ((2.5, -5), (3, -9)),
                   ((-1, 3), (-1, 6)), ((-4, 3), (-7, 5))):
            c.crease([R(q) for q in st], 0.16)
        ab._sheen(c, R((-1.0, -2.6)), t, 5.4, 200, 300, 0.42)
    elif kind == "noor":
        hair = HAIR_BROWN
        c.ellipse(R((-1.4, -1.6)), 7.0, 7.1, hair, rot=t)
        c.capsule(R((4.6, -3.5)), R((6.0, 4.0)), 1.9, 0.9, hair)          # lok langs het oor
        # paardenstaart: vanaf het elastiekje achter op het hoofd naar beneden
        c.capsule(R((-5.0, 1.0)), R((-8.5, 8.5)), 2.8, 2.3, hair, bias=0.02)
        c.capsule(R((-8.5, 8.5)), R((-8.0, 16.5)), 2.3, 1.4, hair)
        c.capsule(R((-8.0, 16.5)), R((-6.0, 21.0)), 1.4, 0.5, hair, bias=-0.04)
        c.ellipse(R((-5.0, 1.0)), 2.0, 1.8, LEATHER, bias=0.05)          # elastiekje
        for s in (((-5, -6), (-4, -1), (-4, 3)), ((-1, -7), (0, -2)), ((2, -6), (3, -2)),
                  ((-7, 4), (-8, 10), (-8, 15)), ((-9, 6), (-9.5, 12))):
            c.crease([R(p) for p in s], 0.18)
        ab._sheen(c, R((-1.4, -1.6)), t, 5.2, 200, 300, 0.26)
    else:   # lotte
        hair = HAIR_ASH
        c.ellipse(R((-1.6, -1.6)), 7.0, 6.9, hair, rot=t)
        c.capsule(R((4.6, -3.5)), R((6.2, 3.5)), 1.9, 0.9, hair)
        # vlecht: kraaltjes van haar die over de rug vallen
        for k in range(6):
            p = R((-4.5 - k * 0.5 + (0.6 if k % 2 else -0.6), 3.5 + k * 3.0))
            c.ellipse(p, 2.3 - k * 0.15, 1.9, hair, rot=t + (0.5 if k % 2 else -0.5), bias=0.03)
        c.ellipse(R((-7.5, 21.5)), 1.3, 1.1, NEON_CYAN, bias=0.2, outline=False)   # cyaan kraal
        for s in (((-5, -6), (-4, -1), (-4, 3)), ((-1, -7), (0, -2)), ((2, -6), (3, -2))):
            c.crease([R(p) for p in s], 0.16)
        ab._sheen(c, R((-1.6, -1.6)), t, 5.2, 200, 300, 0.3)
    # oor (3/4 achter) zodat het hoofd niet als haarbal leest
    c.ellipse(R((2.6, 1.6)), 1.5, 2.1, SKIN, bias=0.02)
    c.ellipse, c.capsule = _c_ellipse, _c_capsule


# ---------------------------------------------------------------- wapens
def _sword(c, hand, deg):
    d = ab._dir(deg)
    perp = (-d[1], d[0])
    c.capsule(add(hand, (-d[0] * 4.5, -d[1] * 4.5)), add(hand, (d[0] * 1, d[1] * 1)), 1.3, 1.3, LEATHER)
    c.ellipse(add(hand, (-d[0] * 5.3, -d[1] * 5.3)), 1.8, 1.8, ARMOR, bias=0.05)
    g = add(hand, (d[0] * 2.2, d[1] * 2.2))
    c.capsule(add(g, (perp[0] * 4.6, perp[1] * 4.6)), add(g, (-perp[0] * 4.6, -perp[1] * 4.6)), 1.3, 1.1, ARMOR)
    b0 = add(hand, (d[0] * 3.2, d[1] * 3.2))
    b1 = add(hand, (d[0] * 30, d[1] * 30))
    c.capsule(b0, b1, 2.0, 0.9, ARMOR, bias=0.12)
    c.crease([add(b0, (d[0] * 2, d[1] * 2)), add(b0, (d[0] * 22, d[1] * 22))], -0.3, light=False)
    return b1, (b0, b1)


def _staff(c, hand, deg, kind):
    d = ab._dir(deg)
    lo = add(hand, (-d[0] * 13, -d[1] * 13))
    hi = add(hand, (d[0] * 24, d[1] * 24))
    wood = WOOD if kind == "orb" else WOOD_PALE
    c.capsule(lo, hi, 1.4, 1.3, wood)
    c.crease([add(lo, (d[0] * 4, d[1] * 4)), add(hi, (-d[0] * 4, -d[1] * 4))], 0.12)
    c.capsule(add(hand, (d[0] * 4, d[1] * 4)), add(hand, (d[0] * 6, d[1] * 6)), 1.7, 1.7, LEATHER)  # omwikkeling
    if kind == "orb":
        top = add(hi, (d[0] * 3.6, d[1] * 3.6))
        for s in (-1, 1):                                                  # klauw om de bol
            c.capsule(hi, add(top, (s * 3.4 * -d[1] + d[0] * 1.5, s * 3.4 * d[0] + d[1] * 1.5)), 1.0, 0.6, ARMOR)
        c.ellipse(top, 3.4, 3.4, NEON_MAGENTA, bias=0.35, outline=False)
        return top, None
    top = add(hi, (d[0] * 4.6, d[1] * 4.6))
    ring = c.ellipse(top, 4.2, 4.2, ARMOR, bias=0.05)
    hole = ((c.X - top[0]) ** 2 + (c.Y - top[1]) ** 2) < 2.6 ** 2
    c.mat[hole] = -1
    c.part[hole] = -1
    c.polygon([add(top, (0, -2.6)), add(top, (1.5, 0)), add(top, (0, 2.6)), add(top, (-1.5, 0))],
              NEON_CYAN, bias=0.3, outline=False)
    return top, None


# ---------------------------------------------------------------- lijven
def _cape(c, P, rmp, length=1.0, narrow=0.0, flare=1.0, trail=0.0, back=0.0, lining=None):
    """Cape van achteren gezien: van de schouders over de rug, wijder naar onder."""
    sn, sf, hn, hf = P["sh_n"], P["sh_f"], P["hip_n"], P["hip_f"]
    kn, kf, fn, ff = P["kn_n"], P["kn_f"], P["ft_n"], P["ft_f"]
    sway = -5.0 if P.get("fx") == "zwaai" else (-2.5 if P.get("wz") == 0 else 0.0)
    if P.get("fx") == "raak":
        sway = 3.0
    sway += P.get("sway", 0.0) - trail      # cape waait iets naar achteren (links)
    bot = lerp(hn, lerp(kn, fn, 0.5), length)[1] + 1
    inset = narrow * 0.6                   # smallere cape: hangt tussen de schouderbladen
    top_l, top_r = add(sn, (-2 + inset, -2.5)), add(sf, (2 - inset, -3))
    xl = hn[0] - 7.5 * flare + narrow + sway
    xr = hf[0] + 6.5 * flare - narrow + sway * 0.6 - back
    if lining is not None:   # rode voering die links onder de cape uitwappert
        lin = [add(sn, (-3.0 + inset, 6)), (xl - 2.2, bot - 7), (xl - 1.0, bot + 2.2), (xl + 6, bot + 2.6), (xl + 4, bot - 6)]
        c.polygon(lin, lining, curve=1.0, tilt=-0.2, vgrad=0.4, bias=-0.06)
    hem = []
    n = 7
    for k in range(n + 1):
        tt = k / n
        hem.append((xl + (xr - xl) * tt, bot + (1.8 if k % 2 else -0.5) + tt * 1.8))
    pts = [top_l, lerp(top_l, top_r, 0.5), top_r, add(sf, (3.2 - inset - back * 0.5, 7)), (xr + 1, bot - 8)] + hem[::-1] + \
          [(xl - 1, bot - 8), add(sn, (-3.5 + inset, 8))]
    c.polygon(pts, rmp, curve=1.0, tilt=-0.25, vgrad=0.5)
    for tt in (0.12, 0.34, 0.58, 0.82):
        x_end = xl + (xr - xl) * tt
        c.crease([add(lerp(top_l, top_r, 0.2 + tt * 0.6), (0, 6)), (x_end + 0.5, bot - 1)], 0.32)
    # plooi-glans: een lichte baan langs elke plooi (kleding met volume, zoals de mockup)
    for tt in (0.22, 0.46, 0.7):
        x_end = xl + (xr - xl) * tt
        c.crease([add(lerp(top_l, top_r, 0.25 + tt * 0.55), (0, 8)), (x_end + 1.2, bot - 2)], -0.16, light=False)
    c.crease([add(top_l, (1, 1.5)), add(lerp(top_l, top_r, 0.5), (0, 2.5)), add(top_r, (-1, 1.5))],
             -0.25, light=False)
    c.crease([(xl + 1, bot - 1.5), (xr - 1, bot - 0.5)], 0.16, light=False)
    return lerp(top_l, top_r, 0.5), bot


def _emblem(c, center, scale=1.0):
    """Boom-rune op Dennis's cape (ontkleurd brons)."""
    x, y = center
    s = scale
    c.capsule((x, y - 6 * s), (x, y + 7 * s), 0.75, 0.75, BRONZE, bias=0.1, outline=False)
    for sgn in (-1, 1):
        c.capsule((x, y - 1 * s), (x + sgn * 4.5 * s, y - 6.5 * s), 0.7, 0.6, BRONZE, bias=0.1, outline=False)
        c.capsule((x, y + 2.5 * s), (x + sgn * 3.5 * s, y - 1.5 * s), 0.65, 0.55, BRONZE, bias=0.05, outline=False)
        c.capsule((x, y + 7 * s), (x + sgn * 3.5 * s, y + 9 * s), 0.6, 0.5, BRONZE, bias=0.0, outline=False)


def _leg(c, P, side, trouser, boot, bias=0.0, foot=(2.6, 0.6)):
    hip, kn, ft = P["hip_" + side], P["kn_" + side], P["ft_" + side]
    c.capsule(hip, kn, 3.8, 3.1, trouser, bias)
    top = lerp(kn, ft, 0.4)
    c.capsule(kn, top, 3.0, 2.9, trouser, bias)
    c.capsule(top, ft, 3.3, 2.8, boot, bias)
    c.ellipse(add(ft, foot), 4.4 if foot[0] else 2.8, 2.5 if foot[0] else 3.6, boot, bias=bias)
    c.crease([add(top, (-3, 0)), add(top, (3, 0))], 0.2)


def _torso_pts(P, widen=1.8):
    return ab._torso_pts(P, widen)


def _body_dennis(c, P):
    hn, hf, sn, sf = P["hip_n"], P["hip_f"], P["sh_n"], P["sh_f"]
    # grijs harnas (zie je opzij van de cape) + leren rok met riem
    skirt = [add(hn, (-3, -3)), add(hf, (3, -3)), add(hf, (5, 7)), add(lerp(hn, hf, 0.5), (0, 8)), add(hn, (-5, 7))]
    c.polygon(skirt, LEATHER, curve=1.0, tilt=0.1, bias=-0.04)
    c.polygon(_torso_pts(P), LEATHER, curve=1.0, tilt=-0.3, vgrad=0.5, bias=-0.02)
    waist_y = (hn[1] + hf[1]) / 2 - 3.5
    c.capsule((hn[0] - 3.5, waist_y + (hn[1] - hf[1]) / 2), (hf[0] + 3.5, waist_y), 1.8, 1.8, LEATHER)
    mid, bot = _cape(c, P, CAPE_DARK2, length=0.6, narrow=2.2, flare=1.1, trail=3.5, back=3.0, lining=CAPE_LINING)
    _emblem(c, add(mid, (-0.5, 14)), 1.05)
    # verre schouderstuk (gelaagd)
    c.ellipse(add(sf, (0.5, -0.5)), 4.7, 3.8, ARMOR, bias=-0.12)
    c.crease([add(sf, (-3.5, 1)), add(sf, (3.5, 1.5))], 0.2)


def _body_noor(c, P):
    hn, hf, sn, sf = P["hip_n"], P["hip_f"], P["sh_n"], P["sh_f"]
    skirt = [add(hn, (-3, -3)), add(hf, (3, -3)), add(hf, (4.5, 9)), add(lerp(hn, hf, 0.5), (0, 10)), add(hn, (-4.5, 9))]
    c.polygon(skirt, CLOTH, curve=1.0, tilt=0.1)
    c.polygon(_torso_pts(P), LEATHER, curve=1.0, tilt=-0.3, vgrad=0.5)
    waist_y = (hn[1] + hf[1]) / 2 - 3.5
    c.capsule((hn[0] - 3.5, waist_y + 0.5), (hf[0] + 3.5, waist_y), 1.6, 1.6, LEATHER, bias=0.08)
    c.ellipse((hf[0] + 1.5, waist_y + 2.5), 2.2, 2.6, LEATHER, bias=-0.05)    # tasje
    mid, bot = _cape(c, P, CAPE_GREY, length=0.5, narrow=2.4, flare=1.0, trail=2.8, back=3.0)
    # kap (ligt omlaag op de schouders)
    hood = add(mid, (-0.5, 2.5))
    c.ellipse(hood, 6.6, 4.2, CAPE_GREY, bias=0.05)
    c.crease([add(hood, (-4.5, -0.5)), add(hood, (0, 2.2)), add(hood, (4.5, -0.5))], 0.3, light=False)
    c.crease([add(hood, (-2.5, 2.8)), add(hood, (-1, 6))], 0.2)


def _body_lotte(c, P):
    hn, hf, sn, sf = P["hip_n"], P["hip_f"], P["sh_n"], P["sh_f"]
    fn, ff = P["ft_n"], P["ft_f"]
    hem_y = max(fn[1], ff[1]) - 2.5
    robe = [add(sn, (-2, -2)), add(sf, (2, -2.5)), add(sf, (2.5, 6)), add(hf, (3, -2)),
            (ff[0] + 6.5, hem_y - 1), (lerp(fn, ff, 0.5)[0] + 2, hem_y + 0.8),
            (lerp(fn, ff, 0.5)[0] - 4, hem_y), (fn[0] - 6, hem_y - 0.5), add(hn, (-4.5, 0)), add(sn, (-2.5, 6))]
    c.polygon(robe, ROBE_PALE, curve=1.0, tilt=-0.15, vgrad=0.55)
    for (a, b) in (((-2, 0), (-5, 22)), ((3, -1), (3, 23)), ((7, -1), (9, 21)), ((-4, 8), (-7, 22))):
        c.crease([add(lerp(hn, hf, 0.5), a), add(lerp(hn, hf, 0.5), b)], 0.18)
    # cyaan zoom en sjerp (accent)
    c.capsule((fn[0] - 6, hem_y - 1.2), (ff[0] + 6.5, hem_y - 1.7), 0.8, 0.8, NEON_CYAN, bias=0.05, outline=False)
    waist_y = (hn[1] + hf[1]) / 2 - 4
    c.capsule((hn[0] - 3.5, waist_y + 0.5), (hf[0] + 3.5, waist_y), 1.5, 1.5, CLOTH, bias=0.05)
    c.capsule((hn[0] - 3.2, waist_y + 0.1), (hf[0] + 3.2, waist_y - 0.4), 0.55, 0.55, NEON_CYAN, bias=0.1, outline=False)
    c.capsule((hn[0] + 1, waist_y + 1), (hn[0] - 0.5, waist_y + 11), 1.1, 0.9, CLOTH)            # sjerp
    # kort manteltje met kap (grijs), cyaan randje
    cap = [add(sn, (-3, -2)), add(sf, (3, -2.5)), add(sf, (4, 7)), lerp(add(sn, (0, 15)), add(sf, (0, 15)), 0.55),
           add(sn, (-3.5, 9))]
    c.polygon(cap, MANTLE_RED, curve=1.0, tilt=-0.35, vgrad=0.4)
    for tt in (0.3, 0.55, 0.8):
        c.crease([lerp(add(sn, (0, 1)), add(sf, (0, 1)), tt), lerp(add(sn, (-1, 10)), add(sf, (1, 10)), tt)], 0.18)
    hood = add(lerp(sn, sf, 0.45), (0, 3.0))
    c.ellipse(hood, 5.2, 3.6, MANTLE_RED, bias=0.06)
    c.crease([add(hood, (-3.5, -0.5)), add(hood, (0, 1.8)), add(hood, (3.5, -0.5))], 0.3, light=False)
    c.capsule(lerp(add(sn, (-3.5, 9)), lerp(add(sn, (0, 15)), add(sf, (0, 15)), 0.55), 0.1),
              lerp(add(sn, (-3.5, 9)), lerp(add(sn, (0, 15)), add(sf, (0, 15)), 0.55), 0.9), 0.5, 0.5,
              NEON_CYAN, bias=0.0, outline=False)


SPECS = {
    "dennis": {"weapon": "zwaard", "head": "dennis", "sleeve": LEATHER, "forearm": ARMOR, "legs": True,
              "trousers": TROUSERS, "boots": LEATHER, "body": _body_dennis, "pauldron": True, "glow": NEON_CYAN},
    "noor": {"weapon": "orbstaf", "head": "noor", "sleeve": CLOTH, "forearm": LEATHER, "legs": True,
             "trousers": TROUSERS, "boots": LEATHER, "body": _body_noor, "glow": NEON_MAGENTA},
    "lotte": {"weapon": "ringstaf", "head": "lotte", "sleeve": ROBE_PALE, "forearm": ROBE_PALE, "legs": False,
              "trousers": CLOTH, "boots": LEATHER, "body": _body_lotte, "cuff": True, "glow": NEON_CYAN},
}


def _hero_canvas(key, P, ko=False):
    c = Canvas(DW, DH, S)
    c.ambient = 0.12
    spec = SPECS[key]
    out = {"tip": None, "blade": None}

    def weapon():
        if spec["weapon"] == "zwaard":
            out["tip"], out["blade"] = _sword(c, P["ha_f"], P["weapon"])
        else:
            out["tip"], _ = _staff(c, P["ha_f"], P["weapon"] if spec["weapon"] != "zwaard" else 0,
                                   "orb" if spec["weapon"] == "orbstaf" else "ring")
    if ko:
        P = dict(P, wz=-1)
    if P["wz"] == 0:
        weapon()
    ab._limb(c, P["sh_f"], P["el_f"], P["ha_f"], 3.3, 2.9, 2.6, spec["sleeve"], spec["forearm"], bias=-0.14)
    c.ellipse(P["ha_f"], 2.4, 2.3, SKIN if key != "dennis" else LEATHER, bias=-0.05)
    if P["wz"] == 1:
        weapon()
    foot = (0.5, 0) if ko else (2.6, 0.6)
    if spec["legs"]:
        _leg(c, P, "f", spec["trousers"], spec["boots"], bias=-0.1, foot=foot)
        _leg(c, P, "n", spec["trousers"], spec["boots"], foot=foot)
    else:
        for side in ("f", "n"):
            if ko:
                c.ellipse(add(P["ft_" + side], (1.5, 0)), 2.6, 3.6, spec["boots"])
            else:
                c.ellipse(add(P["ft_" + side], (2.4, 0.4)), 4.2, 2.5, spec["boots"], bias=-0.05 if side == "f" else 0)
    spec["body"](c, P)
    ab._limb(c, P["sh_n"], P["el_n"], P["ha_n"], 3.5, 3.1, 2.7, spec["sleeve"], spec["forearm"])
    if spec.get("cuff"):
        c.capsule(lerp(P["el_n"], P["ha_n"], 0.55), lerp(P["el_n"], P["ha_n"], 0.8), 3.4, 3.8, spec["sleeve"])
    c.ellipse(P["ha_n"], 2.5, 2.4, SKIN if key != "dennis" else LEATHER)
    if spec.get("pauldron"):
        c.ellipse(add(P["sh_n"], (-0.8, 2.4)), 5.4, 3.0, ARMOR, bias=-0.18)
        c.ellipse(add(P["sh_n"], (-0.5, -0.6)), 6.0, 4.6, ARMOR, bias=-0.06)
        c.crease([add(P["sh_n"], (-4.5, 1)), add(P["sh_n"], (3.5, 1.5))], 0.25)
        c.px(P["sh_n"][0] + 1.5, P["sh_n"][1] - 1.5, ARMOR[5])
    _head(c, P, spec["head"])
    if P["wz"] == 2:
        weapon()
    return c, out


# ---------------------------------------------------------------- effecten (na het renderen)
def _glow(img, center, radius, rmp, strength=1.0):
    """Pixel-gloed: harde ringen met oplopende doorzichtigheid (geen blur)."""
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = center
    for rr, a, col in ((radius, 46, rmp[3]), (radius * 0.72, 80, rmp[3]), (radius * 0.48, 130, rmp[4])):
        a = int(a * strength)
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=col + (a,))
    rr = radius * 0.26
    d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=rmp[5] + (255,))


def _sparkle(img, center, size, col, hot):
    p = img.load()
    cx, cy = int(round(center[0])), int(round(center[1]))
    for k in range(1, size):
        a = 255 if k < size * 0.6 else 150
        for (ox, oy) in ((0, -k), (0, k), (-k, 0), (k, 0)):
            x, y = cx + ox, cy + oy
            if 0 <= x < img.width and 0 <= y < img.height:
                p[x, y] = col + (a,)
    for (ox, oy) in ((-2, -2), (2, -2), (-2, 2), (2, 2)):
        x, y = cx + ox, cy + oy
        if 0 <= x < img.width and 0 <= y < img.height:
            p[x, y] = hot + (220,)
    p[cx, cy] = (255, 255, 255, 255)


def _dissolve_blade(img, blade, rnd, amount=1.0):
    """Zwaard valt vanaf het midden van de kling uiteen in pixelblokjes."""
    (b0, b1) = blade
    x0, y0 = b0[0] * S, b0[1] * S
    x1, y1 = b1[0] * S, b1[1] * S
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    p = img.load()
    W_, H_ = img.size
    # 1) gaten in de buitenste helft van de kling
    ys, xs = np.nonzero(np.array(img)[:, :, 3] > 0)
    for x, y in zip(xs, ys):
        t = ((x + 0.5 - x0) * ux + (y + 0.5 - y0) * uy) / L
        dist = abs((x + 0.5 - x0) * -uy + (y + 0.5 - y0) * ux)
        if 0.5 < t < 1.2 and dist < 4.0:
            if rnd.random() < (t - 0.5) * 1.6 * amount:
                p[x, y] = (0, 0, 0, 0)
    # 2) losse blokjes die van de punt wegzweven
    cols = [ARMOR[5], ARMOR[4], ARMOR[3], ARMOR[4], CYAN, MAGENTA]
    for i in range(int(26 * amount)):
        t = rnd.uniform(0.55, 1.35)
        off = rnd.gauss(0, 2.2 + (t - 0.5) * 4)
        x = x0 + ux * L * t - uy * off
        y = y0 + uy * L * t + ux * off
        s = rnd.choice([1, 1, 1, 2, 2, 3])
        col = rnd.choice(cols) if rnd.random() < 0.9 else rnd.choice([CYAN, MAGENTA])
        for dy in range(s):
            for dx in range(s):
                xx, yy = int(x) + dx, int(y) + dy
                if 0 <= xx < W_ and 0 <= yy < H_:
                    p[xx, yy] = col + (255,)


def _slash(img, P, rnd):
    """Zwaaiboog voor het lijf (aan de vijandkant), uiteenvallend in pixels."""
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = (P["sh_f"][0] - 1) * S, (P["sh_f"][1] + 6) * S
    for (r, a, w, s0, s1, col) in ((34, 200, 2, -70, 35, (226, 228, 232)), (31, 120, 1, -60, 30, (180, 182, 188)),
                                   (37, 90, 1, -50, 22, CYAN)):
        r *= K
        d.arc((cx - r, cy - r, cx + r, cy + r), start=s0, end=s1, fill=col + (a,), width=w)
    for i in range(16):
        ang = math.radians(rnd.uniform(-70, 35))
        r = rnd.uniform(30, 42) * K
        x, y = cx + math.cos(ang) * r, cy + math.sin(ang) * r
        s = rnd.choice([1, 2, 2])
        col = rnd.choice([(230, 230, 236), (150, 150, 158), CYAN, MAGENTA])
        d.rectangle((x, y, x + s - 1, y + s - 1), fill=col + (230,))


def _hit(img, P, rnd):
    x, y = (P["sh_f"][0] + 7) * S, (P["sh_f"][1] - 1) * S
    _sparkle(img, (x, y), 6, (240, 240, 244), (200, 200, 210))
    p = img.load()
    for i in range(10):
        xx, yy = int(x + rnd.gauss(0, 6)), int(y + rnd.gauss(0, 5))
        if 0 <= xx < img.width - 1 and 0 <= yy < img.height - 1:
            col = rnd.choice([(10, 10, 12), (10, 10, 12), MAGENTA, (220, 220, 226)])
            p[xx, yy] = col + (255,)
            p[xx + 1, yy] = col + (255,)


def _rim_light(img, strength=0.38):
    """Randlicht: pixels met een lege buur links of boven worden lichter (licht van
    linksboven), rechts/onder een fractie. Zo komt het figuur los van de grijze zaal."""
    a = np.array(img).astype(np.float32)
    al = a[:, :, 3]
    solid = al > 200
    empty = al < 40
    left = np.zeros_like(solid); left[:, 1:] = empty[:, :-1]; left[:, 0] = True
    up = np.zeros_like(solid); up[1:, :] = empty[:-1, :]; up[0, :] = True
    right = np.zeros_like(solid); right[:, :-1] = empty[:, 1:]
    lit = solid & (left | up)
    rim = np.array(RIM, np.float32)
    a[lit, :3] = a[lit, :3] * (1 - strength) + rim * strength
    soft = solid & right & ~lit
    a[soft, :3] = a[soft, :3] * 0.88 + rim * 0.12
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA").copy()


def _shadow(cx, cy, rx, ry):
    return ab.ground_shadow(F, F, cx, cy, rx * K, ry * K, alpha=120)


def _ko_pose(spec):
    P = ab._pose(wz=0, el_f=(46, 45), ha_f=(46, 53), el_n=(32, 45), ha_n=(33, 53),
                 hip_f=(42, 55), hip_n=(37, 55), kn_f=(42, 65), ft_f=(42, 74), kn_n=(37, 65), ft_n=(37, 74),
                 sh_f=(45, 36), sh_n=(32, 37))
    P = _stretch(P)
    # liggend, hoofd naar links (zelfde vormen, 90 graden gedraaid)
    P = ab._transform_pose(P, lambda p: (8 + (p[1] - 14) * 1.0, 89 - (p[0] - 48)))
    P["weapon"] = 172 if spec["weapon"] == "zwaard" else -178
    P["tilt"] = -1.5708
    return P


IDLE_GLOW = {0: 1.0, 8: 1.3, 9: 0.8}       # bol/kristal pulseert in de adem-frames


def _render_frame(key, P, i, seed):
    spec = SPECS[key]
    rnd = random.Random(seed * 100 + i)
    c, out = _hero_canvas(key, P)
    img = _rim_light(c.render())
    tip = out["tip"]
    tip_px = (tip[0] * S, tip[1] * S) if tip else None
    if out["blade"]:
        _dissolve_blade(img, out["blade"], rnd, 1.0 if i != 3 else 1.2)
    fx = P["fx"]
    pulse = IDLE_GLOW.get(i, 1.0)
    if spec["weapon"] == "orbstaf" and tip_px:
        # de bol gloeit altijd een beetje, bij een spreuk fel
        if fx == "gloed":
            _glow(img, tip_px, 15 * K, NEON_MAGENTA, 1.0)
            _sparkle(img, tip_px, 13, MAGENTA_HOT, MAGENTA)
        elif i == 4:
            _glow(img, tip_px, 10 * K, NEON_MAGENTA, 0.9)
        else:
            _glow(img, tip_px, 7.5 * K * pulse, NEON_MAGENTA, 0.75 + 0.15 * (pulse - 1))
    elif spec["weapon"] == "ringstaf" and tip_px:
        if fx == "gloed":
            _glow(img, tip_px, 14 * K, NEON_CYAN, 1.0)
            _sparkle(img, tip_px, 12, CYAN_HOT, CYAN)
        elif i == 4:
            _glow(img, tip_px, 8 * K, NEON_CYAN, 0.8)
        else:
            _glow(img, tip_px, 5.5 * K * pulse, NEON_CYAN, 0.6)
    elif fx == "glinster" and tip_px:
        _sparkle(img, tip_px, 10, CYAN_HOT, CYAN)
    if fx == "zwaai":
        _slash(img, P, rnd)
    if fx == "raak":
        _hit(img, P, rnd)
    cx = (P["ft_n"][0] / 2 + P["ft_f"][0] / 2 + 2) * S
    fr = _shadow(cx, FEET[1] + 0.5, 22, 4.6)
    fr.alpha_composite(img)
    return fr


def make_sheet(key, seed=1):
    spec = SPECS[key]
    poses = SWORD if spec["weapon"] == "zwaard" else STAFF
    sheet = Image.new("RGBA", (F * 10, F), (0, 0, 0, 0))
    for i, P in enumerate(poses):
        sheet.alpha_composite(_render_frame(key, P, i, seed), (i * F, 0))
    # adem-frames (idle-animatie): 8 = inademen, 9 = uitademen
    sheet.alpha_composite(_render_frame(key, _breathe(poses[0], -0.9, 1.8), 8, seed), (8 * F, 0))
    sheet.alpha_composite(_render_frame(key, _breathe(poses[0], 0.35, -1.6), 9, seed), (9 * F, 0))
    # KO
    P = _ko_pose(spec)
    c, out = _hero_canvas(key, P, ko=True)
    img = _rim_light(c.render())
    if out["blade"]:
        _dissolve_blade(img, out["blade"], random.Random(seed * 100 + 7), 0.8)
    fr = _shadow(FEET[0] - 4 * K, FEET[1] - 1.5, 44, 5.0)
    fr.alpha_composite(img)
    sheet.alpha_composite(fr, (7 * F, 0))
    return sheet


def save_all(root):
    import os
    d = os.path.join(root, "assets", "sprites", "battle")
    os.makedirs(d, exist_ok=True)
    for i, key in enumerate(("dennis", "noor", "lotte")):
        make_sheet(key, i + 1).save(os.path.join(d, key + ".png"))


if __name__ == "__main__":
    import os
    save_all(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
