#!/bin/bash
# Draait één SAPIENTIA-testsuite headless (zoals /workspace/v18_testlogs/run.sh van RPG Forge).
# Gebruik: .github/scripts/run_suite.sh <suite>   (bv. autotest, codextest)
# Env: GODOT (pad naar Godot 4.3-stable binary), LOGDIR (standaard ./testlogs)
# Exit != 0 bij: Godot exit != 0, een FAIL-regel, een SCRIPT ERROR, of geen 'RESULT OK'.
set -u
S=$1; shift || true
GODOT=${GODOT:-godot}
LOGDIR=${LOGDIR:-$PWD/testlogs}
mkdir -p "$LOGDIR/shots_$S"
export XDG_DATA_HOME="$LOGDIR/xdg_$S"     # eigen user://-map per suite
rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME"
LOG="$LOGDIR/$S.log"
START=$(date +%s)
# xvfb-run -a kiest het displaynummer zonder lock: bij veel suites tegelijk pakken er twee hetzelfde en
# start Godot niet ("X11 Display is not available", nog vóór de eerste testregel). Dan opnieuw (max. 3x).
for POGING in 1 2 3; do
  timeout 1200 xvfb-run -a "$GODOT" --rendering-driver opengl3 --path . -- --$S --shots="$LOGDIR/shots_$S" "$@" > "$LOG" 2>&1
  CODE=$?
  [ "$CODE" -ne 0 ] && grep -q 'X11 Display is not available' "$LOG" || break
  rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME"
  sleep $(( RANDOM % 4 + 1 ))
done
DUR=$(( $(date +%s) - START ))
P=$(grep -c '^PASS' "$LOG"); F=$(grep -c '^FAIL' "$LOG"); E=$(grep -c 'SCRIPT ERROR' "$LOG")
R=$(grep -E '^RESULT' "$LOG" | tail -1)
LINE="$S exit=$CODE PASS=$P FAIL=$F ERR=$E ${DUR}s $R"
echo "$LINE"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "| $S | $P | $F | $E | ${DUR}s | $R |" >> "$GITHUB_STEP_SUMMARY"
if [ "$CODE" -ne 0 ] || [ "$F" -ne 0 ] || [ "$E" -ne 0 ] || ! echo "$R" | grep -q 'RESULT OK'; then
  echo "---- FAIL/ERROR-regels ----"; grep -nE '^FAIL|SCRIPT ERROR|ERROR:' "$LOG" | head -50
  echo "---- laatste 40 regels ----"; tail -40 "$LOG"
  exit 1
fi
