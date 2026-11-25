class_name MapLighting
extends RefCounted
## HD-2D mapverlichting (WM1): data uit res://data/hd2d/, recept uit RPG ART HANDOFF_SPEC.

const RigScript := preload("res://scripts/map_lighting_rig.gd")
const Hd2dUnmodulated := preload("res://scripts/hd2d_unmodulated.gd")
const StoryData := preload("res://scripts/data/story_data.gd")
const PRESETS_PATH := "res://data/hd2d/presets.json"
const LIGHTS_PATH := "res://data/hd2d/lights.json"
const MAPS_INDEX_PATH := "res://data/hd2d/maps_index.json"
## Arena-data blijft in *_arena.json. Alleen mergen zolang de vlag aan staat.
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const ARENA_PRESETS_PATH := "res://data/hd2d/presets_arena.json"
const ARENA_LIGHTS_PATH := "res://data/hd2d/lights_arena.json"
const ARENA_INDEX_PATH := "res://data/hd2d/maps_index_arena.json"

## Na deze verhaalstap stuurt proloog-StoryTint de preset niet meer (alleen time_of_day).
const STORY_TINT_FREE_STEP := StoryData.KLAAR

static var _loaded := false
static var _arena_merged := false
static var _maps: Dictionary = {}
static var _lights: Dictionary = {}
static var _index: Dictionary = {}
static var _bake_tiles: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func _root() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root
	return null


static func enabled() -> bool:
	var root := _root()
	if root == null or root.get_node_or_null("Settings") == null:
		return true
	return bool(Settings.get_value("hd2d_light"))


static func _ensure() -> void:
	if not _loaded:
		var pd: Dictionary = _read_json(PRESETS_PATH)
		_maps = pd.get("maps", {}) as Dictionary
		var ld: Dictionary = _read_json(LIGHTS_PATH)
		_lights = ld.get("assets", {}) as Dictionary
		_index = _read_json(MAPS_INDEX_PATH) as Dictionary
		_prep_bake_tiles()
		_loaded = true
	_sync_arena()


## Voegt de arena-json toe aan de runtime-cache. De bestanden zelf blijven onaangeroerd.
## Scènepaden wijzen naar scenes/arena/ (de ART-json noemt scenes/maps/, die map is WM1).
static func _sync_arena() -> void:
	var on := ReleaseFlags.arena_enabled()
	if on == _arena_merged:
		return
	_arena_merged = on
	if not on:
		return
	var lights: Dictionary = _read_json(ARENA_LIGHTS_PATH).get("assets", {}) as Dictionary
	for k in lights:
		_lights[str(k)] = lights[k]
	var presets: Dictionary = _read_json(ARENA_PRESETS_PATH).get("maps", {}) as Dictionary
	for k in presets:
		var rec: Dictionary = (presets[k] as Dictionary).duplicate(true)
		if str(k) == "arena_hal":
			rec["scene"] = "res://scenes/arena/arena_hall.tscn"
		elif str(k) == "arena_lobby":
			rec["scene"] = "res://scenes/arena/arena_lobby.tscn"
		_maps[str(k)] = rec
	var index := _read_json(ARENA_INDEX_PATH)
	for k in index:
		if str(k).begins_with("_"):
			continue
		_index[str(k)] = index[k]


