#!/usr/bin/env python3
"""Samenvatting van SAPIENTIA-sessielogs (scripts/core/sessie_log.gd, JSON Lines).

Gebruik:
    python3 tools/sessielog/samenvat.py <bestand.jsonl | map> [...]

Een map = alle sessie_*.jsonl erin (oudste eerst). Per bestand: speeltijd per scene
(zonder app-pauzes), gevechten (winst/verlies/duur), game-overs per plek en de langste
stilstand. Kapotte of onbekende regels worden overgeslagen en geteld; ze breken niets.
Alleen standaardbibliotheek.
"""

import json
import os
import sys
from collections import Counter, OrderedDict

UITKOMST_NAAM = {"win": "winst", "lose": "verlies", "flee": "gevlucht"}


def tijd(secs):
    secs = max(0, int(round(secs)))
    if secs >= 3600:
        return "%dh %02dm %02ds" % (secs // 3600, secs % 3600 // 60, secs % 60)
    if secs >= 60:
        return "%dm %02ds" % (secs // 60, secs % 60)
    return "%ds" % secs


def lees(pad):
    """Geeft (regels, aantal_overgeslagen). Een regel = dict met t (getal), type, scene, data."""
    regels = []
    overgeslagen = 0
    with open(pad, "r", encoding="utf-8", errors="replace") as f:
        for ruw in f:
            ruw = ruw.strip()
            if not ruw:
                continue
            try:
                d = json.loads(ruw)
            except ValueError:
                overgeslagen += 1
                continue
            if not isinstance(d, dict) or not isinstance(d.get("type"), str):
                overgeslagen += 1
                continue
            t = d.get("t")
            if isinstance(t, bool) or not isinstance(t, (int, float)):
                overgeslagen += 1
                continue
            if not isinstance(d.get("data"), dict):
                d["data"] = {}
            if not isinstance(d.get("scene"), str):
                d["scene"] = ""
            regels.append(d)
    regels.sort(key=lambda d: d["t"])
    return regels, overgeslagen


def getal(v, standaard=0.0):
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        return standaard
    return v


def speeltijd_per_scene(regels):
    """Tijd tussen twee regels telt voor de scene van de eerste; een app-pauze telt niet."""
    per = OrderedDict()
    for vorige, volgende in zip(regels, regels[1:]):
        if vorige["type"] == "app_pauze":
            continue
        dt = volgende["t"] - vorige["t"]
        if dt <= 0:
            continue
        naam = vorige["scene"] or "(geen)"
        per[naam] = per.get(naam, 0.0) + dt
    return per


def samenvat(pad):
    regels, overgeslagen = lees(pad)
    uit = ["== %s ==" % os.path.basename(pad)]
    if not regels:
        uit.append("Geen bruikbare regels (overgeslagen: %d)." % overgeslagen)
        return "\n".join(uit)

    start = next((r for r in regels if r["type"] == "sessie_start"), None)
    stop = next((r for r in reversed(regels) if r["type"] == "sessie_stop"), None)
    info = (start or {}).get("data", {})
    duur = regels[-1]["t"] - regels[0]["t"]
    kop = "Versie %s (%s), modus %s, duur %s" % (
        info.get("versie", "?"), info.get("build", "?"), info.get("modus", "?"), tijd(duur))
    if stop is None:
        kop += " (geen sessie_stop: afgebroken of loopt nog)"
    uit.append(kop)
    uit.append("Regels: %d, overgeslagen (kapot/onbekend): %d" % (len(regels), overgeslagen))

    # speeltijd per scene
    per = speeltijd_per_scene(regels)
    totaal = sum(per.values()) or 1.0
    uit.append("")
    uit.append("Speeltijd per scene:")
    for naam, secs in sorted(per.items(), key=lambda kv: -kv[1]):
        uit.append("  %-26s %10s  %3d%%" % (naam, tijd(secs), round(100.0 * secs / totaal)))

    # gevechten
    gevechten = [r["data"] for r in regels if r["type"] == "gevecht_einde"]
    uit.append("")
    if gevechten:
        tel = Counter(str(g.get("uitkomst", "?")) for g in gevechten)
        delen = ["%s %d" % (UITKOMST_NAAM.get(k, k), n) for k, n in tel.most_common()]
        uit.append("Gevechten: %d (%s)" % (len(gevechten), ", ".join(delen)))
        duren = [getal(g.get("duur")) for g in gevechten]
        uit.append("  duur: gemiddeld %.1fs, langste %.1fs" % (sum(duren) / len(duren), max(duren)))
        uit.append("  %-28s %-9s %7s %7s %9s" % ("vijanden", "uitkomst", "duur", "beurten", "party-HP"))
        for g in gevechten:
            vijanden = g.get("vijanden") if isinstance(g.get("vijanden"), list) else []
            beurten = getal(g.get("beurten"), -1)
            uit.append("  %-28s %-9s %6.1fs %7s %4s%%>%s%%" % (
                ",".join(str(v) for v in vijanden)[:28],
                UITKOMST_NAAM.get(str(g.get("uitkomst", "?")), str(g.get("uitkomst", "?"))),
                getal(g.get("duur")),
                "-" if beurten < 0 else int(beurten),
                g.get("party_hp_pct_start", "?"), g.get("party_hp_pct", "?")))
    else:
        uit.append("Gevechten: geen")

    # game-overs
    overs = Counter(str(r["data"].get("plek", r["scene"] or "?")) for r in regels if r["type"] == "game_over")
    uit.append("")
    if overs:
        uit.append("Game-overs: %d" % sum(overs.values()))
        for plek, n in overs.most_common():
            uit.append("  %-26s %d" % (plek, n))
    else:
        uit.append("Game-overs: geen")

    # langste stilstand
    stil = [r for r in regels if r["type"] == "stilstand"]
    uit.append("")
    if stil:
        r = max(stil, key=lambda r: getal(r["data"].get("secs")))
        secs = getal(r["data"].get("secs"))
        vanaf = getal(r["data"].get("vanaf"), r["t"] - secs)
        uit.append("Langste stilstand: %s in %s (t=%.1fs tot %.1fs)" % (
            tijd(secs), r["scene"] or "(geen)", vanaf, r["t"]))
    else:
        uit.append("Langste stilstand: geen (nergens lang zonder invoer)")
    return "\n".join(uit)


def bestanden(paden):
    uit = []
    for p in paden:
        if os.path.isdir(p):
            namen = sorted(n for n in os.listdir(p) if n.startswith("sessie_") and n.endswith(".jsonl"))
            uit.extend(os.path.join(p, n) for n in namen)
        else:
            uit.append(p)
    return uit


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if len(argv) >= 2 else 2
    lijst = bestanden(argv[1:])
    if not lijst:
        print("Geen sessie_*.jsonl gevonden.")
        return 1
    code = 0
    for i, pad in enumerate(lijst):
        if i:
            print()
        try:
            print(samenvat(pad))
        except OSError as e:
            print("== %s ==\nKan niet lezen: %s" % (os.path.basename(pad), e))
            code = 1
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
