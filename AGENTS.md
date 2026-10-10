# AGENTS.md — SAPIENTIA (voor Cursor cloud agents)

## Project
SAPIENTIA is een mobiele JRPG in **Godot 4.3-stable** (GDScript), renderer **gl_compatibility**,
export **Android arm64**, basisresolutie **384x216** (pixel-art, opgeschaald). Alle tekst in de
game is **Nederlands**. Eigenaar: **Dennis** (werkt vanaf zijn telefoon).

Rollen:
- **RPG Forge** — hoofd-developer/integrator: beheert `main`, merget PR's, bouwt de APK's, doet releases en versienummers.
- **RPG ART** — de enige die pixel-art maakt (definitieve art).
- **RPG CODE** — gameplay-bot.
- **Cursor agents (jij)** — losse taken uit GitHub-issues met label `cursor-agent`.

Zie ook `docs/WORKFLOW.md` (de flow, in het Nederlands) en `README.md`.

## Harde regels (niet onderhandelbaar)
1. **Nooit** bestanden aanpassen, verplaatsen of verwijderen die in `tools/handwerk.txt` staan (handgetekende art).
2. **Nooit** definitieve art tekenen. Alleen placeholders, duidelijk als placeholder herkenbaar, en
   registreer ze in het placeholder-bestand (`tools/placeholders_v17.txt`, of het nieuwste `tools/placeholders_*.txt`).
   Zet in je PR onder "Nodig van RPG ART" welke echte art er moet komen (naam + maat).
