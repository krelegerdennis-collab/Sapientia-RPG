extends Node
## Headless ACTION-gevechtssimulator (SoM-proef, PR #129). Simuleert realtime kamergevechten in de
## SoM-kamers (SomData.ROOMS) met de echte party (GameState._build_som_state), echte vijand-data
## (archief-tier), de arena-formules (SomArena.physical_damage / charge_mult) en spreuken (SpellRules).
## Tijdstap 1/60 s; de beweging is geabstraheerd (aanlooptijd, telegraaf, ontwijkkans).
## Bazen blijven turn-based: die gaan door de bestaande battlesim (tools/battlesim/battlesim.gd).
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --actionsim [--fights=N] [--seed=N]
##            [--boss-fights=N] [--out=pad.md] [--only-final]
## Elke iteratie in ITERATIONS overschrijft een paar parameters (basis = SomData). Dezelfde seed = dezelfde getallen.

const SomData := preload("res://scripts/data/som_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
const BATTLESIM_PATH := "res://tools/battlesim/battlesim.gd"

const DT := 1.0 / 30.0
const MAX_TIME := 240.0
## Doelen (feedback Dennis): gewone gevechten 10-20% HP, bazen 60-80% winst.
const TARGET_LOSS := [0.10, 0.20]
const TARGET_BOSS := [0.60, 0.80]

## Iteraties: label + overschreven parameters (zie params_base()). Gekozen: "CHOSEN" (staat in SomData).
const ITERATIONS := [
	{"label": "v2.1 baseline", "set": {"charge_time": 0.5, "floor": 0.25, "anim_lock": false, "enemy_cd": 1.6, "telegraph": 0.55, "enemy_dmg": 1.0, "ally_spell_cd": 2.5}},
	{"label": "SoM gauge (refill after swing) + 10% floor", "set": {"charge_time": 0.5, "floor": 0.1, "anim_lock": true, "enemy_cd": 1.6, "telegraph": 0.55, "enemy_dmg": 1.0, "ally_spell_cd": 2.5}},
	{"label": "gauge 1.0 s", "set": {"charge_time": 1.0, "floor": 0.1, "anim_lock": true, "enemy_cd": 1.6, "telegraph": 0.55, "enemy_dmg": 1.0, "ally_spell_cd": 2.5}},
	{"label": "gauge 1.0 s, enemy dmg x1.6", "set": {"charge_time": 1.0, "floor": 0.1, "anim_lock": true, "enemy_cd": 1.6, "telegraph": 0.55, "enemy_dmg": 1.6, "ally_spell_cd": 2.5}},
	{"label": "gauge 1.0 s, dmg x1.6, cd 1.2 s, tele 0.45 s", "set": {"charge_time": 1.0, "floor": 0.1, "anim_lock": true, "enemy_cd": 1.2, "telegraph": 0.45, "enemy_dmg": 1.6, "ally_spell_cd": 2.5}},
	{"label": "gauge 0.9 s, dmg x1.8, cd 1.3 s, tele 0.5 s", "set": {"charge_time": 0.9, "floor": 0.1, "anim_lock": true, "enemy_cd": 1.3, "telegraph": 0.5, "enemy_dmg": 1.8, "ally_spell_cd": 2.5}},
	{"label": "gauge 1.0 s, dmg x2.2, cd 1.2 s, tele 0.45 s (CHOSEN = SomData)", "set": {"charge_time": 1.0, "floor": 0.1, "anim_lock": true, "enemy_cd": 1.2, "telegraph": 0.45, "enemy_dmg": 2.2, "ally_spell_cd": 2.5}},
	{"label": "gauge 1.0 s, dmg x2.0, cd 1.1 s, tele 0.45 s, ally spell cd 3 s", "set": {"charge_time": 1.0, "floor": 0.1, "anim_lock": true, "enemy_cd": 1.1, "telegraph": 0.45, "enemy_dmg": 2.0, "ally_spell_cd": 3.0}},
	{"label": "gauge 1.0 s, dmg x2.4, cd 1.2 s, tele 0.45 s, ally spell cd 3 s", "set": {"charge_time": 1.0, "floor": 0.1, "anim_lock": true, "enemy_cd": 1.2, "telegraph": 0.45, "enemy_dmg": 2.4, "ally_spell_cd": 3.0}},
]

var fights := 200
var boss_fights := 300
var base_seed := 20261020
var out_path := "res://docs/ACTION_BALANCE_REPORT.md"
var only_final := false
var standalone := true
var rooms: Array = []         # [{id, tier, enemies: [data...]}]
var party_base: Array = []
var results: Array = []
var boss_results: Array = []


func _ready() -> void:
	if not standalone:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fights="):
			fights = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--boss-fights="):
			boss_fights = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed="):
			base_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--out="):
			out_path = arg.get_slice("=", 1)
		elif arg == "--only-final":
			only_final = true
	_main.call_deferred()


func _main() -> void:
	var t0 := Time.get_ticks_msec()
	await run_all()
	var md := report_markdown(Time.get_ticks_msec() - t0)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(md)
		f.close()
	print("ACTIONSIM report: ", out_path)
	get_tree().quit(0)


static func params_base() -> Dictionary:
	return {
		"charge_time": SomData.CHARGE_TIME, "floor": SomData.CHARGE_MIN_MULT, "anim_lock": SomData.CHARGE_AFTER_ANIM,
		"enemy_cd": SomData.ATTACK_COOLDOWN, "telegraph": SomData.TELEGRAPH, "enemy_dmg": SomData.ENEMY_DAMAGE_MULT,
		"iframes": SomData.PLAYER_IFRAMES, "ally_spell_cd": SomData.ALLY_SPELL_CD, "ally_heal_below": SomData.ALLY_HEAL_BELOW,
		"ally_dmg_chance": SomData.ALLY_DAMAGE_SPELL_CHANCE,
		# speler-/AI-model (geen speldata): aanloop per vijand, ontwijkkans tijdens een telegraaf, gelijktijdige vijanden
		"approach": 1.2, "dodge_player": 0.35, "dodge_ally": 0.15, "wave": 2, "anim": 0.71, "policy": "patient",
	}


func setup() -> void:
	GameState._build_som_state()
	party_base = GameState.party.duplicate(true)
	rooms = []
	for rid in SomData.ROOMS:
		var r: Dictionary = DungeonRooms.room(rid)
		var tier := int(r.get("tier", 0))
		var list: Array = []
		for m in r.get("monsters", []):
			if bool(m.get("boss", false)):
				continue
			var d: Dictionary = (GameData.ENEMIES.get(str(m["enemy"]), {}) as Dictionary).duplicate(true)
			if d.is_empty():
				continue
			if tier > 0 and not bool(d.get("unique", false)):
				d = GameData.apply_archief_tier(d, tier)
			d["id"] = str(m["enemy"])
			list.append(d)
		rooms.append({"id": rid, "tier": tier, "enemies": list})


func run_all() -> void:
	setup()
	results = []
	var its: Array = ITERATIONS
	if only_final:
		its = [ITERATIONS[ITERATIONS.size() - 1]]
	for i in its.size():
		var p := params_base()
		for k in its[i]["set"]:
			p[k] = its[i]["set"][k]
		var res := run_iteration(p)
		res["label"] = its[i]["label"]
		res["params"] = p
		var spam := p.duplicate()
		spam["policy"] = "spam"
		var rs := run_iteration(spam, maxi(1, fights / 4))
		res["spam_loss"] = rs["loss"]
		res["spam_time"] = rs["time"]
		results.append(res)
		if standalone:
			print("ACTIONSIM it%d %s: loss %.1f%% (p90 %.1f%%), win %.1f%%, %.1f s/room; spam: loss %.1f%%, %.1f s" % [
				i + 1, its[i]["label"], res["loss"] * 100.0, res["p90"] * 100.0, res["win"] * 100.0, res["time"],
				rs["loss"] * 100.0, rs["time"]])
	await _bosses()
	GameState.party = party_base.duplicate(true)


## Alle SoM-kamers 'n' keer (vol HP per kamer). Geeft gemiddelden.
func run_iteration(p: Dictionary, n := -1) -> Dictionary:
	if n < 0:
		n = fights
	var losses: Array = []
	var wins := 0
	var time := 0.0
	var per_room := {}
	for r in rooms:
		var rl: Array = []
		for i in n:
			seed(hash([base_seed, str(r["id"]), i, str(p["policy"])]))
			var out := fight_room(r["enemies"], p)
			losses.append(out["loss"])
			rl.append(out["loss"])
			time += float(out["time"])
			if out["win"]:
				wins += 1
		per_room[r["id"]] = _mean(rl)
		if standalone and OS.get_cmdline_user_args().has("--verbose"):
			print("ACTIONSIM   room %s: loss %.1f%% (%d fights, t=%d ms)" % [r["id"], _mean(rl) * 100.0, n, Time.get_ticks_msec()])
	losses.sort()
	return {"loss": _mean(losses), "p90": losses[int(losses.size() * 0.9)] if not losses.is_empty() else 0.0,
		"win": float(wins) / float(maxi(1, losses.size())), "time": time / float(maxi(1, losses.size())), "rooms": per_room}


static func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(maxi(1, a.size()))


## Eén kamer: party (vol) tegen alle map-monsters, hoogstens p.wave tegelijk actief.
func fight_room(enemy_list: Array, p: Dictionary) -> Dictionary:
	var party: Array = party_base.duplicate(true)
	var heroes: Array = []
	var max_total := 0
	for h in party:
		max_total += int(h["max_hp"])
		heroes.append({"h": h, "id": str(h["id"]), "charge": 1.0, "lock": 0.0, "walk": float(p["approach"]) * 0.5,
			"iframes": 0.0, "spell_cd": 1.0, "atk": float(GameState.effective_stat(h, "atk")),
			"def": float(GameState.effective_stat(h, "def"))})
	var queue: Array = []
	for d in enemy_list:
		queue.append({"d": d, "hp": int(d["max_hp"]), "approach": float(p["approach"]), "tele": 0.0, "cd": randf_range(0.2, 0.8),
			"stun": 0.0, "target": -1})
	var active: Array = []
	var t := 0.0
	while t < MAX_TIME:
		while active.size() < int(p["wave"]) and not queue.is_empty():
			active.append(queue.pop_front())
		if active.is_empty():
			break
		var alive := heroes.filter(func(x): return int(x["h"]["hp"]) > 0)
		if alive.is_empty():
			break
		t += DT
		# helden (0 = bestuurde held; de AI-bondgenoten gebruiken dezelfde meter-regel, wachten op 100%)
		for hi in heroes.size():
			var hr: Dictionary = heroes[hi]
			if int(hr["h"]["hp"]) <= 0:
				continue
			hr["iframes"] = maxf(0.0, float(hr["iframes"]) - DT)
			if float(hr["lock"]) > 0.0:
				hr["lock"] = float(hr["lock"]) - DT
			if float(hr["lock"]) <= 0.0 or not bool(p["anim_lock"]):
				hr["charge"] = minf(1.0, float(hr["charge"]) + DT / float(p["charge_time"]))
			if float(hr["walk"]) > 0.0:
				hr["walk"] = float(hr["walk"]) - DT
				continue
			# spreuken (bondgenoten: Seren geneest < drempel, Vesper Spark met kans)
			if hi > 0:
				hr["spell_cd"] = float(hr["spell_cd"]) - DT
				if float(hr["spell_cd"]) <= 0.0:
					hr["spell_cd"] = float(p["ally_spell_cd"])
					_ally_spell(hr, heroes, active, p)
			var want_swing := float(hr["lock"]) <= 0.0 and (float(hr["charge"]) >= 1.0 or (hi == 0 and str(p["policy"]) == "spam"))
			if want_swing:
				var e: Dictionary = active[randi() % active.size()] if hi > 0 else active[0]
				if float(e["approach"]) > 0.0:
					continue
				var c := float(hr["charge"])
				var mult := SomArena.charge_mult_with(c, float(p["floor"]))
				var dmg := SomArena.physical_damage(float(hr["atk"]), float(e["d"]["def"]), mult)
				e["hp"] = int(e["hp"]) - dmg
				if c >= 1.0 or not bool(p["anim_lock"]):
					e["tele"] = 0.0          # volle slag: telegraaf afgebroken + knockback
					e["stun"] = SomData.KNOCKBACK_TIME + 0.15
				hr["charge"] = 0.0
				hr["lock"] = float(p["anim"])        # een nieuwe slag pas na de animatie
				hr["walk"] = 0.25 if hi > 0 else 0.1      # bijsturen naar het doel
		# vijanden
		for e in active.duplicate():
			if int(e["hp"]) <= 0:
				active.erase(e)
				continue
			if float(e["approach"]) > 0.0:
				e["approach"] = float(e["approach"]) - DT
				continue
			if float(e["stun"]) > 0.0:
				e["stun"] = float(e["stun"]) - DT
				continue
			if float(e["tele"]) > 0.0:
				e["tele"] = float(e["tele"]) - DT
				if float(e["tele"]) <= 0.0:
					e["cd"] = float(p["enemy_cd"])
					var hr: Dictionary = heroes[int(e["target"])]
					var dodge := float(p["dodge_player"]) if int(e["target"]) == 0 else float(p["dodge_ally"])
					if int(hr["h"]["hp"]) > 0 and float(hr["iframes"]) <= 0.0 and randf() >= dodge:
						var dmg := roundi(SomArena.physical_damage(float(e["d"]["atk"]), float(hr["def"]), 1.0) * float(p["enemy_dmg"]))
						hr["h"]["hp"] = maxi(0, int(hr["h"]["hp"]) - maxi(1, dmg))
						hr["iframes"] = float(p["iframes"])
				continue
			if float(e["cd"]) > 0.0:
				e["cd"] = float(e["cd"]) - DT
				continue
			var tgt := _enemy_target(heroes)
			if tgt < 0:
				break
			e["target"] = tgt
			e["tele"] = float(p["telegraph"])
	var end_hp := 0
	for h in party:
		end_hp += int(h["hp"])
	var win := queue.is_empty() and active.filter(func(x): return int(x["hp"]) > 0).is_empty()
	return {"win": win, "loss": float(max_total - end_hp) / float(maxi(1, max_total)), "time": t}


## Vijand kiest de bestuurde held (50%) of een willekeurig levend partylid (zoals _target_for: dichtstbij).
static func _enemy_target(heroes: Array) -> int:
	var alive: Array = []
	for i in heroes.size():
		if int(heroes[i]["h"]["hp"]) > 0:
			alive.append(i)
	if alive.is_empty():
		return -1
	if int(heroes[0]["h"]["hp"]) > 0 and randf() < 0.5:
		return 0
	return int(alive[randi() % alive.size()])


func _ally_spell(hr: Dictionary, heroes: Array, active: Array, p: Dictionary) -> void:
	var h: Dictionary = hr["h"]
	var lvl := int(h.get("level", 1))
	for s in h.get("spells", []):
		var sp: Dictionary = GameData.SPELLS.get(str(s), {})
		if sp.is_empty() or int(h["mp"]) < int(sp.get("mp", 0)):
			continue
		if str(sp.get("type", "")) == "heal":
			var low: Dictionary = {}
			var lr := float(p["ally_heal_below"])
			for o in heroes:
				var r := float(o["h"]["hp"]) / maxf(1.0, float(o["h"]["max_hp"]))
				if int(o["h"]["hp"]) > 0 and r < lr:
					lr = r
					low = o["h"]
			if low.is_empty():
				continue
			h["mp"] = int(h["mp"]) - int(sp["mp"])
			var amt := roundi(SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, str(h["id"]), {}))
			low["hp"] = mini(int(low["max_hp"]), int(low["hp"]) + amt)
			return
		if str(sp.get("type", "")) == "damage" and randf() < float(p["ally_dmg_chance"]) and not active.is_empty():
			h["mp"] = int(h["mp"]) - int(sp["mp"])
			var targets: Array = active if str(sp.get("target", "")) == "all_enemies" else [active[0]]
			for e in targets:
				var amt := SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, str(h["id"]), {"s": e["d"]})
				e["hp"] = int(e["hp"]) - maxi(1, roundi(amt * randf_range(0.9, 1.1)))
			return


