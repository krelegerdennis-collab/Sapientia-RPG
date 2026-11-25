extends Node
## Colosseum scene-flow (--arenaflowtest, lokaal; niet in CI-matrix).

const LOBBY := "res://scenes/arena/arena_lobby.tscn"
const HALL := "res://scenes/arena/arena_hall.tscn"
const Layout := preload("res://scripts/arena/arena_layout.gd")
const Tiles := preload("res://scripts/arena/arena_tiles.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const Entry := preload("res://scripts/arena/arena_entry.gd")
const Rewards := preload("res://scripts/data/arena_rewards.gd")
const WORLD := Entry.WORLD_MAP

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
	ReleaseFlags.arena_enabled_override = 1
	GameState.new_game("Dax")
	GameState.story_flags["noor_lid"] = true
	GameState.change_map(LOBBY, "ingang")
	await _wait_path(LOBBY, 12.0)
	var lobby: Node = get_tree().current_scene
	_check_deco_grid(lobby, "lobby")
	await _merchant_talk(lobby)
	lobby.call("_gate_used")
	await _wait_path(HALL, 12.0)
	var hall: Node = get_tree().current_scene
	_check_deco_grid(hall, "hall")
	await _wave_banner(hall)
	await _wipe_full_revive(hall)
	await _second_run_clears()
	await _results_button_on_screen(get_tree().current_scene as Node)
	await _load_hall_redirects_lobby()
	await _lobby_exit_to_world()
	print("ARENAFLOWTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _check_deco_grid(room: Node, kind: String) -> void:
	var rows: Array = Layout.grid(kind)
	var bad := 0
	for y in rows.size():
		for x in (rows[y] as Array).size():
			var idx := int((rows[y] as Array)[x])
			if Tiles.is_walkable_floor_deco(idx) and room.is_wall(Vector2i(x, y)):
				bad += 1
	check("%s: vloerdecor niet muur" % kind, bad == 0)


func _merchant_talk(lobby: Node) -> void:
	var player: Node = lobby.get_node("Objects/Player")
	player.place_at(Vector2i(5, 8), Vector2i.UP)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player._try_interact()
	await get_tree().process_frame
	var shop := lobby.get_node_or_null("ArenaShopScreen")
	check("merchant A opent shop", shop != null)
	if shop != null:
		shop.call("_close")
		await get_tree().process_frame


func _wave_banner(hall: Node) -> void:
	var hud: Node = hall.get_node_or_null("ArenaHud")
	if hud == null:
		check("wave hud aanwezig", false)
		return
	var panel: Control = hud.find_child("ArenaPanel", true, false) as Control
	var bn: Label = hud.find_child("WaveBanner", true, false) as Label
	check("wave: groot paneel verborgen", panel != null and not panel.visible)
	check("wave: banner zichtbaar", bn != null and bn.visible)
	await get_tree().create_timer(2.6).timeout
	check("wave: banner weer verborgen", bn != null and not bn.visible)


func _wipe_full_revive(hall: Node) -> void:
	var run: Node = GameState.get_node("ArenaRun")
	for h in GameState.party:
		if h is Dictionary:
			h["hp"] = 0
	hall.som._party_down()
	await _frames(15)
	check("wipe: results", str(run.phase) == RunScript.PHASE_RESULTS and run.wiped)
	run.acknowledge()
	await _frames(5)
	check("wipe revive constant 100%", Rewards.ARENA_WIPE_REVIVE_HP_PCT >= 1.0)
	var all_full := true
	var alive := 0
	for h in GameState.party:
		if not (h is Dictionary):
			continue
		var mx := int(h.get("max_hp", 1))
		var hp := int(h.get("hp", 0))
		if hp > 0:
			alive += 1
		if hp != mx:
			all_full = false
	check("wipe: party vol HP", all_full)
	check("wipe: alive_heroes", alive == GameState.party.size())
	check("wipe: lobby-fase", str(run.phase) == RunScript.PHASE_LOBBY)
	GameState.change_map(LOBBY, "ingang")
	await _wait_path(LOBBY, 12.0)
	var lobby_after_wipe: Node = get_tree().current_scene
	lobby_after_wipe.call("_gate_used")
	await _wait_path(HALL, 12.0)


func _second_run_clears() -> void:
	var run: Node = GameState.get_node("ArenaRun")
	var hall: Node = get_tree().current_scene
	await _frames(5)
	var w2: Node = run.waves
	check("run2: som rebound", w2._som == hall.som)
	check("run2: enemy_defeated gebonden", hall.som.enemy_defeated.is_connected(w2._on_enemy_defeated))
	for m in hall.monsters.duplicate():
		if is_instance_valid(m) and hall.som.enemies.has(m):
			hall.som._defeat_enemy(m)
	await _frames(30)
	check("run2: wave cleared -> choice", str(run.phase) == RunScript.PHASE_CHOICE)


func _results_button_on_screen(hall: Node) -> void:
	var run: Node = GameState.get_node("ArenaRun")
	run.level_notes.assign([
		"Dax is now level 2!", "Dax learned Cleave!", "Noor is now level 2!",
		"Noor learned Mend!", "Vesper is now level 2!", "Vesper learned Spark!",
	])
	run.phase = RunScript.PHASE_RESULTS
	run.wiped = false
	var hud: Node = hall.get_node_or_null("ArenaHud")
	if hud == null:
		check("results hud", false)
		return
	hud.call("_refresh", RunScript.PHASE_RESULTS)
	await get_tree().process_frame
	var panel: Control = hud.find_child("ArenaPanel", true, false) as Control
	var vp := hall.get_viewport().get_visible_rect()
	var inside := false
	for b in panel.find_children("*", "Button", true, false):
		var r := (b as Control).get_global_rect()
		if str((b as Button).text).contains("lobby") and vp.encloses(r):
			inside = true
	check("results: lobby-knop in viewport", inside)
	var more := false
	for n in panel.find_children("*", "Label", true, false):
		if str((n as Label).text).begins_with("+") and "more" in str((n as Label).text):
			more = true
	check("results: +N more bij >2 notes", more)


func _lobby_exit_to_world() -> void:
	GameState.change_map(LOBBY, "ingang")
	await _wait_path(LOBBY, 12.0)
	var lobby: Node = get_tree().current_scene
	var exit := lobby.get_node_or_null("Exits/NaarWereld") as MapExit
	check("lobby: NaarWereld exit", exit != null and exit.target_map == WORLD and exit.target_spawn == Entry.RETURN_SPAWN)
	var player: Node = lobby.get_node("Objects/Player")
	player.place_at(Vector2i(11, 13), Vector2i.UP)
	await get_tree().physics_frame
	lobby.call("_on_player_stepped", Vector2i(11, 13))
	await _wait_path(WORLD, 12.0)
	var world: Node = get_tree().current_scene
	var world_player: Node = world.get_node("Objects/Player")
	check("lobby exit: wereldkaart", world.scene_file_path == WORLD)
	check("lobby exit: spawn van_arena", world.get_node_or_null("Spawns/" + Entry.RETURN_SPAWN) != null)
	check("lobby exit: tile", world_player.get_tile() == Entry.RETURN_TILE)
	check("lobby exit: facing weg", world_player.facing == Entry.RETURN_FACING)


func _load_hall_redirects_lobby() -> void:
	var hall: Node = get_tree().current_scene
	var player: Node = hall.get_node("Objects/Player")
	var path := "user://arenaflowtest_hall_save.json"
	check("save in hal", GameState.save_game(player.get_tile(), player.facing, path))
	var raw: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(raw)
	var rec: Dictionary = {"path": path, "data": data, "slot": 1}
	check("continue uit hall-save", rec["data"] is Dictionary and await GameState._continue_record(rec))
	await _wait_path(LOBBY, 12.0)
	check("load hall-save landt in lobby", get_tree().current_scene.scene_file_path == LOBBY)


func _wait_path(path: String, timeout: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := get_tree().current_scene
		if s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map:
			break
		await get_tree().process_frame
	if Transition._rect != null:
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 3000.0 and Transition.overlay_alpha() > 0.01:
			await get_tree().process_frame
	await get_tree().process_frame


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
