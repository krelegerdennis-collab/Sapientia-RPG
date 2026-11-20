# RC-audit WM1: checklist tegen de code (klus 10)

Doel: vaststellen wat er vóór de interne RC (F8, uiterlijk 20 nov 2026, **niet publiceren**) nog moet gebeuren.
Er is **niets gerepareerd**: alleen gelezen, geteld en gemeten.

- Basis: `finish/wm1` op `f76aa715` (tag `wm1-freeze`, 17-11-2026). Huidige freeze is `wm1-freeze5` (zie Freeze 5).
  Checklist: `docs/release/WM1_RELEASE_CHECKLIST.md` (93 punten).
  Historisch: de eerste audit (klus 10) stond op `0fb6334` (#476, 15 nov 2026). Klus 19 (17 nov 2026, middag) liep na op `d8a38e41` (#508); sinds klus 18 toen gemerged: #502-#508
  (o.a. #506 placeholders Wilgendal, #507 drie suites in CI, #508 balansmeting `WM1_BALANCE_REPORT_RC.md`). Eerder nog #465-#501.
- **Bijgewerkt (freeze-ronde, 17-11-2026):** lock-cijfers herteld op `f76aa715` in #517 (merge `e7f33011`). F1.6 is daarmee KLAAR.
  GitHub (labels, tags, issues, check-runs, Actions) was in sessie klus 18 niet bereikbaar; regels die daarop leunen staan waar nodig
  als ONVERIFIED.
- Bronnen: code en data in de repo, GitHub REST (labels, tags, issues, PR's, check-runs), `tools/art_audit/palet_check.py` en `tools/art_audit/meet.py` (alleen lezen).
- Automatische controles staan in de nieuwe suite `--rcchecktest` (`scripts/tests/rc_check_tests.gd`). Bekende OPEN-punten
  geven daar een regel `OPEN  [id] ...` en maken de suite niet rood (zie onderaan).
- Statussen: **KLAAR** (bewijs in code, suite of PR), **KLAAR (meting)**, **KLAAR (tussenmeting)**, **KLAAR (besloten)** (besluit van Dennis, met tijd en bron) en
  **VERVALLEN voor RC1** (punt geldt niet voor RC1 door een besluit van Dennis) (tellen mee als KLAAR in de voortgangstabellen),
  **OPEN** (er mist iets), **NIET TE CHECKEN** (handmatig, op toestel of proces).
- Gate-status **KLAAR op N open punt(en) na**: de gate is gehaald op de genoemde open punten na. Dit is alleen een gate-status; de rijtellingen in de
  voortgangstabellen veranderen er niet door (de rijen zelf houden hun eigen status).
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

Snapshot van 18-11-2026. Freeze 2 en tag `wm1-freeze` blijven staan.

- Tag `wm1-freeze3` (annotated tag-object `a072e034`) op commit `fcb3f21e80e3346a468a521781085e6167ad5b69`
  (`fcb3f21e`, head van `finish/wm1`), tagger RPG Forge, 18-11-2026. Niet publiceren.
- Inhoud na freeze 2: F5.3 combat #544 (merge `63012138`, Golem Action-ATK 27) en #549 (merge `fcb3f21e`, Seren 405/36).
  F6-T01 t/m F6-T03: #546 (merge `0132a8be`), #547 (merge `2258429d`), #548 (merge `6f1ec479`); F6-T04+T05: #545 (merge `325a0105`).
- F3.2 op `fcb3f21e`: `RESULT OK (591 goed, 0 fouten)`, twee keer serieel gedraaid. Rapporten op de build-box:
  `/workspace/f3/F3_2_playthrough_fcb3f21_run1.txt` en `F3_2_playthrough_fcb3f21_run2.txt`. Niet in de repo.
- Debug-APK `sapientia-wm1-freeze3-fcb3f21-debug.apk`, v0.21, versionCode 23, **arm64-v8a en armeabi-v7a**, gebouwd door RPG Forge. Niet gepubliceerd (APK niet in de repo).
- Toen nog open: installeren op de Samsung S25 (F7.1), Dennis' HD-2D-oogcheck. F6.23 placeholder-SFX blijft een bekend open punt
  (geen blocker).

## Freeze 5

Huidige freeze voor de interne RC. Eerdere tags (`wm1-freeze` t/m `wm1-freeze4`) blijven staan.

- Tag `wm1-freeze5` (annotated tag-object `6611e218`) op commit `439ff805c071972548f30cb8bab17d6ac9b9648a`
  (`439ff805`, head van `finish/wm1`), tagger Dennis Kreleger, 19-11-2026 02:01 (Europe/Amsterdam). Niet publiceren.
- Inhoud na freeze 3: F6.3 uitlegteksten #551 (merge `c1ded179`); BATTLE_BALANCE_REPORT #552 (merge `a0783abb`, tevens tag `wm1-freeze4` op 18-11-2026 19:01, tagger RPG FORGE); RC-audit F6.3 #553 (merge `4e26c7e3`); F6.24 WW-sfx #554 (merge `83000372`) en RC-audit docs #555 (merge `439ff805`).
- F3.2 op `439ff805`: 591 PASS / 0 FAIL, twee keer serieel gedraaid (Forge, bij de freeze). Rapporten blijven op de build-box. Niet in de repo.
- Debug-APK `sapientia-wm1-freeze5-439ff80-debug.apk`, v0.21, versionCode 23, **arm64-v8a en armeabi-v7a**, gebouwd door RPG Forge. Niet gepubliceerd (APK niet in de repo).
- Nog open: installeren op de Samsung S25 (F7.1), Dennis' HD-2D-oogcheck. F6.23 placeholder-SFX blijft een bekend open punt
  (geen blocker).

## Samenvatting

| Status | Aantal |
|---|---:|
| KLAAR | 60 |
| OPEN | 5 |
| NIET TE CHECKEN | 28 |
| **Totaal** | **93** |

Voortgang per fase (telling van de detailrijen hieronder, freeze 5 op `439ff805`, bijgewerkt met de besluiten van Dennis van 19-11; **KLAAR (meting)**, **KLAAR (tussenmeting)**, **KLAAR (besloten)** en **VERVALLEN voor RC1** tellen als KLAAR):

| Fase | KLAAR | OPEN | NIET TE CHECKEN | Gate |
|---|---:|---:|---:|---|
| 1 Freeze | 7 | 0 | 0 | KLAAR |
| 2 Art op palet | 5 | 1 | 2 | OPEN |
| 3 Stabiliteit | 9 | 0 | 8 | OPEN |
| 4 S25-performance | 3 | 0 | 4 | KLAAR (interne RC) |
| 5 Balans | 7 | 0 | 1 | KLAAR op 1 open punt na |
| 6 UX-polish | 20 | 1 | 3 | OPEN |
| 7 Playtest en fixronde | 2 | 1 | 5 | OPEN |
| 8 Release candidate | 7 | 2 | 5 | OPEN |
| **Totaal** | **60** | **5** | **28** | |

Sinds de eerste audit (15 nov): F1.3, F1.4, F1.5, F1.6, F1.7, F2.2, F2.3, F2.5, F3.2, F3.9, F5.2, F5.3, F5.4, F5.5, F5.6, F6.3, F6.5, F6.11, F6.13, F6.14, F6.15, F6.17, F6.24, F8.1, F8.2, F8.3, F8.4, F8.5 en F8.8 naar
KLAAR (F2.2/F2.3/F5.2/F5.4/F5.5/F5.6 als KLAAR (meting)). Op 19-11 (besluiten Dennis): F4.2, F5.1 en F7.2 naar KLAAR (besloten), F7.8 VERVALLEN voor RC1. Op 20-11: gate fase 5 KLAAR op 1 open punt na (Action kastenzaal 5,3%, ligt bij Dennis) na #562 en #563 (geen rij-wijziging).

### OPEN op risico (voor de interne RC van 20 nov)

F1.6 is KLAAR via #517 en staat niet meer in deze lijst. Geen vervangend punt toegevoegd.
**19-11:** #1 (F7.2) en #3 (F4.2) zijn besloten door Dennis (zie de detailrijen); de regels blijven hieronder staan als geschiedenis. Nog open op risico: #2 (F8.6) en #4 (F6.23, geen RC-blocker).
**20-11:** gate fase 5 KLAAR op 1 open punt na (Action kastenzaal 5,3%, ligt bij Dennis), na #562 en #563. Zie fase 5. De lijst blijft verder ongewijzigd.

| # | Punt | Waarom risico | Voorstel | Grootte | Ja Dennis |
|---:|---|---|---|---|---|
| 1 | F7.2 Dennis' playtest | Scorekaart in `FINISH_LOG.md` heeft geen cijfers van Dennis; geen playtest-issues. Of er P0/P1 zijn, weet niemand. Gate fase 7 staat dus open. | Debug-APK v0.21, versionCode 23, commit `439ff805` (tag `wm1-freeze5`, `sapientia-wm1-freeze5-439ff80-debug.apk`, arm64-v8a + armeabi-v7a, F7.1). Installatie op de S25 door Dennis blijft open. Eén ronde volgens `WM1_PLAYTEST.md`, bugs als issue met label `bug`. | L | ja (alleen Dennis kan spelen) |
| 2 | F8.6 Release-APK | `build-apk` heeft nog nooit met `build_type: release` gedraaid (laatste run op deze branch: debug, `5cb270c`, 5 nov). Of de signing-secrets er staan, kan deze sessie niet zien. Een ondertekende APK is de kern van de RC. | Forge doet nu een droge release-run op de huidige head. Dan blijkt meteen of de secrets kloppen, ruim voor 20 nov. | S | nee (bestaande workflow, interne build, niet publiceren) |
| 3 | F4.2 S25-meting | Geen S25-meting, alleen xvfb/llvmpipe in `docs/perf_wm1.md`. | Dennis meet met `adb dumpsys gfxinfo` op een debug-APK, of accepteert fase 4 bewust voor de interne RC. | M | ja (acceptatie) |
| 4 | F6.23 Placeholder-SFX | 162 regels in `tools/placeholders_algemene_sfx.txt` en 120 in `tools/placeholders_sfx.txt` (F6.23b). LAUNCH_PLAN B2 noemt dit een blocker. `gen_sfx.py` heeft nog nooit gedraaid (OVERDRACHT §4.3). Bekend open punt, geen RC-blocker (akkoord Dennis 17-11-2026 15:29 (kaart t890s5665)). | Vervangen blijft nodig voor de publieke release. | L (vervangen) / S (accepteren) | ja (audio-keuze) |

F5.1 (doelvensters) is op 19-11 besloten door Dennis (KLAAR (besloten), zie fase 5). Op 20-11 is de gate van fase 5 KLAAR op 1 open punt na (Action kastenzaal, ligt bij Dennis): #562 en #563 gemerged, Genezer blijft voor RC1, Wurger en The Voice canon.
F6.24 is KLAAR via #554 (merge `83000372`) en staat niet meer in deze lijst.

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
| F1.3 | Labels `wm1-*` | KLAAR | Labels (REST, `gh label list -R krelegerdennis-collab/Sapientia-RPG`, 19-11-2026, Europe/Amsterdam): `wm1-bugfix`, `wm1-lock`, `wm1-polish` ("Kleine UX/polish-fix voor WM1 (geen nieuwe feature)"), `wm1-cut` ("Uit WM1 geschrapt of geparkeerd tot na de RC") en `wm1-vervanging` ("Placeholder of asset die vervangen moet worden voor WM1") bestaan. | | S | nee |
| F1.4 | CI-matrix gelijk met `game_state.gd` | KLAAR | #361, #380, #400, #406, #449, #480, #488, #500; #507 (merge `060140df`) zette `blauwekisttest`, `bossnametest` en `dungeon100bossmaptest` in de matrix (Dennis akkoord 17-11 12:06). #514 zette `--combattick` in de matrix; de suite draait in CI sinds `f01ba40a`. Matrix nu 135 suites (`.github/workflows/tests.yml:24-42`), `relaytest` als eigen job. Buiten de matrix blijven perf/sim/benchmark en `wm1playthroughtest` (bewust, checklist). | | S | ja (workflow) |
| F1.5 | Baseline PASS-aantallen | KLAAR | Baseline: 140 checks groen op freeze 2 (incl. #521 `wmdeathtest`; PR #542, 140/140). Eerder 138/138 op `f76aa715` (draft-PR #515, `rc/wm1-freeze-ci`, gesloten zonder merge). `--combattick` draait in CI sinds #514. De tabel in `AGENTS.md` is van v0.18. | | S | nee |
| F1.6 | Lock-cijfers hertellen | KLAAR | #517 (merge `e7f33011`, https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/517) hertelde alle lock-cijfers op `f76aa715` (tag `wm1-freeze`) en schreef ze in `docs/release/WM1_CONTENT_LOCK.md`. Story-`EVENTS` is 62 (= 53 string-keys + 9 expressie-keys); de eerdere driftlijst noemde ten onrechte 58 vs 53. Overige rijen na die hertelling: kaartscènes 50 (48 speelroute, 2 dev; extra `leven_v2_leeszaal.tscn`, `woud_beek.tscn`), `ITEMS` 53 (`spreuk_grote_genezing`, `spreuk_vuurbal`, `spreuk_zonnevlam`), Codex 21/32 (`adermot`, `druipslak`, `steenluis` / `aderspark`, `koude_druppel`, `steenbeet`), `TODO(design\|verhaal)` zonder tests 51 (56 − 5 in `scripts/tests/`). Gelijk: `ENEMIES` 26, berggrot-`MONSTERS` 3, `BOSSES` 12 (10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 99), helden 5 (Dax, Vesper, Seren, Kael Voss, Orion), sleutelvoorwerpen 4, `EQUIPMENT` 85, blauwe-kist 36, `SPELLS` 81 (21/20/20/20), kern 2/1/2, opdrachten 7 (6 hoofd, 1 zij) / acts 6 (act 3-6 "later"), BGM 24/13, SFX 99/0. | | S | nee |
| F1.7 | Tag `wm1-freeze` | KLAAR | Tag `wm1-freeze` op `finish/wm1` commit `f76aa7150f23385d47c630e54179e26ac1ba2cb8` (`f76aa715`), akkoord Dennis 17-11-2026 15:25 (kaart t890s5659); tag `wm1-freeze2` op `961101ac`; huidige freeze is `wm1-freeze5` (tag-object `6611e218`) op `439ff805` (zie Freeze 5). Tags `wm1-freeze` t/m `wm1-freeze5` blijven staan. Debug-APK freeze 5: beide ABI's (arm64-v8a en armeabi-v7a). | | S | ja (scope) |

## Fase 2: Art op palet

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F2.1 | Masterpalet vastgelegd | KLAAR | `docs/art/masterpalet.gpl`; #366; CI-job `palet-check` | | | |
| F2.2 | Alle PNG's meten | KLAAR (meting) | Batches geleverd: #538 (`12_assets_ui`), #540 (`10_assets_sprites`), #541 (`06_assets_hd2d`). `palet_check.py --streng` op deze boom (gelijk aan `finish/wm1` `961101ac`): `assets/ui` 364/364 schoon, `assets/sprites` 595/595, `assets/hd2d` 219/219 met `--negeer '**/*_n.png'` (453 genegeerd). Dennis' HD-2D-oogcheck blijft open. | | M | ja (oogcheck) |
| F2.3 | CSV filteren op WM1 | KLAAR (meting) | Op `439ff805` (tag `wm1-freeze5`): `python3 tools/art_audit/palet_check.py --streng --negeer '**/*_n.png'` met de standaardpaden van het script (default `--assets assets/`, palet `docs/art/masterpalet.gpl`). Uitkomst: 73 paletkleuren, 1491 PNG's gecontroleerd, 1491 schoon, **0 buiten het palet**, 461 `*_n.png` overgeslagen, exit 0 (zelfde cijfers als Forge op deze commit). `light_soft_128` (`assets/hd2d/fx_data/light_soft_128.png`) zit in die standaardscan en is schoon (5 unieke kleuren, `buiten_palet` 0); de dithering blijft staan op Dennis' besluit, paletvast sinds #541 (Bayer 8x8). Van de 2053 PNG's in `assets/`+`art/`+`world_warper/art/` vallen er 101 buiten het standaardpad: `art/` 12 en `world_warper/art/` 89. Die zijn apart gecontroleerd met hetzelfde commando plus `--assets art` (12/12 schoon, exit 0) en `--assets world_warper/art` (89/89 schoon, exit 0). Alle gemeten mappen zijn schoon; F2.3 is daarmee KLAAR voor alles in die set. `wacht/` niet gescand. Details en aanvullende meet.py-cijfers: zie de meting onder de tabel. | | M | nee |
| F2.4 | RPG ART levert batches | OPEN | Geleverd: #369-#372, #379, #381, #403, #411, #412, en freeze2 #538 (`12_assets_ui`), #540 (`10_assets_sprites`, akkoord Dennis 17-11 20:18), #541 (`06_assets_hd2d`). Verder akkoord per batch staat niet in dit rapport. Dennis' HD-2D-oogcheck blijft open. | ART per batch, met akkoord van Dennis. | L | ja (art-akkoord) |
| F2.5 | Placeholders in de route (H10) | KLAAR | Rustpunt #375, Blauwe Kist #378 en uitgang-warper #381 zijn klaar. #506 (merge `70f6743c`) haalde 12 dubbele Wilgendal-regels uit `tools/placeholders_v17.txt`; 0 open regels (`rcchecktest` [F2.5] PASS). Het Action-HUD (slagboog, meters, ringmenu) wordt in code getekend en is niet beoordeeld — bewuste kanttekening, geen open placeholder-regel. | | S | ja (bewust laten staan) |
| F2.6 | Ontbrekende art melden in PR | NIET TE CHECKEN | Procesregel. | | | |
| F2.7 | Suites na elke batch | KLAAR | CI draait alle suites op elke PR. Laatste art-PR's waren groen (bijv. #476: 122/122). | | | |
| F2.8 | Screenshots voor/na | NIET TE CHECKEN | Handmatig. | | | |

**Gate fase 2:** OPEN (`palet_check.py --streng --negeer '**/*_n.png'` op `439ff805`: `assets/` 1491/1491 schoon, `art/` 12/12, `world_warper/art/` 89/89, 0 buiten het palet. Dennis' HD-2D-oogcheck en F2.4 blijven open).

### F2.3-meting (freeze 5, `439ff805`)

**palet_check (leidend).** Commando, op een checkout waarvan alleen dit rapport verschilt van `439ff805`:

`python3 tools/art_audit/palet_check.py --streng --negeer '**/*_n.png'`

Het script kijkt standaard naar `assets/` (default `--assets`, palet `docs/art/masterpalet.gpl`). Uitkomst: 73 paletkleuren, 1491 PNG's gecontroleerd, 1491 schoon, **0 buiten het palet**, 461 `*_n.png` overgeslagen, exit 0. Zelfde cijfers als Forge op deze commit. `wacht/` is niet gescand (inhoud niet geopend).

`light_soft_128` valt in die standaardscan (`assets/hd2d/fx_data/light_soft_128.png`) en is schoon (5 unieke kleuren, `buiten_palet` 0). Run 2 van ART (op `cd491d3a`) vond nog 420 afwijkers, waaronder dit bestand; die paletafwijking is weg sinds de F2.2-batches (#538, #540, #541, `light_soft_128` Bayer 8x8). De dithering zelf blijft staan op Dennis' besluit.

Van de 2053 PNG's in `assets/` (1952) + `art/` (12) + `world_warper/art/` (89) vallen er **101 niet in het standaardpad** `assets/`:

| Map buiten `assets/` | PNG's | `*_n.png` | palet_check (zelfde vlaggen) |
|---|---:|---:|---|
| `art/` (`battle_bg` 3, `cutscene` 1, `enemies` 4, `map_creatures` 4) | 12 | 0 | `--assets art`: 12/12 schoon, 0 genegeerd, exit 0 |
| `world_warper/art/` | 89 | 0 | `--assets world_warper/art`: 89/89 schoon, 0 genegeerd, exit 0 |
| **Totaal buiten het standaardpad** | **101** | **0** | **101/101 schoon** |

Alle drie de mappen zijn gecontroleerd en schoon. F2.3 is KLAAR voor die hele set.

**Waarom een eerdere meet.py-run ook 0 gaf.** `palet_check.py` roept `meet.meet_png` aan en gebruikt hetzelfde masterpalet; het criterium is identiek (`buiten_palet` = unieke zichtbare RGB-kleuren die niet in het palet zitten). Het verschil zat in de paden: palet_check scant standaard alleen `assets/` (1952 PNG's, minus 461 `*_n.png` → 1491), terwijl meet.py ook `art/` en `world_warper/art/` meenam (samen 2053). Op niet-`*_n.png` gaven beide 0 buiten het palet. De 457 "buiten palet" in die meet.py-run waren allemaal de `*_n.png` die palet_check met `--negeer` overslaat (453 in `assets/hd2d`, 4 in `assets/placeholder`; 4 `*_n.png` in `assets/tiles` hebben `buiten_palet` 0).

**Aanvullend: WM2/WM3-filter (zelfde palet, niet leidend voor de paletstatus).** Criterium: WM2/WM3-context als het pad onder `wacht/` staat of een padsegment/bestandsstem de token `wm2` of `wm3` heeft (`(?:^|[/._-])wm[23](?:[/._-]|$)`). In de 2053-scan 8 treffers, alle in `world_warper/art/` (knop/icoon locked-wereld); 2045 rijen blijven over. Die 8 zijn in WM1 zichtbaar als Locked-teasers (lock H15) en zaten in de palet_check van `world_warper/art/` (89/89 schoon). `git ls-files` noemt daarnaast 2 PNG's onder `wacht/wm2/` (niet geopend, niet in de scan).

## Fase 3: Stabiliteit

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F3.1 | Verse import zonder fouten | NIET TE CHECKEN | Er is geen Godot in deze sessie. CI importeert bij elke run, maar faalt niet op import-warnings. | Dennis draait lokaal `--import` en leest de uitvoer. | | |
| F3.2 | Alle suites groen op de freeze-commit | KLAAR | Op freeze-commit `f76aa715` (tag `wm1-freeze`): `--wm1playthroughtest` na een verse `--import` **591 PASS / 0 FAIL / 0 SCRIPT ERRORs**. Rapport `/workspace/f3/F3_2_playthrough_f76aa71.txt` (box van het team, niet in de repo). Freeze 2 op `961101ac`: 591 PASS / 0 FAIL, twee keer serieel (`F3_2_playthrough_961101a_run1.txt` en `run2.txt`, build-box, niet in de repo). Freeze 3 op `fcb3f21e`: **591 PASS / 0 FAIL**, twee keer serieel (`RESULT OK (591 goed, 0 fouten)` in `/workspace/f3/F3_2_playthrough_fcb3f21_run1.txt` en `run2.txt`, build-box, niet in de repo). Freeze 5 op `439ff805`: **591 PASS / 0 FAIL**, twee keer serieel (Forge, bij de freeze; rapporten op de build-box, niet in de repo). RC1-kandidaat `a23cd27a` (na #558 en #559): **591 PASS / 0 FAIL**, twee keer serieel op 19-11 (`F3_2_playthrough_a23cd27_run1.txt` en `run2.txt`, build-box, niet in de repo). | | S | nee |
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
| F4.2 | Meting per scène (fps, 1%-low, RAM) | KLAAR (besloten) | Dennis, 19-11-2026 18:36: "Ik accepteer fase 4 zonder S25-meting voor de interne RC" (bron: antwoord van Dennis aan RPG FORGE (DM), 19-11, zoals vastgelegd door RPG FORGE). Geaccepteerd zonder meting, **alleen voor de interne RC**. Achtergrond: er is geen S25-meting. `docs/perf_wm1.md:137` is gemeten op xvfb/llvmpipe. `wm1budgettest` geeft vermoedelijk dubbele instantiatie (OVERDRACHT §4.4, ONVERIFIED). | Dennis meet met `adb dumpsys gfxinfo` op een debug-APK, of accepteert fase 4 bewust voor de interne RC. | M | ja (acceptatie) |
| F4.3 | Meetscènes | NIET TE CHECKEN | Toestel. Lijst verouderd: 13 video's, geen 9. | | | |
| F4.4 | 30 minuten spelen | NIET TE CHECKEN | Toestel. | | | |
| F4.5 | Opstarttijd, laadtijd, APK-grootte | NIET TE CHECKEN | Toestel. Assets nu ±84 MB (audio 36,5 MB, video 40,1 MB). | | | |
| F4.6 | Netwerk-idle bij Co-op/PvP | KLAAR | Niet van toepassing: online dicht (`online_cut`, H11; LAUNCH_PLAN B4). | | | |
| F4.7 | Regressie na fix | KLAAR | CI op elke PR. | | | |

**Gate fase 4:** KLAAR voor de interne RC (acceptatie Dennis 19-11 18:36, F4.2; geen meetrapport). Voor een publieke release blijft een S25-meting nodig.

## Fase 5: Balans

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F5.1 | Doelvensters kiezen | KLAAR (besloten) | Dennis, 19-11-2026 18:36: "Ja, F5.1-doelwaarden zoals voorgesteld" (bron: antwoord van Dennis aan RPG FORGE (DM), 19-11, zoals vastgelegd door RPG FORGE). Doelvensters: normale gevechten 10-25% HP-verlies, bazen 60-85% winst, Diepe Grot 60-80% winst rond verdieping 80-99 (voorstel `WM1_RELEASE_CHECKLIST.md:198-199`). | Dennis neemt het voorstel over of past het aan. | S | ja (balans) |
| F5.2 | Volledig rapport op de freeze-commit | KLAAR (meting) | Op `f76aa715` draaide RPG COMBAT `--battlesim --seed=20261020 --fights=2000`. Alle rijen gelijk aan `docs/release/WM1_BALANCE_REPORT_RC.md` §3.1; het rapport is byte-gelijk aan `docs/BATTLE_BALANCE_REPORT.md` op de looptijd in de kop na. Bestanden `/workspace/combat/f52/sim_f76aa71.txt` en `.json` (box van het team, niet in de repo). Wortelkoning 28% staat zo in §3.1 en wacht op F5.3 / §7. | | M | nee (meten) |
| F5.3 | Besluit per afwijking | KLAAR | Dennis 18-11-2026, `docs/combat/f53_beslissingen.md` (#549). **A1** nee: Wortelkoning baas-ATK blijft **38** (`ENEMIES.wortelkoning.boss`, power scaling v2 #208). **A4** ja: Golem Action-ATK 27, Classic ongewijzigd (#544, merge `63012138`). **A8** ja: Seren (`lotte_glitch.boss`) HP 405 / ATK 36 (#549, merge `fcb3f21e`). **A2, A9, A10:** nee (geen wijziging). **A3, A5, A6, A7, A11, A12, A13, A14:** bewust zo gelaten (zoals voorgesteld in `WM1_BALANCE_REPORT_RC.md` §7). | | M | ja (balans) |
| F5.4 | Levelcurve | KLAAR (meting) | `docs/release/WM1_BALANCE_REPORT_RC.md` §4: per level gevechten en minuten (aanname 5 s/ronde); Golem bereikt op Lv 7 (ontwerp 8), eind Lv 15; 67 verplichte gevechten. A14 bewust: in-game levels zijn het doel (geen data-wijziging). | Diepe Grot-run-tijden via de sim. | M | ja (bij afstellen) |
| F5.5 | Economie | KLAAR (meting) | `docs/release/WM1_BALANCE_REPORT_RC.md` §5: goud per gebied tegenover `shop_data.gd`; alleen monstergoud, kisten geven items. Pakket overal betaalbaar behalve de eerste 70 g (startgoud 0). | CSV-modus tegen `shop_data.gd`. | M | ja (bij afstellen) |
| F5.6 | Classic tegenover Action | KLAAR (meting) | `docs/release/WM1_BALANCE_REPORT_RC.md` §6: `--actionsim` opnieuw (perfect dodge uit): 13,9% HP per kamer (was 11,1%); Classic op dezelfde kamers ≤ 1,7% per gevecht (`tools/battlesim/rc_classic_som.gd`); realtime Golem Lv 7 was 98,5% vóór F5.3 A4 (#544: Action-ATK 27 → ~72% winst, doel 60–80%). Stagger (#450) zit niet in de sim. | `--actionsim` opnieuw draaien. | M | ja (bij afstellen) |
| F5.7 | Zelfde seed opnieuw als bewijs | NIET TE CHECKEN | Procesregel. | | | |
| F5.8 | Balans-suites groen | KLAAR | `battlesimtest`, `balansarchief1test`, `wm1balanstest`, `dungeon100schaaltest`, `autotest`, `woudtest`, `archief2test` in CI; #476 groen. | | | |

**Gate fase 5:** KLAAR op 1 open punt na (20-11-2026). Open punt: Action kastenzaal (zie Bekende uitzonderingen, 1).

- Vensters (F5.1, Dennis): normale gevechten 10-25% HP-verlies; bazen 60-85% winst; Diepe Grot 60-80% winst op verdieping 80-99, inclusief de gewone vloeren 85 en 95.
- Gemerged: #562 (merge `45fb4fd6`, F5 rebalance WM1 + Diepe Grot-bazen + canon Wurger/The Voice + Action tier-2 ATK) en #563 (merge `43d446c9`, Diepe Grot gewone vloeren 81-89/91-98 via `FLOOR_MULT`). Heads `3f0cdb29` en `1518f016`: elk 141/141 checks groen.
- Meting (letterlijk uit `/workspace/f5/sim_after/SUMMARY.md` §6-7, box van het team, niet in de repo; `--seed=20261020`):
  - §6 Action/SoM (commit D `11a7c81b`, tier 2 houdt ATK +9 in Action; Classic blijft +4): leeszaal **11,9%** (binnen), trapzaal **13,6%** (binnen), kastenzaal 5,3% (zoals base, al buiten), gemiddeld iteratie 7 (SomData) **13,9%** (binnen); `balansarchief1` Dax solo tier 2 winst **75%** (doel 70-85%, groen). Classic `--wm1balans` 300/600/100 byte-gelijk aan vóór D.
  - §7 Diepe Grot, 3000 gevechten (winst / HP-verlies): baas 80 Great Book Golem **73,10% / 57,4%**; gewoon 85 **73,47% / 48,0%** (was 99,9% / 11,1%); baas 90 Root Emperor **74,40% / 55,4%**; gewoon 95 **65,83% / 54,0%** (was 99,9% / 12,0%); baas 99 The Voice **79,47% / 49,6%**; eindbaas 100 Knowledge Beast **75,80% / 51,5%**. Bandranden: 81 **69,20% / 49,9%**, 89 **68,00% / 52,3%**, 91 **71,70% / 46,5%**, 98 **65,63% / 53,1%**. Alle binnen 60-80%.
- Besluiten:
  - Genezer blijft zoals hij is voor RC1 (Dennis, 20-11-2026 13:15; bron: besluit van Dennis, zoals doorgegeven door RPG FORGE).
  - Wurger 2450/80 en The Voice 15750/250 zijn canon (Dennis, 20-11-2026 12:12; bron: besluit van Dennis, zoals doorgegeven door RPG FORGE).

Bekende uitzonderingen (getallen uit `/workspace/f5/sim_after/SUMMARY.md`):

1. **Action kastenzaal: 5,3% HP-verlies**, onder het venster van 10-25% (§6: na D 5,3%, "zoals base, al buiten"; §2: base 5,3%). Dit was al zo vóór F5. **Ligt bij Dennis ter beslissing; dit is het ene open punt van de gate.**
2. **Genezer: 100% winst** (§3: oud, zonder C en met C allemaal 100%), buiten 60-85%. Blijft zo voor RC1 (Dennis, 20-11-2026 13:15; bron: besluit van Dennis, zoals doorgegeven door RPG FORGE).
3. **Diepe Grot buiten de scope verdieping 80-99:** bazen 30/40/60/70 op **91 / 94,5 / 93 / 91% winst** (§4, ongewijzigd door #562), en de gewone vloeren 35/45/65 (pool `woud`, 26-80) met **3,4 / 4,1 / 6,3% HP-verlies** (§4, na #562; was 3,6 / 4,6 / 7,3%). Voor die vloeren staat in §4 geen winstpercentage. #563 raakt alleen de strook 81-89/91-98 en verandert deze waarden niet.

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
| F6.11 | Namenlijst | KLAAR | Dennis 18-11-2026 14:09 (F6.11/T08, via RPG Forge): "Ja, de namenlijst in CANON volstaat". `docs/lore/CANON.md` is sindsdien ongewijzigd (laatste commit `39ec3bb7`, 9-11-2026, #397; `git log` na 18-11 14:09 is leeg). `namen_engels.md` staat nog steeds nergens in de repo; dat is geen open punt meer, omdat CANON volstaat. | | S | ja (tekst) |
| F6.12 | Afkapping in ballonnen en menu's | NIET TE CHECKEN | Handmatig. Deels: `uipolishtest` (753), #434. | | | |
| F6.13 | Tekst van Dennis (H8, ECHO) | KLAAR | Dennis 18-11-2026 14:42 (F6.13/T09, via RPG Forge): "Ja, de ECHO-zinnen en 4 stukken mogen zo mee in de RC". De eerdere bevinding (`WM1_PLAYTEST.md:200`: ECHO-zinnen door de agent geschreven; 5 `TODO(verhaal)` in `story_data.gd`, regels 8-291) blijft als achtergrond staan, maar is door dit akkoord geen open punt meer voor de RC. | | M | ja (tekst) |
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
| F6.24 | World Warper-cues zonder fout | KLAAR | #554 (merge `83000372`, https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/554): `ww_hum`, `ww_warp` en `ww_sapientia_glitch` staan in de `sfx` van `assets/audio/audio_manifest.json`, elk met één bestand `sfx_<id>_01.wav`. Gekozen seeds (Dennis, Stable Audio Open 1.0, `assets/audio/sfx/HERKOMST.md`): hum s1002, warp s1002, glitch s1000. `ww_ambient` stond al onder `bgm`. `ambience.gd` speelt via AudioManager; ontbrekende cues blijven stil via `has_sfx` (geen `push_error` in de hub). `rcchecktest` [F6.24] is daarmee PASS (cues staan in het manifest). | | S | |

**Gate fase 6:** OPEN (F6.23 placeholder-SFX blijft open; geen RC-blocker).

## Fase 7: Playtest en fixronde

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F7.1 | Playtest-APK | OPEN | Debug-APK v0.21, versionCode 23, commit `439ff805` (tag `wm1-freeze5`, bestand `sapientia-wm1-freeze5-439ff80-debug.apk`, arm64-v8a en armeabi-v7a), gebouwd door RPG Forge. F3.2 op die commit twee keer 591/0. Niet gepubliceerd (Freeze 5). RC1-kandidaat: debug-APK van `a23cd27a` (`sapientia-wm1-rc1cand-a23cd27-debug.apk`, v0.21/23, debug-signed), gebouwd door RPG Forge op 19-11; nog niet getagd of gepubliceerd. | Installatie op de Samsung S25 door Dennis. | S | nee |
| F7.2 | Dennis speelt de golden path | KLAAR (besloten) | Dennis, 19-11-2026 18:36 (F7.2/D3): "Nee, RC1 mag zonder mijn playtest" (bron: antwoord van Dennis aan RPG FORGE (DM), 19-11, zoals vastgelegd door RPG FORGE). RC1 gaat zonder playtest van Dennis; de kolom "Dennis" in `FINISH_LOG.md` blijft leeg. | Eén ronde volgens `WM1_PLAYTEST.md`. | L | ja |
| F7.3 | Bugs als issue | NIET TE CHECKEN | Procesregel. Nu 0 open issues met label `bug`. | | | |
| F7.4 | Ernst P0-P3 | NIET TE CHECKEN | Definitie, procesregel. | | | |
| F7.5 | Triage | NIET TE CHECKEN | Proces; er is nog niets te triëren. | | | |
| F7.6 | Fixronde per branch | NIET TE CHECKEN | Proces; label `wm1-bugfix` bestaat. | | | |
| F7.7 | Suites na fix-batch | NIET TE CHECKEN | Proces (CI op PR). | | | |
| F7.8 | Tweede playtest | VERVALLEN voor RC1 | Hangt aan F7.2; door het besluit van Dennis van 19-11 18:36 (F7.2) is er voor RC1 geen eerste playtest, dus ook geen tweede. | Plannen na de fixronde, uiterlijk 19 nov voor de RC van 20 nov. | M | ja |

**Gate fase 7:** OPEN (F7.1: installatie op de S25 door Dennis). F7.2 en F7.8 zijn voor RC1 besloten/vervallen (19-11).

## Fase 8: Release candidate

| # | Punt | Status | Bewijs | Bij OPEN: wat mist → voorstel | Grootte | Ja Dennis |
|---|---|---|---|---|---|---|
| F8.1 | Versie kiezen en overal gelijk | KLAAR | Besluit Dennis 15 nov: 0.21 / 23. Gezet met `bump_version set 0.21 --code 23` in versiebron, `project.godot:15` en alle 3 Android-presets; `bump_version --check` OK; `rcchecktest` [F8.1/F8.2] PASS; titelscherm leest `config/version` (`autotest`: label v0.21). Job 11, `release/wm1-rc-prep`. | Dennis kiest, Forge draait `bump_version minor`. | S | ja (versie) |
| F8.2 | `version/code` hoger dan de vorige build | KLAAR | `rcchecktest` [F8.2]: code 23 > 22 (v0.20), PASS. | Komt mee met F8.1. | S | nee (Forge) |
| F8.3 | Changelog | KLAAR | `[0.21]` in `CHANGELOG.md` dekt de merges op `finish/wm1` na #493 t/m #549 (één regel per PR, inclusief #516 t/m #549). `[Unreleased]` is leeg. | | S | nee |
| F8.4 | README en BUILDS kloppen | KLAAR | Klus 12: `README.md:8` noemt "Huidige versie: 0.21 (code 23)" met `tools/release/version.json` als enige bron; de Android-sectie (`README.md:427`) verwijst naar die bron in plaats van "versie 0.13 (code 15)". Historische (v0.xx)-notities blijven. `rcchecktest` [F8.4] wordt daarmee PASS. | | | |
| F8.5 | CI groen op de RC-commit | KLAAR | Optie a: draft-PR #515 (`rc/wm1-freeze-ci`, gesloten zonder merge) draaide de volledige CI-matrix op `wm1-freeze` `f76aa715`: 138/138 checks groen. Freeze 2: 140 checks (incl. #521 `wmdeathtest`); PR #542 140/140 groen. RC1-kandidaat: merge-commits op `finish/wm1` krijgen geen eigen CI-run; deze docs-PR draait de volledige matrix (141 checks) op `a23cd27a` plus alleen deze docs-wijziging. | | S | nee |
| F8.6 | Release-APK met secrets | OPEN | Zie OPEN-lijst #2. Of de secrets bestaan, kan deze sessie niet zien (Actions-API afgeschermd). Dennis, 19-11-2026 18:37: kiest een release-sleutel die hij zelf maakt en zelf als secrets zet (bron: antwoord van Dennis aan RPG FORGE (DM), 19-11, zoals vastgelegd door RPG FORGE). Dat is nog niet gebeurd; daarom blijft F8.6 OPEN. | | S | nee |
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
worden. Nu verwacht: [F6.23], [F6.23b]. [F6.23] en [F6.23b] blijven een bekend open punt, geen RC-blocker (akkoord Dennis 17-11-2026 15:29 (kaart t890s5665)). Dicht (PASS): [F2.5] sinds #506, [F8.2] en [F8.8] sinds Job 11 (#484), [F8.4] sinds Klus 12 (#493), [F6.24] sinds #554 (merge `83000372`).
Statisch nageteld op 17 nov middag: sfx nog open (162 + 120 sfx-regels); placeholders-route is dicht. WW-cues staan sindsdien in het manifest (#554).

Waarom deze keuze: een rode suite in CI zou elke PR blokkeren voor punten die alleen Forge of Dennis kan oplossen
(versie, presets, audio). Een stille suite zou de bevinding verbergen. Met `OPEN` blijft het zichtbaar in de log en in dit rapport,
en een echte regressie (bijv. een signing-veld gevuld of een feature-vlag aan) blijft een `FAIL`.
