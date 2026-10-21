#!/usr/bin/env python3
"""Archief 2 (Het Levende Archief) 1.4x (eenmalig, zie docs/MAP_SCALE_PLAN.md). Zelfde methode als
Esdoorn (#133) / Donker Woud: rij/kolom-verdubbeling, geen vrije herschaling.
- 20x12-kamers -> 28x17, leven_ingang 16x11 -> 22x15.
- Nooit verdubbeld: rand (rij 0-3, onderrij, kolom 0-1 en laatste), uitgang-/boogkolommen ((EE), n),
  brugkolommen, deur-/brugrijen (rijen met '#': groei-/tegen-/licht-brugrij en baas-poortrij),
  podium van De Genezer (kolom 5,6,8-10,12,13; rij 3-6).
- In een kopie: losse decor/props in de grondlaag -> vloer (0/1/2, vaste hash), muurvarianten -> gewone muur.
- Openingen in een '#'-rij blijven even breed als voorheen (smalle doorgang wordt niet breder).
- Punten: x' = eerste kopie; rij H-2 (vlak boven de uitgang) = laatste kopie, zodat de spawn tegen de uitgang blijft.
- Lijsten met tegels (bruggen, blokkades): elke kopie van een verdubbelde kolom komt erbij.
Gebruik: python3 tools/som/archief2_1p4.py   (weigert kamers die al geschaald zijn)"""
import re, sys
R = "scripts/data/archief2_rooms.gd"
GR = "scripts/data/archief2_ground.gd"
WR = "scripts/dungeon/archief2_warpers.gd"

# extra kopieën per kolom (20 breed): links 2,3,4,7; rechts 15,16,17 -> 27 (feedback Forge: geen driedubbele kolommen)
COLS20 = {2: 1, 3: 1, 4: 1, 7: 1, 15: 1, 16: 1, 17: 1}   # 27 breed, symmetrisch rond (EE) 13-14; nooit 3x
# leven_ingang (16 breed): uitgang (EE) 7-8, boog n 9 -> 6 extra
COLS16 = {2: 1, 3: 1, 5: 1, 11: 1, 12: 1, 13: 1}
GENEZER_PODIUM_ROWS = {4, 5, 6, 7}   # podium 48-56 + zegel 62/63

WALL_COPY = {46: 32, 38: 32, 42: 32, 40: 32, 47: 33, 39: 33, 43: 33, 41: 33}
REPEAT = {0, 1, 2, 8, 9, 10, 17, 19, 21, 23, 32, 33, 59, 49, 52, 55}
LAYOUT_COPY = {"M": "F", "G": "F", "A": "F", "m": "f", "g": "f", "x": ".", "@": "."}


def maps(n, dup, last_row=None):
    first, lastc, k = [], [], 0
    for i in range(n):
        first.append(k); k += 1 + dup.get(i, 0); lastc.append(k - 1)
    return first, lastc, k


def vloer(x, y):
    return (x * 7 + y * 13) % 3


def copy_tile(t, x, y, gap_rij=False):
    if t in WALL_COPY: return WALL_COPY[t]
    if t == 59 and not gap_rij: return vloer(x, y)   # losse plantenbak buiten een brugrij niet verdubbelen
    if t in REPEAT: return t
    return vloer(x, y)


def scale_ground(g, cd, rd, lay):
    H, W = len(g), len(g[0])
    # kolommen
    rows = []
    for y in range(H):
        r = []
        for x in range(W):
            r.append(g[y][x])
            for _ in range(cd.get(x, 0)):
                r.append(copy_tile(g[y][x], len(r), y, "#" in lay[y]))
        rows.append(r)
    out = []
    for y in range(H):
        extra = rd.get(y, 0)
        cp = lambda: [copy_tile(t, x, len(out)) if t not in (19, 21) else t for x, t in enumerate(rows[y])]
        if y == H - 2:
            for _ in range(extra): out.append(cp())
            out.append(rows[y])
        else:
            out.append(rows[y])
            for _ in range(extra): out.append(cp())
    # 2 tegels hoge props (70 boven / 71 onder) niet uit elkaar trekken: de bovenkant schuift naar
    # direct boven de onderkant, de oude plek wordt vloer
    for x in range(len(out[0])):
        for y in range(len(out) - 1):
            if out[y][x] == 70 and out[y + 1][x] != 71:
                for k in range(y + 2, min(y + 5, len(out))):
                    if out[k][x] == 71:
                        out[y][x] = vloer(x, y); out[k - 1][x] = 70
                        break
    return out


