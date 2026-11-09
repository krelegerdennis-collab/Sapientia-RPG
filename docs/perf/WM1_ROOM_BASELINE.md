# WM1 nulmeting per kamer

Automatisch gegenereerd door `--wm1roombaselinetest` (`scripts/tests/wm1_room_baseline_tests.gd`). Elke kamer is apart geladen: vorige scène vrijgegeven, `GameState.new_game()`, stijlcache leeg (`KaartStijl.zet_config({})`) en de PackedScene opnieuw van schijf. Niet de CI-matrix. Een overschrijding van `scripts/data/wm1_perf_budget.gd` is een waarschuwing, geen fout.

## Omgeving

- Godot **4.3-stable (official)**, renderer `llvmpipe (LLVM 20.1.2, 256 bits)`, display `X11`.
- Probe: warmup **30** + **180** meetframes (`Wm1Frametime.sample_idle`, zelfde als `--wm1budgettest`).
- Frametijd: wandklok over **60** frames ná de probe (`max_fps=0`, vsync uit). Op llvmpipe niet gelijk aan een telefoon.
- `scene_nodes` telt de huidige scène. `nodes` is `OBJECT_NODE_COUNT`. `objects` is `OBJECT_COUNT`. `static_mb` is `MEMORY_STATIC`.
- `load_ms` is de scènewissel. Hub-kamers gaan via `change_map` en tellen de fade (~0,3 s) mee.

## Zwaarste 5 op scene nodes

| id | scene nodes | frame p95 ms |
|---|---:|---:|
| `dorp_wilgendal` | 1679 | 5.38 |
| `archief_puzzel` | 147 | 4.11 |
| `huis_wilgendal` | 135 | 4.21 |
| `leven_v1_plaat` | 133 | 5.11 |
| `berggrot_geheim` | 126 | 4.10 |

## Zwaarste 5 op frame p95 ms

| id | frame p95 ms | scene nodes |
|---|---:|---:|
| `berggrot_nerf` | 5.74 | 38 |
| `woud_beek` | 5.66 | 25 |
| `dorp_wilgendal` | 5.38 | 1679 |
| `archief_2_v3_licht` | 5.38 | 30 |
| `archief_2_v3_tegen` | 5.27 | 30 |

## Kamers

