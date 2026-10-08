# Puzzels in De Vergeten Archieven

Scène 3 van de proloog (`/workspace/story/PROLOOG.md`): geen magie, dus **boekenkasten
duwen** en **mechanische hendels**. Dit document legt uit hoe het puzzelsysteem werkt en hoe je
een nieuwe puzzelkamer maakt, **alleen met data**.

## 1. Onderdelen

| Onderdeel | Bestand | Wat |
|---|---|---|
| Kamer-data | `scripts/data/puzzle_rooms.gd` | `ROOMS`: per kamer een ASCII-plattegrond + legenda |
| Rekenmodel | `scripts/puzzle/puzzle_logic.gd` (`PuzzleLogic`) | het rooster, de regels, de signalen. Geen nodes |
| Kamer-node | `scripts/puzzle/puzzle_room.gd` (`PuzzleRoom`, erft van `map.gd`) | bouwt de kamer uit de data, koppelt logica en nodes |
| Objecten | `scripts/puzzle/push_block.gd`, `lever.gd`, `gate.gd`, `pressure_plate.gd`, `reset_stone.gd` | de zichtbare objecten (in code opgebouwd, geen eigen .tscn) |
| Testkamer | `scenes/maps/archief_test.tscn` | `room_id = "archief_test"` |
| Art | `assets/puzzle/*.png` | van RPG ART (zie §6) |
| Tests | `scripts/tests/puzzle_tests.gd` | `godot --path . -- --puzzletest` |

## 2. Een nieuwe puzzelkamer maken

1. Voeg in `scripts/data/puzzle_rooms.gd` een sleutel toe aan `ROOMS`:

```gdscript
"archief_gang_2": {
	"name": "Vergeten Archieven - gang",
	"layout": [
		"####X####",
		"####1####",
		"#BB.....#",
		"#..a..p.#",
		"#.......#",
		"#r....h.#",
		"####E####",
	],
	"objects": {
		"a": {"type": "block", "id": "kast_a"},
		"p": {"type": "plate", "id": "plaat_p", "heavy": true},
		"h": {"type": "lever", "id": "hendel_h"},
		"1": {"type": "gate", "id": "poort_1", "needs": ["plaat_p", "hendel_h"], "mode": "all"},
		"r": {"type": "reset", "id": "herstelsteen"},
	},
	"entrance": {"map": "res://scenes/maps/archief_test.tscn", "spawn": "uit_gang"},
	"exit": {"map": "res://scenes/maps/archief_hal.tscn", "spawn": "ingang"},
},
```

2. Maak de scène: kopieer `scenes/maps/archief_test.tscn` en zet `room_id` op de nieuwe
   sleutel (en `map_name`). Ground, Spawns, Exits en de objecten worden bij het starten gebouwd:
   je hoeft in de editor niets te tekenen. De scène houdt dezelfde opbouw als elke map
   (Void, Ground, Objects met Player, Spawns, Exits, TouchControls); `PuzzleRoom` voegt er
   zelf `PuzzleFloor` (platen en poorten, onder Objects) aan toe.
3. Draai `godot --path . -- --puzzletest`: de data-controle test **elke** kamer in `ROOMS`
   (rechthoekig, precies één `E`, elk teken bekend, elk id uniek, elke `needs` bestaat,
   objecten niet in de rand, vrije vloer naast `E`, enz.). Een fout staat ook in de
   uitvoer van Godot zodra de kamer laadt (`push_error`).
4. Kun je hem echt oplossen? Kopieer in de test `_test_solver()` voor jouw kamer: de BFS-oplosser
   zoekt alle standen af en meldt ook of je ergens vast kunt komen te zitten zonder weg naar de
   herstelsteen of de ingang.

Spawnpunt: de kamer maakt zelf een `MapSpawn` met de naam **`ingang`** op de tegel naast `E`
(kijkt de kamer in). Kom je vanaf een andere map binnen, gebruik dan `target_spawn = "ingang"`.

### Tekens in de plattegrond

