# PERF_WM1 — frametijd en geheugen van de zwaarste WM1-scènes (headless)

Script: `tools/perf/perf_wm1_scenes.gd` (+ `.tscn`, eigen steiger-scène; geen test, geen dispatch in `game_state.gd`).

```bash
godot --headless --path . res://tools/perf/perf_wm1_scenes.tscn -- --perfscenes \
    [--warmup=60] [--frames=600] [--seconds=5] [--only=dorp_wilgendal,battle] [--out=pad.md]
```

Print per scène een regel `PERFSCENE id=... avg_ms=... p95_ms=... max_ms=... n=... static_mb=... objects=... nodes=...`,
daarna een Markdown-tabel en `RESULT OK (...)` (exit 0; exit 1 als een scène niet laadt).

## Methode

1. Eigen save-paden (`user://perfscenes_*`), `GameState.new_game()`, encounters uit, preload eerst afgemaakt.
2. Remmen eraf: `Engine.max_fps = 0`, vsync uit, `AppLifecycle.set_low_processor_enabled(false)` en
   **`OS.low_processor_usage_mode_sleep_usec = 0`**. Dat laatste is nodig: headless kan geen venster tekenen
   en dan slaapt de Godot-main-loop élke iteratie die tijd (standaard 6900 µs). Zonder dit meet je overal
   ~6,9 ms / 145 FPS, ongeacht de scène.
3. Scène laden via `Wm1Frametime.enter_room()` (zelfde pad als `--wm1frametest`); het gevecht via
   `map.start_battle()` op de wereldkaart (echte encounter-route, 3 vijanden).
4. Warmup: minstens `--warmup` frames én 1 s wandklok. Dan geheugen-snapshot (`Performance`: `MEMORY_STATIC`,
   `OBJECT_COUNT`, `OBJECT_NODE_COUNT`, `OBJECT_RESOURCE_COUNT`, plus nodes onder de huidige scène), vóór het
   verzamelen zodat de eigen sample-array niet meetelt.
5. Meten: minstens `--frames` frames én `--seconds` wandklok. Frametijd = tijd tussen twee opeenvolgende
   `process_frame`-signalen (hele engine-iteratie incl. eventuele physics-ticks). Gemiddelde, p95 (nearest-rank), max.
   Tijd-gebaseerd omdat een headless frame ~0,1 ms duurt: 600 frames zouden maar ~50 ms speeltijd dekken.

## Scènes (keuze)

Uit de `--wm1frametest`-baseline (`docs/perf_wm1.md`, `docs/perf/wm1_baseline.md`), max 4:

| scène | waarom |
|---|---|
| `dorp_wilgendal` | meeste nodes (~1680) en draw calls (~206) van heel WM1 |
| `archief_puzzel` | meeste nodes buiten het dorp (puzzel-elementen) |
| `warper_hal` | hub-veldkaart, meeste draw calls na het dorp, meeste resources |
| `battle` | gevecht met 3 vijanden (sprites, HUD, menu) — ander type scène dan de kaarten |

## Resultaten

Windows 11, Godot 4.3-stable, `--headless`, standaardinstellingen (warmup 60 / ≥600 frames / ≥5 s), 2026-10-31.
Basis na `clear_scene` (geen scène): static 50,5 MB.

| scène | frame avg ms | p95 ms | max ms | frames (N) | static MB | Δ static MB | objects | nodes | scene nodes | resources |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `dorp_wilgendal` | 0.081 | 0.217 | 7.319 | 61747 | 84.1 | +33.6 | 6361 | 1720 | 1679 | 302 |
| `archief_puzzel` | 0.067 | 0.171 | 7.430 | 74195 | 75.9 | +25.4 | 3930 | 188 | 147 | 277 |
| `warper_hal` | 0.053 | 0.131 | 10.512 | 93634 | 83.5 | +33.0 | 3964 | 152 | 109 | 308 |
| `battle` | 0.122 | 0.301 | 9.486 | 41071 | 83.9 | +33.4 | 3829 | 82 | 41 | 307 |

Herhaald (3 runs): avg en p95 stabiel binnen ~±0,02 ms, geheugen/objecten gelijk; `max` varieert sterk
(1,7–10,5 ms) — losse pieken van het OS/scheduler, niet scène-gebonden.

Lezing:
- CPU-kant is ruim binnen budget: zelfs het gevecht (zwaarste per frame, ~0,12 ms gem / 0,3 ms p95) is <2 % van 16,7 ms.
- Het gevecht is per frame duurder dan het dorp ondanks 40x minder nodes: script-werk (animaties, HUD, menu) weegt
  zwaarder dan het aantal nodes.
- Het dorp heeft de meeste objecten/nodes (6361 / 1720); geheugen ligt voor alle scènes rond +25..+34 MB boven de basis
  (vooral textures/gedeelde resources, die na de eerste scène blijven hangen in de cache).

## Beperkingen van headless meten

- **Geen rendering.** `--headless` gebruikt de dummy-renderer: geen GPU-werk, geen draw calls, geen fill-rate,
  geen shaders. De gemeten frametijd is alleen CPU (scripts, physics, scene tree). Op een Android-telefoon met
  gl_compatibility is de GPU juist vaak de bottleneck — daarvoor `--wm1frametest`/`--wm1budgettest` met
  `--rendering-driver opengl3` of een echte meting op het toestel.
- **Geen script-tijd apart.** `RenderingServer.frame_pre_draw` (waarmee `Wm1Frametime` script-tijd meet) komt
  headless nooit; `Performance.TIME_PROCESS` gaf onbruikbare waarden. De frametijd ís hier de CPU-tijd per iteratie.
- **Desktop-CPU ≠ telefoon.** Absolute ms zijn van een desktop; alleen de verhouding tussen scènes is bruikbaar.
  Reken op een goedkope ARM-telefoon grofweg 5–10x trager.
- **Ongelimiteerde frames.** Zonder vsync/slaap draait de loop >10.000 iteraties/s; per frame-werk dat op `delta`
  schaalt kan daardoor anders verdeeld zijn dan bij 60 FPS. Physics loopt wel op 60 Hz wandklok (pieken in max/p95).
- **`MEMORY_STATIC`** telt alleen engine-allocaties via Godot's allocator, geen GPU-/driver-geheugen (headless toch
  niet aanwezig) en geen OS-overhead. Volgorde telt: resources uit een eerdere scène blijven in de cache, dus Δ is
  "na het laden van deze scène", niet "alleen deze scène".
- `max` is één frame en dus ruisgevoelig; gebruik p95 voor vergelijkingen.

## Wijziging in gedeelde code

`scripts/perf/wm1_frametime.gd` `enter_room()`: `await RenderingServer.frame_post_draw` wordt overgeslagen als
`DisplayServer.get_name() == "headless"` (dat signaal komt headless nooit; de run hing daar). Met een echte
renderer (CI, `--wm1frametest`/`--wm1budgettest`) verandert er niets.
