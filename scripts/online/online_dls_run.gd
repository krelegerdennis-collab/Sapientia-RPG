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
## Geslaagde revives per stoel in deze klim. Overleeft een nieuwe verdieping (nieuwe arena).
## begin_run op de arena wist dit niet; alleen start/stop van de run.
static var revive_used: Array = [0, 0, 0, 0]


static func start(p_mode: String, seed: int) -> void:
	active = true
	mode = p_mode
	run_seed = seed
	floor_no = 1
	exit_reached = false
	returned_to_hall = false
	clear_revives()


static func stop() -> void:
	active = false
	exit_reached = false
	returned_to_hall = false
	clear_revives()


static func clear_revives() -> void:
	revive_used = [0, 0, 0, 0]


static func note_revive(slot: int, n: int) -> void:
	if slot < 0 or slot > 3:
		return
	revive_used[slot] = maxi(0, n)


static func revive_of(slot: int) -> int:
	if slot < 0 or slot > 3:
		return 0
	return int(revive_used[slot])


static func floors_total() -> int:
	return OnlineDlsModes.floors(mode)
