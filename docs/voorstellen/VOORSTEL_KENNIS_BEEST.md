# Voorstel: balans kennis_beest als Golem-baas (WM1)

Status: **alleen voorstel**, geen data gewijzigd. Alle metingen hieronder zijn gedaan met tijdelijke
wijzigingen in `scripts/data/game_data.gd` die daarna zijn teruggezet.

## 1. Wat er nu aan de hand is

Aanleiding (WM1-overzicht, `--battlesim --party=dennis:5,noor:5 --enemy=all --total=1000 --seed=7`, policy `simpel`):

- alle gewone groepen 100% winst, ook `kennis_beest` als gewone kamervijand;
- `baas_kennis_beest`: **11,3%** winst;
- `kennis_beest` gemiddeld **3,8 beurten**, alle andere vijanden 1,0.

Wat dat betekent:

1. **De 3,8 beurten zijn een mengeffect, geen probleem van de gewone vijand.** `--total=1000` verdeelt de
   gevechten gelijk over de 14 groepen van `GameData.ENCOUNTER_GROUPS`. `kennis_beest` zit in 3 daarvan:
   `[kennis_beest]`, `[kennis_beest, papiergeest]` (beide ~1 beurt) en `baas_kennis_beest` (~9,4 beurten,
   zie hieronder). (1,0 + 1,0 + 9,4) / 3 ≈ 3,8. Het per-vijand-gemiddelde telt het baasgevecht dus mee.
2. **De 11,3% is ~71 baasgevechten** (1000 / 14 groepen), dus ruis van ongeveer ±4 punten. Los gemeten
   (1000 baasgevechten, zelfde seed): **9,7%** winst, 9,4 beurten, 3,6% HP over.
3. **BALANS_ARCHIEF1.md** ("kennis_beest@2 op 3,493, vlak onder de grens [3,0-3,5]") gaat over de
   *gewone* kennis_beest in de **Action-arena** (realtime, `SomData.ACTION_AREAS.archief1`). Dat staat los
   van het baasgevecht: bazen blijven Classic, de arena neemt een baas nooit op, en `ENEMIES.kennis_beest.boss`
   (360/27/15) wordt daar niet gebruikt (Forge-review 2 in dat document). Dat punt hoort dus niet in dit
   voorstel; wel goed om te weten dat elke wijziging aan de **gewone** stats (46/14/7) die grens raakt.

## 2. Welk doel lijkt bedoeld (uit de docs, niets nieuws)

- `game_data.gd`, commentaar bij `kennis_beest.boss`: "Doel-level van het Eerste Archief is 7
  (`EERSTE_ARCHIEF_DOEL`). Bevestigd: HP 360 en ATK 27, zodat **Lv 7 slim wint met meerdere items en
  domweg aanvallen meestal verliest**." Daarvoor: "baas voor Dennis ~Lv 10 **MET het Vonkzwaard** (+12)".
- `HANDOFF_GOLEM.md`: gebalanceerd voor **Dennis solo**; de kern (x0,4 dicht / x2 open, Hamerslag) moet
  de sleutel zijn, items gebruiken moet lonen. (De getallen in die handoff, 140/15/10 voor Lv 3, zijn
  verouderd; de huidige waarden komen uit v0.15.)
- `tools/battlesim/battlesim.gd`, gebied `golem`: **Dax solo Lv 8, met Vonkzwaard + latere uitrusting,
  tas `drankje:5, kruid:2, toverwater:2`**. Vesper (= `noor`) komt pas bij de Berggrot (Lv 12-13), na de
  Wortelkoning.
- `docs/BATTLE_BALANCE_REPORT.md`: BOSS Golem **84%** winst, 15,1 rondes, 65% HP-verlies, 4,89 items.

**Aanname:** het bedoelde doel is "zwaar maar haalbaar voor solo-Dax rond Lv 7-8 met het Vonkzwaard, en
alleen met items". Een winrate-getal staat nergens als eis; ik ga uit van "duidelijk meer dan de helft,
niet triviaal". Dat moet Forge/Dennis bevestigen.

**Conclusie:** de meting `dennis:5,noor:5` (zonder uitrusting, met de starttas) is **niet het scenario
waarvoor de baas bedoeld is**: 2 levels te laag, geen Vonkzwaard, en een held (Noor) die op dat moment
in het verhaal nog niet meedoet. De 11,3% zegt vooral iets over de meetopzet.

## 3. Metingen (seed 7, policy simpel, 1000 gevechten per cel)

| variant | boss-stats (HP/ATK/DEF) | duo Lv 5 (`dennis:5,noor:5`) | duo Lv 7 (`dennis:7,noor:7`) | **Dax solo Lv 8 + Vonkzwaard** (gebied `golem`) |
|---|---|---|---|---|
| nu | 360 / 27 / 15 | 9,7% · 9,4 beurten · 3,6% HP over | 79,3% · 9,8 · 41,4% | **82%** · 15,2 rondes · 67% HP-verlies · 4,92 items |
| optie B | 360 / **24** / 15 | 14,4% · 10,4 · 6,1% | 90,5% · 9,5 · 51,2% | **98%** · 14,0 · 54% · 2,94 items |
| optie C | **300** / **24** / 15 | 35,9% · 9,4 · 19,4% | 97,4% · 7,2 · 65,3% | **100%** · 11,4 · 53% · 2,05 items |

