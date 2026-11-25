# MP-split fase 0 — solo golden files

Vast referentiepunt voor een **scripted solo-sessie** (party, goud, tas, uitrusting, verhaal, bestiary, Codex, Dungeon100, checkpoint, map).

| Bestand | Inhoud |
|---|---|
| `save_manual.json` | Genormaliseerde handmatige save na de sessie |
| `save_roundtrip.json` | Zelfde na `load_game` + opnieuw opslaan (moet gelijk zijn aan manual) |
| `autosave.json` | Genormaliseerde `autosave(..., "map")` |
| `state_data.sha256` | SHA-256 van `GameState.state_data` (canonical JSON, `sort_keys`) na de sessie |

## Suite draaien

```bash
export GODOT=<pad>/Godot_v4.3-stable_linux.x86_64
$GODOT --headless --path . --import
.github/scripts/run_suite.sh mpsolobaselinetest
```

## Golden opnieuw genereren (alleen lokaal, niet in CI)

Alleen wanneer de **bedoelde** solo-serialisatie bewust wijzigt (eigen PR met uitleg):

```bash
$GODOT --headless --path . -- --mpsolobaselinetest --regen-golden
```

Committen wat in `scripts/tests/golden/mp_solo_baseline/` is veranderd.

## Normalisatie

De suite zet vóór vergelijking vaste waarden voor `play_time`, `saved_at`, `saved_unix` en
`heard_music` overal in de save-boom (ook in `checkpoint.state`; zie `VOLATILE_KEYS` in
`mp_solo_baseline_tests.gd`). Geen andere filtering.