| Teken | Betekenis |
|---|---|
| `#` | muur. De bouwer kiest de tegel zelf (zie §4) |
| `.` | vloer |
| `E` | ingang (in de rand). Je verschijnt ernaast; erop stappen = `entrance` (map + spawn) |
| `X` | uitgang (in de rand): `exit` met `map` + `spawn`, of alleen `lines` (een bericht) |
| `B` | vaste boekenkast (decor, massief, niet te duwen). Er moet een `#` boven staan: die wordt de bovenkant van de kast |
| ander teken | een object uit `objects` (elk teken precies één keer) |

Buiten `E` en `X` zet de kamer een onzichtbare blokkade, zodat je niet uit het beeld loopt.

### Objecten

| type | velden | gedrag |
|---|---|---|
| `block` | `id` | duwbare boekenkast: loop ertegenaan, hij schuift 1 tile |
| `plate` | `id`, `heavy` (standaard `false`) | drukplaat. Ingedrukt door een kast, of door de speler als hij niet `heavy` is |
| `lever` | `id`, `on` (standaard `false`) | hendel: kijk ernaar + A = om |
| `gate` | `id`, `needs` (lijst ids), `mode` (`"all"`/`"any"`), `invert`, `latch` | poort/hek: open als de voorwaarde klopt |
| `reset` | `id` | herstelsteen: A = 'De kamer herstellen?' Ja/Nee |

## 3. De regels

**Duwen (Sokoban)**: je duwt door tegen een kast te lopen (één duw per stap, je loopt meteen
mee). Een kast gaat alleen naar een tegel die
- in de kamer ligt en geen muur of vaste kast is,
- geen andere kast is (je duwt nooit twee kasten tegelijk),
- geen hendel of herstelsteen is,
- **geen poorttegel** is, ook niet als de poort open is (zo kan een kast nooit een poort
  vastzetten of tussen twee poortstanden klem komen),
- geen ingang/uitgang is,
- niet de speler is (ook niet de tegel waar de speler heen loopt).

Je kunt een kast niet trekken. Een kast tegen een muur of in een hoek kan dus vastzitten: dat is
de bedoeling (Sokoban), daarvoor is de herstelsteen.

**Platen**: ingedrukt zolang er een kast op staat, of de speler (alleen als `heavy` niet aan
staat). Springt terug als hij vrijkomt.

**Poorten**: `needs` = lijst van ids van platen, hendels of andere poorten.
- `mode: "all"` = alles moet aan zijn, `"any"` = minstens één.
- `invert: true` = open als de voorwaarde NIET klopt (bv. een poort die dichtgaat als je op een
  plaat staat).
- `latch: true` = gaat de poort één keer open, dan **blijft hij open**: ook na herstellen,
  na weggaan en terugkomen, en (via de save) na opslaan en laden.
- Een poort gaat **nooit dicht terwijl de speler erin staat** (of erin/eruit loopt): hij wacht
  tot de speler weg is.
- Een poort kan van een andere poort afhangen (keten); het model rekent door tot alles klopt.

**Herstellen**: de herstelsteen vraagt 'De kamer herstellen?'. Ja = korte fade, kasten en
hendels terug naar het begin, jij terug bij de ingang. Vergrendelde poorten blijven open.
**Weggaan** (via `E` of `X` naar een andere map) en terugkomen = ook herstellen.
**Een gevecht** midden in de puzzel herstelt NIET: na het gevecht staat alles zoals het was.

### Waarom zijn de platen in de testkamer zwaar?

Met lichte platen en een `latch`-poort kun je valsspelen: zet één kast op q, haal de hendel,
duw diezelfde kast naar p en ga zelf op q staan. De grendelpoort gaat dan open en blijft open:
de tweede kast is nergens voor nodig. Met **zware** platen (`"heavy": true`) moeten er echt twee
kasten liggen. De BFS-test bewijst dat de kamer met alleen `kast_b` niet op te lossen is.
Vuistregel: **gebruik `heavy` voor platen die een latch-poort openen**; lichte platen zijn
goed voor poorten die alleen open moeten zijn zolang je erop staat (of een kast).

## 4. Tegels (autotile, binnen.png)

