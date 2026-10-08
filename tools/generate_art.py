#!/usr/bin/env python3
"""
Genereert alle pixel-art voor het prototype (eigen werk, geen copyright).
Gebruik:  python3 tools/generate_art.py   (vanuit de projectmap, vereist Pillow)

De STIJLREGELS staan in docs/ARTSTYLE.md (afgeleid van een SNES-RPG-referentie).
Kort samengevat wat dit script toepast:
  - tiles 16x16, GEEN zwarte omlijning; vorm komt van donkere randschaduw
  - licht valt van linksboven; schaduw valt naar rechtsonder op de grond
  - veel fijne textuur (gras met verticale streepjes, korrelig zand, steen met ruis)
  - gedempt, olijfgroen / leisteenblauw / zandkleurig palet, 4-6 tinten per materiaal
  - personages 16x24 (chibi: hoofd ~ helft van de hoogte), donkere (niet zwarte)
    omlijning en een ovale schaduw onder de voeten
  - vijanden met donkere gekleurde omlijning, 4-5 tinten en een grondschaduw

Output:
  (de basis-tiles uit make_tileset() komen als tile 0..32 in assets/tiles/dorp.png:
        0 gras, 1 bloemen, 2 pad, 3 boom*, 4 muur*, 5 water*, 6 brug, 7 rots*
        (* = heeft collision in de TileSet)
        8..32 = rand-varianten (gras met schaduw, pad met grasrand, water met oever),
        die tools/build_maps.gd automatisch kiest.)
  De dorp-, huis- en wereldkaart-tiles maakt tools/art_maps.py (wordt hieronder
  automatisch aangeroepen): dorp.png, huis.png, wereld.png.
  ALLE GEVECHTS-ART EN VENSTERS (v7 'De Vergeten Bibliotheek', 2x zo fijn) maken
  tools/art_v7_ui.py, art_v7_bg.py, art_v7_heroes.py en art_v7_enemies.py; ook die
  worden hieronder automatisch aangeroepen. (art_battle.py/art_battle_bg.py = v6.)
  assets/sprites/player.png   48x96  -> 3 kolommen (stil, stap A, stap B) van 16x24
                                        x 4 rijen (onder, links, rechts, boven)
  assets/sprites/npc.png      48x96  -> zelfde indeling, ander personage
  assets/sprites/sign.png     16x16  -> houten bordje
  assets/sprites/enemies/*.png       -> vijanden (papiergeest, glitchmot, kennis_beest)
  assets/battle/bibliotheek*.png 1280x432 -> gevechtsachtergronden (bibliotheek, overwoekerd)
  assets/ui/window.png               -> 9-slice tekstvenster (houtskool, metalen hoekjes)
  assets/ui/panel_status.png         -> 9-slice statusvak / titel-tabje (dunne grijze rand)
  assets/ui/window_glass.png         -> 9-slice half-doorzichtig venster (overwinningsscherm)
  assets/ui/*_hd.png                 -> dezelfde vensters op het 2x-raster (gevechtsscherm)
  assets/sprites/battle/<held>.png 1120x140 -> gevechtssprite per held: 8 frames van 140x140
        (stil, klaar, aanval A, aanval B, spreuk A, spreuk B, geraakt, KO)
  De oude 16-bit gevechtsfuncties hieronder (make_slime, make_battle_hero, ...) blijven
  bestaan als referentie maar worden niet meer opgeslagen.
"""
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
T = 16


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def ramp(*hexes):
    return [hexc(h) for h in hexes]


# ---------------------------------------------------------------- palet (zie docs/ARTSTYLE.md)
# Elke 'ramp' loopt van donker naar licht.
GRASS = ramp("3a4510", "4e5b16", "606d1b", "737e20", "8e922c", "a6a83e")
PATH = ramp("8a7a32", "a8953d", "b4a14b", "bfae5a", "cdbe6e", "ddd294")
LEAF = ramp("16230a", "26360b", "35460f", "4a5a16", "60701f", "7d8c30")
TRUNK = ramp("2a1a0c", "4a2e16", "6a4422")
STONE = ramp("23282f", "3b454f", "4b525d", "5a606b", "6b717c", "858b96")
WATER = ramp("101d3e", "18295a", "213a78", "2c4c92", "4a6cae", "8aa6d6")
WOOD = ramp("311d17", "553524", "714a33", "8c6246", "a87e5e", "c49c78")
ROCK = ramp("231c1e", "3c3234", "574a49", "726560", "8f827a", "aea296")
SHADOW_GRASS = hexc("2e380c")         # slagschaduw van bomen/rotsen op het gras


def new_tile(color):
    return Image.new("RGBA", (T, T), color)


def grass_tile(seed=1):
    """Gras: geel-olijfgroen met verticale streepjes (lichte en donkere halmen)."""
    im = new_tile(GRASS[3])
    px = im.load()
    rnd = random.Random(seed)
    for x in range(T):
        y = rnd.randrange(T)
        for _ in range(4):                       # per kolom een paar streepjes
            length = rnd.choice((2, 2, 3, 3, 4))
            col = rnd.choice((GRASS[2], GRASS[2], GRASS[4], GRASS[4], GRASS[1]))
            for k in range(length):
                px[x, (y + k) % T] = col
            # direct onder een licht streepje een donker pixeltje = 'halm'
            if col == GRASS[4]:
                px[x, (y + length) % T] = GRASS[2]
            y = (y + length + rnd.randrange(1, 4)) % T
    for _ in range(6):
        px[rnd.randrange(T), rnd.randrange(T)] = GRASS[5]
    return im


def flower_tile():
    im = grass_tile(seed=7)
    px = im.load()
    petals = {"w": hexc("e6dfc6"), "y": hexc("d9bf4e"), "r": hexc("c46a6a")}
    for (x, y, c) in [(3, 3, "w"), (11, 2, "y"), (7, 9, "r"), (13, 11, "w"), (2, 12, "y")]:
        col = petals[c]
        for dx, dy in [(-1, 0), (1, 0), (0, -1)]:
            px[x + dx, y + dy] = col
        px[x, y] = hexc("e9a640")
        px[x, y + 1] = GRASS[0]              # schaduwtje onder het bloemetje
        px[x + 1, y + 1] = GRASS[1]
    return im


def path_tile():
    """Zandpad: dichte korrelige ruis + kiezeltjes met licht boven, schaduw onder."""
    im = new_tile(PATH[2])
    px = im.load()
    rnd = random.Random(3)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < 0.22:
                px[x, y] = PATH[1]
            elif r < 0.45:
                px[x, y] = PATH[3]
            elif r < 0.53:
                px[x, y] = PATH[4]
    for _ in range(4):
        x, y = rnd.randrange(1, 14), rnd.randrange(1, 14)
        px[x, y] = PATH[5]; px[x + 1, y] = PATH[4]
        px[x, y + 1] = PATH[0]; px[x + 1, y + 1] = PATH[0]
    return im


