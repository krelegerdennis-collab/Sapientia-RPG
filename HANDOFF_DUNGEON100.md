# HANDOFF DUNGEON100 - de Diepe Grot (generator)

Procedurele dungeon van maximaal **100 verdiepingen**. Elke verdieping wordt gegenereerd uit
`(run-seed, verdiepingsnummer)`: dezelfde invoer geeft altijd dezelfde kaart. De ingang staat op de
wereldkaart (grot-icoon op tegel (9,26), links in het westen) en leidt naar verdieping 1.

> Het oude "100floorcave"-prototype is niet in deze repo (niet in `main`, `wip/v0.19-respawn`,
> `workflow/cursor-agents` of de git-historie gevonden). Dit is dus een eigen ontwerp in de stijl van de
> bestaande dungeonkamers (`docs/DUNGEON_TILES.txt`, `scripts/data/dungeon_rooms.gd`).

## Bestanden

| bestand | wat |
|---|---|
| `scripts/dungeon/dungeon100_generator.gd` | `Dungeon100Generator` (class_name): de generator + API (statisch, geen node) |
| `scripts/dungeon/dungeon100_content.gd` | welke monsters/kisten op de slots komen + `tier_for_floor` (HAAK voor schaal/loot/bazen) |
| `scripts/dungeon/dungeon100_room.gd` | `Dungeon100Room` (extends `DungeonRoom`): kiest de verdieping, trap/ladder |
| `scenes/maps/dungeon100.tscn` | ÉÉN scène voor alle verdiepingen (zelfde scène wordt opnieuw geladen) |
| `scenes/maps/wereldkaart.tscn` | uitgang `Exits/NaarDiepeGrot` (tegel (9,26)) + spawn `Spawns/van_dungeon100` |
| `scripts/data/dungeon_rooms.gd` | 3 regels in `room()`: kamer-id `dungeon100_<seed>_<verdieping>` -> generator |
| `scripts/game_state.gd` | `dungeon100_floor`, `dungeon100_seed` (+ save/load, new_game, reset in `enter_map`) |
| `scripts/tests/dungeon100_generator_tests.gd` | suite `--dungeon100gentest` (57 checks) |

## GameState-contract (stabiel voor alle dungeon100-branches)

```gdscript
GameState.dungeon100_floor: int   # 1..100, 0 = niet in de dungeon
GameState.dungeon100_seed: int    # run-seed van de generator; 0 = nog niet gekozen
```

- Beide staan in de save (`"dungeon100": {"floor", "seed"}`; oude saves zonder dit veld laden als 0/0;
  floor wordt begrensd op 0..100). `new_game()` zet ze op 0.
- De seed wordt de eerste keer dat je de grot binnenkomt gekozen (`randi_range`) en blijft daarna
  vast: elke verdieping ziet er bij een volgend bezoek hetzelfde uit.
- `GameState.enter_map(pad)` zet `dungeon100_floor` op 0 zodra de map NIET `dungeon100.tscn` is
  (verlaten via de ladder, game over, andere map). Binnenkomen met floor 0 = verdieping 1.

## Spelverloop

- Wereldkaart: stap op de grot-ingang -> `dungeon100.tscn`, spawn `omhoog`, verdieping 1.
- Verdieping n: **ladder omhoog** (tegel 44/45 in de bovenmuur van de ingangskamer) en **trap omlaag**
  (tegel 58, in de hoek van de kamer die het verst lopen van de ingang ligt). Trap = verdieping n+1
  (spawn `omhoog` = voor de ladder), ladder = n-1 (spawn `omlaag` = naast de trap). Ladder op
  verdieping 1 = terug naar de wereldkaart (`van_dungeon100`). Verdieping 100 heeft **geen** trap omlaag.
- Geen random encounters; map-monsters zoals in de Archieven (`dungeon_room.gd`). Terrein/gevechts-
  achtergrond = `archief`, thema `archief_grijs` (geen nieuwe art).
- Autosave bij elke verdiepingswissel (bestaande `change_map`-flow); laden brengt je terug op de
  opgeslagen verdieping en tegel.

## API voor siblings: `Dungeon100Generator` (statisch)

```gdscript
const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
var d: Dictionary = Gen.generate(GameState.dungeon100_seed, GameState.dungeon100_floor)
```

Sleutels van `d` (alle coördinaten = tegels, `Vector2i`; `Gen.NO_TILE = (-1,-1)` = niet aanwezig):

