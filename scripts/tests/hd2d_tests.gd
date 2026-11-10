extends Node
## HD-2D mapverlichting (WM1): data, apply(), budget, save en instellingen.
## Start: godot --path . -- --hd2dtest

const MapLightingC := preload("res://scripts/map_lighting.gd")
const Hd2dUnmodulated := preload("res://scripts/hd2d_unmodulated.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const DORP := "res://scenes/maps/dorp_wilgendal.tscn"
const HUIS := "res://scenes/maps/huis_wilgendal.tscn"
const GANG := "res://scenes/maps/archief_v1_gang.tscn"
const D100 := "res://scenes/maps/dungeon100.tscn"
const PARTY_FOUR := ["noor", "lotte", "kael"]

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
	await _unmodulated_night_tests()
	await _party_light_budget_tests()
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


func _effective_unmodulated(item: CanvasItem, tint: Color) -> Color:
	var m := item.modulate
	return Color(m.r * tint.r, m.g * tint.g, m.b * tint.b, m.a * tint.a)


func _near_white(c: Color, eps := 0.08) -> bool:
	return absf(c.r - 1.0) <= eps and absf(c.g - 1.0) <= eps and absf(c.b - 1.0) <= eps


func _unmodulated_night_tests() -> void:
	GameState.new_game()
	GameState.set_time_of_day("night", 0.0)
	Settings.set_value("hd2d_light", true)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.encounter_multiplier = 0.0
	for id in PARTY_FOUR:
		GameState.add_member(id)
	var sc := await _await_map(GANG, "ingang")
	check("night som-map geladen", sc != null)
	if sc == null:
		return
	for i in 120:
		await get_tree().process_frame
		if sc.get("som") != null:
			break
	var rig := sc.get_node_or_null("MapLightingRig") as MapLightingRig
	check("night archief rig", rig != null)
	if rig == null:
		return
	check("night preset in time_of_day", GameState.time_of_day == "night")
	var tint := Hd2dUnmodulated.canvas_tint_on_map(sc)
	var inv := Hd2dUnmodulated.inverse_modulate(tint)
	var tg := sc.find_child("TelegraphLayer", true, false) as CanvasItem
	var som_n: Node = sc.som if "som" in sc else sc.get("som")
	var hud_node: Node = som_n.get_node_or_null("SomHud") if som_n else null
	check("som: TelegraphLayer aanwezig", tg != null)
	check("som: SomHud aanwezig", hud_node != null)
	if tg:
		check("TelegraphLayer light_mask 0", tg.light_mask == 0)
		check("TelegraphLayer modulate compenseert tint", tg.modulate.is_equal_approx(inv))
		check("TelegraphLayer effectief niet getint", _near_white(_effective_unmodulated(tg, tint)))
		var root_fx := tg.get_node_or_null("RootFxOverlay") as CanvasItem
		if root_fx:
			check("RootFxOverlay light_mask 0", root_fx.light_mask == 0)
			check("RootFxOverlay effectief niet getint", _near_white(_effective_unmodulated(root_fx, tint)))
	if hud_node and hud_node.get_child_count() > 0:
		var hud_root := hud_node.get_child(0) as CanvasItem
		check("SomHud root light_mask 0", hud_root != null and hud_root.light_mask == 0)
		if hud_root:
			check("SomHud effectief niet getint", _near_white(_effective_unmodulated(hud_root, tint)))
	var objects := sc.get_node_or_null("Objects")
	if objects:
		var num := SomFx.number(objects, Vector2(80, 80), "12", Color.WHITE)
		await get_tree().process_frame
		check("damage number SomNumber", num != null and num.name == "SomNumber")
		if num is CanvasItem:
			var ni := num as CanvasItem
			check("SomNumber light_mask 0", ni.light_mask == 0)
			check("SomNumber effectief niet getint", _near_white(_effective_unmodulated(ni, tint)))
	# huis_wilgendal gebruikt wél nacht-preset (niet fixed)
	sc = await _await_map(HUIS, "binnen")
	for i in 10:
		await get_tree().process_frame
	MapLightingC.set_time("night", 0.0)
	for i in 20:
		await get_tree().process_frame
	var ht: CanvasModulate = sc.find_child("Hd2dTint", true, false) as CanvasModulate
	if ht == null:
		var cms: Array = sc.find_children("*", "CanvasModulate", true, false)
		ht = cms[0] as CanvasModulate if not cms.is_empty() else null
	check("night huis: CanvasModulate", ht != null)
	if ht:
		var night_amb: Array = MapLightingC.preset_record("huis_wilgendal").get("night", {}).get("ambient", [1, 1, 1])
		var tc: Color = ht.color
		check("night huis tint ≈ night preset", tc.r < float(night_amb[0]) + 0.35 and tc.b < float(night_amb[2]) + 0.35)


func _party_light_budget_tests() -> void:
	GameState.new_game()
	GameState.set_time_of_day("night", 0.0)
	Settings.set_value("hd2d_light", true)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.encounter_multiplier = 0.0
	for id in PARTY_FOUR:
		GameState.add_member(id)
	check("party size 4", GameState.party.size() == 4)
	var sc := await _await_map(GANG, "ingang")
	if sc == null:
		check("party lights: map geladen", false)
		return
	for i in 120:
		await get_tree().process_frame
		if sc.get("som") != null:
			break
	var rig := sc.get_node_or_null("MapLightingRig") as MapLightingRig
	check("party lights: rig", rig != null)
	if rig == null:
		return
	var max_l := int(MapLightingC.preset_record("archief_v1_gang").get("day", {}).get("max_point_lights", 8))
	var party_n := sc.find_children("Hd2dPartyLight", "PointLight2D", true, false).size()
	check("party: 4 Hd2dPartyLight nodes", party_n == 4)
	check("point lights totaal <= budget (%d)" % max_l, rig.enabled_point_lights() <= max_l)
	check("directional lights <= 1", rig.count_enabled_directional_lights() <= 1)


func _await_map(path: String, spawn := "") -> Node:
	GameState.change_map(path, spawn)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == path and s.is_node_ready():
			return s
	return null
