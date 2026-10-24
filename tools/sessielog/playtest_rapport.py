#!/usr/bin/env python3
"""WM1-playtestrapport uit SAPIENTIA-sessielogs (scripts/core/sessie_log.gd, JSON Lines, alleen debug-builds).

Gebruik:
    python3 tools/sessielog/playtest_rapport.py <bestand.jsonl | map> [...] [--json] [--strict]

Een map = alle sessie_*.jsonl erin (oudste eerst). Per sessie en samen:
  - speeltijd per gebied en per kaart (data/playtest_gebieden.json; app-pauzes tellen niet mee),
  - gevechten per gebied (winst/verlies/gevlucht), baasgevechten, zwaarste gevechten,
  - doden en game-overs per kaart,
  - crashes: een sessie zonder sessie_stop (afgebroken), crash_vorige-regels en vastlopers (frame-gaten),
  - quest-voortgang in tijdsvolgorde.
Kapotte regels worden overgeslagen en geteld. Alleen standaardbibliotheek.

Opties:
    --json     machineleesbaar rapport (zelfde cijfers) in plaats van tekst
    --strict   exitcode 3 als er een crash, een dood of een vastloper in zit (handig als poort na een playtest)
Exitcodes: 0 goed, 1 geen bestanden/niet leesbaar, 2 verkeerd gebruik, 3 --strict en iets gevonden.
"""

import json
import os
import sys
from collections import OrderedDict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from samenvat import bestanden, getal, lees, tijd  # noqa: E402

GEBIEDEN_PAD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data", "playtest_gebieden.json")
ONBEKEND = "overig"
VASTLOPER_SECS = 3.0
UITKOMST = {"win": "winst", "lose": "verlies", "flee": "gevlucht"}


def laad_gebieden(pad=GEBIEDEN_PAD):
    """Zelfde indeling als scripts/data/playtest_gebieden.gd. Geeft (volgorde [(id, naam)], functie kaart->id)."""
    try:
        with open(pad, "r", encoding="utf-8") as f:
            lijst = json.load(f).get("gebieden", [])
    except (OSError, ValueError):
        lijst = []
    volgorde = [(g.get("id", ONBEKEND), g.get("naam", g.get("id", ONBEKEND))) for g in lijst if isinstance(g, dict)]

    def gebied_van(kaart):
        beste, beste_len = "", -1
        for g in lijst:
            if not isinstance(g, dict):
                continue
            if kaart in g.get("maps", []):
                return g.get("id", ONBEKEND)
            for p in g.get("prefix", []):
                if kaart.startswith(p) and len(p) > beste_len:
                    beste, beste_len = g.get("id", ONBEKEND), len(p)
        return beste or ONBEKEND

    return volgorde, gebied_van


def _tel(d, sleutel, waarde):
    d[sleutel] = d.get(sleutel, 0.0) + waarde


