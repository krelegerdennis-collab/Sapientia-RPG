#!/bin/bash
# Draait de geheugen-testsuite headless (xvfb + opengl3). Exit != 0 bij een FAIL, SCRIPT ERROR of geen 'RESULT OK'.
#   GODOT=/pad/naar/Godot tools/geheugen/run_tests.sh
set -u
GODOT=${GODOT:-godot}
PROJ=$(cd "$(dirname "$0")/../.." && pwd)
LOG=${LOG:-/tmp/geheugentest.log}
export XDG_DATA_HOME=${XDG_DATA_HOME:-/tmp/xdg_geheugentest}
rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME"
timeout 600 xvfb-run -a "$GODOT" --rendering-driver opengl3 --path "$PROJ" res://tools/geheugen/geheugen_tests.tscn > "$LOG" 2>&1
CODE=$?
P=$(grep -c '^PASS' "$LOG"); F=$(grep -c '^FAIL' "$LOG"); E=$(grep -c 'SCRIPT ERROR' "$LOG")
R=$(grep -E '^RESULT' "$LOG" | tail -1)
echo "geheugentest exit=$CODE PASS=$P FAIL=$F ERR=$E $R"
if [ "$CODE" -ne 0 ] || [ "$F" -ne 0 ] || [ "$E" -ne 0 ] || ! echo "$R" | grep -q 'RESULT OK'; then
  grep -nE '^FAIL|SCRIPT ERROR' "$LOG" | head -30; tail -20 "$LOG"; exit 1
fi
