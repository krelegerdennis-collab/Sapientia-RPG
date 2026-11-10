class_name MapLightingRig
extends Node
## Runtime HD-2D verlichting op één map (data uit res://data/hd2d/). Wordt door MapLighting.apply aangemaakt.

const MapLightingC := preload("res://scripts/map_lighting.gd")
const Hd2dUnmodulated := preload("res://scripts/hd2d_unmodulated.gd")
const W := 384
const H := 216
const PRIO := {"lantern": 9, "fire": 9, "window": 8, "window_in": 8, "candle": 7, "magic": 6,
		"window_tile": 5, "screen": 5, "tile": 4, "magic_small": 3, "book": 3}
const LIGHT_TEX_PATH := "res://assets/hd2d/fx_data/light_soft_128.png"
var _light_tex: Texture2D

var _map: Node
var _map_id := ""
var _phase := "day"
var _preset: Dictionary = {}
var _map_rec: Dictionary = {}
var _fixed := false
var _cands: Array = []
var _light_pool: Array[PointLight2D] = []
var _party_lights: Array[PointLight2D] = []
var _active_hero_lights := -1
var _picked: Array = []
var _cam_center := Vector2.ZERO
var _last_cam := Vector2(-99999, -99999)
var _emissive_sync: Array[Sprite2D] = []
var _overlay_layer: CanvasLayer
var _sun: DirectionalLight2D
var _tint_node: CanvasModulate
var _tint_base := Color.WHITE
var _tween: Tween


func _light_texture() -> Texture2D:
	if _light_tex == null:
		_light_tex = load(LIGHT_TEX_PATH) as Texture2D
	return _light_tex


func _exit_tree() -> void:
	Hd2dUnmodulated.reset_compensation()


func setup(map_root: Node, map_id: String, phase: String) -> void:
	_map = map_root
	_map_id = map_id
	set_process(true)
	_map_rec = MapLightingC.preset_record(map_id)
	if _map_rec.is_empty():
		return
	_fixed = bool(_map_rec.get("fixed", false))
	_phase = _resolve_phase(phase)
	_preset = _map_rec[_phase] as Dictionary
	_build_candidates()
	_apply_full()


func _resolve_phase(phase: String) -> String:
	if _fixed:
		return "day"
	if phase == "night" or phase == "day":
		return phase
	return "day"


func _story_replace_tint() -> bool:
	if not has_node("/root/Story"):
		return false
	var story: Node = get_node("/root/Story")
	if not story.has_method("tint_name"):
		return false
	var tn: String = story.tint_name()
	return tn in ["day", "evening", "night"] and GameState.story_step < MapLightingC.STORY_TINT_FREE_STEP


func _thema_mult() -> Color:
	var mult := Color.WHITE
	for n: CanvasModulate in _map.find_children("*", "CanvasModulate", true, false):
		if n.name == "StoryTint" and _story_replace_tint():
			continue
		mult *= n.color
	return mult


func _apply_full() -> void:
	_wrap_normals()
	_setup_tint()
	_setup_sun()
	_tweak_existing_glows()
	_apply_emissive_and_halos()
	_tile_emissive_layers()
	_rebuild_point_lights(true)
	_apply_shadows()
	_apply_overlays()
	_spawn_motes()
	_connect_camera()
	_register_combat_layers()


func _wrap_normals() -> void:
	for n in _map.find_children("*", "Sprite2D", true, false):
		var s := n as Sprite2D
		s.texture = MapLightingC.with_normals(s.texture)
	for n in _map.find_children("*", "TileMapLayer", true, false):
		var ts := (n as TileMapLayer).tile_set
		if ts == null:
			continue
		for i in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(i))
			if src is TileSetAtlasSource:
				(src as TileSetAtlasSource).texture = MapLightingC.with_normals((src as TileSetAtlasSource).texture)


