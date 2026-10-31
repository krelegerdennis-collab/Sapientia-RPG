extends Node
## D3 PR B: realtime Golem (GolemBoss + BossCoreRt + GolemFight + GolemBossView). Start: godot --path . -- --golemactiontest

const BossScript := preload("res://scripts/som/boss_script.gd")
const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")
const BossCoreRt := preload("res://scripts/som/boss_core_rt.gd")
const GolemBossView := preload("res://scripts/som/golem_boss_view.gd")
const EnemyAttacks := preload("res://scripts/som/enemy_attacks.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")

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
	_stats_tests()
	_registry_tests()
	_attack_rule_tests()
	_core_rt_tests()
	_fight_phase_tests()
	_fight_core_every_phase_tests()
	_fight_misc_tests()
	_determinism_tests()
	_view_tests()
	_mult_removed_tests()
	GolemBoss.unregister()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _stats_tests() -> void:
	var d := SomData.action_boss_stats(GameData.ENEMIES["kennis_beest"].duplicate(true), 1)
	check("Golem stats ongewijzigd: HP 360 ATK 27 DEF 15 (%d/%d/%d)" % [d["max_hp"], d["atk"], d["def"]],
		int(d["max_hp"]) == 360 and int(d["atk"]) == 27 and int(d["def"]) == 15)
	var d4 := SomData.action_boss_stats(GameData.ENEMIES["kennis_beest"].duplicate(true), 4)
	check("boss_party_scale: 4 spelers ook 360 HP (geen schaal in v1)", int(d4["max_hp"]) == 360)


func _registry_tests() -> void:
	GolemBoss.ensure_registered()
	check("REGISTRY: kennis_beest geregistreerd", BossScript.has_script("kennis_beest"))
	GolemBoss.ensure_registered()
	var phases: Array = BossScript.script_for("kennis_beest").get("phases", [])
	check("3 fases", phases.size() == 3)
	check("drempels 60% / 25% / 0%", phases.size() == 3 and is_equal_approx(float(phases[0]["hp_until"]), 0.60)
		and is_equal_approx(float(phases[1]["hp_until"]), 0.25) and is_equal_approx(float(phases[2]["hp_until"]), 0.0))
	check("adds alleen fase 2: 2x papiergeest", (phases[0]["adds"] as Array).is_empty() and phases[1]["adds"] == ["papiergeest", "papiergeest"]
		and (phases[2]["adds"] as Array).is_empty())
	check("geen enrage", not bool(GolemBoss.SCRIPT.get("enrage", true)))
	check("gewone kennis_beest (geen baas) krijgt geen telegraaf-pool", not EnemyAttacks.has_telegraph_attack("kennis_beest"))


