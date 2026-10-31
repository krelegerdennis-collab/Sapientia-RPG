extends Node
## ALLEEN VOOR TESTEN - battle simulator in CSV-modus (tools/battlesim/battlesim_runs.gd).
## Start:  godot --path . -- --battlesimtest
##   Deel A: argumenten (party, vijandgroepen, items, policy) en foutmeldingen.
##   Deel B: dunne wrapper in battle.gd: physical_base/spell_base/kern_base raken de RNG niet
##           en _physical_damage/_spell_amount/kern_damage blijven binnen hun geluksmarge.
##   Deel C: policy "simpel": genezen onder 35% HP, anders de sterkste aanval.
##   Deel D: deterministisch: zelfde seed = exact dezelfde CSV, andere seed = andere CSV.
##   Deel E: 100+ runs zonder crash (elke groep uit ENCOUNTER_GROUPS, ook de baas).
##   Deel F: de CSV in user://sim/ is geldig (kolommen, getallen, logica per regel).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const Runs := preload("res://tools/battlesim/battlesim_runs.gd")
const Equipment := preload("res://scripts/equipment.gd")
const POLICY := "res://tools/battlesim/policy_simpel.gd"
const BATTLE := "res://scenes/battle/battle.tscn"

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
	var t0 := Time.get_ticks_msec()
	while not GameState._preloading.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	print("=== Deel A: argumenten ===")
	await _arg_tests()
	print("=== Deel B: wrapper in battle.gd ===")
	await _wrapper_tests()
	print("=== Deel C: policy simpel ===")
	await _policy_tests()
	print("=== Deel D: deterministisch ===")
	var csv_det := await _determinism_tests()
	print("=== Deel E: 100+ runs ===")
	var csv_all := await _many_runs_tests()
	print("=== Deel F: CSV geldig ===")
	_csv_tests(csv_det, 10, 2)
	_csv_tests(csv_all, 8, GD.ENCOUNTER_GROUPS.size())
	print("BATTLESIMTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _runner(args: Array) -> Node:
	var r: Node = Runs.new()
	r.standalone = false
	add_child(r)
	r.configure(PackedStringArray(args))
	return r


# ================================================================ deel A
func _arg_tests() -> void:
	check("CSV-modus alleen met run-argumenten", Runs.wants_runs(PackedStringArray(["--battlesim", "--enemy=enc0"]))
			and Runs.wants_runs(PackedStringArray(["--battlesim", "--party=dennis"]))
			and not Runs.wants_runs(PackedStringArray(["--battlesim", "--seed=3", "--fights=10"])))
	var r := _runner(["--party=dennis:7,noor:5", "--enemy=enc1,baas_kennis_beest,mech_wachter+papiergeest",
			"--runs=12", "--seed=99", "--policy=simpel", "--tier=2", "--items=drankje:4,kruid:1", "--out=user://sim/x.csv"])
	check("argumenten gelezen", r.runs == 12 and r.base_seed == 99 and r.policy == "simpel" and r.tier == 2
			and r.out_path == "user://sim/x.csv")
	var party: Array = r.parse_party(r.party_spec)
	check("party: id + level", party == [["dennis", 7], ["noor", 5]])
	check("party zonder level = level 1", r.parse_party("dennis") == [["dennis", 1]])
	var groups: Array = r.parse_groups(r.enemy_spec)
	check("groepen: enc<N>, id en a+b", groups.size() == 3
			and groups[0]["enemies"] == GD.ENCOUNTER_GROUPS[1]["enemies"] and groups[0]["id"] == "enc1"
			and groups[1]["id"] == "baas_kennis_beest" and groups[1]["boss"] == true
			and groups[2]["enemies"] == ["mech_wachter", "papiergeest"] and groups[2]["boss"] == false)
	check("all = elke groep uit ENCOUNTER_GROUPS", r.parse_groups("all").size() == GD.ENCOUNTER_GROUPS.size())
	check("items: id:aantal", r.parse_items(r.items_spec) == {"drankje": 4, "kruid": 1})
	check("items leeg = START_INVENTORY", r.parse_items("") == GD.START_INVENTORY)
	check("geen fouten bij geldige invoer", r.errors.is_empty())
	for bad in [["--party=nobody:3"], ["--party=noor:3"], ["--enemy=enc999"], ["--enemy=geen_monster"],
			["--policy=slim"], ["--runs=0"], ["--items=goud:3"], ["--party=dennis:0"]]:
		var rb := _runner(bad)
		rb.out_path = "user://sim/mag_niet_bestaan.csv"
		var csv: String = await rb.run()
		check("fout gemeld, niets geschreven: %s" % bad[0], csv == "" and not rb.errors.is_empty()
				and not FileAccess.file_exists("user://sim/mag_niet_bestaan.csv"))
		rb.queue_free()
	check("CSV-cel: komma/quote gequote, float met 1 decimaal", Runs.csv_cell("a,b") == "\"a,b\""
			and Runs.csv_cell("x\"y") == "\"x\"\"y\"" and Runs.csv_cell(12.5) == "12.5" and Runs.csv_cell(7) == "7")
	r.queue_free()
	await _gear_tests()
	await _golem_scenario_tests()


## --gear: uitrusting per held (bv. Golem-meting: Dax met Vonkzwaard).
func _gear_tests() -> void:
	var r := _runner(["--party=dennis:8", "--gear=dennis:vonkzwaard+kaftschild"])
	var gear: Dictionary = r.parse_gear(r.gear_spec, r.parse_party(r.party_spec))
	check("gear: held:stuk+stuk", gear == {"dennis": ["vonkzwaard", "kaftschild"]} and r.errors.is_empty())
	var snap: Dictionary = r._build_party([["dennis", 8]], {"drankje": 2}, gear)
	var h: Dictionary = snap["party"][0]
	check("gear: uitgerust (wapen + schild, ATK-bonus), tas = alleen --items",
			Equipment.equipped(h, "wapen") == "vonkzwaard" and Equipment.equipped(h, "schild") == "kaftschild"
			and Equipment.equip_bonus(h, "atk") > 0 and snap["inventory"] == {"drankje": 2} and r.errors.is_empty())
	check("items: none = lege tas", r.parse_items("none") == {})
	r.queue_free()
	for bad in [["--party=dennis:8", "--gear=noor:eiken_staf"], ["--party=dennis:8", "--gear=dennis:geen_zwaard"],
			["--scenario=onbekend"]]:
		var rb := _runner(bad)
		rb.out_path = "user://sim/mag_niet_bestaan.csv"
		var csv: String = await rb.run()
		check("gear/scenario-fout gemeld, niets geschreven: %s" % bad[-1], csv == "" and not rb.errors.is_empty()
				and not FileAccess.file_exists("user://sim/mag_niet_bestaan.csv"))
		rb.queue_free()


## --scenario=golem (kennis_beest optie A): Dax solo, Vonkzwaard-set, inv_mid-tas, baasgroep;
## --party/--items gaan erboven (meting Lv 7/8 met en zonder items).
func _golem_scenario_tests() -> void:
	check("CSV-modus ook met alleen --scenario", Runs.wants_runs(PackedStringArray(["--battlesim", "--scenario=golem"])))
	var r := _runner(["--scenario=golem"])
	check("golem-scenario: standaard Dax Lv %d, baas_kennis_beest, GOLEM_BOSS_GEAR, GOLEM_BOSS_INV" % Runs.GOLEM_BOSS_LEVEL,
			r.parse_party(r.party_spec) == [["dennis", Runs.GOLEM_BOSS_LEVEL]] and r.enemy_spec == Runs.GOLEM_BOSS_GROUP
			and r.parse_gear(r.gear_spec, [["dennis", 8]]) == {"dennis": Runs.GOLEM_BOSS_GEAR}
			and r.parse_items(r.items_spec) == Runs.GOLEM_BOSS_INV and r.errors.is_empty())
	r.queue_free()
	for cell in [["7", "", 1], ["7", "none", 0], ["8", "", 1]]:
		var args := ["--scenario=golem", "--party=dennis:%s" % cell[0], "--runs=4", "--seed=7"]
		if cell[1] != "":
			args.append("--items=" + cell[1])
		var rc := _runner(args)
		var csv: String = await rc.run()
		var ok: bool = csv != "" and rc.errors.is_empty() and rc.rows.size() == 4
		var used := 0
		for row in rc.rows:
			ok = ok and row["group_id"] == "baas_kennis_beest" and row["party"] == "dennis:" + cell[0] \
					and int(row["hp_max"]) == int(GameState.party[0]["max_hp"]) and row["result"] != "timeout"
			used += int(row["items_used"])
		var h: Dictionary = GameState.party[0]
		ok = ok and GameState.party.size() == 1 and int(h["level"]) == int(cell[0]) \
				and Equipment.equipped(h, "wapen") == "vonkzwaard"
		check("golem-scenario Lv %s %s: 4 baasgevechten, solo Dax met Vonkzwaard, %s" % [cell[0],
				"zonder items" if cell[1] == "none" else "met tas", "0 items" if cell[2] == 0 else "tas beschikbaar"],
				ok and (used == 0 if cell[2] == 0 else true))
		rc.queue_free()


# ================================================================ battle met policy (zonder rondelus)
func _battle(party: Array, enemies: Array, boss := false) -> Control:
	var r := _runner([])
	r._build_party(party, {"drankje": 3, "toverwater": 1})
	r.queue_free()
	GameState.prepare_battle(enemies, "", boss, 0)
	var b: Control = (load(BATTLE) as PackedScene).instantiate()
	b.set_script(load(POLICY))
	b.sim_started = true          # rondelus niet starten: alleen keuzes/formules testen
	add_child(b)
	return b


# ================================================================ deel B
func _wrapper_tests() -> void:
	var b := _battle([["dennis", 8], ["noor", 8]], ["kennis_beest", "papiergeest"])
	var h: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	var f: Dictionary = b.enemies[0]
	seed(4242)
	var a := randf()
	seed(4242)
	var pb: float = b.physical_base(h, f, 1.0)
	var sp: Dictionary = GD.SPELLS[noor["s"]["spells"][0]]
	var sb: float = b.spell_base(noor, sp, f)
	var kb: float = b.kern_base(h, f, {"atk_mult": 1.5, "def_factor": 0.25})
	check("physical_base/spell_base/kern_base gebruiken geen randf()", is_equal_approx(randf(), a))
	check("physical_base = ATK - DEF/2 van het doel", is_equal_approx(pb, float(h["s"]["atk"]) * b._buff_mult(h, "atk") - b._defense_of(f) / 2.0))
	var ok_p := true
	var ok_s := true
	var ok_k := true
	for i in 200:
		var d: int = b._physical_damage(h, f, 1.0)
		ok_p = ok_p and d >= maxi(1, floori(pb * 0.85)) and d <= maxi(1, ceili(pb * 1.15))
		var s: int = b._spell_amount(noor, sp, f)
		ok_s = ok_s and s >= maxi(1, floori(sb * 0.9)) and s <= maxi(1, ceili(sb * 1.1))
		var k: int = b.kern_damage(h, f, {"atk_mult": 1.5, "def_factor": 0.25})
		ok_k = ok_k and k >= maxi(1, floori(kb * 0.85)) and k <= maxi(1, ceili(kb * 1.15))
	check("_physical_damage blijft binnen base x 0.85..1.15", ok_p)
	check("_spell_amount blijft binnen base x 0.9..1.1", ok_s)
	check("kern_damage blijft binnen base x 0.85..1.15", ok_k)
	seed(77)
	var d1: int = b._physical_damage(h, f, 1.0)
	seed(77)
	var d2 := maxi(1, roundi(pb * randf_range(0.85, 1.15)))
	check("_physical_damage = roundi(physical_base x geluk) (zelfde RNG-trekking)", d1 == d2)
	b.queue_free()
	await get_tree().process_frame


# ================================================================ deel C
func _policy_tests() -> void:
	var b := _battle([["dennis", 5]], ["mosslijm", "papiergeest"])
	var h: Dictionary = b.heroes[0]
	var max_hp := int(h["s"]["max_hp"])
	h["s"]["hp"] = int(max_hp * 0.30)
	var a: Dictionary = b._ai_action(h, {})
	check("onder 35%% HP zonder genees-spreuk: genees-item op zichzelf (%s)" % a.get("item", a["type"]),
			a["type"] == "item" and GD.ITEMS[a["item"]].get("heal_hp", 0) > 0 and a["target"] == h)
	h["s"]["hp"] = int(ceil(max_hp * 0.36))
	a = b._ai_action(h, {})
	check("boven 35%% HP: aanvallen (%s)" % a["type"], a["type"] == "attack")
	h["s"]["hp"] = int(max_hp * 0.30)
	GameState.inventory = {}
	a = b._ai_action(h, {})
	check("onder 35% maar niets om te genezen: toch aanvallen", a["type"] == "attack")
	h["s"]["hp"] = max_hp
	a = b._ai_action(h, {})
	var best := 0.0
	for f in b._alive(b.enemies):
		best = maxf(best, b.expected_physical(h, f))
	check("sterkste aanval: doel met de hoogste verwachte schade",
			a["type"] == "attack" and is_equal_approx(b.expected_physical(h, a["target"]), best))
	b.queue_free()
	await get_tree().process_frame
	b = _battle([["dennis", 8], ["noor", 8]], ["kennis_beest"])
	var noor: Dictionary = b.heroes[1]
	var dax: Dictionary = b.heroes[0]
	dax["s"]["hp"] = int(int(dax["s"]["max_hp"]) * 0.2)
	noor["s"]["spells"] = (noor["s"]["spells"] as Array) + ["genees"]
	noor["s"]["mp"] = noor["s"]["max_mp"]
	a = b._ai_action(noor, {})
	check("Vesper geneest Dax met een spreuk (%s)" % a.get("spell", a["type"]),
			a["type"] == "spell" and GD.SPELLS[a["spell"]]["type"] == "heal" and a["target"] == dax)
	var planned := {dax["uid"]: true}
	a = b._ai_action(noor, planned)
	var f0: Dictionary = b.enemies[0]
	var phys: float = b.expected_physical(noor, f0)
	var val: float = phys if a["type"] == "attack" else b.expected_spell(noor, GD.SPELLS[a["spell"]], f0)
	var max_val := phys
	for id in noor["s"]["spells"]:
		var sp: Dictionary = GD.SPELLS[id]
		if str(sp.get("type", "damage")) == "damage" and int(noor["s"]["mp"]) >= int(sp["mp"]):
			max_val = maxf(max_val, b.expected_spell(noor, sp, f0))
	check("Dax al ingepland: Vesper kiest de sterkste aanval (%s)" % a.get("spell", a["type"]),
			a["type"] in ["attack", "spell"] and is_equal_approx(val, max_val))
	noor["s"]["mp"] = 0
	a = b._ai_action(noor, planned)
	check("zonder MP: gewone aanval", a["type"] == "attack")
	b.queue_free()
	await get_tree().process_frame


# ================================================================ deel D
func _determinism_tests() -> String:
	var args := ["--party=dennis:5,noor:5", "--enemy=enc6,baas_kennis_beest", "--runs=10", "--seed=123", "--policy=simpel"]
	var r1 := _runner(args)
	var c1: String = await r1.run()
	var r2 := _runner(args)
	var c2: String = await r2.run()
	check("zelfde seed: exact dezelfde CSV (%d regels)" % (c1.split("\n", false).size() - 1), c1 != "" and c1 == c2)
	check("geschreven naar user://sim/battlesim_simpel_s123.csv", r1.written_path == "user://sim/battlesim_simpel_s123.csv"
			and FileAccess.get_file_as_string(r1.written_path) == c1)
	var r3 := _runner(["--party=dennis:5,noor:5", "--enemy=enc6,baas_kennis_beest", "--runs=10", "--seed=124", "--policy=simpel"])
	var c3: String = await r3.run()
	check("andere seed: andere CSV", c3 != "" and c3 != c1)
	var won: int = r1.rows.filter(func(x): return x["group_id"] == "baas_kennis_beest" and x["win"] == 1).size()
	var lost: int = r1.rows.filter(func(x): return x["group_id"] == "baas_kennis_beest" and x["win"] == 0).size()
	check("baas: echte gevechten (winst %d, verlies %d, samen 10)" % [won, lost], won + lost == 10)
	for r in [r1, r2, r3]:
		r.queue_free()
	return c1


# ================================================================ deel E
func _many_runs_tests() -> String:
	var t0 := Time.get_ticks_msec()
	var r := _runner(["--party=dennis:6,noor:6", "--enemy=all", "--runs=8", "--seed=2026", "--policy=simpel"])
	var csv: String = await r.run()
	var n: int = r.rows.size()
	check("%d runs (alle %d groepen x 8) zonder crash in %d ms" % [n, GD.ENCOUNTER_GROUPS.size(), Time.get_ticks_msec() - t0],
			r.errors.is_empty() and n == 8 * GD.ENCOUNTER_GROUPS.size() and n >= 100)
	check("elke run heeft een uitslag", r.rows.all(func(x): return x["result"] in ["win", "lose", "timeout"]))
	var r100 := _runner(["--party=dennis:3", "--enemy=enc8", "--runs=100", "--seed=5", "--policy=simpel", "--out=user://sim/glitchmot100.csv"])
	var c100: String = await r100.run()
	check("100 runs van een groep zonder crash", r100.errors.is_empty() and r100.rows.size() == 100 and c100 != "")
	_csv_tests(FileAccess.get_file_as_string("user://sim/glitchmot100.csv"), 100, 1)
	var rs := _runner(["--party=dennis:6,noor:6", "--enemy=enc6", "--runs=20", "--seed=8", "--policy=standaard"])
	var cs: String = await rs.run()
	check("policy standaard (bestaande sim-AI) draait ook", rs.errors.is_empty() and rs.rows.size() == 20 and cs != "")
	for x in [r, r100, rs]:
		x.queue_free()
	return csv


# ================================================================ deel F
func _csv_tests(csv: String, runs: int, groups: int) -> void:
	var lines := csv.split("\n", false)
	check("CSV: header klopt", lines.size() > 0 and lines[0] == ",".join(Runs.CSV_HEADER))
	check("CSV: %d regels (%d groepen x %d runs)" % [lines.size() - 1, groups, runs], lines.size() - 1 == groups * runs)
	var cols := Runs.CSV_HEADER.size()
	var ok_cols := true
	var ok_num := true
	var ok_logic := true
	var ok_runs := true
	var seen := {}
	for i in range(1, lines.size()):
		var c := lines[i].split(",")
		if c.size() != cols:
			ok_cols = false
			continue
		var row := {}
		for j in cols:
			row[Runs.CSV_HEADER[j]] = c[j]
		for k in ["seed", "tier", "run", "win", "turns", "hero_actions", "hp_left", "hp_max", "kos", "mp_used", "items_used"]:
			ok_num = ok_num and str(row[k]).is_valid_int()
		ok_num = ok_num and str(row["hp_left_pct"]).is_valid_float()
		var hp := int(row["hp_left"])
		var items_sum := 0
		for part in str(row["items_detail"]).split(";", false):
			items_sum += int(part.get_slice(":", 1))
		ok_logic = ok_logic and row["result"] in ["win", "lose", "timeout"] \
				and int(row["win"]) == (1 if row["result"] == "win" else 0) \
				and hp >= 0 and hp <= int(row["hp_max"]) and int(row["turns"]) >= 1 \
				and (row["result"] != "lose" or hp == 0) and (row["result"] != "win" or hp > 0) \
				and float(row["hp_left_pct"]) >= 0.0 and float(row["hp_left_pct"]) <= 100.0 \
				and int(row["mp_used"]) >= 0 and items_sum == int(row["items_used"])
		var key := "%s|%s" % [row["group_id"], row["run"]]
		ok_runs = ok_runs and not seen.has(key) and int(row["run"]) >= 0 and int(row["run"]) < runs
		seen[key] = true
	check("CSV: elke regel %d kolommen" % cols, ok_cols)
	check("CSV: getallen zijn getallen", ok_num)
	check("CSV: per regel logisch (win/result, 0 <= HP <= max, verlies = 0 HP, items_detail = items_used)", ok_logic)
	check("CSV: elke (groep, run) precies 1x, run 0..%d" % (runs - 1), ok_runs and seen.size() == groups * runs)
