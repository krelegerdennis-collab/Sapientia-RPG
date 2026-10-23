extends Node
## Action doel-lock: godot --path . -- --locktest [--shots=/pad/map]

const SomData := preload("res://scripts/data/som_data.gd")
const SomTargetLock := preload("res://scripts/som/som_target_lock.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")
const PHYS_STEP := 1.0 / 60.0
const VIEWPORT := Vector2i(384, 216)
## Vaste tegel voor touch/facing (ver van spawn-monsters, stabiel op 384x216).
const ISOLATED_TILE := Vector2i(12, 14)
var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func arena() -> Node:
	var s := get_tree().current_scene
	return s.som if s != null and "som" in s else null


func room() -> Node:
	return get_tree().current_scene


func lock() -> Node:
	var a := arena()
	return a.target_lock if a != null else null


func _run() -> void:
	GameState.save_path = "user://locktest_save.json"
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	await _enter_som()
	if arena() == null:
		check("arena geladen", false)
		_finish()
		return
	arena().allies_enabled = false
	await _preload_target_lock_textures()
	await _prep_viewport()
	await _auto_lock_tests()
	await _manual_lock_tests()
	await _facing_tests()
	await _auto_scan_throttle_tests()
	await _touch_ui_priority_tests()
	await _marker_tests()
	await _codex_lock_tests()
	await _narrow_viewport_tests()
	await _death_and_clear_tests()
	_finish()


