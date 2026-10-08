"""
v0.11 – PLACEHOLDER-art voor de proloog (tot RPG ART de echte levert).
Alles in assets/sprites/story/ (1 tile = 16x16, frames naast elkaar):
  put.png          16x24  waterput (1 tile, blokkeert; tekening steekt 8 px boven de tile uit)
  zegel.png        32x16  zegelsteen, 2 frames: 0 = slapend, 1 = gecontroleerd (gloeit zwak cyaan)
  kist.png         32x16  kist, 2 frames: 0 = dicht, 1 = open/leeg
  schilderij.png   32x16  schilderij aan de muur, 2 frames: 0 = recht, 1 = scheef (zwaard weg)
  archief.png      64x32  ingang 'De Vergeten Archieven' (2x2 tiles), 2 frames van 32x32:
                          0 = overwoekerd/dicht (ranken), 1 = open (roze/cyaan licht)
Stijl 'De Vergeten Bibliotheek': donkergrijs/bruin/donkergroen, magenta/cyaan alleen als accent.
Bestanden die in tools/handwerk.txt staan en al bestaan worden NIET overschreven.
Starten (vanuit de projectmap):  python3 tools/art_v11.py   [--ook-handwerk]
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = os.path.join(ROOT, "assets", "sprites", "story")


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


OUT = hx("0c0b0d")
MAG = hx("ff1ee6")
MAG_D = hx("8a0c84")
CYA = hx("19ecf6")
CYA_D = hx("08707a")
ST = [hx(c) for c in ("141518", "1e2024", "2a2c31", "373a40", "464a51", "5a5e66", "6f747d")]
WD = [hx(c) for c in ("1e1612", "2e221a", "3e2e22", "4f3b2b", "634a36", "7a5c44")]
GR = [hx(c) for c in ("0e160f", "17231b", "223328", "2f4436", "3e5646", "4f6a55")]
GOLD = hx("b08a3e")
WATER = [hx("10303a"), hx("1a4d5a"), hx("2e7a88")]


def handwerk():
    p = os.path.join(ROOT, "tools", "handwerk.txt")
    out = set()
    if os.path.exists(p):
        for line in open(p, encoding="utf-8"):
            line = line.split("#")[0].strip()
            if line:
                out.add(line)
    return out


def save(im, name):
    rel = "assets/sprites/story/" + name
    path = os.path.join(ROOT, rel)
    if rel in handwerk() and os.path.exists(path) and "--ook-handwerk" not in sys.argv:
        print("overgeslagen (handwerk):", rel)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("gemaakt:", rel, im.size)


def shadow(d, cx, y, w):
    d.ellipse((cx - w, y - 2, cx + w - 1, y + 1), fill=(0, 0, 0, 90))


def make_well():
    im = Image.new("RGBA", (16, 24))
    d = ImageDraw.Draw(im)
    shadow(d, 8, 22, 7)
    # dakje
    d.line((2, 6, 8, 1), fill=WD[1]); d.line((8, 1, 13, 6), fill=WD[1])
    d.polygon([(1, 7), (8, 1), (14, 7)], fill=WD[3], outline=OUT)
    d.line((3, 6, 12, 6), fill=WD[5])
    # palen
    d.rectangle((3, 7, 3, 14), fill=WD[2]); d.rectangle((12, 7, 12, 14), fill=WD[2])
    d.line((3, 10, 12, 10), fill=WD[4])   # as
    d.line((8, 10, 8, 13), fill=ST[5])    # touw
    d.rectangle((7, 13, 9, 15), fill=WD[4], outline=OUT)  # emmer
    # stenen ring
    d.ellipse((1, 13, 14, 22), fill=ST[3], outline=OUT)
    d.ellipse((3, 14, 12, 18), fill=WATER[0])
    d.line((5, 16, 9, 16), fill=WATER[2])
    for x, y in [(2, 19), (5, 21), (9, 21), (12, 19), (7, 20)]:
        d.point((x, y), fill=ST[5])
    d.point((10, 15), fill=CYA)   # glinster
    save(im, "put.png")


def make_seals():
    im = Image.new("RGBA", (32, 16))
    for f in range(2):
        d = ImageDraw.Draw(im)
        ox = f * 16
        shadow(d, ox + 8, 15, 6)
        d.polygon([(ox + 4, 15), (ox + 3, 6), (ox + 6, 2), (ox + 10, 2), (ox + 13, 6), (ox + 12, 15)], fill=ST[3], outline=OUT)
        d.line((ox + 5, 4, ox + 5, 13), fill=ST[5])
        # mos
        for x, y in [(4, 13), (5, 14), (11, 14), (12, 12), (6, 3)]:
            d.point((ox + x, y), fill=GR[4])
        # het teken (cirkel + streep)
        col = CYA if f == 1 else CYA_D
        d.ellipse((ox + 6, 6, ox + 10, 10), outline=col)
        d.point((ox + 8, 8), fill=MAG if f == 1 else MAG_D)
        d.line((ox + 8, 11, ox + 8, 13), fill=col)
        if f == 1:
            for x, y in [(5, 7), (11, 7), (8, 4)]:
                d.point((ox + x, y), fill=hx("9ff8ff"))
    save(im, "zegel.png")


def make_chest():
    im = Image.new("RGBA", (32, 16))
    d = ImageDraw.Draw(im)
    for f in range(2):
        ox = f * 16
        shadow(d, ox + 8, 15, 7)
        d.rectangle((ox + 2, 8, ox + 13, 14), fill=WD[3], outline=OUT)
        d.line((ox + 3, 11, ox + 12, 11), fill=WD[2])
        if f == 0:
            d.rectangle((ox + 2, 4, ox + 13, 8), fill=WD[4], outline=OUT)
            d.line((ox + 3, 5, ox + 12, 5), fill=WD[5])
            d.rectangle((ox + 7, 7, ox + 8, 9), fill=GOLD)
        else:
            d.rectangle((ox + 2, 1, ox + 13, 4), fill=WD[4], outline=OUT)
            d.rectangle((ox + 3, 7, ox + 12, 9), fill=OUT)
            d.point((ox + 6, 8), fill=GR[3])
        d.line((ox + 4, 8, ox + 4, 14), fill=ST[4]); d.line((ox + 11, 8, ox + 11, 14), fill=ST[4])
    save(im, "kist.png")


def make_painting():
    im = Image.new("RGBA", (32, 16))
    d = ImageDraw.Draw(im)
    for f in range(2):
        ox = f * 16
        if f == 0:
            d.rectangle((ox + 2, 2, ox + 13, 12), fill=GOLD, outline=OUT)
            d.rectangle((ox + 4, 4, ox + 11, 10), fill=hx("1f2a3a"))
            d.polygon([(ox + 4, 10), (ox + 7, 6), (ox + 9, 8), (ox + 11, 5), (ox + 11, 10)], fill=GR[3])
            d.point((ox + 9, 5), fill=hx("e2d8bc"))
        else:
            # scheef gehangen, gat erachter met een lege haak
            d.rectangle((ox + 4, 4, ox + 11, 10), fill=ST[0])
            d.line((ox + 5, 7, ox + 10, 7), fill=ST[2])
            d.polygon([(ox + 1, 4), (ox + 12, 1), (ox + 14, 11), (ox + 3, 14)], fill=GOLD, outline=OUT)
            d.polygon([(ox + 3, 5), (ox + 11, 3), (ox + 12, 10), (ox + 4, 12)], fill=hx("1f2a3a"))
            d.point((ox + 8, 7), fill=MAG_D)
    save(im, "schilderij.png")


def make_archive():
    im = Image.new("RGBA", (64, 32))
    d = ImageDraw.Draw(im)
    for f in range(2):
        ox = f * 32
        # rots / heuvel met een stenen boog
        d.polygon([(ox + 0, 31), (ox + 1, 12), (ox + 6, 4), (ox + 16, 1), (ox + 26, 4), (ox + 31, 12), (ox + 31, 31)], fill=ST[2], outline=OUT)
        d.line((ox + 4, 10, ox + 10, 5), fill=ST[4]); d.line((ox + 20, 3, ox + 27, 8), fill=ST[4])
        # boog
        d.rectangle((ox + 7, 12, ox + 24, 31), fill=ST[4], outline=OUT)
        d.pieslice((ox + 7, 5, ox + 24, 20), 180, 360, fill=ST[4], outline=OUT)
        # opening
        inner = OUT if f == 0 else MAG_D
        d.rectangle((ox + 10, 14, ox + 21, 31), fill=inner)
        d.pieslice((ox + 10, 9, ox + 21, 20), 180, 360, fill=inner)
        if f == 1:
            d.rectangle((ox + 12, 16, ox + 19, 31), fill=MAG)
            d.pieslice((ox + 12, 11, ox + 19, 21), 180, 360, fill=MAG)
            d.rectangle((ox + 14, 18, ox + 17, 31), fill=hx("ffb8f6"))
            for x, y in [(11, 22), (20, 25), (13, 29), (18, 19)]:
                d.point((ox + x, y), fill=CYA)
        # stenen in de boog + oude runen
        for y in (13, 19, 25):
            d.line((ox + 7, y, ox + 9, y), fill=ST[2]); d.line((ox + 22, y, ox + 24, y), fill=ST[2])
        d.point((ox + 15, 7), fill=CYA if f == 1 else CYA_D); d.point((ox + 16, 7), fill=CYA if f == 1 else CYA_D)
        # ranken (dicht: over de hele opening; open: alleen aan de randen, kapot)
        vines = [(9, 12, 13, 31), (13, 10, 17, 30), (18, 11, 22, 31), (11, 18, 20, 20), (10, 25, 21, 26)]
        if f == 1:
            vines = [(8, 12, 9, 26), (22, 13, 23, 28)]
        for (x0, y0, x1, y1) in vines:
            d.line((ox + x0, y0, ox + x1, y1), fill=GR[3], width=1)
            d.line((ox + x0 + 1, y0, ox + x1 + 1, y1), fill=GR[2], width=1)
        for x, y in ([(10, 15), (15, 13), (19, 17), (12, 23), (20, 28), (16, 27), (14, 19)] if f == 0 else [(8, 16), (23, 20), (9, 24)]):
            d.rectangle((ox + x, y, ox + x + 1, y + 1), fill=GR[4])
        # gras/varens onderaan
        for x in range(0, 32, 3):
            d.line((ox + x, 31, ox + x + 1, 28 + (x % 2)), fill=GR[3])
    save(im, "archief.png")


if __name__ == "__main__":
    make_well()
    make_seals()
    make_chest()
    make_painting()
    make_archive()
