extends Node
## SoM slagrichting vs target-lock (RPG COMBAT): godot --path . -- --swinglocktest
## Auto-lock: marker ja, slag volgt speler-facing (stick), niet het gelockte doel.
## Handmatige lock: slag richt naar het gelockte doel.

const SomTargetLock := preload("res://scripts/som/som_target_lock.gd")
const ISOLATED_TILE := Vector2i(12, 14)

var failures := 0
var passes := 0


func _ready() -> void:
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
	GameState.save_path = "user://swinglocktest_save.json"
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.start_som_prototype()
	for i in 360:
		if arena() != null and not GameState.changing_map:
			break
		await get_tree().process_frame
	await _frames(40)
	if arena() == null:
		check("arena geladen", false)
		_finish()
		return
	arena().allies_enabled = false
	await _wait_room_active()
	await _inactive_input_ignored_test()
	await _auto_lock_swing_tests()
	await _manual_lock_swing_tests()
	_finish()


func _finish() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_room_active() -> void:
	for i in 600:
		if room().monsters_active():
			return
		await get_tree().process_frame
	check("kamer actief (monsters_active)", room().monsters_active())


func _clear_arena_monsters() -> void:
	for m in arena().enemies.duplicate().keys():
		if is_instance_valid(m):
			arena().enemies.erase(m)
			m.queue_free()
	await _frames(6)


func _spawn_monster(id: String, tile: Vector2i) -> Node:
	var m: Node = room().add_monster({"id": id, "enemy": "mosslijm", "tile": [tile.x, tile.y]})
	m.place_at(tile, Vector2i.LEFT)
	m.stun(9999)
	arena().register(m)
	var e: Dictionary = arena().enemies[m]
	e["hp"] = 9999
	e["max_hp"] = 9999
	e["cd"] = 9.0
	e["chase"] = 9.0
	e["tele"] = 0.0
	return m


func _prep_lock_only() -> Dictionary:
	var p: CharacterBody2D = room().player
	p.input_locked = false
	p.place_at(ISOLATED_TILE, Vector2i.LEFT)
	p.velocity = Vector2.ZERO
	await _frames(4)
	await _clear_arena_monsters()
	var pt: Vector2i = p.get_tile()
	var m_lock: Node = _spawn_monster("swing_lock_tgt", Vector2i(pt.x + 1, pt.y))
	await _sync_until(func(): return arena().enemies.has(m_lock), 12)
	return {"lock": m_lock, "player": p, "tile": pt}


func _prep_swing_pair(pt: Vector2i, m_lock: Node) -> Node:
	# Slachtoffer links (in bereik bij facing LEFT); lock-doel rechts blijft staan.
	var m_hit: Node = _spawn_monster("swing_face_tgt", Vector2i(pt.x - 1, pt.y))
	await _sync_until(func(): return arena().enemies.has(m_hit), 12)
	return m_hit


func _sync_until(pred: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if pred.call():
			return true
		await get_tree().process_frame
	return false


func _swing_facing() -> Vector2i:
	var a := arena()
	return a._swing_facing(a.active_id, a.player)


func _await_swing_finish() -> void:
	var a := arena()
	a.set_process(false)
	a.charge = 1.0
	a.last_enemy_damage = 0
	a.attack()
	# Volledige aanvalsanimatie op de vaste 60 Hz-stap (~45 ticks voor Dax).
	for i in 60:
		a.advance(1.0 / 60.0)
	a.set_process(true)


func _inactive_input_ignored_test() -> void:
	var pair: Dictionary = await _prep_lock_only()
	var a := arena()
	var p: CharacterBody2D = pair["player"]
	p.input_locked = true
	check("inactief: arena niet actief tijdens input-lock", not a.active() and room().monsters_active() == false)
	a.set_process(true)
	a.charge = 1.0
	var attacks0: int = a.attacks
	a.attack()
	check("inactief: slag-anim loopt (sim bezig)", a._combat_sim_busy())
	Input.action_press("interact")
	Input.action_press("cancel")
	for i in 20:
		await get_tree().process_frame
	Input.action_release("interact")
	Input.action_release("cancel")
	check("inactief: stick/A/B leest geen extra aanval (attacks %d -> %d)" % [attacks0, a.attacks],
			a.attacks == attacks0 + 1)
	for i in 120:
		if not a._combat_sim_busy():
			break
		await get_tree().process_frame
	p.input_locked = false
	a.set_process(false)


func _auto_lock_swing_tests() -> void:
	var pair: Dictionary = await _prep_lock_only()
	var m_lock: Node = pair["lock"]
	var p: CharacterBody2D = pair["player"]
	var pt: Vector2i = pair["tile"]
	lock().clear_lock()
	lock().manual = false
	lock()._refresh_auto()
	var locked: Node = lock().locked_enemy()
	check("auto-lock: lock op dichtstbijzijnde (rechts)", locked == m_lock and not lock().manual)
	await _sync_until(func():
		lock()._update_marker()
		var mk: Node = lock()._marker
		return mk != null and mk.visible and locked != null
	, 30)
	check("auto-lock: HUD-marker op gelockte vijand",
			lock().locked_enemy() == m_lock and lock()._marker != null and lock()._marker.visible)
	var m_hit: Node = await _prep_swing_pair(pt, m_lock)
	p.facing = Vector2i.LEFT
	await _frames(2)
	check("auto-lock: slagrichting = speler-facing (links), niet naar lock", _swing_facing() == Vector2i.LEFT)
	var hp_lock0 := int(arena().enemies[m_lock]["hp"])
	var hp_hit0 := int(arena().enemies[m_hit]["hp"])
	await _await_swing_finish()
	var hp_lock1 := int(arena().enemies[m_lock]["hp"]) if arena().enemies.has(m_lock) else hp_lock0
	var hp_hit1 := int(arena().enemies[m_hit]["hp"]) if arena().enemies.has(m_hit) else hp_hit0
	check("auto-lock: slag raakt vijand in facing-richting", arena().last_enemy_damage > 0)
	check("auto-lock: links (facing) geraakt, rechts (lock) ongeschonden",
			hp_hit1 < hp_hit0 and hp_lock1 == hp_lock0)


func _manual_lock_swing_tests() -> void:
	var pair: Dictionary = await _prep_lock_only()
	var m_lock: Node = pair["lock"]
	var p: CharacterBody2D = pair["player"]
	var pt: Vector2i = pair["tile"]
	var m_hit: Node = await _prep_swing_pair(pt, m_lock)
	lock()._set_target(m_lock, true)
	check("manual lock actief", lock().locked_enemy() == m_lock and lock().manual)
	p.facing = Vector2i.LEFT
	await _frames(2)
	check("manual lock: slagrichting naar gelockt doel (rechts)", _swing_facing() == Vector2i.RIGHT)
	var hp_lock0 := int(arena().enemies[m_lock]["hp"])
	var hp_hit0 := int(arena().enemies[m_hit]["hp"])
	await _await_swing_finish()
	var hp_lock1 := int(arena().enemies[m_lock]["hp"]) if arena().enemies.has(m_lock) else hp_lock0
	var hp_hit1 := int(arena().enemies[m_hit]["hp"]) if arena().enemies.has(m_hit) else hp_hit0
	check("manual lock: slag raakt", arena().last_enemy_damage > 0)
	check("manual lock: gelockte vijand geraakt, facing-doel ongeschonden",
			hp_lock1 < hp_lock0 and hp_hit1 == hp_hit0)
