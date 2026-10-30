#!/usr/bin/env python3
"""WM1 T2: maakt data/woud_tegels.json (tegel-id -> bestand) en de PLACEHOLDER-tegels (16x16) in
assets/placeholder/woud/. Alleen ontbrekende plaatjes worden gemaakt (--alles = opnieuw).
RPG ART vervangt een tegel door in data/woud_tegels.json het "file" van die tegel naar het echte
bestand te laten wijzen (zelfde maat, zelfde frames). De code leest alleen de JSON."""
import json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PH = "assets/placeholder/woud/"
T = 16

# groep -> placeholderkleur
KLEUR = {"grond": (58, 74, 46), "pad": (122, 98, 64), "rand": (24, 38, 26), "boom": (40, 60, 34),
         "water": (40, 86, 120), "brug": (110, 80, 50), "prop": (90, 90, 96), "uitgang": (20, 20, 24)}

R = []
def t(naam, groep, functie, solid=False, laag="grond", frames=1, varianten=1, rand=""):
    R.append({"naam": naam, "groep": groep, "functie": functie, "solid": solid, "laag": laag,
              "frames": frames, "varianten": varianten, "rand": rand})

# --- grond
for i in "abcd":
    t("grond_" + i, "grond", "bosvloer, variant " + i, varianten=4)
for i in "ab":
    t("grond_blad_" + i, "grond", "bosvloer met dode bladeren, variant " + i, varianten=2)
t("grond_schaduw_n", "grond", "vloer met schaduw onder de bosrand (boven)", rand="N")
t("grond_schaduw_w", "grond", "vloer met schaduw langs de linkerrand", rand="W")
t("grond_schaduw_nw", "grond", "vloer met schaduw in de hoek linksboven", rand="NW")
# --- pad (autotegel 3x3 + binnenhoeken)
for r_ in ["nw", "n", "no", "w", "m", "o", "zw", "z", "zo"]:
    t("pad_" + r_, "pad", "bospad, " + ("midden" if r_ == "m" else "rand " + r_.upper()), rand=r_.upper())
for r_ in ["nw", "no", "zw", "zo"]:
    t("pad_binnen_" + r_, "pad", "bospad binnenhoek (alleen %s-hoekje gras)" % r_.upper(), rand=r_.upper())
t("pad_m_b", "pad", "bospad midden, variant B", varianten=2)
# --- bosrand (muur van bomen)
for r_ in ["nw", "n", "no", "w", "m", "o", "zw", "z", "zo"]:
    t("rand_top_" + r_, "rand", "bladerdak (bosrand-top), " + ("dicht midden" if r_ == "m" else "open " + r_.upper()), True, rand=r_.upper())
for r_ in ["nw", "no", "zw", "zo"]:
    t("rand_top_binnen_" + r_, "rand", "bladerdak binnenhoek (alleen %s open)" % r_.upper(), True, rand=r_.upper())
for pos in ["links", "midden", "rechts"]:
    t("rand_stam_boven_" + pos, "rand", "stammen onder het bladerdak, bovenste rij, " + pos, True)
    t("rand_stam_onder_" + pos, "rand", "stamvoeten, onderste rij, " + pos, True)
# --- bomen (2 breed x 3 hoog: kruin = overlay boven de speler, voet = massief)
for soort, oms in [("eik", "grote eik"), ("den", "donkere den")]:
    for d in ["boven_l", "boven_r", "midden_l", "midden_r"]:
        t("boom_%s_kruin_%s" % (soort, d), "boom", "%s, kruin %s (overlay)" % (oms, d.replace("_", " ")), False, "overlay")
    for d in ["l", "r"]:
        t("boom_%s_voet_%s" % (soort, d), "boom", "%s, stamvoet %s (massief)" % (oms, d), True)
