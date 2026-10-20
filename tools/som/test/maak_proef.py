#!/usr/bin/env python3
"""Proef voor de SoM-pipeline: een mini-tileset (4 tegels: gras, pad, water, muur-solid), uitgevoerd in
twee paletten (normaal, herfst) naar tools/som/test/uit/. Wordt gebruikt door wilgendaltest (_som)."""
import json, os, sys
from PIL import Image
HIER = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HIER))
import export_tilesets as E

ramps, van = E.laad_palet()
bron = os.path.join(HIER, "bron", "proef")
os.makedirs(bron, exist_ok=True)
im = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
d = im.load()
kleuren = [ramps["Green/Moss"][3], ramps["Brown/Wood"][3], ramps["Blue (Lotte/UI)"][3], ramps["Stone/Slate"][3]]
for t, c in enumerate(kleuren):
    for y in range(16):
        for x in range(16):
            rand = x in (0, 15) or y in (0, 15)
            d[t * 16 + x, y] = (ramps["Ink/Dark"][1] if rand else c) + (255,)
im.save(os.path.join(bron, "tileset.png"))
open(os.path.join(bron, "index.txt"), "w").write("0\tgras\tgrond\n1\tpad\tgrond\n2\twater\tgrond\tsolid\n3\tmuur\tsteen\tsolid\n")
uit = os.path.join(HIER, "uit")
for palet in ("normaal", "herfst"):
    E.exporteer("proef_" + palet, {"tilesets": ["proef"], "palet": palet}, ramps, van, False,
                bron_map=os.path.join(HIER, "bron"), uit_map=uit, res_map="res://tools/som/test/uit")
a = Image.open(os.path.join(uit, "proef_normaal", "proef.png")).convert("RGBA")
b = Image.open(os.path.join(uit, "proef_herfst", "proef.png")).convert("RGBA")
assert a.getpixel((8, 8)) != b.getpixel((8, 8)), "herfst kleurt gras niet om"
assert a.getpixel((0, 0)) == b.getpixel((0, 0)), "omlijning mag nooit van kleur veranderen"
assert a.getpixel((24, 8)) == b.getpixel((24, 8)), "pad hoort in herfst gelijk te blijven"
alle = {c for v in ramps.values() for c in v}
assert all(p[:3] in alle for p in list(b.getdata()) if p[3]), "buiten het masterpalet"
print("proef ok")
