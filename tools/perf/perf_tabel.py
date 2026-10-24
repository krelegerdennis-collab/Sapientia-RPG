#!/usr/bin/env python3
"""Voegt meerdere CSV's van `--perftest` samen (mediaan per scène) tot een Markdown-tabel.

Gebruik:
  python3 tools/perf/perf_tabel.py run1.csv run2.csv run3.csv            # tabel naar stdout
  python3 tools/perf/perf_tabel.py --voor voor_*.csv --na na_*.csv       # voor/na-vergelijking

Draw calls, nodes en textuurgeheugen zijn deterministisch; laadtijd en frametijd verschillen per run
(software-GL onder xvfb), daarom de mediaan over meerdere runs.
"""
import csv
import re
import statistics
import sys

NUM = ["load_ms", "enter_ms", "frame_ms", "frame_p95_ms", "frame_max_ms", "physics_ms", "draw_calls",
       "draw_calls_max", "primitives", "nodes", "nodes_total", "processing_nodes", "physics_nodes",
       "tex_mem_mb", "tex_mem_delta_mb", "tex_unique", "tex_ref_mb", "tex_big", "obj_growth",
       "static_mem_growth_kb", "objects", "resources", "preloaded", "script_us"]


def lees(paden):
    """-> (volgorde, {id: {kolom: mediaan, ...}})"""
    volgorde = []
    per_id = {}
    for p in paden:
        with open(p, newline="") as f:
            for rij in csv.DictReader(f):
                i = rij["id"]
                if i not in per_id:
                    per_id[i] = {"meta": rij, "waarden": {k: [] for k in NUM}}
                    volgorde.append(i)
                for k in NUM:
                    per_id[i]["waarden"][k].append(float(rij.get(k) or 0.0))
    uit = {}
    for i, d in per_id.items():
        m = dict(d["meta"])
        m["tex_top"] = re.sub(r"<(\w+) -?\d+>", r"<\1>", m["tex_top"])
        for k in NUM:
            m[k] = statistics.median(d["waarden"][k])
        uit[i] = m
    return volgorde, uit


def tabel(volgorde, data):
    s = "| Groep | Scène | load ms | enter ms | frame ms | p95 ms | draw calls | nodes | objects | tex ref MB | tex mem Δ MB | grootste textures |\n"
    s += "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n"
    for i in volgorde:
        r = data[i]
        if r["kind"] == "boot":
            s += "| %s | `%s` | – | – | – | – | – | %d | %d | %.2f | %.2f (totaal) | %s |\n" % (
                r["group"], i, r["nodes"], r["objects"], r["tex_ref_mb"], r["tex_mem_mb"], r["tex_top"])
            continue
        s += "| %s | `%s` | %.1f | %.1f | %.2f | %.2f | %.0f | %d | %d | %.2f | %.2f | %s |\n" % (
            r["group"], i, r["load_ms"], r["enter_ms"], r["frame_ms"], r["frame_p95_ms"], r["draw_calls"],
            r["nodes"], r["objects"], r["tex_ref_mb"], r["tex_mem_delta_mb"], r["tex_top"])
    return s


def vergelijk(volgorde, voor, na):
    s = "| Scène | load ms (voor → na) | enter ms | frame ms | draw calls | objects | tex ref MB | tex mem Δ MB |\n"
    s += "|---|---|---|---|---|---|---|---|\n"

    def c(a, b, f):
        return (f % a) + " → " + (f % b)
    for i in volgorde:
        if i not in na:
            continue
        a, b = voor[i], na[i]
        if a["kind"] == "boot":
            s += "| `%s` (tex mem totaal MB, preloaded) | – | – | – | – | – | %s | %s |\n" % (
                i, c(a["tex_ref_mb"], b["tex_ref_mb"], "%.2f"), c(a["tex_mem_mb"], b["tex_mem_mb"], "%.2f"))
            continue
        s += "| `%s` | %s | %s | %s | %s | %s | %s | %s |\n" % (
            i, c(a["load_ms"], b["load_ms"], "%.1f"), c(a["enter_ms"], b["enter_ms"], "%.1f"),
            c(a["frame_ms"], b["frame_ms"], "%.2f"), c(a["draw_calls"], b["draw_calls"], "%.0f"),
            c(a["objects"], b["objects"], "%d"), c(a["tex_ref_mb"], b["tex_ref_mb"], "%.2f"),
            c(a["tex_mem_delta_mb"], b["tex_mem_delta_mb"], "%.2f"))
    return s


def main(args):
    if "--voor" in args:
        k = args.index("--voor")
        n = args.index("--na")
        voor_p, na_p = args[k + 1:n], args[n + 1:]
        volgorde, voor = lees(voor_p)
        _, na = lees(na_p)
        print(vergelijk(volgorde, voor, na))
    else:
        volgorde, data = lees(args)
        print(tabel(volgorde, data))


if __name__ == "__main__":
    main(sys.argv[1:])
