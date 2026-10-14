extends Node
## ALLEEN VOOR TESTEN - v0.14 (RPG CODE) de Golem-baas met de ROZE KERN en de definitieve
## stats van de Golem en de Mechanische Wachter.
## Start:  godot --path . -- --golemtest [--shots=/pad/map]
##   Deel A: regels van de kern (boss_core.gd): open/dicht op schema, schade x0,4 / x2,
##           lading kapot of Hamerslag, berichten.
##   Deel B: data (definitieve stats, het gewone Kennis-Beest blijft gelijk).
##   Deel C: balans-simulatie (zelfde formules als battle.gd): Dennis SOLO tegen de Golem
##           (v0.15: Lv 8/10/12, Vonkzwaard, 3 Drankjes + 3 kruiden) en tegen de Mech. Wachter
##           (met 'Schild omhoog', per monsterniveau van Forge).
##   Deel D: echt baasgevecht in de Archieven met gesimuleerde toetsen: pantser, roze venster,
##           lading kapot, Hamerslag (verdedigd), en daarna winnen als een speler.
## Met --shots=map: golem_kern_dicht.png, golem_kern_open.png, golem_kern_raak.png,
## golem_hamerslag.png (768x432 = het fijne gevechtsraster) + _3x (1152x648 = 3x 384x216).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const BossCore := preload("res://scripts/battle/boss_core.gd")
const Equipment := preload("res://scripts/equipment.gd")
## v0.14: de Golem staat in de Golemhal (4D), bereikbaar via de bibliotheek.
const ROOM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
## cross-indexen (battle.COMMANDS)
const AANVAL := 0
const ITEM := 2
const VERDEDIG := 3

