# HANDOFF: puzzelsysteem De Vergeten Archieven (RPG CODE -> RPG Forge)

Werkmap: `/workspace/code_puzzles` (kopie van `lufia_v9`, v0.10). Niets aangeraakt in
`lufia_v9`, `lufia_v10`, `lufia_v11` of `code_menu`. Getest met Godot **4.3** (hoofdversie) en
**4.7.2** (op een tijdelijke kopie, zodat 4.7.2 geen .uid-bestanden in deze map schrijft).
Uitleg voor level-ontwerp en regels: [`docs/PUZZELS.md`](docs/PUZZELS.md).

## 1. Bestanden

### Nieuw

| Bestand | Doel | Afhankelijk van | Test |
|---|---|---|---|
| `scripts/puzzle/puzzle_logic.gd` (`class_name PuzzleLogic`, RefCounted) | Rooster-model zonder nodes: muren, kasten, platen, hendels, poorten (all/any/invert/latch), herstelstenen, signalen, speler-tile. `try_push`, `toggle_lever`, `set_player_tile`, `update`, `reset`, `is_solid`, `get_state/set_state`, signaal `changed(ids)`. Ook `validate(room)` (data-controle) en `autotile(layout)` (tegels uit binnen.png) | niets | deel A |
| `scripts/puzzle/puzzle_room.gd` (`class_name PuzzleRoom`, erft `res://scripts/map.gd`) | Bouwt in `_ready` (vóór `super._ready()`) Ground, laag `PuzzleFloor`, objecten, spawn `ingang`, uitgangen + randblokkades. Geeft de logica elke frame de speler-tile + doel-tile. Duwen/hendel/herstellen. Latch per spel in `GameState.puzzle_latched` (terugval: static dict). Puzzelstand blijft bewaard over een gevecht heen (`_battle_snapshots`). Doorzicht: kast half doorzichtig als de speler er direct achter staat. Geluidshaak `puzzle_sound(naam)` | map.gd, player.gd (`facing`, `is_moving`, `_target`, `place_at`, `get_tile`, `walk_speed`, `input_locked`), Dialog.ask, Transition, MapSpawn, MapExit, binnen.tres | deel B |
| `scripts/puzzle/push_block.gd` | Duwbare kast (StaticBody2D 14x14). `bump(player)` -> duwen. Node springt meteen, plaatje glijdt 0,25 s | `assets/puzzle/kast_duwbaar.png` (terugval tegels 6/7 van binnen.png) | A+B |
| `scripts/puzzle/lever.gd` | Hendel (StaticBody2D), `interact` = om, 2 frames | `hendel.png` | B |
| `scripts/puzzle/gate.gd` | Poort (StaticBody2D), botsing uit als open, 4 frames animatie (0,06 s/frame), donkere doorgang (ColorRect `#0b0a10`) eronder | `poort.png` | B |
| `scripts/puzzle/pressure_plate.gd` | Drukplaat (Node2D, geen botsing), 2 frames | `drukplaat.png` | B |
| `scripts/puzzle/reset_stone.gd` | Herstelsteen (StaticBody2D), 2 gloei-frames, `interact` -> 'De kamer herstellen?' | `herstelsteen.png` | B |
| `scripts/data/puzzle_rooms.gd` | `ROOMS` met kamer `archief_test` (14x11) | - | A |
| `scenes/maps/archief_test.tscn` | Testkamer (root met puzzle_room.gd, Void, lege Ground met binnen.tres, Objects+Player, Spawns, Exits, TouchControls) | bovenstaande | B |
| `scripts/tests/puzzle_tests.gd` | Tests deel A (logica, data, BFS-oplosser) + B (echte scène met gesimuleerde toetsen) | alles | `-- --puzzletest` |
| `assets/puzzle/hendel.png`, `drukplaat.png`, `poort.png`, `herstelsteen.png`, `kast_duwbaar.png` (+ `.import`) | **Echte art van RPG ART** (uit `/workspace/art_puzzle_v11/out/`), geïntegreerd en gecontroleerd met PIL (maten/frames kloppen, zie §5) | - | screenshots |
| `tools/art_puzzle_placeholders.py` | Placeholder-generator, ALLEEN terugval: schrijft alleen ontbrekende bestanden (`--force`, `--out=`) | PIL | handmatig |
| `docs/PUZZELS.md` | Handleiding (NL) | - | - |
| `HANDOFF_PUZZELS.md` | dit bestand | - | - |

### Gewijzigd (bestaande bestanden, klein)

