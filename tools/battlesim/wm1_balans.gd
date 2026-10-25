extends "res://tools/battlesim/battlesim.gd"
## WM1-balansrapport (release fase 5): ELKE encounter en baas van WM1, veel keer gesimuleerd op het
## verwachte party-level en de verwachte uitrusting voor dat punt in het verhaal. Draait de echte
## gevechtsscène via de bestaande simulator (battlesim.gd, sim_battle.gd); alleen NIEUWE bestanden,
## geen gameplay-wijziging en geen bestaande test aangeraakt.
##
## Per encounter-groep (vaste aantallen, niet gewogen willekeurig, zodat ook zeldzame groepen en bazen
## genoeg gevechten krijgen): winkans, rondes, schade aan de party (absoluut en als % party-HP), items,
## EXP en goud bij winst. Daarnaast een level-gevoeligheid: dezelfde gevechten met de hele party 1-2 levels
## lager/hoger. Uit de EXP/goud-getallen komen de EXP-curve (cumulatief, tegenover het verwachte level
## per gebied) en de goudcurve (tegenover de winkelprijzen van de uitrusting die de sim aanneemt).
##
## Starten:
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --wm1balans [--seed=N] [--fights=N]
##            [--boss-fights=N] [--sens-fights=N] [--d100-fights=N] [--only=id,id] [--no-sens] [--no-d100]
##            [--out=pad.md] [--json=pad.json]
## Dezelfde seed + dezelfde code = exact dezelfde getallen. Het rapport krijgt tussen de markeringen
## WM1-GEN-BEGIN/-END alles wat gegenereerd is; de handgeschreven analyse eromheen blijft staan.

const ShopData := preload("res://scripts/data/shop_data.gd")
const Wm1SimBattleScript := "res://tools/battlesim/wm1_sim_battle.gd"
const META := "wm1_extra"       # Engine-meta met de tellers van wm1_sim_battle.gd

const DEFAULT_REPORT := "res://docs/release/WM1_BALANCE_REPORT.md"
const GEN_BEGIN := "<!-- WM1-GEN-BEGIN -->"
const GEN_END := "<!-- WM1-GEN-END -->"

## Verhaalvolgorde van de WM1-gebieden (scenario-id's van battlesim.gd scenarios() + de extra's hieronder).
const STORY_ORDER := ["wereldkaart1", "archief1_v1", "archief1_v2", "archief1_v3", "archief1_v4", "golem", "inktwurm",
		"woud", "woud_story", "wortelkoning", "berggrot", "archief2_v1", "archief2_v2", "lotte",
		"archief2_v3", "archief2_v4", "a2boss_wurger", "a2boss_genezer"]
## Willekeurige-encounter-gebieden: geen "alles opruimen", dus geen deel van de cumulatieve EXP-curve.
const RANDOM_AREAS := ["wereldkaart1", "wereldkaart1_bos", "wereldkaart1_zand"]
const EXTRA_WORLD := {"wereldkaart1_bos": "bos", "wereldkaart1_zand": "zand"}

const SENS_DELTAS := [-3, -2, -1, 1, 2]
const SENS_DELTAS_WORLD := [-2, -1, 1, 2, 3, 4, 5]

## Drempels voor de outlier-vlaggen (zie rapport "Methode en drempels").
const N_WIN_MIN := 0.95            # gewoon gevecht: winst onder 95% = DEADLY
const N_LOSS_HARD := 0.45          # gewoon gevecht: gem. HP-verlies vanaf 45% = HEAVY
const N_LOSS_TRIVIAL := 0.03       # gewoon gevecht: onder 3% HP-verlies en <= 2 rondes = TRIVIAL
const N_ROUNDS_SLOG := 8.0         # gewoon gevecht: gem. rondes vanaf 8 = SLOG
const N_SPIKE := 2.0               # gem. HP-verlies >= 2x de mediaan van het gebied (en >= 25%) = SPIKE
const B_WIN_LO := 0.80             # baas: winst onder 80% = BOSS-HARD (< 50% = BOSS-IMPOSSIBLE)
const B_WIN_HI := 0.95             # baas: winst boven 95% = BOSS-EASY
const B_ROUNDS_SHORT := 6.0        # baas: gem. rondes onder 6 = BOSS-SHORT
const B_ROUNDS_LONG := 25.0        # baas: gem. rondes boven 25 = BOSS-LONG
const CLIFF_DROP := 0.25           # winst op level-1 is >= 25 procentpunt lager en onder de ondergrens = CLIFF
const GRIND_FIGHTS := 30.0         # meer dan 30 gevechten per level (op het ontwerp-level) = GRIND
const FAST_FIGHTS := 2.0           # minder dan 2 gevechten per level = FAST

## Referentieprijs van een genees-item (Handelskamer/Koopman; in WM1 zelf is er geen potionwinkel).
const ITEM_VALUE := {"drankje": 30, "toverwater": 50, "kruid": 20, "kruidenthee": 20, "feniksveer": 200}

var boss_fights := 600
var sens_fights := 100
var d100_fights := 60
var do_sens := true
var do_d100 := true
var _fight_teller := 0
var auto_run := true                    # false = aangeroepen door een test (geen argumenten, geen rapport, geen quit)


func _init() -> void:
	standalone = false
	fights = 300
	out_path = DEFAULT_REPORT


func _ready() -> void:
	if not auto_run:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			base_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--fights="):
			fights = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--boss-fights="):
			boss_fights = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--sens-fights="):
			sens_fights = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--d100-fights="):
			d100_fights = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--only="):
			only = Array(arg.get_slice("=", 1).split(",", false))
		elif arg.begins_with("--out="):
			out_path = arg.get_slice("=", 1)
		elif arg.begins_with("--json="):
			json_path = arg.get_slice("=", 1)
		elif arg == "--no-sens":
			do_sens = false
		elif arg == "--no-d100":
			do_d100 = false
	_main_wm1.call_deferred()


