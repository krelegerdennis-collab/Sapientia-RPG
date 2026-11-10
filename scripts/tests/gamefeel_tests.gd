extends Node
## F4 game feel. Start: godot --headless --path . -- --gamefeeltest
## Ook via --autotest (debug_autotest.gd): run_embedded().

const SomFeelData := preload("res://scripts/data/som_feel_data.gd")
const SomShakeScript := preload("res://scripts/som/som_shake.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"

var failures := 0
var passes := 0
var _host: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


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
	_table_tests()
	_shake_tests()
	_color_tests()
	_host = null


func _finish() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	_table_tests()
	_shake_tests()
	_color_tests()
	await _arena_shake_stop_test()
	await _sim_hash_test()
	await _number_screenshots()
	_finish()


func _table_tests() -> void:
	for kind in ["finisher", "heavy1", "heavy2", "boss_slam"]:
		var px := SomFeelData.shake_px(kind)
		var ticks := SomFeelData.shake_ticks(kind)
		check("tabellen: %s px>0 ticks>0" % kind, px > 0 and ticks > 0)
	check("tabellen: kleuren gedefinieerd", SomFeelData.COL_FINISHER.r > 0.9 and SomFeelData.COL_HEAVY.g > 0.7)


func _make_shake() -> Array:
	var root := Node2D.new()
	add_child(root)
	var cam := Camera2D.new()
	root.add_child(cam)
	var sh := SomShakeScript.new()
	sh.setup(cam)
	root.add_child(sh)
	return [root, cam, sh]


func _shake_tests() -> void:
	var parts := _make_shake()
	var root: Node2D = parts[0]
	var cam: Camera2D = parts[1]
	var sh = parts[2]
	sh.kick("heavy2")
	sh.test_tick()
	check("shake heavy2: offset tijdens tick", sh.offset_now() != Vector2.ZERO)
	var trail: Array[String] = []
	for _i in SomFeelData.shake_ticks("heavy2") - 1:
		trail.append(str(sh.offset_now()))
		sh.test_tick()
	check("shake heavy2: na ticks offset ZERO", cam.offset == Vector2.ZERO)
	var parts2 := _make_shake()
	var sh2 = parts2[2]
	sh2.kick("finisher")
	sh2.test_tick()
	sh2.kick("heavy2")
	check("shake: sterkere overschrijft zwakkere", sh2.busy())
	var parts3 := _make_shake()
	var sh3 = parts3[2]
	sh3.kick("heavy2")
	sh3.test_tick()
	sh3.kick("finisher")
	check("shake: zwakkere overschrijft sterkere niet", sh3.busy() and SomFeelData.shake_strength("heavy2") >= SomFeelData.shake_strength("finisher"))
	var run1: Array[String] = []
	var run2: Array[String] = []
	for trial in 2:
		var p := _make_shake()
		var s = p[2]
		s.kick("heavy2")
		var seq: Array[String] = []
		for _t in SomFeelData.shake_ticks("heavy2"):
			seq.append(str(s.offset_now()))
			s.test_tick()
		if trial == 0:
			run1 = seq
		else:
			run2 = seq
		p[0].queue_free()
	check("shake: patroon deterministisch", run1 == run2 and not run1.is_empty())
	root.queue_free()
	parts2[0].queue_free()
	parts3[0].queue_free()


func _color_tests() -> void:
	check("kleur: party schade rood", SomFx._digit_row(Color(1, 0.4, 0.4)) == 1)
	check("kleur: heal groen", SomFx._digit_row(Color(0.4, 1, 0.5)) == 2)
	var holder := Node2D.new()
	add_child(holder)
	var n: Node2D = SomFx.number(holder, Vector2.ZERO, "9", SomFeelData.COL_FINISHER, 0.1, 1.0)
	check("kleur: finisher witte rij", int(n.get("row")) == 0)
	check("kleur: finisher modulate", n.modulate.is_equal_approx(SomFeelData.COL_FINISHER))
	var n2: Node2D = SomFx.number(holder, Vector2.ZERO, "9", SomFeelData.COL_HEAVY, 0.1, SomFeelData.SCALE_HEAVY2)
	check("kleur: heavy L2 schaal", is_equal_approx(n2.scale.x, SomFeelData.SCALE_HEAVY2))
	n.queue_free()
	n2.queue_free()
	holder.queue_free()


func _load_room() -> Node:
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			return s
	return null


func _setup_room(seed := 9001) -> SomArena:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	var room := await _load_room()
	if room == null:
		return null
	var arena: SomArena = room.som
	arena.set_process(false)
	arena.allies_enabled = false
	arena.seed_rng(seed)
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			arena.enemies[k]["hp"] = 999999
			break
	return arena


func _arena_shake_stop_test() -> void:
	var arena := await _setup_room()
	if arena == null:
		check("arena exit shake: kamer", false)
		return
	if arena.shake == null:
		check("arena exit shake: shake node", false)
		return
	arena.shake.kick("heavy2")
	arena.shake.test_tick()
	check("arena exit shake: bezig", arena.shake.busy())
	arena._clear_transient_combat()
	var cam := arena.player.get_node_or_null("Camera2D") as Camera2D
	check("arena exit shake: offset ZERO", cam != null and cam.offset == Vector2.ZERO)


func _fight_fingerprint(arena: SomArena) -> String:
	var m: Node = null
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			m = k
			break
	if m == null:
		return ""
	return "%d:%d:%d:%d" % [
		int(arena.enemies[m]["hp"]),
		arena.sim_tick,
		arena.heavy_releases,
		int(arena.chain_of(arena.active_id).get("window", 0)),
	]


func _run_short_fight(arena: SomArena, with_shake: bool) -> String:
	for t in 120:
		var phase := t % 40
		arena._pending["attack"] = phase == 0
		arena._pending["hold"] = phase < 25
		if with_shake and arena.shake != null:
			arena.shake.kick("heavy1")
		arena.step_ticks(1)
	return _fight_fingerprint(arena)


func _unload_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
	for i in 60:
		await get_tree().process_frame


func _sim_hash_test() -> void:
	var f1 := await _fight_log(1337, false)
	var f2 := await _fight_log(1337, true)
	check("sim-hash: feel shake verandert sim niet (%s)" % f1, f1 != "" and f1 == f2)


func _fight_log(seed: int, with_shake: bool) -> String:
	var arena := await _setup_room(seed)
	if arena == null:
		check("sim-hash: kamer", false)
		return ""
	var fp := _run_short_fight(arena, with_shake)
	await _unload_to_title()
	return fp


func _number_screenshots() -> void:
	var art_dir := "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(art_dir)
	await _shot_number(SomFeelData.COL_FINISHER, 1.0, art_dir + "/damage_number_orange.png")
	await _shot_number(SomFeelData.COL_HEAVY, SomFeelData.SCALE_HEAVY2, art_dir + "/damage_number_gold.png")
	check("screenshots: oranje", FileAccess.file_exists(art_dir + "/damage_number_orange.png"))
	check("screenshots: goud", FileAccess.file_exists(art_dir + "/damage_number_gold.png"))


func _shot_number(color: Color, scale: float, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(80, 40)
	vp.transparent_bg = false
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var layer := Node2D.new()
	vp.add_child(layer)
	add_child(vp)
	SomFx.number(layer, Vector2(40, 24), "88", color, 60.0, scale)
	for _i in 8:
		await get_tree().process_frame
	var tex := vp.get_texture()
	if tex != null:
		tex.get_image().save_png(path)
	vp.queue_free()
