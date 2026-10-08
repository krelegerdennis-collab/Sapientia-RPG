"""
Map-art voor v5 (eigen werk): extra dorp-tiles, het huis en de wereldkaart-tiles.
Wordt aangeroepen door generate_art.py (python3 tools/generate_art.py).

Output:
  assets/tiles/dorp.png    tiles van 16x16 op één rij (0..32 = de v3-tiles, daarna nieuw):
        33 kassei (keien), 34..48 kassei met grasrand (masker N1 E2 S4 W8),
        49 heg*, 50 hek*, 51 lage muur*, 52 bloemenperk, 53 ton*     (* = blokkeert)
  assets/tiles/huis.png    80x80 = 5x5 tiles: één huis (dak, vakwerk, ramen, deur)
  assets/tiles/wereld.png  256x144 = raster van 16 kolommen x 9 rijen (zie W_*):
        0..1 gras (2 varianten), 2..17 licht gras, 18..33 zand, 34..49 bos,
        50..65 berg*, 66..112 zee* met kust (47 varianten), 113..114 stad, 115 trap,
        116..131 berg* variant B (de builder wisselt A/B af als een dambord)
        (de 16 varianten per terrein: masker = welke buren hetzelfde terrein zijn,
         N=1 E=2 S=4 W=8; de zee gebruikt ook de hoeken, zie sea_masks())
  assets/battle/backdrop_vlakte.png  640x160  gevechtsachtergrond voor vlakte/zand
"""
import math
import os
import random
from PIL import Image

import generate_art as ga

T = 16
hexc, ramp = ga.hexc, ga.ramp

# ---------------------------------------------------------------- paletten
COBBLE = ramp("262a36", "383e4c", "4a5060", "5c6274", "70778a", "8a90a2")   # blauwgrijze keien
BRICK = ramp("3a2418", "5a3a26", "7a5034", "946644", "ae7e58", "c8a07a")    # baksteen lage muur
ROOF = ramp("281a34", "3e2a4e", "54386a", "6c4a86", "8662a0", "a282ba")     # paars leien dak
PLASTER = ramp("8e7c5c", "aa9672", "c4b08a", "d8c8a2", "e8dcbc", "f4eed8")  # vakwerk-wand
BEAM = ramp("2a1a10", "422a18", "5a3a22")                                   # donkere balken
GLASS = ramp("10142a", "1c2442", "2e3c64", "6a86b4")                        # ramen
# Wereldkaart: iets groener/verzadigder dan het dorp, zoals in de referentie.
WG = ramp("1c4416", "28581c", "336a24", "3e7a2a", "4f8c36", "68a046")     # vlakte
WL = ramp("466e1e", "5a8426", "6e9830", "86ae3c", "a0c24e", "bcd66a")     # licht gras
FOREST = ramp("061208", "0a1e0e", "102c14", "183a1a", "224c22", "346230")  # bos
MOUNT = ramp("3e3228", "625040", "8a7660", "ae9c84", "ccbea4", "e6dcc6")  # rotsheuvels (bleek beige)
SEA = ramp("0c1452", "121e6a", "1a2a84", "24389c", "3a52b4", "7890d8")    # diepe zee
SAND = ramp("6a4a26", "8a6234", "a47a42", "ba9254", "cca866", "dec282")
CLIFF = ramp("2a1c12", "4a3420")                                          # kustrand
FOAM = hexc("d6e0fa")


def tile(color=(0, 0, 0, 0)):
    return Image.new("RGBA", (T, T), color)


def jitter(t, phase=0.0):
    """Periodieke 'ruis' met periode 16, zodat randen naadloos doorlopen over tiles."""
    return 0.9 * math.sin(2 * math.pi * t / 8 + 0.7 + phase) + 0.6 * math.sin(2 * math.pi * t / 16 + 2.1 + phase)


# ================================================================ DORP
def cobble_tile():
    """Keien: onregelmatige ronde stenen in rijen, licht linksboven, donkere voegen."""
    im = tile(COBBLE[0])
    px = im.load()
    rnd = random.Random(41)
    y = 0
    row = 0
    while y < T:
        h = 4 if row % 2 == 0 else 4
        x = rnd.randrange(0, 4) if row % 2 else 0
        start = x
        widths = []
        while sum(widths) < T:
            widths.append(rnd.choice((4, 5, 5, 6)))
        widths[-1] -= sum(widths) - T                 # precies 16 breed (tileable)
        for w in widths:
            for yy in range(y, min(T, y + h - 1)):
                for xx in range(x, x + w - 1):
                    X = xx % T
                    top = yy == y
                    left = xx == x
                    bottom = yy == y + h - 2
                    right = xx == x + w - 2
                    if (top and left) or (bottom and right) or (top and right) or (bottom and left):
                        c = COBBLE[1]                 # afgeronde hoekjes
                    elif top or left:
                        c = COBBLE[4]
                    elif bottom or right:
                        c = COBBLE[2]
                    else:
                        c = rnd.choice((COBBLE[3], COBBLE[3], COBBLE[2], COBBLE[4]))
                    px[X, yy] = c
            x += w
        y += h
        row += 1
    for _ in range(5):
        px[rnd.randrange(T), rnd.randrange(T)] = COBBLE[5]
    return im


