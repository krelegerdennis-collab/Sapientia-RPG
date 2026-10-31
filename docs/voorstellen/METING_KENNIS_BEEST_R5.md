# Meting kennis_beest (Golem-baas) r5 - optie A doorgevoerd

Status: **optie A uit de r4-meting** (`METING_KENNIS_BEEST.md` op branch `claude-trial/r4-4-kennis-beest-meting`,
commit `bf60cb6`) is doorgevoerd. De stats van `ENEMIES.kennis_beest.boss` blijven **360 / 27 / 15**
(`scripts/data/game_data.gd` is niet aangeraakt). Alleen de meetopzet is vastgelegd in de sim-tooling.

## 1. Wat is er veranderd (alleen tooling + test)

`tools/battlesim/battlesim_runs.gd` (CSV-runner):

- **`--scenario=golem`**: zet de bedoelde opzet als standaard: Dax solo (`dennis`) Lv 8
  (`GOLEM_BOSS_LEVEL`), uitrusting `GOLEM_BOSS_GEAR` (vonkzwaard + kaftschild + leren_kap + leren_harnas),
  tas `GOLEM_BOSS_INV` (drankje 5, kruid 2, toverwater 2) en groep `baas_kennis_beest`
  (`GOLEM_BOSS_GROUP`). Expliciete `--party`, `--enemy`, `--gear` en `--items` gaan erboven; zo meet je
  Lv 7 met `--party=dennis:7`. Onbekend scenario = foutmelding, niets geschreven.
- **`--gear=dennis:a+b[;noor:c]`** (overgenomen uit r4 `bf60cb6`): per held uitrusting via
  `Equipment.equip`. Fouten (held niet in `--party`, onbekend stuk, stuk dat de held niet kan dragen)
  geven een foutmelding en er wordt niets geschreven.
- **`--items=none`**: lege tas (voor de meting "zonder items"). r4 gebruikte `--items=drankje:0`; dat
  werkt nog steeds en geeft exact hetzelfde gevecht.
- Geen dubbel werk met main (`cb014a7`, "Golem-baas meten met golem-scenario"): de constanten
  `GOLEM_BOSS_GEAR` / `GOLEM_BOSS_INV` / `GOLEM_BOSS_LEVEL` en `_build_party_geared` uit main worden
  hergebruikt. r4 had een eigen uitrust-lus in `_build_party`; die is niet overgenomen. `_build_party`
  geeft de `--gear` nu door aan `_build_party_geared` (met `strict`, zodat "kan niet dragen" een fout
  geeft; het WM1-overzicht-pad blijft stil zoals het was). Zonder `--scenario`/`--gear` werkt de runner
  precies als eerst.

`scripts/tests/battlesim_tests.gd` (`--battlesimtest`), 10 nieuwe checks:

- `--gear` lezen, uitrusten (wapen + schild, ATK-bonus), tas = alleen `--items`; `--items=none` = lege tas;
- foutgevallen `--gear=noor:...` (niet in party), `--gear=dennis:geen_zwaard`, `--scenario=onbekend`;
- `--scenario` alleen schakelt de CSV-modus in; de standaardwaarden van het scenario;
- het scenario zelf: Lv 7 met tas, Lv 7 zonder items (0 items gebruikt), Lv 8 met tas; elk 4 echte
  baasgevechten, solo Dax met Vonkzwaard, juiste level/max HP, geen timeouts.

## 2. Commando's

```
G=C:/Users/krele/Desktop/SAPIENTIA/Tools/Godot/Godot_v4.3-stable_win64_console.exe
$G --headless --path . --import          # eenmalig (verse worktree)

# hoofdmaat, policy simpel, LV = 7 en 8
$G --headless --path . -- --battlesim --scenario=golem --party=dennis:<LV> --runs=1000 --seed=7 \
   --policy=simpel --out=<map>/kb_lv<LV>_items.csv
$G --headless --path . -- --battlesim --scenario=golem --party=dennis:<LV> --runs=1000 --seed=7 \
   --policy=simpel --items=none --out=<map>/kb_lv<LV>_none.csv

# controle: policy standaard (met items)
$G --headless --path . -- --battlesim --scenario=golem --party=dennis:<LV> --runs=1000 --seed=7 \
   --policy=standaard --out=<map>/kbstd_lv<LV>_items.csv

# kruiscontrole: het letterlijke r4-commando (zonder --scenario)
$G --headless --path . -- --battlesim --party=dennis:<LV> --enemy=baas_kennis_beest --runs=1000 --seed=7 \
   --policy=simpel --items=drankje:5,kruid:2,toverwater:2 \
   --gear=dennis:vonkzwaard+kaftschild+leren_kap+leren_harnas --out=<map>/r4cmd_lv<LV>.csv
```

Samenvatten: gemiddelden over de CSV-kolommen `win`, `turns`, `hp_left_pct`, `items_used`,
`items_detail`, `kos` (eenmalig Python-scriptje, niet bewaard). `--runs=1000` met één groep = precies
1000 gevechten per cel. Elke run duurde ~15 s (de vier cellen parallel).

## 3. Resultaten r5 (seed 7, 1000 gevechten per cel)

