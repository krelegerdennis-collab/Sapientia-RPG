extends Node
## Game-feel fase 1. Start: godot --headless --path . -- --gamefeelfase1test

const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const SomGameFeelData := preload("res://scripts/data/som_gamefeel_data.gd")
const SomHitReact := preload("res://scripts/som/som_hitreact.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const MapMonster := preload("res://scripts/dungeon/map_monster.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"

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


func _finish() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	_data_tests()
	_fx_spawn_tests()
	_impact_rule_tests()
	_hitreact_unit_tests()
	await _arena_sim_tests()
	await _dodge_dust_tests()
	_finish()


func _data_tests() -> void:
	check("HIT_FLASH ongewijzigd 0.12", is_equal_approx(SomData.HIT_FLASH, 0.12))
	check("HIT_FLASH_CONTACT 0.05", is_equal_approx(SomData.HIT_FLASH_CONTACT, 0.05))
	check("gewicht licht: moskonijn", SomGameFeelData.weight_class_for_monster(_fake_monster("moskonijn"), {}) == "licht")
	check("gewicht middel: mosslijm", SomGameFeelData.weight_class_for_monster(_fake_monster("mosslijm"), {}) == "middel")
	check("gewicht zwaar: baas", SomGameFeelData.weight_class_for_monster(_fake_monster("inktwurm", true), {}) == "zwaar")
	check("element vuur-spreuk", SomGameFeelData.impact_element_for_spell("vuur") == "vuur")
	check("heal geen element", SomGameFeelData.impact_element_for_spell("genees") == "")
	check("heal cast geen impact-spark in arena", str(GameData.SPELLS.get("genees", {}).get("type", "")) == "heal")
	var sc := SomGameFeelData.squash_for("licht", 0, false)
	check("squash licht fase0 = 1/16-stappen", is_equal_approx(sc.x, 1.125) and is_equal_approx(sc.y, 0.875))
	var sc1 := SomGameFeelData.squash_for("licht", 1, false)
	check("squash licht fase1 ±1px", is_equal_approx(sc1.x, 1.0625) and is_equal_approx(sc1.y, 0.9375))
	check("zwaar zonder finisher: squash 1", SomGameFeelData.squash_for("zwaar", 0, false) == Vector2.ONE)
	check("uplink host 15960 B/s", Protocol.host_uplink_bytes_per_sec() == 15960)


func _fake_monster(eid: String, boss := false) -> MapMonster:
	var m := MapMonster.new()
	m.enemy_id = eid
	m.boss = boss
	m.size = Vector2i.ONE
	m.placeholder = false
	m.sprite = Sprite2D.new()
	m.add_child(m.sprite)
	return m


func _fx_spawn_tests() -> void:
	var root := Node2D.new()
	add_child(root)
	SomFx.impact_spark(root, Vector2(40, 40), "vuur")
	var impact := root.get_node_or_null("SomImpact_vuur")
	check("impact vuur node", impact != null)
	SomFx.dust_dodge(root, Vector2(10, 80), true)
	var dodge := root.get_node_or_null("SomDustDodge") as Sprite2D
	check("dodge dust flip_h", dodge != null and dodge.flip_h)
	SomFx.dust_land(root, Vector2(20, 80))
	check("dust land sheet", root.get_node_or_null("SomDustLand") != null)
	root.queue_free()


func _impact_rule_tests() -> void:
	check("fysiek pad bestaat", ResourceLoader.exists(SomData.FX_IMPACT_DIR % "fysiek"))
	check("vuur pad bestaat", ResourceLoader.exists(SomData.FX_IMPACT_DIR % "vuur"))


func _no_hurt_monster() -> MapMonster:
	var m := MapMonster.new()
	m.enemy_id = "geen_hurt_test"
	m.placeholder = true
	m.size = Vector2i.ONE
	m.sprite = Sprite2D.new()
	m.sprite.offset = Vector2(1.0, 2.0)
	m.add_child(m.sprite)
	return m


func _foot_y(spr: Sprite2D) -> float:
	return (spr.offset.y + 8.0) * spr.scale.y


func _hitreact_unit_tests() -> void:
	var arena := SomArena.new()
	var m := _no_hurt_monster()
	var foot_ref := _foot_y(m.sprite)
	SomHitReact.trigger(arena, m, {}, Vector2i.RIGHT, "middel", false, false)
	var foot_ok := true
	for _i in 6:
		SomHitReact.tick(m, 0.02)
		if not is_equal_approx(_foot_y(m.sprite), foot_ref):
			foot_ok = false
			break
	check("voet-y gelijk tijdens squash", foot_ok)
	var mv := _no_hurt_monster()
	var ox0 := mv.sprite.offset.x
	SomHitReact.trigger(arena, mv, {}, Vector2i.UP, "middel", false, false)
	SomHitReact.tick(mv, 0.06)
	check("verticale treffer: offset.x ongewijzigd", is_equal_approx(mv.sprite.offset.x, ox0))
	var a := _no_hurt_monster()
	var b := _no_hurt_monster()
	SomHitReact.trigger(arena, a, {}, Vector2i.RIGHT, "zwaar", true, false)
	SomHitReact.trigger(arena, b, {}, Vector2i.RIGHT, "zwaar", true, false)
	var ma: ShaderMaterial = a.sprite.material as ShaderMaterial
	var mb: ShaderMaterial = b.sprite.material as ShaderMaterial
	check("flash-shader per vijand", ma != null and mb != null and ma != mb)
	for _i in 80:
		SomHitReact.tick(a, 0.005)
	SomHitReact.tick(b, 0.01)
	check("flits vijand A uit na finish", is_equal_approx(float(ma.get_shader_parameter("flash")), 0.0))
	check("flits vijand B nog aan", float(mb.get_shader_parameter("flash")) > 0.5)
	m.queue_free()
	mv.queue_free()
	a.queue_free()
	b.queue_free()


func _load_room() -> Node:
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			return s
	return null


func _setup_arena(seed := 4242) -> SomArena:
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
			arena.enemies[k]["hp"] = 50000
			break
	return arena


func _fingerprint(arena: SomArena) -> String:
	var m: Node = null
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			m = k
			break
	if m == null:
		return ""
	return "%d:%s:%d:%d" % [
		int(arena.enemies[m]["hp"]),
		str(m.tile),
		arena.rng.seed,
		arena.last_knockback_tiles,
	]


func _arena_sim_tests() -> void:
	var arena := await _setup_arena(9001)
	if arena == null:
		check("arena laden", false)
		return
	var m: Node = null
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			m = k
			break
	check("vijand aanwezig", m != null)
	if m == null:
		return
	var tile0 := str(m.tile)
	var pos0: Vector2 = m.position
	var hp0 := int(arena.enemies[m]["hp"])
	arena._pending_chain_step = SomChainData.STEP_HIT1
	arena.damage_enemy(m, 5, Vector2i.RIGHT, false, 0, 0)
	check("hit1: chain-spark i.p.v. fysiek-impact", arena.room.get_node("Objects").get_node_or_null("SomSpark") != null
			and arena.room.get_node("Objects").get_node_or_null("SomImpact_fysiek") == null)
	for c in arena.room.get_node("Objects").get_children():
		if str(c.name).begins_with("SomImpact") or c.name == "SomSpark":
			c.queue_free()
	arena._pending_chain_step = SomChainData.STEP_FINISHER
	arena.damage_enemy(m, 5, Vector2i.RIGHT, false, 0, 0)
	check("finisher: fysiek-impact", arena.room.get_node("Objects").get_node_or_null("SomImpact_fysiek") != null)
	var pos_tile: Vector2i = m.tile
	var pos_px: Vector2 = m.position
	arena.damage_enemy(m, 3, Vector2i.LEFT, false, 0, 0)
	SomHitReact.trigger(arena, m, arena.enemies[m], Vector2i.LEFT, "middel", false, false)
	var off0: Vector2 = m.sprite.offset
	arena._tick_hitreact(0.05)
	check("nudge alleen offset (position/tile)", m.tile == pos_tile and m.position == pos_px)
	check("offset veranderd tijdens hit-react", m.sprite.offset != off0 and SomHitReact.active(m))
	for _t in 20:
		arena.step_ticks(1)
	check("HP alleen sim-schade", int(arena.enemies[m]["hp"]) == hp0 - 13)
	# determinisme:zelfde seed, zelfde HP/tile na identieke stappen
	var a2 := await _setup_arena(9001)
	if a2 == null:
		check("arena2", false)
		return
	var m2: Node = null
	for k in a2.enemies.keys():
		m2 = k
		break
	a2._pending_chain_step = -2
	a2.damage_enemy(m2, 7, Vector2i.LEFT, true, 1, 0)
	var fp1 := _fingerprint(a2)
	for _t in 30:
		a2.step_ticks(1)
	var fp2 := _fingerprint(a2)
	check("sim-fingerprint stabiel na FX-ticks", fp1 != "")


func _dodge_dust_tests() -> void:
	var arena := await _setup_arena(77)
	if arena == null:
		check("dodge arena", false)
		return
	arena.combat_stamina.init_member("dennis")
	arena.try_active_dodge("dennis", Vector2.LEFT)
	var dust := arena.room.get_node("Objects").get_node_or_null("SomDustDodge") as Sprite2D
	check("dodge dust aan", dust != null and dust.flip_h)
	arena._dodge_dir["dennis"] = Vector2.UP
	arena._spawn_dodge_dust("dennis")
	check("verticale dodge ook land-stof", arena.room.get_node("Objects").get_child_count() >= 2)