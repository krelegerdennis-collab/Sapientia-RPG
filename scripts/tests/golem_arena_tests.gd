extends Node
## D3 PR C: arena-hook voor de realtime Golem (kennis_beest) in de echte Golemhal (WM1, Action).
## Bewaakt: hook standaard uit (Golem turn-based), met hook: GolemFight drijft het gevecht (fases, kern-venster,
## schadeplafond per fasedrempel, 90 ticks onkwetsbaar), adds in fase 2, aanvallen raken de party, geen
## turn-based gevecht bij aanraken, verslaan via de arena, registry weer schoon na de kamer.
## Start: godot --path . -- --golemarenatest

const SomArena := preload("res://scripts/som/som_arena.gd")
const BossScript := preload("res://scripts/som/boss_script.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")
const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")
const ROOM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const OTHER_SCENE := "res://scenes/maps/archief_v1_gang.tscn"

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
	print("=== D3 PR C: Golem arena-hook ===")
	await _hook_off()
	await _hook_on()
	await _other_room()
	SomArena.golem_rt_enabled = false
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	get_tree().change_scene_to_file(pad)
	for i in 180:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4:
			return s
	return null


func _start() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)


func _golem(s: Node) -> Node:
	for m in s.monsters:
		if is_instance_valid(m) and m.boss and str(m.enemy_id) == GolemBoss.ENEMY_ID:
			return m
	return null


func _events_of(a: Node, type: String) -> Array:
	return (a.golem_events as Array).filter(func(ev): return str(ev.get("type", "")) == type)


## Hook uit (standaard): niets verandert, Golem blijft turn-based.
func _hook_off() -> void:
	SomArena.golem_rt_enabled = false
	_start()
	var s := await _laad(ROOM_SCENE)
	var a: Node = s.get("som") if s else null
	var m := _golem(s) if s else null
	check("uit: Golemhal geladen met Action-arena", a != null and m != null)
	if a == null or m == null:
		return
	check("uit: golem_rt_enabled standaard false", not SomArena.golem_rt_enabled)
	check("uit: Golem NIET in de realtime arena", not a.enemies.has(m))
	check("uit: geen BossScript voor kennis_beest", not BossScript.has_script(GolemBoss.ENEMY_ID))


