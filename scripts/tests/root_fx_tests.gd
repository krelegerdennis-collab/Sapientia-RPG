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
const DIFF_MIN_PIXELS := 150
const DIFF_MIN_ART_MASK := 90
const DIFF_COLOR_TOL := 3

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
	var map_foot_y: float = node.y - MapSprite.voet_offset(MapSprite.NIEUW).y
	check(
		"gemeten: body_of→MapSprite-voet %.0f px (ROOT_FOOT_OFFSET_PX)" % SomArena.ROOT_FOOT_OFFSET_PX,
		is_equal_approx(SomArena.ROOT_FOOT_OFFSET_PX, 14.0),
	)
	check("arena: draw-anker op node+8 (MapSprite zool)", is_equal_approx(draw_pos.y, map_foot_y))
	check("FX onderkant op MapSprite-voetlijn", TelegraphLayer.fx_bottom_y(draw_pos) == map_foot_y)


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


func _pixels_differ(a: Color, b: Color) -> bool:
	if absi(int(a.a8) - int(b.a8)) > DIFF_COLOR_TOL:
		return true
	return absi(int(a.r8) - int(b.r8)) > DIFF_COLOR_TOL \
			or absi(int(a.g8) - int(b.g8)) > DIFF_COLOR_TOL \
			or absi(int(a.b8) - int(b.b8)) > DIFF_COLOR_TOL


func _is_fx_diff_pixel(with_c: Color, without_c: Color) -> bool:
	if absi(int(with_c.a8) - int(without_c.a8)) >= 8:
		return true
	return _pixels_differ(with_c, without_c)


func _art_mask_diff_count(
	with_root: Image,
	without_root: Image,
	anchor_in_crop: Vector2i,
	frame_idx: int,
) -> int:
	var d: Dictionary = SomData.FX_ROOT
	var cw: int = int(d["cell"][0])
	var ch: int = int(d["cell"][1])
	var ax: int = int(d["anchor"][0])
	var ay: int = int(d["anchor"][1])
	var tex: Texture2D = SomFx.tex(str(d.get("sheet", "")))
	if tex == null:
		return 0
	var art: Image = tex.get_image()
	var count := 0
	for ly in ch:
		for lx in cw:
			if art.get_pixel(frame_idx * cw + lx, ly).a8 < 16:
				continue
			var sx: int = anchor_in_crop.x + lx - ax
			var sy: int = anchor_in_crop.y + ly - ay
			if sx < 0 or sy < 0 or sx >= with_root.get_width() or sy >= with_root.get_height():
				continue
			var ca: Color = with_root.get_pixel(sx, sy)
			var cb: Color = without_root.get_pixel(sx, sy)
			if _is_fx_diff_pixel(ca, cb):
				count += 1
	return count


func _image_diff_stats(with_root: Image, without_root: Image) -> Dictionary:
	var w: int = mini(with_root.get_width(), without_root.get_width())
	var h: int = mini(with_root.get_height(), without_root.get_height())
	var count := 0
	var min_x := 99999
	var max_x := -1
	var min_y := 99999
	var max_y := -1
	for y in h:
		for x in w:
			var ca: Color = with_root.get_pixel(x, y)
			var cb: Color = without_root.get_pixel(x, y)
			if not _is_fx_diff_pixel(ca, cb):
				continue
			count += 1
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if count == 0:
		return {"count": 0, "top": -1, "bot": -1, "left": -1, "right": -1}
	return {"count": count, "top": min_y, "bot": max_y, "left": min_x, "right": max_x}


func _make_diff_image(with_root: Image, without_root: Image) -> Image:
	var w: int = mini(with_root.get_width(), without_root.get_width())
	var h: int = mini(with_root.get_height(), without_root.get_height())
	var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 1))
	for y in h:
		for x in w:
			var a: Color = with_root.get_pixel(x, y)
			var b: Color = without_root.get_pixel(x, y)
			if _pixels_differ(a, b):
				out.set_pixel(x, y, Color(1, 0.35, 0.7, 1))
			else:
				out.set_pixel(x, y, Color(a.r * 0.35, a.g * 0.35, a.b * 0.35, 1))
	return out


func _find_sole_bottom_y(img: Image, cx: int, y0: int, y1: int) -> int:
	var best := -1
	for y in range(maxi(0, y0), mini(img.get_height(), y1)):
		for x in range(maxi(0, cx - 12), mini(img.get_width(), cx + 13)):
			var c: Color = img.get_pixel(x, y)
			if c.a8 < 48:
				continue
			best = maxi(best, y)
	return best


