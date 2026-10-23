#!/usr/bin/env python3
"""Plein 10 pass 3 (RPG ART art_10 rand10/rand11): keienplein als autotile i.p.v. gebakken keien.
- kopieert plein_rand_tileset/-layout, keien_licht_tileset/-layout, keien_macro_tileset/-layout en
  gras_licht_tileset naar plein10/ (alleen als ze nog niet bestaan: handwerk wordt nooit overschreven);
- leest de gebakken grond (plein_grond_tileset + plein_grond_map) en schrijft plein10/keien_map.json:
  per bloktegel 'k' = kei (terrain 1), 'g' = gras_licht over gebakken keienresten, '.' = gebakken grond.
Gebruik: python3 tools/plein10_keien.py [/workspace/art_10]"""
import json, os, shutil, sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else '/workspace/art_10'
OUT = os.path.join(SRC, 'out')
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(REPO, 'assets/sprites/buiten/wilgendal/plein10')
for n in ('plein_rand_tileset.png', 'plein_rand_layout.json', 'keien_licht_tileset.png', 'keien_licht_layout.json',
          'keien_macro_tileset.png', 'keien_macro_layout.json', 'gras_licht_tileset.png'):
    if not os.path.exists(os.path.join(DST, n)):
        shutil.copy(os.path.join(OUT, n), os.path.join(DST, n))

gm = json.load(open(os.path.join(DST, 'plein_grond_map.json')))
ts = Image.open(os.path.join(DST, 'plein_grond_tileset.png')).convert('RGB'); cols = gm['cols']
H = len(gm['map']); W = len(gm['map'][0])


def soort(i):
    t = ts.crop(((i % cols) * 16, (i // cols) * 16, (i % cols) * 16 + 16, (i // cols) * 16 + 16))
    k = d = 0
    for r, g, b in (t.get_flattened_data() if hasattr(t, "get_flattened_data") else t.getdata()):
        if (g > r + 8 and g > b + 15) or b > r + 15:
            continue            # gras of water
        if r > g + 12 and r > b + 30:
            d += 1              # zandpad
        else:
            k += 1              # kei
    return '#' if k > 128 else ('+' if k > 51 else ('d' if d > 77 else '.'))


ruw = [[soort(int(i)) for i in rij] for rij in gm['map']]
# kei = vol (#) of half (+) naast een volle; alleen de pleinrijen (de beekoever heeft ook stenen)
kaart = [['.'] * W for _ in range(H)]
for y in range(10, 24):
    for x in range(W):
        c = ruw[y][x]
        # pass 4: alleen tegels die voor meer dan de helft kei zijn -> de organische omtrek van de mockup
        # (onregelmatige randen, ronde hoeken) en een smalle noordsteeg (2 breed) i.p.v. een rechthoek
        if c == '#':
            kaart[y][x] = 'k'
# gaten (gras omringd door kei) dicht
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if kaart[y][x] == '.' and all(kaart[y + b][x + a] == 'k' for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            kaart[y][x] = 'k'
# losse uitsteeksels (1 tegel met maar 1 keibuur) weg: geven anders een smal tongetje
for _ in range(2):
    for y in range(H):
        for x in range(W):
            if kaart[y][x] == 'k':
                n = sum(1 for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= x + a < W and 0 <= y + b < H and kaart[y + b][x + a] == 'k')
                if n == 0:
                    kaart[y][x] = '.'
# gras_licht over de gebakken keienrand rond het plein (buren van k, geen zandpad)
for y in range(H):
    for x in range(W):
        bij_pad = any(0 <= x + a < W and 0 <= y + b < H and ruw[y + b][x + a] == 'd' for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if kaart[y][x] == '.' and (ruw[y][x] == '.' or (ruw[y][x] == '+' and not bij_pad)) and any(
                0 <= x + a < W and 0 <= y + b < H and kaart[y + b][x + a] == 'k' for a in (-1, 0, 1) for b in (-1, 0, 1)):
            kaart[y][x] = 'g'
json.dump({'w': W, 'h': H, 'kaart': [''.join(r) for r in kaart]}, open(os.path.join(DST, 'keien_map.json'), 'w'), indent=1)
for y, r in enumerate(kaart):
    print('%2d' % y, ''.join(r), ''.join(ruw[y]))