func _hook_on() -> void:
	SomArena.golem_rt_enabled = true
	_start()
	var s := await _laad(ROOM_SCENE)
	var a: Node = s.get("som") if s else null
	var m := _golem(s) if s else null
	check("aan: Golemhal geladen met Action-arena", a != null and m != null)
	if a == null or m == null:
		return
	a.allies_enabled = false
	for h in GameState.party:
		h["hp"] = 99999          # niemand KO tijdens de test
	check("aan: Golem in de realtime arena", a.enemies.has(m))
	check("aan: GolemBoss.ensure_registered() via de arena", BossScript.has_script(GolemBoss.ENEMY_ID))
	var f: GolemFight = a.golem_fight_of(m)
	check("aan: arena-entry heeft een GolemFight", f != null)
	if f == null:
		return
	var e: Dictionary = a.enemies[m]
	check("aan: stats ongewijzigd (HP 360, ATK 27)", f.max_hp() == 360 and int(e["hp"]) == 360 and int(e["atk"]) == 27)
	check("aan: start fase 0, niet onkwetsbaar", f.phase_index() == 0 and not f.is_invulnerable())

	# aanraken = geen turn-based gevecht meer
	s.monster_touch(m)
	await get_tree().process_frame
	check("aan: aanraken start GEEN turn-based gevecht", not GameState.in_battle and a.enemies.has(m))

	# kern dicht: schade x closed_mult (0.4)
	var closed := f.core.closed_mult
	a.damage_enemy(m, 50, Vector2i.ZERO)
	var exp1 := maxi(1, roundi(50.0 * closed))
	check("aan: kern dicht: 50 ruw -> %d (x%.1f) [%d]" % [exp1, closed, a.last_enemy_damage], a.last_enemy_damage == exp1 and int(e["hp"]) == 360 - exp1)
	check("aan: arena-hp = GolemFight-hp", int(e["hp"]) == f.hp())

	# schadeplafond op de fasedrempel (60% = 216)
	var thr := f.pm.threshold_hp(0)
	a.damage_enemy(m, 5000, Vector2i.ZERO)
	check("aan: schadeplafond: hp stopt op drempel %d (hp %d)" % [thr, f.hp()], f.hp() == thr and int(e["hp"]) == thr)
	check("aan: fase 1 na drempel", f.phase_index() == 1 and int(e.get("golem_phase", -1)) == 1)
	check("aan: fase-event in arena-log", _events_of(a, "phase").size() == 1)
	check("aan: Golem leeft na overkill (geen defeat)", a.enemies.has(m))
	check("aan: fasewissel onkwetsbaar", f.is_invulnerable())
	a.damage_enemy(m, 500, Vector2i.ZERO)
	check("aan: schade tijdens fasewissel = 0", a.last_enemy_damage == 0 and f.hp() == thr)

	# adds fase 2: 2 papiergeest, ook in de arena
	var adds: Array = []
	for x in s.monsters:
		if is_instance_valid(x) and str(x.monster_id).begins_with("golem_add_"):
			adds.append(x)
	check("aan: fase 2 spawnt 2 adds (%d)" % adds.size(), adds.size() == 2)
	check("aan: adds zijn papiergeest en realtime", adds.all(func(x): return str(x.enemy_id) == "papiergeest" and a.enemies.has(x)))
	for x in adds:
		a.allies_enabled = false
		a.enemies.erase(x)       # adds stil (test meet alleen de Golem)

	# precies 90 ticks onkwetsbaar
	a.step_ticks(BossPhaseMachine.INVULN_TICKS - 1)
	check("aan: tick 89 nog onkwetsbaar", f.is_invulnerable())
	a.step_ticks(1)
	check("aan: na 90 ticks weer kwetsbaar", not f.is_invulnerable() and _events_of(a, "invuln_end").size() == 1)

	# kern-venster: wacht op core_open (vaste 8 s klok), dan schade x open_mult
	var guard := 0
	while not f.core.open and guard < 600:
		a.step_ticks(1)
		guard += 1
	check("aan: kern opent binnen 8 s (core_open-event)", f.core.open and _events_of(a, "core_open").size() >= 1)
	var hp0 := f.hp()
	a.damage_enemy(m, 10, Vector2i.ZERO)
	var exp2 := maxi(1, roundi(10.0 * f.core.open_mult))
	check("aan: kern open: 10 ruw -> %d (x%.1f)" % [exp2, f.core.open_mult], a.last_enemy_damage == exp2 and f.hp() == hp0 - exp2)

	# aanvallen: telegrafen en treffers op de party (via hit_member)
	var hp_before := 0
	for h in GameState.party:
		hp_before += int(h["hp"])
	for i in 20:
		a.step_ticks(60)
		var b: Node2D = a.player
		if b:
			b.position = m.position + Vector2(8, 8)     # naast de Golem, binnen bereik
		for id in a.iframes.keys():
			a.iframes[id] = 0.0
	var tele := _events_of(a, "telegraph_start")
	check("aan: Golem start aanvallen (telegraph_start: %d)" % tele.size(), tele.size() >= 2)
	check("aan: elke windup >= %d ticks" % GolemBoss.MIN_WINDUP_TICKS, tele.all(func(ev): return int(ev["windup"]) >= GolemBoss.MIN_WINDUP_TICKS))
	check("aan: attack_hit-events", _events_of(a, "attack_hit").size() >= 1)
	var hp_after := 0
	for h in GameState.party:
		hp_after += int(h["hp"])
	check("aan: party neemt Golem-schade (%d -> %d)" % [hp_before, hp_after], hp_after < hp_before)

	# verslaan: door fase 2 en 3 heen tot 0 (wachten op elke fasewissel)
	var safety := 0
	while a.enemies.has(m) and safety < 200:
		safety += 1
		if f.is_invulnerable():
			a.step_ticks(BossPhaseMachine.INVULN_TICKS)
		a.damage_enemy(m, 5000, Vector2i.ZERO)
	check("aan: Golem verslagen via de arena (fases %d)" % _events_of(a, "phase").size(), not a.enemies.has(m) and _events_of(a, "phase").size() == 2)
	check("aan: geen turn-based gevecht geopend", not GameState.in_battle)


## Andere kamer: hook geldt alleen in de Golemhal; registry weer schoon na het verlaten.
func _other_room() -> void:
	SomArena.golem_rt_enabled = true
	_start()
	var s := await _laad(OTHER_SCENE)
	check("verlaten Golemhal: kennis_beest weer uit de registry", not BossScript.has_script(GolemBoss.ENEMY_ID))
	var a: Node = s.get("som") if s else null
	if a == null:
		check("andere kamer: arena", false)
		return
	var p: Node = s.get_node("Objects/Player")
	var m: Node = s.add_monster({"id": "pr_c_baas", "enemy": "kennis_beest", "tile": [p.get_tile().x + 3, p.get_tile().y + 1], "moves": false, "boss": true})
	await get_tree().process_frame
	check("andere kamer: Golem-baas NIET realtime (alleen Golemhal)", m != null and not a.enemies.has(m))
