# Epic keten-feel (WM1 Action)

Client-only feel boven op de bestaande 3-slag keten (`SomChainData`). Classic/turn-based ongewijzigd.

## Sim (deterministisch)

| stap | hitstop (ticks) |
|---|---|
| hit1 | 0 |
| hit2 | 2 |
| finisher | 6 |

## Screenshake (`SomFeelData`, achter optie `screen_shake`)

| soort | px | ticks |
|---|---|---|
| finisher | 2 | 6 |
| heavy L2 | 3 | 8 (blijft ≥ finisher) |

## Schadegetal finisher

- Kleur: `COL_FINISHER_NUMBER` = `#FFD24A`, schaal `SCALE_FINISHER_NUMBER` = `1.3`
- `COL_FINISHER` (`#FF8A3D`) blijft voor stagger/wankel-ui

## FX (`assets/sprites/som/fx/`)

| staat | asset | rotatie |
|---|---|---|
| hit1 | `fx_chain_hit1.png` (96×32, 3×50 ms) | `dir.angle()` |
| hit2 | `fx_chain_hit2.png` | idem |
| finisher | `fx_chain_finisher_<held>.png` (160×32, ms 50/50/60/50/50) | idem |
| finisher (grond) | `fx_chain_shockwave.png` (192×48, 4×55 ms) | **geen** |
| onbekende held finisher | terugval `fx_slash.png` | |

Trigger op treffer (zelfde moment als `SomFx.slash`). Zie README in de RPG ART-drop.

## Nagloed (alleen finisher-animatie)

- 3 gepoolde `Sprite2D` per held-id
- Frame −1 / −2 / −3 t.o.v. de aanvalssprite
- Offset tegen kijkrichting: 4 / 8 / 12 px; alpha 0,55 / 0,35 / 0,18
- Tint per held in `SomChainData.AFTERIMAGE_TINT`

## Vijand flits

1 sim-tick (`1/60` s) witte modulate op finisher-treffer.

## Tests

`godot -- --chainfeeltest` (nog niet in CI-matrix; Dennis voegt `chainfeeltest` toe aan `tests.yml`).