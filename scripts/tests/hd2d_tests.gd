extends Node
## HD-2D mapverlichting (WM1): data, apply(), budget, save en instellingen.
## Start: godot --path . -- --hd2dtest

const MapLightingC := preload("res://scripts/map_lighting.gd")
const DORP := "res://scenes/maps/dorp_wilgendal.tscn"
const HUIS := "res://scenes/maps/huis_wilgendal.tscn"
const GANG := "res://scenes/maps/archief_v1_gang.tscn"
const D100 := "res://scenes/maps/dungeon100.tscn"

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
	_data_tests()
	await _map_apply_tests()
	await _time_and_save_tests()
	await _toggle_tests()
	print("HD2DTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data_tests() -> void:
	check("presets: dorp_wilgendal", not MapLightingC.preset_record("dorp_wilgendal").is_empty())
	for mid in ["huis_wilgendal", "archief_v1_gang", "dungeon100"]:
		check("preset %s" % mid, not MapLightingC.preset_record(mid).is_empty())
	check("maps_index sample: normals bestaan", MapLightingC.verify_index_sample())


func _map_apply_tests() -> void:
	GameState.new_game()
	Settings.set_value("hd2d_light", true)
	for spec in [
		[DORP, "dorp_wilgendal", "ingang"],
		[HUIS, "huis_wilgendal", "binnen"],
		[GANG, "archief_v1_gang", "ingang"],
	]:
		await _load_and_check(spec[0], spec[1], spec[2] if spec.size() > 2 else "ingang")
	await _dungeon100_check()


func _load_and_check(path: String, map_id: String, spawn := "ingang") -> void:
	GameState.change_map(path, spawn)
	for i in 120:
		await get_tree().process_frame
		if get_tree().current_scene != null and str(get_tree().current_scene.scene_file_path) == path:
			break
	var sc := get_tree().current_scene
	var ok := sc != null and sc.get_node_or_null("MapLightingRig") != null
	check("apply %s: MapLightingRig" % map_id, ok)
	if not ok:
		return
	var rig := sc.get_node("MapLightingRig") as MapLightingRig
	await get_tree().process_frame
	var max_l := int(MapLightingC.preset_record(map_id).get("day", {}).get("max_point_lights", 8))
	check("%s point lights <= budget (%d)" % [map_id, max_l], rig.enabled_point_lights() <= max_l)


func _dungeon100_check() -> void:
	GameState.new_game()
	GameState.dungeon100_floor = 1
	GameState.dungeon100_seed = 4242
	GameState.dungeon100_checkpoint = 1
	Settings.set_value("hd2d_light", true)
	GameState.change_map(D100, "ingang")
	for i in 400:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc != null and str(sc.scene_file_path) == D100 and sc.get_node_or_null("MapLightingRig") != null:
			check("dungeon100 MapLightingRig", true)
			return
	check("dungeon100 MapLightingRig", false)


func _time_and_save_tests() -> void:
	GameState.new_game()
	GameState.time_of_day = "day"
	check("default time_of_day", GameState.time_of_day == "day")
	GameState.set_time_of_day("night", 0.0)
	check("set_time_of_day night", GameState.time_of_day == "night")
	var snap := GameState.state_data(Vector2i(0, 0), Vector2i.DOWN, DORP)
	check("save bevat time_of_day", snap.get("time_of_day") == "night")
	var old := snap.duplicate(true)
	old.erase("time_of_day")
	GameState.apply_state(old)
	check("oude save zonder time_of_day = day", GameState.time_of_day == "day")
	snap["time_of_day"] = "night"
	GameState.apply_state(snap)
	check("load time_of_day night", GameState.time_of_day == "night")


func _toggle_tests() -> void:
	GameState.change_map(DORP, "start")
	for i in 120:
		await get_tree().process_frame
	Settings.set_value("hd2d_light", false)
	for i in 10:
		await get_tree().process_frame
	var sc := get_tree().current_scene
	check("toggle uit: geen MapLightingRig", sc != null and sc.get_node_or_null("MapLightingRig") == null)
	check("toggle uit: geen Hd2dPointLight", sc == null or sc.find_children("Hd2dPointLight*", "PointLight2D", true, false).is_empty())
	Settings.set_value("hd2d_light", true)
	for i in 30:
		await get_tree().process_frame
	sc = get_tree().current_scene
	check("toggle aan: rig terug", sc != null and sc.get_node_or_null("MapLightingRig") != null)