static func _read_json(path: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


static func _prep_bake_tiles() -> void:
	_bake_tiles.clear()
	for key: String in _index:
		if not key.begins_with("assets/tiles/huis_interieur/"):
			continue
		var rec: Dictionary = _index[key]
		if not rec.get("normal", false):
			continue
		var al_path := "res://" + key
		if not ResourceLoader.exists(al_path):
			continue
		var al := Image.load_from_file(ProjectSettings.globalize_path(al_path))
		al.convert(Image.FORMAT_RGBA8)
		var nf: String = str(rec.get("normal_file", ""))
		if nf.is_empty():
			continue
		var nm_path := "res://" + nf
		if not ResourceLoader.exists(nm_path):
			continue
		var nm := Image.load_from_file(ProjectSettings.globalize_path(nm_path))
		nm.convert(Image.FORMAT_RGBA8)
		var c := al.get_region(Rect2i(0, 0, 16, 16))
		_bake_tiles[c.get_data().hex_encode().sha256_text()] = nm.get_region(Rect2i(0, 0, 16, 16))


static func map_id_from(map_root: Node) -> String:
	var path := str(map_root.scene_file_path)
	if path.is_empty():
		return ""
	if path.begins_with("res://world_warper/maps/"):
		return "warper_" + path.get_file().get_basename()
	if path.begins_with("res://world_warper/kamers/"):
		return "kamer_" + path.get_file().get_basename()
	if path.ends_with("dungeon100.tscn"):
		return "dungeon100"
	if "room_id" in map_root:
		return str(map_root.room_id)
	var naam := path.get_file().get_basename()
	# ART noemt de hal arena_hal; de scène heet arena_hall.
	if naam == "arena_hall":
		return "arena_hal"
	return naam


static func preset_record(map_id: String) -> Dictionary:
	_ensure()
	return _maps.get(map_id, {}) as Dictionary


static func apply(map_root: Node, map_id := "") -> void:
	if map_root == null:
		return
	_remove_rig(map_root)
	if not enabled():
		return
	_ensure()
	if map_id.is_empty():
		map_id = map_id_from(map_root)
	if not _maps.has(map_id):
		return
	var rig: MapLightingRig = RigScript.new()
	rig.name = "MapLightingRig"
	map_root.add_child(rig)
	var phase := _effective_phase(map_root)
	rig.setup(map_root, map_id, phase)


static func _effective_phase(_map_root: Node) -> String:
	var root := _root()
	var phase := "day"
	var gs := root.get_node_or_null("GameState") if root else null
	if gs and "time_of_day" in gs:
		phase = str(gs.time_of_day)
	var story := root.get_node_or_null("Story") if root else null
	if story and story.has_method("tint_name") and gs and int(gs.story_step) < STORY_TINT_FREE_STEP:
		var tn: String = story.tint_name()
		if tn in ["evening", "night"]:
			phase = "night"
		elif tn == "day":
			phase = "day"
	return phase


static func set_time(phase: String, tween_sec := 1.5) -> void:
	if not enabled():
		return
	var m := _current_map()
	if m == null:
		return
	var rig := m.get_node_or_null("MapLightingRig") as MapLightingRig
	if rig:
		rig.set_phase(phase, tween_sec)


static func _current_map() -> Node:
	var root := _root()
	if root == null:
		return null
	var st := root.get_tree()
	if st == null:
		return null
	return st.current_scene


static func _remove_rig(map_root: Node) -> void:
	var rig := map_root.get_node_or_null("MapLightingRig")
	if rig:
		rig.queue_free()


static func strip_map(map_root: Node) -> void:
	_remove_rig(map_root)
	if map_root == null:
		return
	for n in map_root.find_children("Hd2d*", "*", true, false):
		n.queue_free()
	for n in map_root.find_children("*_Hd2dEmissive", "TileMapLayer", true, false):
		n.queue_free()
	for n in map_root.find_children("_hd2d_em", "Sprite2D", true, false):
		n.queue_free()
	for n in map_root.find_children("_hd2d_halo", "Sprite2D", true, false):
		n.queue_free()
	for n in map_root.find_children("Hd2dPartyLight", "PointLight2D", true, false):
		n.queue_free()
	var p := map_root.get_node_or_null("Objects/Player")
	if p:
		var pl := p.get_node_or_null("Hd2dPlayerLight")
		if pl:
			pl.queue_free()
	Hd2dUnmodulated.reset_compensation()


static func col(a: Array, k := 1.0) -> Color:
	return Color(float(a[0]) * k, float(a[1]) * k, float(a[2]) * k)


static func unshaded_mat(blend: int) -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	m.blend_mode = blend
	return m


static func base_texture(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	if t is CanvasTexture:
		return (t as CanvasTexture).diffuse_texture
	return t


static func rule_for_texture(t: Texture2D) -> Dictionary:
	var bt := base_texture(t)
	if bt == null:
		return {}
	if bt is AtlasTexture:
		bt = (bt as AtlasTexture).atlas
	var path := bt.resource_path.trim_prefix("res://")
	return rule_for_path(path)


static func rule_for_path(path: String) -> Dictionary:
	_ensure()
	var key := path.trim_prefix("res://")
	return _lights.get(key, {}) as Dictionary


static func hd_texture(res_path: String, suffix: String) -> Texture2D:
	if res_path.is_empty():
		return null
	_ensure()
	var key := res_path.trim_prefix("res://")
	if not _index.has(key):
		return null
	var rec: Dictionary = _index[key]
	var rel := ""
	if suffix == "_n.png" and rec.get("normal", false):
		rel = str(rec.get("normal_file", ""))
	elif suffix == "_e.png" and rec.get("emissive_px", 0) as int > 0:
		rel = str(rec.get("emissive_file", ""))
	elif suffix == "_g.png" and rec.get("glow", false):
		rel = str(rec.get("glow_file", ""))
	if rel.is_empty():
		return null
	var full := "res://" + rel
	return _cached_tex(full)


static func _cached_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		_tex_cache[path] = null
		return null
	var t: Texture2D = load(path)
	_tex_cache[path] = t
	return t


static func with_normals(orig: Texture2D) -> Texture2D:
	if orig == null or orig is CanvasTexture:
		return orig
	if orig is AtlasTexture:
		var at := orig as AtlasTexture
		var key2 := "atlas|%d|%s" % [at.atlas.get_instance_id(), at.region]
		if _tex_cache.has(key2):
			return _tex_cache[key2]
		var nat := AtlasTexture.new()
		nat.atlas = with_normals(at.atlas)
		nat.region = at.region
		nat.filter_clip = at.filter_clip
		_tex_cache[key2] = nat
		return nat
	var key := orig.resource_path
	var n: Texture2D = null
	if key.is_empty():
		key = "rt|%d" % orig.get_instance_id()
		if _tex_cache.has(key):
			return _tex_cache[key]
		n = _bake_runtime_normal(orig)
	else:
		if _tex_cache.has(key):
			return _tex_cache[key]
		n = hd_texture(key, "_n.png")
	if n == null:
		_tex_cache[key] = orig
		return orig
	var ct := CanvasTexture.new()
	ct.diffuse_texture = orig
	ct.normal_texture = n
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_cache[key] = ct
	return ct


static func _bake_runtime_normal(t: Texture2D) -> Texture2D:
	var im := t.get_image()
	if im == null or im.get_width() % 16 != 0 or im.get_height() % 16 != 0:
		return null
	im.convert(Image.FORMAT_RGBA8)
	var out := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.5, 0.5, 1.0, 0.0))
	var hit := 0
	for y in range(0, im.get_height(), 16):
		for x in range(0, im.get_width(), 16):
			var c := im.get_region(Rect2i(x, y, 16, 16))
			var k := c.get_data().hex_encode().sha256_text()
			if _bake_tiles.has(k):
				out.blit_rect(_bake_tiles[k], Rect2i(0, 0, 16, 16), Vector2i(x, y))
				hit += 1
	if hit == 0:
		return null
	return ImageTexture.create_from_image(out)