## Baas-iteraties (Action-modus, SomData.ACTION_BOSS_MULT). Classic = zonder vermenigvuldiger (referentie).
const BOSS_ITERATIONS := [
	{"label": "Classic (no multiplier)", "classic": true},
	{"label": "flat HP x1.5", "mult": {"max_hp": 1.5}, "per_level": {}},
	{"label": "flat HP x2.0, ATK x1.5", "mult": {"max_hp": 2.0, "atk": 1.5}, "per_level": {}},
	{"label": "flat HP x2.5, ATK x1.7", "mult": {"max_hp": 2.5, "atk": 1.7}, "per_level": {}},
	{"label": "flat HP x3.0, ATK x1.8", "mult": {"max_hp": 3.0, "atk": 1.8}, "per_level": {}},
	{"label": "flat HP x2.5, ATK x2.2", "mult": {"max_hp": 2.5, "atk": 2.2}, "per_level": {}},
	{"label": "flat HP x5.0, ATK x1.2", "mult": {"max_hp": 5.0, "atk": 1.2}, "per_level": {}},
	{"label": "level-scaled: HP x2.5, ATK x1.7 +0.25/lv", "mult": {"max_hp": 2.5, "atk": 1.7}, "per_level": {"atk": 0.25}},
	{"label": "level-scaled: HP x2.4, ATK x1.65 +0.25/lv", "mult": {"max_hp": 2.4, "atk": 1.65}, "per_level": {"atk": 0.25}},
	{"label": "level-scaled: HP x2.2, ATK x1.55 +0.30/lv", "mult": {"max_hp": 2.2, "atk": 1.55}, "per_level": {"atk": 0.3}},
	{"label": "level-scaled: HP x2.3, ATK x1.6 +0.35/lv (CHOSEN = SomData)", "mult": {}, "per_level": {}},
]

