"""Gevechtsachtergronden in '16-bit plus' (1280x432, getoond op schaal 0.5 = 640x216 logisch).

Werkwijze: we tekenen niet direct in kleuren maar in twee lagen:
  mat  = welk materiaal (blad, schors, aarde, ...)
  tone = welke tint uit de kleurladder van dat materiaal (0 = donkerst)
Zo kunnen licht en diepte als 'tint +1 / -1' worden toegepast (lichtvlekken, schaduw
onder struiken, nevel achteraan) zonder ooit kleuren te mengen: geen blur, geen
tussenkleuren, alleen palettekleuren. Alles is origineel en met code getekend.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _r(*hexes):
    return [_rgb(h) for h in hexes]


W, H = 1280, 432
# ---- kleurladders (donker -> licht), passend bij het bestaande palet (olijf, aarde, indigo)
RAMPS = {
    "lucht": _r("5a6a4e", "6e7c5a", "86906a", "9ea67c", "b6ba90", "cccca2"),
    "ver": _r("2a3428", "353f2e", "414a34", "4e563a", "5e6442", "70744c"),        # nevelige verre dennen (warm)
    "blad": _r("0c1507", "142009", "1f2f0b", "2c3f0f", "3d5014", "52641b", "6a7a26", "889838"),
    "schors": _r("170e0a", "26180f", "382416", "4c321e", "624429", "7a5836", "94704a"),
    "aarde": _r("1e1209", "2a190c", "37210f", "452b14", "54361b", "644224", "77522f", "8b643c", "a07a4e"),
    "gras": _r("1c2608", "2a380c", "3a4a10", "4e5e16", "62721e", "7a8a2a", "96a43c"),
    "steen": _r("1e1c1c", "312e2c", "46413c", "5c5650", "746d64", "8e867a", "aaa292"),
    "mos": _r("1e2a0c", "2e3e12", "425618", "586e20", "70862c"),
    "bloem": _r("6a3a2a", "a2563a", "d08a4a", "f0c070"),
    "bloemw": _r("6a6a7a", "a8a8b8", "dcdce4", "fafaff"),
    "water": _r("1a2a3a", "2a4458", "3e6278", "5a8498"),
    "berg": _r("39424e", "46505c", "56606a", "68717a", "7c848a", "939a9c"),
    "heuvel": _r("0b181a", "102224", "152e2e", "1c3a36", "244840", "2e564a"),
    "rots": _r("2e241c", "4a3c30", "6a5846", "8a7660", "ae9c84", "ccbea4", "e6dcc6"),
    "weide": _r("12300c", "1c4416", "28581c", "336a24", "3e7a2a", "4f8c36", "68a046", "84b45a"),
}
MATS = list(RAMPS)
# Materiaal van de vloer: schaduwen onder struiken/stenen krijgen de donkerste tint
# daarvan (anders lijken ze in het gras op gaten in de grond).
_FLOOR = ["aarde"]
MI = {k: i for i, k in enumerate(MATS)}


class Board:
    def __init__(self, seed):
        self.mat = Image.new("L", (W, H), 0)
        self.tone = Image.new("L", (W, H), 0)
        self.dm = ImageDraw.Draw(self.mat)
        self.dt = ImageDraw.Draw(self.tone)
        self.rnd = random.Random(seed)

    def poly(self, pts, mat, tone):
        pts = [(round(x), round(y)) for x, y in pts]
        self.dm.polygon(pts, fill=MI[mat])
        self.dt.polygon(pts, fill=tone)

    def ell(self, cx, cy, rx, ry, mat, tone):
        box = [round(cx - rx), round(cy - ry), round(cx + rx) - 1, round(cy + ry) - 1]
        self.dm.ellipse(box, fill=MI[mat])
        self.dt.ellipse(box, fill=tone)

    def line(self, pts, mat, tone, width=1):
        pts = [(round(x), round(y)) for x, y in pts]
        self.dm.line(pts, fill=MI[mat], width=width)
        self.dt.line(pts, fill=tone, width=width)

    def px(self, x, y, mat, tone):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.mat.putpixel((x, y), MI[mat])
            self.tone.putpixel((x, y), tone)

    def arrays(self):
        return np.array(self.mat, dtype=np.int16), np.array(self.tone, dtype=np.int16)

    def render(self, mat=None, tone=None):
        if mat is None:
            mat, tone = self.arrays()
        out = np.zeros((H, W, 3), np.uint8)
        for k, i in MI.items():
            r = np.array(RAMPS[k], np.uint8)
            m = mat == i
            out[m] = r[np.clip(tone[m], 0, len(r) - 1)]
        return Image.fromarray(out, "RGB").convert("RGBA")


def _smooth_noise(rnd, w, h, cell, seed_off=0):
    """Zachte ruis (bilineair opgeschaald raster). Alleen gebruikt om tinten te kiezen,
    het eindbeeld blijft gekwantiseerd naar de ladder."""
    gw, gh = w // cell + 2, h // cell + 2
    g = np.array([[rnd.random() for _ in range(gw)] for _ in range(gh)])
    ys = np.arange(h) / cell
    xs = np.arange(w) / cell
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


# ------------------------------------------------------------------ bouwstenen
def pine(bd, cx, base, h, w, mat="blad", t0=1, tiers=None, trunk=True, detail=True):
    """Spar in lagen. Licht van linksboven: linkerdeel van elke laag lichter,
    onderrand van elke laag donker (schaduw op de laag eronder)."""
    rnd = bd.rnd
    tiers = tiers or max(3, int(h / 22))
    top = base - h
    if trunk:
        tw = max(2, w * 0.12)
        bd.poly([(cx - tw, base - h * 0.25), (cx + tw, base - h * 0.25), (cx + tw * 1.3, base + 1),
                 (cx - tw * 1.3, base + 1)], "schors", 1)
        bd.line([(cx - tw + 1, base - h * 0.25), (cx - tw * 1.2 + 1, base)], "schors", 3)
    for i in range(tiers):
        f = (i + 1) / tiers
        ty = top + (h * 0.82) * (i / tiers) - 2
        by = top + h * 0.2 + h * 0.66 * f
        hw = w * (0.25 + 0.75 * f)
        jag = []
        n = max(3, int(hw / 4))
        for k in range(n + 1):
            x = cx - hw + 2 * hw * k / n
            y = by - (3 if k % 2 else 0) - abs(x - cx) / hw * 2 + rnd.uniform(-1, 1)
            jag.append((x, y))
        bd.poly([(cx, ty)] + jag[::-1][:1] + list(reversed(jag)) if False else [(cx, ty)] + jag[::-1], mat, t0 + 1)
        # verlichte linkerhelft
        lit = [(cx, ty)] + [p for p in jag if p[0] < cx - hw * 0.05]
        lit.append((cx - hw * 0.1, by - h * 0.06))
        if len(lit) >= 3:
            bd.poly(lit, mat, t0 + 2)
        # schaduwrand onderaan
        bd.line(jag, mat, t0, width=1)
        if detail:
            for _ in range(int(hw / 3)):
                x = rnd.uniform(cx - hw * 0.85, cx - 1)
                y = rnd.uniform(ty + (by - ty) * 0.35, by - 3)
                if abs(x - cx) / hw < (y - ty) / (by - ty + 0.01):
                    bd.line([(x, y), (x - 2, y + 2)], mat, t0 + 3)
            for _ in range(int(hw / 4)):
                x = rnd.uniform(cx + 2, cx + hw * 0.8)
                y = rnd.uniform(ty + (by - ty) * 0.4, by - 3)
                if abs(x - cx) / hw < (y - ty) / (by - ty + 0.01):
                    bd.line([(x, y), (x + 2, y + 2)], mat, t0)


def broadleaf(bd, cx, base, trunk_top, tw, crown, t0=2):
    """Loofboom met zichtbare stam: schors met groeven, licht links, mos aan de voet,
    kruin uit trossen bladeren (elke tros apart belicht)."""
    rnd = bd.rnd
    # wortels
    for dx, ln in ((-1, 1.0), (1, 0.8)):
        bd.poly([(cx + dx * tw * 0.4, base - 10), (cx + dx * (tw + 10 * ln), base + 2), (cx + dx * tw * 0.2, base + 2)],
                "schors", 2)
    # stam
    bd.poly([(cx - tw * 0.8, trunk_top), (cx + tw * 0.8, trunk_top), (cx + tw, base + 2), (cx - tw, base + 2)],
            "schors", 2)
    bd.poly([(cx - tw * 0.8, trunk_top), (cx - tw * 0.25, trunk_top), (cx - tw * 0.35, base + 2), (cx - tw, base + 2)],
            "schors", 4)
    bd.line([(cx - tw * 0.8 + 1, trunk_top), (cx - tw + 1, base)], "schors", 5)
    bd.line([(cx + tw * 0.8 - 1, trunk_top), (cx + tw - 1, base)], "schors", 1, width=2)
    # schorsgroeven
    for _ in range(int((base - trunk_top) / 7)):
        x = cx + rnd.uniform(-tw * 0.7, tw * 0.7)
        y = rnd.uniform(trunk_top + 4, base - 6)
        ln = rnd.uniform(5, 14)
        t = 1 if x > cx - tw * 0.3 else 3
        bd.line([(x, y), (x + rnd.uniform(-1, 1), y + ln)], "schors", t)
    # knoest
    kx, ky = cx + rnd.uniform(-tw * 0.3, tw * 0.3), rnd.uniform(trunk_top + 20, base - 30)
    bd.ell(kx, ky, 3, 4, "schors", 1)
    bd.px(kx - 1, ky - 2, "schors", 4)
    # mos aan de voet
    for _ in range(int(tw * 1.5)):
        x = cx + rnd.uniform(-tw, tw * 0.2)
        y = rnd.uniform(base - 18, base)
        bd.ell(x, y, rnd.uniform(1, 3), rnd.uniform(1, 2), "mos", rnd.choice((2, 3, 3, 4)))
    # kruin
    cx0, cy0, rx, ry = crown
    clumps = []
    for _ in range(int(rx * ry / 120)):
        a = rnd.uniform(0, math.tau)
        d = math.sqrt(rnd.random())
        clumps.append((cx0 + math.cos(a) * rx * d, cy0 + math.sin(a) * ry * d, rnd.uniform(9, 16)))
    clumps.sort(key=lambda c: c[1])
    for (x, y, r) in clumps:
        leaf_clump(bd, x, y, r, t0)


def leaf_clump(bd, x, y, r, t0=2, mat="blad"):
    """Bladtros: donkere basis, lichtere kap linksboven, enkele blaadjes als hoogtepunt."""
    rnd = bd.rnd
    bd.ell(x, y, r, r * 0.8, mat, t0)
    bd.ell(x - r * 0.18, y - r * 0.16, r * 0.78, r * 0.6, mat, t0 + 1)
    bd.ell(x - r * 0.34, y - r * 0.3, r * 0.45, r * 0.36, mat, t0 + 2)
    for _ in range(int(r * 0.9)):
        a = rnd.uniform(math.pi * 0.9, math.pi * 1.9)
        d = rnd.uniform(0.3, 0.95) * r
        px_, py_ = x + math.cos(a) * d, y + math.sin(a) * d * 0.8
        bd.line([(px_, py_), (px_ + 1, py_ - 1)], mat, t0 + 3)
    # gekartelde onderrand
    for k in range(int(r)):
        a = rnd.uniform(0.15, math.pi - 0.15)
        bd.px(x + math.cos(a) * r * 0.95, y + math.sin(a) * r * 0.8, mat, max(0, t0 - 1))


def bush(bd, x, y, w, h, t0=2, mat="blad"):
    rnd = bd.rnd
    n = max(3, int(w / 7))
    for k in range(n):
        cx = x - w / 2 + w * (k + 0.5) / n + rnd.uniform(-2, 2)
        cy = y - h * 0.45 + rnd.uniform(-h * 0.2, h * 0.15)
        leaf_clump(bd, cx, cy, rnd.uniform(h * 0.4, h * 0.6), t0, mat)
    # schaduw onder de struik
    bd.ell(x + 2, y + 1, w * 0.55, 2.5, _FLOOR[0], 1)


def fern(bd, x, y, size, t0=2, flip=1):
    """Varen: gebogen bladstelen met blaadjes, licht aan de bovenkant."""
    rnd = bd.rnd
    for k in range(7):
        ang = math.radians(-160 + k * 23 + rnd.uniform(-6, 6))
        ln = size * rnd.uniform(0.7, 1.0) * (0.75 if k in (0, 6) else 1)
        pts = []
        for s in range(9):
            t = s / 8
            droop = t * t * size * 0.45
            pts.append((x + math.cos(ang) * ln * t, y + math.sin(ang) * ln * t + droop))
        bd.line(pts, "gras", t0, width=1)
        for s in range(1, 8):
            px_, py_ = pts[s]
            leaf = size * 0.18 * (1 - s / 9)
            nx, ny = -math.sin(ang), math.cos(ang)
            bd.line([(px_, py_), (px_ + nx * leaf, py_ + ny * leaf + 1)], "gras", t0 + 1)
            bd.line([(px_, py_), (px_ - nx * leaf, py_ - ny * leaf + 1)], "gras", t0 + 2 + (s < 4))


def rock(bd, x, y, w, h, mat="steen", t0=1, moss=True):
    """Steen: vlakken met harde lichtzijde linksboven, donkere voet en slagschaduw."""
    rnd = bd.rnd
    bd.ell(x + w * 0.12, y + 1, w * 0.62, h * 0.18 + 1, _FLOOR[0], 1)      # slagschaduw
    pts = []
    for k in range(9):
        a = math.pi + k * math.pi / 8
        rr = rnd.uniform(0.85, 1.05)
        pts.append((x + math.cos(a) * w / 2 * rr, y - h * 0.15 + math.sin(a) * h * rr))
    pts += [(x + w / 2, y), (x - w / 2, y)]
    bd.poly(pts, mat, t0 + 1)
    lit = [p for p in pts if p[0] < x + w * 0.15 and p[1] < y - h * 0.2]
    lit += [(x - w * 0.05, y - h * 0.45), (x - w * 0.42, y - h * 0.2)]
    if len(lit) >= 3:
        bd.poly(lit, mat, t0 + 3)
    bd.poly([(x - w * 0.25, y - h * 0.85), (x - w * 0.05, y - h * 0.95), (x - w * 0.1, y - h * 0.6)], mat, t0 + 4)
    bd.line([(x - w / 2, y), (x + w / 2, y)], mat, t0 - 1 if t0 else 0)
    bd.line([(x + w * 0.1, y - h * 0.6), (x + w * 0.25, y - h * 0.2), (x + w * 0.2, y)], mat, t0)   # breuklijn
    if moss:
        for _ in range(int(w / 3)):
            bd.px(x + rnd.uniform(-w * 0.35, w * 0.1), y - h * rnd.uniform(0.75, 1.0), "mos", rnd.choice((2, 3, 4)))


def tuft(bd, x, y, s, t0=2):
    """Graspol: 3-6 sprietjes, buitenste donker, middelste licht."""
    rnd = bd.rnd
    n = rnd.randint(3, 6)
    for k in range(n):
        dx = (k - (n - 1) / 2) * s * 0.5
        hgt = s * rnd.uniform(1.2, 2.2) * (1 - abs(k - (n - 1) / 2) / n * 0.6)
        lean = dx * 0.6 + rnd.uniform(-s * 0.4, s * 0.4)
        t = t0 + (2 if abs(k - (n - 1) / 2) < 1 else 1 if k < n / 2 else 0)
        bd.line([(x + dx, y), (x + dx + lean, y - hgt)], "gras", t)
    bd.line([(x - s * 0.8, y + 1), (x + s * 0.8, y + 1)], _FLOOR[0], 1)


def pebble(bd, x, y, r, t0=2):
    bd.ell(x + 1, y + 1, r + 0.6, r * 0.7, _FLOOR[0], 1)
    bd.ell(x, y, r, r * 0.72, "steen", t0)
    bd.px(x - r * 0.35, y - r * 0.3, "steen", t0 + 2)
    if r > 2:
        bd.px(x - r * 0.35 + 1, y - r * 0.3, "steen", t0 + 1)


# ------------------------------------------------------------------ vloer
def ground(bd, top, path_cx=640, path_w=330, tone_far=2, tone_mid=5, tone_near=3, key="aarde",
           patch_key=None, patch_amount=0.0, patch_shift=-0.6):
    """Getextureerde vloer met perspectief: ver = donker en fijn, midden = licht (open
    plek), voor = weer iets donkerder. De tintgrenzen worden met fijne ruis grillig
    gemaakt, zodat het textuur wordt in plaats van strepen. Optioneel plekken van een
    tweede materiaal (gras op aarde, of aarde in gras)."""
    rnd = bd.rnd
    mat, tone = bd.arrays()
    ys, xs = np.mgrid[0:H, 0:W]
    d = np.clip((ys - top) / (H - top), 0, 1)                 # 0 = horizon, 1 = onderrand
    base = np.where(d < 0.42, tone_far + (tone_mid - tone_far) * np.sqrt(d / 0.42),
                    tone_mid - (tone_mid - tone_near) * np.clip((d - 0.42) / 0.58, 0, 1) ** 1.2)
    clearing = np.exp(-(((xs - path_cx) / path_w) ** 2) - (((ys - (top + 100)) / 60.0) ** 2))
    n1 = _smooth_noise(rnd, W, H, 56)
    n2 = _smooth_noise(rnd, W, H, 16)
    n3 = _smooth_noise(rnd, W, H, 5)
    # perspectief: ver weg moet de fijne ruis 'platter' (breder dan hoog) zijn
    field = base + clearing * 0.9 + (n1 - 0.5) * 1.3 + (n2 - 0.5) * 0.9 + (n3 - 0.5) * 1.1
    gm = ys >= top
    mat[gm] = MI[key]
    tone[gm] = np.floor(field[gm]).astype(np.int16)
    if patch_key:
        pm = gm & ((n1 + (n2 - 0.5) * 0.5 + (n3 - 0.5) * 0.25) > 1 - patch_amount) & (clearing < 0.55)
        mat[pm] = MI[patch_key]
        tone[pm] = np.floor(field[pm] + patch_shift).astype(np.int16)
        # donkere rand rond elke plek (zo liggen ze 'in' de vloer i.p.v. erop geplakt)
        edge = pm & ~(np.roll(pm, 1, 0) & np.roll(pm, -1, 0) & np.roll(pm, 1, 1) & np.roll(pm, -1, 1))
        tone[edge] -= 1
    _store(bd, mat, tone)
    # textuurstreepjes (groter naar voren), steeds 1 tint hoger of lager dan de omgeving
    tone_img = bd.tone.load()
    mat_img = bd.mat.load()
    for _ in range(int(W * (H - top) / 22)):
        x = rnd.uniform(0, W - 4)
        y = top + 1 + (H - top - 2) * rnd.random() ** 0.85
        dd = (y - top) / (H - top)
        ln = 1 + int((0.5 + dd * 3.5) * rnd.random())
        mk = mat_img[int(x), int(y)]
        base_t = tone_img[int(x), int(y)]
        t = base_t + (1 if rnd.random() < 0.42 else -1)
        k = MATS[mk]
        bd.line([(x, y), (x + ln, y)], k, max(0, t))
        if dd > 0.45 and rnd.random() < 0.35:
            bd.line([(x + 1, y - 1), (x + ln - 1, y - 1)], k, max(0, t + 1 if t > base_t else t))


def light_patches(bd, top, areas, step=1):
    """Zachte lichtvlekken (zon door het bladerdak): tint +1 binnen grillige ovalen."""
    mat, tone = bd.arrays()
    ys, xs = np.mgrid[0:H, 0:W]
    rnd = bd.rnd
    noise = _smooth_noise(rnd, W, H, 10)
    for (cx, cy, rx, ry) in areas:
        e = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 + (noise - 0.5) * 0.9
        m = (e < 1) & (ys >= top) & ((mat == MI["aarde"]) | (mat == MI["gras"]))
        tone[m] += step
    _store(bd, mat, tone)


def _store(bd, mat, tone):
    bd.mat = Image.fromarray(mat.astype(np.uint8), "L")
    bd.tone = Image.fromarray(np.clip(tone, 0, 255).astype(np.uint8), "L")
    bd.dm = ImageDraw.Draw(bd.mat)
    bd.dt = ImageDraw.Draw(bd.tone)


def light_shafts(bd, shafts, y_max):
    """Schuine lichtbundels door het bos: tint +1 op bladeren/stammen binnen de bundel
    (harde randen, alleen palettekleuren)."""
    mat, tone = bd.arrays()
    ys, xs = np.mgrid[0:H, 0:W]
    for (x0, width) in shafts:
        u = xs - (x0 + ys * 0.55)
        m = (u > 0) & (u < width) & (ys < y_max) & np.isin(mat, [MI["blad"], MI["schors"], MI["ver"], MI["mos"]])
        tone[m] += 1
    _store(bd, mat, tone)


def bottom_shade(bd, start):
    """Onderrand donkerder (de statusvakken liggen daar), in 2 harde stappen."""
    mat, tone = bd.arrays()
    ys = np.mgrid[0:H, 0:W][0]
    tone[ys > start] -= 1
    tone[ys > start + 44] -= 1
    _store(bd, mat, tone)


# ------------------------------------------------------------------ bos
def make_forest():
    """Dicht bos als 'wand' (geen lucht, zie ARTSTYLE): achteraan lichte nevel tussen
    verre dennen (luchtperspectief), dan donkerder dennen met stammetjes, een donkere
    onderbegroeiing, grote stammen vooraan en een open plek van aangestampte aarde."""
    bd = Board(1606)
    _FLOOR[0] = "aarde"
    rnd = bd.rnd
    horizon = 178
    bd.dm.rectangle([0, 0, W, H], fill=MI["ver"])
    bd.dt.rectangle([0, 0, W, H], fill=5)
    for y in range(0, 150, 1):                  # nevel: lichter naar beneden (licht valt binnen)
        bd.line([(0, y), (W, y)], "ver", 4 if y < 60 else 5)
    # laag A: verre dennen in de nevel (licht, weinig contrast)
    x = -20
    while x < W + 20:
        pine(bd, x, 158 + rnd.uniform(-4, 4), rnd.uniform(120, 168), rnd.uniform(15, 21), "ver", 2,
             trunk=False, detail=False)
        x += rnd.uniform(14, 24)
    # donkere bodem van het bos (hier verdwijnen de stammen in)
    pts = [(0, H)] + [(x, 150 + 6 * math.sin(x * 0.05) + rnd.uniform(-2, 2)) for x in range(0, W + 16, 16)] + [(W, H)]
    bd.poly(pts, "blad", 1)
    # laag B: dennen dichterbij, donker en verzadigd, met stammetjes
    x = -10
    while x < W + 20:
        hgt = rnd.choice((rnd.uniform(100, 140), rnd.uniform(150, 190), rnd.uniform(190, 240)))
        pine(bd, x, 168 + rnd.uniform(-4, 5), hgt, hgt * rnd.uniform(0.13, 0.17), "blad", 1,
             trunk=True, detail=True)
        x += rnd.uniform(18, 54)
    # laag C: grote stammen vooraan, kruinen boven uit beeld
    for cx in (60, 245, 420, 860, 1010, 1190):
        cx += rnd.uniform(-25, 25)
        tw = rnd.uniform(11, 16)
        base = horizon + rnd.uniform(3, 9)
        broadleaf(bd, cx, base, -10, tw, (cx + rnd.uniform(-14, 14), 18, rnd.uniform(64, 86), 46), t0=1)
    # bosrand: struiken en varens langs de horizon (donker, met lichtrand)
    x = -10
    while x < W + 10:
        if rnd.random() < 0.5:
            bush(bd, x, horizon + rnd.uniform(2, 8), rnd.uniform(24, 46), rnd.uniform(14, 22), 1)
        else:
            fern(bd, x, horizon + rnd.uniform(4, 8), rnd.uniform(14, 22), 2)
        x += rnd.uniform(14, 30)
    # vloer: aarde met grasplekken
    ground(bd, horizon + 6, tone_far=1.3, tone_mid=5.0, tone_near=2.6, key="aarde",
           patch_key="gras", patch_amount=0.26, patch_shift=-2.2)
    # struiken die over de vloerrand vallen (overlap = diepte)
    for x in range(10, W, 64):
        x += rnd.uniform(-18, 18)
        if 500 < x < 780:
            continue
        bush(bd, x, horizon + rnd.uniform(12, 20), rnd.uniform(20, 34), rnd.uniform(11, 15), 2)
    # graspollen: dichter aan de randen, spaarzaam op de open plek
    for _ in range(1100):
        x = rnd.uniform(0, W)
        y = rnd.uniform(horizon + 8, H - 3)
        dd = (y - horizon) / (H - horizon)
        edge = abs(x - 640) / 640
        if rnd.random() > 0.2 + edge * 1.0:
            continue
        tuft(bd, x, y, 0.9 + dd * 2.4, 1 if dd < 0.3 else 2)
    # kiezels, takjes en blaadjes
    for _ in range(330):
        x = rnd.uniform(0, W)
        y = rnd.uniform(horizon + 10, H - 4)
        dd = (y - horizon) / (H - horizon)
        pebble(bd, x, y, 0.8 + dd * 2.6 * rnd.random(), 2 if dd > 0.3 else 1)
    for _ in range(60):
        x = rnd.uniform(0, W)
        y = rnd.uniform(horizon + 20, H - 6)
        ln = 3 + (y - horizon) / 30
        a = rnd.uniform(-0.5, 0.5)
        bd.line([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], "schors", 3)
    for _ in range(300):
        x = rnd.uniform(0, W)
        y = rnd.uniform(horizon + 10, H - 4)
        bd.px(x, y, "bloem", rnd.choice((0, 0, 1)))
        if rnd.random() < 0.5:
            bd.px(x + 1, y, "bloem", 0)
    # zachte lichtvlekken op de open plek + lichtbundels door het bos
    light_patches(bd, horizon + 6, [(640, 262, 220, 34), (480, 226, 70, 12), (820, 296, 90, 16),
                                    (560, 322, 60, 10), (720, 214, 60, 10)])
    light_patches(bd, horizon + 6, [(620, 258, 110, 16), (790, 294, 36, 6)])
    light_shafts(bd, [(250, 30), (400, 16), (690, 24), (900, 14)], horizon + 2)
    # voorgrond: stenen en varens in de hoeken (deels onder de bediening)
    rock(bd, 300, 372, 46, 26)
    rock(bd, 334, 386, 24, 12, t0=1)
    fern(bd, 262, 404, 34, 1)
    fern(bd, 1010, 396, 36, 1)
    rock(bd, 978, 362, 40, 21)
    rock(bd, 468, 214, 22, 11)
    rock(bd, 848, 224, 30, 14)
    for (fx, fy) in ((210, 300), (1080, 300), (392, 326), (906, 338)):
        fern(bd, fx, fy, 22, 2)
    foreground(bd)
    return bd.render()


# ------------------------------------------------------------------ vlakte
def rock_hill(bd, cx, cy, rx, ry):
    """Bleke rotsheuvel: bol, licht van linksboven in harde vlakken, gelaagde breuklijnen."""
    rnd = bd.rnd
    mat, tone = bd.arrays()
    ys, xs = np.mgrid[0:H, 0:W]
    dx = (xs + 0.5 - cx) / rx
    dy = (ys + 0.5 - cy) / ry
    nz = _smooth_noise(rnd, W, H, 7)
    dist = dx * dx + np.where(dy < 0, (dy * 1.15) ** 2, dy * dy) + (nz - 0.5) * 0.35
    m = (dist < 1) & (ys < cy + ry * 0.55)
    lit = -dx * 0.85 - dy * 0.95
    t = np.where(lit > 0.95, 5, np.where(lit > 0.45, 4, np.where(lit > -0.15, 3, np.where(lit > -0.6, 2, 1))))
    t = np.where(dist > 0.86, np.minimum(t, 2), t)
    mat[m] = MI["rots"]
    tone[m] = t[m]
    _store(bd, mat, tone)
    slope = rnd.uniform(-0.12, 0.12)
    for k in range(3):                          # gelaagdheid: korte, bijna rechte breuklijnen
        y = cy - ry * 0.45 + k * ry * 0.33 + rnd.uniform(-2, 2)
        x0 = cx - rx * rnd.uniform(0.2, 0.7)
        x1 = x0 + rx * rnd.uniform(0.3, 0.6)
        pts = [(x, y + (x - x0) * slope) for x in np.arange(x0, x1, 2)]
        pts = [q for q in pts if ((q[0] - cx) / rx) ** 2 + ((q[1] - cy) / ry) ** 2 < 0.75]
        if len(pts) > 1:
            bd.line(pts, "rots", 2)
            if x0 < cx:
                bd.line([(q[0], q[1] + 1) for q in pts], "rots", 5)
    for _ in range(int(rx / 4)):                # plukjes gras bovenop
        a = rnd.uniform(math.pi * 1.15, math.pi * 1.75)
        x = cx + math.cos(a) * rx * 0.8
        y = cy + math.sin(a) * ry * 0.85 + 2
        bd.ell(x, y, rnd.uniform(2, 4), 1.6, "weide", rnd.choice((2, 3, 4)))
    for _ in range(int(rx / 2)):
        x = cx + rnd.uniform(-rx * 0.7, rx * 0.7)
        y = cy + rnd.uniform(-ry * 0.8, ry * 0.3)
        if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 0.7:
            bd.px(x, y, "rots", 2)


def make_plains():
    """Vlakte als 'wand' (geen lucht): donkere verre heuvelrug, een rij bleke
    rotsheuvels met struiken ervoor, en een grasvloer met aardeplekken."""
    bd = Board(2604)
    _FLOOR[0] = "weide"
    rnd = bd.rnd
    horizon = 166
    bd.dm.rectangle([0, 0, W, H], fill=MI["heuvel"])
    bd.dt.rectangle([0, 0, W, H], fill=0)
    # twee verre heuvelruggen (achterste donkerst), met fijne textuur
    for (yb, amp, t, seed) in ((70, 22, 2, 0.0), (104, 18, 3, 2.0)):
        pts = [(0, H)]
        for x in range(0, W + 8, 8):
            pts.append((x, yb - amp * (0.5 + 0.5 * math.sin(x / 74 + seed)) - 8 * math.sin(x / 23 + seed * 3)))
        pts.append((W, H))
        bd.poly(pts, "heuvel", t)
        bd.line(pts[1:-1], "heuvel", t + 2)
        for _ in range(900):
            x = rnd.uniform(0, W)
            y = rnd.uniform(yb - amp, horizon)
            if bd.tone.getpixel((int(x), int(y))) == t and bd.mat.getpixel((int(x), int(y))) == MI["heuvel"]:
                bd.px(x, y, "heuvel", t - 1)
    # bleke rotsheuvels
    x = -20
    while x < W + 40:
        rock_hill(bd, x, 138 + rnd.uniform(-6, 6), rnd.uniform(30, 44), rnd.uniform(30, 40))
        x += rnd.uniform(40, 62)
    # bosjes en dennetjes ervoor
    x = -10
    while x < W + 10:
        if rnd.random() < 0.3:
            pine(bd, x, horizon + 2, rnd.uniform(40, 60), rnd.uniform(10, 14), "weide", 1, trunk=True, detail=True)
        else:
            bush(bd, x, horizon + rnd.uniform(0, 6), rnd.uniform(22, 40), rnd.uniform(14, 20), 2, mat="weide")
        x += rnd.uniform(14, 28)
    # vloer: gras met aardeplekken
    ground(bd, horizon + 4, tone_far=1.6, tone_mid=5.2, tone_near=3.0, key="weide",
           patch_key="aarde", patch_amount=0.13, patch_shift=1.4)
    for x in range(20, W, 80):
        x += rnd.uniform(-20, 20)
        if 520 < x < 760:
            continue
        bush(bd, x, horizon + rnd.uniform(14, 22), rnd.uniform(18, 30), rnd.uniform(10, 13), 3, mat="weide")
    # graspollen in de weide-kleuren, bloemetjes, kiezels
    for _ in range(1500):
        x = rnd.uniform(0, W)
        y = rnd.uniform(horizon + 8, H - 3)
        dd = (y - horizon) / (H - horizon)
        if bd.mat.getpixel((int(x), int(y))) != MI["weide"]:
            continue
        n = rnd.randint(3, 5)
        s_ = 0.9 + dd * 2.4
        for k in range(n):
            dx = (k - (n - 1) / 2) * s_ * 0.5
            hgt = s_ * rnd.uniform(1.2, 2.2)
            t = 3 + (2 if abs(k - (n - 1) / 2) < 1 else 1 if k < n / 2 else 0) - (1 if dd < 0.3 else 0)
            bd.line([(x + dx, y), (x + dx + dx * 0.6 + rnd.uniform(-1, 1), y - hgt)], "weide", t)
    for _ in range(260):
        x = rnd.uniform(0, W)
        y = rnd.uniform(horizon + 10, H - 4)
        k = rnd.choice(("bloem", "bloemw", "bloemw"))
        bd.px(x, y, k, 3)
        bd.px(x - 1, y, k, 2)
        bd.px(x, y + 1, "weide", 1)
    for _ in range(160):
        x = rnd.uniform(0, W)
        y = rnd.uniform(horizon + 12, H - 4)
        dd = (y - horizon) / (H - horizon)
        pebble(bd, x, y, 0.8 + dd * 2.2 * rnd.random(), 2)
    light_patches(bd, horizon + 4, [(640, 266, 240, 34), (430, 320, 60, 10), (860, 236, 70, 10)])
    rock(bd, 300, 378, 50, 26, mat="rots", t0=1)
    rock(bd, 990, 366, 40, 22, mat="rots", t0=1)
    rock(bd, 862, 214, 26, 12, mat="rots", t0=1)
    rock(bd, 436, 222, 18, 9, mat="rots", t0=1)
    foreground(bd, plains=True)
    return bd.render()


def big_fern(bd, x, y, size, t0=1, spread=(-165, -15), n=7, mat="blad"):
    """Grote voorgrond-varen: gevulde bladen met blaadjes langs een gebogen nerf.
    Elk blaadje: donkere onderkant, middentint, lichte bovenrand (licht van boven)."""
    rnd = bd.rnd
    for k in range(n):
        ang = math.radians(spread[0] + (spread[1] - spread[0]) * k / max(1, n - 1) + rnd.uniform(-6, 6))
        ln = size * rnd.uniform(0.75, 1.0) * (0.8 if k in (0, n - 1) else 1)
        pts = []
        for st in range(13):
            t = st / 12
            droop = t * t * size * 0.5
            pts.append((x + math.cos(ang) * ln * t, y + math.sin(ang) * ln * t + droop))
        for st in range(1, 12):
            px_, py_ = pts[st]
            qx, qy = pts[st + 1]
            dx, dy = qx - px_, qy - py_
            dl = math.hypot(dx, dy) + 1e-6
            nx, ny = -dy / dl, dx / dl
            leaf = size * 0.16 * (1 - st / 13) + 1.2
            for side in (-1, 1):
                tipx = px_ + nx * leaf * side + dx * 0.6
                tipy = py_ + ny * leaf * side + dy * 0.6 + 1
                poly = [(px_, py_), (px_ + dx * 0.9, py_ + dy * 0.9), (tipx, tipy)]
                up = (ny * side) < 0          # blaadje wijst omhoog -> lichter
                bd.poly(poly, mat, t0 + (2 if up else 1))
                bd.line([(px_, py_), (tipx, tipy)], mat, t0 + (3 if up else 0))
        bd.line(pts, mat, t0, width=1)


def foreground(bd, plains=False):
    """Voorgrond in de zichtbare hoeken (16:9 toont x 256-1024): grote donkere varens,
    struiken en een bemoste steen. Ze 'omlijsten' het slagveld (dichtere camera)."""
    rnd = bd.rnd
    mat = "weide" if plains else "blad"
    # rechterrand, halverwege: struik + steen + varen
    bush(bd, 1004, 300, 64, 34, 2, mat=mat)
    rock(bd, 958, 318, 54, 28)
    big_fern(bd, 990, 330, 46, 3, mat=mat)
    # linksonder (onder de D-pad) en rechtsonder (onder A/B)
    bush(bd, 300, 418, 110, 52, 2, mat=mat)
    big_fern(bd, 330, 436, 64, 3, mat=mat)
    big_fern(bd, 392, 434, 40, 2, spread=(-150, -40), n=5, mat=mat)
    rock(bd, 430, 426, 40, 18)
    bush(bd, 992, 420, 100, 50, 2, mat=mat)
    big_fern(bd, 960, 436, 66, 3, mat=mat)
    big_fern(bd, 900, 434, 42, 2, spread=(-140, -40), n=5, mat=mat)
    # naast het menu op de vloer
    big_fern(bd, 392, 226, 30, 2, n=6, mat=mat)
    if plains:
        for (x, y) in ((450, 430), (870, 430), (1000, 250)):
            for _ in range(5):
                tuft(bd, x + rnd.uniform(-14, 14), y + rnd.uniform(-6, 0), 4.0, 2)


def make_all(root):
    import os
    d = os.path.join(root, "assets", "battle")
    os.makedirs(d, exist_ok=True)
    make_forest().save(os.path.join(d, "backdrop_bos.png"))
    make_plains().save(os.path.join(d, "backdrop_vlakte.png"))


if __name__ == "__main__":
    make_forest().save("/tmp/v6/bos.png")
    make_plains().save("/tmp/v6/vlakte.png")
