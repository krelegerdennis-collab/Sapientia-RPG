extends Node
## F6-6: change_map blijft niet op zwart hangen als het doelpad ontbreekt (--f6uxtest).
## F6-6b: een deur zet input pas vast als change_map echt start.
## Start: godot --path . -- --f6uxtest

const TOWN := "res://scenes/maps/wilgendal.tscn"
const MISSING := "res://scenes/maps/f66_bestaat_niet.tscn"
const DOOR_SCENE := preload("res://scenes/door.tscn")
const SD := preload("res://scripts/data/story_data.gd")
## Eén tegelstap is 16 px bij 64 px/s (~15 frames op 60 Hz). Ruim erboven, wel begrensd.
const STAP_FRAMES := 90
const WISSEL_FRAMES := 900

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	await _wacht(func() -> bool: return Transition.overlay_alpha() == 0.0, 2.0)
	GameState.encounter_multiplier = 0.0
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.in_battle = false
	GameState.changing_map = false
	await _missing_path()
	await _valid_path()
	await _exit_missing()
	await _door_missing()
	await _door_valid()
	print("F6UXTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


## (1) Ontbrekend pad: false, geen wissel, overlay weer vrij.
func _missing_path() -> void:
	var scene_voor: Node = get_tree().current_scene
	var pad_voor := ""
	if scene_voor != null:
		pad_voor = str(scene_voor.scene_file_path)
	var current_voor := GameState.current_map
	var gestart: bool = GameState.change_map(MISSING, "start")
	check("ontbrekend pad: change_map geeft false", gestart == false)
	check("ontbrekend pad: changing_map blijft false", not GameState.changing_map)
	check("ontbrekend pad: current_map ongewijzigd", GameState.current_map == current_voor)
	await _frames(3)
	var scene_na: Node = get_tree().current_scene
	var pad_na := ""
	if scene_na != null:
		pad_na = str(scene_na.scene_file_path)
	check("ontbrekend pad: scène ongewijzigd", scene_na == scene_voor and pad_na == pad_voor)
	check("ontbrekend pad: overlay alpha 0", Transition.overlay_alpha() == 0.0)
	check("ontbrekend pad: changing_map na frames nog false", not GameState.changing_map)


## (2) Bestaand pad: wissel start, en changing_map zakt weer na de nieuwe scène.
func _valid_path() -> void:
	var voor: Node = get_tree().current_scene
	var pad_voor := "" if voor == null else str(voor.scene_file_path)
	var gestart: bool = GameState.change_map(TOWN, "start")
	check("geldig pad: change_map geeft true", gestart == true)
	check("geldig pad: changing_map aan bij start", GameState.changing_map)
	# Pad als String vastleggen: de oude scène is vrijgegeven zodra de wissel klaar is.
	var ok := await _wacht(func() -> bool:
		var s := get_tree().current_scene
		return s != null and str(s.scene_file_path) == TOWN and str(s.scene_file_path) != pad_voor \
				and s.is_node_ready() and not GameState.changing_map
	, 15.0)
	check("geldig pad: scène gewisseld en changing_map weer false", ok)


## (3) Uitgang naar een ontbrekend pad zet de speler niet op slot.
func _exit_missing() -> void:
	var map := get_tree().current_scene
	if map == null or not map.has_method("_use_exit"):
		check("uitgang: kaart met _use_exit", false)
		return
	var player := map.get_node_or_null("Objects/Player")
	var exits := map.get_node_or_null("Exits")
	if player == null or exits == null or not ("input_locked" in player):
		check("uitgang: speler en Exits aanwezig", false)
		return
	check("uitgang: speler en Exits aanwezig", true)
	player.set("input_locked", false)
	var exit := MapExit.new()
	exit.name = "F66Missing"
	exit.target_map = MISSING
	exit.target_spawn = "start"
	exits.add_child(exit)
	map.call("_use_exit", exit)
	check("uitgang ontbrekend pad: input_locked blijft false", bool(player.get("input_locked")) == false)
	check("uitgang ontbrekend pad: changing_map false", not GameState.changing_map)
	await _frames(3)
	check("uitgang ontbrekend pad: scène ongewijzigd", get_tree().current_scene == map)
	check("uitgang ontbrekend pad: input_locked na frames nog false",
			is_instance_valid(player) and bool(player.get("input_locked")) == false)
	check("uitgang ontbrekend pad: overlay alpha 0", Transition.overlay_alpha() == 0.0)


## (4) Deur naar een ontbrekend pad: niet vast, geen scriptfout, lopen en opnieuw proberen kan.
func _door_missing() -> void:
	var map := get_tree().current_scene
	var player := map.get_node_or_null("Objects/Player") if map != null else null
	var objects := map.get_node_or_null("Objects") if map != null else null
	if player == null or objects == null or not ("input_locked" in player) or not player.has_method("get_tile"):
		check("deur ontbrekend: speler aanwezig", false)
		return
	check("deur ontbrekend: speler aanwezig", true)
	player.set("input_locked", false)
	var door := DOOR_SCENE.instantiate() as Node2D
	door.name = "F66MissingDoor"
	door.set("target_map", MISSING)
	door.set("target_spawn", "start")
	door.position = Vector2(-160, -160)
	objects.add_child(door)
	var kaart_voor := str(map.scene_file_path)
	door.call("_enter", player)
	check("deur ontbrekend pad: input_locked blijft false", bool(player.get("input_locked")) == false)
	check("deur ontbrekend pad: changing_map false", not GameState.changing_map)
	check("deur ontbrekend pad: beweging niet op slot", str(player.call("movement_state")) != "locked")
	await _frames(3)
	check("deur ontbrekend pad: scène ongewijzigd", get_tree().current_scene == map)
	check("deur ontbrekend pad: input_locked na frames nog false",
			is_instance_valid(player) and bool(player.get("input_locked")) == false)
	check("deur ontbrekend pad: overlay alpha 0", Transition.overlay_alpha() == 0.0)
	# Opnieuw proberen mag nog steeds geen vastzetting of wissel starten.
	door.call("_enter", player)
	check("deur ontbrekend pad: tweede poging input_locked false",
			is_instance_valid(player) and bool(player.get("input_locked")) == false)
	check("deur ontbrekend pad: tweede poging changing_map false", not GameState.changing_map)
	check("deur ontbrekend pad: tweede poging scène ongewijzigd",
			get_tree().current_scene == map and str(map.scene_file_path) == kaart_voor)
	var gelopen := await _stap_vrij(player)
	check("deur ontbrekend pad: speler kan nog een tegel lopen", gelopen)
	check("deur ontbrekend pad: na het lopen nog vrij en op dezelfde kaart",
			is_instance_valid(player) and bool(player.get("input_locked")) == false
			and get_tree().current_scene == map and not GameState.changing_map)
	if is_instance_valid(door):
		door.queue_free()


## (5) Deur naar een bestaand pad: input vast en de wissel loopt zoals eerder.
func _door_valid() -> void:
	var map := get_tree().current_scene
	var player := map.get_node_or_null("Objects/Player") if map != null else null
	var door := map.get_node_or_null("Objects/Door") if map != null else null
	if player == null or door == null or not door.has_method("_enter") or not ("input_locked" in player):
		check("deur geldig: speler en Door aanwezig", false)
		return
	check("deur geldig: speler en Door aanwezig", true)
	_los_richting()
	if bool(player.get("is_moving")):
		await _wacht_frames(func() -> bool:
			return not is_instance_valid(player) or not bool(player.get("is_moving"))
		, STAP_FRAMES)
	player.set("input_locked", false)
	var doel := str(door.get("target_map"))
	var pad_voor := str(map.scene_file_path)
	door.call("_enter", player)
	check("deur geldig pad: input_locked", is_instance_valid(player) and bool(player.get("input_locked")))
	check("deur geldig pad: changing_map aan bij start", GameState.changing_map)
	check("deur geldig pad: doel verschilt van de huidige kaart", doel != "" and doel != pad_voor)
	var ok := await _wacht_frames(func() -> bool:
		var s := get_tree().current_scene
		return s != null and str(s.scene_file_path) == doel and str(s.scene_file_path) != pad_voor \
				and s.is_node_ready() and not GameState.changing_map
	, WISSEL_FRAMES)
	check("deur geldig pad: scène gewisseld en changing_map weer false", ok)


## Eén tegel lopen via invoer (niet omhoog: daar staat de huisdeur). Begrensd in frames.
func _stap_vrij(player: Node) -> bool:
	if not is_instance_valid(player) or bool(player.get("input_locked")):
		return false
	var van: Vector2i = player.call("get_tile")
	for actie in ["move_down", "move_left", "move_right"]:
		Input.action_press(actie)
		var begon := false
		for _i in 8:
			await get_tree().process_frame
			if not is_instance_valid(player) or GameState.changing_map:
				Input.action_release(actie)
				return false
			if player.call("get_tile") != van or bool(player.get("is_moving")):
				begon = true
				break
		if not begon:
			Input.action_release(actie)
			continue
		var klaar := await _wacht_frames(func() -> bool:
			return not is_instance_valid(player) or player.call("get_tile") != van
		, STAP_FRAMES)
		Input.action_release(actie)
		if not klaar or not is_instance_valid(player):
			_los_richting()
			return false
		await _wacht_frames(func() -> bool:
			return not is_instance_valid(player) or not bool(player.get("is_moving"))
		, STAP_FRAMES)
		_los_richting()
		return is_instance_valid(player) and player.call("get_tile") != van \
				and not bool(player.get("input_locked")) and not GameState.changing_map
	_los_richting()
	return false


func _los_richting() -> void:
	for actie in ["move_up", "move_down", "move_left", "move_right"]:
		if InputMap.has_action(actie):
			Input.action_release(actie)


func _wacht_frames(cond: Callable, max_frames: int) -> bool:
	for _i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _wacht(cond: Callable, timeout: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
