#!/usr/bin/env python3
"""
"16-bit plus" gevechts-art (v6), eigen werk. Wordt aangeroepen door generate_art.py.
Alles is op DUBBELE resolutie getekend: het gevecht rendert op 768x432 (zie
scripts/battle/battle.gd), dus 1 art-pixel = 1 pixel van dat fijne raster.

Werkwijze (geen blur, geen dithering, alles harde pixels):
  - Een personage bestaat uit eenvoudige vormen: capsules (armen, benen, wapens),
    ellipsen (hoofd, handen, buik) en polygonen (tunieken, gewaden, vleugels).
  - Elke vorm krijgt per pixel een 'normaal' (welke kant hij op wijst). Licht komt van
    linksboven-voor; de helderheid wordt afgerond naar een ramp van 6 tinten met
    kleurverschuiving (schaduw koeler/paarser, licht warmer).
  - Vouwen en haarlokken zijn 'kreukels': een donkere lijn met een lichte rand ernaast.
  - Omlijning: de buitenrand krijgt de donkerste tint van zijn eigen materiaal
    (aan de lichte kant een tint lichter = 'selectieve omlijning'); waar een vorm voor
    een andere ligt, krijgt de achterste een donker randje (diepte).
  - Poses zijn lijsten met gewrichten (schouder, elleboog, hand, heup, knie, voet).
  - Achtergronden staan in art_battle_bg.py.

Output:
  assets/sprites/battle/<held>.png   640x80: 8 frames van 80x80, voeten op (40, 77)
        0 stil, 1 klaar, 2 aanval A, 3 aanval B, 4 spreuk A, 5 spreuk B, 6 geraakt, 7 KO
        (ontworpen in een raster van 96x96 'eenheden', getekend op schaal 5/6: zie
        Canvas(..., scale) - meer pixels per vorm, omlijning blijft 1 pixel)
  assets/sprites/enemies/<id>.png    goblin 64x72, slijm 78x62, vleermuis 79x69
        (GOB_S 0.5, SLIME_S 0.7, BAT_S 0.62; voeten = midden onderaan, vlak boven de rand)
  assets/battle/backdrop_bos.png, backdrop_vlakte.png   1280x432
  assets/ui/window_hd.png, panel_status_hd.png, window_glass_hd.png   24x24 (9-slice, rand 8)
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

import generate_art as ga

hexc = ga.hexc


def rgb(h):
    return tuple(hexc(h)[:3])


def ramp(*hexes):
    return [rgb(h) for h in hexes]


# ---------------------------------------------------------------- paletten (6 tinten, hue-shift)
SKIN = ramp("3e1f22", "74392e", "aa5f45", "d48a63", "eeb185", "fbd7b0")
HAIR_BROWN = ramp("1e1014", "3e2018", "62361e", "885226", "ab7434", "cc9a52")
TUNIC = ramp("0f1a14", "1c3018", "30491e", "486426", "668432", "8ea446")      # olijfgroen
LEATHER = ramp("1a0f10", "37211a", "553524", "754c30", "966a40", "b88c58")
STEEL = ramp("15161f", "2f3446", "525c74", "7f8ca4", "b2bfd0", "eef3f8")
GOLD = ramp("33200c", "6a4414", "a2701c", "cfa02c", "eccb5a", "fff0b0")
ROBE_BLUE = ramp("090a22", "131a42", "1d2a66", "2a3d8e", "4157ae", "6a82cc")
HAIR_DARK = ramp("140c18", "2a1626", "45223a", "64304c", "844462", "a4607a")
WOOD = ramp("1c100c", "3a2214", "5c381e", "80522a", "a2703a", "c2925a")
WOOD_LIGHT = ramp("2e1c10", "52361c", "7a5428", "a07436", "c4984c", "e2bc70")
HAIR_BLOND = ramp("3c2410", "735018", "a87e24", "d2a834", "eccb52", "fbe892")
ROBE_WHITE = ramp("2c2a44", "57587a", "8a8eaa", "b8bcd0", "dee0ea", "fbfbff")
TRIM_RED = ramp("2a0c14", "561622", "86222e", "b0363a", "d0584c", "ec8868")
ORB = ramp("12204a", "1f4a8a", "2f86c2", "54c2e2", "9ae8f4", "f4ffff")
# vijanden
GOB_SKIN = ramp("10180c", "22341a", "3a5224", "567232", "7a9444", "a6b85e")
GOB_CLOTH = ramp("1a100c", "34201a", "4e3224", "6a4630", "866040", "a47e56")
SLIME = ramp("06201e", "0c3a32", "17584a", "26806a", "3ea888", "7ed2b0")
BAT_FUR = ramp("120a14", "26142a", "3c2240", "56345a", "744a74", "966894")
BAT_WING = ramp("14080e", "2c1220", "461c30", "642a42", "843e58", "a85a74")
EYE_RED = ramp("3a0808", "7a1010", "c02018", "f04a2a", "ff8a4a", "ffd890")
EYE_YEL = ramp("3a2a08", "7a5a10", "c09018", "f0c42a", "ffe060", "fff8c0")
BONE = ramp("3a3028", "6a5a48", "988670", "c0b098", "e0d6c2", "faf6ec")

OUTLINE_DARK = rgb("120a10")
LIGHT = np.array([-0.58, -0.62, 0.52])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


# ---------------------------------------------------------------- de mini-rasterizer
class Canvas:
    """Verzamelt vormen (achter naar voor) en zet ze om in pixels."""

    def __init__(self, w, h, scale=1.0):
        """w, h = grootte in ontwerp-eenheden; scale = echte pixels per eenheid.
        Alle vormen worden in ontwerp-eenheden opgegeven; bij scale > 1 krijgt elke vorm
        meer echte pixels (fijnere schaduw), terwijl omlijning en plooien 1 pixel blijven."""
        self.s = scale
        w, h = int(round(w * scale)), int(round(h * scale))
        self.w, self.h = w, h
        self.Y, self.X = (np.mgrid[0:h, 0:w].astype(float) + 0.5) / scale
        self.mat = np.full((h, w), -1, int)
        self.val = np.zeros((h, w))
        self.part = np.full((h, w), -1, int)
        self.flat = np.zeros((h, w), bool)        # geen omlijning (bv. gloed)
        self.ramps = []
        self.nparts = 0
        self.overrides = []                       # (x, y, kleur) na de omlijning
        self.ambient = 0.10
        self.diffuse = 0.98

    # --- materialen
    def _mid(self, rmp):
        for i, r in enumerate(self.ramps):
            if r is rmp:
                return i
        self.ramps.append(rmp)
        return len(self.ramps) - 1

    def _shade(self, nx, ny, nz, bias):
        lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        return self.ambient + self.diffuse * lam + bias

    def _put(self, mask, val, rmp, outline=True):
        if not mask.any():
            return
        pid = self.nparts
        self.nparts += 1
        self.mat[mask] = self._mid(rmp)
        self.val[mask] = val[mask]
        self.part[mask] = pid
        self.flat[mask] = not outline

    # --- vormen
    def ellipse(self, c, rx, ry, rmp, rot=0.0, bias=0.0, outline=True, flat_z=1.0):
        dx, dy = self.X - c[0], self.Y - c[1]
        if rot:
            ca, sa = math.cos(rot), math.sin(rot)
            dx, dy = dx * ca + dy * sa, -dx * sa + dy * ca
        u, v = dx / rx, dy / ry
        d2 = u * u + v * v
        mask = d2 <= 1.0
        nz = np.sqrt(np.clip(1 - d2, 0, 1)) * flat_z
        nx, ny = u, v
        if rot:
            ca, sa = math.cos(rot), math.sin(rot)
            nx, ny = u * ca - v * sa, u * sa + v * ca
        n = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-9
        self._put(mask, self._shade(nx / n, ny / n, nz / n, bias), rmp, outline)
        return mask

    def capsule(self, p0, p1, r0, r1, rmp, bias=0.0, outline=True):
        (x0, y0), (x1, y1) = p0, p1
        sx, sy = x1 - x0, y1 - y0
        L2 = sx * sx + sy * sy + 1e-9
        t = np.clip(((self.X - x0) * sx + (self.Y - y0) * sy) / L2, 0, 1)
        cx, cy = x0 + t * sx, y0 + t * sy
        r = r0 + (r1 - r0) * t
        dx, dy = self.X - cx, self.Y - cy
        d = np.sqrt(dx * dx + dy * dy)
        mask = d <= r
        nx, ny = dx / np.maximum(r, 0.5), dy / np.maximum(r, 0.5)
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
        self._put(mask, self._shade(nx, ny, nz, bias), rmp, outline)
        return mask

    def polygon(self, pts, rmp, bias=0.0, curve=1.0, tilt=-0.25, outline=True, vgrad=0.0):
        """Polygoon met 'cilinder'-schaduw per rij (zoals stof om een lijf)."""
        m = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(m).polygon([(p[0] * self.s, p[1] * self.s) for p in pts], fill=255)
        mask = np.array(m) > 0
        u = np.zeros((self.h, self.w))
        ys = np.where(mask.any(axis=1))[0]
        if len(ys):
            y0, y1 = ys.min(), ys.max()
        for y in ys:
            xs = np.where(mask[y])[0]
            xl, xr = xs.min(), xs.max() + 1
            u[y, xs] = ((xs + 0.5 - xl) / max(1, xr - xl)) * 2 - 1
        nx = u * curve
        ny = np.full_like(u, tilt)
        if len(ys) and vgrad:
            ny = ny + vgrad * ((self.Y * self.s - y0) / max(1, y1 - y0) - 0.5)
        nz = np.sqrt(np.clip(1 - nx * nx * 0.85, 0.05, 1))
        n = np.sqrt(nx * nx + ny * ny + nz * nz)
        self._put(mask, self._shade(nx / n, ny / n, nz / n, bias), rmp, outline)
        return mask

    # --- details
    def crease(self, pts, strength=0.22, light=True, width=1):
        """Vouw/lok: donkere lijn, met een lichte pixel aan de lichtkant."""
        m = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(m).line([(p[0] * self.s, p[1] * self.s) for p in pts], fill=255, width=width)
        line = (np.array(m) > 0) & (self.mat >= 0)
        self.val[line] -= strength
        if light:
            hl = np.roll(np.roll(line, -1, axis=0), -1, axis=1) & ~line & (self.mat >= 0)
            self.val[hl] += strength * 0.55

    def tint(self, mask, delta):
        self.val[mask & (self.mat >= 0)] += delta

    def px(self, x, y, color):
        self.overrides.append((int(x * self.s), int(y * self.s), color))

    # --- naar een plaatje
    def render(self, levels=6):
        h, w = self.h, self.w
        out = np.zeros((h, w, 4), np.uint8)
        idx = np.clip((self.val * levels).astype(int), 0, levels - 1)
        filled = self.mat >= 0
        # diepte-randje: een pixel achter een vorm die ervoor ligt wordt donkerder
        edge_back = np.zeros((h, w), bool)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb = np.roll(np.roll(self.part, dy, axis=0), dx, axis=1)
            nbm = np.roll(np.roll(self.flat, dy, axis=0), dx, axis=1)
            edge_back |= filled & (nb > self.part) & (nb >= 0) & ~nbm & ~self.flat
        idx = np.where(edge_back, np.maximum(idx - 2, 0), idx)
        # buitenrand
        outside = ~filled
        border = np.zeros((h, w), bool)
        lit_side = np.zeros((h, w), bool)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb = np.roll(np.roll(outside, dy, axis=0), dx, axis=1)
            if dy == 1:
                nb[0, :] = True
            if dy == -1:
                nb[-1, :] = True
            if dx == 1:
                nb[:, 0] = True
            if dx == -1:
                nb[:, -1] = True
            border |= filled & nb
            if dy == 1 or dx == 1:          # leeg boven/links = lichtkant
                lit_side |= filled & nb
        for mi, rmp in enumerate(self.ramps):
            sel = self.mat == mi
            cols = np.array(rmp, np.uint8)
            out[sel, :3] = cols[idx[sel]]
            out[sel, 3] = 255
            b = sel & border & ~self.flat
            dark = np.array(rmp[0], float) * 0.62 + np.array(OUTLINE_DARK, float) * 0.38
            out[b & ~lit_side, :3] = dark.astype(np.uint8)
            out[b & lit_side, :3] = cols[np.minimum(1, len(rmp) - 1)]
        img = Image.fromarray(out, "RGBA").copy()
        p = img.load()
        for (x, y, c) in self.overrides:
            if 0 <= x < w and 0 <= y < h:
                p[x, y] = tuple(c) + ((255,) if len(c) == 3 else ())
        return img


def ground_shadow(w, h, cx, cy, rx, ry, alpha=110):
    """Ovale grondschaduw (2 tinten, harde rand)."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    p = img.load()
    for y in range(h):
        for x in range(w):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d < 1:
                p[x, y] = (14, 10, 16, alpha if d > 0.45 else alpha + 30)
    return img


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def rot_pt(p, c, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    dx, dy = p[0] - c[0], p[1] - c[1]
    return (c[0] + dx * ca - dy * sa, c[1] + dx * sa + dy * ca)


# ================================================================ helden
HF_W = 96                      # ontwerp-frame 96x96, voeten op (48, 92)
HERO_PX = 80                   # echt frame 80x80 (schaal 5/6): figuur ±55 px hoog (Octopath-achtig)
HERO_S = HERO_PX / HF_W
FRAME_SHIFT = (8, 16)          # de poses hieronder zijn getekend voor voeten op (40, 76)
CAPE_RED = ramp("1e0a10", "421218", "6a1c20", "8e2a26", "b04232", "cc6a48")   # Dennis: karmijn cape
CAPE_SAGE = ramp("141c16", "26342a", "3e5040", "5a6e56", "7c9072", "a2b494")  # Lotte: saliegroen manteltje
TROUSERS = ramp("140f14", "2a2028", "41323a", "5a4648", "765e5a", "927a70")
BOOT = LEATHER
BASE_POSE = {
    "head": (37, 25), "neck": (39, 33),
    "sh_n": (31, 37), "sh_f": (47, 36), "hip_n": (35, 55), "hip_f": (44, 54),
    "el_n": (28, 46), "ha_n": (30, 53), "el_f": (53, 44), "ha_f": (56, 51),
    "kn_n": (34, 65), "ft_n": (32, 74), "kn_f": (46, 64), "ft_f": (48, 73),
    "weapon": 55, "wz": 1, "fx": None, "tilt": 0.0,
}


def _pose(**over):
    p = dict(BASE_POSE)
    shift = over.pop("shift", (0, 0))       # hele lichaam
    upper = over.pop("upper", (0, 0))       # alleen bovenlijf (leunen)
    for k in ("head", "neck", "sh_n", "sh_f", "el_n", "ha_n", "el_f", "ha_f"):
        p[k] = add(p[k], upper)
    p.update(over)
    shift = add(shift, FRAME_SHIFT)
    for k, v in list(p.items()):
        if isinstance(v, tuple) and len(v) == 2:
            p[k] = add(v, shift)
    return p


SWORD_POSES = [
    _pose(),                                                                    # stil
    _pose(shift=(1, 1), upper=(2, 0), el_f=(56, 42), ha_f=(61, 44), weapon=-38,
          el_n=(31, 45), ha_n=(35, 50), kn_n=(33, 65), kn_f=(48, 64), ft_f=(51, 73)),  # klaar
    _pose(upper=(-2, 0), el_f=(50, 30), ha_f=(44, 21), weapon=-150, wz=0,
          el_n=(25, 43), ha_n=(25, 50)),                                        # aanval A
    _pose(shift=(5, 1), upper=(3, 1), el_f=(60, 41), ha_f=(66, 45), weapon=28, wz=2,
          el_n=(30, 46), ha_n=(29, 53), ft_f=(55, 73), kn_f=(51, 64), ft_n=(28, 74),
          kn_n=(31, 65), fx="zwaai"),                                           # aanval B
    _pose(el_f=(52, 34), ha_f=(53, 25), weapon=-90),                            # spreuk A
    _pose(el_f=(52, 34), ha_f=(53, 25), weapon=-90, fx="glinster"),             # spreuk B
    _pose(shift=(-4, 0), upper=(-3, 1), el_n=(24, 41), ha_n=(19, 45), el_f=(51, 41),
          ha_f=(56, 37), weapon=-20, tilt=-0.18, fx="raak"),                    # geraakt
]
STAFF_POSES = [
    _pose(weapon=-84),
    _pose(shift=(1, 1), upper=(2, 0), el_f=(55, 41), ha_f=(59, 43), weapon=-70,
          el_n=(31, 45), ha_n=(35, 50), kn_f=(48, 64), ft_f=(51, 73)),
    _pose(upper=(-2, 0), el_f=(51, 34), ha_f=(50, 25), weapon=-115, wz=0,
          el_n=(25, 43), ha_n=(25, 50)),
    _pose(shift=(4, 1), upper=(3, 1), el_f=(60, 40), ha_f=(66, 43), weapon=-20, wz=2,
          ft_f=(54, 73), kn_f=(50, 64), ft_n=(29, 74), fx="zwaai"),
    _pose(el_f=(52, 35), ha_f=(55, 27), weapon=-86, el_n=(25, 41), ha_n=(23, 34)),
    _pose(el_f=(52, 35), ha_f=(55, 27), weapon=-86, el_n=(25, 41), ha_n=(23, 34), fx="gloed"),
    _pose(shift=(-4, 0), upper=(-3, 1), el_n=(24, 41), ha_n=(19, 45), el_f=(51, 41),
          ha_f=(56, 38), weapon=-60, tilt=-0.18, fx="raak"),
]


def _dir(deg):
    a = math.radians(deg)
    return (math.cos(a), math.sin(a))


def _limb(c, a, b, cc, r0, r1, r2, rmp_upper, rmp_lower, bias=0.0):
    c.capsule(a, b, r0, r1, rmp_upper, bias)
    c.capsule(b, cc, r1 * 0.95, r2, rmp_lower, bias)


def _leg(c, P, side, trouser, boot, boot_top=0.55, bias=0.0, foot=(2.6, 0.6)):
    hip, kn, ft = P["hip_" + side], P["kn_" + side], P["ft_" + side]
    c.capsule(hip, kn, 3.9, 3.2, trouser, bias)
    top = lerp(kn, ft, boot_top)
    c.capsule(kn, top, 3.1, 2.9, trouser, bias)
    c.capsule(top, ft, 3.3, 2.9, boot, bias)
    c.ellipse(add(ft, foot), 4.4 if foot[0] else 2.8, 2.6 if foot[0] else 3.6, boot, bias=bias)  # voet
    c.crease([add(top, (-3, 0)), add(top, (3, 0))], 0.18)             # laarsrand


def _torso_pts(P, widen=0.0, waist_drop=0.0):
    sn, sf, hn, hf = P["sh_n"], P["sh_f"], P["hip_n"], P["hip_f"]
    return [add(sn, (-2 - widen, -2)), lerp(sn, sf, 0.5 + 0.0), add(sf, (2 + widen, -2.5)),
            add(sf, (2.5 + widen, 5)), add(hf, (2.5 + widen, -3 + waist_drop)),
            add(hf, (3 + widen, 2 + waist_drop)), add(hn, (-3 - widen, 2 + waist_drop)),
            add(hn, (-2.5 - widen, -3 + waist_drop)), add(sn, (-2.5 - widen, 5))]


def _sheen(c, h, tilt, r, a0, a1, strength=0.28):
    """Glansband in het haar (de 'lichtring' van 16-bit sprites)."""
    pts = []
    for i in range(9):
        a = math.radians(a0 + (a1 - a0) * i / 8)
        pts.append(rot_pt((h[0] + r * math.cos(a), h[1] + r * math.sin(a) * 0.95), h, tilt))
    c.crease(pts, -strength, light=False, width=2)


def _head(c, P, hair, kind):
    h = P["head"]
    tilt = P["tilt"]
    R = lambda d: rot_pt(add(h, d), h, tilt)
    c.capsule(R((2, 6)), P["neck"], 2.7, 2.9, SKIN, bias=-0.1)                # nek
    c.ellipse(h, 8.4, 8.8, SKIN, rot=tilt)                                     # hoofd
    c.ellipse(R((5.6, 3.0)), 3.4, 3.8, SKIN, bias=0.02)                       # wang/kaak
    if kind == "kort":         # Dennis: bos haar uit grote plukken die naar achter-boven waaieren
        c.ellipse(R((-1.2, -1.0)), 9.2, 9.4, hair, rot=tilt, bias=-0.06)
        clumps = (((0, 3), (-1, 9.5), 3.8, -0.04),      # nek
                  ((-3, 2), (-11, 7), 3.6, -0.02),
                  ((-3, -1), (-14.5, -1.5), 3.9, 0.0),
                  ((-2, -3), (-13, -10), 4.1, 0.02),
                  ((2, -3), (2.5, -14.5), 3.7, 0.04),
                  ((-1, -4), (-6, -15.5), 4.3, 0.06),
                  ((4, -1), (7.6, 1.5), 2.4, 0.0))      # lok voor het oor
        for (a_, b_, r, bias) in clumps:
            c.capsule(R(a_), R(b_), r, 0.9, hair, bias=bias)
        for st in (((1, -6), (-3, -11)), ((-4, -3), (-10, -6)), ((-3, 1), (-10, 1)), ((3, -6), (3, -11)),
                   ((-1, 4), (-1, 7)), ((-4, 4), (-8, 6))):
            c.crease([R(q) for q in st], 0.16)
        _sheen(c, R((-1.0, -3.0)), tilt, 6.0, 205, 285, 0.3)
    elif kind == "lang":       # Lotte: blond, paardenstaart
        c.capsule(R((-5, 2)), R((-9, 21)), 4.0, 2.4, hair)
        c.capsule(R((-9, 21)), R((-7, 28)), 2.4, 0.8, hair)
        c.ellipse(R((-2.0, -2.2)), 9.2, 8.8, hair, rot=tilt)
        c.capsule(R((5.5, -4)), R((7.4, 5)), 2.4, 1.1, hair)                 # lok langs het oor
        c.ellipse(R((-7.5, 7.5)), 2.0, 1.5, TRIM_RED, rot=0.5)              # strik bij de staart
        c.ellipse(R((-4.5, 7.0)), 2.0, 1.5, TRIM_RED, rot=-0.5)
        for s in (((-6, -7), (-5, -1), (-5, 5)), ((-2, -9), (-1, -3), (-1, 3)), ((2, -8), (3, -3), (3, 1)),
                  ((-8, 7), (-9, 14), (-9, 20)), ((-6, 9), (-7, 15), (-7, 20))):
            c.crease([R(p) for p in s], 0.2)
        _sheen(c, R((-2.0, -2.2)), tilt, 6.4, 195, 300, 0.3)
    elif kind == "hoed":       # Noor: donker haar onder een puntige hoed
        c.ellipse(R((-2.0, -0.8)), 9.0, 8.6, hair, rot=tilt)
        c.capsule(R((-4, 4)), R((-6, 11)), 3.6, 2.4, hair)
        c.capsule(R((4.5, -1)), R((6, 6)), 2.0, 1.0, hair)
        for s in (((-6, 0), (-6, 5), (-6, 10)), ((-2, 1), (-2, 6)), ((2, 0), (3, 5))):
            c.crease([R(p) for p in s], 0.2)


def _hat(c, P):
    h = P["head"]
    t = P["tilt"]
    R = lambda d: rot_pt(add(h, d), h, t)
    cone = [R((-8, -5)), R((-5, -12)), R((-4, -17)), R((-8, -22)), R((-15, -23)),
            R((-11, -19)), R((-2, -21)), R((3, -15)), R((7, -6))]
    c.polygon([R((-8.5, -5)), R((-6, -13)), R((-5, -18)), R((-9, -22)), R((-16, -24)),
               R((-10, -25)), R((-3, -22)), R((2, -16)), R((7.5, -5))], ROBE_BLUE,
              curve=0.9, tilt=-0.35, bias=0.04)
    c.ellipse(R((-0.5, -4.5)), 14.5, 3.9, ROBE_BLUE, rot=t - 0.08, bias=0.02)    # rand
    c.capsule(R((-8, -6.5)), R((6.5, -6.5)), 1.5, 1.5, GOLD, bias=0.05)          # band
    c.crease([R((-6, -14)), R((-1, -10))], 0.2)
    c.crease([R((-8, -20)), R((-3, -17))], 0.2)


def _sword(c, hand, deg):
    d = _dir(deg)
    perp = (-d[1], d[0])
    c.capsule(add(hand, (-d[0] * 4, -d[1] * 4)), add(hand, (d[0] * 1, d[1] * 1)), 1.4, 1.4, LEATHER)
    c.ellipse(add(hand, (-d[0] * 4.8, -d[1] * 4.8)), 1.9, 1.9, GOLD)               # knop
    g = add(hand, (d[0] * 2.2, d[1] * 2.2))
    c.capsule(add(g, (perp[0] * 4.2, perp[1] * 4.2)), add(g, (-perp[0] * 4.2, -perp[1] * 4.2)), 1.3, 1.3, GOLD)
    b0 = add(hand, (d[0] * 3.2, d[1] * 3.2))
    b1 = add(hand, (d[0] * 27, d[1] * 27))
    c.capsule(b0, b1, 1.9, 0.7, STEEL, bias=0.08)
    c.crease([add(b0, (d[0] * 2, d[1] * 2)), add(b0, (d[0] * 19, d[1] * 19))], -0.25, light=False)
    return b1


def _staff(c, hand, deg, kind):
    d = _dir(deg)
    lo = add(hand, (-d[0] * 14, -d[1] * 14))
    hi = add(hand, (d[0] * 30, d[1] * 30))
    wood = WOOD if kind == "orb" else WOOD_LIGHT
    c.capsule(lo, hi, 1.5, 1.4, wood)
    c.crease([add(lo, (d[0] * 4, d[1] * 4)), add(hi, (-d[0] * 4, -d[1] * 4))], 0.12)
    if kind == "orb":
        top = add(hi, (d[0] * 4, d[1] * 4))
        for s in (-1, 1):
            c.capsule(hi, add(top, (s * 3.2 * -d[1] + d[0] * 1, s * 3.2 * d[0] + d[1] * 1)), 1.0, 0.7, GOLD)
        c.ellipse(top, 3.9, 3.9, ORB, bias=0.12)
        c.px(top[0] - 1.6, top[1] - 1.8, ORB[5])
        c.px(top[0] - 0.6, top[1] - 1.8, ORB[5])
        return top
    # genezersstaf: gouden ring met een rode steen
    top = add(hi, (d[0] * 5.5, d[1] * 5.5))
    ring = c.ellipse(top, 5.0, 5.0, GOLD, bias=0.05)
    hole = ((c.X - top[0]) ** 2 + (c.Y - top[1]) ** 2) < 2.9 ** 2
    c.mat[hole] = -1
    c.part[hole] = -1
    c.ellipse(top, 1.8, 2.2, TRIM_RED, bias=0.15)
    c.px(top[0] - 0.6, top[1] - 1.2, rgb("ffd0c0"))
    return top


def _fx(img, P, tip, kind, color_set, s=1.0):
    d = ImageDraw.Draw(img)
    P = _transform_pose(P, lambda q: (q[0] * s, q[1] * s))
    if tip:
        tip = (tip[0] * s, tip[1] * s)
    if kind == "zwaai":            # zwaaiboog voor het lijf: van boven naar onder, aan de vijandkant
        cx, cy = P["sh_f"][0] - 2, P["sh_f"][1] + 4
        for (r, a, w, s0, s1) in ((24 * s, 210, 2, -60, 30), (22 * s, 130, 1, -50, 25), (26 * s, 80, 1, -40, 20),
                                  (20 * s, 90, 1, -45, 20)):
            d.arc((cx - r, cy - r, cx + r, cy + r), start=s0, end=s1, fill=(236, 242, 255, a), width=w)
    elif kind in ("glinster", "gloed") and tip:
        tx, ty = int(round(tip[0])), int(round(tip[1]))
        cols = color_set
        if kind == "gloed":
            for rr, al in ((8 * s, 70), (6 * s, 110), (4 * s, 140)):
                d.ellipse((tx - rr, ty - rr, tx + rr, ty + rr), outline=cols[1] + (al,))
        for k in range(1, int(6 * s)):
            a = 255 if k < 4 else 160
            for (ox, oy) in ((0, -k), (0, k), (-k, 0), (k, 0)):
                d.point((tx + ox, ty + oy), fill=cols[0] + (a,))
        for (ox, oy) in ((-2, -2), (2, -2), (-2, 2), (2, 2), (-3, -3), (3, 3)):
            d.point((tx + ox, ty + oy), fill=cols[1] + (200,))
        d.point((tx, ty), fill=(255, 255, 255, 255))
    elif kind == "raak":           # klein inslag-sterretje
        x, y = int(P["sh_f"][0] + 6 * s), int(P["sh_f"][1] - 2 * s)
        for (ox, oy) in ((0, -3), (0, 3), (-3, 0), (3, 0), (-2, -2), (2, 2), (2, -2), (-2, 2), (0, 0)):
            d.point((x + ox, y + oy), fill=(255, 250, 220, 230))


def _hero_canvas(key, P, ko=False):
    c = Canvas(HF_W, HF_W, HERO_S)
    spec = HERO_SPECS[key]
    weapon = spec["weapon"]
    tip = None
    if ko:
        P = dict(P, wz=-1)
    # ---- achter: wapen (achter alles), verre arm
    if P["wz"] == 0:
        tip = _weapon(c, P, weapon)
    _limb(c, P["sh_f"], P["el_f"], P["ha_f"], 3.1, 2.7, 2.4, spec["sleeve"], spec["forearm"], bias=-0.12)
    c.ellipse(P["ha_f"], 2.5, 2.4, SKIN, bias=-0.05)
    if P["wz"] == 1:
        tip = _weapon(c, P, weapon)
    # ---- benen
    foot = (0.5, 0) if ko else (2.6, 0.6)
    if spec["legs"]:
        _leg(c, P, "f", spec["trousers"], BOOT, bias=-0.1, foot=foot)
        _leg(c, P, "n", spec["trousers"], BOOT, foot=foot)
    else:   # lang gewaad: alleen de laarspunten
        for side in ("f", "n"):
            if ko:
                c.ellipse(add(P["ft_" + side], (1.5, 0)), 2.6, 3.6, BOOT)
            else:
                c.ellipse(add(P["ft_" + side], (2.4, 0.4)), 4.2, 2.5, BOOT, bias=-0.05 if side == "f" else 0)
    spec["body"](c, P)
    # ---- voor: nabije arm, hoofd
    _limb(c, P["sh_n"], P["el_n"], P["ha_n"], 3.3, 2.9, 2.5, spec["sleeve"], spec["forearm"])
    if spec.get("cuff"):
        c.capsule(lerp(P["el_n"], P["ha_n"], 0.55), lerp(P["el_n"], P["ha_n"], 0.8), 3.6, 4.0, spec["sleeve"])
    c.ellipse(P["ha_n"], 2.6, 2.5, SKIN)
    if spec.get("pauldron"):
        c.ellipse(add(P["sh_n"], (-0.5, -0.5)), 4.8, 3.9, STEEL, bias=-0.12)
        c.px(P["sh_n"][0] + 1, P["sh_n"][1] + 1, GOLD[4])
        c.crease([add(P["sh_n"], (-4, 1)), add(P["sh_n"], (3, 1.5))], 0.2)
    _head(c, P, spec["hair"], spec["head"])
    if spec["head"] == "hoed" and not ko:
        _hat(c, P)
    if P["wz"] == 2:
        tip = _weapon(c, P, weapon)
    return c, tip


def _weapon(c, P, weapon):
    if weapon == "zwaard":
        return _sword(c, P["ha_f"], P["weapon"])
    return _staff(c, P["ha_f"], P["weapon"], "orb" if weapon == "orbstaf" else "ring")


# ---- lijven per held
def _body_dennis(c, P):
    hn, hf = P["hip_n"], P["hip_f"]
    skirt = [add(hn, (-3, -3)), add(hf, (3, -3)), add(hf, (5.5, 6)), lerp(hn, hf, 0.5) + (0,),
             add(hn, (-5.5, 6))]
    skirt[3] = add(lerp(hn, hf, 0.5), (0, 7))
    c.polygon(skirt, TUNIC, curve=1.0, tilt=0.1, bias=-0.04)
    c.crease([add(hn, (1, 0)), add(hn, (0, 6))], 0.2)
    c.crease([add(hf, (-2, 0)), add(hf, (-1, 6))], 0.2)
    c.polygon(_torso_pts(P), TUNIC, curve=1.0, tilt=-0.3, vgrad=0.5)
    # vouwen in de rug en een leren riem over de schouder (met gesp)
    sn, sf = P["sh_n"], P["sh_f"]
    c.crease([lerp(sn, sf, 0.45), add(lerp(hn, hf, 0.5), (-1, -5))], 0.22)
    c.crease([add(sn, (3, 6)), add(hn, (2, -7))], 0.16)
    c.capsule(add(sf, (-1, -1)), add(hn, (-2, -5)), 1.5, 1.5, LEATHER, bias=0.05)
    waist_y = (hn[1] + hf[1]) / 2 - 3.5
    c.capsule((hn[0] - 3.5, waist_y + (hn[1] - hf[1]) / 2), (hf[0] + 3.5, waist_y), 1.9, 1.9, LEATHER)
    bx = hf[0] + 1
    c.ellipse((bx, waist_y + 0.2), 1.9, 1.7, GOLD, bias=0.1)
    # schouderbladen: zachte vouw dwars over de rug
    c.crease([add(sn, (2, 5)), lerp(add(sn, (0, 7)), add(sf, (0, 7)), 0.5), add(sf, (-2, 5))], 0.16)
    _cape(c, P, CAPE_RED, length=0.6, narrow=2.5)
    c.ellipse(add(sf, (0.5, -0.5)), 4.6, 3.7, STEEL, bias=-0.15)                 # schouderstuk


def _cape(c, P, rmp, length=1.0, narrow=0.0):
    """Cape van achteren: valt van de schouders over de rug, wijder naar onder, met
    plooien die uitwaaieren. Bij een aanval waait de zoom naar achteren (links)."""
    sn, sf, hn, hf = P["sh_n"], P["sh_f"], P["hip_n"], P["hip_f"]
    kn, kf = P["kn_n"], P["kn_f"]
    sway = -4.0 if P.get("fx") == "zwaai" else (-2.0 if P.get("wz") == 0 else 0.0)
    bot = lerp(hn, kn, 0.55)[1] * length + hn[1] * (1 - length) + 1
    top_l, top_r = add(sn, (-1.5, -2.5)), add(sf, (1.5, -3))
    hem = []
    xl, xr = hn[0] - 7 + narrow + sway, hf[0] + 6 - narrow + sway * 0.6
    n = 6
    for k in range(n + 1):
        t = k / n
        hem.append((xl + (xr - xl) * t, bot + (1.6 if k % 2 else -0.4) + t * 1.5))
    pts = [top_l, lerp(top_l, top_r, 0.5), top_r, add(sf, (3, 6)), (xr + 1, bot - 6)] + hem[::-1] +           [(xl - 1, bot - 6), add(sn, (-3, 7))]
    c.polygon(pts, rmp, curve=1.0, tilt=-0.25, vgrad=0.55)
    mid = lerp(top_l, top_r, 0.5)
    for k, t in enumerate((0.12, 0.34, 0.58, 0.82)):
        x_end = xl + (xr - xl) * t
        c.crease([add(lerp(top_l, top_r, 0.25 + t * 0.5), (0, 4)), (x_end + 0.5, bot - 1)], 0.24)
    c.crease([add(top_l, (1, 1.5)), add(mid, (0, 2.5)), add(top_r, (-1, 1.5))], -0.25, light=False)  # kraagrand
    c.crease([(xl + 1, bot - 1.5), (xr - 1, bot - 0.5)], 0.18, light=False)


def _body_noor(c, P):
    hn, hf, sn, sf = P["hip_n"], P["hip_f"], P["sh_n"], P["sh_f"]
    fn, ff = P["ft_n"], P["ft_f"]
    hem_y = max(fn[1], ff[1]) - 1.5
    robe = [add(sn, (-2, -2)), add(sf, (2, -2.5)), add(sf, (3, 6)), add(hf, (3.5, -2)),
            (ff[0] + 7, hem_y - 1), (lerp(fn, ff, 0.5)[0] + 3, hem_y + 0.5),
            (lerp(fn, ff, 0.5)[0] - 4, hem_y), (fn[0] - 6, hem_y - 0.5), add(hn, (-4.5, 0)),
            add(sn, (-2.5, 6))]
    c.polygon(robe, ROBE_BLUE, curve=1.0, tilt=-0.15, vgrad=0.6)
    for (a, b) in (((-1, -1), (-4, 18)), ((3, 0), (3, 19)), ((6, -2), (9, 17)), ((-3, 6), (-7, 18))):
        c.crease([add(lerp(hn, hf, 0.5), a), add(lerp(hn, hf, 0.5), b)], 0.2)
    c.capsule((fn[0] - 6, hem_y - 0.5), (ff[0] + 7, hem_y - 1), 1.2, 1.2, GOLD, bias=0.05)    # zoom
    # schoudermantel met gouden rand
    mantle = [add(sn, (-3.5, -2)), add(sf, (3.5, -3)), add(sf, (4, 6)), lerp(add(sn, (0, 10)), add(sf, (0, 10)), 0.5),
              add(sn, (-4, 7))]
    c.polygon(mantle, ROBE_BLUE, curve=1.0, tilt=-0.45, bias=0.1)
    c.crease([add(sn, (-3, 6.5)), lerp(add(sn, (0, 10)), add(sf, (0, 10)), 0.5), add(sf, (3.5, 5.5))], -0.3, light=False)
    waist_y = (hn[1] + hf[1]) / 2 - 4
    c.capsule((hn[0] - 3.5, waist_y + 0.5), (hf[0] + 3.5, waist_y), 1.4, 1.4, GOLD)


def _body_lotte(c, P):
    hn, hf, sn, sf = P["hip_n"], P["hip_f"], P["sh_n"], P["sh_f"]
    kn, kf = P["kn_n"], P["kn_f"]
    hem_y = max(kn[1], kf[1]) + 3
    robe = [add(sn, (-2, -2)), add(sf, (2, -2.5)), add(sf, (2.5, 6)), add(hf, (3, -2)),
            (kf[0] + 6, hem_y - 1), (lerp(kn, kf, 0.5)[0], hem_y + 1), (kn[0] - 6, hem_y),
            add(hn, (-4, 0)), add(sn, (-2.5, 6))]
    c.polygon(robe, ROBE_WHITE, curve=1.0, tilt=-0.15, vgrad=0.5)
    for (a, b) in (((-2, 0), (-5, 13)), ((3, -1), (3, 14)), ((7, -1), (9, 12))):
        c.crease([add(lerp(hn, hf, 0.5), a), add(lerp(hn, hf, 0.5), b)], 0.2)
    c.capsule((kn[0] - 6, hem_y - 1), (kf[0] + 6, hem_y - 2), 1.5, 1.5, TRIM_RED, bias=0.05)
    c.crease([(kn[0] - 6, hem_y - 3), (kf[0] + 6, hem_y - 4)], -0.4, light=False)
    waist_y = (hn[1] + hf[1]) / 2 - 4
    c.capsule((hn[0] - 3.5, waist_y + 0.5), (hf[0] + 3.5, waist_y), 1.8, 1.8, TRIM_RED)
    c.capsule((hn[0] + 1, waist_y + 1), (hn[0] - 1, waist_y + 9), 1.2, 1.0, TRIM_RED)   # sjerp
    c.crease([lerp(sn, sf, 0.5), add(lerp(hn, hf, 0.5), (0, -6))], 0.18)
    # saliegroen manteltje met kap (ligt op de rug) en gouden kraag
    cap = [add(sn, (-3, -2)), add(sf, (3, -2.5)), add(sf, (4, 6)), lerp(add(sn, (0, 13)), add(sf, (0, 13)), 0.55),
           add(sn, (-3.5, 8))]
    c.polygon(cap, CAPE_SAGE, curve=1.0, tilt=-0.35, vgrad=0.4)
    for t in (0.3, 0.55, 0.8):
        c.crease([lerp(add(sn, (0, 1)), add(sf, (0, 1)), t), lerp(add(sn, (-1, 9)), add(sf, (1, 9)), t)], 0.2)
    hood = add(lerp(sn, sf, 0.45), (0, 3.0))
    c.ellipse(hood, 5.0, 3.6, CAPE_SAGE, bias=0.06)
    c.crease([add(hood, (-3.5, -0.5)), add(hood, (0, 1.8)), add(hood, (3.5, -0.5))], 0.3, light=False)
    c.capsule(add(sn, (2, -1.5)), add(sf, (-2, -2)), 1.6, 1.6, GOLD, bias=0.05)


HERO_SPECS = {
    "dennis": {"weapon": "zwaard", "hair": HAIR_BROWN, "head": "kort", "sleeve": TUNIC,
              "forearm": LEATHER, "legs": True, "trousers": TROUSERS, "body": _body_dennis,
              "pauldron": True, "fx": ((255, 246, 190), (255, 210, 110))},
    "noor": {"weapon": "orbstaf", "hair": HAIR_DARK, "head": "hoed", "sleeve": ROBE_BLUE,
             "forearm": ROBE_BLUE, "legs": False, "trousers": TROUSERS, "body": _body_noor,
             "cuff": True, "fx": ((200, 250, 255), (120, 200, 255))},
    "lotte": {"weapon": "ringstaf", "hair": HAIR_BLOND, "head": "lang", "sleeve": ROBE_WHITE,
              "forearm": ROBE_WHITE, "legs": True, "trousers": ramp("2a2832", "4a4858", "6c6a7c", "8e8c9e", "b0aec0", "d2d0de"),
              "body": _body_lotte, "cuff": True, "fx": ((255, 250, 210), (140, 255, 170))},
}


def _transform_pose(P, fn):
    Q = {}
    for k, v in P.items():
        Q[k] = fn(v) if isinstance(v, tuple) and len(v) == 2 and k != "fx" else v
    return Q


def make_hero_sheet(key):
    spec = HERO_SPECS[key]
    poses = SWORD_POSES if spec["weapon"] == "zwaard" else STAFF_POSES
    S, F = HERO_S, HERO_PX
    sheet = Image.new("RGBA", (F * 8, F), (0, 0, 0, 0))
    for i, P in enumerate(poses):
        c, tip = _hero_canvas(key, P)
        img = c.render()
        _fx(img, P, tip, P["fx"], spec["fx"], S)
        fr = ground_shadow(F, F, (P["ft_n"][0] / 2 + P["ft_f"][0] / 2 + 2) * S, 91.5 * S, 15 * S, 3.4 * S)
        fr.alpha_composite(img)
        sheet.alpha_composite(fr, (i * F, 0))
    # KO: op de grond, hoofd naar links (zelfde vormen, gedraaid; licht klopt nog)
    # ledematen strak langs het lijf (anders steken ze na het draaien omhoog)
    P = _pose(wz=0, el_f=(46, 45), ha_f=(46, 53), el_n=(32, 45), ha_n=(33, 53),
              hip_f=(42, 55), hip_n=(37, 55), kn_f=(42, 65), ft_f=(42, 74), kn_n=(37, 65), ft_n=(37, 74),
              sh_f=(45, 36), sh_n=(32, 37))
    P = _transform_pose(P, lambda p: (48 + (p[1] - 62) - 2, 62 - (p[0] - 48) + 22))
    P["weapon"] = 172 if spec["weapon"] == "zwaard" else -178
    P["tilt"] = -1.5708
    c, _tip = _hero_canvas(key, P, ko=True)
    img = c.render()
    fr = ground_shadow(F, F, 50 * S, 89.5 * S, 32 * S, 4.0 * S)
    fr.alpha_composite(img)
    sheet.alpha_composite(fr, (7 * F, 0))
    return sheet


# ================================================================ vijanden (kijken naar links)
GOB_S = 0.5                            # goblin: ±70 px hoog op het fijne raster


def make_goblin():
    W, H = 128, 144                    # ontwerp-maat; echt plaatje = x GOB_S
    S = GOB_S
    c = Canvas(W, H, S)
    # verre arm (achter het lijf), hangend met klauwen
    c.capsule((84, 64), (95, 82), 6.5, 5.5, GOB_SKIN, bias=-0.14)
    c.capsule((95, 82), (93, 99), 5.5, 4.6, GOB_SKIN, bias=-0.14)
    c.capsule((95, 86), (93, 96), 6.0, 6.0, LEATHER, bias=-0.12)               # armband
    c.ellipse((92, 103), 5.4, 5.0, GOB_SKIN, bias=-0.12)
    for dx in (-3, 0, 3):
        c.capsule((92 + dx, 106), (91 + dx * 1.3, 111), 1.4, 0.6, BONE, bias=-0.1)
    # benen: kort, krom en dik
    for (hip, kn, ft, b) in (((74, 100), (80, 117), (82, 133), -0.12), ((54, 100), (46, 116), (44, 133), 0.0)):
        c.capsule(hip, kn, 8.0, 6.8, GOB_SKIN, b)
        c.capsule(kn, ft, 6.6, 5.4, GOB_SKIN, b)
        c.ellipse(add(ft, (-4, 2.5)), 9.0, 4.6, GOB_SKIN, bias=b)            # voet naar links
        for k in range(3):
            c.capsule(add(ft, (-9 - k * 0.5, 1 + k * 2.2)), add(ft, (-13.5, 1.5 + k * 2.4)), 1.4, 0.6, BONE, bias=b)
        c.crease([add(kn, (-4, -1)), add(kn, (3, 1))], 0.2)
    # lendendoek met rafelrand
    cloth = [(46, 90), (82, 90), (85, 104), (80, 110), (76, 105), (71, 112), (66, 106), (60, 113), (55, 106),
             (50, 111), (44, 104)]
    c.polygon(cloth, GOB_CLOTH, tilt=0.1)
    for x0 in (54, 62, 72):
        c.crease([(x0, 93), (x0 - 1, 108)], 0.2)
    # romp: gebogen rug met dikke buik
    c.ellipse((66, 74), 24, 21, GOB_SKIN)
    c.ellipse((58, 84), 15, 12, GOB_SKIN, bias=0.06)                          # buik
    c.crease([(46, 82), (52, 90), (64, 94)], 0.18)
    c.crease([(60, 66), (68, 70), (76, 68)], 0.16)                             # borst
    # leren riem schuin over de borst, met noppen
    c.capsule((46, 60), (84, 92), 3.2, 3.2, LEATHER, bias=0.02)
    for t in (0.2, 0.42, 0.64, 0.86):
        p = lerp((46, 60), (84, 92), t)
        c.ellipse(p, 1.6, 1.6, STEEL, bias=0.1)
    c.capsule((44, 92), (86, 91), 3.4, 3.4, LEATHER)                          # riem
    c.ellipse((60, 92), 4.2, 3.6, GOLD, bias=0.05)                             # gesp
    c.ellipse((60, 92), 1.8, 1.4, LEATHER, bias=-0.2)
    # hoofd: groot, laag tussen de schouders, gezicht naar links
    hx, hy = 57, 36
    c.capsule((76, 32), (98, 14), 5.6, 1.0, GOB_SKIN, bias=-0.06)             # verre oor
    c.crease([(80, 29), (94, 17)], 0.3, light=False, width=2)
    c.ellipse((hx, hy), 18, 15.5, GOB_SKIN)
    c.ellipse((hx - 6, hy + 9), 13, 7.5, GOB_SKIN, bias=0.02)                 # kaak
    c.capsule((40, 36), (12, 22), 6.2, 1.0, GOB_SKIN, bias=0.02)              # nabije oor
    c.crease([(36, 34), (17, 24)], 0.32, light=False, width=2)
    c.ellipse((41, 42), 5.4, 4.6, GOB_SKIN, bias=0.06)                        # haakneus
    c.px(38, 44, GOB_SKIN[0]); c.px(39, 44, GOB_SKIN[1])
    c.crease([(36, 45), (40, 47), (45, 47)], 0.45, width=1)                 # schaduw onder de neus
    c.crease([(44, 34), (46, 40)], -0.25)                                     # licht op de neusrug
    # wenkbrauwboog (boos) en ogen
    c.crease([(41, 31), (48, 34), (54, 33)], 0.35, width=2)
    c.crease([(58, 32), (64, 30), (69, 28)], 0.35, width=2)
    for (ex, ey) in ((48, 37), (63, 35)):
        c.ellipse((ex, ey), 3.6, 2.4, EYE_YEL, bias=0.2, outline=False)
    # bek met onderbeet en slagtanden
    c.capsule((40, 50), (62, 49), 1.6, 1.4, ramp("100608", "200a0c", "30101a", "401822", "50202a", "602832"))
    for (x, top) in ((45, 46), (58, 46)):
        c.capsule((x, 50), (x + 0.5, top), 1.9, 0.7, BONE, bias=0.1)
    # wratten
    for (wx, wy) in ((66, 25), (70, 42), (52, 26)):
        c.ellipse((wx, wy), 1.4, 1.2, GOB_SKIN, bias=0.18)
    # nabije arm met knots omhoog, naast het hoofd
    c.capsule((48, 66), (26, 64), 7.0, 6.0, GOB_SKIN)
    c.capsule((26, 64), (18, 46), 6.0, 5.0, GOB_SKIN)
    c.capsule((24, 60), (20, 50), 6.4, 6.4, LEATHER, bias=0.04)               # armband
    c.crease([(15, 55), (26, 56)], 0.2)
    # knots: van de hand schuin naar rechtsboven, dik uiteinde met ijzeren pinnen
    hand = (18, 42)
    c.capsule((16, 50), (34, 8), 3.2, 8.0, WOOD, bias=0.02)
    c.crease([(20, 40), (30, 16)], 0.2)
    c.capsule((29, 18), (35, 13), 8.4, 8.4, STEEL, bias=-0.15)                # ijzeren band
    c.capsule((29, 18), (35, 13), 6.0, 6.0, WOOD, bias=0.0)
    for (a_, b_) in (((25, 11), (19, 6)), ((34, 5), (35, 0)), ((41, 10), (47, 7)), ((40, 19), (46, 22)), ((23, 20), (17, 22))):
        c.capsule(a_, b_, 2.0, 0.5, STEEL, bias=0.12)
    c.ellipse(hand, 6.0, 5.4, GOB_SKIN, bias=0.04)                            # vuist om de knots
    c.crease([(14, 41), (22, 44)], 0.2)
    # ijzeren schouderstuk met klinknagels en een punt
    c.ellipse((48, 64), 12, 8.5, STEEL, rot=-0.25, bias=-0.06)
    c.crease([(38, 66), (58, 60)], 0.25)
    for (rx_, ry_) in ((40, 64), (48, 61), (56, 59)):
        c.px(rx_, ry_, STEEL[5]); c.px(rx_ + 1, ry_ + 1, STEEL[1])
    c.capsule((44, 58), (41, 50), 2.2, 0.5, STEEL, bias=0.15)
    img = c.render()
    p = img.load()
    PW, PH = img.size
    for (ex, ey) in ((48, 37), (63, 35)):                                     # rode pupil + glinster
        x, y = int(ex * S), int(ey * S)
        p[x, y] = EYE_RED[2] + (255,)
    out = ground_shadow(PW, PH, 64 * S, 139.5 * S, 38 * S, 5.0 * S)
    out.alpha_composite(img)
    return out


SLIME_S = 0.7                          # slijm groter tekenen (echte pixels per ontwerp-eenheid)


def make_slime():
    W, H = 112, 88                     # ontwerp-maat; echt plaatje = x SLIME_S
    S = SLIME_S
    c = Canvas(W, H, S)
    c.ambient = 0.14
    c.ellipse((56, 78), 46, 8.5, SLIME, bias=-0.1)                             # voet/plas
    body = c.ellipse((56, 56), 42, 30, SLIME, flat_z=0.9)
    # onderkant plat
    cut = (c.Y > 84) & (c.mat >= 0)
    c.mat[cut] = -1
    c.part[cut] = -1
    # doorschijnende kern en belletjes
    core = ((c.X - 62) / 24) ** 2 + ((c.Y - 67) / 12) ** 2 < 1
    c.tint(core & body, -0.12)
    for (bx, by, br) in ((70, 62, 3.2), (78, 54, 2.0), (64, 72, 2.4), (46, 70, 1.6)):
        m = ((c.X - bx) ** 2 + (c.Y - by) ** 2) < br * br
        c.tint(m, 0.22)
        c.px(bx - br * 0.4, by - br * 0.5, SLIME[5])
    # randlicht onderaan rechts (weerkaatsing)
    c.crease([(78, 78), (90, 72), (96, 62)], -0.35, light=False, width=2)
    # gezicht (naar links)
    for (ex, ey) in ((38, 52), (55, 50)):
        c.ellipse((ex, ey), 4.2, 6.2, ramp("041010", "062018", "0a2a22", "0e342a", "123e32", "16483a"), outline=False)
    c.crease([(32, 43), (41, 46)], 0.5, light=False, width=2)                 # ondeugende wenkbrauwen
    c.crease([(51, 43), (59, 41)], 0.5, light=False, width=2)
    c.crease([(40, 63), (45, 66), (51, 66), (56, 63)], 0.9, light=False, width=2)   # grijns
    img = c.render()
    p = img.load()
    PW, PH = img.size
    # glanzende hooglichten (hard, geen blur)
    for (cx, cy, rx, ry) in ((34, 37, 9, 4.5),):
        for y in range(PH):
            for x in range(PW):
                u = (((x + 0.5) / S - cx) * 0.9 + ((y + 0.5) / S - cy) * 0.45) / rx
                v = (-((x + 0.5) / S - cx) * 0.45 + ((y + 0.5) / S - cy) * 0.9) / ry
                if u * u + v * v < 1 and p[x, y][3] > 0:
                    p[x, y] = (238, 255, 246, 255) if u * u + v * v < 0.45 else SLIME[5] + (255,)
    P_ = lambda x, y: (int(x * S), int(y * S))
    for (x, y) in ((50, 32), (51, 32), (50, 33), (56, 31), (82, 44), (83, 45)):
        p[P_(x, y)] = (238, 255, 246, 255)
    for (ex, ey) in ((38, 52), (55, 50)):                                     # oogglinsters
        gx, gy = P_(ex - 2, ey - 3.2)
        for (ox, oy) in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 0)):
            p[gx + ox, gy + oy] = (240, 255, 250, 255)
        p[P_(ex + 1, ey + 2)] = SLIME[3] + (255,)
    out = ground_shadow(PW, PH, 56 * S, 84.5 * S, 46 * S, 3.8 * S, alpha=90)
    # druppels op de grond
    for (x, y) in ((8, 82), (9, 82), (102, 83), (103, 83), (104, 82)):
        out.putpixel(P_(x, y), SLIME[3] + (255,))
    out.alpha_composite(img)
    return out