var failures := 0
var passes := 0
var shots := ""
var messages: Array = []        # alle berichten in de strook (deel D)
var enemy_hits: Array = []      # schade op de Golem (deel D)
var hero_hits: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	seed(1414)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: regels van de kern ===")
	_core_rule_tests()
	print("=== Deel B: data ===")
	_data_tests()
	print("=== Deel C: balans-simulatie ===")
	_balance_tests()
	print("=== Deel D: echt baasgevecht ===")
	await _battle_tests()
	print("GOLEMTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(30)
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A
func _boss_data() -> Dictionary:
	return BossCore.apply_boss(GD.ENEMIES["kennis_beest"])


func _core_rule_tests() -> void:
	var c := BossCore.new(_boss_data()["core"])
	check("kern start DICHT (pantser)", not c.open and is_equal_approx(c.damage_mult(), 0.4))
	var opened := []
	for r in range(1, 13):
		if c.start_round(r):
			opened.append(r)
			c.resolve()
	check("kern gaat open in ronde 3, 6, 9, 12 (elke 3e ronde): %s" % [opened], opened == [3, 6, 9, 12])
	c = BossCore.new(_boss_data()["core"])
	check("ronde 1 en 2: blijft dicht", not c.start_round(1) and not c.start_round(2) and not c.open)
	check("pantser: 18 schade -> 7 (x0,4)", c.scale_damage(18) == 7)
	check("pantser: 1 schade -> toch 1 (nooit 0)", c.scale_damage(1) == 1)
	check("pantser-schade telt niet voor het venster", c.dealt == 0)
	var seen := [false]
	c.changed.connect(func(o): seen[0] = o)
	check("ronde 3: kern gaat OPEN (signaal changed)", c.start_round(3) and c.open and seen[0])
	check("open kern: 30 schade -> 60 (x2)", c.scale_damage(30) == 60 and c.dealt == 60)
	check("60 >= 45: lading kapot", c.is_broken())
	check("einde ronde 3: 'break' (geen Hamerslag), kern weer dicht", c.resolve() == "break" and not c.open
			and c.broken_count == 1 and c.slam_count == 0 and not seen[0])
	c.start_round(6)
	c.scale_damage(20)      # 40 < 45
	check("ronde 6: te weinig schade (40 < 45) -> 'slam'", not c.is_broken() and c.resolve() == "slam" and c.slam_count == 1)
	c.start_round(9)
	c.close()
	check("close(): kern dicht zonder Hamerslag te tellen", not c.open and c.slam_count == 1)
	var d := BossCore.new()
	check("zonder data: standaardwaarden (3 / 0,4 / 2,0 / 20 / 2,2)", d.cycle == 3 and is_equal_approx(d.closed_mult, 0.4)
			and is_equal_approx(d.open_mult, 2.0) and d.break_damage == 20 and is_equal_approx(d.slam_power, 2.2))
	# berichten: Nederlands en kort genoeg voor de strook (max. ~60 tekens)
	var name: String = GD.ENEMIES["kennis_beest"]["name"]
	var texts := [BossCore.MSG_HINT, BossCore.MSG_OPEN % name, BossCore.MSG_WINDOW, BossCore.MSG_BREAK % name,
			BossCore.MSG_SLAM % [name, "Hammer Blow"], BossCore.MSG_CLOSE]
	check("berichten passen in de strook (%s)" % [texts.map(func(t): return t.length())],
			texts.all(func(t): return t.length() <= 60))
	check("telegraaf-bericht: 'De kern gloeit roze! The Knowledge Beast laadt op...'",
			BossCore.MSG_OPEN % name == "The core glows pink! The Knowledge Beast charges...")


# ================================================================ deel B
func _data_tests() -> void:
	var g := _boss_data()
	var want_g := {"max_hp": 360, "atk": 27, "def": 15, "agi": 6, "mag": 11, "mdef": 13, "exp": 210, "gold": 84}
	var ok := true
	for k in want_g:
		ok = ok and int(g.get(k, -1)) == int(want_g[k])
	check("Golem-baas voor Dax Lv 7 + Spark Sword: HP 360, ATK 27, DEF 15, SPD 6, MAG 11, MDEF 13, EXP 210, Goud 84", ok)
	check("First Archive mikt op level 7", GD.EERSTE_ARCHIEF_DOEL == 7)
	check("kern blijft: elke 3e ronde, x0,4 / x2, Hamerslag x2,2; drempel nu 45",
			int(g["core"]["cycle"]) == 3 and is_equal_approx(float(g["core"]["closed_mult"]), 0.4)
			and is_equal_approx(float(g["core"]["open_mult"]), 2.0) and is_equal_approx(float(g["core"]["slam_power"]), 2.2)
			and int(g["core"]["break_damage"]) == 45)
	check("Golem-baas: zwak vuur, bestand tegen bliksem, art v2 + runecirkel, geen 'boss'-sleutel meer",
			g["weak"] == ["vuur"] and g["resist"] == ["bliksem"] and str(g["sprite"]).ends_with("golem_boss_v2.png")
			and str(g["under"]).ends_with("golem_runecirkel.png") and not g.has("boss") and g.has("core"))
	var kb: Dictionary = GD.ENEMIES["kennis_beest"]
	check("gewoon Lore Beast (zwakke Golem-variant) blijft 46/14/7/6, 24 EXP",
			int(kb["max_hp"]) == 46 and int(kb["atk"]) == 14 and int(kb["def"]) == 7 and int(kb["agi"]) == 6 and int(kb["exp"]) == 24)
	check("Kustos: canon-zin in het bestiarium", str(kb["desc"]) == "A guardian without eyes, but with a thousand ears. It hears every thought that enters the Archive. The Old Humanity built it not to kill, but to preserve. Sapientia gave it a new purpose: whatever doesn't fit is removed.")
	var mw: Dictionary = GD.ENEMIES["mech_wachter"]
	var want_w := {"max_hp": 30, "atk": 12, "def": 8, "agi": 5, "mag": 0, "mdef": 4, "exp": 10, "gold": 8}
	ok = true
	for k in want_w:
		ok = ok and int(mw.get(k, -1)) == int(want_w[k])
	check("Mech. Warden basis (niveau 1) blijft: HP 30, ATK 12, DEF 8, SPD 5, MAG 0, MDEF 4, EXP 10, Goud 8, zwak bliksem",
			ok and mw["weak"] == ["bliksem"])
	var guard: Array = mw["skills"].filter(func(sk): return str(sk.get("type", "")) == "guard")
	check("Mech. Warden: trucje 'Shield Up' (20%, DEF x2) + Seal Strike", guard.size() == 1
			and str(guard[0]["name"]) == "Shield Up" and is_equal_approx(float(guard[0]["chance"]), 0.2)
			and is_equal_approx(float(guard[0]["def_mult"]), 2.0)
			and mw["skills"].any(func(sk): return str(sk["name"]) == "Seal Strike"))
	check("Mech. Warden blijft tussen de kleine vijanden en het Lore Beast (dungeontest)",
			["mosslijm", "moskonijn", "papiergeest", "glitchmot"].all(func(e): return int(GD.ENEMIES[e]["max_hp"]) < int(mw["max_hp"]))
			and int(mw["max_hp"]) < int(kb["max_hp"]) and int(mw["atk"]) < int(kb["atk"]))
	var az: Dictionary = GD.EQUIPMENT["vonkzwaard"]
	check("Spark Sword: wapen voor krijgers, ATK +12 (keuze Dax; Short Sword +%d)" % int(GD.EQUIPMENT["kort_zwaard"]["atk"]),
			az["slot"] == "wapen" and az["wie"] == ["krijger"] and int(az["atk"]) == 12)
	check("Golem in de Golem Hall (4D) = baasgevecht met kennis_beest, geen andere monsters daar",
			DR.ROOMS["archief_golemhal"]["monsters"].size() == 1 and DR.ROOMS["archief_golemhal"]["monsters"].any(func(m): return m["id"] == "golem" and m["enemy"] == "kennis_beest" and m.get("boss", false)))
	# v0.14 (Forge): EXP bij de Golem = oefengevecht (Mosslijm) + elk map-monster in de 4 verdiepingen
	# (34 gevechten, hele groep, met het monsterniveau van de kamer) één keer.
	var exp_total := int(GD.ENEMIES["mosslijm"]["exp"])
	var fights := 0
	for rid in DR.ROOMS:
		for m in DR.ROOMS[rid]["monsters"]:
			if not m.get("boss", false):
				fights += 1
				for e in m.get("group", [m["enemy"]]):
					exp_total += int(GD.apply_archief_tier(GD.ENEMIES[e], int(DR.ROOMS[rid].get("tier", 0)))["exp"])
	var lv := 1
	while GD.exp_for_level(lv + 1) <= exp_total:
		lv += 1
	print("INFO  EXP voor de Golem (oefengevecht + 34 gevechten met tiers): %d -> Lv %d" % [exp_total, lv])
	check("34 gevechten; Dax is bij de Golem Lv 7 (%d EXP, Lv %d)" % [exp_total, lv],
			fights == 34 and lv == GD.EERSTE_ARCHIEF_DOEL)


# ================================================================ deel C
## Dennis op level L zoals GameState hem maakt (give_exp -> groei per level) + wapen.
func _dennis(level: int, weapon := "vonkzwaard") -> Dictionary:
	GameState.new_game("Dax")
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(level))
	if weapon != "":
		GameState.equip_weapon(GameState.MAIN_HERO, weapon)
	return h.duplicate(true)


