class_name Dungeon100Room
extends "res://scripts/dungeon/dungeon_room.gd"
## DUNGEON100: de Diepe Grot. ÉÉN scène (scenes/maps/dungeon100.tscn) voor alle verdiepingen: bij
## het binnenkomen kiest deze node de kamer-id "dungeon100_<seed>_<verdieping>" uit
## GameState.dungeon100_seed + GameState.dungeon100_floor; de kamer wordt dan door
## Dungeon100Generator gegenereerd (via DungeonRooms.room()) en door DungeonRoom getekend.
## Trap omlaag / ladder omhoog = dezelfde scène opnieuw, met een andere verdieping.
##   - Binnenkomen (ECHO zet verdieping 1, of een save): verdieping 1 als die nog 0 is; de seed
##     wordt eenmalig gekozen (en zit in de save). De wereldkaart start deze scène niet meer.
##   - Laden uit een save: verdieping en seed komen uit de save.
##   - HET GESIMULEERDE ARCHIEF: het eerste binnenkomen van een run (GameState.dungeon100_begin_run) zet de
##     party op level 1 zonder uitrusting en bewaart de echte party/tas in een momentopname; de ladder op
##     verdieping 1 (na een bevestiging) geeft de run op en brengt je naar ECHO's Kamer.
##   - Hooks voor andere systemen: signal floor_ready(floor_no, data) zodra de kamer er staat.

const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const WarperC := preload("res://scripts/dungeon/dungeon100_warper.gd")
const GrotKamers := preload("res://scripts/data/grot_kamers.gd")
const KoopmanC := preload("res://scripts/dungeon/dungeon100_koopman.gd")
const ValC := preload("res://scripts/dungeon/dungeon100_val.gd")
const PuzzelC := preload("res://scripts/dungeon/dungeon100_puzzel.gd")
const VAL_TEKST := {"spijker": "Spikes shoot up from the floor!", "rune": "A rune flares beneath your feet!"}

## Verdieping is gebouwd; data = Dungeon100Generator.generate() van deze verdieping.
signal floor_ready(floor_no: int, data: Dictionary)

var floor_no := 1
var floor_data: Dictionary = {}
## Het rustpunt van deze verdieping (alleen op 10, 20, ... 100), anders null.
var rustpunt: Node2D = null


const LEAVE_QUESTION := "Leave the Archive? This run is lost. Blue databanks remain."

## Voor de tests: de laatste keer dat de ladder-vraag gesteld is en wat er gekozen werd (0 = verlaten).
var last_leave_choice := -1


func _ready() -> void:
	GameState.dungeon100_begin_run()
	if GameState.dungeon100_seed == 0:
		GameState.dungeon100_seed = randi_range(1, 0x7FFFFFFF)
	if GameState.dungeon100_floor < 1 or GameState.dungeon100_floor > Gen.MAX_FLOOR:
		GameState.dungeon100_floor = 1
	floor_no = GameState.dungeon100_floor
	GameState.dungeon100_reach_floor(floor_no)
	room_id = Gen.room_id(GameState.dungeon100_seed, floor_no)
	floor_data = Gen.generate(GameState.dungeon100_seed, floor_no)
	var returning: bool = GameState.has_return_point and GameState.return_map == scene_file_path
	var spawns: Dictionary = floor_data["room"]["spawns"]
	if not returning and (GameState.pending_spawn not in [Gen.SPAWN_FROM_ABOVE, Gen.SPAWN_FROM_BELOW, Gen.SPAWN_REST, Gen.SPAWN_WARPER]
			or not spawns.has(GameState.pending_spawn)):
		GameState.pending_spawn = Gen.SPAWN_FROM_ABOVE
	super._ready()
	_place_rustpunt()
	_place_warper()
	_place_grot_kamer()
	_place_puzzel()
	floor_ready.emit(floor_no, floor_data)


## Rustpunt (Dungeon100Rustpunt) op elke 10e verdieping, op de rest_slot van de generator.
func _place_rustpunt() -> void:
	if not room.has("rustpunt"):
		return
	var t: Array = room["rustpunt"]
	rustpunt = Dungeon100Rustpunt.create(Vector2i(int(t[0]), int(t[1])))
	rustpunt.name = "Rustpunt"
	$Objects.add_child(rustpunt)


