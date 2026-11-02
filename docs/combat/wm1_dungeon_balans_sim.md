# WM1-balans: Wachtersgang, Voorhal en Zuilenhal moeilijker

Datum: 02-11-2026 · basis `origin/main` @ 96b1613 (#345).

## Methode
Gelijk aan `t31_sim_rapport.md` / `sim_na_342.md`: party via `GameState._build_som_state` (Lv 3), parameters `params_base()` van `tools/battlesim/action_sim.gd`, DT 1/30 s, 200 runs, seed `hash([20261020, kamer, groep, run])`, KAMER = alle groepen achter elkaar zonder genezen. Vijanden met `GameData.apply_archief_tier` op de tier van de kamer. Doelband: 60-90% winst.

HP-verlies = gemiddeld HP-verlies van de party aan het eind; laagste punt = gemiddeld verlies op het laagste moment.

## Oud → nieuw (KAMER, 200 runs)
| Kamer | Vijanden | Winst | HP-verlies eind | Laagste punt (verlies) |
|---|---|---|---|---|
| v4_wachtersgang | 6 → 7 | 91.0 → **83.5%** | 43.8 → 46.7% | 52.0 → 55.7% |
| v4_voorhal | 4 → 6 | 96.5 → **83.5%** | 41.8 → 56.4% | 50.2 → 62.8% |
| v3_zuilenhal | 6 → 9 | 98.0 → **88.0%** | 37.9 → 45.2% | 46.1 → 53.4% |

De oude waarden zijn op deze basis opnieuw gemeten en bit-identiek aan `sim_na_342.md`.

## Wijzigingen (alleen `scripts/data/dungeon_rooms.gd`, alleen vijandgroepen)
Geen vijandstats, heldstats, globale constanten, Golem of andere kamers/WM2 aangepast. Het groepsleider-veld (`enemy`) blijft gelijk.

| Kamer | Groep | Oud | Nieuw |
|---|---|---|---|
| archief_v4_wachtersgang | m4 | `["kennis_beest"]` | `["kennis_beest", "glitchmot"]` |
| archief_v4_voorhal | m1 | `["kennis_beest"]` | `["kennis_beest", "papiergeest"]` |
| archief_v4_voorhal | m3 (guard) | `["kennis_beest"]` | `["kennis_beest", "papiergeest"]` |
| archief_v3_zuilenhal | m2 | `["mech_wachter"]` | `["mech_wachter", "papiergeest"]` |
| archief_v3_zuilenhal | m3 | `["mech_wachter"]` | `["mech_wachter", "papiergeest"]` |
| archief_v3_zuilenhal | m4 | `["kennis_beest"]` | `["kennis_beest", "papiergeest"]` |

Tussenstappen (verworpen): alleen een extra glitchmot (zuilenhal m1 / voorhal m1) verandert bijna niets (96.5% / 95.5%); voorhal met alleen m3 + papiergeest of + mech_wachter: 88.0 / 88.5%; zuilenhal met m3+m4 + papiergeest: 93.5%.

## Tests
Alle 74 suites uit `tests.yml` lokaal headless groen (xvfb, Godot 4.3), plus `--actionsim` exit 0 (`docs/ACTION_BALANCE_REPORT.md` teruggezet). Geen tests aangepast.
