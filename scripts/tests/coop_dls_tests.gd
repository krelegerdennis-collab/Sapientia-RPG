extends Node
## Online DLS Easy: zelfde kaart op 4 clients, cap 8, verdieping 1..10 zonder baas, solo onaangeroerd.
## Start: godot --path . -- --coopdlstest

const Floor := preload("res://scripts/online/online_dls_floor.gd")
const Modes := preload("res://scripts/online/online_dls_modes.gd")
const Run := preload("res://scripts/online/online_dls_run.gd")
const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const FP := preload("res://scripts/online/solo_d100_fingerprint.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")

const SEED := 11

var failures := 0
var passes := 0
var fight_floor := 0


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
	_clients_and_walk()
	_solo_untouched()
	await _arena()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _clients_and_walk() -> void:
	for f in range(1, 11):
		var hashes: Array[String] = []
		for _i in 4:
			Gen._cache.clear()
			hashes.append(Floor.map_hash(Floor.build("easy", SEED, f)))
		var same := hashes[0] != "" and hashes[0] == hashes[1] and hashes[1] == hashes[2] and hashes[2] == hashes[3]
		check("4 clients zelfde kaart-hash easy %d" % f, same)
		Gen._cache.clear()
		var built := Floor.build("easy", SEED, f)
		var room: Dictionary = built.get("room", {})
		var eff := Modes.eff_floor("easy", f)
		var mons: Array = room.get("monsters", [])
		check("easy %d: ≤ 8 vijanden (%d)" % [f, mons.size()], mons.size() <= 8 and mons.size() <= Modes.enemy_cap())
		if mons.size() > 0 and fight_floor == 0:
			fight_floor = f
		var floors_ok := true
		for m in mons:
			if int(m.get("floor", 0)) != eff or bool(m.get("boss", false)):
				floors_ok = false
		for c in room.get("chests", []):
			if int(c.get("floor", 0)) != eff or str(c.get("kind", "")) == Blue.KIND_BLUE:
				floors_ok = false
		check("easy %d: floor-veld = eff %d, geen baas, geen blauwe kist" % [f, eff], floors_ok and not Floor.has_boss_monster(built) and not Floor.has_blue_chest(built))
		check("easy %d: geen puzzel, uitgang bereikbaar" % f, not room.has("puzzel") and not room.has("puzzel_massief") and Floor.exit_reachable(built))
		var rest := room.has("rustpunt")
		check("easy %d: rust %s" % [f, "aan" if f == 5 else "uit"], rest == (f == 5))
	var first: Dictionary = Floor.build("easy", SEED, 1).get("room", {})
	var last := Floor.build("easy", SEED, 10)
	check("easy 1 houdt het start-kristal in de data", first.has("warper"))
	check("easy 10: baas-slot dicht, geen warper, uitgang na het slot",
			bool(last.get("boss_closed", false)) and int(last.get("boss_key", 0)) == 10
			and not last.get("room", {}).has("warper") and not Floor.has_boss_monster(last)
			and Floor.exit_reachable(last))
	check("minstens één easy-verdieping heeft vijanden", fight_floor > 0)


func _solo_untouched() -> void:
	var saved := GameState.dungeon100_floor
	GameState.dungeon100_floor = 42
	Gen._cache.clear()
	var before := FP.generate_hash(3, 99)
	var solo := Gen.generate(3, 99)
	var had_boss := false
	for m in solo.get("room", {}).get("monsters", []):
		if bool(m.get("boss", false)):
			had_boss = true
	Floor.build("easy", 3, 10)
	var still := false
	for m in solo.get("room", {}).get("monsters", []):
		if bool(m.get("boss", false)):
			still = true
	var after := FP.generate_hash(3, 99)
	check("solo generate(3, 99) ongewijzigd na online easy 10", had_boss and still and before == after)
	check("GameState.dungeon100_floor niet geschreven door build", GameState.dungeon100_floor == 42)
	GameState.dungeon100_floor = saved
	check("is_wm1_room blijft dicht voor de DLS", not SomData.is_wm1_room("dungeon100_1_1")
			and not SomData.is_wm1_room("online_dls_easy_1_1")
			and not SomData.room_enabled("dungeon100_1_1", true))


func _arena() -> void:
	var floor_before := GameState.dungeon100_floor
	var gold_before := GameState.gold
	var flags_before := GameState.story_flags.duplicate(true)
	Run.start("easy", SEED)
	Run.floor_no = fight_floor
	var packed := load(Run.SCENE) as PackedScene
	var node := packed.instantiate() as OnlineDlsRoom
	add_child(node)
	await get_tree().process_frame
	var som: SomArena = node.som
	var mons: Array = node.monsters
	var eff := Modes.eff_floor("easy", fight_floor)
	check("SomArena coop_mode op easy %d" % fight_floor, som != null and bool(som.coop_mode))
	check("SomArena heeft alle vijanden (≤ 8) op easy %d" % fight_floor,
			som != null and mons.size() > 0 and mons.size() <= 8 and som.enemies.size() == mons.size())
	var stats_ok := som != null and mons.size() > 0
	if stats_ok:
		for m in mons:
			if not som.enemies.has(m):
				stats_ok = false
				continue
			var entry: Dictionary = som.enemies[m]
			var preview: Dictionary = Floor.monster_preview("easy", str(m.enemy_id), int(m.floor_nr))
			if int(entry.get("max_hp", -1)) != int(preview.get("max_hp", -2)) or int(entry.get("exp", -1)) != int(preview.get("exp", -2)):
				stats_ok = false
			if int(m.floor_nr) != eff or bool(m.boss):
				stats_ok = false
	check("SomArena-stats = monster_stats(eff %d) × exp-factor" % eff, stats_ok)
	for _i in 3:
		await get_tree().process_frame
	check("arena schrijft geen solo-goud of verhaalvlaggen", GameState.gold == gold_before and GameState.story_flags == flags_before and GameState.dungeon100_floor == floor_before)
	node.queue_free()
	Run.floor_no = 10
	var last := packed.instantiate() as OnlineDlsRoom
	add_child(last)
	await get_tree().process_frame
	var boss_nodes := 0
	for m in last.monsters:
		if bool(m.boss):
			boss_nodes += 1
	var exit := last.get_node_or_null("Exits/Uitgang_v")
	var reached := false
	if exit != null:
		last._use_exit(exit)
		reached = Run.exit_reached
	check("easy 10 in de kamer: geen baas, uitgang bereikt", boss_nodes == 0 and last.floor_data.get("boss_closed", false) and reached and GameState.dungeon100_floor == floor_before)
	var koopman: Node = last.find_child("Koopman", true, false)
	var puzzel = last.get("puzzel")
	check("koopman en puzzel staan niet in de online kamer", koopman == null and puzzel == null)
	last.queue_free()
	Run.stop()
