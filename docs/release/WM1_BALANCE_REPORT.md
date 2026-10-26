# WM1 balansrapport (release fase 5: balans en tempo)

Meting van **elke encounter en baas van WM1** op het verwachte party-level en de verwachte uitrusting, met de
headless battle simulator (`tools/battlesim/`). Dit rapport meet en stelt voor; het past **geen** speldata aan
(voorstellen staan hieronder met voor/na en als `.patch`-bestanden in `docs/release/tweaks/`).

- Basis: `main` (`fb17c40`). Power scaling v2 ([PR #208](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/208), nog open) is apart gemeten
  door `main` + #208 lokaal samen te voegen (niets gecommit), en de voorstellen zijn daar bovenop gemeten ("v2" en "voorstel" in tabel 3).
- Scope: Wereldkaart 1 (gras, bos, zand), Eerste Archief (4 verdiepingen, Golem, Inktwurm), Donker Woud (kamers, Zingend Zaad, Wortelkoning),
  Berggrot, Tweede Archief (4 verdiepingen, Seren, Wurger, Genezer) en, als bijlage, de Diepe Grot (via ECHO). Niets uit `wacht/wm2/`.
- Omvang: 72.500 gevechten voor WM1 zelf (84 encounter-groepen, vaste aantallen per groep, plus level-gevoeligheid), 89.120 inclusief de Diepe Grot.
  Dezelfde seed + dezelfde code = dezelfde getallen (gemeten met Godot 4.7.2; CI gebruikt 4.3, kleine afwijkingen in de seed-reeks zijn mogelijk).
- Geen bestaande test of `.github/workflows` gewijzigd. Nieuw: `tools/battlesim/wm1_balans.gd`, `wm1_sim_battle.gd`, `wm1_vergelijk.py`,
  suite `--wm1balanstest` (`scripts/tests/wm1_balans_tests.gd`, 65 PASS; **nog niet in de CI-matrix**, die is voor RPG Forge) en één regel per vlag in `scripts/game_state.gd` (test-dispatch).

## 1. Conclusie in het kort

Alle cijfers hieronder zijn `main` tenzij "#208" staat. Winst / rondes tot winst / gemiddeld HP-verlies.

1. **De hele eerste helft is te makkelijk op `main`.** Wereldkaart Lv 3: 100% / 1,8 / 5%; Archief 1 verdieping 1-4: 100% / 1,4-3,1 / 1-7%; Berggrot en Archief 2 verdieping 1-4: 100% / **1,0** / **0%** (een gevecht is één ronde en kost niets). #208 trekt dit recht (wereldkaart 15%, Archief 1 7-10%, Berggrot 13%, Archief 2 9-14%) en dat is nodig.
2. **De Golem zit in de doelband**: 83% / 15,2 / 66% (5 items per gevecht). Eén level te laag (Lv 7, wat je zonder grinden hebt) is 73%, twee te laag 39%: een duidelijke maar eerlijke drempel. Geen voorstel.
3. **Het Donker Woud heeft één mes-scherpe groep**: de bewaker in de Sporenkring (Root Crawler x2 + Spore Cap, tier 4) wint 52% met 91% HP-verlies; een level hoger is 95%, een level lager 9% (twee lager 0%). Alle drie de tier-4-groepen met drie monsters zijn zo (63-91% verlies tegen 19-43% voor tier-4-groepen van twee). Op het level dat je daar echt hebt (zie 4.2) is het speelbaar, maar de marge is te klein. **Voorstel A.**
4. **De Wortelkoning is op `main` te makkelijk (99%) en met #208 precies op de ondergrens (80%)**; op het level waarmee je hem echt bereikt (Lv 13) is dat 91%. Geen voorstel; #208 is hier goed afgesteld.
5. **Seren (verhaalgevecht, Dax alleen) is op `main` geen gevecht** (1,1 ronde, 0% verlies). #208 maakt er 4 rondes / 19% van; nog steeds kort voor het eerste echte tweede-archief-gevecht. **Voorstel B1** (540 HP / ATK 40: 9 rondes, 56%).
6. **De Wurger en de Genezer (CANON) zijn te zwak voor een Lv 16-party en #208 verandert daar niets aan**: 3,0 en 4,0 rondes, 8% en 22% verlies, 100% winst, ook 3 levels lager. De bossen doen weinig tegen DEF 65 (schade = ATK - DEF/2) en de party doet ~230 HP per ronde. Dit kan niet met een klein getal; het vraagt een **besluit van Dennis** (paragraaf 2.3). Niet toegepast, wel gemeten.
7. **EXP-curve**: zonder grinden bereik je Lv 7 voor de Golem (ontwerp 8), Lv 8 in het Woud (ontwerp 11, maar het Woud geeft zelf 1464 EXP, je bent Lv 13 bij de Wortelkoning, ontwerp 12) en eindigt Archief 2 op Lv 15 (ontwerp 16, tekort 303 EXP voor verdieping 3). Dat is gezond: geen muren, wel een tekort van ~5 gevechten in Archief 2. De uitschieter is de **Berggrot**: 16 EXP per gevecht = 23 gevechten per level (gewone gebieden 3-12 gevechten per level). **Voorstel B2.**
8. **Goudcurve**: tot en met de Golem verdien je 549 g (de Act 1-winkel kost 650 g), het Woud geeft er 702 bij (ruim 40% van alle WM1-goud; 47 g per gevecht tegen 3-27 in Archief 1 en 10-38 erna), Berggrot en Archief 2 samen maar ~270 g. Een spreuk van grade 2 (640 g) kost in Archief 2 17-33 gevechten. Geen tweak: het is een keuze of Act 2 meer goud moet geven.
9. **Neveneffect van #208 dat niet in CI zit**: op Lv 1 is een groep van drie Glitch Moths 1% winst (op `main` 100% met 50% verlies; alle andere wereldkaartgroepen blijven 100%); `--balansarchief1test` (Action-modus Archief 1, Dax Lv 1-4 solo) gaat van 54 PASS naar 46 PASS / 8 FAIL (alle tiers buiten de doelband) en draait niet in de CI-matrix. **Voorstel B3** voor de moths; de Action-modus is buiten deze meting en vraagt een eigen afstemming (`SomData.ACTION_AREAS`).

## 2. Voorstellen (alleen getallen in databestanden)

Niets hiervan staat in deze PR; de patches zijn gemeten op `main` + #208. Elke regel is een getal in `scripts/data/game_data.gd`.
Waar #208 dezelfde regel al wijzigt staat dat in de kolom "#208". Patch A past ook op `main` zelf; patch B pas na #208.

### 2.1 Tabel voor/na

| # | Veld | `main` | #208 | Voorstel | Gemeten effect (voorstel t.o.v. #208) | Patch |
|---|---|---:|---:|---:|---|---|
| A1 | `ENEMIES.wortelkruiper.atk` (Root Crawler) | 22 | 22 | **20** | Donker Woud: drie-monster-groepen tier 4 winst 92/98/52% -> 99/100/96%, verlies 63/63/91% -> 56/51/59%, rondes 7,2/11,5/11,6 -> 6,8/7,1/7,7; gebied 96% -> 100% winst, 28% -> 22% verlies | A |
| A2 | `ENEMIES.sporenzwam.max_hp` (Spore Cap) | 40 | 40 | **36** | idem (A1 en A2 samen gemeten) | A |
| A3 | `ENEMIES.sporenzwam.atk` | 18 | 18 | **16** | idem | A |
| B1 | `ENEMIES.lotte_glitch.boss.max_hp` (Seren, baas-blok) | 90 | 270 | **540** | Seren (Dax alleen, Lv 15): 4,0 -> 9,0 rondes, 19% -> 56% verlies, winst blijft 100% (600 HP / ATK 44 is nog 100%, maar 700 HP / ATK 46 is 38%: niet verder gaan) | B |
| B1 | `ENEMIES.lotte_glitch.boss.atk` | 14 | 32 | **40** | idem | B |
| B2 | `TIERS[7].exp` (Berggrot) | tier 0 (x1,0) | 1,0 | **2,5** | Berggrot: 16 -> 41 EXP per gevecht, 22,9 -> 9,1 gevechten per level (Archief 2: 9,3-9,6); EXP van de hele grot 82 -> 205 | B |
| B2 | `TIERS[7].gold` | tier 0 (x1,0) | 1,0 | **2,0** | Berggrot: 9,6 -> 19,2 goud per gevecht (Archief 2 verd. 1: 21,5) | B |
| B3 | `ENCOUNTER_GROUPS[7].weight` (Glitch Moth x3) | 1 | 1 | **0** | Wereldkaart Lv 1: 3 moths 1% winst (met #208; `main` 100%/50%) wordt nooit meer gekozen; groep blijft in de lijst, indexen en `--battlesimtest` blijven kloppen | B |

Waar de voorstellen op steunen:

- **A** (Woud): getest als enemy-basisstats, niet als nieuwe tier-rij, omdat `dungeon_tests` `TIERS[4]` (x2,3 / +10 / +7) en `woud_tests` "niveau 3-4" vastleggen. De drie soorten komen ook in Archief 2 en de Diepe Grot voor; die veranderen niet merkbaar (zelfde seed: <= 1 procentpunt verschil in winst en HP-verlies, gemeten voor Archief 2 en alle Diepe Grot-verdiepingen). Beide soorten zijn nodig: alleen `sporenzwam` (36 / 16) laat de bewaker op 68% winst staan, alleen `wortelkruiper` (ATK 20) haalt de bewaker naar 94% maar laat Spore Cap x2 + Mist Owl op 11,5 rondes (SLOG).
- **B1** (Seren): de baas-stats staan als `TODO(design)` en zijn niet canon. Het verhaalgevecht loopt door bij winst en verlies, dus een hoge winstkans is hier goed; het gaat om de lengte (9 rondes) en het gevoel (56% verlies).
- **B2** (Berggrot): #208 liet EXP/goud bewust gelijk. De grot ligt tussen het Woud (98 EXP/gevecht) en Archief 2 (42-62) en valt daar uit de curve. Het effect op het level is klein (+123 EXP in totaal).
- **B3** (moths): `main` is hier niet kapot; het is een gevolg van #208 (moth ATK 10 -> 15). Alternatief dat ik **niet** voorstel: `glitchmot.atk` verlagen. Dat verandert het gemiddelde "normaal Lv 5" waar de Inktwurm (`74/44/17/26`) op rust en laat `--fusietest` falen.

Gemeten met de voorstellen (A + B, op `main` + #208): `--autotest` 775 PASS, `--golemtest` 64, `--woudtest` 162, `--codextest` 157, `--fusietest` 155, `--dungeontest` 203,
`--dungeon100schaaltest` 86, `--dungeon100gentest` 69, `--archief2test` 235, `--archieftest` 181, `--checkpointtest` 102, `--koopmantest` 103, `--tutorialtest` 56,
`--kernkrachttest` 127, `--berggrottest` 167, `--battlesimtest` 57, `--questtest` 63, `--wm1balanstest` 65, allemaal 0 FAIL (identiek aan `main` + #208 zonder voorstellen).

Toepassen: `git apply docs/release/tweaks/wm1_tweak_A_woud.patch` (op `main` of op `main` + #208), daarna na #208 `git apply docs/release/tweaks/wm1_tweak_B_na_208.patch`.
Daarna `-- --wm1balans` opnieuw draaien; het gegenereerde deel van dit rapport wordt vervangen, deze tekst blijft staan.

### 2.2 Bewust niet voorgesteld

| Onderdeel | Waarom niet |
|---|---|
| Golem (360 HP / 27 / 15) | CANON (`TODO.md`) en in de doelband: 83% / 15,2 rondes. |
| Wortelkoning ATK 38 (#208) | 80% op het ontwerp-level, 91% op Lv 13 (wat je echt hebt). Met ATK 37 zou het ~90% zijn (#208-notities); dat is een keuze voor RPG Forge, geen fout. |
| Inktwurm (74 / 44 / 17 / 26 na #208) | Vastgelegd als "2x normaal Lv 5" in `--fusietest`. Na #208: 100% winst maar 62% verlies; Lv 7 is 70%, Lv 6 is 1% (**CLIFF**). Je komt met Lv 8 uit de Golem, dus het past, maar er is geen speelruimte. Watch-item. |
| Glitchmot ATK, andere basisstats | #208 heeft die bewust gezet; koppelingen met Codex-gemiddelden (zie B3). |
| EXP- en goudcurve elders | Geen muren; het enige gat (Berggrot) staat in B2. Het goud in Archief 2 is een designkeuze (paragraaf 1.8). |
| Diepe Grot | Bijlage. Canon-bazen 25/50/75/99 zijn 100% in 4 rondes (BOSS-EASY/SHORT, CANON). De niet-canon bazen zakken met #208 onder de band: verdieping 10 van 90% naar 75%, verdieping 20 van 72% naar 58%, 80 van 83% naar 80%, 90 blijft 71-72%. `BOSS_MULT` is #208's keuze; na het mergen opnieuw meten en dan pas bijstellen. |

### 2.3 Besluit van Dennis nodig (CANON-bazen, niet toegepast)

De Wurger (700 / 42 / 28) en de Genezer (900 / 54 / 36) staan als CANON in `TODO.md`/`CANON.md`. Tegen de Lv 16-party (Dax ATK 77 / DEF 65, Vesper en Seren met spreuken, volle tas) zijn ze in 3-4 rondes dood.
Meetreeks op `main` + #208 (alleen de baas-stats gewijzigd, 300 gevechten per rij; HP-verlies is netto):

| Baas | HP / ATK | Winst | Rondes | HP-verlies |
|---|---|---:|---:|---:|
| Wurger (CANON) | 700 / 42 | 100% | 3,0 | 8% |
| Wurger | 1000 / 72 | 100% | 4,0 | 26% |
| Wurger | 2500 / 60 | 100% | 5,6 | 32% |
| Wurger | 3500 / 66 | 96% | 7,3 | 45% |
| Genezer (CANON) | 900 / 54 | 100% | 4,0 | 22% |
| Genezer | 1800 / 80 | 100% | 5,0 | 25% |
| Genezer | 3000 / 70 | 100% | 6,0 | 26% |
| Genezer | 4500 / 80 | 100% | 6,7 | 25% |

De Genezer doet percentage-schade (30% eerste klap, daarna 8-12% en zelfheal), dus zijn ATK maakt geen verschil; alleen HP verlengt het gevecht. Opties:
(1) laten zoals het is (bazen als verhaalmomenten), (2) HP van beide bazen een factor 4-5 omhoog (buiten de canon-waarden), (3) het probleem aan de party-kant zoeken (stat- of gear-groei in Act 2); dat raakt CANON punt 10 (levelschaal) en is geen klein getal.
Hetzelfde geldt voor de canon-bazen van de Diepe Grot.

## 3. Vergelijking `main` / `main` + #208 / `main` + #208 + voorstellen

Gewogen per gebied en per groep (`python3 tools/battlesim/wm1_vergelijk.py main=... v2=... voorstel=...`): winst / rondes tot winst / gem. HP-verlies, zelfde seed.
`-` = de groep bestaat in die variant niet meer (B3: weight 0).

| Gebied | main: winst / rondes / HP-verlies | v2: winst / rondes / HP-verlies | voorstel: winst / rondes / HP-verlies |
|---|---|---|---|
| Worldmap 1 (grass, random encounters) | 100% / 1.8 / 5% | 100% / 2.0 / 15% | 100% / 2.0 / 13% |
| First Archive floor 1 | 100% / 1.4 / 1% | 100% / 1.4 / 9% | 100% / 1.4 / 9% |
| First Archive floor 2 | 100% / 2.1 / 3% | 100% / 2.1 / 10% | 100% / 2.1 / 10% |
| First Archive floor 3 | 100% / 2.5 / 4% | 100% / 2.5 / 7% | 100% / 2.5 / 7% |
| First Archive floor 4 | 100% / 3.1 / 7% | 100% / 3.1 / 9% | 100% / 3.1 / 9% |
| BOSS Golem (First Archive) | 83% / 15.2 / 66% | 83% / 15.2 / 66% | 83% / 15.2 / 66% |
| STORY Ink Worm (secret cabinet, First Archive) | 100% / 2.0 / 40% | 100% / 2.3 / 62% | 100% / 2.3 / 62% |
| Dark Wood | 96% / 4.1 / 28% | 96% / 4.1 / 29% | 100% / 3.4 / 22% |
| STORY Singing Seed (Dark Wood) | 100% / 2.0 / 1% | 100% / 2.0 / 1% | 100% / 2.0 / 1% |
| BOSS Root King (Dark Wood) | 99% / 10.9 / 57% | 80% / 13.1 / 76% | 80% / 13.1 / 76% |
| Mountain Cave (Berggrot) | 100% / 1.0 / 0% | 100% / 1.8 / 13% | 100% / 1.8 / 13% |
| Second Archive floor 1 | 100% / 1.0 / 0% | 100% / 2.0 / 10% | 100% / 2.0 / 10% |
| Second Archive floor 2 | 100% / 1.0 / 0% | 100% / 2.0 / 9% | 100% / 2.0 / 8% |
| STORY Seren/Lotte (Second Archive, Dax alone) | 100% / 1.1 / 0% | 100% / 4.0 / 19% | 100% / 9.0 / 56% |
| Second Archive floor 3 | 100% / 1.0 / 0% | 100% / 2.0 / 14% | 100% / 2.0 / 14% |
| Second Archive floor 4 | 100% / 1.0 / 0% | 100% / 2.0 / 14% | 100% / 2.0 / 14% |
| BOSS The Strangler (Second Archive) | 100% / 3.0 / 8% | 100% / 3.0 / 8% | 100% / 3.0 / 8% |
| BOSS The Mender (Second Archive) | 100% / 4.0 / 22% | 100% / 4.0 / 22% | 100% / 4.0 / 22% |
| Worldmap 1 (bos, random encounters) | 100% / 1.9 / 7% | 100% / 2.2 / 20% | 100% / 2.2 / 16% |
| Worldmap 1 (zand, random encounters) | 100% / 2.1 / 8% | 100% / 2.5 / 22% | 100% / 2.4 / 18% |

Groepen waar de varianten >= 10 procentpunt winst of HP-verlies uiteenlopen, of een baas zijn:

| Gebied | Groep | main: winst / rondes / HP-verlies | v2: winst / rondes / HP-verlies | voorstel: winst / rondes / HP-verlies |
|---|---|---|---|---|
| Worldmap 1 (grass, random encounters) | Moss Rabbit + Moss Slime | 100% / 2.0 / 3% | 100% / 2.0 / 17% | 100% / 2.0 / 17% |
| Worldmap 1 (grass, random encounters) | Paper Wraith + Paper Wraith | 100% / 2.0 / 2% | 100% / 2.7 / 18% | 100% / 2.7 / 18% |
| Worldmap 1 (grass, random encounters) | Glitch Moth + Paper Wraith | 100% / 2.0 / 4% | 100% / 2.4 / 23% | 100% / 2.4 / 23% |
| Worldmap 1 (grass, random encounters) | Glitch Moth + Glitch Moth + Glitch Moth | 100% / 3.0 / 15% | 100% / 3.0 / 65% | - |
| First Archive floor 1 | Moss Rabbit + Moss Slime (tier 1) | 100% / 2.0 / 3% | 100% / 2.0 / 20% | 100% / 2.0 / 20% |
| First Archive floor 1 | Glitch Moth (tier 1) | 100% / 1.0 / 2% | 100% / 1.0 / 13% | 100% / 1.0 / 13% |
| First Archive floor 1 | Paper Wraith + Glitch Moth (tier 1) | 100% / 2.0 / 3% | 100% / 2.0 / 23% | 100% / 2.0 / 23% |
| First Archive floor 2 | Paper Wraith + Paper Wraith + Glitch Moth (tier 2) | 100% / 3.0 / 5% | 100% / 3.0 / 23% | 100% / 3.0 / 23% |
| First Archive floor 2 | Glitch Moth + Glitch Moth (tier 2) | 100% / 2.0 / 3% | 100% / 2.0 / 18% | 100% / 2.0 / 18% |
| First Archive floor 4 | Glitch Moth + Glitch Moth + Glitch Moth (tier 4) | 100% / 3.0 / 4% | 100% / 3.0 / 15% | 100% / 3.0 / 15% |
| BOSS Golem (First Archive) | The Knowledge Beast [BOSS] | 83% / 15.2 / 66% | 83% / 15.2 / 66% | 83% / 15.2 / 66% |
| STORY Ink Worm (secret cabinet, First Archive) | Ink Worm | 100% / 2.0 / 40% | 100% / 2.3 / 62% | 100% / 2.3 / 62% |
| Dark Wood | Spore Cap + Spore Cap (tier 4) | 100% / 4.0 / 36% | 100% / 4.0 / 36% | 100% / 3.6 / 24% |
| Dark Wood | Root Crawler + Spore Cap (tier 4) | 100% / 4.0 / 43% | 100% / 4.0 / 43% | 100% / 3.7 / 31% |
| Dark Wood | Spore Cap + Spore Cap + Mist Owl (tier 4) | 98% / 11.5 / 63% | 98% / 11.5 / 63% | 100% / 7.1 / 51% |
| Dark Wood | Root Crawler + Root Crawler + Spore Cap (tier 4) | 52% / 11.6 / 91% | 52% / 11.6 / 91% | 96% / 7.7 / 59% |
| BOSS Root King (Dark Wood) | The Root King [BOSS] | 99% / 10.9 / 57% | 80% / 13.1 / 76% | 80% / 13.1 / 76% |
| STORY Seren/Lotte (Second Archive, Dax alone) | Seren [BOSS] | 100% / 1.1 / 0% | 100% / 4.0 / 19% | 100% / 9.0 / 56% |
| BOSS The Strangler (Second Archive) | The Strangler [BOSS] | 100% / 3.0 / 8% | 100% / 3.0 / 8% | 100% / 3.0 / 8% |
| BOSS The Mender (Second Archive) | The Mender [BOSS] | 100% / 4.0 / 22% | 100% / 4.0 / 22% | 100% / 4.0 / 22% |
| Worldmap 1 (bos, random encounters) | Paper Wraith + Paper Wraith | 100% / 2.0 / 2% | 100% / 2.7 / 19% | 100% / 2.7 / 19% |
| Worldmap 1 (bos, random encounters) | Glitch Moth + Paper Wraith | 100% / 2.0 / 4% | 100% / 2.4 / 23% | 100% / 2.4 / 23% |
| Worldmap 1 (bos, random encounters) | Glitch Moth + Glitch Moth + Glitch Moth | 100% / 3.0 / 15% | 100% / 3.0 / 65% | - |
| Worldmap 1 (zand, random encounters) | Paper Wraith + Paper Wraith | 100% / 2.0 / 2% | 100% / 2.7 / 19% | 100% / 2.7 / 19% |
| Worldmap 1 (zand, random encounters) | Glitch Moth + Paper Wraith | 100% / 2.0 / 4% | 100% / 2.4 / 23% | 100% / 2.4 / 23% |
| Worldmap 1 (zand, random encounters) | Glitch Moth + Glitch Moth + Glitch Moth | 100% / 3.0 / 15% | 100% / 3.0 / 65% | - |

## 4. Bevindingen per gebied

### 4.1 Wereldkaart en Eerste Archief

- **Wereldkaart** (Lv 3, Dax alleen, startuitrusting): 10 groepen, 5 daarvan TRIVIAL (< 3% verlies en <= 2 rondes). Zwaarste groep: Knowledge Beast + Paper Wraith, 36% (SPIKE; een zeldzame encounter). Bos en zand (7 en 6 groepen) zijn gelijk. Op Lv 1 wint elke groep nog 100% (max 50% verlies); #208 maakt dat Lv 1 hier gevaarlijk is (paragraaf 1.9).
- **Archief 1 verdieping 1-4** (Lv 3/5/6/7): 100% winst, 1-7% verlies, EXP 6-31 per gevecht. Ook op het level dat je echt hebt (Lv 1/2/4/6) zijn ze 100% met 2-11% verlies. Er is geen drempel; dat is de rol van de eerste verdieping, maar dan moeten de gevechten wel iets kosten (#208: 7-10%).
- **Golem**: zie 1.2. Gemiddeld 4,98 items (140 g aan Drankjes) per gevecht: de Golem kost je hele voorraad, dat is het doel. Beloning 210 EXP (bijna een level: 225 nodig) en 84 goud.
- **Inktwurm**: zie 2.2.

### 4.2 Donker Woud

- 15 map-monsters geven samen **1464 EXP** (Lv 8 -> 13) en 702 goud. Het ontwerp-level 11 is een gemiddelde; kamer voor kamer (tabel in het gegenereerde deel) loop je Lv 8 (Wood's Edge) -> 9 (Root Path) -> 11 (Mist Pool) -> 12 (Spore Ring) en elke kamer is gemiddeld >= 98% winst op het level dat je op dat moment hebt (slechtste groep 92%, in de Mist Pool).
- De uitschieters zijn de drie groepen van drie monsters in tier-4-kamers (DEADLY/HEAVY/SPIKE/SLOG/CLIFF in de outliertabel). Voorstel A.
- Het Zingend Zaad (twee Wood Wraiths, EXP 8) is bewust een mini-gevecht (TRIVIAL, 39 gevechten per level): geen tweak.
- Wortelkoning: zie 1.4. Beloning 400 EXP en 150 goud (ruim een level, 3,7 items = 107 g).

### 4.3 Berggrot en Tweede Archief

- `main`: Berggrot, Archief 2 verdieping 1-4 en Seren eindigen in 1,0 ronde met 0% verlies; de vijanden (ATK 13-17, tier 0 / 2-3 met archiefschaal 0,7) kunnen een Lv 14-16-party met DEF 26-65 niet raken. #208 lost dit op met tier 5/6/7 (zie tabel 3).
- Wurger en Genezer: paragraaf 2.3.
- EXP: Archief 2 geeft per gevecht 42-62 EXP (9,3-9,6 gevechten per level voor verdieping 1-2, 7,5-8,3 voor 3-4); de bazen 48 en 90.

### 4.4 EXP- en goudcurve

Zie de tabellen in het gegenereerde deel. In het kort:

| Moment | Level zonder grinden | Ontwerp-level | Verschil |
|---|---:|---:|---:|
| Archief 1 verdieping 1 / 2 / 3 / 4 | 1 / 2 / 4 / 6 | 3 / 5 / 6 / 7 | -2 / -3 / -2 / -1 |
| Golem | 7 | 8 | -1 |
| Donker Woud (begin / eind) | 8 / 13 | 11 | -3 / +2 |
| Wortelkoning | 13 | 12 | +1 |
| Berggrot | 14 | 13 | +1 |
| Archief 2 verdieping 1 / 2 | 14 / 15 | 14 | 0 / +1 |
| Archief 2 verdieping 3 / 4 en bazen | 15 | 16 | -1 |

De curve loopt dus ~1-2 levels onder het ontwerp tot en met de Golem, springt in het Woud over het ontwerp heen en eindigt 1 level eronder. De wereldkaart (9,1 EXP per gevecht, 8 gevechten per level op Lv 3) en de map-monsters die terugkomen na het opnieuw betreden van een kamer dekken elk tekort.

## 5. Reproduceren

```bash
xvfb-run -a godot --rendering-driver opengl3 --path . -- --wm1balans [--seed=N] [--fights=N] [--boss-fights=N] [--sens-fights=N] [--only=id,id] [--no-d100] [--out=pad.md] [--json=pad.json]
xvfb-run -a godot --rendering-driver opengl3 --path . -- --wm1balanstest
python3 tools/battlesim/wm1_vergelijk.py main=main.json v2=v2.json voorstel=voorstel.json
```

Het gegenereerde deel hieronder (tussen `WM1-GEN-BEGIN` en `WM1-GEN-END`) wordt bij elke run vervangen; de tekst erboven en eronder blijft.
Een run van ~89.000 gevechten duurt ongeveer 4,5 minuten op 4 kernen.

<!-- WM1-GEN-BEGIN -->
## Gegenereerde meting

Gegenereerd door `tools/battlesim/wm1_balans.gd` (`-- --wm1balans --seed=20261020 --fights=300 --boss-fights=600 --sens-fights=100`) op Godot 4.7.2-stable (official), looptijd 264 s.
Zelfde seed + zelfde code = dezelfde getallen. Echte `battle.tscn`/`battle.gd`; alleen menu, wachttijden en animaties zijn vervangen
(`sim_battle.gd`, `wm1_sim_battle.gd` telt daarbovenop schade en EXP/goud). Geen gameplay gewijzigd.

### Methode en drempels

- **Verwacht level en uitrusting** per gebied komen uit het bestaande simulatorrapport (`battlesim.gd scenarios()`): `level_scale.gd` (Act 1 = Lv 1-13, Act 2 = 14-19), `EERSTE_ARCHIEF_DOEL` 7, de Golem op Lv 8 met Spark Sword, Dark Wood Lv 11-12, Vesper op Dax-1, Seren op Dax' level. Beide cijfers staan per gebied in de tabellen.
- **Vaste aantallen per groep** (`--fights` gewone groepen, `--boss-fights` bazen), elk gevecht onafhankelijk met een volle party en de vermelde tas. Gelijke groepen in een gebied zijn samengevoegd; het gewicht = aantal keer dat de groep als map-monster in het gebied staat (wereldkaart: encounter-gewicht).
- **Level-gevoeligheid**: dezelfde gevechten met alle helden 1-2 levels lager of hoger (wereldkaart tot +5), uitrusting gelijk. Cel = `winst / gem. HP-verlies`.
- **HP-verlies** = netto party-HP aan het einde tegenover het begin (inclusief genezing; een KO telt als de hele balk). Op lage levels maskeert potiongebruik dit (kolom Items), dus lees het samen met winst en items. **Schade** = echte directe schade aan de party (DoT telt niet; wel ook wat later weggeheald is), absoluut en als % van de party-max-HP.
- **EXP/goud** = buit bij winst, zoals `battle.gd _victory` (iedere levende held krijgt de volle EXP; EXP wordt niet gedeeld). Item-waarde = verbruikte genees-items x referentieprijs (Drankje 30, Toverwater 50, Kruid 20).
- **Vlaggen gewone groep**: DEADLY = winst < 95%; HEAVY = gem. HP-verlies >= 45%; SPIKE = verlies >= 2x de gebiedsmediaan (en >= 25%); SLOG = gem. >= 8 rondes tot winst; TRIVIAL = < 3% verlies en <= 2 rondes bij 100% winst.
- **Vlaggen baas** (doelband winst 80-95%, zoals PR #208): BOSS-HARD < 80%, BOSS-IMPOSSIBLE < 50%, BOSS-EASY > 95%, BOSS-SHORT < 6 rondes tot winst, BOSS-LONG > 25 rondes.
- **CLIFF** = op level-1 daalt de winst >= 25 procentpunt onder de ondergrens (één level te laag is al een muur). **GRIND** = > 30 gevechten per level op het ontwerp-level, **FAST** = < 2.
- **Niet gemodelleerd**: vluchten, verdedigen, Codex-bondgenoten/vangen, mimics, de Koopman, opslaan/rusten tussen gevechten en kist-/verhaalbuit. De sim-AI is eenvoudig (`sim_battle.gd`): een echte speler met slimmer item- en spreukgebruik doet het beter dan de cijfers.

### Samenvatting per gebied (verhaalvolgorde)

Gewogen gemiddelden over alle groepen van het gebied op het ontwerp-level. Vlaggen = groepen met een vlag (details in 'Outliers').

| Gebied | Dax Lv | Groepen | Winst | Rondes tot winst | HP-verlies | Schade/gevecht | Items (waarde) | EXP/gevecht | Goud/gevecht | Gevechten per level | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Worldmap 1 (grass, random encounters) | 3 | 10 | 100% | 1.8 | 5% | 3 HP (5%) | 0.00 (0 g) | 9.1 | 6.5 | 8.2  | TRIVIAL, SPIKE |
| First Archive floor 1 | 3 | 8 | 100% | 1.4 | 1% | 1 HP (1%) | 0.00 (0 g) | 6.3 | 3.0 | 11.8  | TRIVIAL |
| First Archive floor 2 | 5 | 8 | 100% | 2.1 | 3% | 2 HP (3%) | 0.00 (0 g) | 15.8 | 9.1 | 8.6  | TRIVIAL |
| First Archive floor 3 | 6 | 7 | 100% | 2.5 | 4% | 3 HP (4%) | 0.00 (0 g) | 25.9 | 17.4 | 6.4  | TRIVIAL |
| First Archive floor 4 | 7 | 7 | 100% | 3.1 | 7% | 6 HP (7%) | 0.00 (0 g) | 31.4 | 27.1 | 6.2  | TRIVIAL |
| BOSS Golem (First Archive) | 8 | 1 | 83% | 15.2 | 66% | 214 HP (204%) | 4.98 (140 g) | 210.0 | 84.0 | 1.1 FAST |  |
| STORY Ink Worm (secret cabinet, First Archive) | 8 | 1 | 100% | 2.0 | 40% | 42 HP (40%) | 0.00 (0 g) | 60.0 | 40.0 | 3.8  |  |
| Dark Wood | 11 | 15 | 96% | 4.1 | 28% | 66 HP (50%) | 1.00 (28 g) | 97.6 | 46.8 | 3.2  | TRIVIAL, DEADLY, HEAVY, SPIKE, SLOG, CLIFF |
| STORY Singing Seed (Dark Wood) | 11 | 1 | 100% | 2.0 | 1% | 1 HP (1%) | 0.00 (0 g) | 8.0 | 4.0 | 39.4 GRIND | TRIVIAL |
| BOSS Root King (Dark Wood) | 12 | 1 | 99% | 10.9 | 57% | 190 HP (134%) | 3.69 (107 g) | 400.0 | 150.0 | 0.9 FAST | BOSS-EASY |
| Mountain Cave (Berggrot) | 13 | 3 | 100% | 1.0 | 0% | 0 HP (0%) | 0.00 (0 g) | 16.4 | 9.6 | 22.9  | TRIVIAL |
| Second Archive floor 1 | 14 | 2 | 100% | 1.0 | 0% | 0 HP (0%) | 0.00 (0 g) | 42.0 | 21.5 | 9.6  | TRIVIAL |
| Second Archive floor 2 | 14 | 2 | 100% | 1.0 | 0% | 0 HP (0%) | 0.00 (0 g) | 43.5 | 23.5 | 9.3  | TRIVIAL |
| STORY Seren/Lotte (Second Archive, Dax alone) | 15 | 1 | 100% | 1.1 | 0% | 0 HP (0%) | 0.00 (0 g) | 20.0 | 0.0 | 21.8  | BOSS-EASY, BOSS-SHORT |
| Second Archive floor 3 | 16 | 1 | 100% | 1.0 | 0% | 0 HP (0%) | 0.00 (0 g) | 56.0 | 33.0 | 8.3  | TRIVIAL |
| Second Archive floor 4 | 16 | 1 | 100% | 1.0 | 0% | 0 HP (0%) | 0.00 (0 g) | 62.0 | 38.0 | 7.5  | TRIVIAL |
| BOSS The Strangler (Second Archive) | 16 | 1 | 100% | 3.0 | 8% | 33 HP (8%) | 0.01 (0 g) | 48.0 | 20.0 | 9.7  | BOSS-EASY, BOSS-SHORT |
| BOSS The Mender (Second Archive) | 16 | 1 | 100% | 4.0 | 22% | 91 HP (23%) | 0.08 (2 g) | 90.0 | 40.0 | 5.2  | BOSS-EASY, BOSS-SHORT |
| Worldmap 1 (bos, random encounters) | 3 | 7 | 100% | 1.9 | 7% | 4 HP (7%) | 0.00 (0 g) | 11.2 | 8.0 | 6.7  | TRIVIAL, SPIKE |
| Worldmap 1 (zand, random encounters) | 3 | 6 | 100% | 2.1 | 8% | 5 HP (8%) | 0.00 (0 g) | 12.4 | 8.8 | 6.0  | TRIVIAL, SPIKE |

### EXP-curve tegenover het verwachte level

EXP-formule: `15 x (level-1)^2` (`GameData.exp_for_level`). Model: de speler verslaat in verhaalvolgorde **elk map-monster van elk gebied één keer** (geen grinden, geen wereldkaart-gevechten; bazen één keer). Dat is het minimum dat het verhaal oplevert; elk tekort moet worden gegrind (map-monsters komen terug zodra je de kamer opnieuw binnengaat, plus de wereldkaart).

| Gebied | Ontwerp-Lv Dax | EXP nodig voor dat level | EXP verdiend vóór dit gebied | Tekort / overschot | Level bij alleen opruimen (ervoor) | EXP dit gebied (opruimen) | Level erna | Tekort in gevechten van het vorige gebied |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Worldmap 1 (grass, random encounters) | 3 | 60 | 0 | -60 | 1 | willekeurig | 1 |  |
| First Archive floor 1 | 3 | 60 | 0 | -60 | 1 | 57 (9 gevechten) | 2 | 7 x Worldmap 1 (grass, random encounters) |
| First Archive floor 2 | 5 | 240 | 57 | -183 | 2 | 142 (9 gevechten) | 4 | 29 x First Archive floor 1 |
| First Archive floor 3 | 6 | 375 | 199 | -176 | 4 | 207 (8 gevechten) | 6 | 12 x First Archive floor 2 |
| First Archive floor 4 | 7 | 540 | 406 | -134 | 6 | 251 (8 gevechten) | 7 | 6 x First Archive floor 3 |
| BOSS Golem (First Archive) | 8 | 735 | 657 | -78 | 7 | 210 (1 gevechten) | 8 | 3 x First Archive floor 4 |
| STORY Ink Worm (secret cabinet, First Archive) | 8 | 735 | 867 | +132 | 8 | 60 (1 gevechten) | 8 |  |
| Dark Wood | 11 | 1500 | 927 | -573 | 8 | 1464 (15 gevechten) | 13 | 10 x STORY Ink Worm (secret cabinet, First Archive) |
| STORY Singing Seed (Dark Wood) | 11 | 1500 | 2391 | +891 | 13 | 8 (1 gevechten) | 13 |  |
| BOSS Root King (Dark Wood) | 12 | 1815 | 2399 | +584 | 13 | 400 (1 gevechten) | 14 |  |
| Mountain Cave (Berggrot) | 13 | 2160 | 2799 | +639 | 14 | 82 (5 gevechten) | 14 |  |
| Second Archive floor 1 | 14 | 2535 | 2881 | +346 | 14 | 84 (2 gevechten) | 15 |  |
| Second Archive floor 2 | 14 | 2535 | 2965 | +430 | 15 | 87 (2 gevechten) | 15 |  |
| STORY Seren/Lotte (Second Archive, Dax alone) | 15 | 2940 | 3052 | +112 | 15 | 20 (1 gevechten) | 15 |  |
| Second Archive floor 3 | 16 | 3375 | 3072 | -303 | 15 | 56 (1 gevechten) | 15 | 16 x STORY Seren/Lotte (Second Archive, Dax alone) |
| Second Archive floor 4 | 16 | 3375 | 3128 | -247 | 15 | 62 (1 gevechten) | 15 | 5 x Second Archive floor 3 |
| BOSS The Strangler (Second Archive) | 16 | 3375 | 3190 | -185 | 15 | 48 (1 gevechten) | 15 | 3 x Second Archive floor 4 |
| BOSS The Mender (Second Archive) | 16 | 3375 | 3238 | -137 | 15 | 90 (1 gevechten) | 15 | 3 x BOSS The Strangler (Second Archive) |

Het eindlevel bij alleen opruimen is Lv 15 (3328 EXP); het laatste ontwerp-level is Lv 16.

**Gevechten per level op het ontwerp-level** (EXP die nodig is voor het volgende level gedeeld door de gemiddelde EXP per gevecht in het gebied):

| Gebied | Lv | EXP naar volgend level | Gem. EXP/gevecht | Gevechten per level | Gem. gevechtsduur (rondes) |
|---|---:|---:|---:|---:|---:|
| Worldmap 1 (grass, random encounters) | 3 | 75 | 9.1 | 8.2 | 1.8 |
| First Archive floor 1 | 3 | 75 | 6.3 | 11.8 | 1.4 |
| First Archive floor 2 | 5 | 135 | 15.8 | 8.6 | 2.1 |
| First Archive floor 3 | 6 | 165 | 25.9 | 6.4 | 2.5 |
| First Archive floor 4 | 7 | 195 | 31.4 | 6.2 | 3.1 |
| BOSS Golem (First Archive) | 8 | 225 | 210.0 | 1.1 | 15.2 |
| STORY Ink Worm (secret cabinet, First Archive) | 8 | 225 | 60.0 | 3.8 | 2.0 |
| Dark Wood | 11 | 315 | 97.6 | 3.2 | 4.1 |
| STORY Singing Seed (Dark Wood) | 11 | 315 | 8.0 | 39.4 | 2.0 |
| BOSS Root King (Dark Wood) | 12 | 345 | 400.0 | 0.9 | 10.9 |
| Mountain Cave (Berggrot) | 13 | 375 | 16.4 | 22.9 | 1.0 |
| Second Archive floor 1 | 14 | 405 | 42.0 | 9.6 | 1.0 |
| Second Archive floor 2 | 14 | 405 | 43.5 | 9.3 | 1.0 |
| STORY Seren/Lotte (Second Archive, Dax alone) | 15 | 435 | 20.0 | 21.8 | 1.1 |
| Second Archive floor 3 | 16 | 465 | 56.0 | 8.3 | 1.0 |
| Second Archive floor 4 | 16 | 465 | 62.0 | 7.5 | 1.0 |
| BOSS The Strangler (Second Archive) | 16 | 465 | 48.0 | 9.7 | 3.0 |
| BOSS The Mender (Second Archive) | 16 | 465 | 90.0 | 5.2 | 4.0 |
| Worldmap 1 (bos, random encounters) | 3 | 75 | 11.2 | 6.7 | 1.9 |
| Worldmap 1 (zand, random encounters) | 3 | 75 | 12.4 | 6.0 | 2.1 |

### Wat de speler echt heeft: winst op het level van alleen-opruimen

Het ontwerp-level van de gebieden is een aanname; de EXP-curve hierboven laat zien welk level je hebt als je het verhaal zonder grinden speelt. Hier staat dezelfde meting op dat level: **aankomst** = level bij het binnenkomen, **einde** = level na het opruimen van het gebied. Cel = `winst / HP-verlies (slechtste groep)`; `buiten bereik` = meer dan 3 levels onder of 2 boven het ontwerp-level.

Let op: een gebied dat zelf veel EXP geeft (het Donker Woud) wordt hier op één level gemeten; de kamer-voor-kamer-tabel eronder is nauwkeuriger voor het Woud.

| Gebied | Ontwerp-Lv | Aankomst-Lv | Winst op aankomst | Einde-Lv | Winst aan het einde |
|---|---:|---:|---|---:|---|
| First Archive floor 1 | 3 | 1 | 100% / 2% (slechtste: 100%) | 2 | 100% / 2% (slechtste: 100%) |
| First Archive floor 2 | 5 | 2 | 100% / 10% (slechtste: 100%) | 4 | 100% / 4% (slechtste: 100%) |
| First Archive floor 3 | 6 | 4 | 100% / 9% (slechtste: 100%) | 6 | 100% / 4% (slechtste: 100%) |
| First Archive floor 4 | 7 | 6 | 100% / 11% (slechtste: 100%) | 7 | 100% / 7% (slechtste: 100%) |
| BOSS Golem (First Archive) | 8 | 7 | 73% / 68% (slechtste: 73%) | 8 | 83% / 66% (slechtste: 83%) |
| STORY Ink Worm (secret cabinet, First Archive) | 8 | 8 | 100% / 40% (slechtste: 100%) | 8 | 100% / 40% (slechtste: 100%) |
| Dark Wood | 11 | 8 | 80% / 50% (slechtste: 0%) | 13 | 100% / 17% (slechtste: 100%) |
| STORY Singing Seed (Dark Wood) | 11 | 13 | 100% / 1% (slechtste: 100%) | 13 | 100% / 1% (slechtste: 100%) |
| BOSS Root King (Dark Wood) | 12 | 13 | 100% / 55% (slechtste: 100%) | 14 | 100% / 53% (slechtste: 100%) |
| Mountain Cave (Berggrot) | 13 | 14 | 100% / 0% (slechtste: 100%) | 14 | 100% / 0% (slechtste: 100%) |
| Second Archive floor 1 | 14 | 14 | 100% / 0% (slechtste: 100%) | 15 | 100% / 0% (slechtste: 100%) |
| Second Archive floor 2 | 14 | 15 | 100% / 0% (slechtste: 100%) | 15 | 100% / 0% (slechtste: 100%) |
| STORY Seren/Lotte (Second Archive, Dax alone) | 15 | 15 | 100% / 0% (slechtste: 100%) | 15 | 100% / 0% (slechtste: 100%) |
| Second Archive floor 3 | 16 | 15 | 100% / 0% (slechtste: 100%) | 15 | 100% / 0% (slechtste: 100%) |
| Second Archive floor 4 | 16 | 15 | 100% / 0% (slechtste: 100%) | 15 | 100% / 0% (slechtste: 100%) |
| BOSS The Strangler (Second Archive) | 16 | 15 | 100% / 11% (slechtste: 100%) | 15 | 100% / 11% (slechtste: 100%) |
| BOSS The Mender (Second Archive) | 16 | 15 | 100% / 22% (slechtste: 100%) | 15 | 100% / 22% (slechtste: 100%) |

**Donker Woud kamer voor kamer** (volgorde `WoudRooms.ORDER`, EXP uit de kamers zelf, start met de EXP van de gebieden ervoor):

| Kamer | Niveau | Monsters | EXP kamer | Level bij binnenkomst | Winst op dat level | HP-verlies | Slechtste groep |
|---|---:|---:|---:|---:|---|---|---|
| Dark Wood - Wood's Edge | 3 | 3 | 147 | 8 | 100% | 8% | Root Crawler (tier 3) (100%) |
| Dark Wood - Root Path | 3 | 5 | 480 | 9 | 100% | 30% | Root Crawler + Root Crawler (tier 3) (100%) |
| Dark Wood - Mist Pool | 4 | 4 | 441 | 11 | 98% | 40% | Root Crawler + Mist Owl + Root Crawler (tier 4) (92%) |
| Dark Wood - Spore Ring | 4 | 3 | 396 | 12 | 98% | 45% | Root Crawler + Root Crawler + Spore Cap (tier 4) (95%) |

### Goudcurve

Zelfde model als de EXP-curve (elk map-monster één keer). Uitgaven: de winkelstukken uit de uitrusting die de sim voor dat gebied aanneemt (alleen wat Wilgendal verkoopt, `shop_data.gd`; Spark Sword, smeedspullen en kistvondsten kosten niets), spreuken (`160 x grade^2`, de winkel verkoopt per act tot grade = act, max 3) en een referentiewaarde voor verbruikte genees-items. In WM1 zijn potions niet te koop (alleen vondsten); de itemwaarde laat zien wat de gevechten aan voorraad opslokken.

Winkelaanbod uitrusting (zonder magie en Handelskamer): Act 1 = 650 g, Act 2 erbij = 390 g. Spreuk grade 1 = 160 g, grade 2 = 640 g, grade 3 = 1440 g.

| Gebied | Goud dit gebied (opruimen) | Cumulatief goud | Kosten winkeluitrusting van de party | Items verbruikt per gevecht (waarde) | Goud per gevecht | Netto goud per gevecht | Gevechten per spreuk grade 1 (160 g) | per spreuk grade 2 (640 g) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Worldmap 1 (grass, random encounters) | willekeurig | - | 190 | 0.00 (0 g) | 6.5 | 6.5 | 25 | 99 |
| First Archive floor 1 | 27 | 27 | 190 | 0.00 (0 g) | 3.0 | 3.0 | 54 | 214 |
| First Archive floor 2 | 82 | 109 | 260 | 0.00 (0 g) | 9.1 | 9.1 | 18 | 71 |
| First Archive floor 3 | 139 | 248 | 190 | 0.00 (0 g) | 17.4 | 17.4 | 10 | 37 |
| First Archive floor 4 | 217 | 465 | 190 | 0.00 (0 g) | 27.1 | 27.1 | 6 | 24 |
| BOSS Golem (First Archive) | 84 | 549 | 190 | 4.98 (140 g) | 84.0 | -56.4 | nooit | nooit |
| STORY Ink Worm (secret cabinet, First Archive) | 40 | 589 | 190 | 0.00 (0 g) | 40.0 | 40.0 | 4 | 16 |
| Dark Wood | 702 | 1291 | 240 | 1.00 (28 g) | 46.8 | 19.0 | 9 | 34 |
| STORY Singing Seed (Dark Wood) | 4 | 1295 | 240 | 0.00 (0 g) | 4.0 | 4.0 | 40 | 160 |
| BOSS Root King (Dark Wood) | 150 | 1445 | 240 | 3.69 (107 g) | 150.0 | 43.3 | 4 | 15 |
| Mountain Cave (Berggrot) | 48 | 1493 | 360 | 0.00 (0 g) | 9.6 | 9.6 | 17 | 67 |
| Second Archive floor 1 | 43 | 1536 | 360 | 0.00 (0 g) | 21.5 | 21.5 | 8 | 30 |
| Second Archive floor 2 | 47 | 1583 | 360 | 0.00 (0 g) | 23.5 | 23.5 | 7 | 28 |
| STORY Seren/Lotte (Second Archive, Dax alone) | 0 | 1583 | 360 | 0.00 (0 g) | 0.0 | 0.0 | nooit | nooit |
| Second Archive floor 3 | 33 | 1616 | 180 | 0.00 (0 g) | 33.0 | 33.0 | 5 | 20 |
| Second Archive floor 4 | 38 | 1654 | 180 | 0.00 (0 g) | 38.0 | 38.0 | 5 | 17 |
| BOSS The Strangler (Second Archive) | 20 | 1674 | 180 | 0.01 (0 g) | 20.0 | 19.6 | 9 | 33 |
| BOSS The Mender (Second Archive) | 40 | 1714 | 180 | 0.08 (2 g) | 40.0 | 37.6 | 5 | 17 |
| Worldmap 1 (bos, random encounters) | willekeurig | - | 190 | 0.00 (0 g) | 8.0 | 8.0 | 21 | 81 |
| Worldmap 1 (zand, random encounters) | willekeurig | - | 190 | 0.00 (0 g) | 8.8 | 8.8 | 19 | 73 |

Winkelprijzen ter referentie (`ShopData.list_price`): Short Sword 120, Wooden Shield 40, Cover Shield 90, Leather Hood 30, Leather Armor 70, Iron Helm 80, Oak Staff 90, Travel Robe 30.

### Outliers (per encounter-groep, ontwerp-level)

Alle groepen met een vlag, behalve TRIVIAL (die staat per gebied geteld in de laatste kolom). Sensitiviteit: kleinste level-delta (t.o.v. het ontwerp-level) waarbij de winst op de ondergrens ligt (`0` = ontwerp-level, `-1` = één level lager nog genoeg).

| Gebied | Groep | n | Winst | Rondes tot winst | HP-verlies (p90) | Schade | EXP | Goud | Level-venster | Vlaggen |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| Worldmap 1 (grass, random encounters) | The Knowledge Beast + Paper Wraith | 300 | 100% | 4.0 | 36% (47%) | 22 (36%) | 29.0 | 22.0 | -2 | SPIKE |
| Dark Wood | Root Crawler + Mist Owl + Root Crawler (tier 4) | 300 | 92% | 7.2 | 63% (98%) | 164 (124%) | 141.0 | 72.0 | +1 | DEADLY, HEAVY, SPIKE |
| Dark Wood | Root Crawler + Spore Cap (tier 4) | 300 | 100% | 4.0 | 43% (52%) | 57 (43%) | 102.0 | 55.0 | -3 | SPIKE |
| Dark Wood | Spore Cap + Spore Cap + Mist Owl (tier 4) | 300 | 98% | 11.5 | 63% (87%) | 245 (186%) | 153.0 | 82.0 | 0 | HEAVY, SLOG, SPIKE, CLIFF |
| Dark Wood | Root Crawler + Root Crawler + Spore Cap (tier 4) | 300 | 52% | 11.6 | 91% (100%) | 310 (235%) | 150.0 | 80.0 | +1 | DEADLY, HEAVY, SLOG, SPIKE, CLIFF |
| BOSS Root King (Dark Wood) | The Root King [BOSS] | 600 | 99% | 10.9 | 57% (65%) | 190 (134%) | 400.0 | 150.0 | -1 | BOSS-EASY |
| STORY Seren/Lotte (Second Archive, Dax alone) | Seren [BOSS] | 600 | 100% | 1.1 | 0% (1%) | 0 (0%) | 20.0 | 0.0 | -3 | BOSS-EASY, BOSS-SHORT |
| BOSS The Strangler (Second Archive) | The Strangler [BOSS] | 600 | 100% | 3.0 | 8% (15%) | 33 (8%) | 48.0 | 20.0 | -3 | BOSS-EASY, BOSS-SHORT |
| BOSS The Mender (Second Archive) | The Mender [BOSS] | 600 | 100% | 4.0 | 22% (27%) | 91 (23%) | 90.0 | 40.0 | -3 | BOSS-EASY, BOSS-SHORT |
| Worldmap 1 (bos, random encounters) | The Knowledge Beast + Paper Wraith | 300 | 100% | 4.0 | 36% (50%) | 22 (37%) | 29.0 | 22.0 | -2 | SPIKE |
| Worldmap 1 (zand, random encounters) | The Knowledge Beast + Paper Wraith | 300 | 100% | 4.0 | 35% (48%) | 21 (36%) | 29.0 | 22.0 | -2 | SPIKE |

TRIVIAL-groepen (per gebied): Worldmap 1 (grass, random encounters): 5 van 10; First Archive floor 1: 6 van 8; First Archive floor 2: 4 van 8; First Archive floor 3: 2 van 7; First Archive floor 4: 1 van 7; Dark Wood: 3 van 15; STORY Singing Seed (Dark Wood): 1 van 1; Mountain Cave (Berggrot): 3 van 3; Second Archive floor 1: 2 van 2; Second Archive floor 2: 2 van 2; Second Archive floor 3: 1 van 1; Second Archive floor 4: 1 van 1; Worldmap 1 (bos, random encounters): 3 van 7; Worldmap 1 (zand, random encounters): 2 van 6.

### Alle groepen per gebied

Kolommen `Lv-2`..`Lv+2` (wereldkaart tot `Lv+5`) = `winst / HP-verlies` met de hele party dat aantal levels lager/hoger. `Schade` = gemiddelde directe schade aan de party per gevecht (en als % van de party-max-HP); `Sch./ronde` = schade per ronde.

#### Worldmap 1 (grass, random encounters) (`wereldkaart1`)

- Party: Dax Lv3 (HP 60 MP 0 ATK 23 DEF 17 AGI 11 MAG 2; Short Sword, Wooden Shield, Leather Hood, Apprentice Cloak; spells: -)
- Tas: {"drankje":3,"kruid":2,"toverwater":1}
- Aanname: Random-encounter pool for terrain 'gras' (GameData.ENCOUNTER_GROUPS + weights). Dax solo, Lv 3.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Lv+3 | Lv+4 | Lv+5 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Moss Slime | 3 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 3.0 | 2.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -2 | TRIVIAL |
| Moss Slime + Moss Slime | 2 | 300 | 100% | 2.0 | 2% | 2% | 1 (2%) | 0.5 | 0.00 | 6.0 | 4.0 | 100%/2% | 100%/2% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | -2 | TRIVIAL |
| Moss Rabbit | 2 | 300 | 100% | 1.0 | 1% | 2% | 1 (1%) | 0.8 | 0.00 | 4.0 | 3.0 | 100%/6% | 100%/3% | 100%/1% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -2 | TRIVIAL |
| Moss Rabbit + Moss Slime | 2 | 300 | 100% | 2.0 | 3% | 3% | 2 (3%) | 0.9 | 0.00 | 7.0 | 5.0 | 100%/12% | 100%/6% | 100%/2% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | -2 |  |
| Paper Wraith | 3 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 5.0 | 4.0 | 100%/3% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -2 | TRIVIAL |
| Paper Wraith + Paper Wraith | 3 | 300 | 100% | 2.0 | 2% | 2% | 1 (2%) | 0.5 | 0.00 | 10.0 | 8.0 | 100%/14% | 100%/3% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | -2 | TRIVIAL |
| Glitch Moth + Paper Wraith | 3 | 300 | 100% | 2.0 | 4% | 5% | 2 (4%) | 1.2 | 0.00 | 11.0 | 7.0 | 100%/17% | 100%/8% | 100%/3% | 100%/2% | 100%/2% | 100%/1% | 100%/1% | -2 |  |
| Glitch Moth + Glitch Moth + Glitch Moth | 1 | 300 | 100% | 3.0 | 15% | 18% | 9 (15%) | 3.0 | 0.00 | 18.0 | 9.0 | 100%/50% | 100%/30% | 100%/9% | 100%/7% | 100%/5% | 100%/4% | 100%/3% | -2 |  |
| The Knowledge Beast | 1 | 300 | 100% | 3.0 | 25% | 32% | 15 (25%) | 4.9 | 0.00 | 24.0 | 18.0 | 100%/37% | 100%/32% | 100%/15% | 100%/7% | 100%/5% | 100%/3% | 100%/2% | -2 |  |
| The Knowledge Beast + Paper Wraith | 1 | 300 | 100% | 4.0 | 36% | 47% | 22 (36%) | 5.4 | 0.01 | 29.0 | 22.0 | 100%/36% | 100%/41% | 100%/23% | 100%/14% | 100%/10% | 100%/7% | 100%/5% | -2 | SPIKE |

#### First Archive floor 1 (`archief1_v1`)

- Party: Dax Lv3 (HP 60 MP 0 ATK 23 DEF 17 AGI 11 MAG 2; Short Sword, Wooden Shield, Leather Hood, Apprentice Cloak; spells: -)
- Tas: {"drankje":3,"kruid":2,"toverwater":1}
- Aanname: Map monsters of every floor-1 room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7).

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Moss Slime (tier 1) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 3.0 | 1.0 | - | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -2 | TRIVIAL |
| Moss Rabbit (tier 1) | 1 | 300 | 100% | 1.0 | 1% | 2% | 1 (1%) | 0.8 | 0.00 | 4.0 | 2.0 | - | 100%/2% | 100%/2% | 100%/1% | 100%/0% | -2 | TRIVIAL |
| Paper Wraith (tier 1) | 2 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 5.0 | 3.0 | - | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -2 | TRIVIAL |
| Moss Slime + Moss Slime (tier 1) | 1 | 300 | 100% | 2.0 | 2% | 2% | 1 (2%) | 0.5 | 0.00 | 6.0 | 2.0 | - | 100%/2% | 100%/2% | 100%/1% | 100%/1% | -2 | TRIVIAL |
| Moss Rabbit + Moss Slime (tier 1) | 1 | 300 | 100% | 2.0 | 3% | 3% | 2 (3%) | 0.9 | 0.00 | 7.0 | 3.0 | - | 100%/5% | 100%/4% | 100%/2% | 100%/2% | -2 |  |
| Glitch Moth (tier 1) | 1 | 300 | 100% | 1.0 | 2% | 2% | 1 (2%) | 1.0 | 0.00 | 6.0 | 2.0 | - | 100%/2% | 100%/2% | 100%/1% | 100%/1% | -2 | TRIVIAL |
| Paper Wraith + Paper Wraith (tier 1) | 1 | 300 | 100% | 2.0 | 2% | 2% | 1 (2%) | 0.5 | 0.00 | 10.0 | 6.0 | - | 100%/2% | 100%/2% | 100%/1% | 100%/1% | -2 | TRIVIAL |
| Paper Wraith + Glitch Moth (tier 1) | 1 | 300 | 100% | 2.0 | 3% | 3% | 2 (3%) | 1.0 | 0.00 | 11.0 | 5.0 | - | 100%/5% | 100%/4% | 100%/3% | 100%/2% | -2 |  |

#### First Archive floor 2 (`archief1_v2`)

- Party: Dax Lv5 (HP 78 MP 0 ATK 29 DEF 23 AGI 13 MAG 2; Short Sword, Wooden Shield, Leather Hood, Leather Armor; spells: -)
- Tas: {"drankje":3,"kruid":2,"toverwater":1}
- Aanname: Map monsters of every floor-2 room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7).

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Paper Wraith + Paper Wraith (tier 2) | 1 | 300 | 100% | 2.0 | 1% | 1% | 1 (1%) | 0.5 | 0.00 | 12.0 | 8.0 | 100%/3% | 100%/2% | 100%/1% | 100%/1% | 100%/1% | -3 | TRIVIAL |
| Glitch Moth (tier 2) | 1 | 300 | 100% | 1.0 | 1% | 1% | 1 (1%) | 0.8 | 0.00 | 8.0 | 3.0 | 100%/3% | 100%/2% | 100%/1% | 100%/1% | 100%/0% | -3 | TRIVIAL |
| Mech. Warden (tier 2) | 2 | 300 | 100% | 2.0 | 2% | 5% | 1 (2%) | 0.6 | 0.00 | 12.0 | 8.0 | 100%/8% | 100%/3% | 100%/2% | 100%/1% | 100%/0% | -3 | TRIVIAL |
| Glitch Moth + Paper Wraith (tier 2) | 1 | 300 | 100% | 2.0 | 2% | 3% | 2 (2%) | 0.9 | 0.00 | 14.0 | 7.0 | 100%/5% | 100%/3% | 100%/3% | 100%/2% | 100%/1% | -3 | TRIVIAL |
| Paper Wraith + Paper Wraith + Glitch Moth (tier 2) | 1 | 300 | 100% | 3.0 | 5% | 5% | 4 (5%) | 1.3 | 0.00 | 20.0 | 11.0 | 100%/10% | 100%/7% | 100%/6% | 100%/4% | 100%/3% | -3 |  |
| Glitch Moth + Glitch Moth (tier 2) | 1 | 300 | 100% | 2.0 | 3% | 4% | 2 (3%) | 1.2 | 0.00 | 16.0 | 6.0 | 100%/9% | 100%/5% | 100%/4% | 100%/2% | 100%/1% | -3 |  |
| Mech. Warden + Paper Wraith (tier 2) | 1 | 300 | 100% | 3.0 | 3% | 6% | 2 (3%) | 0.7 | 0.00 | 18.0 | 12.0 | 100%/15% | 100%/6% | 100%/4% | 100%/2% | 100%/2% | -3 |  |
| The Knowledge Beast (tier 2) | 1 | 300 | 100% | 2.1 | 4% | 12% | 3 (4%) | 1.6 | 0.00 | 30.0 | 19.0 | 100%/27% | 100%/16% | 100%/11% | 100%/3% | 100%/2% | -3 |  |

#### First Archive floor 3 (`archief1_v3`)

- Party: Dax Lv6 (HP 87 MP 0 ATK 41 DEF 26 AGI 14 MAG 2; Spark Sword, Cover Shield, Leather Hood, Leather Armor; spells: -)
- Tas: {"drankje":5,"kruid":2,"toverwater":2}
- Aanname: Map monsters of every floor-3 room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7).

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Glitch Moth + Glitch Moth (tier 3) | 1 | 300 | 100% | 2.0 | 2% | 3% | 2 (2%) | 1.0 | 0.00 | 18.0 | 8.0 | 100%/10% | 100%/4% | 100%/3% | 100%/2% | 100%/1% | -3 | TRIVIAL |
| Mech. Warden (tier 3) | 2 | 300 | 100% | 1.8 | 1% | 1% | 1 (1%) | 0.5 | 0.00 | 15.0 | 11.0 | 100%/6% | 100%/3% | 100%/2% | 100%/1% | 100%/0% | -3 | TRIVIAL |
| Mech. Warden + Glitch Moth (tier 3) | 1 | 300 | 100% | 2.8 | 3% | 7% | 3 (3%) | 1.0 | 0.00 | 24.0 | 15.0 | 100%/12% | 100%/7% | 100%/5% | 100%/2% | 100%/1% | -3 |  |
| The Knowledge Beast (tier 3) | 1 | 300 | 100% | 2.0 | 4% | 11% | 4 (4%) | 1.8 | 0.00 | 36.0 | 25.0 | 100%/22% | 100%/12% | 100%/6% | 100%/3% | 100%/2% | -3 |  |
| Paper Wraith + Paper Wraith + Glitch Moth (tier 3) | 1 | 300 | 100% | 3.0 | 4% | 5% | 4 (4%) | 1.2 | 0.00 | 25.0 | 16.0 | 100%/8% | 100%/6% | 100%/5% | 100%/3% | 100%/3% | -3 |  |
| Mech. Warden + Mech. Warden (tier 3) | 1 | 300 | 100% | 3.6 | 5% | 9% | 5 (5%) | 1.3 | 0.00 | 30.0 | 22.0 | 100%/20% | 100%/14% | 100%/8% | 100%/4% | 100%/2% | -3 |  |
| The Knowledge Beast + Paper Wraith (tier 3) | 1 | 300 | 100% | 3.0 | 9% | 15% | 8 (9%) | 2.6 | 0.00 | 44.0 | 31.0 | 100%/35% | 100%/20% | 100%/12% | 100%/6% | 100%/5% | -3 |  |

#### First Archive floor 4 (`archief1_v4`)

- Party: Dax Lv7 (HP 96 MP 0 ATK 44 DEF 28 AGI 15 MAG 2; Spark Sword, Cover Shield, Leather Hood, Leather Armor; spells: -)
- Tas: {"drankje":5,"kruid":2,"toverwater":2}
- Aanname: Map monsters of every floor-4 room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7).

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Mech. Warden (tier 4) | 1 | 300 | 100% | 2.0 | 2% | 7% | 2 (2%) | 0.8 | 0.00 | 15.0 | 14.0 | 100%/6% | 100%/4% | 100%/2% | 100%/1% | 100%/1% | -3 | TRIVIAL |
| Glitch Moth + Glitch Moth + Glitch Moth (tier 4) | 1 | 300 | 100% | 3.0 | 4% | 5% | 4 (4%) | 1.2 | 0.00 | 27.0 | 18.0 | 100%/26% | 100%/14% | 100%/5% | 100%/3% | 100%/3% | -3 |  |
| Mech. Warden + Glitch Moth (tier 4) | 1 | 300 | 100% | 3.0 | 3% | 9% | 3 (3%) | 1.1 | 0.00 | 24.0 | 20.0 | 100%/15% | 100%/10% | 100%/6% | 100%/3% | 100%/2% | -3 |  |
| The Knowledge Beast (tier 4) | 2 | 300 | 100% | 2.2 | 7% | 14% | 6 (7%) | 2.9 | 0.00 | 36.0 | 32.0 | 100%/23% | 100%/18% | 100%/11% | 100%/3% | 100%/3% | -3 |  |
| Mech. Warden + Mech. Warden (tier 4) | 1 | 300 | 100% | 4.0 | 7% | 10% | 6 (7%) | 1.6 | 0.00 | 30.0 | 28.0 | 100%/24% | 100%/16% | 100%/11% | 100%/6% | 100%/4% | -3 |  |
| The Knowledge Beast + Mech. Warden (tier 4) | 1 | 300 | 100% | 4.2 | 19% | 29% | 18 (19%) | 4.3 | 0.00 | 51.0 | 46.0 | 100%/43% | 100%/38% | 100%/28% | 100%/12% | 100%/8% | -3 |  |
| Mech. Warden + Paper Wraith + Glitch Moth (tier 4) | 1 | 300 | 100% | 4.0 | 6% | 11% | 6 (6%) | 1.5 | 0.00 | 32.0 | 27.0 | 100%/25% | 100%/16% | 100%/10% | 100%/5% | 100%/4% | -3 |  |

#### BOSS Golem (First Archive) (`golem`)

- Party: Dax Lv8 (HP 105 MP 0 ATK 47 DEF 30 AGI 16 MAG 2; Spark Sword, Cover Shield, Leather Hood, Leather Armor; spells: -)
- Tas: {"drankje":5,"kruid":2,"toverwater":2}
- Aanname: Golem Hall boss (kennis_beest + pink core). Dax Lv 8 with Spark Sword.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| The Knowledge Beast [BOSS] | 1 | 600 | 83% | 15.2 | 66% | 100% | 214 (204%) | 13.7 | 4.98 | 210.0 | 84.0 | 21%/92% | 39%/87% | 73%/68% | 98%/57% | 99%/54% | 0 |  |

#### STORY Ink Worm (secret cabinet, First Archive) (`inktwurm`)

- Party: Dax Lv8 (HP 105 MP 0 ATK 47 DEF 30 AGI 16 MAG 2; Spark Sword, Cover Shield, Leather Hood, Leather Armor; spells: -)
- Tas: {"drankje":5,"kruid":2,"toverwater":2}
- Aanname: Unique monster (fixed Lv 5 stats, no tier). Fought after the Golem; capture is not modelled, a win = defeated. Dax Lv 8.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Ink Worm | 1 | 300 | 100% | 2.0 | 40% | 44% | 42 (40%) | 21.0 | 0.00 | 60.0 | 40.0 | 94%/87% | 100%/72% | 100%/51% | 100%/35% | 100%/31% | -2 |  |

#### Dark Wood (`woud`)

- Party: Dax Lv11 (HP 132 MP 0 ATK 56 DEF 38 AGI 19 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Core: golemkern
- Tas: {"drankje":5,"kruid":2,"toverwater":2}
- Aanname: All Dark Wood map monsters, room tier 3 (no archief scaling). Dax solo Lv 11 + Golem Core (Core Strike).

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Root Crawler (tier 3) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 48.0 | 20.0 | 100%/5% | 100%/2% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |
| Mist Owl (tier 3) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 45.0 | 18.0 | 100%/7% | 100%/2% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |
| Spore Cap (tier 3) | 1 | 300 | 100% | 1.3 | 2% | 5% | 3 (2%) | 1.4 | 0.00 | 54.0 | 24.0 | 100%/11% | 100%/6% | 100%/5% | 100%/0% | 100%/0% | -3 | TRIVIAL |
| Root Crawler + Root Crawler (tier 3) | 1 | 300 | 100% | 3.0 | 18% | 23% | 23 (18%) | 7.8 | 0.00 | 96.0 | 40.0 | 100%/36% | 100%/31% | 100%/21% | 100%/15% | 100%/13% | -3 |  |
| Mist Owl + Root Crawler (tier 3) | 1 | 300 | 100% | 2.4 | 10% | 15% | 13 (10%) | 5.2 | 0.00 | 93.0 | 38.0 | 100%/40% | 100%/24% | 100%/14% | 100%/7% | 100%/5% | -3 |  |
| Spore Cap + Mist Owl (tier 3) | 1 | 300 | 100% | 2.7 | 15% | 28% | 20 (15%) | 6.8 | 0.00 | 99.0 | 42.0 | 100%/52% | 100%/34% | 100%/21% | 100%/9% | 100%/5% | -3 |  |
| Root Crawler + Spore Cap (tier 3) | 1 | 300 | 100% | 3.3 | 22% | 34% | 29 (22%) | 8.6 | 0.00 | 102.0 | 44.0 | 100%/49% | 100%/38% | 100%/30% | 100%/17% | 100%/14% | -3 |  |
| Mist Owl + Mist Owl (tier 3) | 1 | 300 | 100% | 2.4 | 10% | 17% | 13 (10%) | 5.3 | 0.00 | 90.0 | 36.0 | 100%/35% | 100%/22% | 100%/14% | 100%/7% | 100%/5% | -3 |  |
| Mist Owl + Mist Owl (tier 4) | 1 | 300 | 100% | 3.0 | 19% | 23% | 25 (19%) | 8.3 | 0.00 | 90.0 | 44.0 | 100%/47% | 100%/31% | 100%/24% | 100%/16% | 100%/13% | -3 |  |
| Spore Cap + Spore Cap (tier 4) | 1 | 300 | 100% | 4.0 | 36% | 45% | 47 (36%) | 11.7 | 0.00 | 108.0 | 60.0 | 100%/51% | 100%/46% | 100%/42% | 100%/26% | 100%/21% | -3 |  |
| Root Crawler + Mist Owl + Root Crawler (tier 4) | 1 | 300 | 92% | 7.2 | 63% | 98% | 164 (124%) | 20.1 | 2.80 | 141.0 | 72.0 | 0%/100% | 12%/95% | 70%/75% | 100%/50% | 100%/41% | +1 | DEADLY, HEAVY, SPIKE |
| Root Crawler + Spore Cap (tier 4) | 1 | 300 | 100% | 4.0 | 43% | 52% | 57 (43%) | 14.1 | 0.02 | 102.0 | 55.0 | 100%/55% | 100%/53% | 100%/48% | 100%/35% | 100%/27% | -3 | SPIKE |
| Spore Cap + Spore Cap + Mist Owl (tier 4) | 1 | 300 | 98% | 11.5 | 63% | 87% | 245 (186%) | 21.0 | 5.57 | 153.0 | 82.0 | 1%/100% | 21%/97% | 68%/87% | 100%/51% | 100%/44% | 0 | HEAVY, SLOG, SPIKE, CLIFF |
| Root Crawler + Root Crawler + Spore Cap (tier 4) | 1 | 300 | 52% | 11.6 | 91% | 100% | 310 (235%) | 27.8 | 6.64 | 150.0 | 80.0 | 0%/100% | 0%/100% | 9%/97% | 95%/67% | 100%/51% | +1 | DEADLY, HEAVY, SLOG, SPIKE, CLIFF |
| Mist Owl + Root Crawler (tier 4) | 1 | 300 | 100% | 3.4 | 27% | 42% | 36 (27%) | 10.1 | 0.00 | 93.0 | 47.0 | 100%/59% | 100%/48% | 100%/37% | 100%/19% | 100%/14% | -3 |  |

#### STORY Singing Seed (Dark Wood) (`woud_story`)

- Party: Dax Lv11 (HP 132 MP 0 ATK 56 DEF 38 AGI 19 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Core: golemkern
- Tas: {"drankje":5,"kruid":2,"toverwater":2}
- Aanname: Scripted story battle (story_data.gd, 'zingend_zaad_na'): 2 Wood Spirits, tier 0. Dax Lv 11 like the Dark Wood.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Wood Wraith + Wood Wraith | 1 | 300 | 100% | 2.0 | 1% | 1% | 1 (1%) | 0.5 | 0.00 | 8.0 | 4.0 | 100%/1% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | -3 | TRIVIAL |

#### BOSS Root King (Dark Wood) (`wortelkoning`)

- Party: Dax Lv12 (HP 141 MP 0 ATK 59 DEF 40 AGI 20 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Core: golemkern
- Tas: {"drankje":5,"kruid":2,"toverwater":2}
- Aanname: Root King, Dax solo Lv 12 (Vesper joins after this fight).

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| The Root King [BOSS] | 1 | 600 | 99% | 10.9 | 57% | 65% | 190 (134%) | 16.9 | 3.69 | 400.0 | 150.0 | 46%/90% | 77%/76% | 96%/63% | 100%/55% | 100%/53% | -1 | BOSS-EASY |

#### Mountain Cave (Berggrot) (`berggrot`)

- Party: Dax Lv13 (HP 150 MP 0 ATK 62 DEF 42 AGI 21 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv12 (HP 83 MP 62 ATK 20 DEF 20 AGI 33 MAG 36; Oak Staff, Leather Hood, Padded Jerkin; spells: Spark, Chain Lightning); Core: golemkern
- Tas: {"drankje":5,"kruid":2,"toverwater":2}
- Aanname: Berggrot map monsters (tier 0). Dax Lv 13 + Vesper Lv 12 (joined at Dax-1).

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Stone Louse | 2 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 16.0 | 10.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |
| Vein Moth | 2 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 16.0 | 8.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |
| Drip Slug | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 18.0 | 12.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |

#### Second Archive floor 1 (`archief2_v1`)

- Party: Dax Lv14 (HP 159 MP 0 ATK 65 DEF 44 AGI 22 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv13 (HP 88 MP 66 ATK 21 DEF 21 AGI 35 MAG 38; Oak Staff, Leather Hood, Padded Jerkin; spells: Spark, Chain Lightning); Core: golemkern
- Tas: {"drankje":6,"kruid":3,"toverwater":3}
- Aanname: Archief 2 map monsters floor 1 (tier from room, archief scaling). Dax Lv 14 + Vesper Lv 13.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Tendril + Tendril (tier 2) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 40.0 | 20.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |
| Thorn Runner + Root Crawler (tier 2) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 44.0 | 23.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |

#### Second Archive floor 2 (`archief2_v2`)

- Party: Dax Lv14 (HP 159 MP 0 ATK 65 DEF 44 AGI 22 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv13 (HP 88 MP 66 ATK 21 DEF 21 AGI 35 MAG 38; Oak Staff, Leather Hood, Padded Jerkin; spells: Spark, Chain Lightning); Core: golemkern
- Tas: {"drankje":6,"kruid":3,"toverwater":3}
- Aanname: Archief 2 map monsters floor 2 (tier from room, archief scaling). Dax Lv 14 + Vesper Lv 13.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Thorn Runner + Tendril (tier 2) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 44.0 | 23.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |
| Sporehead + Spore Cap (tier 2) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 43.0 | 24.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |

#### STORY Seren/Lotte (Second Archive, Dax alone) (`lotte`)

- Party: Dax Lv15 (HP 168 MP 0 ATK 68 DEF 46 AGI 23 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv14 (HP 93 MP 70 ATK 22 DEF 22 AGI 37 MAG 40; Oak Staff, Leather Hood, Padded Jerkin; spells: Spark, Chain Lightning); Core: golemkern
- Tas: {"drankje":6,"kruid":3,"toverwater":3}
- Aanname: Story fight: only Dax fights (archief2_party_filter = dennis), no Codex ally. Win or lose both continue the story.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Seren [BOSS] | 1 | 600 | 100% | 1.1 | 0% | 1% | 0 (0%) | 0.1 | 0.00 | 20.0 | 0.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | BOSS-EASY, BOSS-SHORT |

#### Second Archive floor 3 (`archief2_v3`)

- Party: Dax Lv16 (HP 177 MP 0 ATK 77 DEF 65 AGI 23 MAG 2; Kettle Blade, Kettle Shield, Kettle Helm, Scrap Plate; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 23 DEF 26 AGI 39 MAG 46; Oak Staff, Leather Hood, Work Cloak; spells: Spark, Chain Lightning); Seren Lv16 (HP 122 MP 59 ATK 42 DEF 23 AGI 23 MAG 51; Tuning Fork, Leather Hood, Travel Robe; spells: Minor Heal, Icicle); Core: golemkern
- Tas: {"drankje":6,"kruid":3,"toverwater":3}
- Aanname: Archief 2 floor 3. Full party: Dax 16, Vesper 15, Seren 16 (joins at Dax's level), Act-2 forge gear.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Blooming Dread + Sporehead (tier 3) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 56.0 | 33.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |

#### Second Archive floor 4 (`archief2_v4`)

- Party: Dax Lv16 (HP 177 MP 0 ATK 77 DEF 65 AGI 23 MAG 2; Kettle Blade, Kettle Shield, Kettle Helm, Scrap Plate; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 23 DEF 26 AGI 39 MAG 46; Oak Staff, Leather Hood, Work Cloak; spells: Spark, Chain Lightning); Seren Lv16 (HP 122 MP 59 ATK 42 DEF 23 AGI 23 MAG 51; Tuning Fork, Leather Hood, Travel Robe; spells: Minor Heal, Icicle); Core: golemkern
- Tas: {"drankje":6,"kruid":3,"toverwater":3}
- Aanname: Archief 2 floor 4. Full party: Dax 16, Vesper 15, Seren 16 (joins at Dax's level), Act-2 forge gear.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Rootghost + Blooming Dread (tier 3) | 1 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 62.0 | 38.0 | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -3 | TRIVIAL |

#### BOSS The Strangler (Second Archive) (`a2boss_wurger`)

- Party: Dax Lv16 (HP 177 MP 0 ATK 77 DEF 65 AGI 23 MAG 2; Kettle Blade, Kettle Shield, Kettle Helm, Scrap Plate; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 23 DEF 26 AGI 39 MAG 46; Oak Staff, Leather Hood, Work Cloak; spells: Spark, Chain Lightning); Seren Lv16 (HP 122 MP 59 ATK 42 DEF 23 AGI 23 MAG 51; Tuning Fork, Leather Hood, Travel Robe; spells: Minor Heal, Icicle); Core: golemkern
- Tas: {"drankje":6,"kruid":3,"toverwater":3}
- Aanname: Archief 2 boss, same party as floors 3-4.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| The Strangler [BOSS] | 1 | 600 | 100% | 3.0 | 8% | 15% | 33 (8%) | 11.0 | 0.01 | 48.0 | 20.0 | 100%/15% | 100%/14% | 100%/11% | 100%/7% | 100%/7% | -3 | BOSS-EASY, BOSS-SHORT |

#### BOSS The Mender (Second Archive) (`a2boss_genezer`)

- Party: Dax Lv16 (HP 177 MP 0 ATK 77 DEF 65 AGI 23 MAG 2; Kettle Blade, Kettle Shield, Kettle Helm, Scrap Plate; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 23 DEF 26 AGI 39 MAG 46; Oak Staff, Leather Hood, Work Cloak; spells: Spark, Chain Lightning); Seren Lv16 (HP 122 MP 59 ATK 42 DEF 23 AGI 23 MAG 51; Tuning Fork, Leather Hood, Travel Robe; spells: Minor Heal, Icicle); Core: golemkern
- Tas: {"drankje":6,"kruid":3,"toverwater":3}
- Aanname: Archief 2 boss, same party as floors 3-4.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-3 | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| The Mender [BOSS] | 1 | 600 | 100% | 4.0 | 22% | 27% | 91 (23%) | 22.7 | 0.08 | 90.0 | 40.0 | 100%/22% | 100%/22% | 100%/22% | 100%/23% | 100%/23% | -3 | BOSS-EASY, BOSS-SHORT |

#### Worldmap 1 (bos, random encounters) (`wereldkaart1_bos`)

- Party: Dax Lv3 (HP 60 MP 0 ATK 23 DEF 17 AGI 11 MAG 2; Short Sword, Wooden Shield, Leather Hood, Apprentice Cloak; spells: -)
- Tas: {"drankje":3,"kruid":2,"toverwater":1}
- Aanname: Random-encounter pool for terrain 'bos' (rate 10% per step). Same party as Worldmap 1.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Lv+3 | Lv+4 | Lv+5 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Moss Rabbit | 2 | 300 | 100% | 1.0 | 1% | 2% | 1 (1%) | 0.8 | 0.00 | 4.0 | 3.0 | 100%/6% | 100%/3% | 100%/1% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -2 | TRIVIAL |
| Paper Wraith | 3 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 5.0 | 4.0 | 100%/3% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -2 | TRIVIAL |
| Paper Wraith + Paper Wraith | 3 | 300 | 100% | 2.0 | 2% | 2% | 1 (2%) | 0.5 | 0.00 | 10.0 | 8.0 | 100%/15% | 100%/3% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | -2 | TRIVIAL |
| Glitch Moth + Paper Wraith | 3 | 300 | 100% | 2.0 | 4% | 5% | 2 (4%) | 1.2 | 0.00 | 11.0 | 7.0 | 100%/18% | 100%/8% | 100%/3% | 100%/2% | 100%/2% | 100%/1% | 100%/1% | -2 |  |
| Glitch Moth + Glitch Moth + Glitch Moth | 1 | 300 | 100% | 3.0 | 15% | 17% | 9 (15%) | 3.0 | 0.00 | 18.0 | 9.0 | 100%/50% | 100%/29% | 100%/8% | 100%/7% | 100%/5% | 100%/4% | 100%/3% | -2 |  |
| The Knowledge Beast | 1 | 300 | 100% | 3.0 | 24% | 33% | 15 (24%) | 4.8 | 0.00 | 24.0 | 18.0 | 100%/39% | 100%/33% | 100%/15% | 100%/7% | 100%/5% | 100%/3% | 100%/2% | -2 |  |
| The Knowledge Beast + Paper Wraith | 1 | 300 | 100% | 4.0 | 36% | 50% | 22 (37%) | 5.5 | 0.01 | 29.0 | 22.0 | 100%/35% | 100%/42% | 100%/23% | 100%/14% | 100%/9% | 100%/7% | 100%/5% | -2 | SPIKE |

#### Worldmap 1 (zand, random encounters) (`wereldkaart1_zand`)

- Party: Dax Lv3 (HP 60 MP 0 ATK 23 DEF 17 AGI 11 MAG 2; Short Sword, Wooden Shield, Leather Hood, Apprentice Cloak; spells: -)
- Tas: {"drankje":3,"kruid":2,"toverwater":1}
- Aanname: Random-encounter pool for terrain 'zand' (rate 6% per step). Same party as Worldmap 1.

| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud | Lv-2 | Lv-1 | Lv+1 | Lv+2 | Lv+3 | Lv+4 | Lv+5 | Venster | Vlaggen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Paper Wraith | 3 | 300 | 100% | 1.0 | 0% | 0% | 0 (0%) | 0.0 | 0.00 | 5.0 | 4.0 | 100%/3% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | 100%/0% | -2 | TRIVIAL |
| Paper Wraith + Paper Wraith | 3 | 300 | 100% | 2.0 | 2% | 2% | 1 (2%) | 0.5 | 0.00 | 10.0 | 8.0 | 100%/16% | 100%/3% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | 100%/1% | -2 | TRIVIAL |
| Glitch Moth + Paper Wraith | 3 | 300 | 100% | 2.0 | 4% | 5% | 3 (4%) | 1.3 | 0.00 | 11.0 | 7.0 | 100%/18% | 100%/8% | 100%/3% | 100%/2% | 100%/2% | 100%/1% | 100%/1% | -2 |  |
| Glitch Moth + Glitch Moth + Glitch Moth | 1 | 300 | 100% | 3.0 | 15% | 18% | 9 (15%) | 3.0 | 0.00 | 18.0 | 9.0 | 100%/50% | 100%/30% | 100%/8% | 100%/7% | 100%/5% | 100%/4% | 100%/3% | -2 |  |
| The Knowledge Beast | 1 | 300 | 100% | 3.0 | 24% | 33% | 15 (24%) | 4.9 | 0.00 | 24.0 | 18.0 | 100%/39% | 100%/32% | 100%/15% | 100%/7% | 100%/5% | 100%/3% | 100%/2% | -2 |  |
| The Knowledge Beast + Paper Wraith | 1 | 300 | 100% | 4.0 | 35% | 48% | 21 (36%) | 5.3 | 0.00 | 29.0 | 22.0 | 100%/37% | 100%/42% | 100%/24% | 100%/14% | 100%/10% | 100%/6% | 100%/5% | -2 | SPIKE |

### Bijlage: Diepe Grot (100 verdiepingen, via ECHO)

Steekproef van verdiepingen en alle canon-baasverdiepingen, 60 gevechten per groep, geen level-gevoeligheid (het level volgt de verdieping: Lv = 5 + 0,4 x verdieping, zie `battlesim.gd d100_level`). Zelfde vlaggen als hierboven.

| Verdieping | Party | Groepen | Winst | Rondes tot winst | HP-verlies | Schade | Items (waarde) | EXP/gevecht | Goud/gevecht | Vlaggen |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Deep Cave (Dungeon100) floor 1 | Lv 1 | 11 | 100% | 1.1 | 2% | 2 (2%) | 0.00 (0 g) | 5.1 | 3.8 | TRIVIAL |
| Deep Cave (Dungeon100) floor 5 | Lv 7 | 11 | 100% | 1.1 | 0% | 0 (0%) | 0.00 (0 g) | 7.5 | 5.8 | TRIVIAL |
| Deep Cave (Dungeon100) floor 15 | Lv 11 | 20 | 100% | 1.3 | 2% | 5 (2%) | 0.00 (0 g) | 28.2 | 15.4 | TRIVIAL |
| Deep Cave (Dungeon100) floor 35 | Lv 19 | 43 | 100% | 1.9 | 7% | 34 (7%) | 0.03 (0 g) | 160.7 | 63.9 | TRIVIAL |
| Deep Cave (Dungeon100) floor 45 | Lv 23 | 38 | 100% | 2.3 | 11% | 68 (13%) | 0.10 (0 g) | 331.0 | 115.0 | TRIVIAL, SPIKE |
| Deep Cave (Dungeon100) floor 65 | Lv 31 | 37 | 100% | 3.8 | 23% | 265 (38%) | 0.70 (0 g) | 830.3 | 245.2 | DEADLY, TRIVIAL, SLOG |
| Deep Cave (Dungeon100) floor 85 | Lv 39 | 59 | 95% | 5.4 | 36% | 609 (71%) | 1.51 (0 g) | 1910.8 | 548.2 | HEAVY, SLOG, DEADLY |
| Deep Cave (Dungeon100) floor 95 | Lv 43 | 46 | 90% | 6.5 | 43% | 910 (97%) | 2.15 (0 g) | 2545.8 | 742.9 | DEADLY, HEAVY, SLOG |
| BOSS Deep Cave floor 10 (Page Warden) | Lv 9 | 1 | 90% | 5.1 | 59% | 200 (76%) | 1.37 (41 g) | 715.0 | 410.0 | BOSS-SHORT |
| BOSS Deep Cave floor 20 (Glitch Queen) | Lv 13 | 1 | 72% | 5.6 | 76% | 325 (95%) | 2.05 (62 g) | 1520.0 | 725.0 | BOSS-HARD, BOSS-SHORT |
| BOSS Deep Cave floor 25 (The Shadow of H-6) | Lv 15 | 1 | 100% | 4.0 | 18% | 92 (24%) | 0.32 (0 g) | 2055.0 | 910.0 | BOSS-EASY, BOSS-SHORT |
| BOSS Deep Cave floor 30 (Spore Lord) | Lv 17 | 1 | 93% | 5.8 | 51% | 379 (90%) | 1.77 (5 g) | 2685.0 | 1115.0 | BOSS-SHORT |
| BOSS Deep Cave floor 40 (Root Mother) | Lv 21 | 1 | 97% | 6.0 | 50% | 506 (101%) | 2.67 (8 g) | 4210.0 | 1590.0 | BOSS-EASY |
| BOSS Deep Cave floor 50 (The Cycle) | Lv 25 | 1 | 100% | 4.0 | 17% | 110 (19%) | 0.10 (0 g) | 6090.0 | 2140.0 | BOSS-EASY, BOSS-SHORT |
| BOSS Deep Cave floor 60 (Mist Lord) | Lv 29 | 1 | 92% | 6.1 | 52% | 705 (106%) | 2.73 (0 g) | 8335.0 | 2770.0 |  |
| BOSS Deep Cave floor 70 (Seal Warden) | Lv 33 | 1 | 93% | 6.4 | 45% | 699 (94%) | 2.22 (0 g) | 10940.0 | 3485.0 |  |
| BOSS Deep Cave floor 75 (The Judge) | Lv 35 | 1 | 100% | 4.0 | 19% | 225 (29%) | 0.52 (0 g) | 12375.0 | 3870.0 | BOSS-EASY, BOSS-SHORT |
| BOSS Deep Cave floor 80 (Great Book Golem) | Lv 37 | 1 | 83% | 6.7 | 57% | 1023 (124%) | 3.00 (0 g) | 13905.0 | 4275.0 |  |
| BOSS Deep Cave floor 90 (Root Emperor) | Lv 41 | 1 | 72% | 7.0 | 63% | 1223 (136%) | 2.68 (0 g) | 17230.0 | 5150.0 | BOSS-HARD |
| BOSS Deep Cave floor 99 (The Voice) | Lv 45 | 1 | 100% | 4.0 | 20% | 299 (30%) | 0.53 (0 g) | 20525.0 | 6000.0 | BOSS-EASY, BOSS-SHORT |

<!-- WM1-GEN-END -->

## 6. Beperkingen

- De sim-AI is eenvoudig (`sim_battle.gd`): heal onder 40%, simpele spreukkeuze, geen verdedigen, vluchten, Codex-bondgenoten of mimics. Een speler met slimmer gebruik doet het beter; een speler zonder goede tas slechter.
- Elk gevecht begint met een volle party en een vaste tas (geen uitputting over meerdere gevechten of kamers). Dat onderschat het Woud en de Golem-aanloop, waar HP en items over meerdere gevechten lopen.
- Het ontwerp-level en de uitrusting per gebied komen uit `battlesim.gd scenarios()` (dezelfde aannames als `docs/BATTLE_BALANCE_REPORT.md`); de EXP-curve rekent zonder wereldkaart-gevechten en zonder kistbuit of verhaalbeloningen.
- Meting met Godot 4.7.2 op Linux (software-GL); de CI gebruikt 4.3.
- Action-modus is niet gemeten (zie 1.9).
