#!/usr/bin/env python3
"""SoM-hekken (RPG ART fase 4) als derde bron (id 2) in de terrain-tileset van een gebied.

Bron: tools/som/bron/hekken/<palet>.png  (256x32, cellen van 16 px; rij 0 = autotile op masker N1 E2 S4 W8,
      rij 1 = paalvarianten en poorten) + hekken_index.json (namen, botsing). Het palet komt uit gebieden.json
      ("palet"); bestaat er geen eigen sheet (bv. "normaal"), dan de sheet van "wilgendal".
Uit:  assets/tilesets/som/<gebied>/hekken.png
      assets/tilesets/som/<gebied>/terrain.tres  krijgt sources/2 (botsing per hek-stuk; open poorten botsen niet)
      assets/tilesets/som/<gebied>/hekken_namen.json  {"hek_10": [kol, rij], ...}
Herhaalbaar: een eerdere hekken-bron wordt eerst weggehaald. export_tilesets.py roept dit na water_anim aan.

Gebruik: python3 tools/som/hekken.py [gebied ...]
"""
import json, os, re, shutil, sys

HIER = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HIER))
GEBIEDEN = os.path.join(REPO, "assets/tilesets/som/gebieden.json")
BRON = os.path.join(HIER, "bron", "hekken")
VAST = "wilgendal"


def tel_stappen(tekst):
    return 1 + len(re.findall(r"^\[(?:ext_resource|sub_resource)", tekst, flags=re.M))


def maak(gebied, cfg):
    palet = cfg.get("palet", "normaal")
    png = os.path.join(BRON, palet + ".png")
    if not os.path.exists(png):
        png = os.path.join(BRON, VAST + ".png")
    d = os.path.join(REPO, "assets/tilesets/som", gebied)
    tres = os.path.join(d, "terrain.tres")
    if not os.path.exists(png) or not os.path.exists(tres):
        print("  %s: geen hekken" % gebied)
        return
    index = json.load(open(os.path.join(BRON, "hekken_index.json")))
    shutil.copyfile(png, os.path.join(d, "hekken.png"))
    res = "res://assets/tilesets/som/%s/hekken.png" % gebied
    tekst = open(tres).read()
    # eerdere hekken-bron weghalen (herhaalbaar)
    tekst = re.sub(r'\[ext_resource [^\n]*id="3_hekken"\]\n\n', "", tekst)
    tekst = re.sub(r'\[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_hekken"\]\n.*?\n\n', "", tekst, flags=re.S)
    tekst = re.sub(r"\nsources/2 = .*", "", tekst).rstrip("\n") + "\n"
    ext = '[ext_resource type="Texture2D" path="%s" id="3_hekken"]\n\n' % res
    tekst = tekst.replace("\n[sub_resource", "\n" + ext + "[sub_resource", 1)
    kop, rest = tekst.split("\n[resource]\n")
    sub = ['[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_hekken"]', 'texture = ExtResource("3_hekken")']
    namen = {}
    for t in sorted(index["tiles"], key=lambda t: (t["row"], t["col"])):
        k = "%d:%d" % (t["col"], t["row"])
        sub.append("%s/0 = 0" % k)
        if t["solid"]:
            sub.append("%s/0/physics_layer_0/polygon_0/points = PackedVector2Array(%s)" % (k, ", ".join(str(v) for v in t["collision_polygon"])))
        sub += ['%s/0/custom_data_0 = "%s"' % (k, t["name"]), '%s/0/custom_data_1 = "overlay"' % k]
        namen[t["name"]] = [t["col"], t["row"]]
    uit = kop.rstrip("\n") + "\n\n" + "\n".join(sub) + "\n\n[resource]\n" + rest.rstrip("\n") \
        + '\nsources/2 = SubResource("TileSetAtlasSource_hekken")\n'
    uit = re.sub(r"load_steps=\d+", "load_steps=%d" % tel_stappen(uit), uit, count=1)
    open(tres, "w").write(uit)
    json.dump(namen, open(os.path.join(d, "hekken_namen.json"), "w"), indent=0, sort_keys=True)
    print("  %s: hekken (%d tegels, palet %s)" % (gebied, len(namen), os.path.basename(png)[:-4]))


def main(args):
    gebieden = json.load(open(GEBIEDEN))["gebieden"]
    for g in args or list(gebieden):
        if "terrain" in gebieden[g].get("tilesets", []):
            maak(g, gebieden[g])


if __name__ == "__main__":
    main(sys.argv[1:])
