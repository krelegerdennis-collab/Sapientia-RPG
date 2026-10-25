# WM1 performance-profiel

Meting van alle WM1-scènes (Willowdale, wereldkaart 1, Eerste Archief, Donker Woud, gevechten) met de
nieuwe profileermodus `--perftest`, plus de kleine fixes die daaruit kwamen. Doel: eerst meten, dan alleen
ingrijpen waar de winst duidelijk is en het risico klein. Geen enkele art-bestand is aangeraakt of visueel veranderd.

## Draaien

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
GODOT=$GODOT .github/scripts/run_suite.sh perftest                      # alle scènes, ~40 s, schrijft PASS/FAIL + RESULT OK
GODOT=$GODOT .github/scripts/run_suite.sh perftest --csv=/tmp/run1.csv  # ook een CSV (1 rij per scène)
# eenmalig, met de hand (xvfb nodig voor gl_compatibility):
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --perftest --perf-only=dorp_wilgendal,battle_gras --perf-verbose
# mediaan over meerdere runs, en voor/na:
python3 tools/perf/perf_tabel.py run1.csv run2.csv run3.csv
python3 tools/perf/perf_tabel.py --voor voor_*.csv --na na_*.csv
```

Opties (na `--`): `--perf-frames=N` (meetframes per scène, standaard 180), `--perf-only=id,id`, `--csv=pad`, `--md=pad`,
`--perf-verbose` (alle textures per scène), `--perf-hide=Naam,Naam` (verberg nodes met die naam vóór het meten, om hun
draw calls te isoleren). De vlag eindigt op `test` zodat de wereldkaart-cutscene zich als in de andere suites gedraagt.
Code: `scripts/tests/perf_wm1.gd` (aangeroepen via de lijst in `scripts/game_state.gd`, zoals de andere suites).
De suite staat bewust niet in `.github/workflows/tests.yml` (meting, geen regressietest; RPG Forge kan hem toevoegen).

## Wat er gemeten wordt

Per scène: de vorige scène wordt eerst opgeruimd, dan geladen, 90 frames laten rusten (fades, autosave) en 180 frames gemeten
zonder 60 fps-begrenzing en zonder vsync.

| kolom | betekenis |
|---|---|
| load ms | `load()` van de .tscn (alleen de eerste keer duur; GameState bewaart bezochte scènes) |
| enter ms | scènewissel tot het eerste getekende frame (instantiëren + `_ready` van de kaart) |
| frame ms / p95 | wandkloktijd per frame (gemiddelde / 95e percentiel) |
| draw calls | `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`, gemiddeld per frame (incl. touch-besturing en CRT-overlay) |
| nodes | nodes in de scène zelf |
| objects | `OBJECT_COUNT` van de hele engine (nodes + resources) |
| tex ref MB | unieke textures die de scène referereert (breedte x hoogte x 4 bytes, zonder mipmaps/padding) |
| tex mem Δ MB | verschil in `RENDERING_INFO_TEXTURE_MEM_USED` tussen vóór het laden en na het rusten |
| script µs | som van `_process(0.0)` van alle scripts die per frame draaien (scène + autoloads), in de CSV |
| obj/mem growth | groei van objecten en `MEMORY_STATIC` tijdens de 180 meetframes (per-frame allocaties), in de CSV |

`boot_preload` is een extra rij: wat `GameState._preload_paths()` bij het opstarten vooraf in het geheugen zet, nog vóór er
een scène is geladen. Dat blijft de hele sessie bezet.

## Beperkingen (lees dit voor je getallen vergelijkt)

- Gemeten met Godot 4.3-stable (zoals CI en de APK), `gl_compatibility`, onder `xvfb` met software-GL (Mesa llvmpipe), 4 vCPU's.
  Dat is **geen telefoon-GPU**: `frame ms`, `load ms` en `enter ms` zijn alleen onderling vergelijkbaar (zelfde machine, zelfde
  methode; ruis tussen runs ongeveer ±5% voor frame ms, ±10% voor enter ms). Draw calls, nodes, objecten en textuurgeheugen zijn
  deterministisch en dus wel absoluut bruikbaar.
- De draw-call-aantallen verschillen per engineversie (Godot 4.7 telt bv. 38 i.p.v. 64 in een gevecht); vergelijk dus alleen binnen 4.3.
- `tex ref MB` schat 4 bytes per pixel; op Android zijn dat RGBA8-textures (geen VRAM-compressie ingesteld).
- Alle WM1-kaarten staan op `encounters = false`; er is geen vijand-AI of dialoog actief tijdens het meten (alleen idle-animaties).
- Cijfers hieronder: mediaan van 5 runs.

## Resultaten (na de fixes)

| Groep | Scène | load ms | enter ms | frame ms | p95 ms | draw calls | nodes | objects | tex ref MB | tex mem Δ MB | grootste textures |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Boot | `boot_preload` | – | – | – | – | – | 40 | 2002 | 22.27 | 27.82 (totaal) | gras.png 1280x432; zand.png 1280x432; boss.png 1280x432 |
| Willowdale | `huis_wilgendal` | 0.0 | 63.7 | 3.14 | 3.59 | 30 | 29 | 2057 | 0.13 | 0.12 | oude_man_wm1_slim.png 72x128; dax_wm1.png 72x128; <GradientTexture2D> 88x88 |
| Willowdale | `wilgendal` | 0.0 | 30.9 | 4.24 | 4.70 | 41 | 72 | 2628 | 0.80 | 1.77 | grond_v8.png 1024x128; dorp_v8.png 864x16; dax_wm1.png 72x128 |
| Willowdale | `dorp_wilgendal` | 82.9 | 207.8 | 5.02 | 6.13 | 207 | 1679 | 8650 | 8.82 | 19.15 | grond_v8.png 1024x336; grond_v8_licht.png 1024x336; wilgendal_grond_tileset.png 512x640 |
| Willowdale | `wilgendal_binnen` | 60.1 | 11.3 | 3.04 | 3.42 | 30 | 22 | 2086 | 0.10 | 0.12 | dax_wm1.png 72x128; npc_wm1_slim.png 72x128; binnen_v8.png 400x16 |
| World map 1 | `wereldkaart` | 0.0 | 28.0 | 3.37 | 3.76 | 26 | 38 | 2127 | 0.20 | 0.02 | wereld_v14.png 256x144; world_warper.png 128x64; player.png 48x96 |
| First Archive | `archief_ingang` | 271.0 | 57.7 | 3.60 | 4.04 | 35 | 40 | 2385 | 0.28 | 0.70 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_v1_gang` | 0.3 | 14.4 | 3.69 | 4.08 | 34 | 44 | 2391 | 0.23 | 0.11 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_v2_trapzaal` | 0.3 | 17.7 | 3.54 | 3.93 | 33 | 36 | 2375 | 0.24 | 0.10 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_v2_leeszaal` | 0.3 | 14.0 | 3.65 | 3.96 | 31 | 38 | 2384 | 0.22 | 0.10 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_v2_kastenzaal` | 0.3 | 13.0 | 3.57 | 3.93 | 31 | 28 | 2364 | 0.21 | 0.10 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_puzzel` | 130.6 | 19.5 | 3.62 | 4.00 | 41 | 147 | 2766 | 0.22 | 0.30 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_v3_gang` | 0.3 | 12.5 | 3.48 | 3.85 | 30 | 32 | 2552 | 0.21 | 0.09 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_v3_zuilenhal` | 0.3 | 18.4 | 3.65 | 4.02 | 34 | 45 | 2575 | 0.29 | 0.12 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_v4_voorhal` | 0.3 | 12.1 | 3.43 | 3.82 | 31 | 35 | 2557 | 0.21 | 0.09 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_v4_wachtersgang` | 0.3 | 17.8 | 3.62 | 4.00 | 34 | 38 | 2563 | 0.25 | 0.10 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_bibliotheek` | 0.3 | 17.1 | 3.45 | 3.81 | 54 | 53 | 2577 | 0.24 | 0.09 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| First Archive | `archief_golemhal` | 0.3 | 16.4 | 3.44 | 3.81 | 32 | 32 | 2552 | 0.24 | 0.09 | archief_grijs_tiles.png 256x96; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| Dark Wood | `esdoorn` | 4.3 | 29.5 | 3.86 | 4.27 | 28 | 51 | 3310 | 0.80 | 2.06 | grond_v8.png 1024x144; dorp_v8.png 864x16; marit.png 72x128 |
| Dark Wood | `esdoorn_herberg` | 0.8 | 14.4 | 3.08 | 3.43 | 30 | 22 | 2536 | 0.13 | 0.12 | waard.png 72x128; dax_wm1.png 72x128; <GradientTexture2D> 88x88 |
| Dark Wood | `esdoorn_huis_noor` | 0.7 | 8.9 | 3.08 | 3.49 | 28 | 18 | 2527 | 0.10 | 0.12 | ilse.png 72x128; dax_wm1.png 72x128; binnen_v8.png 400x16 |
| Dark Wood | `woud_rand` | 0.3 | 43.4 | 3.95 | 4.34 | 40 | 55 | 3101 | 0.33 | 0.88 | woud_tiles_v9b.png 256x128; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| Dark Wood | `woud_pad` | 0.3 | 22.4 | 3.76 | 4.17 | 36 | 56 | 3107 | 0.26 | 0.10 | woud_tiles_v9b.png 256x128; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| Dark Wood | `woud_mistpoel` | 0.3 | 22.1 | 3.93 | 4.33 | 37 | 57 | 3108 | 0.30 | 0.10 | woud_tiles_v9b.png 256x128; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| Dark Wood | `woud_sporenkring` | 0.3 | 20.4 | 3.92 | 4.33 | 38 | 53 | 3093 | 0.30 | 0.10 | woud_tiles_v9b.png 256x128; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| Dark Wood | `woud_open_plek` | 0.3 | 22.0 | 4.02 | 4.41 | 37 | 54 | 3095 | 0.38 | 0.20 | woud_tiles_v9b.png 256x128; archief_grijs_bibliotheek.png 256x64; dax_wm1.png 72x128 |
| Battle | `battle_gras` | 0.0 | 35.2 | 5.93 | 6.97 | 64 | 40 | 3127 | 3.86 | 1.32 | gras.png 1280x432; dennis_rug.png 2100x210; mosslijm.png 90x94 |
| Battle | `battle_zand` | 0.1 | 19.0 | 5.88 | 6.79 | 65 | 40 | 3128 | 3.91 | 1.73 | zand.png 1280x432; dennis_rug.png 2100x210; moskonijn.png 106x110 |
| Battle | `battle_archief` | 0.1 | 18.9 | 5.94 | 7.43 | 65 | 41 | 3131 | 3.89 | 1.73 | bibliotheek.png 1280x432; dennis_rug.png 2100x210; glitchmot.png 106x96 |
| Battle | `battle_woud` | 0.0 | 18.7 | 5.80 | 6.96 | 66 | 41 | 3132 | 3.92 | 1.73 | donker_woud.png 1280x432; dennis_rug.png 2100x210; wortelgeest.png 90x90 |
| Battle | `battle_baas_golem` | 0.0 | 35.3 | 6.52 | 8.12 | 108 | 43 | 3148 | 4.70 | 2.71 | boss.png 1280x432; dennis_rug.png 2100x210; golem_boss_v2_idle.png 784x182 |
| Battle | `battle_kas` | 0.0 | 18.8 | 5.88 | 6.63 | 65 | 40 | 3139 | 3.89 | 3.84 | bibliotheek_overwoekerd.png 1280x432; dennis_rug.png 2100x210; glitchmot.png 106x96 |
| Battle | `battle_diepe_grot` | 0.0 | 21.8 | 5.81 | 6.85 | 64 | 40 | 3140 | 3.87 | 1.73 | diepe_grot.png 1280x432; dennis_rug.png 2100x210; glitchmot.png 106x96 |


## Voor en na de fixes

Voor = `main` (c55b77b) + alleen de profileermodus; na = deze PR. Mediaan van 5 afwisselend gedraaide runs.

| Scène | load ms (voor → na) | enter ms | frame ms | draw calls | objects | tex ref MB | tex mem Δ MB |
|---|---|---|---|---|---|---|---|
| `boot_preload` (tex mem totaal MB, preloaded) | – | – | – | – | – | 43.37 → 22.27 | 48.91 → 27.82 |
| `dorp_wilgendal` | 82.5 → 82.9 | 204.9 → 207.8 | 5.02 → 5.02 | 207 → 207 | 8927 → 8650 | 8.82 → 8.82 | 19.15 → 19.15 |
| `wereldkaart` | 0.0 → 0.0 | 25.0 → 28.0 | 3.31 → 3.37 | 26 → 26 | 2137 → 2127 | 0.20 → 0.20 | 0.02 → 0.02 |
| `archief_ingang` | 265.3 → 271.0 | 56.4 → 57.7 | 3.71 → 3.60 | 35 → 35 | 2395 → 2385 | 0.28 → 0.28 | 0.70 → 0.70 |
| `battle_gras` | 0.0 → 0.0 | 35.9 → 35.2 | 5.77 → 5.93 | 64 → 64 | 3137 → 3127 | 3.86 → 3.86 | 1.32 → 1.32 |
| `battle_kas` | 0.1 → 0.0 | 19.2 → 18.8 | 5.87 → 5.88 | 65 → 65 | 3148 → 3139 | 3.89 → 3.89 | 1.73 → 3.84 |

Op `boot_preload`: 43,4 → 22,3 MB aan vooraf geladen textures, en het totale textuurgeheugen na het opstarten gaat van 48,9 naar 27,8 MB
(-21,1 MB, -43%). In `battle_kas` stijgt `tex mem Δ` met 2,1 MB: dat is de kas-achtergrond die nu bij het gevecht wordt geladen in plaats van bij
het opstarten; de rest van de scènes en de frametijden veranderen niet (alle verschillen zitten binnen de ruis).
Bij `dorp_wilgendal` gaan de objecten van 8927 naar 8650 (-277, waarvan ~10 uit de lagere basislijn): de bomen delen één botsvorm.

## Wat is gefixt

1. **Gevechtsachtergronden niet allemaal bij het opstarten laden** (`scripts/game_state.gd`, `scripts/data/game_data.gd`).
   `_preload_paths()` laadde alle 16 achtergronden (16 x 2,1 MB = 33,7 MB) en hield ze de hele sessie in het geheugen, ook de
   Diepe Grot-varianten, de kas en de overwoekerde bibliotheek die in WM1 niet voorkomen. Nu staan alleen de zes vroege achtergronden
   in `GameData.BACKDROPS_BOOT` (gras, zand, boss, bibliotheek, donker woud, berggrot). De rest wordt in `prepare_battle` op de
   achtergrond aangevraagd (`load_threaded_request`) terwijl de gevechtsflits (~0,5 s) loopt, en de vorige "late" achtergrond wordt weer losgelaten,
   zodat er hooguit één extra staat. `get_resource()` wacht zo nodig op de threadlading. Er verandert niets aan wat de speler ziet
   (`--perftest` controleert per gevecht dat de achtergrond van het gevecht echt is geladen, ook voor kas en Diepe Grot).
2. **Eén gedeelde botsvorm voor de dorpsbomen** (`scripts/village/dorp_ground.gd`). Elke boom (rand van Willowdale) maakte een
   eigen `RectangleShape2D` van 16x16; nu is het één resource. -277 objecten in `dorp_wilgendal`, zelfde botsing.

## Slechtste plekken (niet gefixt, met reden)

| # | Wat | Cijfers | Waarom niet gefixt / advies |
|---|---|---|---|
| 1 | `dorp_wilgendal`: tekenwerk | 207 draw calls, 1679 nodes, ~8,6k objecten, 5,0 ms/frame (software-GL) | `--perf-hide=SomV8` haalt 111 draw calls weg: de v8-grondlaag heeft 3 atlasbronnen (`grond_v8`, `gras_licht`, `grond_v8_licht`) die per cel afwisselen, dus elke wissel breekt de batch. Opsplitsen in 3 lagen zou het oplossen maar breekt `wilgendaltest` (verwacht één laag `Ground/SomV8` met bron 0/1/2) en die test mag deze PR niet wijzigen. Advies: bij het bakken één gecombineerde atlas maken (RPG ART / Forge). |
| 2 | `dorp_wilgendal`: textuurgeheugen | 19,2 MB voor 8,8 MB aan referenties | Gemeten (experiment, niet toegepast): `TileSetAtlasSource.use_texture_padding = false` op de atlassen van het dorp geeft 12,6 MB (-6,6 MB). Niet toegepast omdat de padding naden/bleeding voorkomt bij fractionele camerastand of schaling; dat moet op een echte telefoon visueel getest worden. Zelfde patroon in `esdoorn` (2,1 MB voor 0,8 MB) en `wilgendal` (1,8 MB voor 0,8 MB). |
| 3 | Eerste bezoek aan een kaart | `archief_ingang` 271 ms load, `archief_puzzel` 130 ms, `dorp_wilgendal` 83 ms load + 208 ms enter, `wilgendal_binnen` 60 ms | Vooral GDScript-compilatie bij de eerste `load()` (`dungeon_room.gd` preload een stuk of 20 scripts). Voorladen op de achtergrond (`dorp_wilgendal` en `archief_ingang` in `_preload_paths()`) werkt, maar geeft `Caller thread can't call this function in this node (/root/Dialog)` omdat de scripts in de laadthread compileren; de oplossing (scripts in `MAIN_THREAD_SCRIPTS`) verplaatst de kosten naar de opstart. Geen duidelijke winst, wel risico: niet gedaan. |
| 4 | Touch-besturing | 22 van de 26 draw calls op `wereldkaart` (4 zonder), 22 van 30 in kleine kamers | `touch_controls.gd` tekent cirkels, bogen en tekst los (schaduw + tekst apart). Terugbrengen kan alleen door te cachen of te herontwerpen; dat raakt het uiterlijk. Op een telefoon-GPU is 22 kleine draw calls goedkoop. |
| 5 | Gevechten | 64-66 draw calls (108 bij de golem-baas), 3,9-4,7 MB referenties, `dennis_rug.png` 2100x210 (1,7 MB), achtergronden 1280x432 (2,1 MB) | Groot door de art zelf; "geen visuele wijzigingen aan art". Advies aan RPG ART: de heldensheets en achtergronden bekijken op lege ruimte / lagere resolutie. De helden `kael.png` en `orion.png` (2 x 1,7 MB) staan ook vooraf geladen; of ze in WM1 al in de party kunnen komen is een vraag voor RPG CODE. |
| 6 | Runtime `load()` van vaste paden | gecachede `load()` kost 4,6 µs, een `preload`-constante 0,02 µs; `dorp_opbouw.gd` doet ~600 zulke aanroepen = ~3 ms van 208 ms | Meetbaar nul; omzetten levert niets op. Niet gedaan. |
| 7 | Per-frame allocaties | objectgroei -8..+1 per 180 frames, `MEMORY_STATIC` +5..26 KB per 180 frames; alle `_process`-scripts samen 4-25 µs per frame (`woud_mist.gd` 6 µs, `plein_lus.gd` 8 µs, `dungeon_room.gd` 5-10 µs) | Geen lek of allocatiepiek gevonden; de scriptkosten zijn verwaarloosbaar naast de 16,7 ms van een 60 fps-frame. Niets te fixen. |

## Reproduceren van de voor/na-cijfers

`main` + alleen `scripts/tests/perf_wm1.gd` en de regel in `game_state.gd` = "voor"; deze branch = "na". Beide met
`run_suite.sh perftest --csv=...` (5x, afwisselend) en daarna `tools/perf/perf_tabel.py --voor ... --na ...`.