def scale_row(s, cd):
    out = ""
    for x, c in enumerate(s):
        out += c
        for _ in range(cd.get(x, 0)):
            out += LAYOUT_COPY.get(c, c)
    if "#" in s:   # openingen (runs van niet-'#') even breed houden als voorheen
        o = list(out)
        Xf, Xl, _ = maps(len(s), cd)
        x = 0
        while x < len(s):
            if s[x] == "." :
                e = x
                while e + 1 < len(s) and s[e + 1] == ".": e += 1
                for k in range(Xf[x] + (e - x + 1), Xl[e] + 1): o[k] = "#"
                x = e + 1
            else:
                x += 1
        out = "".join(o)
    return out


def fix_gap_ground(g2, lay_oud, lay2, cd, Ynew):
    """Alleen een gesloten kopie van een opening in een '#'-rij wordt plantenbak 59; eigen grond
    (podium, onzichtbare blokkades) blijft zoals hij was."""
    Xf, _, _ = maps(len(lay_oud[0]), cd)
    for y, row in enumerate(lay_oud):
        if "#" not in row: continue
        ny = Ynew[y]
        Xl_ = maps(len(lay_oud[0]), cd)[1]
        for x in range(len(row)):   # elke dichtgemaakte tegel van een opening (ook het origineel, bv. tegen (6,4))
            for nx in range(Xf[x], Xl_[x] + 1):
                if row[x] == "." and lay2[ny][nx] == "#": g2[ny][nx] = 59
        for nx, c in enumerate(lay2[ny]):   # open tegel in een '#'-rij is nooit plantenbak
            if c == "." and g2[ny][nx] == 59: g2[ny][nx] = vloer(nx, ny)


def pick_rows(layout, extra, verboden=set()):
    H = len(layout)
    ok = [y for y in range(4, H - 1) if "#" not in layout[y] and y not in verboden]
    rd = {}
    if not ok: raise SystemExit("geen vrije rijen")
    step = len(ok) / min(extra, len(ok))
    for i in range(min(extra, len(ok))):
        y = ok[int(i * step + step / 2)]; rd[y] = 1
    return rd   # te weinig vrije rijen (Genezer): kamer wordt iets lager, nooit 3x


def gd_rows(g, ind="\t\t"):
    return "".join(f"{ind}[{', '.join(str(t) for t in r)}],\n" for r in g)


ground_src = open(GR).read()
def lees_ground(rid):
    m = re.search(r'\t"%s": \[\n(.*?)\n\t\],' % rid, ground_src, re.S)
    return m, [list(map(int, re.findall(r"-?\d+", l))) for l in m.group(1).split("\n")]

src = open(R).read()
consts = dict(re.findall(r'^const (_\w+) := "([^"]*)"$', src, re.M))
assert len(consts["_F"]) == 20, "al geschaald?"
# baaspoort 2 breed (kolom 9-10, in lijn met de uitgang (EE)); de tweede tegel is dicht tot de baas verslagen is
assert consts["_B"] == "<S#######.#########>"
src = src.replace('const _B := "<S#######.#########>"', 'const _B := "<S#######..########>"')
consts["_B"] = "<S#######..########>"
report = []

# ---- 20x12-kamers: constanten (kolommen) + per kamer de rijen ----
Xf, Xl, W2 = maps(20, COLS20)
for k, v in consts.items():
    src = src.replace(f'const {k} := "{v}"', f'const {k} := "{scale_row(v, COLS20)}"')
basis_layout = ["_TOP", "_WU", "_WL", "_SH", "_F", "_F", "_F", "_F", "_F", "_F", "_F", "_BOT"]

def var_blocks(s):
    body_start = s.index("static func rooms()")
    heads = list(re.finditer(r'^\tvar (\w+) := _met\(', s[body_start:], re.M))
    ret = re.search(r'^\treturn \{', s[body_start:], re.M).start()
    out = []
    for i, h in enumerate(heads):
        a = body_start + h.start(); b = body_start + (heads[i + 1].start() if i + 1 < len(heads) else ret)
        out.append((h.group(1), a, b))
    return out

