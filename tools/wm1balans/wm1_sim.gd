extends "res://tools/battlesim/battlesim.gd"
## WM1-meting met de bestaande battlesim (echte battle.tscn). Geen balansdata, geen CI.
## Zelfde party, uitrusting en seeds als tools/battlesim/battlesim.gd, beperkt tot WM1
## (wereldkaart, Archief 1, Donker Woud, berggrot, Archief 2, Diepe Grot) plus drie
## gevechten die de gebiedslijst niet heeft: de proloogles, de Inktwurm en het Zingend Zaad.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/wm1balans/wm1_main.gd -- \
##       [--seed=N] [--fights=N] [--only=id,id] [--out=pad.md] [--json=pad.json]
## Standaard: seed 20261020, 200 gevechten per encountergroep (elke groep even vaak; niet de
## gewogen steekproef van battlesim.gd). JSON naar tools/wm1balans/wm1_runs.json.

var _tutorial_hook: Dictionary = {}


func _ready() -> void:
	standalone = true
	fights = 200
	base_seed = DEFAULT_SEED
	out_path = "/tmp/wm1_sim_raw.md"
	json_path = "res://tools/wm1balans/wm1_runs.json"
	only = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			base_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--fights="):
			fights = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--only="):
			only = Array(arg.get_slice("=", 1).split(",", false))
		elif arg.begins_with("--out="):
			out_path = arg.get_slice("=", 1)
		elif arg.begins_with("--json="):
			json_path = arg.get_slice("=", 1)
		elif arg == "--trace":
			trace = true
	_main.call_deferred()


func scenarios() -> Array:
	var filter: Array = only.duplicate()
	only = []
	var all: Array = super.scenarios()
	only = filter
	var out: Array = []
	for sc in all:
		var id := str(sc["id"])
		if not _is_wm1(id):
			continue
		if not filter.is_empty() and not filter.has(id):
			continue
		out.append(sc)
	for extra in _extras():
		if filter.is_empty() or filter.has(str(extra["id"])):
			out.append(extra)
	return out


## WM1 volgens docs/BACKLOG_WM1.md: eerste wereld plus de Diepe Grot (ECHO).
## Geen _nostun-varianten: dat is een gevoeligheidsproef, geen encounter.
static func _is_wm1(id: String) -> bool:
	if id.ends_with("_nostun"):
		return false
	if id in ["wereldkaart1", "golem", "woud", "wortelkoning", "berggrot", "lotte"]:
		return true
	return id.begins_with("archief1_") or id.begins_with("archief2_") or id.begins_with("a2boss_") or id.begins_with("d100_")


func _extras() -> Array:
	var woud_gear := ["vonkzwaard", "kaftschild", "ijzeren_helm", "leren_harnas"]
	var a1_late := ["vonkzwaard", "kaftschild", "leren_kap", "leren_harnas"]
	var inv_mid := {"drankje": 5, "toverwater": 2, "kruid": 2}
	return [
		{
			"id": "wm1extra_les",
			"name": "PROLOGUE lesson (Moss Slime, scripted 30 HP)",
			"party": [["dennis", 1, ["kort_zwaard", "leerling_mantel"]]],
			"inv": {},
			"tutorial": {"tutorial": true, "enemy_hp": 30},
			"encounters": [{"enemies": ["mosslijm"], "weight": 1, "boss": false, "tier": 0, "archief": false, "floor": 0}],
			"notes": "story_data.gd les: Dax Lv 1, Short Sword just received, Apprentice Cloak, no bag. Moss Slime max HP forced to 30.",
		},
		{
			"id": "wm1extra_inktwurm",
			"name": "UNIQUE Ink Worm (Golem Hall, after the Golem)",
			"party": [["dennis", 8, a1_late]],
			"inv": inv_mid,
			"kern": true,
			"encounters": [{"enemies": ["inktwurm"], "weight": 1, "boss": false, "tier": 0, "archief": false, "floor": 0}],
			"notes": "Cabinet opens only with the Golem Core (inktwurm_kast.gd). Same party as the Golem fight: Dax Lv 8, Spark Sword. Unique: no tier scaling, stats from GameData.",
		},
		{
			"id": "wm1extra_woudgeest",
			"name": "SIDE Singing Seed (two Wood Wraiths)",
			"party": [["dennis", 12, woud_gear], ["noor", 11, ["eiken_staf", "reisgewaad"]]],
			"inv": inv_mid,
			"kern": true,
			"encounters": [{"enemies": ["woudgeest", "woudgeest"], "weight": 1, "boss": false, "tier": 0, "archief": false, "floor": 0}],
			"notes": "story_data.gd zingend_zaad, after Vesper joins (Dax-1) at the Root King party (Dax Lv 12). Base stats, no wood tier. Oak Staff and Travel Robe are her join gear.",
		},
	]


