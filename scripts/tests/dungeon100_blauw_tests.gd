extends Node
## ALLEEN VOOR TESTEN - Het Gesimuleerde Archief: Blauwe Kisten, Mimics en de Warp.
## Start:  godot --path . -- --dungeon100blauwtest [--shots=/pad/map]
##   Deel A: deterministische soort (~5% blauw, ~10% Mimic), baaskist nooit, Warp alleen op 100.
##   Deel B: momentopname, permanente items in de save, dood = dungeon uit, Warp levert af.
##   Deel C: echte scène: blauwe tint, Mimic-gevecht met schaal, Warp naar ECHO's Kamer.
## Zit niet in de export (scripts/tests/*).

const Blue := preload("res://scripts/data/dungeon100_blue.gd")
const S := preload("res://scripts/data/dungeon100_scaling.gd")
const Gear := preload("res://scripts/data/grade_gear.gd")
const Shop := preload("res://scripts/data/shop_data.gd")
const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DUNGEON := "res://scenes/maps/dungeon100.tscn"
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const Equipment := preload("res://scripts/equipment.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")

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
	_ring_tests()
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
	check("kind_for zonder aanwijzing geeft nooit blauw (%d kisten)" % n, blue_n == 0 and Blue.kind_for(1, 7, "k", false, true) == Blue.KIND_BLUE)
	_blue_bracket_tests()
	check("Mimic ~10%% (%.2f%%)" % (mimic_p * 100.0), mimic_p > 0.08 and mimic_p < 0.12)
	var loot := Blue.blue_loot(9, 12, "kist")
	check("blauwe buit is gemarkeerd en heeft een soort", bool(loot["blue"]) and str(loot["kind"]) in Blue.BLUE_KINDS)
	var again := Blue.blue_loot(9, 12, "kist")
	check("blauwe buit is deterministisch", loot == again)
	check("blue_gear geeft altijd een blauw uitrustingsstuk", Blue.is_blue_item(Blue.blue_gear(9, 12, "kist")))
	_blue_ratio_tests()
	var boss := S.boss_loot(100, _rng(1))
	var with := Blue.with_warp(boss, 100)
	check("Warp Crystal zit in de baasbuit van verdieping 100 en nergens anders",
			(with["items"] as Array).any(func(it): return str(it["item"]) == Blue.WARP_ITEM)
			and not (Blue.with_warp(boss, 90)["items"] as Array).any(func(it): return str(it["item"]) == Blue.WARP_ITEM))
	check("Mimic bestaat in de vijanddata", GD.ENEMIES.has(Blue.MIMIC_ENEMY))
	_g4_rol_tests()


