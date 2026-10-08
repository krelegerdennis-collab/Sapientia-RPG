"""
v8 – Dorp Wilgendal en de wereldkaart in de stijl 'De Vergeten Bibliotheek'
(digitaal verval x dark academia, zie docs/ARTSTYLE.md hoofdstuk 10d).

Werkwijze: de bestaande generatoren (generate_art.py + art_maps.py) blijven de basis,
zodat ELKE tile op dezelfde plek in dezelfde sheet blijft (dorp.png 864x16,
huis.png 80x80, wereld.png 256x144). Alleen de paletten worden vervangen
(ontkleurd grijs/steen met donkergroen) en een paar tiles krijgen een nieuw ontwerp:
  dorp  : bloemen -> papiersnippers, ton -> lantaarn op sokkel, hek -> smeedijzer,
          bloemenperk -> grijs-witte bloemen met een snipper, lage muur -> natuursteen
  huis  : bibliotheek-gebouw (natuursteen, leien dak met mos, boogramen met boeken,
          lantaarns naast een boogdeur, kapotte leien met glitch-pixels)
  wereld: stadje-icoon = kleine ruïne-bibliotheek met torentje; lichte vlakken =
          korstmos/puin, zand = as/grind
  figuren: Dennis (donkere cape, leer, grijze kraag) en een geleerde in grijsgroen.
Magenta/cyaan alleen als losse pixels (ramen, kraal, glitch op het dak).
Collision/doorgang zit in de .tres-tilesets en is NIET aangepast.
"""
import os
import random
from PIL import Image

import generate_art as ga
import art_maps as am

T = 16
hexc, ramp = ga.hexc, ga.ramp
NEON_M = hexc("e040c8")
NEON_C = hexc("40e0e8")
LAMP = ramp("6a4410", "b07a20", "e8b84a", "fff0b0")       # warm lantaarnlicht

# ---------------------------------------------------------------- paletten (v8)
V8_GA = dict(
    GRASS=ramp("222e22", "2c3a2c", "364636", "405242", "4e6050", "627462"),     # mosgroen, ontkleurd
    PATH=ramp("3e3c38", "4e4b46", "5e5a54", "6e6a62", "827d74", "9c968a"),      # as-grijs pad
    LEAF=ramp("0a130d", "122017", "1a2c20", "24392a", "304a36", "425c46"),      # donkergroen blad
    TRUNK=ramp("1c1714", "322820", "463a2e"),
    STONE=ramp("1c1e22", "2e3136", "3e4248", "4f535a", "62666c", "80848a"),
    WATER=ramp("0a1216", "121c24", "1a2832", "243642", "364c5a", "62808c"),
    WOOD=ramp("1e1714", "33281f", "47382b", "5c4a38", "73604a", "8f7c64"),
    ROCK=ramp("1a1b1e", "2c2e32", "3e4146", "52565c", "6a6e74", "868a90"),
    SHADOW_GRASS=hexc("141c15"),
)
V8_AM = dict(
    COBBLE=ramp("1e2024", "2c2f34", "3b3e44", "4b4e54", "5e6168", "7a7d84"),    # grijze plavuizen
    BRICK=ramp("222424", "343736", "474a48", "5a5d5a", "70736e", "8c8f88"),     # natuursteen
    ROOF=ramp("111816", "1a2421", "24302c", "2e3c37", "3a4a44", "4e605a"),      # leien, groenzwart
    PLASTER=ramp("3a3b3a", "4c4d4b", "5e5f5c", "71716d", "868680", "a2a29a"),   # steen
    BEAM=ramp("171412", "26211d", "362f29"),
    GLASS=ramp("0a1012", "131d21", "203036", "3e7e84"),
    WG=ramp("1a271d", "223226", "2a3c2e", "334736", "3e5440", "4e6650"),        # vlakte: donker mosgroen
    WL=ramp("2a312b", "353e36", "424b42", "50594e", "626b5e", "7c8476"),        # korstmos / puin
    FOREST=ramp("040906", "08110b", "0d1a11", "142418", "1c3020", "283e2c"),
    MOUNT=ramp("18191c", "282a2e", "3a3d42", "4f5258", "686c72", "8a8e94"),     # grijze bergen
    SEA=ramp("080c12", "0d141c", "131e28", "1a2834", "263a4a", "48606e"),       # leisteen-zee
    SAND=ramp("2c2a26", "3a3732", "48453f", "57534c", "6a665e", "847f76"),      # as / grind
    CLIFF=ramp("101113", "1e2023"),
    FOAM=hexc("8aa0a8"),
)