func _main_wm1() -> void:
	var t0 := Time.get_ticks_msec()
	await run_all_wm1()
	var ms := Time.get_ticks_msec() - t0
	_write_report(report_wm1(ms))
	if json_path != "":
		_write(json_path, JSON.stringify(results, "  "))
	print("WM1BALANS written: %s (%d scenarios, %.1fs)" % [out_path, results.size(), ms / 1000.0])
	print("RESULT OK (wm1balans)")
	get_tree().quit(0)


## Alle WM1-scenario's draaien; de uitkomst staat in results.
func run_all_wm1() -> void:
	SimBattle = load(Wm1SimBattleScript)
	BATTLE_SCENE = load(BATTLE_SCENE_PATH)
	holder = Node.new()
	holder.name = "Wm1Holder"
	add_child(holder)
	results = []
	var list := wm1_scenarios()
	if auto_run:
		print("WM1BALANS start: seed %d, %d scenarios, %d fights/group (boss %d, sens %d)" % [
				base_seed, list.size(), fights, boss_fights, sens_fights])
	for sc in list:
		var t1 := Time.get_ticks_msec()
		var r := await run_wm1(sc)
		results.append(r)
		if auto_run:
			print("WM1BALANS %s: %d groups, %d ms" % [sc["id"], (r["groups"] as Array).size(), Time.get_ticks_msec() - t1])
	holder.queue_free()


# =============================================================== scenario's
## WM1 = battlesim-scenario's (zelfde party/uitrusting/tas als het bestaande rapport, dus één bron van
## waarheid) + extra's die dat rapport niet heeft: Inktwurm, de woudgeest-verhaalstrijd, bos/zand-wereldkaart.
func wm1_scenarios() -> Array:
	var keep_only := only
	only = []
	var all: Array = scenarios()
	only = keep_only
	var by_id := {}
	for sc in all:
		if not sc.has("lazy_d100") and not str(sc["id"]).ends_with("_nostun"):
			by_id[str(sc["id"])] = sc
	var out: Array = []
	for id in STORY_ORDER:
		if by_id.has(id):
			out.append(by_id[id])
		elif id == "inktwurm":
			out.append(_inktwurm_scenario(by_id["golem"]))
		elif id == "woud_story":
			out.append(_woud_story_scenario(by_id["woud"]))
	for id in EXTRA_WORLD:
		var w: Dictionary = (by_id["wereldkaart1"] as Dictionary).duplicate(true)
		w["id"] = id
		w["name"] = "Worldmap 1 (%s, random encounters)" % EXTRA_WORLD[id]
		w["encounters"] = _terrain_groups(str(EXTRA_WORLD[id]))
		w["notes"] = "Random-encounter pool for terrain '%s' (rate %d%% per step). Same party as Worldmap 1." % [
				EXTRA_WORLD[id], roundi(float(GameData.ENCOUNTER_RATES.get(EXTRA_WORLD[id], 0.0)) * 100.0)]
		out.append(w)
	if do_d100:
		for f in D100_SAMPLE_FLOORS:
			out.append({"id": "d100_v%d" % f, "lazy_d100": [f, false]})
		for f in Dungeon100Scaling.boss_floors():
			out.append({"id": "d100_boss_%d" % f, "lazy_d100": [int(f), true]})
	if not only.is_empty():
		out = out.filter(func(s): return only.has(s["id"]))
	return out


func _inktwurm_scenario(golem: Dictionary) -> Dictionary:
	return {"id": "inktwurm", "name": "STORY Ink Worm (secret cabinet, First Archive)",
		"party": (golem["party"] as Array).duplicate(true), "inv": (golem["inv"] as Dictionary).duplicate(),
		"encounters": [{"enemies": ["inktwurm"], "weight": 1, "boss": false, "tier": 0, "archief": false, "floor": 0}],
		"notes": "Unique monster (fixed Lv 5 stats, no tier). Fought after the Golem; capture is not modelled, a win = defeated. Dax Lv 8."}


func _woud_story_scenario(woud: Dictionary) -> Dictionary:
	return {"id": "woud_story", "name": "STORY Singing Seed (Dark Wood)",
		"party": (woud["party"] as Array).duplicate(true), "inv": (woud["inv"] as Dictionary).duplicate(),
		"kern": true,
		"encounters": [{"enemies": ["woudgeest", "woudgeest"], "weight": 1, "boss": false, "tier": 0, "archief": false, "floor": 0}],
		"notes": "Scripted story battle (story_data.gd, 'zingend_zaad_na'): 2 Wood Spirits, tier 0. Dax Lv 11 like the Dark Wood."}


## Gelijke groepen (zelfde label) samenvoegen; gewichten tellen op.
func _merge_groups(groups: Array) -> Array:
	var by: Dictionary = {}
	var out: Array = []
	for g in groups:
		var key := _group_label(g)
		if by.has(key):
			by[key]["weight"] = int(by[key]["weight"]) + int(g["weight"])
			continue
		var c: Dictionary = (g as Dictionary).duplicate(true)
		c["label"] = key
		by[key] = c
		out.append(c)
	return out


# =============================================================== simuleren
## Alle groepen van één scenario op het ontwerp-level (delta 0) en, met do_sens, op level +/- delta.
func run_wm1(sc_in: Dictionary) -> Dictionary:
	var sc := sc_in
	if sc.has("lazy_d100"):
		var sid := str(sc["id"])
		sc = _d100_scenario(int(sc["lazy_d100"][0]), bool(sc["lazy_d100"][1]))
		sc["id"] = sid
	var groups := _merge_groups(sc["encounters"])
	var is_random := str(sc["id"]) in RANDOM_AREAS
	var is_d100 := bool(sc.get("d100", false))
	var res := {"id": sc["id"], "name": sc["name"], "notes": sc.get("notes", ""), "d100": is_d100,
		"random": is_random, "groups": [], "design_level": _lead_level(sc), "inventory": sc["inv"],
		"gear_cost": _gear_cost(sc)}
	_build_party(sc)
	res["party"] = _party_desc()
	var deltas: Array = []
	if do_sens and not is_d100:
		deltas = SENS_DELTAS_WORLD if is_random else SENS_DELTAS
	for g in groups:
		var n := d100_fights if is_d100 else (boss_fights if bool(g["boss"]) else fights)
		var entry := {"label": g["label"], "enemies": g["enemies"], "tier": g["tier"], "boss": g["boss"],
			"weight": g["weight"], "base": await _run_group(sc, g, 0, n), "sens": {}}
		for d in deltas:
			var lv_min := _lead_level(sc) + int(d)
			if lv_min < 1:
				continue
			entry["sens"][str(d)] = await _run_group(sc, g, int(d), sens_fights)
		res["groups"].append(entry)
	return res