def edge_tile(base, mask, seed, dark, mid):
    """Grasrand over een ondergrond (zelfde idee als het pad in v3)."""
    im = base.copy()
    px = im.load()
    grass = ga.grass_tile(seed=2).load()
    rnd = random.Random(seed + mask)
    for bit, side in ((1, "N"), (2, "E"), (4, "S"), (8, "W")):
        if not mask & bit:
            continue
        tuft = [rnd.choice((2, 2, 3, 3, 4)) for _ in range(T)]
        for (x, y, d) in ga._side_coords(side, 6):
            i = x if side in "NS" else y
            if d < tuft[i] - 1:
                px[x, y] = grass[x, y]
            elif d == tuft[i] - 1:
                px[x, y] = ga.GRASS[0] if side in "SE" else ga.GRASS[1]
            elif d == tuft[i]:
                px[x, y] = dark if side in "NW" else mid
    return im


def _shadow_ellipse(px, cx, cy, rx, ry, color):
    for y in range(T):
        for x in range(T):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                px[x, y] = color


def hedge_tile():
    """Ronde heg/struik: bladclusters, licht linksboven, schaduw rechtsonder."""
    im = ga.grass_tile(seed=13)
    px = im.load()
    _shadow_ellipse(px, 9.5, 13.5, 7, 2.6, ga.SHADOW_GRASS)
    rnd = random.Random(14)
    L = ga.LEAF
    for y in range(T):
        for x in range(T):
            dx, dy = (x + 0.5 - 8) / 7.2, (y + 0.5 - 7.6) / 6.6
            d = dx * dx + dy * dy
            if d <= 1:
                lit = -dx - dy
                if d > 0.8:
                    c = L[0] if lit < 0.3 else L[1]
                elif lit > 0.8:
                    c = L[5]
                elif lit > 0.2:
                    c = L[4]
                elif lit > -0.5:
                    c = L[3]
                else:
                    c = L[2]
                px[x, y] = c
    for _ in range(14):                       # blaadjes-textuur
        x, y = rnd.randrange(2, 14), rnd.randrange(2, 13)
        if px[x, y] in (L[3], L[4]):
            px[x, y] = L[5] if rnd.random() < 0.5 else L[2]
    return im


def fence_tile():
    """Houten hek (horizontaal): paaltjes met 2 latten, schaduw op het gras."""
    im = ga.grass_tile(seed=15)
    px = im.load()
    W = ga.WOOD
    for x in range(T):
        px[x, 14] = ga.SHADOW_GRASS
        px[x, 13] = ga.SHADOW_GRASS if x % 8 in (2, 3, 4) else px[x, 13]
    for y0 in (6, 10):                        # latten
        for x in range(T):
            px[x, y0] = W[4]
            px[x, y0 + 1] = W[2]
            px[x, y0 + 2] = W[0] if y0 == 10 else W[1]
    for cx in (3, 11):                        # paaltjes
        for y in range(3, 14):
            px[cx - 1, y] = W[3]
            px[cx, y] = W[2]
            px[cx + 1, y] = W[1]
        px[cx - 1, 3] = W[5]; px[cx, 3] = W[4]; px[cx + 1, 3] = W[2]
        px[cx - 1, 2] = W[0]; px[cx, 2] = W[0]; px[cx + 1, 2] = W[0]
    return im


def lowwall_tile():
    """Lage bakstenen muur (van voren gezien): afdeksteen boven, stenen in verband."""
    im = tile(BRICK[0])
    px = im.load()
    rnd = random.Random(16)
    for x in range(T):                        # afdeklaag
        px[x, 0] = BRICK[1]
        px[x, 1] = BRICK[5]
        px[x, 2] = BRICK[4]
        px[x, 3] = BRICK[2]
    for r, y0 in enumerate(range(4, 16, 4)):
        off = 0 if r % 2 == 0 else 4
        for x in range(T):
            for y in range(y0, min(T, y0 + 3)):
                if (x + off) % 8 == 7:
                    continue                  # voeg
                if y == y0:
                    c = BRICK[4]
                elif y == y0 + 2:
                    c = BRICK[2]
                else:
                    c = rnd.choice((BRICK[3], BRICK[3], BRICK[2]))
                px[x, y] = c
    return im


def flowerbed_tile():
    """Bloemenperk: dichte witte en roze bloemetjes op gras (zoals in dorpen)."""
    im = ga.grass_tile(seed=17)
    px = im.load()
    rnd = random.Random(18)
    cols = [hexc("f0ecf4"), hexc("e0a8c8"), hexc("f0ecf4"), hexc("c87ab0")]
    spots = [(2, 2), (7, 1), (12, 3), (4, 6), (10, 7), (14, 9), (1, 10), (6, 11), (11, 13), (3, 14)]
    for (x, y) in spots:
        c = rnd.choice(cols)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            px[(x + dx) % T, (y + dy) % T] = c
        px[(x + 1) % T, (y + 1) % T] = hexc("e9c04a")       # hartje
        px[(x + 1) % T, (y + 2) % T] = ga.GRASS[0]
        px[(x + 2) % T, (y + 2) % T] = ga.GRASS[1]
    return im


