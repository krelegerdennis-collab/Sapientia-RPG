# TelegraphLayer (Combat T3)

Status: geïmplementeerd op `scripts/som/telegraph_layer.gd`.

## Doel

Eén `Node2D` in de Action-arena (`SomArena`) tekent **alle** grond-telegrafen in één `_draw()`. De laag is puur visueel: ze leest `TelegraphAttack` / `TelegraphShape` / `TelegraphState` en verandert geen sim-logica, timings of schade.

## Waar

- Node: `Objects/TelegraphLayer` (kind 0 onder `Objects`, `z_index` 4).
- Sync: na elke vaste sim-stap in `SomArena._sim_world()` via `_sync_telegraph_draw()`.
- Alleen vijanden met `attacks`-data (`e["tg"]`); gewone float-telegraaf blijft rood knipperen op de sprite.

## Placeholder-visuals

- **Rood** = ontwijken (standaard, o.a. Inktspuw).
- **Geel + diagonale arcering** = onderbreekbaar (`interruptible: true` in `som_action_attacks.gd`, later Hamerslag).
- **3 px rand** (`draw_polyline`, `BORDER_PX`).
- **Opvulling** in 4 discrete stappen tijdens WINDUP; vol bij ACTIVE (`fill_steps` 1–4).
- Geen art-bestanden; `TEXTURE_FILTER_NEAREST` (pixel-perfect).

## Tests

`--telegraphtest` → `scripts/tests/telegraph_layer_tests.gd` (outline circle/line/cone, fill-stappen, zichtbaarheid per fase, leeg na einde).

## Volgende stappen (niet T3)

- T5: co-op snapshot stuurt telegraaf-state; gast tekent alleen snapshot.
- Echte art via RPG Forge (COMBAT_DESIGN §11 / voorstel sectie E).
