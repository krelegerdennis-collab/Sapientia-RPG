#!/usr/bin/env python3
"""SoM-stijl: slot-tilesets offline omkleuren per gebied en als Godot-TileSet (.tres) wegschrijven.
Geen shader: per gebied een eigen PNG + .tres (mobielvriendelijk).

Invoer (van RPG ART), per tileset <set>:
  tools/som/bron/<set>/tileset.png  RGBA, alleen masterpalet (tools/som/sapientia_palette.json), raster 16 px
  tools/som/bron/<set>/index.txt    per tegel: "<id>\t<naam>[\t<soort>][\tsolid]" (id = rij*kolommen+kolom)
                                    soort = grond|kruin|plant|huis|hout|steen|vast (standaard: grond)
  tools/som/bron/<set>/groepen.png  (optioneel) groepcode zoals somlib.group_layer: R=groep, G=tint, B=ramp
                                    (heeft voorrang op soort-regels)
Paletten: tools/som/paletten/<palet>.json of <set>_<palet>.json: {groep: [doelramp, verschuiving]}
          groepen: vast gebladerte gras pad hout steen dak water muur accent ('vast' en Ink/Dark kleuren nooit om).
Gebieden: assets/tilesets/som/gebieden.json (stijl, maps, palet, tilesets).
Uitvoer:  assets/tilesets/som/<gebied>/<set>.png + <set>.tres (TileSetAtlasSource 16x16, botsing voor 'solid',
          custom data "terrain" = tegelnaam).

Gebruik: python3 tools/som/export_tilesets.py [gebied ...]   (zonder argument: alle gebieden)
         python3 tools/som/export_tilesets.py --check         (alleen controleren, niets schrijven)
"""
import json, os, sys
from PIL import Image

T = 16
HIER = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HIER))
GEBIEDEN = os.path.join(REPO, "assets/tilesets/som/gebieden.json")
UIT = os.path.join(REPO, "assets/tilesets/som")
GROEPEN = ["vast", "gebladerte", "gras", "pad", "hout", "steen", "dak", "water", "muur", "accent"]
REGELS = {  # soort -> {ramp: groep}; '*' = rest (zelfde als somlib.RULES)
    "grond": {"Green/Moss": "gras", "Brown/Wood": "pad", "Blue (Lotte/UI)": "water", "Stone/Slate": "steen", "*": "accent"},
    "kruin": {"Green/Moss": "gebladerte", "Brown/Wood": "hout", "*": "accent"},
    "plant": {"Green/Moss": "gebladerte", "Brown/Wood": "hout", "*": "accent"},
    "huis": {"Skin": "dak", "Brown/Wood": "hout", "Stone/Slate": "steen", "Green/Moss": "gebladerte", "White/Paper": "muur", "*": "accent"},
    "hout": {"Brown/Wood": "hout", "Stone/Slate": "steen", "Green/Moss": "gebladerte", "*": "accent"},
    "steen": {"Stone/Slate": "steen", "Brown/Wood": "hout", "Green/Moss": "gebladerte", "*": "accent"},
    "vast": {"*": "vast"},
}


def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def laad_palet():
    pal = json.load(open(os.path.join(HIER, "sapientia_palette.json")))
    ramps = {r: [hx(c) if isinstance(c, str) else tuple(c[:3]) for c in v] for r, v in pal.items()}
    van = {}
    for r, v in ramps.items():
        for i, c in enumerate(v):
            van[c] = (r, i)
    return ramps, van


def lees_index(pad):
    tegels = {}
    for regel in open(pad, encoding="utf-8"):
        regel = regel.rstrip("\n")
        if not regel.strip() or regel.startswith("#"):
            continue
        d = regel.split("\t")
        tid = int(d[0])
        rest = d[2:]
        soort = next((x for x in rest if x in REGELS), "grond")
        tegels[tid] = {"naam": d[1] if len(d) > 1 else str(tid), "soort": soort, "solid": "solid" in rest}
    return tegels