## Elke encountergroep precies `fights` keer. De gebiedsregel in het rapport is dan het
## ongewogen gemiddelde van de groepen; `weight` blijft het aantal plaatsingen / het gewicht
## op de kaart (alleen ter info, niet om te loten).
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
	GameState.som_mode = bool(sc.get("som", false))
	var groups := _unique_groups(sc["encounters"])
	if standalone:
		print("BATTLESIM %s: %d groups x %d fights" % [sc["id"], groups.size(), fights])
	var snap := _party_snapshot()
	var party_desc := _party_desc()
	var per_group := {}
	var rows: Array = []
	var n := 0
	for g in groups:
		var key := _group_label(g)
		per_group[key] = []
		for i in fights:
			seed(hash([base_seed, str(sc["id"]), key, i]))
			_restore(snap)
			var r := await _fight(sc, g)
			rows.append(r)
			per_group[key].append(r)
			n += 1
			if n % 64 == 0:
				await get_tree().process_frame
	_restore(snap)
	var res := _summarize(rows)
	res["id"] = sc["id"]
	res["name"] = sc["name"]
	res["notes"] = sc.get("notes", "")
	res["party"] = party_desc
	res["inventory"] = snap["inventory"]
	res["groups"] = []
	for g in groups:
		var key := _group_label(g)
		var gs := _summarize(per_group[key])
		gs["label"] = key
		gs["weight"] = int(g.get("weight", 1))
		gs["enemies"] = (g["enemies"] as Array).duplicate()
		res["groups"].append(gs)
	return res


## Zelfde label (zelfde vijanden + tier + verdieping) telt één keer. Gewicht = som van de plaatsingen.
static func _unique_groups(groups: Array) -> Array:
	var out: Array = []
	var seen := {}
	for g in groups:
		var key := ""
		var names: Array = []
		for e in g["enemies"]:
			names.append(str(e))
		key = "%s|%d|%d" % [",".join(names), int(g.get("tier", 0)), int(g.get("floor", 0))]
		if seen.has(key):
			seen[key]["weight"] = int(seen[key]["weight"]) + int(g.get("weight", 1))
			continue
		var copy: Dictionary = g.duplicate(true)
		copy["weight"] = int(g.get("weight", 1))
		seen[key] = copy
		out.append(copy)
	return out


func _fight(sc: Dictionary, g: Dictionary) -> Dictionary:
	_tutorial_hook = sc.get("tutorial", {})
	if holder != null and not holder.child_entered_tree.is_connected(_arm_tutorial):
		holder.child_entered_tree.connect(_arm_tutorial)
	return await super._fight(sc, g)


## battle.gd leest pending_tutorial in _ready. child_entered_tree vuurt vóór _ready.
## Via /root, zodat dit script ook als -s-entrypoint compileert (autoload-naam is dan nog geen identifier).
func _arm_tutorial(_node: Node) -> void:
	if _tutorial_hook.is_empty():
		return
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.pending_tutorial = _tutorial_hook.duplicate(true)
