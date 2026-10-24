extends Node
## Vaste simulatiestap van het Action-gevecht (COMBAT_DESIGN.md §16, roadmap stap 3).
## Bewijst: advance() zet frametijd om in stappen van 1/60 s, onafhankelijk van de framerate (30/60/120/144 fps);
## plafond per frame; input wordt door de volgende stap verbruikt; zelfde seed + zelfde stappen => zelfde gevecht,
## ook bij een andere framerate.
## Start: godot --headless --path . -- --combattick

const SomArena := preload("res://scripts/som/som_arena.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"
const SECONDS := 8.0

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
	_accumulator_tests()
	await _fight_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


## advance() op een kale arena (geen kamer): alleen de teller, sim_step doet zonder vijanden niets schadelijks.
func _accumulator_tests() -> void:
	check("TICK_HZ = 60 (net_protocol SIM_HZ)", SomArena.TICK_HZ == 60)
	for fps in [30, 60, 120, 144]:
		var a: Node = SomArena.new()
		var total := 0
		for f in fps * 2:              # 2 seconden
			total += a.advance(1.0 / float(fps))
		check("%d fps, 2 s => 120 stappen (%d)" % [fps, total], total == 120 and a.sim_tick == 120)
		a.free()
	var b: Node = SomArena.new()
	var n: int = b.advance(1.0)        # hapering van 1 s
	check("plafond: hapering van 1 s => max %d stappen (%d), achterstand vervalt" % [SomArena.MAX_TICKS_PER_FRAME, n],
			n == SomArena.MAX_TICKS_PER_FRAME and float(b._tick_acc) < SomArena.TICK_DT)
	check("negatieve delta telt niet", b.advance(-1.0) == 0)
	b.free()
	var c: Node = SomArena.new()
	c.charge = 0.0
	c.step_ticks(30)
	var want := minf(1.0, 30.0 * SomArena.TICK_DT / SomArena.SomData.CHARGE_TIME)
	check("meter laadt per stap (%.4f ~ %.4f)" % [float(c.charge), want], absf(float(c.charge) - want) < 0.0001)
	c.free()


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


## Eén vijand naast Dax, geen bondgenoten, geen aanvalsanimatie (treffer meteen): alleen de vaste stap telt.
## fps = de frametijd die advance() krijgt. Dax slaat elke volle meter (input via _pending).
func _fight(seed: int, fps: int) -> String:
	_new_game()
	var room := await _load_room()
	if room == null:
		return "GEEN KAMER"
	var arena: Node = room.som
	arena.set_process(false)
	arena.allies_enabled = false
	arena.attack_texs.clear()
	arena.seed_rng(seed)
	var ms: Array = room.monsters.filter(func(m): return is_instance_valid(m) and arena.enemies.has(m))
	ms.sort_custom(func(x, y): return str(x.monster_id) < str(y.monster_id))
	if ms.is_empty():
		return "GEEN VIJAND"
	var m: Node = ms[0]
	for o in ms.slice(1):
		arena.enemies.erase(o)
		o.set_process(false)
	m.set_process(false)                 # geen tegelbeweging met frametijd: vijand staat stil, slaat wel
	arena.enemies[m]["chase"] = 1e9
	arena.player.position = arena.center_of(m) + Vector2(0, 14) - Vector2(0, SomArena.SomData.BODY_Y)
	arena.player.facing = Vector2i.UP
	var dax: Dictionary = arena.member("dennis")
	dax["hp"] = int(dax["max_hp"]) * 50       # geen KO in de test
	var log: Array = []
	var frames := int(SECONDS * fps)
	for f in frames:
		if arena.charge >= 1.0 and arena.enemies.has(m):
			arena._pending["attack"] = true
		arena.advance(1.0 / float(fps))
		if arena.last_enemy_damage != 0:
			log.append("t%d hit %d" % [arena.sim_tick, arena.last_enemy_damage])
			arena.last_enemy_damage = 0
		if arena.last_player_damage != 0:
			log.append("t%d back %d" % [arena.sim_tick, arena.last_player_damage])
			arena.last_player_damage = 0
	log.append("ticks=%d alive=%s hp=%d gold=%d" % [arena.sim_tick, str(arena.enemies.has(m)), int(dax["hp"]), GameState.gold])
	return "\n".join(log)


func _fight_tests() -> void:
	var a := await _fight(4242, 60)
	var b := await _fight(4242, 60)
	var c := await _fight(4242, 30)
	var d := await _fight(4242, 144)
	check("kamer + vijand geladen", not a.begins_with("GEEN"))
	check("gevecht heeft treffers beide kanten (%d regels)" % a.count("\n"), a.contains(" hit ") and a.contains(" back "))
	check("zelfde seed + 60 fps => identiek", a == b)
	# 30 fps: input wordt maar elke 2 stappen gelezen (een frame duurt 2 stappen), dus de tijdstempels schuiven
	# hooguit een paar stappen; schade, volgorde en eindstand moeten gelijk zijn.
	check("30 fps: zelfde treffers, volgorde en eindstand als 60 fps", _zonder_tijd(a) == _zonder_tijd(c))
	check("30 fps: tijdverschil per treffer <= 3 stappen", _max_shift(a, c) <= 3)
	check("144 fps geeft hetzelfde gevecht als 60 fps", a == d)
	if _zonder_tijd(a) != _zonder_tijd(c) or a != d:
		print("INFO  60fps:\n" + a + "\nINFO  30fps:\n" + c + "\nINFO  144fps:\n" + d)


func _zonder_tijd(log: String) -> Array:
	var out: Array = []
	for line in log.split("\n"):
		out.append(line.get_slice(" ", 1) + " " + line.get_slice(" ", 2) if line.begins_with("t") and line.contains(" ") and not line.begins_with("ticks") else line)
	return out


func _max_shift(x: String, y: String) -> int:
	var lx := x.split("\n")
	var ly := y.split("\n")
	var mx := 0
	for i in mini(lx.size(), ly.size()):
		if lx[i].begins_with("t") and not lx[i].begins_with("ticks") and ly[i].begins_with("t"):
			mx = maxi(mx, absi(int(lx[i].get_slice(" ", 0).substr(1)) - int(ly[i].get_slice(" ", 0).substr(1))))
	return mx