func _setup_tint() -> void:
	_tint_base = _thema_mult()
	var cms: Array = _map.find_children("*", "CanvasModulate", true, false)
	_tint_node = cms[0] as CanvasModulate if not cms.is_empty() else null
	if _tint_node == null:
		_tint_node = CanvasModulate.new()
		_tint_node.name = "Hd2dTint"
		_map.add_child(_tint_node)
	elif _tint_node.name != "ThemaTint" and _tint_node.name != "StoryTint":
		pass
	_tint_node.color = MapLightingC.col(_preset["ambient"]) * _tint_base
	if _story_replace_tint():
		var st := _map.get_node_or_null("StoryTint") as CanvasModulate
		if st:
			st.color = Color.WHITE


func _setup_sun() -> void:
	if _sun:
		_sun.queue_free()
		_sun = null
	var sun_d: Dictionary = _preset["sun"]
	if float(sun_d.get("energy", 0.0)) <= 0.0:
		return
	_sun = DirectionalLight2D.new()
	_sun.name = "Hd2dSun"
	_sun.color = MapLightingC.col(sun_d["color"])
	_sun.energy = float(sun_d["energy"])
	_sun.height = float(sun_d["height"])
	_sun.rotation_degrees = float(sun_d["rotation_deg"])
	_sun.range_item_cull_mask = Hd2dUnmodulated.WORLD_LIGHT_MASK
	_map.add_child(_sun)


func _register_combat_layers() -> void:
	for n in _map.find_children("TelegraphLayer", "TelegraphLayer", true, false):
		Hd2dUnmodulated.mark(n)
	for n in _map.find_children("RootFxOverlay", "Node2D", true, false):
		Hd2dUnmodulated.mark(n)
	for n in _map.find_children("SomHud", "CanvasLayer", true, false):
		Hd2dUnmodulated.mark_descendants(n)


func _tweak_existing_glows() -> void:
	for n in _map.find_children("*", "Sprite2D", true, false):
		var s := n as Sprite2D
		if (s.name == "Aura" or s.name == "Glow") and s.material is CanvasItemMaterial:
			(s.material as CanvasItemMaterial).light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var wl := _map.get_node_or_null("WoudLantaarn")
	if wl and _preset.get("player_light") != null:
		(wl as CanvasItem).visible = false


func _apply_emissive_and_halos() -> void:
	_emissive_sync.clear()
	var em: Dictionary = _preset["emissive"]
	var done := {}
	var view := _view_rect()
	for c: Dictionary in _cands:
		if c.get("local") == null:
			continue
		var s: Sprite2D = c["node"]
		if done.has(s):
			continue
		done[s] = true
		var k := float(em.get(c["kind"], 0.0))
		if k <= 0.0:
			continue
		if not view.grow(64).has_point(c["pos"]):
			continue
		_emissive_child(s, k)
		_halo_sprite(s, c)
	for n in _map.find_children("*", "Sprite2D", true, false):
		var s := n as Sprite2D
		if done.has(s) or s.texture == null:
			continue
		var r := MapLightingC.rule_for_texture(s.texture)
		if r.is_empty() or not (r["kind"] in ["hero", "eyes"]):
			continue
		var k2 := float(em.get(r["kind"], 0.0))
		if k2 > 0.0:
			_emissive_child(s, k2)


func _emissive_child(s: Sprite2D, k: float) -> void:
	var bt := MapLightingC.base_texture(s.texture)
	var path := bt.resource_path if bt and not (bt is AtlasTexture) else ""
	var e := MapLightingC.hd_texture(path, "_e.png")
	if e == null and bt is AtlasTexture:
		var at := bt as AtlasTexture
		if at.atlas:
			path = MapLightingC.base_texture(at.atlas).resource_path
			e = MapLightingC.hd_texture(path, "_e.png")
	if e == null:
		return
	var tag := "_hd2d_em"
	if s.get_node_or_null(tag):
		return
	var o := Sprite2D.new()
	o.name = tag
	o.texture = e
	o.hframes = s.hframes
	o.vframes = s.vframes
	o.frame = s.frame
	o.centered = s.centered
	o.offset = s.offset
	o.flip_h = s.flip_h
	o.region_enabled = s.region_enabled
	o.region_rect = s.region_rect
	o.material = MapLightingC.unshaded_mat(CanvasItemMaterial.BLEND_MODE_MIX)
	o.modulate = Color(k, k, k) if k < 1.0 else Color.WHITE
	s.add_child(o)
	if s.hframes > 1 or s.vframes > 1:
		_emissive_sync.append(s)