## Kamersoort van deze verdieping (scripts/data/grot_kamers.gd): "val", "rust", "koopman" of "".
var kamer_soort := ""
var koopman: Node2D
var vallen: Dictionary = {}     # Vector2i -> Dungeon100Val


## Valkamer: vallen op de vloer (stap = trigger). Koopmankamer: kraam + H-5.
## Rustkamer: het rustpunt zelf toont het kampvuur (dungeon100_rustpunt.gd).
func _place_grot_kamer() -> void:
	kamer_soort = GrotKamers.kamer_soort(GameState.dungeon100_seed, floor_no)
	if kamer_soort == GrotKamers.SOORT_KOOPMAN:
		var plek := GrotKamers.koopman_plek(room, floor_data)
		if plek.is_empty():
			return
		var kraam: Node2D = KoopmanC.create(plek["kraam"],
				_koopman_sleutel())
		$Objects.add_child(kraam)
		koopman = kraam.get_node("Koopman")
	elif kamer_soort == GrotKamers.SOORT_VAL:
		for d in GrotKamers.vallen(GameState.dungeon100_seed, room, floor_data):
			var v: Node2D = ValC.create(d)
			$Objects.add_child(v)
			vallen[d["tile"]] = v
		if is_instance_valid(player) and not player.is_connected("stepped", _on_val_stap):
			player.connect("stepped", _on_val_stap)


## Puzzle Room (GrotPuzzels): de puzzel op room["puzzel"]; de blauwe kist staat al in de kamer.
## Bij binnenkomst (na de overgang) één korte hint van ECHO.
var puzzel: Node2D
const PUZZEL_HINT_WACHT := 0.6


func _place_puzzel() -> void:
	if not room.has("puzzel"):
		return
	puzzel = PuzzelC.create(self, room["puzzel"], "%s_puzzel" % room_id)
	add_child(puzzel)
	move_child(puzzel, $Objects.get_index())
	_puzzel_hint()


func _puzzel_hint() -> void:
	await get_tree().create_timer(PUZZEL_HINT_WACHT).timeout
	if not is_instance_valid(puzzel) or not is_inside_tree() or GameState.changing_map or GameState.in_battle:
		return
	if Dialog.is_open:
		await Dialog.finished
	if is_instance_valid(puzzel) and not Dialog.is_open and not GameState.changing_map:
		puzzel.show_hint()


func _koopman_sleutel() -> String:
	return "%d_%d" % [GameState.dungeon100_seed, floor_no]


func _on_val_stap(t: Vector2i) -> void:
	for vt in vallen:
		var vv = vallen[vt]
		if is_instance_valid(vv):
			vv.speler_bij(t)
	var v = vallen.get(t)
	if v == null or not is_instance_valid(v) or v.afgegaan:
		return
	v.trigger()
	Dialog.show_lines([str(VAL_TEKST.get(v.soort, "A trap!")), "The party takes damage."])


## Warper (verdieping 1, 25, 50, 75, 99) op room["warper"], naast de ingang.
func _place_warper() -> void:
	if not room.has("warper"):
		return
	var t: Array = room["warper"]
	var warper := WarperC.create(Vector2i(int(t[0]), int(t[1])))
	warper.name = "Warper"
	$Objects.add_child(warper)


## De Diepe Grot heeft eigen terugkeerregels (rustpunt, zie Dungeon100Rules.defeat_plan): het
## kamer-checkpoint van v0.19 wordt hier niet gezet.
func allows_checkpoint() -> bool:
	return false


## Trap/ladder: eerst de nieuwe verdieping in GameState zetten, dan pas de gewone uitgang
## (fade + dezelfde scène laden). De ladder op verdieping 1 gaat naar ECHO's Kamer: na een bevestiging
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
	last_leave_choice = await Dialog.ask(LEAVE_QUESTION, ["Leave", "Stay"])
	if last_leave_choice == 0:
		GameState.dungeon100_leave()
		super._use_exit(exit)
	else:
		player.input_locked = false


## v0.21: de Diepe Grot heeft een eigen terrein (gevechtsachtergrond cave_deep, RPG ART batch 13).
## De tegels zelf houden het terrein van hun thema; alleen het gevecht kijkt hiernaar.
func terrain_at(tile: Vector2i) -> String:
	return "dungeon100" if super.terrain_at(tile) != "" else ""
