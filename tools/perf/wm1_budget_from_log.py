#!/usr/bin/env python3
"""Parse WM1FRAME-regels uit wm1frametest-log en schrijf LIMITS naar stdout (GDScript-snippet)."""
import re
import sys

PAT = re.compile(
    r"WM1FRAME id=(\S+) path=(\S+) proc_ms=([\d.]+) draw=([\d.]+) draw_max=(\d+) "
    r"nodes=(\d+) scene_nodes=(\d+) frames=(\d+)"
)


def main() -> None:
    rows = {}
    for line in sys.stdin:
        m = PAT.search(line)
        if not m:
            continue
        rid, path, proc, draw, draw_max, nodes, scene, frames = m.groups()
        rows[rid] = {
            "path": path,
            "proc_ms": float(proc),
            "draw_avg": float(draw),
            "draw_max": int(draw_max),
            "nodes": int(nodes),
            "scene_nodes": int(scene),
            "frames": int(frames),
        }
    if not rows:
        sys.stderr.write("geen WM1FRAME-regels gevonden\n")
        sys.exit(1)
    print("const LIMITS: Dictionary = {")
    for rid in sorted(rows):
        r = rows[rid]
        max_proc = round(r["proc_ms"] * 1.35 + 1.5, 3)
        max_draw_avg = round(r["draw_avg"] + 3.0, 1)
        max_draw_max = r["draw_max"] + 3
        max_scene = r["scene_nodes"] + 8
        max_nodes = r["nodes"] + 120
        print(
            f'\t"{rid}": {{'
            f'"max_proc_ms": {max_proc}, '
            f'"max_draw_avg": {max_draw_avg}, '
            f'"max_draw_max": {max_draw_max}, '
            f'"max_scene_nodes": {max_scene}, '
            f'"max_nodes": {max_nodes}}},'
        )
    print("}")


if __name__ == "__main__":
    main()