func _finish() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _enter_som() -> void:
	GameState.start_som_prototype()
	for i in 360:
		if arena() != null and not GameState.changing_map:
			break
		await get_tree().process_frame
	await _frames(30)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _sync_until(pred: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if pred.call():
			return true
		await get_tree().process_frame
	return false


func _preload_target_lock_textures() -> void:
	var d: Dictionary = SomData.TARGET_LOCK
	for key in ["marker", "wissel"]:
		var path: String = str(d[key])
		await _sync_until(func():
			return ResourceLoader.exists(path) and load(path) != null
		, 240)
	SomFx.tex(str(d["marker"]))
	SomFx.tex(str(d["wissel"]))


func _wait_lock_marker_on(m: Node, max_dist: float, max_frames: int) -> bool:
	return await _sync_until(func():
		if lock() == null or m == null or not is_instance_valid(m):
			return false
		lock()._update_marker()
		var mk: Node = lock()._marker
		if mk == null or not is_instance_valid(mk):
			return false
		return mk.global_position.distance_to(lock().head_of(m)) < max_dist
	, max_frames)


func _prep_viewport() -> void:
	get_tree().root.size = VIEWPORT
	await _frames(4)
	var tc := _touch_control()
	if tc:
		tc.refit()
	if arena() and arena().hud:
		arena().hud._place()
	await _frames(2)


func _stun_all_enemies(steps: int = 9999) -> void:
	if arena() == null:
		return
	for m in arena().enemies.keys():
		if is_instance_valid(m) and m.has_method("stun"):
			m.stun(steps)


func _trim_enemies(keep: Array) -> void:
	if arena() == null:
		return
	for m in arena().enemies.duplicate().keys():
		if is_instance_valid(m) and not keep.has(m):
			arena().enemies.erase(m)
			m.queue_free()
	await _frames(6)


func _isolate_player() -> void:
	var p: CharacterBody2D = room().player
	p.input_locked = false
	p.place_at(ISOLATED_TILE, p.facing)
	p.velocity = Vector2.ZERO
	await _frames(2)


func _sorted_enemies() -> Array:
	var list: Array = []
	for m in arena().enemies.keys():
		if is_instance_valid(m):
			list.append(m)
	list.sort_custom(func(a, b): return arena().center_of(a).distance_to(arena().body()) < arena().center_of(b).distance_to(arena().body()))
	return list


func _place_player(tile: Vector2i) -> void:
	var p: CharacterBody2D = room().player
	p.place_at(tile, p.facing)
	p.velocity = Vector2.ZERO
	await _frames(2)


func _clear_lock() -> void:
	lock().clear_lock()
	lock().manual = false
	await _frames(3)


func _auto_lock_tests() -> void:
	await _isolate_player()
	_stun_all_enemies()
	await _clear_lock()
	var p: CharacterBody2D = room().player
	var pt: Vector2i = p.get_tile()
	var near_m: Node = room().add_monster({"id": "lock_near", "enemy": "mosslijm", "tile": [pt.x + 1, pt.y]})
	near_m.place_at(Vector2i(pt.x + 1, pt.y), Vector2i.LEFT)
	near_m.stun(9999)
	var far_m: Node = room().add_monster({"id": "lock_far", "enemy": "mosslijm", "tile": [pt.x + 9, pt.y]})
	far_m.place_at(Vector2i(pt.x + 9, pt.y), Vector2i.LEFT)
	far_m.stun(9999)
	await _sync_until(func(): return arena().enemies.has(near_m) and arena().enemies.has(far_m), 8)
	lock().clear_lock()
	lock().manual = false
	lock()._refresh_auto()
	var nearest: Node = arena().nearest_enemy(arena().body(), SomTargetLock.AUTO_LOCK_RADIUS)
	var locked: Node = lock().locked_enemy()
	var dist: float = arena().center_of(locked).distance_to(arena().body()) if locked != null else 999.0
	check("auto-lock: dichtbij binnen %.0f tegels (%.0f px)" % [SomTargetLock.AUTO_LOCK_TILES, dist],
			locked != null and not lock().manual and dist <= SomTargetLock.AUTO_LOCK_RADIUS)
	check("auto-lock: ver weg geen lock", arena().center_of(far_m).distance_to(arena().body()) > SomTargetLock.AUTO_LOCK_RADIUS
			and lock().locked_enemy() != far_m)
	check("auto-lock: dichtstbijzijnde vijand", locked == nearest and nearest == near_m)


func _touch_control() -> Control:
	return room().get_node("TouchControls/Control") as Control


func _viewport_of_tc(local: Vector2) -> Vector2:
	var tc := _touch_control()
	return tc.get_global_transform_with_canvas() * local


func _touch_screen(tc: Control, local: Vector2, pressed: bool, index: int = 7) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = tc.get_global_transform_with_canvas() * local
	tc._input(ev)


func _touch_hits_stick(tc: Control, local: Vector2) -> bool:
	return local.distance_to(tc.stick_center()) <= tc.stick_reach()


func _touch_hits_a(tc: Control, local: Vector2) -> bool:
	return local.distance_to(tc.a_center()) <= tc.button_radius * 1.25


func _place_monster_at_viewport(vp: Vector2, id: String) -> Node:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * vp
	var tile := Vector2i(roundi(world.x / 16.0), roundi(world.y / 16.0))
	var m: Node = room().add_monster({"id": id, "enemy": "mosslijm", "tile": [tile.x, tile.y]})
	m.place_at(tile, Vector2i.LEFT)
	return m


func _touch_ui_priority_tests() -> void:
	await _prep_viewport()
	await _isolate_player()
	_stun_all_enemies()
	await _clear_lock()
	var tc: Control = _touch_control()
	tc._touch_owner.clear()
	tc.joy_raw = Vector2.ZERO
	var stick_local: Vector2 = tc.stick_center()
	var a_local: Vector2 = tc.a_center()
	var stick_vp: Vector2 = _viewport_of_tc(stick_local)
	var a_vp: Vector2 = _viewport_of_tc(a_local)
	check("touch: joystick hit-test stabiel", _touch_hits_stick(tc, stick_local))
	check("touch: A hit-test stabiel", _touch_hits_a(tc, a_local))
	check("touch: geen vijand op knoppen", lock().pick_enemy_at_viewport(a_vp) == null)
	var m_stick: Node = _place_monster_at_viewport(stick_vp, "lock_under_stick")
	m_stick.stun(9999)
	await _sync_until(func(): return lock().pick_enemy_at_viewport(stick_vp) == m_stick, 8)
	check("touch: monster onder joystick is pickbaar", lock().pick_enemy_at_viewport(stick_vp) == m_stick)
	m_stick.queue_free()
	await _sync_until(func(): return not is_instance_valid(m_stick), 12)
	var joy_idx := 7
	_touch_screen(tc, stick_local, true, joy_idx)
	check("touch: tik op joystick lockt niet", lock().locked_enemy() == null and tc._touch_owner.get(joy_idx, "") == "joy")
	_touch_screen(tc, stick_local, false, joy_idx)
	var a_idx := 8
	_touch_screen(tc, a_local, true, a_idx)
	check("touch: tik op A lockt niet", lock().locked_enemy() == null and tc._touch_owner.get(a_idx, "") == "a")
	_touch_screen(tc, a_local, false, a_idx)
	tc._touch_owner.clear()
	tc.joy_raw = Vector2.ZERO


func _ensure_arena_ready() -> void:
	var p: CharacterBody2D = room().player
	p.input_locked = false
	room()._grace_left = 0.0
	_stun_all_enemies()
	var a := arena()
	if a == null:
		return
	a.down = false
	if a.ring.is_open:
		a.ring.close({})


func _auto_scan_throttle_tests() -> void:
	await _clear_lock()
	await _ensure_arena_ready()
	lock().timed_auto_scans = 0
	var p: CharacterBody2D = room().player
	var pt: Vector2i = p.get_tile()
	var near_m: Node = room().add_monster({"id": "lock_throttle", "enemy": "mosslijm", "tile": [pt.x + 1, pt.y]})
	near_m.place_at(Vector2i(pt.x + 1, pt.y), Vector2i.LEFT)
	near_m.stun(9999)
	await _sync_until(func(): return arena().enemies.has(near_m), 8)
	lock().manual = false
	check("arena actief voor auto-scan timer", arena() != null and arena().active())
	# Deterministisch via tick(delta), geen wall-clock (flake in headless/CI).
	lock().timed_auto_scans = 0
	lock()._auto_scan_t = SomTargetLock.AUTO_SCAN_INTERVAL
	var step := SomTargetLock.AUTO_SCAN_INTERVAL / 10.0
	for i in 3:
		lock().tick(step)
	check("auto-scan: niet elke frame (3 ticks)", lock().timed_auto_scans == 0)
	lock().timed_auto_scans = 0
	lock()._auto_scan_t = 0.0
	lock().tick(SomTargetLock.AUTO_SCAN_INTERVAL)
	check("auto-scan: loopt op interval (~%.2fs)" % SomTargetLock.AUTO_SCAN_INTERVAL, lock().timed_auto_scans >= 1)


func _tap_monster(m: Node) -> void:
	var world: Vector2 = arena().center_of(m)
	var vp: Vector2 = get_viewport().get_canvas_transform() * world
	arena().try_lock_tap(vp)
	await _frames(2)


func _manual_lock_tests() -> void:
	await _clear_lock()
	var list := _sorted_enemies()
	if list.is_empty():
		check("manual: monsters aanwezig", false)
		return
	var a: Node = list[0]
	var b: Node = list[1] if list.size() > 1 else a
	await _tap_monster(a)
	check("manual tap: lock op monster", lock().locked_enemy() == a and lock().manual)
	await _frames(6)
	await _tap_monster(b)
	check("manual tap: wissel naar tweede", lock().locked_enemy() == b and lock().manual)
	await _tap_monster(b)
	check("manual tap: zelfde monster ontgrendelt", lock().locked_enemy() == null or not lock().manual)
	var attacks_before: int = arena().attacks
	await _tap_monster(a)
	check("tap monster triggert geen aanval", arena().attacks == attacks_before)


func _death_and_clear_tests() -> void:
	await _clear_lock()
	await _isolate_player()
	_ensure_arena_ready()
	var p: CharacterBody2D = room().player
	var pt: Vector2i = p.get_tile()
	var first: Node = room().add_monster({"id": "lock_die_a", "enemy": "mosslijm", "tile": [pt.x + 2, pt.y]})
	first.place_at(pt + Vector2i(2, 0), Vector2i.LEFT)
	var second: Node = room().add_monster({"id": "lock_die_b", "enemy": "mosslijm", "tile": [pt.x + 3, pt.y]})
	second.place_at(pt + Vector2i(3, 0), Vector2i.LEFT)
	second.stun(9999)
	await _sync_until(func(): return arena().enemies.has(first) and arena().enemies.has(second), 8)
	_trim_enemies([first, second])
	lock()._set_target(first, false)
	arena().enemies[first]["hp"] = 1
	arena().damage_enemy(first, 99, Vector2i.ZERO, false)
	await _sync_until(func(): return lock().locked_enemy() == second, 16)
	check("death: wissel naar exact volgende doel", lock().locked_enemy() == second)
	for m in arena().enemies.keys():
		if is_instance_valid(m):
			arena().enemies[m]["hp"] = 0
			arena().damage_enemy(m, 99, Vector2i.ZERO, false)
	await _sync_until(func(): return lock().locked_enemy() == null, 16)
	check("geen vijand meer: lock leeg", lock().locked_enemy() == null)


func _facing_tests() -> void:
	await _preload_target_lock_textures()
	await _prep_viewport()
	await _isolate_player()
	_ensure_arena_ready()
	await _clear_lock()
	var p: CharacterBody2D = room().player
	p.input_locked = false
	var origin := ISOLATED_TILE
	var m: Node = room().add_monster({"id": "lock_facing", "enemy": "mosslijm", "tile": [origin.x + 4, origin.y]})
	m.place_at(origin + Vector2i(4, 0), Vector2i.LEFT)
	m.stun(9999)
	await _sync_until(func(): return arena().enemies.has(m), 24)
	await _sync_until(func():
		return arena() != null and arena().active() and p.analog_input.is_valid() and p.facing_provider.is_valid()
	, 60)
	lock()._set_target(m, true)
	await _sync_until(func(): return lock().facing_for_player() == Vector2i.RIGHT, 30)
	p.facing = Vector2i.DOWN
	arena().forced_joy = Vector2(0, -1)
	var facing_ok := false
	for i in 24:
		p._process_analog(PHYS_STEP)
		if lock().facing_for_player() == Vector2i.RIGHT and p.facing == Vector2i.RIGHT:
			facing_ok = true
			break
	check("facing: strafen maar kijkt naar doel", facing_ok)
	arena().forced_joy = Vector2.ZERO


func _marker_tests() -> void:
	var list := _sorted_enemies()
	if list.is_empty():
		check("marker: monster nodig", false)
		return
	var m: Node = list[0]
	lock()._set_target(m, false)
	await _frames(5)
	var mk: Node = lock()._marker
	var ok: bool = mk != null and is_instance_valid(mk) and mk.visible
	var dist: float = 0.0
	if ok:
		dist = mk.global_position.distance_to(lock().head_of(m))
	check("marker zichtbaar boven doel (afwijking %.1f px)" % dist, ok and dist < 6.0)
	if shots != "" and ok:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		DirAccess.make_dir_recursive_absolute(shots)
		img.save_png(shots.path_join("lock_marker.png"))
		print("INFO  screenshot: ", shots.path_join("lock_marker.png"))


func _codex_lock_tests() -> void:
	var list := _sorted_enemies()
	if list.is_empty():
		check("codex: monster nodig", false)
		return
	var m: Node = list[0]
	lock()._set_target(m, true)
	GameState.inventory[CodexData.BOOK_ITEM] = 5
	arena().codex.force_roll = 0.0
	var before: int = arena().enemies.size()
	arena().codex.capture(m)
	for i in 60:
		if not arena().codex.busy:
			break
		await get_tree().process_frame
	check("codex: gevangen monster lock opgelost", not arena().enemies.has(m) and (lock().locked_enemy() == null or lock().locked_enemy() != m))
	check("codex: vijand uit arena", arena().enemies.size() < before)
	arena().codex.force_roll = -1.0


func _narrow_viewport_tests() -> void:
	for sz in [Vector2i(288, 216), Vector2i(270, 216)]:
		get_tree().root.size = sz
		await _frames(6)
		var tc: Control = room().get_node_or_null("TouchControls/Control")
		if tc:
			tc.refit()
		if arena() and arena().hud:
			arena().hud._place()
		var list := _sorted_enemies()
		if list.is_empty():
			check("smal scherm %dx%d: geen monster" % [sz.x, sz.y], false)
			continue
		var m: Node = list[0]
		lock()._set_target(m, false)
		var aligned: bool = await _wait_lock_marker_on(m, 8.0, 36)
		var mk: Node = lock()._marker
		var dist: float = mk.global_position.distance_to(lock().head_of(m)) if mk != null else 999.0
		check("smal scherm %dx%d: marker op doel (%.1f px)" % [sz.x, sz.y, dist], aligned and mk != null and dist < 8.0)
	get_tree().root.size = Vector2i(384, 216)
	await _frames(4)