t("struik", "boom", "lage struik, 1 tegel (massief)", True, varianten=2)
# --- water (beek)
t("water_m", "water", "beekwater midden (animatie 4 frames, horizontaal 64x16)", True, frames=4)
for r_ in ["n", "z", "w", "o", "nw", "no", "zw", "zo"]:
    t("water_oever_" + r_, "water", "oever %s (gras -> water, massief)" % r_.upper(), True, frames=4, rand=r_.upper())
for r_ in ["nw", "no", "zw", "zo"]:
    t("water_oever_binnen_" + r_, "water", "oever binnenhoek %s (massief)" % r_.upper(), True, frames=4, rand=r_.upper())
t("stapsteen", "water", "stapsteen in de beek (beloopbaar, water eromheen)", False, frames=4)
# --- brug
for pos in ["links", "midden", "rechts"]:
    t("brug_" + pos, "brug", "houten brug over de beek, horizontaal, " + pos + " (beloopbaar)")
# --- props
t("steen", "prop", "rotsblok (massief)", True, varianten=2)
t("stronk", "prop", "boomstronk (massief)", True)
t("stam_liggend_l", "prop", "liggende stam, linkerhelft (massief, 2 breed)", True)
t("stam_liggend_r", "prop", "liggende stam, rechterhelft (massief, 2 breed)", True)
t("varen", "prop", "varen (decor, beloopbaar)", varianten=2)
t("paddenstoel", "prop", "paddenstoelen (decor, beloopbaar)", varianten=2)
t("paddenstoel_gloed", "prop", "gloeiende magenta paddenstoel (decor, 2 frames gloed)", frames=2)
t("wegwijzer", "prop", "houten wegwijzer (massief, leesbaar)", True)
t("mist", "prop", "mistsliert (overlay, horizontaal herhaalbaar)", False, "overlay")
# --- uitgang
t("uitgang_pad", "uitgang", "bospad uit de kamer (beloopbaar, uitgangstegel)")
t("uitgang_rand_l", "uitgang", "bosrand links van de uitgang (massief)", True)
t("uitgang_rand_r", "uitgang", "bosrand rechts van de uitgang (massief)", True)

def main():
    alles = "--alles" in sys.argv
    os.makedirs(os.path.join(ROOT, PH), exist_ok=True)
    json_pad = os.path.join(ROOT, "data/woud_tegels.json")
    oud = {}
    if os.path.exists(json_pad):
        oud = {r["naam"]: r for r in json.load(open(json_pad))["tegels"]}
    uit = []
    for i, r in enumerate(R):
        r = dict(r, id=i)
        r["file"] = oud.get(r["naam"], {}).get("file", "res://" + PH + r["naam"] + ".png")
        uit.append(r)
        pad = os.path.join(ROOT, PH, r["naam"] + ".png")
        if r["file"].startswith("res://" + PH) and (alles or not os.path.exists(pad)):
            k = KLEUR[r["groep"]]
            img = Image.new("RGBA", (T * r["frames"], T), (0, 0, 0, 0))
            for f in range(r["frames"]):
                for y in range(T):
                    for x in range(T):
                        c = k
                        if (x + y + f * 2) % 8 == 0:
                            c = tuple(min(255, v + 40) for v in k)     # arcering = PLACEHOLDER
                        if x in (0, T - 1) or y in (0, T - 1):
                            c = (255, 0, 255) if r["solid"] else (255, 255, 255)   # rand: magenta = massief
                        a = 150 if r["laag"] == "overlay" else 255
                        img.putpixel((f * T + x, y), c + (a,))
            img.save(pad)
    json.dump({"opmerking": "WM1 T2 Donker Woud: tegel-id -> bestand (16x16; frames naast elkaar). "
               "PLACEHOLDER tot RPG ART: vervang alleen 'file'. Gemaakt door tools/woud_tegels_placeholders.py.",
               "tegelmaat": T, "tegels": uit}, open(json_pad, "w"), indent=1, ensure_ascii=False)
    print(len(uit), "tegels")

main()