| Plek | Tegel |
|---|---|
| bovenste en onderste rij (rand) | 2 muurtop |
| linker-/rechterrand | 23 / 24 zijmuur; naast een muurband (bv. de rij onder de bovenrand) 3 (of 2 als het daaronder ook muur is), net als in het huis |
| muur binnenin met muur eronder | 2 muurtop |
| muur binnenin met vloer eronder | 3 muurvoorkant |
| `B` | 7 kastonderkant, met 6 (kastbovenkant) in de muur erboven |
| `E`, `X` | 5 deur |
| vloer en alles onder objecten | 0/1 (vast patroon) |

Een poort ligt op een vloertegel; de poort tekent zelf een donkere doorgang eronder (het hek is
doorzichtig tussen de spijlen). Zet een poort bij voorkeur in een opening van de muurvoorkant
(zoals `poort_1`) of in een smalle doorgang tussen twee muren (zoals `poort_2`).

## 5. Het signaalsysteem (voor programmeurs)

`PuzzleLogic` is een `RefCounted` zonder nodes:
- `from_room(room, id, latched_ids)` bouwt het model.
- `try_push(id, dir) -> bool`, `can_push`, `push_block_reason` (waarom niet: "muur", "kast",
  "poort", "hendel", "herstelsteen", "deur", "speler", "buiten de kamer").
- `toggle_lever(id)`, `set_player_tile(tile, doel_tile)`, `update()`, `reset()`.
- `is_solid(tile)` (voor de speler), `gate_open(id)`, `plate_pressed(id)`, `lever_on(id)`,
  `signal_value(id)`, `latched_ids()`, `get_state()` / `set_state()` (JSON-veilig).
- Signaal `changed(ids)`: na elke verandering, met de ids van kasten/platen/hendels/poorten
  die veranderd zijn. `PuzzleRoom` werkt daarmee de nodes bij.

Volgorde bij elke `update()`: platen (kast erop, of speler als niet `heavy`) → `signals[id]`
(platen, hendels) → poorten (herhaald tot niets meer verandert, want poorten kunnen van
poorten afhangen) → `signals[poort-id]` = open.

`PuzzleRoom` geeft de logica elke frame de tile van de speler én de tile waar hij heen loopt.
Duwen: `player.gd` roept `bump(player)` aan op de kast vóór hem → `PuzzleRoom.request_push` →
`logic.try_push` → de kast-node springt meteen naar de nieuwe tile (dus de botsing ook) en
alleen het plaatje glijdt in 0,25 s mee (de looptijd van de speler).

Geluid: `PuzzleRoom` heeft een signaal `puzzle_sound(naam)` met "duw", "duw_mis", "hendel",
"poort_open", "poort_dicht", "herstel". Er hangt nog geen audio aan.

## 6. Art

Alle frames 16x16, horizontale strook, Nearest. Zelfde naam en maat = vervangen zonder code.

| Bestand | Maat | Frames |
|---|---|---|
| `assets/puzzle/hendel.png` | 32x16 | 0 uit, 1 aan |
| `assets/puzzle/drukplaat.png` | 32x16 | 0 omhoog, 1 ingedrukt |
| `assets/puzzle/poort.png` | 64x16 | 0 dicht .. 3 open (doorzichtig tussen de spijlen) |
| `assets/puzzle/herstelsteen.png` | 32x16 | 2 gloei-frames (lus, magenta) |
| `assets/puzzle/kast_duwbaar.png` | 16x32 | 1 frame; onderste helft = de tile, bovenste helft steekt erboven uit |

Ontbreekt `kast_duwbaar.png`, dan gebruikt de kast tegel 6 boven 7 uit `binnen.png`.
Placeholder-generator (alleen als terugval): `python3 tools/art_puzzle_placeholders.py`
(schrijft alleen ontbrekende bestanden; `--force` overschrijft, `--out=map` ergens anders).

## 7. Testen

```
godot --headless --path . -- --puzzletest                 # deel A + B
godot --headless --path . -- --puzzletest --only-logic    # alleen deel A (geen scène)
xvfb-run -a godot --rendering-driver opengl3 --path . -- --puzzletest --shots=/pad/map
```
Met `--shots` komen er screenshots (3x, nearest) in die map. Exit code 0 = alles goed.

Handmatig: start het spel in een debug-build en druk op **F4** (TIJDELIJK) om naar de
testkamer te gaan. De ingang `E` brengt je naar het huis.
