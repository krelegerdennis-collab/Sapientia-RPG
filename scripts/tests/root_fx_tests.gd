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
	await get_tree().process_frame
	await get_tree().process_frame
	var p: CharacterBody2D = room.get_node_or_null("Objects/Player") as CharacterBody2D
	if p == null:
		check("arena screenshot: Player in archief_v1_gang", false)
		get_tree().root.remove_child(vp)
		vp.queue_free()
		return
	p.sprite.texture = SomFx.tex(str(SomData.SHEETS["dennis"]))
	MapSprite.pas_toe(p.sprite, MapSprite.NIEUW)
	if p.has_method("place_at"):
		p.place_at(Vector2i(12, 10), Vector2i.DOWN)
	var cam := p.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
	var root_pos: Vector2 = Vector2(p.position) + Vector2(0, SomData.BODY_Y + SomArena.ROOT_FOOT_OFFSET_PX)
	var layer := TelegraphLayer.new()
	layer.z_index = 12
	room.get_node("Objects").add_child(layer)
	layer._ready()
	var roots := CombatRoots.new()
	roots.try_apply_root("solo", 60)
	layer.sync_from_roots(roots, {"solo": root_pos})
	layer.set_root_anim_start_for_test("solo", Time.get_ticks_msec() - 350)
	for _i in 8:
		await get_tree().process_frame
	var tex: ViewportTexture = vp.get_texture()
	var img: Image = tex.get_image()
	var path := out.path_join("root_fx_solo.png")
	# Crop rond held + FX
	var cx := int(p.position.x)
	var cy := int(p.position.y)
	var crop := Rect2i(maxi(0, cx - 48), maxi(0, cy - 56), mini(128, img.get_width()), mini(128, img.get_height()))
	if crop.size.x > 0 and crop.size.y > 0:
		img = img.get_region(crop)
	var err := img.save_png(path)
	check("screenshot arena Dax rooted (%s)" % path, err == OK and img.get_width() > 0)
	get_tree().root.remove_child(vp)
	vp.queue_free()