func _halo_sprite(s: Sprite2D, c: Dictionary) -> void:
	var r: Dictionary = c["rule"]
	var hk := float(_preset["halo"])
	if hk <= 0.0 or r.get("halo") == null:
		return
	var add := MapLightingC.unshaded_mat(CanvasItemMaterial.BLEND_MODE_ADD)
	if str(r["halo"]) == "house_g":
		var bt := MapLightingC.base_texture(s.texture)
		var g := MapLightingC.hd_texture(bt.resource_path if bt else "", "_g.png")
		if g == null:
			return
		var gs := Sprite2D.new()
		gs.name = "_hd2d_halo"
		gs.texture = g
		gs.centered = s.centered
		gs.offset = s.offset - (Vector2(8, 8) if not s.centered else Vector2.ZERO)
		gs.material = add
		gs.modulate = Color(1, 1, 1, hk * 0.55)
		s.add_child(gs)
		return
	var fam: String = str(c["family"])
	if r["kind"] in ["lantern", "fire", "candle"]:
		fam = "warm"
	var size := int(r.get("halo_size", 24))
	var h := Sprite2D.new()
	h.name = "_hd2d_halo"
	var halo_path := "res://assets/hd2d/fx/halo_%s_%d.png" % [fam, size]
	if ResourceLoader.exists(halo_path):
		h.texture = load(halo_path)
	var at: Vector2 = c["local"]
	if c.get("halo_at") != null:
		var fi := MapLightingC.frame_info(s)
		at = fi["tl"] + Vector2(c["halo_at"][0], c["halo_at"][1])
	h.position = at
	h.material = add
	h.modulate = Color(1, 1, 1, hk * (0.6 if size >= 48 else 0.7))
	s.add_child(h)


func _tile_emissive_layers() -> void:
	var em: Dictionary = _preset["emissive"]
	var k := float(em.get("tile", 0.0))
	var kw := float(em.get("window_tile", 0.0))
	for n in _map.find_children("*", "TileMapLayer", true, false):
		var tl := n as TileMapLayer
		if tl.name.ends_with("_Hd2dEmissive"):
			continue
		_tile_emissive_one(tl, k, kw)


func _tile_emissive_one(tl: TileMapLayer, k: float, kw: float) -> void:
	if tl.tile_set == null:
		return
	var ts2 := TileSet.new()
	ts2.tile_size = tl.tile_set.tile_size
	var any := false
	var cell_map := {}
	for i in tl.tile_set.get_source_count():
		var sid := tl.tile_set.get_source_id(i)
		var src := tl.tile_set.get_source(sid)
		if not (src is TileSetAtlasSource):
			continue
		var base := MapLightingC.base_texture((src as TileSetAtlasSource).texture)
		var path := base.resource_path if base else ""
		var r := MapLightingC.rule_for_path(path)
		if r.is_empty():
			continue
		var kk := kw if r["kind"] == "window_tile" else k
		if kk <= 0.0:
			continue
		var e := MapLightingC.hd_texture(path, "_e.png")
		if e == null:
			continue
		var ns := TileSetAtlasSource.new()
		ns.texture = e
		ns.texture_region_size = (src as TileSetAtlasSource).texture_region_size
		ns.use_texture_padding = false
		var cells := {}
		for tc: Dictionary in r["tile_cells"]:
			cells[Vector2i(tc["cell"][0], tc["cell"][1])] = true
			ns.create_tile(Vector2i(tc["cell"][0], tc["cell"][1]))
		ts2.add_source(ns, sid)
		cell_map[sid] = cells
		any = true
	if not any:
		return
	var ov := TileMapLayer.new()
	ov.name = tl.name + "_Hd2dEmissive"
	ov.tile_set = ts2
	ov.z_index = tl.z_index
	ov.material = MapLightingC.unshaded_mat(CanvasItemMaterial.BLEND_MODE_MIX)
	ov.modulate = Color(k, k, k) if k < 1.0 else Color.WHITE
	var cnt := 0
	for cell in tl.get_used_cells():
		var sid := tl.get_cell_source_id(cell)
		if cell_map.has(sid) and cell_map[sid].has(tl.get_cell_atlas_coords(cell)):
			ov.set_cell(cell, sid, tl.get_cell_atlas_coords(cell))
			cnt += 1
	if cnt == 0:
		ov.free()
		return
	tl.add_sibling(ov)
	ov.position = tl.position


