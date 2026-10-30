# Godot-upgrade haalbaarheidsstudie — 16 KB Android-pagina's

**Datum:** 24 oktober 2026  
**Auteur:** Cursor cloud agent (docs-only)  
**Doel:** Dennis en RPG Forge kunnen beslissen of SAPIENTIA van **Godot 4.3-stable** naar een nieuwere engine moet voor **Google Play 16 KB ELF-uitlijning** (apps met `targetSdk` 35+).  
**Scope:** alleen dit document; geen wijzigingen aan `project.godot`, CI, code of export-presets.

## Samenvatting en advies

| Vraag | Antwoord |
|--------|----------|
| **Minimale officiële Godot-versie met 16 KB-templates?** | **Godot 4.5-stable** (en alle latere 4.5.x / 4.6.x onderhoudsreleases). |
| **Blijft 4.3-stable Play-conform voor targetSdk 35+?** | **Nee** — standaard export-templates hebben `libgodot_android.so` met **4 KB** (`Align 0x1000`), zie [meting](#elf-meting) en [Sapientia PR #236](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/236). |
| **Code-impact SAPIENTIA (4.3 → 4.5.2)?** | **Laag** in deze trial: 10 headless suites, **0 FAIL**, waaronder `autotest` (810 PASS). Zie [proefrun](#proefrun-godot-452). |
| **Aanbeveling** | **Upgrade naar Godot 4.5.2-stable** (of nieuwste 4.5.x patch) voor **release-AAB/APK**; houd `gl_compatibility` en arm64-only export. Plan als **aparte PR** na deze beslissing: CI, `config/features`, editor-reimport, echte AAB-check op device. |

**Niet aanbevolen** als primaire route: zelf 4.3-templates herbouwen met alleen een linkerflag — onderhoudslast en divergentie van upstream; alleen overwogen als upgrade tijdelijk geblokkeerd is.

---

## Context: Play-beleid en Sapientia PR #236

Google Play vereist dat native bibliotheken op **64-bit** apparaten **16 KB-geheugenpagina's** ondersteunen wanneer de app **Android 15 (API 35) of hoger** target. Vanaf **1 februari 2027** blokkeert Play updates die dit niet ondersteunen. Achtergrond:

- [Support 16 KB page sizes (Android Developers)](https://developer.android.com/guide/practices/page-sizes)
- [Prepare Play apps for devices with 16 KB page size (Android Developers Blog, mei 2025)](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html)

In Sapientia markeert **[PR #236](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/236)** (Play Store-voorbereiding fase 8) het **belangrijkste release-risico**: officiële **Godot 4.3**-templates leveren **4 KB-uitlijning**; de PR adviseert release-builds met **Godot 4.5+** en laat de engine-beslissing bij Dennis/RPG Forge.

SAPIENTIA is **GDScript-only** (geen C#/Mono), `renderer/rendering_method.mobile="gl_compatibility"`, CI en APK-workflows staan op **4.3-stable** (`.github/workflows/tests.yml`, `build-apk.yml`).

---

## Minimale Godot-versie met 16 KB Android-templates

### Engine-fix (bron van waarheid)

| Bron | Wat het zegt |
|------|----------------|
| [godot#106313](https://github.com/godotengine/godot/issues/106313) | Play-waarschuwing: Godot werkt aan 16 KB-support; milestone **4.5**. |
| [godot PR #106358](https://github.com/godotengine/godot/pull/106358) | **NDK r28b** (`28.1.13356709`); 16 KB via NDK-defaults. Labels **`cherrypick:4.3`** en **`cherrypick:4.4`**. |
| [Godot 4.5 CHANGELOG](https://github.com/godotengine/godot/blob/4.5-stable/CHANGELOG.md) | Vermeldt expliciet: *"Android: Add support for 16 KB page sizes, update to NDK r28b ([GH-106358])"*. |
| [Godot 4.4.1 CHANGELOG](https://github.com/godotengine/godot/blob/4.4.1-stable/CHANGELOG.md) | **Geen** vermelding van 16 KB / GH-106358 (alleen eerdere NDK r27c in 4.5-changelog context). |

**Conclusie:** de eerste **stabiele** release in de officiële changelog met 16 KB Android-templates is **4.5-stable** (september 2025). Praktisch: gebruik **4.5.2-stable** of de nieuwste **4.5.x** patch op het moment van migratie.

### Cherry-pick naar 4.3 / 4.4

PR #106358 is **gelabeld** voor cherry-pick naar 4.3 en 4.4, maar op [GitHub Releases](https://github.com/godotengine/godot/releases) staat **geen** `4.3.1` … `4.3.7` — alleen **`4.3-stable` (augustus 2024)**. Zonder zelfgebouwde templates blijft **4.3-stable downloadbaar 4 KB**.

**Alternatief (niet getest in deze studie):** custom Android export templates vanaf 4.3-bron met `-Wl,-z,max-page-size=16384` in `platform/android/detect.py` (zie discussie in [godot#110852](https://github.com/godotengine/godot/issues/110852)). Dat lost alleen **libgodot** op; eventuele **andere** `.so` in de exportketen moeten apart 16 KB zijn.

### C# / Mono (niet van toepassing op SAPIENTIA)

Voor C#-projecten vereist Godot 4.5+ op Android **.NET 9** voor 16 KB-aligned runtime ([PR #110263](https://github.com/godotengine/godot/pull/110263), [Upgrading to Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html)). SAPIENTIA gebruikt geen Mono-export.

### ELF-meting

Uit de officiële **export_templates** (`android_release.apk`, `lib/arm64-v8a/libgodot_android.so`), `readelf -l`:

| Template | LOAD-segment `Align` |
|----------|----------------------|
| Godot **4.3-stable** | **`0x1000`** (4 KB) |
| Godot **4.5.2-stable** | **`0x4000`** (16 KB) |

Dit komt overeen met de bevinding in PR #236 (`Align 0x1000` op 4.3).

**Na export** moet RPG Forge nog steeds de **gebouwde AAB/APK** controleren (eigen plugins, Gradle-native deps, `check_elf_alignment.sh` uit de Android-docs) — alleen een nieuwe Godot-versie is niet voldoende als er extra `.so` in de app zitten.

---

## Breaking changes 4.3 → 4.5.x die SAPIENTIA raken

Officiële migratiegidsen:

- [Upgrading from Godot 4.3 to Godot 4.4](https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.4.html)
- [Upgrading from Godot 4.4 to Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html)

Hieronder: **concrete bestanden in deze repo** die relevant zijn (grep op `main`, oktober 2026). Geen volledige engine-changelog.

### 1. `@export_file` en `uid://`-paden (4.4 gedrag)

Vanaf 4.4 kan de editor bij `@export_file` **`uid://`** opslaan i.p.v. `res://` ([GH-97912](https://github.com/godotengine/godot/pull/97912)). In 4.5 bestaat `@export_file_path` om `res://` te behouden.

**Bestanden met `@export_file`:**

| Bestand | Export-veld |
|---------|-------------|
| `scripts/door.gd` | `target_map` |
| `scripts/map_exit.gd` | `target_map` |
| `scripts/village/v8_grond.gd` | `json_pad`, `png_pad` |
| `world_warper/kamers/deur.gd` | `destination` |
| `world_warper/maps/locked_exit.gd` | `destination` |

**Huidige repo:** geen `uid://` in `.tscn`/`.gd` (grep). **Risico:** na eerste bewerking in 4.5-inspector kunnen scènes gemengde paden krijgen; scripts die `res://` vergelijken moeten dat aankunnen of velden migreren.

### 2. Verouderde signal-`connect` met string (werkt nog, deprecation-radar)

| Bestand | Regel (indicatief) |
|---------|-------------------|
| `scripts/dungeon/dungeon100_room.gd` | `player.connect("stepped", _on_val_stap)` |
| `world_warper/flow/hub_boot.gd` | `_warp.connect("warp_requested", …)`, `_hanger.connect("hanger_activated", …)`, `_hanger.connect("threat_finished", …)` |

Aanbevolen bij upgrade-PR: omzetten naar `connect("stepped", _on_val_stap)` → Callable-stijl `stepped.connect(_on_val_stap)` (rest van de codebase doet dit al).

### 3. `TileMapLayer` (groot oppervlak, beperkt API-risico)

Het project is al gemigreerd naar **`TileMapLayer`** (niet legacy `TileMap` als hoofdmodel), o.a.:

- `scripts/core/atlas_zuinig.gd` (ondersteunt `TileMapLayer` en legacy `TileMap`)
- Tientallen `scenes/maps/*.tscn`, `world_warper/**/*.tscn`, `scripts/dungeon/dungeon_room.gd`, `scripts/map.gd`, `tools/build_maps.gd`, tests (`wilgendal_tests.gd`, `dungeon_tests.gd`, …)

**4.5 gedrag:** standaard **physics chunking** op `TileMapLayer`; `get_coords_for_body_rid()` kan afwijken t.o.v. 4.4 ([4.5 upgrade guide](https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html#tilemaplayer)). **Repo:** geen gebruik van `get_coords_for_body_rid` / `physics_quadrant_size` in GDScript (grep). Risico voor SAPIENTIA: **laag**, tenzij toekomstige physics op tegels zonder test.

### 4. `FileAccess` (breed gebruik, GDScript-compatibel)

4.4 wijzigt `store_*`-methoden: return type `void` → `bool` (GDScript **compatibel**).

**Bestanden met `FileAccess` (selectie — tests + runtime):**

`scripts/game_state.gd`, `scripts/settings.gd`, `scripts/audio_manager.gd`, `scripts/core/sessie_log.gd`, `scripts/debug_autotest.gd`, `scripts/debug_menutest.gd`, `scripts/data/kaart_stijl.gd`, `scripts/data/music_tracks.gd`, `scripts/data/playtest_gebieden.gd`, `scripts/data/quest_data.gd`, `scripts/data/wilgendal_dorp.gd`, `scripts/village/dorp_ground.gd`, `scripts/village/dorp_opbouw.gd`, `scripts/village/v8_grond.gd`, `scripts/ui/hero_portrait.gd`, en **de meeste** `scripts/tests/*_tests.gd` / autotest-scripts.

Geen actie vereist tenzij C# wordt toegevoegd.

### 5. Android-sensoren (4.4)

Sensor-events staan **standaard uit** ([GH-94799](https://github.com/godotengine/godot/pull/94799)). SAPIENTIA gebruikt geen accelerometer/gyro in code (alleen oriëntatie-constant in `scripts/tests/lifecycle_tests.gd`). **Risico: laag.**

### 6. Multiplayer / netcode

ENet/LAN/relay: `scripts/net/lan_lobby.gd`, `scripts/net/action_coop_session.gd`, `scripts/net/relay_peer.gd`, `scripts/coop/action_sandbox_scene.gd`, tests `net_tests.gd`, `net_sync_tests.gd`, `coop_*`, `relay_tests.gd`. Geen `get_rpc_config` / `@rpc` in `scripts/` (grep). **4.5** hernoemt `get_rpc_config` → `get_node_rpc_config` (niet gebruikt hier).

### 7. Rendering / shaders

- `project.godot`: `gl_compatibility` op mobiel — blijft ondersteund in 4.5.
- Canvas-shaders: `assets/shaders/glitch.gdshader`, `assets/shaders/scanlines.gdshader` — standaard `canvas_item`; geen VisualShader-breaking changes in gebruik.

### 8. Configuratie (bij echte upgrade-PR, niet in deze studie)

| Item | Huidige waarde | Actie bij upgrade |
|------|----------------|-------------------|
| `project.godot` → `config/features` | `"4.3", "Mobile"` | Naar `"4.5"` (of editor-suggestie) |
| CI `GODOT_VERSION` | `4.3-stable` | `4.5.2-stable` (of nieuwste 4.5.x) |
| Export-templates pad | `4.3.stable` | `4.5.2.stable` |
| JDK / Android SDK | CI: JDK 17, SDK 34/36 in workflows | Volgen Godot 4.5 export-doc (meestal **JDK 17**, recentere build-tools) |

### 9. Niet gebruikt in repo (breaking changes genegeerd)

GraphEdit `frame_rect_changed`, CSG/Manifold, OpenXR-editorklassen, RichTextLabel `add_image`-signaturen, `JSONRPC.set_scope`, `Resource.duplicate(true)`-semantiek — geen matches in gameplay-code.

---

## Proefrun Godot 4.5.2

**Omgeving:** Cursor cloud VM, Linux, `xvfb-run` + Mesa (zelfde patroon als `.github/scripts/run_suite.sh`).  
**Engine:** `Godot_v4.5.2-stable_linux.x86_64` (download van [godot releases](https://github.com/godotengine/godot/releases/tag/4.5.2-stable)).  
**Project:** `main` checkout; **één** `--import` met 4.5.2 (wijzigingen aan `.import` / `.godot` **niet** gecommit).  
**Datum run:** 24 oktober 2026.

| Suite | PASS | FAIL | Opmerking |
|-------|------|------|-----------|
| `echotest` | 12 | 0 | |
| `wm1bugtest` | 14 | 0 | |
| `menutest` | 249 | 0 | |
| `relaytest` | 90 | 0 | Node relay lokaal |
| `checkpointtest` | 102 | 0 | AGENTS.md noemt 65; suite gegroeid |
| `koopmantest` | 103 | 0 | AGENTS.md noemt 83 |
| `codextest` | 157 | 0 | AGENTS.md noemt 90 |
| `puzzletest` | 156 | 0 | AGENTS.md noemt 152 |
| `dungeontest` | 203 | 0 | AGENTS.md noemt 185 |
| `autotest` | **810** | **0** | ~370 s; AGENTS.md noemt 447 |

**Niet gedraaid** in deze studie (tijd): volledige CI-matrix (~30+ suites), echte **Android AAB**-export, S25-hardware, `wm1playthroughtest`, `actorsfxtest`, alle dungeon100-suites.

**Interpretatie:** geen regressies in deze steekproef; een volledige upgrade-PR moet nog **alle** matrix-suites en een **ondertekende AAB** met ELF-check laten slagen.

---

## Risico's

| Risico | Ernst | Mitigatie |
|--------|-------|-----------|
| Play weigert update door 4 KB `libgodot` op 4.3 | **Hoog** (release blocker) | Upgrade export naar **4.5.2+** of custom templates |
| Ongeziene rendering/touch op Samsung/Adreno met 4.5 + `gl_compatibility` | **Medium** | S25 smoke-test na upgrade; vergelijk met 4.3 APK |
| Editor re-import wijzigt `.import` / binary `.ctex` | **Medium** | Dedicated upgrade-PR; RPG Forge reviewt diff; geen handwerk in `tools/handwerk.txt` |
| `@export_file` → `uid://` in scènes | **Laag–medium** | `@export_file_path` of script-migratie; grep op `uid://` na editor-pass |
| CI-tijd / agent-cache | **Laag** | Godot-binary cache in Actions aanpassen |
| Team gebruikt ook **Godot 4.7.2** voor web-export (`.github/ci/README.md`) | **Organisatorisch** | Twee engineversies documenteren: **4.5.x = Android release**, **4.7.x = web** tot geconsolideerd |

---

## Inschatting inspanning (technisch, geen kalender)

| Werkpakket | Inhoud |
|------------|--------|
| **Besluit + voorbereiding** | Dennis akkoord; RPG Forge kiest exacte patch (4.5.2 vs nieuwste 4.5.x). |
| **Engine/CI PR** | `tests.yml`, `build-apk.yml`, `build-web.yml` (indien gewenst), `run_suite.sh`-commentaar, AGENTS.md; Godot + templates download in CI. |
| **Project openen** | 4.5 editor import; `config/features`; eventueel `connect`-strings opschonen; controle `@export_file`-scènes. |
| **Verificatie** | Volledige suite-matrix lokaal/CI; `build_aab.sh` / Play-preset; ELF 16 KB op output; 14-dagen closed testing op Play indien nodig. |
| **Documentatie** | README/WM1-checklist engine-versie; PR #236-follow-up afvinken. |

**Code-impact inschatting:** **klein** (proefrun 0 FAIL). **Proces-impact:** **middel** (CI, export, devices, import-diff).

---

## Aanbevolen migratieplan (stappen)

1. **Besluit** — Dennis/RPG Forge: target **Godot 4.5.2-stable** (of laatste 4.5.x) voor **Android release builds**; 4.3 alleen nog voor hotfix indien upgrade vertraagd (met acceptatie Play-risico).
2. **Issue/branch** — `cursor/godot-45-upgrade` (één logische PR, niet mengen met gameplay).
3. **CI eerst** — Godot-binary + export-templates 4.5.2; alle matrix-suites groen op de branch.
4. **Projectmetadata** — `config/features`, eventueel minimale GDScript-cleanups (`connect` strings, `@export_file_path` waar nodig).
5. **Re-import** — volledige import in 4.5; review `git diff` op `.import` / assets (geen secrets, geen `.uid` commit indien policy dat verbiedt).
6. **Android** — release-AAB met bestaande presets; `readelf` / Play pre-launch / `check_elf_alignment.sh`; test op 16 KB-emulator of Pixel met developer-optie ([Android-docs](https://developer.android.com/guide/practices/page-sizes#test)).
7. **Device QA** — WM1 smoke (boot, gevecht, save/load, co-op indien release-scope); vergelijk frametijd met `docs/perf/`.
8. **Merge** — RPG Forge; tag/release pas bij versie-bump (buiten agent-scope).
9. **Optioneel later** — evaluatie **4.6/4.7** voor feature-pariteit met web-build; niet vereist voor 16 KB (4.5.2 heeft 16 KB al).

---

## Referenties

- Sapientia: [PR #236 — Play Store-voorbereiding](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/236)
- Godot: [Issue #106313](https://github.com/godotengine/godot/issues/106313), [PR #106358](https://github.com/godotengine/godot/pull/106358), [4.5 release notes](https://godotengine.org/releases/4.5/)
- Android: [16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
- Intern: `AGENTS.md` (test suites), `.github/workflows/tests.yml`, `docs/release/WM1_RELEASE_CHECKLIST.md`