func _lead_level(sc: Dictionary) -> int:
	return int((sc["party"] as Array)[0][1])


func _shift_party(sc: Dictionary, delta: int) -> Dictionary:
	if delta == 0:
		return sc
	var c: Dictionary = sc.duplicate(true)
	for spec in c["party"]:
		spec[1] = maxi(1, int(spec[1]) + delta)
	return c


func _run_group(sc_in: Dictionary, g: Dictionary, delta: int, n: int) -> Dictionary:
	var sc := _shift_party(sc_in, delta)
	_build_party(sc)
	var snap := _party_snapshot()
	var rows: Array = []
	for i in n:
		seed(hash([base_seed, str(sc["id"]), str(g["label"]), delta, i]))
		_restore(snap)
		Engine.set_meta(META, {"dmg_taken": 0, "dmg_dealt": 0, "exp": 0, "gold": 0})
		var r := await _fight(sc, g)
		var tel: Dictionary = Engine.get_meta(META)
		r["dmg_taken"] = int(tel["dmg_taken"])
		r["exp"] = int(tel["exp"]) if r["win"] else 0
		r["gold"] = int(tel["gold"]) if r["win"] else 0
		r["item_value"] = _item_value(snap["inventory"], GameState.inventory)
		r["max_hp"] = _party_max_hp(sc)
		rows.append(r)
		_fight_teller += 1
		if _fight_teller % 24 == 0:
			await get_tree().process_frame     # vrijgegeven gevechten opruimen; anders loopt de berichtenwachtrij vol
	_restore(snap)
	return _summarize_wm1(rows)


func _party_max_hp(sc: Dictionary) -> int:
	var total := 0
	for h in GameState.party:
		if str(sc.get("filter", "")) != "" and str(h.get("id", "")) != str(sc["filter"]):
			continue
		total += int(h["max_hp"])
	return total


func _item_value(before: Dictionary, after: Dictionary) -> int:
	var v := 0
	for id in before:
		var used := maxi(0, int(before[id]) - int(after.get(id, 0)))
		v += used * int(ITEM_VALUE.get(id, 0))
	return v


func _gear_cost(sc: Dictionary) -> int:
	var total := 0
	var seen := {}
	for spec in sc["party"]:
		for gid in spec[2]:
			var key := "%s:%s" % [spec[0], gid]
			if seen.has(key) or not _in_shop(str(gid)):
				continue
			seen[key] = true
			total += ShopData.list_price(str(gid))
	return total


func _in_shop(id: String) -> bool:
	for sid in ShopData.SHOPS:
		for offer in ShopData.SHOPS[sid].get("offers", []):
			if str(offer.get("id", "")) == id:
				return true
	return false


func _summarize_wm1(rows: Array) -> Dictionary:
	var base := _summarize(rows)
	var n := float(maxi(1, rows.size()))
	var wins := 0
	var dmg := 0.0
	var dmg_pct := 0.0
	var exp_sum := 0.0
	var gold_sum := 0.0
	var val := 0.0
	var dmg_per_round := 0.0
	for r in rows:
		if r["win"]:
			wins += 1
		dmg += float(r["dmg_taken"])
		dmg_pct += float(r["dmg_taken"]) / float(maxi(1, int(r["max_hp"])))
		exp_sum += float(r["exp"])
		gold_sum += float(r["gold"])
		val += float(r["item_value"])
		dmg_per_round += float(r["dmg_taken"]) / float(maxi(1, int(r["rounds"])))
	base["avg_dmg"] = dmg / n
	base["avg_dmg_pct"] = dmg_pct / n
	base["avg_dmg_round"] = dmg_per_round / n
	base["avg_exp_win"] = exp_sum / float(maxi(1, wins))
	base["avg_gold_win"] = gold_sum / float(maxi(1, wins))
	base["avg_item_value"] = val / n
	var win_rounds := 0.0
	for r in rows:
		if r["win"]:
			win_rounds += float(r["rounds"])
	base["avg_rounds_win"] = (win_rounds / float(wins)) if wins > 0 else float(base["avg_rounds"])
	return base


# =============================================================== analyse
func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	var m := s.size() / 2
	return float(s[m]) if s.size() % 2 == 1 else (float(s[m - 1]) + float(s[m])) / 2.0


## Vlaggen per groep (alleen op de ontwerp-level-meting). median_loss = mediaan van het gebied.
func flags_for(g: Dictionary, median_loss: float) -> Array:
	var f: Array = []
	var b: Dictionary = g["base"]
	var win := float(b["win_rate"])
	var loss := float(b["avg_hp_loss"])
	var rounds := float(b["avg_rounds_win"])
	if bool(g["boss"]):
		if win < 0.5:
			f.append("BOSS-IMPOSSIBLE")
		elif win < B_WIN_LO:
			f.append("BOSS-HARD")
		elif win > B_WIN_HI:
			f.append("BOSS-EASY")
		if rounds < B_ROUNDS_SHORT:
			f.append("BOSS-SHORT")
		elif rounds > B_ROUNDS_LONG:
			f.append("BOSS-LONG")
	else:
		if win < N_WIN_MIN:
			f.append("DEADLY")
		if loss >= N_LOSS_HARD:
			f.append("HEAVY")
		if loss < N_LOSS_TRIVIAL and rounds <= 2.0 and win >= 1.0:
			f.append("TRIVIAL")
		if rounds >= N_ROUNDS_SLOG:
			f.append("SLOG")
		if median_loss > 0.0 and loss >= N_SPIKE * median_loss and loss >= 0.25:
			f.append("SPIKE")
	var s1: Dictionary = g["sens"].get("-1", {})
	if not s1.is_empty():
		var lo := B_WIN_LO if bool(g["boss"]) else N_WIN_MIN
		if float(s1["win_rate"]) < lo and win - float(s1["win_rate"]) >= CLIFF_DROP:
			f.append("CLIFF")
	return f