func _attack_rule_tests() -> void:
	check("DODGE_IFRAME_TICKS = 15", SomData.DODGE_IFRAME_TICKS == 15)
	var phase_ids := {}
	for p in GolemBoss.SCRIPT["phases"]:
		for a in p["attacks"]:
			phase_ids[str(a["id"])] = true
	for id in phase_ids:
		check("fase-aanval %s bestaat" % id, GolemBoss.ATTACKS.has(id))
	for id in GolemBoss.ATTACKS:
		var a: Dictionary = GolemBoss.ATTACKS[id]
		var min_w := GolemBoss.MIN_WINDUP_LARGE_AOE_TICKS if bool(a["large_aoe"]) else GolemBoss.MIN_WINDUP_TICKS
		check("%s windup %d >= %d" % [id, a["windup"], min_w], int(a["windup"]) >= min_w)
		if a.has("windup2"):
			check("%s 2e windup %d >= %d" % [id, a["windup2"], min_w], int(a["windup2"]) >= min_w)
		check("%s actief %d <= %d en < dodge-iframes 15" % [id, a["active"], GolemBoss.MAX_ACTIVE_TICKS],
			int(a["active"]) <= GolemBoss.MAX_ACTIVE_TICKS and int(a["active"]) < SomData.DODGE_IFRAME_TICKS)
		var ea := EnemyAttacks.attack(id)
		check("%s via EnemyAttacks: ms -> ticks exact (%d/%d/%d)" % [id, a["windup"], a["active"], a["recovery"]],
			TelegraphState.ms_to_ticks(int(ea["windup_ms"])) == int(a["windup"])
			and TelegraphState.ms_to_ticks(int(ea["active_ms"])) == int(a["active"])
			and TelegraphState.ms_to_ticks(int(ea["recovery_ms"])) == int(a["recovery"]))
	check("hammer_blow r=3 tegels, windup 42", is_equal_approx(float(GolemBoss.ATTACKS["golem_hammer_blow"]["reach_tiles"]), 3.0)
		and int(GolemBoss.ATTACKS["golem_hammer_blow"]["windup"]) == 42)
	check("p3 hammer_blow windup 48", int(GolemBoss.ATTACKS["golem_hammer_blow_p3"]["windup"]) == 48)
	check("book_hammer x2: 36 + 24", int(GolemBoss.ATTACKS["golem_book_hammer_x2"]["windup"]) == 36
		and int(GolemBoss.ATTACKS["golem_book_hammer_x2"]["windup2"]) == 24 and int(GolemBoss.ATTACKS["golem_book_hammer_x2"]["repeat"]) == 2)


func _core_rt_tests() -> void:
	check("kern: 8 s cyclus, 2 s open, break 45", int(GolemBoss.CORE["cycle_ticks"]) == 480 and int(GolemBoss.CORE["open_ticks"]) == 120
		and int(GolemBoss.CORE["break_damage"]) == 45)
	var c := BossCoreRt.new(GolemBoss.CORE)
	var opens: Array = []
	var slams: Array = []
	for t in range(1, 1441):
		var e := c.tick()
		if e == "open":
			opens.append(t)
		elif e == "slam":
			slams.append(t)
	check("kern open op tick 360/840/1320 (%s)" % str(opens), opens == [360, 840, 1320])
	check("zonder break: slam op tick 480/960/1440 (%s)" % str(slams), slams == [480, 960, 1440])
	c = BossCoreRt.new(GolemBoss.CORE)
	for t in 360:
		c.tick()
	check("dicht: x0.4, open: x2.0", c.open and is_equal_approx(c.damage_mult(), 2.0))
	check("44 schade: nog geen break", not c.add_dealt(44) and c.open)
	check("45e punt: break", c.add_dealt(1) and not c.open and c.broken_count == 1)
	var next_open := -1
	var slam_after_break := false
	for t in range(361, 1000):
		var e := c.tick()
		if e == "open" and next_open < 0:
			next_open = t
		if e == "slam" and t < 840:
			slam_after_break = true
	check("na break: geen slam en vaste cyclus (volgende opening tick %d = 840)" % next_open, next_open == 840 and not slam_after_break)
	check("dicht venster: schade x0.4 (10 -> 4)", BossCoreRt.new(GolemBoss.CORE).scale_damage(10) == 4)


## Damage tot net onder een drempel, met tikken ertussen.
func _hit_to(f: GolemFight, hp_target: int) -> void:
	var guard := 0
	while f.hp() > hp_target and guard < 100000:
		guard += 1
		f.tick()
		f.take_events()
		if f.is_invulnerable():
			continue
		var need := f.hp() - hp_target
		var raw := maxi(1, int(ceil(float(need) / f.core.damage_mult())))
		if f.core.open:
			if need < 2:
				continue
			raw = 1
		f.damage(raw)