static func frame_info(s: Sprite2D) -> Dictionary:
	var t := base_texture(s.texture)
	if t == null:
		return {"size": Vector2.ZERO, "tl": Vector2.ZERO}
	var fs := Vector2(t.get_width() / maxi(1, s.hframes), t.get_height() / maxi(1, s.vframes))
	if s.region_enabled:
		fs = s.region_rect.size
	var tl := s.offset - (fs / 2.0 if s.centered else Vector2.ZERO)
	return {"size": fs, "tl": tl}


static func cluster_tile_lights(cands: Array) -> void:
	var keep: Array = []
	var buckets := {}
	for c: Dictionary in cands:
		if c.get("local") != null:
			keep.append(c)
			continue
		var k := Vector2i(floori(c["pos"].x / 40.0), floori(c["pos"].y / 40.0))
		if not buckets.has(k):
			buckets[k] = []
		(buckets[k] as Array).append(c)
	for k in buckets:
		var arr: Array = buckets[k]
		var sum := Vector2.ZERO
		var px := 0
		var best: Dictionary = arr[0]
		for c2: Dictionary in arr:
			sum += c2["pos"] * c2["px"]
			px += c2["px"]
			if c2["px"] > best["px"]:
				best = c2
		var m := best.duplicate()
		m["pos"] = sum / maxf(px, 1)
		m["px"] = px
		m["n"] = arr.size()
		keep.append(m)
	cands.clear()
	cands.append_array(keep)


static func dedupe_lights(pick: Array) -> Array:
	var dd: Array = []
	for c: Dictionary in pick:
		var dup := false
		for d: Dictionary in dd:
			if d["kind"] == c["kind"] and d["pos"].distance_to(c["pos"]) < 16.0:
				dup = true
				break
		if not dup:
			dd.append(c)
	return dd


