#!/usr/bin/env python3
"""v0.15 ARCHIEF-STIJL 'grauwe grijze bieb' (gegenereerd, GEEN handwerk).

Dennis wil dat de archieven (Eerste Archief en alle volgende) eruitzien als de gevechts-
achtergrond assets/battle/bibliotheek.png: een grijze, sombere, vervallen bibliotheek met hoge
donkere boekenkasten, een grijze stenen vloer, stof, losse bladzijden en heel spaarzaam een
magenta/cyaan glitch-pixel.

Dit script maakt NIEUWE bestanden (de originelen van RPG ART blijven onaangeroerd, zie
tools/handwerk.txt):
  assets/tiles/dungeon/archief_grijs_tiles.png        256x80, zelfde nummering als dungeon_tiles_v14.png
                                                      (docs/DUNGEON_TILES.txt)
  assets/tiles/dungeon/archief_grijs_bibliotheek.png  256x64, zelfde nummering als bibliotheek_tiles.png
                                                      (docs/BIBLIOTHEEK_TILES.txt)
  assets/sprites/dungeon/grijs/<naam>.png             grijze versies van de losse dungeon-sprites
                                                      (zelfde maat en frames als het origineel)
Werkwijze:
  - Palet: afgeleid van bibliotheek.png (koel neutraal grijs h~240 s~0.1, van (6,6,8) tot
    (113,112,110)), een stoffig grijsbruin houtpalet, gedempt mauve (kleden) en de glitch-
    accenten magenta (255,30,230) / cyaan.
  - Vloer: nieuw getekende grijze steenplaten (3 varianten + schaduwranden); decor (botten,
    bladzijden, puin, runen) wordt van de oude tegel overgenomen en omgekleurd.
  - Muurvoorkant: de gewone voorkant (32/33), de mos-voorkant (46/47) en de glitch-scheur
    (38/39) worden hoge donkere boekenkasten (zoals op de achtergrond); de einden (34-37),
    bogen, ladder en pilaren blijven grijze steen (pilaren tussen de kasten).
  - Al het andere: omgekleurd naar het palet (vorm/pixels van RPG ART blijven gelijk, zodat
    alles naadloos past en botsing/indeling identiek blijven).
Gebruik:  python3 tools/art_archief_grijs.py   (overschrijft alleen de bestanden hierboven)
"""
import colorsys
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)

# ------------------------------------------------------------------ palet (uit bibliotheek.png)
GREY = [(6, 6, 8), (14, 14, 17), (21, 21, 24), (29, 29, 33), (38, 38, 42), (48, 48, 52),
        (60, 60, 63), (74, 74, 76), (92, 91, 91), (113, 112, 110), (138, 137, 134),
        (166, 165, 160), (196, 194, 188)]
WOOD = [(16, 14, 14), (26, 23, 22), (36, 32, 30), (47, 42, 38), (59, 53, 48), (73, 66, 59),
        (90, 82, 73), (110, 101, 90)]
MAUVE = [(22, 17, 23), (33, 25, 34), (45, 34, 46), (58, 44, 59), (72, 56, 73), (90, 72, 90)]
MAGENTA = [(70, 8, 64), (138, 12, 132), (200, 22, 182), (255, 30, 230), (255, 120, 240)]
CYAN = [(8, 60, 66), (8, 112, 122), (60, 170, 176), (117, 196, 196), (170, 236, 236)]
FLAME = [(120, 108, 86), (176, 164, 132), (214, 206, 180), (236, 232, 214)]


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def nearest(ramp, l):
    return min(ramp, key=lambda c: abs(lum(c) - l))


def recolor_px(p, dim=0.9):
    r, g, b, a = p
    if a == 0:
        return p
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    h *= 360
    l = lum(p)
    # alleen echte neon-accenten blijven gekleurd (spaarzaam, zoals op de achtergrond)
    if s > 0.6 and v > 0.62 and 285 <= h <= 335:
        return nearest(MAGENTA, l) + (a,)
    if s > 0.55 and v > 0.6 and 168 <= h <= 200:
        return nearest(CYAN, l) + (a,)
    if s > 0.3 and (h >= 280 or h < 12) and v > 0.15:      # paars/rood fluweel, kleed -> gedempt mauve
        return nearest(MAUVE, l * 1.05) + (a,)
    if s > 0.35 and v > 0.75 and 35 <= h <= 65:          # kaarsvlam / licht: bleek en gedempt
        return nearest(FLAME, l) + (a,)
    if s > 0.22 and 12 <= h <= 60:                         # hout / messing -> stoffig grijsbruin
        return nearest(WOOD, l * dim) + (a,)
    return nearest(GREY, l * dim) + (a,)


def recolor(im, dim=0.9):
    im = im.convert("RGBA")
    out = Image.new("RGBA", im.size)
    out.putdata([recolor_px(p, dim) for p in im.get_flattened_data()])
    return out