BAT_S = 0.62                           # vleermuis groter tekenen


def make_bat():
    W, H = 128, 112                    # ontwerp-maat; echt plaatje = x BAT_S
    S = BAT_S
    c = Canvas(W, H, S)
    c.ambient = 0.14

    def wing(sh, wrist, tips, sign, bias):
        pts = [sh, wrist, tips[0]]
        for i in range(len(tips) - 1):          # gekartelde achterrand tussen de vingers
            a, b = tips[i], tips[i + 1]
            m = lerp(a, b, 0.5)
            pts.append(add(m, (sign * -2.5, -4)))
            pts.append(b)
        pts.append(add(sh, (sign * -2, 12)))
        c.polygon(pts, BAT_WING, curve=0.35, tilt=-0.3, bias=bias)
        for t in tips:                           # vingerbotten
            c.crease([wrist, t], -0.28, light=False)
        c.capsule(sh, wrist, 2.6, 2.0, BAT_FUR, bias=bias + 0.06)
        c.capsule(wrist, add(wrist, (sign * -4, -5)), 1.6, 0.6, BONE, bias=bias)   # duimklauw
        for t in tips:
            c.capsule(wrist, t, 1.2, 0.6, BAT_WING, bias=bias + 0.18)

    wing((72, 44), (96, 24), [(124, 20), (122, 44), (106, 60), (84, 60)], -1, -0.16)   # verre vleugel
    c.ellipse((64, 54), 14, 16, BAT_FUR)                                        # lijf
    for (a, b) in (((58, 44), (56, 60)), ((64, 46), (64, 64)), ((70, 46), (72, 60))):
        c.crease([a, b], 0.2)
    c.capsule((58, 68), (56, 76), 2.2, 1.2, BAT_FUR, bias=-0.05)                # pootjes
    c.capsule((68, 68), (70, 76), 2.2, 1.2, BAT_FUR, bias=-0.1)
    for (x, y) in ((54, 78), (56, 79), (70, 79), (72, 78)):
        c.capsule((x + 1, y - 2), (x, y), 0.9, 0.5, BONE)
    wing((56, 44), (30, 22), [(3, 18), (5, 44), (20, 62), (42, 62)], 1, 0.0)  # nabije vleugel
    # kop met grote oren
    c.capsule((54, 30), (46, 9), 4.6, 0.8, BAT_FUR)
    c.capsule((68, 29), (74, 9), 4.2, 0.8, BAT_FUR, bias=-0.08)
    c.crease([(51, 27), (47, 13)], 0.35, light=False, width=2)
    c.crease([(69, 26), (72, 13)], 0.35, light=False, width=2)
    c.ellipse((60, 36), 12, 10.5, BAT_FUR)
    c.ellipse((56, 41), 6.5, 4.5, BAT_FUR, bias=0.06)                           # snuit
    c.px(53, 40, BAT_FUR[0]); c.px(55, 40, BAT_FUR[0])
    for (ex, ey) in ((53, 34), (63, 33)):
        c.ellipse((ex, ey), 2.8, 2.2, EYE_RED, bias=0.25, outline=False)
    c.crease([(49, 30), (56, 32)], 0.35, light=False)
    c.crease([(60, 30), (67, 29)], 0.35, light=False)
    c.capsule((51, 45), (60, 45), 1.4, 1.2, ramp("10040a", "200812", "300c1a", "401222", "50182a", "602032"))
    img = c.render()
    p = img.load()
    PW, PH = img.size
    for (x0, y0) in ((52, 46), (58, 46)):                                      # slagtandjes
        x0, y0 = int(x0 * S), int(y0 * S)
        n = max(2, int(round(3 * S)))
        for k in range(n):
            p[x0, y0 + k] = (250, 246, 236, 255) if k < n - 1 else (200, 190, 180, 255)
        if S >= 1:
            p[x0 + 1, y0] = (220, 214, 204, 255)
    for (ex, ey) in ((53, 34), (63, 33)):
        gx, gy = int((ex - 1) * S), int((ey - 1) * S)
        p[gx, gy] = (255, 240, 200, 255)
        p[gx + 1, gy] = (255, 220, 170, 255)
    out = ground_shadow(PW, PH, 64 * S, 108.5 * S, 20 * S, 3.4 * S, alpha=80)
    out.alpha_composite(img)
    return out