func _viewport_crop(vp: SubViewport, crop_r: Rect2i) -> Image:
	var full: Image = vp.get_texture().get_image()
	var r := crop_r
	if r.position.x + r.size.x > full.get_width():
		r.size.x = full.get_width() - r.position.x
	if r.position.y + r.size.y > full.get_height():
		r.size.y = full.get_height() - r.position.y
	if r.size.x <= 0 or r.size.y <= 0:
		return full
	return full.get_region(r)


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
	layer.set_root_anim_frame_override(2)
	var fi: int = layer.root_anim_frame_for("dennis")
	check("screenshot: loop-frame 2 of 3 (nu %d)" % fi, fi == 2 or fi == 3)
	for _i in 12:
		await get_tree().process_frame
		if objects.get_node_or_null("RootFxOverlay") != null:
			break
	var ovl: CanvasItem = objects.get_node_or_null("RootFxOverlay") as CanvasItem
	check("screenshot: RootFxOverlay aanwezig", ovl != null)
	var pin_frame: int = fi if fi == 2 or fi == 3 else 2
	layer.set_root_anim_frame_override(pin_frame)
	p.sprite.frame = 0
	layer.set_root_fx_visible(true)
	check("screenshot: overlay zichtbaar, Dax rooted", ovl != null and ovl.visible and roots.is_rooted("dennis"))
	for _i in 4:
		await get_tree().process_frame
	var foot_world: Vector2 = _arena_root_draw_pos(p)
	var foot_px: Vector2i = _world_to_viewport_px(foot_world, cam, vp.size)
	var map_sole_world: float = p.position.y - MapSprite.voet_offset(MapSprite.NIEUW).y
	var sole_px_y: int = _world_to_viewport_px(Vector2(p.position.x, map_sole_world), cam, vp.size).y
	var crop_r := Rect2i(
		maxi(0, foot_px.x - 48),
		maxi(0, foot_px.y - 20),
		mini(128, vp.size.x),
		mini(64, vp.size.y),
	)

	var with_img: Image = _viewport_crop(vp, crop_r)
	var path_with := out.path_join("root_fx_with.png")
	with_img.save_png(path_with)
	layer.set_root_anim_frame_override(pin_frame)
	check("screenshot: frametijd vast vóór zonder-capture", layer.root_anim_frame_for("dennis") == pin_frame)
	layer.set_root_fx_visible(false)
	check(
		"screenshot: alleen RootFxOverlay uit, CombatRoots ongewijzigd",
		ovl != null and not ovl.visible and roots.is_rooted("dennis") and layer.root_icon_count() == 1,
	)
	for _i in 4:
		await get_tree().process_frame
	check("screenshot: overlay uit, root nog actief", roots.is_rooted("dennis") and layer.root_icon_count() == 1)
	check("screenshot: anim-frame gelijk na overlay-toggle", layer.root_anim_frame_for("dennis") == pin_frame)
	p.sprite.frame = 0
	var without_img: Image = _viewport_crop(vp, crop_r)
	var path_without := out.path_join("root_fx_without.png")
	without_img.save_png(path_without)
	var cx_crop: int = foot_px.x - crop_r.position.x
	var anchor_crop := Vector2i(cx_crop, foot_px.y - crop_r.position.y)
	var diff_stats: Dictionary = _image_diff_stats(with_img, without_img)
	var diff_count: int = int(diff_stats.get("count", 0))
	var art_mask_diff: int = _art_mask_diff_count(with_img, without_img, anchor_crop, pin_frame)
	var diff_ok: bool = diff_count >= DIFF_MIN_PIXELS or art_mask_diff >= DIFF_MIN_ART_MASK
	check(
		"diff-test: %d crop / %d art-mask pixels (min %d of %d), bbox y=%d..%d"
		% [
			diff_count,
			art_mask_diff,
			DIFF_MIN_PIXELS,
			DIFF_MIN_ART_MASK,
			diff_stats.get("top", -1),
			diff_stats.get("bot", -1),
		],
		diff_ok and int(diff_stats.get("bot", -1)) >= 0,
	)
	var diff_img: Image = _make_diff_image(with_img, without_img)
	var path_diff := out.path_join("root_fx_diff.png")
	diff_img.save_png(path_diff)
	var sole_crop_y: int = sole_px_y - crop_r.position.y
	var sole_scan: int = _find_sole_bottom_y(with_img, cx_crop, maxi(0, sole_crop_y - 28), sole_crop_y + 2)
	if sole_scan < 0:
		sole_scan = sole_crop_y
	var diff_bot: int = int(diff_stats.get("bot", -1))
	check(
		"diff-test: zool y=%d, diff_bbox bot=%d (Δ=%d px)"
		% [sole_scan, diff_bot, absi(diff_bot - sole_scan)],
		absi(diff_bot - sole_scan) <= 2,
	)
	check(
		"screenshot: node.y=%.1f map_sole=%.1f draw_y=%.1f offset=%.0f"
		% [p.position.y, map_sole_world, foot_world.y, SomArena.ROOT_FOOT_OFFSET_PX],
		is_equal_approx(foot_world.y, map_sole_world),
	)
	var path := out.path_join("root_fx_solo.png")
	var err := with_img.save_png(path)
	check(
		"screenshot artifacts with/without/diff (%s)" % path,
		err == OK and diff_ok and absi(diff_bot - sole_scan) <= 2,
	)
	layer.queue_free()
	get_tree().root.remove_child(vp)
	vp.queue_free()