## Kleinste level-delta waarbij de winst op of boven de ondergrens ligt ("" = niet in -2..+2 / +5).
func level_window(g: Dictionary) -> String:
	var lo := B_WIN_LO if bool(g["boss"]) else N_WIN_MIN
	var best := ""
	var keys: Array = [-3, -2, -1, 0, 1, 2, 3, 4, 5]
	for d in keys:
		var s: Dictionary = g["base"] if d == 0 else g["sens"].get(str(d), {})
		if s.is_empty():
			continue
		if float(s["win_rate"]) >= lo:
			best = ("%+d" % d) if d != 0 else "0"
			break
	return best if best != "" else "> +2"


## Gewogen gebiedsgemiddelden (gewicht = hoe vaak de groep in het gebied voorkomt).
func area_summary(r: Dictionary) -> Dictionary:
	var w := 0.0
	var s := {"win": 0.0, "rounds": 0.0, "loss": 0.0, "dmg": 0.0, "dmg_pct": 0.0, "exp": 0.0, "gold": 0.0,
		"items": 0.0, "item_value": 0.0, "clear_exp": 0.0, "clear_gold": 0.0}
	var losses: Array = []
	for g in r["groups"]:
		var gw := float(g["weight"])
		var b: Dictionary = g["base"]
		w += gw
		s["win"] += gw * float(b["win_rate"])
		s["rounds"] += gw * float(b["avg_rounds_win"])
		s["loss"] += gw * float(b["avg_hp_loss"])
		s["dmg"] += gw * float(b["avg_dmg"])
		s["dmg_pct"] += gw * float(b["avg_dmg_pct"])
		s["exp"] += gw * float(b["avg_exp_win"])
		s["gold"] += gw * float(b["avg_gold_win"])
		s["items"] += gw * float(b["avg_items"])
		s["item_value"] += gw * float(b["avg_item_value"])
		s["clear_exp"] += gw * float(b["avg_exp_win"])
		s["clear_gold"] += gw * float(b["avg_gold_win"])
		losses.append(float(b["avg_hp_loss"]))
	for k in ["win", "rounds", "loss", "dmg", "dmg_pct", "exp", "gold", "items", "item_value"]:
		s[k] = s[k] / maxf(1.0, w)
	s["fights"] = int(w)
	s["median_loss"] = _median(losses)
	return s


# =============================================================== rapport
func _write_report(generated: String) -> void:
	var block := GEN_BEGIN + "\n" + generated + "\n" + GEN_END + "\n"
	var p := ProjectSettings.globalize_path(out_path) if out_path.begins_with("res://") else out_path
	var text := block
	if FileAccess.file_exists(p):
		var old := FileAccess.get_file_as_string(p)
		var a := old.find(GEN_BEGIN)
		var b := old.find(GEN_END)
		if a >= 0 and b > a:
			text = old.substr(0, a) + block + old.substr(b + GEN_END.length()).trim_prefix("\n")
	_write(out_path, text)


func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _f1(v: float) -> String:
	return "%.1f" % v


func _level_for_exp(x: float) -> int:
	return 1 + int(floor(sqrt(maxf(0.0, x) / 15.0)))


func _flag_str(f: Array) -> String:
	return ", ".join(f)


func _sens_cell(g: Dictionary, d: int) -> String:
	var s: Dictionary = g["base"] if d == 0 else g["sens"].get(str(d), {})
	if s.is_empty():
		return "-"
	return "%s/%s" % [_pct(float(s["win_rate"])), _pct(float(s["avg_hp_loss"]))]


func report_wm1(ms: int) -> String:
	var L: Array = []
	var wm1: Array = results.filter(func(r): return not bool(r["d100"]))
	var deep: Array = results.filter(func(r): return bool(r["d100"]))
	L.append("## Gegenereerde meting")
	L.append("")
	L.append("Gegenereerd door `tools/battlesim/wm1_balans.gd` (`-- --wm1balans --seed=%d --fights=%d --boss-fights=%d --sens-fights=%d%s`) op Godot %s, looptijd %.0f s." % [
			base_seed, fights, boss_fights, sens_fights, "" if do_d100 else " --no-d100", Engine.get_version_info()["string"], ms / 1000.0])
	L.append("Zelfde seed + zelfde code = dezelfde getallen. Echte `battle.tscn`/`battle.gd`; alleen menu, wachttijden en animaties zijn vervangen")
	L.append("(`sim_battle.gd`, `wm1_sim_battle.gd` telt daarbovenop schade en EXP/goud). Geen gameplay gewijzigd.")
	L.append("")
	var summaries := {}
	for r in results:
		summaries[str(r["id"])] = area_summary(r)
	L.append_array(_section_methode())
	L.append_array(_section_gebieden(wm1, summaries))
	L.append_array(_section_expcurve(wm1, summaries))
	L.append_array(_section_aankomst(wm1))
	L.append_array(_section_goudcurve(wm1, summaries))
	L.append_array(_section_outliers(wm1, summaries))
	L.append_array(_section_per_gebied(wm1, summaries))
	if not deep.is_empty():
		L.append_array(_section_diepe_grot(deep, summaries))
	return "\n".join(L)