3. **Alle tekst die de speler ziet is Nederlands** (dialoog, menu's, items, foutmeldingen in UI).
4. Verhaal/lore volgt **`docs/lore/CANON.md`**; dat gaat boven de andere lore-bestanden. Twijfel → vraag in de PR.
5. **Nooit secrets committen**: geen keystores (`*.keystore`, `*.jks`), wachtwoorden, tokens, `.env`, APK/AAB-bestanden.
6. **Nooit** de signing-velden in `export_presets.cfg` aanraken (keystore/user/password). Liefst dat bestand helemaal niet.
7. **Geen versienummers bumpen** (`project.godot`, `export_presets.cfg`, README). Dat doet RPG Forge bij een release.
8. **Eén taak per branch**: `cursor/<korte-taak>` (bv. `cursor/inktwurm-ai`). Kleine, gerichte PR's naar `main`,
   met het PR-template (`.github/pull_request_template.md`) volledig ingevuld.
9. **Elk nieuw systeem krijgt tests** in de bestaande headless test-runner, en **alle bestaande suites moeten slagen** (CI).
10. Niet mergen: RPG Forge reviewt en merget.

## Codestijl
- Statische types overal (`var x: int`, `func f(a: String) -> void`), `class_name` waar zinvol.
- **Signals boven harde koppeling**; geen `get_node("../../..")`-ketens tussen systemen.
- **Data-gedreven**: content (monsters, items, kamers, codex, verhaal) in `scripts/data/*.gd` / JSON, niet hardcoded in logica.
- **Mobile-first**: touch-bediening (`scripts/touch_controls.gd`), 384x216, lage kosten per frame.
- Geen zware shaders (gl_compatibility op goedkope Android-telefoons); bestaande shaders in `assets/shaders/`.
- `preload()` voor vaste resources; geen `load()` in `_process`.
- Commentaar mag Nederlands zijn (zoals de bestaande code).

## Tests draaien (headless)
Testers worden gestart via user-args na `--`; `scripts/game_state.gd` (`_ready`) kiest de tester.
Elke suite schrijft regels `PASS ...` / `FAIL ...` en eindigt met `RESULT OK (...)`; exitcode 0 = goed.
De suites hebben een echte renderer nodig (gl_compatibility → `opengl3`), dus op Linux zonder scherm via `xvfb-run`.

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
# 1x importeren (verse checkout, maakt .godot/)
$GODOT --headless --path . --import
# één suite (exact wat CI doet):
GODOT=$GODOT .github/scripts/run_suite.sh codextest
# of met de hand:
XDG_DATA_HOME=/tmp/xdg_codex xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --codextest --shots=/tmp/shots
```

Suites (v0.18, aantallen PASS ter referentie):

| suite | script | PASS |
|---|---|---|
| `--autotest` | `scripts/debug_autotest.gd` | 445 |
| `--menutest` | `scripts/debug_menutest.gd` | 225 |
| `--puzzletest` | `scripts/tests/puzzle_tests.gd` | 152 |
| `--dungeontest` | `scripts/tests/dungeon_tests.gd` | 185 |
| `--golemtest` | `scripts/tests/golem_tests.gd` | 62 |
| `--archieftest` | `scripts/tests/archief_tests.gd` | 91 |
| `--kerntest` | `scripts/tests/kern_tests.gd` | 72 |
| `--kernkrachttest` | `scripts/tests/kernkracht_tests.gd` | 102 |
| `--woudtest` | `scripts/tests/woud_tests.gd` | 90 |
| `--codextest` | `scripts/tests/codex_tests.gd` | 90 |
| `--checkpointtest` | `scripts/tests/checkpoint_tests.gd` | 65 |
| `--dungeon100gentest` | `scripts/tests/dungeon100_generator_tests.gd` | 57 |
| `--dungeon100schaaltest` | `scripts/tests/dungeon100_schaal_tests.gd` | 78 |
| `--dungeon100regelstest` | `scripts/tests/dungeon100_tests.gd` | 74 |
| `--dungeon100integratietest` | `scripts/tests/dungeon100_integratie_tests.gd` | 41 |
| `--dungeon100blauwtest` | `scripts/tests/dungeon100_blauw_tests.gd` | (na deze taak) |

Alle suites lokaal: `for s in autotest menutest puzzletest dungeontest golemtest archieftest kerntest kernkrachttest woudtest codextest checkpointtest dungeon100gentest dungeon100schaaltest dungeon100regelstest dungeon100integratietest dungeon100blauwtest; do .github/scripts/run_suite.sh $s; done`
(samen ~12 min; CI draait ze parallel). Een eigen `XDG_DATA_HOME` per suite houdt `user://` (saves/instellingen) gescheiden.

**Nieuwe suite toevoegen:** script in `scripts/tests/<naam>_tests.gd` (zelfde PASS/FAIL/RESULT-format,
`get_tree().quit(1 if failures else 0)`), een regel in de lijst in `scripts/game_state.gd` `_ready()`,
en de suite in de matrix van `.github/workflows/tests.yml` (tijdelijk `.github/ci/tests.yml`, zie `.github/ci/README.md`).

## Kaart van de code
- `project.godot` — autoloads: `GameState`, `Transition`, `Dialog`, `Story`, `Crt`, `Settings`, `AudioManager`. Hoofdscène `scenes/ui/title.tscn`.
- `scripts/game_state.gd` — party, inventaris, saves, test-dispatch. `scripts/story.gd` + `scripts/data/story_data.gd` — verhaalvlaggen/dialoog.
- `scripts/data/` — **alle content-data**: `game_data.gd` (helden, monsters, items, skills), `dungeon100_scaling.gd`, `dungeon100_blue.gd` (Blauwe Kisten / Mimic / Warp), `codex_data.gd` (Codex: verzamelbare/vangbare wezens),
  `book_data.gd`, `kern_data.gd`, `dungeon_rooms.gd`, `puzzle_rooms.gd`, `woud_rooms.gd`, `story_data.gd`.
- `scripts/battle/` — gevechten (`battle.gd`, menu, helden, baas-kern, `codex_battle.gd`/`codex_ally.gd` voor de Codex).
- `scripts/ui/` — menu's, titelscherm, Codex-scherm (`codex_screen.gd`), bestiarium, stijl (`ui_style.gd`, `menu_colors.gd`).
- `scripts/dungeon/`, `scripts/puzzle/`, `scripts/kern/` — kerkers, puzzel-elementen, kernkrachten.
- `scripts/tests/` — testsuites; `scripts/debug_autotest.gd`, `scripts/debug_menutest.gd` — de twee oudste suites.
- `scenes/` — .tscn-scènes. `assets/` — sprites, tiles, fonts, ui, shaders, audio. `art/` — art van RPG ART.
- `tools/` — Python art-generators (placeholders), `handwerk.txt`, `placeholders_*.txt`.
- `docs/` — ontwerp, handoffs, `docs/lore/CANON.md`, `docs/ARTSTYLE.md`.

**Audio:** er is nog géén audio. `scripts/audio_manager.gd` + `assets/audio/audio_manifest.json` staan klaar;
`assets/audio/bgm|sfx/` bevatten alleen een README. Code moet blijven werken zonder geluidsbestanden.