def tree_tile():
    """Eigen naaldboom die de hele tile vult (zodat een rij bomen een dicht bos vormt):
    drie lagen 'hangende' takken, licht links, donker rechts, een donkere rand
    (geen zwarte lijn) en een slagschaduw rechtsonder op het gras."""
    im = grass_tile(seed=11)
    px = im.load()
    for y in range(11, 16):                                   # slagschaduw
        for x in range(5, 16):
            if ((x - 10.5) / 5.5) ** 2 + ((y - 14.5) / 2.2) ** 2 <= 1.0:
                px[x, y] = SHADOW_GRASS
    px[7, 15] = TRUNK[1]; px[8, 15] = TRUNK[0]                # stammetje
    layer = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    lp = layer.load()
    draw_pine(lp, T, T, 7.5, 15, 16, 8.6, [LEAF[1], LEAF[1], LEAF[2], LEAF[3], LEAF[5]],
              random.Random(12), tiers=3, fullness=0.42)
    # silhouet: randpixels donker (rechts/onder het donkerst, licht valt van linksboven)
    solid = [[lp[x, y][3] > 0 for x in range(T)] for y in range(T)]
    for y in range(T):
        for x in range(T):
            if not solid[y][x]:
                continue
            open_r = x + 1 >= T or not solid[y][x + 1]
            open_b = y + 1 >= T or not solid[y + 1][x]
            open_l = x - 1 < 0 or not solid[y][x - 1]
            open_t = y - 1 < 0 or not solid[y - 1][x]
            if open_r or open_b:
                lp[x, y] = LEAF[0]
            elif open_l or open_t:
                lp[x, y] = LEAF[1] if x > 7 else LEAF[2]
    im.alpha_composite(layer)
    return im


def wall_tile():
    """Muur van leisteenblauwe blokken: ruis-textuur, licht linksboven, voeg donker."""
    im = new_tile(STONE[0])
    px = im.load()
    rnd = random.Random(9)
    rows = [(0, 5, 0), (5, 10, 4), (10, 16, 2)]          # (y0, y1, verschuiving)
    for y0, y1, off in rows:
        widths = [7, 9] if off != 4 else [8, 8]
        x0 = -off
        while x0 < T:
            for w in widths:
                for y in range(y0, y1 - 1):
                    for x in range(x0, x0 + w - 1):
                        if 0 <= x < T:
                            if y == y0 or x == x0:
                                c = STONE[4]                  # bovenkant/linkerkant: licht
                            elif y == y1 - 2 or x == x0 + w - 2:
                                c = STONE[1]                  # onderkant/rechterkant: donker
                            else:
                                c = rnd.choice((STONE[2], STONE[3], STONE[3], STONE[2], STONE[4]))
                            px[x, y] = c
                x0 += w
                if x0 >= T:
                    break
    for _ in range(6):                                       # een paar putjes
        x, y = rnd.randrange(T), rnd.randrange(T)
        if px[x, y] != STONE[0]:
            px[x, y] = STONE[1]
    return im


def water_tile():
    """Diep blauw water: donkere ruis + korte lichte golfjes (horizontaal)."""
    im = new_tile(WATER[2])
    px = im.load()
    rnd = random.Random(4)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < 0.25:
                px[x, y] = WATER[1]
            elif r < 0.33:
                px[x, y] = WATER[3]
    for (x, y, n) in [(1, 2, 4), (9, 4, 5), (4, 8, 4), (12, 10, 3), (1, 13, 5), (9, 14, 4)]:
        for k in range(n):
            px[(x + k) % T, y] = WATER[4] if 0 < k < n - 1 else WATER[3]
        if n >= 5:
            px[(x + 2) % T, y] = WATER[5]
        for k in range(n):
            px[(x + k) % T, (y + 1) % T] = WATER[1]
    return im


def bridge_tile():
    """Houten brug: verticale planken met nerf, leuning boven/onder met schaduw."""
    im = new_tile(WOOD[3])
    px = im.load()
    rnd = random.Random(6)
    for y in range(T):
        for x in range(T):
            k = x % 4
            if k == 3:
                c = WOOD[1]                      # naad
            elif k == 0:
                c = WOOD[4]                      # licht randje (licht van links)
            else:
                c = WOOD[3] if rnd.random() > 0.2 else WOOD[2]
            px[x, y] = c
    for x in range(T):                           # leuning
        px[x, 0] = WOOD[0]; px[x, 1] = WOOD[5] if x % 4 else WOOD[2]; px[x, 2] = WOOD[1]
        px[x, 3] = WOOD[2]                       # schaduw van de leuning op de planken
        px[x, 13] = WOOD[5] if x % 4 else WOOD[2]; px[x, 14] = WOOD[1]; px[x, 15] = WOOD[0]
    return im


def rock_tile():
    """Rotsblok op gras: 5 tinten, licht linksboven, donkere rand, schaduw rechtsonder."""
    im = grass_tile(seed=21)
    px = im.load()
    for y in range(8, 16):
        for x in range(3, 16):
            if ((x - 9.5) / 6.2) ** 2 + ((y - 12.5) / 3.2) ** 2 <= 1.0:
                px[x, y] = SHADOW_GRASS
    cx, cy, rx, ry = 7.5, 8.5, 6.6, 5.8
    for y in range(T):
        for x in range(T):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                lit = -(x - cx) / rx - (y - cy) / ry          # >0 = linksboven
                if d > 0.78:
                    c = ROCK[0] if lit < 0.4 else ROCK[1]
                elif lit > 0.9:
                    c = ROCK[5]
                elif lit > 0.3:
                    c = ROCK[4]
                elif lit > -0.4:
                    c = ROCK[3]
                else:
                    c = ROCK[2]
                px[x, y] = c
    for (x, y) in [(9, 6), (10, 7), (6, 10), (5, 9)]:        # barstjes
        px[x, y] = ROCK[1]
    return im


# ---------------------------------------------------------------- randjes (automatisch gekozen)
# Zoals in de referentie lopen materialen niet 'hard' in elkaar over: gras hangt een
# beetje over het pad, een rivieroever geeft een donkere rand op het water en bomen/
# muren/rotsen werpen schaduw op het gras eronder/rechts ervan.
# tools/build_maps.gd kiest automatisch de juiste variant op basis van de buren.
# Masker-bits:  N = 1 (boven), E = 2 (rechts), S = 4 (onder), W = 8 (links)
GRASS_SHADOW_BASE = 7    # 8..10  : gras met schaduw  (1 = van boven, 2 = van links, 3 = beide)
PATH_EDGE_BASE = 10      # 11..25 : pad met grasrand  (masker N/E/S/W)
WATER_BANK_BASE = 25     # 26..32 : water met oever   (1 = boven, 2 = rechts, 4 = links)


def _side_coords(side, depth):
    """Pixels van een rand: geeft (x, y, d) met d = afstand tot de rand (0 = buitenste rij)."""
    out = []
    for d in range(depth):
        for i in range(T):
            out.append({"N": (i, d), "S": (i, T - 1 - d), "W": (d, i), "E": (T - 1 - d, i)}[side] + (d,))
    return out