func _build_candidates() -> void:
	_cands.clear()
	for n in _map.find_children("*", "Sprite2D", true, false):
		var s := n as Sprite2D
		if s.texture == null or not s.is_visible_in_tree():
			continue
		var r := MapLightingC.rule_for_texture(s.texture)
		if r.is_empty() or float(r.get("energy", 0)) <= 0.0:
			continue
		var fi := MapLightingC.frame_info(s)
		for an: Dictionary in r["anchors"]:
			var loc: Vector2 = fi["tl"] + Vector2(an["offset"][0], an["offset"][1])
			if s.flip_h:
				loc.x = -loc.x
			_cands.append({"pos": s.to_global(loc), "kind": r["kind"], "rule": r, "color": r["color"],
					"family": r["family"], "px": int(an["px"]), "node": s, "local": loc,
					"halo_at": an.get("halo_at", null)})
	for n in _map.find_children("*", "TileMapLayer", true, false):
		var tl := n as TileMapLayer
		if tl.tile_set == null or not tl.is_visible_in_tree() or tl.name.ends_with("_Hd2dEmissive"):
			continue
		for i in tl.tile_set.get_source_count():
			var sid := tl.tile_set.get_source_id(i)
			var src := tl.tile_set.get_source(sid)
			if not (src is TileSetAtlasSource):
				continue
			var base := MapLightingC.base_texture((src as TileSetAtlasSource).texture)
			var r := MapLightingC.rule_for_path(base.resource_path if base else "")
			if r.is_empty() or r["tile_cells"].is_empty():
				continue
			var by := {}
			for tc: Dictionary in r["tile_cells"]:
				by[Vector2i(tc["cell"][0], tc["cell"][1])] = tc
			for cell in tl.get_used_cells():
				if tl.get_cell_source_id(cell) != sid:
					continue
				var ac := tl.get_cell_atlas_coords(cell)
				if not by.has(ac):
					continue
				var td: Dictionary = by[ac]
				var gp := tl.to_global(tl.map_to_local(cell) - Vector2(8, 8) + Vector2(td["offset"][0], td["offset"][1]))
				_cands.append({"pos": gp, "kind": r["kind"], "rule": r, "color": td["color"], "family": td["family"],
						"px": int(td["px"]), "node": tl, "local": null})
	MapLightingC.cluster_tile_lights(_cands)


func _view_rect() -> Rect2:
	var cam := _active_camera()
	if cam:
		return Rect2(cam.get_screen_center_position() - Vector2(W, H) * 0.5, Vector2(W, H))
	return Rect2(_cam_center - Vector2(W, H) * 0.5, Vector2(W, H))


func _active_camera() -> Camera2D:
	var p := _player()
	if p and p.has_node("Camera2D"):
		var c := p.get_node("Camera2D") as Camera2D
		if c.is_current():
			return c
	for n in _map.find_children("*", "Camera2D", true, false):
		var c2 := n as Camera2D
		if c2.is_current():
			return c2
	return null