| id | groep | load ms | scene nodes | nodes | objects | draw avg | draw max | proc ms | static MB | frame avg | frame p95 | budget |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `archief_2_v1_entree` | maps | 150.4 | 41 | 82 | 2383 | 33.0 | 33 | 0.173 | 72.38 | 3.73 | 4.45 | ok |
| `archief_2_v1_plaat` | maps | 22.4 | 30 | 71 | 2360 | 28.0 | 28 | 0.155 | 72.34 | 3.53 | 3.95 | ok |
| `archief_2_v2_gang` | maps | 22.6 | 36 | 77 | 2375 | 30.0 | 30 | 0.154 | 72.36 | 3.63 | 4.78 | ok |
| `archief_2_v2_lotte` | maps | 26.8 | 30 | 71 | 2364 | 28.0 | 28 | 0.151 | 72.34 | 3.51 | 3.92 | ok |
| `archief_2_v3_ketting` | maps | 28.7 | 39 | 80 | 2376 | 29.0 | 29 | 0.156 | 72.39 | 3.76 | 4.68 | ok |
| `archief_2_v3_licht` | maps | 22.6 | 30 | 71 | 2362 | 28.0 | 28 | 0.159 | 72.35 | 3.68 | 5.38 | ok |
| `archief_2_v3_tegen` | maps | 24.7 | 30 | 71 | 2362 | 28.0 | 28 | 0.160 | 72.35 | 3.69 | 5.27 | ok |
| `archief_2_v3_wurger` | maps | 32.9 | 36 | 77 | 2374 | 30.0 | 30 | 0.165 | 72.40 | 3.47 | 3.99 | ok |
| `archief_2_v4_genezer` | maps | 28.3 | 78 | 119 | 2433 | 30.0 | 30 | 0.189 | 72.54 | 3.78 | 4.39 | ok |
| `archief_2_v4_hal` | maps | 25.8 | 30 | 71 | 2364 | 28.0 | 28 | 0.151 | 72.35 | 3.57 | 4.04 | ok |
| `archief_2_warper` | maps | 30.4 | 35 | 76 | 2598 | 32.0 | 32 | 0.159 | 72.80 | 3.56 | 4.07 | ok |
| `archief_bibliotheek` | maps | 71.2 | 53 | 94 | 2855 | 54.0 | 54 | 0.173 | 76.88 | 3.69 | 4.59 | ok |
| `archief_golemhal` | maps | 27.4 | 32 | 73 | 2827 | 32.0 | 32 | 0.179 | 76.89 | 3.65 | 4.16 | ok |
| `archief_ingang` | maps | 27.3 | 40 | 81 | 2839 | 35.0 | 35 | 0.160 | 76.93 | 3.69 | 4.11 | ok |
| `archief_puzzel` | maps | 28.3 | 147 | 188 | 3219 | 41.0 | 41 | 0.174 | 79.19 | 3.69 | 4.11 | ok |
| `archief_v1_gang` | maps | 23.3 | 44 | 85 | 3027 | 34.0 | 34 | 0.159 | 78.98 | 3.78 | 4.21 | ok |
| `archief_v2_kastenzaal` | maps | 27.2 | 28 | 69 | 3000 | 31.0 | 31 | 0.160 | 78.87 | 3.78 | 4.36 | ok |
| `archief_v2_leeszaal` | maps | 27.8 | 38 | 79 | 3020 | 31.0 | 31 | 0.166 | 79.00 | 3.61 | 4.11 | ok |
| `archief_v2_trapzaal` | maps | 27.2 | 36 | 77 | 3013 | 33.0 | 33 | 0.171 | 78.87 | 3.65 | 4.32 | ok |
| `archief_v3_gang` | maps | 21.9 | 32 | 73 | 3007 | 30.0 | 30 | 0.154 | 78.83 | 3.61 | 4.48 | ok |
| `archief_v3_zuilenhal` | maps | 28.0 | 45 | 86 | 3031 | 34.0 | 34 | 0.172 | 79.04 | 3.90 | 4.55 | ok |
| `archief_v4_voorhal` | maps | 23.7 | 35 | 76 | 3012 | 31.0 | 31 | 0.165 | 78.86 | 4.31 | 5.06 | ok |
| `archief_v4_wachtersgang` | maps | 38.4 | 38 | 79 | 3018 | 34.0 | 34 | 0.182 | 79.00 | 3.88 | 4.44 | ok |
| `berggrot_bouwplaats` | maps | 44.9 | 49 | 90 | 3030 | 36.0 | 36 | 0.163 | 80.00 | 3.48 | 3.85 | ok |
| `berggrot_geheim` | maps | 31.3 | 126 | 167 | 3350 | 37.0 | 37 | 0.181 | 80.57 | 3.54 | 4.10 | ok |
| `berggrot_grendel` | maps | 22.2 | 82 | 123 | 3263 | 33.0 | 33 | 0.177 | 80.35 | 3.65 | 4.25 | ok |
| `berggrot_mond` | maps | 32.9 | 38 | 79 | 3405 | 33.0 | 33 | 0.183 | 80.73 | 3.37 | 3.79 | ok |
| `berggrot_nerf` | maps | 30.6 | 38 | 79 | 3405 | 33.0 | 33 | 0.167 | 80.73 | 3.65 | 5.74 | ok |
| `berggrot_uitmond` | maps | 31.6 | 35 | 76 | 3399 | 32.0 | 32 | 0.170 | 80.72 | 3.47 | 3.93 | ok |
| `dorp_wilgendal` | maps | 220.2 | 1679 | 1720 | 7506 | 207.0 | 207 | 0.188 | 93.69 | 4.97 | 5.38 | WARN scene_nodes, nodes |
| `esdoorn` | maps | 40.5 | 51 | 92 | 5450 | 28.0 | 28 | 0.155 | 86.41 | 3.91 | 4.29 | ok |
| `esdoorn_herberg` | maps | 46.1 | 22 | 63 | 4725 | 30.0 | 30 | 0.162 | 84.06 | 3.23 | 3.62 | ok |
| `esdoorn_huis_noor` | maps | 23.1 | 18 | 59 | 4716 | 28.0 | 28 | 0.151 | 84.00 | 3.06 | 3.41 | ok |
| `huis_wilgendal` | maps | 42.9 | 135 | 176 | 4869 | 61.0 | 61 | 0.160 | 84.62 | 3.90 | 4.21 | WARN scene_nodes |
| `kamer_beeldkamer` | warper_kamers | 350.3 | 27 | 68 | 4734 | 32.0 | 32 | 0.154 | 83.77 | 3.04 | 3.42 | ok |
| `kamer_echo_kamer` | warper_kamers | 323.5 | 38 | 79 | 4756 | 39.0 | 39 | 0.150 | 84.09 | 3.12 | 3.46 | ok |
| `kamer_hal` | warper_kamers | 335.1 | 61 | 102 | 4787 | 32.0 | 32 | 0.148 | 84.25 | 3.14 | 3.53 | ok |
| `kamer_handelskamer` | warper_kamers | 321.2 | 23 | 64 | 4735 | 29.0 | 29 | 0.147 | 84.03 | 3.00 | 3.31 | ok |
| `kamer_kern` | warper_kamers | 324.7 | 23 | 64 | 4737 | 29.0 | 29 | 0.147 | 84.05 | 3.03 | 3.33 | ok |
| `kamer_rustkamer` | warper_kamers | 319.0 | 31 | 72 | 4751 | 33.0 | 33 | 0.145 | 84.10 | 3.09 | 3.40 | ok |
| `kamer_trainingshal` | warper_kamers | 323.4 | 23 | 64 | 4741 | 30.0 | 30 | 0.147 | 84.06 | 3.15 | 3.50 | ok |
| `kamer_werkplaats` | warper_kamers | 322.6 | 23 | 64 | 4743 | 29.0 | 29 | 0.150 | 84.07 | 3.23 | 3.71 | ok |
| `leven_ingang` | maps | 48.4 | 36 | 77 | 4767 | 31.0 | 31 | 0.180 | 86.76 | 3.47 | 3.80 | ok |
| `leven_v1_plaat` | maps | 24.6 | 133 | 174 | 5103 | 29.0 | 29 | 0.186 | 87.30 | 3.56 | 5.11 | ok |
| `leven_v2_leeszaal` | maps | 23.6 | 101 | 142 | 5049 | 34.0 | 34 | 0.164 | 87.17 | 3.27 | 3.60 | ok |
| `leven_v3_combi` | maps | 22.3 | 106 | 147 | 5051 | 31.0 | 31 | 0.168 | 87.17 | 3.34 | 3.79 | ok |
| `warper_exterieur` | warper_maps | 22.5 | 20 | 61 | 4925 | 28.0 | 28 | 0.155 | 87.58 | 3.40 | 3.74 | ok |
| `warper_hal` | warper_maps | 35.8 | 103 | 146 | 5096 | 108.0 | 108 | 0.155 | 88.69 | 4.45 | 4.83 | ok |
| `warper_hanger_nis` | warper_maps | 18.9 | 15 | 56 | 4922 | 27.0 | 27 | 0.143 | 87.99 | 3.42 | 4.47 | ok |
| `warper_warp_ring` | warper_maps | 22.7 | 18 | 59 | 4927 | 28.0 | 28 | 0.143 | 88.05 | 3.22 | 3.61 | ok |
| `wereldkaart` | maps | 51.8 | 38 | 79 | 4974 | 26.0 | 26 | 0.162 | 90.95 | 3.42 | 3.87 | ok |
| `wilgendal` | maps | 63.2 | 72 | 113 | 5268 | 41.0 | 41 | 0.180 | 88.82 | 4.63 | 5.26 | ok |
| `wilgendal_binnen` | maps | 24.7 | 22 | 63 | 4593 | 30.0 | 30 | 0.140 | 86.41 | 3.12 | 3.69 | ok |
| `woud_beek` | maps | 62.3 | 25 | 66 | 4925 | 378.0 | 378 | 0.165 | 87.71 | 4.93 | 5.66 | WARN draw_avg, draw_max |
| `woud_mistpoel` | maps | 52.9 | 57 | 98 | 5479 | 37.0 | 37 | 0.203 | 89.03 | 3.95 | 4.44 | ok |
| `woud_open_plek` | maps | 50.6 | 66 | 107 | 5484 | 37.7 | 38 | 0.191 | 88.98 | 4.19 | 4.58 | WARN scene_nodes |
| `woud_pad` | maps | 35.5 | 61 | 102 | 5485 | 36.0 | 36 | 0.196 | 89.18 | 4.33 | 4.96 | ok |
| `woud_rand` | maps | 32.8 | 55 | 96 | 5469 | 40.0 | 40 | 0.190 | 88.96 | 4.10 | 4.82 | ok |
| `woud_sporenkring` | maps | 32.2 | 53 | 94 | 5465 | 38.0 | 38 | 0.194 | 88.96 | 4.09 | 4.49 | ok |

## Boven het bestaande budget (waarschuwing)

Drempels zijn de sequentiële meting in `scripts/data/wm1_perf_budget.gd`. Deze nulmeting laadt elke kamer geïsoleerd; daardoor kan een kamer hoger uitkomen dan die drempel. De test faalt daar niet op.

| id | metriek | gemeten | drempel |
|---|---|---:|---:|
| `dorp_wilgendal` | scene_nodes | 1679 | 838 |
| `dorp_wilgendal` | nodes | 1720 | 991 |
| `huis_wilgendal` | scene_nodes | 135 | 39 |
| `woud_beek` | draw_avg | 378 | 127.1 |
| `woud_beek` | draw_max | 378 | 128 |
| `woud_open_plek` | scene_nodes | 66 | 62 |

## Herhaling

`dorp_wilgendal` nog een keer na de andere kamers: scene_nodes **1679** en **1679**.

## Kamers zonder drempel

Geen.