static func add_fill_lights(pick: Array, preset: Dictionary, view: Rect2, bounds: Rect2,
		player: Node2D, hero_light_count := -1) -> Array:
	var fill: Variant = preset.get("fill")
	if fill == null:
		return pick
	var f: Dictionary = fill
	var grid := float(f.get("grid", 48.0))
	var clear_r := float(f.get("clear", 32.0))
	var max_v := int(f.get("max_in_view", 4))
	var inset := bounds.grow(-24.0).intersection(view.grow(32))
	if inset.size.x < grid or inset.size.y < grid:
		return pick
	var ppos := player.global_position if player else view.get_center()
	var hero_n := hero_light_count
	if hero_n < 0:
		hero_n = 1 if preset.get("player_light") != null else 0
	var remaining := int(preset["max_point_lights"]) - pick.size() - hero_n
	remaining = mini(remaining, max_v)
	if remaining <= 0:
		return pick
	var added := 0
	var y := inset.position.y
	while y <= inset.end.y - 0.5 and added < remaining:
		var x := inset.position.x
		while x <= inset.end.x - 0.5 and added < remaining:
			var pos := Vector2(x, y)
			if not view.grow(8).has_point(pos):
				x += grid
				continue
			var blocked := false
			for c: Dictionary in pick:
				if c["pos"].distance_to(pos) < clear_r:
					blocked = true
					break
			if not blocked and pos.distance_to(ppos) >= clear_r:
				pick.append({"pos": pos, "kind": "tile", "rule": {
					"energy": 1.0, "height": float(f.get("height", 40)),
					"scale": float(f.get("scale", 1.0)), "family": "warm"}, "color": f["color"],
					"family": "warm", "px": 1, "node": null, "local": null, "fill": true})
				added += 1
			x += grid
		y += grid
	return pick


static func index_has_files(map_id: String) -> bool:
	_ensure()
	if not _maps.has(map_id):
		return false
	return true


## Hal: 6 fakkels + 4 vuurschalen worden 4 vuurlichten (noord-fakkels, noord-schalen,
## west, oost). Met 4 heldenlichten blijft het totaal op 8. De lobby (2 fakkels) blijft los.
static func cluster_arena_torches(cands: Array) -> void:
	var torches: Array[int] = []
	var braziers: Array[int] = []
	for i in cands.size():
		var c: Dictionary = cands[i]
		if str(c.get("kind", "")) != "fire":
			continue
		var n: Object = c.get("node")
		if not (n is Sprite2D):
			continue
		var spr := n as Sprite2D
		if spr.texture == null:
			continue
		var path := str(spr.texture.resource_path)
		if path.ends_with("/arena_torch.png"):
			torches.append(i)
		elif path.ends_with("/arena_brazier.png"):
			braziers.append(i)
	if torches.size() != 6 or braziers.size() != 4:
		return
	var groups := {"nt": [], "nb": [], "w": [], "e": []}
	var drop := {}
	for i in torches:
		var p := _arena_anchor(cands[i])
		var key := "nt" if p.y < 100.0 else ("w" if p.x < 240.0 else "e")
		var bucket: Array = groups[key]
		bucket.append(i)
		groups[key] = bucket
		drop[i] = true
	for i in braziers:
		var p := _arena_anchor(cands[i])
		var key := "nb" if p.y < 150.0 else ("w" if p.x < 240.0 else "e")
		var bucket: Array = groups[key]
		bucket.append(i)
		groups[key] = bucket
		drop[i] = true
	var merged: Array = []
	for key in ["nt", "nb", "w", "e"]:
		var ids: Array = groups[key]
		if ids.is_empty():
			return
		var acc: Dictionary = (cands[int(ids[0])] as Dictionary).duplicate()
		var pos: Vector2 = acc["pos"]
		var px := int(acc.get("px", 1))
		for j in range(1, ids.size()):
			var other: Dictionary = cands[int(ids[j])]
			pos += other["pos"]
			px += int(other.get("px", 1))
		acc["pos"] = pos / float(ids.size())
		acc["px"] = px
		acc["n"] = ids.size()
		merged.append(acc)
	if merged.size() != 4:
		return
	var keep: Array = []
	for i in cands.size():
		if not drop.has(i):
			keep.append(cands[i])
	keep.append_array(merged)
	cands.clear()
	cands.append_array(keep)


static func _arena_anchor(c: Dictionary) -> Vector2:
	var spr := c.get("node") as Node2D
	if spr != null and spr.get_parent() is Node2D:
		return (spr.get_parent() as Node2D).global_position
	return spr.global_position if spr != null else Vector2.ZERO


static func verify_index_sample() -> bool:
	_ensure()
	for path: String in ["assets/sprites/player.png", "assets/tiles/dungeon/archief_grijs_tiles.png"]:
		if not _index.has(path):
			return false
		var rec: Dictionary = _index[path]
		if rec.get("normal", false):
			var nf := "res://" + str(rec.get("normal_file", ""))
			if not ResourceLoader.exists(nf):
				return false
	return true
