# WM1 performance-audit (24 okt 2026)

Scope: speelbare **World Map 1** — veldkaarten onder `scenes/maps/` (excl. `dungeon100.tscn` in deze audit), Donker-Woud-kamers met `WoudMist`, wereldkaart-flyover, World Warper-hub (`world_warper/maps/`). Geen WM2, geen `wacht/`.

Omgeving voor metingen: Godot **4.3.stable** headless via `xvfb-run`, `--rendering-driver opengl3`, viewport **384×216** (zoals de game). Script: eenmalige probe op de agent-VM (`/tmp/wm1_perf_probe.gd`, niet in de repo): SubViewport, **180** meetframes na **30** warmup-frames, gemiddelde van `Performance.TIME_PROCESS` en `RENDER_TOTAL_*`.

## Texture-import (pixel art)

| Check | Resultaat |
|---|---|
| `textures/canvas_textures/default_texture_filter` in `project.godot` | `0` (= nearest) |
| WM1-gerelateerde `.import` (~248 paden onder `assets/sprites/som`, `assets/tilesets/som`, `world_warper/art` + textures uit `scenes/maps/*.tscn`) met `mipmaps/generate=true` | **0** |
| `compress/mode` lossy op SoM-tilesets | niet gevonden (mode 0) |

Runtime: kaartcode zet waar nodig expliciet `TEXTURE_FILTER_NEAREST` (o.a. `KaartStijl`, hub-decor, WM1-sprites). Geen import-wijzigingen nodig voor filter/mipmaps.

## Atlas / tilesets

- Veldgrond gebruikt gedeelde SoM-tilesets uit `assets/tilesets/som/` (config `gebieden.json`); atlasbronnen zijn grote PNG’s per gebied (geen per-tegel-textures in de scènes).
- WM1-hub en cutscenes gebruiken `AtlasTexture` voor animaties (bv. hanger-gloed, hub-wanderers bij opbouw) — geen per-frame atlas-allocs in `_process`.
- **TileMap-lagen** (nodes `TileMapLayer` in `.tscn`): meeste WM1-kamers **1** laag; uitzonderingen: `wilgendal.tscn` **4**, `esdoorn.tscn` **3** (grond + decor — bewuste scheiding, geen veilige merge zonder visuele risico’s).

## Draw calls / objecten (probe, statische scène zonder lopende speler)

| Scène | proc_ms_avg | draw_avg | objects_avg | prims_avg |
|---|---:|---:|---:|---:|
| `scenes/maps/wilgendal.tscn` | 5.566 → 6.233* | 41.0 | 2322.0 | 5300.0 |
| `scenes/maps/wereldkaart.tscn` | 13.080 → 12.848* | 7.0 | 935.0 | 1870.0 |
| `scenes/maps/woud_open_plek.tscn` | 5.505 → 6.257* | 42.0 | 575.0 | 1806.0 |
| `world_warper/maps/hal.tscn` | 6.009 → 6.705* | **174.0** → **108.0**† | 621.0 → 525.0† | 2108.0 → 1916.0† |

\*Twee runs op dezelfde VM (vóór en na de micro-optimalisaties in deze PR). Verschil valt binnen normale ruis van headless rendering; draw/object/primitive-tellers zijn **identiek** tussen runs.

†Hal Atrium draw-call fix (#260–#269): zelfde SubViewport-probe (30 warmup + 180 frames, Godot 4.3, 384×216); **174.0** vóór, **108.0** na (drie runs identiek).

Interpretatie (geen extra metingen):

- **Hal** had veel draw calls door Dauwpixel-Labels op de hub-vlakken (vooral “Deep Learning Simulation”, ~1 draw per glyph). Opgelost door die tekst één keer naar een nearest `ImageTexture` te bakken (`world_warper/art/baked_label.gd`, `hub_boot.gd`); headless SHA-256 van drie camerastanden ongewijzigd (`tools/perf/hal_atrium_shots.gd`).
- **Wilgendal** heeft veel “objects” door tile layers + y-sort props; verwacht voor een grote 1.4x-kaart.

## `_process` / allocaties

Gezocht naar zware patronen in WM1-scripts (`get_node*` elke frame, `.new()` in `_process`, groep-scans). Opvallend maar **niet** stil aangepast (risico of ontwerp):

- `world_warper/art/flyover.gd`: elke actieve frame nog `Color(...)` en `Line2D`-updates voor burst-trail (zichtbaarheid).
- `scripts/village/plein_lus.gd`: `PhysicsPointQueryParameters2D.new()` bij start van een loopstap (niet elke frame).
- `world_warper/kamers/echo_kisten.gd`: bij pulse modulate per gevuld vlak (act 6); nu `_process` uit wanneer niet nodig (zie fixes).

## Veilige fixes in deze PR

| Bestand | Wijziging |
|---|---|
| `scripts/map.gd` | `TouchControls/Control` één keer cachen; `_process`/`_set_touch_visible` geen `get_node` meer per frame. |
| `scripts/dungeon/woud_mist.gd` | Spelerreferentie cachen na deferred lantern-setup (Donker Woud mist-kamers). |
| `world_warper/art/flyover.gd` | Touch + speler cachen; hergebruik `Array[Rect2]` voor knop-avoid i.p.v. nieuwe array per frame op wereldkaart. |
| `world_warper/wander/wanderers.gd` | Vaste hal-naambordjes (`hub_naambord`) één keer per `refresh()`; geen `get_nodes_in_group` meer elke frame. |
| `world_warper/kamers/echo_kisten.gd` | `set_process(_pulse)` in `pas_toe()` — geen lege `_process` buiten act 6-pulse. |

Visueel gedrag ongewijzigd; geen asset- of tileset-wijzigingen.

## Tests gedraaid

| suite | Resultaat |
|---|---|
| `--wm1bugtest` | 14 PASS, 0 FAIL, ~5 s |
| `world_warper/tests/run.gd` | `RESULT OK` |

## Niet gedaan (bewust)

- WM2/WM3/wacht-content.
- TileMap-layer merge op Wilgendal/Esdoorn.
- CI/workflows of bestaande testsuites wijzigen.
- Samsung S25 on-device profiling (geen hardware in CI/VM).
