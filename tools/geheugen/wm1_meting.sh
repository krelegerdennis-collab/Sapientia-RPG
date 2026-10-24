#!/bin/bash
# WM1 geheugenmeting: reproduceerbaar, headless (xvfb + opengl3). Schrijft JSON naar <uitmap> en
# (met rapport.py) een markdown-tabel. Elke kaart draait in een verse Godot-proces, zodat de cijfers
# niet door eerdere kaarten worden beinvloed; daarnaast een sessie-run (alle kaarten achter elkaar).
#
# Gebruik:  GODOT=/pad/naar/Godot tools/geheugen/wm1_meting.sh <uitmap>
#           python3 tools/geheugen/rapport.py <uitmap> [<uitmap-voor>]   # vergelijk voor/na
# Vereist: xvfb-run, een Godot-binary (CI: 4.3-stable), een geimporteerd project (.godot/).
set -u
UIT=${1:?geef een uitmap}
GODOT=${GODOT:-godot}
PROJ=$(cd "$(dirname "$0")/../.." && pwd)
SCENE=res://tools/geheugen/wm1_meting.tscn
mkdir -p "$UIT/kaarten" "$UIT/gevecht"
export XDG_DATA_HOME="$UIT/xdg"; rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME"

draai() {   # draai <uitbestand> <argumenten...>
  local out=$1; shift
  timeout 300 xvfb-run -a "$GODOT" --rendering-driver opengl3 --path "$PROJ" "$SCENE" -- "$@" --out="$out" \
    > "$out.log" 2>&1 || { echo "FOUT bij $*"; tail -20 "$out.log"; }
}

draai "$UIT/start.json" --start
draai "$UIT/texaudit.json" --texaudit
for g in gras zand bos woud boss; do
  draai "$UIT/gevecht/$g.json" --battle=$g
done
"$GODOT" --headless --path "$PROJ" "$SCENE" -- --lijst 2>/dev/null | grep '^res://' > "$UIT/kaarten.txt"
while read -r k; do
  draai "$UIT/kaarten/$(basename "$k" .tscn).json" --scene="$k"
done < "$UIT/kaarten.txt"
draai "$UIT/sessie.json" --sessie
echo "klaar: $UIT"
