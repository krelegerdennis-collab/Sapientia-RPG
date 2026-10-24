extends Node
## Pure gevechtskern + alles op de vaste stap (COMBAT_DESIGN.md §16, roadmap stap 3b).
## - CombatSim (scripts/som/combat_sim.gd: klok + meters) is node-vrij;
## - aanvals-/cast-animaties: de treffer valt op de vaste stap, niet op frametijd;
## - vijandbeweging (MapMonster.sim_move) en target-lock lopen op de stap;
## - volledig gevecht (animaties, vijand-AI, achtervolgen aan; bondgenoten uit): 30/60/144 fps => zelfde uitkomst.
## Start: godot --headless --path . -- --combatsimtest

const CombatSim := preload("res://scripts/som/combat_sim.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
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


func _run() -> void:
	_pure_tests()
	await _anim_tests()
	await _world_tests()
	await _fight_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _pure_tests() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/som/combat_sim.gd")
	var code := ""
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line.get_slice("#", 0) + "\n"
	var bad: Array = []
	for w in ["Node", "get_tree", "Input.", "Engine.", "randf", "randi", "preload", "load("]:
		if code.contains(w):
			bad.append(w)
	check("CombatSim is RefCounted en node-vrij (%s)" % ["ok" if bad.is_empty() else str(bad)],
			code.contains("extends RefCounted") and bad.is_empty())
	var c := CombatSim.new()
	var t := 0
	for f in 288:
		t += c.frames_to_ticks(1.0 / 144.0)
	check("klok: 144 fps x 2 s = 120 stappen (%d)" % t, t == 120)
	check("klok: plafond %d bij hapering" % CombatSim.MAX_TICKS_PER_FRAME, c.frames_to_ticks(2.0) == CombatSim.MAX_TICKS_PER_FRAME and c.acc < CombatSim.TICK_DT)
	check("charge_after: laadt alleen buiten swing-lock (CHARGE_AFTER_ANIM)",
			is_equal_approx(CombatSim.charge_after(0.0, 0.0, true, 1.0, 0.5), 0.5)
			and is_equal_approx(CombatSim.charge_after(0.0, 0.2, true, 1.0, 0.5), 0.0)
			and is_equal_approx(CombatSim.charge_after(0.9, 0.0, true, 1.0, 0.5), 1.0))
	var tm := {"a": 0.05, "b": 1.0}
	CombatSim.tick_down(tm, 0.1)
	check("tick_down: niet onder 0", is_equal_approx(float(tm["a"]), 0.0) and is_equal_approx(float(tm["b"]), 0.9))


## Aanvalsanimatie met sim_driven: frametijd doet niets, de treffer valt op de vaste stap.
func _anim_tests() -> void:
	var tex: Texture2D = load(str(SomData.ATTACK_ANIMS["dennis"]["sheet"]))
	if tex == null:
		check("aanvalssheet Dax laadt", false)
		return
	var holder := Node2D.new()
	holder.set("facing", Vector2i.DOWN)
	var host := CharacterBody2D.new()
	host.set_script(null)
	add_child(holder)
	var body := Node2D.new()
	body.set_meta("x", 1)
	holder.add_child(body)
	var p := _FacingNode.new()
	holder.add_child(p)
	var a: Node = SomFx.attack_anim(p, tex, SomData.ATTACK_ANIMS["dennis"])
	a.sim_driven = true
	var hits := [0]
	a.hit.connect(func() -> void: hits[0] += 1)
	for i in 30:
		await get_tree().process_frame
	check("sim_driven: 30 frames zonder step => geen treffer", hits[0] == 0 and is_equal_approx(float(a.elapsed_ms), 0.0))
	var want := int(ceil(float(a.start_of(a.hit_index)) / (CombatSim.TICK_DT * 1000.0) - 0.0001))
	var n := 0
	while hits[0] == 0 and n < 200 and is_instance_valid(a):
		a.step(CombatSim.TICK_DT)
		n += 1
	check("treffer op stap %d (verwacht %d, hit-frame %d)" % [n, want, int(a.hit_index) + 1], hits[0] == 1 and n == want)
	holder.queue_free()
	host.free()


class _FacingNode extends Node2D:
	var facing := Vector2i.DOWN


func _new_game() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	for id in ["noor", "lotte"]:
		if not GameState.has_member(id):
			GameState.add_member(id)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)


func _load_room() -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.pending_spawn = ""
	get_tree().change_scene_to_file(ROOM)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			return s
	return null