def grass_shadow_tile(mask):
    """Gras met slagschaduw van een boom/muur/rots: van boven (bit 1) een kartelige band,
    van links (bit 2) een smallere schaduw die naar onder toe breder wordt
    (licht komt van linksboven, dus schaduw valt naar rechtsonder)."""
    im = grass_tile(seed=1)
    px = im.load()
    rnd = random.Random(30 + mask)
    if mask & 1:
        for x in range(T):
            depth = rnd.choice((2, 3, 3, 4))
            for y in range(depth):
                px[x, y] = SHADOW_GRASS if y < depth - 1 else GRASS[1]
    if mask & 2:
        for y in range(T):
            depth = int(1 + 2.5 * y / T) + rnd.choice((0, 0, 1))
            if y < 4 and not mask & 1:
                depth = max(0, depth - 1)
            for x in range(depth):
                px[x, y] = SHADOW_GRASS if x < depth - 1 else GRASS[1]
    return im


def path_edge_tile(mask):
    """Pad met grasrand: het gras ligt iets hoger, dus de graskant krijgt een donkere
    rand (zoals in de referentie) en het pad vlak ernaast een schaduwrandje."""
    im = path_tile()
    px = im.load()
    grass = grass_tile(seed=2).load()
    rnd = random.Random(50 + mask)
    for bit, side in ((1, "N"), (2, "E"), (4, "S"), (8, "W")):
        if not mask & bit:
            continue
        tuft = [rnd.choice((2, 2, 3, 3, 4)) for _ in range(T)]
        for (x, y, d) in _side_coords(side, 6):
            i = x if side in "NS" else y
            if d < tuft[i] - 1:
                px[x, y] = grass[x, y]                        # overhangend gras
            elif d == tuft[i] - 1:
                px[x, y] = GRASS[0] if side in "SE" else GRASS[1]   # donkere graskant
            elif d == tuft[i]:
                px[x, y] = PATH[0] if side in "NW" else PATH[1]     # schaduw op het pad
            elif d == tuft[i] + 1 and side in "NW" and rnd.random() < 0.5:
                px[x, y] = PATH[1]
    return im


def water_bank_tile(mask):
    im = water_tile()
    px = im.load()
    grass = grass_tile(seed=3).load()
    rnd = random.Random(70 + mask)
    for bit, side in ((1, "N"), (2, "E"), (4, "W")):
        if not mask & bit:
            continue
        lip = [rnd.choice((1, 1, 2)) for _ in range(T)]
        for (x, y, d) in _side_coords(side, 5):
            i = x if side == "N" else y
            if d < lip[i]:
                px[x, y] = grass[x, y] if d < lip[i] - 1 else GRASS[1]   # graskantje
            elif d < lip[i] + (2 if side == "N" else 1):
                px[x, y] = WATER[0]                               # donkere oever-schaduw
            elif d < lip[i] + (3 if side == "N" else 2):
                px[x, y] = WATER[1]
    return im


def make_tileset():
    tiles = [grass_tile(), flower_tile(), path_tile(), tree_tile(),
             wall_tile(), water_tile(), bridge_tile(), rock_tile()]
    tiles += [grass_shadow_tile(m) for m in range(1, 4)]          # 8..10
    tiles += [path_edge_tile(m) for m in range(1, 16)]            # 11..25
    tiles += [water_bank_tile(m) for m in range(1, 8)]            # 26..32
    assert len(tiles) == 33
    sheet = Image.new("RGBA", (T * len(tiles), T), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * T, 0))
    return sheet


# ---------------------------------------------------------------- personages (16x24)
CW, CH = 16, 24
# Legenda:  o omlijning (donker, niet zwart)   h/H/d haar (midden/licht/donker)
#   s/S huid (licht/schaduw)  e oog   y/Y sjaal   c/C/L kleding (midden/donker/licht)
#   b riem   p/P broek   k laars   , schaduw onder de voeten (half doorzichtig)
HEAD_FRONT = [
    "................",
    ".....oooooo.....",
    "...ooHHhhhhoo...",
    "..oHHhhhhhhhdo..",
    ".oHHhhhhhhhhhdo.",
    ".oHhhhhhhhhhhdo.",
    ".ohhhhhhhhhhhdo.",
    ".ohhdhhhdhhhddo.",
    ".ohdshhdsshdsdo.",
    ".odssessssessdo.",
    ".odssessssesSdo.",
    ".odsssssssssSdo.",
    "..oosssSSSSSoo..",
    "....ooyyyyoo....",
]
HEAD_BACK = HEAD_FRONT[:7] + [
    ".ohhhdhhhhdhhdo.",
    ".ohhhdhhhhdhhdo.",
    ".odhhhdhhdhhhdo.",
    ".odhhhhhhhhhddo.",
    ".oddhhhhhhhhddo.",
    "..oodddhhdddoo..",
    "....ooyyyyoo....",
]
BODY_FRONT = [
    "...oyyyyyyyYo...",
    "..oLLcccccccCo..",
    ".oLLcccccccccCo.",
    ".osLbbbbbbbbbso.",
    ".oocccccccccCoo.",
]
BODY_BACK = [
    "...oyyyyyyyYo...",
    "..oLLccyyccCCo..",
    ".oLLcccyycccCCo.",
    ".osLbbbbbbbbbso.",
    ".oocccccccccCoo.",
]
LEGS_FRONT = {
    "idle": ["...oppppPPPPo...", "...oppo..oPPo...", "..okkko..okkko..", "..,ooo,,,,ooo,..", "....,,,,,,,,...."],
    "a":    ["...oppppPPPPo...", "...okkko.oPPo...", "...,ooo,.okkko..", "..,,,,,,,,ooo,..", "....,,,,,,,,...."],
    "b":    ["...oppppPPPPo...", "...oppo.okkko...", "..okkko.,ooo,...", "..,ooo,,,,,,,,..", "....,,,,,,,,...."],
}
HEAD_SIDE = [
    "................",
    "....oooooo......",
    "..ooHHhhhhoo....",
    ".oHHhhhhhhhdo...",
    ".oHhhhhhhhhhdo..",
    "ohhhhhhhhhhhhdo.",
    "ohhhhhhhhhhhhdo.",
    "ohssdhhhhhhhhdo.",
    "ossssshhhhhhhdo.",
    "osessshhhhhhddo.",
    "osesssSShhhhddo.",
    "ossssssShhhhdo..",
    ".oSsssssoddoo...",
    "..oooyyyyoo.....",
]
BODY_SIDE = [
    "...oyyyyyYo.....",
    "...oLccccCo.....",
    "...oLsccccCo....",
    "...obbbbbbo.....",
    "...occcccCo.....",
]
LEGS_SIDE = {
    "idle": ["....oppPPo......", "....oppPPo......", "...okkkkko......", "..,,ooooo,,.....", "...,,,,,,,......"],
    "a":    ["....oppPPo......", "...oppooPPo.....", "..okkko.okko....", "..,ooo,,,oo,....", "...,,,,,,,,....."],
    "b":    ["....oppPPo......", "....oPPpo.......", "...okkkko.......", "..,,oooo,,......", "...,,,,,,,......"],
}


def render_rows(rows, pal):
    im = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    px = im.load()
    assert len(rows) == CH, len(rows)
    for y, row in enumerate(rows):
        assert len(row) == CW, (y, row, len(row))
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = pal[ch]
    return im


