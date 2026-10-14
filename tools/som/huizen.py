#!/usr/bin/env python3
"""SoM-huizen per gebied, offline (geen shader, geen runtime-opbouw).

Indeling = RPG ART fase 1 buildings.house(w, rh, wh, door, dormers, chimneys, sign, seed, stone):
rij 0 schoorsteentop (alleen als er een schoorsteen is), rh dakrijen, wh muurrijen; de deur staat
onderaan. Tegels komen uit de geëxporteerde gebouw-tileset van het gebied (export_tilesets.py), dus
het palet van het gebied zit er al in.

Bron:  tools/som/bron/huizen/<gebied>.json   {pand_id: {w, rh, wh, door, chimneys, dormers, sign, seed, stone}}
Uit:   assets/tilesets/som/<gebied>/huizen/<pand_id>.png
       assets/tilesets/som/<gebied>/huizen.json  {pand_id: {maat: [w, h], muur_rijen, deur: [kol, rij]}}

Gebruik: python3 tools/som/huizen.py [gebied ...]
"""
import json, os, random, sys
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
T = 16


def module(naam, w, h):
    return [["%s_c%dr%d" % (naam, x, y) for x in range(w)] for y in range(h)]


MODS = {}
for sx in ("", "_steen"):
    MODS["enkel" + sx] = module("deur_enkel" + sx, 1, 2)
    MODS["dubbel" + sx] = module("deur_dubbel" + sx, 2, 2)
    MODS["boog" + sx] = module("deur_boog" + sx, 2, 2)
    MODS["luik" + sx] = module("raam_luik" + sx, 2, 2)
    MODS["luikb" + sx] = module("raam_luik_b" + sx, 2, 2)
DORMER = module("dakkapel", 2, 2)


def house(w, rh, wh, door="enkel", dormers=(), chimneys=(), sign=None, seed=1, stone=False):
    """Kopie van de indeling van RPG ART buildings.house (fase 1); geeft (grond, overlay, deurcel)."""
    assert w >= 4 and rh >= 3 and wh >= 2
    r = random.Random(seed); H = rh + wh + 1
    g = [[None] * w for _ in range(H)]; o = [[None] * w for _ in range(H)]
    for ty in range(rh):
        for tx in range(w):
            side = "l" if tx == 0 else "r" if tx == w - 1 else "m"
            if ty == 0: n = "dak_nok_" + side
            elif ty == rh - 1: n = "dak_goot_" + side
            elif side != "m": n = "dak_rand_" + side
            else: n = "dak_vul_%d" % r.choice((0, 0, 1, 1, 2, 3))
            g[1 + ty][tx] = n
    for dx in dormers:
        for yy in range(2):
            for xx in range(2): g[2 + yy][dx + xx] = DORMER[yy][xx]
    for cx in chimneys: o[0][cx] = "schoorsteen_top"; g[1][cx] = "schoorsteen_voet_nok"
    wy = 1 + rh; mid = w // 2
    dw = {"enkel": 1, "dubbel": 2, "boog": 2}[door]; dx0 = mid - (dw + 1) // 2 if dw == 1 else mid - 1
    for ty in range(wh):
        for tx in range(w):
            base = ty == wh - 1; side = "l" if tx == 0 else "r" if tx == w - 1 else "m"
            if stone: n = ("muur_steen_" if not base else "muur_voet_") + side
            elif base: n = "muur_voet_" + side
            elif side != "m": n = "muur_pleister_" + side
            else: n = "muur_pleister_%d" % r.choice((0, 0, 0, 0, 0, 1, 2))
            g[wy + ty][tx] = n
    sx = "_steen" if stone else ""; mod = MODS[door + sx]
    for yy in range(2):
        for xx in range(dw): g[wy + wh - 2 + yy][dx0 + xx] = mod[yy][xx]
    used = set(range(dx0, dx0 + dw)); wins = []; x = 1
    while x <= w - 3:
        if not (set(range(x, x + 2)) & used) and not (wh < 3 and x + 1 == dx0 - 1):
            wins.append(x); used |= set(range(x, x + 2)); x += 3
        else: x += 1
    for i, x in enumerate(wins):
        mw = MODS[("luik" if i % 2 == 0 else "luikb") + sx]
        if wh >= 3:
            for yy in range(2):
                for xx in range(2): g[wy + yy][x + xx] = mw[yy][xx]
        else: g[wy][x] = "raam_klein"; g[wy][x + 1] = "raam_klein"
    if not stone:
        for tx in range(2, w - 2):
            if tx not in used and wh >= 3 and g[wy][tx].startswith("muur_pleister"):
                for ty in range(wh - 1): g[wy + ty][tx] = "muur_stijl"
                if wh >= 4 and tx % 3 == 0: g[wy + wh - 2][tx] = "muur_vakwerk_a" if tx % 2 else "muur_vakwerk_b"
    if sign and dx0 + dw < w - 1 and g[wy + wh - 2][dx0 + dw].startswith(("muur_pleister", "muur_stijl")):
        g[wy + wh - 2][dx0 + dw] = "bord_" + sign
    if dx0 - 1 > 0 and g[wy + wh - 2][dx0 - 1].startswith("muur_pleister"):
        g[wy + wh - 2][dx0 - 1] = "muurlamp"
    return g, o, (dx0, wy + wh - 1)


def maak(gebied):
    bron = os.path.join(REPO, "tools/som/bron/huizen/%s.json" % gebied)
    d = os.path.join(REPO, "assets/tilesets/som", gebied)
    sheet = Image.open(os.path.join(d, "gebouw.png")).convert("RGBA")
    namen = json.load(open(os.path.join(d, "gebouw_namen.json")))
    os.makedirs(os.path.join(d, "huizen"), exist_ok=True)
    uit = {}
    for pid, spec in json.load(open(bron)).items():
        g, o, deur = house(spec["w"], spec["rh"], spec["wh"], spec.get("door", "enkel"), spec.get("dormers", ()),
                           spec.get("chimneys", ()), spec.get("sign"), spec.get("seed", 1), spec.get("stone", False))
        if not spec.get("chimneys"):  # lege schoorsteenrij weglaten
            g, o, deur = g[1:], o[1:], (deur[0], deur[1] - 1)
        h, w = len(g), len(g[0])
        img = Image.new("RGBA", (w * T, h * T))
        for laag in (g, o):
            for y in range(h):
                for x in range(w):
                    n = laag[y][x]
                    if n is None: continue
                    c, r = namen[n]
                    img.alpha_composite(sheet.crop((c * T, r * T, c * T + T, r * T + T)), (x * T, y * T))
        img.save(os.path.join(d, "huizen", pid + ".png"))
        uit[pid] = {"maat": [w, h], "muur_rijen": spec["wh"], "deur": list(deur)}
    json.dump(uit, open(os.path.join(d, "huizen.json"), "w"), indent="\t", sort_keys=True)
    print("%s: %d huizen" % (gebied, len(uit)))


if __name__ == "__main__":
    for gb in (sys.argv[1:] or [os.path.basename(p)[:-5] for p in os.listdir(os.path.join(REPO, "tools/som/bron/huizen"))]):
        maak(gb)
