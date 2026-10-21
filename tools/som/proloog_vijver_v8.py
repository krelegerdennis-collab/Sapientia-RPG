#!/usr/bin/env python3
"""Bakt de v8-vijver (RPG ART vijver_v8_teal.png, 3x3 autotile) voor het kleine 3x2-vijvertje op het
Wachtershuis-erf (wilgendal.tscn, cellen (14..16, 16..17)): rij 0 + rij 2 van de autotile; het oude dorp.png-gras
in de oever wordt vervangen door de gebakken v8-erfgrond (grond_v8.png/json) op dezelfde cel, zodat er geen
donker vierkant rond de vijver staat. Uit: assets/tiles/vijver_v8_teal_erf.png (48x32)."""
import json, os
from PIL import Image
R = os.path.join(os.path.dirname(__file__), "..", "..")
P = lambda *a: os.path.join(R, *a)
vijver = Image.open(P("assets/tiles/vijver_v8_teal.png")).convert("RGBA")
gras = set(Image.open(P("assets/tiles/dorp.png")).convert("RGBA").crop((0, 0, 16, 16)).getdata())
grond = Image.open(P("assets/tilesets/som/wachtershuis/grond_v8.png")).convert("RGBA")
j = json.load(open(P("assets/tilesets/som/wachtershuis/grond_v8.json")))
X0, Y0 = 14, 16
uit = Image.new("RGBA", (48, 32))
for rij, bronrij in ((0, 0), (1, 2)):
    for k in range(3):
        i = j["cellen"][(Y0 + rij) * j["w"] + X0 + k]
        g = grond.crop(((i % j["kolommen"]) * 16, (i // j["kolommen"]) * 16, (i % j["kolommen"]) * 16 + 16, (i // j["kolommen"]) * 16 + 16))
        t = vijver.crop((k * 16, bronrij * 16, k * 16 + 16, bronrij * 16 + 16))
        for y in range(16):
            for x in range(16):
                p = t.getpixel((x, y))
                t.putpixel((x, y), g.getpixel((x, y)) if p in gras or p[3] == 0 else p)
        uit.paste(t, (k * 16, rij * 16))
uit.save(P("assets/tiles/vijver_v8_teal_erf.png"))
