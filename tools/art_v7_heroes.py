"""Gevechtshelden voor 'De Vergeten Bibliotheek' (v7), eigen werk.

Groot (zoals de mockup): elk frame is 160x160 art-pixels, getoond op schaal 0.5 op het
768x432-raster. De figuur zelf is ±112 fijne pixels hoog (2x zo groot als v6).
Voeten (midden van de grondschaduw) op (80, 154) in elk frame.
Strook: 8 frames naast elkaar = 1280x160:
    0 stil, 1 klaar, 2 aanval A, 3 aanval B, 4 spreuk A, 5 spreuk B, 6 geraakt, 7 KO

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
S = 1.6                       # art-pixels per eenheid -> frame 160x160
F = int(DW * S)
FEET = (80, 154)              # in art-pixels (zie battle_hero.gd)
K = S / 1.4                   # effecten (gloed, schaduw) waren gemaakt voor S = 1.4
VS = 1.2                      # lijf langer dan v6
ROBE_PALE = ramp("232327", "3e3e44", "5c5c63", "7e7e85", "a2a2a7", "c4c4c7")
HAIR_DARK = ramp("0d0a0a", "1c1614", "2c221e", "3d2f29", "533f35", "6c5446")   # Dennis: bijna zwart, bruine glans
CAPE_DARK2 = ramp("0c0c10", "17171c", "222228", "2f2f36", "3e3e46", "54545c")
RIM = (206, 206, 214)         # randlicht van linksboven (losser van de grijze achtergrond)
CAPE_GREY = ramp("0e0e11", "19191d", "25252a", "323238", "414148", "54545b")
WOOD_PALE = ramp("221c17", "3e342b", "5c5044", "7a6d5e", "988b7a", "b6aa98")


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


SWORD = [_stretch(p) for p in ab.SWORD_POSES]
STAFF = [_stretch(p) for p in ab.STAFF_POSES]


# ---------------------------------------------------------------- hoofd en haar
def _head(c, P, kind):
    h = P["head"]
    t = P["tilt"]
    R = lambda d: rot_pt(add(h, d), h, t)
    c.capsule(R((1.5, 5.5)), P["neck"], 2.4, 2.7, SKIN, bias=-0.12)
    c.ellipse(h, 6.9, 7.4, SKIN, rot=t)
    c.ellipse(R((4.3, 2.4)), 2.7, 3.4, SKIN, bias=0.02)                 # wang / kaak
    if kind == "dennis":
        hair = HAIR_DARK
        c.ellipse(R((-1.0, -1.4)), 7.6, 7.8, hair, rot=t, bias=0.02)
        for (a_, b_, r, bias) in (((0, 3), (-1.0, 9.0), 3.4, -0.04), ((-3, 2), (-9.0, 6.0), 3.4, -0.02),
                                  ((-3, -1), (-10.0, -1.0), 3.6, 0.0), ((-2, -3), (-7.8, -7.6), 3.8, 0.03),
                                  ((1, -4), (1.5, -9.0), 3.6, 0.05), ((-1, -4), (-4.0, -9.5), 3.9, 0.06),
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
def _cape(c, P, rmp, length=1.0, narrow=0.0, flare=1.0):
    """Cape van achteren gezien: van de schouders over de rug, wijder naar onder."""
    sn, sf, hn, hf = P["sh_n"], P["sh_f"], P["hip_n"], P["hip_f"]
    kn, kf, fn, ff = P["kn_n"], P["kn_f"], P["ft_n"], P["ft_f"]
    sway = -5.0 if P.get("fx") == "zwaai" else (-2.5 if P.get("wz") == 0 else 0.0)
    if P.get("fx") == "raak":
        sway = 3.0
    bot = lerp(hn, lerp(kn, fn, 0.5), length)[1] + 1
    top_l, top_r = add(sn, (-2, -2.5)), add(sf, (2, -3))
    xl = hn[0] - 7.5 * flare + narrow + sway
    xr = hf[0] + 6.5 * flare - narrow + sway * 0.6
    hem = []
    n = 7
    for k in range(n + 1):
        tt = k / n
        hem.append((xl + (xr - xl) * tt, bot + (1.8 if k % 2 else -0.5) + tt * 1.8))
    pts = [top_l, lerp(top_l, top_r, 0.5), top_r, add(sf, (3.2, 7)), (xr + 1, bot - 8)] + hem[::-1] + \
          [(xl - 1, bot - 8), add(sn, (-3.5, 8))]
    c.polygon(pts, rmp, curve=1.0, tilt=-0.25, vgrad=0.5)
    for tt in (0.1, 0.3, 0.52, 0.74, 0.9):
        x_end = xl + (xr - xl) * tt
        c.crease([add(lerp(top_l, top_r, 0.2 + tt * 0.6), (0, 5)), (x_end + 0.5, bot - 1)], 0.2)
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


def _torso_pts(P, widen=1.2):
    return ab._torso_pts(P, widen)


def _body_dennis(c, P):
    hn, hf, sn, sf = P["hip_n"], P["hip_f"], P["sh_n"], P["sh_f"]
    # grijs harnas (zie je opzij van de cape) + leren rok met riem
    skirt = [add(hn, (-3, -3)), add(hf, (3, -3)), add(hf, (5, 7)), add(lerp(hn, hf, 0.5), (0, 8)), add(hn, (-5, 7))]
    c.polygon(skirt, LEATHER, curve=1.0, tilt=0.1, bias=-0.04)
    c.polygon(_torso_pts(P), ARMOR, curve=1.0, tilt=-0.3, vgrad=0.5, bias=-0.05)
    waist_y = (hn[1] + hf[1]) / 2 - 3.5
    c.capsule((hn[0] - 3.5, waist_y + (hn[1] - hf[1]) / 2), (hf[0] + 3.5, waist_y), 1.8, 1.8, LEATHER)
    mid, bot = _cape(c, P, CAPE_DARK2, length=0.95, narrow=0.0, flare=1.15)
    _emblem(c, add(mid, (0.5, 14)), 1.05)
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
    mid, bot = _cape(c, P, CAPE_GREY, length=0.75, narrow=0.5)
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
    c.polygon(cap, ramp("2c2c31", "4c4c53", "6c6c73", "8c8c92", "aaaaae", "c6c6c9"), curve=1.0, tilt=-0.35, vgrad=0.4)
    for tt in (0.3, 0.55, 0.8):
        c.crease([lerp(add(sn, (0, 1)), add(sf, (0, 1)), tt), lerp(add(sn, (-1, 10)), add(sf, (1, 10)), tt)], 0.18)
    hood = add(lerp(sn, sf, 0.45), (0, 3.0))
    c.ellipse(hood, 5.2, 3.6, ramp("2c2c31", "4c4c53", "6c6c73", "8c8c92", "aaaaae", "c6c6c9"), bias=0.06)
    c.crease([add(hood, (-3.5, -0.5)), add(hood, (0, 1.8)), add(hood, (3.5, -0.5))], 0.3, light=False)
    c.capsule(lerp(add(sn, (-3.5, 9)), lerp(add(sn, (0, 15)), add(sf, (0, 15)), 0.55), 0.1),
              lerp(add(sn, (-3.5, 9)), lerp(add(sn, (0, 15)), add(sf, (0, 15)), 0.55), 0.9), 0.5, 0.5,
              NEON_CYAN, bias=0.0, outline=False)


SPECS = {
    "dennis": {"weapon": "zwaard", "head": "dennis", "sleeve": CLOTH, "forearm": ARMOR, "legs": True,
              "trousers": CLOTH, "boots": LEATHER, "body": _body_dennis, "pauldron": True, "glow": NEON_CYAN},
    "noor": {"weapon": "orbstaf", "head": "noor", "sleeve": CLOTH, "forearm": LEATHER, "legs": True,
             "trousers": CLOTH, "boots": LEATHER, "body": _body_noor, "glow": NEON_MAGENTA},
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


def make_sheet(key, seed=1):
    spec = SPECS[key]
    poses = SWORD if spec["weapon"] == "zwaard" else STAFF
    sheet = Image.new("RGBA", (F * 8, F), (0, 0, 0, 0))
    for i, P in enumerate(poses):
        rnd = random.Random(seed * 100 + i)
        c, out = _hero_canvas(key, P)
        img = _rim_light(c.render())
        tip = out["tip"]
        tip_px = (tip[0] * S, tip[1] * S) if tip else None
        if out["blade"]:
            _dissolve_blade(img, out["blade"], rnd, 1.0 if i != 3 else 1.2)
        fx = P["fx"]
        if spec["weapon"] == "orbstaf" and tip_px:
            # de bol gloeit altijd een beetje, bij een spreuk fel
            if fx == "gloed":
                _glow(img, tip_px, 15 * K, NEON_MAGENTA, 1.0)
                _sparkle(img, tip_px, 10, MAGENTA_HOT, MAGENTA)
            elif i == 4:
                _glow(img, tip_px, 10 * K, NEON_MAGENTA, 0.9)
            else:
                _glow(img, tip_px, 7 * K, NEON_MAGENTA, 0.75)
        elif spec["weapon"] == "ringstaf" and tip_px:
            if fx == "gloed":
                _glow(img, tip_px, 14 * K, NEON_CYAN, 1.0)
                _sparkle(img, tip_px, 9, CYAN_HOT, CYAN)
            elif i == 4:
                _glow(img, tip_px, 8 * K, NEON_CYAN, 0.8)
            else:
                _glow(img, tip_px, 5 * K, NEON_CYAN, 0.6)
        elif fx == "glinster" and tip_px:
            _sparkle(img, tip_px, 8, CYAN_HOT, CYAN)
        if fx == "zwaai":
            _slash(img, P, rnd)
        if fx == "raak":
            _hit(img, P, rnd)
        cx = (P["ft_n"][0] / 2 + P["ft_f"][0] / 2 + 2) * S
        fr = _shadow(cx, FEET[1] + 0.5, 21, 4.6)
        fr.alpha_composite(img)
        sheet.alpha_composite(fr, (i * F, 0))
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