def groepcode(im, tegels, ramps, van, groepen_png=None):
    """RGBA bron -> lijst per pixel (groep, ramp, tint) of None (transparant)."""
    w, h = im.size
    kol = w // T
    src = im.load()
    gp = groepen_png.load() if groepen_png else None
    rlist = list(ramps)
    uit = [[None] * w for _ in range(h)]
    fout = set()
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if p[3] == 0:
                continue
            if gp:
                g, i, ri, a = gp[x, y]
                if a:
                    uit[y][x] = (GROEPEN[g], rlist[ri], i)
                continue
            rk = van.get(p[:3])
            if rk is None:
                fout.add(p[:3])
                continue
            r, i = rk
            soort = tegels.get((y // T) * kol + x // T, {}).get("soort", "grond")
            regels = REGELS[soort]
            g = "vast" if r == "Ink/Dark" else regels.get(r, regels["*"])
            uit[y][x] = (g, r, i)
    if fout:
        raise SystemExit("kleuren buiten het masterpalet: %s" % sorted(fout)[:5])
    return uit


def kleur(code, w, h, pmap, ramps):
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = out.load()
    for y in range(h):
        for x in range(w):
            c = code[y][x]
            if c is None:
                continue
            g, r, i = c
            if g != "vast" and g in pmap:
                r, sh = pmap[g][0], int(pmap[g][1])
                i = max(0, min(len(ramps[r]) - 1, i + sh))
            d[x, y] = ramps[r][i] + (255,)
    return out


def tres(res_png, w, h, tegels):
    kol = w // T
    regels = ['[gd_resource type="TileSet" load_steps=3 format=3]', "",
              '[ext_resource type="Texture2D" path="%s" id="1_som"]' % res_png, "",
              '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_som"]',
              'texture = ExtResource("1_som")']
    for tid in range((w // T) * (h // T)):
        x, y = tid % kol, tid // kol
        t = tegels.get(tid)
        if t is None:
            continue
        regels.append("%d:%d/0 = 0" % (x, y))
        if t["solid"]:
            regels.append("%d:%d/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)" % (x, y))
        regels.append('%d:%d/0/custom_data_0 = "%s"' % (x, y, t["naam"]))
    regels += ["", "[resource]", "physics_layer_0/collision_layer = 1",
               'custom_data_layer_0/name = "terrain"', "custom_data_layer_0/type = 4",
               'sources/0 = SubResource("TileSetAtlasSource_som")', ""]
    return "\n".join(regels)


def palet_voor(set_naam, palet):
    for naam in ("%s_%s.json" % (set_naam, palet), "%s.json" % palet):
        p = os.path.join(HIER, "paletten", naam)
        if os.path.exists(p):
            return json.load(open(p))
    raise SystemExit("palet ontbreekt: %s" % palet)


def exporteer(gebied, cfg, ramps, van, alleen_check=False, bron_map=None, uit_map=None, res_map="res://assets/tilesets/som"):
    gemaakt = []
    for set_naam in cfg.get("tilesets", []):
        bron = os.path.join(bron_map or os.path.join(HIER, "bron"), set_naam)
        png = os.path.join(bron, "tileset.png")
        if not os.path.exists(png):
            print("  %s/%s: geen bron (%s), overgeslagen" % (gebied, set_naam, os.path.relpath(png, REPO)))
            continue
        im = Image.open(png).convert("RGBA")
        w, h = im.size
        if w % T or h % T:
            raise SystemExit("%s: maat %dx%d is geen veelvoud van 16" % (png, w, h))
        tegels = lees_index(os.path.join(bron, "index.txt"))
        gpad = os.path.join(bron, "groepen.png")
        gim = Image.open(gpad).convert("RGBA") if os.path.exists(gpad) else None
        code = groepcode(im, tegels, ramps, van, gim)
        pmap = palet_voor(set_naam, cfg.get("palet", "normaal"))
        uit = kleur(code, w, h, pmap, ramps)
        if alleen_check:
            print("  %s/%s: ok (%d tegels)" % (gebied, set_naam, len(tegels)))
            continue
        d = os.path.join(uit_map or UIT, gebied)
        os.makedirs(d, exist_ok=True)
        uit.save(os.path.join(d, set_naam + ".png"))
        res_png = "%s/%s/%s.png" % (res_map, gebied, set_naam)
        open(os.path.join(d, set_naam + ".tres"), "w").write(tres(res_png, w, h, tegels))
        gemaakt.append(os.path.join(d, set_naam + ".tres"))
        print("  %s/%s -> %s" % (gebied, set_naam, os.path.relpath(d, REPO)))
    return gemaakt


def main(args):
    check = "--check" in args
    namen = [a for a in args if not a.startswith("--")]
    ramps, van = laad_palet()
    gebieden = json.load(open(GEBIEDEN))["gebieden"]
    for g in namen or list(gebieden):
        if g not in gebieden:
            raise SystemExit("onbekend gebied: %s" % g)
        print(g)
        exporteer(g, gebieden[g], ramps, van, check)


if __name__ == "__main__":
    main(sys.argv[1:])