## Zelfde formule als battle.gd _physical_damage: ATK x mult - DEF/2, +/-15%, min 1, verdedigen = helft.
static func phys(atk: float, mult: float, def: float, defending: bool) -> int:
	var dmg := maxi(1, roundi((atk * mult - def / 2.0) * randf_range(0.85, 1.15)))
	if defending:
		dmg = maxi(1, int(dmg / 2.0))
	return dmg


## Eén gevecht. policy: "slim" (kern aanvallen, genezen onder 40%), "domweg" (altijd aanvallen,
## nooit genezen), "nooit_kern" (in het roze venster verdedigen i.p.v. aanvallen).
## items = lijst met genees-waarden (drankje 30, kruid 25). Geeft [gewonnen, rondes, items gebruikt].
func _sim(hero: Dictionary, boss: Dictionary, policy: String, items: Array) -> Array:
	var core := BossCore.new(boss["core"])
	var hp := int(hero["max_hp"])
	var ghp := int(boss["max_hp"])
	var bag := items.duplicate()
	var used := 0
	for rnd in range(1, 120):
		core.start_round(rnd)
		var act := "attack"
		var big_hit := float(boss["atk"]) * 1.5 - float(hero["def"]) / 2.0
		if policy == "nooit_kern" and core.open:
			act = "defend"
		elif policy != "domweg" and not core.open and (hp <= big_hit * 1.15 or hp < 0.4 * int(hero["max_hp"])) and not bag.is_empty():
			act = "heal"
		var hero_first := core.open or float(hero["agi"]) + randf() * 3.0 > float(boss["agi"]) + randf() * 3.0
		for turn in 2:
			var heroes_turn := (turn == 0) == hero_first
			if heroes_turn:
				match act:
					"attack":
						ghp -= core.scale_damage(phys(float(hero["atk"]), 1.0, float(boss["def"]), false))
					"heal":
						hp = mini(int(hero["max_hp"]), hp + int(bag.pop_front()))
						used += 1
			else:
				if core.open:
					if core.resolve() == "slam":
						hp -= phys(float(boss["atk"]), core.slam_power, float(hero["def"]), act == "defend")
				else:
					var mult := 1.0
					for sk in boss["skills"]:
						if randf() < float(sk["chance"]):
							mult = float(sk["power"])
							break
					hp -= phys(float(boss["atk"]), mult, float(hero["def"]), act == "defend")
			if ghp <= 0:
				return [true, rnd, used]
			if hp <= 0:
				return [false, rnd, used]
		core.close()
	return [false, 120, used]


