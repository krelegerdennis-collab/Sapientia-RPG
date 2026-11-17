# WM1 balansmeting voor de interne RC (klus 17)

Meting van RC_AUDIT-punten **F5.2, F5.4, F5.5 en F5.6** op de huidige `finish/wm1`. Dit rapport **meet en stelt voor**;
er is geen enkel balans- of spelgetal veranderd. Besluiten per afwijking: Dennis (F5.3, tabel in paragraaf 6).

- **Meetcommit:** `9a87280c25bdcc707cb84bb21e2b6dd158176c8b` (`finish/wm1` op het moment van de meting, F6.15 #498). Daarin zitten C-2 stun-lock #408,
  C-12 MAG/MDEF #414, GQ-balans #446, F2 stagger #450 en perfect dodge #472 (standaard uit). De cijfers in dit rapport zijn op die commit
  vastgelegd; latere alleen-docs merges op `finish/wm1` (o.a. #503, #505, #507) wijzigen de gameplay niet.
- **Engine:** Godot 4.3-stable (official, `77dcf97d8`), headless op xvfb (`--rendering-driver opengl3`), 2 kernen.
- **Seed:** overal `20261020`. Zelfde seed + zelfde code = dezelfde getallen (zie F5.2: de battlesim komt byte voor byte overeen
  met het rapport in de repo).
- Legenda: **FACT** = gemeten of in de code gelezen. **ONVERIFIED** = aanname of niet nagemeten. **VOORSTEL** = niet doorgevoerd.

## 1. Commando's

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
$GODOT --headless --path . --import
# F5.2 (alle gebieden, 2000 gevechten per gebied, 788 s)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --battlesim --seed=20261020 --fights=2000 --out=/tmp/battlesim.md --json=/tmp/battlesim.json
# F5.2/F5.4/F5.5 (elke WM1-groep en baas, EXP- en goudcurve, level-gevoeligheid; 557 s)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --wm1balans --seed=20261020 --fights=300 --boss-fights=600 --sens-fights=100 --out=/tmp/wm1balans.md --json=/tmp/wm1balans.json
# F5.6 Action (SoM-kamers, perfect dodge uit zoals in de release; --verbose geeft de cijfers per kamer)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --actionsim --seed=20261020 --fights=300 --boss-fights=300 --out=/tmp/actionsim.md
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --actionsim --seed=20261020 --fights=300 --boss-fights=0 --verbose --out=/tmp/actionsim_v.md
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --actionsim --boss-rt --seed=20261020 --boss-fights=200 --boss-levels=7,3 --out=/tmp/boss_rt.md
# F5.6 Classic op dezelfde kamers en met dezelfde party (nieuw meetscript, alleen sim-code)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -s res://tools/battlesim/rc_classic_som.gd -- --seed=20261020 --fights=300
```

De rapporten zijn bewust naar `/tmp` geschreven: `docs/BATTLE_BALANCE_REPORT.md`, `docs/ACTION_BALANCE_REPORT.md` en
`docs/release/WM1_BALANCE_REPORT.md` blijven ongewijzigd (de oude cijfers staan hieronder naast de nieuwe).
Een `--d100modesim` bestaat niet in de repo (FACT: geen treffer in `scripts/` en `tools/`); de Diepe Grot zit in `--battlesim`.

## 2. Samenvatting

1. **FACT: de Wortelkoning is de grote afwijking.** Op het ontwerp-level (Dax alleen, Lv 12) wint de speler **28%**, met 16 rondes
   en 96% HP-verlies (`BOSS-IMPOSSIBLE`). In `WM1_BALANCE_REPORT.md` was dat 99% (`fb17c40`) en 80% (met #208). Op het level waarmee je
   hem echt bereikt (Lv 13) is het 61%, op Lv 14 86%. **Oorzaak (FACT, git bisect met `--battlesim --only=wortelkoning`):** #394
   (`cd6b52e8`, "drain Golem Core power"). Sinds Sapientia de Golemkern leegt, heeft Dax geen Kernslag meer. #408, #414, #446, #450 en #472
   veranderen hier niets (28% vóór #408, vóór #414 en nu).
2. **FACT: hetzelfde raakt het Donker Woud.** De groep Root Crawler + Mist Owl + Root Crawler (tier 4) wint **37%**, met 93% verlies
   (eerst 92%). Root Crawler x2 + Spore Cap wint 84% (eerst 52%). Over het hele Woud: 95% winst en 37% verlies (eerst 96% en 28%).
3. **FACT: de Golem zit nu iets boven de band.** Hij wint 96% (was 83%), met 18,6 rondes en 57% verlies op Lv 8. Op het aankomstlevel Lv 7 is
   dat 75%. De realtime Golem (Action) op Lv 7 wint 98,5% (was 65,5%).
4. **FACT: F5.2 is reproduceerbaar.** `--battlesim --seed=20261020 --fights=2000` op `9a87280` geeft **dezelfde getallen** als
   `docs/BATTLE_BALANCE_REPORT.md`. Alleen de looptijd in de kop verschilt. Dat rapport is als laatste gemaakt in #446, dus na #408 en #414.
   #450 en #472 (alleen Action) veranderen Classic dus niet.
5. **FACT: de levelcurve (F5.4).** Wie het verhaal zonder grinden speelt, komt op **Lv 7 bij de Golem** (ontwerp 8; 113 EXP tekort,
   ongeveer 5 gevechten op verdieping 4) en eindigt op Lv 15 (ontwerp 16). WM1 vraagt zo **67 verplichte gevechten en ongeveer 27
   minuten gevechtstijd** (ONVERIFIED: aanname 5 s per ronde + 8 s per gevecht).
6. **FACT: de economie (F5.5).** De enige goudbron in WM1 is monstergoud. Kisten geven alleen items, gewone drops zijn alleen
   bestiariumtekst, quests geven geen goud en het startgoud is 0. Uitrusting is goedkoop. Het zwaard en de mantel krijg je in het verhaal,
   Leather Hood, Cover Shield en Iron Helm liggen in kisten. Wat je echt moet kopen is 70-140 g in Act 1 en hooguit 30 g voor Vesper. Dat is steeds
   te betalen op het moment dat het in de winkel ligt. Alleen de allereerste aankoop (70 g bij 0 g startgoud) kost 3-11 gevechten.
   Spreuken zijn de echte goudput: grade 2 kost 640 g, ofwel 17-30 gevechten in het Tweede Archief (67 in de Berggrot).
7. **FACT: Classic tegenover Action (F5.6).** Action kost per SoM-kamer **13,9%** HP (doel 10-20%; was 11,1%). Classic kost op dezelfde
   kamers met dezelfde Lv 3-party **0-1,7% per gevecht, in 1 ronde**. Action is in Archief 1 dus duidelijk zwaarder dan Classic. De
   zuilenhal is in Action met 29% de uitschieter. ONVERIFIED: de Action-sims modelleren de F2-stagger (#450) niet, dus Action is in het echt
   iets makkelijker dan deze cijfers.

## 3. F5.2: volledig rapport na de freeze

### 3.1 `--battlesim` (2000 gevechten per gebied): oud tegenover nieuw

Oud = `docs/BATTLE_BALANCE_REPORT.md` (laatst gemaakt in #446). Nieuw = `9a87280`. **Alle 59 rijen zijn gelijk.** Dat geldt ook voor de
Diepe Grot en de `[no stun spells]`-varianten. De WM1-rijen:

| Gebied | Winst | Rondes | HP-verlies | p90 | Items | Vlag | oud → nieuw |
|---|---:|---:|---:|---:|---:|---|---|
| Wereldkaart 1 (gras) | 100% | 2,1 | 16% | 37% | 0,01 | | gelijk |
| Eerste Archief verd. 1 | 100% | 1,4 | 9% | 23% | 0,00 | | gelijk |
| Eerste Archief verd. 2 | 100% | 2,1 | 10% | 22% | 0,00 | | gelijk |
| Eerste Archief verd. 3 | 100% | 2,5 | 6% | 16% | 0,00 | | gelijk |
| Eerste Archief verd. 4 | 100% | 2,6 | 6% | 16% | 0,00 | | gelijk |
| BAAS Golem | 95% | 18,7 | 58% | 88% | 3,82 | | gelijk |
| Donker Woud | 93% | 5,1 | 38% | 86% | 1,22 | | gelijk |
| BAAS Wortelkoning | **28%** | 14,7 | 95% | 100% | 6,89 | NEAR-IMPOSSIBLE | gelijk |
| Berggrot | 100% | 1,6 | 7% | 15% | 0,00 | | gelijk |
| Tweede Archief verd. 1 | 100% | 1,5 | 4% | 13% | 0,00 | TRIVIAL | gelijk |
| Tweede Archief verd. 2 | 100% | 1,5 | 6% | 16% | 0,00 | | gelijk |
| VERHAAL Seren (Dax alleen) | 100% | 4,7 | 24% | 29% | 0,00 | | gelijk |
| Tweede Archief verd. 3 | 100% | 1,0 | 0% | 0% | 0,00 | TRIVIAL | gelijk |
| Tweede Archief verd. 4 | 100% | 1,0 | 0% | 0% | 0,00 | TRIVIAL | gelijk |
| BAAS Wurger | 100% | 2,0 | 5% | 8% | 0,00 | TRIVIAL | gelijk |
| BAAS Genezer | 100% | 3,0 | 21% | 23% | 0,00 | | gelijk |

Diepe Grot (bijlage, gelijk aan het oude rapport): baas verdieping 10 (Page Warden) 68% (`HARD`), verdieping 20 (Glitch Queen) 83%,
canon-bazen 25/50/75/99 100% in 1-2 rondes.

### 3.2 `--wm1balans` per WM1-gebied: oud tegenover nieuw

Cel = winst / rondes tot winst / gemiddeld HP-verlies, op het ontwerp-level. `fb17c40` en "#208" komen uit `WM1_BALANCE_REPORT.md`
(gemeten met Godot 4.7.2; kleine verschillen in de seed-reeks zijn mogelijk). "Nu" is gemeten met 4.3 op `9a87280`.

| Gebied | Lv | `fb17c40` (main) | #208 (v2) | nu `9a87280` | Vlaggen nu |
|---|---:|---|---|---|---|
| Wereldkaart 1 (gras) | 3 | 100% / 1,8 / 5% | 100% / 2,0 / 15% | **100% / 2,0 / 15%** | TRIVIAL, HEAVY, SPIKE |
| Eerste Archief verd. 1 | 3 | 100% / 1,4 / 1% | 100% / 1,4 / 9% | **100% / 1,4 / 9%** | TRIVIAL |
| Eerste Archief verd. 2 | 5 | 100% / 2,1 / 3% | 100% / 2,1 / 10% | **100% / 2,1 / 10%** | |
| Eerste Archief verd. 3 | 6 | 100% / 2,5 / 4% | 100% / 2,5 / 7% | **100% / 2,5 / 6%** | TRIVIAL |
| Eerste Archief verd. 4 | 7 | 100% / 3,1 / 7% | 100% / 3,1 / 9% | **100% / 2,6 / 6%** | TRIVIAL |
| BAAS Golem | 8 | 83% / 15,2 / 66% | 83% / 15,2 / 66% | **96% / 18,6 / 57%** | BOSS-EASY |
| VERHAAL Inktwurm | 8 | 100% / 2,0 / 40% | 100% / 2,3 / 62% | **100% / 2,3 / 62%** | HEAVY, CLIFF |
| Donker Woud | 11 | 96% / 4,1 / 28% | 96% / 4,1 / 29% | **95% / 5,0 / 37%** | DEADLY, HEAVY, SLOG, SPIKE, CLIFF |
| VERHAAL Zingend Zaad | 11 | 100% / 2,0 / 1% | 100% / 2,0 / 1% | **100% / 2,0 / 1%** | TRIVIAL |
| BAAS Wortelkoning | 12 | 99% / 10,9 / 57% | 80% / 13,1 / 76% | **28% / 16,2 / 96%** | BOSS-IMPOSSIBLE |
| Berggrot | 13 | 100% / 1,0 / 0% | 100% / 1,8 / 13% | **100% / 1,6 / 7%** | TRIVIAL |
| Tweede Archief verd. 1 | 14 | 100% / 1,0 / 0% | 100% / 2,0 / 10% | **100% / 1,5 / 4%** | TRIVIAL |
| Tweede Archief verd. 2 | 14 | 100% / 1,0 / 0% | 100% / 2,0 / 9% | **100% / 1,5 / 6%** | TRIVIAL |
| VERHAAL Seren (Dax alleen) | 15 | 100% / 1,1 / 0% | 100% / 4,0 / 19% | **100% / 4,7 / 23%** | BOSS-EASY, BOSS-SHORT |
| Tweede Archief verd. 3 | 16 | 100% / 1,0 / 0% | 100% / 2,0 / 14% | **100% / 1,0 / 0%** | TRIVIAL |
| Tweede Archief verd. 4 | 16 | 100% / 1,0 / 0% | 100% / 2,0 / 14% | **100% / 1,1 / 1%** | TRIVIAL |
| BAAS Wurger | 16 | 100% / 3,0 / 8% | 100% / 3,0 / 8% | **100% / 2,0 / 5%** | BOSS-EASY, BOSS-SHORT |
| BAAS Genezer | 16 | 100% / 4,0 / 22% | 100% / 4,0 / 22% | **100% / 3,0 / 21%** | BOSS-EASY, BOSS-SHORT |
| Wereldkaart 1 (bos) | 3 | 100% / 1,9 / 7% | 100% / 2,2 / 20% | **100% / 2,2 / 20%** | TRIVIAL, HEAVY, SPIKE |
| Wereldkaart 1 (zand) | 3 | 100% / 2,1 / 8% | 100% / 2,5 / 22% | **100% / 2,5 / 22%** | HEAVY, SPIKE |

### 3.3 Per baas, op het ontwerp-level en op het level dat je echt hebt

Doelband baas: 80-95% winst. "Aankomst" = het level als je het verhaal zonder grinden speelt (F5.4).

| Baas | Ontwerp-Lv: winst / rondes / verlies | Aankomst-Lv | Winst op aankomst (verlies) | Einde-Lv | Winst aan het einde |
|---|---|---:|---|---:|---|
| Golem | Lv 8: 96% / 18,6 / 57% | 7 | 75% (69%) | 8 | 96% |
| Inktwurm (verhaal) | Lv 8: 100% / 2,3 / 62% | 8 | 100% (62%) | 8 | 100% |
| Wortelkoning | Lv 12: **28%** / 16,2 / 96% | 13 | **61%** (86%) | 14 | 86% |
| Seren (verhaal, Dax alleen) | Lv 15: 100% / 4,7 / 23% | 15 | 100% (23%) | 15 | 100% |
| Wurger | Lv 16: 100% / 2,0 / 5% | 15 | 100% (7%) | 15 | 100% |
| Genezer | Lv 16: 100% / 3,0 / 21% | 15 | 100% (20%) | 15 | 100% |

**Wortelkoning, bisect** (`--battlesim --seed=20261020 --fights=600 --only=wortelkoning`, Dax Lv 12 alleen; alleen gemeten in een
losse worktree, niets gecommit):

| Commit | Winst | Rondes | HP-verlies |
|---|---:|---:|---:|
| `61986e94` (#208 gemerged) | 83% | 12,8 | 75% |
| `fd0b1bc1` (#393) | 83% | 12,8 | 75% |
| **`cd6b52e8` (#394, "drain Golem Core power")** | **28%** | 14,7 | 95% |
| `a1a85b5a` (vóór #408) | 28% | | |
| `9a87280` (nu) | 28% | 14,7 | 95% |

Het sim-scenario zet nog `kern: true` ("Golem Core (Core Strike)"), maar de kern geeft sinds #394 geen gevechtskracht meer. Het scenario is
dus nog geldig (de speler heeft die kracht echt niet meer), alleen de notitie in `battlesim.gd` is verouderd.

### 3.4 Donker Woud (de groepen met een vlag)

| Groep (tier 4) | `fb17c40` | nu `9a87280` | Level-venster nu | Vlaggen nu |
|---|---|---|---|---|
| Root Crawler + Mist Owl + Root Crawler | 92% / 7,2 / 63% | **37% / 12,5 / 93%** | +2 | DEADLY, HEAVY, SLOG, SPIKE, CLIFF |
| Root Crawler + Root Crawler + Spore Cap | 52% / 11,6 / 91% | 84% / 11,5 / 70% | +1 | DEADLY, HEAVY, SLOG, CLIFF |
| Spore Cap + Spore Cap + Mist Owl | 98% / 11,5 / 63% | 97% / 10,8 / 59% | 0 | HEAVY, SLOG, CLIFF |

Kamer voor kamer, op het level waarmee je binnenkomt: Wood's Edge (Lv 8) 100% / 18%, Root Path (Lv 9) 100% / 47%,
**Mist Pool (Lv 11) 84% / 54%** (slechtste groep 37%), Spore Ring (Lv 12) 99% / 48%.

Overige uitschieters (gelijk aan #208): de wereldkaart-groep Glitch Moth x3 kost op Lv 3 65% HP (HEAVY, SPIKE; voorstel B3 is niet
toegepast). De Knowledge Beast + Paper Wraith kost 40% (SPIKE).

## 4. F5.4: levelcurve

Model (`--wm1balans`): elk map-monster van elk gebied wordt één keer verslagen, in verhaalvolgorde, zonder grinden en zonder
wereldkaart-gevechten. EXP-formule `15 x (level-1)^2`.

### 4.1 Per level: gevechten en minuten

ONVERIFIED aanname voor de minuten: **5 s per ronde + 8 s per gevecht** (overgang en overwinningsscherm), alleen gevechtstijd en geen
lopen. De sim slaat wachttijden over, dus dit is geen meting. Ter controle: het speeltijdrapport van `docs/release/WM1_PLAYTEST.md`.

| Naar Lv | Bereikt in | Gevechten voor dit level | Rondes | Minuten (aanname) |
|---:|---|---:|---:|---:|
| 2 | Eerste Archief verd. 1 | 3 | 4 | 0,8 |
| 3 | Eerste Archief verd. 2 | 7 | 11 | 1,8 |
| 4 | Eerste Archief verd. 2 | 4 | 8 | 1,2 |
| 5 | Eerste Archief verd. 3 | 6 | 13 | 1,9 |
| 6 | Eerste Archief verd. 3 | 5 | 12 | 1,7 |
| 7 | Eerste Archief verd. 4 | 7 | 18 | 2,4 |
| 8 | Golem (baasgevecht) | 3 | 24 | 2,4 |
| 9 | Donker Woud | 2 | 7 | 0,9 |
| 10 | Donker Woud | 3 | 15 | 1,6 |
| 11 | Donker Woud | 3 | 15 | 1,6 |
| 12 | Donker Woud | 3 | 15 | 1,6 |
| 13 | Donker Woud | 3 | 15 | 1,6 |
| 14 | Wortelkoning (baasgevecht) | 4 | 28 | 2,9 |
| 15 | Tweede Archief verd. 2 | 8 | 12 | 2,1 |

Totaal verplicht: **67 gevechten, ongeveer 212 rondes, ongeveer 27 minuten gevechtstijd**. Daarna eindig je op Lv 15 (3293 EXP; Lv 16 vraagt 3375).

### 4.2 Aankomst tegenover ontwerp

| Moment | Level zonder grinden | Ontwerp | Tekort (EXP) | Tekort in gevechten |
|---|---:|---:|---:|---|
| Eerste Archief verd. 1 / 2 / 3 / 4 | 1 / 2 / 4 / 6 | 3 / 5 / 6 / 7 | -60 / -183 / -176 / -137 | 7 wereldkaart / 29 verd. 1 / 12 verd. 2 / 6 verd. 3 |
| **Golem** | **7** | 8 | -113 | **5 x verdieping 4** (ongeveer 2 min) |
| Donker Woud (begin / eind) | 8 / 13 | 11 | -608 / +856 | het Woud zelf geeft 1464 EXP |
| Wortelkoning | 13 | 12 | +549 | |
| Berggrot / Tweede Archief verd. 1-2 | 14 / 14-15 | 13 / 14 | overschot | |
| Tweede Archief verd. 3-4 en bazen | 15 | 16 | -338 tot -172 | ongeveer 6 x verdieping 3 |

Grindtempo per gebied op het ontwerp-level (gevechten per level / minuten per level met 4-7 s per ronde): wereldkaart 6-8 / 2-3,
Eerste Archief 6,5-11,8 / 2-3,5, Donker Woud 3,2 / 1,5-2,3, **Berggrot 22,9 / 5,5-7,3** (uitschieter, voorstel B2 niet toegepast),
Tweede Archief 7,5-9,6 / 1,6-3.

## 5. F5.5: economie

### 5.1 Waar het goud vandaan komt (FACT, code)

| Bron | Goud in WM1 | Bewijs |
|---|---|---|
| Monsters (Classic en Action) | ja, `gold` per vijand bij winst | `battle.gd` (`add_gold(gold_total)`), `som_arena.gd` |
| Drops | **nee** (gewone drops zijn alleen bestiariumtekst; alleen vaste baasbuit, bijvoorbeeld 3 Blank Books van de Golem) | `game_data.gd` regel 103, `grant_fixed_boss_drops` |
| Kisten | **nee**, alleen items (zie 5.3) | `dungeon_chest.gd` (goud alleen in Diepe Grot-kisten) |
| Verhaal en quests | **nee** (geen `add_gold` buiten gevecht, winkel en Koopman) | grep op `add_gold(` |
| Startgoud | **0** | `GameData.START_GOLD` |
| Verkopen | helft van de vraagprijs | `ShopData.sell_price` |

### 5.2 Goud per gebied tegenover de winkel

Goud bij alleen opruimen (`--wm1balans`). De winkel volgt de act, en die volgt het hoogste level in de party: **Act 2 vanaf Lv 14**,
dus na de Wortelkoning.

| Gebied | Goud dit gebied | Cumulatief | Goud per gevecht | Items verbruikt per gevecht (waarde) |
|---|---:|---:|---:|---:|
| Wereldkaart (gras / bos / zand) | willekeurig | - | 6,5 / 8,0 / 8,8 | 0 |
| Eerste Archief verd. 1 | 27 | 27 | 3,0 | 0 |
| Eerste Archief verd. 2 | 82 | 109 | 9,1 | 0 |
| Eerste Archief verd. 3 | 145 | 254 | 18,1 | 0 |
| Eerste Archief verd. 4 | 191 | 445 | 23,9 | 0 |
| Golem | 84 | 529 | 84 | 3,85 (111 g) |
| Inktwurm | 40 | 569 | 40 | 0 |
| Donker Woud | 702 | 1271 | 46,8 | 1,09 (30 g) |
| Wortelkoning | 150 | 1425 | 150 | 6,90 (188 g) |
| Berggrot | 48 | 1473 | 9,6 | 0 |
| Tweede Archief verd. 1-2 | 90 | 1563 | 21,5-23,5 | 0 |
| Tweede Archief verd. 3-4 + bazen | 131 | 1694 | 20-40 | 0 |

Winkelaanbod (FACT, `shop_data.gd`):

| Act | Wapens | Pantser | Accessoire | Kruiden | Magie | Totaal uitrusting |
|---|---|---|---|---|---|---:|
| 1 | Short Sword 120, Dagger 60, Oak Staff 90 | Wooden Shield 40, Cover Shield 90, Leather Hood 30, Travel Robe 30, Leather Armor 70 | Bookmark 100 | Herbal Tea 20 | grade 1: 160 per spreuk | 650 |
| 2 (vanaf Lv 14) | | Iron Helm 80, Chainmail 160 | Green Ring 150 | | grade 2: 640 per spreuk | +390 |

### 5.3 Kan de speler het pakket betalen als het in de winkel ligt?

"Pakket" = de uitrusting die de sim voor dat gebied aanneemt (`battlesim.gd scenarios()`), minus wat het verhaal en de kisten al geven.
FACT, gratis: Short Sword (`["weapon", "kort_zwaard"]` in `story_data.gd`), Apprentice Cloak (tutorial), Vesper sluit aan met Oak Staff +
Travel Robe en je krijgt een Doublet (`story_data.gd`, `join noor`), Spark Sword (puzzelkist `kist_vonkzwaard`).
Kisten: Leather Hood (verd. 2), Cover Shield (verd. 3), Iron Helm (Woud, Mist Pool), Berggrot-staf en -accessoire, en drankjes,
toverwater en Blank Books.

| Moment | Sim-pakket | Zelf kopen | Goud dan (alleen opruimen) | Betaalbaar? |
|---|---|---:|---:|---|
| Wereldkaart / verd. 1 (Lv 3) | Short Sword, Wooden Shield, Leather Hood, Cloak | Wooden Shield 40 + Leather Hood 30 = **70** | **0** | **Nee, eerst grinden**: 11 gras-gevechten of 3 x verd. 1 opruimen (27 g). ONVERIFIED: of de winkel en de wereldkaart vóór verdieping 1 bereikbaar zijn |
| Verd. 2 (Lv 5) | + Leather Armor | +70 (hood ligt in de kist van verd. 2) | 27 + wereldkaart | Ja, na ongeveer 6 extra gevechten op de wereldkaart (of de shield overslaan) |
| Verd. 3-4, Golem (Lv 6-8) | Spark Sword, Cover Shield, Hood, Leather Armor | 0 (shield uit kist) | 109-529 | Ja, ruim |
| Donker Woud, Wortelkoning (Lv 11-12) | + Iron Helm | 0 (Iron Helm uit Woud-kist; in de winkel pas Act 2) | 569-1425 | Ja |
| Berggrot, Vesper (Lv 12-13) | Oak Staff, Doublet, Leather Hood | Leather Hood **30** (staf en gewaad komen mee bij het aansluiten) | 1425 | Ja |
| Act 2-winkel (Lv 14) | Iron Helm, Chainmail, Green Ring (niet in de sim) | 390 | 1425-1563 | Ja |
| Spreuken Act 1 / Act 2 | grade 1 / grade 2 | 160 / 640 per stuk | 1425 bij de start van Act 2 | grade 1 overal; bij de start van Act 2 twee spreuken van grade 2 óf één plus alle Act 2-uitrusting; daarna 17-30 gevechten per spreuk (Berggrot 67) |

Conclusie (FACT): de uitrusting is nergens een muur behalve bij de allereerste aankoop. Het Woud geeft 41% van alle WM1-goud (702 van 1694).
Na het Woud staat er ongeveer 1270 g tegenover maximaal 650 g Act 1-uitrusting. De goudput zit in spreuken van grade 2. De Golem en de
Wortelkoning zijn netto verlies (items: -27 en -38 g per gevecht).
Sim-noot: de kolom "Kosten winkeluitrusting" in `wm1_balans.gd` telt de Short Sword (120) mee, terwijl het verhaal hem geeft. De bedragen
in die kolom (190-360) zijn dus te hoog. Niet aangepast (meten kon, zie 7).

## 6. F5.6: Classic tegenover Action

### 6.1 Normale gevechten: dezelfde kamers, dezelfde party

Party: SoM-start (Dax, Vesper, Seren op Lv 3, Spark Sword, Wooden Shield, Leather Hood, tas `SomData.START_ITEMS`). Kamers: `SomData.ROOMS`
met de archief-tier. **Action** (`--actionsim`, iteratie 7 = de huidige `SomData`) vecht de hele kamer in één keer met volle HP.
**Classic** (`rc_classic_som.gd`, echte `battle.tscn`) vecht elke map-monster-groep van die kamer als los gevecht met volle HP, 300 per kamer.

| Kamer | Action HP-verlies (hele kamer) | Classic HP-verlies per gevecht | Classic winst | Classic rondes |
|---|---:|---:|---:|---:|
| archief_v1_gang | 9,6% | 0,5% | 100% | 1,0 |
| archief_v2_kastenzaal | 2,8% | 0,6% | 100% | 1,0 |
| archief_v2_leeszaal | 12,5% | 1,7% | 100% | 1,0 |
| archief_v2_trapzaal | 11,5% | 0,0% | 100% | 1,0 |
| archief_v3_gang | 17,8% | 0,0% | 100% | 1,0 |
| archief_v3_zuilenhal | **29,2%** | 0,6% | 100% | 1,0 |
| **gemiddeld** | **13,9%** (p90 34,5%, winst 99,9%, 5,1 s per kamer) | ≤ 1,7% | 100% | 1,0 |

Action tegenover het oude `ACTION_BALANCE_REPORT.md` (vóór #450 en #472), met dezelfde parameters:

| Iteratie | HP-verlies oud → nieuw | p90 oud → nieuw | Winst oud → nieuw |
|---|---|---|---|
| 7 (gekozen = `SomData`) | 11,1% → **13,9%** | 29,6% → 34,5% | 100% → 99,9% |
| 9 (oud per-kamer-rapport) | 11,6% → 15,1% | 31,7% → 37,3% | 100% → 99,9% |

Per kamer, iteratie 9 (alleen die stond in het oude rapport): v1_gang 1,4 → 8,5%, kastenzaal 2,2 → 5,3%, leeszaal 6,3 → 11,9%,
trapzaal 10,3 → 13,6%, v3_gang 20,4 → 19,5%, zuilenhal 29,2 → 31,7%.

### 6.2 Golem: Classic tegenover realtime

| Meting | Lv | Oud | Nu |
|---|---:|---|---|
| Classic Golem, SoM-party (`--actionsim` baastabel) | 3 | 99,7% / 24,1% verlies | 98,0% / 39,3% |
| Classic Golem, SoM-party | 5 | 100% / 19,1% | 100% / 25,2% |
| Realtime Golem (`--boss-rt`, profiel default) | 7 | 65,5% / 74,5% (`docs/combat/d3_golem_sim_report.md`) | **98,5% / 44,9%** |
| Realtime Golem (profiel good) | 7 | 98,5% / 58,5% | 99,0% / 41,7% |
| Realtime Golem (default / good) | 3 | 2,5% / 15,0% | 0,0% / 16,5% |
| Classic Golem, Dax alleen (`--wm1balans`) | 7 / 8 | 73% / 83% | 75% / 96% |

Het doel van de realtime Golem (60-80% winst op Lv 7) wordt nu ruim overschreden. ONVERIFIED: welke PR dat veroorzaakt (niet gebisect).
De kop van het `--boss-rt`-rapport noemt nog "HP 360, ATK 27", terwijl `game_data.gd` nu 520 / 23 zegt (#354). Dat is alleen tekst in de sim.

### 6.3 Grenzen van de Action-meting

- ONVERIFIED: `action_sim.gd` en `golem_rt_sim.gd` modelleren de **F2-stagger** (#450, wankel x1,3 schade) **niet**. In het echt doet de
  speler dus iets meer schade en is Action iets makkelijker dan hier gemeten. Dat inbouwen is een sim-uitbreiding, geen fout: niet gedaan.
- Perfect dodge staat uit (`SomPerfectDodgeData.ENABLED = false`) en zit niet in de sims, zoals in de release.
- De Action-sim gebruikt een abstract spelermodel (ontwijkkans 35%, aanloop 1,2 s). De Classic-sim gebruikt de eenvoudige AI van `sim_battle.gd`.

## 7. Afwijkingen (voor F5.3)

Doelbanden zoals in de eerdere rapporten: baas 80-95% winst; Action gewone kamer 10-20% HP; gewone groep < 45% HP-verlies en ≥ 95% winst.
**Niets hiervan is toegepast.**

| # | Afwijking (FACT) | Gemeten | Doel | Voorstel | Dennis beslist |
|---|---|---|---|---|---|
| A1 | Wortelkoning te zwaar sinds #394 (geen Kernslag meer) | 28% op Lv 12; 61% op Lv 13 (aankomst); 86% op Lv 14 | 80-95% | VOORSTEL: in een aparte klus een meetreeks voor alleen de baas-stats (`ENEMIES.wortelkoning.boss`), met doel 80-90% op Lv 13. Alternatief: Vesper vóór de baas laten aansluiten (verhaal), of het accepteren | ☐ stats-meetreeks ☐ verhaal ☐ accepteren |
| A2 | Woud: Root Crawler + Mist Owl + Root Crawler (Mist Pool) | 37% winst, 93% verlies op Lv 11; Mist Pool op het aankomstlevel 84% | ≥ 95% | VOORSTEL: voorstel A uit `WM1_BALANCE_REPORT.md` (Root Crawler ATK 22 → 20, Spore Cap 40/18 → 36/16) opnieuw meten na het besluit over A1 (zelfde oorzaak) | ☐ A opnieuw meten ☐ accepteren |
| A3 | Golem iets te makkelijk op het ontwerp-level | 96% op Lv 8 (BOSS-EASY), 75% op Lv 7 (aankomst) | 80-95% | VOORSTEL: niet aanpassen; op het level dat je echt hebt zit hij in de band | ☐ akkoord ☐ anders |
| A4 | Realtime Golem (Action) veel te makkelijk | 98,5% op Lv 7 (was 65,5%) | 60-80% | VOORSTEL: eerst bisecten welke PR dit deed, daarna pas afstellen (`action_boss_stats`) | ☐ bisect ☐ accepteren |
| A5 | Action-kamer zuilenhal piekt | 29,2% (iteratie 7) | 10-20% | VOORSTEL: niet aanpassen tot de stagger (#450) in de sim zit; de stagger verlaagt dit cijfer | ☐ akkoord ☐ anders |
| A6 | Action duidelijk zwaarder dan Classic in Archief 1 | Action 13,9% per kamer, Classic ≤ 1,7% per gevecht | (geen doel) | VOORSTEL: bewuste keuze vastleggen ("Action = uitdaging") of Classic Archief 1 later apart bekijken | ☐ bewust ☐ apart bekijken |
| A7 | Tweede Archief verd. 3-4, Wurger, Genezer triviaal | 0-21% verlies, 1-3 rondes | baas 80-95%, ≥ 6 rondes | VOORSTEL: open besluit 2.3 uit `WM1_BALANCE_REPORT.md` (CANON-waarden) | ☐ laten ☐ HP x4-5 ☐ party-kant |
| A8 | Seren (verhaalgevecht) kort | 100%, 4,7 rondes, 23% | geen doel (verhaal) | VOORSTEL: voorstel B1 (540 / 40) blijft liggen | ☐ B1 ☐ laten |
| A9 | Glitch Moth x3 op de wereldkaart | 65% verlies op Lv 3 (HEAVY) | < 45% | VOORSTEL: voorstel B3 (gewicht 0) | ☐ B3 ☐ laten |
| A10 | Berggrot traag levelen | 22,9 gevechten per level (andere gebieden 3-12) | geen muur | VOORSTEL: voorstel B2 (tier 7 EXP x2,5 / goud x2) | ☐ B2 ☐ laten |
| A11 | Inktwurm zwaar en scherp | 62% verlies; Lv 7 = CLIFF | geen doel (verhaal) | VOORSTEL: niet aanpassen (watch-item) | ☐ akkoord |
| A12 | Eerste aankoop zonder goud | pakket 70 g, startgoud 0, 3-11 gevechten | geen muur | VOORSTEL: niet aanpassen; eventueel startgoud 50 (zoals `SomData.START_GOLD`) | ☐ laten ☐ startgoud |
| A13 | Spreuk grade 2 duur in Act 2 | 640 g = 17-30 gevechten (Berggrot 67) | geen doel | VOORSTEL: niet aanpassen (Act 2 hoort bij WM2-economie) | ☐ akkoord |
| A14 | Levelcurve 1 level onder ontwerp bij Golem en eind | Golem Lv 7 (ontwerp 8), eind Lv 15 (16) | 0 | VOORSTEL: niet aanpassen; 5-6 gevechten grinden is gezond | ☐ akkoord |

## 8. Sim-noten (niet aangepast, meten kon)

- `battlesim.gd`: de scenario-notities "Golem Core (Core Strike)" kloppen niet meer sinds #394 (de kern geeft geen gevechtskracht).
- `wm1_balans.gd`: de winkelkosten tellen de Short Sword mee, terwijl het verhaal die geeft (5.3).
- `action_sim.gd --boss-rt`: de kop noemt nog de Golem-stats 360 / 27.
- Nieuw: `tools/battlesim/rc_classic_som.gd` (alleen meten, start via `-s`, geen regel in `game_state.gd`). Nodig voor F5.6
  "Classic op dezelfde gevechten". Geen bestaande sim-code is aangepast.
