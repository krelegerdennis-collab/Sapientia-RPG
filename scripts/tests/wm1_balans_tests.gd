extends Node
## ALLEEN VOOR TESTEN - WM1-balansmeting (tools/battlesim/wm1_balans.gd + wm1_sim_battle.gd).
## Start:  godot --path . -- --wm1balanstest
##   Deel A: scenariolijst (alle WM1-gebieden, extra's, geen _nostun-varianten, Diepe Grot optioneel).
##   Deel B: meting klopt: aantallen, EXP/goud uit de echte vijanddata, schade-teller, level-gevoeligheid.
##   Deel C: deterministisch (zelfde seed = zelfde getallen).
##   Deel D: vlaggen, level-venster en gebiedssamenvatting op vaste invoer.
##   Deel E: rapport (secties, markeringen; handgeschreven tekst blijft staan bij opnieuw genereren).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SimScript := "res://tools/battlesim/wm1_balans.gd"
const TEST_REPORT := "user://wm1_balans_test.md"

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


func _sim(only_ids: Array, fights_n: int) -> Node:
	var sim: Node = load(SimScript).new()
	sim.auto_run = false
	sim.base_seed = 4242
	sim.fights = fights_n
	sim.boss_fights = fights_n
	sim.sens_fights = 8
	sim.d100_fights = 6
	sim.do_d100 = false
	sim.only = only_ids
	add_child(sim)
	return sim