func _rate(level: int, policy: String, n: int, items: Array) -> Dictionary:
	var hero := _dennis(level)
	var boss := _boss_data()
	var wins := 0
	var rounds := 0
	var used := 0
	for i in n:
		var r := _sim(hero, boss, policy, items)
		rounds += int(r[1])
		if r[0]:
			wins += 1
			used += int(r[2])
	return {"win": float(wins) / n, "rounds": float(rounds) / n, "items": float(used) / maxi(1, wins)}


## Voorraad bij de Golem (zelfde aanname als Forge): 3 Drankjes (30 HP) + 3 kruiden (25 HP).
const BOSS_BAG := [30, 30, 30, 25, 25, 25]
## Monsterniveaus van Forge (ARCHIEF1_PLATTEGROND.md §6): HP x, ATK +, DEF +, EXP x.


func _balance_tests() -> void:
	seed(2026)
	# Dennis Lv 7 zoals het spel hem maakt
	var d7 := _dennis(7)
	print("INFO  Dax Lv 7 (+Spark Sword): HP %d, ATK %d, DEF %d, SPD %d (EXP %d)"
			% [d7["max_hp"], d7["atk"], d7["def"], d7["agi"], GD.exp_for_level(7)])
	check("Dax Lv 7 met Spark Sword: HP 96, ATK 44 (32+12), DEF 20, SPD 15",
			int(d7["max_hp"]) == 96 and int(d7["atk"]) == 44 and int(d7["def"]) == 20 and int(d7["agi"]) == 15
			and int(d7["level"]) == 7)
	var boss := _boss_data()
	var min_open := roundi(roundi((float(d7["atk"]) - float(boss["def"]) / 2.0) * 0.85) * 2.0)
	check("drempel 45: elke klap van Dax Lv 7 op de open kern haalt hem (min. %d)" % min_open, min_open >= 45)
	var weak_open := roundi((25.0 - float(boss["def"]) / 2.0) * 1.15 * 2.0)
	check("drempel 45: een zwakke klap (ATK 25, bv. later Vesper) haalt hem NIET (max. %d)" % weak_open, weak_open < 45)
	var n := 1500
	var res := {}
	for L in [5, 7, 9]:
		for pol in ["slim", "domweg", "nooit_kern"]:
			var r := _rate(L, pol, n, BOSS_BAG)
			res["%d_%s" % [L, pol]] = r
			print("INFO  Lv %d %-10s winst %5.1f%%  rondes %4.1f  items %3.1f" % [L, pol, r["win"] * 100.0, r["rounds"], r["items"]])
	check("Lv 7 (doel), slim spelen: wint >= 97%% (%.1f%%)" % (res["7_slim"]["win"] * 100.0), res["7_slim"]["win"] >= 0.97)
	check("Lv 7: kost meerdere items (gem. %.1f, >= 3)" % res["7_slim"]["items"], res["7_slim"]["items"] >= 3.0)
	check("Lv 7: gevecht <= 20 rondes (%.1f)" % res["7_slim"]["rounds"], res["7_slim"]["rounds"] <= 20.0)
	check("Lv 5: zwaar maar te doen, slim 40-90%% (%.1f%%)" % (res["5_slim"]["win"] * 100.0),
			res["5_slim"]["win"] >= 0.4 and res["5_slim"]["win"] <= 0.9)
	check("Lv 9: wint >= 99%% (%.1f%%)" % (res["9_slim"]["win"] * 100.0), res["9_slim"]["win"] >= 0.99)
	check("Lv 7: domweg aanvallen zonder genezen verliest meestal (%.1f%% < 10%%)" % (res["7_domweg"]["win"] * 100.0),
			res["7_domweg"]["win"] < 0.1)
	check("de kern negeren verliest altijd (Lv 5/7/9: %.1f / %.1f / %.1f%%)" % [res["5_nooit_kern"]["win"] * 100.0,
			res["7_nooit_kern"]["win"] * 100.0, res["9_nooit_kern"]["win"] * 100.0],
			res["5_nooit_kern"]["win"] == 0.0 and res["7_nooit_kern"]["win"] == 0.0 and res["9_nooit_kern"]["win"] == 0.0)
	# Info: met de kisten van Forge's plattegrond (Kaftschild DEF+3, Leren Kap DEF+1)
	for L in [5, 7]:
		var hg := _dennis(L)
		for arm in ["kaftschild", "leren_kap"]:
			GameState.inventory[arm] = 1
			Equipment.give_and_equip(GameState.party[0], GameState.inventory, arm)
		hg = GameState.party[0].duplicate(true)
		var wins := 0
		var used := 0
		for i in n:
			var r := _sim(hg, _boss_data(), "slim", BOSS_BAG)
			if r[0]:
				wins += 1
				used += int(r[2])
		print("INFO  Lv %d + Cover Shield + Leather Hood (DEF %d): slim winst %.1f%%, items %.1f" % [L, hg["def"], wins * 100.0 / n, float(used) / maxi(1, wins)])
		var dwins := 0
		for i in n:
			if _sim(hg, _boss_data(), "domweg", BOSS_BAG)[0]:
				dwins += 1
		print("INFO  Lv %d + Cover Shield + Leather Hood: domweg winst %.1f%%" % [L, dwins * 100.0 / n])
		if L == 7:
			check("Lv 7 met schild en kap: domweg aanvallen verliest nog steeds meestal (%.1f%% < 10%%)" % (dwins * 100.0 / n),
					dwins < n / 10)
	# Mech. Wachter (met Schild omhoog) per monsterniveau, Dennis op het level van die verdieping
	var w: Dictionary = GD.ENEMIES["mech_wachter"]
	var wres := {}
	for row in [[1, 2, "kort_zwaard"], [2, 4, "kort_zwaard"], [3, 7, "kort_zwaard"], [4, 9, "vonkzwaard"], [4, 8, "vonkzwaard"]]:
		var tw := _tier(w, int(row[0]))
		var h := _dennis(int(row[1]), str(row[2]))
		var wins := 0
		var lost := 0
		var rounds := 0
		for i in 1000:
			var r := _sim_wachter(h, tw)
			if r[0]:
				wins += 1
			lost += int(r[1])
			rounds += int(r[2])
		var pct := float(lost) / 1000.0 / float(h["max_hp"]) * 100.0
		wres["%d_%d" % [row[0], row[1]]] = {"wins": wins, "pct": pct}
		print("INFO  Warden niveau %d (HP %d ATK %d DEF %d EXP %d) vs Dax Lv %d (%s): winst %.1f%%, %.1f rondes, %.0f%% HP kwijt"
				% [row[0], tw["max_hp"], tw["atk"], tw["def"], tw["exp"], row[1], row[2], wins / 10.0, rounds / 1000.0, pct])
	check("Mech. Warden niveau 2 vs Dax Lv 4: wint altijd zonder items (%.0f%% HP kwijt)" % wres["2_4"]["pct"], wres["2_4"]["wins"] == 1000)
	check("Mech. Warden niveau 4 vs Dax Lv 8 (+Spark Sword): wint altijd, maar kost HP (3-50%%: %.0f%%)" % wres["4_8"]["pct"],
			wres["4_8"]["wins"] == 1000 and wres["4_8"]["pct"] >= 3.0 and wres["4_8"]["pct"] <= 50.0)
	# EXP-curve (advies voor Forge)
	var line := []
	for L in range(2, 11):
		line.append("Lv%d=%d" % [L, GD.exp_for_level(L)])
	print("INFO  EXP-curve: " + ", ".join(line))
	GameState.new_game("Dax")