## Bazen (turn-based): bestaande battlesim met de SoM-startparty (Lv 3) en met Lv 5, per baas-iteratie.
func _bosses() -> void:
	boss_results = []
	if boss_fights <= 0 or not ResourceLoader.exists(BATTLESIM_PATH):
		return
	var bs: Node = load(BATTLESIM_PATH).new()
	bs.standalone = false
	bs.fights = boss_fights
	bs.base_seed = base_seed
	add_child(bs)
	bs.SimBattle = load(bs.SIM_BATTLE_PATH)
	bs.BATTLE_SCENE = load(bs.BATTLE_SCENE_PATH)
	bs.holder = Node.new()
	bs.add_child(bs.holder)
	var inv: Dictionary = SomData.START_ITEMS.duplicate()
	var was_som: bool = GameState.som_mode
	var its: Array = BOSS_ITERATIONS
	if only_final:
		its = [BOSS_ITERATIONS[0], BOSS_ITERATIONS[BOSS_ITERATIONS.size() - 1]]
	for it in its:
		var classic := bool(it.get("classic", false))
		var chosen := not classic and (it["mult"] as Dictionary).is_empty()
		SomData.action_boss_override = {} if classic or chosen else {"mult": it["mult"], "per_level": it["per_level"]}
		var row := {"label": it["label"], "classic": classic, "m3": SomData.action_boss_mult(SomData.START_LEVEL),
			"m5": SomData.action_boss_mult(SomData.START_LEVEL + 2), "levels": []}
		for lv in [SomData.START_LEVEL, SomData.START_LEVEL + 2]:
			GameState.som_mode = not classic
			var gear: Array = SomData.START_GEAR
			var sc := {"id": "som_golem_lv%d" % lv, "name": "BOSS Golem vs SoM party Lv %d" % lv,
				"party": [["dennis", lv, gear], ["noor", lv, []], ["lotte", lv, []]], "inv": inv, "som": not classic,
				"encounters": bs._room_groups(DungeonRooms.ROOMS, -1, true, true)}
			var r: Dictionary = await bs.run_scenario(sc)
			r["level"] = lv
			row["levels"].append(r)
			if standalone:
				print("ACTIONSIM boss [%s] Lv %d: win %.1f%%, HP loss %.1f%%, rounds %s" % [it["label"], lv, float(r.get("win_rate", 0.0)) * 100.0,
					float(r.get("avg_hp_loss", 0.0)) * 100.0, str(r.get("avg_rounds", "?"))])
		boss_results.append(row)
	SomData.action_boss_override = {}
	GameState.som_mode = was_som
	bs.queue_free()