func _section_methode() -> Array:
	var L: Array = []
	L.append("### Methode en drempels")
	L.append("")
	L.append("- **Verwacht level en uitrusting** per gebied komen uit het bestaande simulatorrapport (`battlesim.gd scenarios()`): `level_scale.gd` (Act 1 = Lv 1-13, Act 2 = 14-19), `EERSTE_ARCHIEF_DOEL` 7, de Golem op Lv 8 met Spark Sword, Dark Wood Lv 11-12, Vesper op Dax-1, Seren op Dax' level. Beide cijfers staan per gebied in de tabellen.")
	L.append("- **Vaste aantallen per groep** (`--fights` gewone groepen, `--boss-fights` bazen), elk gevecht onafhankelijk met een volle party en de vermelde tas. Gelijke groepen in een gebied zijn samengevoegd; het gewicht = aantal keer dat de groep als map-monster in het gebied staat (wereldkaart: encounter-gewicht).")
	L.append("- **Level-gevoeligheid**: dezelfde gevechten met alle helden 1-2 levels lager of hoger (wereldkaart tot +5), uitrusting gelijk. Cel = `winst / gem. HP-verlies`.")
	L.append("- **HP-verlies** = netto party-HP aan het einde tegenover het begin (inclusief genezing; een KO telt als de hele balk). Op lage levels maskeert potiongebruik dit (kolom Items), dus lees het samen met winst en items. **Schade** = echte directe schade aan de party (DoT telt niet; wel ook wat later weggeheald is), absoluut en als % van de party-max-HP.")
	L.append("- **EXP/goud** = buit bij winst, zoals `battle.gd _victory` (iedere levende held krijgt de volle EXP; EXP wordt niet gedeeld). Item-waarde = verbruikte genees-items x referentieprijs (Drankje 30, Toverwater 50, Kruid 20).")
	L.append("- **Vlaggen gewone groep**: DEADLY = winst < %d%%; HEAVY = gem. HP-verlies >= %d%%; SPIKE = verlies >= %dx de gebiedsmediaan (en >= 25%%); SLOG = gem. >= %d rondes tot winst; TRIVIAL = < %d%% verlies en <= 2 rondes bij 100%% winst." % [
			roundi(N_WIN_MIN * 100), roundi(N_LOSS_HARD * 100), int(N_SPIKE), int(N_ROUNDS_SLOG), roundi(N_LOSS_TRIVIAL * 100)])
	L.append("- **Vlaggen baas** (doelband winst %d-%d%%, zoals PR #208): BOSS-HARD < %d%%, BOSS-IMPOSSIBLE < 50%%, BOSS-EASY > %d%%, BOSS-SHORT < %d rondes tot winst, BOSS-LONG > %d rondes." % [
			roundi(B_WIN_LO * 100), roundi(B_WIN_HI * 100), roundi(B_WIN_LO * 100), roundi(B_WIN_HI * 100), int(B_ROUNDS_SHORT), int(B_ROUNDS_LONG)])
	L.append("- **CLIFF** = op level-1 daalt de winst >= %d procentpunt onder de ondergrens (één level te laag is al een muur). **GRIND** = > %d gevechten per level op het ontwerp-level, **FAST** = < %d." % [
			roundi(CLIFF_DROP * 100), int(GRIND_FIGHTS), int(FAST_FIGHTS)])
	L.append("- **Niet gemodelleerd**: vluchten, verdedigen, Codex-bondgenoten/vangen, mimics, de Koopman, opslaan/rusten tussen gevechten en kist-/verhaalbuit. De sim-AI is eenvoudig (`sim_battle.gd`): een echte speler met slimmer item- en spreukgebruik doet het beter dan de cijfers.")
	L.append("")
	return L


func _section_gebieden(wm1: Array, summaries: Dictionary) -> Array:
	var L: Array = []
	L.append("### Samenvatting per gebied (verhaalvolgorde)")
	L.append("")
	L.append("Gewogen gemiddelden over alle groepen van het gebied op het ontwerp-level. Vlaggen = groepen met een vlag (details in 'Outliers').")
	L.append("")
	L.append("| Gebied | Dax Lv | Groepen | Winst | Rondes tot winst | HP-verlies | Schade/gevecht | Items (waarde) | EXP/gevecht | Goud/gevecht | Gevechten per level | Vlaggen |")
	L.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|")
	for r in wm1:
		var s: Dictionary = summaries[str(r["id"])]
		var lv := int(r["design_level"])
		var need := GameData.exp_for_level(lv + 1) - GameData.exp_for_level(lv)
		var per_level := float(need) / maxf(0.01, float(s["exp"]))
		var flagged := 0
		var all_flags: Array = []
		for g in r["groups"]:
			var fl := flags_for(g, float(s["median_loss"]))
			if not fl.is_empty() and fl != ["TRIVIAL"]:
				flagged += 1
			for x in fl:
				if not all_flags.has(x):
					all_flags.append(x)
		var tag := ""
		if per_level > GRIND_FIGHTS:
			tag = "GRIND"
		elif per_level < FAST_FIGHTS:
			tag = "FAST"
		L.append("| %s | %d | %d | %s | %s | %s | %.0f HP (%s) | %.2f (%d g) | %.1f | %.1f | %.1f %s | %s |" % [
				r["name"], lv, (r["groups"] as Array).size(), _pct(s["win"]), _f1(s["rounds"]), _pct(s["loss"]),
				s["dmg"], _pct(s["dmg_pct"]), s["items"], roundi(s["item_value"]), s["exp"], s["gold"], per_level, tag,
				_flag_str(all_flags)])
	L.append("")
	return L