## Vijand op monsterniveau t in het Eerste Archief (doel-level 7).
static func _tier(e: Dictionary, t: int) -> Dictionary:
	return GD.apply_archief_tier(e, t)


## Dennis tegen één Mech. Wachter (zelfde regels als battle.gd, met Schild omhoog).
## Geeft [gewonnen, HP kwijt, rondes].
func _sim_wachter(h: Dictionary, w: Dictionary) -> Array:
	var hp := int(h["max_hp"])
	var whp := int(w["max_hp"])
	var guard := 0
	var lost := 0
	var r := 0
	while hp > 0 and whp > 0 and r < 50:
		r += 1
		var hero_first := float(h["agi"]) + randf() * 3.0 > float(w["agi"]) + randf() * 3.0
		for turn in 2:
			if (turn == 0) == hero_first:
				whp -= phys(float(h["atk"]), 1.0, float(w["def"]) * (2.0 if guard > 0 else 1.0), false)
			else:
				var mult := 1.0
				var guarded := false
				for sk in w["skills"]:
					if randf() < float(sk["chance"]):
						if str(sk.get("type", "")) == "guard":
							if guard > 0:
								continue
							guard = 2
							guarded = true
							break
						mult = float(sk["power"])
						break
				if not guarded:
					var d := phys(float(w["atk"]), mult, float(h["def"]), false)
					hp -= d
					lost += d
			if whp <= 0 or hp <= 0:
				break
		guard = maxi(0, guard - 1)
	return [whp <= 0, lost, r]


