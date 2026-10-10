extends Node
## ALLEEN VOOR TESTEN - Het Gesimuleerde Archief: Blauwe Kisten, Mimics en de Warp.
## Start:  godot --path . -- --dungeon100blauwtest [--shots=/pad/map]
##   Deel A: deterministische soort (~5% blauw, ~10% Mimic), baaskist nooit, Warp alleen op 100.
##   Deel B: momentopname, permanente items in de save, dood = dungeon uit, Warp levert af.
##   Deel C: echte scène: blauwe tint, Mimic-gevecht met schaal, Warp naar de wereldkaart.
## Zit niet in de export (scripts/tests/*).

const Blue := preload("res://scripts/data/dungeon100_blue.gd")
const S := preload("res://scripts/data/dungeon100_scaling.gd")
const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DUNGEON := "res://scenes/maps/dungeon100.tscn"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	seed(100100)
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 300 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: kistsoort ===")
	_kind_tests()
	print("=== Deel B: run, dood, save, Warp ===")
	_run_tests()
	print("=== Deel C: scène (blauw, Mimic, Warp) ===")
	await _scene_tests()
	print("DUNGEON100BLAUWTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(8)
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A
func _kind_tests() -> void:
	var a := Blue.kind_for(42, 7, "d100_42_7_1")
	var b := Blue.kind_for(42, 7, "d100_42_7_1")
	check("zelfde seed+verdieping+kist-id geeft dezelfde soort", a == b and a != "")
	var roll_a := Blue.roll(42, 7, "d100_42_7_1")
	check("de worp ligt tussen 0 en 1 en is vast voor hetzelfde id", roll_a == Blue.roll(42, 7, "d100_42_7_1") and roll_a >= 0.0 and roll_a < 1.0)
	check("andere seed geeft een andere worp voor dezelfde kist", Blue.roll(1, 7, "k") != Blue.roll(2, 7, "k"))
	check("verdieping 0 en een baaskist zijn nooit blauw of Mimic",
			Blue.kind_for(1, 0, "k") == Blue.KIND_NORMAL and Blue.kind_for(1, 10, "baas", true) == Blue.KIND_NORMAL)
	var n := 0
	var blue_n := 0
	var mimic_n := 0
	for sd in [1, 2, 3, 4, 5]:
		for f in range(1, 101):
			for i in range(1, 5):
				n += 1
				match Blue.kind_for(sd, f, "d100_%d_%d_%d" % [sd, f, i]):
					Blue.KIND_BLUE:
						blue_n += 1
					Blue.KIND_MIMIC:
						mimic_n += 1
	var blue_p := float(blue_n) / float(n)
	var mimic_p := float(mimic_n) / float(n)
	check("Blauwe Kist ~5%% over %d kisten (%.2f%%)" % [n, blue_p * 100.0], blue_p > 0.035 and blue_p < 0.065)
	check("Mimic ~10%% (%.2f%%)" % (mimic_p * 100.0), mimic_p > 0.08 and mimic_p < 0.12)
	var loot := Blue.blue_loot(9, 12, "kist")
	check("blauwe buit is één uitrustingsstuk, geen goud, gemarkeerd", int(loot["gold"]) == 0 and bool(loot["blue"])
			and (loot["items"] as Array).size() == 1 and Blue.is_blue_item(str(loot["items"][0]["item"])))
	var again := Blue.blue_loot(9, 12, "kist")
	check("blauwe buit is deterministisch", str(loot["items"][0]["item"]) == str(again["items"][0]["item"]))
	var boss := S.boss_loot(100, _rng(1))
	var with := Blue.with_warp(boss, 100)
	check("Warp-kristal zit in de baasbuit van verdieping 100 en nergens anders",
			(with["items"] as Array).any(func(it): return str(it["item"]) == Blue.WARP_ITEM)
			and not (Blue.with_warp(boss, 90)["items"] as Array).any(func(it): return str(it["item"]) == Blue.WARP_ITEM))
	check("Mimic bestaat in de vijanddata", GD.ENEMIES.has(Blue.MIMIC_ENEMY))


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


# ================================================================ deel B
func _run_tests() -> void:
	GameState.new_game("Dennis")
	GameState.gold = 80
	GameState.inventory["kruid"] = 2
	GameState.party[0]["level"] = 8
	var gear_before := str(GameState.party[0].get("equip", {}).get("wapen", ""))
	check("begin_run maakt een momentopname en zet de party op level 1 zonder goud", GameState.dungeon100_begin_run()
			and GameState.dungeon100_run_active() and GameState.party[0]["level"] == 1 and GameState.gold == 0
			and int(GameState.dungeon100_snapshot["gold"]) == 80 and int(GameState.dungeon100_snapshot["party"][0]["level"]) == 8)
	check("tweede begin_run doet niets", not GameState.dungeon100_begin_run() and GameState.party[0]["level"] == 1)
	check("tijdens de run zit de startvoorraad niet in de tas", GameState.item_count("kruid") == 0)
	GameState.dungeon100_floor = 4
	GameState.inventory["sterk_drankje"] = 2
	GameState.party[0]["level"] = 3
	var blauw := Blue.blue_loot(5, 4, "testkist")
	var item_id := str(blauw["items"][0]["item"])
	GameState.dungeon100_permanent[item_id] = 1
	GameState.inventory[item_id] = 1
	var path := "user://dungeon100_blauw.json"
	check("opslaan tijdens de run", GameState.save_game(Vector2i(2, 2), Vector2i.DOWN, path))
	var raw := GameState.read_save(path)
	check("save bevat permanent item en momentopname (goud 80), niet alleen de run",
			raw["dungeon100"] is Dictionary and int(raw["dungeon100"]["permanent"].get(item_id, 0)) == 1
			and int(raw["dungeon100"]["snapshot"]["gold"]) == 80 and int(raw["dungeon100"]["snapshot"]["party"][0]["level"]) == 8)
	GameState.dungeon100_floor = 4
	GameState.dungeon100_checkpoint = 0
	GameState.party[0]["hp"] = 0
	GameState.respawn()
	check("dood: verdieping 0, spawn bij de ingang, run voorbij", GameState.dungeon100_floor == 0
			and GameState.pending_spawn == "van_dungeon100" and not GameState.dungeon100_run_active())
	check("dood zet level 8, 80 goud en kruid terug en levert het blauwe item af",
			GameState.party[0]["level"] == 8 and GameState.gold == 80 and GameState.item_count("kruid") == 2
			and GameState.item_count("sterk_drankje") == 0 and GameState.item_count(item_id) == 1
			and int(GameState.dungeon100_permanent.get(item_id, 0)) == 1
			and int(GameState.dungeon100_delivered.get(item_id, 0)) == 1)
	check("wapenvak van voor de run is terug (%s)" % gear_before, str(GameState.party[0].get("equip", {}).get("wapen", "")) == gear_before)
	var path_na := "user://dungeon100_blauw_na.json"
	check("opslaan na de dood", GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, path_na))
	GameState.new_game("Dennis")
	check("laden na de dood: databank en item blijven, geen lopende run, level 8 en 80 goud",
			GameState.load_game(path_na) and not GameState.dungeon100_run_active()
			and int(GameState.dungeon100_permanent.get(item_id, 0)) == 1 and GameState.item_count(item_id) == 1
			and GameState.party[0]["level"] == 8 and GameState.gold == 80 and GameState.item_count("kruid") == 2)
	GameState.new_game("Dennis")
	check("tussentijdse save laadt de run terug, met de echte party in de momentopname", GameState.load_game(path)
			and GameState.dungeon100_run_active() and int(GameState.dungeon100_snapshot["party"][0]["level"]) == 8
			and int(GameState.dungeon100_snapshot["gold"]) == 80)
	GameState.dungeon100_end_run(true)
	check("einde van die geladen run levert het blauwe item één keer af", GameState.item_count(item_id) == 1
			and GameState.party[0]["level"] == 8 and not GameState.dungeon100_run_active())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_na))
	# nieuwe run pas bij herintrede
	GameState.gold = 80
	GameState.party[0]["level"] = 8
	GameState.dungeon100_begin_run()
	check("nieuwe run: level 1, blauw item beschikbaar, geen tijdelijk drankje", GameState.party[0]["level"] == 1
			and GameState.item_count(item_id) >= 1 and GameState.item_count("sterk_drankje") == 0 and GameState.dungeon100_floor >= 1)
	GameState.dungeon100_floor = 99
	GameState.inventory[Blue.WARP_ITEM] = 1
	check("Warp werkt niet op verdieping 99", not GameState.dungeon100_can_warp() and not GameState.dungeon100_warp())
	GameState.dungeon100_floor = 100
	check("Warp mag op verdieping 100", GameState.dungeon100_can_warp())
	# geen scènewissel hier: dungeon100_warp roept change_map aan. Dat test deel C.
	GameState.inventory.erase(Blue.WARP_ITEM)
	GameState.dungeon100_end_run(true)
	check("na afloop is het blauwe item er één keer (niet verdubbeld)", GameState.item_count(item_id) == 1
			and GameState.party[0]["level"] == 8 and GameState.gold == 80)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameState.new_game("Dennis")