func _section_expcurve(wm1: Array, summaries: Dictionary) -> Array:
	var L: Array = []
	L.append("### EXP-curve tegenover het verwachte level")
	L.append("")
	L.append("EXP-formule: `15 x (level-1)^2` (`GameData.exp_for_level`). Model: de speler verslaat in verhaalvolgorde **elk map-monster van elk gebied één keer** (geen grinden, geen wereldkaart-gevechten; bazen één keer). Dat is het minimum dat het verhaal oplevert; elk tekort moet worden gegrind (map-monsters komen terug zodra je de kamer opnieuw binnengaat, plus de wereldkaart).")
	L.append("")
	L.append("| Gebied | Ontwerp-Lv Dax | EXP nodig voor dat level | EXP verdiend vóór dit gebied | Tekort / overschot | Level bij alleen opruimen (ervoor) | EXP dit gebied (opruimen) | Level erna | Tekort in gevechten van het vorige gebied |")
	L.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
	var cum := 0.0
	var prev: Dictionary = {}
	var gap_notes: Array = []
	var by_id := {}
	for r in wm1:
		by_id[str(r["id"])] = r
	for id in STORY_ORDER:
		if not by_id.has(id):
			continue
		var r: Dictionary = by_id[id]
		var s: Dictionary = summaries[id]
		var lv := int(r["design_level"])
		var need := GameData.exp_for_level(lv)
		var diff := cum - float(need)
		var clear := float(s["clear_exp"]) if not bool(r["random"]) else 0.0
		var rows_prev := ""
		if diff < 0.0 and not prev.is_empty():
			var ps: Dictionary = summaries[str(prev["id"])]
			rows_prev = "%.0f x %s" % [ceil(-diff / maxf(0.01, float(ps["exp"]))), prev["name"]]
			gap_notes.append("%s: Lv %d vraagt %d EXP, opruimen levert %.0f (tekort %.0f)" % [r["name"], lv, need, cum, -diff])
		L.append("| %s | %d | %d | %.0f | %s | %d | %s | %d | %s |" % [
				r["name"], lv, need, cum, ("%+.0f" % diff), _level_for_exp(cum),
				("willekeurig" if bool(r["random"]) else "%.0f (%d gevechten)" % [clear, int(s["fights"])]),
				_level_for_exp(cum + clear), rows_prev])
		cum += clear
		prev = r
	L.append("")
	L.append("Het eindlevel bij alleen opruimen is Lv %d (%.0f EXP); het laatste ontwerp-level is Lv %d." % [
			_level_for_exp(cum), cum, int(by_id[STORY_ORDER[STORY_ORDER.size() - 1]]["design_level"]) if by_id.has(STORY_ORDER[STORY_ORDER.size() - 1]) else 0])
	L.append("")
	L.append("**Gevechten per level op het ontwerp-level** (EXP die nodig is voor het volgende level gedeeld door de gemiddelde EXP per gevecht in het gebied):")
	L.append("")
	L.append("| Gebied | Lv | EXP naar volgend level | Gem. EXP/gevecht | Gevechten per level | Gem. gevechtsduur (rondes) |")
	L.append("|---|---:|---:|---:|---:|---:|")
	for r in wm1:
		var s: Dictionary = summaries[str(r["id"])]
		var lv := int(r["design_level"])
		var need := GameData.exp_for_level(lv + 1) - GameData.exp_for_level(lv)
		L.append("| %s | %d | %d | %.1f | %.1f | %.1f |" % [r["name"], lv, need, s["exp"], float(need) / maxf(0.01, float(s["exp"])), s["rounds"]])
	L.append("")
	return L


## Gewogen winst/verlies van een gebied op ontwerp-level + delta (leeg als die delta niet gemeten is).
func area_at_delta(r: Dictionary, d: int) -> Dictionary:
	var w := 0.0
	var win := 0.0
	var loss := 0.0
	var rounds := 0.0
	var worst := 2.0
	var worst_label := ""
	for g in r["groups"]:
		var s: Dictionary = g["base"] if d == 0 else g["sens"].get(str(d), {})
		if s.is_empty():
			return {}
		var gw := float(g["weight"])
		w += gw
		win += gw * float(s["win_rate"])
		loss += gw * float(s["avg_hp_loss"])
		rounds += gw * float(s["avg_rounds"])
		if float(s["win_rate"]) < worst:
			worst = float(s["win_rate"])
			worst_label = str(g["label"])
	return {"win": win / w, "loss": loss / w, "rounds": rounds / w, "worst": worst, "worst_label": worst_label}


func _cell_at(r: Dictionary, lv: int) -> String:
	var d := lv - int(r["design_level"])
	var a := area_at_delta(r, d)
	if a.is_empty():
		return "buiten bereik"
	return "%s / %s (slechtste: %s)" % [_pct(a["win"]), _pct(a["loss"]), _pct(a["worst"])]


func _section_aankomst(wm1: Array) -> Array:
	var L: Array = []
	L.append("### Wat de speler echt heeft: winst op het level van alleen-opruimen")
	L.append("")
	L.append("Het ontwerp-level van de gebieden is een aanname; de EXP-curve hierboven laat zien welk level je hebt als je het verhaal zonder grinden speelt. Hier staat dezelfde meting op dat level: **aankomst** = level bij het binnenkomen, **einde** = level na het opruimen van het gebied. Cel = `winst / HP-verlies (slechtste groep)`; `buiten bereik` = meer dan 3 levels onder of 2 boven het ontwerp-level.")
	L.append("")
	L.append("Let op: een gebied dat zelf veel EXP geeft (het Donker Woud) wordt hier op één level gemeten; de kamer-voor-kamer-tabel eronder is nauwkeuriger voor het Woud.")
	L.append("")
	L.append("| Gebied | Ontwerp-Lv | Aankomst-Lv | Winst op aankomst | Einde-Lv | Winst aan het einde |")
	L.append("|---|---:|---:|---|---:|---|")
	var cum := 0.0
	var woud_cum := -1.0
	for id in STORY_ORDER:
		var r: Dictionary = {}
		for x in wm1:
			if str(x["id"]) == id:
				r = x
		if r.is_empty():
			continue
		if id == "woud":
			woud_cum = cum
		var s: Dictionary = area_summary(r)
		var arr := _level_for_exp(cum)
		var clear := float(s["clear_exp"]) if not bool(r["random"]) else 0.0
		var end := _level_for_exp(cum + clear)
		if bool(r["random"]):
			continue
		L.append("| %s | %d | %d | %s | %d | %s |" % [r["name"], int(r["design_level"]), arr, _cell_at(r, arr), end, _cell_at(r, end)])
		cum += clear
	L.append("")
	if woud_cum >= 0.0:
		L.append_array(_section_woud_pad(wm1, woud_cum))
	return L


