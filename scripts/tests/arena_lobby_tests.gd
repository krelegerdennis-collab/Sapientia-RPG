extends Node
## Colosseum lobby: export-pad + ingang wereldkaart (--arenalobbytest).
## Start: godot --path . -- --arenalobbytest

const Layout := preload("res://scripts/arena/arena_layout.gd")
const Entry := preload("res://scripts/arena/arena_entry.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const LOBBY := "res://scenes/arena/arena_lobby.tscn"

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
	_export_path()
	await _warp_world_to_lobby(false)
	await _warp_world_to_lobby(true)
	await _save_in_lobby()
	print("ARENALOBBYTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _export_path() -> void:
	check("layouts.json onder data/ (niet docs/)", Layout.PATH.begins_with("res://data/"))
	check("layouts.json bestaat", FileAccess.file_exists(Layout.PATH))
	var grid: Array = Layout.grid("lobby")
	check("lobby-grid 24x14", grid.size() == 14 and grid[0].size() == 24)
	var hall: Array = Layout.grid("hall")
	check("hal-grid 30x20", hall.size() == 20 and hall[0].size() == 30)


func _warp_world_to_lobby(noor_lid: bool) -> void:
	ReleaseFlags.arena_enabled_override = 1
	GameState.new_game("Dax")
	GameState.story_flags.erase("noor_lid")
	if noor_lid:
		GameState.story_flags["noor_lid"] = true
	get_tree().change_scene_to_packed(load(WORLD) as PackedScene)
	await _wait_path(WORLD, 12.0)
	var world: Node = get_tree().current_scene
	var exit: MapExit = world.get_node_or_null("Exits/NaarArena") as MapExit
	check("wereldkaart: NaarArena aanwezig", exit != null)
	if exit == null:
		return
	check("uitgang naar lobby", exit.target_map == LOBBY and exit.target_spawn == "ingang")
	check("change_map start", GameState.change_map(LOBBY, "ingang"))
	await _wait_path(LOBBY, 12.0)
	var lobby: Node = get_tree().current_scene
	var lg: TileMapLayer = lobby.get_node_or_null("Ground") as TileMapLayer
	check("lobby: tegels geschilderd", lg != null and lg.get_used_rect().size == Vector2i(24, 14))
	var player: CharacterBody2D = lobby.get_node_or_null("Objects/Player") as CharacterBody2D
	var spawn := Vector2i(11, 10)
	check("lobby: speler vrij", player != null and not player.input_locked and not GameState.changing_map)
	check("lobby: veld vrij", GameState.field_free())
	if player != null and lobby.has_method("is_wall"):
		check("lobby: spawn loopbaar", not lobby.is_wall(spawn))
		check("lobby: stap naar noord kan", not lobby.is_wall(spawn + Vector2i.UP))


func _save_in_lobby() -> void:
	ReleaseFlags.arena_enabled_override = 1
	GameState.new_game("Dax")
	get_tree().change_scene_to_packed(load(LOBBY) as PackedScene)
	await _wait_path(LOBBY, 10.0)
	var lobby: Node = get_tree().current_scene
	var player: CharacterBody2D = lobby.get_node("Objects/Player") as CharacterBody2D
	var tile: Vector2i = player.get_tile()
	var path := "user://arenalobbytest_save.json"
	check("automatische save in lobby", GameState.save_game(tile, player.facing, path))
	GameState.new_game("Dax")
	check("save laden", GameState.load_game(path))
	check("save in lobby", GameState.return_map == LOBBY)
	check("opnieuw de lobby laden", GameState.change_map(LOBBY, "ingang"))
	await _wait_path(LOBBY, 10.0)
	player = get_tree().current_scene.get_node("Objects/Player") as CharacterBody2D
	check("doorgaan lobby: tegels", get_tree().current_scene.get_node("Ground").get_used_rect().size == Vector2i(24, 14))
	check("doorgaan lobby: vrij", player != null and not player.input_locked and GameState.field_free())


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