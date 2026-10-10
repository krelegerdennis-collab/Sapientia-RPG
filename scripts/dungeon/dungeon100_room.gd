class_name Dungeon100Room
extends "res://scripts/dungeon/dungeon_room.gd"
## DUNGEON100: de Diepe Grot. ÉÉN scène (scenes/maps/dungeon100.tscn) voor alle verdiepingen: bij
## het binnenkomen kiest deze node de kamer-id "dungeon100_<seed>_<verdieping>" uit
## GameState.dungeon100_seed + GameState.dungeon100_floor; de kamer wordt dan door
## Dungeon100Generator gegenereerd (via DungeonRooms.room()) en door DungeonRoom getekend.
## Trap omlaag / ladder omhoog = dezelfde scène opnieuw, met een andere verdieping.
##   - Binnenkomen vanaf de wereldkaart (verdieping 0): verdieping 1; de seed wordt eenmalig
##     gekozen (en zit in de save), dus elke verdieping ziet er bij een volgend bezoek hetzelfde uit.
##   - Laden uit een save: verdieping en seed komen uit de save.
##   - Hooks voor andere systemen: signal floor_ready(floor_no, data) zodra de kamer er staat.

const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")

## Verdieping is gebouwd; data = Dungeon100Generator.generate() van deze verdieping.
signal floor_ready(floor_no: int, data: Dictionary)

var floor_no := 1
var floor_data: Dictionary = {}


func _ready() -> void:
	if GameState.dungeon100_seed == 0:
		GameState.dungeon100_seed = randi_range(1, 0x7FFFFFFF)
	if GameState.dungeon100_floor < 1 or GameState.dungeon100_floor > Gen.MAX_FLOOR:
		GameState.dungeon100_floor = 1
	floor_no = GameState.dungeon100_floor
	room_id = Gen.room_id(GameState.dungeon100_seed, floor_no)
	floor_data = Gen.generate(GameState.dungeon100_seed, floor_no)
	var returning: bool = GameState.has_return_point and GameState.return_map == scene_file_path
	if not returning and GameState.pending_spawn not in [Gen.SPAWN_FROM_ABOVE, Gen.SPAWN_FROM_BELOW]:
		GameState.pending_spawn = Gen.SPAWN_FROM_ABOVE
	super._ready()
	floor_ready.emit(floor_no, floor_data)


## Trap/ladder: eerst de nieuwe verdieping in GameState zetten, dan pas de gewone uitgang
## (fade + dezelfde scène laden). De ladder op verdieping 1 gaat naar de wereldkaart.
func _use_exit(exit: Node) -> void:
	if exit.target_map == Gen.SCENE:
		var next := floor_no + (1 if exit.name == "Uitgang_v" else -1)
		GameState.dungeon100_floor = clampi(next, 1, Gen.MAX_FLOOR)
	super._use_exit(exit)
