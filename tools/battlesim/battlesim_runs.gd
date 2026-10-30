extends Node
## Battle simulator per run (CSV). Eén regel per gevecht in user://sim/, om de balans te meten.
## Gestart via --battlesim zodra een van de run-argumenten erbij staat (zie battlesim.gd _ready):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --battlesim --party=dennis:5,noor:5
##            --enemy=all --runs=100 --seed=1 --policy=simpel [--tier=N] [--items=drankje:3,kruid:2] [--out=pad.csv]
## Rapport: python3 tools/battlesim/rapport.py [csv ...]
## WM1-overzicht (1000 gevechten verdeeld over WM1-groepen, winrate per vijand):
##   ... -- --battlesim --party=dennis:5,noor:5 --enemy=all --total=1000 --seed=7 --out=pad.csv
## --total=N verdeelt precies N gevechten om de beurt over de (niet-baas) groepen. Baasgroepen uit
## ENCOUNTER_GROUPS (nu baas_kennis_beest) vallen buiten die pool en worden apart gemeten met het
## bedoelde scenario (zelfde party als battlesim.gd `golem`: Dax solo Lv 8, Vonkzwaard). Alleen met
## --total of --summary komen ook <pad>_per_enemy.csv en <pad>_per_enemy.md.
##
## Elk gevecht is de echte scenes/battle/battle.tscn. GameState.prepare_battle zet de vijanden
## (hetzelfde deel van start_battle dat het spel gebruikt); alleen het menu, wachten en het einde
## zijn vervangen (sim_battle.gd, policy_simpel.gd). Dezelfde seed + dezelfde code = dezelfde CSV.

