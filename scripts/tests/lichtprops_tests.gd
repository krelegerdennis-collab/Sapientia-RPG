extends Node
## HD-2D lichtprops (WM1): assets, presets, plaatsing (scène), lichtbudget (4 helden co-op) en collision.
## Start: godot --path . -- --lichtpropstest
## Niet in CI-matrix tot placements + lights/index gemerged zijn (draft-fase mogelijk).

const MapLightingC := preload("res://scripts/map_lighting.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const SomData := preload("res://scripts/data/som_data.gd")

const COOP_HERO_LIGHTS := 4
const HD2D_MAX_POINT := 8
const TELEGRAPH_TILE_REACH := 3.0
const TILE_PX := 16
const EXCLUDE_MAPS := ["archief_2_v3_licht"]

const PROP_IDS: Array[String] = [
	"archief_kandelaber", "archief_wandblaker", "archief_leeslamp", "kas_gloeipot", "kas_gloeiplant",
	"kas_gloeiknoppen", "warper_wandlamp", "warper_wandlamp_violet", "warper_kristalzuil",
	"woud_gloeizwammen", "woud_lantaarnpaal", "woud_waterlelie", "bouw_stormlamp", "bouw_vuurkorf",
	"binnen_wandlamp", "binnen_kandelaar", "wk_kampvuur", "wk_baken", "wk_kristal",
]

## Voet-collision (breedte x hoogte in px), gecentreerd op x met onderkant op y. "-" = geen voet.
const PROP_FEET: Dictionary = {
	"archief_kandelaber": Vector2i(8, 4),
	"archief_wandblaker": Vector2i.ZERO,
	"archief_leeslamp": Vector2i.ZERO,
	"kas_gloeipot": Vector2i.ZERO,
	"kas_gloeiplant": Vector2i(10, 4),
	"kas_gloeiknoppen": Vector2i.ZERO,
	"warper_wandlamp": Vector2i.ZERO,
	"warper_wandlamp_violet": Vector2i.ZERO,
	"warper_kristalzuil": Vector2i(10, 4),
	"woud_gloeizwammen": Vector2i.ZERO,
	"woud_lantaarnpaal": Vector2i(6, 4),
	"woud_waterlelie": Vector2i.ZERO,
	"bouw_stormlamp": Vector2i(6, 4),
	"bouw_vuurkorf": Vector2i(10, 4),
	"binnen_wandlamp": Vector2i.ZERO,
	"binnen_kandelaar": Vector2i.ZERO,
	"wk_kampvuur": Vector2i.ZERO,
	"wk_baken": Vector2i.ZERO,
	"wk_kristal": Vector2i.ZERO,
}

const ARCHIEF1_PRESET_MAPS: Array[String] = [
	"archief_v1_gang", "archief_v2_kastenzaal", "archief_v2_leeszaal",
	"archief_v2_trapzaal", "archief_v3_gang", "archief_v4_voorhal",
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
	_preset_candle_tests()
	_scene_placement_tests()
	_light_budget_tests()
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


func _preset_candle_tests() -> void:
	for mid in ARCHIEF1_PRESET_MAPS:
		var rec := MapLightingC.preset_record(mid)
		check("preset %s bestaat" % mid, not rec.is_empty())
		if rec.is_empty():
			continue
		for tod in ["day", "night"]:
			var lights: Dictionary = rec.get(tod, {}).get("lights", {})
			check("%s %s candle=1.8" % [mid, tod], float(lights.get("candle", 0.0)) == 1.8)


func _scene_placement_tests() -> void:
	var placements := _collect_scene_placements()
	check("lichtprops draft: placements tellen geregistreerd", true)
	if placements.is_empty():
		check("geen props in WM1-scènes (draft OK)", true)
		return
	for p in placements:
		var tex_path := "res://assets/sprites/lichtprops/%s.png" % p["prop"]
		check("texture %s @%s" % [p["prop"], p["map_id"]], ResourceLoader.exists(tex_path))
		_check_gameplay_overlap(p)


func _collect_scene_placements() -> Array:
	var out: Array = []
	for path in _wm1_map_scene_paths():
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
		_scan_prop_nodes(inst, map_id, out)
		inst.free()
	return out


func _wm1_map_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	for e in DungeonRooms.ORDER:
		if str(e[1]) != "":
			paths.append(str(e[1]))
	var a2: Script = DungeonRooms.archief2()
	for e in a2.ORDER:
		if str(e[1]) != "":
			paths.append(str(e[1]))
	# Warper-hub (lichtprops-levering)
	for sub in ["maps", "kamers"]:
		var dir := "res://world_warper/%s/" % sub
		var d := DirAccess.open(dir)
		if d:
			d.list_dir_begin()
			var fn := d.get_next()
			while fn != "":
				if fn.ends_with(".tscn"):
					paths.append(dir + fn)
				fn = d.get_next()
	for extra in [
		"res://scenes/maps/woud_beek.tscn", "res://scenes/maps/woud_pad.tscn",
		"res://scenes/maps/berggrot_bouwplaats.tscn", "res://scenes/maps/wilgendal_binnen.tscn",
		"res://scenes/maps/wereldkaart.tscn",
	]:
		if not paths.has(extra):
			paths.append(extra)
	return paths


func _map_id_from_path(path: String, root: Node) -> String:
	if path.begins_with("res://world_warper/maps/"):
		return "warper_" + path.get_file().get_basename()
	if path.begins_with("res://world_warper/kamers/"):
		return "kamer_" + path.get_file().get_basename()
	if "room_id" in root:
		return str(root.room_id)
	return path.get_file().get_basename()


func _scan_prop_nodes(root: Node, map_id: String, out: Array) -> void:
	for n in root.find_children("*", "Sprite2D", true, false):
		var sp := n as Sprite2D
		if sp.texture == null:
			continue
		var tp := sp.texture.resource_path
		if not tp.contains("/lichtprops/"):
			continue
		var prop := tp.get_file().get_basename()
		if not PROP_IDS.has(prop):
			continue
		var x := int(sp.global_position.x) if sp.is_inside_tree() else int(sp.position.x)
		var y := int(sp.global_position.y) if sp.is_inside_tree() else int(sp.position.y)
		out.append({"map_id": map_id, "prop": prop, "x": x, "y": y})


func _foot_rect(p: Dictionary) -> Rect2:
	var foot: Vector2i = PROP_FEET.get(p["prop"], Vector2i.ZERO)
	if foot == Vector2i.ZERO:
		return Rect2()
	var hw := foot.x * 0.5
	var x := float(p["x"])
	var y := float(p["y"])
	return Rect2(x - hw, y - foot.y, foot.x, foot.y)


func _check_gameplay_overlap(p: Dictionary) -> void:
	var foot := _foot_rect(p)
	if foot.size == Vector2.ZERO:
		return
	var mid: String = p["map_id"]
	for r in _forbidden_rects(mid):
		check("%s voet %s geen overlap %s" % [mid, p["prop"], r], not foot.intersects(r))
	if SomData.ROOMS.has(mid):
		for r in _archief1_combat_rects(mid, true):
			check("%s voet %s buiten combat/telegraph" % [mid, p["prop"]], not foot.intersects(r))


func _forbidden_rects(map_id: String) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not DungeonRooms.ROOMS.has(map_id):
		return rects
	var room: Dictionary = DungeonRooms.room(map_id)
	var pad := float(TILE_PX) * 0.5
	for _name in room.get("spawns", {}):
		var v: Array = room["spawns"][_name]
		rects.append(Rect2(float(v[0]) * TILE_PX, float(v[1]) * TILE_PX, TILE_PX, TILE_PX))
	for ch in room.get("chests", []):
		var t: Array = ch["tile"]
		rects.append(Rect2(float(t[0]) * TILE_PX, float(t[1]) * TILE_PX, TILE_PX, TILE_PX))
	var layout: Array = room.get("layout", [])
	for y in layout.size():
		var row: String = layout[y]
		for x in row.length():
			var ch := row[x]
			if ch in ["U", "v", "n", "E", "(", ")", "N", "B", "#", "x", "@", "t", "T"]:
				rects.append(Rect2(x * TILE_PX, y * TILE_PX, TILE_PX, TILE_PX))
	return rects


func _archief1_combat_rects(map_id: String, telegraph_margin: bool) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not DungeonRooms.ROOMS.has(map_id):
		return rects
	var room: Dictionary = DungeonRooms.room(map_id)
	var theme := DungeonRooms.theme_of(room)
	var legend := DungeonRooms.legend_of(room)
	var layout: Array = room.get("layout", [])
	var margin := int(TELEGRAPH_TILE_REACH * TILE_PX) if telegraph_margin else 0
	for y in layout.size():
		var row: String = layout[y]
		for x in row.length():
			var ch := row[x]
			if ch == "<" or ch == ">" or ch == " ":
				continue
			if not legend.has(ch):
				continue
			var num := int(legend[ch])
			if num < 0 or DungeonRooms.is_solid(num, theme) or DungeonRooms.is_no_monster(num, theme):
				continue
			var r := Rect2(x * TILE_PX, y * TILE_PX, TILE_PX, TILE_PX)
			if margin > 0:
				r = r.grow(margin)
			rects.append(r)
	return rects


func _light_budget_tests() -> void:
	var placements := _collect_scene_placements()
	if placements.is_empty():
		check("lichtbudget: geen scene-placements (draft OK)", true)
		return
	var by_map: Dictionary = {}
	for p in placements:
		var mid: String = p["map_id"]
		if EXCLUDE_MAPS.has(mid):
			continue
		if not by_map.has(mid):
			by_map[mid] = []
		(by_map[mid] as Array).append(p)
	for mid in by_map:
		var rec := MapLightingC.preset_record(mid)
		var max_l := int(rec.get("day", {}).get("max_point_lights", HD2D_MAX_POINT))
		var prop_lights := (by_map[mid] as Array).size()
		var total := prop_lights + COOP_HERO_LIGHTS
		check("%s pointlights props(%d)+heroes(%d)<=%d" % [mid, prop_lights, COOP_HERO_LIGHTS, max_l], total <= max_l)