def analyseer(pad, gebied_van):
    """Eén sessiebestand -> dict met alle cijfers (JSON-vriendelijk)."""
    regels, overgeslagen = lees(pad)
    uit = {"bestand": os.path.basename(pad), "regels": len(regels), "overgeslagen": overgeslagen}
    if not regels:
        uit.update({"leeg": True})
        return uit
    start = next((r for r in regels if r["type"] == "sessie_start"), None)
    stop = next((r for r in reversed(regels) if r["type"] == "sessie_stop"), None)
    info = (start or {}).get("data", {})
    uit["versie"] = info.get("versie", info.get("spel", "?"))
    uit["build"] = info.get("build", "?")
    uit["modus"] = info.get("modus", "?")
    uit["utc"] = info.get("utc", "")
    uit["duur"] = round(regels[-1]["t"] - regels[0]["t"], 1)
    uit["netjes_gestopt"] = stop is not None

    kaart_secs, gebied_secs = OrderedDict(), OrderedDict()
    cur_kaart, cur_start, pauze_in_kaart = None, 0.0, 0.0
    pauze_totaal = 0.0
    onvolledig = False
    dooden, game_overs, respawns = [], [], []
    gevechten, open_gevecht = [], None
    quests, vastlopers, crash_vorige = [], [], []
    stilstanden, saves, loads = 0, 0, 0
    kaart_tijd_regels = 0

    for r in regels:
        typ, d, t = r["type"], r["data"], r["t"]
        if typ == "kaart":
            cur_kaart = str(d.get("kaart", "?"))
            cur_start = t
            pauze_in_kaart = 0.0
        elif typ == "kaart_tijd":
            kaart_tijd_regels += 1
            k = str(d.get("kaart", "?"))
            secs = max(0.0, getal(d.get("secs")) - pauze_in_kaart)
            _tel(kaart_secs, k, secs)
            _tel(gebied_secs, gebied_van(k), secs)
            cur_kaart, pauze_in_kaart = None, 0.0
        elif typ == "app_hervat":
            p = getal(d.get("pauze"))
            pauze_totaal += p
            pauze_in_kaart += p
        elif typ == "gevecht_start":
            open_gevecht = {"kaart": str(d.get("kaart", "?")), "vijanden": d.get("vijanden", []),
                            "baas": bool(d.get("baas", False)), "t": t,
                            "hp_start": d.get("party_hp_pct")}
        elif typ == "gevecht_eind":
            g = open_gevecht or {"kaart": str(d.get("kaart", "?")), "vijanden": [], "baas": False, "t": t}
            g.update({"uitkomst": str(d.get("resultaat", "?")), "secs": getal(d.get("secs")),
                      "ronden": int(getal(d.get("ronden"))), "hp_verlies": int(getal(d.get("hp_verlies")))})
            g["gebied"] = gebied_van(g["kaart"])
            gevechten.append(g)
            open_gevecht = None
        elif typ == "dood":
            k = str(d.get("kaart", "?"))
            dooden.append({"t": t, "kaart": k, "gebied": gebied_van(k), "reden": str(d.get("reden", "?"))})
        elif typ == "game_over":
            game_overs.append({"t": t, "plek": str(d.get("plek", "?"))})
        elif typ == "respawn":
            respawns.append({"t": t, "naar": str(d.get("naar", "?")), "soort": str(d.get("soort", "?"))})
        elif typ == "quest_update":
            quests.append({"t": t, "quest": str(d.get("quest", "?")), "stappen": d.get("stappen"),
                           "klaar": bool(d.get("klaar", False))})
        elif typ == "gat":
            s = getal(d.get("secs"))
            if s >= VASTLOPER_SECS:
                vastlopers.append({"t": t, "secs": s, "scene": r["scene"]})
        elif typ == "crash_vorige":
            crash_vorige.append({"bestand": d.get("bestand", "?"), "kaart": d.get("kaart", ""),
                                 "laatste_type": d.get("laatste_type", ""), "laatste_t": d.get("laatste_t")})
        elif typ == "stilstand":
            stilstanden += 1
        elif typ == "save":
            saves += 1
        elif typ == "load":
            loads += 1

    # sessie afgebroken midden op een kaart: de laatste kaart heeft geen kaart_tijd
    if cur_kaart is not None:
        secs = max(0.0, regels[-1]["t"] - cur_start - pauze_in_kaart)
        _tel(kaart_secs, cur_kaart, secs)
        _tel(gebied_secs, gebied_van(cur_kaart), secs)
        onvolledig = True

    # oudste regels getrimd (bestand vol): val terug op de totalen in sessie_stop
    samenvatting = (stop or {}).get("data", {}).get("samenvatting")
    if kaart_tijd_regels == 0 and isinstance(samenvatting, dict) and not kaart_secs:
        for k, v in (samenvatting.get("kaart_secs") or {}).items():
            _tel(kaart_secs, k, getal(v))
        for k, v in (samenvatting.get("gebied_secs") or {}).items():
            _tel(gebied_secs, k, getal(v))
        uit["tijd_uit_samenvatting"] = True

    uit["pauze_secs"] = round(pauze_totaal, 1)
    uit["kaart_secs"] = {k: round(v, 1) for k, v in kaart_secs.items()}
    uit["gebied_secs"] = {k: round(v, 1) for k, v in gebied_secs.items()}
    uit["laatste_kaart_afgebroken"] = onvolledig
    uit["gevechten"] = gevechten
    uit["doden"] = dooden
    uit["game_overs"] = game_overs
    uit["respawns"] = respawns
    uit["quest_updates"] = quests
    uit["vastlopers"] = vastlopers
    uit["crash_vorige"] = crash_vorige
    uit["stilstanden"] = stilstanden
    uit["saves"] = saves
    uit["loads"] = loads
    return uit


