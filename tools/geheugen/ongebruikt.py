#!/usr/bin/env python3
"""Zoekt png's in assets/, art/ en world_warper/ waarvan de bestandsnaam (stam) nergens in de runtime-bronnen
voorkomt (scripts/, scenes/, world_warper/, pvp/, project.godot, *.tres, *.json, *.tscn). Dat is een
ondergrens-heuristiek: dynamische paden (`P10 + naam + ".png"`) worden alleen via de stam gevonden.
Verwijdert niets; handgetekende art (tools/handwerk.txt) wordt apart gemarkeerd.

  python3 tools/geheugen/ongebruikt.py
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BRON_EXT = (".gd", ".tscn", ".tres", ".json", ".cfg", ".godot", ".md")
BRON_DIRS = ["scripts", "scenes", "world_warper", "pvp", "assets", "data"]
PNG_DIRS = ["assets", "art", "world_warper"]


def tekst_bronnen():
    delen = []
    for d in BRON_DIRS:
        for dp, dn, fn in os.walk(os.path.join(ROOT, d)):
            for f in fn:
                if f.endswith(BRON_EXT) and not f.endswith(".md"):
                    try:
                        delen.append(open(os.path.join(dp, f), errors="ignore").read())
                    except OSError:
                        pass
    delen.append(open(os.path.join(ROOT, "project.godot"), errors="ignore").read())
    return "\n".join(delen)


def handwerk():
    out = set()
    for l in open(os.path.join(ROOT, "tools", "handwerk.txt"), errors="ignore"):
        l = l.strip()
        if l and not l.startswith("#"):
            out.add(l)
    return out


def main():
    tekst = tekst_bronnen()
    hw = handwerk()
    kandidaten = []
    for d in PNG_DIRS:
        for dp, dn, fn in os.walk(os.path.join(ROOT, d)):
            for f in fn:
                if not f.endswith(".png"):
                    continue
                rel = os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, "/")
                stam = f[:-4]
                if stam not in tekst:
                    kandidaten.append((os.path.getsize(os.path.join(dp, f)), rel, rel in hw))
    kandidaten.sort(reverse=True)
    tot = sum(k[0] for k in kandidaten)
    print(f"{len(kandidaten)} png's zonder verwijzing (stam), samen {tot / 1e6:.2f} MB op schijf (niet in RAM: niet geladen)")
    for grootte, rel, hand in kandidaten:
        print(f"{grootte:>9} {'HANDWERK ' if hand else ''}{rel}")


main()