## Grade 4-spreuken: één rol per canon-spreuk, alleen in de blauwe pool vanaf verdieping 80.
## De oude vijf rol-ids blijven opzoekbaar, maar zijn niet meer die pool.
func _g4_rol_tests() -> void:
	var spells: Array[String] = []
	for sid in GD.SPELLS:
		var sp: Dictionary = GD.SPELLS[sid]
		if int(sp.get("grade", 0)) == 4:
			spells.append(str(sid))
	spells.sort()
	var verwacht: Array[String] = []
	for sid in spells:
		verwacht.append("spreuk_g4_" + sid)
	var pool: Array[String] = []
	for id in Gear.SCROLLS:
		pool.append(str(id))
	pool.sort()
	check("grade 4 is twintig canon-spreuken, elk met een eigen rol", spells.size() == 20 and pool == verwacht)
	var rol_ok := true
	var winkel := false
	for sid in spells:
		var rid := "spreuk_g4_" + sid
		var it: Dictionary = GD.ITEMS.get(rid, {})
		var sp: Dictionary = GD.SPELLS[sid]
		var naam := str(it.get("name", ""))
		var spreuknaam := str(sp.get("name", ""))
		var kort := str(it.get("short", naam))
		if str(it.get("teach", "")) != sid or str(it.get("target", "")) != "ally":
			rol_ok = false
		if not naam.begins_with("Scroll: ") or not naam.contains(spreuknaam):
			rol_ok = false
		if kort.length() > 13 or (naam.length() > 13 and not it.has("short")):
			rol_ok = false
		if sp.get("shop", true) != false or int(it.get("price", 0)) != 0:
			winkel = true
		if Shop.list_price(rid) != 0 or Shop.sell_price(rid) != 0:
			winkel = true
		if not Blue.is_blue_item(rid):
			rol_ok = false
		if (S.SPELL_SCROLLS as Array).has(rid):
			winkel = true
	for shop_id in Shop.SHOPS:
		var shop: Dictionary = Shop.SHOPS[shop_id]
		for offer in shop.get("offers", []):
			if str(offer.get("id", "")).begins_with("spreuk_g4_"):
				winkel = true
	check("elke G4-rol leert die spreuk, in het Nederlands, en blijft een blauw item", rol_ok)
	check("G4-rollen liggen niet in de winkel en niet in gewone kisten", not winkel)
	var oud_ok := true
	var oud_in_pool := false
	for id in Gear.LEGACY_SCROLLS:
		var oud: Dictionary = GD.ITEMS.get(id, {})
		if oud.is_empty() or str(oud.get("teach", "")) == "" or not Blue.is_blue_item(id):
			oud_ok = false
		if Gear.is_scroll(id):
			oud_in_pool = true
	check("oude vijf rollen blijven opzoekbaar en zijn geen grade-4-pool", oud_ok and not oud_in_pool
			and Gear.LEGACY_SCROLLS.size() == 5)
	var onder := true
	for f in range(1, 80):
		for seed in range(0, 4):
			var id := Gear.pick(seed, f, "rol")
			if Gear.is_scroll(id) or Gear.is_legacy_scroll(id):
				onder = false
			elif int(Gear.item(id).get("grade", 0)) != Gear.grade_for_floor(f):
				onder = false
	check("onder verdieping 80 valt geen G4-rol", onder)
	var gezien := {}
	var diep := true
	for seed in range(0, 240):
		for chest in ["a", "b"]:
			var id := Gear.pick(seed, 80, chest)
			if Gear.is_scroll(id):
				gezien[id] = true
			elif Gear.is_legacy_scroll(id) or int(Gear.item(id).get("grade", 0)) != 4:
				diep = false
			elif int(Gear.item(id).get("min_floor", 99)) > 80:
				diep = false
	var loot := Blue.blue_loot(4, 85, "diep")
	var lid := Blue.blue_gear(4, 85, "diep")
	check("vanaf verdieping 80 valt elke G4-rol, en geen oude rol", diep and gezien.size() == Gear.SCROLLS.size()
			and int(loot["grade"]) == 4 and Blue.is_blue_item(lid)
			and (Gear.is_scroll(lid) or int(Gear.item(lid).get("grade", 0)) == 4)
			and not Gear.is_legacy_scroll(lid))


## CANON: blauwe-kistkans per floor-bracket (TODO.md "Blue chest kans per floor-bracket").
func _blue_bracket_tests() -> void:
	var want := {5: 0.05, 15: 0.10, 30: 0.15, 40: 0.20, 60: 0.25, 70: 0.30, 90: 0.40, 97: 0.50}
	var ok := true
	var max_one := true
	for f in want:
		ok = ok and is_equal_approx(Blue.blue_floor_chance(f), float(want[f]))
		var hits := 0
		var n := 3000
		for sd in n:
			var b := Blue.blue_indices(sd * 31 + 7, f, 4)
			max_one = max_one and b.size() <= 1
			if not b.is_empty():
				hits += 1
		var p := float(hits) / float(n)
		if absf(p - float(want[f])) > 0.03:
			ok = false
			print("  verdieping %d: %.3f (verwacht %.2f)" % [f, p, float(want[f])])
	check("blauwe-kistkans per bracket: 5/10/15/20/25/30/40/50%", ok)
	check("normale kamer: hoogstens 1 blauwe kist per verdieping", max_one)
	check("verdieping 100 en zonder kisten: geen blauwe kist", Blue.blue_floor_chance(100) == 0.0
			and Blue.blue_indices(1, 50, 0).is_empty())
	var forced := Blue.blue_indices(3, 2, 5, 2)
	check("vast aantal (kamer-override) geeft precies zoveel verschillende kisten", forced.size() == 2 and forced[0] != forced[1]
			and Blue.blue_indices(3, 2, 1, 2).size() == 1)
	var tot := 0.0
	for f in range(1, 100):
		tot += Blue.blue_floor_chance(f)
	check("verwacht ~23 blauwe kisten per run uit normale kamers (%.1f; was ~60-80)" % tot, tot > 20.0 and tot < 26.0)
	var early := 0
	var gen_ok := true
	var room_ok := true
	for f in range(1, 21):
		var d := Gen.generate(5, f)
		var nb := 0
		for c in d["room"]["chests"]:
			if str(c.get("kind", "")) == Blue.KIND_BLUE:
				nb += 1
		var lt := str(d.get("layout_type", ""))
		if lt == "kist":
			room_ok = room_ok and nb == mini(Blue.BLUE_ROOM_CHEST, (d["chest_slots"] as Array).size())
			continue
		gen_ok = gen_ok and nb <= 1
		early += nb
	check("generator: verdieping 1-20 hoogstens 1 blauwe kist per verdieping buiten Chest Room (%d totaal)" % early, gen_ok and early <= 8)
	check("generator: Chest Room heeft precies 2 blauwe kisten", room_ok)
	# kamer-type-overrides (CANON)
	var tr := 0
	var tr_ok := true
	for sd in 2000:
		var v := Blue.blue_forced_for(sd, 30, "schat")
		tr_ok = tr_ok and (v == 0 or v == 1)
		tr += v
	check("override: Chest Room 2, Treasure Room ~50%% op 1 (%.2f), andere kamers volgen de tabel" % (tr / 2000.0),
			Blue.blue_forced_for(1, 30, "kist") == 2 and tr_ok and absf(tr / 2000.0 - 0.5) < 0.04
			and Blue.blue_forced_for(1, 30, "medium") == -1 and Blue.blue_forced_for(1, 30, "puzzel") == 0)
	# bracket-statistiek floor 1-20 vs. oud (5% per kist, ~2-4 kisten): flink lager
	var per_floor_early := 0.0
	for f in range(1, 21):
		per_floor_early += Blue.blue_floor_chance(f)
	check("verdieping 1-20: verwacht %.1f blauwe kisten (oud ~3-4 bij 5%% per kist)" % per_floor_early, absf(per_floor_early - 1.5) < 0.01)


