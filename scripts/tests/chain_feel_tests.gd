extends Node
## Epic keten-feel (WM1 Action). Start: godot --headless --path . -- --chainfeeltest

const CombatSim := preload("res://scripts/som/combat_sim.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomFeelData := preload("res://scripts/data/som_feel_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const SomShakeScript := preload("res://scripts/som/som_shake.gd")
const SomChainFeelScript := preload("res://scripts/som/som_chain_feel.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"
const HEROES: Array[String] = ["dennis", "lotte", "noor", "kael", "orion"]

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
	_data_tests()
	_fx_defs_tests()
	_shake_settings_tests()
	_number_tests()
	_afterimage_data_tests()
	_classic_hash_test()
	await _afterimage_runtime_test()
	await _afterimage_pool_survives_hero_free_test()
	await _shockwave_rotation_test()
	_uplink_test()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data_tests() -> void:
	check("hitstop array", SomChainData.HITSTOP_TICKS[0] == 0 and SomChainData.HITSTOP_TICKS[1] == 2 and SomChainData.HITSTOP_TICKS[2] == 6)
	check("hit1 hitstop 0", SomChainData.hitstop_ticks(SomChainData.STEP_HIT1) == 0)
	check("hit2 hitstop 2", SomChainData.hitstop_ticks(SomChainData.STEP_HIT2) == 2)
	check("finisher hitstop 6", SomChainData.hitstop_ticks(SomChainData.STEP_FINISHER) == 6)
	check("finisher shake 2/6", SomFeelData.shake_px("finisher") == 2 and SomFeelData.shake_ticks("finisher") == 6)
	check("heavy2 >= finisher shake", SomFeelData.shake_strength("heavy2") >= SomFeelData.shake_strength("finisher"))
	check("COL_FINISHER ongewijzigd", SomFeelData.COL_FINISHER.is_equal_approx(Color("#FF8A3D")))
	check("finisher getal FFD24A", SomFeelData.COL_FINISHER_NUMBER.is_equal_approx(Color("#FFD24A")))
	check("finisher getal schaal 1.3", is_equal_approx(SomFeelData.SCALE_FINISHER_NUMBER, 1.3))


func _fx_defs_tests() -> void:
	for id in HEROES:
		check("%s finisher sheet" % id, SomChainData.finisher_fx_sheet(id) != "")
		var tex := SomFx.tex(SomChainData.finisher_fx_sheet(id))
		check("%s finisher 160x32" % id, tex != null and tex.get_width() == 160 and tex.get_height() == 32)
	var h1 := SomFx.tex(str(SomChainData.FX_HIT1["sheet"]))
	var h2 := SomFx.tex(str(SomChainData.FX_HIT2["sheet"]))
	var sw := SomFx.tex(str(SomChainData.FX_SHOCKWAVE["sheet"]))
	check("hit1 96x32 3 frames", h1 != null and h1.get_width() == 96 and int(SomChainData.FX_HIT1["frames"]) == 3)
	check("hit2 96x32 3 frames", h2 != null and h2.get_width() == 96 and int(SomChainData.FX_HIT2["frames"]) == 3)
	check("shockwave 192x48 4 frames", sw != null and sw.get_width() == 192 and sw.get_height() == 48
			and int(SomChainData.FX_SHOCKWAVE["frames"]) == 4)
	check("fallback onbekende held", SomChainData.fx_def_for_step(SomChainData.STEP_FINISHER, "xyzzy").is_empty())
	check("finisher ms impact frame", SomChainData.FINISHER_FX_MS.size() == 5 and SomChainData.FINISHER_FX_MS[2] == 60)


func _shake_settings_tests() -> void:
	Settings.set_value("screen_shake", false)
	var cam := Camera2D.new()
	var sh := SomShakeScript.new()
	add_child(cam)
	sh.setup(cam)
	add_child(sh)
	sh.kick("finisher")
	sh.test_tick()
	check("shake uit bij screen_shake false", not sh.busy())
	Settings.set_value("screen_shake", true)
	sh.kick("finisher")
	sh.test_tick()
	check("shake aan bij screen_shake true", sh.busy())
	sh.queue_free()
	cam.queue_free()


func _number_tests() -> void:
	var holder := Node2D.new()
	add_child(holder)
	var fin := SomFx.number(holder, Vector2.ZERO, "12", SomFeelData.COL_FINISHER_NUMBER, 0.1, SomFeelData.SCALE_FINISHER_NUMBER)
	check("finisher getal modulate", fin.modulate.is_equal_approx(SomFeelData.COL_FINISHER_NUMBER))
	check("finisher getal scale", is_equal_approx(fin.scale.x, SomFeelData.SCALE_FINISHER_NUMBER))
	var norm := SomFx.number(holder, Vector2.ZERO, "5", SomFeelData.COL_NORMAL, 0.1, 1.0)
	check("gewoon getal schaal 1", is_equal_approx(norm.scale.x, 1.0))
	fin.queue_free()
	norm.queue_free()
	holder.queue_free()


func _afterimage_data_tests() -> void:
	check("nagloed 3 offsets", SomChainData.AFTERIMAGE_OFFSETS.size() == 3)
	check("nagloed alphas", SomChainData.AFTERIMAGE_ALPHAS.size() == 3 and absf(SomChainData.AFTERIMAGE_ALPHAS[0] - 0.55) < 0.001
			and absf(SomChainData.AFTERIMAGE_ALPHAS[1] - 0.35) < 0.001 and absf(SomChainData.AFTERIMAGE_ALPHAS[2] - 0.18) < 0.001)
	for id in HEROES:
		var c: Color = SomChainData.AFTERIMAGE_TINT[id]
		check("%s tint componenten 0..1" % id, c.r >= 0.0 and c.r <= 1.0 and c.g >= 0.0 and c.g <= 1.0 and c.b >= 0.0 and c.b <= 1.0)
	check("flash 1 tick", is_equal_approx(SomChainData.FINISHER_ENEMY_FLASH_SEC, 1.0 / 60.0))


func _classic_hash_test() -> void:
	var a := SomArena.new()
	a.down = false
	var before := str(a.get_script())
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	check("classic: geen keten-FX def bij classic", not Settings.action_battles())
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	check("action battles flag", Settings.action_battles())


func _hero_node(id: String) -> Node2D:
	var p: Node2D = preload("res://scripts/tests/chain_feel_mock_hero.gd").new()
	p.hero_id = id
	p.facing = Vector2i.RIGHT
	var body := Sprite2D.new()
	body.name = "Sprite2D"
	p.add_child(body)
	add_child(p)
	return p


func _afterimage_runtime_test() -> void:
	var hero := _hero_node("dennis")
	var tex := SomFx.tex(SomData.ATTACK_ANIMS["dennis"]["sheet"])
	var anim := SomFx.attack_anim(hero, tex, SomData.ATTACK_ANIMS["dennis"])
	anim.sim_driven = true
	var ctrl: Node = SomChainFeelScript.attach(hero, anim, "dennis")
	check("nagloed 3 sprites", ctrl.get_child_count() == 3)
	for _t in 8:
		anim.step(CombatSim.TICK_DT)
		if ctrl.has_method("step"):
			ctrl.step(CombatSim.TICK_DT)
	var visible_after := 0
	for c in ctrl.get_children():
		if c.visible:
			visible_after += 1
	check("nagloed zichtbaar tijdens swing", visible_after > 0)
	anim.finish_now()
	for _t in 20:
		if ctrl.has_method("step"):
			ctrl.step(CombatSim.TICK_DT)
	await get_tree().process_frame
	check("nagloed opgeruimd", not is_instance_valid(ctrl) or ctrl.get_child_count() == 0)
	hero.queue_free()


func _afterimage_pool_survives_hero_free_test() -> void:
	var hero := _hero_node("dennis")
	var tex := SomFx.tex(SomData.ATTACK_ANIMS["dennis"]["sheet"])
	var anim := SomFx.attack_anim(hero, tex, SomData.ATTACK_ANIMS["dennis"])
	anim.sim_driven = true
	var ctrl: Node = SomChainFeelScript.attach(hero, anim, "dennis")
	for _t in 3:
		anim.step(CombatSim.TICK_DT)
		if ctrl.has_method("step"):
			ctrl.step(CombatSim.TICK_DT)
	hero.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var hero2 := _hero_node("dennis")
	var anim2 := SomFx.attack_anim(hero2, tex, SomData.ATTACK_ANIMS["dennis"])
	anim2.sim_driven = true
	var ctrl2: Node = SomChainFeelScript.attach(hero2, anim2, "dennis")
	check("pool: tweede finisher start", ctrl2 != null)
	check("pool: 3 sprites na held-free", ctrl2.get_child_count() == 3)
	var valid := 0
	for c in ctrl2.get_children():
		if c is Sprite2D and is_instance_valid(c):
			valid += 1
	check("pool: 3 geldige Sprite2D", valid == 3)
	anim2.finish_now()
	hero2.queue_free()
	await get_tree().process_frame


func _shockwave_rotation_test() -> void:
	var layer := Node2D.new()
	add_child(layer)
	var sw := SomFx.chain_shockwave(layer, Vector2(80, 40))
	await get_tree().process_frame
	check("shockwave rotation 0", sw != null and is_equal_approx(sw.rotation, 0.0))
	layer.queue_free()


func _uplink_test() -> void:
	check("uplink 15960 B/s", Protocol.host_uplink_bytes_per_sec() == 15960)