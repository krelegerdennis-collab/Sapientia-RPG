# WM1 performance-baseline (headless)

Automatisch gegenereerd door `--wm1baselinebenchtest` (`scripts/tests/wm1_baseline_benchmark.gd`). Niet de CI-matrix; opnieuw draaien na grote WM1-wijzigingen.

## Omgeving

- Godot **4.3-stable**, `gl_compatibility`, viewport **384×216**, `xvfb-run` + `--rendering-driver opengl3`.
- Warmup **25** frames, idle **120** frames, lopen **90** frames (rechts) waar een speler bestaat.
- **Frametijd** = wandklok tussen opeenvolgende frames (`max_fps=0`, vsync uit). Op llvmpipe **niet** gelijk aan een Galaxy S25.
- **S25-schatting** = `p95_ms + draw_avg×0.06 + scene_nodes×0.002`; **RISK** als ≥ **16.667 ms** (60 fps).

| id | kind | mode | frame avg ms | frame p95 ms | draw avg | draw max | scene nodes | engine nodes | static MB | S25 est ms | flag |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `archief_2_v1_entree` | map | idle+walk | 4.49 | 4.86 | 76.3 | 90 | 41 | 82 | 66.95 | 9.52 | **OK** |
| `archief_2_v1_plaat` | map | idle+walk | 4.09 | 4.50 | 124.8 | 125 | 30 | 71 | 66.91 | 12.05 | **WATCH** |
| `archief_2_v2_gang` | map | idle+walk | 4.24 | 6.17 | 126.5 | 127 | 36 | 77 | 66.93 | 13.83 | **WATCH** |
| `archief_2_v2_lotte` | map | idle+walk | 4.17 | 4.70 | 124.7 | 125 | 30 | 71 | 66.92 | 12.24 | **WATCH** |
| `archief_2_v3_ketting` | map | idle+walk | 4.25 | 6.14 | 125.9 | 126 | 39 | 80 | 66.96 | 13.78 | **WATCH** |
| `archief_2_v3_licht` | map | idle+walk | 4.38 | 6.09 | 124.5 | 125 | 30 | 71 | 66.93 | 13.62 | **WATCH** |
| `archief_2_v3_tegen` | map | idle+walk | 4.36 | 6.85 | 124.7 | 125 | 30 | 71 | 66.93 | 14.39 | **WATCH** |
| `archief_2_v3_wurger` | map | idle+walk | 4.10 | 4.54 | 126.4 | 127 | 36 | 77 | 66.98 | 12.20 | **WATCH** |
| `archief_2_v4_genezer` | map | idle+walk | 4.47 | 5.40 | 127.0 | 127 | 78 | 119 | 67.12 | 13.17 | **WATCH** |
| `archief_2_v4_hal` | map | idle+walk | 4.14 | 4.56 | 124.2 | 125 | 30 | 71 | 66.92 | 12.07 | **WATCH** |
| `archief_2_warper` | map | idle+walk | 4.36 | 6.13 | 67.0 | 129 | 35 | 76 | 67.43 | 10.22 | **OK** |
| `archief_bibliotheek` | map | idle+walk | 4.32 | 5.04 | 164.3 | 165 | 53 | 94 | 71.51 | 15.00 | **WATCH** |
| `archief_golemhal` | map | idle+walk | 4.37 | 6.36 | 142.9 | 143 | 32 | 73 | 71.53 | 15.00 | **WATCH** |
| `archief_ingang` | map | idle+walk | 4.41 | 5.05 | 145.5 | 146 | 40 | 81 | 71.56 | 13.86 | **WATCH** |
| `archief_puzzel` | map | idle+walk | 4.68 | 5.44 | 151.1 | 152 | 147 | 188 | 73.82 | 14.80 | **WATCH** |
| `archief_v1_gang` | map | idle+walk | 4.83 | 5.43 | 144.4 | 145 | 44 | 85 | 73.61 | 14.18 | **WATCH** |
| `archief_v2_kastenzaal` | map | idle+walk | 4.49 | 5.58 | 141.7 | 142 | 28 | 69 | 73.49 | 14.14 | **WATCH** |
| `archief_v2_leeszaal` | map | idle+walk | 4.53 | 5.70 | 141.6 | 142 | 38 | 79 | 73.62 | 14.27 | **WATCH** |
| `archief_v2_trapzaal` | map | idle+walk | 4.37 | 6.33 | 143.5 | 144 | 36 | 77 | 73.49 | 15.01 | **WATCH** |
| `archief_v3_gang` | map | idle+walk | 4.23 | 5.04 | 140.8 | 141 | 32 | 73 | 73.46 | 13.56 | **WATCH** |
| `archief_v3_zuilenhal` | map | idle+walk | 4.58 | 5.82 | 144.5 | 145 | 45 | 86 | 73.66 | 14.58 | **WATCH** |
| `archief_v4_voorhal` | map | idle+walk | 4.23 | 5.05 | 141.4 | 142 | 35 | 76 | 73.48 | 13.60 | **WATCH** |
| `archief_v4_wachtersgang` | map | idle+walk | 4.34 | 5.01 | 144.9 | 145 | 38 | 79 | 73.62 | 13.78 | **WATCH** |
| `berggrot_bouwplaats` | map | idle+walk | 4.15 | 4.89 | 146.5 | 147 | 49 | 90 | 74.62 | 13.78 | **WATCH** |
| `berggrot_geheim` | map | idle+walk | 4.20 | 4.68 | 147.7 | 148 | 126 | 167 | 75.19 | 13.79 | **WATCH** |
| `berggrot_grendel` | map | idle+walk | 3.91 | 4.39 | 143.6 | 144 | 82 | 123 | 74.97 | 13.17 | **WATCH** |
| `berggrot_mond` | map | idle+walk | 3.99 | 4.54 | 144.0 | 144 | 38 | 79 | 75.35 | 13.26 | **WATCH** |
| `berggrot_nerf` | map | idle+walk | 4.22 | 4.85 | 143.2 | 144 | 38 | 79 | 75.35 | 13.52 | **WATCH** |
| `berggrot_uitmond` | map | idle+walk | 3.92 | 4.24 | 142.9 | 143 | 35 | 76 | 75.34 | 12.88 | **WATCH** |
| `dorp_wilgendal` | map | idle+walk | 5.59 | 6.15 | 317.3 | 318 | 1679 | 1720 | 88.29 | 28.54 | **RISK** |
| `esdoorn` | map | idle+walk | 4.36 | 4.70 | 138.5 | 139 | 51 | 92 | 81.02 | 13.12 | **WATCH** |
| `esdoorn_herberg` | map | idle+walk | 3.72 | 4.04 | 141.0 | 141 | 22 | 63 | 78.66 | 12.55 | **WATCH** |
| `esdoorn_huis_noor` | map | idle+walk | 3.60 | 3.92 | 139.0 | 139 | 18 | 59 | 78.60 | 12.29 | **WATCH** |
| `huis_wilgendal` | map | idle+walk | 4.31 | 4.68 | 171.1 | 172 | 135 | 176 | 79.23 | 15.21 | **WATCH** |
| `kamer_beeldkamer` | map | idle+walk | 3.68 | 4.01 | 143.0 | 143 | 27 | 68 | 78.38 | 12.65 | **WATCH** |
| `kamer_echo_kamer` | map | idle+walk | 3.69 | 4.09 | 150.0 | 150 | 38 | 79 | 78.70 | 13.17 | **WATCH** |
| `kamer_hal` | map | idle+walk | 3.70 | 4.03 | 143.0 | 143 | 61 | 102 | 78.86 | 12.73 | **WATCH** |
| `kamer_handelskamer` | map | idle+walk | 3.67 | 4.07 | 140.0 | 140 | 23 | 64 | 78.65 | 12.52 | **WATCH** |
| `kamer_kern` | map | idle+walk | 4.19 | 5.01 | 140.0 | 140 | 23 | 64 | 78.65 | 13.45 | **WATCH** |
| `kamer_rustkamer` | map | idle+walk | 3.66 | 3.97 | 144.0 | 144 | 31 | 72 | 78.71 | 12.67 | **WATCH** |
| `kamer_trainingshal` | map | idle+walk | 3.62 | 3.91 | 141.0 | 141 | 23 | 64 | 78.67 | 12.41 | **WATCH** |
| `kamer_werkplaats` | map | idle+walk | 3.64 | 3.92 | 140.0 | 140 | 23 | 64 | 78.68 | 12.37 | **WATCH** |
| `leven_ingang` | map | idle+walk | 3.71 | 4.86 | 88.0 | 142 | 36 | 77 | 81.36 | 10.21 | **OK** |
| `leven_v1_plaat` | map | idle+walk | 4.00 | 4.70 | 123.2 | 126 | 133 | 174 | 81.91 | 12.36 | **WATCH** |
| `leven_v2_leeszaal` | map | idle+walk | 3.72 | 4.19 | 130.6 | 131 | 101 | 142 | 81.78 | 12.22 | **WATCH** |
| `leven_v3_combi` | map | idle+walk | 3.73 | 4.36 | 128.0 | 128 | 106 | 147 | 81.77 | 12.25 | **WATCH** |
| `warper_exterieur` | map | idle+walk | 3.85 | 4.21 | 124.4 | 125 | 20 | 61 | 82.71 | 11.71 | **WATCH** |
| `warper_hal` | map | idle+walk | 4.88 | 5.30 | 204.0 | 205 | 103 | 146 | 83.87 | 17.75 | **RISK** |
| `warper_hanger_nis` | map | idle+walk | 3.72 | 4.40 | 124.0 | 124 | 15 | 56 | 83.18 | 11.87 | **WATCH** |
| `warper_warp_ring` | map | idle+walk | 3.85 | 4.53 | 124.6 | 125 | 18 | 59 | 83.23 | 12.04 | **WATCH** |
| `wereldkaart` | map | idle+walk | 4.07 | 4.51 | 122.8 | 123 | 38 | 79 | 86.18 | 11.96 | **WATCH** |
| `wilgendal` | map | idle+walk | 4.98 | 5.72 | 137.0 | 138 | 72 | 113 | 84.54 | 14.09 | **WATCH** |
| `wilgendal_binnen` | map | idle+walk | 3.62 | 3.98 | 126.7 | 127 | 22 | 63 | 82.42 | 11.63 | **WATCH** |
| `woud_beek` | map | idle+walk | 6.99 | 7.93 | 491.2 | 492 | 25 | 66 | 83.56 | 37.45 | **RISK** |
| `woud_mistpoel` | map | idle+walk | 4.73 | 5.71 | 133.3 | 134 | 57 | 98 | 84.86 | 13.82 | **WATCH** |
| `woud_open_plek` | map | idle+walk | 4.54 | 5.19 | 134.0 | 135 | 54 | 95 | 84.71 | 13.34 | **WATCH** |
| `woud_pad` | map | idle+walk | 4.45 | 4.89 | 132.8 | 133 | 61 | 102 | 84.94 | 12.98 | **WATCH** |
| `woud_rand` | map | idle+walk | 4.65 | 5.10 | 136.6 | 137 | 55 | 96 | 84.72 | 13.41 | **WATCH** |
| `woud_sporenkring` | map | idle+walk | 4.48 | 4.85 | 134.8 | 135 | 53 | 94 | 84.72 | 13.04 | **WATCH** |
| `battle_gras` | battle | battle | 6.59 | 7.35 | 166.4 | 170 | 40 | 81 | 83.88 | 17.42 | **RISK** |
| `battle_woud` | battle | battle | 6.73 | 7.64 | 165.3 | 172 | 41 | 82 | 83.90 | 17.64 | **RISK** |
| `battle_archief` | battle | battle | 6.51 | 7.41 | 164.3 | 171 | 41 | 82 | 83.90 | 17.35 | **RISK** |
| `battle_baas_golem` | battle | battle | 6.80 | 7.47 | 189.9 | 196 | 43 | 84 | 83.54 | 18.95 | **RISK** |
| `battle_kas` | battle | battle | 6.50 | 7.28 | 164.6 | 171 | 40 | 81 | 83.52 | 17.23 | **RISK** |

