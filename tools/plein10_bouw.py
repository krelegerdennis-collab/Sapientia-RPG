#!/usr/bin/env python3
"""Plein 10 (RPG ART art_10) -> Wilgendal. Maakt assets/sprites/buiten/wilgendal/plein10/layout.json,
bos_rand.png (bosdak-band met openingen voor de straat), gespiegeld smal huis, schaduwen voor oude props,
en zet het blok (40x32 tegels, plein_mockup.png) in GROND van scripts/data/wilgendal_dorp.gd.
Kopieert art alleen als het doelbestand nog niet bestaat (handwerk wordt nooit overschreven).
Gebruik: python3 tools/plein10_bouw.py [/workspace/art_10]"""
import json, math, os, random, re, shutil, sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else '/workspace/art_10'
OUT = os.path.join(SRC, 'out')
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(REPO, 'assets/sprites/buiten/wilgendal/plein10')
OX, OY = 29, 0            # blok linksboven in dorpstegels
TW, TH = 40, 32
GAP_ROWS = (15, 16)       # straat oost-west door de bosrand (blokrijen)
GAP_L, GAP_R = range(0, 3), range(37, 40)
GR = [(16, 28, 24, 255), (28, 52, 36, 255)]
os.makedirs(DST, exist_ok=True)


def L(n):
    return Image.open(os.path.join(OUT, n + '.png')).convert('RGBA')


def kopie(n):
    d = os.path.join(DST, n + '.png')
    if not os.path.exists(d):
        shutil.copy(os.path.join(OUT, n + '.png'), d)