func _player() -> Node2D:
	if _map.get("player") is Node2D:
		return _map.player as Node2D
	return _map.get_node_or_null("Objects/Player") as Node2D


func _connect_camera() -> void:
	var cam := _active_camera()
	if cam:
		_last_cam = cam.get_screen_center_position()
	_cam_center = _last_cam


func _process(_delta: float) -> void:
	for s in _emissive_sync:
		var o := s.get_node_or_null("_hd2d_em") as Sprite2D
		if o:
			o.frame = s.frame
	var cam := _active_camera()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	if c.distance_to(_last_cam) >= 32.0:
		_last_cam = c
		_cam_center = c
		_rebuild_point_lights(false)
	var flick: Dictionary = _preset.get("flicker", {})
	var t := Time.get_ticks_msec() * 0.01
	for i in mini(_picked.size(), _light_pool.size()):
		var l := _light_pool[i]
		if not l.enabled:
			continue
		var cnd: Dictionary = _picked[i]
		var amp := float(flick.get(cnd["kind"], 0.0))
		var base_e: float = cnd.get("base_energy", l.energy)
		l.energy = base_e * (1.0 + amp * (0.6 * sin(t * 1.7 + cnd["pos"].x) + 0.4 * sin(t * 3.1 + cnd["pos"].y)))
	Hd2dUnmodulated.apply_compensation(Hd2dUnmodulated.canvas_tint_on_map(_map))
	var hero_live := mini(_party_light_budget(), _party_light_bodies().size())
	if hero_live != _active_hero_lights and _preset.get("player_light") != null:
		_active_hero_lights = hero_live
		_sync_party_lights(false)
		_rebuild_point_lights(false)


func _rebuild_point_lights(first: bool) -> void:
	var lights: Dictionary = _preset["lights"]
	var view := _view_rect()
	var pick: Array = []
	for c: Dictionary in _cands:
		var e := float(lights.get(c["kind"], 0.0))
		if e <= 0.0 or not view.grow(48).has_point(c["pos"]):
			continue
		pick.append(c)
	pick = MapLightingC.dedupe_lights(pick)
	var hero_n := _party_light_budget()
	pick = MapLightingC.add_fill_lights(pick, _preset, view, _room_bounds(), _player(), hero_n)
	var centre := view.get_center()
	pick.sort_custom(func(a, b):
		var pa: int = PRIO.get(a["kind"], 1)
		var pb: int = PRIO.get(b["kind"], 1)
		if pa != pb:
			return pa > pb
		return a["pos"].distance_to(centre) < b["pos"].distance_to(centre))
	var budget := int(_preset["max_point_lights"]) - hero_n
	_picked = pick.slice(0, budget) as Array
	if first:
		for l in _light_pool:
			l.queue_free()
		_light_pool.clear()
		for old in _map.find_children("Hd2dPointLight*", "PointLight2D", true, false):
			old.queue_free()
		for cnd: Dictionary in _picked:
			_light_pool.append(_spawn_point_light(cnd))
		_sync_party_lights(true)
		_active_hero_lights = mini(_party_light_budget(), _party_light_bodies().size())
	else:
		while _light_pool.size() < _picked.size():
			_light_pool.append(_make_point_light())
		for i in _light_pool.size():
			var l := _light_pool[i]
			if i < _picked.size():
				_configure_point_light(l, _picked[i])
				l.enabled = true
			else:
				l.enabled = false
		_sync_party_lights(false)


func _spawn_point_light(cnd: Dictionary) -> PointLight2D:
	var l := _make_point_light()
	_configure_point_light(l, cnd)
	_map.add_child(l)
	return l


func _make_point_light() -> PointLight2D:
	var l := PointLight2D.new()
	l.name = "Hd2dPointLight"
	l.texture = _light_texture()
	l.shadow_enabled = false
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.range_item_cull_mask = Hd2dUnmodulated.WORLD_LIGHT_MASK
	return l