## CANON-verdeling blauwe kisten per grade (TODO.md "Loot ratio consumables vs. equipment").
func _blue_ratio_tests() -> void:
	var floors := {1: 10, 2: 30, 3: 60, 4: 90}
	var all_ok := true
	var ids_ok := true
	var elixer_seen := false
	for g in floors:
		var tel := {}
		var n := 5000
		for i in n:
			var l := Blue.blue_loot(i * 7919 + g, int(floors[g]), "d100_%d_%d" % [i, g])
			var k := str(l["kind"])
			tel[k] = int(tel.get(k, 0)) + 1
			match k:
				"leeg":
					ids_ok = ids_ok and (l["items"] as Array).is_empty() and int(l["gold"]) == 0
				"goud":
					ids_ok = ids_ok and (l["items"] as Array).is_empty() and int(l["gold"]) > 0
				"equipment", "accessoire":
					ids_ok = ids_ok and Blue.is_blue_item(str(l["items"][0]["item"]))
				"consumable":
					var cid := str(l["items"][0]["item"])
					ids_ok = ids_ok and GD.ITEMS.has(cid) and not Blue.is_blue_item(cid)
					elixer_seen = elixer_seen or cid == "elixer"
		var row: Array = Blue.BLUE_RATIO[g - 1]
		for i in Blue.BLUE_KINDS.size():
			var p := float(tel.get(Blue.BLUE_KINDS[i], 0)) / float(n)
			var ok := absf(p - float(row[i]) / 100.0) < 0.035
			all_ok = all_ok and ok
			if not ok:
				print("  G%d %s: %.3f (verwacht %.2f)" % [g, Blue.BLUE_KINDS[i], p, float(row[i]) / 100.0])
	check("blauwe kisten volgen de CANON-verdeling per grade (G1-G4)", all_ok)
	check("blauwe buit per soort klopt (leeg/goud/uitrusting/accessoire/consumable)", ids_ok)
	check("elixers kunnen in een blauwe kist zitten", elixer_seen)
	var acc_ok := true
	for i in 200:
		var l := Blue.blue_loot(i, 90, "acc%d" % i)
		if str(l["kind"]) == "accessoire":
			acc_ok = acc_ok and str(Gear.item(str(l["items"][0]["item"])).get("slot", "")) == "accessoire"
	check("accessoire op grade 4 is een G4-accessoire", acc_ok)


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