# ================================================================ deel C
func _scene_tests() -> void:
	var mimic_floor := _find_kind(Blue.KIND_MIMIC)
	var blue_floor := _find_kind(Blue.KIND_BLUE)
	check("er is een verdieping met een Mimic en een met een Blauwe Kist", not mimic_floor.is_empty() and not blue_floor.is_empty())
	if mimic_floor.is_empty():
		return
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.gold = 55
	GameState.party[0]["level"] = 6
	GameState.dungeon100_seed = int(mimic_floor["seed"])
	GameState.dungeon100_floor = int(mimic_floor["floor"])
	GameState.change_map(DUNGEON, "omhoog")
	check("Mimic-verdieping geladen", await wait_floor(int(mimic_floor["floor"])))
	var ch := _chest(str(mimic_floor["id"]))
	check("Mimic-kist ziet eruit als een gewone kist (geen blauwe tint)", ch != null and ch.kind == Blue.KIND_MIMIC
			and ch.sprite.modulate != Blue.BLUE_TINT)
	var base_hp := int(GD.ENEMIES[Blue.MIMIC_ENEMY]["max_hp"])
	var scaled := int(S.monster_stats(GD.ENEMIES[Blue.MIMIC_ENEMY], int(mimic_floor["floor"]))["max_hp"])
	ch.wake_mimic()
	check("Mimic start een gevecht", await wait_until(func(): return battle() != null and battle().is_node_ready(), 20.0))
	var b := battle()
	check("Mimic-gevecht gebruikt de schaal van de verdieping (HP %d > basis %d)" % [scaled, base_hp],
			b != null and str(b.enemies[0]["id"]) == Blue.MIMIC_ENEMY and int(b.enemies[0]["s"]["max_hp"]) == scaled
			and (scaled > base_hp or int(mimic_floor["floor"]) == 1))
	await screenshot("d100_mimic_gevecht")
	GameState.end_battle("flee")
	check("vluchten uit de Mimic: de kist blijft dicht, de run loopt door", await wait_floor(int(mimic_floor["floor"]))
			and GameState.dungeon100_run_active() and not GameState.story_flags.has("kist:" + str(mimic_floor["id"])))

	# Blauwe Kist op een (mogelijk andere) verdieping van dezelfde run
	GameState.dungeon100_seed = int(blue_floor["seed"])
	GameState.dungeon100_floor = int(blue_floor["floor"])
	GameState.change_map(DUNGEON, "omhoog")
	check("Blauwe verdieping geladen", await wait_floor(int(blue_floor["floor"])))
	var bl := _chest(str(blue_floor["id"]))
	check("Blauwe Kist is blauw getint", bl != null and bl.kind == Blue.KIND_BLUE and bl.sprite.modulate == Blue.BLUE_TINT)
	await screenshot("d100_blauwe_kist")
	var bid := str(bl.loot["items"][0]["item"])
	bl.open_chest()
	await pframes(5)
	check("openen zet het item in de databank en in de tas van de run", int(GameState.dungeon100_permanent.get(bid, 0)) >= 1
			and GameState.item_count(bid) >= 1 and GameState.story_flags.has("kist:" + bl.chest_id))
	await _close_dialog()

	# Warp: verdieping 100, kristal gebruiken, echte party terug + blauw item afgeleverd
	GameState.inventory[Blue.WARP_ITEM] = 1
	GameState.dungeon100_floor = 100
	check("Warp vanuit de run", GameState.dungeon100_warp())
	check("Warp: wereldkaart", await wait_scene_path(Gen.WORLD_SCENE))
	var wsp: Node2D = scene().get_node_or_null("Spawns/van_dungeon100")
	check("Warp: bij de ingang, level 6, 55 goud, blauw item in de echte tas, geen kristal, run voorbij",
			wsp != null and tile() == Vector2i((wsp.position / 16.0).floor()) and GameState.party[0]["level"] == 6
			and GameState.gold == 55 and GameState.item_count(bid) >= 1 and GameState.item_count(Blue.WARP_ITEM) == 0
			and not GameState.dungeon100_run_active() and GameState.dungeon100_floor == 0)
	await screenshot("d100_warp_ingang")
	GameState.encounter_multiplier = 1.0


