#!/usr/bin/env python3
"""Rapport over de CSV's van de battle simulator (godot -- --battlesim --party=... --enemy=...).

Gebruik:
    python3 tools/battlesim/rapport.py [csv of map ...] [--top=N] [--markdown]

Zonder pad: alle *.csv in user://sim/ van SAPIENTIA (Linux: $XDG_DATA_HOME of
~/.local/share/godot/app_userdata/SAPIENTIA/sim, macOS/Windows: de Godot-standaardmap).
Toont: winrate, mediaan van de beurten (rondes) en de zwaarste vijandgroepen
(laagste winrate, dan het minste HP over). Alleen de standaardbibliotheek.
Exitcode 1 als een CSV ongeldig is of er geen rijen zijn.
"""
import csv
import os
import statistics
import sys
from pathlib import Path

VERPLICHT = ["seed", "policy", "party", "group_id", "enemies", "run", "result", "win",
             "turns", "hp_left", "hp_max", "hp_left_pct", "mp_used", "items_used"]
GETALLEN = ["seed", "run", "win", "turns", "hp_left", "hp_max", "mp_used", "items_used"]
RESULTATEN = {"win", "lose", "timeout"}


def standaard_map() -> Path:
    if sys.platform.startswith("win"):
        basis = Path(os.environ.get("APPDATA", "")) / "Godot"
    elif sys.platform == "darwin":
        basis = Path.home() / "Library" / "Application Support" / "Godot"
    else:
        basis = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot"
    return basis / "app_userdata" / "SAPIENTIA" / "sim"


def lees(paden: list[Path]) -> list[dict]:
    rijen: list[dict] = []
    for pad in paden:
        with pad.open(newline="", encoding="utf-8") as f:
            lezer = csv.DictReader(f)
            ontbreekt = [k for k in VERPLICHT if k not in (lezer.fieldnames or [])]
            if ontbreekt:
                raise ValueError(f"{pad}: missing columns: {', '.join(ontbreekt)}")
            for nr, r in enumerate(lezer, start=2):
                if None in r or any(v is None for v in r.values()):
                    raise ValueError(f"{pad}:{nr}: wrong number of columns")
                if r["result"] not in RESULTATEN:
                    raise ValueError(f"{pad}:{nr}: unknown result {r['result']!r}")
                for k in GETALLEN:
                    r[k] = int(r[k])
                r["hp_left_pct"] = float(r["hp_left_pct"])
                if r["win"] != (1 if r["result"] == "win" else 0):
                    raise ValueError(f"{pad}:{nr}: win and result disagree")
                rijen.append(r)
    return rijen


def samenvatting(rijen: list[dict]) -> dict:
    n = len(rijen)
    return {
        "runs": n,
        "winrate": sum(r["win"] for r in rijen) / n,
        "median_turns": statistics.median(r["turns"] for r in rijen),
        "hp_left_pct": statistics.fmean(r["hp_left_pct"] for r in rijen),
        "mp": statistics.fmean(r["mp_used"] for r in rijen),
        "items": statistics.fmean(r["items_used"] for r in rijen),
        "timeouts": sum(1 for r in rijen if r["result"] == "timeout"),
    }


def rapport(rijen: list[dict], top: int, markdown: bool) -> str:
    totaal = samenvatting(rijen)
    groepen: dict[tuple, list[dict]] = {}
    for r in rijen:
        groepen.setdefault((r["party"], r["policy"], r["group_id"], r["enemies"]), []).append(r)
    per_groep = [(k, samenvatting(v)) for k, v in groepen.items()]
    per_groep.sort(key=lambda kv: (kv[1]["winrate"], kv[1]["hp_left_pct"], -kv[1]["median_turns"],
                                   -kv[1]["items"], -kv[1]["mp"]))

    seeds = sorted({r["seed"] for r in rijen})
    L = []
    kop = "## " if markdown else ""
    L.append(f"{kop}Battle simulator report")
    L.append("")
    L.append(f"Runs: {totaal['runs']}  groups: {len(groepen)}  seeds: {', '.join(map(str, seeds))}")
    L.append(f"Win rate: {totaal['winrate']:.1%}")
    L.append(f"Median turns: {totaal['median_turns']:g}")
    L.append(f"Avg HP left: {totaal['hp_left_pct']:.1f}%  avg MP used: {totaal['mp']:.1f}  "
             f"avg items used: {totaal['items']:.2f}  timeouts: {totaal['timeouts']}")
    L.append("")
    L.append(f"{kop}Heaviest enemy groups (top {min(top, len(per_groep))})")
    L.append("")
    kolommen = ["#", "group", "enemies", "party", "policy", "runs", "win rate", "median turns",
                "avg HP left", "avg MP", "avg items"]
    tabel = []
    for i, ((party, policy, gid, enemies), s) in enumerate(per_groep[:top], start=1):
        tabel.append([str(i), gid, enemies, party, policy, str(s["runs"]), f"{s['winrate']:.0%}",
                      f"{s['median_turns']:g}", f"{s['hp_left_pct']:.1f}%", f"{s['mp']:.1f}", f"{s['items']:.2f}"])
    if markdown:
        L.append("| " + " | ".join(kolommen) + " |")
        L.append("|" + "|".join("---" if j < 5 else "---:" for j in range(len(kolommen))) + "|")
        for rij in tabel:
            L.append("| " + " | ".join(rij) + " |")
    else:
        breedte = [max(len(kolommen[j]), *(len(r[j]) for r in tabel)) for j in range(len(kolommen))]
        L.append("  ".join(k.ljust(breedte[j]) for j, k in enumerate(kolommen)))
        for rij in tabel:
            L.append("  ".join(c.ljust(breedte[j]) for j, c in enumerate(rij)).rstrip())
    return "\n".join(L) + "\n"


def main(argv: list[str]) -> int:
    top = 5
    markdown = False
    paden: list[Path] = []
    for a in argv:
        if a.startswith("--top="):
            top = max(1, int(a.split("=", 1)[1]))
        elif a == "--markdown":
            markdown = True
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            p = Path(a)
            paden.extend(sorted(p.glob("*.csv")) if p.is_dir() else [p])
    if not paden:
        paden = sorted(standaard_map().glob("*.csv"))
    if not paden:
        print(f"no CSV files found (looked in {standaard_map()})", file=sys.stderr)
        return 1
    try:
        rijen = lees(paden)
    except (ValueError, OSError) as e:
        print(f"invalid CSV: {e}", file=sys.stderr)
        return 1
    if not rijen:
        print("no rows", file=sys.stderr)
        return 1
    print(rapport(rijen, top, markdown), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