ids = dict(re.findall(r'^\t\t"(archief_2_\w+)": (\w+),$', src, re.M))
var2id = {v: k for k, v in ids.items()}
pieces, last = [], 0
gpatch = {}
for var, a, b in var_blocks(src):
    rid = var2id[var]; blk = src[a:b]
    lm = re.search(r'"layout": \[([^\]]*)\]', blk)
    names = [n.strip() for n in lm.group(1).split(",")] if lm else basis_layout
    lay = [consts[n] for n in names]
    verboden = GENEZER_PODIUM_ROWS if rid == "archief_2_v4_genezer" else set()
    rd = pick_rows(lay, 5, verboden)
    Yf, Yl, H2 = maps(12, rd)
    Y = lambda y: Yl[y] if y == 10 else Yf[y]
    new_names = []
    for y, n in enumerate(names):
        new_names += [n] * (1 + rd.get(y, 0))
    nl = '"layout": [' + ", ".join(new_names) + "]"
    if lm: blk = blk[:lm.start()] + nl + blk[lm.end():]
    else: blk = blk.replace("_met(_basis(", "_met(_basis(", 1).replace("{\n", "{\n\t\t" + nl + ",\n", 1)
    if H2 != 17:   # lagere kamer (Genezer): eigen spawns, zuid blijft vlak boven de uitgang
        blk = blk.replace(nl + ",", nl + ',\n\t\t"spawns": {"zuid": [%d, %d, "up"], "noord": [%d, 3, "down"], "ingang": [%d, %d, "up"]},' % (Xf[9], Y(10), Xf[9], Xf[9], Y(10)), 1)
    if rid in ("archief_2_v2_lotte", "archief_2_v3_wurger"):   # tweede poorttegel dicht tot de baas weg is
        bid = "lotte" if "lotte" in rid else "wurger"
        blk = blk.replace('\t\t"monsters": [{', '\t\t# poort 2 breed: (10,5) in 20x12-coördinaten = (14,6) na schalen; dicht tot de bewaker verslagen is\n\t\t"blokkades": {"tot_vlag": "bewaker:%s/%s", "tiles": [[10, 5]]},\n\t\t"monsters": [{' % (rid, bid), 1)
    pt = lambda m: f'{m.group(1)}[{Xf[int(m.group(2))]}, {Y(int(m.group(3)))}]'
    blk = re.sub(r'("(?:tile|save|warp)": )\[(\d+), (\d+)\]', pt, blk)
    def lijst(m):
        tiles = re.findall(r'\[(\d+), (\d+)\]', m.group(2))
        nt = []
        for x, y in tiles:
            x, y = int(x), int(y)
            for xx in range(Xf[x], Xl[x] + 1): nt.append(f"[{xx}, {Y(y)}]")
        return m.group(1) + "[" + ", ".join(nt) + "]"
    blk = re.sub(r'("tiles": )\[((?:\[\d+, \d+\](?:,\s*)?)+)\]', lijst, blk)
    pieces.append(src[last:a]); pieces.append(blk); last = b
    gm, g = lees_ground(rid)
    g2 = scale_ground(g, COLS20, rd, lay)
    lay2 = [scale_row(consts[n], COLS20) for n in new_names]
    fix_gap_ground(g2, lay, lay2, COLS20, Yf)
    assert len(g2) == len(lay2) == 12 + sum(rd.values()) and all(len(r) == W2 for r in g2), rid
    gpatch[rid] = g2
    report.append(f"{rid}: 20x12 -> {W2}x{12 + sum(rd.values())}; rijen {dict(rd)}")
pieces.append(src[last:])
src = "".join(pieces)
# _basis: standaard-layout 17 rijen (F-kamer) en spawns
Yb, Ybl, _ = maps(12, pick_rows([consts[n] for n in basis_layout], 5))
src = src.replace('"layout": [_TOP, _WU, _WL, _SH, _F, _F, _F, _F, _F, _F, _F, _BOT],',
                  '"layout": [_TOP, _WU, _WL, _SH' + ", _F" * 12 + ", _BOT],", 1)
src = src.replace('"spawns": {"zuid": [9, 10, "up"], "noord": [9, 3, "down"], "ingang": [9, 10, "up"]},',
                  '"spawns": {"zuid": [%d, 15, "up"], "noord": [%d, 3, "down"], "ingang": [%d, 15, "up"]},' % (Xf[9], Xf[9], Xf[9]))


# ---- leven_ingang 16x11 -> 22x15 ----
m = re.search(r'("leven_ingang": \{.*?"layout": \[\n)(.*?)(\n\t\t\],)(.*?)\n\t\},', src, re.S)
lay = re.findall(r'"([^"]*)"', m.group(2))
assert len(lay[0]) == 16
rd = pick_rows(lay, 4)
Xf6, Xl6, _ = maps(16, COLS16); Yf6, Yl6, _ = maps(11, rd)
Y6 = lambda y: Yl6[y] if y == 9 else Yf6[y]
lay2 = []
for y, r in enumerate(lay):
    r2 = scale_row(r, COLS16)
    cp = "".join(LAYOUT_COPY.get(c, c) for c in r2)
    if y == 9: lay2 += [cp] * rd.get(y, 0) + [r2]
    else: lay2 += [r2] + [cp] * rd.get(y, 0)