def apply_palettes():
    for k, v in V8_GA.items():
        setattr(ga, k, v)
    for k, v in V8_AM.items():
        setattr(am, k, v)


# ---------------------------------------------------------------- dorp-tiles (vervangers)
def flower_tile_v8():
    """Gras met papiersnippers (met binaire streepjes) en grijze steentjes."""
    im = ga.grass_tile(seed=7)
    px = im.load()
    PAPER = (hexc("cfc8b6"), hexc("a8a294"), hexc("5a564e"))
    for (x, y, w) in ((2, 3, 3), (10, 9, 3), (5, 12, 2)):
        for dx in range(w):
            px[x + dx, y] = PAPER[0]
            px[x + dx, y + 1] = PAPER[1]
        px[x + 1, y] = PAPER[2]                       # 'inkt' = binaire streepjes
        px[x, y + 2] = ga.GRASS[0]
        px[x + w - 1, y + 2] = ga.GRASS[0]
    for (x, y) in ((12, 3), (7, 6), (13, 13)):
        px[x, y] = ga.STONE[4]; px[x + 1, y] = ga.STONE[2]; px[x, y + 1] = ga.GRASS[0]
    px[14, 7] = hexc("8a9a94")                         # (neon alleen op unieke objecten)
    return im


def fence_tile_v8():
    """Smeedijzeren hekje met puntjes, op mosgras."""
    im = ga.grass_tile(seed=15)
    px = im.load()
    IRON = ramp("0c0d10", "1c1e24", "2e3138", "4a4e56", "6a6e78")
    for x in range(T):
        px[x, 14] = ga.SHADOW_GRASS
    for y0 in (5, 11):
        for x in range(T):
            px[x, y0] = IRON[3]
            px[x, y0 + 1] = IRON[1]
    for cx in (1, 5, 9, 13):
        for y in range(3, 14):
            px[cx, y] = IRON[2] if y > 3 else IRON[4]
            px[cx + 1, y] = IRON[0]
        px[cx, 2] = IRON[4]
    return im


def lowwall_tile_v8():
    """Lage natuurstenen muur: afdeksteen, onregelmatige blokken, een boekje in een nis."""
    im = ga.new_tile(am.BRICK[0])
    px = im.load()
    B = am.BRICK
    rnd = random.Random(16)
    for x in range(T):
        px[x, 0] = B[1]; px[x, 1] = B[5]; px[x, 2] = B[4]; px[x, 3] = B[2]
    for r, y0 in enumerate(range(4, 16, 4)):
        off = (0, 5, 2)[r]
        for x in range(T):
            for y in range(y0, min(T, y0 + 3)):
                if (x + off) % 7 == 6:
                    continue
                c = B[4] if y == y0 else (B[2] if y == y0 + 2 else rnd.choice((B[3], B[3], B[2])))
                px[x, y] = c
    for (x, y) in ((3, 9), (11, 6)):                  # mos in de voegen
        px[x, y] = V8_GA["LEAF"][3]; px[x + 1, y] = V8_GA["LEAF"][2]
    return im


def flowerbed_tile_v8():
    """Perk met kleine grijs-witte bloemen (geen roze meer) en een snipper papier."""
    im = ga.grass_tile(seed=17)
    px = im.load()
    rnd = random.Random(18)
    cols = [hexc("b8b8b0"), hexc("8e9488"), hexc("d4d0c4"), hexc("7a8478")]
    spots = [(2, 2), (7, 1), (12, 3), (4, 6), (10, 7), (14, 9), (1, 10), (6, 11), (11, 13), (3, 14)]
    for (x, y) in spots:
        c = rnd.choice(cols)
        for dx, dy in ((0, 0), (1, 0), (0, 1)):
            px[(x + dx) % T, (y + dy) % T] = c
        px[(x + 1) % T, (y + 1) % T] = hexc("6a6a5a")
        px[(x + 1) % T, (y + 2) % T] = ga.GRASS[0]
    return im


