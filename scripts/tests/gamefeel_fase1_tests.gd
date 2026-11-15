extends Node
## Game-feel fase 1. Start: godot --headless --path . -- --gamefeelfase1test

const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const SomGameFeelData := preload("res://scripts/data/som_gamefeel_data.gd")
const SomHitReact := preload("res://scripts/som/som_hitreact.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const MapMonster := preload("res://scripts/dungeon/map_monster.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"


class _SomRoomStub extends Node2D:
	var som: SomArena


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
	await _pending_fx_leak_tests()
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
	# Tweede treffer na >270 ms: flash opnieuw vol aan
	var twice := _no_hurt_monster()
	var orig := CanvasItemMaterial.new()
	twice.sprite.material = orig
	SomHitReact.trigger(arena, twice, {}, Vector2i.RIGHT, "middel", false, false)
	var mt: ShaderMaterial = twice.sprite.material as ShaderMaterial
	check("shader flits treffer 1 frame 1", mt != null and float(mt.get_shader_parameter("flash")) > 0.9)
	for _i in 60:
		SomHitReact.tick(twice, 0.005)
	for _i in 20:
		SomHitReact.tick(twice, 0.02)
	SomHitReact.trigger(arena, twice, {}, Vector2i.RIGHT, "middel", false, false)
	check("shader flits treffer 2 frame 1", float(mt.get_shader_parameter("flash")) > 0.9)
	# Re-hit tijdens lopende flits: origineel material terug na finish
	var rehit := _no_hurt_monster()
	var keep := StandardMaterial3D.new()
	rehit.sprite.material = keep
	SomHitReact.trigger(arena, rehit, {}, Vector2i.RIGHT, "middel", false, false)
	SomHitReact.tick(rehit, 0.01)
	SomHitReact.trigger(arena, rehit, {}, Vector2i.RIGHT, "middel", false, false)
	for _i in 70:
		SomHitReact.tick(rehit, 0.005)
	check("re-hit: origineel material terug", rehit.sprite.material == keep)
	# dir ZERO: geen nudge op x; y alleen voet-pivot
	var zd := _no_hurt_monster()
	var off_z: Vector2 = zd.sprite.offset
	SomHitReact.trigger(arena, zd, {}, Vector2i.ZERO, "middel", false, false)
	SomHitReact.tick(zd, 0.04)
	check("dir zero: offset.x ongewijzigd", is_equal_approx(zd.sprite.offset.x, off_z.x))
	var off_y_only := (off_z.y + 8.0) / zd.sprite.scale.y - 8.0
	check("dir zero: geen nudge op y", is_equal_approx(zd.sprite.offset.y, off_y_only))
	# hitstop-freeze (alleen meta-timer; geen arena-diff)
	var hs := _no_hurt_monster()
	var room := _SomRoomStub.new()
	var som := SomArena.new()
	som.enemies[hs] = {"hitstop": 8, "hp": 100}
	room.som = som
	hs.room = room
	add_child(room)
	SomHitReact.trigger(arena, hs, {}, Vector2i.RIGHT, "middel", false, false)
	check("hitstop: koppel room->som->enemy", room.som == som and som.enemies.has(hs) and hs.room == room)
	check("hitstop: flits frame 0", SomHitReact.contact_flash_active(hs))
	SomHitReact.tick(hs, 0.08)
	var hs_st: Dictionary = hs.get_meta(&"som_hitreact")
	check("hitstop: meta-timer bevriest", is_equal_approx(float(hs_st["t"]), 0.0))
	check("hitstop: timer bevriest tijdens hitstop", SomHitReact.contact_flash_active(hs))
	som.enemies[hs]["hitstop"] = 0
	SomHitReact.tick(hs, 0.08)
	check("hitstop: timer loopt na hitstop", not SomHitReact.contact_flash_active(hs))
	m.queue_free()
	mv.queue_free()
	a.queue_free()
	b.queue_free()
	twice.queue_free()
	rehit.queue_free()
	zd.queue_free()
	hs.queue_free()
	room.queue_free()


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
	check("sim-fingerprint stabiel na FX-ticks", fp1 == fp2 and fp1 != "")


func _clear_impact_fx(objects: Node) -> void:
	for c in objects.get_children():
		if str(c.name).begins_with("SomImpact") or c.name == "SomSpark":
			c.queue_free()


func _golem_invuln(f: GolemFight) -> bool:
	var guard := 0
	while f.hp() > 217 and guard < 100000:
		guard += 1
		f.tick()
		f.take_events()
		if f.is_invulnerable():
			return true
		var need := f.hp() - 217
		var raw := maxi(1, int(ceil(float(need) / f.core.damage_mult())))
		if f.core.open:
			if need < 2:
				continue
			raw = 1
		f.damage(raw)
	f.damage(10)
	f.take_events()
	return f.is_invulnerable()


func _pending_fx_leak_tests() -> void:
	var arena := await _setup_arena(4243)
	if arena == null:
		check("pending-leak arena", false)
		return
	var m: Node = null
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			m = k
			break
	check("pending-leak vijand", m != null)
	if m == null:
		return
	var objects := arena.room.get_node("Objects")
	# Onbekende vijand: pending wordt opgegeten vóór return.
	var stray := _fake_monster("stray_pending_leak")
	arena._pending_chain_step = SomChainData.STEP_HIT1
	arena._pending_impact_element = "vuur"
	arena.damage_enemy(stray, 9, Vector2i.RIGHT, false, 0, 0)
	check("onbekende vijand: pending geleegd", arena._pending_chain_step == -2 and arena._pending_impact_element == "")
	_clear_impact_fx(objects)
	arena.damage_enemy(m, 4, Vector2i.RIGHT, false, 0, 0)
	check("na stray-hit: fysiek-impact (geen chain-lek)", objects.get_node_or_null("SomImpact_fysiek") != null
			and objects.get_node_or_null("SomSpark") == null)
	_clear_impact_fx(objects)
	# Golem 0 schade (onkwetsbaar): zelfde pending-reset.
	var gf := GolemFight.new(360, 7)
	arena.enemies[m]["hp"] = 360
	arena.enemies[m]["golem"] = gf
	check("golem invuln voor 0-schade", _golem_invuln(gf))
	arena.enemies[m]["hp"] = gf.hp()
	arena._pending_chain_step = SomChainData.STEP_HIT2
	arena._pending_impact_element = ""
	var hp_before := gf.hp()
	arena.damage_enemy(m, 50, Vector2i.LEFT, false, 0, 0)
	check("golem 0-schade: pending geleegd", arena._pending_chain_step == -2)
	check("golem 0-schade: HP ongewijzigd", gf.hp() == hp_before)
	_clear_impact_fx(objects)
	arena._pending_chain_step = -2
	arena._pending_impact_element = ""
	arena.damage_enemy(m, 6, Vector2i.RIGHT, false, 0, 0)
	check("na golem-blok: generic fysiek-impact", objects.get_node_or_null("SomImpact_fysiek") != null
			and objects.get_node_or_null("SomSpark") == null)
	arena.enemies[m].erase("golem")
	stray.queue_free()


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