## S25 60 fps (16,667 ms) — headless signalen

Bevestig op het toestel met `docs/perf/s25_check.md`. Headless **RISK** betekent: extra aandacht op de S25, geen garantie.

- **RISK:** `dorp_wilgendal`, `warper_hal`, `woud_beek`, `battle_gras`, `battle_woud`, `battle_archief`, `battle_baas_golem`, `battle_kas`
- **WATCH:** `archief_2_v1_plaat`, `archief_2_v2_gang`, `archief_2_v2_lotte`, `archief_2_v3_ketting`, `archief_2_v3_licht`, `archief_2_v3_tegen`, `archief_2_v3_wurger`, `archief_2_v4_genezer`, `archief_2_v4_hal`, `archief_bibliotheek`, `archief_golemhal`, `archief_ingang`, `archief_puzzel`, `archief_v1_gang`, `archief_v2_kastenzaal`, `archief_v2_leeszaal`, `archief_v2_trapzaal`, `archief_v3_gang`, `archief_v3_zuilenhal`, `archief_v4_voorhal`, `archief_v4_wachtersgang`, `berggrot_bouwplaats`, `berggrot_geheim`, `berggrot_grendel`, `berggrot_mond`, `berggrot_nerf`, `berggrot_uitmond`, `esdoorn`, `esdoorn_herberg`, `esdoorn_huis_noor`, `huis_wilgendal`, `kamer_beeldkamer`, `kamer_echo_kamer`, `kamer_hal`, `kamer_handelskamer`, `kamer_kern`, `kamer_rustkamer`, `kamer_trainingshal`, `kamer_werkplaats`, `leven_v1_plaat`, `leven_v2_leeszaal`, `leven_v3_combi`, `warper_exterieur`, `warper_hanger_nis`, `warper_warp_ring`, `wereldkaart`, `wilgendal`, `wilgendal_binnen`, `woud_mistpoel`, `woud_open_plek`, `woud_pad`, `woud_rand`, `woud_sporenkring`

## Kamers zonder speler (alleen idle)

Hub-kamers via `change_map`, warper-veldkaarten en gevechten meten geen loop-samples.
