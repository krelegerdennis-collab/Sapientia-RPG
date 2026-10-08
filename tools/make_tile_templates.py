"""
Maakt sjabloon-PNG's voor de art director: de huidige tiles 4x vergroot, met indexnummer,
positie en 'S' (= blokkeert / solid). Leest de botsingen uit de echte .tres-bestanden.
Gebruik:  python3 tools/make_tile_templates.py /workspace/art_specs_v8
"""
import os
import re
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
Z = 4
FONT = ImageFont.load_default(size=11)
FONT_B = ImageFont.load_default(size=14)
SOLID_COL = (255, 70, 90, 255)
WALK_COL = (90, 230, 140, 255)


def parse_tres(path):
    """{bronnummer: {(kol, rij): {"solid": bool, "name": str}}} in volgorde van 'sources/N'."""
    subs, order, cur = {}, {}, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r'\[sub_resource type="TileSetAtlasSource" id="(\w+)"', line)
        if m:
            cur = m.group(1); subs[cur] = {}; continue
        m = re.match(r'sources/(\d+) = SubResource\("(\w+)"\)', line.strip())
        if m:
            order[int(m.group(1))] = m.group(2); continue
        m = re.match(r'(\d+):(\d+)/0(/(\S+))? = (.*)', line.strip())
        if m and cur:
            d = subs[cur].setdefault((int(m.group(1)), int(m.group(2))), {"solid": False, "name": ""})
            key = m.group(4) or ""
            if key.startswith("physics_layer_0/polygon_0/points"):
                d["solid"] = True
            elif key == "custom_data_0":
                d["name"] = m.group(5).strip('"')
    return {n: subs[sid] for n, sid in order.items()}


def tile_cell(tile, label1, label2, solid):
    cw = 16 * Z
    cell = Image.new("RGBA", (cw + 4, cw + 34), (24, 24, 28, 255))
    cell.paste(tile.resize((cw, cw), Image.NEAREST), (2, 2), tile.resize((cw, cw), Image.NEAREST))
    d = ImageDraw.Draw(cell)
    d.rectangle((1, 1, cw + 2, cw + 2), outline=SOLID_COL if solid else WALK_COL)
    d.text((3, cw + 4), label1, font=FONT_B, fill=(240, 240, 240, 255))
    d.text((3, cw + 20), label2, font=FONT, fill=SOLID_COL if solid else (190, 190, 190, 255))
    return cell


