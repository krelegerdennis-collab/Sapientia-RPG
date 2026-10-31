#!/bin/bash
# Draait één SAPIENTIA-testsuite headless (zoals /workspace/v18_testlogs/run.sh van RPG Forge).
# Gebruik: .github/scripts/run_suite.sh <suite>   (bv. autotest, codextest)
# Env: GODOT (pad naar Godot 4.3-stable binary), LOGDIR (standaard ./testlogs),
#      SUITE_TIMEOUT (seconden per poging, standaard 1200)
# Exit != 0 bij: Godot exit != 0, een FAIL-regel, een SCRIPT ERROR, geen 'RESULT OK', of een timeout.
set -u
S=$1; shift || true
GODOT=${GODOT:-godot}
LOGDIR=${LOGDIR:-$PWD/testlogs}
SUITE_TIMEOUT=${SUITE_TIMEOUT:-1200}
# Een suite die niet in de dispatch-lijst van game_state.gd staat start gewoon het titelscherm en
# eindigt nooit (geen uitvoer tot de timeout). Dat meteen melden in plaats van te wachten.
if ! grep -qF "\"--$S\"" scripts/game_state.gd; then
  echo "::error::$S: '--$S' staat niet in de tester-lijst van scripts/game_state.gd (_ready); de game zou het titelscherm starten en blijven hangen"
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "| $S | 0 | 0 | 0 | 0s | niet geregistreerd in game_state.gd |" >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi
mkdir -p "$LOGDIR/shots_$S"
export XDG_DATA_HOME="$LOGDIR/xdg_$S"     # eigen user://-map per suite
rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME"
LOG="$LOGDIR/$S.log"
START=$(date +%s)
# xvfb-run -a kiest het displaynummer zonder lock: bij veel suites tegelijk pakken er twee hetzelfde en
# start Godot niet ("X11 Display is not available", nog vóór de eerste testregel). Dan opnieuw (max. 3x).
for POGING in 1 2 3; do
  # -k 10: reageert Godot niet op SIGTERM, dan na 10 s SIGKILL (anders hangt de stap tot de job-timeout).
  timeout -k 10 "$SUITE_TIMEOUT" xvfb-run -a "$GODOT" --rendering-driver opengl3 --path . -- --$S --shots="$LOGDIR/shots_$S" "$@" > "$LOG" 2>&1
  CODE=$?
  [ "$CODE" -ne 0 ] && grep -q 'X11 Display is not available' "$LOG" || break
  rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME"
  sleep $(( RANDOM % 4 + 1 ))
done
DUR=$(( $(date +%s) - START ))
P=$(grep -c '^PASS' "$LOG"); F=$(grep -c '^FAIL' "$LOG"); E=$(grep -c 'SCRIPT ERROR' "$LOG")
R=$(grep -E '^RESULT' "$LOG" | tail -1)
if [ "$CODE" -eq 124 ] || [ "$CODE" -eq 137 ]; then
  echo "::error::$S: timeout na ${SUITE_TIMEOUT}s (exit=$CODE, PASS=$P) - de suite hangt (await/quit() niet bereikt?)"
  R=${R:-"TIMEOUT na ${SUITE_TIMEOUT}s"}
fi
LINE="$S exit=$CODE PASS=$P FAIL=$F ERR=$E ${DUR}s $R"
echo "$LINE"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "| $S | $P | $F | $E | ${DUR}s | $R |" >> "$GITHUB_STEP_SUMMARY"
if [ "$CODE" -ne 0 ] || [ "$F" -ne 0 ] || [ "$E" -ne 0 ] || ! echo "$R" | grep -q 'RESULT OK'; then
  echo "---- FAIL/ERROR-regels ----"; grep -nE '^FAIL|SCRIPT ERROR|ERROR:' "$LOG" | head -50
  echo "---- laatste 40 regels ----"; tail -40 "$LOG"
  exit 1
fi
