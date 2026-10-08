#!/usr/bin/env python3
"""v0.14 Eerste Archief: zet de ontwerp-kaarten (story/ARCHIEF1_PLATTEGROND.md, bron
/workspace/archief1_ontwerp/rooms.py) om naar LEGEND-layouts voor scripts/data/dungeon_rooms.gd.
Print de layouts (GDScript-array per kamer) zodat ze in dungeon_rooms.gd geplakt kunnen worden.
Gebruik:  python3 tools/gen_archief1_rooms.py [/pad/naar/rooms.py]
"""
import sys, importlib.util, json

SRC = sys.argv[1] if len(sys.argv) > 1 else "/workspace/archief1_ontwerp/rooms.py"
spec = importlib.util.spec_from_file_location("rooms", SRC)
rooms = importlib.util.module_from_spec(spec); spec.loader.exec_module(rooms)

SEED = [0]


def h(x, y, k=7):
    return abs((x * 73856093) ^ (y * 19349663) ^ (k * 83492791) ^ (SEED[0] * 2654435761)) % 97

def convert(grid):
    H = len(grid); W = len(grid[0])
    out = [[" "] * W for _ in range(H)]
    g = lambda x, y: grid[y][x] if 0 <= x < W and 0 <= y < H else "#"
    objs = {"monsters": {}, "chests": [], "books": [], "save": None}
    for y in range(H):
        for x in range(W):
            c = grid[y][x]
            if y == 0:
                out[y][x] = "a" if x == 0 else ("b" if x == W - 1 else "-")
            elif y == H - 1:
                if c == "W":
                    out[y][x] = "E"
                elif c == "U":
                    out[y][x] = "U"
                else:
                    out[y][x] = "c" if x == 0 else ("d" if x == W - 1 else "_")
            elif x == 0:
                out[y][x] = "<"
            elif x == W - 1:
                out[y][x] = ">"
            elif y in (1, 2):
                up = y == 1
                if c == "A":
                    out[y][x] = "A" if up else "n"
                elif c == "L":
                    out[y][x] = "H" if up else "h"
                elif x == 1:
                    out[y][x] = "L" if up else "l"
                elif x == W - 2:
                    out[y][x] = "R" if up else "r"
                else:
                    r = h(x, 1, 11)
                    pair = "Ff"
                    if r < 6: pair = "Mm"
                    elif r < 9: pair = "Gg"
                    elif r < 12: pair = "Kk"
                    out[y][x] = pair[0] if up else pair[1]
            else:
                if c == "P":
                    # kolomhoogte van het pilaarblok
                    top = y
                    while g(x, top - 1) == "P": top -= 1
                    bot = y
                    while g(x, bot + 1) == "P": bot += 1
                    hgt = bot - top + 1; i = y - top
                    lp = g(x - 1, y) == "P"; rp = g(x + 1, y) == "P"
                    if i == 0:
                        out[y][x] = "2" if (lp and rp) else ("1" if rp else ("3" if lp else "5"))
                    elif i == hgt - 1 and hgt >= 3:
                        out[y][x] = "f" if (lp and rp) or (not lp and not rp) else ("l" if not lp else "r")
                    else:
                        out[y][x] = "F" if (lp and rp) or (not lp and not rp) else ("L" if not lp else "R")
                    continue
                if c == "o":
                    shelf = (g(x - 1, y) == "o" or g(x + 1, y) == "o")
                    if shelf:
                        out[y][x] = "N" if h(x, y) < 18 else "B"
                    else:
                        out[y][x] = "#" if h(x, y) < 60 else "N"
                    continue
                if c == "v":
                    out[y][x] = "v"; continue
                if c == "S":
                    out[y][x] = "@"; objs["save"] = [x, y]; continue
                if c == ",":
                    out[y][x] = "wxp,*"[h(x, y, 3) % 5]; continue
                # vloer (ook onder monsters/kisten/boeken)
                if c.isdigit():
                    objs["monsters"][c] = [x, y]
                elif c == "K":
                    objs["chests"].append([x, y])
                elif c == "H":
                    objs["books"].append([x, y])
                under_front = grid[y - 1][x] in "=AL" and y == 3
                if x == 1 and y == 3:
                    out[y][x] = "Z"
                elif x == 1:
                    out[y][x] = "S"
                elif under_front:
                    out[y][x] = "s"
                else:
                    out[y][x] = "."
    # pilaren naast een doorgang onderaan
    for x in range(W):
        if out[H - 1][x] in "EU":
            for dx, ch in ((-1, "("), (1, ")")):
                if out[H - 1][x + dx] not in "EU":
                    out[H - 1][x + dx] = ch
    return ["".join(r) for r in out], objs