Kolommen: winst; gem. beurten (rondes) over alle gevechten; gem. HP over (% van max HP, verloren
gevecht = 0) en tussen haakjes alleen over de gewonnen gevechten; gem. items per gevecht (drankje /
kruid); KO's = aandeel gevechten waarin Dax KO gaat (solo, dus 100% - winst). Toverwater werd nooit
gebruikt (Dax heeft geen spreuken). Geen timeouts.

### Policy `simpel` (hoofdmaat)

| Lv | tas | winst | beurten | HP over (bij winst) | items (drankje / kruid) | KO's |
|---|---|---|---|---|---|---|
| 7 | met items | **63,0%** | 14,5 | 23,2% (36,8%) | 4,86 (4,02 / 0,84) | 37,0% |
| 7 | zonder items | **0,5%** | 9,2 | 0,0% (1,4%) | 0 | 99,5% |
| 8 | met items | **82,0%** | 14,8 | 30,9% (37,7%) | 4,52 (3,80 / 0,72) | 18,0% |
| 8 | zonder items | **49,0%** | 10,2 | 6,5% (13,2%) | 0 | 51,0% |

### Policy `standaard` (controle, met items)

| Lv | winst | beurten | HP over (bij winst) | items (drankje / kruid) | KO's |
|---|---|---|---|---|---|
| 7 | 69,6% | 14,9 | 27,4% (39,3%) | 5,20 (4,19 / 1,01) | 30,4% |
| 8 | 80,7% | 15,2 | 32,8% (40,6%) | 4,98 (4,05 / 0,93) | 19,3% |

Ruis: bij 1000 gevechten is de standaardfout op een winrate rond 60-80% ongeveer ±1,3-1,5 punt.

## 4. Vergelijking met r4

| cel | r4 | r5 | verschil |
|---|---|---|---|
| Lv 7 met items (simpel) | 63,0% · 14,5 · 23,2% · 4,86 · KO 37,0% | 63,0% · 14,5 · 23,2% · 4,86 · KO 37,0% | 0 |
| Lv 8 met items (simpel) | 82,0% · 14,8 · 30,9% · 4,52 · KO 18,0% | 82,0% · 14,8 · 30,9% · 4,52 · KO 18,0% | 0 |
| Lv 7 zonder items | 0,5% · 9,2 | 0,5% · 9,2 · 0,0% | 0 |
| Lv 8 zonder items | 49,0% · 10,2 · 6,5% | 49,0% · 10,2 · 6,5% | 0 |
| Lv 7 met items (standaard) | 69,6% · 14,9 · 27,4% · 5,20 | 69,6% · 14,9 · 27,4% · 5,20 | 0 |
| Lv 8 met items (standaard) | 80,7% · 15,2 · 32,8% · 4,98 | 80,7% · 15,2 · 32,8% · 4,98 | 0 |

**Alle cellen zijn exact gelijk aan r4.** Daarnaast is de CSV van het letterlijke r4-commando
(`--gear`, zonder `--scenario`) byte-voor-byte gelijk aan de `--scenario=golem`-CSV (Lv 7 en Lv 8,
`cmp` zonder verschil).

Verklaring (waarom er geen verschil is):

- **Zelfde gevecht:** `--scenario=golem` levert dezelfde party, uitrusting, tas en groep als het
  r4-commando; het is alleen een kortere schrijfwijze.
- **Zelfde RNG-stroom:** de CSV-runner seedt per gevecht met `hash([seed, group_id, run])`; seed, groep
  en runnummers zijn gelijk. (Het WM1-overzicht-pad uit main, `--enemy=all --total=N`, gebruikt een
  andere stroom, `hash([seed, "boss_scenario", ...])`, en alleen Lv 8; dat pad is hier niet gemeten.
  Een andere stroom geeft binnen de ruis andere getallen, zoals r4 zag bij het gebiedsrapport
  `--only=golem`: 82% vs 80,7% bij `standaard`.)
- **Geen relevante code-wijziging sinds r4:** tussen de r4-basis (`da0263f`) en nu zijn
  `scripts/battle/`, `scripts/data/game_data.gd` en `scripts/equipment.gd` ongewijzigd. Wat er wel bij
  kwam (charge-attack, SoM-arena, Wilgendal, formule-/enemy-tests) raakt het beurtgevecht in
  `battle.tscn` niet.
- **`--items=none` vs `--items=drankje:0`:** beide geven een tas zonder bruikbare items; de policy
  kiest dus dezelfde acties en de uitkomst is gelijk.

## 5. Conclusie

Optie A blijft kloppen met het doel bij `kennis_beest.boss` ("Lv 7 wint slim met meerdere items,
domweg aanvallen verliest meestal"): Lv 7 met items 63-70% winst bij ~5 items, zonder items 0,5%;
Lv 8 beloont een extra level (82% met items, 49% zonder). De meting is nu met één commando
reproduceerbaar (`--scenario=golem`) en door `--battlesimtest` gedekt.

Niet meegenomen: kern-regels, Dungeon100 verdieping 80, gewone `kennis_beest` (46/14/7), een
tussenstap ATK 25/26 (ontwerpkeuze voor Forge/Dennis).

## 6. Tests

| suite | uitslag |
|---|---|
| `--battlesimtest` | RESULT OK, 68 PASS, 0 FAIL (was 58; +10 nieuw) |
| `--battlesimenemytest` | RESULT OK, 22 PASS, 0 FAIL |
| `--wm1balanstest` | RESULT OK, 65 PASS, 0 FAIL |