def checker(w, h, s=8):
    im = Image.new("RGBA", (w, h), (60, 60, 66, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, h, s):
        for x in range(0, w, s):
            if (x // s + y // s) % 2:
                d.rectangle((x, y, x + s - 1, y + s - 1), fill=(78, 78, 86, 255))
    return im


def grid_sheet(title, cells, cols):
    cw, ch = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    out = Image.new("RGBA", (cols * (cw + 4) + 8, rows * (ch + 4) + 40), (12, 12, 14, 255))
    d = ImageDraw.Draw(out)
    d.text((8, 8), title, font=FONT_B, fill=(255, 255, 255, 255))
    d.text((8, 24), "groen kader = begaanbaar, rood kader + 'S' = blokkeert (solid)", font=FONT, fill=(200, 200, 200, 255))
    for i, c in enumerate(cells):
        out.paste(c, (8 + (i % cols) * (cw + 4), 40 + (i // cols) * (ch + 4)))
    return out


def main(dst):
    os.makedirs(dst, exist_ok=True)
    tiles = os.path.join(ROOT, "assets", "tiles")
    town = parse_tres(os.path.join(tiles, "dorp.tres"))
    world = parse_tres(os.path.join(tiles, "wereld.tres"))
    # dorp.png: één rij van 54 tiles
    dorp = Image.open(os.path.join(tiles, "dorp.png")).convert("RGBA")
    cells = []
    for i in range(dorp.width // 16):
        info = town[0].get((i, 0), {"solid": False, "name": "?"})
        t = dorp.crop((i * 16, 0, i * 16 + 16, 16))
        cells.append(tile_cell(t, "#%d x=%d" % (i, i * 16), ("S " if info["solid"] else "") + info["name"], info["solid"]))
    grid_sheet("dorp.png (864x16, 1 rij van 54 tiles van 16x16; hier in rijen van 18 getoond, 4x)", cells, 18) \
        .save(os.path.join(dst, "template_dorp.png"))
    # huis.png 5x5
    huis = Image.open(os.path.join(tiles, "huis.png")).convert("RGBA")
    cells = []
    for r in range(5):
        for c in range(5):
            info = town[1].get((c, r), {"solid": False, "name": "?"})
            lab = "deur" if (c, r) == (2, 4) else info["name"]
            cells.append(tile_cell(huis.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16)),
                                   "(%d,%d)" % (c, r), ("S " if info["solid"] else "") + lab, info["solid"]))
    sheet = grid_sheet("huis.png (80x80 = 5x5 tiles, 4x). Alles solid; deur = tile (2,4)", cells, 5)
    big = checker(80 * Z, 80 * Z)
    big.alpha_composite(huis.resize((80 * Z, 80 * Z), Image.NEAREST))
    out = Image.new("RGBA", (sheet.width + big.width + 24, max(sheet.height, big.height + 48)), (12, 12, 14, 255))
    out.paste(sheet, (0, 0))
    out.paste(big, (sheet.width + 12, 40))
    ImageDraw.Draw(out).text((sheet.width + 12, 20), "geheel (4x, ruit = doorzichtig)", font=FONT, fill=(220, 220, 220, 255))
    out.save(os.path.join(dst, "template_huis.png"))
    # wereld.png 16 kolommen
    wereld = Image.open(os.path.join(tiles, "wereld.png")).convert("RGBA")
    cells = []
    for i in range(132):
        c, r = i % 16, i // 16
        info = world[0].get((c, r), {"solid": False, "name": "?"})
        cells.append(tile_cell(wereld.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16)),
                               "#%d (%d,%d)" % (i, c, r), ("S " if info["solid"] else "") + info["name"], info["solid"]))
    grid_sheet("wereld.png (256x144 = 16 kolommen x 9 rijen van 16x16; 132 tiles gebruikt, 4x)", cells, 16) \
        .save(os.path.join(dst, "template_wereld.png"))
    # figuren 48x96
    spr = os.path.join(ROOT, "assets", "sprites")
    dirs = ["onder (naar je toe)", "links", "rechts", "boven (rug)"]
    cols = ["0 stil", "1 stap A", "2 stap B"]
    for name in ("player", "npc"):
        im = Image.open(os.path.join(spr, name + ".png")).convert("RGBA")
        cw, ch = 16 * Z * 2, 24 * Z * 2 // 2 * 2
        out = Image.new("RGBA", (170 + 3 * (16 * Z + 12), 50 + 4 * (24 * Z + 12)), (12, 12, 14, 255))
        d = ImageDraw.Draw(out)
        d.text((8, 8), "%s.png (48x96 = 3 kolommen x 4 rijen, frame 16x24, 4x)" % name, font=FONT_B, fill=(255, 255, 255, 255))
        for c in range(3):
            d.text((170 + c * (16 * Z + 12), 30), cols[c], font=FONT, fill=(220, 220, 220, 255))
        for r in range(4):
            d.text((8, 50 + r * (24 * Z + 12) + 40), "rij %d: %s" % (r, dirs[r]), font=FONT, fill=(220, 220, 220, 255))
            for c in range(3):
                fr = im.crop((c * 16, r * 24, c * 16 + 16, r * 24 + 24)).resize((16 * Z, 24 * Z), Image.NEAREST)
                bg = checker(16 * Z, 24 * Z)
                bg.alpha_composite(fr)
                x, y = 170 + c * (16 * Z + 12), 50 + r * (24 * Z + 12)
                out.paste(bg, (x, y))
                # gele lijn = bovenkant van de 16x16-tile waar de figuur op staat (frame-rij 8);
                # de onderkant van het frame = onderkant van de tile
                d.line((x, y + 8 * Z, x + 16 * Z - 1, y + 8 * Z), fill=(255, 200, 0, 200))
        out.save(os.path.join(dst, "template_%s.png" % name))
    sign = Image.open(os.path.join(spr, "sign.png")).convert("RGBA")
    bg = checker(16 * Z, 16 * Z)
    bg.alpha_composite(sign.resize((16 * Z, 16 * Z), Image.NEAREST))
    out = Image.new("RGBA", (260, 16 * Z + 40), (12, 12, 14, 255))
    out.paste(bg, (8, 32))
    ImageDraw.Draw(out).text((8, 8), "sign.png (16x16, 4x)", font=FONT_B, fill=(255, 255, 255, 255))
    out.save(os.path.join(dst, "template_sign.png"))
    print("sjablonen in", dst)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "art_specs_v8"))
