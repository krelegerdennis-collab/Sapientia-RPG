extends Node
## F3 held-signatures. Start: godot --headless --path . -- --signaturetest

const SomArena := preload("res://scripts/som/som_arena.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomHeavyData := preload("res://scripts/data/som_heavy_data.gd")
const SomStagger := preload("res://scripts/som/som_stagger.gd")
const SomStaggerData := preload("res://scripts/data/som_stagger_data.gd")
const SomSignatureData := preload("res://scripts/data/som_signature_data.gd")
const SomSignature := preload("res://scripts/som/som_signature.gd")
const SomFeelData := preload("res://scripts/data/som_feel_data.gd")
const SomActionAttacks := preload("res://scripts/data/som_action_attacks.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const MapMonster := preload("res://scripts/dungeon/map_monster.gd")
const MockRoom := preload("res://scripts/tests/perfect_dodge_mock_room.gd")
const PlayerScript := preload("res://scripts/player.gd")
const SomAllyScript := preload("res://scripts/som/som_ally.gd")
const CombatStamina := preload("res://scripts/som/combat_stamina.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")

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
	_orion_integration_tests()
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
	var e := {"hp": 200, "max_hp": 200, "atk": 5, "def": 2, "flash": 0.0, "tele": 0.0, "cd": 0.0, "chase": 0.0,
		"hitstop": 0, "target": "dennis", "data": {"max_hp": 200, "def": 2, "unique": false}}
	SomStagger.init_entry(e)
	a.enemies[m] = e
	return m


func _backstab_unit_tests() -> void:
	check("vesper backstab: van achter", SomSignature.backstab_hit(Vector2i.LEFT, Vector2i.LEFT))
	check("vesper backstab: van voren niet", not SomSignature.backstab_hit(Vector2i.LEFT, Vector2i.RIGHT))


func _dax_integration_tests() -> void:
	check("dax knock 3/3/4", SomSignature.dax_knockback_tiles(SomChainData.STEP_FINISHER, 0) == 3
			and SomSignature.dax_knockback_tiles(-1, 1) == 3 and SomSignature.dax_knockback_tiles(-1, 2) == 4)
	var e0 := {"stg": 0, "stg_idle": 0, "stg_wankel": 0, "stg_immune": 0}
	SomStagger.apply_hit(e0, null, {}, SomStaggerData.KIND_FINISHER, 1.0)
	var e1 := {"stg": 0, "stg_idle": 0, "stg_wankel": 0, "stg_immune": 0}
	SomStagger.apply_hit(e1, null, {}, SomStaggerData.KIND_FINISHER, SomSignatureData.DAX_STAGGER_MULT)
	check("dax stagger x1,25", int(e1["stg"]) > int(e0["stg"]))
	var a := _arena()
	var m := _enemy(a)
	a.last_attacker = "dennis"
	a._pending_chain_step = SomChainData.STEP_FINISHER
	a._pending_heavy_level = 0
	a.last_knockback_tiles = 0
	a.damage_enemy(m, 8, Vector2i.RIGHT, true, SomSignatureData.DAX_KNOCK_FIN, 0,
			Color.WHITE, 1.0, SomStaggerData.KIND_FINISHER)
	check("dax finisher knockback 3", a.last_knockback_tiles == 3)


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


func _vesper_integration_tests() -> void:
	var a := _arena()
	a.active_id = "noor"
	a.player.facing = Vector2i.RIGHT
	var m := _enemy(a, Vector2i.LEFT)
	var base := 40
	a.sig_backstab_hits = 0
	var front: Dictionary = SomSignature.adjust_melee_damage(a, "noor", m, base, Vector2i.RIGHT, Color.WHITE, 1.0)
	check("vesper front geen crit", front["dmg"] == base and a.sig_backstab_hits == 0)
	var a2 := _arena()
	var m2 := _enemy(a2, Vector2i.LEFT)
	var back: Dictionary = SomSignature.adjust_melee_damage(a2, "noor", m2, base, Vector2i.LEFT, Color.WHITE, 1.0)
	check("vesper back crit x1.5", back["dmg"] == roundi(float(base) * SomSignatureData.CRIT_MULT))
	check("vesper back goud", back["color"] == SomFeelData.COL_FINISHER_NUMBER)


func _kael_integration_tests() -> void:
	var a := _arena()
	var m := _enemy(a)
	SomSignature.after_melee_hit(a, "kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	var until := int(a.enemies[m].get("sig_aggro", {}).get("until", 0))
	check("kael aggro gezet", until > a.sim_tick)
	check("kael target lock", SomSignature.aggro_target(a, m) == "kael")
	SomSignature.after_melee_hit(a, "kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("kael ICD: geen tweede lock", int(a.enemies[m]["sig_aggro"]["until"]) == until)
	while a.sim_tick < until:
		a.clock.tick += 1
	check("kael lock verloopt", SomSignature.aggro_target(a, m) == "")


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
	var m := _enemy(a)
	SomSignature.after_melee_hit(a, "kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("uit: geen aggro", not a.enemies[m].has("sig_aggro"))
	SomSignatureData.force_active = true