def shadow_of(im, dx=10, dy=4, start=0.4):
    """Zelfde methode als art_10/build10.py shadow_of: masker rechtsonder verschoven, kern GR1, rand gedithered."""
    W, H = im.size; m = im.load()
    W2 = ((W + dx + 15) // 16) * 16; H2 = ((H + dy + 15) // 16) * 16
    inside = lambda x, y: 0 <= x - dx < W and 0 <= y - dy < H and m[x - dx, y - dy][3] and y >= int(H * start)
    obj = lambda x, y: x < W and y < H and m[x, y][3]
    c = Image.new('RGBA', (W2, H2)); p = c.load()
    for y in range(H2):
        for x in range(W2):
            if inside(x, y) and not obj(x, y):
                rim = not all(inside(x + a, y + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if rim:
                    if (x + y) % 2 == 0: p[x, y] = GR[1]
                else: p[x, y] = GR[1] if (x // 2 + y) % 5 else GR[0]
    for x in range(W):
        if m[x, H - 1][3] and H < H2: p[x, H] = GR[0]
    return c


# --- art ---
for n in ('plein_grond_tileset', 'bos_dak_13', 'rook_4f', 'lantaarnpaal_flikker_4f', 'bloemstrook_13', 'bloemstrook_b_13',
          'kar_10', 'kar_10_schaduw', 'wegwijzer_10', 'wegwijzer_10_schaduw', 'hek_10', 'hek_10_schaduw',
          'krat_10', 'krat_10_schaduw', 'krat_klein_10', 'krat_klein_10_schaduw', 'ton_10', 'ton_10_schaduw',
          'zak_10', 'zak_10_schaduw', 'zak_graan_10', 'zak_graan_10_schaduw',
          'bloembed_10', 'bloembed_10_schaduw', 'bloembed_b_10', 'bloembed_b_10_schaduw', 'bloembed_c_10', 'bloembed_c_10_schaduw',
          'struik_10', 'struik_10_schaduw', 'struik_klein_10', 'struik_klein_10_schaduw',
          'steen_10', 'steen_10_schaduw', 'steen_klein_10', 'steen_klein_10_schaduw',
          'dorpeling_blauw', 'dorpeling_rood', 'dorpeling_groen', 'dorpeling_oker', 'dorpeling_oma', 'dorpeling_kind', 'dorpeling_koopman'):
    kopie(n)
if not os.path.exists(os.path.join(DST, 'plein_grond_map.json')):
    shutil.copy(os.path.join(OUT, 'plein_grond_map.json'), DST)
# gespiegeld smal huis (derde pand bovenaan; geen eigen art voor die plek)
sp = L('huis_smal_11').transpose(Image.FLIP_LEFT_RIGHT)
sp.save(os.path.join(DST, 'huis_smal_11_spiegel.png'))
shadow_of(sp, 12, 4, 0.45).save(os.path.join(DST, 'huis_smal_11_spiegel_schaduw.png'))
# schaduwen voor de oude SoM-props en de flikkerlamp (frame 0)
PROPS = os.path.join(REPO, 'assets/sprites/som/wilgendal/props')
for n in ('put', 'bank', 'bloembak', 'lantaarn'):
    shadow_of(Image.open(os.path.join(PROPS, n + '.png')).convert('RGBA'), 6, 3, 0.3).save(os.path.join(DST, 'schaduw_%s.png' % n))
shadow_of(L('lantaarnpaal_flikker_4f').crop((0, 0, 16, 48)), 6, 3, 0.3).save(os.path.join(DST, 'schaduw_lantaarnpaal.png'))

# --- grond (tileset + map van RPG ART) ---
gm = json.load(open(os.path.join(OUT, 'plein_grond_map.json')))
ts = L('plein_grond_tileset'); cols = gm['cols']
grond = Image.new('RGBA', (TW * 16, TH * 16))
for ty, rij in enumerate(gm['map']):
    for tx, i in enumerate(rij):
        grond.alpha_composite(ts.crop(((i % cols) * 16, (i // cols) * 16, (i % cols) * 16 + 16, (i // cols) * 16 + 16)), (tx * 16, ty * 16))
gp = grond.load()


def blauw(tx, ty):
    n = 0
    for y in range(ty * 16, ty * 16 + 16):
        for x in range(tx * 16, tx * 16 + 16):
            r, g, b, a = gp[x, y]
            n += b > r + 20 and b > g
    return n / 256.0


# --- bosdak (mockup10.py: linker/rechter band + bovenband, golvende binnenrand), met de straat-openingen ---
can = L('bos_dak_13'); cp = can.load()
bos = Image.new('RGBA', (TW * 16, TH * 16)); bp = bos.load()
dek = [[0] * TW for _ in range(TH)]


def in_gap(tx, ty):
    return ty in GAP_ROWS and (tx in GAP_L or tx in GAP_R)


for y in range(TH * 16):
    for x in range(TW * 16):
        il = 28 + 8 * math.sin(y / 29) + 4 * math.sin(y / 9); ir = 612 - 8 * math.sin(y / 31) - 4 * math.sin(y / 11)
        top = 40 + 6 * math.sin(x / 23) + 3 * math.sin(x / 7)
        if (x < il or x > ir or y < top) and not in_gap(x // 16, y // 16):
            bp[x, y] = cp[x % 32, y % 32]; dek[y // 16][x // 16] += 1
bos.save(os.path.join(DST, 'bos_rand.png'))

# --- objecten uit mockup10.py (blok-px) ---
DEUR_VOOR = [(4, 12), (12, 12), (19, 12), (28, 12), (30, 28)]   # voor de deuren (blok): wapen, pantser, accessoire, magie, Dax
BRUG_KOL = (19, 20)


def bbox(im):
    return im.getbbox() or (0, 0, im.width, im.height)


def voet_tegels(im, x, y, band=10):
    b = bbox(im); x0, y0, x1, y1 = x + b[0] + 2, y + b[3] - band, x + b[2] - 2, y + b[3]
    uit = []
    for ty in range(y0 // 16, (y1 - 1) // 16 + 1):
        for tx in range(x0 // 16, (x1 - 1) // 16 + 1):
            ox = min(x1, tx * 16 + 16) - max(x0, tx * 16); oy = min(y1, ty * 16 + 16) - max(y0, ty * 16)
            if ox >= 4 and oy >= 3:
                uit.append((tx, ty))
    return uit


rnd = random.Random(5); trees = []
for row, y in enumerate(range(-40, 520, 30)):
    for x in ((-28, -6, 14) if row % 2 else (-18, 4)):
        if x > -20 and -60 < y < 170: continue
        trees.append((x + rnd.randint(-3, 3), y + rnd.randint(-4, 4)))
    for x in ((574, 596, 618) if row % 2 else (586, 608)):
        if not (420 <= x < 612 and 330 < y < 500): trees.append((x + rnd.randint(-3, 3), y + rnd.randint(-4, 4)))
for x in range(40, 580, 26):
    trees.append((x + rnd.randint(-3, 3), -58 + rnd.randint(-4, 6)))
    trees.append((x + 13 + rnd.randint(-3, 3), -40 + rnd.randint(-3, 3)))
for x, y in ((612, 330), (620, 372), (606, 410), (622, 446), (612, 480), (624, 500)): trees.append((x, y))
for x, y in ((40, 380), (196, 372), (250, 486), (400, 420)): trees.append((x, y))
objs = []
for i, (x, y) in enumerate(trees):
    n = ('loofboom_12', 'kegelboom_licht_11', 'loofboom_b_12', 'loofboom_12')[(i * 7 + x // 13) % 4]
    objs.append((n, x + (0 if i % 4 == 1 else -2), y + (16 if i % 4 != 1 else 0), 'boom'))
for x, y in ((-14, 214), (600, 236), (-10, 330), (606, 140), (16, 468), (560, 486)): objs.append(('loofboom_b_12', x, y, 'boom'))
HUIS = ((16, 128), (144, 96), (272, 96), (400, 128))   # blok-px van de vier panden bovenaan (op tegels)
for i, (hx, hw) in enumerate(HUIS):
    objs.append(('bloemstrook_13' if i % 2 else 'bloemstrook_b_13', hx + 8 if hx != 272 else hx + 40, 162, 'vloer'))
    if hw == 128: objs.append(('bloemstrook_b_13' if i % 2 else 'bloemstrook_13', hx + hw - 56, 162, 'vloer'))
for n, x, y in (('krat_10', 150, 250), ('ton_10', 92, 246), ('zak_10', 196, 264), ('zak_graan_10', 206, 270),
                ('kar_10', 84, 286), ('zak_10', 72, 318), ('ton_10', 512, 250), ('krat_10', 530, 268),
                ('bloembed_10', 112, 196), ('bloembed_b_10', 352, 196), ('bloembed_c_10', 538, 196),
                ('wegwijzer_10', 360, 350), ('hek_10', 20, 208), ('hek_10', 572, 208),
                ('struik_10', 4, 250), ('struik_klein_10', 560, 330), ('struik_10', 150, 400), ('struik_klein_10', 400, 372), ('struik_10', 150, 486),
                ('steen_10', 120, 372), ('steen_klein_10', 520, 410), ('steen_10', 580, 474), ('steen_klein_10', 40, 476)):
    objs.append((n, x, y, 'prop'))

# --- tekenkaart blok: W bosdak (dicht), ~ beek, B brug, . land ---
kaart = [['.'] * TW for _ in range(TH)]
for ty in range(TH):
    for tx in range(TW):
        if dek[ty][tx] >= 128: kaart[ty][tx] = 'W'
        elif blauw(tx, ty) >= 0.10: kaart[ty][tx] = '~'
# brug (blok-px 296..344, 450..498): kolommen 19-20 over de beek beloopbaar
brug = [(tx, ty) for ty in range(TH) for tx in BRUG_KOL if kaart[ty][tx] == '~']
for tx, ty in brug: kaart[ty][tx] = 'B'
# beek dicht tot aan de bosrand (geen lekken langs de oever)
decor = []; bezet = set()
for n, x, y, soort in objs:
    im = L(n)
    if y + im.height < 8 or x + im.width < 0 or x > TW * 16: continue
    vast = []
    if soort == 'boom':
        b = bbox(im); ft = ((x + (b[0] + b[2]) // 2) // 16, (y + b[3] - 4) // 16)
        if not (0 <= ft[0] < TW and 0 <= ft[1] < TH): ft = None
        if ft and in_gap(*ft): continue          # geen boom in de straat-opening
        if ft and kaart[ft[1]][ft[0]] == '.': vast = [ft]
    elif soort == 'prop':
        vast = [t for t in voet_tegels(im, x, y) if 0 <= t[0] < TW and 0 <= t[1] < TH and kaart[t[1]][t[0]] == '.']
    for t in vast:
        assert t not in DEUR_VOOR and t[0] not in BRUG_KOL or t[1] < 25, (n, t)
    bezet.update(vast)
    sch = n + '_schaduw' if os.path.exists(os.path.join(OUT, n + '_schaduw.png')) else ''
    if sch: kopie(sch)
    kopie(n)
    decor.append({'file': n + '.png', 'x': x + OX * 16, 'y': y + OY * 16, 'soort': soort,
                  'schaduw': (sch + '.png') if sch else '', 'vast': [[tx + OX, ty + OY] for tx, ty in vast],
                  'voet': y + OY * 16 + bbox(im)[3]})
# rook op de schoorstenen (bovenste ondoorzichtige kolommen van het pand), anker onder-midden (x+11, y+46)
rook = []
for n, hx, hy in (('wilgendal_wapen_11', 16, 32), ('huis_smal_11', 144, 32), ('huis_smal_11_spiegel', 272, 32), ('huis_dax_11', 432, 288)):
    im = Image.open(os.path.join(DST, n + '.png')) if n.endswith('spiegel') else L(n)
    for yy in range(im.height):
        xs = [x for x in range(im.width) if im.getpixel((x, yy))[3]]
        if xs: break
    cx = (xs[0] + xs[-1]) // 2
    rook.append({'x': hx + cx - 11 + OX * 16, 'y': hy + yy - 46 + OY * 16})
lay = {'ox': OX, 'oy': OY, 'w': TW, 'h': TH, 'kaart': [''.join(r) for r in kaart], 'decor': decor, 'rook': rook,
       'brug_px': [296 + OX * 16, 450 + OY * 16]}
json.dump(lay, open(os.path.join(DST, 'layout.json'), 'w'), indent=1)

# --- GROND in wilgendal_dorp.gd: blok erin ---
gd = os.path.join(REPO, 'scripts/data/wilgendal_dorp.gd'); s = open(gd).read()
a = s.index('const GROND: Array[String] = [\n') + len('const GROND: Array[String] = [\n'); b = s.index(']\n', a)
rijen = [l.strip().strip(',').strip('"') for l in s[a:b].strip().split('\n')]
for ty in range(TH):
    r = list(rijen[ty + OY])
    for tx in range(TW):
        r[tx + OX] = kaart[ty][tx]
    rijen[ty + OY] = ''.join(r)
s = s[:a] + ''.join('\t"%s",\n' % r for r in rijen) + s[b:]
open(gd, 'w').write(s)
print('blok', OX, OY, 'decor', len(decor), 'vast', len(bezet), 'brug', brug, 'rook', rook)
for r in kaart: print(''.join(r))