def lantern_tile_v8():
    """Lantaarn op een stenen sokkel (vervangt de ton): blokkeert net als de ton."""
    im = am.cobble_tile()
    px = im.load()
    am._shadow_ellipse(px, 9.5, 14.2, 5.5, 1.8, am.COBBLE[0])
    S = ga.STONE
    IRON = ramp("0c0d10", "1c1e24", "2e3138", "4a4e56")
    for y in range(10, 15):                            # sokkel
        for x in range(5, 11):
            px[x, y] = S[4] if x < 7 else (S[3] if x < 9 else S[2])
            if y == 10:
                px[x, y] = S[5]
        px[4, y] = S[1]; px[11, y] = S[1]
    for y in range(6, 10):                             # paal
        px[7, y] = IRON[3]; px[8, y] = IRON[1]
    for y in range(1, 7):                              # kap + glas
        for x in range(5, 11):
            edge = x in (5, 10) or y in (1, 6)
            if edge:
                px[x, y] = IRON[2] if x < 8 else IRON[0]
            else:
                px[x, y] = LAMP[3] if (x in (7, 8) and y in (3, 4)) else LAMP[2] if y < 5 else LAMP[1]
    px[7, 0] = IRON[3]; px[8, 0] = IRON[1]
    return im


def town_tiles_v8():
    base = am.cobble_tile()
    tiles = [am.cobble_tile()]
    tiles += [am.edge_tile(base, m, 80, am.COBBLE[0], am.COBBLE[1]) for m in range(1, 16)]
    tiles += [am.hedge_tile(), fence_tile_v8(), lowwall_tile_v8(), flowerbed_tile_v8(), lantern_tile_v8()]
    return tiles


def make_town_sheet_v8():
    ga.flower_tile = flower_tile_v8
    extra = town_tiles_v8()
    base = ga.make_tileset()
    sheet = Image.new("RGBA", (T * (33 + len(extra)), T), (0, 0, 0, 0))
    sheet.paste(base, (0, 0))
    for i, t in enumerate(extra):
        sheet.paste(t, ((33 + i) * T, 0))
    return sheet


