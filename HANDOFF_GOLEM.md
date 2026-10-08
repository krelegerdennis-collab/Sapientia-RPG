# HANDOFF – Golem-baas 'roze kern' + definitieve stats (pakket 'golem', RPG CODE)

Basis: `/workspace/lufia_v13` zoals die was op **6 okt 2026 12:49 (Europe/Amsterdam)**; laatste
wijziging van Forge daarin: `scripts/tests/dungeon_tests.gd` om 12:47. Dat is ná de merge van het
menu-pakket (`save_screen.gd`, `hero_portrait.gd`, `equipment.gd` staan erin) en mét Forge's fix
in `debug_autotest.gd` (bestiarium 3/6). Kopie van die stand: `/workspace/.code_golem_base_v13`.
Gewerkt alleen in `/workspace/code_golem/`; geen enkele `lufia_v*`-map aangeraakt.
Patch: `/workspace/code_golem/code_golem.patch` (git-diff tegen die stand, zonder `.godot/`/`*.uid`).
Toepassen in een kopie van v13: `git apply code_golem.patch`. Gecontroleerd: op een verse kopie
van de 12:49-stand geeft dat precies `code_golem`; `git apply --check` op de live v13 van 13:22
(Forge had toen alleen map-monster-art, `export_presets.cfg` en `handwerk.txt` veranderd) lukt ook.
Geen binaire bestanden in de patch (geen nieuwe art nodig).

## 1. Wat er gebouwd is
**De Golem-baas** = de vijand `kennis_beest` in een **baasgevecht** (`GameState.pending_boss`; de
Golem op het platform in de Archieven, of F3 in debug). Dan gelden de baas-stats uit het nieuwe
blok `"boss"` in zijn data + de **roze kern**. Het gewone Kennis-Beest (zwakke Golem-variant die
op de kaart rondloopt en op de wereldkaart kan opduiken) houdt Forge's waarden.

**Roze kern** (klein en leesbaar op een telefoon):
1. Start: één regel uitleg *'Pantser op de kern! Wacht op het roze licht.'*
2. **Kern dicht** (ronde 1-2, 4-5, ...): twee steenplaten over de kern (met een dun roze naadje).
   Alle schade op de Golem **x0,4**, het schadegetal is grijs. De Golem valt gewoon aan
   (20% kans op Boekenhamer x1,5).
3. **Elke 3e ronde** (3, 6, 9, ...) aan het begin: *'De kern gloeit roze! Het Kennis-Beest laadt
   op...'* + roze flits. De platen schuiven opzij, roze gloed om de kern, de idle-animatie van de
   kern pulseert sneller (0,4 -> 0,15 s per frame). Zolang je kiest staat bovenin de roze strook
   *'Roze kern open! Val nu aan!'*. Schade op de kern **x2**, het getal is roze.
4. In die ronde is de Golem als **laatste** aan de beurt:
   - kreeg de kern **>= 20 schade** in die ronde: *'Raak! De lading barst. Het Kennis-Beest
     wankelt.'* – geen aanval;
   - anders: *'Het Kennis-Beest: Hamerslag!'* = ATK x2,2 (verdedigen halveert, zoals altijd).
   Daarna *'De kern sluit zich weer.'*, platen dicht.
