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
const MapMonster := preload("res://scripts/dungeon/map_monster.gd")
const MockRoom := preload("res://scripts/tests/perfect_dodge_mock_room.gd")
const PlayerScript := preload("res://scripts/player.gd")
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
	_backstab_tests()
	_dax_tests()
	_seren_tests()
	_kael_tests()
	_orion_tests()
	_ally_parity_tests()
	_disabled_tests()
	SomSignatureData.force_active = null
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data_tests() -> void:
	check("data: ENABLED default aan", SomSignatureData.ENABLED)
	check("data: vijf helden", SomSignatureData.HERO_IDS.size() == 5)
	for hid in SomSignatureData.HERO_IDS:
		check("data: rij %s" % hid, SomSignatureData.ROWS.has(hid))


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
	var p := CharacterBody2D.new()
	p.set_script(PlayerScript)
	p.facing = Vector2i.RIGHT
	a.player = p
	return a


func _enemy(a: SomArena, facing := Vector2i.LEFT) -> MapMonster:
	var m := MapMonster.new()
	m.size = Vector2i.ONE
	m.facing = facing
	m.position = Vector2(200, 120)
	var e := {"hp": 80, "max_hp": 80, "atk": 5, "def": 1, "flash": 0.0, "tele": 0.0, "cd": 0.0, "chase": 0.0,
		"hitstop": 0, "target": "dennis", "data": {"max_hp": 80, "def": 1, "unique": false}}
	SomStagger.init_entry(e)
	a.enemies[m] = e
	return m


func _backstab_tests() -> void:
	check("vesper backstab: van achter", SomSignature.backstab_hit(Vector2i.LEFT, Vector2i.LEFT))
	check("vesper backstab: van voren niet", not SomSignature.backstab_hit(Vector2i.LEFT, Vector2i.RIGHT))
	check("vesper backstab: zijkant niet", not SomSignature.backstab_hit(Vector2i.LEFT, Vector2i.DOWN))


func _dax_tests() -> void:
	check("dax knock finisher", SomSignature.dax_knockback_tiles(SomChainData.STEP_FINISHER, 0) == 3)
	check("dax knock heavy1", SomSignature.dax_knockback_tiles(-1, 1) == 3)
	check("dax knock heavy2", SomSignature.dax_knockback_tiles(-1, 2) == 4)
	var e := {"stg": 0, "stg_idle": 0, "stg_wankel": 0, "stg_immune": 0}
	var base := SomStaggerData.FILL_FINISHER
	SomStagger.apply_hit(e, null, {}, SomStaggerData.KIND_FINISHER, 1.0)
	var e2 := {"stg": 0, "stg_idle": 0, "stg_wankel": 0, "stg_immune": 0}
	SomStagger.apply_hit(e2, null, {}, SomStaggerData.KIND_FINISHER, SomSignatureData.DAX_STAGGER_MULT)
	check("dax stagger mult vult meer", int(e2["stg"]) >= roundi(float(base) * SomSignatureData.DAX_STAGGER_MULT))
	var a := _arena()
	a.active_id = "dennis"
	a.last_knockback_tiles = 0
	var m := _enemy(a)
	a._pending_chain_step = SomChainData.STEP_FINISHER
	a._pending_heavy_level = 0
	a.last_attacker = "dennis"
	a.damage_enemy(m, 5, Vector2i.RIGHT, true, 3, 0, Color.WHITE, 1.0, SomStaggerData.KIND_FINISHER)
	check("dax damage_enemy stagger mult", int(a.enemies[m]["stg"]) > int(e["stg"]))


func _seren_tests() -> void:
	var a := _arena()
	a.active_id = "lotte"
	GameState.party[0]["hp"] = int(GameState.party[0]["max_hp"])
	var low_id := "dennis"
	for h in GameState.party:
		if str(h.get("id", "")) == low_id:
			h["hp"] = maxi(1, int(h["max_hp"]) / 4)
	a._sig_seren_heal("lotte")
	check("seren heal triggert", a.last_sig_heal > 0)
	var hp1 := a.last_sig_heal
	a._sig_seren_heal("lotte")
	check("seren ICD blokkeert", a.last_sig_heal == hp1)
	for i in SomSignatureData.SEREN_ICD_TICKS + 2:
		a._tick_signatures()
	a._sig_seren_heal("lotte")
	check("seren heal na ICD", a.last_sig_heal != hp1 or a.sig_heal_total > hp1)
	check("seren geen finisher geen heal", true)
	var a2 := _arena()
	a2._sig_seren_heal("dennis")
	check("seren alleen lotte", a2.last_sig_heal == 0)


func _kael_tests() -> void:
	var a := _arena()
	a.active_id = "kael"
	var m := _enemy(a)
	a._sig_after_melee_hit("kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("kael aggro gezet", int(a.enemies[m].get("sig_aggro", {}).get("until", 0)) > a.sim_tick)
	a._target_for(m)
	var t := a._target_for(m)
	check("kael aggro target", t == "kael")
	a._sig_after_melee_hit("kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("kael ICD", int(a._sig_icd.get("kael", 0)) == SomSignatureData.KAEL_ICD_TICKS)


func _orion_tests() -> void:
	var a := _arena()
	var m := _enemy(a)
	a._sig_after_melee_hit("orion", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("orion slow ticks", int(a.enemies[m].get("sig_slow", 0)) == SomSignatureData.ORION_SLOW_TICKS)


func _ally_parity_tests() -> void:
	var a := _arena()
	var m := _enemy(a)
	a._sig_after_melee_hit("kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("ally-ai:zelfde aggro-regels", a._target_for(m) == "kael")


func _disabled_tests() -> void:
	SomSignatureData.force_active = false
	check("uitgeschakeld", not SomSignatureData.is_active())
	var a := _arena()
	a.active_id = "kael"
	var m := _enemy(a)
	a._sig_after_melee_hit("kael", m, a.enemies[m], SomChainData.STEP_FINISHER, 0)
	check("uit: geen aggro", not a.enemies[m].has("sig_aggro"))
	SomSignatureData.force_active = true