func _configure_point_light(l: PointLight2D, cnd: Dictionary) -> void:
	var r: Dictionary = cnd["rule"]
	var lights: Dictionary = _preset["lights"]
	var e := float(lights[cnd["kind"]]) * float(r["energy"])
	var colr: Array = cnd["color"]
	if cnd["kind"] == "window_in":
		colr = _preset.get("window_in_color", [1.0, 1.0, 1.0])
	elif cnd["kind"] == "window":
		colr = [1.0, 0.72, 0.42]
	elif cnd["kind"] == "lantern":
		colr = [1.0, 0.70, 0.40]
	var sc_ := float(r["scale"])
	if cnd.has("n"):
		sc_ *= clampf(0.8 + 0.1 * float(cnd["n"]), 0.8, 1.6)
		e *= clampf(sqrt(float(cnd["px"]) / 6.0), 0.6, 1.5)
	l.global_position = cnd["pos"]
	l.color = MapLightingC.col(colr)
	l.energy = e
	l.height = float(r["height"])
	l.texture_scale = sc_
	cnd["base_energy"] = e


func _party_light_budget() -> int:
	if _preset.get("player_light") == null:
		return 0
	return mini(4, GameState.party.size())


func _party_light_bodies() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var objects := _map.get_node_or_null("Objects") as Node2D
	if objects == null:
		var p := _player()
		return [p] if p else []
	var p := _player()
	if p:
		out.append(p)
	var allies: Array[Node2D] = []
	for c in objects.get_children():
		if not (c is Node2D) or c == p:
			continue
		var n := c as Node2D
		if c.name.begins_with("Ally_") or c.name.begins_with("SomAlly") or c.name.begins_with("CoopAvatar"):
			allies.append(n)
	allies.sort_custom(func(a, b): return str(a.name) < str(b.name))
	out.append_array(allies)
	return out


func _clear_party_lights() -> void:
	for n in _map.find_children("Hd2dPlayerLight", "PointLight2D", true, false):
		n.queue_free()
	for l in _party_lights:
		if is_instance_valid(l):
			l.queue_free()
	_party_lights.clear()


func _configure_party_light(l: PointLight2D) -> void:
	var pl: Dictionary = _preset["player_light"]
	l.texture = _light_texture()
	l.shadow_enabled = false
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.range_item_cull_mask = Hd2dUnmodulated.WORLD_LIGHT_MASK
	l.color = MapLightingC.col(pl["color"])
	l.energy = float(pl["energy"])
	l.height = float(pl["height"])
	l.texture_scale = float(pl["scale"])


func _sync_party_lights(first: bool) -> void:
	if _preset.get("player_light") == null:
		if first:
			_clear_party_lights()
		return
	var want := mini(_party_light_budget(), _party_light_bodies().size())
	if first:
		_clear_party_lights()
	while _party_lights.size() < want:
		var l := PointLight2D.new()
		l.name = "Hd2dPartyLight"
		_configure_party_light(l)
		_party_lights.append(l)
	var bodies := _party_light_bodies()
	for i in want:
		var body := bodies[i]
		var l := _party_lights[i]
		if l.get_parent() != body:
			if l.get_parent():
				l.reparent(body)
			else:
				body.add_child(l)
		l.position = Vector2(0, -6)
		l.enabled = true
	for j in range(want, _party_lights.size()):
		_party_lights[j].enabled = false


func _apply_shadows() -> void:
	var sa := float(_preset["shadow_alpha"])
	for n in _map.find_children("*", "Sprite2D", true, false):
		var s := n as Sprite2D
		var bt := MapLightingC.base_texture(s.texture)
		if bt and "schaduw" in bt.resource_path:
			s.self_modulate.a *= sa


