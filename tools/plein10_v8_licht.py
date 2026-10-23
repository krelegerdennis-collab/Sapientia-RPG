#!/usr/bin/env python3
"""Plein 10 pass 4: grond_v8 met het gras omgekleurd naar de gras_licht-ramp (zelfde palet, één stap lichter),
voor padcellen en hun graszoom buiten het plein-blok. Zo blijven de grasplukjes langs de oude paden, maar zonder
donkere rand naast het lichte gras. Schrijft assets/sprites/buiten/wilgendal/plein10/grond_v8_licht.png
(zelfde atlas-indeling als assets/tilesets/som/wilgendal/grond_v8.png). Gebruik: python3 tools/plein10_v8_licht.py"""
import os
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, 'assets/tilesets/som/wilgendal/grond_v8.png')
DST = os.path.join(REPO, 'assets/sprites/buiten/wilgendal/plein10/grond_v8_licht.png')
# donker -> licht (art_10 gras_licht: basis 74963e, accent 4a7038, schaduw 2e5030)
MAP = {(28, 52, 36): (46, 80, 48), (46, 80, 48): (74, 112, 56), (74, 112, 56): (116, 150, 62)}
im = Image.open(SRC).convert('RGBA'); p = im.load()
for y in range(im.height):
    for x in range(im.width):
        r, g, b, a = p[x, y]
        if (r, g, b) in MAP:
            p[x, y] = MAP[(r, g, b)] + (a,)
im.save(DST)
print(DST)