5. Geen vastloper: het venster komt altijd terug (elke 3e ronde), Verdedig / Item kan altijd,
   vluchten blijft mogelijk (zoals Forge's tests het gebruiken), verliezen = gewoon game over /
   wakker worden (bestaande regel). Eén klap van Dennis (vanaf Lv 1) haalt de 20 al.

**Mechanische Wachter**: definitieve stats (geen speciale regel; Zegelslag 15% x1,4).

## 2. Bestanden
| Bestand | Wat |
|---|---|
| `scripts/battle/boss_core.gd` (nieuw) | Regels van de kern (geen beeld, los testbaar): schema, schade x0,4/x2, lading kapot of Hamerslag, berichten, `apply_boss()` |
| `scripts/battle/boss_core_view.gd` (nieuw) | Beeld: pantserplaten / roze gloed op het Golem-plaatje (kind van de vijand-knop, klikken gaan erdoor) |
| `scripts/battle/battle.gd` | Kleine haakjes (allemaal gemarkeerd met `v0.14`): baas-stats bij het maken van de vijand, kern + beeld eraan, uitleg en telegraaf aan het begin van de ronde, oplaad-actie als laatste, `_hit` schaalt schade door de kern (grijs/roze getal), `_core_resolve` (wankelen of Hamerslag), roze strook tijdens het kiezen. Formules en de rest van het gevecht zijn niet veranderd. |
| `scripts/data/game_data.gd` | `kennis_beest.boss` (baas-stats + `core`), `mech_wachter` definitief |
| `scripts/game_state.gd` | Eén regel: `--golemtest` in de lijst met testers |
| `scripts/tests/golem_tests.gd` (nieuw) | De tests (§5) |
| `HANDOFF_GOLEM.md`, `code_golem.patch` | dit bestand en de patch |
`hd_ui.gd` is niet aangeraakt. Geen nieuwe art nodig (de platen worden in code getekend in de
steenkleuren van `golem_boss_v2.py`).

## 3. Definitieve stats
**Golem-baas** (`kennis_beest` in een baasgevecht; art v2 met hamer + aparte runecirkel, zoals Forge):
| HP | ATK | DEF | MAG | MDEF | SPD | EXP | Goud | Buit | Zwak | Bestand |
|---|---|---|---|---|---|---|---|---|---|---|
| 140 | 15 | 10 | 8 | 12 | 6 | 60 | 50 | Drankje 100%, Toverwater 50% | vuur | bliksem |
Kern: elke 3e ronde open; dicht x0,4, open x2,0; lading kapot bij >= 20 schade; Hamerslag x2,2;
Boekenhamer 20% x1,5.

**Mechanische Wachter** (`mech_wachter`):
| HP | ATK | DEF | MAG | MDEF | SPD | EXP | Goud | Buit | Zwak | Bestand |
|---|---|---|---|---|---|---|---|---|---|---|
| 30 | 12 | 8 | 0 | 4 | 5 | 10 | 8 | Drankje 25% | bliksem | – |
Zegelslag 15% x1,4. (Was voorlopig: 26/11/6/–/–/5, 9 EXP, 7 goud, Drankje 20%, Zegelslag x1,3.)

Ter vergelijking, het gewone Kennis-Beest blijft 46/14/7/–/–/6, 24 EXP (Forge).
Let op: MAG/MDEF van vijanden doen nu nog niets (vijanden spreken geen spreuken en de
spreukformule kijkt nog niet naar MDEF); 'buit' en 'zwak/bestand' zijn ook nog alleen informatie
(bestiarium). Dat is zo in v13.

## 4. Waarom deze getallen
Schadeformule (ongewijzigd, `battle.gd`): ATK x mult - DEF/2, +/-15%, min. 1; verdedigen = helft.

**Op welk level is Dennis bij de Golem?** Oefengevecht (Mosslijm, 3 EXP) + elk map-monster in de
ingangskamer één keer (3+4+5+6+24+10) = **55 EXP = Lv 2** (Lv 3 = 60 EXP). De echte kerker krijgt
meer kamers/Wachters, dus **doel = Lv 3**, met Lv 2 als 'vroeg maar te doen'. Dennis heeft het
Kort zwaard (zwaardles) en 3 Drankjes + 3 kruiden (kist van de Oude Man).

| Dennis | HP | ATK | DEF | op pantser | op open kern | Golem normaal | Boekenhamer | Hamerslag (verdedigd) |
|---|---|---|---|---|---|---|---|---|
| Lv 2 | 51 | 20 | 10 | ~6 | ~30 | ~10 | ~18 | ~28 (14) |
| Lv 3 | 60 | 23 | 12 | ~7 | ~36 | ~9 | ~17 | ~27 (13) |

- **HP 140**: op Lv 3 ~50 schade per ronde-van-3 (2x pantser + 1x kern) -> ~3 vensters, ~9-10
  rondes: lang genoeg voor een baas, kort genoeg voor een telefoon.
- **x0,4 dicht / x2 open**: zonder de kern te raken is hij niet te verslaan (zie simulatie) –
  de kern is dus echt de sleutel, zoals in het verhaal (scène 4: 'zwakke plek = roze kern').
- **ATK 15**: ~9 per klap op Lv 3; met 60 HP genoeg ruimte, maar zonder genezen gaat het vaak
  mis -> items gebruiken loont.
- **Hamerslag x2,2**: ~27 (bijna de helft van Dennis' HP) – een duidelijke straf, maar nooit
  in één klap KO vanaf volle HP; verdedigen maakt er ~13 van.
- **Lading kapot bij 20**: één gewone klap van Dennis (ook Lv 1: min. 20) – leesbaar: 'roze =
  aanvallen'. Later met Noor/Lotte (zwakkere fysieke klap) moet je er echt op mikken.
- **EXP 60 / Goud 50**: een flinke beloning (net één level rond Lv 3).

**Simulatie** (`golem_tests.gd` deel C, 1500 gevechten per regel, zelfde formules, items:
3 Drankjes + 3 kruiden):
| Dennis | slim (kern raken, genezen < 40%) | domweg (altijd aanvallen, nooit genezen) | nooit de kern raken |
|---|---|---|---|
| Lv 2 | 100% winst, ~12 rondes, ~2,1 items | 0% | 0% |
| Lv 3 | 100% winst, ~9,4 rondes, ~1,1 items | ~34% | 0% |
| Lv 4 | 100% winst, ~8,9 rondes, ~0,7 items | ~94% | 0% |

Mech. Wachter: Dennis Lv 1 wint altijd zonder items (3 klappen, ~17 HP kwijt), Lv 2 in 2 klappen
(~8 HP kwijt). Sterkste gewone vijand van de Archieven, onder het Kennis-Beest (Forge's dungeontest
eist dat ook).

## 5. Testen
```
godot --headless --path . -- --golemtest
xvfb-run -a godot --path . --rendering-driver opengl3 -- --golemtest --shots=/workspace/code_golem_shots
```
`--golemtest`: A) regels van de kern (open in ronde 3/6/9/12, x0,4 en x2, min. 1, alleen open
schade telt, lading kapot / Hamerslag, close(), standaardwaarden, berichten <= 60 tekens);
B) definitieve stats, gewone Kennis-Beest gelijk, Wachter tussen klein en Kennis-Beest;
C) balans-simulatie (tabel hierboven) + Wachter; D) **echt baasgevecht** in de Archieven met
gesimuleerde toetsen: baas-stats, platen precies op de kern, uitleg, ronde 1 schade x0,4,
ronde 3 telegraaf + roze strook + snellere puls + schade x2 + 'lading barst' (geen schade voor
Dennis) + kern weer dicht, ronde 6 verdedigen -> Hamerslag gehalveerd, en daarna **uitspelen als
een speler** (kern open = aanvallen, < 40% HP = Drankje) tot de overwinning (+60 EXP, terug in
de Archieven, bestiarium).