def tile(im, n):
    x, y = (n % 16) * 16, (n // 16) * 16
    return im.crop((x, y, x + 16, y + 16))


def put(im, n, t):
    im.paste(t, ((n % 16) * 16, (n // 16) * 16))


# ------------------------------------------------------------------ nieuwe stenen vloer
G = {i: GREY[i] + (255,) for i in range(len(GREY))}


def floor_tile(variant, seed):
    rnd = random.Random(seed)
    t = Image.new("RGBA", (16, 16), G[5])
    px = t.load()
    # vlakken: variant 0 = één grote plaat, 1 = twee platen boven/onder (verspringend),
    # 2 = gebarsten plaat
    for y in range(16):
        for x in range(16):
            r = rnd.random()
            px[x, y] = G[4] if r < 0.10 else (G[6] if r < 0.15 else G[5])
    # voegen (1 px donker) boven en links: samen een raster van 16x16-platen
    for i in range(16):
        px[i, 0] = G[2]
        px[0, i] = G[2]
    # lichte rand linksboven binnen de plaat, donkere onderrand
    for i in range(1, 16):
        px[i, 1] = G[6]
        px[1, i] = G[6] if i > 1 else px[1, i]
        px[i, 15] = G[4]
        px[15, i] = G[4]
    if variant == 1:
        for x in range(16):
            px[x, 8] = G[2]
            px[x, 9] = G[6] if x else G[2]
        sx = 6 + rnd.randint(0, 4)
        for y in range(1, 8):
            px[sx, y] = G[2]
            if sx + 1 < 16:
                px[sx + 1, y] = G[6]
    if variant == 2:
        x, y = rnd.randint(3, 6), rnd.randint(2, 4)
        for _ in range(12):
            if 1 < x < 15 and 1 < y < 15:
                px[x, y] = G[3]
                if x + 1 < 15:
                    px[x + 1, y] = G[6]
            x += rnd.choice((0, 1, 1))
            y += 1
    # stof: een paar lichte korrels
    for _ in range(3):
        x, y = rnd.randint(2, 14), rnd.randint(2, 14)
        px[x, y] = G[7]
    return t


FLOORS = [floor_tile(0, 11), floor_tile(1, 23), floor_tile(2, 37)]


def overlay_decor(old, base_colors, new_floor):
    """Pixels van de oude vloer (kleur in base_colors) -> nieuwe vloer; de rest omkleuren."""
    old = old.convert("RGBA")
    rec = recolor(old)
    out = new_floor.copy()
    o, r, px = old.load(), rec.load(), out.load()
    for y in range(16):
        for x in range(16):
            if o[x, y] not in base_colors:
                px[x, y] = r[x, y]
    return out


def shade(t, f):
    """f(x, y) -> factor 0..1 (schaduw)."""
    out = t.copy()
    px = out.load()
    for y in range(16):
        for x in range(16):
            c = px[x, y]
            k = f(x, y)
            px[x, y] = nearest(GREY, lum(c) * k) + (255,)
    return out


def shadow_profile(old, base_tiles, axis):
    """Gemiddelde helderheidsverhouding per rij (axis 1) of kolom (axis 0) t.o.v. de basisvloer."""
    base_l = sum(lum(p) for b in base_tiles for p in b.convert("RGBA").get_flattened_data()) / (256 * len(base_tiles))
    o = old.convert("RGBA").load()
    prof = []
    for i in range(16):
        s = sum(lum(o[(j, i) if axis == 1 else (i, j)]) for j in range(16)) / 16
        prof.append(min(1.0, s / base_l))
    return prof


# ------------------------------------------------------------------ boekenkasten (muurvoorkant)
def shelf_pair(lib_rec, top_n, bot_n, cobweb=False, seed=0):
    """Hoge donkere kast uit de (omgekleurde) bibliotheek-kast: boekruggen extra gedempt."""
    top, bot = tile(lib_rec, top_n).copy(), tile(lib_rec, bot_n).copy()
    rnd = random.Random(seed)
    for t in (top, bot):
        px = t.load()
        for y in range(16):
            for x in range(16):
                c = px[x, y]
                if c[:3] in MAGENTA or c[:3] in CYAN:
                    continue
                # alles iets donkerder: 'hoge donkere kasten'
                ramp = WOOD if c[:3] in WOOD else GREY
                px[x, y] = nearest(ramp, lum(c) * 0.85) + (255,)
    if cobweb:
        px = top.load()
        web = [(4, 4), (5, 5), (6, 6), (7, 7), (8, 7), (5, 4), (6, 4), (7, 4), (4, 5), (4, 6), (4, 7),
               (6, 5), (7, 6), (9, 8), (10, 9)]
        for (x, y) in web:
            px[x, y] = G[9] if (x + y) % 3 else G[8]
        # stofdraad naar beneden
        pb = bot.load()
        for (x, y) in [(10, 0), (10, 1), (11, 2)]:
            pb[x, y] = G[8]
    return top, bot


def main():
    src = Image.open(P("assets/tiles/dungeon/dungeon_tiles_v14.png")).convert("RGBA")
    lib = Image.open(P("assets/tiles/dungeon/bibliotheek_tiles.png")).convert("RGBA")
    out = recolor(src)
    lib_rec = recolor(lib)
    base = [tile(src, i) for i in (0, 1, 2)]
    dirt = set()
    for b in base:
        dirt |= set(b.get_flattened_data())
    # vloer A/B/C
    for i in range(3):
        put(out, i, FLOORS[i])
    # decor op de vloer (onkruid, botten, bladzijden, puin, schedel, rune, sokkel, afgrondrand,
    # glitch-scheur, trap omlaag, onderrand-doorgang)
    for n in (3, 4, 5, 6, 7, 11, 12, 14, 15, 58, 64):
        put(out, n, overlay_decor(tile(src, n), dirt, FLOORS[n % 3]))
    # tegel 5 (losse bladzijden) extra blad, zoals op de achtergrond
    # schaduwranden (8 boven, 9 links, 10 hoek) met het profiel van RPG ART
    top = shadow_profile(tile(src, 8), base, 1)
    left = shadow_profile(tile(src, 9), base, 0)
    put(out, 8, shade(FLOORS[0], lambda x, y: top[y]))
    put(out, 9, shade(FLOORS[1], lambda x, y: left[x]))
    put(out, 10, shade(FLOORS[2], lambda x, y: min(top[y], left[x])))
    # muurvoorkant -> hoge donkere boekenkasten (32/33 midden A, 46/47 midden B met spinrag,
    # 38/39 glitch-boek). Einden 34-37 blijven steen (pilaren tussen de kasten).
    t, b = shelf_pair(lib_rec, 1, 17, seed=1)
    put(out, 32, t); put(out, 33, b)
    t, b = shelf_pair(lib_rec, 2, 18, cobweb=True, seed=2)
    put(out, 46, t); put(out, 47, b)
    t, b = shelf_pair(lib_rec, 5, 21, seed=3)
    put(out, 38, t); put(out, 39, b)
    # kapotte kast 40/41: omgekleurd, iets donkerder
    for n in (40, 41):
        put(out, n, shade(tile(out, n), lambda x, y: 0.9))
    out.save(P("assets/tiles/dungeon/archief_grijs_tiles.png"))

    # ---------------- bibliotheek-atlas: zelfde nummering, grijze steenvloer
    lo = lib_rec.copy()
    wb = [tile(lib, 32), tile(lib, 33)]
    wood = set()
    for b in wb:
        wood |= set(b.get_flattened_data())
    for n in range(0, 9):          # kasten / muren: donkerder (zoals de achtergrond)
        t, b = shelf_pair(lib_rec, n, n + 16, seed=10 + n)
        put(lo, n, t); put(lo, n + 16, b)
    put(lo, 32, FLOORS[0]); put(lo, 33, FLOORS[1])
    topl = shadow_profile(tile(lib, 34), wb, 1)
    leftl = shadow_profile(tile(lib, 35), wb, 0)
    put(lo, 34, shade(FLOORS[0], lambda x, y: topl[y]))
    put(lo, 35, shade(FLOORS[1], lambda x, y: leftl[x]))
    put(lo, 36, shade(FLOORS[2], lambda x, y: min(topl[y], leftl[x])))
    for n in [37, 38, 39, 40, 41, 42] + list(range(48, 58)):
        put(lo, n, overlay_decor(tile(lib, n), wood, FLOORS[n % 3]))
    lo.save(P("assets/tiles/dungeon/archief_grijs_bibliotheek.png"))

    # ---------------- losse sprites (zelfde maat/frames)
    sprites = {
        "staande_kast": "assets/sprites/dungeon/staande_kast.png",
        "kandelaar": "assets/sprites/dungeon/kandelaar.png",
        "golemdeur": "assets/sprites/dungeon/golemdeur.png",
        "leestafel": "assets/sprites/dungeon/leestafel.png",
        "schatkist": "assets/sprites/dungeon/schatkist.png",
        "kist": "assets/sprites/buiten/kist.png",
        "geheime_deur_archief": "assets/puzzle/geheime_deur_archief.png",
        "drukplaat": "assets/puzzle/drukplaat.png",
        "drukplaat_rune": "assets/puzzle/drukplaat_rune.png",
        "kast_vast": "assets/puzzle/kast_vast.png",
        "kast_duwbaar": "assets/puzzle/kast_duwbaar.png",
        "kast_zwaar": "assets/puzzle/kast_zwaar.png",
        "poort": "assets/puzzle/poort.png",
        "hendel": "assets/puzzle/hendel.png",
        "herstelsteen": "assets/puzzle/herstelsteen.png",
    }
    for name, path in sprites.items():
        recolor(Image.open(P(path)), dim=0.95).save(P("assets/sprites/dungeon/grijs", name + ".png"))
    print("klaar:", len(sprites), "sprites + 2 atlassen")


if __name__ == "__main__":
    main()
