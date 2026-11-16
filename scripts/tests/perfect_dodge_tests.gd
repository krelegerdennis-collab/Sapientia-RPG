extends Node
## F1 perfect dodge. Start: godot --headless --path . -- --perfectdodgetest

const CombatSim := preload("res://scripts/som/combat_sim.gd")
const CombatStamina := preload("res://scripts/som/combat_stamina.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomStagger := preload("res://scripts/som/som_stagger.gd")
const SomStaggerData := preload("res://scripts/data/som_stagger_data.gd")
const SomPerfectDodgeData := preload("res://scripts/data/som_perfect_dodge_data.gd")
const SomFeelData := preload("res://scripts/data/som_feel_data.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const MapMonster := preload("res://scripts/dungeon/map_monster.gd")
const MockRoom := preload("res://scripts/tests/perfect_dodge_mock_room.gd")
const PlayerScript := preload("res://scripts/player.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")

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
	SomPerfectDodgeData.force_active = true
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	_fx_art_tests()
	_data_tests()
	_window_sim_step_tests()
	_window_coop_host_tests()
	_source_tests()
	_freeze_tests()
	_counter_tests()
	_stagger_counter_fill_tests()
	_stamina_icd_tests()
	_net_tests()
	_determinism_tests()
	_disabled_byte_tests()
	_ally_rate_tests()
	_followup_src_and_clear_tests()
	SomPerfectDodgeData.force_active = null
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _fx_art_tests() -> void:
	var ring: Dictionary = SomData.FX_PERFECT_RING
	var spark: Dictionary = SomData.FX_COUNTER_SPARK
	var tr: Texture2D = SomFx.tex(str(ring["sheet"]))
	var ts: Texture2D = SomFx.tex(str(spark["sheet"]))
	check("FX_PERFECT_RING sheet laadt", tr != null)
	check("FX_COUNTER_SPARK sheet laadt", ts != null)
	if tr != null:
		check("FX_PERFECT_RING size 64x16", tr.get_size() == Vector2(64, 16))
		check("FX_PERFECT_RING 4 frames", int(ring["frames"]) == 4 and tr.get_width() / int(ring["cell"][0]) == 4)
	if ts != null:
		check("FX_COUNTER_SPARK size 48x16", ts.get_size() == Vector2(48, 16))
		check("FX_COUNTER_SPARK 3 frames", int(spark["frames"]) == 3 and ts.get_width() / int(spark["cell"][0]) == 3)


func _arena() -> SomArena:
	var a := SomArena.new()
	a.down = false
	a.combat_stamina = CombatStamina.new()
	a.combat_roots = CombatRoots.new()
	GameState.new_game("Dax")
	GameState.add_member("lotte")
	a.active_id = "dennis"
	a.combat_stamina.init_member("dennis")
	a.combat_stamina.init_member("lotte")
	_mock_room(a)
	return a


func _mock_room(a: SomArena) -> void:
	var r := MockRoom.new()
	var objs := Node2D.new()
	objs.name = "Objects"
	r.add_child(objs)
	a.room = r
	var p := CharacterBody2D.new()
	p.set_script(PlayerScript)
	p.facing = Vector2i.DOWN
	a.player = p
	a._coop_slots = {0: "dennis", 1: "lotte"}


func _mock_enemy(a: SomArena, golem := false) -> MapMonster:
	var m := MapMonster.new()
	m.size = Vector2i.ONE
	m.position = Vector2(160, 160)
	var e := {
		"hp": 40, "max_hp": 40, "atk": 8, "def": 2, "flash": 0.0, "tele": 0.0, "cd": 0.0, "chase": 0.0,
		"hitstop": 0, "target": "dennis", "data": {"max_hp": 40, "def": 2, "unique": false},
	}
	if golem:
		e["golem"] = RefCounted.new()
	else:
		SomStagger.init_entry(e)
	a.enemies[m] = e
	return m


func _start_dodge(a: SomArena, id := "dennis", clear_icd := true, fill_stamina := true) -> void:
	a.iframes.clear()
	a._dodge_cd_ticks.erase(id)
	if clear_icd:
		a._pd_icd.erase(id)
	if fill_stamina:
		a.combat_stamina.set_current(id, SomData.STAMINA_MAX)
	a._dodge_roll_ticks.erase(id)
	a.try_active_dodge(id, Vector2.RIGHT)
	a.iframes[id] = float(SomData.DODGE_IFRAME_TICKS) * CombatSim.TICK_DT


func _age_dodge(a: SomArena, id: String, ticks: int) -> void:
	for _i in ticks:
		a._tick_perfect_dodge_pre()
		a.iframes[id] = float(SomData.DODGE_IFRAME_TICKS) * CombatSim.TICK_DT
		a._dodge_roll_ticks[id] = maxi(1, int(a._dodge_roll_ticks.get(id, 1)))


func _data_tests() -> void:
	check("data: default uit", not SomPerfectDodgeData.ENABLED)
	check("data: venster 6", SomPerfectDodgeData.WINDOW_TICKS == 6)
	check("data: gast +3", SomPerfectDodgeData.GUEST_BONUS_TICKS == 3)
	check("data: hitstop 18", SomPerfectDodgeData.HITSTOP_TICKS == 18)
	check("data: counter 30", SomPerfectDodgeData.COUNTER_WINDOW_TICKS == 30)
	check("data: ICD 90", SomPerfectDodgeData.ICD_TICKS == 90)
	check("data: refund 15", SomPerfectDodgeData.STAMINA_REFUND == 15)
	check("data: shake perfect", SomFeelData.shake_ticks("perfect") == 4)
	check("data: FLAG_PERFECT", Protocol.FLAG_PERFECT == 8)


func _window_sim_step_tests() -> void:
	var a := _arena()
	var m := _mock_enemy(a)
	for age in range(1, 8):
		a.perfect_count = 0
		a._pd_icd.erase("dennis")
		_start_dodge(a)
		_age_dodge(a, "dennis", age)
		var hp0 := int(GameState.member("dennis")["hp"])
		a.hit_member("dennis", 20, 1.0, 0, m)
		var perfect := a.perfect_count == 1
		check("sim_step pad: leeftijd %d perfect=%s" % [age, perfect], (age <= 6) == perfect)
		check("sim_step pad: geen schade bij perfect (leeftijd %d)" % age, int(GameState.member("dennis")["hp"]) == hp0)
	a.free(); m.free()

	var a2 := _arena()
	_start_dodge(a2)
	a2._dodge_roll_ticks.erase("dennis")
	a2.iframes["dennis"] = SomData.PLAYER_IFRAMES
	var hp1 := int(GameState.member("dennis")["hp"])
	a2.hit_member("dennis", 20)
	check("post-hit iframes: geen perfect", a2.perfect_count == 0)
	check("post-hit iframes: iframes blokkeren schade", int(GameState.member("dennis")["hp"]) == hp1)
	a2.free()


func _window_coop_host_tests() -> void:
	var a := _arena()
	a.coop_mode = true
	a.coop_sim_host = true
	a.active_id = "lotte"
	var lotte_body := CharacterBody2D.new()
	lotte_body.set_script(PlayerScript)
	lotte_body.facing = Vector2i.DOWN
	a.player = lotte_body
	var m := _mock_enemy(a)
	for age in [8, 9, 10]:
		a.perfect_count = 0
		a._pd_icd.erase("lotte")
		_start_dodge(a, "lotte")
		_age_dodge(a, "lotte", age)
		a.hit_member("lotte", 15, 1.0, 0, m)
		var ok: bool = (age <= 9 and a.perfect_count == 1) or (age > 9 and a.perfect_count == 0)
		check("coop gast leeftijd %d venster 9" % age, ok)
	# volgorde coop_host_step: pre-tick vóór vijand (geen vijanden in de AI-loop)
	a.enemies.clear()
	a.perfect_count = 0
	a._pd_age.erase("dennis")
	a._pd_icd.erase("dennis")
	a.combat_stamina.set_current("dennis", 40)
	a.try_active_dodge("dennis", Vector2.RIGHT)
	a.coop_host_step([], CombatSim.TICK_DT)
	a.enemies[m] = {"hp": 40, "max_hp": 40, "atk": 8, "def": 2, "flash": 0.0, "tele": 0.0, "cd": 0.0, "chase": 0.0,
			"hitstop": 0, "target": "dennis", "data": {"max_hp": 40, "def": 2, "unique": false}}
	SomStagger.init_entry(a.enemies[m])
	a.hit_member("dennis", 12, 1.0, 0, m)
	check("coop_host_step: perfect na dodge zelfde tick-keten", a.perfect_count == 1)
	a.free(); m.free()


func _source_tests() -> void:
	var a := _arena()
	var m := _mock_enemy(a)
	_start_dodge(a)
	_age_dodge(a, "dennis", 1)
	a.hit_member("dennis", 10, 1.0, 0, m)
	check("bron melee: perfect", a.perfect_count == 1)
	a.perfect_count = 0
	_start_dodge(a)
	_age_dodge(a, "dennis", 1)
	a.enemies[m]["tg"] = TelegraphAttack.new()
	var pc_t := a.perfect_count
	a.hit_member("dennis", 10, 1.0, 0, m)
	check("bron telegraaf: perfect", a.perfect_count == pc_t + 1)
	a.perfect_count = 0
	_start_dodge(a)
	_age_dodge(a, "dennis", 1)
	var g := _mock_enemy(a, true)
	var pc_g := a.perfect_count
	a.hit_member("dennis", 10, 1.0, 0, g)
	check("bron Golem-strike: perfect", a.perfect_count == pc_g + 1)
	var pc_before := a.perfect_count
	var hp0 := int(GameState.member("dennis")["hp"])
	a.iframes.erase("dennis")
	a._dodge_roll_ticks.erase("dennis")
	a.hit_member_zone_dot("dennis", 10, 1.0)
	check("zone-DoT: geen perfect", a.perfect_count == pc_before and int(GameState.member("dennis")["hp"]) < hp0)
	a.free(); m.free(); g.free()


func _freeze_tests() -> void:
	var a := _arena()
	var m1 := _mock_enemy(a)
	var m2 := _mock_enemy(a)
	a.enemies[m2]["cd"] = 0.0
	_start_dodge(a)
	_age_dodge(a, "dennis", 2)
	a.hit_member("dennis", 8, 1.0, 0, m1)
	var hs1 := int(a.enemies[m1].get("hitstop", 0))
	var hs2 := int(a.enemies[m2].get("hitstop", 0))
	check("freeze: aanvaller hitstop 18", hs1 == SomPerfectDodgeData.HITSTOP_TICKS)
	check("freeze: andere vijand door", hs2 == 0)
	a.perfect_count = 0
	a._pd_icd.erase("dennis")
	_start_dodge(a)
	_age_dodge(a, "dennis", 2)
	a.enemies[m1]["hitstop"] = 12
	a.hit_member("dennis", 8, 1.0, 0, m1)
	check("freeze: max met bestaande hitstop", int(a.enemies[m1]["hitstop"]) == 18)
	var g := _mock_enemy(a, true)
	_start_dodge(a)
	_age_dodge(a, "dennis", 2)
	a.hit_member("dennis", 8, 1.0, 0, g)
	check("Golem freeze 0", int(a.enemies[g].get("hitstop", 0)) == 0)
	a.free(); m1.free(); m2.free(); g.free()


func _counter_tests() -> void:
	var a := _arena()
	var m := _mock_enemy(a)
	_start_dodge(a)
	_age_dodge(a, "dennis", 1)
	a.hit_member("dennis", 8, 1.0, 0, m)
	check("counter: venster open", int(a._pd_counter.get("dennis", 0)) == SomPerfectDodgeData.COUNTER_WINDOW_TICKS)
	var atk := float(GameState.effective_stat(GameState.member("dennis"), "atk"))
	var ctr_rng := a.rng.state
	var dmg_base := a.physical_damage(atk, 2.0, 1.0, a.rng)
	a.rng.state = ctr_rng
	var dmg_counter := a.physical_damage(atk, 2.0, SomPerfectDodgeData.COUNTER_DAMAGE_MULT, a.rng)
	a.rng.state = ctr_rng
	var ctr_spread := a.rng.randf_range(0.85, 1.15)
	var lin := (atk - 2.0 / 2.0) * 1.0
	var expect_counter := maxi(1, roundi(lin * SomPerfectDodgeData.COUNTER_DAMAGE_MULT * ctr_spread))
	var hp0 := int(a.enemies[m]["hp"])
	a._pd_counter["dennis"] = 8
	a.damage_enemy(m, dmg_counter, Vector2i.RIGHT, false, 0, 0,
			SomFeelData.COL_HEAVY, SomPerfectDodgeData.COUNTER_NUM_SCALE, SomStaggerData.KIND_NONE)
	var hp1 := int(a.enemies[m]["hp"])
	a.enemies[m]["hp"] = hp0
	a.damage_enemy(m, dmg_base, Vector2i.RIGHT, false, 0, 0, Color.WHITE, 1.0, SomStaggerData.KIND_NONE)
	var hp2 := int(a.enemies[m]["hp"])
	check("counter: x1.5 schade", dmg_counter == expect_counter and dmg_base == maxi(1, roundi(lin * ctr_spread)))
	check("counter: meer dan gewone slag", (hp0 - hp1) > (hp0 - hp2))
	a._pd_counter["dennis"] = 12
	for _i in 12:
		a._tick_perfect_dodge_pre()
	check("counter: verloopt na 30 ticks", not a._pd_counter.has("dennis"))
	a.free(); m.free()


func _stagger_counter_fill_tests() -> void:
	var a := _arena()
	var m := _mock_enemy(a)
	var e: Dictionary = a.enemies[m]
	e["stg"] = 70
	SomStagger.apply_hit(e, m, e["data"], SomStaggerData.KIND_HIT1)
	SomStagger.apply_hit(e, m, e["data"], SomStaggerData.KIND_PERFECT_COUNTER)
	check("stagger: +20 perfect-counter bovenop", int(e["stg"]) == 70 + SomStaggerData.FILL_HIT1 + SomStaggerData.FILL_PERFECT_COUNTER)
	SomStagger.enter_wankel(e)
	e["stg_wankel"] = 5
	var before := int(e["stg"])
	SomStagger.apply_hit(e, m, e["data"], SomStaggerData.KIND_PERFECT_COUNTER)
	check("stagger: geen vulling in wankel", int(e["stg"]) == before)
	var g := _mock_enemy(a, true)
	var eg: Dictionary = a.enemies[g]
	before = int(eg.get("stg", 0))
	SomStagger.apply_hit(eg, g, eg["data"], SomStaggerData.KIND_PERFECT_COUNTER)
	check("stagger: geen vulling op Golem", int(eg.get("stg", before)) == before)
	a.free(); m.free(); g.free()


func _stamina_icd_tests() -> void:
	var a := _arena()
	var m := _mock_enemy(a)
	a.combat_stamina.set_current("dennis", 50)
	var sta_before := 50
	_start_dodge(a, "dennis", true, false)
	_age_dodge(a, "dennis", 1)
	a.hit_member("dennis", 5, 1.0, 0, m)
	check("stamina: +15 clamp", a.combat_stamina.current("dennis") == mini(SomData.STAMINA_MAX, sta_before - SomData.STAMINA_DODGE_COST + SomPerfectDodgeData.STAMINA_REFUND))
	check("ICD: eerste perfect geteld", a.perfect_count == 1)
	_start_dodge(a, "dennis", false)
	_age_dodge(a, "dennis", 1)
	a.hit_member("dennis", 5, 1.0, 0, m)
	check("ICD: tweede perfect binnen 90 geblokkeerd", a.perfect_count == 1)
	a.free(); m.free()


func _net_tests() -> void:
	check("payload bytes", Protocol.snapshot_payload_bytes() == 218)
	check("uplink B/s", Protocol.host_uplink_bytes_per_sec() == 15960)
	check("codec vijand-bytes v2", Protocol.SNAPSHOT_ENEMY_BYTES_V2 == 21)
	var row := {"idx": 0, "x": 1, "y": 2, "hp": 9, "pose": SomPerfectDodgeData.POSE_FREEZE_BIT, "target_slot": 0,
			"atk_id": 0, "phase": 0, "t": 0, "ox": 0, "oy": 0, "dir_x": 0, "dir_y": 0, "stg": 0}
	var players := [{"slot": 0, "x": 0, "y": 0, "face": 0, "frame": 0, "hp": 10, "mp": 80, "flags": Protocol.FLAG_PERFECT}]
	var raw := Codec.pack_snapshot(3, players, [row])
	var snap := Codec.unpack_snapshot(raw)
	check("codec round-trip pose bit", int(snap["enemies"][0]["pose"]) == 1)
	check("codec round-trip FLAG_PERFECT", int(snap["players"][0]["flags"]) & Protocol.FLAG_PERFECT != 0)


func _determinism_tests() -> void:
	var logs: Array = []
	for _r in 2:
		var a := _arena()
		a.seed_rng(424242)
		var m := _mock_enemy(a)
		for _i in 6:
			_start_dodge(a)
			_age_dodge(a, "dennis", 2)
			a.hit_member("dennis", 4, 1.0, 0, m)
			for _t in 5:
				a._tick_perfect_dodge_pre()
		logs.append(",".join(a.perfect_event_ticks.map(func(t): return str(t))))
		a.free(); m.free()
	check("determinisme perfect ticks", logs.size() == 2 and logs[0] == logs[1])


func _disabled_byte_tests() -> void:
	SomPerfectDodgeData.force_active = false
	var a := _arena()
	var m := _mock_enemy(a)
	_start_dodge(a)
	_age_dodge(a, "dennis", 2)
	a.hit_member("dennis", 7, 1.0, 0, m)
	check("ENABLED uit: geen perfect", a.perfect_count == 0)
	check("ENABLED uit: geen pd-dicts", a._pd_age.is_empty() and a._pd_counter.is_empty())
	SomPerfectDodgeData.force_active = true
	a.free(); m.free()


func _ally_rate_tests() -> void:
	## Model van ally-dodge-AI: windup k=8..1, kans 0,55 skip/tick, perfect als k<=6 na 1 age-tick.
	var a := _arena()
	a.seed_rng(991001)
	var m := _mock_enemy(a)
	var tries := 0
	var perfects := 0
	a.combat_stamina.set_current("dennis", SomData.STAMINA_MAX)
	for _round in 800:
		var dodged := false
		for k in range(8, 0, -1):
			if a.rng.randf() > 0.55:
				continue
			a._pd_icd.erase("dennis")
			a._dodge_cd_ticks.erase("dennis")
			a.combat_stamina.set_current("dennis", SomData.STAMINA_MAX)
			if not a.try_active_dodge("dennis", Vector2.RIGHT):
				continue
			tries += 1
			dodged = true
			a.iframes["dennis"] = 1.0
			if k <= 6:
				a._tick_perfect_dodge_pre()
			else:
				for _t in 7:
					a._tick_perfect_dodge_pre()
			var before := a.perfect_count
			a.hit_member("dennis", 4, 1.0, 0, m)
			if a.perfect_count > before:
				perfects += 1
			a._dodge_roll_ticks.erase("dennis")
			a.iframes.erase("dennis")
			break
	check("ally-model: minstens 50 dodge-pogingen", tries >= 50)
	var rate := 0.0 if tries == 0 else float(perfects) / float(tries) * 100.0
	check("ally-model: perfect-rate 10-30%% (%.1f%%, n=%d)" % [rate, tries], rate >= 10.0 and rate <= 30.0)
	a.free(); m.free()


## Follow-ups: src door hit_player, en tellers leeg na gevecht.
func _followup_src_and_clear_tests() -> void:
	var a := _arena()
	var m1 := _mock_enemy(a)
	var m2 := _mock_enemy(a)
	_start_dodge(a)
	_age_dodge(a, "dennis", 2)
	a.hit_player(8, Vector2.ZERO, m1)
	check("hit_player src: perfect", a.perfect_count == 1)
	check("hit_player src: juiste vijand", int(a.enemies[m1].get("hitstop", 0)) == SomPerfectDodgeData.HITSTOP_TICKS and bool(a.enemies[m1].get("pd_freeze", false)))
	check("hit_player src: andere vijand niet", int(a.enemies[m2].get("hitstop", 0)) == 0 and not bool(a.enemies[m2].get("pd_freeze", false)))
	a._pd_icd.erase("dennis")
	a.perfect_count = 0
	a.last_perfect_hitstop = -1
	a.enemies[m1]["hitstop"] = 0
	a.enemies[m1]["pd_freeze"] = false
	_start_dodge(a)
	_age_dodge(a, "dennis", 2)
	a.hit_player(8, Vector2.ZERO, null)
	check("hit_player null src: geen crash", true)
	check("hit_player null src: perfect zonder vijand-freeze", a.perfect_count == 1 and int(a.enemies[m1].get("hitstop", 0)) == 0 and int(a.enemies[m2].get("hitstop", 0)) == 0 and a.last_perfect_hitstop == -1)
	a._pd_icd.erase("dennis")
	_start_dodge(a)
	_age_dodge(a, "dennis", 2)
	a.hit_player(8)
	check("hit_player zonder src-argument: geen crash", a.perfect_count == 2)
	a.perfect_count = 3
	a.perfect_event_ticks = [4, 9, 12]
	a._clear_transient_combat()
	check("clear: perfect_count 0", a.perfect_count == 0)
	check("clear: perfect_event_ticks leeg", a.perfect_event_ticks.is_empty())
	a.free(); m1.free(); m2.free()
