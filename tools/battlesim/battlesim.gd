extends Node
## Headless gevechtssimulator: duizenden gevechten per gebied met de ECHTE vijanden, items,
## spreuken en gevechtscode (scenes/battle/battle.tscn + battle.gd, alleen het menu/wachten
## vervangen door tools/battlesim/sim_battle.gd). Geen gameplay-wijziging.
##
## Starten (zie docs/BATTLE_BALANCE_REPORT.md):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --battlesim [--seed=N] [--fights=N]
##            [--only=id1,id2] [--out=pad.md] [--json=pad.json]
## Standaard: seed 20261020, 2000 gevechten per gebied, rapport naar docs/BATTLE_BALANCE_REPORT.md.
## Dezelfde seed + dezelfde code = exact dezelfde getallen.

const GameData := preload("res://scripts/data/game_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const WoudRooms := preload("res://scripts/data/woud_rooms.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const Archief2Rooms := preload("res://scripts/data/archief2_rooms.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const Dungeon100Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Equipment := preload("res://scripts/equipment.gd")
## Pas bij het draaien geladen (niet als preload: dit script wordt al tijdens GameState._ready gemaakt)
const SIM_BATTLE_PATH := "res://tools/battlesim/sim_battle.gd"
const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
var SimBattle: Script
var BATTLE_SCENE: PackedScene

const DEFAULT_SEED := 20261020
const STUN_ELEMENTS := ["bliksem", "ijs"]
const DEFAULT_FIGHTS := 2000
const D100_LAYOUTS := 6            # zoveel run-seeds per sample-verdieping (verschillende monstergroepen)
const D100_SAMPLE_FLOORS := [1, 5, 15, 35, 45, 65, 85, 95]

## Outlier-drempels per encounter-groep (zie rapport)
const HARD_WIN := 0.80             # winkans onder 80%: "bijna onmogelijk/te zwaar" (< 50%: bijna onmogelijk)
const EASY_LOSS := 0.05            # gem. HP-verlies onder 5% en <= 2 rondes en 100% winst: "triviaal"

var base_seed := DEFAULT_SEED
var fights := DEFAULT_FIGHTS
var only: Array = []
var out_path := "res://docs/BATTLE_BALANCE_REPORT.md"
var json_path := ""
var trace := false                 # --trace: elk gevechtsbericht printen (met --fights=1)
var standalone := true             # false = aangeroepen door de autotest (geen quit, geen bestand)
var results: Array = []            # per gebied een Dictionary (zie _summarize)
var holder: Node


func _ready() -> void:
	if not standalone:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			base_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--fights="):
			fights = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--only="):
			only = Array(arg.get_slice("=", 1).split(",", false))
		elif arg.begins_with("--out="):
			out_path = arg.get_slice("=", 1)
		elif arg == "--trace":
			trace = true
		elif arg.begins_with("--json="):
			json_path = arg.get_slice("=", 1)
	_main.call_deferred()


func _main() -> void:
	var t0 := Time.get_ticks_msec()
	print("BATTLESIM start: seed %d, %d fights per area" % [base_seed, fights])
	await run_all()
	var md := report_markdown(Time.get_ticks_msec() - t0)
	_write(out_path, md)
	if json_path != "":
		_write(json_path, JSON.stringify(results, "  "))
	print("BATTLESIM written: %s (%d areas, %d fights each, seed %d, %.1fs)" % [
			out_path, results.size(), fights, base_seed, (Time.get_ticks_msec() - t0) / 1000.0])
	print("RESULT OK (battlesim)")
	get_tree().quit(0)


func _write(path: String, text: String) -> void:
	var p := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		push_error("battlesim: kan %s niet schrijven" % p)
		return
	f.store_string(text)
	f.close()


# =============================================================== scenario's
## Elk scenario: id, name, party (Callable die GameState.party/inventory bouwt), encounters
## (lijst {"enemies", "weight", "boss", "tier", "archief", "floor", "filter", "label"}), notes.
func scenarios() -> Array:
	var out: Array = []
	var starter := ["kort_zwaard", "houten_schild", "leren_kap", "leerling_mantel"]
	var a1_mid := ["kort_zwaard", "houten_schild", "leren_kap", "leren_harnas"]
	var a1_late := ["vonkzwaard", "kaftschild", "leren_kap", "leren_harnas"]
	var woud_gear := ["vonkzwaard", "kaftschild", "ijzeren_helm", "leren_harnas"]
	var noor_gear := ["eiken_staf", "reisgewaad"]
	var noor_gear2 := ["eiken_staf", "wambuis", "leren_kap"]
	var forge_dax := ["ketelkling", "ketelschild", "ketelhelm", "schrootplaat"]
	var forge_noor := ["eiken_staf", "werkmantel", "leren_kap"]
	var forge_lotte := ["stemvork", "reisgewaad", "leren_kap"]
	var inv_early := {"drankje": 3, "toverwater": 1, "kruid": 2}
	var inv_mid := {"drankje": 5, "toverwater": 2, "kruid": 2}
	var inv_act2 := {"drankje": 6, "toverwater": 3, "kruid": 3}

	out.append({"id": "wereldkaart1", "name": "Worldmap 1 (grass, random encounters)",
		"party": [["dennis", 3, starter]], "inv": inv_early,
		"encounters": _terrain_groups("gras"),
		"notes": "Random-encounter pool for terrain 'gras' (GameData.ENCOUNTER_GROUPS + weights). Dax solo, Lv 3."})
	var a1_lv := {1: 3, 2: 5, 3: 6, 4: 7}
	for fl in [1, 2, 3, 4]:
		var gear: Array = starter if fl == 1 else (a1_mid if fl == 2 else a1_late)
		out.append({"id": "archief1_v%d" % fl, "name": "First Archive floor %d" % fl,
			"party": [["dennis", a1_lv[fl], gear]], "inv": inv_early if fl <= 2 else inv_mid,
			"encounters": _room_groups(DungeonRooms.ROOMS, fl, true, false),
			"notes": "Map monsters of every floor-%d room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7)." % fl})
	out.append({"id": "golem", "name": "BOSS Golem (First Archive)",
		"party": [["dennis", 8, a1_late]], "inv": inv_mid,
		"encounters": _room_groups(DungeonRooms.ROOMS, -1, true, true),
		"notes": "Golem Hall boss (kennis_beest + pink core). Dax Lv 8 with Spark Sword."})
	out.append({"id": "woud", "name": "Dark Wood",
		"party": [["dennis", 11, woud_gear]], "inv": inv_mid, "kern": true,
		"encounters": _room_groups(WoudRooms.ROOMS, -1, false, false),
		"notes": "All Dark Wood map monsters, room tier 3 (no archief scaling). Dax solo Lv 11 + Golem Core (Core Strike)."})
	out.append({"id": "wortelkoning", "name": "BOSS Root King (Dark Wood)",
		"party": [["dennis", 12, woud_gear]], "inv": inv_mid, "kern": true,
		"encounters": _room_groups(WoudRooms.ROOMS, -1, false, true),
		"notes": "Root King, Dax solo Lv 12 (Vesper joins after this fight)."})
	out.append({"id": "berggrot", "name": "Mountain Cave (Berggrot)",
		"party": [["dennis", 13, woud_gear], ["noor", 12, noor_gear2]], "inv": inv_mid, "kern": true,
		"encounters": _room_groups(BerggrotData.ROOMS, -1, false, false),
		"notes": "Berggrot map monsters (tier 0). Dax Lv 13 + Vesper Lv 12 (joined at Dax-1)."})
	var a2 := Archief2Rooms.rooms()
	for fl in [1, 2]:
		out.append({"id": "archief2_v%d" % fl, "name": "Second Archive floor %d" % fl,
			"party": [["dennis", 14, woud_gear], ["noor", 13, noor_gear2]], "inv": inv_act2, "kern": true,
			"encounters": _room_groups(a2, fl, true, false),
			"notes": "Archief 2 map monsters floor %d (tier from room, archief scaling). Dax Lv 14 + Vesper Lv 13." % fl})
	out.append({"id": "lotte", "name": "STORY Seren/Lotte (Second Archive, Dax alone)",
		"party": [["dennis", 15, woud_gear], ["noor", 14, noor_gear2]], "inv": inv_act2, "kern": true,
		"filter": "dennis",
		"encounters": _room_groups(a2, 2, true, true),
		"notes": "Story fight: only Dax fights (archief2_party_filter = dennis), no Codex ally. Win or lose both continue the story."})
	for fl in [3, 4]:
		out.append({"id": "archief2_v%d" % fl, "name": "Second Archive floor %d" % fl,
			"party": [["dennis", 16, forge_dax], ["noor", 15, forge_noor], ["lotte", 16, forge_lotte]],
			"inv": inv_act2, "kern": true,
			"encounters": _room_groups(a2, fl, true, false),
			"notes": "Archief 2 floor %d. Full party: Dax 16, Vesper 15, Seren 16 (joins at Dax's level), Act-2 forge gear." % fl})
	var a2_boss: Array = _room_groups(a2, 3, true, true) + _room_groups(a2, 4, true, true)
	for g in a2_boss:
		out.append({"id": "a2boss_" + str(g["enemies"][0]), "name": "BOSS %s (Second Archive)" % _enemy_name(str(g["enemies"][0])),
			"party": [["dennis", 16, forge_dax], ["noor", 15, forge_noor], ["lotte", 16, forge_lotte]],
			"inv": inv_act2, "kern": true, "encounters": [g],
			"notes": "Archief 2 boss, same party as floors 3-4."})
	# Diepe Grot: de verdieping wordt pas gegenereerd als het scenario echt draait (traag)
	for f in D100_SAMPLE_FLOORS:
		out.append({"id": "d100_v%d" % f, "lazy_d100": [f, false]})
	for f in Dungeon100Scaling.boss_floors():
		out.append({"id": "d100_boss_%d" % f, "lazy_d100": [int(f), true]})
	# Gevoeligheid: dezelfde gevechten, maar de AI gebruikt geen bliksem/ijs (die verlammen/bevriezen
	# bij ELKE treffer, SpellRules.on_hit). Alleen voor scenario's met een caster die zo'n spreuk kent.
	var variants: Array = []
	for sc in out:
		if sc.has("lazy_d100"):
			if int(sc["lazy_d100"][0]) >= 30:
				variants.append({"id": str(sc["id"]) + "_nostun", "lazy_d100": sc["lazy_d100"], "ban": STUN_ELEMENTS})
		elif (sc["party"] as Array).any(func(p): return str(p[0]) in ["noor", "lotte"]) and str(sc.get("filter", "")) == "":
			var v: Dictionary = sc.duplicate(true)
			v["id"] = str(sc["id"]) + "_nostun"
			v["name"] = str(sc["name"]) + " [no stun spells]"
			v["ban"] = STUN_ELEMENTS
			variants.append(v)
	out.append_array(variants)
	if not only.is_empty():
		out = out.filter(func(s): return only.has(s["id"]))
	return out


## Speler-level in de Diepe Grot (aanname): canon zegt bij de baas HP = level x 50 (25: 750 -> Lv 15,
## 50 -> 25, 75 -> 35, 99 -> 45), dus Lv = 5 + 0,4 x verdieping; verdieping 1 = Lv 1 (verse run).
static func d100_level(f: int) -> int:
	return 1 if f <= 1 else roundi(5.0 + 0.4 * f)


func _d100_scenario(f: int, boss: bool) -> Dictionary:
	var lv := d100_level(f)
	var tier := clampi(Dungeon100Scaling.tier_for_floor(f), 1, 5)
	var groups: Array = []
	for k in D100_LAYOUTS:
		var room: Dictionary = Dungeon100Generator.generate(base_seed + k * 7717, f).get("room", {})
		for m in room.get("monsters", []):
			if bool(m.get("boss", false)) != boss:
				continue
			var g := {"enemies": (m.get("group", [m["enemy"]]) as Array).duplicate(), "weight": 1, "boss": boss,
					"tier": 0, "archief": false, "floor": f}
			groups.append(g)
			if boss:
				break
		if boss and not groups.is_empty():
			break
	var pots: Array = Dungeon100Scaling.POTIONS[tier - 1]
	var inv := {}
	for p in pots:
		inv[p] = int(inv.get(p, 0)) + 3
	var spells := {"dennis": [], "noor": [], "lotte": []}
	if f >= 10:
		spells["noor"] = ["vuur"]
		spells["lotte"] = ["genees"]
	if f >= 30:
		spells["noor"] = ["vuur", "bliksem"]
	return {"id": ("d100_boss_%d" if boss else "d100_v%d") % f,
		"name": ("BOSS Deep Cave floor %d (%s)" % [f, Dungeon100Scaling.boss_for_floor(f).get("name", "?")]) if boss \
				else "Deep Cave (Dungeon100) floor %d" % f,
		"d100": true, "d100_tier": tier, "d100_spells": spells,
		"party": [["dennis", lv, []], ["noor", lv, []], ["lotte", lv, []]], "inv": inv, "kern": true,
		"encounters": groups,
		"notes": "Generated floor (Dungeon100Generator, %d run seeds). Party Lv %d, d100 gear tier %d, potions of loot tier %d (3 each)." % [D100_LAYOUTS, lv, tier, tier]}


func _terrain_groups(terrain: String) -> Array:
	var out: Array = []
	for g in GameData.ENCOUNTER_GROUPS:
		if int(g["weight"]) <= 0:
			continue
		if g.has("terrains") and not (terrain in g["terrains"]):
			continue
		out.append({"enemies": (g["enemies"] as Array).duplicate(), "weight": int(g["weight"]), "boss": false,
				"tier": 0, "archief": false, "floor": 0})
	return out


## Monstergroepen uit kamerdata. fl = verdieping (-1 = alle). Elke map-monster telt 1x (gewicht 1),
## zoals de speler ze in de kamer tegenkomt. Gelijke groepen worden samengevoegd (gewicht opgeteld).
func _room_groups(rooms: Dictionary, fl: int, archief: bool, bosses: bool) -> Array:
	var by_key := {}
	var out: Array = []
	for rid in rooms:
		var room: Dictionary = rooms[rid]
		if fl > 0 and int(room.get("floor", 0)) != fl:
			continue
		for m in room.get("monsters", []):
			var is_boss := bool(m.get("boss", false))
			if is_boss != bosses:
				continue
			var group: Array = (m.get("group", [m["enemy"]]) as Array).duplicate()
			var tier := 0 if is_boss else int(room.get("tier", 0))
			var key := "%s|%d|%s" % [",".join(group), tier, is_boss]
			if by_key.has(key):
				by_key[key]["weight"] += 1
				continue
			var g := {"enemies": group, "weight": 1, "boss": is_boss, "tier": tier,
					"archief": archief, "floor": 0}
			by_key[key] = g
			out.append(g)
	return out


func _enemy_name(id: String) -> String:
	if GameData.ENEMIES.has(id):
		return str(GameData.ENEMIES[id].get("name", id))
	if BerggrotData.has_enemy(id):
		return str(BerggrotData.enemy(id).get("name", id))
	return id


# =============================================================== party bouwen (echte GameState-code)
func _build_party(sc: Dictionary) -> void:
	GameState.new_game(GameState.DEFAULT_NAME)
	GameState.codex_reset(false)
	GameState.kernfragmenten = {}
	if bool(sc.get("kern", false)):
		GameState.grant_kern("golemkern")
	var specs: Array = sc["party"]
	if bool(sc.get("d100", false)):
		for spec in specs.slice(1):
			GameState.add_member(str(spec[0]))
		GameState._dungeon100_fresh_run()       # level 1, geen uitrusting, geen spreuken (echte run-start)
	for spec in specs:
		var id := str(spec[0])
		var lv := int(spec[1])
		var gear: Array = spec[2]
		if bool(sc.get("d100", false)):
			gear = _d100_gear(id, int(sc["d100_tier"]))
		if id == "lotte" and not bool(sc.get("d100", false)):
			Archief2.sluit_lotte_aan()          # Seren sluit aan op Dax' level met haar startspullen
		elif not GameState.has_member(id):
			GameState.join_member(id, lv, [])
		var h: Dictionary = GameState.member(id)
		if lv > int(h["level"]):
			GameState.give_exp(h, GameData.exp_for_level(lv) - int(h["exp"]))
		for gid in gear:
			var slot := Equipment.slot_of(str(gid))
			if slot == "" or not Equipment.can_wear(h, str(gid)):
				continue
			GameState.inventory[gid] = GameState.item_count(str(gid)) + 1
			Equipment.equip(h, GameState.inventory, slot, str(gid))
		if bool(sc.get("d100", false)):
			h["spells"] = (sc["d100_spells"].get(id, []) as Array).duplicate()
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	GameState.inventory = (sc["inv"] as Dictionary).duplicate(true)


func _d100_gear(id: String, tier: int) -> Array:
	var out: Array = []
	var kinds := ["zwaard", "schild", "helm", "harnas", "ring"] if id == "dennis" else ["staf", "helm", "harnas", "ring"]
	for k in kinds:
		out.append(Dungeon100Scaling.GEAR[k][tier - 1])
	return out


func _party_snapshot() -> Dictionary:
	return {"party": GameState.party.duplicate(true), "inventory": GameState.inventory.duplicate(true)}


func _restore(snap: Dictionary) -> void:
	GameState.party = (snap["party"] as Array).duplicate(true)
	GameState.inventory = (snap["inventory"] as Dictionary).duplicate(true)


# =============================================================== simuleren
func run_all() -> void:
	SimBattle = load(SIM_BATTLE_PATH)
	BATTLE_SCENE = load(BATTLE_SCENE_PATH)
	results = []
	holder = Node.new()
	holder.name = "BattleSimHolder"
	add_child(holder)
	for sc in scenarios():
		results.append(await run_scenario(sc))
	holder.queue_free()


func run_scenario(sc: Dictionary) -> Dictionary:
	if sc.has("lazy_d100"):
		var t0 := Time.get_ticks_msec()
		var ban: Array = sc.get("ban", [])
		var sid := str(sc["id"])
		sc = _d100_scenario(int(sc["lazy_d100"][0]), bool(sc["lazy_d100"][1]))
		if not ban.is_empty():
			sc["id"] = sid
			sc["name"] = str(sc["name"]) + " [no stun spells]"
			sc["ban"] = ban
		if standalone:
			print("BATTLESIM %s generated in %d ms" % [sc["id"], Time.get_ticks_msec() - t0])
	_build_party(sc)
	if standalone:
		print("BATTLESIM %s: %d groups, %d fights" % [sc["id"], (sc["encounters"] as Array).size(), fights])
	var snap := _party_snapshot()
	var party_desc := _party_desc()
	var groups: Array = sc["encounters"]
	var per_group := {}
	var rows: Array = []
	var total_w := 0
	for g in groups:
		total_w += int(g["weight"])
	for i in fights:
		seed(hash([base_seed, str(sc["id"]), i]))
		var roll := randi() % maxi(1, total_w)
		var g: Dictionary = groups[0]
		for cand in groups:
			roll -= int(cand["weight"])
			if roll < 0:
				g = cand
				break
		_restore(snap)
		var r := await _fight(sc, g)
		rows.append(r)
		var key := _group_label(g)
		if not per_group.has(key):
			per_group[key] = []
		per_group[key].append(r)
		if i % 64 == 63:
			await get_tree().process_frame     # vrijgegeven gevechten echt opruimen
	_restore(snap)
	var res := _summarize(rows)
	res["id"] = sc["id"]
	res["name"] = sc["name"]
	res["notes"] = sc.get("notes", "")
	res["party"] = party_desc
	res["inventory"] = snap["inventory"]
	res["groups"] = []
	for key in per_group:
		var gs := _summarize(per_group[key])
		gs["label"] = key
		res["groups"].append(gs)
	return res


func _fight(sc: Dictionary, g: Dictionary) -> Dictionary:
	GameState.pending_enemies = (g["enemies"] as Array).duplicate()
	GameState.pending_boss = bool(g["boss"])
	GameState.pending_tier = 0 if g["boss"] else int(g["tier"])
	GameState.pending_archief = bool(g["archief"]) and not bool(g["boss"])
	GameState.dungeon100_floor = int(g.get("floor", 0))
	GameState.pending_tutorial = {}
	GameState.pending_backdrop = ""
	GameState.practice_battle = false
	GameState.pending_story_loss = false
	GameState.archief2_temp_ally = {}
	GameState.archief2_party_filter = str(sc.get("filter", ""))
	var start_hp := 0
	var max_hp := 0
	var start_mp := 0
	var fighters: Array = []
	for h in GameState.party:
		if GameState.archief2_party_filter != "" and str(h.get("id", "")) != GameState.archief2_party_filter:
			continue
		fighters.append(h)
		start_hp += int(h["hp"])
		max_hp += int(h["max_hp"])
		start_mp += int(h["mp"])
	var inv_before := GameState.inventory.duplicate(true)
	var b: Control = BATTLE_SCENE.instantiate()
	b.set_script(SimBattle)
	b.sim_trace = trace
	b.sim_ban_elements = sc.get("ban", [])
	holder.add_child(b)
	if b.sim_result == "":
		b._run()
	if b.sim_result == "":
		await b.sim_done
	var end_hp := 0
	var kos := 0
	for h in fighters:
		end_hp += maxi(0, int(h["hp"]))
		if int(h["hp"]) <= 0:
			kos += 1
	var items := 0
	for id in inv_before:
		items += maxi(0, int(inv_before[id]) - GameState.item_count(id))
	var r := {"win": b.sim_result == "win", "timeout": b.sim_result == "timeout", "rounds": b.sim_rounds,
		"hp_loss": float(start_hp - end_hp) / float(maxi(1, max_hp)), "kos": kos,
		"items": items, "mp": b.sim_mp_used}
	holder.remove_child(b)
	b.queue_free()
	GameState.archief2_party_filter = ""
	GameState.dungeon100_floor = 0
	return r


func _group_label(g: Dictionary) -> String:
	var names: Array = []
	for e in g["enemies"]:
		names.append(_enemy_name(str(e)))
	var s := " + ".join(names)
	if int(g.get("tier", 0)) > 0:
		s += " (tier %d)" % int(g["tier"])
	if int(g.get("floor", 0)) > 0:
		s += " (floor %d)" % int(g["floor"])
	return s


func _party_desc() -> String:
	var parts: Array = []
	for h in GameState.party:
		var eq: Array = []
		for slot in Equipment.slots():
			var id := Equipment.equipped(h, slot)
			if id != "":
				eq.append(Equipment.item_name(id))
		parts.append("%s Lv%d (HP %d MP %d ATK %d DEF %d AGI %d MAG %d; %s; spells: %s)" % [
				h["name"], h["level"], h["max_hp"], h["max_mp"], h["atk"], h["def"], h["agi"], h.get("mag", 0),
				", ".join(eq) if not eq.is_empty() else "no gear",
				", ".join((h["spells"] as Array).map(func(s): return GameData.SPELLS[s]["name"])) if not (h["spells"] as Array).is_empty() else "-"])
	if not GameState.kernfragmenten.is_empty():
		parts.append("Core: " + ", ".join(GameState.kernfragmenten.keys()))
	return "; ".join(parts)


static func _summarize(rows: Array) -> Dictionary:
	var n := rows.size()
	var wins := 0
	var timeouts := 0
	var rounds := 0.0
	var items := 0.0
	var mp := 0.0
	var kos := 0.0
	var losses: Array = []
	for r in rows:
		wins += 1 if r["win"] else 0
		timeouts += 1 if r["timeout"] else 0
		rounds += r["rounds"]
		items += r["items"]
		mp += r["mp"]
		kos += r["kos"]
		losses.append(float(r["hp_loss"]))
	losses.sort()
	var avg_loss := 0.0
	for l in losses:
		avg_loss += l
	var nn := float(maxi(1, n))
	return {"n": n, "win_rate": wins / nn, "timeouts": timeouts, "avg_rounds": rounds / nn,
		"avg_hp_loss": avg_loss / nn, "p90_hp_loss": losses[mini(n - 1, int(ceil(0.9 * n)) - 1)] if n > 0 else 0.0,
		"avg_items": items / nn, "avg_mp": mp / nn, "avg_kos": kos / nn}


# =============================================================== rapport
static func pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func outlier_tag(s: Dictionary) -> String:
	if float(s["win_rate"]) < 0.5:
		return "NEAR-IMPOSSIBLE"
	if float(s["win_rate"]) < HARD_WIN:
		return "HARD"
	if float(s["win_rate"]) >= 1.0 and float(s["avg_hp_loss"]) < EASY_LOSS and float(s["avg_rounds"]) <= 2.0:
		return "TRIVIAL"
	return ""


func report_markdown(ms: int) -> String:
	var L: Array = []
	L.append("# Battle balance report (headless simulator)")
	L.append("")
	L.append("Generated by `tools/battlesim/battlesim.gd` (`-- --battlesim --seed=%d --fights=%d`) on Godot %s. Runtime %.1f s." % [
			base_seed, fights, Engine.get_version_info()["string"], ms / 1000.0])
	L.append("Same seed + same code = same numbers. **No gameplay was changed**: the simulator instantiates the real")
	L.append("`scenes/battle/battle.tscn` and only swaps the menu, waits and animations (`tools/battlesim/sim_battle.gd`).")
	L.append("")
	L.append("## Summary per area")
	L.append("")
	L.append("| Area | Fights | Win rate | Avg rounds | Avg HP loss | p90 HP loss | Avg items | Avg MP | Avg KOs | Flag |")
	L.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---|")
	for r in results:
		L.append("| %s | %d | %s | %.1f | %s | %s | %.2f | %.1f | %.2f | %s |" % [r["name"], r["n"], pct(r["win_rate"]),
				r["avg_rounds"], pct(r["avg_hp_loss"]), pct(r["p90_hp_loss"]), r["avg_items"], r["avg_mp"], r["avg_kos"], outlier_tag(r)])
	L.append("")
	L.append("HP loss = party HP at the end vs. the start of the fight, as a share of the party's max HP (net of healing; a KO counts as the full bar).")
	L.append("Each fight starts with the party at full HP/MP and the listed bag (fights are independent, no carry-over).")
	L.append("Items = consumables used per fight; MP = MP spent per fight. Rounds = battle rounds (all heroes + enemies act once).")
	L.append("")
	L.append("## Outliers (per encounter group)")
	L.append("")
	L.append("NEAR-IMPOSSIBLE = win rate < 50%%; HARD = win rate < %d%%; TRIVIAL = 100%% wins, avg HP loss < %d%% and <= 2 rounds." % [
			roundi(HARD_WIN * 100), roundi(EASY_LOSS * 100)])
	L.append("")
	L.append("| Area | Encounter | Fights | Win rate | Avg rounds | Avg HP loss | p90 HP loss | Flag |")
	L.append("|---|---|---:|---:|---:|---:|---:|---|")
	var any := false
	for r in results:
		for g in r["groups"]:
			var tag := outlier_tag(g)
			if tag == "":
				continue
			any = true
			L.append("| %s | %s | %d | %s | %.1f | %s | %s | %s |" % [r["name"], g["label"], g["n"], pct(g["win_rate"]),
					g["avg_rounds"], pct(g["avg_hp_loss"]), pct(g["p90_hp_loss"]), tag])
	if not any:
		L.append("| - | none | | | | | | |")
	L.append("")
	L.append("## Per area: party, assumptions and encounter groups")
	for r in results:
		L.append("")
		L.append("### %s (`%s`)" % [r["name"], r["id"]])
		L.append("")
		L.append("- Party: %s" % r["party"])
		L.append("- Bag: %s" % JSON.stringify(r["inventory"]))
		L.append("- Source/assumption: %s" % r["notes"])
		L.append("")
		L.append("| Encounter | Fights | Win | Rounds | HP loss | p90 | Items | MP |")
		L.append("|---|---:|---:|---:|---:|---:|---:|---:|")
		for g in r["groups"]:
			L.append("| %s | %d | %s | %.1f | %s | %s | %.2f | %.1f |" % [g["label"], g["n"], pct(g["win_rate"]), g["avg_rounds"],
					pct(g["avg_hp_loss"]), pct(g["p90_hp_loss"]), g["avg_items"], g["avg_mp"]])
	L.append("")
	L.append(ASSUMPTIONS)
	return "\n".join(L) + "\n"


const ASSUMPTIONS := """## Global assumptions and method

- **Real code**: every fight is the real `battle.tscn` with `battle.gd` (`_ready` builds combatants and applies
  tier / First-Archive scaling / Dungeon100 scaling / boss stats; `_execute`, `_physical_damage`, `_spell_amount`,
  buffs, DoT/HoT, guard, Golem core, Archief-2 opening strike/leech/skills, Core Strike, turn order, KO/victory checks).
  Monster, item, spell and gear tables are read from `GameData`, `BerggrotData`, `SpellsData`, `Dungeon100Scaling`.
  The round loop in `sim_battle.gd` mirrors `battle.gd _run` without fades/waits; enemy AI is the game's own.
- **Party building** uses `GameState.new_game`, `join_member`, `give_exp` (real level-up growth), `Equipment.equip`,
  `Archief2.sluit_lotte_aan` (Seren) and `_dungeon100_fresh_run` (Deep Cave: Lv 1, no gear, no spells, then leveled).
- **Levels/gear per area** follow `scripts/data/level_scale.gd` (Act 1 = Lv 1-13, Act 2 = 14-19), the First
  Archive target (Lv 7, `EERSTE_ARCHIEF_DOEL`), the Golem note (balanced around Lv ~10 with the Spark Sword; we test Lv 8),
  Vesper joining after the Root King at Dax-1, Seren joining at Dax's level. Gear is the shop/chest gear plausible at
  that point (Short Sword/Wooden Shield/Leather Hood/Apprentice Cloak at the start; Leather Armor from floor 2; Spark
  Sword + Cover Shield from floor 3; Iron Helm from the Dark Wood chest; Act-2 forge gear from Archive 2 floor 3).
- **Deep Cave**: party level = 5 + 0.4 x floor (derived from the canon boss rule HP = level x 50 at floors 25/50/75/99),
  floor 1 = Lv 1. Gear = the Dungeon100 loot line of `tier_for_floor`. Spells only from scrolls: from floor 10 Vesper
  has Spark and Seren Minor Heal, from floor 30 Vesper also Chain Lightning. 3 of each potion of that loot tier.
  Dax keeps the Golem Core (kern fragments are not reset by a run).
- **Not modelled**: Codex allies / capturing (no Blank Books used), fleeing, defending, buffs from Seren's later
  spells, Koopman token, Inktwurm (secret), mimics, practice fight. Seren/Lotte story fight has no Codex ally.
- **Simple AI** (`sim_battle.gd`): heal anyone below 40% HP (heal spell if MP, else the smallest potion that covers
  the gap); revive a KO ally with a revive spell / Phoenix Feather; casters drink Magic Water below 25% MP; use Core
  Strike when charged (on the enemy with most HP); cast a damage spell only if its expected damage beats a normal
  attack by 15% (group spell counts all living enemies); otherwise attack the enemy with the lowest HP.
- A fight that is not over after 60 rounds counts as a loss (timeout).
"""