| Bestand | Wat |
|---|---|
| `scripts/game_state.gd` | `puzzle_latched` (+ wissen bij nieuw spel, opslaan, laden), `--puzzletest`-haak, F4-actie `debug_puzzle` (TIJDELIJK) |
| `scripts/map.gd` | TIJDELIJK: F4 in debug-builds = naar de testkamer |
| `export_presets.cfg` | `scripts/tests/*` uit de export (beide presets) |

## 2. Samenvoegen in jouw nieuwere versie (exacte stappen)

1. Kopieer de nieuwe bestanden: `scripts/puzzle/` (map), `scripts/data/puzzle_rooms.gd`,
   `scripts/tests/` (map), `scenes/maps/archief_test.tscn`, `assets/puzzle/` (map, mag zonder
   `.import`: Godot maakt ze opnieuw), `tools/art_puzzle_placeholders.py`, `docs/PUZZELS.md`.
2. `scripts/game_state.gd` (5 plekken):
   - onder `var bestiary := {}`:
     ```gdscript
     ## Puzzels: kamer-id -> Array van poort-ids die voor altijd open zijn (latch). Gaat mee in de save.
     var puzzle_latched := {}
     ```
   - in `_ready()`, direct NA het `if "--autotest" ...:`-blok (zelfde inspringing als `if`):
     ```gdscript
     	# Puzzeltests: godot -- --puzzletest [--shots=/pad/map]  (zie scripts/tests/puzzle_tests.gd)
     	elif "--puzzletest" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://scripts/tests/puzzle_tests.gd"):
     		save_path = "user://puzzletest_save_1.json"
     		var ptester: Node = load("res://scripts/tests/puzzle_tests.gd").new()
     		ptester.name = "PuzzleTest"
     		get_tree().root.add_child.call_deferred(ptester)
     ```
   - in `_ensure_input_actions()`: commentaarregel `## "debug_puzzle" = F4: TIJDELIJK, naar de puzzel-testkamer (alleen in debug-builds).`
     en in de `keys`-dictionary `"debug_puzzle": [KEY_F4]` erbij.
   - in `new_game()`, na `bestiary.clear()`: `puzzle_latched.clear()`
   - in `save_game()`, in de `data`-dictionary na `"bestiary": ...`:
     `"puzzle_latched": puzzle_latched.duplicate(true),`
   - in `load_game()`, vlak vóór `_play_time_base = float(d.get("play_time", 0.0))`:
     ```gdscript
     	puzzle_latched = {}
     	var pl: Dictionary = d.get("puzzle_latched", {})
     	for k in pl:
     		puzzle_latched[k] = (pl[k] as Array).map(func(g): return str(g))
     ```
     (Oude saves zonder dit veld laden gewoon: dan `{}`. `SAVE_VERSION` hoeft niet omhoog.)
3. `scripts/map.gd` (TIJDELIJK, mag weg zodra de Archieven een echte ingang hebben):
   - onder `@export var encounters := true`:
     ```gdscript
     ## TIJDELIJK (puzzels): F4 in debug-builds gaat hierheen.
     const DEBUG_PUZZLE_ROOM := "res://scenes/maps/archief_test.tscn"
     ```
   - in `_process()`, vlak vóór `# F2 = forceer een gevecht ...`:
     ```gdscript
     	# TIJDELIJK (puzzels): F4 = naar de puzzel-testkamer (alleen debug-builds). Weghalen
     	# zodra De Vergeten Archieven een echte ingang heeft.
     	if OS.is_debug_build() and InputMap.has_action("debug_puzzle") and Input.is_action_just_pressed("debug_puzzle"):
     		if not GameState.in_battle and not GameState.changing_map and not player.is_moving \
     				and not Dialog.is_open and not menu_open():
     			player.input_locked = true
     			GameState.change_map(DEBUG_PUZZLE_ROOM, "ingang")
     ```
4. `export_presets.cfg`: in ELKE preset `exclude_filter` aanvullen met `scripts/tests/*`
   (`"tools/*, docs/*, scripts/debug_autotest.gd, scripts/tests/*, *.md, export_presets.cfg"`).
5. Eén keer `godot --headless --path . --import` (of de editor openen): nieuwe `class_name`s
   (`PuzzleLogic`, `PuzzleRoom`) in de class-cache en de .import-bestanden van de art.
6. Testen: `godot --headless --path . -- --puzzletest` (moet `RESULT OK` + exit 0 geven) en de
   gewone `-- --autotest`.

