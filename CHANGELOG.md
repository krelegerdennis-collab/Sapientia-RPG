# Changelog

Alle noemenswaardige wijzigingen van SAPIENTIA, vanaf v0.18. Formaat naar [Keep a Changelog](https://keepachangelog.com/);
versies volgen `tools/release/version.json` (de enige bron, zie `docs/release/PLAY_STORE.md`).
Een kopje `## [X.Y]` per versie is verplicht: `tools/release/bump_version --check` (en `--aabtest`) controleert dat.
`tools/release/bump_version minor` zet bij een bump zelf het nieuwe kopje onder `[Unreleased]`.

Data van oudere versies komt uit de git-tags (`v0.18`, `v0.19`, `v0.20`); de teksten hieronder zijn een samenvatting;
oudere versieparagrafen stonden vroeger in `README.md` (nu alleen nog technische setup). Alle speler-tekst in het spel is Engels, dit bestand blijft Nederlands.

## [Unreleased]

## [0.21] (RC) - 2026-11-15

Alles op `finish/wm1` na tag `v0.20` (release-branch voor WM1).

### Toegevoegd
- Online co-op via een Node-relay (`relay/`, kamers met 6-tekencode, max. 4 spelers) onder dezelfde lobby/sync als LAN; `--relaytest`.
- Fase B: LAN co-op lobby, host-autoritaire Action-sync in de sandbox, co-op host op Android (voor de RC weer dicht, zie Bekend).
- Action-modus: doel-lock met tikken, auto-lock, Codex vangen in Action, gekozen leider blijft over warps/opslaan/laden, Action als standaard voor een nieuw spel.
- Action-HUD overal (joystick + knoppenrij, geen D-pad), RUN/MENU-knoppen in dezelfde stijl.
- Rekruten Kael en Orion in de World Warper-hal, met eigen gevechtssprites, ontwijk-poses en actor-sfx.
- Party-sprites op 24x32 (Dax, Seren, Vesper, Kael, Orion) op alle kaarten behalve wereldkaart en bouwplaats.
- Quest Log + ECHO per act (data-gedreven quests, scherm Active/Done, save-veld `quests`).
- Music-tab (Scenes > Music) met alle aanwezige tracks, schuifregelaars, mute en preview; WM1-muziek op elke map.
- Vang-tutorial (Codex) na de Inktwurm-tutorial; Golemhal-uitgang blijft op slot tot de Inktwurm in de Codex staat.
- Lokale sessielog (JSON Lines, `user://`, max. 2 MiB) met `tools/sessielog/samenvat.py`.
- Battle simulator per run (`--battlesim --party --enemy --runs --seed --policy`, CSV + `rapport.py`) en Action-simulator.
- Release-voorbereiding Play Store: AAB-preset, `tools/release/` (versiebron, `bump_version`, `build_aab.sh`), `docs/release/PLAY_STORE.md`, suite `--aabtest`.
- Realtime Golem-baas in Action (fases, kernvenster, telegraph) met story-events na de arenawinst; opening Drift + story-Hal met ECHO.
- Tekst en lore (`finish/wm1`, 5 nov): unieke beschrijvingen voor alle Diepe Grot-uitrusting, bestiarium-tekst voor alle twaalf grotbazen, 20 lege-kamer-briefjes, ECHO-hubregels in zijn eigen stem, namen en tweede zinnen voor de Wilgendal-winkeliers en -dorpelingen, Koopman-variatie per bezoek.
- Release-docs: `LAUNCH_PLAN.md`, `FINISH_LOG.md` (scorekaart), `STORE_LISTING.md`; `tools/sfx/` (SFX-generatie via ComfyUI + Stable Audio Open).
- WM1-filmpjes CS-01 t/m CS-12 met Scenes-menu, goedgekeurde storytext en proloog-titelkaart (#383, #393, #394, #436, #439-#441).
- HD-2D-mapverlichting voor WM1 (`MapLighting`) met lichtprops in Archief 2 (#413, #415, #437).
- Action: stagger-meter voor vijanden (F2, #450) en vloer-telegraphs (#453).
- Action game-feel: screenshake, gekleurde schadegetallen, impact, stof, hit-react, glitch-dood, loot-pop en enemy-read (#404, #444, #477, #482).
- Autosave per slot (`autosave_N.json`, met migratie) (#391).
- Uitleg over opslaan voor de speler: save-boek en grijze Save-knop (#388).
- Wachtrij voor `Dialog.show_lines` (#457); Android-terugknop en Back op het naamscherm (#451).
- Android launcher-icoon (archief-embleem) (#443).
- Masterpalet (`docs/art/masterpalet.gpl`) met `palet_check` en CI-waarschuwing (#366).
- Centrale inventaris- en goud-API (#399).
- Nieuwe suites o.a. `--rcchecktest` (#481), `--savestresstest` (#469), `--f6uxtest2` (#463) en de game-feel-suites (#449, #480, #488).
- Keten-feel: 3-hit chain (#475).
- Arena-flow, achter `ARENA_ENABLED = false` (#478).
- WM1 QA-ronde op de RC en suite `--wm1qasweeptest` (#492).
- Arena-golven: vervolgpunten review #487 (A-D) (#494).
- Plan voor het refactor-blok van `battle.gd` (fase 1, vanaf 24-11) (#495).
- Game over en respawn bij Strangler en Mender, suite `--bossrespawntest` (#497).
- RUN-knop in kerker, Rest Room en Koopman, suite `--runknoptest` (#498).
- `--negeer <glob>` in `palet_check.py` en `meet.py` (#505).
- Balansmeting WM1 voor de interne RC (F5.2, F5.4, F5.5, F5.6) (#508).

### Gewijzigd
- Interne RC (besluit Dennis, 15 nov): versie 0.21 / versionCode 23; netwerkrechten (`internet`, `access_network_state`,
  `access_wifi_state`, `change_wifi_multicast_state`) uit in alle Android-presets, omdat online dicht is (H11). Solo speelt zonder netwerk.
- Toestandsmachines expliciet gemaakt zonder de buitenkant te veranderen (`docs/STATE_MACHINES.md`): veldflow via
  `FlowState` (`GameState.flow_state()/scene_busy()/field_free()` + signaal `flow_changed`) in plaats van ~20 herhaalde
  guards; benoemde constanten + sets voor `battle.state`, `som_ally.state`, `kern_absorption.phase` en de `mode` van
  winkel/uitrusting/slotlijst/Codex; alleen-lezen `player.movement_state()` en `Dialog.phase()`. Nieuwe suite
  `--statemachinetest` (75) bewaakt dat elke toestand een constante in de set is.
- Wilgendal plein 10 en binnen-tilesets v8 van RPG ART; Archief 2 geschaald (1.4x), Berggrot-geheim, Wilgendal-panden.
- WM1-cuts (content-lock Dennis, 24 okt): hubkamers H3, nissen H2, dev-kamers H1, PvP/Co-op-knoppen H11 (verborgen zonder relay-URL), Koopman H13.
- Art-batches 1 en 3 en nieuw titelscherm naar het masterpalet (RPG ART).
- Power scaling v2 (data-only monster/baas-stats; Wortelkoning ~82% winst) en Action-balans Archief 1.
- Framerate begrensd op 60 fps; opties met 24px tikhoogte en layouttests op drie viewports.
- CI-matrix naar 121 suites plus een aparte relay-job (alle geregistreerde suites behalve perf/benchmark en de lange playthrough) (#406, #409).
- Art naar het masterpalet en eigen sprites voor rustpunt, Blauwe Kist en uitgang-warper (RPG ART; #369-#372, #375, #378, #379, #381, #403, #411, #412).
- Telegraph-kleur van rood naar magenta (kleurregel) (#485, #490).
- Gevechtsbalans: stun-lock dicht (C-2, #408), MAG/MDEF met zwakte/resistentie en scroll-ladder in de Diepe Grot (C-12, #414), Solar Flare-scroll vanaf vloer 20 (#446).
- Hoofdmenu: Beta Test, End State en SoM achter een testvlag (#398).
- Export-presets gelijkgetrokken; `export/web` niet meer in git (#390).
- Grijze UI-tekst haalt 4,5:1 contrast (#463).
- Battle Style-uitleg en tutorial: Golem is realtime in Action (#367).
- World Warper Rustkamer en Party-select binnen de safe area, letters >= 10, ECHO-kistnamen leesbaar (#465).
- Lijstregels in menu's krijgen een onzichtbaar tikvlak >= `TOUCH_MIN` (#466).
- Settings General past binnen venster en safe area (16:9, 19,5:9, notch) (#467).
- Perfect dodge (F1): bron via `hit_player`, tellers reset per gevecht (#479).
- Verouderde geen-CI-matrix-comments bij de arena weg (#496).
- Vier bestaande suites in `tests.yml` (bossrespawn, book_point, qa-sweep, arena-followup) (#500).
- Dax- en Vesper-finishers in de kleurregel (#501).
- `BATTLE_REFACTOR_PLAN` bijgewerkt na #450, #472 en #501 (#503).
- RC-audit bijgewerkt (klus 18) en kleine doc-nits (#504).
- `placeholders_v17.txt` opgeschoond (F2.5) (#506).
- `blauwekisttest`, `bossnametest` en `dungeon100bossmaptest` in de CI-matrix (F1.4) (#507).
- RC-audit klus 19 (17 nov middag, #506–#508) (#509).
- EOF-newline in twee book_point-tests (#511).
- Paletaudit F2.2, run 2 (alleen meting) (#512).
- Droge Android-releasebuild gedocumenteerd (F8.6) (#513).
- `--combattick` in de CI-suite-matrix (F1.4) (#514).
- RC-audit freeze (F1.7, F1.4, F3.2, F6.23) en changelog 0.21 (F8.3) (#516).
- Lock-cijfers herteld op `f76aa715` (F1.6) (#517).
- RC-audit: F1.6 KLAAR (EVENTS 62) na hertelling #517 (#519).
- `wmdeathtest` in de CI-matrix (`tests.yml`, akkoord Dennis) (#521).
- Paletfix F2.2 `01_art` (#523).
- Paletfix F2.2 `02_world_warper_art` (#524).
- Paletfix F2.2 `03_assets_bg` (#525).
- Paletfix F2.2 `04_assets_characters` (#526).
- Paletfix F2.2 `05_assets_fx` (#527).
- Paletfix F2.2 `08_assets_placeholder` (#528).
- Paletfix F2.2 `11_assets_tiles` (#529).
- Paletfix F2.2 `07_assets_map_monsters` (sporekop v2) (#530).
- Paletfix F2.2 `09_assets_puzzle` (#531).
- Hit-react-nudge op hele pixels, ook diagonaal (alleen weergave) (#532).
- Naamscherm binnen de veilige zone (#533).
- Diepe Grot-pil volgt het veilige gebied (#534).
- Slotlijst gecentreerd in de veilige zone (#535).
- Warp-view binnen de veilige zone (#536).
- Titelscherm-stage in het veilige gebied (#537).
- Paletfix F2.2 `12_assets_ui` (#538).
- Paletfix F2.2 `10_assets_sprites` (#540).
- Paletfix F2.2 `06_assets_hd2d` (`light_soft_128`, Bayer 8x8) (#541).

### Opgelost
- Saves zijn atomair en herstelbaar; verplichte pauze-save hersteld; suspend-save alleen op mobiel.
- Huis-uitgang Wilgendal hangt af van de herkomst (`huis_herkomst` in de save).
- Warp-pingpong met een vinger op de D-pad (`spawn_hold`); diverse flaky CI-tests deterministisch gemaakt.
- KO door gif of brand wordt gemeld als gewone KO (bericht, geluid, wegfade).
- Zingend Meel van de molen is per bezoek en niet meer per save: laden geeft geen tweede meel.
- Respawn-tekst definitief ("The Current pulls you back...").
- Saves: versie-guard, `scene_busy`-guard en geneste typechecks bij laden (#392, #395); Molen-meel alleen via `story_flags` (#387).
- `change_map` heeft een vangnet bij een ontbrekend pad; een deur zet input pas vast als de wissel slaagt (#452, #459).
- Tekstvak te laag bij gestapelde keuzes (#434); Classic-baasnaam afgekapt op 16:9 (#410).
- Golem-aanvallen zichtbaar in Action (#374); Drift-achtergrond vult een breed scherm (#373).
- Relay: peer-id-overflow en gast-input gebonden aan de afzender (#405, #407).
- Localisatie-guard: PvP-modi in het Engels (#386).
- `book_point` stopt na await als het object weg is (#499).
- `--combattick` groen op 30 fps (meter-framecorrectie); enemy-read zonder lambda-capture-errors (#510).
- Inktwurm uit de geheime kast is vangbaar in de Action-arena ("No enemy in range") (#518).
- Softlock na game over op de wereldkaart (#520).
- `--uishots` slaat de intro-cutscene over (#522).
- `step_dir` wacht op process-frames in plaats van physics-frames (race bij `time_scale` 4, F3.2) (#539).

### Bekend
- Online staat dicht: PvP en co-op (LAN en relay) zijn verborgen via `online_cut` (H11), en de Android-presets vragen geen netwerkrechten.
- Hubkamers Training Hall, Workshop, Exchange en The Core en de hub-nissen blijven dicht via `hub_cut` (H3/H2).
- Perfect dodge (F1) zit in de code maar staat uit (`SomPerfectDodgeData.ENABLED = false`) tot de balanspas (#472, #486).
- Geluidseffecten zijn nog synthetische placeholders (`tools/placeholders_algemene_sfx.txt`); vervanging loopt via `tools/sfx/`. Voor de interne RC bewust geaccepteerd (besluit Dennis, 15 nov).
- Het Action-HUD wordt in code getekend en is nog niet beoordeeld (kanttekening bij F2.5, geen open placeholder-regel). `tools/placeholders_v17.txt` is opgeschoond (#506, merge `70f6743c`): 0 open regels.

## [0.20] - 2026-10-13

Tag `v0.20`. Bestiarium-fix, RPG ART's Inktwurm met geheimkast en kernscheur, Engelse ondertitel op het titelscherm.

### Toegevoegd
- Dungeon100 ("Diepe Grot", 100 verdiepingen): generator, schaalfuncties, rustpunt elke 10 verdiepingen, Blauwe Kisten, Mimics en Warp.
- World Warper-hub (ECHO als gids, warp-bestemmingen, savepunt) en Het Levende Archief / Archief 2 met Lotte, de Wurger en De Genezer.
- Wilgendal met vier winkelpanden en magie in de winkel (160 x grade^2); Berggrot en de kas.
- Vier save-slots met Doorgaan-lijst en Laden; eigen naam bij Nieuw spel; betatest- en eindstaat-account.
- PvP-vriendenmodus (lobby, gevecht, uitslag, LAN) met `--pvptest`.
- Inktwurm, Codex-knop, glitch-fusie; de Spiegel (Archief 4)-scène.
- Headless testsuites in GitHub Actions (`tests.yml`).

### Gewijzigd
- Alle speler-tekst vertaald naar het Engels.
- Web-export zonder threads voor telefoonbrowsers, gepubliceerd via GitHub Pages.

## [0.19] - 2026-10-10

Tag `v0.19` (versie 0.19, code 21). Kamer-checkpoint.

### Toegevoegd
- Kamer-checkpoint: na GAME OVER ontwaak je waar je de kamer/map binnenkwam (met je voortgang, zonder goudverlies); baaskamers zetten geen checkpoint (`--checkpointtest`).
- Workflow voor Cursor-agents: `AGENTS.md`, regels, PR- en issue-templates, CI.

### Gewijzigd
- Game-overregels in de handleiding gelijkgetrokken; preset `Android arm64` met `../rpg_prototype_v0.19_arm64.apk`.

## [0.18] - 2026-10-08

Tag `v0.18` (versie 0.18, code 20). Rugaanzichten, Codex-namen, audio-basis, design en lore.

### Toegevoegd
- Rug-sprites Moskonijn en Mech. Wachter van RPG ART (`sprite_back`), Codex-bondgenoten gebruiken nu de echte rug.
- Audio-basis: autoload `AudioManager`, `assets/audio/audio_manifest.json` (nog zonder geluidsbestanden); manifest zit in de APK via `include_filter="*.json"`.
- Design en lore als referentie (`docs/design/`, `docs/lore/`) met `docs/lore/CANON.md` als bindende beslissingen van Dennis.

### Gewijzigd
- Codex-scherm: lijst 12 px breder, namen tot 13 tekens (`LIST_W` 132).
- Arm64-preset: `export_path` = `../rpg_prototype_v0.18_arm64.apk`.