# ================================================================ HD-vensters (24x24, marge 8 = 4 logisch)
def _hd_window(rings, fill, lit_split=True):
    """9-slice-venster op het 2x-raster. rings = lijst van (licht, schaduw) per ring van
    buiten naar binnen; hoeken 3 px afgeschuind. Licht = boven/links, schaduw = onder/rechts."""
    S = 24
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    p = im.load()
    for j in range(S):
        for i in range(S):
            cx, cy = min(i, S - 1 - i), min(j, S - 1 - j)
            r = min(cx, cy, cx + cy - 3)
            if r < 0:
                continue
            lit = (i + j) < S - 1 if lit_split else True
            if r < len(rings):
                col = rings[r][0] if lit else rings[r][1]
            else:
                col = fill
            p[i, j] = col
    return im


def _c(h, a=255):
    return rgb(h) + (a,)


def make_ui_hd():
    window = _hd_window([
        (_c("0a0820"), _c("0a0820")),
        (_c("f2eefa"), _c("bcb6d2")),
        (_c("b4aecc"), _c("88829f")),
        (_c("5e5896"), _c("4a4482")),
        (_c("0a0838"), _c("0a0838")),
        (_c("130d6a"), _c("1a1280")),
    ], _c("1a1280"))
    status = _hd_window([
        (_c("080c18"), _c("080c18")),
        (_c("8296a4"), _c("162438")),
        (_c("587288"), _c("1c2c42")),
        (_c("3e5574"), _c("22354f")),
        (_c("30486a"), _c("273e5e")),
    ], _c("2a4264"))
    glass = _hd_window([
        (_c("0a0820", 200), _c("0a0820", 200)),
        (_c("dce8f6"), _c("a8bad2")),
        (_c("8aa2c0", 230), _c("6a82a2", 230)),
        (_c("4a668e", 220), _c("3a557a", 220)),
        (_c("0a1838", 200), _c("0a1838", 200)),
    ], _c("10224e", 182))
    return {"window_hd": window, "panel_status_hd": status, "window_glass_hd": glass}


# ================================================================ alles opslaan
def make_all(root):
    """Schrijft alle gevechts-assets in '16-bit plus' (wordt aangeroepen door generate_art.py)."""
    import os
    import art_battle_bg
    sp = os.path.join(root, "assets", "sprites")
    os.makedirs(os.path.join(sp, "battle"), exist_ok=True)
    os.makedirs(os.path.join(sp, "enemies"), exist_ok=True)
    for key in ("dennis", "noor", "lotte"):
        make_hero_sheet(key).save(os.path.join(sp, "battle", key + ".png"))
    make_goblin().save(os.path.join(sp, "enemies", "goblin.png"))
    make_slime().save(os.path.join(sp, "enemies", "slijm.png"))
    make_bat().save(os.path.join(sp, "enemies", "vleermuis.png"))
    ui = os.path.join(root, "assets", "ui")
    for name, im in make_ui_hd().items():
        im.save(os.path.join(ui, name + ".png"))
    art_battle_bg.make_all(root)