func _find_kind(kind: String) -> Dictionary:
	for sd in [3, 11, 42, 99, 7]:
		for f in range(1, 31):
			var d := Gen.generate(sd, f)
			for c in d["room"]["chests"]:
				if str(c.get("kind", "")) == kind:
					return {"seed": sd, "floor": f, "id": str(c["id"])}
	return {}


func _chest(id: String):
	var s := scene()
	if s == null:
		return null
	for c in s.chests:
		if c.chest_id == id:
			return c
	return null


# ================================================================ hulp
func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func battle():
	var s := scene()
	if s != null and s.scene_file_path == GameState.BATTLE_SCENE:
		return s
	return null


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 8.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func wait_floor(n: int, timeout := 15.0) -> bool:
	var ok := await wait_until(func():
		var s := scene()
		return s != null and s.name == "Dungeon100" and s.is_node_ready() and not GameState.changing_map \
				and int(s.get("floor_no")) == n and GameState.dungeon100_floor == n, timeout)
	await wait_fade()
	return ok


func wait_scene_path(path: String, timeout := 15.0) -> bool:
	var ok := await wait_until(func():
		var s := scene()
		return s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map, timeout)
	await wait_fade()
	return ok


func _close_dialog() -> void:
	for i in 8:
		if not Dialog.is_open:
			return
		if Dialog.has_method("advance"):
			Dialog.advance()
		await pframes(2)


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	var dir := shots
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