# ================================================================ deel B
func _run_tests() -> void:
	GameState.new_game("Dax")
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
	var item_id := Blue.blue_gear(5, 4, "testkist")
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
			and GameState.pending_spawn == EchoGrot.KAMER_SPAWN and not GameState.dungeon100_run_active())
	check("dood zet level 8, 80 goud en kruid terug en levert het blauwe item af",
			GameState.party[0]["level"] == 8 and GameState.gold == 80 and GameState.item_count("kruid") == 2
			and GameState.item_count("sterk_drankje") == 0 and GameState.item_count(item_id) == 1
			and int(GameState.dungeon100_permanent.get(item_id, 0)) == 1
			and int(GameState.dungeon100_delivered.get(item_id, 0)) == 1)
	check("wapenvak van voor de run is terug (%s)" % gear_before, str(GameState.party[0].get("equip", {}).get("wapen", "")) == gear_before)
	var path_na := "user://dungeon100_blauw_na.json"
	check("opslaan na de dood", GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, path_na))
	GameState.new_game("Dax")
	check("laden na de dood: databank en item blijven, geen lopende run, level 8 en 80 goud",
			GameState.load_game(path_na) and not GameState.dungeon100_run_active()
			and int(GameState.dungeon100_permanent.get(item_id, 0)) == 1 and GameState.item_count(item_id) == 1
			and GameState.party[0]["level"] == 8 and GameState.gold == 80 and GameState.item_count("kruid") == 2)
	GameState.new_game("Dax")
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
	GameState.new_game("Dax")


func _ring_tests() -> void:
	GameState.new_game("Dax")
	check("ring-run start", GameState.dungeon100_begin_run() and GameState.dungeon100_run_active())
	GameState.dungeon100_floor = 100
	GameState.inventory[Blue.WARP_ITEM] = 1
	check("warp zonder keuze laat de run lopen", not GameState.dungeon100_warp()
			and GameState.dungeon100_can_warp() and GameState.dungeon100_run_active()
			and GameState.dungeon100_floor == 100)
	GameState.inventory.erase(Blue.WARP_ITEM)
	GameState.dungeon100_floor = 12
	GameState.inventory["simulatie_ring"] = 1
	var held: Dictionary = GameState.party[0]
	var kaal := int(held["atk"])
	var hp0 := int(held["max_hp"])
	check("Simulatie-ring om", bool(Equipment.equip(held, GameState.inventory, "accessoire", "simulatie_ring")["ok"]))
	check("ring geeft +10% in de grot", int(held["atk"]) == GD.round_half_even(float(kaal) * 1.1)
			and int(held["max_hp"]) == GD.round_half_even(float(hp0) * 1.1) and int(held["atk"]) > kaal)
	GameState.dungeon100_floor = 0
	Equipment.refresh(held)
	check("ring doet niets buiten de grot", int(held["atk"]) == kaal and int(held["max_hp"]) == hp0)
	GameState.dungeon100_floor = 12
	Equipment.refresh(held)
	held["hp"] = 0
	var terug := GameState.dungeon100_defeat()
	check("eerste dood met ring herstart de verdieping", terug == Rules.dungeon_scene
			and GameState.dungeon100_run_active() and GameState.dungeon100_floor == 12
			and int(GameState.party[0]["hp"]) == int(GameState.party[0]["max_hp"])
			and bool(GameState.story_flags.get("dungeon100_ring:reset", false)))
	var weg := GameState.dungeon100_defeat()
	check("tweede dood beëindigt de run naar ECHO", weg == Rules.WORLD_SCENE
			and not GameState.dungeon100_run_active() and GameState.dungeon100_floor == 0)
	GameState._autosave_request = ""
	GameState.new_game("Dax")


