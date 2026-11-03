# Gevechtsduur-balans (Action/realtime) — sim voor en na

Besluit Dennis (2 nov 2026): "Ja, de gevechten mogen langer duren." Doel: gemiddelde gevechtsduur in realtime
Action-modus ca. +30-50%, winkans overal 60-90%, Golem niet dodelijker.

## Wat is er veranderd (alleen data, `scripts/data/som_data.gd`, `ACTION_AREAS.archief1`)

| veld | voor | na |
|---|---|---|
| `hp_hits` (vijand-HP geklemd op x volle slagen van een verse Dax) | 2.5-3.0 | 3.7-4.4 |
| `hits` (doelbereik, bewaakt door balansarchief1test) | 3.0-3.5 | 3.7-4.9 |
| tier 1 schade / cooldown | 0.21 / 3.0 | 0.14 / 3.15 |
| tier 2 schade | 0.53 | 0.36 |
| tier 3 schade | 0.50 | 0.35 |
| tier 4 schade | 0.65 | 0.43 |

Dit geldt alleen in Action (som_arena / `SomData.apply_action_area`). Classic (turn-based), de GameData-stats,
bazen en unieke vijanden blijven ongewijzigd. Meer HP met minder schade per klap: langer, niet dodelijker.

## Methode

- WM1-kerkers: `action_sim.gd` `fight_room` (realtime spelermodel), party = SoM-start (Dax + startleden) op
  **level 3**, de **hele kamer achter elkaar zonder heal** (alle gewone monsters, geen baas), 200 runs per kamer,
  seed `hash([20261102, kamer, run])`. Vijanden met de echte Action-regels: `apply_archief_tier` +
  `SomData.apply_action_area`, schade `SomData.enemy_damage_mult(kamer, tier)`, cooldown `SomData.attack_cooldown`.
  (Tijdelijke wrapper, niet gecommit.)
- Golem: `-- --actionsim --boss-rt --boss-levels=7` (200 gevechten, profiel default = ontwijkkans 0.35).
- Dax solo per tier (ontwerpdoelen in `targets`): `balansarchief1test` (500 gevechten per kamer).

## Resultaat: WM1-kerkers (party lv 3, hele kamer, 200 runs)

| kamer | tier | winst voor | winst na | gem. duur voor | gem. duur na | Δ duur | p90 HP-verlies voor | na |
|---|---|---|---|---|---|---|---|---|
| archief_v4_wachtersgang | 4 | 100% | 100% | 14.6 s | 19.6 s | +34% | 47% | 38% |
| archief_v4_voorhal | 4 | 100% | 100% | 12.6 s | 16.7 s | +32% | 48% | 36% |
| archief_v3_zuilenhal | 3 | 100% | 100% | 15.8 s | 21.9 s | +39% | 40% | 37% |

Vijand-HP in deze kamers: 40-54 -> 57-74.

## Resultaat: Dax solo per tier (balansarchief1test, doelen ongewijzigd)

| tier | doel winst | voor | na | HP-verlies voor | na |
|---|---|---|---|---|---|
| 1 (lv 1) | 80-90% (verlies <= 80%) | 86% | 88% | 78% | 79% |
| 2 (lv 2) | 70-85% | 77% | 75% | | |
| 3 (lv 3) | 65-80% | 73% | 73% | | |
| 4 (lv 4) | 60-75% | 67% | 66% | | |

## Resultaat: Golem realtime (lv 7, 200 gevechten) — ONGEWIJZIGD

| profiel | winst | gem. duur | p90 HP-verlies |
|---|---|---|---|
| default (voor = na) | 65.5% | 23.8 s | 100% |
| good (voor = na) | 98.5% | 23.5 s | 82.9% |

De Golem is in deze PR **niet** aangepast. Zijn stats (HP 360 / ATK 27 / DEF 15) en de kernklok (8 s cyclus,
2 s open, break 45) zijn vastgelegd in bestaande tests (`golemtest`, `golemactiontest`, `golemactionsimtest`,
`golemarenatest`: "Golem stats ongewijzigd"), en die tests passen we niet aan. Een langer Golem-gevecht met minder
ATK (bv. HP 360 -> ~500, ATK 27 -> ~24) vraagt eerst een besluit van Dennis + aanpassing van die tests.

## Opmerkingen

- Met de echte Action-regels wint de party op lv 3 elke WM1-kamer (100%); de 60-90%-band wordt bewaakt door de
  Dax-solo-doelen hierboven. Het oudere WM1-sim-model (globale `ENEMY_DAMAGE_MULT` 2.2, zonder gebiedsregels) gaf
  81-90.5% winst bij 13.3-14.3 s; dat model leest `ACTION_AREAS` niet en verandert dus niet door deze PR.
- Archief 1 tier 1-2 (archief_v1/v2) worden ook langer (zelfde `hp_hits`).
