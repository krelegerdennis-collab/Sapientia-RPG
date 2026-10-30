# WM1 performance-audit (frametime + budget)

Scope: speelbare **World Map 1** — alle `scenes/maps/*.tscn` (excl. `dungeon100`, `archief_test`, `kern_demo`), de World Warper-veldkaarten (`world_warper/maps/`, excl. cutscene-nissen) en hub-kamers (`world_warper/kamers/`). Geen WM2, geen nieuwe content. Dit document sluit aan op draw-call-werk in de hub (The Atrium / `warper_hal` + `kamer_hal`).

## Meting draaien

Omgeving: Godot **4.3.stable**, `gl_compatibility`, headless via `xvfb-run` en `--rendering-driver opengl3`, viewport **384×216** (zoals de game en een opgeschaalde S25-viewport).

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
# Frametime-log (57 kamers, ~65 s): één WM1FRAME-regel per kamer op stdout
GODOT=$GODOT .github/scripts/run_suite.sh wm1frametest
# Optioneel: --only=wilgendal,warper_hal  --warmup=30  --frames=180

# Budget-regressietest (286 PASS, ~58 s): zelfde meting, drempels in scripts/data/wm1_perf_budget.gd
GODOT=$GODOT .github/scripts/run_suite.sh wm1budgettest
```

Code:

| Onderdeel | Pad |
|---|---|
| Meting + kamerlijst | `scripts/perf/wm1_frametime.gd` |
| Log-suite | `scripts/tests/wm1_frametime_tests.gd` (`--wm1frametest`) |
| Budget-suite | `scripts/tests/wm1_budget_tests.gd` (`--wm1budgettest`) |
| Drempels | `scripts/data/wm1_perf_budget.gd` |
| Drempels opnieuw afleiden | `tools/perf/wm1_budget_from_log.py` (stdin = WM1FRAME-regels) |

Suites staan in de dispatch van `scripts/game_state.gd` maar **niet** in `.github/workflows/tests.yml` (bewust; RPG Forge kan ze toevoegen).

## Wat er gemeten wordt

Per kamer:

1. Vorige scène opruimen, kamer laden (veldkaart via `change_scene_to_packed`; hub-kamer via `GameState.change_map` met `warper_hub_open`).
2. **30** warmup-frames, daarna **180** meetframes (`max_fps = 0`, vsync uit).
3. Per meetframe:
   - **proc_ms** — script-fase van `process_frame` tot `RenderingServer.frame_pre_draw` (µs → ms, gemiddeld). Dit is de CPU-kant van idle gameplay **zonder** render-tijd; vergelijkbaar met `tools/perf/perf_wm1.gd` (`script_ms`). Als de callback 0 blijft, valt de meting terug op `TIME_PROCESS + TIME_PHYSICS_PROCESS` (zeldzaam op 4.3 headless).
   - **draw_avg** / **draw_max** — `RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME` (incl. touch-besturing en CRT-overlay via autoloads).
   - **scene_nodes** — nodes in de huidige scène-root.
   - **nodes** — `Performance.OBJECT_NODE_COUNT` (hele boom incl. autoloads).

Logformaat (machine-leesbaar):

```text
WM1FRAME id=wilgendal path=res://scenes/maps/wilgendal.tscn proc_ms=0.148 draw=38.2 draw_max=39 nodes=113 scene_nodes=72 frames=180
```

### Budget-drempels (niet flaky)

Baseline op deze agent-VM (24 okt 2026, één `wm1frametest`-run). Drempels in `wm1_perf_budget.gd`:

| metriek | marge |
|---|---|
| proc_ms | gemeten × **1,35** + **1,5** ms |
| draw_avg | gemeten + **3** |
| draw_max | gemeten + **3** |
| scene_nodes | gemeten + **8** |
| nodes (engine) | gemeten + **120** |

Draw calls en node-tellers zijn **deterministisch** op Godot 4.3; proc_ms heeft bewust een ruime marge tegen xvfb/llvmpipe-ruis. Na een echte perf-regressie: `wm1frametest` draaien, `wm1_budget_from_log.py` op de WM1FRAME-regels, `LIMITS` bijwerken.

## Baseline (24 okt 2026, headless VM)

Uitvoer: `wm1frametest` → 57 kamers, 57 PASS, RESULT OK (~65 s).

| id | proc_ms | draw_avg | draw_max | scene_nodes | nodes |
|---|---:|---:|---:|---:|---:|
| `archief_2_v1_entree` | 0.162 | 29.6 | 36 | 41 | 82 |
| `archief_2_v1_plaat` | 0.127 | 24.8 | 26 | 30 | 71 |
| `archief_2_v2_gang` | 0.118 | 26.0 | 27 | 31 | 72 |
| `archief_2_v2_lotte` | 0.118 | 25.1 | 26 | 30 | 71 |
| `archief_2_v3_ketting` | 0.121 | 26.1 | 27 | 39 | 80 |
| `archief_2_v3_licht` | 0.114 | 25.0 | 26 | 30 | 71 |
| `archief_2_v3_tegen` | 0.114 | 25.0 | 26 | 30 | 71 |
| `archief_2_v3_wurger` | 0.123 | 27.0 | 28 | 36 | 77 |
| `archief_2_v4_genezer` | 0.124 | 27.0 | 28 | 78 | 119 |
| `archief_2_v4_hal` | 0.118 | 25.1 | 26 | 30 | 71 |
| `archief_2_warper` | 0.139 | 28.1 | 30 | 35 | 76 |
| `archief_bibliotheek` | 0.149 | 50.0 | 50 | 53 | 94 |
| `archief_golemhal` | 0.142 | 31.4 | 32 | 32 | 73 |
| `archief_ingang` | 0.129 | 34.5 | 35 | 40 | 81 |
| `archief_puzzel` | 0.131 | 40.5 | 41 | 147 | 188 |
| `archief_v1_gang` | 0.120 | 33.4 | 34 | 44 | 85 |
| `archief_v2_kastenzaal` | 0.127 | 30.3 | 31 | 28 | 69 |
| `archief_v2_leeszaal` | 0.119 | 30.2 | 31 | 38 | 79 |
| `archief_v2_trapzaal` | 0.128 | 32.1 | 33 | 36 | 77 |
| `archief_v3_gang` | 0.119 | 29.0 | 30 | 32 | 73 |
| `archief_v3_zuilenhal` | 0.132 | 33.1 | 34 | 45 | 86 |
| `archief_v4_voorhal` | 0.120 | 30.1 | 31 | 35 | 76 |
| `archief_v4_wachtersgang` | 0.132 | 33.1 | 34 | 38 | 79 |
| `berggrot_bouwplaats` | 0.119 | 35.0 | 36 | 49 | 90 |
| `berggrot_geheim` | 0.137 | 36.1 | 37 | 126 | 167 |
| `berggrot_grendel` | 0.123 | 32.0 | 33 | 82 | 123 |
| `berggrot_mond` | 0.126 | 32.0 | 33 | 38 | 79 |
| `berggrot_nerf` | 0.129 | 32.0 | 33 | 38 | 79 |
| `berggrot_uitmond` | 0.138 | 31.1 | 32 | 35 | 76 |
| `dorp_wilgendal` | 0.325 | 206.3 | 207 | 1679 | 1720 |
| `esdoorn` | 0.116 | 27.2 | 28 | 51 | 92 |
| `esdoorn_herberg` | 0.134 | 29.0 | 30 | 22 | 63 |
| `esdoorn_huis_noor` | 0.120 | 27.0 | 28 | 18 | 59 |
| `huis_wilgendal` | 0.115 | 28.9 | 30 | 29 | 70 |
| `kamer_beeldkamer` | 0.119 | 31.3 | 32 | 27 | 68 |
| `kamer_echo_kamer` | 0.112 | 38.5 | 39 | 38 | 79 |
| `kamer_hal` | 0.118 | 31.0 | 32 | 61 | 102 |
| `kamer_handelskamer` | 0.585 | 28.4 | 29 | 23 | 64 |
| `kamer_kern` | 0.114 | 28.1 | 29 | 23 | 64 |
| `kamer_rustkamer` | 0.115 | 31.9 | 33 | 31 | 72 |
| `kamer_trainingshal` | 0.113 | 29.4 | 30 | 23 | 64 |
| `kamer_werkplaats` | 0.109 | 28.4 | 29 | 23 | 64 |
| `leven_ingang` | 0.159 | 27.7 | 31 | 36 | 77 |
| `leven_v1_plaat` | 0.141 | 25.3 | 27 | 133 | 174 |
| `leven_v3_combi` | 0.124 | 28.0 | 29 | 106 | 147 |
| `warper_exterieur` | 0.118 | 25.2 | 26 | 20 | 61 |
| `warper_hal` | 0.126 | 54.2 | 55 | 103 | 149 |
| `warper_hanger_nis` | 0.109 | 24.8 | 25 | 15 | 56 |
| `warper_warp_ring` | 0.108 | 25.7 | 26 | 18 | 59 |
| `wereldkaart` | 0.128 | 23.6 | 24 | 38 | 79 |
| `wilgendal` | 0.148 | 38.2 | 39 | 72 | 113 |
| `wilgendal_binnen` | 0.151 | 27.2 | 28 | 22 | 63 |
| `woud_mistpoel` | 0.158 | 34.2 | 35 | 57 | 98 |
| `woud_open_plek` | 0.153 | 34.9 | 36 | 54 | 95 |
| `woud_pad` | 0.139 | 33.2 | 34 | 56 | 97 |
| `woud_rand` | 0.146 | 37.3 | 38 | 55 | 96 |
| `woud_sporenkring` | 0.149 | 35.3 | 36 | 53 | 94 |

### Hub / Atrium (draw calls)

| Scène | Rol | draw_avg | scene_nodes | Notitie |
|---|---|---:|---:|---|
| `warper_hal` | Hal met warp-ring (veldkaart) | 54.2 | 103 | Veel losse hub-sprites; batching raakt art/layout. |
| `kamer_hal` | The Atrium (hub-kamer) | 31.0 | 61 | Binnen-kamer; minder draw calls dan de buiten-hal. |
| `dorp_wilgendal` | Willowdale plein | 206.3 | 1679 | Grootste draw-call-last in WM1 (SoM-v8 + props). |

## Beperkingen

- Gemeten op **Linux xvfb + llvmpipe**, niet op een Samsung S25-GPU. **draw_avg**, **draw_max** en **scene_nodes** zijn wel bruikbaar als absolute budgetten op Godot 4.3; **proc_ms** is alleen onderling vergelijkbaar (zelfde machine/methode).
- Geen lopende speler, geen encounters (`encounters = false` op kaarten); alleen idle met autoloads (touch, CRT).
- Uitgebreidere profiel-run (laadtijd, textuur-scan): `--perftest` en `docs/perf/WM1_PERF.md`.

## Texture-import (pixel art) — ongewijzigd sinds eerdere audit

| Check | Resultaat |
|---|---|
| `textures/canvas_textures/default_texture_filter` in `project.godot` | `0` (= nearest) |
| WM1-gerelateerde `.import` met `mipmaps/generate=true` op SoM-paden | **0** |
| Runtime nearest waar nodig (`KaartStijl`, hub-decor) | OK |

## Tests gedraaid (deze PR)

| suite | Resultaat |
|---|---|
| `--wm1frametest` | 57 PASS, 0 FAIL, ~65 s |
| `--wm1budgettest` | 286 PASS, 0 FAIL, ~58 s |
