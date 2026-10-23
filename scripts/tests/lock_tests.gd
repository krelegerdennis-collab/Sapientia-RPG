extends Node
## Action doel-lock: godot --path . -- --locktest [--shots=/pad/map]

const SomData := preload("res://scripts/data/som_data.gd")
const SomTargetLock := preload("res://scripts/som/som_target_lock.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")
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
	await _auto_lock_tests()
	await _manual_lock_tests()
	await _touch_ui_priority_tests()
	await _auto_scan_throttle_tests()
	await _facing_tests()
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


func _wait_arena_active(max_frames: int = 180) -> bool:
	for i in max_frames:
		var a := arena()
		if a != null and a.active():
			return true
		await get_tree().process_frame
	return false


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
	for i in 90:
		if arena() != null and arena().active():
			break
		await get_tree().process_frame
	await _clear_lock()
	var p: CharacterBody2D = room().player
	var pt: Vector2i = p.get_tile()
	var near_m: Node = room().add_monster({"id": "lock_near", "enemy": "mosslijm", "tile": [pt.x + 1, pt.y]})
	near_m.place_at(Vector2i(pt.x + 1, pt.y), Vector2i.LEFT)
	var far_m: Node = room().add_monster({"id": "lock_far", "enemy": "mosslijm", "tile": [pt.x + 9, pt.y]})
	far_m.place_at(Vector2i(pt.x + 9, pt.y), Vector2i.LEFT)
	await _frames(12)
	lock()._refresh_auto()
	await _frames(2)
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


func _simulate_touch(vp: Vector2, pressed: bool, index: int = 7) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = vp
	ev.pressed = pressed
	ev.index = index
	_touch_control()._input(ev)


func _place_monster_at_viewport(vp: Vector2, id: String) -> Node:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * vp
	var tile := Vector2i(roundi(world.x / 16.0), roundi(world.y / 16.0))
	var m: Node = room().add_monster({"id": id, "enemy": "mosslijm", "tile": [tile.x, tile.y]})
	m.place_at(tile, Vector2i.LEFT)
	return m


func _touch_ui_priority_tests() -> void:
	await _clear_lock()
	var tc: Control = _touch_control()
	var stick_vp: Vector2 = _viewport_of_tc(tc.stick_center())
	var a_vp: Vector2 = _viewport_of_tc(tc.a_center())
	var m_stick: Node = _place_monster_at_viewport(stick_vp, "lock_under_stick")
	var m_a: Node = _place_monster_at_viewport(a_vp, "lock_under_a")
	await _frames(4)
	check("touch: monster onder joystick is pickbaar", lock().pick_enemy_at_viewport(stick_vp) == m_stick)
	_simulate_touch(stick_vp, true)
	await _frames(2)
	check("touch: tik op joystick lockt niet", lock().locked_enemy() == null and tc._touch_owner.get(7, "") == "joy")
	_simulate_touch(stick_vp, false, 7)
	await _frames(2)
	_simulate_touch(a_vp, true, 8)
	await _frames(2)
	check("touch: tik op A lockt niet", lock().locked_enemy() == null and tc._touch_owner.get(8, "") == "a")
	_simulate_touch(a_vp, false, 8)


func _auto_scan_throttle_tests() -> void:
	await _clear_lock()
	lock().timed_auto_scans = 0
	var p: CharacterBody2D = room().player
	p.input_locked = false
	var pt: Vector2i = p.get_tile()
	var near_m: Node = room().add_monster({"id": "lock_throttle", "enemy": "mosslijm", "tile": [pt.x + 1, pt.y]})
	near_m.place_at(Vector2i(pt.x + 1, pt.y), Vector2i.LEFT)
	await _frames(2)
	lock().manual = false
	check("arena actief voor auto-scan timer", await _wait_arena_active())
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
	var list := _sorted_enemies()
	if list.size() < 2:
		check("death: minstens 2 vijanden", false)
		return
	var first: Node = list[0]
	var second: Node = list[1]
	lock()._set_target(first, false)
	await _frames(2)
	arena().enemies[first]["hp"] = 1
	arena().damage_enemy(first, 99, Vector2i.ZERO, false)
	await _frames(4)
	check("death: wissel naar exact volgende doel", lock().locked_enemy() == second)
	for m in arena().enemies.keys():
		if is_instance_valid(m):
			arena().enemies[m]["hp"] = 0
			arena().damage_enemy(m, 99, Vector2i.ZERO, false)
	await _frames(6)
	check("geen vijand meer: lock leeg", lock().locked_enemy() == null)


func _facing_tests() -> void:
	var list := _sorted_enemies()
	if list.is_empty():
		check("facing: monster nodig", false)
		return
	var m: Node = list[0]
	lock()._set_target(m, true)
	await _frames(2)
	var p: CharacterBody2D = room().player
	p.facing = Vector2i.DOWN
	arena().forced_joy = Vector2(0, -1)
	await _frames(8)
	var want: Vector2i = lock().facing_for_player()
	check("facing: strafen maar kijkt naar doel", want != Vector2i.ZERO and p.facing == want)
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
		await _frames(5)
		var mk: Node = lock()._marker
		var dist: float = mk.global_position.distance_to(lock().head_of(m)) if mk != null else 999.0
		check("smal scherm %dx%d: marker op doel (%.1f px)" % [sz.x, sz.y, dist], mk != null and dist < 8.0)
	get_tree().root.size = Vector2i(384, 216)
	await _frames(4)