rest = m.group(4)
pt6 = lambda mm: f'{mm.group(1)}[{Xf6[int(mm.group(2))]}, {Y6(int(mm.group(3)))}'
rest = re.sub(r'("(?:tile|save)": )\[(\d+), (\d+)', pt6, rest)
rest = re.sub(r'("\w+": )\[(\d+), (\d+)(?=, "(?:up|down|left|right)")', pt6, rest)
src = src[:m.start()] + m.group(1) + "\n".join(f'\t\t\t"{r}",' for r in lay2) + m.group(3) + rest + "\n\t}," + src[m.end():]
gm, g = lees_ground("leven_ingang")
g2 = scale_ground(g, COLS16, rd, lay); fix_gap_ground(g2, lay, lay2, COLS16, Yf6)
assert len(g2) == 15 and all(len(r) == 22 for r in g2)
gpatch["leven_ingang"] = g2
report.append(f"leven_ingang: 16x11 -> 22x15; rijen {dict(rd)}; kolommen {COLS16}")
src = src.replace("# 1 KAS (16x11)", "# 1 KAS (22x15, was 16x11)")
open(R, "w").write(src)

for rid, g2 in gpatch.items():
    gm, _ = lees_ground(rid)
    ground_src = ground_src[:gm.start()] + f'\t"{rid}": [\n' + gd_rows(g2).rstrip("\n") + "\n\t]," + ground_src[gm.end():]
open(GR, "w").write(ground_src)

w = open(WR).read()
w = w.replace("## Naast de ingang-spawn (9, 10), niet op de uitgang.\nconst BEGIN_TILE := Vector2i(8, 10)",
              f"## Naast de ingang-spawn ({Xf[9]}, 15), niet op de uitgang (1.4x: was (8, 10)).\nconst BEGIN_TILE := Vector2i({Xf[8]}, 15)")
open(WR, "w").write(w)
# ---- puzzelkamers (puzzle_rooms.gd): alleen de rand/aanloop, rooster ongewijzigd ----
# Links en rechts extra vloer-/kloofkolommen (de kloof '~'/'V' loopt door tot de muur), onderaan extra
# aanlooprijen tussen puzzel en ingang E. De puzzel zelf (hendel, kast, plaat, groei-plaat, kloof, X) schuift
# alleen mee met de linkermarge: onderlinge posities en rijnummers blijven gelijk.
PR = "scripts/data/puzzle_rooms.gd"
PUZ = {"leven_v1_plaat": (3, 3, 4), "leven_v3_combi": (2, 2, 3)}   # links, rechts, rijen onder
ps = open(PR).read()
for rid, (L, Rr, B) in PUZ.items():
    m = re.search(r'\t"%s": \{.*?\n\t\},\n' % rid, ps, re.S)
    blk = m.group(0)
    def breed(key, blk):
        lm = re.search(r'("%s": \[\n)(.*?)(\n\t\t\],)' % key, blk, re.S)
        rows = re.findall(r'"([^"]*)"', lm.group(2))
        assert len(rows[0]) in (15, 11), (rid, "al geschaald?")
        vul = lambda c: c if c in "#~V-_." else "."   # nooit een puzzelobject kopiëren
        out = [r[:2] + vul(r[2]) * L + r[2:-1] + vul(r[-2]) * Rr + r[-1] for r in rows]
        out = out[:-1] + [out[-2]] * B + out[-1:]
        return blk[:lm.start()] + lm.group(1) + "\n".join(f'\t\t\t"{r}",' for r in out) + lm.group(3) + blk[lm.end():], (len(rows[0]), len(rows), len(out[0]), len(out))
    blk, maat = breed("layout", blk)
    blk, _ = breed("look", blk)
    blk = re.sub(r'("noord": )\[(\d+), (\d+)', lambda mm: f'{mm.group(1)}[{int(mm.group(2)) + L}, {mm.group(3)}', blk)
    ps = ps[:m.start()] + blk + ps[m.end():]
    report.append(f"{rid}: {maat[0]}x{maat[1]} -> {maat[2]}x{maat[3]} (puzzel +{L} in x, rijen gelijk)")
open(PR, "w").write(ps)
print(f"kolommen 20->{W2}: {COLS20} (X(9)={Xf[9]})")
print("\n".join(report))