Commando's:
```
# duo (CSV-runner)
godot --headless --path . -- --battlesim --party=dennis:5,noor:5 --enemy=baas_kennis_beest --runs=1000 --seed=7 --out=<pad>.csv
# bedoeld scenario (gebiedsrapport, alleen de Golem)
godot --headless --path . -- --battlesim --only=golem --fights=1000 --seed=7 --out=<pad>.md
```

Wat opvalt: de Lv 5-duo reageert nauwelijks op een ATK-verlaging (9,7 -> 14,4%), maar het bedoelde
scenario wel sterk (82 -> 98%). Het gat bij Lv 5 zit vooral in schade per ronde (geen Vonkzwaard, 2 levels
minder) tegen 360 HP achter het pantser (x0,4), niet in de klappen van de Golem.

## 4. Opties

### Optie A (aanbevolen): stats laten staan, de meting goed zetten

Geen wijziging in `game_data.gd`. Wel:
- in het WM1-overzicht het baasgevecht apart rapporteren (of uit `--enemy=all` laten) en de baas meten
  met het bedoelde scenario: `--only=golem` (Dax solo Lv 8, Vonkzwaard) - nu **82%**, 4,9 items, 67% HP-verlies;
- in de tekst van het overzicht noemen dat het per-vijand-gemiddelde van `kennis_beest` het baasgevecht
  meetelt (verklaart de 3,8 beurten).

Waarom: het past bij het vastgelegde doel ("slim wint met meerdere items"): ~5 items per gevecht en
2/3 HP kwijt is precies "zwaar, items nodig". Gewone `kennis_beest` (46/14/7) en de Action-grens
3,0-3,5 uit BALANS_ARCHIEF1 blijven ongemoeid.

### Optie B: iets milder - alleen ATK 27 -> 24

```
# scripts/data/game_data.gd, ENEMIES.kennis_beest.boss
-			"max_hp": 360, "atk": 27, "def": 15, "agi": 6, "mag": 11, "mdef": 13, "mp": 0,
+			"max_hp": 360, "atk": 24, "def": 15, "agi": 6, "mag": 11, "mdef": 13, "mp": 0,
```
Gemeten: Dax solo Lv 8 **98%** (2,9 items, 54% HP-verlies); duo Lv 5 14,4%; duo Lv 7 90,5%.
Alleen kiezen als Forge/Dennis 82% bij het bedoelde level te zwaar vindt. Risico: het doel "domweg
aanvallen verliest meestal" lijkt dan niet meer te kloppen (policy simpel = aanvallen + genezen onder 35%,
wint 98%). Hamerslag (ATK x 2,2) gaat mee omlaag: ~59 -> ~53 voor verdediging.

### Optie C: baas afstemmen op de Lv 5-duo - HP 360 -> 300 en ATK 27 -> 24

```
-			"max_hp": 360, "atk": 27, "def": 15, "agi": 6, "mag": 11, "mdef": 13, "mp": 0,
+			"max_hp": 300, "atk": 24, "def": 15, "agi": 6, "mag": 11, "mdef": 13, "mp": 0,
```
Gemeten: duo Lv 5 nog steeds maar **35,9%**; Dax solo Lv 8 **100%** (2,0 items, 11,4 rondes); duo Lv 7 97,4%.
**Niet aanbevolen**: zelfs deze flinke verlaging maakt de Lv 5-duo niet "gewoon te doen", terwijl het
bedoelde solo-gevecht triviaal wordt. Wie de Lv 5-duo echt boven ~70% wil, moet nog veel verder (en dan
is de Golem op het bedoelde level geen baas meer). Dat zou een nieuw ontwerpdoel zijn; dat beslis ik niet.

## 5. Vragen voor Forge / Dennis

1. Klopt de aanname dat de Golem bedoeld is voor **Dax solo Lv 7-8 met het Vonkzwaard** (zoals het
   gebiedsrapport)? Zo ja: optie A.
2. Is er een gewenste winrate voor WM1-bazen bij policy `simpel` (nu 82%, Wortelkoning 82%)? Dan kan de
   keuze tussen A en B op een getal.
3. Moet het WM1-overzicht (`--enemy=all`) bazen meenemen? Zo ja, met welke party per baas?

## 6. Niet meegenomen

- Kern-regels (`boss.core`: cycle 3, x0,4 / x2,0, break 45, slam 2,2) zijn niet gevarieerd; die bepalen
  de leesbaarheid van het gevecht (HANDOFF_GOLEM) en zijn een ontwerpkeuze, geen getal om mee te schuiven.
- Dungeon100 verdieping 80 (Grote Boekengolem, schaalt vanaf `kennis_beest.boss` via `Scaling.boss_stats`):
  optie B/C verandert die ook (nu 71%, "HARD" in BATTLE_BALANCE_REPORT). Niet gemeten.
- Gewone `kennis_beest` (46/14/7): niet aanraken, zie de Action-grens in BALANS_ARCHIEF1.