func _group(r: Dictionary, label_part: String) -> Dictionary:
	for g in r["groups"]:
		if str(g["label"]).contains(label_part):
			return g
	return {}


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while not GameState._preloading.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	print("=== Deel A: scenario's ===")
	_scenario_tests()
	print("=== Deel B: meting ===")
	var res_a := await _meting_tests()
	print("=== Deel C: deterministisch ===")
	await _determinisme_tests(res_a)
	print("=== Deel D: vlaggen en samenvatting ===")
	_vlag_tests()
	print("=== Deel E: rapport ===")
	await _rapport_tests()
	print("WM1BALANSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A
func _scenario_tests() -> void:
	var sim := _sim([], 10)
	sim.do_d100 = true
	var list: Array = sim.wm1_scenarios()
	var ids: Array = list.map(func(s): return str(s["id"]))
	var script: GDScript = load(SimScript)
	var story: Array = script.get_script_constant_map()["STORY_ORDER"]
	var all_story := true
	for id in story:
		all_story = all_story and ids.has(id)
	check("alle STORY_ORDER-gebieden zijn scenario's", all_story)
	check("extra's: Inktwurm, woudgeest-verhaalstrijd, wereldkaart bos en zand",
			ids.has("inktwurm") and ids.has("woud_story") and ids.has("wereldkaart1_bos") and ids.has("wereldkaart1_zand"))
	check("Archief 2-bazen Wurger en Genezer erbij", ids.has("a2boss_wurger") and ids.has("a2boss_genezer"))
	check("geen _nostun-varianten", ids.filter(func(i): return str(i).ends_with("_nostun")).is_empty())
	check("Diepe Grot standaard erbij (steekproefverdiepingen en bazen)", ids.has("d100_v1") and ids.has("d100_boss_25"))
	sim.do_d100 = false
	check("--no-d100: geen Diepe Grot", (sim.wm1_scenarios() as Array).filter(func(s): return str(s["id"]).begins_with("d100")).is_empty())
	sim.only = ["golem", "inktwurm"]
	check("--only filtert (ook de extra's)", (sim.wm1_scenarios() as Array).size() == 2)
	var wk: Dictionary = {}
	for s in list:
		if str(s["id"]) == "wereldkaart1_bos":
			wk = s
	var bos_has_slijm := false
	for g in wk.get("encounters", []):
		bos_has_slijm = bos_has_slijm or (g["enemies"] as Array).has("mosslijm")
	check("bos-pool heeft geen mosslijm (alleen gras/hoog gras)", not wk.is_empty() and not bos_has_slijm)
	sim.queue_free()


# ================================================================ deel B
func _meting_tests() -> Array:
	var sim := _sim(["wereldkaart1", "golem", "inktwurm", "woud_story"], 20)
	await sim.run_all_wm1()
	var res: Array = sim.results.duplicate(true)
	check("4 gebieden gemeten", res.size() == 4)
	var by_id := {}
	for r in res:
		by_id[str(r["id"])] = r
	var w: Dictionary = by_id.get("wereldkaart1", {})
	var all_n := true
	var sane := true
	for r in res:
		for g in r["groups"]:
			var b: Dictionary = g["base"]
			all_n = all_n and int(b["n"]) == 20
			sane = sane and float(b["win_rate"]) >= 0.0 and float(b["win_rate"]) <= 1.0 and float(b["avg_rounds"]) >= 1.0 \
					and float(b["p90_hp_loss"]) >= float(b["avg_hp_loss"]) - 0.0001 and int(b["timeouts"]) == 0 \
					and float(b["avg_dmg"]) >= 0.0
	check("elke groep precies --fights/--boss-fights gevechten (vast aantal, niet gewogen)", all_n)
	check("getallen kloppen (winkans 0..1, >= 1 ronde, p90 >= gem., geen timeouts, schade >= 0)", sane)
	check("wereldkaart: alle encounter-groepen aanwezig (ook zeldzame)", (w["groups"] as Array).size() >= 8)
	var slijm: Dictionary = _group(w, "Moss Slime")
	var exp_slijm := int(GD.ENEMIES["mosslijm"]["exp"])
	var gold_slijm := int(GD.ENEMIES["mosslijm"]["gold"])
	var enkel: Dictionary = {}
	for g in w["groups"]:
		if (g["enemies"] as Array) == ["mosslijm"]:
			enkel = g
	check("EXP bij winst = EXP uit de vijanddata (1 mosslijm)", not enkel.is_empty() \
			and is_equal_approx(float(enkel["base"]["avg_exp_win"]), float(exp_slijm)))
	check("goud bij winst = goud uit de vijanddata (1 mosslijm)", not enkel.is_empty() \
			and is_equal_approx(float(enkel["base"]["avg_gold_win"]), float(gold_slijm)))
	check("(groepen met mosslijm gevonden)", not slijm.is_empty())
	var ink: Dictionary = (by_id["inktwurm"]["groups"] as Array)[0]
	check("Inktwurm: vaste EXP 60 en goud 40 (unieke beloning, geen tier)",
			is_equal_approx(float(ink["base"]["avg_exp_win"]), 60.0) and is_equal_approx(float(ink["base"]["avg_gold_win"]), 40.0))
	var zaad: Dictionary = (by_id["woud_story"]["groups"] as Array)[0]
	var woudgeest: Dictionary = GD.ENEMIES["woudgeest"]
	check("woudgeest-verhaalstrijd: EXP = 2 x woudgeest", is_equal_approx(float(zaad["base"]["avg_exp_win"]), 2.0 * float(woudgeest["exp"])))
	var golem: Dictionary = (by_id["golem"]["groups"] as Array)[0]
	check("Golem is een baas-groep", bool(golem["boss"]))
	check("rondes tot winst (alleen gewonnen gevechten) bestaat en is >= 1", float(golem["base"]["avg_rounds_win"]) >= 1.0)
	check("Golem: EXP en goud = baas-blok van kennis_beest",
			is_equal_approx(float(golem["base"]["avg_exp_win"]), float(GD.ENEMIES["kennis_beest"]["boss"]["exp"]))
			and is_equal_approx(float(golem["base"]["avg_gold_win"]), float(GD.ENEMIES["kennis_beest"]["boss"]["gold"])))
	check("Golem: schade-teller loopt (> 0) en per ronde > 0", float(golem["base"]["avg_dmg"]) > 0.0 and float(golem["base"]["avg_dmg_round"]) > 0.0)
	check("Golem kost items (genees-waarde > 0)", float(golem["base"]["avg_item_value"]) > 0.0)
	check("level-gevoeligheid: -2..+2 voor de Golem", golem["sens"].has("-2") and golem["sens"].has("-1") \
			and golem["sens"].has("1") and golem["sens"].has("2"))
	check("wereldkaart: gevoeligheid tot +5", (w["groups"] as Array)[0]["sens"].has("5"))
	var hoger := float(golem["sens"]["2"]["win_rate"]) >= float(golem["sens"]["-2"]["win_rate"])
	check("Golem: 2 levels hoger wint minstens zo vaak als 2 levels lager", hoger)
	check("ontwerp-level en gearkosten staan in het resultaat", int(by_id["golem"]["design_level"]) == 8 and int(by_id["golem"]["gear_cost"]) > 0)
	check("speelstand niet in een gevecht blijven hangen", not GameState.in_battle)
	sim.queue_free()
	await get_tree().process_frame
	return res


# ================================================================ deel C
func _determinisme_tests(eerste: Array) -> void:
	var sim := _sim(["wereldkaart1", "golem", "inktwurm", "woud_story"], 20)
	await sim.run_all_wm1()
	check("zelfde seed = exact dezelfde uitkomst", JSON.stringify(sim.results) == JSON.stringify(eerste))
	sim.queue_free()
	await get_tree().process_frame
	var anders := _sim(["wereldkaart1", "golem"], 20)
	anders.base_seed = 4243
	await anders.run_all_wm1()
	var gelijk := JSON.stringify(anders.results) == JSON.stringify(eerste.filter(func(r): return str(r["id"]) in ["wereldkaart1", "golem"]))
	check("andere seed = andere uitkomst", not gelijk)
	anders.queue_free()
	await get_tree().process_frame


# ================================================================ deel D
func _fake_group(boss: bool, win: float, loss: float, rounds: float, sens_win_min1: float = -1.0) -> Dictionary:
	var base := {"n": 100, "win_rate": win, "avg_hp_loss": loss, "p90_hp_loss": loss, "avg_rounds": rounds, "avg_rounds_win": rounds,
		"avg_dmg": 10.0, "avg_dmg_pct": loss, "avg_dmg_round": 1.0, "avg_exp_win": 10.0, "avg_gold_win": 5.0,
		"avg_items": 0.0, "avg_item_value": 0.0}
	var sens := {}
	if sens_win_min1 >= 0.0:
		sens["-1"] = {"win_rate": sens_win_min1, "avg_hp_loss": 0.9}
	return {"label": "x", "boss": boss, "weight": 1, "base": base, "sens": sens}


func _vlag_tests() -> void:
	var sim := _sim([], 1)
	check("gewone groep, gezond: geen vlaggen", (sim.flags_for(_fake_group(false, 1.0, 0.2, 4.0), 0.2) as Array).is_empty())
	check("DEADLY onder 95% winst", (sim.flags_for(_fake_group(false, 0.90, 0.2, 4.0), 0.2) as Array).has("DEADLY"))
	check("HEAVY vanaf 45% HP-verlies", (sim.flags_for(_fake_group(false, 1.0, 0.5, 4.0), 0.5) as Array).has("HEAVY"))
	check("TRIVIAL: < 3% verlies, <= 2 rondes, 100% winst", (sim.flags_for(_fake_group(false, 1.0, 0.01, 1.5), 0.01) as Array).has("TRIVIAL"))
	check("SLOG vanaf 8 rondes", (sim.flags_for(_fake_group(false, 1.0, 0.2, 9.0), 0.2) as Array).has("SLOG"))
	check("SPIKE: >= 2x gebiedsmediaan en >= 25%", (sim.flags_for(_fake_group(false, 1.0, 0.30, 4.0), 0.10) as Array).has("SPIKE"))
	check("geen SPIKE onder 25% verlies", not (sim.flags_for(_fake_group(false, 1.0, 0.2, 4.0), 0.05) as Array).has("SPIKE"))
	check("baas: 85% winst is binnen de doelband", (sim.flags_for(_fake_group(true, 0.85, 0.6, 12.0), 0.0) as Array).is_empty())
	check("BOSS-HARD onder 80%", (sim.flags_for(_fake_group(true, 0.7, 0.6, 12.0), 0.0) as Array).has("BOSS-HARD"))
	check("BOSS-IMPOSSIBLE onder 50%", (sim.flags_for(_fake_group(true, 0.3, 0.6, 12.0), 0.0) as Array).has("BOSS-IMPOSSIBLE"))
	check("BOSS-EASY boven 95%", (sim.flags_for(_fake_group(true, 0.99, 0.2, 12.0), 0.0) as Array).has("BOSS-EASY"))
	check("BOSS-SHORT onder 6 rondes", (sim.flags_for(_fake_group(true, 0.85, 0.6, 3.0), 0.0) as Array).has("BOSS-SHORT"))
	check("BOSS-LONG boven 25 rondes", (sim.flags_for(_fake_group(true, 0.85, 0.6, 30.0), 0.0) as Array).has("BOSS-LONG"))
	check("CLIFF: level-1 geeft >= 25 punten minder winst onder de ondergrens", (sim.flags_for(_fake_group(true, 0.85, 0.6, 12.0, 0.4), 0.0) as Array).has("CLIFF"))
	check("geen CLIFF als level-1 nog ruim winnen is", not (sim.flags_for(_fake_group(true, 0.85, 0.6, 12.0, 0.8), 0.0) as Array).has("CLIFF"))
	var g := _fake_group(true, 0.85, 0.6, 12.0)
	g["sens"] = {"-2": {"win_rate": 0.9}, "-1": {"win_rate": 0.88}, "1": {"win_rate": 0.97}, "2": {"win_rate": 0.99}}
	check("level-venster: -2 is al genoeg", sim.level_window(g) == "-2")
	g["sens"] = {"-2": {"win_rate": 0.1}, "-1": {"win_rate": 0.4}, "1": {"win_rate": 0.97}}
	check("level-venster: 0 (ontwerp-level) is genoeg", sim.level_window(g) == "0")
	g["base"]["win_rate"] = 0.5
	check("level-venster: +1 nodig", sim.level_window(g) == "+1")
	g["sens"] = {"1": {"win_rate": 0.5}, "2": {"win_rate": 0.6}}
	check("level-venster: buiten bereik", sim.level_window(g) == "> +2")
	var r := {"groups": [_fake_group(false, 1.0, 0.1, 2.0), _fake_group(false, 0.8, 0.3, 4.0)]}
	r["groups"][1]["weight"] = 3
	var s: Dictionary = sim.area_summary(r)
	check("gebiedssamenvatting is gewogen (gewicht 1 en 3)", is_equal_approx(float(s["win"]), (1.0 * 1.0 + 3.0 * 0.8) / 4.0) and int(s["fights"]) == 4)
	check("gebiedsmediaan van het verlies", is_equal_approx(float(s["median_loss"]), 0.2))
	check("EXP-level volgt 15 x (level-1)^2", sim._level_for_exp(0.0) == 1 and sim._level_for_exp(15.0) == 2 \
			and sim._level_for_exp(59.0) == 2 and sim._level_for_exp(60.0) == 3 and sim._level_for_exp(735.0) == 8)
	var sc := {"party": [["dennis", 5, ["kort_zwaard", "vonkzwaard", "kaftschild"]], ["noor", 5, ["eiken_staf", "reisgewaad"]]]}
	var verwacht: int = sim.ShopData.list_price("kort_zwaard") + sim.ShopData.list_price("kaftschild") \
			+ sim.ShopData.list_price("eiken_staf") + sim.ShopData.list_price("reisgewaad")
	check("gearkosten: alleen wat de winkel verkoopt (Spark Sword telt niet)", sim._gear_cost(sc) == verwacht and verwacht > 0)
	sim.queue_free()


# ================================================================ deel E
func _rapport_tests() -> void:
	var sim := _sim(["wereldkaart1", "archief1_v1", "golem", "woud"], 12)
	await sim.run_all_wm1()
	var md: String = sim.report_wm1(0)
	for kop in ["### Methode en drempels", "### Samenvatting per gebied", "### EXP-curve tegenover het verwachte level",
			"### Goudcurve", "### Outliers", "### Alle groepen per gebied"]:
		check("rapport heeft sectie: " + kop, md.contains(kop))
	check("rapport heeft de winst op het level van alleen-opruimen en het Woud kamer voor kamer",
			md.contains("### Wat de speler echt heeft") and md.contains("Donker Woud kamer voor kamer") and md.contains("Dark Wood - Wood's Edge"))
	check("rapport noemt de gemeten gebieden", md.contains("First Archive floor 1") and md.contains("BOSS Golem"))
	check("rapport heeft geen Diepe Grot-bijlage zonder Diepe Grot", not md.contains("### Bijlage: Diepe Grot"))
	if FileAccess.file_exists(TEST_REPORT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REPORT))
	sim.out_path = TEST_REPORT
	sim._write_report("EERSTE")
	var t1 := FileAccess.get_file_as_string(TEST_REPORT)
	check("nieuw rapport: generatieblok tussen markeringen", t1.begins_with(sim.GEN_BEGIN) and t1.contains("EERSTE") and t1.contains(sim.GEN_END))
	var met_tekst := "# Kop\nhandgeschreven analyse\n\n" + t1 + "\nhandgeschreven staart\n"
	var f := FileAccess.open(TEST_REPORT, FileAccess.WRITE)
	f.store_string(met_tekst)
	f.close()
	sim._write_report("TWEEDE")
	var t2 := FileAccess.get_file_as_string(TEST_REPORT)
	check("opnieuw genereren: nieuw blok vervangt het oude", t2.contains("TWEEDE") and not t2.contains("EERSTE"))
	check("opnieuw genereren: handgeschreven tekst ervoor en erna blijft staan",
			t2.begins_with("# Kop\nhandgeschreven analyse") and t2.contains("handgeschreven staart"))
	check("markeringen precies één keer", t2.count(sim.GEN_BEGIN) == 1 and t2.count(sim.GEN_END) == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REPORT))
	sim.queue_free()
	await get_tree().process_frame
