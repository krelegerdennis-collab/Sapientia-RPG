"""Bakt de v8-stadsgrond van RPG ART (maps_test/town8.py / wil.py, goedgekeurd 20 okt 2026) voor Dorp
Wilgendal op de 1.4x-kaart (scripts/data/wilgendal_dorp.gd, GROND). Tekent zelf niets: draait de
terrain-generator en de gras-passes van RPG ART en knipt het resultaat in unieke 16x16-tegels.
Uit: assets/tilesets/som/wilgendal/grond_v8.png (atlas, 64 tegels breed) + grond_v8.json (tegel per cel).
Gebruik: PYTHONHASHSEED=0 python3 tools/som/wilgendal_v8_grond.py [pad/naar/art_mapsprites_v4/maps_test]
"""
import sys, os, re, json, math
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ART = sys.argv[1] if len(sys.argv) > 1 else '/workspace/art_mapsprites_v4/maps_test'
assert os.environ.get('PYTHONHASHSEED') == '0', 'zet PYTHONHASHSEED=0 (rnd() van RPG ART gebruikt hash())'
sys.path.insert(0, ART); os.chdir(ART)
import numpy as np
import heroes
from props5 import *
from PIL import Image, ImageOps
src = open(os.path.join(REPO, 'scripts/data/wilgendal_dorp.gd')).read()
blok = re.search(r'const GROND: Array\[String\] = \[\n(.*?)\n\]', src, re.S).group(1)
rows = re.findall(r'"([^"]*)"', blok)
Hh, W = len(rows), len(rows[0])
SOORT = {'=': 'path', 'B': 'path', '#': 'plaza'}
G = [['grass'] * (W + 1) for _ in range(Hh + 1)]
for y in range(Hh):
    for x in range(W):
        s = SOORT.get(rows[y][x])
        if s:
            for j in (0, 1):
                for i in (0, 1):
                    if G[y + j][x + i] != 'plaza':
                        G[y + j][x + i] = s
cv = ground(G, W, Hh)
PW, PH = W * 16, Hh * 16
# --- gras-passes: letterlijk zoals wil.py / town8.py (RPG ART) ---
for y in range(PH):
    for x in range(PW):
        c = cv.p[x, y]
        if c not in {GR[2], GR[3], GR[4]}: continue
        m = pnoise(x, y, 5, 128, 32); d = (x + y) % 2
        if m > 0.68 and d and c == GR[3]: c = GR[4]
        if m < 0.30 and d and c == GR[3]: c = GR[2]
        lx, ly = x % 32, y % 32
        for (bx, by_) in ((4, 6), (19, 3), (11, 17), (26, 22), (6, 27)):
            if (lx, ly) in ((bx, by_), (bx + 2, by_)): c = GR[5] if m > 0.5 else GR[4]
            if (lx, ly) in ((bx + 1, by_ + 1), (bx, by_ + 1), (bx + 2, by_ + 1)): c = GR[2] if m > 0.3 else GR[1]
        cv.p[x, y] = c
def binnen(tx, ty): return all(G[ty + j][tx + i] == 'grass' for j in (0, 1) for i in (0, 1))
for ty in range(Hh):
    for tx in range(W):
        if binnen(tx, ty):
            h = rnd('g', tx, ty).randrange(7)
            if h < 3: heroes.blit(cv, ['t_grass1', 't_grass2', 't_grass3'][h], tx * 16, ty * 16)
inter = [(tx, ty) for ty in range(Hh) for tx in range(W) if binnen(tx, ty)]
plain = []; over = []
for (tx, ty) in inter:
    (over if rnd('g', tx, ty).randrange(7) < 3 else plain).append((tx, ty))
allp = [cv.im.crop((x * 16, y * 16, x * 16 + 16, y * 16 + 16)) for x, y in plain]
lum = [np.asarray(a).mean() for a in allp]; med = np.median(lum)
order = sorted(range(len(allp)), key=lambda i: abs(lum[i] - med))
canon_p = [allp[i] for i in order[:240:12]]
canon_p += [ImageOps.mirror(a) for a in canon_p]
HV = [["................","....k.k.........","...jkjk.........","....jj..........","................","..........l.....",".........kjk....","..........j.....","................","................",".....h..........","....hih.........","................","...........k.k..","..........jkjk..","................"],
["................","..h.............","..ih.....k......","..ih....kj......","........j.......","................","......l.........",".....kjk........","......j.........","................","..............h.","............hih.","............ii..","................","...k............","................"],
["................","................","......x.........",".....xYx........","......x.........","................","................","................","..........k.....",".........jkj....","................","................","...l............","..kjk...........","................","................"]]
def hv(i, base):
    im = base.copy(); p = im.load()
    for y, r in enumerate(HV[i]):
        for x, ch in enumerate(r):
            if heroes.L.get(ch): p[x, y] = heroes.L[ch]
    return im
canon_o = [cv.im.crop((x * 16, y * 16, x * 16 + 16, y * 16 + 16)) for x, y in over[1:200:60][:3]]
canon_o += [hv(i, canon_p[i * 3]) for i in range(3)]
for (tx, ty) in inter:
    r = rnd('g2', tx, ty); h = rnd('g', tx, ty).randrange(7)
    cv.im.paste(canon_o[r.randrange(len(canon_o))] if h < 3 else canon_p[r.randrange(len(canon_p))], (tx * 16, ty * 16))
cv.p = cv.im.load()
for y in range(PH):
    for x in range(PW):
        if not binnen(x // 16, y // 16): continue
        m = 0.5 + 0.28 * math.sin(x / 53.0 + y / 71.0) + 0.22 * math.sin(y / 37.0 - x / 91.0 + 1.7) + 0.1 * math.sin((x + y) / 23.0)
        c = cv.p[x, y]
        if m > 0.86 and (x + y) % 2 and c == GR[3]: c = GR[4]
        elif m > 0.95 and c == GR[3]: c = GR[4]
        elif m < 0.16 and (x + y) % 2 and c in (GR[3], GR[4]): c = GR[2]
        elif m < 0.06 and c == GR[3]: c = GR[2]
        cv.p[x, y] = c
# --- unieke tegels -> atlas ---
KOL = 64
uniek = {}; tegels = []; cellen = []
for ty in range(Hh):
    for tx in range(W):
        t = cv.im.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16))
        k = t.tobytes()
        if k not in uniek:
            uniek[k] = len(tegels); tegels.append(t)
        cellen.append(uniek[k])
rij = (len(tegels) + KOL - 1) // KOL
atlas = Image.new('RGBA', (KOL * 16, rij * 16))
for i, t in enumerate(tegels): atlas.paste(t, ((i % KOL) * 16, (i // KOL) * 16))
assert atlas.width <= 2048 and atlas.height <= 2048, atlas.size
uit = os.path.join(REPO, 'assets/tilesets/som/wilgendal/')
atlas.save(uit + 'grond_v8.png')
json.dump({'bron': 'RPG ART v8 (town8.py/wil.py), gebakken door tools/som/wilgendal_v8_grond.py',
           'w': W, 'h': Hh, 'kolommen': KOL, 'uniek': len(tegels), 'cellen': cellen},
          open(uit + 'grond_v8.json', 'w'), separators=(',', ':'))
cv.im.save('/tmp/s14/wil14_v8_grond.png')
print('kaart %dx%d, unieke tegels %d, atlas %dx%d' % (W, Hh, len(tegels), atlas.width, atlas.height))
