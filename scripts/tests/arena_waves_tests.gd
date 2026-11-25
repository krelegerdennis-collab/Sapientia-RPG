extends Node
## SomArenaWaves (--arenawavestest). Suite in .github/workflows/tests.yml (CI, akkoord Dennis).

const WavesScript := preload("res://scripts/arena/som_arena_waves.gd")
const WavesData := preload("res://scripts/data/arena_waves_data.gd")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const HALL := "res://scenes/arena/arena_hall.tscn"
const MapMonsterScript := preload("res://scripts/dungeon/map_monster.gd")
const MockRoom := preload("res://scripts/tests/perfect_dodge_mock_room.gd")

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


func _run_all() -> void:
	_interface()
	await _stub_flow()
	await _spawn_rules()
	await _waves_3_5_som_tick()
	await _determinism()
	await _spawn_timeout_no_hall()
	await _wave_cleared_flow()
	await _party_wiped_flow()
	await _arena_mode_guard()
	_arena_kill_loot_off()
	_flag_off()
	print("ARENAWAVESTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _interface() -> void:
	var w := WavesScript.new()
	check("SomArenaWaves class", w.get_class() == "SomArenaWaves" or w is SomArenaWaves)
	check("signal wave_started", w.has_signal("wave_started"))
	check("signal wave_cleared", w.has_signal("wave_cleared"))
	check("signal party_wiped", w.has_signal("party_wiped"))
	check("var active_wave", "active_wave" in w)
	check("methode start_wave", w.has_method("start_wave"))
	check("geen member_down", not w.has_signal("member_down"))


func _stub_flow() -> void:
	var run := RunScript.new()
	run.name = "TestRun"
	add_child(run)
	run.run_seed = 42
	run.phase = RunScript.PHASE_WAVE
	run.wave = 1
	run.waves.start_wave(1)
	check("arena_run met echte waves: wave 1", run.phase == RunScript.PHASE_WAVE and run.wave == 1 and run.waves.active_wave == 1)
	var waves: Node = run.get_node("Waves")
	check("Waves-node bestaat", waves != null and waves.has_method("start_wave"))
	run.queue_free()
	await _await_frames(5)


func _mock_hall() -> Node:
	var hall: Node = (load(HALL) as PackedScene).instantiate()
	hall.name = "TestHall"
	add_child(hall)
	return hall


func _hall_spawn_tile(hall: Node) -> Vector2i:
	return SomArenaWaves._spawn_tile(hall)


func _await_frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _spawn_rules() -> void:
	await _await_frames(3)
	ReleaseFlags.arena_enabled_override = 1
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.new_game("Dax")
	var hall := _mock_hall()
	await _await_frames(3)
	var spawn_tile := _hall_spawn_tile(hall)
	var run := RunScript.new()
	run.name = "SpawnRun"
	run.run_seed = 9001
	add_child(run)
	var waves: SomArenaWaves = run.get_node("Waves") as SomArenaWaves
	for n in range(1, 6):
		waves.start_wave(n)
		await _await_frames(8)
		var want := WavesData.enemy_count(n)
		check("wave %d: aantal monsters" % n, hall.monsters.size() == want)
		var pool := WavesData.pool_for_wave(n)
		for m in hall.monsters:
			check("wave %d: id in pool (%s)" % [n, m.enemy_id], pool.has(m.enemy_id))
			var t: Vector2i = m.tile
			check("wave %d: geen muur" % n, not hall.is_wall(t))
			var gate_ok := true
			for gt in hall.gate_tiles():
				if t == gt:
					gate_ok = false
			check("wave %d: geen gate-tegel" % n, gate_ok)
			check(
				"wave %d: min %d tegels van spawn" % [n, WavesData.MIN_TILE_DIST_FROM_SPAWN],
				SomArenaWaves._tile_dist(t, spawn_tile) >= WavesData.MIN_TILE_DIST_FROM_SPAWN
			)
		for m in hall.monsters:
			m.queue_free()
		hall.monsters.clear()
	run.queue_free()
	hall.queue_free()
	ReleaseFlags.arena_enabled_override = -1


## Golven 3–5: langere tick zodat SomArena._step_toward loopt (vroeger SCRIPT ERROR zonder monster_can_enter).
func _waves_3_5_som_tick() -> void:
	await _await_frames(3)
	ReleaseFlags.arena_enabled_override = 1
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.new_game("Dax")
	var hall := _mock_hall()
	await _await_frames(3)
	var run := RunScript.new()
	run.name = "SomTickRun"
	run.run_seed = 4242
	add_child(run)
	var waves: SomArenaWaves = run.get_node("Waves") as SomArenaWaves
	for n in [3, 4, 5]:
		waves.start_wave(n)
		await _await_frames(40)
		check("wave %d: monster_can_enter aanwezig" % n, hall.has_method("monster_can_enter"))
		var step_ok := true
		for m in hall.monsters:
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var r: String = hall.monster_can_enter(m, m.tile + d)
				if r not in ["free", "player", "blocked", "wall"]:
					step_ok = false
			if hall.som != null:
				hall.som._step_toward(m, hall.player.position + Vector2(8, 8))
		check("wave %d: som-stappen zonder scriptfout" % n, step_ok)
		for m in hall.monsters:
			m.queue_free()
		hall.monsters.clear()
	run.queue_free()
	hall.queue_free()
	ReleaseFlags.arena_enabled_override = -1


func _determinism() -> void:
	var hall := _mock_hall()
	await _await_frames(3)
	var snap_a := await _wave_spawn_snapshot(hall, 111, 2)
	var snap_b := await _wave_spawn_snapshot(hall, 111, 2)
	var snap_c := await _wave_spawn_snapshot(hall, 222, 2)
	hall.queue_free()
	check("zelfde seed:zelfde spawn", snap_a == snap_b)
	check("andere seed:anders", snap_a != snap_c)


func _wave_spawn_snapshot(hall: Node, run_seed: int, wave_n: int) -> Array:
	for m in hall.monsters:
		if is_instance_valid(m):
			m.queue_free()
	hall.monsters.clear()
	var run := RunScript.new()
	run.run_seed = run_seed
	add_child(run)
	var waves: SomArenaWaves = run.get_node("Waves") as SomArenaWaves
	waves._spawn_wave(hall, wave_n)
	var snap: Array = []
	for m in hall.monsters:
		snap.append({"enemy": m.enemy_id, "tile": m.tile})
	run.queue_free()
	await _await_frames(1)
	return snap


func _spawn_timeout_no_hall() -> void:
	for node in get_tree().get_nodes_in_group("arena_hall"):
		if is_instance_valid(node):
			node.queue_free()
	await _await_frames(15)
	var run := RunScript.new()
	run.run_seed = 5050
	add_child(run)
	var waves: SomArenaWaves = run.get_node("Waves") as SomArenaWaves
	var cleared: Array[int] = []
	waves.wave_cleared.connect(func(n: int) -> void: cleared.append(n))
	waves.start_wave(2)
	await _await_frames(WavesData.HALL_FIND_MAX_FRAMES + 8)
	check("timeout zonder hal: wave_cleared precies 1x", cleared.size() == 1 and cleared[0] == 2)
	run.queue_free()


func _wave_cleared_flow() -> void:
	GameState.new_game("Dax")
	ReleaseFlags.arena_enabled_override = 1
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var hall := _mock_hall()
	await _await_frames(3)
	var run := RunScript.new()
	run.run_seed = 77
	add_child(run)
	var waves: SomArenaWaves = run.get_node("Waves")
	var cleared: Array[int] = []
	waves.wave_cleared.connect(func(n: int) -> void: cleared.append(n))
	waves.start_wave(1)
	await _await_frames(10)
	check("wave_cleared: spawn aanwezig", hall.monsters.size() > 0)
	check("wave_cleared: niet voor tijd", cleared.is_empty())
	var ms: Array = hall.monsters.duplicate()
	for i in ms.size():
		if i < ms.size() - 1 and hall.som != null:
			hall.som.enemy_defeated.emit(ms[i], 0, 0, [])
			await _await_frames(1)
	check("wave_cleared: nog niet na deel", cleared.is_empty())
	if hall.som != null and ms.size() > 0:
		hall.som.enemy_defeated.emit(ms[ms.size() - 1], 0, 0, [])
	await _await_frames(2)
	check("wave_cleared: precies 1x", cleared.size() == 1 and cleared[0] == 1)
	if hall.som != null and ms.size() > 0:
		hall.som.enemy_defeated.emit(ms[ms.size() - 1], 0, 0, [])
	await _await_frames(2)
	check("wave_cleared: geen dubbel", cleared.size() == 1)
	run.queue_free()
	hall.queue_free()
	ReleaseFlags.arena_enabled_override = -1


func _party_wiped_flow() -> void:
	GameState.new_game("Dax")
	GameState.add_member("noor")
	var run := RunScript.new()
	add_child(run)
	var waves: SomArenaWaves = run.get_node("Waves")
	var wiped: Array[int] = []
	waves.party_wiped.connect(func() -> void: wiped.append(1))
	waves.start_wave(1)
	waves.active_wave = 1
	GameState.party[0]["hp"] = 0
	check("party_wiped: één neer geen signaal", wiped.is_empty())
	GameState.party[1]["hp"] = 0
	waves._on_player_defeated()
	check("party_wiped: heel team 1x", wiped.size() == 1)
	waves._on_player_defeated()
	check("party_wiped: geen dubbel", wiped.size() == 1)
	run.queue_free()


func _arena_mode_guard() -> void:
	GameState.new_game("Dax")
	ReleaseFlags.arena_enabled_override = 1
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var hall := _mock_hall()
	await _await_frames(3)
	var som: Node = hall.som
	check("arena_mode: som in hal", som != null)
	if som == null:
		hall.queue_free()
		ReleaseFlags.arena_enabled_override = -1
		return
	var fresh := SomArena.new()
	check("arena_mode: default uit", not fresh.arena_mode)
	fresh.free()
	som.arena_mode = true
	for h in GameState.party:
		h["hp"] = 0
	var before_lose := GameState.last_battle_result == "lose"
	som._party_down()
	await _await_frames(5)
	check("arena_mode: geen end_battle lose", GameState.last_battle_result != "lose" or not before_lose)
	hall.queue_free()
	ReleaseFlags.arena_enabled_override = -1


func _arena_kill_loot_off() -> void:
	GameState.new_game("Dax")
	var gold0 := GameState.gold
	var exp0 := int(GameState.party[0]["exp"])
	var inv0 := GameState.item_count("drankje")
	var som: SomArena = SomArena.new()
	som.arena_mode = true
	var room := MockRoom.new()
	room.room_id = "arena_kill_loot_test"
	room.monsters = []
	som.room = room
	add_child(som)
	var m: MapMonster = MapMonsterScript.new()
	m.enemy_id = "mosslijm"
	m.monster_id = "9001"
	som.enemies[m] = {
		"hp": 0,
		"max_hp": 13,
		"exp": 40,
		"gold": 77,
		"drops": [{"item": "drankje", "chance": 1.0}],
		"data": {},
	}
	som._defeat_enemy(m)
	check("arena_mode: geen kill-goud", GameState.gold == gold0)
	check("arena_mode: geen kill-xp", int(GameState.party[0]["exp"]) == exp0)
	check("arena_mode: geen kill-drops", GameState.item_count("drankje") == inv0)
	som.queue_free()
	m.queue_free()
	room.queue_free()


func _flag_off() -> void:
	ReleaseFlags.arena_enabled_override = -1
	check("ARENA_ENABLED true", ReleaseFlags.ARENA_ENABLED == true)
	check("uplink 15960", Protocol.host_uplink_bytes_per_sec() == 15960)
	var run := RunScript.new()
	add_child(run)
	check("vlag uit: Waves-node alleen onder run", run.get_node_or_null("Waves") != null)
	run.queue_free()