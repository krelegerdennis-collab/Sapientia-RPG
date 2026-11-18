# RC-audit WM1: checklist tegen de code (klus 10)

Doel: vaststellen wat er vóór de interne RC (F8, uiterlijk 20 nov 2026, **niet publiceren**) nog moet gebeuren.
Er is **niets gerepareerd**: alleen gelezen, geteld en gemeten.

- Basis: `finish/wm1` op `f76aa715` (tag `wm1-freeze`, 17-11-2026). Huidige freeze is `wm1-freeze3` (zie Freeze 3).
  Checklist: `docs/release/WM1_RELEASE_CHECKLIST.md` (93 punten).
  Historisch: de eerste audit (klus 10) stond op `0fb6334` (#476, 15 nov 2026). Klus 19 (17 nov 2026, middag) liep na op `d8a38e41` (#508); sinds klus 18 toen gemerged: #502-#508
  (o.a. #506 placeholders Wilgendal, #507 drie suites in CI, #508 balansmeting `WM1_BALANCE_REPORT_RC.md`). Eerder nog #465-#501.
- **Bijgewerkt (freeze-ronde, 17-11-2026):** lock-cijfers herteld op `f76aa715` in #517 (merge `e7f33011`). F1.6 is daarmee KLAAR.
  GitHub (labels, tags, issues, check-runs, Actions) was in sessie klus 18 niet bereikbaar; regels die daarop leunen staan waar nodig
  als ONVERIFIED.
- Bronnen: code en data in de repo, GitHub REST (labels, tags, issues, PR's, check-runs), `tools/art_audit/palet_check.py` (alleen lezen).
- Automatische controles staan in de nieuwe suite `--rcchecktest` (`scripts/tests/rc_check_tests.gd`). Bekende OPEN-punten
  geven daar een regel `OPEN  [id] ...` en maken de suite niet rood (zie onderaan).
- Statussen: **KLAAR** (bewijs in code, suite of PR), **KLAAR (meting)** en **KLAAR (tussenmeting)** (tel mee als KLAAR in de voortgangstabellen),
  **OPEN** (er mist iets), **NIET TE CHECKEN** (handmatig, op toestel of proces).
- Grootte: S (uren), M (een dag), L (meerdere dagen of afhankelijk van een ander). "Ja Dennis" = vraagt een besluit over balans,
  nieuwe mechanic, bestaande test, workflow of publicatie (of een ander besluit dat alleen Dennis neemt; dat staat erbij).

## Freeze 2

Tag `wm1-freeze` (commit `f76aa715`) blijft zoals hij is.

- Tag `wm1-freeze2` (annotated tag-object `fa723ca4`) op commit `961101acb98de40daea50077c495f79082ca8a09`.
  Tag-object volledig `fa723ca4d173763b14851264a1c82d0c822fc992`, tagger RPG Forge, 18-11-2026. Niet publiceren.
- Inhoud: F2.2-paletfix af. #538 (`12_assets_ui`), #540 (`10_assets_sprites`, inclusief dambord-voetschaduw;
  `DORP_SPRITES` 2950/3184, akkoord Dennis 17-11 20:18 via RPG Forge), #541 (`06_assets_hd2d`, `light_soft_128` Bayer 8x8).
  F6 safe-area: #533, #534, #535, #536 en #537. #539 dicht de `step_dir`-testrace (F3.2).
- F3.2 op `961101ac`: 591 PASS / 0 FAIL, twee keer serieel gedraaid. Rapporten blijven op de build-box:
  `F3_2_playthrough_961101a_run1.txt` en `run2.txt`. Niet in de repo.
- Debug-APK v0.21, versionCode 23, alleen **arm64-v8a**, gebouwd door RPG Forge. Niet gepubliceerd.

## Freeze 3

Huidige freeze voor de interne RC. Freeze 2 en tag `wm1-freeze` blijven staan.

- Tag `wm1-freeze3` (annotated tag-object `a072e034`) op commit `fcb3f21e80e3346a468a521781085e6167ad5b69`
  (`fcb3f21e`, head van `finish/wm1`), tagger RPG Forge, 18-11-2026. Niet publiceren.
- Inhoud na freeze 2: F5.3 combat #544 (merge `63012138`, Golem Action-ATK 27) en #549 (merge `fcb3f21e`, Seren 405/36).
  F6-T01 t/m F6-T03: #546 (merge `0132a8be`), #547 (merge `2258429d`), #548 (merge `6f1ec479`); F6-T04+T05: #545 (merge `325a0105`).
- F3.2 op `fcb3f21e`: `RESULT OK (591 goed, 0 fouten)`, twee keer serieel gedraaid. Rapporten op de build-box:
  `/workspace/f3/F3_2_playthrough_fcb3f21_run1.txt` en `F3_2_playthrough_fcb3f21_run2.txt`. Niet in de repo.
- Debug-APK `sapientia-wm1-freeze3-fcb3f21-debug.apk`, v0.21, versionCode 23, **arm64-v8a en armeabi-v7a**, gebouwd door RPG Forge. Niet gepubliceerd (APK niet in de repo).
- Nog open: installeren op de Samsung S25 (F7.1), Dennis' HD-2D-oogcheck. F6.23 placeholder-SFX blijft een bekend open punt
  (geen blocker).

## Samenvatting

| Status | Aantal |
|---|---:|
| KLAAR | 51 |
| OPEN | 14 |
| NIET TE CHECKEN | 28 |
| **Totaal** | **93** |

Voortgang per fase (telling van de detailrijen hieronder, freeze 3 op `fcb3f21e`; **KLAAR (meting)** en **KLAAR (tussenmeting)** tellen als KLAAR):

| Fase | KLAAR | OPEN | NIET TE CHECKEN | Gate |
|---|---:|---:|---:|---|
| 1 Freeze | 6 | 1 | 0 | OPEN |
| 2 Art op palet | 4 | 2 | 2 | OPEN |
| 3 Stabiliteit | 9 | 0 | 8 | OPEN |
| 4 S25-performance | 2 | 1 | 4 | OPEN |
| 5 Balans | 6 | 1 | 1 | OPEN |
| 6 UX-polish | 17 | 4 | 3 | OPEN |
| 7 Playtest en fixronde | 0 | 3 | 5 | OPEN |
| 8 Release candidate | 7 | 2 | 5 | OPEN |
| **Totaal** | **51** | **14** | **28** | |

Sinds de eerste audit (15 nov): F1.4, F1.5, F1.6, F1.7, F2.2, F2.5, F3.2, F3.9, F5.2, F5.3, F5.4, F5.5, F5.6, F6.3, F6.5, F6.14, F6.15, F6.17, F8.1, F8.2, F8.3, F8.4, F8.5 en F8.8 naar
KLAAR (F2.2/F5.2/F5.4/F5.5/F5.6 als KLAAR (meting)).

### OPEN op risico (voor de interne RC van 20 nov)

F1.6 is KLAAR via #517 en staat niet meer in deze lijst. Geen vervangend punt toegevoegd.

| # | Punt | Waarom risico | Voorstel | Grootte | Ja Dennis |
|---:|---|---|---|---|---|
| 1 | F7.2 Dennis' playtest | Scorekaart in `FINISH_LOG.md` heeft geen cijfers van Dennis; geen playtest-issues. Of er P0/P1 zijn, weet niemand. Gate fase 7 staat dus open. | Debug-APK v0.21, versionCode 23, commit `fcb3f21e` (tag `wm1-freeze3`, `sapientia-wm1-freeze3-fcb3f21-debug.apk`, arm64-v8a + armeabi-v7a, F7.1). Installatie op de S25 door Dennis blijft open. Eén ronde volgens `WM1_PLAYTEST.md`, bugs als issue met label `bug`. | L | ja (alleen Dennis kan spelen) |
| 2 | F8.6 Release-APK | `build-apk` heeft nog nooit met `build_type: release` gedraaid (laatste run op deze branch: debug, `5cb270c`, 5 nov). Of de signing-secrets er staan, kan deze sessie niet zien. Een ondertekende APK is de kern van de RC. | Forge doet nu een droge release-run op de huidige head. Dan blijkt meteen of de secrets kloppen, ruim voor 20 nov. | S | nee (bestaande workflow, interne build, niet publiceren) |
| 3 | F4.2 S25-meting | Geen S25-meting, alleen xvfb/llvmpipe in `docs/perf_wm1.md`. | Dennis meet met `adb dumpsys gfxinfo` op een debug-APK, of accepteert fase 4 bewust voor de interne RC. | M | ja (acceptatie) |
| 4 | F6.23 Placeholder-SFX | 162 regels in `tools/placeholders_algemene_sfx.txt` en 120 in `tools/placeholders_sfx.txt` (F6.23b). LAUNCH_PLAN B2 noemt dit een blocker. `gen_sfx.py` heeft nog nooit gedraaid (OVERDRACHT §4.3). Bekend open punt, geen RC-blocker (akkoord Dennis 17-11-2026 15:29 (kaart t890s5665)). | Vervangen blijft nodig voor de publieke release. | L (vervangen) / S (accepteren) | ja (audio-keuze) |

Daarnaast open: F5.1 (doelvensters; cijfers staan in `docs/release/WM1_BALANCE_REPORT_RC.md` §3) en
F6.24 (World Warper-cues: in spel stil via `ambience.gd`, manifest-/RC-besluit nog open; optie b wacht op Dennis).

### Verouderde tekst in de checklist

De onderstaande feitfouten stonden in `docs/release/WM1_RELEASE_CHECKLIST.md` en zijn in PR **docs/f6-t04-t05** (F6-T05) gecorrigeerd:

- F8.1: preset en `project.godot` noemden 0.19/0.20; repo staat nu op 0.21 / code 23 (`tools/release/version.json`, `project.godot:15`, `export_presets.cfg:34-35,105-106,218-219`).
- F4.3/F4.5: 9 video's (30,46 MB) → 13 bestanden, 40.054.438 bytes in `assets/video/*.ogv`.
- F5.6: `SomData.ACTION_BOSS_MULT` verwijderd; Action-bazen via `BossCore.apply_boss` (`scripts/data/som_data.gd:6`).
- F6.16: D-pad bewust weg (joystick + knoppenrij).
- Voortgangstabel onderaan de checklist: bijgewerkt in klus 18 (status per fase met de telling uit dit rapport; akkoordkolom leeg gelaten); ongewijzigd in die PR.

---

## Fase 1: Freeze

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F1.1 | Lock reviewen en mergen | KLAAR | `docs/release/WM1_CONTENT_LOCK.md` staat op de branch; cuts doorgevoerd (CHANGELOG 24 okt; `scripts/data/release_flags.gd`). Het vakje zelf is niet afgevinkt. | | | |
| F1.2 | BESLIS-punten H3/H11/H13 | KLAAR | `release_flags.gd:13-24`; suite `wm1releasetest` | | | |
| F1.3 | Labels `wm1-*` | OPEN | Labels (REST): `wm1-bugfix` en `wm1-lock` bestaan. `wm1-polish`, `wm1-cut` en `wm1-vervanging` ontbreken. | Forge maakt de drie labels aan. | S | nee (Forge) |
| F1.4 | CI-matrix gelijk met `game_state.gd` | KLAAR | #361, #380, #400, #406, #449, #480, #488, #500; #507 (merge `060140df`) zette `blauwekisttest`, `bossnametest` en `dungeon100bossmaptest` in de matrix (Dennis akkoord 17-11 12:06). #514 zette `--combattick` in de matrix; de suite draait in CI sinds `f01ba40a`. Matrix nu 135 suites (`.github/workflows/tests.yml:24-42`), `relaytest` als eigen job. Buiten de matrix blijven perf/sim/benchmark en `wm1playthroughtest` (bewust, checklist). | | S | ja (workflow) |
| F1.5 | Baseline PASS-aantallen | KLAAR | Baseline: 140 checks groen op freeze 2 (incl. #521 `wmdeathtest`; PR #542, 140/140). Eerder 138/138 op `f76aa715` (draft-PR #515, `rc/wm1-freeze-ci`, gesloten zonder merge). `--combattick` draait in CI sinds #514. De tabel in `AGENTS.md` is van v0.18. | | S | nee |
| F1.6 | Lock-cijfers hertellen | KLAAR | #517 (merge `e7f33011`, https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/517) hertelde alle lock-cijfers op `f76aa715` (tag `wm1-freeze`) en schreef ze in `docs/release/WM1_CONTENT_LOCK.md`. Story-`EVENTS` is 62 (= 53 string-keys + 9 expressie-keys); de eerdere driftlijst noemde ten onrechte 58 vs 53. Overige rijen na die hertelling: kaartscènes 50 (48 speelroute, 2 dev; extra `leven_v2_leeszaal.tscn`, `woud_beek.tscn`), `ITEMS` 53 (`spreuk_grote_genezing`, `spreuk_vuurbal`, `spreuk_zonnevlam`), Codex 21/32 (`adermot`, `druipslak`, `steenluis` / `aderspark`, `koude_druppel`, `steenbeet`), `TODO(design\|verhaal)` zonder tests 51 (56 − 5 in `scripts/tests/`). Gelijk: `ENEMIES` 26, berggrot-`MONSTERS` 3, `BOSSES` 12 (10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 99), helden 5 (Dax, Vesper, Seren, Kael Voss, Orion), sleutelvoorwerpen 4, `EQUIPMENT` 85, blauwe-kist 36, `SPELLS` 81 (21/20/20/20), kern 2/1/2, opdrachten 7 (6 hoofd, 1 zij) / acts 6 (act 3-6 "later"), BGM 24/13, SFX 99/0. | | S | nee |
| F1.7 | Tag `wm1-freeze` | KLAAR | Tag `wm1-freeze` op `finish/wm1` commit `f76aa7150f23385d47c630e54179e26ac1ba2cb8` (`f76aa715`), akkoord Dennis 17-11-2026 15:25 (kaart t890s5659); tag `wm1-freeze2` op `961101ac`; huidige freeze is `wm1-freeze3` (tag-object `a072e034`) op `fcb3f21e` (zie Freeze 3). Debug-APK freeze 3: beide ABI's (arm64-v8a en armeabi-v7a). Tags blijven staan. | | S | ja (scope) |

## Fase 2: Art op palet

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F2.1 | Masterpalet vastgelegd | KLAAR | `docs/art/masterpalet.gpl`; #366; CI-job `palet-check` | | | |
| F2.2 | Alle PNG's meten | KLAAR (meting) | Batches geleverd: #538 (`12_assets_ui`), #540 (`10_assets_sprites`), #541 (`06_assets_hd2d`). `palet_check.py --streng` op deze boom (gelijk aan `finish/wm1` `961101ac`): `assets/ui` 364/364 schoon, `assets/sprites` 595/595, `assets/hd2d` 219/219 met `--negeer '**/*_n.png'` (453 genegeerd). Dennis' HD-2D-oogcheck blijft open. | | M | ja (oogcheck) |
| F2.3 | CSV filteren op WM1 | OPEN | F2.2 is KLAAR (meting): `palet_check.py --streng` op `assets/ui` 364/364, `assets/sprites` 595/595, `assets/hd2d` 219/219 met `--negeer '**/*_n.png'` (453 genegeerd). De CSV-filter op de lock-inventaris staat niet in dit rapport. Dennis' HD-2D-oogcheck blijft open. | Filteren op de lock-inventaris (kaarten, NPC's, vijanden, items, cutscenes, UI, hub; WM2/WM3 valt af). | M | nee |
| F2.4 | RPG ART levert batches | OPEN | Geleverd: #369-#372, #379, #381, #403, #411, #412, en freeze2 #538 (`12_assets_ui`), #540 (`10_assets_sprites`, akkoord Dennis 17-11 20:18), #541 (`06_assets_hd2d`). Verder akkoord per batch staat niet in dit rapport. Dennis' HD-2D-oogcheck blijft open. | ART per batch, met akkoord van Dennis. | L | ja (art-akkoord) |
| F2.5 | Placeholders in de route (H10) | KLAAR | Rustpunt #375, Blauwe Kist #378 en uitgang-warper #381 zijn klaar. #506 (merge `70f6743c`) haalde 12 dubbele Wilgendal-regels uit `tools/placeholders_v17.txt`; 0 open regels (`rcchecktest` [F2.5] PASS). Het Action-HUD (slagboog, meters, ringmenu) wordt in code getekend en is niet beoordeeld — bewuste kanttekening, geen open placeholder-regel. | | S | ja (bewust laten staan) |
| F2.6 | Ontbrekende art melden in PR | NIET TE CHECKEN | Procesregel. | | | |
| F2.7 | Suites na elke batch | KLAAR | CI draait alle suites op elke PR. Laatste art-PR's waren groen (bijv. #476: 122/122). | | | |
| F2.8 | Screenshots voor/na | NIET TE CHECKEN | Handmatig. | | | |

**Gate fase 2:** OPEN (F2.2-meting schoon: `palet_check.py --streng` `assets/ui` 364/364, `assets/sprites` 595/595, `assets/hd2d` 219/219, 453 `*_n.png` genegeerd; Dennis' HD-2D-oogcheck blijft open).

## Fase 3: Stabiliteit

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F3.1 | Verse import zonder fouten | NIET TE CHECKEN | Er is geen Godot in deze sessie. CI importeert bij elke run, maar faalt niet op import-warnings. | Dennis draait lokaal `--import` en leest de uitvoer. | | |
| F3.2 | Alle suites groen op de freeze-commit | KLAAR | Op freeze-commit `f76aa715` (tag `wm1-freeze`): `--wm1playthroughtest` na een verse `--import` **591 PASS / 0 FAIL / 0 SCRIPT ERRORs**. Rapport `/workspace/f3/F3_2_playthrough_f76aa71.txt` (box van het team, niet in de repo). Freeze 2 op `961101ac`: 591 PASS / 0 FAIL, twee keer serieel (`F3_2_playthrough_961101a_run1.txt` en `run2.txt`, build-box, niet in de repo). Freeze 3 op `fcb3f21e`: **591 PASS / 0 FAIL**, twee keer serieel (`RESULT OK (591 goed, 0 fouten)` in `/workspace/f3/F3_2_playthrough_fcb3f21_run1.txt` en `run2.txt`, build-box, niet in de repo). | | S | nee |
| F3.3 | Geen `SCRIPT ERROR` | KLAAR | `.github/scripts/run_suite.sh:25,30-33` faalt erop; #476 groen. | | | |
| F3.4 | Golden path route A en B | NIET TE CHECKEN | Handmatig. Deels gedekt door `wm1playthroughtest` (kas en berggrot, niet in CI). | | | |
| F3.5 | Terugweg Archief 2 (H14) | NIET TE CHECKEN | Handmatig. `archief2test` raakt `leven_v1_plaat`. | | | |
| F3.6 | Archief 2 zonder Vesper (H17) | NIET TE CHECKEN | Handmatig. Deels: `kasdeurtest`, `archieftest`. | | | |
| F3.7 | Golem Hall-varianten | NIET TE CHECKEN | Handmatig. Deels: `codextest`, `wm1playthroughtest`. | | | |
| F3.8 | Zingend Graan | NIET TE CHECKEN | Handmatig. Deels: `woudtest`, `uxtest`, #363. | | | |
| F3.9 | Game over bij elke baas | KLAAR | `checkpointtest` deel D/E (Golem, Root King); `--bossrespawntest` (#497) dekt respawn bij The Strangler en The Mender (Archief 2); sinds #500 in de CI-matrix. | | | |
| F3.10 | Save/load, autosave, oude saves | KLAAR | `savetest`, `savefuzztest`, `saveroundtriptest`, `saverobusttest`, `savehardeningtest`, `savestresstest` (#469), autosave per slot #391, versie-guard #392; allemaal in CI. | | | |
| F3.11 | Hub-checks | NIET TE CHECKEN | Handmatig. Deels: `warperkamertest`, `echotest`, `wm1releasetest`. | | | |
| F3.12 | Diepe Grot | KLAAR | `dungeon100gentest`/`schaaltest`/`regelstest`/`integratietest`/`blauwtest`/`rustpunttest`, `koopmantest`; allemaal in CI. | | | |
| F3.13 | Classic en Action per kerker | NIET TE CHECKEN | Handmatig. Deels: `somroomstest`. | | | |
| F3.14 | H1/H2 dicht, F3/F4 alleen debug | KLAAR | `wm1releasetest`; `scripts/map.gd:331,336,342`; `rcchecktest` (debugtoetsen + dev-kamers in release). | | | |
| F3.15 | `wacht/` en tools/docs/tests niet in export | KLAAR | `wacht/.gdignore`; `export_presets.cfg:11,82,153,195`; `rcchecktest` (alle 4 presets, en elke `--suite` in `game_state.gd` wijst buiten de export). | | | |
| F3.16 | Repo-hygiëne | KLAAR | `git ls-files` op `0fb6334` en opnieuw op `9a87280` (17 nov) geeft niets voor apk/aab/jks/keystore/uid/.env; `.gitignore` dekt ze (`rcchecktest`). | | | |
| F3.17 | `build-web` groen op `main` | KLAAR | Run op `main` `db0aa04` (9 nov): success. | | | |

**Gate fase 3:** OPEN (routes niet handmatig gespeeld).

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
| F5.2 | Volledig rapport op de freeze-commit | KLAAR (meting) | Op `f76aa715` draaide RPG COMBAT `--battlesim --seed=20261020 --fights=2000`. Alle rijen gelijk aan `docs/release/WM1_BALANCE_REPORT_RC.md` §3.1; het rapport is byte-gelijk aan `docs/BATTLE_BALANCE_REPORT.md` op de looptijd in de kop na. Bestanden `/workspace/combat/f52/sim_f76aa71.txt` en `.json` (box van het team, niet in de repo). Wortelkoning 28% staat zo in §3.1 en wacht op F5.3 / §7. | | M | nee (meten) |
| F5.3 | Besluit per afwijking | KLAAR | Dennis 18-11-2026, `docs/combat/f53_beslissingen.md` (#549). **A1** nee: Wortelkoning baas-ATK blijft **38** (`ENEMIES.wortelkoning.boss`, power scaling v2 #208). **A4** ja: Golem Action-ATK 27, Classic ongewijzigd (#544, merge `63012138`). **A8** ja: Seren (`lotte_glitch.boss`) HP 405 / ATK 36 (#549, merge `fcb3f21e`). **A2, A9, A10:** nee (geen wijziging). **A3, A5, A6, A7, A11, A12, A13, A14:** bewust zo gelaten (zoals voorgesteld in `WM1_BALANCE_REPORT_RC.md` §7). | | M | ja (balans) |
| F5.4 | Levelcurve | KLAAR (meting) | `docs/release/WM1_BALANCE_REPORT_RC.md` §4: per level gevechten en minuten (aanname 5 s/ronde); Golem bereikt op Lv 7 (ontwerp 8), eind Lv 15; 67 verplichte gevechten. A14 bewust: in-game levels zijn het doel (geen data-wijziging). | Diepe Grot-run-tijden via de sim. | M | ja (bij afstellen) |
| F5.5 | Economie | KLAAR (meting) | `docs/release/WM1_BALANCE_REPORT_RC.md` §5: goud per gebied tegenover `shop_data.gd`; alleen monstergoud, kisten geven items. Pakket overal betaalbaar behalve de eerste 70 g (startgoud 0). | CSV-modus tegen `shop_data.gd`. | M | ja (bij afstellen) |
| F5.6 | Classic tegenover Action | KLAAR (meting) | `docs/release/WM1_BALANCE_REPORT_RC.md` §6: `--actionsim` opnieuw (perfect dodge uit): 13,9% HP per kamer (was 11,1%); Classic op dezelfde kamers ≤ 1,7% per gevecht (`tools/battlesim/rc_classic_som.gd`); realtime Golem Lv 7 was 98,5% vóór F5.3 A4 (#544: Action-ATK 27 → ~72% winst, doel 60–80%). Stagger (#450) zit niet in de sim. | `--actionsim` opnieuw draaien. | M | ja (bij afstellen) |
| F5.7 | Zelfde seed opnieuw als bewijs | NIET TE CHECKEN | Procesregel. | | | |
| F5.8 | Balans-suites groen | KLAAR | `battlesimtest`, `balansarchief1test`, `wm1balanstest`, `dungeon100schaaltest`, `autotest`, `woudtest`, `archief2test` in CI; #476 groen. | | | |

**Gate fase 5:** OPEN.

## Fase 6: UX-polish

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F6.1 | Uitrusting-tutorial (mantel) | NIET TE CHECKEN | Handmatig. Deels: `uxtest`. | | | |
| F6.2 | Inktwurm- en vang-tutorial | KLAAR | `tutorialtest` in CI; tekstfix #367. | | | |
| F6.3 | Uitleg RUN/partywissel/winkels/Warp | KLAAR | #551 (merge `c1ded179`, https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/551): de 9 door Dennis goedgekeurde teksten staan exact in de code (RUN-uitleg eenmalig, partywissel, winkels, Warp-uitleg eenmalig). De RUN- en Warp-uitlegvlag wordt pas gezet na lezen of sluiten. Opslaan was al uitgelegd (#388). `f6uxtest2` (`f6_ux2/f6_17_uitleg_texts.gd`) in CI. | | S | |
| F6.4 | Titelknoppen volgens H11 | KLAAR | `wm1releasetest` (titel); #398 (testknoppen achter vlag); `rcchecktest`. | | | |
| F6.5 | Veldmenu met één duim, Android-terug | KLAAR | F6-T01 #546 (merge `0132a8be`, Android-back sluit save-slotlijst), F6-T02 #547 (merge `2258429d`, hub Warp/Party boven joystick), F6-T03 #548 (merge `6f1ec479`, hub Android-terug); F6-T04+T05 #545 (checklist-feiten). `f6uxtest2` (`f6_10_back_slotlist.gd`, `f6_11_hub_touch.gd`, `f6_12_hub_back.gd`) in CI; eerder `menutest`, `androidbacktest` (#451), rij-tikvlakken #466. Nameten op de S25 gaat mee in de playtest (F7.2). | | | |
| F6.6 | Melding "warp hub cannot be reached yet" | KLAAR | `scripts/ui/field_menu.gd`; `menutest`. | | | |
| F6.7 | Bevestiging bij opslaan/laden | KLAAR | #388 (uitleg + grijze Save-knop), #391 (autosave per slot). De beleving zelf hoort in de playtest. | | | |
| F6.8 | Quest Log | KLAAR | `questtest`; titel zijopdracht Engels (H7). | | | |
| F6.9 | Punten uit H7 | KLAAR | Geen van de H7-strings komt nog voor in `scripts/`, `world_warper/` of `pvp/` (grep 15 nov). | | | |
| F6.10 | Volledige sweep op Nederlandse tekst | KLAAR | `rg`-sweep: 79 treffers buiten tests. Allemaal intern (validatiemeldingen, nodenamen, redencodes zoals `"niet nu"` in `kern_kracht_veld.gd:84`). Verder #386 (localisatie-guard) en `[TEKST]`-checks in `wm1playthroughtest`. | | | |
| F6.11 | Namenlijst | OPEN | `namen_engels.md` staat nergens in de repo (`docs/BACKLOG_WM1.md:82`, A5). | Dennis levert de lijst of verklaart CANON voldoende. | S | ja (tekst) |
| F6.12 | Afkapping in ballonnen en menu's | NIET TE CHECKEN | Handmatig. Deels: `uipolishtest` (753), #434. | | | |
| F6.13 | Tekst van Dennis (H8, ECHO) | OPEN | `WM1_PLAYTEST.md:200`: de ECHO-zinnen zijn nog door de agent geschreven. In `story_data.gd` staan 5 `TODO(verhaal)`-notities (ingekorte tekst, regels 8-291). | Dennis keurt de tekst goed of levert eigen tekst. | M | ja (tekst) |
| F6.14 | Tikdoelen ≥ 48 dp | KLAAR | #466 gemerged: lijstregels in alle menu's krijgen een tikvlak ≥ `UiTouch.TOUCH_MIN` (`scripts/ui/touch_row.gd`, `touch_row_zones.gd`). `TOUCH_MIN` = 25 eenheden ≈ 47,7 dp op 412 dp (`uxtest` controleert ≥ 47,5); `f6uxtest2` (`f6_ux2/f6_2_row_touch.gd`) in CI. Nameten op de S25 gaat mee in de playtest (F7.2). | | | |
| F6.15 | RUN-knop in elke kamersoort | KLAAR | `--runknoptest` (CI-matrix): kerker (`archief_ingang`), Rest Room en Koopman. `hudtest` deel D dekt veld, dorp, hub-hal en wereldkaart. De knop is aanwezig; geen codefix nodig. | | | |
| F6.16 | Joystick, ringmenu, Codex-knop | KLAAR | `hudtest` deel D/G (geen D-pad, zo bedoeld). | | | |
| F6.17 | Veilige zone | KLAAR | Gemerged: #463, #465 (World Warper Rustkamer/Party-select) en #467 (Settings General bij 16:9, 19,5:9 en notch). Gedekt door `f6uxtest2` (`f6_ux2/f6_5_warper_safe.gd`, `f6_1_options_general.gd`) in CI. Kijken op een toestel met notch gaat mee in de playtest (F7.2). | | | |
| F6.18 | Multitouch, rotatie, achtergrond, vergrendelen | NIET TE CHECKEN | Toestel. Deels: `lifecycletest`, `savestresstest` deel C. | | | |
| F6.19 | Video overslaan en vangnet | KLAAR | `scripts/data/cutscene_videos.gd:2-3`, `worldmap_cutscene.gd:30`; `cutscenetest`, #442/#447; `rcchecktest` (alle 13 filmpjes hebben een bestand). | | | |
| F6.20 | Juiste track per kaart | KLAAR | `musictest`, `muziektest` in CI. | | | |
| F6.21 | Ontbrekende BGM stil (H9) | KLAAR | 11 tracks zonder bestand. Geen ervan wordt in WM1-code aangeroepen (`FINISH_LOG.md` R2; grep 15 nov). Het manifest is niet gesnoeid (LAUNCH_PLAN stap 4), maar dat is niet nodig. | | | |
| F6.22 | Volume, mute, stoppen bij focusverlies | KLAAR | `muziektest`/`musictest` (schuiven, mute); `lifecycletest` deel B (geluid bij pauze). | | | |
| F6.23 | Placeholder-SFX | OPEN | `rcchecktest` [F6.23] en [F6.23b]: 162 + 120 placeholderregels; `gen_sfx.py` nog nooit gedraaid. Bekend open punt, geen RC-blocker (akkoord Dennis 17-11-2026 15:29 (kaart t890s5665)). | Zie OPEN-lijst #4. | L / S | ja (audio) |
| F6.24 | World Warper-cues zonder fout | OPEN | `ww_hum`, `ww_warp` en `ww_sapientia_glitch` staan niet in de `sfx` van het manifest (`ww_ambient` onder `bgm`, nageteld 17 nov). Enige speelpad: `world_warper/audio/ambience.gd:49-57` (`_play_sfx`): bij ontbrekende cue controleert `has_sfx` en keert stil terug (sinds `828e1497`); geen `push_error` in de hub. Rechtstreekse `AudioManager.play_sfx` zou bij onbekende naam `audio_manager.gd:252` (`_report` → `push_error`) aanroepen; geen andere `play_sfx`-aanroep met deze drie namen. `rcchecktest` [F6.24] OPEN: meldingstekst nog «push_error per cue», verouderd t.o.v. `ambience.gd`; bestaande test niet gewijzigd. | Optie a: cues **met** platte `.wav` in het manifest (lege/ontbrekende placeholders falen in CI-job `algemene-sfx`: `tools/check_algemene_sfx.py` ontbrekend bestand `:95-96`, stil `rms<0.02` `:129-130`, geen `.import` `:139-141`). Optie b: bewust stil accepteren voor RC — besluit naar Dennis via RPG Forge; hier niet als besloten markeren. | S | ja (audio, lock H9) |

**Gate fase 6:** OPEN.

## Fase 7: Playtest en fixronde

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F7.1 | Playtest-APK | OPEN | Debug-APK v0.21, versionCode 23, commit `fcb3f21e` (tag `wm1-freeze3`, bestand `sapientia-wm1-freeze3-fcb3f21-debug.apk`, arm64-v8a en armeabi-v7a), gebouwd door RPG Forge. Niet gepubliceerd (Freeze 3). | Installatie op de Samsung S25 door Dennis. | S | nee |
| F7.2 | Dennis speelt de golden path | OPEN | Kolom "Dennis" in de scorekaart (`FINISH_LOG.md`) is leeg. Zie OPEN-lijst #1. | Eén ronde volgens `WM1_PLAYTEST.md`. | L | ja |
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
| F8.3 | Changelog | KLAAR | `[0.21]` in `CHANGELOG.md` dekt de merges op `finish/wm1` na #493 t/m #549 (één regel per PR, inclusief #516 t/m #549). `[Unreleased]` is leeg. | | S | nee |
| F8.4 | README en BUILDS kloppen | KLAAR | Klus 12: `README.md:8` noemt "Huidige versie: 0.21 (code 23)" met `tools/release/version.json` als enige bron; de Android-sectie (`README.md:427`) verwijst naar die bron in plaats van "versie 0.13 (code 15)". Historische (v0.xx)-notities blijven. `rcchecktest` [F8.4] wordt daarmee PASS. | | | |
| F8.5 | CI groen op de RC-commit | KLAAR | Optie a: draft-PR #515 (`rc/wm1-freeze-ci`, gesloten zonder merge) draaide de volledige CI-matrix op `wm1-freeze` `f76aa715`: 138/138 checks groen. Freeze 2: 140 checks (incl. #521 `wmdeathtest`); PR #542 140/140 groen. | | S | nee |
| F8.6 | Release-APK met secrets | OPEN | Zie OPEN-lijst #2. Of de secrets bestaan, kan deze sessie niet zien (Actions-API afgeschermd). | | S | nee |
| F8.7 | `apksigner` / `aapt` | NIET TE CHECKEN | Er is nog geen release-APK. | | | |
| F8.8 | Rechten passen bij H11 | KLAAR | Besluit Dennis 15 nov: uit. `internet`, `access_network_state`, `access_wifi_state` en `change_wifi_multicast_state` staan op `false` in alle Android-presets (`export_presets.cfg:60-63,131-134,244-247`). `rcchecktest` [F8.8] PASS: geen netwerkrecht aan, `online_cut` aan, PvP/Co-op-knop verborgen (`title_screen.gd:384-390`). Solo raakt geen netwerkcode: `scripts/net/` en `pvp/` worden alleen geopend via die twee knoppen (`title_screen.gd:560-567`). `coophosttest` en `aabtest` volgen nu `online_cut`. | Besluit: online blijft dicht voor de RC, dus de rechten uit. Forge past de presets aan. | S | ja (H11) |
| F8.9 | Installatietest S25 | NIET TE CHECKEN | Toestel. | | | |
| F8.10 | Rookroute op de RC-APK | NIET TE CHECKEN | Toestel. | | | |
| F8.11 | Repo-hygiëne, signing-velden leeg | KLAAR | `rcchecktest` (alle `keystore/*` leeg; `.gitignore`); `git ls-files` schoon (ook op `9a87280`, 17 nov). Op de RC-commit opnieuw draaien. | | | |
| F8.12 | Tag `v<versie>-rc1` + artifact bewaren | OPEN | Tag bestaat nog niet. | Forge tagt na F8.5/F8.6. Artifact binnen 14 dagen downloaden. | S | nee |
| F8.13 | Dennis: go of no-go | NIET TE CHECKEN | Eindbeslissing, na de RC. | | | |
| F8.14 | Na go: tag en release-notities | NIET TE CHECKEN | Na de RC; publicatie valt buiten deze klus. | | | |

**Gate fase 8:** OPEN.

### Niet in de checklist, wel van belang vóór Play (FACT)

- Pakketnaam: nu `com.dennis.rpgprototype` (alle presets gelijk, `rcchecktest`). Het voorstel `com.eazydstudio.sapientia` is nog niet besloten
  (`STORE_LISTING.md`, OVERDRACHT §3). Voor de interne RC geen probleem; vóór de eerste Play-upload is dit wel een besluit van Dennis.
- `codex_tutorial_autotest.gd` heeft geen eigen vlag in `game_state.gd`, maar draait wel: aan het eind van `--autotest` (`scripts/debug_autotest.gd:688`) en los via `--autotest -- --test-codex-tutorial` (`debug_autotest.gd:599-602`). Opgelost (was ONVERIFIED).

---

## Suite `--rcchecktest`

`scripts/tests/rc_check_tests.gd`, geregistreerd in `scripts/game_state.gd`. Draait in CI sinds #481 (akkoord Dennis): matrix in `.github/workflows/tests.yml`.

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
worden. Nu verwacht: [F6.23], [F6.23b], [F6.24]. [F6.23] en [F6.23b] blijven een bekend open punt, geen RC-blocker (akkoord Dennis 17-11-2026 15:29 (kaart t890s5665)). Dicht (PASS): [F2.5] sinds #506, [F8.2] en [F8.8] sinds Job 11 (#484), [F8.4] sinds Klus 12 (#493).
Statisch nageteld op 17 nov middag: sfx en WW-cues nog open (162 + 120 sfx-regels, 3 cues); placeholders-route is dicht.

Waarom deze keuze: een rode suite in CI zou elke PR blokkeren voor punten die alleen Forge of Dennis kan oplossen
(versie, presets, audio). Een stille suite zou de bevinding verbergen. Met `OPEN` blijft het zichtbaar in de log en in dit rapport,
en een echte regressie (bijv. een signing-veld gevuld of een feature-vlag aan) blijft een `FAIL`.
