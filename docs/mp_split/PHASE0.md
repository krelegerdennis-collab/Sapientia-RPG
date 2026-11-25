# MP-split fase 0 — solo baseline

## Doel

Voordat solo-state (`PlayerState` / `WorldState`) en MP-state gesplitst worden, leggen we een **vast solo-referentiepunt** vast: één deterministische sessie waarvan save-bytes en `state_data` SHA-256 tegen golden files worden vergeleken. Latere MP-split-fases mogen het solo-pad niet stiekem wijzigen.

## Suite

- Script: `scripts/tests/mp_solo_baseline_tests.gd`
- Vlag: `--mpsolobaselinetest` (alleen geregistreerd in `scripts/game_state.gd`, **geen** CI-matrix-regel)
- Golden: `scripts/tests/golden/mp_solo_baseline/`

De sessie raakt o.a. party/goud/tas/uitrusting, verhaalvlaggen, bestiary, Codex, Dungeon100, checkpoint en `current_map`.

## Lokaal draaien

```bash
export GODOT=<pad>/Godot_v4.3-stable_linux.x86_64
$GODOT --headless --path . --import
.github/scripts/run_suite.sh mpsolobaselinetest
```

Golden opnieuw maken (alleen bij bewuste wijziging van solo-serialisatie):

```bash
$GODOT --headless --path . -- --mpsolobaselinetest --regen-golden
```

## Regel voor vervolg-PR’s

**Elke MP-split-PR moet `--mpsolobaselinetest` ongewijzigd groen houden.** De golden files veranderen alleen via een aparte, gemotiveerde regen-PR.