func _fight_phase_tests() -> void:
	var f := GolemFight.new(360, 7)
	check("start fase 0, HP 360", f.phase_index() == 0 and f.hp() == 360)
	_hit_to(f, 217)
	f.take_events()
	# 216 = 60% van 360
	f.damage(10)
	var ev := f.take_events()
	var types := ev.map(func(e): return str(e["type"]))
	check("onder 60%%: fase 1 + 2 papiergeest-adds (%s)" % str(types), f.phase_index() == 1 and types.has("phase") and types.has("adds")
		and ev.any(func(e): return str(e["type"]) == "adds" and e["ids"] == ["papiergeest", "papiergeest"]))
	check("fasewissel: onkwetsbaar", f.is_invulnerable())
	check("onkwetsbaar: schade 0", f.damage(50) == 0)
	var n := 0
	var attacks_in_invuln := false
	while f.is_invulnerable():
		f.tick()
		n += 1
		for e in f.take_events():
			if str(e["type"]) == "telegraph_start" or str(e["type"]) == "attack_hit":
				attacks_in_invuln = true
	check("90 ticks onkwetsbaar (%d)" % n, n == 90)
	check("geen aanvallen tijdens fasewissel", not attacks_in_invuln)
	check("geen telegraaf na fasewissel actief", f.step != GolemFight.Step.WINDUP)
	_hit_to(f, 91)
	f.damage(5)
	ev = f.take_events()
	check("onder 25%%: fase 2, geen nieuwe adds", f.phase_index() == 2 and not ev.any(func(e): return str(e["type"]) == "adds"))
	# telegraaf vervalt bij fasewissel
	var g := GolemFight.new(360, 3)
	var guard := 0
	while g.step != GolemFight.Step.WINDUP and guard < 1000:
		guard += 1
		g.tick()
		g.take_events()
	g.damage(int(ceil(146.0 / 0.4)))
	ev = g.take_events()
	check("lopende telegraaf vervalt bij fasewissel", g.phase_index() == 1 and ev.any(func(e): return str(e["type"]) == "telegraphs_cancelled")
		and g.step == GolemFight.Step.IDLE)
	check("overkill: hoogstens één fasewissel per klap", g.phase_index() == 1)


## Kern in ELKE fase: opening precies 360 ticks na einde fasewissel (klok pauzeert tijdens invuln).
func _fight_core_every_phase_tests() -> void:
	for target_phase in [0, 1, 2]:
		var f := GolemFight.new(360, 11)
		if target_phase >= 1:
			_hit_to(f, 217)
			f.damage(10)
		if target_phase >= 2:
			while f.is_invulnerable():
				f.tick()
			_hit_to(f, 91)
			f.damage(5)
		f.take_events()
		while f.is_invulnerable():
			f.tick()
			f.take_events()
		var opened_at := -1
		var closed_at := -1
		var normal_start_while_open := false
		var start := f.tick_no
		for i in 700:
			f.tick()
			for e in f.take_events():
				if str(e["type"]) == "core_open" and opened_at < 0:
					opened_at = f.tick_no - start
				if str(e["type"]) == "core_slam" and closed_at < 0:
					closed_at = f.tick_no - start
				if str(e["type"]) == "telegraph_start" and f.core.open and not str(e["id"]).begins_with("golem_hammer_blow"):
					normal_start_while_open = true
		check("fase %d: kern open na 6 s (tick %d), 2 s open (dicht op %d)" % [target_phase + 1, opened_at, closed_at],
			f.phase_index() == target_phase and opened_at == 360 and closed_at == 480)
		check("fase %d: geen gewone aanval starten in het open venster" % [target_phase + 1], not normal_start_while_open)