static func _mx(m: Dictionary, k: String) -> String:
	return "-" if m.is_empty() else "%.2f" % float(m.get(k, 1.0))


func report_markdown(ms: int) -> String:
	var s := "# Action battle balance (SoM prototype)\n\n"
	s += "Generated by `-- --actionsim` (tools/battlesim/action_sim.gd), seed %d, %d fights per room per iteration, %.1f s.\n" % [base_seed, fights, ms / 1000.0]
	s += "Target: normal fights (one SoM room, full HP) cost 10-20% party HP; bosses (turn-based) 60-80% win rate.\n\n"
	s += "| # | Iteration | gauge s | floor | refill after swing | enemy cd s | telegraph s | enemy dmg | HP loss | p90 | win | s/room | spam HP loss | spam s/room |\n"
	s += "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for i in results.size():
		var r: Dictionary = results[i]
		var p: Dictionary = r["params"]
		s += "| %d | %s | %.2f | %.2f | %s | %.2f | %.2f | x%.2f | %.1f%% | %.1f%% | %.1f%% | %.1f | %.1f%% | %.1f |\n" % [i + 1, r["label"],
			p["charge_time"], p["floor"], "yes" if p["anim_lock"] else "no", p["enemy_cd"], p["telegraph"], p["enemy_dmg"],
			r["loss"] * 100.0, r["p90"] * 100.0, r["win"] * 100.0, r["time"], r["spam_loss"] * 100.0, r["spam_time"]]
	if not results.is_empty():
		var last: Dictionary = results[results.size() - 1]
		s += "\nPer room (last iteration): "
		var parts: Array = []
		for k in last["rooms"]:
			parts.append("%s %.1f%%" % [k, float(last["rooms"][k]) * 100.0])
		s += ", ".join(parts) + "\n"
	s += "\n## Bosses: Action-mode multiplier (turn-based Golem fight, Classic unchanged)\n\n"
	s += "Target: 60-80%% win rate at Lv 3 and Lv 5. Multiplier applies only when GameState.som_mode or Battle Style = Action (SomData.ACTION_BOSS_MULT); %d fights per level.\n\n" % boss_fights
	s += "| # | Iteration | Lv 3 HP x / ATK x | Lv 5 HP x / ATK x | Lv 3 win | Lv 3 HP loss | Lv 5 win | Lv 5 HP loss |\n|---|---|---|---|---|---|---|---|\n"
	for i in boss_results.size():
		var b: Dictionary = boss_results[i]
		var c3 := "-" if b["classic"] else "%s / %s" % [_mx(b["m3"], "max_hp"), _mx(b["m3"], "atk")]
		var c5 := "-" if b["classic"] else "%s / %s" % [_mx(b["m5"], "max_hp"), _mx(b["m5"], "atk")]
		s += "| %d | %s | %s | %s |" % [i + 1, b["label"], c3, c5]
		for r in b["levels"]:
			s += " %.1f%% | %.1f%% |" % [float(r.get("win_rate", 0.0)) * 100.0, float(r.get("avg_hp_loss", 0.0)) * 100.0]
		s += "\n"
	return s