## Het Donker Woud kamer voor kamer: het level stijgt tijdens het opruimen (de kamers geven samen 1464 EXP), dus elke
## kamer wordt gemeten op het level dat je met alleen-opruimen op dat moment hebt.
func _section_woud_pad(wm1: Array, cum_start: float) -> Array:
	var L: Array = []
	var wood: Dictionary = {}
	for x in wm1:
		if str(x["id"]) == "woud":
			wood = x
	if wood.is_empty():
		return L
	var by_label := {}
	for g in wood["groups"]:
		by_label[str(g["label"])] = g
	L.append("**Donker Woud kamer voor kamer** (volgorde `WoudRooms.ORDER`, EXP uit de kamers zelf, start met de EXP van de gebieden ervoor):")
	L.append("")
	L.append("| Kamer | Niveau | Monsters | EXP kamer | Level bij binnenkomst | Winst op dat level | HP-verlies | Slechtste groep |")
	L.append("|---|---:|---:|---:|---:|---|---|---|")
	var cum := cum_start
	for e in WoudRooms.ORDER:
		var room: Dictionary = WoudRooms.ROOMS[str(e[0])]
		var lv := _level_for_exp(cum)
		var d := lv - int(wood["design_level"])
		var win := 0.0
		var loss := 0.0
		var n := 0
		var exp_room := 0.0
		var worst := 2.0
		var worst_label := ""
		var measured := true
		var cnt := 0
		for m in room.get("monsters", []):
			if bool(m.get("boss", false)):
				continue
			cnt += 1
			var label := _group_label({"enemies": (m.get("group", [m["enemy"]]) as Array), "tier": int(room.get("tier", 0))})
			if not by_label.has(label):
				continue
			var g: Dictionary = by_label[label]
			var s: Dictionary = g["base"] if d == 0 else g["sens"].get(str(d), {})
			exp_room += float(g["base"]["avg_exp_win"])
			if s.is_empty():
				measured = false
				continue
			n += 1
			win += float(s["win_rate"])
			loss += float(s["avg_hp_loss"])
			if float(s["win_rate"]) < worst:
				worst = float(s["win_rate"])
				worst_label = "%s (%s)" % [label, _pct(float(s["win_rate"]))]
		if cnt == 0:
			continue
		if measured and n > 0:
			L.append("| %s | %d | %d | %.0f | %d | %s | %s | %s |" % [room["name"], int(room.get("tier", 0)), cnt, exp_room, lv,
					_pct(win / n), _pct(loss / n), worst_label])
		else:
			L.append("| %s | %d | %d | %.0f | %d | buiten bereik | | |" % [room["name"], int(room.get("tier", 0)), cnt, exp_room, lv])
		cum += exp_room
	L.append("")
	return L


func _shop_totals() -> Dictionary:
	var act1 := 0
	var act2 := 0
	for sid in ShopData.SHOPS:
		var shop: Dictionary = ShopData.SHOPS[sid]
		if bool(shop.get("magic", false)) or str(sid) == "handelskamer":
			continue
		for offer in shop.get("offers", []):
			var price: int = ShopData._offer_price(offer)
			if int(offer.get("min_act", 1)) <= 1:
				act1 += price
			else:
				act2 += price
	return {"act1": act1, "act2": act2}


func _section_goudcurve(wm1: Array, summaries: Dictionary) -> Array:
	var L: Array = []
	var tot := _shop_totals()
	L.append("### Goudcurve")
	L.append("")
	L.append("Zelfde model als de EXP-curve (elk map-monster één keer). Uitgaven: de winkelstukken uit de uitrusting die de sim voor dat gebied aanneemt (alleen wat Wilgendal verkoopt, `shop_data.gd`; Spark Sword, smeedspullen en kistvondsten kosten niets), spreuken (`160 x grade^2`, de winkel verkoopt per act tot grade = act, max 3) en een referentiewaarde voor verbruikte genees-items. In WM1 zijn potions niet te koop (alleen vondsten); de itemwaarde laat zien wat de gevechten aan voorraad opslokken.")
	L.append("")
	L.append("Winkelaanbod uitrusting (zonder magie en Handelskamer): Act 1 = %d g, Act 2 erbij = %d g. Spreuk grade 1 = 160 g, grade 2 = 640 g, grade 3 = 1440 g." % [int(tot["act1"]), int(tot["act2"])])
	L.append("")
	L.append("| Gebied | Goud dit gebied (opruimen) | Cumulatief goud | Kosten winkeluitrusting van de party | Items verbruikt per gevecht (waarde) | Goud per gevecht | Netto goud per gevecht | Gevechten per spreuk grade 1 (160 g) | per spreuk grade 2 (640 g) |")
	L.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
	var cum := 0.0
	var by_id := {}
	for r in wm1:
		by_id[str(r["id"])] = r
	var order: Array = STORY_ORDER.duplicate()
	for id in EXTRA_WORLD:
		order.append(id)
	for id in order:
		if not by_id.has(id):
			continue
		var r: Dictionary = by_id[id]
		var s: Dictionary = summaries[id]
		var rnd := bool(r["random"])
		var clear := float(s["clear_gold"]) if not rnd else 0.0
		cum += clear
		var net := float(s["gold"]) - float(s["item_value"])
		var f1 := "%.0f" % ceil(160.0 / net) if net > 0.5 else "nooit"
		var f2 := "%.0f" % ceil(640.0 / net) if net > 0.5 else "nooit"
		L.append("| %s | %s | %s | %d | %.2f (%d g) | %.1f | %.1f | %s | %s |" % [r["name"],
				("willekeurig" if rnd else "%.0f" % clear), ("-" if rnd else "%.0f" % cum), int(r["gear_cost"]),
				s["items"], roundi(s["item_value"]), s["gold"], net, f1, f2])
	L.append("")
	L.append("Winkelprijzen ter referentie (`ShopData.list_price`): Short Sword 120, Wooden Shield 40, Cover Shield 90, Leather Hood 30, Leather Armor 70, Iron Helm 80, Oak Staff 90, Travel Robe 30.")
	L.append("")
	return L