func _apply_overlays() -> void:
	if _overlay_layer:
		_overlay_layer.queue_free()
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "Hd2dOverlay"
	_overlay_layer.layer = 10
	var hz_d: Variant = _preset.get("haze")
	if hz_d != null:
		var hz := TextureRect.new()
		hz.texture = load("res://assets/hd2d/fx/haze_384x216.png")
		var h: Dictionary = hz_d
		hz.modulate = Color(h["color"][0], h["color"][1], h["color"][2], h["alpha"])
		_overlay_layer.add_child(hz)
	if float(_preset["vignette"]) > 0.0:
		var vg := TextureRect.new()
		vg.texture = load("res://assets/hd2d/fx/vignette_384x216.png")
		vg.modulate = Color(1, 1, 1, float(_preset["vignette"]))
		_overlay_layer.add_child(vg)
	_map.add_child(_overlay_layer)


func _spawn_motes() -> void:
	var mo: Variant = _preset.get("motes")
	if mo == null:
		return
	var m: Dictionary = mo
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_map_id)
	var view := _view_rect()
	var area := Rect2(view.position + Vector2(20, 40), Vector2(W - 40, H - 60)).intersection(_room_bounds().grow(-16))
	if area.size.x <= 0 or area.size.y <= 0:
		return
	for i in int(m["count"]):
		var f := Sprite2D.new()
		f.name = "Hd2dMote"
		var spark := "res://assets/hd2d/fx/spark_%s_8.png" % m["family"]
		if ResourceLoader.exists(spark):
			f.texture = load(spark)
		f.material = MapLightingC.unshaded_mat(CanvasItemMaterial.BLEND_MODE_ADD)
		f.modulate = Color(1, 1, 1, float(m["alpha"]))
		f.position = area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		f.z_index = 5
		_map.add_child(f)


func _room_bounds() -> Rect2:
	var b := Rect2()
	var first := true
	for n in _map.find_children("*", "TileMapLayer", true, false):
		var tl := n as TileMapLayer
		if tl.tile_set == null or not tl.is_visible_in_tree():
			continue
		var r := tl.get_used_rect()
		if r.size == Vector2i.ZERO:
			continue
		var ts := tl.tile_set.tile_size
		var rr := Rect2(tl.to_global(Vector2(r.position * ts)), Vector2(r.size * ts))
		b = rr if first else b.merge(rr)
		first = false
	if first:
		var p := _player()
		if p:
			b = Rect2(p.global_position - Vector2(W, H) / 2, Vector2(W, H))
	return b


func set_phase(phase: String, tween_sec: float) -> void:
	if _map_rec.is_empty() or _fixed:
		return
	var p := _resolve_phase(phase)
	if p == _phase and tween_sec > 0.0:
		return
	_phase = p
	_preset = _map_rec[_phase] as Dictionary
	if tween_sec <= 0.0:
		if _tint_node:
			_tint_node.color = MapLightingC.col(_preset["ambient"]) * _tint_base
		_apply_sun_energy(float(_preset["sun"]["energy"]))
		_apply_emissive_and_halos()
		_rebuild_point_lights(true)
		_apply_overlays()
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var target := MapLightingC.col(_preset["ambient"]) * _tint_base
	if _tint_node:
		_tween.tween_property(_tint_node, "color", target, tween_sec)
	if _sun:
		_tween.parallel().tween_property(_sun, "energy", float(_preset["sun"]["energy"]), tween_sec)
	_apply_emissive_and_halos()
	_rebuild_point_lights(true)
	_apply_overlays()


func _apply_sun_energy(e: float) -> void:
	if _sun:
		_sun.energy = e
	elif e > 0.0:
		_setup_sun()


func enabled_point_lights() -> int:
	var n := 0
	for l in _light_pool:
		if l.enabled:
			n += 1
	for l in _party_lights:
		if is_instance_valid(l) and l.enabled:
			n += 1
	return n


func count_enabled_directional_lights() -> int:
	var n := 0
	for l in _map.find_children("*", "DirectionalLight2D", true, false):
		var d := l as DirectionalLight2D
		if d.enabled and d.energy > 0.001:
			n += 1
	return n
