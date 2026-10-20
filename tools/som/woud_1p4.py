#!/usr/bin/env python3
"""Donker Woud 1.4x (eenmalig, zie docs/MAP_SCALE_PLAN.md): rij/kolom-verdubbeling op de
ASCII-layouts in scripts/data/woud_rooms.gd en omrekenen van alle vaste tegels in die kamer.
Nooit verdubbeld: rand (rij 0-3, onderste 2 rijen, kolom 0-1 en laatste 2), en rijen/kolommen met
structuur (boog/uitgang, pilaren 13/LR, wortelheuvel [=]{~}, kuilrand Y, wortelpad j, opslagsokkel @).
In een kopie worden losse decortegels vloer ('.') en muurvarianten gewone muur (F/f/s)."""
import re, sys
P = "scripts/data/woud_rooms.gd"
STRUCT_C = set("1Llrn()AUE[]{}=~^oOJ@I")    # kolom mag 3/R (rechterhelft pilaar) en j bevatten
STRUCT_R = set("13lrAn()UE{}~^oOYJ@I")    # rij mag L/R (voet van pilaar) en j bevatten
DECOR = {c: "." for c in "xpw,*#BNPiCDX"}
COPY = dict(DECOR, **{"M": "F", "K": "F", "G": "F", "m": "f", "k": "f", "g": "f", "3": ".", "R": "."})
DUP_COPY_ROW = dict(DECOR, **{"L": ".", "R": ".", "j": "."})

def pick(allowed, n):
    if n <= 0: return []
    if len(allowed) < n: raise SystemExit(f"te weinig vrije lijnen {allowed} {n}")
    step = len(allowed) / n
    return sorted(allowed[int(i * step + step / 2)] for i in range(n))

def scale(layout):
    H, W = len(layout), len(layout[0])
    W2, H2 = round(W * 1.4), round(H * 1.4)
    cols = [x for x in range(2, W - 2) if not any(layout[y][x] in STRUCT_C for y in range(H))]
    rows = [y for y in range(4, H - 1) if not any(c in STRUCT_R for c in layout[y][2:W - 2])]
    dc, dr = pick(cols, W2 - W), pick(rows, H2 - H)
    X, x2 = [], 0
    for x in range(W):
        X.append(x2); x2 += 2 if x in dc else 1
    Y, y2 = [], 0
    for y in range(H):
        # rij vlak boven de zuiduitgang: laatste kopie, zodat spawns/mist tegen de uitgang blijven
        Y.append(y2 + (1 if (y == H - 2 and y in dr) else 0)); y2 += 2 if y in dr else 1
    out = []
    for y in range(H):
        row = ""
        for x in range(W):
            c = layout[y][x]; row += c
            if x in dc: row += ("s" if c == "3" and y == 3 else COPY.get(c, c))
        if y in dr and y == H - 2:
            out.append("".join(DUP_COPY_ROW.get(c, c) for c in row))
        out.append(row)
        if y in dr and y != H - 2:
            out.append("".join(DUP_COPY_ROW.get(c, c) for c in row))
    return out, X, Y, dc, dr

src = open(P).read()
heads = list(re.finditer(r'^\t"(woud_\w+)": \{', src, re.M))
end = src.index("\n}\n", heads[-1].start())
pieces, last = [], 0
report = []
for i, h in enumerate(heads):
    s = h.start(); e = heads[i + 1].start() if i + 1 < len(heads) else end
    pieces.append(src[last:s]); blk = src[s:e]; last = e
    lm = re.search(r'"layout": \[\n(.*?)\n\t*\],', blk, re.S)
    layout = re.findall(r'"([^"]*)"', lm.group(1))
    new, X, Y, dc, dr = scale(layout)
    ind = re.search(r'\n(\t*)"', lm.group(0)).group(1)
    blk = blk[:lm.start()] + '"layout": [\n' + "".join(f'{ind}"{r}",\n' for r in new) + ind[:-1] + "]," + blk[lm.end():]
    pt = lambda m: f"{m.group(1)}[{X[int(m.group(2))]}, {Y[int(m.group(3))]}"
    blk = re.sub(r'("tile": )\[(\d+), (\d+)', pt, blk)
    blk = re.sub(r'("save": )\[(\d+), (\d+)', pt, blk)
    blk = re.sub(r'("\w+": )\[(\d+), (\d+)(?=, "(?:up|down|left|right)")', pt, blk)
    def lijst(key, fn):
        global blk
        m = re.search(r'"%s": \[(.*)\],\n' % key, blk)
        if m:
            inner = re.sub(r'\[(\d+), (\d+), ([^\]]+)\]', fn, m.group(1))
            blk = blk[:m.start(1)] + inner + blk[m.end(1):]
    lijst("trees", lambda m: f"[{X[int(m.group(1))]}, {Y[int(m.group(2))]}, {m.group(3)}]")
    lijst("overlay", lambda m: f"[{X[int(m.group(1))]}, {Y[int(m.group(2))]}, {m.group(3)}]")
    def mist(m):
        x, y, n = int(m.group(1)), int(m.group(2)), int(m.group(3))
        return f"[{X[x]}, {Y[y]}, {X[x + n - 1] - X[x] + 1 + (1 if x + n - 1 in dc else 0)}]"
    lijst("mist", mist)
    blk = re.sub(r'\((\d+)x(\d+)', lambda m: f"({len(new[0])}x{len(new)}" if m.group(0) == f"({len(layout[0])}x{len(layout)}" else m.group(0), blk, count=1)
    pieces.append(blk)
    report.append(f"{h.group(1)}: {len(layout[0])}x{len(layout)} -> {len(new[0])}x{len(new)}; rijen {dr}; kolommen {dc}")
pieces.append(src[last:])
open(P, "w").write("".join(pieces))
print("\n".join(report))
