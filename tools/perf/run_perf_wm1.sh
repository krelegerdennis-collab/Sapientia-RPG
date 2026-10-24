#!/bin/bash
# Draait het WM1-perfharnas (tools/perf/perf_wm1.gd) headless onder xvfb en schrijft JSON.
# Gebruik: tools/perf/run_perf_wm1.sh <uitvoer.json> [--runs=5] [--frames=300]
# Env: GODOT (pad naar de binary, standaard 'godot'). Gebruikt een eigen user://-map (XDG_DATA_HOME).
set -u
OUT=${1:?uitvoerbestand (json) ontbreekt}; shift
GODOT=${GODOT:-godot}
XDG=$(mktemp -d /tmp/xdg_perfwm1.XXXXXX)
export XDG_DATA_HOME="$XDG"
LOG="${OUT%.json}.log"
xvfb-run -a "$GODOT" --rendering-driver opengl3 --path . res://tools/perf/perf_wm1.tscn -- --perfwm1 --out="$OUT" "$@" > "$LOG" 2>&1
CODE=$?
grep -E '^PERF |^RESULT|SCRIPT ERROR|^ERROR' "$LOG" | head -120
rm -rf "$XDG"
exit $CODE
