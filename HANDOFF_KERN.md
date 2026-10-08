# HANDOFF – Kernfragmenten stap 1 van 3 (RPG CODE, v0.15)

Basis: `/workspace/lufia_v14` (met de gemergde Archief-patch; archieftest 91, golemtest 62 bij Forge).
Kopie gemaakt wo 7 okt 2026 21:01:52 CEST. (Stap 1 patch-check 21:52: past schoon op een verse kopie van v14; v14 ongewijzigd.) Werkkopie `/workspace/code_kern/`, patch
`/workspace/code_kern/code_kern.patch` (tegen v14). lufia_v9..v15 zijn niet aangeraakt.

Stap 2 (archiveren/temmen) en stap 3 (glitch-fusie) zijn NIET gebouwd; het datamodel laat er ruimte voor
(zie §2).

## 1. Bestanden

| Bestand | Wat |
|---|---|
| `scripts/data/kern_data.gd` (nieuw) | `KERNFRAGMENTEN`, `KERN_SKILLS`, `WORLD_ABILITIES`, `fragment_for_boss()`, `validate()` |
| `scripts/game_state.gd` | `kernfragmenten` (in de save als `"kernen"`), `pending_kern_absorb`, `grant_kern()`, `has_kern()`, `has_world_ability()`, `world_abilities()`, `kern_skills_of()`; geven in `end_battle()` na een gewonnen baasgevecht; `--kerntest` |
| `scripts/battle/battle.gd` | Kernslag: `Magie` aan als de held een kernvaardigheid heeft, regel in het Magie-menu, actie `kern_skill`, opladen per ronde (kleine hooks + één blok onderaan) |
| `scripts/kern/kern_absorption.gd` (nieuw) | het absorptie-moment op de kaart |
| `scripts/map.gd` | 5 regels: start het moment als `GameState.pending_kern_absorb` gezet is |
| `scripts/puzzle/puzzle_logic.gd` | zware kasten (`heavy_blocks`, `abilities`, reden `"te zwaar"`) |
| `scripts/puzzle/puzzle_room.gd` | vaardigheden uit GameState doorgeven, hint-tekst bij een zware kast |
| `scripts/puzzle/push_block.gd` | uiterlijk zware kast (tint + roze rune; eigen art `assets/puzzle/kast_zwaar.png` wordt gebruikt als die bestaat) |
| `scripts/data/puzzle_rooms.gd` + `scenes/maps/kern_demo.tscn` (nieuw) | demo/test-kamer `kern_demo` met één zware kast |
| `scripts/ui/status_screen.gd` | regel `Kernen: Golemkern (Kernslag)` (alleen bij de hoofdheld, alleen als hij een kern heeft) |
| `scripts/tests/kern_tests.gd` (nieuw) | `--kerntest` |
| `scripts/tests/dungeon_tests.gd` | na de echte Golem-winst (deel F) het absorptie-moment wegklikken zoals een speler (+1 check); anders bleef de speler op slot en faalden de gevechten van deel G |
| `assets/ui/icons/golemkern.png`, `assets/fx/kern_absorptie.png` | art van RPG ART (`/workspace/art_kern_v15/out/`), alleen gekopieerd. **Forge levert deze bestanden in v15**; de patch bevat ze ook, zodat hij los werkt. Hun `.import` zit er niet in (Godot maakt die zelf). |

`hd_ui.gd` is niet aangeraakt.

## 2. Datamodel (`scripts/data/kern_data.gd`)

```gdscript
KERNFRAGMENTEN = {
  "golemkern": {
    "id": "golemkern", "naam": "Golemkern",
    "beschrijving": "Het roze hart van de Golem. Zwaar en warm; het geeft je de kracht van steen.",
    "icon": "res://assets/ui/icons/golemkern.png",
    "source_boss": "kennis_beest",          # sleutel in GameData.ENEMIES (moet een 'boss'-blok hebben)
    "battle_skill": "kernslag",             # sleutel in KERN_SKILLS ("" = geen)
    "world_ability": "zware_blokken",       # sleutel in WORLD_ABILITIES ("" = geen)
    "kleur": Color(1.0, 0.36, 0.78),        # gloed van het absorptie-moment (optioneel)
  },
}
```