def character_frames(variant):
    """Geeft per richting 3 frames (lijst met 24 rijen tekst)."""
    head_f, head_b, body_f, body_b = HEAD_FRONT, HEAD_BACK, BODY_FRONT, BODY_BACK
    legs_f, legs_s, body_s = LEGS_FRONT, LEGS_SIDE, BODY_SIDE
    if variant == "robe":
        # lange mantel tot op de voeten (voor de oude dorpeling)
        body_f = ["...oyyyyyyyYo...", "..oLLcccccccCo..", ".oLLcccccccccCo.", ".osLcccccccccso.", ".oLcccccccccCCo."]
        body_b = body_f
        robe = ["..oLcccccccCCo..", "..oLcccccccCCo..", "..oookkoookkoo..", "..,,,ooo,ooo,,..", "....,,,,,,,,...."]
        legs_f = {"idle": robe, "a": robe[:2] + ["..ooookkoooooo..", "..,,,ooo,,,,,,..", "....,,,,,,,,...."],
                  "b": robe[:2] + ["..ooooooookkoo..", "..,,,,,,,ooo,,..", "....,,,,,,,,...."]}
        body_s = ["...oyyyyyYo.....", "...oLccccCo.....", "...oLsccccCo....", "...oLccccCCo....", "..oLccccccCo...."]
        side_robe = ["..oLcccccCCo....", "..oLcccccCCo....", "..okkoooooo.....", "..,ooo,,,,,.....", "...,,,,,,,......"]
        legs_s = {"idle": side_robe, "a": side_robe[:2] + ["..ookkooooo.....", "..,,ooo,,,,.....", "...,,,,,,,......"],
                  "b": side_robe}
    down = [head_f + body_f + legs_f[k] for k in ("idle", "a", "b")]
    up = [head_b + body_b + legs_f[k] for k in ("idle", "b", "a")]
    left = [HEAD_SIDE + body_s + legs_s[k] for k in ("idle", "a", "b")]
    return {"down": down, "left": left, "up": up}


def make_character(pal, variant="tunic"):
    frames = character_frames(variant)
    sheet = Image.new("RGBA", (CW * 3, CH * 4), (0, 0, 0, 0))
    for r, d in enumerate(["down", "left", "right", "up"]):
        for c in range(3):
            if d == "right":
                im = render_rows(frames["left"][c], pal).transpose(Image.FLIP_LEFT_RIGHT)
            else:
                im = render_rows(frames[d][c], pal)
            sheet.paste(im, (c * CW, r * CH))
    return sheet


SKIN = {"s": hexc("efb895"), "S": hexc("c98a68"), "e": hexc("2a1c1c")}
SHADOW_PX = (16, 20, 8, 110)
# Held: kastanjebruin haar, groene tuniek, okergele sjaal (eigen ontwerp)
PLAYER_PAL = dict(SKIN, **{
    "o": hexc("1c1a14"), "h": hexc("7a4426"), "H": hexc("a8683c"), "d": hexc("4c2816"),
    "y": hexc("d6a83c"), "Y": hexc("9a7424"),
    "c": hexc("3f7434"), "C": hexc("2a5126"), "L": hexc("5f9648"),
    "b": hexc("6a4422"), "p": hexc("5a4a3a"), "P": hexc("3e3228"), "k": hexc("4a2e18"),
    ",": SHADOW_PX,
})
# Dorpsoudste: grijs haar, paarse mantel, crèmekleurige kraag (eigen ontwerp)
NPC_PAL = dict(SKIN, **{
    "o": hexc("1c1820"), "h": hexc("a8a4b0"), "H": hexc("dcd8e2"), "d": hexc("6e6a78"),
    "y": hexc("d8ccb0"), "Y": hexc("a89a7c"),
    "c": hexc("5e3c78"), "C": hexc("3e2652"), "L": hexc("7e5a98"),
    "b": hexc("c8a048"), "p": hexc("3e2652"), "P": hexc("2c1a3c"), "k": hexc("3a2616"),
    ",": SHADOW_PX,
})


def make_sign():
    rows = [
        "................",
        "................",
        "..oooooooooooo..",
        "..oHwwwwwwwwwo..",
        "..owddddddddDo..",
        "..owwwwwwwwwDo..",
        "..owdddddddwDo..",
        "..owwwwwwwwwDo..",
        "..oDDDDDDDDDDo..",
        "..oooooDDooooo..",
        "......owDo......",
        "......owDo,,....",
        "......owDo,,,...",
        ".....gowDog,,...",
        "....ggooooGg,...",
        "................",
    ]
    pal = {"o": WOOD[0], "w": WOOD[4], "H": WOOD[5], "d": WOOD[2], "D": WOOD[1],
           "g": GRASS[1], "G": GRASS[4], ",": SHADOW_PX}
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = pal[ch]
    return im


# ---------------------------------------------------------------- vijanden (48x48)
E = 48