## Vijandbeweging en target-lock op de stap.
func _world_tests() -> void:
	_new_game()
	var room := await _load_room()
	if room == null:
		check("kamer geladen", false)
		return
	var arena: Node = room.som
	arena.set_process(false)
	arena.allies_enabled = false
	var m: Node = null
	for x in room.monsters:
		if is_instance_valid(x) and arena.enemies.has(x):
			m = x
			break
	if m == null:
		check("vijand in de arena", false)
		return
	for i in 600:                       # kamer-grace eerst voorbij (zoals in het spel: arena.active())
		if room.monsters_active():
			break
		await get_tree().process_frame
	check("kamer actief (monsters_active)", room.monsters_active())
	arena.step_ticks(1)
	check("na één stap: vijand sim_driven", bool(m.sim_driven))
	# laat hem een stap zetten en kijk of frames alleen niets verschuiven
	var dir := Vector2i.ZERO
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if room.monster_can_enter(m, m.tile + d) == "free":
			dir = d
			break
	if dir == Vector2i.ZERO:
		check("vrije tegel naast vijand", false)
		return
	m.try_step(dir)
	var p0: Vector2 = m.position
	for i in 20:
		await get_tree().process_frame
	check("frames zonder stap: vijand schuift niet (sim_driven)", m.position == p0 and m.is_moving)
	var n := 0
	while m.is_moving and n < 120:
		arena.step_ticks(1)
		n += 1
	var want := int(ceil(16.0 / float(m.WALK_SPEED) / CombatSim.TICK_DT - 0.0001))
	check("tegelstap klaar na %d stappen (verwacht ~%d)" % [n, want], not m.is_moving and absi(n - want) <= 1)
	var scans0 := int(arena.target_lock.timed_auto_scans)
	for i in 30:
		await get_tree().process_frame
	check("target-lock: frames zonder stap scannen niet", int(arena.target_lock.timed_auto_scans) == scans0)
	arena.step_ticks(int(ceil(arena.target_lock.AUTO_SCAN_INTERVAL / CombatSim.TICK_DT)) + 1)
	check("target-lock: scant op de stap", int(arena.target_lock.timed_auto_scans) > scans0)


## Volledig gevecht: aanvalsanimaties, vijand-AI, achtervolgen en tegelbeweging aan; alleen frametijd verschilt.
## Bondgenoten staan uit: hun move_and_slide botst tegen de physics-ruimte, die Godot alleen per physics-frame
## bijwerkt. Dat maakt ze (nog) niet reproduceerbaar; zie de PR (stap 3c).
func _fight(seed: int, fps: int, seconds: float) -> String:
	_new_game()
	var room := await _load_room()
	if room == null:
		return "GEEN KAMER"
	var arena: Node = room.som
	arena.set_process(false)
	arena.allies_enabled = false
	arena.seed_rng(seed)
	arena.enemies.clear()
	var ms: Array = room.monsters.duplicate()
	ms.sort_custom(func(x, y): return str(x.monster_id) < str(y.monster_id))
	for m in ms:
		arena.register(m)
	for h in GameState.party:
		h["hp"] = int(h["max_hp"]) * 40
		h["max_hp"] = int(h["max_hp"]) * 40
	var log: Array = []
	arena.enemy_hit.connect(func(m: Node, d: int) -> void: log.append("t%d E %s %d" % [arena.sim_tick, m.monster_id, d]))
	arena.player_hit.connect(func(d: int) -> void: log.append("t%d P %d %s" % [arena.sim_tick, d, arena.last_hit_id]))
	for i in 600:
		if room.monsters_active():
			break
		await get_tree().process_frame
	# Dax slaat elke volle meter; de "bot" beslist binnen de stap (sim_ticked), dus geen framekwantisatie.
	var bot := func(_t: int) -> void:
		if arena.charge >= 1.0 and not arena.enemies.is_empty():
			var m: Node = arena.nearest_enemy(arena.player.position, 400.0)
			if m != null:
				arena.player.position = arena.center_of(m) + Vector2(0, 14) - Vector2(0, SomData.BODY_Y)
				arena.player.facing = Vector2i.UP
				arena._pending["attack"] = true
	arena.sim_ticked.connect(bot)
	var ticks := int(seconds * CombatSim.TICK_HZ)
	var frame_dt := 1.0 / float(fps)
	while arena.sim_tick < ticks:
		arena.advance(frame_dt)
	var pos: Array = []
	for m in ms:
		if is_instance_valid(m) and arena.enemies.has(m):
			pos.append("%s@%s" % [m.monster_id, str(m.tile)])
	log.append("end t%d left=%d gold=%d %s" % [arena.sim_tick, arena.enemies.size(), GameState.gold, ",".join(pos)])
	return "\n".join(log)


func _fight_tests() -> void:
	var a := await _fight(31337, 60, 12.0)
	var b := await _fight(31337, 60, 12.0)
	var c := await _fight(31337, 144, 12.0)
	var d := await _fight(31337, 30, 12.0)
	check("gevecht heeft treffers beide kanten (%d regels)" % a.count("\n"), a.contains(" E ") and a.contains(" P "))
	check("gevecht, 60 fps: zelfde seed => identiek", a == b)
	check("gevecht: 144 fps == 60 fps", a == c)
	check("gevecht: 30 fps == 60 fps", a == d)
	if a != c or a != d or a != b:
		print("INFO  60:\n" + a + "\nINFO  60b:\n" + b + "\nINFO  144:\n" + c + "\nINFO  30:\n" + d)
