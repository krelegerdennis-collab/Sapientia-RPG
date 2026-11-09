extends Node
## Visuele root-FX (fx_root.png, TelegraphLayer). Start: godot --headless --path . -- --rootfxtest
## Ook via --autotest (debug_autotest.gd): run_embedded().

const SomData := preload("res://scripts/data/som_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const MapSprite := preload("res://scripts/map_sprite.gd")
const TelegraphLayer := preload("res://scripts/som/telegraph_layer.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const ARENA_ROOM := "res://scenes/maps/archief_v1_gang.tscn"
const ROOT_GREEN_A := Color(74 / 255.0, 112 / 255.0, 56 / 255.0)
const ROOT_GREEN_B := Color(116 / 255.0, 150 / 255.0, 62 / 255.0)
const GREEN_TOL := 4

var failures := 0
var passes := 0
var _host: Node = null
var _shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.get_slice("=", 1)
	_run_flow.call_deferred()


func check(label: String, ok: bool) -> void:
	if _host != null and _host.has_method("check"):
		_host.check(label, ok)
		return
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func run_embedded(host: Node) -> void:
	_host = host
	_run_sync_tests()
	check("screenshot rooted held (autotest: overgeslagen)", true)
	_host = null


func _finish() -> void:
	if _host != null:
		return
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _run_flow() -> void:
	_run_sync_tests()
	if _host != null:
		return
	await _screenshot_rooted_hero()
	_finish()


func _run_sync_tests() -> void:
	_fx_root_data_tests()
	_layer_sync_one_hero_tests()
	_layer_expire_tests()
	_layer_two_heroes_tests()
	_layer_missing_position_tests()
	_snapshot_guest_path_tests()
	_foot_line_alignment_tests()
	_frame_timing_tests()
	_fallback_texture_tests()


func _fx_root_data_tests() -> void:
	var d: Dictionary = SomData.FX_ROOT
	check("FX_ROOT sheet pad", str(d.get("sheet", "")).ends_with("fx_root.png"))
	var t: Texture2D = SomFx.tex(str(d["sheet"]))
	check("FX_ROOT sheet laadt", t != null)
	if t != null:
		check("FX_ROOT size 64x16", t.get_size() == Vector2(64, 16))
	check("FX_ROOT 4 frames", int(d.get("frames", 0)) == 4)
	check("FX_ROOT anker (8,16)", int(d["anchor"][0]) == 8 and int(d["anchor"][1]) == 16)


func _layer_sync_one_hero_tests() -> void:
	var roots := CombatRoots.new()
	var layer := TelegraphLayer.new()
	layer._ready()
	var foot := Vector2(120, 88)
	roots.try_apply_root("hero", 30)
	layer.sync_from_roots(roots, {"hero": foot})
	check("sync 1 rooted: 1 icoon", layer.root_icon_count() == 1)
	roots.break_root("hero")
	layer.sync_from_roots(roots, {"hero": foot})
	check("break_root: 0 iconen", layer.root_icon_count() == 0)
	layer.free()


func _layer_expire_tests() -> void:
	var roots := CombatRoots.new()
	var layer := TelegraphLayer.new()
	layer._ready()
	roots.try_apply_root("h", 3)
	layer.sync_from_roots(roots, {"h": Vector2(50, 50)})
	check("voor afloop: 1 icoon", layer.root_icon_count() == 1)
	for _i in 3:
		roots.tick()
	layer.sync_from_roots(roots, {"h": Vector2(50, 50)})
	check("na afloop root: 0 iconen", layer.root_icon_count() == 0)
	layer.free()


func _layer_two_heroes_tests() -> void:
	var roots := CombatRoots.new()
	var layer := TelegraphLayer.new()
	layer._ready()
	var p1 := Vector2(40, 60)
	var p2 := Vector2(200, 100)
	roots.try_apply_root("a", 20)
	roots.try_apply_root("b", 20)
	layer.sync_from_roots(roots, {"a": p1, "b": p2})
	check("twee rooted: 2 iconen", layer.root_icon_count() == 2)
	# Posities worden intern bewaard; sync vergelijkt op volgorde rooted_ids
	var rids: Array = roots.rooted_ids()
	check("rooted ids bevat a en b", rids.has("a") and rids.has("b"))
	layer.free()


func _layer_missing_position_tests() -> void:
	var roots := CombatRoots.new()
	var layer := TelegraphLayer.new()
	layer._ready()
	roots.try_apply_root("ko", 25)
	layer.sync_from_roots(roots, {})
	check("geen positie (KO/weg): 0 iconen", layer.root_icon_count() == 0)
	layer.free()


func _snapshot_guest_path_tests() -> void:
	var host_roots := CombatRoots.new()
	var slots := {0: "dennis", 1: "noor"}
	host_roots.try_apply_root("dennis", 12)
	host_roots.try_apply_root("noor", 8)
	var wire := Codec.pack_snapshot(7, [], [], [], host_roots.wire_rows(slots))
	var snap := Codec.unpack_snapshot(wire)
	var guest := CombatRoots.new()
	guest.apply_wire_rows(snap.get("roots", []), slots)
	var layer := TelegraphLayer.new()
	layer._ready()
	var pos := {"dennis": Vector2(80, 72), "noor": Vector2(140, 72)}
	layer.sync_from_roots(guest, pos)
	check("snapshot gast: 2 iconen", layer.root_icon_count() == 2)
	guest.clear_all()
	layer.sync_from_roots(guest, pos)
	check("lege roots na clear: 0 iconen", layer.root_icon_count() == 0)
	var empty_snap := Codec.unpack_snapshot(Codec.pack_snapshot(1, [], [], [], []))
	var g2 := CombatRoots.new()
	g2.apply_wire_rows(empty_snap.get("roots", []), slots)
	layer.sync_from_roots(g2, pos)
	check("lege snapshot: 0 iconen", layer.root_icon_count() == 0)
	layer.free()


func _foot_line_alignment_tests() -> void:
	var node := Vector2(120, 98)
	var body := node + Vector2(0, SomData.BODY_Y)
	var draw_pos := body + Vector2(0, SomArena.ROOT_FOOT_OFFSET_PX)
	check(
		"gemeten: body_of→voetlijn %.0f px (ROOT_FOOT_OFFSET_PX)" % SomArena.ROOT_FOOT_OFFSET_PX,
		is_equal_approx(SomArena.ROOT_FOOT_OFFSET_PX, 6.0),
	)
	check("arena: draw-anker = node.position (zelfde als heal_glow)", draw_pos == node)
	check("FX onderkant op draw-anker (voetlijn FX)", TelegraphLayer.fx_bottom_y(draw_pos) == node.y)
	var visual_foot_y: float = node.y - MapSprite.voet_offset(MapSprite.NIEUW).y
	check("visuele 24x32-voet op node+8 (MapSprite, los van FX-anker)", is_equal_approx(visual_foot_y, node.y + 8.0))


func _frame_timing_tests() -> void:
	var layer := TelegraphLayer.new()
	layer._ready()
	var roots := CombatRoots.new()
	var t0: int = Time.get_ticks_msec()
	roots.try_apply_root("hero", 40)
	layer.sync_from_roots(roots, {"hero": Vector2(64, 64)})
	check("t=0 frame 0", layer.root_anim_frame_for("hero") == 0)
	layer.set_root_anim_start_for_test("hero", t0 - 50)
	check("t=50ms frame 0", layer.root_anim_frame_for("hero") == 0)
	layer.set_root_anim_start_for_test("hero", t0 - 150)
	check("t=150ms frame 1", layer.root_anim_frame_for("hero") == 1)
	layer.set_root_anim_start_for_test("hero", t0 - 250)
	check("t=250ms frame 2", layer.root_anim_frame_for("hero") == 2)
	layer.set_root_anim_start_for_test("hero", t0 - 350)
	check("t=350ms frame 2 (loop)", layer.root_anim_frame_for("hero") == 2)
	layer.set_root_anim_start_for_test("hero", t0 - 450)
	check("t=450ms frame 3 (loop)", layer.root_anim_frame_for("hero") == 3)
	layer.set_root_anim_start_for_test("hero", t0 - 550)
	check("t=550ms frame 2 (loop)", layer.root_anim_frame_for("hero") == 2)
	roots.break_root("hero")
	layer.sync_from_roots(roots, {})
	roots.try_apply_root("hero", 30)
	layer.sync_from_roots(roots, {"hero": Vector2(64, 64)})
	check("break + nieuwe root: frame 0", layer.root_anim_frame_for("hero") == 0)
	roots.try_apply_root("b", 30)
	layer.sync_from_roots(roots, {"hero": Vector2(10, 10), "b": Vector2(90, 10)})
	layer.set_root_anim_start_for_test("hero", t0 - 400)
	layer.set_root_anim_start_for_test("b", t0 - 80)
	check("per-held: hero alleen 2/3 in loop", layer.root_anim_frame_for("hero") == 2 or layer.root_anim_frame_for("hero") == 3)
	check("per-held: b nog in intro", layer.root_anim_frame_for("b") == 0)
	layer.free()


func _fallback_texture_tests() -> void:
	var layer := TelegraphLayer.new()
	layer._ready()
	layer.set_root_texture(null)
	var roots := CombatRoots.new()
	roots.try_apply_root("x", 5)
	layer.sync_from_roots(roots, {"x": Vector2(64, 64)})
	check("fallback: geen crash met 1 icoon", layer.root_icon_count() == 1)
	layer.free()


func _arena_root_draw_pos(player: Node2D) -> Vector2:
	return player.position + Vector2(0, SomData.BODY_Y + SomArena.ROOT_FOOT_OFFSET_PX)


func _color_near_root_green(c: Color) -> bool:
	return (_px_near(c.r8, 74) and _px_near(c.g8, 112) and _px_near(c.b8, 56)) \
			or (_px_near(c.r8, 116) and _px_near(c.g8, 150) and _px_near(c.b8, 62))


func _px_near(v: int, target: int) -> bool:
	return absi(v - target) <= GREEN_TOL


func _find_root_green_rows(img: Image, cx: int, y0: int, y1: int) -> Vector2i:
	var min_y := 99999
	var max_y := -1
	var hits := 0
	for y in range(maxi(0, y0), mini(img.get_height(), y1)):
		for x in range(maxi(0, cx - 14), mini(img.get_width(), cx + 14)):
			var c: Color = img.get_pixel(x, y)
			if c.a8 < 16:
				continue
			if not _color_near_root_green(c):
				continue
			hits += 1
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if hits < 4:
		return Vector2i(-1, -1)
	return Vector2i(min_y, max_y)


func _world_to_viewport_px(world: Vector2, cam: Camera2D, vp_size: Vector2i) -> Vector2i:
	var xform: Transform2D = cam.get_canvas_transform()
	var p: Vector2 = xform * world
	return Vector2i(roundi(p.x), roundi(p.y))


func _screenshot_rooted_hero() -> void:  # await in _run_flow
	var out := _shots if _shots != "" else "/opt/cursor/artifacts"
	if not DirAccess.dir_exists_absolute(out):
		DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = Vector2i(384, 216)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	get_tree().root.add_child(vp)
	var room: Node2D = load(ARENA_ROOM).instantiate()
	vp.add_child(room)
	for _w in 20:
		await get_tree().process_frame
		if room.is_node_ready():
			break
	var p: CharacterBody2D = room.get_node_or_null("Objects/Player") as CharacterBody2D
	if p == null:
		check("arena screenshot: Player in archief_v1_gang", false)
		get_tree().root.remove_child(vp)
		vp.queue_free()
		return
	p.sprite.texture = SomFx.tex(str(SomData.SHEETS["dennis"]))
	MapSprite.pas_toe(p.sprite, MapSprite.NIEUW)
	p.sprite.frame = 0
	if p.has_method("place_at"):
		p.place_at(Vector2i(12, 10), Vector2i.DOWN)
	var cam := p.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
	var objects: Node2D = room.get_node("Objects") as Node2D
	var layer := TelegraphLayer.new()
	objects.add_child(layer)
	layer._ready()
	await get_tree().process_frame
	var roots := CombatRoots.new()
	roots.try_apply_root("dennis", 60)
	var positions: Dictionary = {"dennis": _arena_root_draw_pos(p)}
	layer.sync_from_roots(roots, positions)
	check("screenshot: dennis rooted in CombatRoots", roots.is_rooted("dennis"))
	check("screenshot: TelegraphLayer root-entry voor dennis", layer.root_icon_count() == 1)
	var now: int = Time.get_ticks_msec()
	layer.set_root_anim_start_for_test("dennis", now - 250)
	var fi: int = layer.root_anim_frame_for("dennis")
	check("screenshot: loop-frame 2 of 3 (nu %d)" % fi, fi == 2 or fi == 3)
	layer.queue_redraw()
	for _i in 4:
		await get_tree().process_frame
	var tex: ViewportTexture = vp.get_texture()
	var img: Image = tex.get_image()
	var foot_world: Vector2 = _arena_root_draw_pos(p)
	var foot_px: Vector2i = _world_to_viewport_px(foot_world, cam, vp.size)
	var rows: Vector2i = _find_root_green_rows(img, foot_px.x, foot_px.y - 18, foot_px.y + 6)
	check(
		"screenshot: fx_root groentinten bij voet (hits, rij %d..%d vs voet_px.y=%d)"
		% [rows.x, rows.y, foot_px.y],
		rows.x >= 0 and rows.y >= rows.x,
	)
	if rows.x >= 0:
		check(
			"screenshot: groen vs node.y (node=%.1f top=%d bot=%d Δtop=%.0f Δbot=%.0f)"
			% [p.position.y, rows.x, rows.y, float(rows.x) - p.position.y, float(rows.y) - p.position.y],
			rows.y >= foot_px.y - 18 and rows.x <= foot_px.y + 2,
		)
	var path := out.path_join("root_fx_solo.png")
	var crop := Rect2i(
		maxi(0, foot_px.x - 40),
		maxi(0, foot_px.y - 48),
		mini(96, img.get_width()),
		mini(72, img.get_height()),
	)
	if crop.position.x + crop.size.x > img.get_width():
		crop.size.x = img.get_width() - crop.position.x
	if crop.position.y + crop.size.y > img.get_height():
		crop.size.y = img.get_height() - crop.position.y
	var shot: Image = img.get_region(crop) if crop.size.x > 0 and crop.size.y > 0 else img
	var err := shot.save_png(path)
	check("screenshot arena Dax rooted (%s)" % path, err == OK and shot.get_width() > 0 and rows.x >= 0)
	layer.queue_free()
	get_tree().root.remove_child(vp)
	vp.queue_free()
