# Changelog

Alle noemenswaardige wijzigingen van SAPIENTIA, vanaf v0.18. Formaat naar [Keep a Changelog](https://keepachangelog.com/);
versies volgen `tools/release/version.json` (de enige bron, zie `docs/release/PLAY_STORE.md`).
Een kopje `## [X.Y]` per versie is verplicht: `tools/release/bump_version --check` (en `--aabtest`) controleert dat.
`tools/release/bump_version minor` zet bij een bump zelf het nieuwe kopje onder `[Unreleased]`.

Data van oudere versies komt uit de git-tags (`v0.18`, `v0.19`, `v0.20`); de teksten hieronder zijn een samenvatting,
de details staan in README.md en in de commitgeschiedenis. Alle speler-tekst in het spel is Engels, dit bestand blijft Nederlands.

## [Unreleased]

Alles op `main` na tag `v0.20`.

### Toegevoegd
- Online co-op via een Node-relay (`relay/`, kamers met 6-tekencode, max. 4 spelers) onder dezelfde lobby/sync als LAN; `--relaytest`.
- Fase B: LAN co-op lobby, host-autoritaire Action-sync in de sandbox, co-op host op Android (INTERNET-permissies in de presets).
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

### Gewijzigd
- Wilgendal plein 10 en binnen-tilesets v8 van RPG ART; Archief 2 geschaald (1.4x), Berggrot-geheim, Wilgendal-panden.
- WM1-cuts (content-lock Dennis, 24 okt): hubkamers H3, nissen H2, dev-kamers H1, PvP/Co-op-knoppen H11 (verborgen zonder relay-URL), Koopman H13.
- Art-batches 1 en 3 en nieuw titelscherm naar het masterpalet (RPG ART).
- Power scaling v2 (data-only monster/baas-stats; Wortelkoning ~82% winst) en Action-balans Archief 1.
- Framerate begrensd op 60 fps; opties met 24px tikhoogte en layouttests op drie viewports.

### Opgelost
- Saves zijn atomair en herstelbaar; verplichte pauze-save hersteld; suspend-save alleen op mobiel.
- Huis-uitgang Wilgendal hangt af van de herkomst (`huis_herkomst` in de save).
- Warp-pingpong met een vinger op de D-pad (`spawn_hold`); diverse flaky CI-tests deterministisch gemaakt.

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
