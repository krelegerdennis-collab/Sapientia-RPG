"""Esdoorn (Mapleton) 1.4x: 34x24 -> 48x34 met dezelfde rij/kolom-verdubbeling als Dorp Wilgendal
(docs/MAP_SCALE_PLAN.md). Nooit verdubbeld: pad-, hek-, deur-, huis-, vijver- en uitgangsrijen/-kolommen.
Daarna worden de twee 1 tegel brede paden 2 breed (hoofdweg + zuidpad), zoals in het plan (2-3 breed).
Schrijft scenes/maps/esdoorn.tscn over (Ground, Gebouwen en alle posities). Eenmalig: weigert een
kaart die al 48x34 is. Gebruik: python3 tools/som/esdoorn_1p4.py
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import tscn_tegels as tt
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PAD = os.path.join(REPO, 'scenes/maps/esdoorn.tscn')
W, H = 34, 24
RIJEN = {0, 1, 2, 11, 15, 17, 18, 19, 20, 21}
KOLOMMEN = {0, 1, 2, 3, 4, 10, 12, 13, 19, 20, 22, 23, 31, 32}
def X(x): return x + sum(1 for k in KOLOMMEN if k < x)
def Y(y): return y + sum(1 for r in RIJEN if r < y)
def Xl(x): return X(x) + (1 if x in KOLOMMEN else 0)
def Yl(y): return Y(y) + (1 if y in RIJEN else 0)
NW, NH = X(W), Y(H)

src = open(PAD).read()
g = tt.lees(src, 'Ground'); b = tt.lees(src, 'Gebouwen')
xs = [k[0] for k in g]; ys = [k[1] for k in g]
assert (max(xs) + 1, max(ys) + 1) == (W, H), 'kaart is niet 34x24 (al geschaald?)'
for (x, y) in b:
    assert x not in KOLOMMEN and y not in RIJEN, ('huis op een verdubbelde rij/kolom', x, y)

def bron_x(nx):
    for x in range(W):
        if X(x) <= nx <= Xl(x): return x, nx != X(x)
def bron_y(ny):
    for y in range(H):
        if Y(y) <= ny <= Yl(y): return y, ny != Y(y)

ng = {}
for ny in range(NH):
    for nx in range(NW):
        (x, kx), (y, ky) = bron_x(nx), bron_y(ny)
        c = g[(x, y)]
        if (kx or ky) and c[1] in (52, 53):   # geen dubbele tonnen/bloembakken
            buren = [tt.soort(g.get((x + dx, y + dy), (0, 0))[1]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            c = (0, 33 if '#' in buren else 0, 0, 0)
        ng[(nx, ny)] = c
nb = {(X(x), Y(y)): v for (x, y), v in b.items()}

# paden 2 breed: hoofdweg (rij 10) krijgt de eerste kopie van rij 11 erbij, zuidpad (kolom 16) kolom 17
for nx in range(X(7), X(26) + 1):
    if tt.soort(ng[(nx, Y(11))][1]) == '.': ng[(nx, Y(11))] = (0, 2, 0, 0)
for ny in range(Y(16), Yl(21) + 1):
    if tt.soort(ng[(X(17), ny)][1]) == '.': ng[(X(17), ny)] = (0, 2, 0, 0)
# padranden opnieuw kiezen (2 = pad, 10 + masker N1 E2 S4 W8 = kant met gras)
def is_pad(t):
    c = ng.get(t)
    return c is None or tt.soort(c[1]) in '=#'
for (nx, ny), c in list(ng.items()):
    if tt.soort(c[1]) != '=': continue
    m = sum(bit for bit, (dx, dy) in ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0))) if not is_pad((nx + dx, ny + dy)))
    ng[(nx, ny)] = (0, 2 if m == 0 else 10 + m, 0, 0)
src = tt.schrijf(src, 'Ground', ng)
src = tt.schrijf(src, 'Gebouwen', nb)

# posities: punten op de eerste kopie; deuren/bordjes/put met de onderrand (laatste kopie)
ONDER = ('Deur_', 'Put', 'Bord')
def zet(m):
    naam, blok = m.group(1), m.group(0)
    pm = re.search(r'position = Vector2\(([-\d.]+), ([-\d.]+)\)', blok)
    if not pm: return blok
    px, py = float(pm.group(1)), float(pm.group(2))
    tx, ty = int(px // 16), int(py // 16)
    nx = X(tx) * 16 + (px - tx * 16)
    ny = (Yl(ty) if naam.startswith(ONDER) else Y(ty)) * 16 + (py - ty * 16)
    if naam == 'WortelGreep':   # de wortels grijpen op de tegel waar Vesper naartoe loopt (1 onder haar)
        ny = (Y(15) + 1) * 16 + 8
    return blok[:pm.start()] + 'position = Vector2(%g, %g)' % (nx, ny) + blok[pm.end():]
src = re.sub(r'\[node name="([^"]+)"[^\n]*\](?:\n(?!\[)[^\n]*)*', zet, src)
open(PAD, 'w').write(src)
print('esdoorn %dx%d -> %dx%d' % (W, H, NW, NH))
for n, (x, y) in {'speler ontmoeting': (16, 21), 'Vesper': (16, 15), 'Marit': (19, 14), 'voor_noor': (7, 9), 'plein': (14, 14)}.items():
    print(n, (x, y), '->', (X(x), Y(y)))