func _section_outliers(wm1: Array, summaries: Dictionary) -> Array:
	var L: Array = []
	L.append("### Outliers (per encounter-groep, ontwerp-level)")
	L.append("")
	L.append("Alle groepen met een vlag, behalve TRIVIAL (die staat per gebied geteld in de laatste kolom). Sensitiviteit: kleinste level-delta (t.o.v. het ontwerp-level) waarbij de winst op de ondergrens ligt (`0` = ontwerp-level, `-1` = één level lager nog genoeg).")
	L.append("")
	L.append("| Gebied | Groep | n | Winst | Rondes tot winst | HP-verlies (p90) | Schade | EXP | Goud | Level-venster | Vlaggen |")
	L.append("|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|")
	var any := false
	var trivial_counts: Array = []
	for r in wm1:
		var s: Dictionary = summaries[str(r["id"])]
		var triv := 0
		for g in r["groups"]:
			var fl := flags_for(g, float(s["median_loss"]))
			if fl.has("TRIVIAL"):
				triv += 1
				fl.erase("TRIVIAL")
			if fl.is_empty():
				continue
			any = true
			var b: Dictionary = g["base"]
			L.append("| %s | %s%s | %d | %s | %s | %s (%s) | %.0f (%s) | %.1f | %.1f | %s | %s |" % [r["name"], g["label"],
					" [BOSS]" if bool(g["boss"]) else "", b["n"], _pct(b["win_rate"]), _f1(b["avg_rounds_win"]), _pct(b["avg_hp_loss"]),
					_pct(b["p90_hp_loss"]), b["avg_dmg"], _pct(b["avg_dmg_pct"]), b["avg_exp_win"], b["avg_gold_win"], level_window(g), _flag_str(fl)])
		if triv > 0:
			trivial_counts.append("%s: %d van %d" % [r["name"], triv, (r["groups"] as Array).size()])
	if not any:
		L.append("| - | geen | | | | | | | | | |")
	L.append("")
	L.append("TRIVIAL-groepen (per gebied): " + ("; ".join(trivial_counts) if not trivial_counts.is_empty() else "geen") + ".")
	L.append("")
	return L


func _section_per_gebied(wm1: Array, summaries: Dictionary) -> Array:
	var L: Array = []
	L.append("### Alle groepen per gebied")
	L.append("")
	L.append("Kolommen `Lv-2`..`Lv+2` (wereldkaart tot `Lv+5`) = `winst / HP-verlies` met de hele party dat aantal levels lager/hoger. `Schade` = gemiddelde directe schade aan de party per gevecht (en als % van de party-max-HP); `Sch./ronde` = schade per ronde.")
	for r in wm1:
		var s: Dictionary = summaries[str(r["id"])]
		L.append("")
		L.append("#### %s (`%s`)" % [r["name"], r["id"]])
		L.append("")
		L.append("- Party: %s" % r["party"])
		L.append("- Tas: %s" % JSON.stringify(r["inventory"]))
		L.append("- Aanname: %s" % r["notes"])
		L.append("")
		var deltas: Array = SENS_DELTAS_WORLD if bool(r["random"]) else SENS_DELTAS
		var head := "| Groep | Gew. | n | Winst | Rondes tot winst | HP-verlies | p90 | Schade | Sch./ronde | Items | EXP | Goud |"
		var sep := "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
		if do_sens:
			for d in deltas:
				head += " Lv%+d |" % d
			head += " Venster |"
			sep += "---:|".repeat(deltas.size()) + "---|"
		head += " Vlaggen |"
		sep += "---|"
		L.append(head)
		L.append(sep)
		for g in r["groups"]:
			var b: Dictionary = g["base"]
			var row := "| %s%s | %d | %d | %s | %s | %s | %s | %.0f (%s) | %.1f | %.2f | %.1f | %.1f |" % [g["label"], " [BOSS]" if bool(g["boss"]) else "",
					g["weight"], b["n"], _pct(b["win_rate"]), _f1(b["avg_rounds_win"]), _pct(b["avg_hp_loss"]), _pct(b["p90_hp_loss"]),
					b["avg_dmg"], _pct(b["avg_dmg_pct"]), b["avg_dmg_round"], b["avg_items"], b["avg_exp_win"], b["avg_gold_win"]]
			if do_sens:
				for d in deltas:
					row += " %s |" % _sens_cell(g, int(d))
				row += " %s |" % level_window(g)
			row += " %s |" % _flag_str(flags_for(g, float(s["median_loss"])))
			L.append(row)
	L.append("")
	return L


func _section_diepe_grot(deep: Array, summaries: Dictionary) -> Array:
	var L: Array = []
	L.append("### Bijlage: Diepe Grot (100 verdiepingen, via ECHO)")
	L.append("")
	L.append("Steekproef van verdiepingen en alle canon-baasverdiepingen, %d gevechten per groep, geen level-gevoeligheid (het level volgt de verdieping: Lv = 5 + 0,4 x verdieping, zie `battlesim.gd d100_level`). Zelfde vlaggen als hierboven.\n" % d100_fights)
	L.append("| Verdieping | Party | Groepen | Winst | Rondes tot winst | HP-verlies | Schade | Items (waarde) | EXP/gevecht | Goud/gevecht | Vlaggen |")
	L.append("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|")
	for r in deep:
		var s: Dictionary = summaries[str(r["id"])]
		var all_flags: Array = []
		for g in r["groups"]:
			for x in flags_for(g, float(s["median_loss"])):
				if not all_flags.has(x):
					all_flags.append(x)
		L.append("| %s | Lv %d | %d | %s | %s | %s | %.0f (%s) | %.2f (%d g) | %.1f | %.1f | %s |" % [r["name"], int(r["design_level"]),
				(r["groups"] as Array).size(), _pct(s["win"]), _f1(s["rounds"]), _pct(s["loss"]), s["dmg"], _pct(s["dmg_pct"]),
				s["items"], roundi(s["item_value"]), s["exp"], s["gold"], _flag_str(all_flags)])
	L.append("")
	return L
