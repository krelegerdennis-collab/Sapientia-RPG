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
##   - HET GESIMULEERDE ARCHIEF: het eerste binnenkomen van een run (GameState.dungeon100_begin_run) zet de
##     party op level 1 zonder uitrusting en bewaart de echte party/tas in een momentopname; de ladder op
##     verdieping 1 (na een bevestiging) geeft de run op en brengt je naar de wereldkaart.
##   - Hooks voor andere systemen: signal floor_ready(floor_no, data) zodra de kamer er staat.

const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")

## Verdieping is gebouwd; data = Dungeon100Generator.generate() van deze verdieping.
signal floor_ready(floor_no: int, data: Dictionary)

var floor_no := 1
var floor_data: Dictionary = {}
## Het rustpunt van deze verdieping (alleen op 10, 20, ... 100), anders null.
var rustpunt: Node2D = null


const LEAVE_QUESTION := "Het Archief verlaten? Deze run gaat verloren. Blauwe databanken blijven."

## Voor de tests: de laatste keer dat de ladder-vraag gesteld is en wat er gekozen werd (0 = verlaten).
var last_leave_choice := -1


func _ready() -> void:
	GameState.dungeon100_begin_run()
	if GameState.dungeon100_seed == 0:
		GameState.dungeon100_seed = randi_range(1, 0x7FFFFFFF)
	if GameState.dungeon100_floor < 1 or GameState.dungeon100_floor > Gen.MAX_FLOOR:
		GameState.dungeon100_floor = 1
	floor_no = GameState.dungeon100_floor
	room_id = Gen.room_id(GameState.dungeon100_seed, floor_no)
	floor_data = Gen.generate(GameState.dungeon100_seed, floor_no)
	var returning: bool = GameState.has_return_point and GameState.return_map == scene_file_path
	var spawns: Dictionary = floor_data["room"]["spawns"]
	if not returning and (GameState.pending_spawn not in [Gen.SPAWN_FROM_ABOVE, Gen.SPAWN_FROM_BELOW, Gen.SPAWN_REST]
			or not spawns.has(GameState.pending_spawn)):
		GameState.pending_spawn = Gen.SPAWN_FROM_ABOVE
	super._ready()
	_place_rustpunt()
	floor_ready.emit(floor_no, floor_data)


## Rustpunt (Dungeon100Rustpunt) op elke 10e verdieping, op de rest_slot van de generator.
func _place_rustpunt() -> void:
	if not room.has("rustpunt"):
		return
	var t: Array = room["rustpunt"]
	rustpunt = Dungeon100Rustpunt.create(Vector2i(int(t[0]), int(t[1])))
	rustpunt.name = "Rustpunt"
	$Objects.add_child(rustpunt)


## De Diepe Grot heeft eigen terugkeerregels (rustpunt, zie Dungeon100Rules.defeat_plan): het
## kamer-checkpoint van v0.19 wordt hier niet gezet.
func allows_checkpoint() -> bool:
	return false


## Trap/ladder: eerst de nieuwe verdieping in GameState zetten, dan pas de gewone uitgang
## (fade + dezelfde scène laden). De ladder op verdieping 1 gaat naar de wereldkaart: na een bevestiging
## is de run opgegeven (de echte party/tas komen terug, GameState.dungeon100_leave).
func _use_exit(exit: Node) -> void:
	if exit.target_map == Gen.SCENE:
		var next := floor_no + (1 if exit.name == "Uitgang_v" else -1)
		GameState.dungeon100_floor = clampi(next, 1, Gen.MAX_FLOOR)
		super._use_exit(exit)
		return
	_confirm_leave(exit)


func _confirm_leave(exit: Node) -> void:
	if Dialog.is_open or GameState.changing_map:
		return
	player.input_locked = true
	last_leave_choice = await Dialog.ask(LEAVE_QUESTION, ["Verlaten", "Blijven"])
	if last_leave_choice == 0:
		GameState.dungeon100_leave()
		super._use_exit(exit)
	else:
		player.input_locked = false