def combineer(sessies):
    """Totalen over alle sessies. De laatste sessie zonder sessie_stop kan nog lopen: telt als 'afgebroken'."""
    tot = {"sessies": len(sessies), "duur": 0.0, "gebied_secs": OrderedDict(), "kaart_secs": OrderedDict(),
           "gevechten": 0, "uitkomsten": {}, "doden": 0, "game_overs": 0, "afgebroken": 0, "vastlopers": 0,
           "crash_vorige": 0}
    for s in sessies:
        if s.get("leeg"):
            continue
        tot["duur"] += s["duur"]
        for k, v in s["gebied_secs"].items():
            _tel(tot["gebied_secs"], k, v)
        for k, v in s["kaart_secs"].items():
            _tel(tot["kaart_secs"], k, v)
        tot["gevechten"] += len(s["gevechten"])
        for g in s["gevechten"]:
            _tel(tot["uitkomsten"], g["uitkomst"], 1)
        tot["doden"] += len(s["doden"])
        tot["game_overs"] += len(s["game_overs"])
        tot["vastlopers"] += len(s["vastlopers"])
        tot["crash_vorige"] += len(s["crash_vorige"])
        if not s["netjes_gestopt"]:
            tot["afgebroken"] += 1
    tot["duur"] = round(tot["duur"], 1)
    tot["uitkomsten"] = {k: int(v) for k, v in tot["uitkomsten"].items()}
    return tot


def _gebieden_regels(secs, volgorde, uit):
    totaal = sum(secs.values()) or 1.0
    namen = dict(volgorde)
    gezien = set()
    rij = [(i, namen.get(i, i)) for i, _ in volgorde] + [(ONBEKEND, "Overig (niet ingedeeld)")]
    for gid, naam in rij:
        if gid in gezien or gid not in secs:
            continue
        gezien.add(gid)
        uit.append("  %-30s %10s  %3d%%" % (naam, tijd(secs[gid]), round(100.0 * secs[gid] / totaal)))
    for gid, v in secs.items():
        if gid not in gezien:
            uit.append("  %-30s %10s  %3d%%" % (gid, tijd(v), round(100.0 * v / totaal)))


def tekst_sessie(s, volgorde, gebied_van):
    uit = ["== %s ==" % s["bestand"]]
    if s.get("leeg"):
        uit.append("Geen bruikbare regels (overgeslagen: %d)." % s["overgeslagen"])
        return "\n".join(uit)
    kop = "Versie %s (%s), modus %s, duur %s" % (s["versie"], s["build"], s["modus"], tijd(s["duur"]))
    if not s["netjes_gestopt"]:
        kop += "  ** GEEN sessie_stop: crash, afgesloten of loopt nog **"
    uit.append(kop)
    uit.append("Regels: %d, overgeslagen: %d, pauze (niet meegeteld): %s" % (s["regels"], s["overgeslagen"], tijd(s["pauze_secs"])))

    uit.append("")
    uit.append("Speeltijd per gebied%s:" % (" (uit samenvatting)" if s.get("tijd_uit_samenvatting") else ""))
    _gebieden_regels(s["gebied_secs"], volgorde, uit)
    uit.append("Speeltijd per kaart (top 8):")
    for k, v in sorted(s["kaart_secs"].items(), key=lambda kv: -kv[1])[:8]:
        uit.append("  %-30s %10s  (%s)" % (k, tijd(v), gebied_van(k)))

    g = s["gevechten"]
    uit.append("")
    if g:
        tel = {}
        for x in g:
            tel[x["uitkomst"]] = tel.get(x["uitkomst"], 0) + 1
        uit.append("Gevechten: %d (%s)" % (len(g), ", ".join("%s %d" % (UITKOMST.get(k, k), n) for k, n in sorted(tel.items()))))
        per = OrderedDict()
        for x in g:
            p = per.setdefault(x["gebied"], {"n": 0, "win": 0, "lose": 0, "flee": 0, "secs": 0.0})
            p["n"] += 1
            p[x["uitkomst"]] = p.get(x["uitkomst"], 0) + 1
            p["secs"] += x["secs"]
        namen = dict(volgorde)
        for gid, p in per.items():
            uit.append("  %-30s %3d  w%d v%d f%d  gem. %.1fs" % (namen.get(gid, gid), p["n"], p["win"], p["lose"], p["flee"], p["secs"] / p["n"]))
        bazen = [x for x in g if x["baas"]]
        if bazen:
            uit.append("Baasgevechten:")
            for x in bazen:
                uit.append("  %-28s %-9s %6.1fs  %d ronden  HP-verlies %d  (%s)" % (
                    ",".join(str(v) for v in x["vijanden"])[:28], UITKOMST.get(x["uitkomst"], x["uitkomst"]),
                    x["secs"], x["ronden"], x["hp_verlies"], x["kaart"]))
        zwaar = sorted(g, key=lambda x: -x["hp_verlies"])[:3]
        uit.append("Zwaarste gevechten (HP-verlies):")
        for x in zwaar:
            uit.append("  %-28s %5d HP  %s  (%s)" % (",".join(str(v) for v in x["vijanden"])[:28], x["hp_verlies"],
                                                   UITKOMST.get(x["uitkomst"], x["uitkomst"]), x["kaart"]))
    else:
        uit.append("Gevechten: geen")

    uit.append("")
    if s["doden"] or s["game_overs"]:
        uit.append("Doden: %d, game-overs: %d" % (len(s["doden"]), len(s["game_overs"])))
        for x in s["doden"]:
            uit.append("  t=%7.1fs  %-24s %-14s reden: %s" % (x["t"], x["kaart"], "(%s)" % x["gebied"], x["reden"]))
        for x in s["game_overs"]:
            uit.append("  t=%7.1fs  game-over op %s" % (x["t"], x["plek"]))
    else:
        uit.append("Doden: geen")

    uit.append("")
    problemen = []
    if not s["netjes_gestopt"]:
        problemen.append("sessie niet netjes gestopt (laatste kaart: %s)" % (list(s["kaart_secs"])[-1] if s["kaart_secs"] else "?"))
    for c in s["crash_vorige"]:
        problemen.append("vorige sessie %s eindigde zonder sessie_stop (laatste kaart %s, laatste regel %s)" % (
            c["bestand"], c["kaart"] or "?", c["laatste_type"] or "?"))
    for v in s["vastlopers"]:
        problemen.append("vastloper van %.1fs op t=%.1fs in scene %s" % (v["secs"], v["t"], v["scene"] or "?"))
    if problemen:
        uit.append("Crashes en vastlopers: %d" % len(problemen))
        uit.extend("  - " + p for p in problemen)
    else:
        uit.append("Crashes en vastlopers: geen")

    if s["quest_updates"]:
        uit.append("")
        uit.append("Quest-voortgang:")
        for q in s["quest_updates"]:
            uit.append("  t=%7.1fs  %-18s stappen %s%s" % (q["t"], q["quest"], q["stappen"], "  KLAAR" if q["klaar"] else ""))
    uit.append("")
    uit.append("Saves %d, loads %d, stilstanden (>= 20s) %d" % (s["saves"], s["loads"], s["stilstanden"]))
    return "\n".join(uit)


