# RC-audit WM1: checklist tegen de code (klus 10)

Doel: vaststellen wat er vóór de interne RC (F8, uiterlijk 20 nov 2026, **niet publiceren**) nog moet gebeuren.
Er is **niets gerepareerd**: alleen gelezen, geteld en gemeten.

- Basis: `finish/wm1` op `0fb6334` (#476, 15 nov 2026). Checklist: `docs/release/WM1_RELEASE_CHECKLIST.md` (93 punten).
- Bronnen: code en data in de repo, GitHub REST (labels, tags, issues, PR's, check-runs), `tools/art_audit/palet_check.py` (alleen lezen).
- Automatische controles staan in de nieuwe suite `--rcchecktest` (`scripts/tests/rc_check_tests.gd`). Bekende OPEN-punten
  geven daar een regel `OPEN  [id] ...` en maken de suite niet rood (zie onderaan).
- Statussen: **KLAAR** (bewijs in code, suite of PR), **OPEN** (er mist iets), **NIET TE CHECKEN** (handmatig, op toestel of proces).
- Grootte: S (uren), M (een dag), L (meerdere dagen of afhankelijk van een ander). "Ja Dennis" = vraagt een besluit over balans,
  nieuwe mechanic, bestaande test, workflow of publicatie (of een ander besluit dat alleen Dennis neemt; dat staat erbij).

## Samenvatting

| Status | Aantal |
|---|---:|
| KLAAR | 28 |
| OPEN | 36 |
| NIET TE CHECKEN | 29 |
| **Totaal** | **93** |

Per fase (K / O / N): F1 3/4/0 · F2 2/4/2 · F3 7/2/8 · F4 2/1/4 · F5 1/6/1 · F6 12/8/4 · F7 0/3/5 · F8 1/8/5.

### Top 5 OPEN op risico (voor de interne RC van 20 nov)

| # | Punt | Waarom risico | Voorstel | Grootte | Ja Dennis |
|---:|---|---|---|---|---|
| 1 | F7.2 Dennis' playtest | Scorekaart in `FINISH_LOG.md` heeft geen cijfers van Dennis; geen playtest-issues. Of er P0/P1 zijn, weet niemand. Gate fase 7 staat dus open. | Verse debug-APK van de huidige `finish/wm1` (F7.1), één ronde volgens `WM1_PLAYTEST.md`, bugs als issue met label `bug`. | L | ja (alleen Dennis kan spelen) |
| 2 | F1.7 Freeze / scope | Geen tag `wm1-freeze`. Na 5 nov kwamen er nog nieuwe features bij (F2 stagger #450, F1 perfect dodge #472, F4 game feel #404/#444, HD-2D #413/#415/#474/#476) en drie feature-PR's staan open (#475 keten, #477 game-feel fase 1, #478 arena). Zo blijft de RC-commit schuiven. | Dennis kiest de freeze-commit, Forge tagt die. Daarna tot de RC alleen `wm1-bugfix`/`wm1-polish`; #475/#477/#478 parkeren tot na de RC. | S | ja (scope, nieuwe mechanics) |
| 3 | F8.6 Release-APK | `build-apk` heeft nog nooit met `build_type: release` gedraaid (laatste run op deze branch: debug, `5cb270c`, 5 nov). Of de signing-secrets er staan, kan deze sessie niet zien. Een ondertekende APK is de kern van de RC. | Forge doet nu een droge release-run op de huidige head. Dan blijkt meteen of de secrets kloppen, ruim voor 20 nov. | S | nee (bestaande workflow, interne build, niet publiceren) |
| 4 | F8.5 CI op de RC-commit | `tests.yml` draait alleen op `pull_request` en `push` naar `main`. De squash-commits op `finish/wm1` krijgen zelf geen run: `0fb6334` heeft 0 check-runs. Wel 122/122 groen op de PR-head van #476 (`bb1622e`). | Optie a: de RC-commit testen via een draft-PR (niet mergen). Optie b: `workflow_dispatch` aan `tests.yml` toevoegen. | S | ja (b is een workflow-wijziging) |
| 5 | F6.23 Placeholder-SFX | 162 regels in `tools/placeholders_algemene_sfx.txt` en 120 in `tools/placeholders_sfx.txt`. LAUNCH_PLAN B2 noemt dit een blocker. `gen_sfx.py` heeft nog nooit gedraaid (OVERDRACHT §4.3). | Voor de interne RC: Dennis accepteert de placeholders bewust (komt in known issues). Vervangen blijft nodig voor de publieke release. | L (vervangen) / S (accepteren) | ja (audio-keuze) |

Net buiten de top 5 vallen: F4.2 (geen S25-meting, alleen xvfb/llvmpipe in `docs/perf_wm1.md`), F5.1/F5.2 (geen doelvensters
gekozen; het balansrapport is van vóór #408/#414/#446/#450) en F6.14/F6.17 (touch- en safe-area-PR's #465, #466 en #467 staan open).

### Verouderde tekst in de checklist (FACT, niet gerepareerd)

- F8.1 noemt preset `version/name="0.19"`. Nu staat alles op 0.20 / code 22 (`tools/release/version.json`, `project.godot:15`, `export_presets.cfg:34-35,105-106,218-219`).
- F8.3 zegt "er is nog geen `CHANGELOG.md`". Die bestaat sinds #365.
- F4.3/F4.5 noemen 9 video's (30,46 MB). Het zijn er nu 13: 40.054.438 bytes in `assets/video/*.ogv`.
- F5.6 noemt `SomData.ACTION_BOSS_MULT`. Die is verwijderd (`scripts/data/som_data.gd:6`).
- F6.16 noemt de D-pad. Die is bewust weg (CHANGELOG Unreleased: "joystick + knoppenrij, geen D-pad").
- Voortgangstabel onderaan: alle fases 2-8 staan op "open", ook waar delen klaar zijn.

---

## Fase 1: Freeze

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F1.1 | Lock reviewen en mergen | KLAAR | `docs/release/WM1_CONTENT_LOCK.md` staat op de branch; cuts doorgevoerd (CHANGELOG 24 okt; `scripts/data/release_flags.gd`). Het vakje zelf is niet afgevinkt. | | | |
| F1.2 | BESLIS-punten H3/H11/H13 | KLAAR | `release_flags.gd:13-24`; suite `wm1releasetest` | | | |
| F1.3 | Labels `wm1-*` | OPEN | Labels (REST): `wm1-bugfix` en `wm1-lock` bestaan. `wm1-polish`, `wm1-cut` en `wm1-vervanging` ontbreken. | Forge maakt de drie labels aan. | S | nee (Forge) |
| F1.4 | CI-matrix gelijk met `game_state.gd` | KLAAR | #361, #380, #400, #406, #449; `.github/workflows/tests.yml:24` | | | |
| F1.5 | Baseline PASS-aantallen | OPEN | Geen freeze-commit, geen baseline. De tabel in `AGENTS.md` is van v0.18. | Na de freeze de CI-samenvatting (`GITHUB_STEP_SUMMARY`) in de checklist of in een issue zetten. | S | nee |
| F1.6 | Lock-cijfers hertellen | OPEN | Hangt aan de freeze-commit. | Hertellen na de tag; zo nodig een `wm1-lock`-PR. | S | nee |
| F1.7 | Tag `wm1-freeze` | OPEN | Tags: `v0.17`-`v0.20`, `debug-*`, `coop-*`; geen `wm1-freeze`. Features na 5 nov: zie top 5 #2. | Dennis kiest de commit, Forge tagt. Daarna alleen bugfix/polish. | S | ja (scope) |

## Fase 2: Art op palet

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F2.1 | Masterpalet vastgelegd | KLAAR | `docs/art/masterpalet.gpl`; #366; CI-job `palet-check` | | | |
| F2.2 | Alle PNG's meten | OPEN | `palet_check.py` (15 nov, alleen lezen): 1893 PNG's, waarvan 1113 schoon en 780 buiten het palet. Van die 780 zijn er 442 HD-2D-normal maps (`*_n.png`) en 339 overige (o.a. `ui/icons` 118, `placeholder/woud` 80, `sprites/buiten` 19, `sprites/archief2` 19). `meet.py` (CSV) is niet gedraaid op `art/` en `world_warper/art/`. | `meet.py` draaien op de drie mappen. Normal maps uitsluiten of als uitzondering laten tekenen. | M | ja (uitzonderingslijst) |
| F2.3 | CSV filteren op WM1 | OPEN | Hangt aan F2.2. | Filteren op de lock-inventaris. | M | nee |
| F2.4 | RPG ART levert batches | OPEN | Al geleverd: #369-#372, #379, #381, #403, #411, #412. De rest hangt aan F2.3. | ART per batch, met akkoord van Dennis. | L | ja (art-akkoord) |
| F2.5 | Placeholders in de route (H10) | OPEN | Rustpunt #375, Blauwe Kist #378 en uitgang-warper #381 zijn klaar. Het Action-HUD (slagboog, meters, ringmenu) wordt in code getekend en is niet beoordeeld. `tools/placeholders_v17.txt` heeft 25 regels zonder KLAAR/VERVANGEN, waarvan 12 dubbele Wilgendal-regels (regel 79+). `rcchecktest` [F2.5]. | Dennis bekijkt het Action-HUD op het toestel en kiest "laten staan" of "ART". Forge/ART ruimt de lijst op. | S | ja (bewust laten staan) |
| F2.6 | Ontbrekende art melden in PR | NIET TE CHECKEN | Procesregel. | | | |
| F2.7 | Suites na elke batch | KLAAR | CI draait alle suites op elke PR. Laatste art-PR's waren groen (bijv. #476: 122/122). | | | |
| F2.8 | Screenshots voor/na | NIET TE CHECKEN | Handmatig. | | | |

**Gate fase 2:** OPEN (`buiten_palet` niet 0 en geen getekende uitzonderingslijst).

## Fase 3: Stabiliteit

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F3.1 | Verse import zonder fouten | NIET TE CHECKEN | Er is geen Godot in deze sessie. CI importeert bij elke run, maar faalt niet op import-warnings. | Dennis draait lokaal `--import` en leest de uitvoer. | | |
| F3.2 | Alle suites groen op de freeze-commit | OPEN | Er is geen freeze-commit. Laatste volledige run: PR-head #476 `bb1622e`, 122/122 groen. De branch-commit `0fb6334` heeft 0 check-runs (zie F8.5). `wm1playthroughtest` (golden path) zit bewust niet in CI. | Na de freeze: CI op die commit (F8.5) en `wm1playthroughtest` één keer lokaal. | S | nee |
| F3.3 | Geen `SCRIPT ERROR` | KLAAR | `.github/scripts/run_suite.sh:25,30-33` faalt erop; #476 groen. | | | |
| F3.4 | Golden path route A en B | NIET TE CHECKEN | Handmatig. Deels gedekt door `wm1playthroughtest` (kas en berggrot, niet in CI). | | | |
| F3.5 | Terugweg Archief 2 (H14) | NIET TE CHECKEN | Handmatig. `archief2test` raakt `leven_v1_plaat`. | | | |
| F3.6 | Archief 2 zonder Vesper (H17) | NIET TE CHECKEN | Handmatig. Deels: `kasdeurtest`, `archieftest`. | | | |
| F3.7 | Golem Hall-varianten | NIET TE CHECKEN | Handmatig. Deels: `codextest`, `wm1playthroughtest`. | | | |
| F3.8 | Zingend Graan | NIET TE CHECKEN | Handmatig. Deels: `woudtest`, `uxtest`, #363. | | | |
| F3.9 | Game over bij elke baas | OPEN | `checkpointtest` dekt Golem (deel D) en Root King (deel E). Strangler en Mender hebben geen test. | Nieuwe suite voor respawn bij Strangler en Mender (geen bestaande test aanpassen). Tot dan in de playtest meenemen. | M | nee (nieuwe suite; CI-regel later via Forge) |
| F3.10 | Save/load, autosave, oude saves | KLAAR | `savetest`, `savefuzztest`, `saveroundtriptest`, `saverobusttest`, `savehardeningtest`, `savestresstest` (#469), autosave per slot #391, versie-guard #392; allemaal in CI. | | | |
| F3.11 | Hub-checks | NIET TE CHECKEN | Handmatig. Deels: `warperkamertest`, `echotest`, `wm1releasetest`. | | | |
| F3.12 | Diepe Grot | KLAAR | `dungeon100gentest`/`schaaltest`/`regelstest`/`integratietest`/`blauwtest`/`rustpunttest`, `koopmantest`; allemaal in CI. | | | |
| F3.13 | Classic en Action per kerker | NIET TE CHECKEN | Handmatig. Deels: `somroomstest`. | | | |
| F3.14 | H1/H2 dicht, F3/F4 alleen debug | KLAAR | `wm1releasetest`; `scripts/map.gd:331,336,342`; `rcchecktest` (debugtoetsen + dev-kamers in release). | | | |
| F3.15 | `wacht/` en tools/docs/tests niet in export | KLAAR | `wacht/.gdignore`; `export_presets.cfg:11,82,153,195`; `rcchecktest` (alle 4 presets, en elke `--suite` in `game_state.gd` wijst buiten de export). | | | |
| F3.16 | Repo-hygiëne | KLAAR | `git ls-files` op `0fb6334` geeft niets voor apk/aab/jks/keystore/uid/.env; `.gitignore` dekt ze (`rcchecktest`). | | | |
| F3.17 | `build-web` groen op `main` | KLAAR | Run op `main` `db0aa04` (9 nov): success. | | | |

**Gate fase 3:** OPEN (geen freeze-commit; routes niet handmatig gespeeld).

## Fase 4: S25-performance

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F4.1 | Release- en debug-APK op toestel | NIET TE CHECKEN | Toestel. | | | |
| F4.2 | Meting per scène (fps, 1%-low, RAM) | OPEN | Er is geen S25-meting. `docs/perf_wm1.md:137` is gemeten op xvfb/llvmpipe. `wm1budgettest` geeft vermoedelijk dubbele instantiatie (OVERDRACHT §4.4, ONVERIFIED). | Dennis meet met `adb dumpsys gfxinfo` op een debug-APK, of accepteert fase 4 bewust voor de interne RC. | M | ja (acceptatie) |
| F4.3 | Meetscènes | NIET TE CHECKEN | Toestel. Lijst verouderd: 13 video's, geen 9. | | | |
| F4.4 | 30 minuten spelen | NIET TE CHECKEN | Toestel. | | | |
| F4.5 | Opstarttijd, laadtijd, APK-grootte | NIET TE CHECKEN | Toestel. Assets nu ±84 MB (audio 36,5 MB, video 40,1 MB). | | | |
| F4.6 | Netwerk-idle bij Co-op/PvP | KLAAR | Niet van toepassing: online dicht (`online_cut`, H11; LAUNCH_PLAN B4). | | | |
| F4.7 | Regressie na fix | KLAAR | CI op elke PR. | | | |

**Gate fase 4:** OPEN (geen meetrapport en geen getekende acceptatie).

## Fase 5: Balans

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F5.1 | Doelvensters kiezen | OPEN | Niets genoteerd in de checklist. | Dennis neemt het voorstel over of past het aan. | S | ja (balans) |
| F5.2 | Volledig rapport op de freeze-commit | OPEN | `WM1_BALANCE_REPORT.md` meet op `fb17c40`, `BATTLE_BALANCE_REPORT.md` op `61986e9`. Sindsdien: C-2 stun-lock #408, C-12 MAG/MDEF #414, GQ-balans #446, F2 stagger #450. | `--battlesim --seed=20261020 --fights=2000` draaien na de freeze. | M | nee (meten) |
| F5.3 | Besluit per afwijking | OPEN | Hangt aan F5.2. | Afwijkingentabel aan Dennis voorleggen. | M | ja (balans) |
| F5.4 | Levelcurve | OPEN | Niet gemeten na de recente wijzigingen. | Diepe Grot-run-tijden via de sim. | M | ja (bij afstellen) |
| F5.5 | Economie | OPEN | Niet gemeten. | CSV-modus tegen `shop_data.gd`. | M | ja (bij afstellen) |
| F5.6 | Classic tegenover Action | OPEN | `docs/ACTION_BALANCE_REPORT.md` bestaat, maar van vóór F1/F2 (#450, #472). `ACTION_BOSS_MULT` bestaat niet meer. | `--actionsim` opnieuw draaien. | M | ja (bij afstellen) |
| F5.7 | Zelfde seed opnieuw als bewijs | NIET TE CHECKEN | Procesregel. | | | |
| F5.8 | Balans-suites groen | KLAAR | `battlesimtest`, `balansarchief1test`, `wm1balanstest`, `dungeon100schaaltest`, `autotest`, `woudtest`, `archief2test` in CI; #476 groen. | | | |

**Gate fase 5:** OPEN.

## Fase 6: UX-polish

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F6.1 | Uitrusting-tutorial (mantel) | NIET TE CHECKEN | Handmatig. Deels: `uxtest`. | | | |
| F6.2 | Inktwurm- en vang-tutorial | KLAAR | `tutorialtest` in CI; tekstfix #367. | | | |
| F6.3 | Uitleg RUN/partywissel/winkels/Warp | OPEN | Alleen opslaan is uitgelegd (#388). Over de rest is geen besluit genoteerd. | Dennis beslist per onderwerp of de bestaande tekst volstaat (geen nieuwe tutorial, lock §4). | S | ja (tekst/scope) |
| F6.4 | Titelknoppen volgens H11 | KLAAR | `wm1releasetest` (titel); #398 (testknoppen achter vlag); `rcchecktest`. | | | |
| F6.5 | Veldmenu met één duim, Android-terug | NIET TE CHECKEN | Eén duim: toestel. Wel gedekt: `menutest`, `androidbacktest` (#451). | | | |
| F6.6 | Melding "warp hub cannot be reached yet" | KLAAR | `scripts/ui/field_menu.gd`; `menutest`. | | | |
| F6.7 | Bevestiging bij opslaan/laden | KLAAR | #388 (uitleg + grijze Save-knop), #391 (autosave per slot). De beleving zelf hoort in de playtest. | | | |
| F6.8 | Quest Log | KLAAR | `questtest`; titel zijopdracht Engels (H7). | | | |
| F6.9 | Punten uit H7 | KLAAR | Geen van de H7-strings komt nog voor in `scripts/`, `world_warper/` of `pvp/` (grep 15 nov). | | | |
| F6.10 | Volledige sweep op Nederlandse tekst | KLAAR | `rg`-sweep: 79 treffers buiten tests. Allemaal intern (validatiemeldingen, nodenamen, redencodes zoals `"niet nu"` in `kern_kracht_veld.gd:84`). Verder #386 (localisatie-guard) en `[TEKST]`-checks in `wm1playthroughtest`. | | | |
| F6.11 | Namenlijst | OPEN | `namen_engels.md` staat nergens in de repo (`docs/BACKLOG_WM1.md:82`, A5). | Dennis levert de lijst of verklaart CANON voldoende. | S | ja (tekst) |
| F6.12 | Afkapping in ballonnen en menu's | NIET TE CHECKEN | Handmatig. Deels: `uipolishtest` (753), #434. | | | |
| F6.13 | Tekst van Dennis (H8, ECHO) | OPEN | `WM1_PLAYTEST.md:200`: de ECHO-zinnen zijn nog door de agent geschreven. In `story_data.gd` staan 5 `TODO(verhaal)`-notities (ingekorte tekst, regels 8-291). | Dennis keurt de tekst goed of levert eigen tekst. | M | ja (tekst) |
| F6.14 | Tikdoelen ≥ 48 dp | OPEN | #466 (F6-2: tikvlak ≥ `TOUCH_MIN`) staat open. Meten op het toestel is nog niet gedaan. | #466 reviewen en mergen, daarna op de S25 nameten. | S | nee (Forge review) |
| F6.15 | RUN-knop in elke kamersoort | OPEN | `hudtest` deel D dekt veld, dorp, hub-hal en wereldkaart. Kerker, Rest Room en Koopman niet (backlog A11). | Nieuwe kleine suite voor die drie kamersoorten (hudtest niet aanpassen). | S | nee |
| F6.16 | Joystick, ringmenu, Codex-knop | KLAAR | `hudtest` deel D/G (geen D-pad, zo bedoeld). | | | |
| F6.17 | Veilige zone | OPEN | #465 (World Warper/Rustkamer) en #467 (Settings) staan open. Al gemerged: #463. | Reviewen en mergen, daarna op toestel met notch kijken. | S | nee (Forge review) |
| F6.18 | Multitouch, rotatie, achtergrond, vergrendelen | NIET TE CHECKEN | Toestel. Deels: `lifecycletest`, `savestresstest` deel C. | | | |
| F6.19 | Video overslaan en vangnet | KLAAR | `scripts/data/cutscene_videos.gd:2-3`, `worldmap_cutscene.gd:30`; `cutscenetest`, #442/#447; `rcchecktest` (alle 13 filmpjes hebben een bestand). | | | |
| F6.20 | Juiste track per kaart | KLAAR | `musictest`, `muziektest` in CI. | | | |
| F6.21 | Ontbrekende BGM stil (H9) | KLAAR | 11 tracks zonder bestand. Geen ervan wordt in WM1-code aangeroepen (`FINISH_LOG.md` R2; grep 15 nov). Het manifest is niet gesnoeid (LAUNCH_PLAN stap 4), maar dat is niet nodig. | | | |
| F6.22 | Volume, mute, stoppen bij focusverlies | KLAAR | `muziektest`/`musictest` (schuiven, mute); `lifecycletest` deel B (geluid bij pauze). | | | |
| F6.23 | Placeholder-SFX | OPEN | `rcchecktest` [F6.23]: 162 + 120 placeholderregels; `gen_sfx.py` nog nooit gedraaid. | Zie top 5 #5. | L / S | ja (audio) |
| F6.24 | World Warper-cues zonder fout | OPEN | `ww_ambient`, `ww_hum`, `ww_warp` en `ww_sapientia_glitch` staan niet in het manifest. Gevolg: geen crash, wel één `push_error` per cue (`audio_manager.gd:252`, via `world_warper/flow/hub_boot.gd:51-142`). `rcchecktest` [F6.24]. | Optie a: de 4 cues zonder bestand in het manifest zetten (ontbrekend bestand = stil, zonder error). Optie b: bewust accepteren. | S | ja (audio, lock H9) |

**Gate fase 6:** OPEN.

## Fase 7: Playtest en fixronde

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F7.1 | Playtest-APK | OPEN | Laatste `build-apk` op `finish/wm1`: `5cb270c` (debug, 5 nov). Daarna zijn er 72 PR's gemerged. | Forge bouwt een debug-APK van de huidige head (bestaande workflow). | S | nee |
| F7.2 | Dennis speelt de golden path | OPEN | Kolom "Dennis" in de scorekaart (`FINISH_LOG.md`) is leeg. Zie top 5 #1. | Eén ronde volgens `WM1_PLAYTEST.md`. | L | ja |
| F7.3 | Bugs als issue | NIET TE CHECKEN | Procesregel. Nu 0 open issues met label `bug`. | | | |
| F7.4 | Ernst P0-P3 | NIET TE CHECKEN | Definitie, procesregel. | | | |
| F7.5 | Triage | NIET TE CHECKEN | Proces; er is nog niets te triëren. | | | |
| F7.6 | Fixronde per branch | NIET TE CHECKEN | Proces; label `wm1-bugfix` bestaat. | | | |
| F7.7 | Suites na fix-batch | NIET TE CHECKEN | Proces (CI op PR). | | | |
| F7.8 | Tweede playtest | OPEN | Hangt aan F7.2. | Plannen na de fixronde, uiterlijk 19 nov voor de RC van 20 nov. | M | ja |

**Gate fase 7:** OPEN.

## Fase 8: Release candidate

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F8.1 | Versie kiezen en overal gelijk | KLAAR | Besluit Dennis 15 nov: 0.21 / 23. Gezet met `bump_version set 0.21 --code 23` in versiebron, `project.godot:15` en alle 3 Android-presets; `bump_version --check` OK; `rcchecktest` [F8.1/F8.2] PASS; titelscherm leest `config/version` (`autotest`: label v0.21). Job 11, `release/wm1-rc-prep`. | Dennis kiest, Forge draait `bump_version minor`. | S | ja (versie) |
| F8.2 | `version/code` hoger dan de vorige build | KLAAR | `rcchecktest` [F8.2]: code 23 > 22 (v0.20), PASS. | Komt mee met F8.1. | S | nee (Forge) |
| F8.3 | Changelog | OPEN | Kop `## [0.21] (RC) - 2026-11-15` staat erin (Job 11), met regels over versie, netwerkrechten en geaccepteerde placeholder-SFX. De rest is nog niet bijgewerkt: `CHANGELOG.md` bestaat (#365) maar is sinds #397 (9 nov) niet bijgewerkt. Ontbreekt o.a.: HD-2D, CS-09 tot CS-12, F1/F2/F4, launcher-icoon. "Bekend (WM1-release)" zegt dat H3-kamers "achter de Diepe Grot-levels" zitten, maar `hub_cut` houdt ze dicht (`release_flags.gd:4`). Ook de regel over placeholder-art in Archief 2/World Warper is verouderd (`placeholders_v17.txt`: VERVANGEN v0.21). | Forge werkt Unreleased + Bekend bij, met de known issues uit deze audit. | M | nee (Forge) |
| F8.4 | README en BUILDS kloppen | OPEN | `rcchecktest` [F8.4]: README noemt 0.21 nergens, wel "versie 0.13 (code 15)" (`README.md:426`). | Forge werkt beide bij. | S | nee (Forge) |
| F8.5 | CI groen op de RC-commit | OPEN | Zie top 5 #4. | | S | ja (bij workflow-optie) |
| F8.6 | Release-APK met secrets | OPEN | Zie top 5 #3. Of de secrets bestaan, kan deze sessie niet zien (Actions-API afgeschermd). | | S | nee |
| F8.7 | `apksigner` / `aapt` | NIET TE CHECKEN | Er is nog geen release-APK. | | | |
| F8.8 | Rechten passen bij H11 | KLAAR | Besluit Dennis 15 nov: uit. `internet`, `access_network_state`, `access_wifi_state` en `change_wifi_multicast_state` staan op `false` in alle Android-presets (`export_presets.cfg:60-63,131-134,244-247`). `rcchecktest` [F8.8] PASS: geen netwerkrecht aan, `online_cut` aan, PvP/Co-op-knop verborgen (`title_screen.gd:384-390`). Solo raakt geen netwerkcode: `scripts/net/` en `pvp/` worden alleen geopend via die twee knoppen (`title_screen.gd:560-567`). `coophosttest` en `aabtest` volgen nu `online_cut`. | Besluit: online blijft dicht voor de RC, dus de rechten uit. Forge past de presets aan. | S | ja (H11) |
| F8.9 | Installatietest S25 | NIET TE CHECKEN | Toestel. | | | |
| F8.10 | Rookroute op de RC-APK | NIET TE CHECKEN | Toestel. | | | |
| F8.11 | Repo-hygiëne, signing-velden leeg | KLAAR | `rcchecktest` (alle `keystore/*` leeg; `.gitignore`); `git ls-files` schoon. Op de RC-commit opnieuw draaien. | | | |
| F8.12 | Tag `v<versie>-rc1` + artifact bewaren | OPEN | Tag bestaat nog niet. | Forge tagt na F8.5/F8.6. Artifact binnen 14 dagen downloaden. | S | nee |
| F8.13 | Dennis: go of no-go | NIET TE CHECKEN | Eindbeslissing, na de RC. | | | |
| F8.14 | Na go: tag en release-notities | NIET TE CHECKEN | Na de RC; publicatie valt buiten deze klus. | | | |

**Gate fase 8:** OPEN.

### Niet in de checklist, wel van belang vóór Play (FACT)

- Pakketnaam: nu `com.dennis.rpgprototype` (alle presets gelijk, `rcchecktest`). Het voorstel `com.eazydstudio.sapientia` is nog niet besloten
  (`STORE_LISTING.md`, OVERDRACHT §3). Voor de interne RC geen probleem; vóór de eerste Play-upload is dit wel een besluit van Dennis.
- `codex_tutorial_autotest.gd` staat in `scripts/tests/`, maar heeft geen vlag in `game_state.gd`. ONVERIFIED of hij via een andere suite draait.

---

## Suite `--rcchecktest`

`scripts/tests/rc_check_tests.gd`, geregistreerd in `scripts/game_state.gd`. Nog **niet** in `tests.yml`: dat doet Forge na akkoord van Dennis.

Wat de suite controleert (alleen lezen):
- Versie: versiebron == `project.godot` == elke Android-preset (`version/name`, `version/code`).
- Export: exclude-filters in alle presets, signing-velden leeg, arm64-v8a aan, pakketnaam gelijk, `wacht/.gdignore`, `.gitignore`-regels.
- Project: hoofdscène, autoloads, verplichte scènes, 384x216, gl_compatibility, 60 fps, liggend; elk WM1-filmpje heeft een bestand.
- Releasevlaggen: `hub_cut`, `online_cut`, geen testhaken aan, relay-URL leeg, testmenu en `--testmenu` dicht in release,
  dev-kamers geblokkeerd en sessielog uit in release.
- Debugtoetsen in `map.gd` alleen achter `is_debug_build()` / `dev_rooms_allowed()`.
- Elke `--suite` in `game_state.gd` wijst naar code buiten de export.
- ENABLED-vlaggen: elke `*ENABLED`-constante in `scripts/`, `world_warper/` en `pvp/` die `true` is, moet op de lijst staan van
  features die meegaan (nu `som_data.gd` en `som_feel_data.gd`). F1 perfect dodge staat uit.

**Bekende OPEN-punten** komen als `OPEN  [id] ...` in de uitvoer. Die tellen niet als `FAIL`, zodat de suite groen kan blijven
terwijl de bevinding zichtbaar is. Gaat zo'n punt dicht, dan wordt het een `PASS` met de melding dat dit rapport bijgewerkt moet
worden. Nu verwacht: [F8.2], [F8.4], [F8.8], [F6.23], [F6.23b], [F6.24] en [F2.5].

Waarom deze keuze: een rode suite in CI zou elke PR blokkeren voor punten die alleen Forge of Dennis kan oplossen
(versie, presets, audio). Een stille suite zou de bevinding verbergen. Met `OPEN` blijft het zichtbaar in de log en in dit rapport,
en een echte regressie (bijv. een signing-veld gevuld of een feature-vlag aan) blijft een `FAIL`.
