"""Wachtershuis-erf (wilgendal.tscn, 'House at the Wood's Edge', proloog) 1.4x: 32x22 -> 45x31 met dezelfde
rij/kolom-verdubbeling als Dorp Wilgendal en Esdoorn (docs/MAP_SCALE_PLAN.md). Nooit verdubbeld: huis
(kolom 14-18, rij 2-6), deurrij 6, keienplein voor het huis (rij 7-8), padkolom 15 en uitgang (rij 21,
kolom 14-16), ruines/Archief-ingang (kolom 23-28, rij 2-5), put (kolom 9-10) en de vijverrijen 12-13.
Daarna wordt het 1 tegel brede tuinpad (kolom 15) 2 breed; de uitgang blijft 3 breed.
Het interieur (huis_wilgendal.tscn) wordt niet geschaald. Eenmalig: weigert een kaart die al 45x31 is.
Gebruik: python3 tools/som/wachtershuis_1p4.py
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import tscn_tegels as tt
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PAD = os.path.join(REPO, 'scenes/maps/wilgendal.tscn')
W, H = 32, 22
RIJEN = {0, 1, 10, 11, 14, 15, 16, 17, 18}
KOLOMMEN = {0, 1, 2, 3, 4, 5, 6, 11, 21, 22, 29, 30, 31}
def X(x): return x + sum(1 for k in KOLOMMEN if k < x)
def Y(y): return y + sum(1 for r in RIJEN if r < y)
def Xl(x): return X(x) + (1 if x in KOLOMMEN else 0)
def Yl(y): return Y(y) + (1 if y in RIJEN else 0)
NW, NH = X(W), Y(H)

if __name__ == '__main__':
    src = open(PAD).read()
    g = tt.lees(src, 'Ground'); b = tt.lees(src, 'Gebouwen')
    xs = [k[0] for k in g]; ys = [k[1] for k in g]
    assert (max(xs) + 1, max(ys) + 1) == (W, H), 'kaart is niet 32x22 (al geschaald?)'
    for (x, y) in b:
        assert x not in KOLOMMEN and y not in RIJEN, ('huis op een verdubbelde rij/kolom', x, y)

    def bron(n, N, F, Fl):
        for v in range(N):
            if F(v) <= n <= Fl(v): return v, n != F(v)
    ng = {}
    for ny in range(NH):
        for nx in range(NW):
            (x, kx), (y, ky) = bron(nx, W, X, Xl), bron(ny, H, Y, Yl)
            c = g[(x, y)]
            if c[1] == 7 and y == 1 and not ky:
                c = (0, 3, 0, 0)       # rotsrij achter de ruines niet dubbel: bomen op de eerste kopie, rotsen tegen de ruines
            ng[(nx, ny)] = c
    nb = {(X(x), Y(y)): v for (x, y), v in b.items()}

    # tuinpad 2 breed: kolom 16 naast kolom 15, van onder het keienplein tot de uitgang
    for ny in range(Y(9), Yl(20) + 1):
        if tt.soort(ng[(X(16), ny)][1]) == '.': ng[(X(16), ny)] = (0, 2, 0, 0)
    # padranden opnieuw kiezen (2 = pad, 10 + masker N1 E2 S4 W8 = kant met gras)
    def is_pad(t):
        c = ng.get(t)
        return c is None or tt.soort(c[1]) in '=#'
    for (nx, ny), c in list(ng.items()):
        if tt.soort(c[1]) != '=': continue
        m = sum(bit for bit, (dx, dy) in ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0)))
                if tt.soort(ng.get((nx + dx, ny + dy), (0, 2))[1]) == '.')
        ng[(nx, ny)] = (0, 2 if m == 0 else 10 + m, 0, 0)
    src = tt.schrijf(src, 'Ground', ng)
    src = tt.schrijf(src, 'Gebouwen', nb)

    # posities: punten op de eerste kopie; deur met de onderrand (laatste kopie, = eerste: rij 6 blijft)
    ONDER = ('Door', 'Put', 'Kist')
    def zet(m):
        naam, blok = m.group(1), m.group(0)
        pm = re.search(r'position = Vector2\(([-\d.]+), ([-\d.]+)\)', blok)
        if not pm: return blok
        px, py = float(pm.group(1)), float(pm.group(2))
        tx, ty = int(px // 16), int(py // 16)
        nx = X(tx) * 16 + (px - tx * 16)
        ny = (Yl(ty) if naam.startswith(ONDER) else Y(ty)) * 16 + (py - ty * 16)
        return blok[:pm.start()] + 'position = Vector2(%g, %g)' % (nx, ny) + blok[pm.end():]
    src = re.sub(r'\[node name="([^"]+)"[^\n]*\](?:\n(?!\[)[^\n]*)*', zet, src)
    open(PAD, 'w').write(src)
    print('wachtershuis %dx%d -> %dx%d' % (W, H, NW, NH))
    for n, (x, y) in {'deur': (16, 6), 'start': (16, 8), 'zuid_ingang': (15, 19), 'uitgang': (14, 21),
                      'OudeMan': (21, 8), 'Archief': (25, 2), 'speelplek': (19, 11), 'volg-rij': (14, 14)}.items():
        print(n, (x, y), '->', (X(x), Y(y)))