Uitslag op 6 okt 2026 (headless, elk met een eigen user://-map):
| Test | Godot 4.3 | Godot 4.7.2 | v13-basis zonder dit pakket |
|---|---|---|---|
| menutest | 225 PASS, 0 FAIL | 225 PASS, 0 FAIL | 225 / 225 |
| autotest | 407 PASS, 0 FAIL | 407 PASS, 0 FAIL | 407 / 407 |
| puzzletest | 127 goed, 0 fouten | 127 goed, 0 fouten | 127 / 127 |
| dungeontest | 122 goed, 0 fouten | 122 goed, 0 fouten | 122 / 122 |
| golemtest (nieuw) | 54 goed, 0 fouten | 54 goed, 0 fouten | – |
(Het echte gevecht in deel D won op 4.3 met 1 Drankje, op 4.7.2 met 2; beide keren 3x 'lading
kapot' en 1 Hamerslag – de verdedigde in ronde 6.)

Screenshots (`/workspace/code_golem_shots/`, gevecht = fijn raster 768x432 + `_3x` = 1152x648):
- `golem_kern_dicht` – ronde 1, pantserplaten over de kern
- `golem_kern_open` – ronde 3, kern open (roze gloed), strook 'Roze kern open! Val nu aan!'
- `golem_kern_raak` – Dennis raakt de open kern (roze getal 32)
- `golem_hamerslag` – ronde 6, verdedigd tegen de Hamerslag (13 schade), kern weer dicht

## 6. Open vragen voor Dennis
1. **Level bij de Golem**: ik ga uit van Lv 3 (= de ingangskamer + een paar Wachters meer).
   Komen er meer kamers, dan wordt hij makkelijker (Lv 4: 94% wint zelfs zonder te genezen).
2. **Eén vijand of twee?** Nu is de Golem = Kennis-Beest met een baas-blok, zodat het bestiarium
   op 6 blijft. Wil je de baas als apart nummer in het bestiarium (eigen naam, bv. 'De Golem')?
3. **Vluchten** uit het baasgevecht kan nu nog (Forge's tests gebruiken dat). Lufia 2 laat dat bij
   bazen meestal niet toe. Uitzetten?
4. **De laatste kracht van de Oude Man** (PROLOOG scène 4: 'kern nu tijdelijk kwetsbaar'): nu
   niet gebouwd. Idee: het eerste venster al in ronde 1, of een gratis eerste klap x2.
5. **EXP 60 / Goud 50 / buit**: akkoord? (Buit doet in v13 nog niets.)
6. **Wachter**: geen eigen trucje (alleen Zegelslag). Iets kleins erbij, bv. 'schild omhoog'
   (1 ronde DEF x2)?
