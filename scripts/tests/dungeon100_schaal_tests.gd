extends Node
## ALLEEN VOOR TESTEN - Task #4 "Monsterschaal en buit" (dungeon van 100 verdiepingen).
## Start:  godot --path . -- --dungeon100schaaltest
##   Deel A: pure functies (scripts/data/dungeon100_scaling.gd): verdiepingen/bazen/buitniveaus,
##           monotone schaling van HP/ATK/DEF/EXP/goud, bazen sterker dan gewone monsters, verdieping 0 =
##           ongewijzigd, buit (niveau stijgt, deterministisch per seed, alle ids bestaan), spawn-gegevens.
##   Deel B: haken in de bestaande code: DungeonChest (buit per verdieping), Battle (monster- en
##           baasstats uit GameState.dungeon100_floor, verdieping 0 = oude waarden, baasbuit + baasvlag).
## Zit niet in de export (scripts/tests/*).

const S := preload("res://scripts/data/dungeon100_scaling.gd")
const GD := preload("res://scripts/data/game_data.gd")
const Equipment := preload("res://scripts/equipment.gd")
const ChestScript := preload("res://scripts/dungeon/dungeon_chest.gd")
const MonsterScript := preload("res://scripts/dungeon/map_monster.gd")

## Gewone vijanden (niet de bazen-only Wortelkoning, die in game_data.gd een baas-basis heeft).
const NORMAL_ENEMIES := ["mosslijm", "moskonijn", "papiergeest", "glitchmot", "mech_wachter", "kennis_beest",
		"wortelkruiper", "mistuil", "sporenzwam"]