Let op bij samenvoegen: `puzzle_room.gd` leunt op `player.gd` (`_target`, `is_moving`,
`facing`, `walk_speed`, `place_at`, `get_tile`, `input_locked`, `bumped`/`bump()`,
`interact()`) en op `map.gd` (`ground`, `player`, `_process`, `$Objects`, `$Spawns`, `$Exits`).
Als je die in v0.11 hernoemt, moet `puzzle_room.gd` mee. Er staan geen preloads van puzzelcode in
`game_state.gd` (alleen een `load()` van de tester), dus geen kringverwijzingen.

## 3. FEIT/GETEST vs TODO

**Getest (Godot 4.3, headless; en dezelfde tests op 4.7.2 op een kopie):**
- `-- --puzzletest`: **127 PASS, 0 FAIL**, exit 0, op 4.3 (headless én xvfb + screenshots)
  en op 4.7.2 (headless).
  - Deel A (78): duwen (ok; tegen muur/kast/hendel/dichte én open poort/deur/herstelsteen/
    speler/doel-tile van de speler = geblokkeerd), platen (kast, speler, zwaar, los),
    hendel + signaal, poorten all/any/invert/latch, keten poort->poort, poort blijft open
    met de speler erin en gaat dicht als hij eruit is, reset (latch blijft), set_state,
    data-controle van elke kamer + 12 kapotte kamers die gevonden moeten worden, autotile,
    de bedoelde oplossing, valsspeel-check (speler op zware plaat), doodlopende stand.
    **BFS-oplosser**: archief_test is oplosbaar; 28.558 standen volledig doorzocht; in
    **elke** bereikbare stand kan de speler bij de herstelsteen of de ingang (0 standen
    zonder uitweg); na `UUU LL` (kast_a tegen de muur) NIET meer oplosbaar, na reset wel;
    met alleen kast_b NIET oplosbaar (beide kasten zijn echt nodig). Duurt ±12 s.
  - Deel B (49): kamer gebouwd (tegels, 8 objecten, lagen, spawn, uitgangen), echte duw met
    toetsen (node + botsing meteen verplaatst, plaatje glijdt), kast tegen de muur,
    herstelsteen: B = Nee (niets verandert), A = Ja (fade, alles terug, speler bij de ingang),
    oplossen met toetsen (kast_b op q, poort_2 botsing uit + frame 3, door de poort, A op de
    hendel, kast_a op p, poort_1 open + vergrendeld + in `GameState.puzzle_latched`), bericht
    bij X, niet voorbij X, via E naar het huis, F4 terug = herstel (poort_1 blijft open),
    gevecht midden in de puzzel (echt vluchten) = stand blijft, save/laden van de latch,
    doorzicht achter een kast.
- `-- --autotest` (bestaande test, geen regressie): **264 PASS, 0 FAIL** op 4.3 en op 4.7.2,
  net als de baseline vóór mijn wijzigingen (264/0).
  Let op: alle kopieën van het project delen dezelfde `user://`-map (zelfde projectnaam).
  Draaien er tegelijk autotests van andere werkmappen, dan kan de save-test
  ('Nee': niets opgeslagen) toevallig falen (gebeurde 1x op 4.7.2). Gebruik dan een eigen
  `XDG_DATA_HOME=/tmp/iets godot ...`; zo geïsoleerd was het weer 264/0.
- Screenshots (echte rendering, xvfb + opengl3, 3x nearest): `/workspace/code_puzzles_shots/`
  `01_start`, `02_doodlopend`, `03_herstelvraag`, `03b_achter_kast`, `04_opgelost`,
  `05_uitgang_bericht`. Zelf bekeken: muren/zijmuren kloppen met het huis, vaste kasten in de
  muur, duwbare kasten (koper + cyaan rune) duidelijk anders, poorten met donkere doorgang,
  kast-y-sort klopt.

**Niet getest / TODO:**
- Niet op een echte telefoon getest (touch-D-pad duwen zou hetzelfde moeten werken: het zijn
  dezelfde input-acties).
- Geen geluid: alleen het signaal `puzzle_sound`.
- De puzzelstand MIDDEN in een puzzel gaat niet mee in de save (alleen de latch-poorten).
  Opslaan kan in een puzzelkamer toch niet (geen opslagboek). Bij laden midden in een kast
  zet de kamer je bij de ingang.
- F4 en de ingang `E` -> huis zijn TIJDELIJK. De echte ingang van de Archieven (bij het bos) en
  de rest van de dungeon (`X` geeft nu alleen een bericht) komen later.
- Drukken van een plaat door de speler (niet-zware platen) zit in de logica en de unit-tests,
  maar wordt in archief_test niet gebruikt (beide platen zijn zwaar, zie docs/PUZZELS.md
  'Waarom zwaar?'). De BFS-oplosser houdt geen rekening met lichte platen.
