#!/usr/bin/env python3
"""Geanimeerd water (RPG ART fase 3, batch 3) als tweede bron in de terrain-tileset van een gebied.

Bron: tools/som/bron/water_anim/<palet>.png (512x96: 4 frameblokken van 8x6 tegels naast elkaar)
      tools/som/bron/water_anim/water_index.json (masker -> kolom/rij in blok 0)
Uit:  assets/tilesets/som/<gebied>/water_anim.png
      assets/tilesets/som/<gebied>/terrain.tres  krijgt sources/1 (47 blob-tegels, 4 frames, ~5 fps,
      animation_columns=0, animation_separation=(7,0), botsing zoals het oude water)
      assets/tilesets/som/<gebied>/water_anim_namen.json  {"water_068": [kol, rij], ...} (bron 1)
Herhaalbaar: een eerdere water-bron in terrain.tres wordt eerst weggehaald.
export_tilesets.py roept dit na de terrain-export aan.

Gebruik: python3 tools/som/water_anim.py [gebied ...]
"""
import json, os, re, shutil, sys

HIER = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HIER))
GEBIEDEN = os.path.join(REPO, "assets/tilesets/som/gebieden.json")
BRON = os.path.join(HIER, "bron", "water_anim")
FPS = 5.0


def maak(gebied, cfg):
    palet = cfg.get("palet", "normaal")
    png = os.path.join(BRON, palet + ".png")
    d = os.path.join(REPO, "assets/tilesets/som", gebied)
    tres = os.path.join(d, "terrain.tres")
    if not os.path.exists(png) or not os.path.exists(tres):
        print("  %s: geen water_anim (%s)" % (gebied, os.path.relpath(png, REPO)))
        return
    index = json.load(open(os.path.join(BRON, "water_index.json")))
    shutil.copyfile(png, os.path.join(d, "water_anim.png"))
    res = "res://assets/tilesets/som/%s/water_anim.png" % gebied
    tekst = open(tres).read()
    # eerdere water-bron weghalen (herhaalbaar)
    tekst = re.sub(r'\[ext_resource [^\n]*id="2_water"\]\n\n', "", tekst)
    tekst = re.sub(r'\[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_water"\]\n.*?\n\n', "", tekst, flags=re.S)
    tekst = re.sub(r"\nsources/1 = .*", "", tekst).rstrip("\n") + "\n"
    tekst = tekst.replace("load_steps=3", "load_steps=5")
    ext = '[ext_resource type="Texture2D" path="%s" id="2_water"]\n\n' % res
    tekst = tekst.replace("\n[sub_resource", "\n" + ext + "[sub_resource", 1)
    kop, rest = tekst.split("\n[resource]\n")
    sub = ['[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_water"]',
           'texture = ExtResource("2_water")']
    namen = {}
    for t in index["tiles"]:
        k = "%d:%d" % (t["col"], t["row"])
        sub += ["%s/animation_columns = 0" % k, "%s/animation_separation = Vector2i(7, 0)" % k,
                "%s/animation_speed = %.1f" % (k, FPS), "%s/animation_frames_count = %d" % (k, index["frames"]),
                "%s/0 = 0" % k,
                "%s/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)" % k,
                '%s/0/custom_data_0 = "water_%03d"' % (k, t["mask"]), '%s/0/custom_data_1 = "ground"' % k]
        namen["water_%03d" % t["mask"]] = [t["col"], t["row"]]
    uit = kop.rstrip("\n") + "\n\n" + "\n".join(sub) + "\n\n[resource]\n" + rest.rstrip("\n") \
        + '\nsources/1 = SubResource("TileSetAtlasSource_water")\n'
    open(tres, "w").write(uit)
    json.dump(namen, open(os.path.join(d, "water_anim_namen.json"), "w"), indent=0, sort_keys=True)
    print("  %s: water_anim (%d tegels, %d frames)" % (gebied, len(namen), index["frames"]))


def main(args):
    gebieden = json.load(open(GEBIEDEN))["gebieden"]
    for g in args or list(gebieden):
        if "terrain" in gebieden[g].get("tilesets", []):
            maak(g, gebieden[g])


if __name__ == "__main__":
    main(sys.argv[1:])
