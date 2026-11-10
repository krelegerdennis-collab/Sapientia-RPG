extends Node
## HD-2D lichtprops (WM1): assets, presets, plaatsing, budget (4 helden) en collision (§9–10).
## Start: godot --path . -- --lichtpropstest

const MapLightingC := preload("res://scripts/map_lighting.gd")
const MapLightingRig := preload("res://scripts/map_lighting_rig.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const COOP_HERO_LIGHTS := 4
const HD2D_MAX_POINT := 8
const EXCLUDE_MAPS: Array[String] = ["archief_2_v3_licht"]
const NO_GLOW_PRESET: Array[String] = ["archief_v2_trapzaal", "wereldkaart"]
const BUSY_NIGHT_MAP := "woud_pad"
const WOUD_PAD := "res://scenes/maps/woud_pad.tscn"
const EXCLUDED_LICHT_SCENE := "res://scenes/maps/archief_2_v3_licht.tscn"
const PARTY_FOUR := ["noor", "lotte", "kael"]
const BUSY_CAM := Vector2(224, 0)

const PROP_IDS: Array[String] = [
	"archief_kandelaber", "archief_wandblaker", "archief_wandblaker_glow",
	"archief_leeslamp", "archief_leeslamp_glow",
	"kas_gloeipot", "kas_gloeipot_glow", "kas_gloeiplant", "kas_gloeiknoppen",
	"warper_wandlamp", "warper_wandlamp_violet", "warper_kristalzuil",
	"woud_gloeizwammen", "woud_lantaarnpaal", "woud_waterlelie",
	"bouw_stormlamp", "bouw_stormlamp_glow", "bouw_vuurkorf",
	"binnen_wandlamp", "binnen_kandelaar",
	"wk_kampvuur", "wk_baken", "wk_kristal",
]

const LICHTPROP_MAPS: Array[String] = [
	"archief_v1_gang", "archief_v2_kastenzaal", "archief_v2_leeszaal", "archief_v2_trapzaal",
	"archief_v3_gang", "archief_v4_voorhal",
	"archief_2_v1_plaat", "archief_2_v2_gang", "archief_2_v2_lotte", "archief_2_v3_wurger",
	"archief_2_v4_hal", "leven_ingang", "leven_v1_plaat", "leven_v2_leeszaal", "leven_v3_combi",
	"warper_warp_ring", "warper_hanger_nis",
	"kamer_beeldkamer", "kamer_echo_kamer", "kamer_handelskamer", "kamer_kern",
	"kamer_rustkamer", "kamer_trainingshal", "kamer_werkplaats",
	"woud_beek", "woud_pad", "berggrot_bouwplaats", "wilgendal_binnen", "wereldkaart",
]

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
	_asset_tests()
	_preset_tests()
	_excluded_map_tests()
	_collision_report_tests()
	_scene_placement_tests()
	_busy_budget_reference_tests()
	_glow_pointlight_guard_tests()
	await _runtime_busy_budget_tests()
	print("LICHTPROPSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _asset_tests() -> void:
	for pid in PROP_IDS:
		var al := "res://assets/sprites/lichtprops/%s.png" % pid
		var nm := "res://assets/hd2d/sprites/lichtprops/%s_n.png" % pid
		var em := "res://assets/hd2d/sprites/lichtprops/%s_e.png" % pid
		check("albedo %s" % pid, ResourceLoader.exists(al))
		check("normal %s" % pid, ResourceLoader.exists(nm))
		check("emissive %s" % pid, ResourceLoader.exists(em))


func _preset_tests() -> void:
	for mid in LICHTPROP_MAPS:
		if mid in EXCLUDE_MAPS:
			continue
		var rec := MapLightingC.preset_record(mid)
		check("preset %s" % mid, not rec.is_empty())
		if rec.is_empty():
			continue
		if mid in NO_GLOW_PRESET:
			continue
		for tod in ["day", "night"]:
			var em: Dictionary = rec.get(tod, {}).get("emissive", {})
			check("%s %s emissive.glow" % [mid, tod], float(em.get("glow", -1.0)) >= 0.0)
			var lights: Dictionary = rec.get(tod, {}).get("lights", {})
			check("%s %s geen lights.glow PointLight" % [mid, tod], not lights.has("glow"))
	for mid in ["archief_v1_gang", "archief_v2_kastenzaal"]:
		for tod in ["day", "night"]:
			var lights: Dictionary = MapLightingC.preset_record(mid).get(tod, {}).get("lights", {})
			check("%s %s candle=1.8" % [mid, tod], float(lights.get("candle", 0.0)) == 1.8)


func _excluded_map_tests() -> void:
	var path := EXCLUDED_LICHT_SCENE
	var sc := load(path) as PackedScene
	var inst := sc.instantiate()
	var n := 0
	for c in inst.find_children("*", "Sprite2D", true, false):
		if str(c.name).begins_with("Lp_"):
			n += 1
	inst.free()
	check("archief_2_v3_licht: geen geplaatste props", n == 0)


func _collision_report_tests() -> void:
	var txt := FileAccess.get_file_as_string("res://data/hd2d/reference/collision_report_lichtprops.json")
	var parsed: Variant = JSON.parse_string(txt)
	check("collision_report JSON", parsed is Dictionary)
	if not parsed is Dictionary:
		return
	var rep: Dictionary = parsed
	for mid in rep:
		if mid in EXCLUDE_MAPS:
			continue
		var block: Dictionary = rep[mid]
		for p: Dictionary in block.get("props", []):
			var areas: Array = p.get("areas", [])
			check("%s %s: geen area-overlap" % [mid, p.get("prop", "?")], areas.is_empty())


func _scene_placement_tests() -> void:
	var placements := _collect_scene_placements()
	check("props in scènes: %d" % placements.size(), not placements.is_empty())
	for p in placements:
		check("texture %s @%s" % [p["prop"], p["map_id"]], ResourceLoader.exists(
				"res://assets/sprites/lichtprops/%s.png" % p["prop"]))


func _collect_scene_placements() -> Array:
	var out: Array = []
	for path in _scene_paths():
		if not ResourceLoader.exists(path):
			continue
		var sc := load(path) as PackedScene
		if sc == null:
			continue
		var inst := sc.instantiate()
		var map_id := _map_id_from_path(path, inst)
		if EXCLUDE_MAPS.has(map_id):
			inst.free()
			continue
		for n in inst.find_children("*", "Sprite2D", true, false):
			if not str(n.name).begins_with("Lp_"):
				continue
			var sp := n as Sprite2D
			var pid := ""
			if "prop_id" in sp:
				pid = str(sp.prop_id)
			if pid.is_empty():
				pid = str(n.name).get_slice("_", 1)
			out.append({"map_id": map_id, "prop": pid, "x": int(sp.position.x), "y": int(sp.position.y)})
		inst.free()
	return out


func _scene_paths() -> Array[String]:
	var paths: Array[String] = []
	for mid in LICHTPROP_MAPS:
		if mid in EXCLUDE_MAPS:
			continue
		var p: String = str(MapLightingC.preset_record(mid).get("scene", ""))
		if p != "":
			paths.append(p)
	return paths


func _map_id_from_path(path: String, root: Node) -> String:
	if path.begins_with("res://world_warper/maps/"):
		return "warper_" + path.get_file().get_basename()
	if path.begins_with("res://world_warper/kamers/"):
		return "kamer_" + path.get_file().get_basename()
	if "room_id" in root:
		return str(root.room_id)
	return path.get_file().get_basename()


func _busy_budget_reference_tests() -> void:
	var txt := FileAccess.get_file_as_string("res://data/hd2d/reference/render_report_lichtprops_busy.json")
	var parsed: Variant = JSON.parse_string(txt)
	check("render_report_busy JSON", parsed is Dictionary)
	if not parsed is Dictionary:
		return
	for key in parsed:
		if key.begins_with(EXCLUDE_MAPS[0]):
			continue
		if not str(key).ends_with("|night"):
			continue
		var v: Dictionary = parsed[key]
		var pl := int(v.get("point_lights", 99))
		var heroes := int(v.get("heroes", 0))
		check("busy %s point_lights<=%d (got %d, heroes %d)" % [key, HD2D_MAX_POINT, pl, heroes],
				pl <= HD2D_MAX_POINT and heroes == COOP_HERO_LIGHTS)


func _kind_is_point_light(prop: String) -> bool:
	var r := MapLightingC.rule_for_path("assets/sprites/lichtprops/%s.png" % prop)
	return not r.is_empty() and str(r.get("kind", "")) != "glow"


func _light_budget_tests_static() -> void:
	var txt := FileAccess.get_file_as_string("res://data/hd2d/reference/render_report_lichtprops_busy.json")
	var parsed: Variant = JSON.parse_string(txt)
	check("static budget: busy report JSON", parsed is Dictionary)
	if not parsed is Dictionary:
		return
	for mid in LICHTPROP_MAPS:
		if mid in EXCLUDE_MAPS:
			continue
		var key := "%s|night" % mid
		if not parsed.has(key):
			check("static budget: %s in busy report" % key, false)
			continue
		var v: Dictionary = parsed[key]
		var max_l := int(MapLightingC.preset_record(mid).get("night", {}).get("max_point_lights", 8))
		var scan_props := int(v.get("scan_max_props", 99))
		var pl := int(v.get("point_lights", 99))
		check("%s scan_max_props+heroes <= max (%d)" % [mid, max_l], scan_props + COOP_HERO_LIGHTS <= max_l)
		check("%s busiest night point_lights <= max (%d)" % [mid, max_l], pl <= max_l)


func _glow_pointlight_guard_tests() -> void:
	for pid in PROP_IDS:
		var r := MapLightingC.rule_for_path("assets/sprites/lichtprops/%s.png" % pid)
		if r.is_empty():
			continue
		var kind: String = str(r.get("kind", ""))
		if kind != "glow" and not bool(r.get("glow_only", false)):
			continue
		check("lights.json %s glow_only" % pid, bool(r.get("glow_only", false)) and kind == "glow")
		check("rule %s geen PointLight-kandidaat" % pid, not _kind_is_point_light(pid))
	for mid in LICHTPROP_MAPS:
		if mid in EXCLUDE_MAPS:
			continue
		var lights: Dictionary = MapLightingC.preset_record(mid).get("night", {}).get("lights", {})
		check("%s night lights.glow uit (PointLight)" % mid, float(lights.get("glow", 0.0)) <= 0.0)


func _runtime_busy_budget_tests() -> void:
	_light_budget_tests_static()
	GameState.new_game()
	GameState.set_time_of_day("night", 0.0)
	Settings.set_value("hd2d_light", true)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.encounter_multiplier = 0.0
	for id in PARTY_FOUR:
		GameState.add_member(id)
	GameState.change_map(WOUD_PAD, "zuid")
	var sc: Node = null
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == WOUD_PAD and s.is_node_ready():
			sc = s
			break
	if sc == null:
		sc = get_tree().current_scene
	var cam := sc.get_viewport().get_camera_2d() if sc != null else null
	if cam != null:
		cam.position = BUSY_CAM + Vector2(192, 108)
	check("runtime busiest map %s geladen" % BUSY_NIGHT_MAP, sc != null)
	if sc == null:
		return
	var rig := sc.get_node_or_null("MapLightingRig") as MapLightingRig
	check("MapLightingRig aanwezig", rig != null)
	if rig == null:
		return
	for _w in 48:
		await get_tree().process_frame
	var max_l := int(MapLightingC.preset_record(BUSY_NIGHT_MAP).get("night", {}).get("max_point_lights", 8))
	var pts := rig.enabled_point_lights()
	check("runtime point lights <= %d (got %d)" % [max_l, pts], pts <= max_l)
	var ref_key := "%s|night" % BUSY_NIGHT_MAP
	var busy_txt := FileAccess.get_file_as_string("res://data/hd2d/reference/render_report_lichtprops_busy.json")
	var busy_parsed: Variant = JSON.parse_string(busy_txt)
	if busy_parsed is Dictionary and busy_parsed.has(ref_key):
		var ref_pts := int(busy_parsed[ref_key].get("point_lights", HD2D_MAX_POINT))
		check("reference busiest %s point_lights<=%d (ART got %d)" % [ref_key, HD2D_MAX_POINT, ref_pts],
				ref_pts <= HD2D_MAX_POINT)
	var proc_ms := 0.0
	var draw_sum := 0.0
	var draw_max := 0
	for _w in 12:
		await get_tree().process_frame
	for _f in 60:
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		proc_ms += (Time.get_ticks_usec() - t0) / 1000.0
		var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_sum += dc
		draw_max = maxi(draw_max, dc)
	proc_ms /= 60.0
	var draw_avg := draw_sum / 60.0
	print("LICHTPROPPERF map=%s night heroes=4 point_lights=%d proc_ms=%.3f draw_avg=%.1f draw_max=%d" % [
			BUSY_NIGHT_MAP, pts, proc_ms, draw_avg, draw_max])
	check("runtime perf log geschreven", proc_ms > 0.0)