def barrel_tile():
    """Houten ton op gras/keien: duigen met 2 metalen banden."""
    im = cobble_tile()
    px = im.load()
    _shadow_ellipse(px, 9.5, 14, 6.5, 2.2, COBBLE[0])
    W = ga.WOOD
    for y in range(2, 15):
        half = 5.5 - abs(y - 8.5) * 0.12
        for x in range(T):
            dx = x + 0.5 - 8
            if abs(dx) <= half:
                if y in (2, 3):
                    c = W[1] if abs(dx) > half - 1.2 else (W[4] if y == 2 else W[2])   # deksel
                elif y in (5, 11):
                    c = ga.STONE[4] if dx < 0 else ga.STONE[2]                         # band
                elif y in (6, 12):
                    c = ga.STONE[1]
                else:
                    c = W[4] if dx < -2.5 else (W[3] if dx < 1 else (W[2] if dx < 3.5 else W[1]))
                    if int(dx + 8) % 3 == 0:
                        c = W[1]
                if abs(dx) > half - 0.8:
                    c = W[0]
                px[x, y] = c
    return im


def town_tiles():
    tiles = [cobble_tile()]
    base = cobble_tile()
    tiles += [edge_tile(base, m, 80, COBBLE[0], COBBLE[1]) for m in range(1, 16)]
    tiles += [hedge_tile(), fence_tile(), lowwall_tile(), flowerbed_tile(), barrel_tile()]
    return tiles


def make_town_sheet():
    tiles = [ga.make_tileset()]
    extra = town_tiles()
    sheet = Image.new("RGBA", (T * (33 + len(extra)), T), (0, 0, 0, 0))
    sheet.paste(ga.make_tileset(), (0, 0))
    for i, t in enumerate(extra):
        sheet.paste(t, ((33 + i) * T, 0))
    return sheet


