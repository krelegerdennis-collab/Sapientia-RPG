#!/usr/bin/env python3
"""Vergelijkt meerdere WM1-balansmetingen (JSON van `-- --wm1balans --json=pad.json`) naast elkaar.

Gebruik:
  python3 tools/battlesim/wm1_vergelijk.py main=/tmp/wm1_main.json v2=/tmp/wm1_208.json tweaks=/tmp/wm1_tuned.json

Schrijft markdown naar stdout: een tabel per gebied (gewogen winst, rondes tot winst, HP-verlies, schade) en een
tabel per baas/groep waar de varianten ver uiteenlopen (>= 10 procentpunt winst of HP-verlies, of vlag-relevant).
Alleen WM1 (de Diepe Grot-bijlage blijft buiten de vergelijking, tenzij --d100).
"""
import json
import sys


def laad(pad):
    with open(pad, encoding="utf-8") as f:
        return {r["id"]: r for r in json.load(f)}


def gebied(r):
    w = sum(g["weight"] for g in r["groups"]) or 1
    def avg(k):
        return sum(g["weight"] * g["base"][k] for g in r["groups"]) / w
    return {"win": avg("win_rate"), "rounds": avg("avg_rounds_win"), "loss": avg("avg_hp_loss"),
            "dmg": avg("avg_dmg"), "exp": avg("avg_exp_win"), "gold": avg("avg_gold_win")}


def pct(v):
    return "%d%%" % round(v * 100)


def main(argv):
    d100 = "--d100" in argv
    args = [a for a in argv if "=" in a]
    if len(args) < 2:
        print(__doc__)
        return 1
    namen = [a.split("=", 1)[0] for a in args]
    data = [laad(a.split("=", 1)[1]) for a in args]
    ids = [i for i in data[0] if d100 or not data[0][i].get("d100")]
    print("| Gebied | " + " | ".join("%s: winst / rondes / HP-verlies" % n for n in namen) + " |")
    print("|---|" + "---|" * len(namen))
    for i in ids:
        cellen = []
        for d in data:
            if i not in d:
                cellen.append("-")
                continue
            g = gebied(d[i])
            cellen.append("%s / %.1f / %s" % (pct(g["win"]), g["rounds"], pct(g["loss"])))
        print("| %s | %s |" % (data[0][i]["name"], " | ".join(cellen)))
    print()
    print("Groepen waar de varianten >= 10 procentpunt winst of HP-verlies uiteenlopen, of een baas zijn:")
    print()
    print("| Gebied | Groep | " + " | ".join("%s: winst / rondes / HP-verlies" % n for n in namen) + " |")
    print("|---|---|" + "---|" * len(namen))
    for i in ids:
        for gi, g0 in enumerate(data[0][i]["groups"]):
            rijen = []
            for d in data:
                if i not in d:
                    rijen.append(None)
                    continue
                m = [g for g in d[i]["groups"] if g["label"] == g0["label"]]
                rijen.append(m[0]["base"] if m else None)
            echte = [b for b in rijen if b]
            if not echte:
                continue
            spreiding_w = max(b["win_rate"] for b in echte) - min(b["win_rate"] for b in echte)
            spreiding_l = max(b["avg_hp_loss"] for b in echte) - min(b["avg_hp_loss"] for b in echte)
            if not (g0["boss"] or spreiding_w >= 0.10 or spreiding_l >= 0.10):
                continue
            cellen = ["-" if b is None else "%s / %.1f / %s" % (pct(b["win_rate"]), b["avg_rounds_win"], pct(b["avg_hp_loss"])) for b in rijen]
            print("| %s | %s%s | %s |" % (data[0][i]["name"], g0["label"], " [BOSS]" if g0["boss"] else "", " | ".join(cellen)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