| sleutel | betekenis |
|---|---|
| `floor`, `run_seed`, `floor_seed` | invoer + afgeleid zaad (`Gen.floor_seed(run_seed, floor)`) |
| `is_boss_floor` | `floor % 10 == 0` (10, 20 ... 100) |
| `is_milestone` | hetzelfde (`floor % 10 == 0`); bedoeld voor rustpunten/HUD-mijlpalen |
| `tier` | monsterniveau 1-4 (`Dungeon100Content.tier_for_floor`) |
| `size`, `layout`, `rooms` | afmeting (tegels), kamertekens (DungeonRooms-legenda), `Array[Rect2i]` kamers |
| `spawn_up` | waar je aankomt van boven (voor de ladder); `stairs_up` = de ladder-tegel erboven |
| `has_stairs_down`, `stairs_down`, `spawn_down` | trap omlaag + de tegel ernaast waar je van onderen aankomt (verdieping 100: false / NO_TILE) |
| `monster_slots` | `Array[Vector2i]` vrije, bereikbare tegels voor monsters (>= 6 stappen van `spawn_up`) |
| `chest_slots` | kisten in kamerhoeken; sluiten nooit iets af |
| `boss_slot` | alleen op baasverdiepingen: linkerbovenhoek van een **vrij 2x2-gebied** in de trapkamer (past de Golem); die kamer heeft geen gewone monsters en geen obstakels. Anders `NO_TILE` |
| `rest_slot` | vrije tegel in de ingangskamer (op ELKE verdieping), bedoeld voor een rustpunt |
| `room` | kant-en-klare `DungeonRoom`-data (zelfde formaat als `scripts/data/dungeon_rooms.gd`) |

Overig: `Gen.room_id(seed, floor)` / `Gen.parse_room_id(id)` / `Gen.room_for_id(id)`,
`Gen.is_boss_floor(f)`, `Gen.reachable_tiles(room, from)` (BFS op de echte botsing),
constanten `Gen.MAX_FLOOR`, `Gen.SCENE`, `Gen.SPAWN_FROM_ABOVE = "omhoog"`, `Gen.SPAWN_FROM_BELOW = "omlaag"`.
`generate()` is puur en gecached (laatste 8 verdiepingen); willekeur komt NOOIT uit de globale `randi()`.

### Waar siblings inhaken (zonder de generator aan te passen)

1. **Schaal + loot + baas** (`dungeon100-schaal-loot`): pas `scripts/dungeon/dungeon100_content.gd` aan:
   `tier_for_floor(f)`, `enemy_pool(f)`, `monsters(data)`, `chests(data)`, en in `fill_room(room, data)` de
   baas: `if data["is_boss_floor"]: room["monsters"].append({... "boss": true, "tile": [boss_slot.x, boss_slot.y] ...})`.
   `room["tier"]` wordt door `DungeonRoom.tier()` al aan elk gevecht meegegeven.
2. **Rustpunten + HUD** (`dungeon100-regels`): lees `GameState.dungeon100_floor` (HUD "Verdieping X/100").
   Een rustpunt op `floor % 10 == 0`: gebruik `data["rest_slot"]`, bv. in `Content.fill_room`
   `room["save"] = [rest.x, rest.y]` (opslagboek op de sokkel, `"save_type"` uit `book_data.gd`) of een eigen object.
   De scène heeft het signal `Dungeon100Room.floor_ready(floor_no, data)` (komt na het bouwen van de kamer),
   bruikbaar voor een HUD-node: `scene.floor_ready.connect(...)` of lees `scene.floor_no` / `scene.floor_data`.
3. Een verdieping van buitenaf openen (tests/cheats): `GameState.dungeon100_floor = n;
   GameState.change_map(Gen.SCENE, Gen.SPAWN_FROM_ABOVE)`.

## Algoritme (kort)

6-10 kamers (5x4 tot 10x7, minstens 3 tegels uit elkaar), Prim-boom van gangen (1 of 2 breed) + 1-2
lussen, dunne muren dichtgemaakt, ladder in de bovenmuur van de ingangskamer, trap in de verste kamer
(BFS-loopafstand), obstakels (steenhoop/kast/boekenstapel) binnenin kamers, slots, daarna
autotile van de muurtoppen/voorkanten/schaduwen volgens `docs/DUNGEON_TILES.txt`. Per verdieping
worden tot 24 pogingen gedaan (deterministisch); lukt dat niet, dan een vaste noodindeling (nooit nodig in de tests).
Na het bouwen: BFS op de echte tegelbotsing van `spawn_up` naar de trap, anders opnieuw.

## Tests

`godot --path . -- --dungeon100gentest [--shots=/pad/map]` (xvfb, zoals de andere suites; regel toegevoegd
aan `scripts/game_state.gd` en `.github/ci/tests.yml`):
determinisme (opnieuw genereren = identiek), 5 seeds x 100 verdiepingen geldig (tegels, buitenrand dicht,
ladder/trap, exits, ingang -> trap bereikbaar op de echte botsing, alle kamers/slots bereikbaar, baas-slot
alleen op x0), noodindeling, save/load, wereldkaart-ingang, en echte scènes: wereldkaart -> verdieping 1 ->
lopend naar de trap -> 2 -> ladder -> 1 -> wereldkaart -> opnieuw binnen (zelfde kaart) -> 10, 100, laden.

## Nodig van RPG ART (placeholders)

- Ingang op de wereldkaart: hergebruikt het grot-icoon van het Donker Woud (`wereld_v17_iconen.png`, tegel 4,0).
  Eigen icoon voor de Diepe Grot (16x16) gewenst.
- Dungeon-tegels: bestaande `archief_grijs`-set; een eigen thema per 25 verdiepingen is mogelijk via `room["theme"]`
  (nu niet gedaan, tegelnummers 0-64 zijn in alle thema's gelijk).