- **Volgende baas = alleen data**: een regel in `KERNFRAGMENTEN` (+ eventueel een `KERN_SKILLS`- en
  `WORLD_ABILITIES`-regel). `end_battle()` zoekt per verslagen baas `fragment_for_boss(enemy_id)`.
- `validate(GameData.ENEMIES)` controleert: alle velden, id = sleutel, baas bestaat en heeft een
  baasgevecht, één kern per baas, vaardigheden bestaan, icoon bestaat, Kernslag-achtige vaardigheden zijn
  `physical`/`enemy`, `atk_mult > 0`, `cooldown >= 1`, naam max 8 tekens (gevechtsmenu).
- **Save**: `"kernen": {"golemkern": {"bron": "kennis_beest", "stap": 1}}`. Oude saves zonder dit veld
  laden gewoon (geen kernen); onbekende ids vallen bij het laden weg.
- **Ruimte voor stap 2/3**: per fragment staat in de save een eigen dictionary (`"stap"` en straks bijv.
  `"gearchiveerd"`, `"fusie"`); in de tabel kunnen velden als `"archief"` / `"fusie"` erbij zonder dat
  stap 1 iets merkt (validate kijkt alleen naar de verplichte velden).
- **Wie draagt de kern**: de hoofdheld (`GameState.MAIN_HERO`, nergens 'ruben' of 'dennis' hard).
  `kern_skills_of(hero_id)` geeft alleen voor MAIN_HERO vaardigheden; Noor krijgt niets.

## 3. Geven + absorptie-moment

- `GameState.end_battle("win")` in een baasgevecht (`pending_boss`): voor elke vijand met een kern
  `grant_kern()` (eenmalig; een tweede keer = `false`, nooit dubbel) en `pending_kern_absorb = id`.
  Het geven gebeurt **vóór** de autosave van de kaart, dus de kern zit meteen in de autosave.
- Vluchten (bijv. de F3-debugbaas in de autotest) of verliezen geeft niets. De gewone (niet-baas)
  Kennis-Beesten geven ook niets.
- `map.gd` start daarna `scripts/kern/kern_absorption.gd` (werkt in elke kaart, dus ook in de
  Golemhal, die van map.gd erft):
  1. wacht 0,45 s (fade-in) en tot er geen cutscene/tekstvak meer loopt; speler op slot;
  2. effect `kern_absorptie.png` (192x48, `hframes = 4`, 0,12 s per frame, niet loopen), `centered`
     dus midden (24,24), als kind van de held op `(0,-4)` = zijn borst (12 px boven zijn voeten);
     daaronder een additieve roze gloed (zelfde radiale gloed als het savepunt, `BookPoint.aura_texture`)
     en op het laatste frame een korte roze flits op de held; het laatste frame vervaagt in 0,25 s;
  3. tekst (uit de data, dus ook goed voor latere kernen):
     `Dennis absorbeert de Golemkern!` / `Nieuwe vaardigheid: Kernslag. (In het gevecht: Magie > Kernslag)` /
     `Nieuw: Zware blokken duwen. Je kunt nu zware, met runen beladen kasten duwen.` (`{naam}` = spelersnaam);
  4. gloed weg, speler vrij, `pending_kern_absorb = ""`, autosave met reden `"kern"`.
- Wisselt de kaart midden in het moment (kan in het spel niet, de speler staat op slot; wel in tests),
  dan stopt het netjes; was de tekst nog niet gezien, dan speelt het op de volgende kaart alsnog.
- Bekend randgeval: crasht het spel precies tussen het geven en het moment, dan heb je de kern wel
  (save) maar zie je het moment niet (`pending_kern_absorb` gaat bewust niet mee in de save).

## 4. Kernslag (gevechtsvaardigheid)