func _fight_misc_tests() -> void:
	# break -> stagger 60 ticks, geen hammer_blow
	var f := GolemFight.new(360, 5)
	while not f.core.open:
		f.tick()
		f.take_events()
	var dealt := 0
	while f.core.open:
		dealt += f.damage(10)
	var ev := f.take_events()
	check("break bij >= 45 in venster (%d)" % dealt, ev.any(func(e): return str(e["type"]) == "core_break") and dealt >= 45 and f.step == GolemFight.Step.STAGGER)
	var hb := false
	for i in 200:
		f.tick()
		for e in f.take_events():
			if str(e["type"]) == "telegraph_start" and str(e["id"]) == "golem_hammer_blow":
				hb = true
	check("na break geen golem_hammer_blow", not hb)
	# geen break -> hammer_blow
	var g := GolemFight.new(360, 5)
	var got_hb := false
	for i in 600:
		g.tick()
		for e in g.take_events():
			if str(e["type"]) == "telegraph_start" and str(e["id"]) == "golem_hammer_blow":
				got_hb = true
	check("venster zonder break -> golem_hammer_blow (42 windup)", got_hb)
	# max 2 baas-telegrafen
	var h := GolemFight.new(360, 9)
	var max_tg := 0
	for i in 6000:
		h.tick()
		h.take_events()
		max_tg = maxi(max_tg, h.telegraph_count())
		if i % 50 == 0:
			h.damage(6)
	check("max 2 gelijktijdige baas-telegrafen (%d)" % max_tg, max_tg <= 2)
	# fase 3: eenmalige klap onder 10%
	var k := GolemFight.new(360, 13)
	_hit_to(k, 217)
	k.damage(10)
	while k.is_invulnerable():
		k.tick()
	_hit_to(k, 91)
	k.damage(5)
	while k.is_invulnerable():
		k.tick()
	k.take_events()
	_hit_to(k, 35)
	var p3 := 0
	for i in 2000:
		k.tick()
		for e in k.take_events():
			if str(e["type"]) == "telegraph_start" and str(e["id"]) == "golem_hammer_blow_p3":
				p3 += 1
	check("fase 3 onder 10%%: golem_hammer_blow_p3 precies 1x (%d)" % p3, p3 == 1)


func _script_log(seed_val: int) -> Array:
	var f := GolemFight.new(360, seed_val)
	var log: Array = []
	for i in 9000:
		f.tick()
		if i % 37 == 0:
			f.damage(9)
		for e in f.take_events():
			log.append([f.tick_no, str(e["type"]), str(e.get("id", ""))])
		if f.is_dead():
			break
	return log


func _determinism_tests() -> void:
	var a := _script_log(42)
	var b := _script_log(42)
	check("determinisme: zelfde seed + invoer -> zelfde event-log (%d events)" % a.size(), a == b and a.size() > 10)
	check("gevecht eindigt (dood) binnen script", a.any(func(e): return e[1] == "phase"))


func _view_tests() -> void:
	check("#341-sprites laden (telegraph_marker, golem_core_open, phase_flash, golem_boss_v2_damaged)", GolemBossView.textures_ok())
	var v := GolemBossView.new()
	add_child(v)
	var f := GolemFight.new(360, 1)
	v.sync(f)
	check("view: start = golem_boss_v2.png, geen gloed/flash", v.body.texture.resource_path.ends_with("golem_boss_v2.png")
		and not v.core_glow.visible and not v.flash.visible)
	while not f.core.open:
		f.tick()
	v.sync(f)
	check("view: kern open -> golem_core_open zichtbaar", v.core_glow.visible and v.core_glow.hframes == 2)
	var g := GolemFight.new(360, 1)
	_hit_to(g, 217)
	g.damage(10)
	v.sync(g)
	check("view: fase 2 -> damaged sprite + phase_flash", v.body.texture.resource_path.ends_with("golem_boss_v2_damaged.png") and v.flash.visible)
	var h := GolemFight.new(360, 1)
	while h.step != GolemFight.Step.WINDUP:
		h.tick()
	v.sync(h, Vector2(10, 20))
	check("view: windup -> telegraph_marker op doel", v.marker.visible and v.marker.position == Vector2(10, 20) and v.marker.hframes == 3)
	v.queue_free()


func _mult_removed_tests() -> void:
	var consts: Dictionary = (load("res://scripts/data/som_data.gd") as Script).get_script_constant_map()
	check("ACTION_BOSS_MULT verwijderd", not consts.has("ACTION_BOSS_MULT") and not consts.has("ACTION_BOSS_PER_LEVEL"))