# ================================================================ deel C
func _scene_tests() -> void:
	var mimic_floor := _find_kind(Blue.KIND_MIMIC)
	var blue_floor := _find_kind(Blue.KIND_BLUE)
	check("er is een verdieping met een Mimic en een met een Blauwe Kist", not mimic_floor.is_empty() and not blue_floor.is_empty())
	if mimic_floor.is_empty():
		return
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.gold = 55
	GameState.party[0]["level"] = 6
	GameState.dungeon100_seed = int(mimic_floor["seed"])
	GameState.dungeon100_floor = int(mimic_floor["floor"])
	GameState.change_map(DUNGEON, "omhoog")
	check("Mimic-verdieping geladen", await wait_floor(int(mimic_floor["floor"])))
	var ch = _chest(str(mimic_floor["id"]))
	check("Mimic-kist ziet eruit als een gewone kist (geen blauwe tint)", ch != null and ch.kind == Blue.KIND_MIMIC
			and ch.sprite.modulate != Blue.BLUE_TINT)
	var base_hp := int(GD.ENEMIES[Blue.MIMIC_ENEMY]["max_hp"])
	var scaled := int(S.monster_stats(GD.ENEMIES[Blue.MIMIC_ENEMY], int(mimic_floor["floor"]))["max_hp"])
	ch.wake_mimic()
	check("Mimic start een gevecht", await wait_until(func(): return battle() != null and battle().is_node_ready(), 20.0))
	var b = battle()
	check("Mimic-gevecht gebruikt de schaal van de verdieping (HP %d > basis %d)" % [scaled, base_hp],
			b != null and str(b.enemies[0]["id"]) == Blue.MIMIC_ENEMY and int(b.enemies[0]["s"]["max_hp"]) == scaled
			and (scaled > base_hp or int(mimic_floor["floor"]) == 1))
	await screenshot("d100_mimic_gevecht")
	_drop_battle()
	GameState.end_battle("flee")
	check("vluchten uit de Mimic: de kist blijft dicht, de run loopt door", await wait_floor(int(mimic_floor["floor"]))
			and GameState.dungeon100_run_active() and not GameState.story_flags.has("kist:" + str(mimic_floor["id"])))

	_mimic_vermomd_tests()

	# Blauwe Kist op een (mogelijk andere) verdieping van dezelfde run
	GameState.dungeon100_seed = int(blue_floor["seed"])
	GameState.dungeon100_floor = int(blue_floor["floor"])
	GameState.change_map(DUNGEON, "omhoog")
	check("Blauwe verdieping geladen", await wait_floor(int(blue_floor["floor"])))
	var bl = _chest(str(blue_floor["id"]))
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
	check("Warp zonder keuze doet niets", not GameState.dungeon100_warp()
			and GameState.dungeon100_can_warp() and GameState.dungeon100_run_active())
	check("Warp vanuit de run", GameState.dungeon100_warp("ring"))
	check("Warp: ECHO's Chamber", await wait_scene_path(EchoGrot.KAMER))
	var wsp: Node2D = scene().get_node_or_null("Spawns/" + EchoGrot.KAMER_SPAWN)
	check("Warp: bij ECHO, level 6, 55 goud, blauw item in de echte tas, geen kristal, run voorbij",
			wsp != null and tile() == Vector2i((wsp.position / 16.0).floor()) and GameState.party[0]["level"] == 6
			and GameState.gold == 55 and GameState.item_count(bid) >= 1 and GameState.item_count("simulatie_ring") >= 1
			and GameState.item_count(Blue.WARP_ITEM) == 0
			and not GameState.dungeon100_run_active() and GameState.dungeon100_floor == 0
			and GameState.story_flags.get(EchoGrot.FLAG_RESULTAAT, false) == true)
	await screenshot("d100_warp_ingang")
	GameState.encounter_multiplier = 1.0


func _find_kind(kind: String) -> Dictionary:
	for sd in [3, 11, 42, 99, 7, 5, 8]:
		for f in range(1, 61):
			var d := Gen.generate(sd, f)
			for c in d["room"]["chests"]:
				if str(c.get("kind", "")) == kind and (kind != Blue.KIND_BLUE
						or Blue.is_blue_item(str(c.get("item", "")))):
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


## Stopt een lopend gevecht zonder dat de wachtlus nog een frame pakt (die is dan al weg).
func _drop_battle() -> void:
	var b = battle()
	if b == null:
		return
	if get_tree().current_scene == b:
		get_tree().current_scene = null
	b.free()


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


## v0.21: Mimic op de kaart = dichte Blauwe Kist (pixel-gelijk), loopt niet, verraadt zich niet.
func _mimic_vermomd_tests() -> void:
	var ed: Dictionary = GD.ENEMIES[Blue.MIMIC_ENEMY]
	var mm: MapMonster = preload("res://scripts/dungeon/map_monster.gd").new()
	var room := scene()
	mm.setup(room, {"id": "mimic_test", "enemy": Blue.MIMIC_ENEMY, "tile": [1, 1]}, 1)
	check("Mimic op de kaart: moves false (game_data en MapMonster)", ed.get("moves", true) == false
			and not mm.moves and mm.disguised)
	mm.stun(5)
	mm._stun_look(0.3)
	mm.step_tick()
	check("Mimic na vluchten/stun: geen stun, geen tint, geen sterretjes", not mm.is_stunned()
			and mm.sprite.modulate == Color.WHITE and mm.get_node_or_null("Verlamd") == null)
	var hw := FileAccess.get_file_as_string("res://tools/handwerk.txt")
	var tex: Texture2D = load("res://assets/map_monsters/mimic.png")
	check("Mimic-art (gevecht 80x64, kaart 32x64) in handwerk.txt", hw.contains("assets/sprites/enemies/mimic.png")
			and hw.contains("assets/map_monsters/mimic.png") and tex.get_width() == 32 and tex.get_height() == 64
			and (load(ed["sprite"]) as Texture2D).get_size() == Vector2(80, 64))
	mm.free()