const GameData := preload("res://scripts/data/game_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const Equipment := preload("res://scripts/equipment.gd")
## Zelfde aannames als battlesim.gd scenario `golem` (Golem Hall / kennis_beest baas).
const GOLEM_BOSS_GEAR := ["vonkzwaard", "kaftschild", "leren_kap", "leren_harnas"]
const GOLEM_BOSS_INV := {"drankje": 5, "toverwater": 2, "kruid": 2}
const GOLEM_BOSS_LEVEL := 8
const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const POLICIES := {
	"simpel": "res://tools/battlesim/policy_simpel.gd",
	"standaard": "res://tools/battlesim/sim_battle.gd",
}
const RUN_ARGS := ["--party=", "--enemy=", "--runs=", "--policy=", "--total="]
const SIM_DIR := "user://sim"
const CSV_HEADER := ["seed", "policy", "party", "group_id", "enemies", "tier", "run", "result", "win",
	"turns", "hero_actions", "hp_left", "hp_max", "hp_left_pct", "kos", "mp_used", "items_used", "items_detail"]
const ENEMY_HEADER := ["enemy", "fights", "wins", "losses", "winrate_pct", "avg_turns", "avg_hp_left_pct", "groups"]

var party_spec := "dennis:5"
var enemy_spec := "all"
var runs := 100
var base_seed := 1
var policy := "simpel"
var tier := 0
var items_spec := ""
var out_path := ""
var total := 0                  # > 0: precies zoveel gevechten verdeeld (--total gaat boven --runs)
var summary_path := ""          # zonder extensie; leeg = <csv-pad zonder .csv>_per_enemy
var total_given := false
var standalone := true          # false = aangeroepen door een test (geen quit)
var quiet := false

var errors: Array[String] = []
var rows: Array[Dictionary] = []
var boss_rows: Array[Dictionary] = []   # baasgevechten met bedoeld scenario (niet in per_enemy-pool)
var written_path := ""
var written_summary := ""
var enemy_stats: Array[Dictionary] = []
var _battle_scene: PackedScene
var _policy_script: Script
var _holder: Node


## true als de argumenten om de CSV-modus vragen (en niet om het oude gebiedsrapport).
static func wants_runs(args: PackedStringArray) -> bool:
	for a in args:
		for p in RUN_ARGS:
			if a.begins_with(p):
				return true
	return false


func _ready() -> void:
	if not standalone:
		return
	configure(OS.get_cmdline_user_args())
	_main.call_deferred()


func configure(args: PackedStringArray) -> void:
	for arg in args:
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--party="):
			party_spec = v
		elif arg.begins_with("--enemy="):
			enemy_spec = v
		elif arg.begins_with("--runs="):
			runs = int(v)
		elif arg.begins_with("--seed="):
			base_seed = int(v)
		elif arg.begins_with("--policy="):
			policy = v
		elif arg.begins_with("--tier="):
			tier = int(v)
		elif arg.begins_with("--items="):
			items_spec = v
		elif arg.begins_with("--out="):
			out_path = v
		elif arg.begins_with("--total="):
			total = int(v)
			total_given = true
		elif arg.begins_with("--summary="):
			summary_path = v


func _main() -> void:
	var t0 := Time.get_ticks_msec()
	var csv := await run()
	if not errors.is_empty():
		for e in errors:
			printerr("BATTLESIM ERROR: " + e)
		get_tree().quit(2)
		return
	print("BATTLESIM csv: %s (%d rows, seed %d, policy %s, %.1fs)" % [
			ProjectSettings.globalize_path(written_path), rows.size(), base_seed, policy, (Time.get_ticks_msec() - t0) / 1000.0])
	if not quiet:
		print("\n".join(csv.split("\n").slice(0, 6)))
	if written_summary != "":
		print("BATTLESIM per enemy: %s(.csv|.md)" % ProjectSettings.globalize_path(written_summary))
	print("RESULT OK (battlesim)")
	get_tree().quit(0)


# =============================================================== invoer
## "dennis:5,noor:4" -> [["dennis", 5], ["noor", 4]] (level standaard 1). Fout = errors.
func parse_party(spec: String) -> Array:
	var out: Array = []
	var known: Array = GameData.HEROES.map(func(h): return str(h["id"]))
	for part in spec.split(",", false):
		var id := part.get_slice(":", 0).strip_edges()
		var lv := int(part.get_slice(":", 1)) if part.contains(":") else 1
		if not known.has(id):
			errors.append("unknown hero '%s' (known: %s)" % [id, ", ".join(known)])
			continue
		if lv < 1 or lv > 99:
			errors.append("level for '%s' must be 1..99" % id)
			continue
		out.append([id, lv])
	if out.is_empty() and errors.is_empty():
		errors.append("--party is empty")
	if not out.is_empty() and str(out[0][0]) != GameState.MAIN_HERO:
		errors.append("--party must start with '%s' (the main hero is always in the party)" % GameState.MAIN_HERO)
	return out


## Groep-id's, komma-gescheiden:
##   all          = elke groep uit GameData.ENCOUNTER_GROUPS
##   enc<N>       = GameData.ENCOUNTER_GROUPS[N]
##   <id>         = groep met dat "id" (bv. baas_kennis_beest)
##   a+b+c        = losse vijand-id's als groep (ook kamermonsters, bv. mech_wachter+papiergeest)
## Elke groep: {"id", "enemies", "boss"}.
func parse_groups(spec: String) -> Array:
	var out: Array = []
	var groups: Array = GameData.ENCOUNTER_GROUPS
	for tok in spec.split(",", false):
		tok = tok.strip_edges()
		if tok == "all":
			for i in groups.size():
				out.append(_group_from(i))
		elif tok.begins_with("enc") and tok.substr(3).is_valid_int():
			var i := int(tok.substr(3))
			if i < 0 or i >= groups.size():
				errors.append("enemy group '%s' does not exist (enc0..enc%d)" % [tok, groups.size() - 1])
			else:
				out.append(_group_from(i))
		else:
			var found := -1
			for i in groups.size():
				if str(groups[i].get("id", "")) == tok:
					found = i
			if found >= 0:
				out.append(_group_from(found))
				continue
			var ids := Array(tok.split("+", false))
			var bad := ids.filter(func(e): return not _enemy_known(str(e)))
			if ids.is_empty() or not bad.is_empty():
				errors.append("unknown enemy group or enemy '%s'" % tok)
				continue
			out.append({"id": tok, "enemies": ids, "boss": false})
	if out.is_empty() and errors.is_empty():
		errors.append("--enemy is empty")
	return out


func _group_from(i: int) -> Dictionary:
	var g: Dictionary = GameData.ENCOUNTER_GROUPS[i]
	return {"id": str(g.get("id", "enc%d" % i)), "enemies": (g["enemies"] as Array).duplicate(),
			"boss": bool(g.get("boss", false))}


static func _enemy_known(id: String) -> bool:
	return GameData.ENEMIES.has(id) or BerggrotData.has_enemy(id)


## "drankje:3,kruid:2" -> {"drankje": 3, "kruid": 2}; leeg = GameData.START_INVENTORY.
func parse_items(spec: String) -> Dictionary:
	if spec == "":
		return GameData.START_INVENTORY.duplicate(true)
	var out := {}
	for part in spec.split(",", false):
		var id := part.get_slice(":", 0).strip_edges()
		if not GameData.ITEMS.has(id):
			errors.append("unknown item '%s'" % id)
			continue
		out[id] = maxi(0, int(part.get_slice(":", 1)) if part.contains(":") else 1)
	return out


# =============================================================== simuleren
## Alle runs voor alle groepen; geeft de CSV-tekst terug (en schrijft hem naar user://sim/).
func run() -> String:
	errors.clear()
	rows.clear()
	boss_rows.clear()
	enemy_stats.clear()
	written_summary = ""
	var party := parse_party(party_spec)
	var groups := parse_groups(enemy_spec)
	var bag := parse_items(items_spec)
	if runs < 1:
		errors.append("--runs must be >= 1")
	if total_given and total <= 0:
		errors.append("--total must be >= 1")
	if not POLICIES.has(policy):
		errors.append("unknown policy '%s' (known: %s)" % [policy, ", ".join(POLICIES.keys())])
	if not errors.is_empty():
		return ""
	_battle_scene = load(BATTLE_SCENE_PATH)
	_policy_script = load(POLICIES[policy])
	_holder = Node.new()
	_holder.name = "BattlesimRunsHolder"
	add_child(_holder)
	var snap := _build_party(party, bag)
	var party_label := ";".join(party.map(func(p): return "%s:%d" % [p[0], p[1]]))
	var wm1_overview := enemy_spec.strip_edges() == "all" and (total_given or summary_path != "")
	var regular: Array = groups
	var bosses: Array = []
	if wm1_overview:
		regular = groups.filter(func(g): return not bool(g.get("boss", false)))
		bosses = groups.filter(func(g): return bool(g.get("boss", false)))
	var n := 0
	var full_n := groups.size()
	for g_idx in regular.size():
		var g: Dictionary = regular[g_idx]
		var count := runs if total <= 0 else _split_total(total, regular.size(), g_idx)
		for i in count:
			_restore(snap)
			seed(hash([base_seed, str(g["id"]), i]))
			var r := await _fight(g)
			r.merge({"seed": base_seed, "policy": policy, "party": party_label, "group_id": g["id"],
					"enemies": "+".join(g["enemies"]), "tier": 0 if g["boss"] else tier, "run": i})
			rows.append(r)
			n += 1
			if n % 64 == 0:
				await get_tree().process_frame
	if wm1_overview and not bosses.is_empty() and total > 0:
		var boss_snap := _build_golem_boss_snap()
		var boss_party_label := "dennis:%d (golem scenario)" % GOLEM_BOSS_LEVEL
		for g in bosses:
			var orig_idx := _group_index(groups, g)
			var count := _split_total(total, full_n, orig_idx)
			for i in count:
				_restore(boss_snap)
				seed(hash([base_seed, "boss_scenario", str(g["id"]), i]))
				var r := await _fight(g)
				r.merge({"seed": base_seed, "policy": policy, "party": boss_party_label, "group_id": g["id"],
						"enemies": "+".join(g["enemies"]), "tier": 0, "run": i})
				boss_rows.append(r)
				n += 1
				if n % 64 == 0:
					await get_tree().process_frame
	_restore(snap)
	_holder.queue_free()
	var csv := to_csv(rows)
	written_path = out_path if out_path != "" else "%s/battlesim_%s_s%d.csv" % [SIM_DIR, policy, base_seed]
	_write(written_path, csv)
	enemy_stats = per_enemy(rows)
	if total_given or summary_path != "":
		written_summary = summary_path if summary_path != "" else written_path.trim_suffix(".csv") + "_per_enemy"
		_write(written_summary + ".csv", to_csv(enemy_stats, ENEMY_HEADER))
		_write(written_summary + ".md", to_markdown(enemy_stats, rows, party_label))
	return csv


## Verdeelt total gevechten over n groepen (groep k krijgt k, k+n, k+2n, ...).
static func _split_total(total_fights: int, n: int, index: int) -> int:
	if n <= 0:
		return 0
	return int(total_fights / n) + (1 if index < total_fights % n else 0)


static func _group_index(groups: Array, target: Dictionary) -> int:
	var tid := str(target.get("id", ""))
	for i in groups.size():
		if str(groups[i].get("id", "")) == tid:
			return i
	return 0


static func _use_golem_party_for_boss(group_id: String) -> bool:
	return group_id == "baas_kennis_beest"


func _build_golem_boss_snap() -> Dictionary:
	return _build_party_geared([["dennis", GOLEM_BOSS_LEVEL, GOLEM_BOSS_GEAR]], GOLEM_BOSS_INV)


## Party via de echte GameState-code (new_game, join_member -> give_exp = normale groei).
func _build_party(party: Array, bag: Dictionary) -> Dictionary:
	var specs: Array = []
	for p in party:
		specs.append([p[0], p[1], []])
	return _build_party_geared(specs, bag)


func _build_party_geared(party: Array, bag: Dictionary) -> Dictionary:
	GameState.new_game(GameState.DEFAULT_NAME)
	GameState.codex_reset(false)
	for spec in party:
		var id := str(spec[0])
		var lv := int(spec[1])
		var gear: Array = spec[2] if spec.size() > 2 else []
		if not GameState.has_member(id):
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
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	GameState.inventory = bag.duplicate(true)
	GameState.pending_tutorial = {}
	GameState.archief2_party_filter = ""
	GameState.archief2_temp_ally = {}
	GameState.pending_story_loss = false
	GameState.dungeon100_floor = 0
	return {"party": GameState.party.duplicate(true), "inventory": GameState.inventory.duplicate(true)}


func _restore(snap: Dictionary) -> void:
	GameState.party = (snap["party"] as Array).duplicate(true)
	GameState.inventory = (snap["inventory"] as Dictionary).duplicate(true)


func _fight(g: Dictionary) -> Dictionary:
	GameState.prepare_battle((g["enemies"] as Array).duplicate(), "", bool(g["boss"]), tier)
	var hp_start := 0
	var hp_max := 0
	var mp_start := 0
	for h in GameState.party:
		hp_start += int(h["hp"])
		hp_max += int(h["max_hp"])
		mp_start += int(h["mp"])
	var inv_before := GameState.inventory.duplicate(true)
	var b: Control = _battle_scene.instantiate()
	b.set_script(_policy_script)
	_holder.add_child(b)
	if b.sim_result == "":
		b._run()
	if b.sim_result == "":
		await b.sim_done
	var hp_left := 0
	var kos := 0
	for h in GameState.party:
		hp_left += maxi(0, int(h["hp"]))
		if int(h["hp"]) <= 0:
			kos += 1
	var used := {}
	var items := 0
	for id in inv_before:
		var d := maxi(0, int(inv_before[id]) - GameState.item_count(id))
		if d > 0:
			used[id] = d
			items += d
	var ids := used.keys()
	ids.sort()
	var actions := 0
	for k in b.sim_actions:
		actions += int(b.sim_actions[k])
	var r := {"result": b.sim_result, "win": 1 if b.sim_result == "win" else 0, "turns": b.sim_rounds,
		"hero_actions": actions, "hp_left": hp_left, "hp_max": hp_max,
		"hp_left_pct": snappedf(100.0 * hp_left / float(maxi(1, hp_max)), 0.1), "kos": kos,
		"mp_used": b.sim_mp_used, "items_used": items,
		"items_detail": ";".join(ids.map(func(id): return "%s:%d" % [id, used[id]]))}
	_holder.remove_child(b)
	b.queue_free()
	for i in 3:
		await get_tree().process_frame
	return r


# =============================================================== per vijand
static func per_enemy(list: Array) -> Array[Dictionary]:
	var acc := {}
	for r in list:
		var seen := {}
		for e in str(r["enemies"]).split("+", false):
			if seen.has(e):
				continue
			seen[e] = true
			if not acc.has(e):
				acc[e] = {"enemy": e, "fights": 0, "wins": 0, "turns": 0, "hp": 0.0, "groups": {}}
			var a: Dictionary = acc[e]
			a["fights"] += 1
			a["wins"] += int(r["win"])
			a["turns"] += int(r["turns"])
			a["hp"] += float(r["hp_left_pct"])
			a["groups"][str(r["group_id"])] = true
	var out: Array[Dictionary] = []
	for e in acc:
		var a: Dictionary = acc[e]
		var f := float(a["fights"])
		var gids: Array = a["groups"].keys()
		gids.sort()
		out.append({"enemy": e, "fights": a["fights"], "wins": a["wins"], "losses": a["fights"] - a["wins"],
				"winrate_pct": snappedf(100.0 * a["wins"] / f, 0.1), "avg_turns": snappedf(a["turns"] / f, 0.1),
				"avg_hp_left_pct": snappedf(a["hp"] / f, 0.1), "groups": ";".join(gids)})
	out.sort_custom(func(x, y): return x["winrate_pct"] < y["winrate_pct"] \
			or (x["winrate_pct"] == y["winrate_pct"] and str(x["enemy"]) < str(y["enemy"])))
	return out


static func _summarize_fights(list: Array) -> Dictionary:
	var n := list.size()
	if n == 0:
		return {"n": 0, "winrate_pct": 0.0, "avg_turns": 0.0, "avg_hp_left_pct": 0.0, "avg_items": 0.0}
	var wins := 0
	var turns := 0.0
	var hp := 0.0
	var items := 0.0
	for r in list:
		wins += int(r["win"])
		turns += float(r["turns"])
		hp += float(r["hp_left_pct"])
		items += float(r["items_used"])
	var f := float(n)
	return {"n": n, "winrate_pct": snappedf(100.0 * wins / f, 0.1), "avg_turns": snappedf(turns / f, 0.1),
			"avg_hp_left_pct": snappedf(hp / f, 0.1), "avg_items": snappedf(items / f, 0.2)}


func to_markdown(stats: Array, list: Array, party_label: String) -> String:
	var wins := 0
	for r in list:
		wins += int(r["win"])
	var md: Array[String] = ["# Battle simulator — winrate per enemy", "",
		"- seed: `%d`, policy: `%s`, party: `%s`, tier: %d" % [base_seed, policy, party_label, tier],
		"- enemy groups: `%s`, fights (regular pool): %d, total winrate: %.1f%%" % [enemy_spec, list.size(),
				100.0 * wins / float(maxi(1, list.size()))], ""]
	if enemy_spec.strip_edges() == "all" and (total_given or summary_path != ""):
		md.append("- WM1 pool: encounter groups **without** boss rows (`boss: true` in `ENCOUNTER_GROUPS`).")
		md.append("- `kennis_beest` averages here are **only** random/map groups; the Golem boss is listed below.")
		md.append("")
	md += ["## Per enemy", "", "| enemy | fights | wins | winrate | avg turns | avg HP left |", "|---|---:|---:|---:|---:|---:|"]
	for s in stats:
		md.append("| %s | %d | %d | %.1f%% | %.1f | %.1f%% |" % [s["enemy"], s["fights"], s["wins"],
				s["winrate_pct"], s["avg_turns"], s["avg_hp_left_pct"]])
	md += ["", "## Per group (regular pool)", "", "| group | enemies | fights | winrate |", "|---|---|---:|---:|"]
	var order: Array = []
	var g := {}
	for r in list:
		var id := str(r["group_id"])
		if not g.has(id):
			g[id] = [str(r["enemies"]), 0, 0]
			order.append(id)
		g[id][1] += 1
		g[id][2] += int(r["win"])
	for id in order:
		md.append("| %s | %s | %d | %.1f%% |" % [id, g[id][0], g[id][1], 100.0 * g[id][2] / float(g[id][1])])
	if not boss_rows.is_empty():
		md += ["", "## Boss (intended party, matches `battlesim.gd` golem scenario)", "",
				"Dax solo Lv %d, Spark Sword + late Act-1 gear, bag %s." % [GOLEM_BOSS_LEVEL, str(GOLEM_BOSS_INV)], "",
				"| group | enemies | fights | winrate | avg turns | avg HP left | avg items |", "|---|---|---:|---:|---:|---:|---:|"]
		var by_group := {}
		var boss_order: Array = []
		for r in boss_rows:
			var id := str(r["group_id"])
			if not by_group.has(id):
				by_group[id] = []
				boss_order.append(id)
			by_group[id].append(r)
		for id in boss_order:
			var s: Dictionary = _summarize_fights(by_group[id])
			var enemies := str(by_group[id][0]["enemies"])
			md.append("| %s | %s | %d | %.1f%% | %.1f | %.1f%% | %.2f |" % [
					id, enemies, s["n"], s["winrate_pct"], s["avg_turns"], s["avg_hp_left_pct"], s["avg_items"]])
	return "\n".join(md) + "\n"


# =============================================================== CSV
static func to_csv(list: Array, header: Array = CSV_HEADER) -> String:
	var lines: Array[String] = [",".join(header)]
	for r in list:
		var cells: Array[String] = []
		for col in header:
			cells.append(csv_cell(r.get(col, "")))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


static func csv_cell(v: Variant) -> String:
	var s := ("%.1f" % v) if typeof(v) == TYPE_FLOAT else str(v)
	if s.contains(",") or s.contains("\"") or s.contains("\n"):
		s = "\"%s\"" % s.replace("\"", "\"\"")
	return s


func _write(path: String, text: String) -> void:
	var p := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		errors.append("cannot write %s" % p)
		return
	f.store_string(text)
	f.close()
