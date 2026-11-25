extends Node
class_name ArenaAbandonTest
## Colosseum abandon: hal verlaten midden in wave, lobby reset, poort opnieuw (--arenaabandontest).

const LOBBY := "res://scenes/arena/arena_lobby.tscn"
const HALL := "res://scenes/arena/arena_hall.tscn"
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const Host := preload("res://scripts/arena/arena_host.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_all.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> Node:
	return GameState.get_node_or_null("ArenaRun")


func _wait_path(path: String, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		var sc := get_tree().current_scene
		if sc != null and sc.scene_file_path == path and not GameState.changing_map and sc.is_node_ready():
			await _frames(5)
			return true
		await get_tree().process_frame
	return false


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _wait_spawn(n: int) -> bool:
	var run := _run()
	if run == null:
		return false
	for _i in 120:
		if run.waves.active_wave == n:
			var hall: Node = get_tree().current_scene
			if hall != null and "monsters" in hall and hall.monsters.size() > 0:
				return true
		await get_tree().process_frame
	return false


func _enter_gate() -> bool:
	var lobby: Node = get_tree().current_scene
	if lobby == null or lobby.scene_file_path != LOBBY:
		return false
	lobby.call("_gate_used")
	return await _wait_path(HALL, 12.0)


func _run_all() -> void:
	ReleaseFlags.arena_enabled_override = 1
	GameState.new_game("Dax")
	GameState.story_flags["noor_lid"] = true
	GameState.story_flags["run_uitleg_gezien"] = true
	GameState.change_map(LOBBY, "ingang")
	check("lobby laadt", await _wait_path(LOBBY, 15.0))

	# Midden in wave naar lobby: _drop_stale_run -> abandon.
	check("gate naar hal", await _enter_gate())
	await _wait_spawn(1)
	var run := _run()
	check("wave 1 actief", run != null and run.phase == RunScript.PHASE_WAVE and run.wave == 1)
	GameState.change_map(LOBBY, "ingang")
	check("terug in lobby", await _wait_path(LOBBY, 12.0))
	await _frames(15)
	run = _run()
	check("abandon: phase lobby", run != null and run.phase == RunScript.PHASE_LOBBY)
	check("abandon: waves geabort (active_wave=0)", run != null and int(run.waves.active_wave) == 0)
	check("abandon: wave counter reset", run != null and run.wave == 0)

	check("poort opent opnieuw na abandon", await _enter_gate())
	await _wait_spawn(1)
	run = _run()
	check("nieuwe run start via poort", run.phase == RunScript.PHASE_WAVE and run.wave == 1)

	# Hal opnieuw laden midden in wave: rebind + golf cleart op nieuwe som.
	var wave_n := int(run.wave)
	GameState.change_map(HALL, "ingang")
	check("hal herladen mid-wave", await _wait_path(HALL, 12.0))
	await _frames(30)
	run = _run()
	check("run nog in dezelfde golf", run.phase == RunScript.PHASE_WAVE and run.wave == wave_n)
	check("golf respawnt na rebind", await _wait_spawn(wave_n))
	var hall: Node = get_tree().current_scene
	var choice_ok := false
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		run = _run()
		if run != null and run.phase == RunScript.PHASE_CHOICE:
			choice_ok = true
			break
		if hall != null and hall.som != null and "monsters" in hall:
			for m in hall.monsters.duplicate():
				if is_instance_valid(m) and hall.som.enemies.has(m):
					hall.som.damage_enemy(m, 9999, Vector2i.DOWN)
		await _frames(5)
	check("rebind: wave cleared -> choice", choice_ok)

	# Harness-pad: mid-wave mapwissel naar lobby, dan begin() + hal (wipe detectie).
	if _run().phase != RunScript.PHASE_LOBBY:
		GameState.change_map(LOBBY, "ingang")
		await _wait_path(LOBBY, 12.0)
		await _frames(10)
	if _run() == null or _run().phase == RunScript.PHASE_LOBBY:
		check("STALE gate naar hal", await _enter_gate())
		await _wait_spawn(1)
	GameState.change_map(LOBBY, "ingang")
	check("STALE lobby na mid-wave mapwissel", await _wait_path(LOBBY, 12.0))
	run = _run()
	check("STALE abandon in lobby", run != null and run.phase == RunScript.PHASE_LOBBY)
	Host.ensure().begin()
	GameState.change_map(HALL, "ingang")
	check("STALE hal na begin", await _wait_path(HALL, 12.0))
	await _frames(30)
	hall = get_tree().current_scene
	run = _run()
	check("STALE begin+hal -> wave", run.phase == RunScript.PHASE_WAVE)
	for h in GameState.party:
		h["hp"] = 0
	if hall != null and hall.som != null:
		hall.som._party_down()
	await _frames(15)
	var run_end := _run()
	check("STALE wipe gedetecteerd", run_end != null and run_end.phase == RunScript.PHASE_RESULTS and run_end.wiped)

	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)