#!/usr/bin/env python3
"""Vergelijkt beeldopnames (wm1_meting.gd --pixels --pngdir=...) van voor en na een wijziging.

  python3 tools/geheugen/beeldcheck.py <voor_a> <voor_b> <na_a> [<na_b>]

Sommige kaarten hebben tijdgestuurde gloed/animatie, dus twee opnames van dezelfde code verschillen een
paar pixels (ruis, meestal 1 kleurwaarde). Daarom: ruismasker = pixels die tussen twee opnames van dezelfde
code verschillen (opgerekt met 2 px). Een wijziging is beeld-identiek als voor_a en na_a buiten dat masker
op geen enkele pixel verschillen. Exitcode 1 bij een verschil buiten het masker.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image


def laad(pad):
    return np.array(Image.open(pad).convert("RGBA")).astype(np.int16)


def oprekken(m, n=2):
    uit = m.copy()
    for dy in range(-n, n + 1):
        for dx in range(-n, n + 1):
            uit |= np.roll(np.roll(m, dy, axis=0), dx, axis=1)
    return uit


def main():
    va, vb, na = sys.argv[1], sys.argv[2], sys.argv[3]
    nb = sys.argv[4] if len(sys.argv) > 4 else None
    bestanden = sorted(os.path.basename(f) for f in glob.glob(os.path.join(va, "*.png")))
    totaal = ruis_px = buiten = identiek = 0
    slecht = []
    for f in bestanden:
        a, b, c = laad(os.path.join(va, f)), laad(os.path.join(vb, f)), laad(os.path.join(na, f))
        if a.shape != c.shape:
            slecht.append((f, "afmeting", a.shape, c.shape))
            continue
        ruis = (a != b).any(axis=2)
        if nb:
            d = laad(os.path.join(nb, f))
            ruis |= (c != d).any(axis=2)
        masker = oprekken(ruis)
        verschil = (a != c).any(axis=2)
        totaal += 1
        if not verschil.any():
            identiek += 1
        ruis_px += int(ruis.sum())
        out = verschil & ~masker
        buiten += int(out.sum())
        if out.any():
            ys, xs = np.where(out)
            slecht.append((f, int(out.sum()), (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))))
    print(f"{totaal} opnames vergeleken; {identiek} bit-identiek; ruis-pixels (tijdgestuurd): {ruis_px}; "
          f"verschillen buiten het ruismasker: {buiten}")
    for s in slecht:
        print("VERSCHIL", s)
    sys.exit(1 if slecht else 0)


main()
