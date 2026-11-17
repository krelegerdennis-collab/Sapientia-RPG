# AGENTS.md — SAPIENTIA (voor Cursor cloud agents)

## Project
SAPIENTIA is een mobiele JRPG in **Godot 4.3-stable** (GDScript), renderer **gl_compatibility**,
export **Android arm64**, basisresolutie **384x216** (pixel-art, opgeschaald). Alle tekst in de
game is **Engels** (sinds v0.21, besluit Dennis); docs, commentaar en commits blijven Nederlands. Eigenaar: **Dennis** (werkt vanaf zijn telefoon).

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
3. **Alle tekst die de speler ziet is Engels** (dialoog, menu's, items, foutmeldingen in UI). Docs (`docs/`, AGENTS.md, PR-teksten) en code-commentaar blijven Nederlands. Identifiers/keys niet hernoemen.
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

Suites (aantallen PASS ter referentie uit v0.18; `–` = nog geen referentie, de baseline volgt na de freeze, zie RC-audit F1.5).
De tabel volgt de matrix in `.github/workflows/tests.yml`; `--relaytest` draait daar als eigen job.

| suite | script | PASS |
|---|---|---|
| `--autotest` | `scripts/debug_autotest.gd` | 447 |
| `--menutest` | `scripts/debug_menutest.gd` | 225 |
| `--puzzletest` | `scripts/tests/puzzle_tests.gd` | 152 |
| `--dungeontest` | `scripts/tests/dungeon_tests.gd` | 185 |
| `--golemtest` | `scripts/tests/golem_tests.gd` | 62 |
| `--archieftest` | `scripts/tests/archief_tests.gd` | 91 |
| `--kerntest` | `scripts/tests/kern_tests.gd` | 72 |
| `--kernkrachttest` | `scripts/tests/kernkracht_tests.gd` | 102 |
| `--woudtest` | `scripts/tests/woud_tests.gd` | 91 |
| `--woud16test` | `scripts/tests/woud16_tests.gd` | 8 |
| `--codextest` | `scripts/tests/codex_tests.gd` | 90 |
| `--checkpointtest` | `scripts/tests/checkpoint_tests.gd` | 65 |
| `--dungeon100gentest` | `scripts/tests/dungeon100_generator_tests.gd` | 58 |

| `--dungeon100schaaltest` | `scripts/tests/dungeon100_schaal_tests.gd` | 78 |
| `--dungeon100regelstest` | `scripts/tests/dungeon100_tests.gd` | 72 |
| `--dungeon100integratietest` | `scripts/tests/dungeon100_integratie_tests.gd` | 41 |
| `--dungeon100blauwtest` | `scripts/tests/dungeon100_blauw_tests.gd` | 38 |
| `--actorsfxtest` | `scripts/tests/actor_sfx_tests.gd` | 199 |
| `--koopmantest` | `scripts/tests/koopman_tests.gd` | 83 |
| `--tutorialtest` | `scripts/tests/tutorial_tests.gd` | 52 |
| `--questtest` | `scripts/tests/quest_tests.gd` | 63 |
| `--echotest` | `scripts/tests/echo_tests.gd` | 12 |
| `--battlesimtest` | `scripts/tests/battlesim_tests.gd` | 57 |
| `--berggrotdextest` | `scripts/tests/berggrot_dex_tests.gd` | 91 |
| `--savehardeningtest` | `scripts/tests/save_hardening_tests.gd` | 156 |
| `--savestresstest` | `scripts/tests/save_stress_tests.gd` | 135 |
| `--saverobusttest` | `scripts/tests/save_robust_tests.gd` | (zie suite) |
| `--relaytest` | `scripts/tests/relay_tests.gd` | 89 |
| `--testmodustest` | `scripts/tests/testmodus_tests.gd` | 9 |
| `--wm1bugtest` | `scripts/tests/wm1_bugjacht_tests.gd` | 14 |
| `--wm1frametest` | `scripts/tests/wm1_frametime_tests.gd` | 57 |
| `--wm1budgettest` | `scripts/tests/wm1_budget_tests.gd` | 286 |
| `--wm1openbugtest` | `scripts/tests/wm1_bugjacht_open_tests.gd` | 24 |
| `--aabtest` | `scripts/tests/aab_tests.gd` | 84 |
| `--perfprobetest` | `scripts/tests/perf_probe_tests.gd` | 62 |
| `--statemachinetest` | `scripts/tests/state_machine_tests.gd` | 75 |
| `--coopguestsavetest` | `scripts/tests/coop_guest_save_tests.gd` | 18 |
| `--combatrngtest` | `scripts/tests/combat_rng_tests.gd` | 11 |
| `--combatsimtest` | `scripts/tests/combat_sim_tests.gd` | 17 |
| `--demofixtest` | `scripts/tests/demofix_tests.gd` | 23 |
| `--kasdeurtest` | `scripts/tests/kas_deur_tests.gd` | 8 |
| `--zonetest` | `scripts/tests/zone_tests.gd` | 34 |
| `--telegraphcooptest` | `scripts/tests/telegraph_coop_sync_tests.gd` | 12 |
| `--uxtest` | `scripts/tests/ux_tests.gd` | 121 |
| `--uipolishtest` | `scripts/tests/ui_polish_tests.gd` | 753 |
| `--uxpolishtest` | `scripts/tests/ux_polish_autotest.gd` | 26 |
| `--sessiefixtest` | `scripts/tests/sessiefix_tests.gd` | 30 |
| `--wm1releasetest` | `scripts/tests/wm1_release_tests.gd` | 102 |
| `--rcchecktest` | `scripts/tests/rc_check_tests.gd` | 97 |
| `--androidbacktest` | `scripts/tests/android_back_tests.gd` | – |
| `--archief2test` | `scripts/tests/archief2_tests.gd` | – |
| `--arenatest` | `scripts/tests/arena_tests.gd` | – |
| `--arenawavesfollowuptest` | `scripts/tests/arena_waves_followup_tests.gd` | – |
| `--arenawavestest` | `scripts/tests/arena_waves_tests.gd` | – |
| `--balansarchief1test` | `scripts/tests/balans_archief1_tests.gd` | – |
| `--battlesimenemytest` | `scripts/tests/battlesim_enemy_tests.gd` | – |
| `--berggrottest` | `scripts/tests/berggrot_tests.gd` | – |
| `--bookpointawaittest` | `scripts/tests/book_point_await_tests.gd` | – |
| `--bossphasetest` | `scripts/tests/boss_phase_tests.gd` | – |
| `--bossrespawntest` | `scripts/tests/boss_respawn_tests.gd` | – |
| `--castjointest` | `scripts/tests/cast_join_tests.gd` | – |
| `--catalogustest` | `scripts/tests/catalogus_tests.gd` | – |
| `--chainfeeltest` | `scripts/tests/chain_feel_tests.gd` | – |
| `--chaintest` | `scripts/tests/chain_tests.gd` | – |
| `--chargetest` | `scripts/tests/charge_tests.gd` | – |
| `--combatbugstest` | `scripts/tests/combat_bugs_tests.gd` | – |
| `--coope2etest` | `scripts/tests/coop_e2e_tests.gd` | – |
| `--coophosttest` | `scripts/tests/coop_host_tests.gd` | – |
| `--cutscenetest` | `scripts/tests/worldmap_cutscene_tests.gd` | – |
| `--dodgetest` | `scripts/tests/dodge_tests.gd` | – |
| `--driftbgtest` | `scripts/tests/drift_bg_tests.gd` | – |
| `--dungeon100rustpunttest` | `scripts/tests/dungeon100_rustpunt_tests.gd` | – |
| `--f6uxtest` | `scripts/tests/f6_ux_tests.gd` | – |
| `--f6uxtest2` | `scripts/tests/f6_ux2_tests.gd` | – |
| `--formuletest` | `scripts/tests/formule_tests.gd` | – |
| `--fusietest` | `scripts/tests/fusie_tests.gd` | – |
| `--gamefeelfase1test` | `scripts/tests/gamefeel_fase1_tests.gd` | – |
| `--gamefeelfase2test` | `scripts/tests/gamefeel_fase2_tests.gd` | – |
| `--gamefeeltest` | `scripts/tests/gamefeel_tests.gd` | – |
| `--gategaptest` | `scripts/tests/gate_gap_tests.gd` | – |
| `--golemactionsimtest` | `scripts/tests/golem_actionsim_tests.gd` | – |
| `--golemactiontest` | `scripts/tests/golem_action_tests.gd` | – |
| `--golemarenatest` | `scripts/tests/golem_arena_tests.gd` | – |
| `--golemstorytest` | `scripts/tests/golem_story_tests.gd` | – |
| `--golemzichtbaartest` | `scripts/tests/golem_zichtbaar_tests.gd` | – |
| `--gqzonnevlamscrolltest` | `scripts/tests/gq_zonnevlam_scroll_tests.gd` | – |
| `--grotlayouttest` | `scripts/tests/grot_layout_tests.gd` | – |
| `--hangertest` | `scripts/tests/hanger_tests.gd` | – |
| `--hd2dtest` | `scripts/tests/hd2d_tests.gd` | – |
| `--held24test` | `scripts/tests/held24_tests.gd` | – |
| `--hudtest` | `scripts/tests/hud_tests.gd` | – |
| `--huiscollisiontest` | `scripts/tests/huis_collision_tests.gd` | – |
| `--huisdrawtest` | `scripts/tests/huis_draw_calls_tests.gd` | – |
| `--huispixeltest` | `scripts/tests/huis_pixel_tests.gd` | – |
| `--inventorytest` | `scripts/tests/inventory_tests.gd` | – |
| `--launchertest` | `scripts/tests/launcher_icon_tests.gd` | – |
| `--lichtpropstest` | `scripts/tests/lichtprops_tests.gd` | – |
| `--lifecycletest` | `scripts/tests/lifecycle_tests.gd` | – |
| `--locktest` | `scripts/tests/lock_tests.gd` | – |
| `--magentabangtest` | `scripts/tests/magenta_bang_tests.gd` | – |
| `--musictest` | `scripts/tests/music_tests.gd` | – |
| `--muziektest` | `scripts/tests/muziek_tests.gd` | – |
| `--netsynctest` | `scripts/tests/net_sync_tests.gd` | – |
| `--nettest` | `scripts/tests/net_tests.gd` | – |
| `--openingtest` | `scripts/tests/opening_tests.gd` | – |
| `--partytest` | `scripts/tests/party_tests.gd` | – |
| `--pdfollowuptest` | `scripts/tests/pd_followup_tests.gd` | – |
| `--perfectdodgetest` | `scripts/tests/perfect_dodge_tests.gd` | – |
| `--playtestkittest` | `scripts/tests/playtest_kit_tests.gd` | – |
| `--pvptest` | `pvp/tests/pvp_tests.gd` | – |
| `--rekruuttest` | `scripts/tests/rekruut_tests.gd` | – |
| `--roottest` | `scripts/tests/root_tests.gd` | – |
| `--runknoptest` | `scripts/tests/run_knop_kamers_tests.gd` | – |
| `--savefuzztest` | `scripts/tests/save_fuzz_tests.gd` | – |
| `--saveroundtriptest` | `scripts/tests/save_roundtrip_tests.gd` | – |
| `--savetest` | `scripts/tests/save_tests.gd` | – |
| `--sessielogcoretest` | `scripts/tests/sessielog_core_tests.gd` | – |
| `--sessielogtest` | `scripts/tests/sessielog_tests.gd` | – |
| `--somroomstest` | `scripts/tests/som_rooms_tests.gd` | – |
| `--spiegeltest` | `scripts/tests/spiegel_tests.gd` | – |
| `--staggertest` | `scripts/tests/stagger_tests.gd` | – |
| `--studiourltest` | `scripts/tests/studio_url_tests.gd` | – |
| `--swinglocktest` | `scripts/tests/swing_lock_tests.gd` | – |
| `--t26sheettest` | `scripts/tests/t26_sheet_tests.gd` | – |
| `--telegraphtest` | `scripts/tests/telegraph_tests.gd` | – |
| `--updatetest` | `scripts/tests/todo_update_tests.gd` | – |
| `--warperkamertest` | `scripts/tests/warper_kamer_tests.gd` | – |
| `--wilgendaltest` | `scripts/tests/wilgendal_tests.gd` | – |
| `--wm1balanstest` | `scripts/tests/wm1_balans_tests.gd` | – |
| `--wm1dekkingtest` | `scripts/tests/wm1_dekking_tests.gd` | – |
| `--wm1f3stabilitytest` | `scripts/tests/wm1_f3_stability_tests.gd` | – |
| `--wm1qasweeptest` | `scripts/tests/wm1_qa_sweep_tests.gd` | – |
| `--wm1storytexttest` | `scripts/tests/wm1_storytext_tests.gd` | – |
| `--woudgrondtest` | `scripts/tests/woud_grond_tests.gd` | – |

Balans (geen test): `-- --battlesim [--seed=N] [--fights=N] [--only=id,id]` (`tools/battlesim/`) schrijft `docs/BATTLE_BALANCE_REPORT.md`; een kleine vaste-seed steekproef zit in `--autotest`.

Balans per run (CSV, geen test): `-- --battlesim --party=dennis:5,noor:5 --enemy=all|enc<N>|<groep-id>|a+b --runs=N --seed=S --policy=simpel`
schrijft `user://sim/battlesim_<policy>_s<seed>.csv`; `python3 tools/battlesim/rapport.py [csv|map]` geeft winrate, mediaan beurten en de zwaarste groepen.

Alle suites lokaal: `for s in autotest menutest puzzletest dungeontest golemtest archieftest kerntest kernkrachttest woudtest codextest checkpointtest dungeon100gentest dungeon100schaaltest dungeon100regelstest dungeon100integratietest dungeon100blauwtest actorsfxtest; do .github/scripts/run_suite.sh $s; done`
(samen ~12 min; CI draait ze parallel). Een eigen `XDG_DATA_HOME` per suite houdt `user://` (saves/instellingen) gescheiden.

`--relaytest` (online co-op via `relay/`) start zelf `node relay/server.js` en heeft Node >= 20 nodig; CI-job `relay` in `.github/workflows/tests.yml` draait `cd relay && npm ci && npm test` en daarna deze suite (zie `relay/README.md` voor lokaal draaien).

**Nieuwe suite toevoegen:** script in `scripts/tests/<naam>_tests.gd` (zelfde PASS/FAIL/RESULT-format,
`get_tree().quit(1 if failures else 0)`), een regel in de lijst in `scripts/game_state.gd` `_ready()`,
en de suite in de matrix van `.github/workflows/tests.yml` (zie `.github/ci/README.md`).

## Kaart van de code
- `project.godot` — autoloads: `GameState`, `Transition`, `Dialog`, `Story`, `Crt`, `Settings`, `AudioManager`. Hoofdscène `scenes/ui/title.tscn`.
- `scripts/game_state.gd` — party, inventaris, saves, test-dispatch. `scripts/story.gd` + `scripts/data/story_data.gd` — verhaalvlaggen/dialoog.
- `scripts/data/` — **alle content-data**: `game_data.gd` (helden, monsters, items, skills), `dungeon100_scaling.gd`, `dungeon100_blue.gd` (Blauwe Kisten / Mimic / Warp), `codex_data.gd` (Codex: verzamelbare/vangbare wezens),
  `book_data.gd`, `kern_data.gd`, `dungeon_rooms.gd`, `puzzle_rooms.gd`, `woud_rooms.gd`, `story_data.gd`.
- `scripts/battle/` — gevechten (`battle.gd`, menu, helden, baas-kern, `codex_battle.gd`/`codex_ally.gd` voor de Codex).
- `scripts/ui/` — menu's, titelscherm, Codex-scherm (`codex_screen.gd`), bestiarium, stijl (`ui_style.gd`, `menu_colors.gd`).
- `scripts/dungeon/`, `scripts/puzzle/`, `scripts/kern/` — kerkers, puzzel-elementen, kernkrachten.
- `scripts/core/flow_state.gd` — veldflow (`GameState.flow_state()/scene_busy()/field_free()`); alle toestandsmachines en hun constanten (`ST_*`, `MODE_*`, `PHASE_*`) staan in `docs/STATE_MACHINES.md`. Nieuwe toestand = constante + in de set, anders faalt `--statemachinetest`.
- `scripts/perf/` — lichte profiler (`perf_probe.gd`, T27 / s25_check RISK-haken; `--perfprobe` / `--perfprobetest`) en WM1-frametijd (`wm1_frametime.gd`).
- `scripts/tests/` — testsuites; `scripts/debug_autotest.gd`, `scripts/debug_menutest.gd` — de twee oudste suites.
- `scenes/` — .tscn-scènes. `assets/` — sprites, tiles, fonts, ui, shaders, audio. `art/` — art van RPG ART.
- `tools/` — Python art-generators (placeholders), `handwerk.txt`, `placeholders_*.txt`.
- `docs/` — ontwerp, handoffs, `docs/lore/CANON.md`, `docs/ARTSTYLE.md`.

**Audio:** manifest-gedreven via autoload `AudioManager` (`scripts/audio_manager.gd`,
`assets/audio/audio_manifest.json`). In de repo staan nu ~298 `.ogg`-bestanden (BGM + SFX); ontbrekende
manifest-paden spelen stil af zonder errors. **11 BGM-tracks** hebben nog geen bestand (zie ticket A-2 in
`docs/handoff/HANDOFF_review_2026-11.md`): o.a. `eindbaas_fase1`, `eindbaas_fase2`, `game_over`, `overwinning`,
`aftiteling`, `sapientia_thema`, `rustplek`, `industriestad`, `zwevende_tempel`, `ondergronds_lab`,
`sterrenobservatorium`.