- Vraag: X gebruikt deurtegel 5 in de BOVENrand; die tegel is getekend voor de onderrand. Ziet
  er acceptabel uit, maar RPG ART kan een 'doorgang boven'-tegel leveren.
- Vraag: de duwbare kast is 2 tiles hoog; achter een kast zie je de speler bijna niet. Daarom
  het doorzicht (`SEE_THROUGH_ALPHA = 0.6` in puzzle_room.gd, 1.0 = uit). Akkoord?

## 4. Afwijkingen van het ontwerp (en waarom)

1. **Beide platen zijn zwaar** (`"heavy": true`, nieuw veld) en **poort_1 heeft
   `needs: [plaat_p, plaat_q, hendel_h]`** i.p.v. `[plaat_p, hendel_h]`. Met lichte platen en
   latch kon je met één kast + jezelf op een plaat de grendelpoort openen; met alleen
   `[p, h]` was kast_a overbodig (kast_b kan na de hendel van q naar p). Nu zijn beide kasten
   nodig (BFS bewijst dat). Gevolg: de speler kan poort_2 niet meer openen door zelf op q te
   staan (dat was volgens het ontwerp toch nutteloos).
2. **Vast teken `B`** (vaste boekenkast, decor) toegevoegd: de Archieven horen vol boeken te
   staan, en zo zie je het verschil met de duwbare kast. Vier stuks in de testkamer, BFS-getest.
3. **Latch-opslag in `GameState.puzzle_latched`** (meteen in save/laden) i.p.v. alleen een
   static dict: de save had het toch nodig, en het waren maar 7 regels. De static dict in
   puzzle_room.gd blijft als terugval als `GameState` het veld niet heeft.
4. **Objecten worden in code opgebouwd** (geen aparte .tscn per object): minder bestanden om
   samen te voegen; alles staat in de 5 kleine scripts.
5. **Platen en poorten in een eigen laag `PuzzleFloor`** (onder Objects, niet y-sorted): ze
   liggen plat, de speler moet er altijd vóór lopen (ook in een open poort in de muurrij).
6. **Gevecht midden in de puzzel = stand blijft** (static `_battle_snapshots`), anders zou elke
   random encounter in een latere dungeonkamer je puzzel herstellen.
7. **Onzichtbare blokkade** buiten `E`/`X`, zodat je bij een bericht-uitgang niet van de map loopt.

## 5. Art (RPG ART) - GEÏNTEGREERD

De echte art uit `/workspace/art_puzzle_v11/out/` zit erin (`assets/puzzle/`). Met PIL
gecontroleerd: RGBA, maten kloppen. Vervangen = zelfde naam en maat, geen code nodig.

| Bestand | Maat | Frames | Gebruik in code |
|---|---|---|---|
| `hendel.png` | 32x16 | 2: 0 uit (rood, links), 1 aan (cyaan, rechts) | `lever.gd`, `hframes = 2` |
| `drukplaat.png` | 32x16 | 2: 0 omhoog, 1 ingedrukt (cyaan rune) | `pressure_plate.gd`, `hframes = 2` |
| `poort.png` | 64x16 | 4: 0 dicht .. 3 open (hek schuift omhoog), doorzichtig tussen de spijlen | `gate.gd`, `hframes = 4`, donkere ColorRect eronder |
| `herstelsteen.png` | 32x16 | 2 gloei-frames, MAGENTA (niet verwarren met het cyaan opslagboek) | `reset_stone.gd`, lus 0,5 s/frame |
| `kast_duwbaar.png` | 16x32 | 1 (onderste 16 px = de tile, bovenste 16 px steekt erboven uit) | `push_block.gd`, `offset = (0, -8)` |

Terugval: zonder `kast_duwbaar.png` tekent de kast tegel 6 boven 7 uit `binnen.png`; de
generator `tools/art_puzzle_placeholders.py` maakt ontbrekende bestanden in dezelfde maten.

## 6. Hernoeming hoofdpersoon -> dennis

In de nieuwe puzzelcode staat **nergens** de oude held-naam (gecontroleerd met grep op `scripts/puzzle/`,
`scripts/tests/`, `scripts/data/puzzle_rooms.gd`, `tools/art_puzzle_placeholders.py`). De
puzzelcode gebruikt alleen de speler-node (`$Objects/Player`), nooit een held-id; de test
gebruikt `GameState.pick_encounter_group()` en het party-loze `GameState.save_game/load_game`.
Er was dus geen `HERO_ID`-constante nodig. De bestaande v9-bestanden heb ik niet hernoemd.