def tekst_totaal(tot, volgorde):
    uit = ["== TOTAAL (%d sessies, %s) ==" % (tot["sessies"], tijd(tot["duur"]))]
    uit.append("Speeltijd per gebied:")
    _gebieden_regels(tot["gebied_secs"], volgorde, uit)
    uit.append("Gevechten %d (%s), doden %d, game-overs %d" % (
        tot["gevechten"], ", ".join("%s %d" % (UITKOMST.get(k, k), n) for k, n in sorted(tot["uitkomsten"].items())) or "geen",
        tot["doden"], tot["game_overs"]))
    uit.append("Afgebroken sessies %d, crash_vorige-meldingen %d, vastlopers %d" % (tot["afgebroken"], tot["crash_vorige"], tot["vastlopers"]))
    return "\n".join(uit)


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("-")]
    opties = [a for a in argv[1:] if a.startswith("-")]
    if "--help" in opties or "-h" in opties:
        print(__doc__.strip())
        return 0
    onbekend = [o for o in opties if o not in ("--json", "--strict")]
    if onbekend:
        print("Onbekende optie: %s" % ", ".join(onbekend), file=sys.stderr)
        return 2
    if not args:
        print(__doc__.strip())
        return 2
    lijst = bestanden(args)
    if not lijst:
        print("Geen sessie_*.jsonl gevonden.", file=sys.stderr)
        return 1
    volgorde, gebied_van = laad_gebieden()
    sessies, code = [], 0
    for pad in lijst:
        try:
            sessies.append(analyseer(pad, gebied_van))
        except OSError as e:
            print("Kan %s niet lezen: %s" % (pad, e), file=sys.stderr)
            code = 1
    if not sessies:
        return 1
    tot = combineer(sessies)
    if "--json" in opties:
        print(json.dumps({"totaal": tot, "sessies": sessies}, indent=2, ensure_ascii=False))
    else:
        for i, s in enumerate(sessies):
            if i:
                print()
            print(tekst_sessie(s, volgorde, gebied_van))
        if len(sessies) > 1:
            print()
            print(tekst_totaal(tot, volgorde))
    if "--strict" in opties and (tot["afgebroken"] or tot["crash_vorige"] or tot["vastlopers"] or tot["doden"]):
        return 3
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
