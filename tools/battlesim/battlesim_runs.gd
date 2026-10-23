extends Node
## Battle simulator per run (CSV). Eén regel per gevecht in user://sim/, om de balans te meten.
## Gestart via --battlesim zodra een van de run-argumenten erbij staat (zie battlesim.gd _ready):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --battlesim --party=dennis:5,noor:5
##            --enemy=all --runs=100 --seed=1 --policy=simpel [--tier=N] [--items=drankje:3,kruid:2] [--out=pad.csv]
## Rapport: python3 tools/battlesim/rapport.py [csv ...]
##
## Elk gevecht is de echte scenes/battle/battle.tscn. GameState.prepare_battle zet de vijanden
## (hetzelfde deel van start_battle dat het spel gebruikt); alleen het menu, wachten en het einde
## zijn vervangen (sim_battle.gd, policy_simpel.gd). Dezelfde seed + dezelfde code = dezelfde CSV.

const GameData := preload("res://scripts/data/game_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const POLICIES := {
	"simpel": "res://tools/battlesim/policy_simpel.gd",
	"standaard": "res://tools/battlesim/sim_battle.gd",
}
const RUN_ARGS := ["--party=", "--enemy=", "--runs=", "--policy="]
const SIM_DIR := "user://sim"
const CSV_HEADER := ["seed", "policy", "party", "group_id", "enemies", "tier", "run", "result", "win",
	"turns", "hero_actions", "hp_left", "hp_max", "hp_left_pct", "kos", "mp_used", "items_used", "items_detail"]

var party_spec := "dennis:5"
var enemy_spec := "all"
var runs := 100
var base_seed := 1
var policy := "simpel"
var tier := 0
var items_spec := ""
var out_path := ""
var standalone := true          # false = aangeroepen door een test (geen quit)
var quiet := false

var errors: Array[String] = []
var rows: Array[Dictionary] = []
var written_path := ""
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
	var party := parse_party(party_spec)
	var groups := parse_groups(enemy_spec)
	var bag := parse_items(items_spec)
	if runs < 1:
		errors.append("--runs must be >= 1")
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
	var n := 0
	for g in groups:
		for i in runs:
			_restore(snap)
			seed(hash([base_seed, str(g["id"]), i]))
			var r := await _fight(g)
			r.merge({"seed": base_seed, "policy": policy, "party": party_label, "group_id": g["id"],
					"enemies": "+".join(g["enemies"]), "tier": 0 if g["boss"] else tier, "run": i})
			rows.append(r)
			n += 1
			if n % 64 == 0:
				await get_tree().process_frame     # vrijgegeven gevechten echt opruimen
	_restore(snap)
	_holder.queue_free()
	var csv := to_csv(rows)
	written_path = out_path if out_path != "" else "%s/battlesim_%s_s%d.csv" % [SIM_DIR, policy, base_seed]
	_write(written_path, csv)
	return csv


## Party via de echte GameState-code (new_game, join_member -> give_exp = normale groei).
func _build_party(party: Array, bag: Dictionary) -> Dictionary:
	GameState.new_game(GameState.DEFAULT_NAME)
	GameState.codex_reset(false)
	for p in party:
		var id := str(p[0])
		var lv := int(p[1])
		if not GameState.has_member(id):
			GameState.join_member(id, lv, [])
		var h: Dictionary = GameState.member(id)
		if lv > int(h["level"]):
			GameState.give_exp(h, GameData.exp_for_level(lv) - int(h["exp"]))
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
	return r


# =============================================================== CSV
static func to_csv(list: Array) -> String:
	var lines: Array[String] = [",".join(CSV_HEADER)]
	for r in list:
		var cells: Array[String] = []
		for col in CSV_HEADER:
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
