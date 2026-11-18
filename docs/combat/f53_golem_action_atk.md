# F5.3 A4 · Golem: eigen ATK in Action (Classic ongewijzigd)

**Besluit Dennis, 18-11-2026:** baasdoelen gelden op het in-game level (Golem Lv 7, `EERSTE_ARCHIEF_DOEL`).
A4: "Ja, Golem Action-ATK 27 met de testaanpassingen".

## Probleem
Op Lv 7 wezen de twee modi een andere kant op met hetzelfde stat-blok (`ENEMIES.kennis_beest.boss`, HP 520 / ATK 23):

| | doel | gemeten |
|---|---|---|
| Classic Lv 7 (`--wm1balans --only=golem`, kolom Lv-1) | 80-95% | 76% |
| Action Lv 7 (`--actionsim --boss-rt`, default) | 60-80% | 98,5% |

Een gedeelde ATK 24 bracht Classic Lv 7 naar 59%, daarom alleen Action.

## Wijziging
- `SomData.ACTION_BOSS_ATK = {"kennis_beest": 27}`; `SomData.action_boss_stats` zet die ATK na `BossCore.apply_boss`.
  De baas wordt herkend aan zijn `"boss"`-blok (gelijk aan dat in `GameData.ENEMIES`), dus alleen ruwe vijand-data.
- Classic (`battle.gd`, `BossCore.apply_boss`) en `game_data.gd` zijn ongewijzigd. Andere bazen ook.
- Tests: `golem_action_tests.gd` (Action ATK 27 + Classic nog 23), `boss_phase_tests.gd` (Golem-ATK = `ACTION_BOSS_ATK`, Wortelkoning = `apply_boss`).

## Sim (seed 20261020, 200 gevechten, Lv 7, profiel default)

| Action-ATK | winst | p90 HP-verlies |
|---|---|---|
| 23 (oud) | 98,5% | 75% |
| 24 | 93,5% | 87% |
| 25 | 88,0% | 100% |
| 26 | 80,5% | 100% |
| **27** | **72,0%** | 100% |
| 28 | 63,5% | 100% |

27 en niet 26: de sim kent de stagger (#450) niet, dus in het echt is het iets makkelijker.