# ================================================================ deel D
func scene() -> Node:
	return get_tree().current_scene


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


func wait_battle_state(states: Array, timeout := 30.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var b := battle()
		if b == null and Time.get_ticks_msec() - t0 > 500 and not GameState.in_battle:
			return ""
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
	return ""


func cross_to(b: Node, index: int) -> void:
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	for k in 3:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])


## Kies een commando voor Dennis (in 'command') en bevestig doel/item. Wacht tot de ronde
## voorbij is (weer 'command') of het gevecht klaar is ("" / message_wait van de winst).
func do_round(b: Node, cmd: int) -> String:
	if await wait_battle_state(["command"]) != "command":
		return ""
	await cross_to(b, cmd)
	await tap("interact")
	if cmd == AANVAL:
		if await wait_battle_state(["target_enemy", "busy"], 5) == "target_enemy":
			await tap("interact")
	elif cmd == ITEM:
		await pframes(3)
		await tap("interact")                          # eerste item (Drankje)
		if await wait_battle_state(["target_ally"], 5) == "target_ally":
			await tap("interact")
	await wait_battle_state(["busy", "message_wait"], 5)
	return await wait_battle_state(["command", "message_wait"], 40)


func _watch(b: Node) -> void:
	var last := ""
	while is_instance_valid(b):
		var t: String = b.message_label.text
		if t != last:
			last = t
			messages.append(t)
		await get_tree().process_frame


func seen_message(part: String) -> bool:
	return messages.any(func(m): return part in m)


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	var path := shots.path_join(name + ".png")
	img.save_png(path)                                         # fijn raster (768x432)
	var big := img.duplicate()
	big.resize(img.get_width() * 3 / 2, img.get_height() * 3 / 2, Image.INTERPOLATE_NEAREST)
	big.save_png(shots.path_join(name + "_3x.png"))            # 1152x648 = 3x 384x216
	print("INFO  screenshot: ", path, " ", img.get_size(), " + _3x ", big.get_size())


func _start_boss(level: int) -> Node:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(level))
	GameState.equip_weapon(GameState.MAIN_HERO, "vonkzwaard")
	GameState.inventory["drankje"] = 6      # ~ 3 Drankjes + 3 kruiden (de bot gebruikt alleen Drankjes)
	h["hp"] = h["max_hp"]
	GameState.change_map(ROOM_SCENE, "zuid")
	if not await wait_scene("ArchiefGolemhal"):
		return null
	await pframes(10)
	var p: Node = scene().get_node("Objects/Player")
	GameState.start_battle(["kennis_beest"], p.get_tile(), p.facing, "archief", true)
	if not await wait_scene("Battle"):
		return null
	var b := battle()
	messages.clear()
	enemy_hits.clear()
	hero_hits.clear()
	_watch(b)
	b.damage_shown.connect(func(who: String, amount: int):
		if who == GameState.party[0]["name"]:
			hero_hits.append(amount)
		else:
			enemy_hits.append(amount))
	return b