# ---------------------------------------------------------------- het huis: kleine bibliotheek
def make_house_v8():
    """80x80 (5x5 tiles), deur op kolom 2 van de onderste rij (x 32..47) zoals v5-v7."""
    W, H = 80, 80
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    rnd = random.Random(61)
    R, P, B, G = am.ROOF, am.PLASTER, am.BEAM, am.GLASS
    S = ga.STONE
    MOSS = V8_GA["LEAF"]
    roof_bottom, ridge_y = 40, 4
    # dak: leien in rijen, schilddak-zijvlakken, mosplekken
    for y in range(ridge_y, roof_bottom + 1):
        t = (y - ridge_y) / (roof_bottom - ridge_y)
        inset = round(14 * (1 - t))
        for x in range(inset, W - inset):
            side_l = x < inset + round(10 * (1 - t)) + 2
            side_r = x >= W - inset - round(10 * (1 - t)) - 2
            row, yy = (y - ridge_y) // 4, (y - ridge_y) % 4
            off = 2 if row % 2 else 0
            c = R[1] if (yy == 3 or (x + off) % 5 == 0 and yy > 0) else (R[4] if yy == 0 else R[3])
            if side_l:
                c = {R[1]: R[2], R[4]: R[5], R[3]: R[4]}[c]
            elif side_r:
                c = {R[1]: R[0], R[4]: R[2], R[3]: R[2]}[c]
            if x in (inset, W - inset - 1):
                c = R[0]
            px[x, y] = c
    for (mx, my, n) in ((20, 34, 7), (58, 30, 5), (30, 12, 4)):            # mos
        for k in range(n):
            x, y = mx + rnd.randrange(-4, 5), my + rnd.randrange(-2, 3)
            if px[x, y][3]:
                px[x, y] = MOSS[3] if rnd.random() < 0.6 else MOSS[4]
    for x in range(14, W - 14):
        px[x, ridge_y] = R[5]; px[x, ridge_y + 1] = R[2]
    # kapotte leien rechtsboven: gat met glitch-pixels (digitaal verval)
    for (x, y) in ((60, 18), (61, 18), (62, 18), (60, 19), (61, 19), (63, 20), (59, 20)):
        px[x, y] = hexc("06080a")
    px[61, 19] = NEON_C; px[63, 20] = NEON_M
    for (x, y) in ((22, 22), (23, 22), (25, 22)):                         # binaire splinter
        px[x, y] = R[5]
    for y in range(roof_bottom - 1, roof_bottom + 2):                      # goot (steen)
        for x in range(W):
            px[x, y] = S[1] if y > roof_bottom - 1 else S[4]
    # stenen schoorsteen = klein klokkentorentje
    for y in range(0, 16):
        for x in range(56, 63):
            c = S[4] if x < 59 else S[2]
            if y % 4 == 3 or x in (56, 62):
                c = S[1]
            px[x, y] = c
    for x in range(55, 64):
        px[x, 0] = S[5]; px[x, 1] = S[1]
    # dakkapel met roosvenster (rond, cyaan glinstering)
    cx = 40
    for y in range(12, 34):
        half = min(10, (y - 12) * 0.75 + 1)
        for x in range(int(cx - half), int(cx + half) + 1):
            edge = abs(x + 0.5 - cx) > half - 2
            px[x, y] = R[0] if edge else (P[4] if x < cx else P[3])
    for y in range(19, 32):
        for x in range(34, 47):
            d = ((x + 0.5 - 40.5) ** 2 + (y + 0.5 - 25.5) ** 2) ** 0.5
            if d < 6.2:
                c = B[1] if d > 5.0 else (G[1] if (x + y) % 3 else G[2])
                if d < 5 and (x == 40 or y == 25):
                    c = B[2]
                if d < 1.2:
                    c = G[3]
                px[x, y] = c
    px[38, 23] = NEON_C
    for y in range(31, 35):
        for x in range(30, 51):
            px[x, y] = R[1] if y == 31 else R[2]
    # gevel: natuursteen in verband
    wall_top = roof_bottom + 2
    for y in range(wall_top, H):
        for x in range(W):
            row = (y - wall_top) // 5
            off = 6 if row % 2 else 0
            yy = (y - wall_top) % 5
            if yy == 4 or (x + off) % 12 == 0:
                c = P[1]
            else:
                n = rnd.random()
                c = P[3] if n < 0.7 else (P[4] if n < 0.85 else P[2])
                if yy == 0:
                    c = P[4]
            if x > W - 5:
                c = P[2] if c != P[1] else P[0]
            px[x, y] = c
    for x in range(W):
        px[x, wall_top] = P[0]; px[x, wall_top + 1] = P[1]
    for (x0, x1) in ((0, 3), (24, 27), (52, 55), (76, 80)):               # pilasters
        for y in range(wall_top, H - 5):
            for x in range(x0, x1):
                px[x, y] = P[5] if x == x0 else (P[4] if x == x0 + 1 else P[2])
    for x in range(W):                                                     # kroonlijst
        px[x, 58] = P[5]; px[x, 59] = P[2]; px[x, 60] = P[0]
    # hoge boogramen met boekenkasten erachter
    SPINES = [hexc("5a2a26"), hexc("2e4a3a"), hexc("6a5a3a"), hexc("3a3e56"), hexc("7a6a4e"), hexc("4a2e3a")]
    for wx in (7, 59):
        for y in range(44, 58):
            for x in range(wx, wx + 14):
                rel = x - wx
                arch = y < 48 and ((rel + 0.5 - 7) ** 2 + ((y - 48) * 1.4) ** 2) ** 0.5 > 6.6
                if arch:
                    continue
                if rel in (0, 13) or y == 57:
                    c = S[4] if rel == 0 else S[1]
                elif ((rel + 0.5 - 7) ** 2 + ((y - 48) * 1.4) ** 2) ** 0.5 > 5.6 and y < 48:
                    c = S[3]
                else:
                    shelf = (y - 44) % 5
                    if shelf == 4:
                        c = B[2]                                            # plank
                    else:
                        c = SPINES[(rel * 7 + (y // 5) * 3) % len(SPINES)]
                        if shelf == 0:
                            c = G[0]
                    if rel == 7:
                        c = B[1]                                            # roede
                px[x, y] = c
        px[wx + 3, 50] = G[3]                                              # glinstering
    # deur: boogdeur met ijzerbeslag (x 32..47, onderste rij)
    for y in range(60, H - 3):
        for x in range(32, 48):
            rel = x - 32
            top = 63 if 4 <= rel <= 11 else (64 if 2 <= rel <= 13 else 66)
            if y < top - 3:
                continue
            if y < top - 1:
                c = S[5]                                                    # stenen boog
            elif rel in (0, 1, 14, 15):
                c = S[2] if rel in (1, 14) else S[1]
            else:
                c = ga.WOOD[3] if rel % 4 != 1 else ga.WOOD[1]
                if rel > 11:
                    c = ga.WOOD[2]
                if y in (67, 73) and 2 <= rel <= 13:
                    c = hexc("2e3138")                                      # ijzeren band
                if rel == 11 and y == 70:
                    c = LAMP[2]
            px[x, y] = c
    # lantaarns naast de deur
    for lx in (27, 50):
        for y in range(62, 68):
            for x in range(lx, lx + 3):
                c = LAMP[2] if y in (63, 64, 65) else hexc("1c1e24")
                if x == lx + 1 and y == 64:
                    c = LAMP[3]
                px[x, y] = c
        px[lx + 1, 61] = hexc("1c1e24")
    # klimop links
    for (x, y) in ((1, 44), (2, 45), (1, 46), (3, 47), (2, 49), (1, 50), (4, 50), (2, 52), (3, 54), (1, 55)):
        px[x, y] = MOSS[3]; px[x + 1, y] = MOSS[2]
    # binaire inscriptie op de kroonlijst boven de deur
    for i, bit in enumerate("10110"):
        x = 35 + i * 2
        px[x, 59] = P[0]
        if bit == "1":
            px[x, 58] = P[1]
    # stenen plint + traptree
    for y in range(H - 5, H):
        for x in range(W):
            c = S[3] if (x // 6 + (y > H - 3)) % 2 else S[4]
            if y == H - 5:
                c = S[5]
            if y == H - 1:
                c = S[1]
            if (x + (3 if y > H - 3 else 0)) % 6 == 5:
                c = S[1]
            px[x, y] = c
    for y in range(H - 3, H):
        for x in range(32, 48):
            px[x, y] = S[5] if y == H - 3 else S[3]
    return im


# ---------------------------------------------------------------- wereldkaart
def town_icon_v8():
    """Stad op de wereldkaart (2 tiles): bibliotheek met zuilen + fronton en een half
    ingestort torentje. Lichte steen tegen een donker interieur = leesbaar op een telefoon."""
    im = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    im.paste(am.world_grass(seed=8), (0, 0)); im.paste(am.world_grass(seed=9), (16, 0))
    px = im.load()
    OUT = hexc("0a0b0d")
    ST = ramp("2a2c30", "4a4d52", "70737a", "9a9ca2", "c2c3c6", "e2e2e0")
    DARK = hexc("101418")
    for x in range(2, 23):
        px[x, 15] = am.WG[0]                                 # schaduw
    # fronton (driehoek) y 2..5
    for y in range(2, 6):
        half = (y - 1) * 3
        for x in range(12 - half, 13 + half):
            if 1 <= x <= 22:
                c = ST[4] if x < 12 else ST[3]
                if y == 5 or abs(x - 12) >= half - 1:
                    c = OUT if y < 5 else ST[2]
                px[x, y] = c
    px[12, 3] = NEON_C                                       # roosvenstertje
    # architraaf
    for x in range(1, 24):
        px[x, 6] = ST[5] if x < 12 else ST[4]
        px[x, 7] = ST[2]
    # zuilen + donker interieur met boeken
    for y in range(8, 13):
        for x in range(2, 23):
            col = (x - 2) % 5 in (0, 1)
            if col:
                c = ST[4] if (x - 2) % 5 == 0 else ST[2]
            else:
                c = DARK
                if y in (9, 11) and x % 2:
                    c = (hexc("4a2c26"), hexc("2c4434"), hexc("5a4e34"))[x % 3]   # boekruggen
            px[x, y] = c
    for x in range(1, 24):                                   # traptreden
        px[x, 13] = ST[5] if x < 12 else ST[3]
        px[x, 14] = ST[2]
    # torentje rechts (half ingestort)
    for y in range(3, 15):
        for x in range(25, 30):
            if y < 6 and x > 27:
                continue
            c = ST[3] if x < 27 else ST[1]
            if y % 3 == 0:
                c = ST[2]
            if x in (25, 29) or y in (3,):
                c = OUT
            px[x, y] = c
    px[26, 8] = LAMP[2]                                      # licht achter het raam
    px[28, 4] = NEON_M                                       # glitch
    px[30, 2] = NEON_C
    px[29, 5] = OUT
    return im


def ruin_fill_v8(seed):
    """Lichte vlakken = overwoekerde plavuizen van een verdwenen academie-plein."""
    im = am.tile(am.WL[2])
    px = im.load()
    rnd = random.Random(seed)
    L = am.WL
    for y in range(T):
        for x in range(T):
            c = L[3] if rnd.random() < 0.7 else L[2]
            if x % 8 == 7 or y % 8 == 7:
                c = L[0] if rnd.random() < 0.8 else am.WG[3]      # voeg (soms mos)
            elif x % 8 == 0 or y % 8 == 0:
                c = L[4]
            px[x, y] = c
    px[3, 3] = L[5]; px[11, 12] = L[1]; px[12, 4] = am.WG[4]; px[4, 11] = am.WG[4]
    return im


def ash_fill_v8(seed):
    """Zandvlakken = as en grind met wat puin."""
    im = am.tile(am.SAND[3])
    px = im.load()
    rnd = random.Random(seed)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < 0.2:
                px[x, y] = am.SAND[2]
            elif r < 0.3:
                px[x, y] = am.SAND[4]
    for (x, y) in ((4, 5), (11, 10)) if seed % 2 else ((9, 4),):     # puin-steentjes
        px[x, y] = am.SAND[5]; px[x + 1, y] = am.SAND[4]
        px[x, y + 1] = am.SAND[1]; px[x + 1, y + 1] = am.SAND[0]
    return im


def make_world_sheet_v8():
    am.town_icon = town_icon_v8
    am.light_grass_fill = ruin_fill_v8
    am.sand_fill = ash_fill_v8
    return am.make_world_sheet()


# ---------------------------------------------------------------- figuren
PLAYER_BODY_BACK = [
    "...oyyyyyyyYo...",
    "..oLLLLLLLLCCo..",
    ".oLLLLLgLLLCCCo.",
    ".osLLLLLLLLLCso.",
    ".ooLLLLLLLLCCoo.",
]
PLAYER_PAL_V8 = dict(ga.SKIN, **{
    "o": hexc("0c0b0b"), "h": hexc("4a3426"), "H": hexc("6e5038"), "d": hexc("2a1d15"),
    "y": hexc("9aa0a8"), "Y": hexc("5e636c"),                              # grijze kraag / schouderstuk
    "c": hexc("6e4a2e"), "C": hexc("1c1d22"), "L": hexc("33353c"),         # leer + antraciet cape
    "b": hexc("2e1c12"), "p": hexc("2c2a30"), "P": hexc("1c1b20"), "k": hexc("4a2e1a"),
    "g": hexc("b08434"),                                                   # bronzen embleem
    ",": ga.SHADOW_PX,
})
NPC_PAL_V8 = dict(ga.SKIN, **{
    "o": hexc("0e100e"), "h": hexc("9a9c96"), "H": hexc("cfd0ca"), "d": hexc("5e605a"),
    "y": hexc("d4c8a8"), "Y": hexc("9c9078"),                              # perkamenten kraag
    "c": hexc("4a5a4c"), "C": hexc("2e3a30"), "L": hexc("6a7a6a"),         # grijsgroene geleerdenmantel
    "b": hexc("b08434"), "p": hexc("2e3a30"), "P": hexc("1e2820"), "k": hexc("2e221a"),
    ",": ga.SHADOW_PX,
})


def make_player_v8():
    old = ga.BODY_BACK
    ga.BODY_BACK = PLAYER_BODY_BACK
    try:
        return ga.make_character(PLAYER_PAL_V8)
    finally:
        ga.BODY_BACK = old


def make_npc_v8():
    return ga.make_character(NPC_PAL_V8, "robe")


def save_all(root):
    apply_palettes()
    tiles_dir = os.path.join(root, "assets", "tiles")
    spr_dir = os.path.join(root, "assets", "sprites")
    make_town_sheet_v8().save(os.path.join(tiles_dir, "dorp.png"))
    make_house_v8().save(os.path.join(tiles_dir, "huis.png"))
    make_world_sheet_v8().save(os.path.join(tiles_dir, "wereld.png"))
    player = make_player_v8()
    player.save(os.path.join(spr_dir, "player.png"))
    make_npc_v8().save(os.path.join(spr_dir, "npc.png"))
    ga.make_sign().save(os.path.join(spr_dir, "sign.png"))
    # project-icoon: Dennis op mosgras
    icon = ga.make_tileset().crop((0, 0, 16, 16))
    icon.alpha_composite(player.crop((0, 0, 16, 24)).crop((0, 2, 16, 18)))
    icon.resize((128, 128), Image.NEAREST).save(os.path.join(root, "icon.png"))


if __name__ == "__main__":
    save_all(ga.ROOT)
    print("v8 map-art gegenereerd")
