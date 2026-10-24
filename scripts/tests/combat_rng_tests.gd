extends Node
## Seeded RNG in het Action-gevecht (COMBAT_DESIGN.md §16, roadmap stap 2).
## Bewijst: zelfde seed => identiek gevecht (schade, HP, EXP, goud, buit); andere seed => ander verloop;
## zonder seed blijft het willekeurig; geen globale randf/randi meer in scripts/som/.
## Start: godot --headless --path . -- --combatrngtest

const SomArena := preload("res://scripts/som/som_arena.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"
const SOM_DIR := "res://scripts/som/"
const MAX_ROUNDS := 300

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
	_static_tests()
	_formula_tests()
	await _fight_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


## Geen kale randf()/randi()/randf_range()/randomize() in scripts/som/ buiten de gevecht-RNG.
func _static_tests() -> void:
	var re := RegEx.new()
	re.compile("(?<![\\w.])(randf|randi|randf_range|randi_range|randfn)\\s*\\(")
	var bad: Array = []
	for f in DirAccess.get_files_at(SOM_DIR):
		if not f.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string(SOM_DIR + f).split("\n")
		for i in lines.size():
			var code := lines[i].get_slice("#", 0)
			if re.search(code) == null:
				continue
			# enige toegestane plek: de fallback van physical_damage zonder RNG (tools/battlesim)
			if f == "som_arena.gd" and code.contains("if r != null else randf_range"):
				continue
			bad.append("%s:%d" % [f, i + 1])
	check("geen globale rand-aanroep in scripts/som/ (%s)" % ["ok" if bad.is_empty() else str(bad)], bad.is_empty())


func _formula_tests() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 42
	b.seed = 42
	var sa: Array = []
	var sb: Array = []
	for i in 50:
		sa.append(SomArena.physical_damage(30.0, 8.0, 1.0, a))
		sb.append(SomArena.physical_damage(30.0, 8.0, 1.0, b))
	check("physical_damage: zelfde seed => zelfde 50 rolls", sa == sb)
	var lo := 1 << 30
	var hi := 0
	for v in sa:
		lo = mini(lo, int(v))
		hi = maxi(hi, int(v))
	# (30 - 4) * [0.85, 1.15] = [22.1, 29.9] -> afgerond 22..30 (gedrag ongewijzigd)
	check("physical_damage: spreiding blijft 0.85-1.15 (%d..%d)" % [lo, hi], lo >= 22 and hi <= 30 and lo < hi)
	var g := SomArena.physical_damage(30.0, 8.0, 1.0)
	check("physical_damage zonder RNG (tools/battlesim) werkt nog (%d)" % g, g >= 22 and g <= 30)


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


## Eén volledig gevecht met vaste stappen (geen frame-delta): Dax slaat elke vijand, elke levende vijand slaat terug.
## Geeft een vingerafdruk van alles wat toeval raakt.
func _fight(seed: int) -> String:
	_new_game()
	var room := await _load_room()
	if room == null:
		return "GEEN KAMER"
	var arena: Node = room.som
	arena.set_process(false)          # geen realtime AI/bondgenoten tussendoor: alleen het script hieronder
	for a in arena.allies:
		a.set_process(false)
		a.set_physics_process(false)
	arena.seed_rng(seed)
	arena.enemies.clear()
	var ms: Array = room.monsters.duplicate()
	ms.sort_custom(func(x, y): return str(x.monster_id) < str(y.monster_id))
	for m in ms:
		arena.register(m)
	var log: Array = []
	for m in ms:
		if arena.enemies.has(m):
			log.append("chase %s %.6f" % [m.monster_id, float(arena.enemies[m]["chase"])])
	var dax: Dictionary = arena.member("dennis")
	var atk := float(GameState.effective_stat(dax, "atk"))
	var rounds := 0
	while not arena.enemies.is_empty() and rounds < MAX_ROUNDS:
		rounds += 1
		for m in ms:
			if not arena.enemies.has(m):
				continue
			var e: Dictionary = arena.enemies[m]
			var dmg: int = SomArena.physical_damage(atk, float(e["def"]), 1.0, arena.rng)
			arena.damage_enemy(m, dmg, Vector2i.ZERO, false)
			log.append("hit %s %d" % [m.monster_id, dmg])
			if not arena.enemies.has(m):
				continue
			if int(dax["hp"]) * 3 < int(dax["max_hp"]):
				dax["hp"] = int(dax["max_hp"])     # geen KO/party_down in de test
				log.append("heel")
			arena.iframes.clear()
			arena.hit_member("dennis", int(e["atk"]))
			log.append("back %s %d hp=%d" % [m.monster_id, arena.last_player_damage, int(dax["hp"])])
	log.append("rounds=%d left=%d gold=%d exp=%d" % [rounds, arena.enemies.size(), GameState.gold, int(dax.get("exp", 0))])
	var inv: Array = GameState.inventory.keys()
	inv.sort()
	for k in inv:
		log.append("inv %s=%d" % [k, int(GameState.inventory[k])])
	log.append("next %.9f" % arena.rng.randf())
	return "\n".join(log)


func _fight_tests() -> void:
	var a := await _fight(20261024)
	var b := await _fight(20261024)
	var c := await _fight(777)
	check("kamer geladen met Action-arena", a != "GEEN KAMER")
	check("gevecht heeft vijanden en treffers (%d regels)" % a.count("\n"), a.count("hit ") >= 2 and a.count("back ") >= 1)
	check("gevecht eindigt: alle vijanden verslagen", a.contains(" left=0 "))
	check("zelfde seed => identiek gevecht", a == b)
	if a != b:
		print("INFO  A:\n" + a + "\nINFO  B:\n" + b)
	check("andere seed => ander verloop", a != c)
	# zonder seed: twee arena's krijgen elk een eigen willekeurige RNG (gedrag zoals de globale randf)
	var x: Node = SomArena.new()
	var y: Node = SomArena.new()
	check("zonder seed_rng: willekeurige seeds per arena", x.rng.seed != y.rng.seed)
	x.seed_rng(5)
	var r1: float = x.rng.randf()
	x.seed_rng(5)
	check("seed_rng(n) is herhaalbaar", is_equal_approx(r1, x.rng.randf()))
	x.free()
	y.free()