| | |
|---|---|
| Waar | gevechtskruis **Magie** > `Kernslag KERN` (titel "Kern"; met spreuken erbij "Magie/Kern"). Dennis heeft geen spreuken, dus Magie gaat aan zodra hij een kern heeft. |
| Doel | één vijand (gewone doelkeuze) |
| Schade | `ATK x 1,5 - DEF x 0,25`, +/- 15 %, min. 1; verdedigt het doel: de helft (gewone aanval: `ATK - DEF x 0,5`) |
| Kosten | geen MP (Dennis heeft 0 MP), wel **3 rondes opladen**: ronde 1, 4, 7, ... In het menu staat dan `Kernslag (2)` / `(1)` uitgegrijsd. Elk gevecht begint opgeladen. |
| Kern van de baas | gaat gewoon door `_damage()`, dus ook pantser x0,4 / open kern x2 |
| Beeld | bericht `Dennis: Kernslag!`, held en doel kort roze, gewone uithaal |

Getallen (Dennis Lv 10 + Vonkzwaard = ATK 53, gemiddelden zonder spreiding):

| Doel (DEF) | Aanval | Kernslag | per slag | over 3 rondes (K + 2 aanvallen vs 3 aanvallen) |
|---|---|---|---|---|
| Papiergeest (3) | 52 | 79 | +53 % | +18 % |
| Mech. Wachter niveau 4 (15) | 46 | 76 | +66 % | +22 % |
| DEF 22 (zoals de Golem) | 42 | 74 | +76 % | +25 % |

Waarom zo: duidelijk sterker dan een aanval (ook tegen gepantserde vijanden, door de DEF x0,25) maar
door het opladen geen knop om steeds in te drukken; het slimme moment is bijv. een open baaskern (x2).
Je krijgt hem pas na de Golem, dus de Golem-balans (golemtest) verandert niet. Getallen staan in
`KERN_SKILLS["kernslag"]` en zijn daar los aan te passen.

## 5. Zware blokken duwen (wereldvaardigheid)

- In `scripts/data/puzzle_rooms.gd` een kast zwaar maken:
  `"z": {"type": "block", "id": "kast_zwaar", "heavy": true}`
  (optioneel `"ability": "<andere vaardigheid>"` en `"hint": ["eigen", "tekst"]`).
- Zonder de vaardigheid: de kast blijft staan, geluid `duw_mis`, tekst
  `Deze kast zit vol runen en is loodzwaar.` / `Hij beweegt geen millimeter... Daar is meer kracht voor nodig.`
- Met de vaardigheid: gewoon duwen zoals elke kast (zelfde regels: platen, poorten, herstelsteen).
- `PuzzleLogic` blijft een los model: `PuzzleRoom` zet `logic.abilities` uit `GameState.world_abilities()`
  (bij het bouwen en bij elke duw, dus meteen goed na het absorberen).
- Uiterlijk: gewone kast, paarsgrijs getint, met een kleine roze rune. Wil RPG ART eigen art:
  `assets/puzzle/kast_zwaar.png` (16x32, zelfde vorm als `kast.png`) wordt dan vanzelf gebruikt.
- **Demo/test**: kamer `kern_demo` (`scenes/maps/kern_demo.tscn`, geen verhaalroute, alleen voor
  `--kerntest`): zware kast 2x naar rechts op de zware plaat -> poort open. Forge's kaarten zijn niet
  aangeraakt.
- **Plek voor Forge**: een zware kast werkt het best als *terugkom-geheim* in kamers die je vóór de
  Golem al ziet, bijv. een zijnis met een kist achter een zware kast in de Vergeten Archieven
  (`archief_test`) of in een van de Archief-verdiepingen 2-3 (puzzelkamers in `puzzle_rooms.gd`).
  Een zware kast mag nooit de verplichte route vóór de Golem blokkeren.

## 6. Tests