# ---------------------------------------------------------------- extra data per kamer (uit het plan)
D = "res://scenes/maps/"
META = {
 "1A": {"key": "archief_ingang", "name": "Vergeten Archieven", "spawns": {"ingang": [9, 10, "up"], "boog": [9, 3, "down"]},
        "exits": {"E": ["res://scenes/maps/wereldkaart.tscn", "van_archief"], "n": [D + "archief_v1_gang.tscn", "zuid"]}},
 "1B": {"key": "archief_v1_gang", "name": "Vergeten Archieven - Stoffige Gang", "spawns": {"zuid": [3, 10, "up"], "trap": [27, 3, "down"]},
        "exits": {"U": [D + "archief_ingang.tscn", "boog"], "v": [D + "archief_v2_kastenzaal.tscn", "ladder"]}},
 "2A": {"key": "archief_v2_kastenzaal", "name": "Vergeten Archieven - Kastenzaal", "spawns": {"ladder": [3, 3, "down"], "boog": [20, 3, "down"]},
        "exits": {"h": [D + "archief_v1_gang.tscn", "trap"], "n": [D + "archief_v2_leeszaal.tscn", "zuid"]}},
 "2B": {"key": "archief_v2_leeszaal", "name": "Vergeten Archieven - Leeszaal", "spawns": {"zuid": [9, 22, "up"], "boog": [10, 3, "down"]},
        "exits": {"U": [D + "archief_v2_kastenzaal.tscn", "boog"], "n": [D + "archief_v2_trapzaal.tscn", "zuid"]}},
 "2C": {"key": "archief_v2_trapzaal", "name": "Vergeten Archieven - Trapzaal", "spawns": {"zuid": [9, 10, "up"], "trap": [15, 4, "down"]},
        "exits": {"U": [D + "archief_v2_leeszaal.tscn", "boog"], "v": [D + "archief_v3_zuilenhal.tscn", "ladder"]}},
 "3A": {"key": "archief_v3_zuilenhal", "name": "Vergeten Archieven - Zuilenhal", "spawns": {"ladder": [2, 3, "down"], "boog": [28, 3, "down"]},
        "exits": {"h": [D + "archief_v2_trapzaal.tscn", "trap"], "n": [D + "archief_puzzel.tscn", "ingang"]}},
 "3C": {"key": "archief_v3_gang", "name": "Vergeten Archieven - Gang", "spawns": {"zuid": [8, 10, "up"], "trap": [16, 3, "down"]},
        "exits": {"U": [D + "archief_puzzel.tscn", "uit_x"], "v": [D + "archief_v4_wachtersgang.tscn", "ladder"]}},
 "4A": {"key": "archief_v4_wachtersgang", "name": "Vergeten Archieven - Wachtersgang", "spawns": {"ladder": [2, 3, "down"], "boog": [29, 3, "down"]},
        "exits": {"h": [D + "archief_v3_gang.tscn", "trap"], "n": [D + "archief_v4_voorhal.tscn", "zuid"]}},
 "4B": {"key": "archief_v4_voorhal", "name": "Vergeten Archieven - Voorhal", "spawns": {"zuid": [9, 10, "up"], "boog": [10, 3, "down"]},
        "exits": {"U": [D + "archief_v4_wachtersgang.tscn", "boog"], "n": [D + "archief_bibliotheek.tscn", "zuid"]}},
}
CHEST_ITEMS = {"1B": ("drankje", 2), "2B": ("leren_kap", 1), "2C": ("drankje", 3), "3A": ("kaftschild", 1), "4B": ("drankje", 2)}

def q(v):
    return json.dumps(v, ensure_ascii=False)

for f in rooms.FLOORS:
    for r in f["rooms"]:
        if r["id"] not in META:
            continue
        m = META[r["id"]]
        SEED[0] = sum(ord(c) for c in r["id"]) * 31
        rows, objs = convert(r["grid"])
        print("\t# %s %s (%dx%d), verdieping %d" % (r["id"], r["name"], len(rows[0]), len(rows), f["tier"][0] if isinstance(f["tier"], list) else f["tier"]))
        print("\t%s: {" % q(m["key"]))
        print("\t\t\"name\": %s, \"floor\": %d, \"tier\": %d," % (q(m["name"]), f["tier"], f["tier"]))
        print("\t\t\"layout\": [")
        for row in rows:
            print("\t\t\t\"%s\"," % row)
        print("\t\t],")
        if objs["save"]:
            print("\t\t\"save\": %s," % q(objs["save"]))
        sp = ", ".join("%s: %s" % (q(k), q(v)) for k, v in m["spawns"].items())
        print("\t\t\"spawns\": {%s}," % sp)
        print("\t\t\"exits\": {")
        for k, (mp, spn) in m["exits"].items():
            print("\t\t\t%s: {\"map\": %s, \"spawn\": %s}," % (q(k), q(mp), q(spn)))
        print("\t\t},")
        for i, b in enumerate(objs["books"]):
            print("\t\t\"books\": [{\"type\": \"hp\", \"tile\": %s}]," % q(b))
        for i, c in enumerate(objs["chests"]):
            it, n = CHEST_ITEMS[r["id"]]
            print("\t\t\"chests\": [{\"id\": %s, \"tile\": %s, \"item\": %s, \"n\": %d}]," % (q("kist_" + r["id"].lower()), q(c), q(it), n))
        print("\t\t\"monsters\": [")
        for d in sorted(r.get("mon", {})):
            grp = r["mon"][d]
            t = objs["monsters"][d]
            still = d in r.get("still", [])
            extra = ', "guard": true' if still else ""
            print("\t\t\t{\"id\": %s, \"enemy\": %s, \"group\": %s, \"tile\": %s, \"moves\": %s%s}," % (
                q("m" + d), q(grp[0]), q(grp), q(t), "false" if still else "true", extra))
        print("\t\t],")
        print("\t},")