# ---------------------------------------------------------------- huis (5x5 tiles)
def make_house():
    """Eigen huis van 80x80: paars leien schilddak met dakkapel, vakwerkgevel,
    twee ramen met luiken, houten deur in het midden onderaan, stenen plint."""
    W, H = 80, 80
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    rnd = random.Random(60)
    roof_bottom = 40                      # onderkant dakrand (dakgoot)
    ridge_y = 4
    # --- dak: trapezium, linker schuinte licht, rechter schuinte donker
    for y in range(ridge_y, roof_bottom + 1):
        t = (y - ridge_y) / (roof_bottom - ridge_y)
        inset = round(14 * (1 - t))
        for x in range(inset, W - inset):
            # schaduw-band naar de hoeken (schilddak-zijvlakken)
            side_l = x < inset + round(10 * (1 - t)) + 2
            side_r = x >= W - inset - round(10 * (1 - t)) - 2
            row = (y - ridge_y) // 4
            yy = (y - ridge_y) % 4
            off = 3 if row % 2 else 0
            scallop = (x + off) % 6
            if yy == 3 or (yy == 2 and scallop in (0, 5)):
                c = ROOF[1]                               # schaduw onder elke leirij
            elif yy == 0 and scallop in (1, 2, 3):
                c = ROOF[4]                               # lichte bovenkant van de leien
            else:
                c = ROOF[3]
            if side_l:
                c = {ROOF[1]: ROOF[2], ROOF[4]: ROOF[5], ROOF[3]: ROOF[4]}[c]
            elif side_r:
                c = {ROOF[1]: ROOF[0], ROOF[4]: ROOF[2], ROOF[3]: ROOF[2]}[c]
            if x == inset or x == W - inset - 1:
                c = ROOF[0]
            px[x, y] = c
    for x in range(14, W - 14):                           # nok
        px[x, ridge_y] = ROOF[5]
        px[x, ridge_y + 1] = ROOF[2]
    for y in range(roof_bottom - 1, roof_bottom + 2):     # dakgoot
        for x in range(W):
            px[x, y] = ROOF[0] if y > roof_bottom - 1 else ROOF[2]
    # --- schoorsteen rechts
    for y in range(0, 16):
        for x in range(56, 63):
            c = BRICK[3] if x < 59 else BRICK[2]
            if (y % 4 == 3) or (x == 59 and y % 8 < 4):
                c = BRICK[1]
            if x in (56, 62):
                c = BRICK[0]
            px[x, y] = c
    for x in range(55, 64):
        px[x, 0] = BRICK[5]; px[x, 1] = BRICK[1]
    # --- dakkapel in het midden (klein puntgeveltje met raam)
    cx = 40
    for y in range(12, 34):
        half = min(10, (y - 12) * 0.75 + 1)
        for x in range(int(cx - half), int(cx + half) + 1):
            edge = abs(x + 0.5 - cx) > half - 2
            px[x, y] = ROOF[0] if edge else (PLASTER[4] if x < cx else PLASTER[3])
    for y in range(20, 31):
        for x in range(35, 46):
            c = GLASS[1]
            if x in (35, 45) or y in (20, 30):
                c = BEAM[1]
            elif x == 40 or y == 25:
                c = BEAM[2]
            elif (x - 36) + (y - 21) < 3:
                c = GLASS[3]
            px[x, y] = c
    for y in range(31, 35):
        for x in range(30, 51):
            px[x, y] = ROOF[1] if y == 31 else ROOF[2]
    # --- gevel (vakwerk)
    wall_top = roof_bottom + 2
    for y in range(wall_top, H):
        for x in range(W):
            n = rnd.random()
            c = PLASTER[3] if n < 0.75 else (PLASTER[4] if n < 0.9 else PLASTER[2])
            if x > W - 5:
                c = PLASTER[2]
            px[x, y] = c
    for x in range(W):                                    # schaduw van het dak
        px[x, wall_top] = PLASTER[0]; px[x, wall_top + 1] = PLASTER[1]
    for (x0, x1) in ((0, 3), (24, 27), (52, 55), (76, 80)):   # staanders
        for y in range(wall_top, H - 5):
            for x in range(x0, x1):
                px[x, y] = BEAM[2] if x == x0 else BEAM[1]
    for y0 in (wall_top + 2, 58):                         # regels
        for x in range(W):
            px[x, y0] = BEAM[2]; px[x, y0 + 1] = BEAM[1]; px[x, y0 + 2] = BEAM[0]
    for (xa, xb) in ((3, 24), (55, 76)):                  # schoren (diagonaal) onder de ramen
        for i in range(xb - xa):
            y = 61 + i * 13 // (xb - xa)
            for x in (xa + i, xa + i + 1):
                if x < xb and y < H - 5:
                    px[x, y] = BEAM[1]
    # ramen met luiken
    for wx in (7, 59):
        for y in range(46, 57):
            for x in range(wx, wx + 14):
                rel = x - wx
                if rel < 2 or rel > 11:
                    c = hexc("3a5a3a") if rel in (0, 13) else hexc("4e7448")   # groene luiken
                    if y % 3 == 0:
                        c = hexc("2e4a2e")
                else:
                    c = GLASS[1]
                    if rel in (2, 11) or y in (46, 56):
                        c = BEAM[1]
                    elif rel == 7 or y == 51:
                        c = BEAM[2]
                    elif (rel - 3) + (y - 47) < 3:
                        c = GLASS[3]
                    elif rel > 8 and y > 52:
                        c = GLASS[2]
                px[x, y] = c
        for x in range(wx + 1, wx + 13):                  # vensterbank
            px[x, 57] = PLASTER[5]
    # deur (tile kolom 2 = x 32..47, onderste rij)
    for y in range(58, H - 3):
        for x in range(32, 48):
            rel = x - 32
            top = 61 if 4 <= rel <= 11 else (62 if 2 <= rel <= 13 else 64)
            if y < top - 3:
                continue
            if y < top - 1:
                c = PLASTER[1]                            # boogje
            elif rel in (0, 1, 14, 15) or y == top - 1:
                c = BEAM[1]                               # kozijn
            else:
                c = ga.WOOD[3] if rel % 4 != 1 else ga.WOOD[1]
                if rel < 4:
                    c = ga.WOOD[4] if rel % 4 != 1 else ga.WOOD[2]
                if rel > 11:
                    c = ga.WOOD[2]
                if rel == 11 and y == 70:
                    c = hexc("e9c04a")                    # deurklink
            px[x, y] = c
    # stenen plint + traptree
    for y in range(H - 5, H):
        for x in range(W):
            c = ga.STONE[3] if (x // 6 + (y > H - 3)) % 2 else ga.STONE[4]
            if y == H - 5:
                c = ga.STONE[5]
            if y == H - 1:
                c = ga.STONE[1]
            if (x + (3 if y > H - 3 else 0)) % 6 == 5:
                c = ga.STONE[1]
            px[x, y] = c
    for y in range(H - 3, H):
        for x in range(32, 48):
            px[x, y] = ga.STONE[5] if y == H - 3 else ga.STONE[3]
    return im


# ================================================================ WERELDKAART
WORLD_COLS = 16
W_GRASS, W_LIGHT, W_SAND, W_FOREST, W_MOUNT, W_SEA = 0, 2, 18, 34, 50, 66
W_TOWN, W_STAIRS = 113, 115
W_MOUNT_B = 116          # 116..131: tweede berg-variant (dambordpatroon)
W_COUNT = 132
DIRS = {1: (0, -1), 2: (1, 0), 4: (0, 1), 8: (-1, 0)}


def sea_masks():
    """De 47 kust-maskers (zelfde volgorde als in tools/build_maps.gd):
    bits N1 E2 S4 W8 = land aan die kant, NE16 SE32 SW64 NW128 = land op die hoek.
    Een hoek telt alleen als de twee zijkanten ernaast water zijn."""
    out = []
    for m in range(256):
        r = m
        for corner, a, b in ((16, 1, 2), (32, 2, 4), (64, 4, 8), (128, 8, 1)):
            if (m & a) or (m & b):
                r &= ~corner
        if r == m:
            out.append(m)
    return out


def world_grass(seed):
    im = tile(WG[3])
    px = im.load()
    rnd = random.Random(seed)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < 0.16:
                px[x, y] = WG[2]
            elif r < 0.26:
                px[x, y] = WG[4]
    for _ in range(5):                                  # korte halmpjes
        x, y = rnd.randrange(T), rnd.randrange(1, T)
        px[x, y] = WG[5]; px[x, y - 1] = WG[4]
        px[x, (y + 1) % T] = WG[1]
    return im


def light_grass_fill(seed):
    """Licht, hoog gras met verticale halmen (zoals de lichte vlakken in de referentie)."""
    im = tile(WL[3])
    px = im.load()
    rnd = random.Random(seed)
    for x in range(T):
        y = rnd.randrange(T)
        for _ in range(3):
            n = rnd.choice((2, 3, 3, 4))
            c = rnd.choice((WL[4], WL[4], WL[2], WL[5]))
            for k in range(n):
                px[x, (y + k) % T] = c
            px[x, (y + n) % T] = WL[1]
            y = (y + n + rnd.randrange(1, 4)) % T
    return im


def sand_fill(seed):
    im = tile(SAND[3])
    px = im.load()
    rnd = random.Random(seed)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < 0.22:
                px[x, y] = SAND[2]
            elif r < 0.36:
                px[x, y] = SAND[4]
            elif r < 0.40:
                px[x, y] = SAND[1]
    return im


def _inside_patch(x, y, mask, margin=2.0):
    """Ligt pixel (x, y) binnen een vlek, gegeven welke buren hetzelfde zijn?
    Rafelige rand met jitter(); hoeken worden rond als beide zijkanten anders zijn."""
    cx, cy = x + 0.5, y + 0.5
    dist = {1: cy, 2: T - cx, 4: T - cy, 8: cx}
    along = {1: x, 2: y, 4: x, 8: y}
    for bit in (1, 2, 4, 8):
        if not mask & bit and dist[bit] < margin + 1.2 + jitter(along[bit], bit) * 0.9:
            return False, 0
    for a, b, (kx, ky) in ((1, 2, (T, 0)), (2, 4, (T, T)), (4, 8, (0, T)), (8, 1, (0, 0))):
        if not mask & a and not mask & b:
            if math.hypot(cx - kx, cy - ky) < margin + 5.5:
                return False, 0
    edge = min([dist[b] for b in (1, 2, 4, 8) if not mask & b] + [99])
    return True, edge


def patch_tile(mask, fill, rim_dark, rim_light, seed):
    im = world_grass(seed=3)
    px = im.load()
    f = fill.load()
    for y in range(T):
        for x in range(T):
            ok, edge = _inside_patch(x, y, mask)
            if ok:
                c = f[x, y]
                if edge < 4.2:
                    c = rim_dark if (x + y) % 3 else c       # zachte, donkere rand
                px[x, y] = c
    return im


def _crown_list(mask):
    """Boomkruinen op een verspringend raster van 8 px (zoals een dicht bladerdak).
    Kruinen op de tilegrens (x=0 en x=16) alleen als daar ook bos is, anders zou
    de kruin plat worden afgesneden."""
    crowns = [(4.0, 4.4), (12.0, 4.4), (8.0, 11.9)]
    if mask & 8:
        crowns.append((0.0, 11.9))
    if mask & 2:
        crowns.append((16.0, 11.9))
    if mask & 1:
        crowns += [(0.0, -4.1), (8.0, -4.1), (16.0, -4.1)]
    crowns.sort(key=lambda c: c[1])
    return crowns


def forest_tile(mask):
    im = world_grass(seed=5)
    px = im.load()
    for y in range(T):                                       # donkere bosgrond
        for x in range(T):
            ok, _ = _inside_patch(x, y, mask, margin=0.6)
            if ok:
                px[x, y] = FOREST[0]
    crowns = _crown_list(mask)
    r = 4.25
    for (ccx, ccy) in crowns:                                # schaduw rechtsonder
        for y in range(T):
            for x in range(T):
                if math.hypot(x + 0.5 - ccx - 1.0, y + 0.5 - ccy - 1.5) < r:
                    px[x, y] = FOREST[0]
    for (ccx, ccy) in crowns:                                # kruinen, van achter naar voren
        for y in range(T):
            for x in range(T):
                dx, dy = x + 0.5 - ccx, y + 0.5 - ccy
                d = math.hypot(dx, dy) / r
                if d < 1:
                    lit = -(dx + dy) / r
                    if d > 0.8:
                        c = FOREST[1] if lit > -0.3 else FOREST[0]
                    elif lit > 0.6:
                        c = FOREST[5] if (x + y) % 2 else FOREST[4]
                    elif lit > 0.1:
                        c = FOREST[4] if (x * 3 + y) % 4 else FOREST[3]
                    elif lit > -0.5:
                        c = FOREST[3] if (x + y * 2) % 5 else FOREST[2]
                    else:
                        c = FOREST[2]
                    px[x, y] = c
    return im


def _mound(px, cx, cy, rx, ry, seed):
    """Eén rotsheuvel (puntig bovenaan, licht van linksboven, donkere onderrand).
    Alleen pixels binnen de tile worden getekend; een heuvel op de tilegrens wordt
    door de buurtile afgemaakt (zelfde middelpunt), zo ontstaat één doorlopende keten."""
    rnd = random.Random(seed)
    for y in range(T):
        for x in range(T):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            dyy = dy if dy > 0 else dy * (1.0 + 0.65 * abs(dx))      # puntige top
            d = dx * dx + dyy * dyy
            if d >= 1:
                continue
            lit = -dx * 0.85 - dy * 0.9
            if d > 0.78 and dy > -0.2:
                c = MOUNT[0] if lit < 0.0 else MOUNT[1]                # donkere voet/rand
            elif lit > 0.75:
                c = MOUNT[5]
            elif lit > 0.25:
                c = MOUNT[4]
            elif lit > -0.3:
                c = MOUNT[3]
            elif lit > -0.75:
                c = MOUNT[2]
            else:
                c = MOUNT[1]
            # ribbels: schuine lijnen vanaf de top, zoals verweerde rots
            if c in (MOUNT[3], MOUNT[4]) and (int(x - cx * 0 + y * 0.5 + seed) % 5 == 0) and dy > -0.5:
                c = MOUNT[2] if c == MOUNT[3] else MOUNT[3]
            px[x, y] = c


def mountain_tile(mask, variant=0):
    """Rotsheuvels in een verspringend rooster (zoals de bergketens in de referentie):
    elke berg-tile heeft één grote heuvel in het midden, en op elke hoek waar ook
    berg-buren zijn een 'tussenheuvel'. Die tussenheuvels liggen precies op de
    tilehoek, dus vier tiles tekenen samen één heuvel. Achter- (boven) en voorkant
    (onder) worden in volgorde getekend, zodat de rijen elkaar overlappen.
    Losse bergen (geen buren) zijn één heuvel op gras met een schaduw."""
    im = world_grass(seed=6)
    px = im.load()
    N, E, S, W = mask & 1, mask & 2, mask & 4, mask & 8
    # rotsgrond naar berg-buren toe (wordt grotendeels bedekt door heuvels)
    for y in range(T):
        for x in range(T):
            cx, cy = x + 0.5, y + 0.5
            if (N and cy < 8) or (S and cy > 8) or (W and cx < 8) or (E and cx > 8):
                px[x, y] = MOUNT[1] if (x * 3 + y) % 4 else MOUNT[0]
    # slagschaduw op het gras (rechtsonder)
    if not (S and E):
        for y in range(T):
            for x in range(T):
                if ((x + 0.5 - 10.0) / 7.4) ** 2 + ((y + 0.5 - 14.2) / 2.6) ** 2 < 1 and px[x, y] not in MOUNT:
                    px[x, y] = WG[0]
    mounds = []
    if N and W: mounds.append((0.0, 0.5, 6.6, 6.2))
    if N and E: mounds.append((16.0, 0.5, 6.6, 6.2))
    rx, ry = (7.7, 7.4) if variant == 0 else (7.2, 7.8)
    cx = 8.0 if variant == 0 else 8.5
    mounds.append((cx, 8.6 if variant == 0 else 8.2, rx, ry))
    if S and W: mounds.append((0.0, 16.5, 6.6, 6.2))
    if S and E: mounds.append((16.0, 16.5, 6.6, 6.2))
    for i, (mx, my, mrx, mry) in enumerate(sorted(mounds, key=lambda m: m[1])):
        # zaad hangt af van de wereldpositie van de heuvel -> buurtiles tekenen hem gelijk
        _mound(px, mx, my, mrx, mry, seed=int(mx) % 3)
    return im


def sea_fill():
    im = tile(SEA[2])
    px = im.load()
    rnd = random.Random(70)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < 0.18:
                px[x, y] = SEA[1]
            elif r < 0.24:
                px[x, y] = SEA[3]
    for (x, y, n) in ((2, 3, 3), (10, 6, 4), (5, 11, 3), (13, 13, 3)):
        for k in range(n):
            px[(x + k) % T, y] = SEA[3]
        px[(x + 1) % T, y - 1] = SEA[4]
    return im


def sea_tile(mask):
    """Zee met kust: donkere rotsrand, een stippellijn schuim en ondieper water."""
    im = sea_fill()
    px = im.load()
    for y in range(T):
        for x in range(T):
            cx, cy = x + 0.5, y + 0.5
            ds = []
            if mask & 1: ds.append(cy + jitter(x, 1) * 0.7)
            if mask & 2: ds.append(T - cx + jitter(y, 2) * 0.7)
            if mask & 4: ds.append(T - cy + jitter(x, 3) * 0.7)
            if mask & 8: ds.append(cx + jitter(y, 4) * 0.7)
            for bit, (kx, ky) in ((16, (T, 0)), (32, (T, T)), (64, (0, T)), (128, (0, 0))):
                if mask & bit:
                    ds.append(math.hypot(cx - kx, cy - ky) - 0.6 + jitter(x + y, bit) * 0.5)
            if not ds:
                continue
            d = min(ds)
            if d < 1.0:
                px[x, y] = CLIFF[1] if d > 0.5 and (x + y) % 2 else CLIFF[0]
            elif d < 1.8:
                px[x, y] = CLIFF[0]
            elif d < 2.8:
                px[x, y] = FOAM if (x + y) % 2 == 0 else SEA[4]
            elif d < 4.6:
                px[x, y] = SEA[3] if (x * 2 + y) % 5 else SEA[4]
    return im


def town_icon():
    """Stad op de wereldkaart (2 tiles breed): twee huisjes met paars en roodbruin dak."""
    im = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    a = world_grass(seed=8)
    im.paste(a, (0, 0)); im.paste(world_grass(seed=9), (16, 0))
    px = im.load()
    OUT = hexc("1a1420")

    def house(x0, w, roof, wall_h, roof_h, base_y):
        # schaduw
        for x in range(x0 + 2, min(x0 + w + 2, 32)):
            if base_y < 16:
                px[x, base_y] = WG[0]
        for y in range(base_y - wall_h, base_y):
            for x in range(x0, x0 + w):
                c = PLASTER[4] if x < x0 + w // 2 else PLASTER[2]
                if x in (x0, x0 + w - 1) or y == base_y - 1:
                    c = OUT
                px[x, y] = c
        dx = x0 + w // 2 - 1
        for y in range(base_y - 4, base_y - 1):        # deurtje
            px[dx, y] = ga.WOOD[1]; px[dx + 1, y] = ga.WOOD[2]
        px[x0 + 2, base_y - 4] = GLASS[2]
        px[x0 + w - 3, base_y - 4] = GLASS[2]
        top = base_y - wall_h - roof_h
        for y in range(top, base_y - wall_h + 1):
            t = (y - top) / max(1, roof_h)
            inset = round((w // 2) * (1 - t)) - 1
            for x in range(x0 - 1 + max(0, inset), x0 + w + 1 - max(0, inset)):
                lx = x - x0
                c = roof[4] if lx < w // 2 else roof[2]
                if (y - top) % 2 == 1:
                    c = roof[3] if lx < w // 2 else roof[1]
                if x in (x0 - 1 + max(0, inset), x0 + w - max(0, inset)) or y == base_y - wall_h:
                    c = OUT
                px[x, y] = c

    BLUE = ramp("141a3a", "1e2c5c", "2c4486", "3e5eaa", "5a7cc4", "86a2dc")
    house(1, 12, ROOF, 6, 8, 15)       # paars dak (zoals het huis in Wilgendal)
    house(18, 7, BLUE, 4, 5, 9)        # klein huisje met blauw dak, erachter
    house(23, 8, BRICK, 6, 7, 15)      # roodbruin dak, vooraan
    # boompje tussen de huizen
    for (x, y) in ((15, 9), (16, 9), (15, 10), (16, 10), (14, 10), (17, 10), (15, 8), (16, 8), (14, 11), (17, 11), (15, 11), (16, 11)):
        px[x, y] = FOREST[5] if y < 10 and x < 16 else (FOREST[4] if y < 11 else FOREST[3])
    px[15, 12] = ga.TRUNK[1]; px[16, 12] = ga.TRUNK[0]
    px[15, 13] = ga.TRUNK[1]
    return im


def stairs_tile():
    """Trap naar beneden: ronde opening in de grond met stenen rand en treden."""
    im = world_grass(seed=10)
    px = im.load()
    S = ga.STONE
    cx, cy = 8.0, 8.5
    for y in range(T):
        for x in range(T):
            if ((x + 0.5 - 9.0) / 7.6) ** 2 + ((y + 0.5 - 10.5) / 6.0) ** 2 < 1:
                px[x, y] = WG[0]                                   # schaduw
    for y in range(T):
        for x in range(T):
            dx, dy = (x + 0.5 - cx) / 7.6, (y + 0.5 - cy) / 6.8
            d = dx * dx + dy * dy
            if d < 1:
                lit = -dx - dy
                if d > 0.45:
                    c = S[5] if lit > 0.6 else (S[4] if lit > 0 else (S[2] if lit > -0.6 else S[1]))
                    if (x + y) % 4 == 0:
                        c = S[1]                               # voegen in de rand
                else:
                    c = hexc("0a0a12")
                px[x, y] = c
    for i, (x0, y0) in enumerate(((4, 7), (6, 9), (8, 11))):   # treden, naar beneden toe donkerder
        for k in range(5):
            if 0 <= x0 + k < T:
                px[x0 + k, y0] = (S[5], S[4], S[3])[i]
                px[x0 + k, y0 + 1] = (S[2], S[1], S[0])[i]
    return im


def make_world_sheet():
    tiles = [world_grass(1), world_grass(2)]
    lf, sf = light_grass_fill(20), sand_fill(21)
    tiles += [patch_tile(m, lf, WL[1], WL[5], 30 + m) for m in range(16)]
    tiles += [patch_tile(m, sf, SAND[1], SAND[5], 50 + m) for m in range(16)]
    tiles += [forest_tile(m) for m in range(16)]
    tiles += [mountain_tile(m) for m in range(16)]
    tiles += [sea_tile(m) for m in sea_masks()]
    icon = town_icon()
    tiles += [icon.crop((0, 0, 16, 16)), icon.crop((16, 0, 32, 16)), stairs_tile()]
    tiles += [mountain_tile(m, 1) for m in range(16)]
    assert len(tiles) == W_COUNT, len(tiles)
    rows = (len(tiles) + WORLD_COLS - 1) // WORLD_COLS
    sheet = Image.new("RGBA", (WORLD_COLS * T, rows * T), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % WORLD_COLS) * T, (i // WORLD_COLS) * T))
    return sheet


# ---------------------------------------------------------------- gevechtsachtergrond vlakte
def make_backdrop_plains(w=640, h=160):
    """Vlakte: verre blauwige heuvels, een rij tan rotsheuvels en struiken als 'wand',
    daaronder een grasvloer die naar voren lichter wordt. Geen lucht (zie ARTSTYLE)."""
    im = Image.new("RGBA", (w, h), WG[0])
    px = im.load()
    rnd = random.Random(77)
    far = ramp("142a2a", "1c3a36", "264a40")
    for x in range(w):                                     # verre heuvelrug
        top = 18 + 10 * math.sin(x / 37.0) + 6 * math.sin(x / 13.0 + 1)
        for y in range(h):
            if y < top:
                px[x, y] = hexc("0c1a1c")
            elif y < 82:
                px[x, y] = far[2] if (y - top) < 3 else (far[1] if (x + y) % 5 else far[0])
    for i in range(int(w / 26) + 2):                       # tan rotsheuvels
        cx = i * 26 + rnd.randrange(-6, 6)
        cy = 66 + rnd.randrange(-4, 5)
        rx, ry = rnd.randrange(14, 19), rnd.randrange(14, 19)
        for y in range(int(cy - ry), int(cy + ry)):
            for x in range(int(cx - rx), int(cx + rx)):
                if 0 <= x < w and 0 <= y < 84:
                    dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                    d = dx * dx + dy * dy
                    if d < 1:
                        lit = -dx * 0.9 - dy
                        c = MOUNT[5] if lit > 0.9 else MOUNT[4] if lit > 0.35 else MOUNT[3] if lit > -0.3 else MOUNT[2]
                        if d > 0.8:
                            c = MOUNT[1] if lit < 0.3 else MOUNT[2]
                        if (x * 7 + y * 3) % 23 == 0:
                            c = MOUNT[2]
                        px[x, y] = c
    for i in range(int(w / 12) + 2):                       # struikenrij voor de heuvels
        cx = i * 12 + rnd.randrange(-3, 3)
        cy = 80 + rnd.randrange(-2, 2)
        r = rnd.randrange(6, 9)
        for y in range(cy - r, cy + r):
            for x in range(cx - r, cx + r):
                if 0 <= x < w and 0 <= y < h:
                    dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
                    d = dx * dx + dy * dy
                    if d < 1:
                        lit = -dx - dy
                        c = FOREST[4] if lit > 0.6 else FOREST[3] if lit > 0 else FOREST[2]
                        if d > 0.75:
                            c = FOREST[1]
                        px[x, y] = c
    for y in range(84, h):                                 # grasvloer
        t = (y - 84) / (h - 84)
        for x in range(w):
            r = rnd.random()
            base = WG[2] if t < 0.3 else WG[3] if t < 0.7 else WG[4]
            c = base
            if r < 0.18:
                c = WG[1] if t < 0.5 else WG[2]
            elif r < 0.27:
                c = WG[4] if t < 0.5 else WG[5]
            if y % 9 == 0 and r < 0.5:
                c = WG[1]                                  # perspectief-streepjes
            px[x, y] = c
    for y in range(84, 88):
        for x in range(w):
            if px[x, y] not in (FOREST[1], FOREST[2], FOREST[3], FOREST[4]):
                px[x, y] = WG[1] if y < 86 else px[x, y]
    return im


def make_all(root):
    tiles_dir = os.path.join(root, "assets", "tiles")
    make_town_sheet().save(os.path.join(tiles_dir, "dorp.png"))
    make_house().save(os.path.join(tiles_dir, "huis.png"))
    make_world_sheet().save(os.path.join(tiles_dir, "wereld.png"))
    # backdrop_vlakte.png komt sinds v6 uit tools/art_battle_bg.py (16-bit plus);
    # make_backdrop_plains() hierboven is de oude 16-bit versie.


if __name__ == "__main__":
    make_all(ga.ROOT)
    print("Map-art gegenereerd")
