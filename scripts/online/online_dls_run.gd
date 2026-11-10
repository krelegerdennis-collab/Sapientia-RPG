class_name OnlineDlsRun
extends RefCounted
## Staat van één online DLS-run. Niet GameState.dungeon100_floor (die blijft van solo).
## M5 (lobby) roept start() aan en laadt daarna ONLINE_SCENE. M9 opent het baas-slot.

const SCENE := "res://scenes/online/online_dls_room.tscn"

static var active := false
static var mode := "easy"
static var run_seed := 0
static var floor_no := 1
static var exit_reached := false
static var returned_to_hall := false


static func start(p_mode: String, seed: int) -> void:
	active = true
	mode = p_mode
	run_seed = seed
	floor_no = 1
	exit_reached = false
	returned_to_hall = false


static func stop() -> void:
	active = false
	exit_reached = false
	returned_to_hall = false


static func floors_total() -> int:
	return OnlineDlsModes.floors(mode)
