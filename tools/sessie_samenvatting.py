#!/usr/bin/env python3
"""Samenvatting van een sessielogboek (scripts/sessielog.gd, JSON-lines).

Gebruik: python3 tools/sessie_samenvatting.py <log.jsonl> [meer.jsonl ...] [--json]
Leest één of meer logboeken (ook een geëxporteerd bestand met meerdere sessies achter elkaar) en
geeft per sessie: duur, apparaat, kaarten met tijd, plekken waar de speler lang stilstond, botsingen
(bump) per plek, gevechten (resultaat, ronden, hp-verlies, acties), doden en respawns, menu's,
dialogen en cutscenes. Kapotte regels worden overgeslagen en geteld.
"""
import json, sys
from collections import Counter, defaultdict

STIL_SECS = 10.0  # zo lang op één tegel = "blijft hangen"


def lees(paden):
    sessies, kapot = [], 0
    for p in paden:
        with open(p, encoding="utf-8") as f:
            for regel in f:
                regel = regel.strip()
                if not regel:
                    continue
                try:
                    d = json.loads(regel)
                except ValueError:
                    kapot += 1
                    continue
                if d.get("e") == "start" or not sessies:
                    sessies.append([])
                sessies[-1].append(d)
    return sessies, kapot


def vat_samen(regels):
    s = {"sessie": "", "duur": 0.0, "apparaat": {}, "kaarten": Counter(), "warps": 0, "stil": [],
         "bumps": Counter(), "gevechten": [], "doden": [], "respawns": [], "menus": Counter(),
         "dialogen": 0, "cutscenes": Counter(), "knoppen": Counter(), "bron": Counter(), "afgekapt": False}
    vorige = None  # (kaart, x, y, t)
    for d in regels:
        e, t = d.get("e"), float(d.get("t", 0))
        s["duur"] = max(s["duur"], t)
        if e == "start":
            s["sessie"] = d.get("sessie", "")
            s["apparaat"] = {k: d.get(k) for k in ("os", "web", "android", "spel", "motor", "utc")}
        elif e == "kaart_tijd":
            s["kaarten"][d.get("kaart", "?")] += float(d.get("secs", 0))
        elif e == "warp":
            s["warps"] += 1
        elif e == "pos":
            plek = (d.get("kaart"), d.get("x"), d.get("y"))
            if vorige and vorige[:3] == plek:
                pass
            else:
                if vorige and t - vorige[3] >= STIL_SECS:
                    s["stil"].append({"kaart": vorige[0], "x": vorige[1], "y": vorige[2], "secs": round(t - vorige[3], 1)})
                vorige = plek + (t,)
        elif e == "bump":
            s["bumps"][(d.get("kaart"), d.get("x"), d.get("y"))] += 1
        elif e == "gevecht_eind":
            s["gevechten"].append({k: d.get(k) for k in ("kaart", "resultaat", "ronden", "secs", "hp_verlies", "acties")})
        elif e == "dood":
            s["doden"].append({"kaart": d.get("kaart"), "reden": d.get("reden"), "t": t})
        elif e == "respawn":
            s["respawns"].append({"naar": d.get("naar"), "soort": d.get("soort")})
        elif e == "menu":
            s["menus"][d.get("scherm", "?")] += 1
        elif e == "dialoog_start":
            s["dialogen"] += 1
        elif e == "cutscene_start":
            s["cutscenes"][d.get("id", "?")] += 1
        elif e == "knop":
            s["knoppen"][d.get("a", "?")] += 1
            s["bron"][d.get("bron", "?")] += 1
        elif e == "dir":
            s["bron"][d.get("bron", "?")] += 1
        elif e == "afgekapt":
            s["afgekapt"] = True
    s["stil"].sort(key=lambda r: -r["secs"])
    return s


def als_json(s):
    uit = dict(s)
    uit["kaarten"] = {k: round(v, 1) for k, v in s["kaarten"].most_common()}
    uit["bumps"] = [{"kaart": k[0], "x": k[1], "y": k[2], "n": n} for k, n in s["bumps"].most_common()]
    for k in ("menus", "cutscenes", "knoppen", "bron"):
        uit[k] = dict(s[k])
    return uit


def tekst(s):
    a = s["apparaat"]
    r = ["Sessie %s  (%s, %s%s)  duur %.0f s%s" % (s["sessie"] or "?", a.get("utc") or "?", a.get("os") or "?",
         ", web" if a.get("web") else "", s["duur"], "  [afgekapt]" if s["afgekapt"] else "")]
    if s["kaarten"]:
        r.append("  Kaarten: " + ", ".join("%s %.0fs" % kv for kv in s["kaarten"].most_common()))
    r.append("  Warps: %d   dialogen: %d   menu's: %s" % (s["warps"], s["dialogen"], dict(s["menus"]) or "-"))
    if s["stil"]:
        r.append("  Lang stil (>= %.0fs): " % STIL_SECS + ", ".join("%s (%s,%s) %.0fs" % (x["kaart"], x["x"], x["y"], x["secs"]) for x in s["stil"][:8]))
    if s["bumps"]:
        r.append("  Botsingen: " + ", ".join("%s (%s,%s) x%d" % (k[0], k[1], k[2], n) for k, n in s["bumps"].most_common(8)))
    g = s["gevechten"]
    if g:
        uit = Counter(x["resultaat"] for x in g)
        r.append("  Gevechten: %d %s, gem. %.1f ronden, gem. hp-verlies %.0f" % (len(g), dict(uit),
                 sum(x["ronden"] or 0 for x in g) / len(g), sum(x["hp_verlies"] or 0 for x in g) / len(g)))
        acties = Counter()
        for x in g:
            acties.update(x.get("acties") or {})
        if acties:
            r.append("  Acties: " + ", ".join("%s x%d" % kv for kv in acties.most_common(8)))
    for x in s["doden"]:
        r.append("  Dood op %s (%s) na %.0fs" % (x["kaart"], x["reden"], x["t"]))
    if s["respawns"]:
        r.append("  Respawn: " + ", ".join("%s (%s)" % (x["naar"], x["soort"]) for x in s["respawns"]))
    if s["cutscenes"]:
        r.append("  Cutscenes: " + ", ".join("%s x%d" % kv for kv in s["cutscenes"].most_common()))
    if s["bron"]:
        r.append("  Invoer: %s   knoppen: %s" % (dict(s["bron"]), dict(s["knoppen"])))
    return "\n".join(r)


def main(args):
    js = "--json" in args
    paden = [a for a in args if not a.startswith("--")]
    if not paden:
        print(__doc__.strip())
        return 2
    sessies, kapot = lees(paden)
    samen = [vat_samen(x) for x in sessies]
    if js:
        print(json.dumps({"sessies": [als_json(s) for s in samen], "kapotte_regels": kapot}, indent=1, default=str))
    else:
        for s in samen:
            print(tekst(s))
        if kapot:
            print("(%d kapotte regels overgeslagen)" % kapot)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
