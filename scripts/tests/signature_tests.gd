extends Node
## F3 held-signatures. Start: godot --headless --path . -- --signaturetest

const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomHeavyData := preload("res://scripts/data/som_heavy_data.gd")
const SomStaggerData := preload("res://scripts/data/som_stagger_data.gd")
const SomSignatureData := preload("res://scripts/data/som_signature_data.gd")
const SomSignature := preload("res://scripts/som/som_signature.gd")
const SomFeelData := preload("res://scripts/data/som_feel_data.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const MapMonster := preload("res://scripts/dungeon/map_monster.gd")
const MockRoom := preload("res://scripts/tests/perfect_dodge_mock_room.gd")
const PlayerScript := preload("res://scripts/player.gd")
const SomAllyScript := preload("res://scripts/som/som_ally.gd")
const CombatStamina := preload("res://scripts/som/combat_stamina.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")

const VESPER_RNG_SEED := 4242
const VESPER_AT := Vector2(128, 120)

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
	SomSignatureData.force_active = true
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	_data_tests()
	_backstab_unit_tests()
	_dax_integration_tests()
	_seren_integration_tests()
	_vesper_integration_tests()
	_kael_integration_tests()
	_kael_coop_target_tests()
	_orion_integration_tests()
	_orion_chase_slow_tests()
	_orion_enemy_ai_chase_hook_tests()
	_orion_enemy_ai_telegraph_chase_hook_tests()
	_ally_ai_kael_test()
	_disabled_tests()
	SomSignatureData.force_active = null
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data_tests() -> void:
	check("data: vijf held-ids", SomSignatureData.HERO_IDS.size() == 5)
	check("data: krit en knock constanten", SomSignatureData.CRIT_MULT == 1.5 and SomSignatureData.DAX_KNOCK_FIN == 3)


func _arena() -> SomArena:
	var a := SomArena.new()
	a.down = false
	a.combat_stamina = CombatStamina.new()
	a.combat_roots = CombatRoots.new()
	GameState.new_game("Dax")
	GameState.add_member("lotte")
	GameState.add_member("noor")
	GameState.add_member("kael")
	GameState.add_member("orion")
	a.active_id = "dennis"
	a.charge = 1.0
	for hid in SomSignatureData.HERO_IDS:
		a.combat_stamina.init_member(hid)
	for m in GameState.party:
		m["hp"] = int(m["max_hp"])
	var r := MockRoom.new()
	var objs := Node2D.new()
	objs.name = "Objects"
	r.add_child(objs)
	a.room = r
	a.add_child(r)
	var p := CharacterBody2D.new()
	p.set_script(PlayerScript)
	p.facing = Vector2i.RIGHT
	p.position = Vector2(96, 120)
	a.player = p
	a.add_child(p)
	return a


func _enemy(a: SomArena, facing := Vector2i.LEFT, at := Vector2(160, 120)) -> MapMonster:
	var m := MapMonster.new()
	m.size = Vector2i.ONE
	m.facing = facing
	m.position = at
	m.tile = Vector2i(int(at.x / 16), int(at.y / 16))
	var e := {"hp": 200, "max_hp": 200, "atk": 5, "def": 2, "flash": 0.0, "tele": 0.0, "cd": 0.0, "chase": 0.0,
		"hitstop": 0, "target": "dennis", "data": {"max_hp": 200, "def": 2, "unique": false}, "stg": 0,
		"stg_idle": 0, "stg_wankel": 0, "stg_immune": 0}
	a.enemies[m] = e
	m.room = a.room
	return m


func _backstab_unit_tests() -> void:
	check("vesper backstab: van achter", SomSignature.backstab_hit(Vector2i.LEFT, Vector2i.LEFT))
	check("vesper backstab: van voren niet", not SomSignature.backstab_hit(Vector2i.LEFT, Vector2i.RIGHT))


func _dax_integration_tests() -> void:
	var a := _arena()
	a.active_id = "dennis"
	a.player.facing = Vector2i.RIGHT
	var m := _enemy(a, Vector2i.LEFT, Vector2(128, 120))
	a.chains["dennis"] = {"next": SomChainData.STEP_FINISHER, "window": 0, "state": "finisher", "last": 2}
	var stg0 := int(a.enemies[m].get("stg", 0))
	a.chain_swing("dennis", a.player, 1.0)
	check("dax finisher knockback via _land", a.last_knockback_tiles == SomSignatureData.DAX_KNOCK_FIN)
	var expect_stg := roundi(float(SomStaggerData.FILL_FINISHER) * SomSignatureData.DAX_STAGGER_MULT)
	check("dax finisher stagger x1.25 via _land", int(a.enemies[m]["stg"]) >= expect_stg and int(a.enemies[m]["stg"]) > stg0)
	var m2 := _enemy(a, Vector2i.LEFT, Vector2(128, 104))
	a.heavy_hold["dennis"] = SomHeavyData.LEVEL_TICKS[1]
	a.heavy_tick("dennis", false, a.player, 1.0)
	check("dax heavy L2 knockback via _land", a.last_knockback_tiles == SomSignatureData.DAX_KNOCK_HEAVY2)


func _seren_integration_tests() -> void:
	var a := _arena()
	a.active_id = "lotte"
	a.player.position = Vector2(100, 120)
	for h in GameState.party:
		if str(h.get("id", "")) == "dennis":
			h["hp"] = maxi(1, int(h["max_hp"]) / 5)
		elif str(h.get("id", "")) == "noor":
			h["hp"] = int(h["max_hp"])
	var d_hp := int(GameState.member("dennis")["hp"])
	var total0 := a.sig_heal_total
	SomSignature.try_seren_heal(a, "lotte", SomChainData.STEP_HIT1, 1)
	check("seren geen heal zonder finisher", a.last_sig_heal == 0 and a.sig_heal_total == total0)
	SomSignature.try_seren_heal(a, "lotte", SomChainData.STEP_FINISHER, 1)
	check("seren heal laagste dichtbij", a.last_sig_heal > 0 and int(GameState.member("dennis")["hp"]) > d_hp)
	var after1 := a.last_sig_heal
	var tot1 := a.sig_heal_total
	SomSignature.try_seren_heal(a, "lotte", SomChainData.STEP_FINISHER, 1)
	check("seren ICD blokkeert", a.last_sig_heal == after1 and a.sig_heal_total == tot1)
	var a_full := _arena()
	a_full.active_id = "lotte"
	a_full.player.position = Vector2(100, 120)
	SomSignature.try_seren_heal(a_full, "lotte", SomChainData.STEP_FINISHER, 1)
	check("seren geen ICD bij heal 0 (vol HP)", int(a_full._sig_icd.get("lotte", 0)) == 0 and a_full.sig_heal_total == 0)
	for i in SomSignatureData.SEREN_ICD_TICKS + 1:
		SomSignature.tick(a)
	var d_hp2 := int(GameState.member("dennis")["hp"])
	for h in GameState.party:
		if str(h.get("id", "")) == "dennis":
			h["hp"] = maxi(1, d_hp2 - 10)
	SomSignature.try_seren_heal(a, "lotte", SomChainData.STEP_FINISHER, 1)
	check("seren heal na ICD", a.sig_heal_total > tot1 and a.last_sig_heal > 0)
	var a_far := _arena()
	a_far.active_id = "lotte"
	a_far.player.position = Vector2(100, 120)
	for h in GameState.party:
		if str(h.get("id", "")) == "dennis":
			h["hp"] = 1
	var dax_far: CharacterBody2D = SomAllyScript.new()
	dax_far.setup(a_far, "dennis", 0)
	dax_far.position = Vector2(400, 120)
	a_far.room.add_child(dax_far)
	a_far.allies.append(dax_far)
	SomSignature.try_seren_heal(a_far, "lotte", SomChainData.STEP_FINISHER, 1)
	check("seren geen heal buiten 48px", a_far.last_sig_heal == 0)


func _noor_swing_dmg(a: SomArena, backstab: bool) -> int:
	a.rng.seed = VESPER_RNG_SEED
	# Backstab in sim: aanvalrichting · vijand-facing > 0,5 (zelfde kant als kijkrichting).
	var m := _enemy(a, Vector2i.RIGHT if backstab else Vector2i.LEFT, VESPER_AT)
	a.active_id = "noor"
	a.player.facing = Vector2i.RIGHT
	var hp0 := int(a.enemies[m]["hp"])
	a.chains["noor"] = {"next": SomChainData.STEP_HIT1, "window": 0, "state": "hit1", "last": 0}
	a.chain_swing("noor", a.player, 1.0)
	return hp0 - int(a.enemies[m]["hp"])


func _vesper_integration_tests() -> void:
	var front := _noor_swing_dmg(_arena(), false)
	var back := _noor_swing_dmg(_arena(), true)
	check("vesper front raakt", front > 0)
	check("vesper back == roundi(front*1.5)", back == roundi(float(front) * SomSignatureData.CRIT_MULT))
	var a_cnt := _arena()
	a_cnt.sig_backstab_hits = 0
	_noor_swing_dmg(a_cnt, true)
	check("vesper swing telt backstab", a_cnt.sig_backstab_hits == 1)


func _kael_integration_tests() -> void:
	var a := _arena()
	var m := _enemy(a)
	SomSignature.after_melee_hit(a, "kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	var until := int(a.enemies[m].get("sig_aggro", {}).get("until", 0))
	check("kael aggro gezet", until > a.sim_tick)
	check("kael target lock", SomSignature.aggro_target(a, m) == "kael")
	SomSignature.after_melee_hit(a, "kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("kael ICD: geen tweede lock", int(a.enemies[m]["sig_aggro"]["until"]) == until)
	for i in 12:
		SomSignature.tick(a)
		a.clock.tick += 1
	SomSignature.after_melee_hit(a, "kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("kael ICD: lock-eindtijd stabiel", int(a.enemies[m]["sig_aggro"]["until"]) == until)
	for i in SomSignatureData.KAEL_ICD_TICKS + 4:
		SomSignature.tick(a)
	check("kael ICD verloopt", SomSignature.icd_ready(a._sig_icd, "kael"))
	a.clock.tick += 1
	SomSignature.after_melee_hit(a, "kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	var until2 := int(a.enemies[m]["sig_aggro"]["until"])
	check("kael ICD: nieuwe lock na cooldown", until2 > until and until2 > a.sim_tick)
	while a.sim_tick < until2:
		a.clock.tick += 1
	check("kael lock verloopt", SomSignature.aggro_target(a, m) == "")
	# N1: exacte ICD-grens (tick 239 = nog niet klaar, tick 240 = klaar).
	var a_b := _arena()
	var m_b := _enemy(a_b)
	SomSignature.after_melee_hit(a_b, "kael", m_b, a_b.enemies[m_b], SomChainData.STEP_FINISHER, 0)
	check("kael ICD net gezet", not SomSignature.icd_ready(a_b._sig_icd, "kael"))
	for i in SomSignatureData.KAEL_ICD_TICKS - 1:
		SomSignature.tick(a_b)
	check("kael ICD blokkeert na 239 ticks", not SomSignature.icd_ready(a_b._sig_icd, "kael"))
	SomSignature.tick(a_b)
	check("kael ICD klaar na 240 ticks", SomSignature.icd_ready(a_b._sig_icd, "kael"))
	check("kael ICD constant is 240", SomSignatureData.KAEL_ICD_TICKS == 240)


func _kael_coop_target_tests() -> void:
	var a := _arena()
	a.coop_mode = true
	a.coop_sim_host = true
	a._coop_slots = {0: "dennis", 1: "lotte"}
	var m := _enemy(a)
	check("coop zonder lock: slot 0", a._target_for(m) == "dennis")
	a.enemies[m]["sig_aggro"] = {"hero": "kael", "until": a.sim_tick + SomSignatureData.KAEL_LOCK_TICKS}
	check("coop lock vóór slot 0", a._target_for(m) == "kael")


func _orion_integration_tests() -> void:
	var a := _arena()
	var m := _enemy(a)
	SomSignature.after_melee_hit(a, "orion", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("orion slow ticks", int(a.enemies[m].get("sig_slow", 0)) == SomSignatureData.ORION_SLOW_TICKS)
	var e_golem := {"golem": RefCounted.new()}
	SomSignature.after_melee_hit(a, "orion", m, e_golem, SomChainData.STEP_FINISHER, 0)
	check("orion geen slow op golem", not e_golem.has("sig_slow"))
	var tg := TelegraphAttack.new()
	var def: Dictionary = {"id": "sig_test", "windup_ms": 360, "active_ms": 120, "recovery_ms": 0, "shape": "line", "reach": 24}
	tg.configure(def, 500)
	var ed: Dictionary = a.enemies[m]
	ed["tg"] = tg
	SomSignature.on_telegraph_started(ed)
	tg.start(TelegraphShape.to_px(Vector2(160, 120)), Vector2i.RIGHT, str(def.get("shape", "line")))
	var w0 := tg.ticks_left_in_phase()
	SomSignature.after_melee_hit(a, "orion", m, ed, SomChainData.STEP_FINISHER, 0)
	var w1 := tg.ticks_left_in_phase()
	SomSignature.after_melee_hit(a, "orion", m, ed, SomChainData.STEP_FINISHER, 0)
	var w2 := tg.ticks_left_in_phase()
	check("orion windup +6 eenmalig", w1 == w0 + SomSignatureData.ORION_WINDUP_EXTRA_TICKS and w2 == w1)


func _orion_chase_slow_tests() -> void:
	var base := SomData.CHASE_INTERVAL
	var ed := {"sig_slow": 45}
	var slow_iv := SomSignature.chase_interval(base, ed)
	check("orion chase 0.6x", is_equal_approx(slow_iv, base / SomSignatureData.ORION_SLOW_MULT))
	var a := _arena()
	var m := _enemy(a)
	a.enemies[m]["sig_slow"] = SomSignatureData.ORION_SLOW_TICKS
	for i in SomSignatureData.ORION_SLOW_TICKS:
		SomSignature.tick(a)
	check("orion slow verloopt", int(a.enemies[m].get("sig_slow", 0)) == 0)
	check("orion chase normaal na tick", is_equal_approx(SomSignature.chase_interval(base, a.enemies[m]), base))


func _orion_enemy_ai_chase_hook_tests() -> void:
	var a := _arena()
	var m := _enemy(a, Vector2i.LEFT, Vector2(200, 120))
	var e: Dictionary = a.enemies[m]
	e["sig_slow"] = 90
	e["chase"] = 0.001
	e["tele"] = 0.0
	e["cd"] = 0.0
	e["target"] = "dennis"
	var expect_slow := SomSignature.chase_interval(SomData.CHASE_INTERVAL, e)
	m.is_moving = false
	a._enemy_ai(m, 0.02)
	check("_enemy_ai chase langzamer met sig_slow", is_equal_approx(float(e["chase"]), expect_slow))
	e["sig_slow"] = 0
	e["chase"] = 0.001
	m.is_moving = false
	a._enemy_ai(m, 0.02)
	check("_enemy_ai chase normaal zonder sig_slow", is_equal_approx(float(e["chase"]), SomData.CHASE_INTERVAL))


func _orion_enemy_ai_telegraph_chase_hook_tests() -> void:
	var a := _arena()
	var m := _enemy(a, Vector2i.LEFT, Vector2(200, 120))
	var e: Dictionary = a.enemies[m]
	var tg := TelegraphAttack.new()
	var def: Dictionary = {"id": "sig_test", "windup_ms": 360, "active_ms": 120, "recovery_ms": 0, "shape": "line", "reach": 24}
	tg.configure(def, 500)
	e["tg"] = tg
	e["sig_slow"] = 90
	e["chase"] = 0.001
	e["tele"] = 0.0
	e["cd"] = 0.0
	e["target"] = "dennis"
	var expect_slow := SomSignature.chase_interval(SomData.CHASE_INTERVAL, e)
	m.is_moving = false
	a._enemy_ai_telegraph(m, e, 0.02)
	check("_enemy_ai_telegraph chase langzamer met sig_slow", is_equal_approx(float(e["chase"]), expect_slow))
	e["sig_slow"] = 0
	e["chase"] = 0.001
	m.is_moving = false
	a._enemy_ai_telegraph(m, e, 0.02)
	check("_enemy_ai_telegraph chase normaal zonder sig_slow", is_equal_approx(float(e["chase"]), SomData.CHASE_INTERVAL))


func _ally_ai_kael_test() -> void:
	var a := _arena()
	var m := _enemy(a, Vector2i.LEFT, Vector2(130, 120))
	var ally: CharacterBody2D = SomAllyScript.new()
	ally.setup(a, "kael", 1)
	ally.position = Vector2(96, 120)
	ally.facing = Vector2i.RIGHT
	a.room.add_child(ally)
	a.allies.append(ally)
	a.chains["kael"] = {"next": SomChainData.STEP_FINISHER, "window": 10, "state": "finisher", "last": 1}
	var hits := a.chain_swing("kael", ally, 1.0)
	check("ally kael finisher raakt", hits > 0)
	check("ally kael aggro zelfde regel", SomSignature.aggro_target(a, m) == "kael")


func _disabled_tests() -> void:
	SomSignatureData.force_active = false
	check("uitgeschakeld", not SomSignatureData.is_active())
	var a := _arena()
	var m := _enemy(a, Vector2i.LEFT, Vector2(128, 120))
	a.active_id = "dennis"
	a.chains["dennis"] = {"next": SomChainData.STEP_FINISHER, "window": 0, "state": "finisher", "last": 2}
	a.chain_swing("dennis", a.player, 1.0)
	check("uit dennis: basis knockback finisher", a.last_knockback_tiles == SomChainData.knockback_tiles(SomChainData.STEP_FINISHER))
	var a_stg := _arena()
	var m_stg := _enemy(a_stg, Vector2i.LEFT, Vector2(128, 120))
	a_stg.active_id = "dennis"
	a_stg.chains["dennis"] = {"next": SomChainData.STEP_FINISHER, "window": 0, "state": "finisher", "last": 2}
	a_stg.chain_swing("dennis", a_stg.player, 1.0)
	check("uit dennis: stagger zonder x1.25", int(a_stg.enemies[m_stg]["stg"]) == SomStaggerData.FILL_FINISHER)
	a.active_id = "lotte"
	a.player.position = Vector2(100, 120)
	var dennis_hp_saved := 0
	for h in GameState.party:
		if str(h.get("id", "")) == "dennis":
			dennis_hp_saved = int(h["hp"])
			h["hp"] = maxi(1, int(h["max_hp"]) / 4)
	var heal_before := a.sig_heal_total
	SomSignature.try_seren_heal(a, "lotte", SomChainData.STEP_FINISHER, 1)
	check("uit lotte: geen heal bij gewonde in range", a.sig_heal_total == heal_before and a.last_sig_heal == 0
			and int(a._sig_icd.get("lotte", 0)) == 0)
	for h in GameState.party:
		if str(h.get("id", "")) == "dennis":
			h["hp"] = dennis_hp_saved
	var m2 := _enemy(a, Vector2i.LEFT, Vector2(128, 104))
	var dmg_back_off := _noor_swing_dmg(_arena(), true)
	var dmg_front_off := _noor_swing_dmg(_arena(), false)
	var a_last := _arena()
	_noor_swing_dmg(a_last, true)
	check("uit noor: geen backstab teller", a_last.sig_backstab_hits == 0)
	check("uit noor: geen crit (back ~= front)", dmg_back_off <= dmg_front_off + 2)
	SomSignature.after_melee_hit(a, "kael", m2, a.enemies[m2], SomChainData.STEP_FINISHER, 0)
	check("uit kael: geen aggro", not a.enemies[m2].has("sig_aggro"))
	SomSignature.after_melee_hit(a, "orion", m2, a.enemies[m2], SomChainData.STEP_FINISHER, 0)
	check("uit orion: geen slow", not a.enemies[m2].has("sig_slow"))
	SomSignatureData.force_active = true