def mask_from(draw_fn):
    """Maak een zwart/wit masker (mode '1') door draw_fn(ImageDraw) aan te roepen."""
    m = Image.new("1", (E, E), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def paint(img, mask, color):
    img.paste(Image.new("RGBA", img.size, color), (0, 0), mask)


def shaded(img, mask, ramp4):
    """Kleur een vorm met 4 tinten, licht van linksboven:
    ramp4 = [diepe schaduw, schaduw, midden, licht]."""
    mp = mask.load()

    def inside(x, y):
        return 0 <= x < E and 0 <= y < E and mp[x, y]
    px = img.load()
    for y in range(E):
        for x in range(E):
            if not mp[x, y]:
                continue
            if not inside(x + 1, y + 1):
                c = ramp4[0]                          # rand rechtsonder: diepste schaduw
            elif not inside(x + 3, y + 3):
                c = ramp4[1]
            elif not inside(x - 2, y - 2):
                c = ramp4[3]                          # rand linksboven: licht
            else:
                c = ramp4[2]
            px[x, y] = c


def add_outline(img, color):
    """Omlijning van 1 pixel in een donkere tint van de vijand zelf (geen puur zwart)."""
    px = img.load()
    w, h = img.size
    solid = [[px[x, y][3] > 200 for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and solid[ny][nx]:
                    px[x, y] = color
                    break
    return img


def with_ground_shadow(img, cx=24, cy=45, rx=14, ry=2.5):
    """Donkere ovale schaduw op de grond onder de vijand (achter de vijand getekend)."""
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(10, 8, 6, 150))
    base.alpha_composite(img)
    return base


def make_slime():
    img = Image.new("RGBA", (E, E), (0, 0, 0, 0))
    body = mask_from(lambda d: (d.ellipse((8, 18, 40, 44), fill=1),
                                d.polygon([(17, 23), (24, 8), (31, 23)], fill=1),
                                d.rectangle((8, 36, 40, 42), fill=1)))
    shaded(img, body, ramp("1f4a3a", "2f6a4c", "4a8c5c", "78b278"))
    hl = mask_from(lambda d: (d.ellipse((13, 22, 19, 28), fill=1), d.rectangle((21, 13, 22, 18), fill=1)))
    paint(img, hl, hexc("c4e2b4"))
    eyes = mask_from(lambda d: (d.rectangle((17, 28, 19, 33), fill=1), d.rectangle((27, 28, 29, 33), fill=1)))
    paint(img, eyes, hexc("12201a"))
    glint = mask_from(lambda d: (d.point((17, 29), fill=1), d.point((27, 29), fill=1)))
    paint(img, glint, hexc("e8f0e0"))
    mouth = mask_from(lambda d: d.line((21, 37, 25, 37), fill=1))
    paint(img, mouth, hexc("1f4a3a"))
    return with_ground_shadow(add_outline(img, hexc("10261c")))


def make_bat():
    img = Image.new("RGBA", (E, E), (0, 0, 0, 0))
    wings = mask_from(lambda d: (
        d.polygon([(22, 20), (12, 10), (2, 16), (1, 30), (6, 26), (10, 31), (14, 27), (18, 32), (22, 28)], fill=1),
        d.polygon([(26, 20), (36, 10), (46, 16), (47, 30), (42, 26), (38, 31), (34, 27), (30, 32), (26, 28)], fill=1)))
    shaded(img, wings, ramp("281a34", "3c2a4c", "56406a", "765c8c"))
    bones = mask_from(lambda d: (d.line((21, 21, 12, 12), fill=1), d.line((12, 12, 3, 17), fill=1),
                                 d.line((27, 21, 36, 12), fill=1), d.line((36, 12, 45, 17), fill=1)))
    paint(img, bones, hexc("947aa8"))
    body = mask_from(lambda d: (d.ellipse((16, 16, 32, 36), fill=1),
                                d.polygon([(17, 19), (18, 9), (22, 17)], fill=1),
                                d.polygon([(31, 19), (30, 9), (26, 17)], fill=1)))
    shaded(img, body, ramp("2e2038", "4a3458", "6a5080", "8e74a4"))
    eyes = mask_from(lambda d: (d.rectangle((20, 22, 22, 24), fill=1), d.rectangle((26, 22, 28, 24), fill=1)))
    paint(img, eyes, hexc("e05a3a"))
    pupils = mask_from(lambda d: (d.point((21, 23), fill=1), d.point((27, 23), fill=1)))
    paint(img, pupils, hexc("fff0b0"))
    fangs = mask_from(lambda d: (d.line((21, 29, 21, 31), fill=1), d.line((27, 29, 27, 31), fill=1)))
    paint(img, fangs, hexc("e8e0d8"))
    feet = mask_from(lambda d: (d.line((21, 37, 21, 40), fill=1), d.line((27, 37, 27, 40), fill=1)))
    paint(img, feet, hexc("3c2a4c"))
    return with_ground_shadow(add_outline(img, hexc("140c1a")), cy=46, rx=10, ry=2)


def make_goblin():
    img = Image.new("RGBA", (E, E), (0, 0, 0, 0))
    skin4 = ramp("3a4416", "56621e", "75842c", "98a644")
    club = mask_from(lambda d: (d.line((36, 30, 40, 10), fill=1), d.line((37, 30, 41, 10), fill=1),
                                d.ellipse((36, 3, 45, 14), fill=1)))
    shaded(img, club, WOOD[0:1] + WOOD[1:2] + WOOD[3:4] + WOOD[4:5])
    legs = mask_from(lambda d: (d.rectangle((17, 36, 21, 44), fill=1), d.rectangle((27, 36, 31, 44), fill=1)))
    shaded(img, legs, skin4)
    feet = mask_from(lambda d: (d.rectangle((15, 43, 21, 45), fill=1), d.rectangle((27, 43, 33, 45), fill=1)))
    paint(img, feet, hexc("3a2616"))
    torso = mask_from(lambda d: d.polygon([(15, 24), (33, 24), (31, 38), (17, 38)], fill=1))
    shaded(img, torso, skin4)
    cloth = mask_from(lambda d: d.polygon([(16, 32), (32, 32), (31, 39), (24, 41), (17, 39)], fill=1))
    shaded(img, cloth, ramp("3e2a1c", "5a3e28", "7a5838", "9a7650"))
    arms = mask_from(lambda d: (d.polygon([(15, 25), (10, 34), (13, 36), (17, 29)], fill=1),
                                d.polygon([(33, 25), (38, 30), (36, 33), (31, 29)], fill=1)))
    shaded(img, arms, skin4)
    hand = mask_from(lambda d: d.ellipse((35, 27, 40, 32), fill=1))
    shaded(img, hand, skin4)
    head = mask_from(lambda d: (d.ellipse((15, 6, 33, 25), fill=1),
                                d.polygon([(16, 13), (7, 9), (15, 18)], fill=1),
                                d.polygon([(32, 13), (41, 9), (33, 18)], fill=1)))
    shaded(img, head, skin4)
    eyes = mask_from(lambda d: (d.rectangle((19, 13, 22, 15), fill=1), d.rectangle((26, 13, 29, 15), fill=1)))
    paint(img, eyes, hexc("e8c84a"))
    pupils = mask_from(lambda d: (d.point((21, 14), fill=1), d.point((27, 14), fill=1)))
    paint(img, pupils, hexc("1a1c10"))
    brow = mask_from(lambda d: (d.line((18, 11, 22, 12), fill=1), d.line((26, 12, 30, 11), fill=1)))
    paint(img, brow, skin4[0])
    mouth = mask_from(lambda d: d.line((20, 20, 28, 20), fill=1))
    paint(img, mouth, hexc("1a1c10"))
    teeth = mask_from(lambda d: (d.point((21, 19), fill=1), d.point((27, 19), fill=1)))
    paint(img, teeth, hexc("e8e0c8"))
    return with_ground_shadow(add_outline(img, hexc("1a1c10")), cy=46)


# ---------------------------------------------------------------- gevechtsachtergrond
DIRT = ramp("2a170b", "3a2112", "4a2d18", "5a3a22", "6e4a2e", "86603e")


def draw_pine(px, w, h, cx, base_y, height, half_w, shades, rnd, tiers=4, fullness=0.18):
    """Eigen naaldboom-vorm: lagen 'hangende' takken; licht links, donker rechts.
    shades = 5 tinten van donker naar licht."""
    top = base_y - height
    for y in range(max(top, 0), min(base_y, h)):
        t = (y - top) / height
        u = (t * tiers) % 1.0                         # positie binnen een takkenlaag
        ww = half_w * (fullness + (1 - fullness) * t) * (0.55 + 0.45 * u) + rnd.uniform(-0.8, 0.8)
        for x in range(int(cx - ww), int(cx + ww) + 1):
            if not (0 <= x < w):
                continue
            rel = (x - cx) / max(ww, 1.0)
            if abs(rel) > 0.92:
                c = shades[0]                          # donkere rand (geen zwarte lijn)
            elif u > 0.82:
                c = shades[1] if rel < 0.2 else shades[0]   # onderkant van een laag
            elif rel < -0.45:
                c = shades[3]
            elif rel < 0.15:
                c = shades[2]
            else:
                c = shades[1]
            if c == shades[3] and rnd.random() < 0.22:
                c = shades[4]                          # lichte naaldjes
            elif c == shades[2] and rnd.random() < 0.12:
                c = shades[1]
            px[x, y] = c


def make_backdrop(w=640, h=160):
    """Bosrand + open plek met aangestampte aarde. Geen lucht: zoals in de referentie
    vult een getextureerde 'wand' (hier dicht naaldbos) de bovenkant, daaronder de vloer
    (donker achteraan, lichter naar voren)."""
    img = Image.new("RGBA", (w, h), LEAF[0])
    px = img.load()
    rnd = random.Random(42)
    horizon = 82
    # 1) bos in 3 lagen: achter klein/donker, voor groot/lichter; gaten blijven bijna zwart-groen
    layers = [(40, 34, 7, 8, LEAF[0:5]), (62, 44, 9, 12, LEAF[0:5]), (horizon + 4, 52, 12, 15, LEAF[1:6])]
    for base_y, height, half_w, step, shades in layers:
        x = -rnd.randrange(step)
        while x < w + step:
            hh = height + rnd.randrange(-8, 9)
            draw_pine(px, w, h, x, base_y + rnd.randrange(-3, 4), hh, half_w + rnd.uniform(-2, 2), shades, rnd)
            x += step + rnd.randrange(-3, 4)
    # 2) varens/struikjes aan de voet van het bos
    for _ in range(70):
        bx, by = rnd.randrange(w), horizon + rnd.randrange(-2, 3)
        for k in range(rnd.randrange(4, 9)):
            x, y = bx + rnd.randrange(-6, 7), by - rnd.randrange(0, 5)
            if 0 <= x < w and 0 <= y < h:
                px[x, y] = rnd.choice((GRASS[3], GRASS[4], LEAF[4]))
    # 3) vloer: aarde, donker achteraan -> lichter vooraan, horizontale streepjes (perspectief)
    for y in range(horizon + 3, h):
        t = (y - horizon) / (h - horizon)
        base_i = 1 if t < 0.2 else (2 if t < 0.5 else 3)
        for x in range(w):
            r = rnd.random()
            c = DIRT[base_i]
            if r < 0.16:
                c = DIRT[base_i - 1]
            elif r < 0.27:
                c = DIRT[base_i + 1]
            px[x, y] = c
        for _ in range(int(14 + t * 36)):
            x0 = rnd.randrange(w)
            ln = rnd.randrange(3, 6 + int(t * 10))
            col = DIRT[base_i + 1] if rnd.random() < 0.55 else DIRT[base_i - 1]
            for k in range(ln):
                if x0 + k < w:
                    px[x0 + k, y] = col
    # 4) overgang bos -> vloer: schaduwstrook en hier en daar een graspol
    for y in range(horizon, horizon + 7):
        for x in range(w):
            if rnd.random() < 1.0 - (y - horizon) / 7.0:
                px[x, y] = DIRT[0]
    for _ in range(40):
        gx, gy = rnd.randrange(w), rnd.randrange(horizon + 8, h - 4)
        for k in range(rnd.randrange(3, 7)):
            x = gx + k - 3
            if 0 <= x < w:
                px[x, gy] = GRASS[2]; px[x, gy - (k % 2)] = GRASS[3]
                px[x, gy + 1] = DIRT[0]
    return img


# ---------------------------------------------------------------- UI-vensters (9-slice)
def make_window():
    """12x12, marge 4: buitenrand donker, 2 px lichte lavendelrand, vlak diepblauw.
    Hoekjes afgerond (de 'o' hoekpixels blijven doorzichtig)."""
    rows = [
        "..oooooooo..",
        ".oBBBBBBBBo.",
        "oBBbbbbbbBBo",
        "oBbiiiiiibBo",
        "oBbiffffibBo",
        "oBbiffffibBo",
        "oBbiffffibBo",
        "oBbiffffibBo",
        "oBbiiiiiibBo",
        "oBBbbbbbbBBo",
        ".oBBBBBBBBo.",
        "..oooooooo..",
    ]
    pal = {"o": hexc("0a0820"), "B": hexc("d8d2e2"), "b": hexc("9c96b4"),
           "i": hexc("120c62"), "f": hexc("1a1280")}
    return _render_ui(rows, pal)


def make_status_panel():
    """12x12, marge 4: leisteenblauw vak met reliëf (licht linksboven, donker rechtsonder)."""
    rows = [
        ".oooooooooo.",
        "oLLLLLLLLLLo",
        "oLlllllllldo",
        "oLlffffffddo",
        "oLlffffffddo",
        "oLlffffffddo",
        "oLlffffffddo",
        "oLlffffffddo",
        "oLlffffffddo",
        "oLddddddddDo",
        "oDDDDDDDDDDo",
        ".oooooooooo.",
    ]
    pal = {"o": hexc("080c18"), "L": hexc("6a7e8c"), "l": hexc("3c5272"),
           "f": hexc("2a4264"), "d": hexc("1e3048"), "D": hexc("142236")}
    return _render_ui(rows, pal)


def _render_ui(rows, pal):
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = pal[ch]
    return im


# ---------------------------------------------------------------- helden in gevechten (32x32)
# Elke held heeft een strook van 8 frames van 32x32 (256x32):
#   0 stil   1 klaar (aan de beurt)   2 aanval A (uithalen)   3 aanval B (slaan)
#   4 spreuk A (arm omhoog)   5 spreuk B (met glinstering)   6 geraakt   7 KO (liggend)
# Gezien van schuin achteren, kijkend naar rechts (naar de vijanden).
# Het lijf is getekend zonder omlijning; de omlijning (1 px, donker, niet zwart) wordt
# automatisch toegevoegd. Arm + wapen zijn een aparte laag per frame, met een eigen
# omlijning, zodat ze ook vóór het lijf goed leesbaar blijven.
BF = 32                     # framegrootte
BODY_OFF = (4, 1)           # waar het lijf (24x30) in het frame staat
SHOULDER = (20, 16)         # schouder van de wapenarm (in frame-coördinaten)
HERO_OUTLINE = hexc("1c1a14")

DENNIS_BODY = [
    "",
    ".........hhhhh",
    ".......hhHHHhhhh",
    "......hHHhhhhhhhh",
    ".....hHhhhhhhhhhhh",
    ".....hhhhhhhhhhhhhd",
    "....hhhdhhhhhhhhhhd",
    "....hhhhdhhhhhhhhsd",
    "....dhhhhdhhhhhhssS",
    "....dhhhhhdhhhhhssS",
    ".....dhhhhhhhhhhssS",
    ".....ddhhhhhhhhdSS",
    "......ddhhhhhhdd",
    ".......yyyyyyyyY",
    "......LyyyyyyyyYY",
    ".....LLcccccccccC",
    ".....LccccccccccC",
    ".....LcccccccccCC",
    "....sLcccccccccC",
    "......bbbbbbbbbb",
    "......cccccccccC",
    "......LcccccccCC",
    "......pppp..pppP",
    "......pppp..pppP",
    "......ppPP..ppPP",
    "......pPPP..pPPP",
    "......kkkk..kkkK",
    ".....kkkkk..kkkkK",
    ".....KKKKK..KKKKK",
    "",
]
NOOR_BODY = [
    "..........ww",
    ".........wwW",
    "........wwwW",
    "........wwwWW",
    ".......wwwwWW",
    ".......wwwwwWW",
    "......wwwwwwWWW",
    ".....ggggggggggg",
    "...wwwwwwwwwwwwwwWW",
    "....nnnnnnnnnnnnsS",
    "....nnnnnnnnnnnssS",
    "....nNnnnnnnnnnsS",
    ".....nNnnnnnnnnS",
    ".....nnyyyyyyyyY",
    ".....nnrrrrrrrrRR",
    ".....nnrrrrrrrrrR",
    ".....LnrrrrrrrrrR",
    "....sLrrrrrrrrrRR",
    ".....LrrrrrrrrrrR",
    ".....LrrrrrrrrrrRR",
    "....LLrrrrrrrrrrRR",
    "....LrrrrrrrrrrrRR",
    "....LrrrrrrrrrrrRRR",
    "....LrrrrrrrrrrrRRR",
    "...LLrrrrrrrrrrrRRR",
    "...LrrrrrrrrrrrrRRR",
    "...RRRRRRRRRRRRRRRR",
    "......kk....kkk",
    "......KK....KKK",
    "",
]
LOTTE_BODY = [
    "",
    ".........hhhhh",
    ".......hhHHHhhhh",
    "......hHHhhhhhhhh",
    ".....hHhhhhhhhhhhh",
    ".....hhhhhhhhhhhhhd",
    "....gggggggggggggggd",
    "....hhhhdhhhhhhhhsd",
    "....dhhhhdhhhhhhssS",
    "....dhhhhhdhhhhhssS",
    ".....dhhhhhhhhhhssS",
    ".....ddhhhhhhhhdSS",
    "......ddhhHhhhdd",
    ".......wwwhHwwwwW",
    "......LwwwhhwwwwWW",
    ".....LLwwwhHwwwwwW",
    ".....LwwwwhhwwwwwW",
    ".....LwwwwdhwwwwWW",
    "....sLwwwwwdwwwwW",
    "......ggggggggggg",
    ".....LwwwwwwwwwwWW",
    ".....LwwwwwwwwwwWW",
    "....LwwwwwwwwwwwWW",
    "....LwwwwwwwwwwwWWW",
    "....LwwwwwwwwwwwWWW",
    "....gggggggggggggggg",
    "......kk....kkk",
    "......KK....KKK",
    "",
    "",
]

BATTLE_HEROES = {
    # naam: (lijf, palet, mouwkleur, wapen)
    "dennis": (DENNIS_BODY, dict(SKIN, **{
        "h": hexc("7a4426"), "H": hexc("a8683c"), "d": hexc("4c2816"),
        "y": hexc("d6a83c"), "Y": hexc("9a7424"),
        "c": hexc("3f7434"), "C": hexc("2a5126"), "L": hexc("5f9648"),
        "b": hexc("6a4422"), "p": hexc("5a4a3a"), "P": hexc("3e3228"),
        "k": hexc("4a2e18"), "K": hexc("2e1c0e")}), hexc("3f7434"), "zwaard"),
    "noor": (NOOR_BODY, dict(SKIN, **{
        "w": hexc("3a2a6e"), "W": hexc("261a4a"), "g": hexc("d6a83c"),
        "n": hexc("2e2a48"), "N": hexc("4a4670"), "y": hexc("d6a83c"), "Y": hexc("9a7424"),
        "r": hexc("2c3a78"), "R": hexc("1c2650"), "L": hexc("44589a"),
        "k": hexc("4a2e18"), "K": hexc("2e1c0e")}), hexc("2c3a78"), "toverstaf"),
    "lotte": (LOTTE_BODY, dict(SKIN, **{
        "h": hexc("c89a48"), "H": hexc("e8c470"), "d": hexc("8a6428"),
        "g": hexc("4a7a3a"), "w": hexc("e4dcc6"), "W": hexc("b2a68c"), "L": hexc("f6f2e4"),
        "k": hexc("6a4422"), "K": hexc("4a2e16")}), hexc("e4dcc6"), "levensstaf"),
}

# Per frame: (verschuiving van het lijf, handpositie, hoek van het wapen in graden
# (0 = naar rechts, 90 = recht omhoog), extra effect)
HERO_POSES = {
    "zwaard": [((0, 0), (23, 21), 60, None), ((1, 0), (25, 19), 30, None),
               ((-1, 0), (18, 10), 120, None), ((1, 0), (26, 20), -30, "zwaai"),
               ((0, 0), (22, 12), 90, None), ((0, 0), (22, 12), 90, "glinster"),
               ((-2, 1), (21, 21), 80, None)],
    "staf":   [((0, 0), (23, 20), 95, None), ((1, 0), (25, 18), 75, None),
               ((-1, 0), (19, 11), 135, None), ((1, 0), (26, 19), 10, "zwaai"),
               ((0, 0), (23, 13), 80, None), ((0, 0), (23, 13), 80, "glinster"),
               ((-2, 1), (21, 20), 105, None)],
}


def _rows_to_image(rows, pal, w=24, h=30):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows[:h]):
        for x, ch in enumerate(row.ljust(w, ".")[:w]):
            if ch != ".":
                px[x, y] = pal[ch]
    return im


def _outline_rgba(img, color):
    """1 px omlijning rond alles wat niet doorzichtig is (in hetzelfde plaatje)."""
    px = img.load()
    w, h = img.size
    solid = [[px[x, y][3] > 200 for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                continue
            if any(0 <= nx < w and 0 <= ny < h and solid[ny][nx]
                   for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                px[x, y] = color
    return img


def _weapon_layer(kind, hand, angle, sleeve):
    """Arm (schouder -> hand) + wapen, op een eigen laag."""
    import math
    lay = Image.new("RGBA", (BF, BF), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.line([SHOULDER, hand], fill=sleeve, width=2)
    dx, dy = math.cos(math.radians(angle)), -math.sin(math.radians(angle))
    hx, hy = hand
    if kind == "zwaard":
        tip = (hx + dx * 12, hy + dy * 12)
        d.line([(hx - dx * 3, hy - dy * 3), (hx, hy)], fill=hexc("5a3a1c"), width=2)          # gevest
        d.line([(hx + dx, hy + dy), tip], fill=hexc("c8ccd8"), width=2)                       # kling
        d.line([(hx + dx * 2 - dy * 0.6, hy + dy * 2 + dx * 0.6), tip], fill=hexc("f2f4fa"), width=1)
        d.line([(hx - dy * 2.5, hy + dx * 2.5), (hx + dy * 2.5, hy - dx * 2.5)], fill=hexc("c8a040"), width=1)
    else:
        top = (hx + dx * 11, hy + dy * 11)
        d.line([(hx - dx * 7, hy - dy * 7), top], fill=hexc("6a4422"), width=1)              # schacht
        tx, ty = min(max(round(top[0]), 3), BF - 4), min(max(round(top[1]), 3), BF - 4)
        if kind == "toverstaf":
            d.ellipse((tx - 2, ty - 2, tx + 2, ty + 2), fill=hexc("e89a3a"))                 # bol
            lay.putpixel((tx - 1, ty - 1), hexc("fff0c0"))
        else:
            d.polygon([(tx, ty - 3), (tx + 2, ty), (tx, ty + 2), (tx - 2, ty)], fill=hexc("5ab878"))  # blad/kristal
            lay.putpixel((tx - 1, ty - 1), hexc("d8f8e0"))
    d.rectangle((hx - 1, hy - 1, hx, hy), fill=SKIN["s"])                                     # hand
    return _outline_rgba(lay, HERO_OUTLINE), (dx, dy)


def _tip_of(kind, hand, dxdy):
    n = 12 if kind == "zwaard" else 11
    return (round(hand[0] + dxdy[0] * n), round(hand[1] + dxdy[1] * n))


def _ground_shadow(frame, rx=9, cx=15.5, cy=29.5):
    sh = Image.new("RGBA", (BF, BF), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((cx - rx, cy - 2.2, cx + rx, cy + 2.2), fill=(10, 8, 6, 130))
    sh.alpha_composite(frame)
    return sh


def make_battle_hero(key):
    body_rows, pal, sleeve, weapon = BATTLE_HEROES[key]
    body = _rows_to_image(body_rows, pal)
    poses = HERO_POSES["zwaard" if weapon == "zwaard" else "staf"]
    sheet = Image.new("RGBA", (BF * 8, BF), (0, 0, 0, 0))
    for i, (shift, hand, angle, fx) in enumerate(poses):
        fr = Image.new("RGBA", (BF, BF), (0, 0, 0, 0))
        fr.paste(body, (BODY_OFF[0] + shift[0], BODY_OFF[1] + shift[1]), body)
        _outline_rgba(fr, HERO_OUTLINE)
        hand2 = (hand[0] + shift[0], hand[1] + shift[1])
        lay, dxdy = _weapon_layer(weapon, hand2, angle, sleeve)
        fr.alpha_composite(lay)
        d = ImageDraw.Draw(fr)
        if fx == "zwaai":                              # lichte zwaaiboog
            d.arc((12, 2, 36, 30), start=-80, end=25, fill=(236, 240, 255, 190), width=1)
        elif fx == "glinster":                         # sterretje bij de punt
            tx, ty = _tip_of(weapon, hand2, dxdy)
            tx, ty = min(max(tx, 3), BF - 4), min(max(ty, 3), BF - 4)
            for ox, oy in ((0, -3), (0, 3), (-3, 0), (3, 0)):
                d.point((tx + ox, ty + oy), fill=(255, 246, 190, 255))
            for ox, oy in ((-2, -2), (2, -2), (-2, 2), (2, 2)):
                d.point((tx + ox, ty + oy), fill=(255, 220, 120, 200))
        sheet.alpha_composite(_ground_shadow(fr), (i * BF, 0))
    # KO: lijf op de grond (90 graden gedraaid, hoofd naar links), zonder wapen
    lying = body.rotate(90, expand=True)              # 30 breed x 24 hoog
    bbox = lying.getbbox()
    lying = lying.crop(bbox)
    fr = Image.new("RGBA", (BF, BF), (0, 0, 0, 0))
    fr.paste(lying, ((BF - lying.width) // 2, 30 - lying.height), lying)
    _outline_rgba(fr, HERO_OUTLINE)
    sheet.alpha_composite(_ground_shadow(fr, rx=14, cy=29.5), (7 * BF, 0))
    return sheet


def make_glass_window():
    """12x12, marge 4: half-doorzichtig 'glazen' venster voor het overwinningsscherm."""
    rows = [
        "..oooooooo..",
        ".oBBBBBBBBo.",
        "oBBbbbbbbBBo",
        "oBbffffffbBo",
        "oBbffffffbBo",
        "oBbffffffbBo",
        "oBbffffffbBo",
        "oBbffffffbBo",
        "oBbffffffbBo",
        "oBBbbbbbbBBo",
        ".oBBBBBBBBo.",
        "..oooooooo..",
    ]
    pal = {"o": hexc("0a0820", 200), "B": hexc("c8d8ec"), "b": hexc("6a86a8", 230),
           "f": hexc("10224e", 182)}
    return _render_ui(rows, pal)


def _handwerk_lijst():
    """Paden uit tools/handwerk.txt: handgemaakte art die niet overschreven mag worden."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "handwerk.txt")
    if not os.path.exists(path):
        return []
    out = []
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line)
    return out


def main():
    import sys
    keep = {}
    if "--ook-handwerk" not in sys.argv:
        # handgemaakte bestanden bewaren en na het genereren terugzetten
        for rel in _handwerk_lijst():
            full = os.path.join(ROOT, rel)
            if os.path.exists(full):
                keep[full] = open(full, "rb").read()
    try:
        _generate_all()
    finally:
        for full, data in keep.items():
            with open(full, "wb") as f:
                f.write(data)
            print("overgeslagen (handwerk, zie tools/handwerk.txt):", os.path.relpath(full, ROOT))


def _generate_all():
    tiles_dir = os.path.join(ROOT, "assets", "tiles")
    spr_dir = os.path.join(ROOT, "assets", "sprites")
    enemy_dir = os.path.join(spr_dir, "enemies")
    battle_dir = os.path.join(ROOT, "assets", "battle")
    ui_dir = os.path.join(ROOT, "assets", "ui")
    for d in (tiles_dir, spr_dir, enemy_dir, battle_dir, ui_dir):
        os.makedirs(d, exist_ok=True)
    make_character(PLAYER_PAL).save(os.path.join(spr_dir, "player.png"))
    make_character(NPC_PAL, "robe").save(os.path.join(spr_dir, "npc.png"))
    make_sign().save(os.path.join(spr_dir, "sign.png"))
    make_window().save(os.path.join(ui_dir, "window.png"))
    make_status_panel().save(os.path.join(ui_dir, "panel_status.png"))
    make_glass_window().save(os.path.join(ui_dir, "window_glass.png"))
    # Project-icoon (128x128): hoofd + bovenlijf van de held op gras
    icon = make_tileset().crop((0, 0, 16, 16))
    hero = make_character(PLAYER_PAL).crop((0, 0, 16, 24)).crop((0, 2, 16, 18))
    icon.alpha_composite(hero)
    icon.resize((128, 128), Image.NEAREST).save(os.path.join(ROOT, "icon.png"))
    # Dorp, huis, wereldkaart en vlakte-achtergrond (zie tools/art_maps.py)
    import art_maps
    art_maps.make_all(ROOT)
    # v7 'De Vergeten Bibliotheek': vensters, gevechtsachtergrond, helden en vijanden
    # (zie docs/ARTSTYLE.md). De vensters hierboven worden daarbij overschreven.
    # tools/art_battle.py en art_battle_bg.py (v6) blijven als bibliotheek/referentie.
    # v8: grotere, warmere helden + nieuwe Papiergeest/Kennis-Beest (art_v8_*).
    import art_v7_ui, art_v7_bg, art_v8_heroes, art_v8_enemies
    art_v7_ui.save_all(ROOT)
    art_v7_bg.save_all(ROOT)
    art_v8_heroes.save_all(ROOT)
    art_v8_enemies.save_all(ROOT)
    # v8: dorp, huis, wereldkaart, figuren en icoon opnieuw in 'Vergeten Bibliotheek'-stijl
    # (zelfde tile-posities; overschrijft de bestanden van art_maps/make_character hierboven).
    # Als laatste, omdat het de paletten van generate_art/art_maps vervangt.
    import art_v8_maps
    art_v8_maps.save_all(ROOT)
    print("Art gegenereerd in assets/")


if __name__ == "__main__":
    main()
