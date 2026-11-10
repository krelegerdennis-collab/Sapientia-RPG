class_name OnlineDlsRoom
extends DungeonRoom
## Online DLS in Action. Solo-DLS (scenes/maps/dungeon100.tscn) komt hier niet langs.
## Schrijft GameState.dungeon100_floor niet. Koopman, puzzel en blauwe kist worden niet geplaatst.
## Het baas-slot blijft leeg (M9). De uitgang na dat slot zet exit_reached.

const Floor := preload("res://scripts/online/online_dls_floor.gd")
const Run := preload("res://scripts/online/online_dls_run.gd")
const Rust := preload("res://scripts/dungeon/dungeon100_rustpunt.gd")

var online_dls := false
var floor_data: Dictionary = {}
var mode_floor := 1


func _online_room_injected() -> bool:
	return online_dls and not room.is_empty()


func wants_som() -> bool:
	return online_dls


func _setup_som() -> void:
	som = SomArenaScript.new()
	som.coop_mode = true
	add_child(som)
	som.setup(self)


func _ready() -> void:
	if not Run.active:
		push_error("Online DLS zonder OnlineDlsRun.start")
		return
	if GameState.dungeon100_run_active():
		push_error("Online DLS weigert een actieve solo-run")
		return
	var snap := _solo_snap()
	online_dls = true
	sets_checkpoint = false
	encounters = false
	mode_floor = Run.floor_no
	floor_data = Floor.build(Run.mode, Run.run_seed, mode_floor)
	room = floor_data.get("room", {})
	room_id = "online_dls_%s_%d_%d" % [Run.mode, Run.run_seed, mode_floor]
	map_name = str(room.get("name", "Verdieping"))
	super._ready()
	_restore_solo(snap)
	_place_online_rest()


## Zelfde prop als solo (Dungeon100Rustpunt). interact() slaat online af zolang de run loopt.
func _place_online_rest() -> void:
	if not room.has("rustpunt"):
		return
	var objects := get_node_or_null("Objects")
	if objects == null or objects.get_node_or_null("Rustpunt") != null:
		return
	var t: Array = room["rustpunt"]
	var rp: Node2D = Rust.create(Vector2i(int(t[0]), int(t[1])))
	rp.name = "Rustpunt"
	objects.add_child(rp)


func _use_exit(exit: Node) -> void:
	var spawn := str(exit.target_spawn)
	if spawn == "uitgang":
		Run.exit_reached = true
		return
	if spawn == "hal":
		Run.returned_to_hall = true
		return
	if str(exit.target_map) == Floor.ONLINE_SCENE:
		if spawn == "omhoog":
			Run.floor_no = mini(Run.floor_no + 1, Run.floors_total())
		elif spawn == "omlaag":
			Run.floor_no = maxi(Run.floor_no - 1, 1)
	super._use_exit(exit)


func _solo_snap() -> Dictionary:
	return {
		"floor": GameState.dungeon100_floor,
		"map": GameState.current_map,
		"bezocht": GameState.bezochte_kaarten.duplicate(),
		"checkpoint": GameState.checkpoint.duplicate(true),
		"entry": GameState.entry_kind,
		"scheduled": Story.scheduled.duplicate(true),
	}


func _restore_solo(snap: Dictionary) -> void:
	GameState.dungeon100_floor = int(snap["floor"])
	GameState.current_map = str(snap["map"])
	GameState.bezochte_kaarten.clear()
	for pad in snap["bezocht"]:
		GameState.bezochte_kaarten.append(str(pad))
	GameState.checkpoint = snap["checkpoint"]
	GameState.entry_kind = str(snap["entry"])
	Story.scheduled = snap["scheduled"]