const STAT_KEYS := ["max_hp", "atk", "def", "agi", "exp", "gold"]

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(4040)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: pure functies ===")
	_floor_tests()
	_scaling_tests()
	_boss_tests()
	_loot_tests()
	_entry_tests()
	print("=== Deel B: haken in kist en gevecht ===")
	await _chest_tests()
	await _battle_tests()
	GameState.dungeon100_floor = 0
	print("DUNGEON100TEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _rng(sd: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	return r


# ================================================================ deel A
func _floor_tests() -> void:
	check("GameState.dungeon100_floor bestaat en staat standaard op 0", GameState.dungeon100_floor == 0)
	var boss_floors := []
	for f in range(-3, 111):
		if S.is_boss_floor(f):
			boss_floors.append(f)
	check("baasverdiepingen = canon, zonder 100",
			boss_floors == [10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 99] and S.boss_floors() == boss_floors)
	check("alleen verdieping 100 is de eindverdieping, en daar staat geen baas",
			S.is_final_floor(100) and not S.is_final_floor(90) and not S.is_final_floor(0)
			and not S.is_boss_floor(100) and S.boss_for_floor(100).is_empty())
	check("boss_index: 10 -> 1, 25 -> 3, 100 -> 0, 15 -> 0",
			S.boss_index(10) == 1 and S.boss_index(25) == 3 and S.boss_index(100) == 0 and S.boss_index(15) == 0)
	var tiers_ok := true
	var prev := 0
	for f in range(1, 101):
		var t := S.tier_for_floor(f)
		tiers_ok = tiers_ok and t >= prev and t >= 1 and t <= 5
		prev = t
	check("buitniveau stijgt monotoon van 1 naar 5 (1, 20 = 1; 21 = 2; 100 = 5)", tiers_ok
			and S.tier_for_floor(1) == 1 and S.tier_for_floor(20) == 1 and S.tier_for_floor(21) == 2 and S.tier_for_floor(100) == 5)
	check("buitniveau buiten de dungeon (0) = 0", S.tier_for_floor(0) == 0)
	check("boss_flag('dungeon100_boss:30') en boss_defeated", S.boss_flag(30) == "dungeon100_boss:30"
			and S.boss_defeated(30, {"dungeon100_boss:30": true}) and not S.boss_defeated(30, {}))


func _scaling_tests() -> void:
	var same := true
	for id in GD.ENEMIES:
		same = same and S.monster_stats(GD.ENEMIES[id], 0) == GD.ENEMIES[id] \
				and S.battle_enemy(GD.ENEMIES[id], 0, false) == GD.ENEMIES[id] \
				and S.battle_enemy(GD.ENEMIES[id], 0, true) == GD.ENEMIES[id]
	check("verdieping 0: monster_stats/battle_enemy geven de data ongewijzigd terug (alle vijanden)", same)
	var base: Dictionary = GD.ENEMIES["mosslijm"]
	var f1 := S.monster_stats(base, 1)
	var ok1 := true
	for k in STAT_KEYS:
		ok1 = ok1 and int(f1[k]) == int(base[k])
	check("verdieping 1 = de basiswaarden van de vijand", ok1)
	check("de bron-data wordt niet aangepast (duplicate)", int(GD.ENEMIES["mosslijm"]["max_hp"]) == 10
			and int(S.monster_stats(base, 50)["max_hp"]) > 10 and int(base["max_hp"]) == 10)
	var mono := true
	var strict := true
	for id in NORMAL_ENEMIES:
		var b: Dictionary = GD.ENEMIES[id]
		var last: Dictionary = S.monster_stats(b, 1)
		for f in range(2, 101):
			var cur := S.monster_stats(b, f)
			for k in STAT_KEYS:
				mono = mono and int(cur[k]) >= int(last[k])
			for k in ["max_hp", "atk"]:
				strict = strict and int(cur[k]) > int(last[k])
			if b.has("mag"):
				mono = mono and int(cur["mag"]) >= int(last["mag"]) and int(cur["mdef"]) >= int(last["mdef"])
			last = cur
	check("alle gewone vijanden: HP/ATK/DEF/SPD/EXP/goud nemen nooit af van verdieping 1 t/m 100", mono)
	var windows := true
	for id in NORMAL_ENEMIES:
		for f in range(1, 91, 10):
			for k in ["def", "exp", "gold"]:
				windows = windows and int(S.monster_stats(GD.ENEMIES[id], f + 10)[k]) > int(S.monster_stats(GD.ENEMIES[id], f)[k])
	check("... HP/ATK stijgen elke verdieping echt, DEF/EXP/goud elke 10 verdiepingen", strict and windows)
	var m100 := S.monster_stats(base, 100)
	check("Moss Slime op 100: veel sterker dan op 1 (HP %d, ATK %d, DEF %d, EXP %d, goud %d)"
			% [m100["max_hp"], m100["atk"], m100["def"], m100["exp"], m100["gold"]],
			int(m100["max_hp"]) >= 20 * int(base["max_hp"]) and int(m100["atk"]) >= 10 * int(base["atk"])
			and int(m100["def"]) >= 10 * int(base["def"]) and int(m100["exp"]) >= 30 * int(base["exp"])
			and int(m100["gold"]) >= 10 * int(base["gold"]))
	check("verdieping boven 100 / onder 1 wordt begrensd (150 = 100)", S.monster_stats(base, 150) == S.monster_stats(base, 100)
			and S.monster_stats(base, -5) == base)
	check("niet-stat-velden (naam, sprite, skills) blijven staan", m100["name"] == base["name"] and m100["sprite"] == base["sprite"]
			and m100["skills"] == base["skills"] and int(m100["dungeon100_floor"]) == 100)
	var wk: Dictionary = GD.ENEMIES["wortelkruiper"]
	var wk50 := S.monster_stats(wk, 50)
	check("mag/mdef schalen mee als de vijand ze heeft", int(wk50["mag"]) >= int(wk["mag"]) and int(wk50["mdef"]) > int(wk["mdef"])
			and not S.monster_stats(base, 50).has("mag"))
	# een held van niveau 1 kan hem op verdieping 1 nog neerleggen, op 100 niet in 1 slag
	check("verdieping 1 voelt als de wereldkaart: Moss Slime-HP 10 blijft 10", int(f1["max_hp"]) == 10)


func _boss_tests() -> void:
	var ok_names := true
	var names := {}
	for f in S.boss_floors():
		var b := S.boss_for_floor(f)
		ok_names = ok_names and not b.is_empty() and GD.ENEMIES.has(b["enemy"]) and str(b["name"]) != "" \
				and int(b["floor"]) == f and not bool(b["final"]) and int(b["index"]) == S.boss_index(f)
		names[b["name"]] = true
	check("boss_for_floor: elke baasverdieping een baas met bestaande vijand-sprite en naam", ok_names)
	check("alle 12 bazen hebben een eigen naam", names.size() == 12)
	check("boss_for_floor op een gewone verdieping = {}", S.boss_for_floor(1).is_empty() and S.boss_for_floor(95).is_empty()
			and S.boss_for_floor(0).is_empty() and S.boss_for_floor(110).is_empty() and S.boss_for_floor(100).is_empty())
	check("verdieping 25 heet De Schaduw van H-6", S.boss_for_floor(25)["name"] == "De Schaduw van H-6"
			and S.boss_for_floor(50)["name"] == "De Cyclus" and S.boss_for_floor(75)["name"] == "De Rechter"
			and S.boss_for_floor(99)["name"] == "De Stem")
	var bossier := true
	var last: Dictionary = {}
	var rising := true
	var canon_floors: Array[int] = [25, 50, 75, 99]
	for f in S.boss_floors():
		var bs := S.boss_stats(GD.ENEMIES[S.boss_for_floor(f)["enemy"]], f)
		if f in canon_floors:
			continue
		for id in NORMAL_ENEMIES:
			var nm := S.monster_stats(GD.ENEMIES[id], f)
			for k in ["max_hp", "atk", "def", "exp", "gold"]:
				bossier = bossier and int(bs[k]) > int(nm[k])
		if not last.is_empty():
			for k in ["max_hp", "atk", "def", "exp", "gold"]:
				rising = rising and int(bs[k]) > int(last[k])
		last = bs
	check("elke curve-baas is sterker dan elk gewoon monster op dezelfde verdieping (HP/ATK/DEF/EXP/goud)", bossier)
	check("curve-bazen worden sterker per baasverdieping (10 -> 90)", rising)
	var canon_ok := true
	var want := {25: [750, 45, 30, "licht"], 50: [1250, 75, 50, "bliksem"], 75: [1750, 105, 70, "natuur"], 99: [2250, 135, 90, "ijs"]}
	for f in want:
		var bs2 := S.boss_stats(GD.ENEMIES[S.boss_for_floor(f)["enemy"]], f)
		var row: Array = want[f]
		canon_ok = canon_ok and int(bs2["max_hp"]) == int(row[0]) and int(bs2["atk"]) == int(row[1]) \
				and int(bs2["def"]) == int(row[2]) and bool(bs2.get("weak_matters", false)) \
				and str(row[3]) in bs2.get("weak", [])
	check("canon-bazen 25/50/75/99 hebben vaste HP/ATK/DEF en zwakte", canon_ok)
	# v0.21: eigen art van RPG ART (batch 11) voor de vier canon-bazen, 256x200, met rug; De Stem 4 idle-frames.
	var art_ok := true
	for f in [25, 50, 75, 99]:
		var bs3 := S.boss_stats(GD.ENEMIES[S.boss_for_floor(f)["enemy"]], f)
		var voor: Texture2D = load(str(bs3.get("sprite", "")))
		var rug: Texture2D = load(str(bs3.get("sprite_back", "")))
		art_ok = art_ok and bool(bs3.get("is_boss", false)) and voor != null and rug != null \
				and voor.get_size() == Vector2(256, 200) and rug.get_size() == Vector2(256, 200) \
				and str(bs3["sprite"]) == str(S.BOSSES[f]["sprite"])
		if f == 99:
			var idle: Texture2D = load(str(bs3.get("idle", "")))
			art_ok = art_ok and idle != null and idle.get_size() == Vector2(1024, 200) and int(bs3.get("idle_frames", 0)) == 4
		else:
			art_ok = art_ok and not bs3.has("idle")
	check("canon-bazen: eigen art 256x200 + rug, is_boss; De Stem idle 4x256", art_ok)
	# v0.21 batch 12: de acht andere bazen ook eigen art (geen geleende vijand-sprite meer)
	var b12_ok := true
	for f in [10, 20, 30, 40, 60, 70, 80, 90]:
		var bs4 := S.boss_stats(GD.ENEMIES[S.boss_for_floor(f)["enemy"]], f)
		var v4: Texture2D = load(str(bs4.get("sprite", "")))
		var r4: Texture2D = load(str(bs4.get("sprite_back", "")))
		b12_ok = b12_ok and bool(bs4.get("is_boss", false)) and v4 != null and r4 != null \
				and v4.get_size() == Vector2(256, 200) and r4.get_size() == Vector2(256, 200) and not bs4.has("idle")
	check("alle 12 bazen van de Diepe Grot hebben eigen art 256x200 + rug", b12_ok)
	var b100 := S.boss_stats(GD.ENEMIES["kennis_beest"], 100)
	var b90 := S.boss_stats(GD.ENEMIES["kennis_beest"], 90)
	check("eindbaas (100) sterker dan een baas met dezelfde formule zonder eindbaas-bonus",
			int(b100["max_hp"]) > int(S.boss_stats(GD.ENEMIES["kennis_beest"], 99)["max_hp"]) * 1.25 and int(b100["atk"]) > int(b90["atk"]))
	check("verdieping 100 heeft geen baasnaam; de formule houdt de vijandnaam, geen roze kern",
			b100["name"] == "The Knowledge Beast" and not b100.has("core") and not b100.has("boss")
			and int(b100["boss_floor"]) == 100)
	var skill_names := []
	for sk in b100["skills"]:
		skill_names.append(sk["name"])
	check("eindbaas heeft Last Judgment; baas zonder skills krijgt Heavy Blow",
			"Last Judgment" in skill_names and S.boss_stats(GD.ENEMIES["mosslijm"], 10)["skills"][0]["name"] == "Heavy Blow")
	check("boss_stats gebruikt de bron-data niet als uitvoer (kennis_beest boss-blok blijft in game_data)",
			GD.ENEMIES["kennis_beest"].has("boss") and GD.ENEMIES["kennis_beest"]["boss"].has("core"))
	check("baas op verdieping 0: data ongewijzigd", S.boss_stats(GD.ENEMIES["kennis_beest"], 0) == GD.ENEMIES["kennis_beest"])
	check("baasstats verdieping 10: HP > 600 en < 1500 (speelbaar voor ~level 8-12)",
			int(S.boss_stats(GD.ENEMIES["papiergeest"], 10)["max_hp"]) > 600 and int(S.boss_stats(GD.ENEMIES["papiergeest"], 10)["max_hp"]) < 1500)


func _all_ids_exist(loot: Dictionary) -> bool:
	for it in loot["items"]:
		var id := str(it["item"])
		if not (GD.ITEMS.has(id) or GD.EQUIPMENT.has(id)) or int(it["n"]) < 1:
			return false
	return true


func _gear_tier(id: String) -> int:
	for kind in S.GEAR:
		var i: int = (S.GEAR[kind] as Array).find(id)
		if i >= 0:
			return i + 1
	return 0


## CANON-verdeling gewone kisten: Consumables 60% (1-2) / Goud 20% / Equipment 15% / Leeg 5%.
func _ratio_tests() -> void:
	var tel := {}
	var n := 4000
	var count_ok := true
	for i in n:
		var l := S.chest_loot(1 + i % 99, _rng(123000 + i))
		var k := str(l["kind"])
		tel[k] = int(tel.get(k, 0)) + 1
		if k == S.LOOT_CONSUMABLE:
			var c: int = int(l["items"][0]["n"])
			count_ok = count_ok and c >= 1 and c <= 2
	var want := {S.LOOT_CONSUMABLE: 0.60, S.LOOT_GOLD: 0.20, S.LOOT_EQUIPMENT: 0.15, S.LOOT_EMPTY: 0.05}
	var ok := true
	for k in want:
		var p := float(tel.get(k, 0)) / float(n)
		ok = ok and absf(p - float(want[k])) < 0.025
	check("gewone kisten: 60/20/15/5 (consumable %d, goud %d, uitrusting %d, leeg %d van %d)" % [
			int(tel.get(S.LOOT_CONSUMABLE, 0)), int(tel.get(S.LOOT_GOLD, 0)), int(tel.get(S.LOOT_EQUIPMENT, 0)), int(tel.get(S.LOOT_EMPTY, 0)), n], ok)
	check("consumables in een gewone kist: 1-2 stuks", count_ok)


func _loot_tests() -> void:
	check("buit op verdieping 0 = leeg", S.chest_loot(0, _rng(1))["items"].is_empty() and S.chest_loot(0, _rng(1))["gold"] == 0
			and S.boss_loot(0, _rng(1))["items"].is_empty())
	var ids_ok := true
	var min_one := true
	for f in range(1, 101):
		for sd in 20:
			var l := S.chest_loot(f, _rng(f * 1000 + sd))
			ids_ok = ids_ok and _all_ids_exist(l)
			match str(l["kind"]):
				S.LOOT_GOLD:
					min_one = min_one and int(l["gold"]) > 0 and l["items"].is_empty()
				S.LOOT_EMPTY:
					min_one = min_one and int(l["gold"]) == 0 and l["items"].is_empty()
				_:
					min_one = min_one and l["items"].size() >= 1 and int(l["gold"]) == 0
	check("kistbuit: alle ids bestaan, elke soort klopt (goud alleen bij goud, leeg is leeg; verdieping 1-100)", ids_ok and min_one)
	_ratio_tests()
	var gear_ok := true
	for kind in S.GEAR:
		for t in range(1, 6):
			var id := S.gear_id(kind, t)
			gear_ok = gear_ok and GD.EQUIPMENT.has(id) and str(GD.EQUIPMENT[id]["slot"]) in GD.EQUIP_SLOTS
	check("alle 30 uitrustingsstukken (6 soorten x 5 niveaus) bestaan in EQUIPMENT met een geldig vak", gear_ok and S.GEAR.size() == 6)
	var stronger := true
	for kind in S.GEAR:
		var prev_score := -1.0
		for t in range(1, 6):
			var sc := 0.0
			var it: Dictionary = GD.EQUIPMENT[S.gear_id(kind, t)]
			for st in GD.EQUIP_STATS:
				sc += float(it.get(st, 0)) * float(GD.STRONGEST_WEIGHTS["standaard"][st])
			stronger = stronger and sc > prev_score
			prev_score = sc
	check("uitrusting wordt per niveau sterker (score met STRONGEST_WEIGHTS)", stronger)
	var wearable := Equipment.can_wear({"equip_type": "krijger"}, "d100_zwaard_5") and not Equipment.can_wear({"equip_type": "magier"}, "d100_zwaard_5") \
			and Equipment.can_wear({"equip_type": "magier"}, "d100_staf_3") and Equipment.can_wear({"equip_type": "priester"}, "d100_ring_4")
	check("nieuwe uitrusting: 'wie' klopt (zwaard krijger, staf magier/priester, ring iedereen)", wearable)
	# gouden gemiddelden per verdieping stijgen
	var prev_avg := 0.0
	var gold_mono := true
	var gear_mono := true
	var prev_gear := -1.0
	for f in [1, 10, 25, 50, 75, 100]:
		var gold := 0.0
		var gear := 0.0
		var tier_sum := 0.0
		var n := 400
		for sd in n:
			var l := S.chest_loot(f, _rng(77000 + sd))
			gold += float(l["gold"])
			for it in l["items"]:
				var gt := _gear_tier(str(it["item"]))
				if gt > 0:
					gear += 1.0
					tier_sum += float(gt)
		gold /= n
		gear /= n
		gold_mono = gold_mono and gold > prev_avg
		gear_mono = gear_mono and gear >= prev_gear - 0.03
		prev_avg = gold
		prev_gear = gear
	check("gemiddeld kistgoud stijgt met de verdieping (1, 10, 25, 50, 75, 100)", gold_mono)
	check("uitrustingskans in kisten stijgt met de verdieping (%.2f -> %.2f)" % [S.gear_chance(1), S.gear_chance(100)],
			gear_mono and S.gear_chance(100) > S.gear_chance(1))
	var max_tier_ok := true
	var best_at := {}
	for f in range(1, 101):
		var best := 0
		for sd in 60:
			for it in S.chest_loot(f, _rng(5000 * f + sd))["items"]:
				var gt := _gear_tier(str(it["item"]))
				max_tier_ok = max_tier_ok and gt <= S.tier_for_floor(f)
				best = maxi(best, gt)
		best_at[f] = best
	check("kist-uitrusting nooit hoger dan het buitniveau van de verdieping", max_tier_ok)
	check("op verdieping 1-20 val alleen niveau-1 uitrusting, op 81-100 komt niveau 5 voor (beste: %d / %d)" % [best_at[10], best_at[100]],
			best_at[10] <= 1 and best_at[100] == 5)
	var a := S.chest_loot(42, _rng(99))
	var b := S.chest_loot(42, _rng(99))
	check("zelfde seed = zelfde buit", a == b)
	var potions_hi := {}
	for sd in 100:
		for it in S.chest_loot(90, _rng(sd))["items"]:
			potions_hi[it["item"]] = true
	check("gewone kisten bevatten nooit een elixer (alleen blauw of handelaar), wel sterke items op 90",
			not potions_hi.has("elixer") and potions_hi.has("toverbrouwsel"))
	var potions_lo := {}
	for sd in 100:
		for it in S.chest_loot(3, _rng(sd))["items"]:
			potions_lo[it["item"]] = true
	check("ondiepe kisten geen elixer/sterk drankje op verdieping 3", not potions_lo.has("elixer") and not potions_lo.has("sterk_drankje"))
	# baasbuit
	var boss_ok := true
	var boss_better := true
	var all_gear := true
	for f in S.boss_floors():
		for sd in 30:
			var bl := S.boss_loot(f, _rng(f * 31 + sd))
			var cl := S.chest_loot(f, _rng(f * 31 + sd))
			var gear_t := 0
			for it in bl["items"]:
				gear_t = maxi(gear_t, _gear_tier(str(it["item"])))
			boss_ok = boss_ok and _all_ids_exist(bl) and bool(bl["boss"]) and gear_t >= 1
			boss_better = boss_better and int(bl["gold"]) > int(cl["gold"]) * 3 and gear_t >= mini(5, S.tier_for_floor(f) + 1) \
					and bl["items"].size() >= 2
		var fl := S.boss_loot(f, _rng(f))
		if f == 100:
			var kinds := 0
			for it in fl["items"]:
				if _gear_tier(str(it["item"])) == 5:
					kinds += 1
			all_gear = kinds == 6
	check("baasbuit: gegarandeerd uitrusting + genees-items + goud, ids bestaan (alle baasverdiepingen)", boss_ok)
	check("baasbuit is beter dan een kist: >3x goud en uitrusting een niveau hoger", boss_better)
	check("eindbaas geeft van elke soort uitrusting niveau 5 en 5 elixers", all_gear
			and S.boss_loot(100, _rng(1))["items"].any(func(it): return it["item"] == "elixer" and int(it["n"]) >= 5))
	check("chest_loot(..., boss=true) = baasbuit", S.chest_loot(50, _rng(3), true)["boss"] == true and S.chest_loot(50, _rng(3), false)["boss"] == false)
	var inv := {"drankje": 2}
	var gold_back := S.grant_loot({"items": [{"item": "drankje", "n": 3}, {"item": "elixer", "n": 1}], "gold": 77}, inv)
	check("grant_loot legt voorwerpen in de tas en geeft het goud terug", inv["drankje"] == 5 and inv["elixer"] == 1 and gold_back == 77)
	var txt := S.loot_text({"items": [{"item": "drankje", "n": 2}, {"item": "d100_zwaard_2", "n": 1}], "gold": 120})
	check("loot_text in het Nederlands: '%s'" % txt, txt == "2x Potion, Archive Sword, 120 gold")
	var names_fit := true
	for id in GD.ITEMS:
		var pn: String = GD.ITEMS[id].get("short", GD.ITEMS[id]["name"])
		names_fit = names_fit and pn.length() <= 13
	check("itemnamen passen in de lijst (max 13 tekens)", names_fit)
	var scrolls := {}
	var scroll_n := 0
	for sd in 400:
		for it in S.chest_loot(15, _rng(910000 + sd))["items"]:
			var sid := str(it["item"])
			if (S.SPELL_SCROLLS as Array).has(sid):
				scrolls[sid] = true
				scroll_n += 1
	check("gewone kisten kunnen Fire-, Lightning- en Heal Scroll geven (%d rollen)" % scroll_n,
			scrolls.has("spreuk_vuur") and scrolls.has("spreuk_bliksem") and scrolls.has("spreuk_genees") and scroll_n > 0)
	var boss_clean := true
	for f in S.boss_floors():
		for sd in 20:
			for it in S.boss_loot(f, _rng(44000 + f * 20 + sd))["items"]:
				boss_clean = boss_clean and not (S.SPELL_SCROLLS as Array).has(str(it["item"]))
	check("baasbuit bevat geen spreukrol", boss_clean)


func _entry_tests() -> void:
	var m := S.monster_entry("mosslijm", 12, Vector2i(4, 5))
	check("monster_entry: id, enemy, tile en floor", m["enemy"] == "mosslijm" and m["tile"] == [4, 5] and m["floor"] == 12
			and str(m["id"]).begins_with("d100_12_"))
	var b := S.boss_entry(30, Vector2i(8, 8))
	check("boss_entry verdieping 30: boss=true, stil, baas-vijand, floor", b["boss"] == true and b["moves"] == false
			and b["enemy"] == "sporenzwam" and b["group"] == ["sporenzwam"] and b["floor"] == 30 and b["id"] == "d100_baas_30")
	check("boss_entry op een gewone verdieping = {}", S.boss_entry(31, Vector2i.ZERO).is_empty())
	var c := S.chest_entry(60, "k60_1", Vector2i(2, 3), _rng(5))
	check("chest_entry: loot, floor, item/n van het eerste voorwerp", c["floor"] == 60 and c["loot"]["items"].size() >= 1
			and c["item"] == c["loot"]["items"][0]["item"] and c["n"] == c["loot"]["items"][0]["n"] and c["tile"] == [2, 3])
	check("chest_entry(boss=true) is een baaskist", S.chest_entry(60, "k", Vector2i.ZERO, _rng(5), true)["loot"]["boss"] == true)


# ================================================================ deel B
func _chest_tests() -> void:
	GameState.new_game()
	GameState.dungeon100_floor = 0
	Dialog.close()
	var old := ChestScript.new()
	add_child(old)
	old.setup({"id": "oud", "tile": [1, 1], "item": "kruid", "n": 2})
	check("kist zonder verdieping: gewoon gedrag (floor 0, geen loot)", old.floor_nr == 0 and old.loot.is_empty() and old.item == "kruid" and old.count == 2)
	var gold0 := GameState.gold
	old.interact(null)
	check("gewone kist: 2x kruid erbij, geen goud", GameState.item_count("kruid") == 2 and GameState.gold == gold0 and old.last_result == "gekregen")
	Dialog.close()
	await get_tree().process_frame
	old.queue_free()

	GameState.new_game()
	GameState.dungeon100_floor = 80
	var fx := ChestScript.new()
	add_child(fx)
	fx.setup({"id": "d100_k80", "tile": [3, 3]})
	check("kist op verdieping 80 (zonder item): schaalbuit gerold, niveau 4", fx.floor_nr == 80 and not fx.loot.is_empty() and int(fx.loot["tier"]) == 4)
	var fx2 := ChestScript.new()
	add_child(fx2)
	fx2.setup({"id": "d100_k80", "tile": [3, 3]})
	check("zelfde kist-id + verdieping = zelfde buit (save/load-vast)", fx.loot == fx2.loot)
	var fx3 := ChestScript.new()
	add_child(fx3)
	fx3.setup({"id": "d100_k80", "tile": [3, 3], "floor": 20})
	check("eigen 'floor' in de kistdata wint van GameState (verdieping 20 = niveau 1)", fx3.floor_nr == 20 and int(fx3.loot["tier"]) == 1)
	var inv_before := GameState.inventory.duplicate()
	var g_before := GameState.gold
	fx.interact(null)
	var expected_gold: int = g_before + int(fx.loot["gold"])
	var got_all := true
	for it in fx.loot["items"]:
		var had := int(inv_before.get(it["item"], 0))
		got_all = got_all and GameState.item_count(it["item"]) == had + int(it["n"])
	check("kist openen: alle buit in de tas en goud erbij (+%d)" % int(fx.loot["gold"]), got_all and GameState.gold == expected_gold and fx.is_open())
	var last_line := str(Dialog._lines[-1])
	check("melding noemt de buit (of dat de kist leeg is)", Dialog.is_open and (("finds" in last_line
			and (int(fx.loot["gold"]) == 0 or "gold" in last_line)) or (S.loot_text(fx.loot) == "" and "empty" in last_line)))
	Dialog.close()
	await get_tree().process_frame
	var g_after := GameState.gold
	fx.interact(null)
	check("tweede keer: 'De kist is leeg.', niets erbij", GameState.gold == g_after and fx.last_result == "leeg")
	Dialog.close()
	var fixed := ChestScript.new()
	add_child(fixed)
	fixed.setup({"id": "vast", "tile": [4, 4], "item": "drankje", "n": 1})
	check("kist met vast item blijft vast, ook op een verdieping", fixed.loot.is_empty() and fixed.item == "drankje")
	var pre := ChestScript.new()
	add_child(pre)
	var entry := S.chest_entry(50, "k50", Vector2i(5, 5), _rng(8))
	pre.setup(entry)
	check("kist uit chest_entry gebruikt de vooraf gerolde buit", pre.loot == entry["loot"])
	for n in [fx, fx2, fx3, fixed, pre]:
		n.queue_free()
	GameState.dungeon100_floor = 0
	GameState.new_game()
	await get_tree().process_frame

	# map-monster: floor uit data of GameState, scaled_stats
	GameState.dungeon100_floor = 40
	var mm := MonsterScript.new()
	add_child(mm)
	mm.setup(null, {"id": "t", "enemy": "papiergeest", "tile": [2, 2]}, 1)
	check("MapMonster neemt GameState.dungeon100_floor over (40) en levert geschaalde stats",
			mm.floor_nr == 40 and mm.scaled_stats() == S.monster_stats(GD.ENEMIES["papiergeest"], 40))
	var mm2 := MonsterScript.new()
	add_child(mm2)
	check("boss_entry(100) is leeg: verdieping 100 is geen baas", S.boss_entry(100, Vector2i(3, 3)).is_empty())
	mm2.setup(null, S.boss_entry(99, Vector2i(3, 3)), 1)
	check("MapMonster uit boss_entry(99): De Stem, floor 99, baasstats", mm2.boss and mm2.floor_nr == 99
			and mm2.scaled_stats()["name"] == "De Stem"
			and int(mm2.scaled_stats()["max_hp"]) == int(S.boss_stats(GD.ENEMIES["papiergeest"], 99)["max_hp"]))
	GameState.dungeon100_floor = 0
	var mm3 := MonsterScript.new()
	add_child(mm3)
	mm3.setup(null, {"id": "t3", "enemy": "papiergeest", "tile": [2, 2]}, 1)
	check("MapMonster zonder verdieping: gewone stats", mm3.floor_nr == 0 and mm3.scaled_stats() == GD.ENEMIES["papiergeest"])
	for n in [mm, mm2, mm3]:
		n.queue_free()
	await get_tree().process_frame


func _make_battle(enemies: Array, floor_nr: int, boss: bool, tier := 0) -> Node:
	GameState.dungeon100_floor = floor_nr
	GameState.pending_enemies = enemies
	GameState.pending_boss = boss
	GameState.pending_tier = tier
	var b: Node = load(GameState.BATTLE_SCENE).instantiate()
	get_tree().root.add_child(b)
	return b


func _free_battle(b: Node) -> void:
	b.queue_free()
	GameState.pending_boss = false
	GameState.pending_tier = 0
	GameState.pending_enemies = []
	GameState.dungeon100_floor = 0


func _battle_tests() -> void:
	GameState.new_game()
	# verdieping 0, geen tier: oude waarden
	var b := _make_battle(["papiergeest", "mosslijm"], 0, false)
	await get_tree().process_frame
	var e0: Dictionary = b.enemies[0]["s"]
	check("gevecht verdieping 0: Paper Wraith HP/ATK/DEF/EXP/goud = game_data.gd", int(e0["max_hp"]) == 16 and int(e0["atk"]) == 9
			and int(e0["def"]) == 3 and int(e0["exp"]) == 5 and int(e0["gold"]) == 4 and int(e0["hp"]) == 16)
	_free_battle(b)
	await get_tree().process_frame
	# verdieping 0 + tier (oude kamerniveaus) blijft werken
	b = _make_battle(["mech_wachter"], 0, false, 2)
	await get_tree().process_frame
	var t2: Dictionary = GD.apply_tier(GD.ENEMIES["mech_wachter"], 2)
	check("gevecht verdieping 0 + tier 2: oude TIERS-schaal ongewijzigd (HP %d)" % int(b.enemies[0]["s"]["max_hp"]),
			int(b.enemies[0]["s"]["max_hp"]) == int(t2["max_hp"]) and int(b.enemies[0]["s"]["atk"]) == int(t2["atk"]))
	_free_battle(b)
	await get_tree().process_frame
	# verdieping 35: geschaald
	b = _make_battle(["papiergeest", "papiergeest"], 35, false, 3)
	await get_tree().process_frame
	var want := S.monster_stats(GD.ENEMIES["papiergeest"], 35)
	var e35: Dictionary = b.enemies[0]["s"]
	check("gevecht verdieping 35: stats = monster_stats (HP %d, ATK %d, DEF %d, EXP %d, goud %d), tier genegeerd"
			% [e35["max_hp"], e35["atk"], e35["def"], e35["exp"], e35["gold"]],
			int(e35["max_hp"]) == int(want["max_hp"]) and int(e35["atk"]) == int(want["atk"]) and int(e35["def"]) == int(want["def"])
			and int(e35["exp"]) == int(want["exp"]) and int(e35["gold"]) == int(want["gold"]) and int(e35["hp"]) == int(want["max_hp"])
			and int(b.enemies[1]["s"]["max_hp"]) == int(want["max_hp"]))
	check("verdieping 35: EXP en goud van het gevecht stijgen mee (victory_text)", int(e35["exp"]) > 5 * 5 and int(e35["gold"]) > 4 * 3)
	check("verdieping 35: vluchten blijft mogelijk (geen baas)", b.can_flee)
	_free_battle(b)
	await get_tree().process_frame
	# baas verdieping 30
	GameState.new_game()
	b = _make_battle(["sporenzwam"], 30, true)
	await get_tree().process_frame
	var bs: Dictionary = b.enemies[0]["s"]
	var bwant := S.boss_stats(GD.ENEMIES["sporenzwam"], 30)
	check("baasgevecht verdieping 30: Spore Lord met baasstats (HP %d, ATK %d), niet vluchten" % [bs["max_hp"], bs["atk"]],
			bs["name"] == "Spore Lord" and int(bs["max_hp"]) == int(bwant["max_hp"]) and int(bs["atk"]) == int(bwant["atk"])
			and not b.can_flee and int(bs["max_hp"]) > 5 * int(S.monster_stats(GD.ENEMIES["sporenzwam"], 30)["max_hp"]))
	var inv_before := GameState.inventory.duplicate()
	var gold_before := GameState.gold
	var page: String = b._dungeon100_boss_loot()
	var gained := false
	for id in GameState.inventory:
		if int(GameState.inventory[id]) > int(inv_before.get(id, 0)):
			gained = true
	check("baasbuit na de overwinning: voorwerpen + goud erbij, pagina 'Buit van de baas!' met gear", gained and GameState.gold > gold_before
			and page.begins_with("Boss loot!") and page.contains("\n") and page.contains("gold"))
	check("baasvlag 'dungeon100_boss:30' gezet", S.boss_defeated(30, GameState.story_flags))
	_free_battle(b)
	await get_tree().process_frame
	# eindbaas
	GameState.new_game()
	b = _make_battle(["kennis_beest"], 100, true)
	await get_tree().process_frame
	var fs: Dictionary = b.enemies[0]["s"]
	check("verdieping 100 is geen baasnaam; geforceerde formule houdt The Knowledge Beast, HP %d, geen kern" % int(fs["max_hp"]),
			fs["name"] == "The Knowledge Beast" and int(fs["max_hp"]) == int(S.boss_stats(GD.ENEMIES["kennis_beest"], 100)["max_hp"])
			and not b.enemies[0].has("core") and not b.can_flee)
	b._dungeon100_boss_loot()
	var sets := 0
	for kind in S.GEAR:
		if GameState.item_count(S.gear_id(kind, 5)) >= 1:
			sets += 1
	check("eindbaas-buit: alle 6 soorten niveau-5 uitrusting in de tas + 5 elixers", sets == 6 and GameState.item_count("elixer") >= 5)
	_free_battle(b)
	await get_tree().process_frame
	# baas verdieping 0: oude baas (Golem met kern) ongewijzigd
	GameState.new_game()
	b = _make_battle(["kennis_beest"], 0, true)
	await get_tree().process_frame
	var g: Dictionary = b.enemies[0]["s"]
	check("baasgevecht verdieping 0: Golem-baas ongewijzigd (HP 360, kern aanwezig), geen baasbuit",
			int(g["max_hp"]) == 360 and b.enemies[0].has("core") and b._dungeon100_boss_loot() == "")
	_free_battle(b)
	await get_tree().process_frame
	# gewoon gevecht in de dungeon: geen baasbuit
	GameState.new_game()
	b = _make_battle(["mosslijm"], 12, false)
	await get_tree().process_frame
	check("gewoon gevecht in de dungeon geeft geen baasbuit", b._dungeon100_boss_loot() == "" and GameState.story_flags.is_empty())
	_free_battle(b)
	await get_tree().process_frame
	GameState.new_game()
