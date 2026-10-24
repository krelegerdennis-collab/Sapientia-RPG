#!/usr/bin/env python3
"""Vergelijkt twee sets perf-JSON's (tools/perf/run_perf_wm1.sh) en print een markdown-tabel.
Gebruik: compare_perf.py --before a1.json a2.json a3.json --after b1.json b2.json b3.json
Per metriek wordt de mediaan over de bestanden genomen (elk bestand is zelf al een mediaan over --runs)."""
import argparse
import json
import statistics


def load(paths):
    return [json.load(open(p)) for p in paths]


def med(runs, getter):
    vals = []
    for r in runs:
        try:
            v = getter(r)
        except (KeyError, TypeError):
            continue
        if v is not None:
            vals.append(float(v))
    return statistics.median(vals) if vals else None


def stat(key):
    return lambda r: r[key]["median"]


ROWS = [
    ("Startup", None, None),
    ("Engine start -> autoloads klaar (GameState._ready e.a.)", lambda r: r["engine_start_to_harness_ms"], "ms"),
    ("Titelscherm, eerste keer opbouwen (cold)", lambda r: r["startup_title_first_ready_ms"], "ms"),
    ("Titelscherm opbouwen (warm, mediaan)", stat("startup_title_warm_ready_ms"), "ms"),
    ("Titel -> WM1", None, None),
    ("Titelscherm klaar, 4 saves aanwezig", stat("title_ready_with_saves_ms"), "ms"),
    ("Slotlijst openen", stat("title_slotlist_open_ms"), "ms"),
    ("Doorgaan -> wereldkaart klaar", stat("title_to_wm1_ready_ms"), "ms"),
    ("Doorgaan -> wereldkaart settled (+4 frames)", stat("title_to_wm1_settled_ms"), "ms"),
    ("Doorgaan -> wereldkaart, langste frame", stat("title_to_wm1_hitch_ms"), "ms"),
    ("Kaartwissels WM1 (13 stappen)", None, None),
    ("Cold, mediaan klaar", stat("map_transition_cold_ready_ms"), "ms"),
    ("Cold, mediaan langste frame", stat("map_transition_cold_hitch_ms"), "ms"),
    ("Cold, zwaarste kaart klaar", lambda r: r["map_transition_cold_ready_ms"]["max"], "ms"),
    ("Cold, totaal 13 wissels (klaar)", lambda r: sum(v for k, v in r["map_transition_per_map_ms"].items() if k.endswith("#cold")), "ms"),
    ("Warm, mediaan klaar", stat("map_transition_warm_ready_ms"), "ms"),
    ("Warm, mediaan langste frame", stat("map_transition_warm_hitch_ms"), "ms"),
    ("Warm, zwaarste kaart klaar", lambda r: r["map_transition_warm_ready_ms"]["max"], "ms"),
    ("Warm, totaal 13 wissels (klaar)", lambda r: sum(v for k, v in r["map_transition_per_map_ms"].items() if k.endswith("#warm")), "ms"),
    ("Per kaart", None, None),
    ("dorp_wilgendal cold", lambda r: r["map_transition_per_map_ms"]["dorp_wilgendal#cold"], "ms"),
    ("dorp_wilgendal warm", lambda r: r["map_transition_per_map_ms"]["dorp_wilgendal#warm"], "ms"),
    ("woud_rand cold (eerste kerker/woud-kamer)", lambda r: r["map_transition_per_map_ms"]["woud_rand#cold"], "ms"),
    ("archief_ingang cold", lambda r: r["map_transition_per_map_ms"]["archief_ingang#cold"], "ms"),
    ("esdoorn cold", lambda r: r["map_transition_per_map_ms"]["esdoorn#cold"], "ms"),
    ("wilgendal cold", lambda r: r["map_transition_per_map_ms"]["wilgendal#cold"], "ms"),
    ("Gevecht", None, None),
    ("Gevecht in, eerste keer (cold)", lambda r: r["battle_enter_cold_ms"], "ms"),
    ("Gevecht in (warm)", stat("battle_enter_warm_ms"), "ms"),
    ("Gevecht in (warm), langste frame", stat("battle_enter_hitch_ms"), "ms"),
    ("Gevecht uit, eerste keer (cold)", lambda r: r["battle_exit_cold_ms"], "ms"),
    ("Gevecht uit (warm)", stat("battle_exit_warm_ms"), "ms"),
    ("Gevecht uit (warm), langste frame", stat("battle_exit_hitch_ms"), "ms"),
    ("Save laden / opslaan (CPU per aanroep)", None, None),
    ("read_save (1 slot)", stat("save_read_one_ms"), "ms"),
    ("apply_state", stat("save_apply_state_ms"), "ms"),
    ("save_game (schrijven + verifieren)", stat("save_write_ms"), "ms"),
    ("slot_record x5 (slotlijst)", stat("save_slot_records_5_ms"), "ms"),
    ("newest_slot_record", stat("save_newest_slot_record_ms"), "ms"),
    ("set_checkpoint (elke kaartwissel)", stat("save_set_checkpoint_ms"), "ms"),
    ("Script-tijd per frame (stilstaand, zonder renderen)", None, None),
]
for tag, name in [("wereldkaart", "wereldkaart"), ("wilgendal", "wilgendal"), ("dorp", "dorp_wilgendal"),
                  ("esdoorn", "esdoorn"), ("woud_pad", "woud_pad"), ("archief_gang", "archief_v1_gang")]:
    ROWS.append((name, (lambda t: lambda r: r["frame_idle_%s" % t]["script_ms_mean"])(tag), "ms"))
ROWS.append(("wereldkaart lopend", lambda r: r["frame_walk_wereldkaart"]["script_ms_mean"], "ms"))
ROWS.append(("Som van alle _process-aanroepen (probe, us)", None, None))
for tag in ["wereldkaart", "dorp", "woud_pad", "archief_gang"]:
    ROWS.append((tag, (lambda t: lambda r: r["probe"][t]["us_total"])(tag), "us"))


def fmt(v):
    return "-" if v is None else ("%.2f" % v if v < 100 else "%.0f" % v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", nargs="+", required=True)
    ap.add_argument("--after", nargs="+", required=True)
    a = ap.parse_args()
    b, n = load(a.before), load(a.after)
    print("| Meting | Voor | Na | Delta |")
    print("|---|---:|---:|---:|")
    for name, getter, unit in ROWS:
        if getter is None:
            print("| **%s** | | | |" % name)
            continue
        v0, v1 = med(b, getter), med(n, getter)
        if v0 is None or v1 is None:
            delta = ""
        elif v0 == 0:
            delta = ""
        else:
            delta = "%+.0f%%" % ((v1 - v0) / v0 * 100.0)
        print("| %s (%s) | %s | %s | %s |" % (name, unit, fmt(v0), fmt(v1), delta))


if __name__ == "__main__":
    main()