`/workspace/run_tests_iso.sh` (eigen user://), headless, Godot 4.3 en 4.7.2:

Laatste volledige run wo 7 okt 21:49-22:15 CEST (`/workspace/.scratch/kern/t3_*`), PASS/FAIL:

| Suite | 4.3 | 4.7.2 | v14 (Forge) |
|---|---|---|---|
| autotest | 408 / 0 | 408 / 0 | 408 |
| menutest | 225 / 0 | 225 / 0 | 225 |
| puzzletest | 152 / 0 | 152 / 0 | 150 (+2: kamer kern_demo gevalideerd) |
| dungeontest | 165 / 0 | 165 / 0 | 164 (+1: absorptie wegklikken) |
| golemtest | 62 / 0 | 62 / 0 | 62 |
| archieftest | 90 / **1** | 90 / **1** | 91 checks; dezelfde FAIL zit ook in een schone v14 (zie §8.6) |
| kerntest (nieuw) | 72 / 0 | 72 / 0 | - |

Geen SCRIPT ERRORs in alle logs.

`--kerntest` (scripts/tests/kern_tests.gd):
- A data: `validate()` leeg, validate vangt fouten, art-maten, Kernslag-getallen, kamer `kern_demo` geldig,
  elke zware kast vraagt een bestaande vaardigheid.
- B regels: eenmalig, geen dubbel, onbekend = false, alleen MAIN_HERO, save/load, oude save, onbekende kern.
- C echte Golem-winst in de Golemhal (via het monster): kern gegeven, absorptie-moment (frames 0-3 één
  keer, op de borst, additieve gloed), tekst, autosave "kern" met de kern, autosave laden; tweede
  overwinning: niets dubbel, geen nieuw moment.
- D Kernslag: Magie uit zonder kern / aan met kern, menu-regel, schade binnen de formule, sterker dan een
  aanval, (2)/(1)/klaar.
- E zware kast: logica, hint + blijft staan zonder kern, duwbaar met kern, op de plaat -> poort open.
- F statusscherm `Kernen`.

## 7. Screenshots (`/workspace/code_kern_shots/`, elk ook `_3x` = 1152x648)

Gemaakt wo 7 okt 21:48-21:49 CEST met
`xvfb-run ... Godot 4.3 --rendering-driver opengl3 -- --kerntest --shots=/workspace/code_kern_shots`
(veld 384x216, gevecht 768x432). Allemaal zelf bekeken.

| Bestand | Wat je ziet |
|---|---|
| `kern_absorptie.png` | Golemhal na de winst (Golem weg), frame 2: samengeperste roze kern + gloed op Dennis' borst |
| `kern_absorptie_bericht.png` | tekstvak `Dennis absorbeert de Golemkern!`, zachte gloed rond Dennis |
| `kernslag_menu.png` | gevecht, Magie gekozen, menu "Kern" met `Kernslag KERN` |
| `kernslag_raak.png` | `Dennis: Kernslag!`, roze uithaal, Papiergeest roze getint, schade 84 |
| `kernslag_opladen.png` | ronde 2: `Kernslag (2)` uitgegrijsd |
| `zware_kast_hint.png` | kern_demo zonder kern: `Deze kast zit vol runen en is loodzwaar.`, kast (met rune) staat stil naast Dennis |
| `zware_kast_geduwd.png` | met kern: kast op de zware plaat, poort boven open |
| `status_kernen.png` | statusscherm met de regel `Kernen  Golemkern (Kernslag)` |

## 8. Open vragen voor Forge / Dennis

1. Kernslag onder **Magie** (geen nieuwe knop in het kruis, zo blijft battle.gd klein). Liever een eigen
   knop/icoon "Kern" in het kruis? Dan hebben we een icoon van RPG ART nodig.
2. Zware kast: tint + rune in code. Eigen art `kast_zwaar.png` gewenst?
3. Waar komt de eerste echte zware kast (zie §5)? Ik heb geen kaart van Forge aangeraakt.
4. Moet het absorptie-moment ook een geluid krijgen? (er is nu geen speciaal geluid)
5. Puzzletest telt nu 2 checks meer (de nieuwe kamer `kern_demo` wordt mee gevalideerd), dungeontest 1 meer
   (absorptie wegklikken na de Golem).
6. **archieftest: 1 FAIL die al in v14 zit** (ook op een schone kopie van lufia_v14, beide versies):
   `tekstvak onderin en NIET over de kist` - het tekstvak staat bij de kist (13,4) bovenin (P (8,3)) en
   valt over de kist. Niet door deze patch; ik heb het tekstvak (dialog_box.gd) niet aangeraakt. Forge:
   bewust (tekstvak altijd bovenin) -> test aanpassen, of de at_bottom-regel terugzetten?
