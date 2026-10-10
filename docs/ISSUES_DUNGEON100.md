# Open punten — Dungeon100

Stand: `main` `9cbb1de` (merge van PR #13), 10 oktober 2026.
Alleen wat op die stand nog ontbreekt of stuk is. Geen GitHub-issue: `gh` mag die niet aanmaken.

## Al op main

- Generator (PR #8), schaal/buit (PR #9), regels/HUD (PR #7).
- Blauwe Kisten, Mimics en Warp (PR #11). Dood in de grot zet je op de wereldkaart bij `van_dungeon100`. De hele party gaat naar binnen op level 1 zonder uitrusting. Goud van de run vervalt; het goud uit de momentopname komt terug. Elke nieuwe binnenkomst krijgt een nieuwe seed (`dungeon100_end_run` zet `dungeon100_seed` op 0). Het Warp-kristal is baasbuit op verdieping 100 en werkt alleen daar.
- Titelscherm met Doorgaan en Nieuw spel (PR #12).
- Web-preset zonder threads, plus de export onder `export/web/` (PR #13). Die export is verouderd; zie Web.
- De Ancient Cave-branch staat niet meer op de remote.
- De repo is public. GitHub Pages staat aan op `cursor/web-build-29ec`, map `/`.

## Gameplay

### [ ] Mimic zonder kaartplaatje: `--dungeontest` en `--woudtest` falen

- Waarom: `scripts/tests/dungeon_tests.gd` eist `assets/map_monsters/<vijand>.png` voor elke vijand. De Mimic heeft alleen `assets/sprites/enemies/mimic.png`. In het spel valt `scripts/dungeon/map_monster.gd` terug op het verkleinde gevechtsplaatje met magenta hoekjes. `--woudtest` vergelijkt `bestiary_ids().slice(6)` met de vier woudvijanden; bestiarium 011 is de Mimic, dus die check faalt. `AGENTS.md` noemt nog 185 en 90 PASS voor die twee suites; op deze `main` zijn ze rood.
- Volgende stap: draft-PR #15 mergen. Die levert een placeholder van 32×64 en laat de woud-check bij 007–010 stoppen. Daarna staat `--woudtest` op 91 PASS.
- Zie: [PR #15](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/15), `assets/map_monsters/mimic.png`, `tools/placeholders_v17.txt`, `scripts/tests/woud_tests.gd`.

### [ ] Schaal en buit zijn niet gesimuleerd

- Waarom: curves, baasvermenigvuldigers en buitkansen in `scripts/data/dungeon100_scaling.gd` zijn voorlopig. Er is geen simulatie die nagaat of verdieping 1–100 haalbaar is met een party op level 1 zonder uitrusting.
- Volgende stap: verdieping 1, 10, 50 en 100 spelen of headless narekenen, daarna `HP_LIN`, `BOSS_MULT`, `GEAR` en `gear_chance` bijstellen. `--dungeon100schaaltest` en `--dungeon100blauwtest` blijven groen.
- Zie: `HANDOFF_DUNGEON100_SCHAAL.md`, `scripts/data/dungeon100_scaling.gd`.

### [ ] Geüploade muziek speelt niet

- Waarom: `7d11c76` zette zes mp3's in `assets/audio/bgm/` (`SapientiaWORLDBGM (1).mp3` en vijf anderen, met spaties en `(1)` in de naam). `assets/audio/audio_manifest.json` wijst naar `bgm_*.ogg` die er niet zijn. De AudioManager blijft stil. Draft-PR #14 koppelt de wereldkaart aan `bgm_wereld.ogg`; dat bestand zit niet in de PR en niet op `main`.
- Volgende stap: de Suno-bestanden de manifestnaam geven (ogg, of het manifest op deze mp3's zetten) en #14 daarmee afmaken. Zonder bestand blijft de wereldkaart stil.
- Zie: [PR #14](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/14), `assets/audio/bgm/`, `assets/audio/audio_manifest.json`.

## Art

Nodig van RPG ART. Tot die bestanden er zijn blijven de placeholders staan.

### [ ] Rustpunt is het opslagboek

- Waarom: `Dungeon100Rustpunt` tint `assets/sprites/save_book.png` met `Color(1.0, 0.86, 0.62)`. Er is geen eigen bestand, dus ook geen regel in `tools/placeholders_v17.txt`.
- Volgende stap: eigen sprite, 64×16, 4 frames van 16×16, palet van de Archieven. Pad in `tools/handwerk.txt` zodra het echte art is.
- Zie: `scripts/dungeon/dungeon100_rustpunt.gd`, `HANDOFF_DUNGEON100_REGELS.md`.

### [ ] Ingang op de wereldkaart is het grot-icoon van het Donker Woud

- Waarom: `Exits/NaarDiepeGrot` staat op tegel (9, 26) en de grondtegel is atlas `(4, 0)` van `wereld_v17_iconen.png`. De generator-test eist dat icoon.
- Volgende stap: eigen icoon 16×16 voor de Diepe Grot, en de atlas-check in `scripts/tests/dungeon100_generator_tests.gd` mee aanpassen.
- Zie: `scenes/maps/wereldkaart.tscn`, `HANDOFF_DUNGEON100.md`.

### [ ] Tien bazen zonder eigen art of lore

- Waarom: `BOSSES` hergebruikt bestaande vijanden en geeft ze alleen een andere gevechtsnaam: Bladzijdenwachter (papiergeest), Glitchkoningin (glitchmot), Sporenvorst (sporenzwam), Wortelmoeder (wortelkruiper), Wachter-Kolos en Zegelwachter (mech_wachter), Mistheer (mistuil), Grote Boekengolem en De Laatste Wachter (kennis_beest), Wortelkeizer (wortelkoning).
- Volgende stap: per baas een eigen sprite in de maat van die vijand, plus een lore-naam. Tot die tijd blijven de bestaande ids.
- Zie: `scripts/data/dungeon100_scaling.gd`.

### [ ] Blauwe kist is een tint

- Waarom: `Dungeon100Blue.BLUE_TINT` (`Color(0.45, 0.7, 1.35)`) kleurt `assets/sprites/buiten/kist.png`. Geen eigen sprite.
- Volgende stap: eigen kist, zelfde maat als de gewone kist (2×16×16), en de tint in code vervangen.
- Zie: `scripts/data/dungeon100_blue.gd`, `tools/placeholders_v17.txt`.

### [ ] Mimic-art is placeholder

- Waarom: het gevechtsplaatje is 80×64 uit `tools/art_mimic_placeholder.py` (kist met tanden, magenta hoekjes). Het kaartplaatje ontbreekt op `main`; PR #15 levert daar een placeholder van 32×64 (2×4 frames) voor.
- Volgende stap: echt gevechtsplaatje 80×64 en echt kaartplaatje 32×64. Daarna de regels uit `tools/placeholders_v17.txt` halen en de paden in `tools/handwerk.txt` zetten.
- Zie: `assets/sprites/enemies/mimic.png`, [PR #15](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/15).

## Web/test op telefoon

### [ ] De live web-build is `bfff094`

- Waarom: spelen op de telefoon gaat via de browser, niet via een APK. Pages staat aan en de repo is public. https://krelegerdennis-collab.github.io/Sapientia-RPG/ geeft HTTP 200 (bronbranch `cursor/web-build-29ec`, map `/`, last-modified 10 okt 2026 18:04 UTC). Die branch eindigt op `1974c12`: een export van `main` `bfff094` met Godot 4.7.2, threads uit. Dat is vóór Blauwe Kisten (#11), het titelscherm (#12), het Mimic-kaartplaatje (#15) en de geüploade mp3's (`7d11c76`). De merge van #13 heeft diezelfde `export/web/index.pck` op `main` gezet; de broncode van `main` is nieuwer dan de export.
- Volgende stap: na #15 een nieuwe web-export van de huidige `main` maken (zelfde preset, threads uit). `export/web/` vervangen en de Pages-branch bijwerken, of Pages op een branch zetten die die export aan de root heeft. In `export/web/README.md` de sha van de export zetten. Pages zelf hoeft niet opnieuw aangezet te worden.
- Zie: [PR #13](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/13) (gemerged), `export/web/README.md`, `export_presets.cfg`, `index.html`.

## Technisch/CI

### [ ] De testsuites draaien niet op GitHub Actions

- Waarom: `.github/workflows/tests.yml` bestaat niet. De matrix staat in `.github/ci/tests.yml`. `.github/ci/README.md`: de bot-token heeft geen `workflow`-scope, dus het bestand is nooit geactiveerd. De enige Actions-run in de repo is `pages-build-deployment` (geslaagd). Of het minutenbudget op is, is met deze token niet te lezen.
- Volgende stap: `tests.yml` in `.github/workflows/` zetten (`gh auth refresh -s workflow`, of plakken via de website). Tot die tijd lokaal `.github/scripts/run_suite.sh`.
- Zie: `.github/ci/README.md`, `.github/ci/tests.yml`.

### [ ] Project staat op Godot 4.3, de machine op 4.7.2

- Waarom: `project.godot` heeft feature `4.3`. Deze omgeving heeft Godot 4.7.2. `scripts/party_actions.gd` vermijdt `load()` omdat Godot 4.7 bij afsluiten lekte. `docs/HANDOFF_PUZZELS.md`: suites die dezelfde `user://` delen kunnen de save-test laten falen (gezien op 4.7.2). Een aparte flake van `--kernkrachttest` staat niet in de repo.
- Volgende stap: suites alleen via `.github/scripts/run_suite.sh` (eigen `XDG_DATA_HOME` per suite). Het project blijft op 4.3 tot RPG Forge de feature-vlag zet.
- Zie: `project.godot`, `README.md`, `.github/scripts/run_suite.sh`, `docs/HANDOFF_PUZZELS.md`.

## Documentatie

### [ ] Lore van Het Gesimuleerde Archief staat niet in de canon

- Waarom: `scripts/data/dungeon100_blue.gd` en `HANDOFF_DUNGEON100_BLUECHEST.md` noemen de Diepe Grot een simulatie van de Oude Mensheid, aangetast door de Zwarte Stroom. Dat is een voorstel. `docs/lore/CANON.md` heeft het niet. Spelertekst noemt de simulatie al (`MSG_WARP_USED`, de beschrijving van de Mimic).
- Volgende stap: Dennis zet het voorstel in `docs/lore/CANON.md`, of de zinnen die de grot zo noemen gaan eruit.
- Zie: `HANDOFF_DUNGEON100_BLUECHEST.md`, `docs/lore/CANON.md`.

### [ ] Vijf teksten lopen achter op de code

- Waarom:
  - `export/web/README.md` zegt dat Pages uit staat, dat de build de huidige `main` is, en dat dungeon100 nog op losse branches staat.
  - `assets/audio/bgm/README.md` zegt dat de map leeg is.
  - `AGENTS.md` zegt dat er nog geen audio is en dat `bgm/` alleen een README bevat.
  - `HANDOFF_DUNGEON100_REGELS.md` §7 zegt 74 PASS; `AGENTS.md` zegt 72 voor `--dungeon100regelstest`.
  - `HANDOFF_DUNGEON100.md` (bovenaan) zegt dat de seed vast blijft. Na `dungeon100_end_run` is de seed 0 en krijgt de volgende run een nieuwe (`scripts/dungeon/dungeon100_room.gd`).
- Volgende stap: die passages gelijk trekken met `main` `9cbb1de`.
- Zie: de vijf bestanden hierboven.