func _battle_tests() -> void:
	Engine.time_scale = 2.0
	var b := await _start_boss(10)
	check("baasgevecht gestart (Archives, baas)", b != null and GameState.pending_boss)
	if b == null:
		return
	var g: Dictionary = b.enemies[0]
	var core = g.get("core")
	var view: Control = g["node"].get_node_or_null("BossCore")
	var bd := _boss_data()
	check("Golem: baas-stats in het gevecht (HP %d, ATK %d, DEF %d; Dax Lv %d ATK %d)"
			% [g["s"]["max_hp"], g["s"]["atk"], g["s"]["def"], GameState.party[0]["level"], GameState.party[0]["atk"]], int(g["s"]["max_hp"]) == int(bd["max_hp"])
			and int(g["s"]["hp"]) == int(bd["max_hp"]) and int(g["s"]["atk"]) == int(bd["atk"]) and int(g["s"]["def"]) == int(bd["def"])
			and int(GameState.party[0]["level"]) == 10)
	check("v0.15: niet vluchten voor de baas (can_flee uit)", not b.can_flee)
	check("Golem: kern + beeld aanwezig (pantserplaten, dicht)", core != null and view != null and not core.open and view.plates_shown())
	var k: float = g["node"].size.x / 196.0
	check("pantser ligt precies op de kern (82,52 30x30 in het plaatje)", view.position.is_equal_approx(Vector2(82, 52) * k)
			and view.size.is_equal_approx(Vector2(30, 30) * k) and view.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	check("ronde 1: wacht op het commando", await wait_battle_state(["command"]) == "command")
	check("uitleg bij de start: '%s'" % BossCore.MSG_HINT, seen_message("pink light"))
	var hero: Dictionary = GameState.party[0]
	var atk := float(hero["atk"])
	await pframes(20)
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.4).timeout
	await screenshot("golem_kern_dicht")
	Engine.time_scale = 2.0
	# --- ronde 1: aanvallen op het pantser
	await do_round(b, AANVAL)
	var base := atk - float(bd["def"]) / 2.0
	var max_closed := maxi(1, roundi(roundi(base * 1.15) * 0.4))
	check("ronde 1: pantser, schade x0,4 (%s, max %d)" % [enemy_hits, max_closed], enemy_hits.size() == 1
			and enemy_hits[0] >= 1 and enemy_hits[0] <= max_closed)
	check("ronde 1: kern bleef dicht, Golem viel gewoon aan", not core.open and hero_hits.size() >= 1)
	# --- ronde 2: verdedigen
	check("ronde 2: nog steeds dicht", await wait_battle_state(["command"]) == "command" and b.round_no == 2 and not core.open)
	await do_round(b, VERDEDIG)
	# --- ronde 3: kern open -> aanvallen = lading kapot
	check("ronde 3: 'De kern gloeit roze!' (telegraaf)", await wait_battle_state(["command"]) == "command" and b.round_no == 3
			and seen_message("The core glows pink!") and core.open)
	await get_tree().create_timer(0.5).timeout
	var idle: Timer = g["node"].get_node_or_null("Idle")
	check("ronde 3: tijdens het kiezen roze strook '%s'" % b.message_label.text, b.caption.visible
			and b.message_label.text == BossCore.MSG_WINDOW)
	check("ronde 3: platen weg, roze gloed, kern pulseert sneller (%.2f s/frame)" % (idle.wait_time if idle else -1.0),
			view.is_open_shown() and idle != null and is_equal_approx(idle.wait_time, 0.15))
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.3).timeout
	await screenshot("golem_kern_open")
	Engine.time_scale = 2.0
	var hits_before := enemy_hits.size()
	var hero_before := hero_hits.size()
	var hp_before := int(hero["hp"])
	await cross_to(b, AANVAL)
	await tap("interact")
	if await wait_battle_state(["target_enemy", "busy"], 5) == "target_enemy":
		await tap("interact")
	await get_tree().create_timer(0.6).timeout
	if shots != "":
		Engine.time_scale = 1.0
		await screenshot("golem_kern_raak")
		Engine.time_scale = 2.0
	await wait_battle_state(["command", "message_wait"], 40)
	var min_open := roundi(roundi(base * 0.85) * 2.0) - 2
	check("ronde 3: open kern, schade x2 (%s, min ~%d) >= drempel %d" % [enemy_hits.slice(hits_before), min_open, core.break_damage],
			enemy_hits.size() == hits_before + 1 and enemy_hits[hits_before] >= min_open and enemy_hits[hits_before] >= core.break_damage)
	check("ronde 3: 'Hit! The charge bursts.' en geen schade voor Dax", seen_message("The charge bursts")
			and hero_hits.size() == hero_before and int(hero["hp"]) == hp_before)
	check("daarna: 'The core seals shut.', platen terug", seen_message("The core seals shut") and not core.open
			and core.broken_count == 1)
	await get_tree().create_timer(0.5).timeout
	check("kern dicht: tijdens het kiezen weer geen strook (zoals v0.13)", await wait_battle_state(["command"]) == "command"
			and not b.caption.visible and b.message_label.text.begins_with("What will"))
	check("platen weer dicht in beeld, idle weer normaal", view.plates_shown() and is_equal_approx(idle.wait_time, 0.4))
	# --- ronde 4, 5: verdedigen; ronde 6: verdedigen in het open venster -> Hamerslag (gehalveerd)
	await do_round(b, VERDEDIG)
	await do_round(b, VERDEDIG)
	check("ronde 6: kern weer open", await wait_battle_state(["command"]) == "command" and core.open and core.opened_count == 2)
	hero["hp"] = hero["max_hp"]
	b._refresh_party()
	hero_before = hero_hits.size()
	await cross_to(b, VERDEDIG)
	await tap("interact")
	# screenshot zodra de Hamerslag-tekst er staat
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and not seen_message("Hammer Blow"):
		await get_tree().process_frame
	if shots != "":
		Engine.time_scale = 1.0
		await get_tree().create_timer(0.45).timeout
		await screenshot("golem_hamerslag")
		Engine.time_scale = 2.0
	await wait_battle_state(["command", "message_wait"], 40)
	var max_slam := ceili(maxf(1.0, (float(bd["atk"]) * float(bd["core"]["slam_power"]) - float(hero["def"]) / 2.0) * 1.15) / 2.0) + 1
	check("ronde 6: niet geraakt -> 'The Knowledge Beast: Hammer Blow!'", seen_message("Hammer Blow!") and core.slam_count == 1)
	check("Hamerslag verdedigd = halve schade (%s, max %d)" % [hero_hits.slice(hero_before), max_slam],
			hero_hits.size() == hero_before + 1 and hero_hits[hero_before] <= max_slam and hero_hits[hero_before] >= 5)
	# --- uitspelen als een speler: kern open = aanvallen, weinig HP = Drankje, anders aanvallen
	var exp_before := int(hero["exp"])
	var drank_before := GameState.item_count("drankje")
	var won := false
	for guard in 150:
		var st := await wait_battle_state(["command", "message_wait"], 40)
		if st == "":
			break
		if st == "message_wait":
			if b.victory_panel.visible:
				won = true
			await tap("interact")
			continue
		var low: bool = int(hero["hp"]) < int(hero["max_hp"]) * 0.4
		if not core.open and low and GameState.item_count("drankje") > 0:
			await do_round(b, ITEM)
		else:
			await do_round(b, AANVAL)
	check("gewonnen (overwinningsvenster gezien, %d drankjes gebruikt, %d keer kapot, %d Hamerslagen)"
			% [drank_before - GameState.item_count("drankje"), core.broken_count, core.slam_count], won)
	check("terug in de Golem Hall, EXP +%d" % int(bd["exp"]), await wait_scene("ArchiefGolemhal") and GameState.last_battle_result == "win"
			and int(GameState.party[0]["exp"]) == exp_before + int(bd["exp"]))
	check("Golem in het bestiarium als verslagen", GameState.defeated_count("kennis_beest") >= 1)
	Engine.time_scale = 1.0
