extends Node
## F5-meettool: ECHTE SomArena headless, per tick gescripte input. Meet schade/s per held
## en per beleid (keten / zware slag), bondgenoot-AI-schade, en TTK per vijand (HP / gemeten DPS bij diens DEF).
## godot --headless --path . -- --f5sim [--out=pad.json] [--ticks=N]
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomHeavyData := preload("res://scripts/data/som_heavy_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"
const HEROES := ["dennis", "lotte", "noor", "kael", "orion"]
const POLICIES := ["wacht_vol", "keten_snel", "keten_laat", "keten_ai", "mash8", "zwaar1", "zwaar2", "keten_zwaar1", "keten_zwaar2"]
var ticks := 1800
var quick := false
var out_path := "user://f5_sim.json"
var dmg_by := {}
var hits_by := {}
var results := {"meta": {}, "player": [], "ally": [], "ttk": []}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_path = a.get_slice("=", 1)
		elif a.begins_with("--ticks="): ticks = int(a.get_slice("=", 1))
		elif a == "--quick": quick = true
	_run.call_deferred()

func _setup_party(ids: Array) -> void:
	GameState._build_som_state()
	GameState.encounter_multiplier = 0.0
	var lv := GameData.exp_for_level(SomData.START_LEVEL)
	for id in ids:
		if not GameState.has_member(id):
			GameState.add_member(id)
		for i in GameState.party_bench.size():
			if str(GameState.party_bench[i]["id"]) == id:
				var h: Dictionary = GameState.party_bench[i]
				GameState.party_bench.remove_at(i)
				# vervang een lid dat niet in ids staat
				for j in range(GameState.party.size() - 1, 0, -1):
					if not ids.has(str(GameState.party[j]["id"])):
						GameState.party_bench.append(GameState.party[j])
						GameState.party.remove_at(j)
						break
				GameState.party.append(h)
				break
	for h in GameState.party:
		if int(h["exp"]) < lv:
			GameState.give_exp(h, lv - int(h["exp"]))
		h["hp"] = h["max_hp"]

func _load_room() -> Node:
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	for i in 300:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			return s
	return null

func _line_up(room: Node, arena: SomArena, m: Node) -> void:
	for y in range(2, 24):
		for x in range(2, 44):
			var c := Vector2i(x, y)
			var ok := true
			for dx in 6:
				if room.is_wall(c + Vector2i(dx, 0)):
					ok = false
					break
			if ok:
				arena.player.place_at(c, Vector2i.RIGHT)
				m.place_at(c + Vector2i.RIGHT, m.facing)
				return

func _on_hit(m: Node, dmg: int, arena: SomArena) -> void:
	var id := str(arena.last_attacker)
	dmg_by[id] = int(dmg_by.get(id, 0)) + dmg
	hits_by[id] = int(hits_by.get(id, 0)) + 1

## Eén meting. active = bestuurde held met beleid 'pol' ("idle" = slaat niet); allies = bondgenoot-AI aan.
func measure(party_ids: Array, active: String, pol: String, allies: bool, def_override := -1, sd := 20261031) -> Dictionary:
	_setup_party(party_ids)
	var room := await _load_room()
	if room == null:
		return {"error": "room"}
	var arena: SomArena = room.som
	arena.set_process(false)
	arena.allies_enabled = allies
	arena.seed_rng(sd)
	seed(sd)
	if active != arena.active_id:
		arena.switch_hero(active)
	var m: Node = null
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			m = k
			break
	if m == null:
		return {"error": "enemy"}
	# alleen deze ene vijand: de rest weg (anders slaan bondgenoten andere doelen)
	for k in arena.enemies.keys():
		if k != m:
			arena.enemies.erase(k)
			if is_instance_valid(k): k.queue_free()
	var e: Dictionary = arena.enemies[m]
	e["hp"] = 99999999
	e["max_hp"] = 99999999
	e["atk"] = 0
	if def_override >= 0:
		e["def"] = def_override
	_line_up(room, arena, m)
	if allies:
		for a in arena.allies:
			a.position = m.position + Vector2(-14 if randi() % 2 == 0 else 14, 0)
	dmg_by = {}
	hits_by = {}
	arena.enemy_hit.connect(_on_hit.bind(arena))
	arena.step_ticks(30)
	dmg_by = {}
	hits_by = {}
	var heavy0 := arena.heavy_releases
	var st := {"phase": 0, "cnt": 0}
	for t in ticks:
		arena.player.position = m.position + Vector2(-16, 0)
		arena.player.facing = Vector2i.RIGHT
		for h in GameState.party:
			h["hp"] = h["max_hp"]
		_policy(arena, pol, st, t)
		arena.step_ticks(1)
	var out := {"active": active, "policy": pol, "allies": allies, "def": int(e["def"]), "ticks": ticks,
		"dps": {}, "hits": hits_by.duplicate(), "heavy_releases": arena.heavy_releases - heavy0}
	for id in dmg_by:
		out["dps"][id] = float(dmg_by[id]) / (ticks / 60.0)
	arena.enemy_hit.disconnect(_on_hit)
	return out

func _press(arena: SomArena, hold: bool) -> void:
	arena._pending["attack"] = true
	arena._pending["hold"] = hold

## Speler-beleid per tick (zet _pending voor de volgende sim_step).
func _policy(arena: SomArena, pol: String, st: Dictionary, t: int) -> void:
	var id := arena.active_id
	var c := arena.chain_of(id)
	var free := arena.swing_lock <= 0.0
	arena._pending["hold"] = false
	match pol:
		"idle":
			pass
		"wacht_vol":
			if free and arena.charge >= 1.0: _press(arena, false)
		"keten_snel":
			if free: _press(arena, false)
		"keten_laat":   # laatste tick van het venster (meter zo vol mogelijk), anders vol wachten
			if free and (int(c["window"]) == 2 or (int(c["next"]) == 0 and arena.charge >= 1.0)): _press(arena, false)
		"mash8":
			if t % 8 == 0: _press(arena, false)
		"zwaar1", "zwaar2":
			var target := 1 if pol == "zwaar1" else 2
			if arena.heavy_hold.has(id):
				arena._pending["hold"] = SomHeavyData.level_for(int(arena.heavy_hold[id])) < target
			elif free:
				_press(arena, true)
		"keten_ai":   # zoals de bondgenoot-AI: hit1 bij volle meter, vervolg ALLY_FOLLOWUP_TICKS na de animatie
			var w := int(c["window"])
			if free and ((int(c["next"]) > 0 and w > 0 and w <= SomChainData.CHAIN_WINDOW_TICKS - SomChainData.ALLY_FOLLOWUP_TICKS) \
					or (int(c["next"]) == 0 and arena.charge >= 1.0)):
				_press(arena, false)
		"keten_zwaar1", "keten_zwaar2":   # hit1-hit2-finisher (AI-tempo), daarna opladen tot L1/L2 (indrukken = ook een tik)
			var target2 := 1 if pol == "keten_zwaar1" else 2
			var ph := int(st["phase"])
			var w2 := int(c["window"])
			if ph == 4:
				if arena.heavy_hold.has(id):
					arena._pending["hold"] = SomHeavyData.level_for(int(arena.heavy_hold[id])) < target2
				else:
					st["phase"] = 0
			elif free:
				if ph == 0 and arena.charge >= 1.0:
					_press(arena, false); st["phase"] = 1
				elif (ph == 1 or ph == 2) and int(c["next"]) > 0 and w2 > 0 and w2 <= SomChainData.CHAIN_WINDOW_TICKS - SomChainData.ALLY_FOLLOWUP_TICKS:
					_press(arena, false); st["phase"] = ph + 1
				elif (ph == 1 or ph == 2) and int(c["next"]) == 0:
					st["phase"] = 0
				elif ph == 3:
					_press(arena, true); st["phase"] = 4
		_:
			pass

func _enemy_list() -> Array:
	var seen := {}
	var list: Array = []
	for rid in SomData.ROOMS:
		var r: Dictionary = DungeonRooms.room(rid)
		var tier := int(r.get("tier", 0))
		for mm in r.get("monsters", []):
			if bool(mm.get("boss", false)): continue
			var d: Dictionary = (GameData.ENEMIES.get(str(mm["enemy"]), {}) as Dictionary).duplicate(true)
			if d.is_empty(): continue
			if tier > 0 and not bool(d.get("unique", false)):
				d = GameData.apply_archief_tier(d, tier)
			d = SomData.apply_action_area(d, rid, tier)
			var key := "%s@t%d" % [mm["enemy"], tier]
			if seen.has(key): continue
			seen[key] = true
			list.append({"key": key, "room": rid, "max_hp": int(d["max_hp"]), "def": int(d.get("def", 0)), "atk": int(d.get("atk", 0))})
	return list

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	results["meta"] = {"chain_window": SomChainData.CHAIN_WINDOW_TICKS, "chain_mult": SomChainData.DAMAGE_MULT,
		"heavy_hold_start": SomHeavyData.HOLD_START_TICKS, "heavy_level_ticks": SomHeavyData.LEVEL_TICKS,
		"heavy_mult": SomHeavyData.DAMAGE_MULT, "ally_followup": SomChainData.ALLY_FOLLOWUP_TICKS,
		"ally_level": SomHeavyData.ALLY_LEVEL, "followup_min_meter": SomChainData.FOLLOWUP_MIN_METER, "tap_gate": SomChainData.TAP_GATE, "chain_hitstop": SomChainData.HITSTOP_TICKS, "heavy_hitstop": SomHeavyData.HITSTOP_TICKS, "start_level": SomData.START_LEVEL, "ticks": ticks}
	# 1) speler-DPS per held en beleid (alleen bestuurde held, bondgenoten uit), op de eerste vijand van archief_v1_gang
	for h in (["dennis"] if quick else HEROES):
		for pol in POLICIES:
			var party := ["dennis"] if h == "dennis" else ["dennis", h]
			var r := await measure(party, h, pol, false)
			results["player"].append(r)
			print("F5 player %s %s dps=%s hits=%s heavy=%s" % [h, pol, r.get("dps"), r.get("hits"), r.get("heavy_releases")])
	# 2) bondgenoot-AI (ketent op spelersnelheid + zwaar L1 na finisher), 5 herhalingen (AI-beweging is niet volledig seed-vast); bestuurde held slaat niet
	for grp in [["lotte", ["dennis", "lotte", "noor", "kael"]], ["dennis", ["dennis", "lotte", "orion"]]]:
		for rep in 5:
			var r2 := await measure(grp[1], grp[0], "idle", true, -1, 20261031 + rep)
			r2["rep"] = rep
			results["ally"].append(r2)
			print("F5 ally active=%s dps=%s hits=%s heavy=%s" % [grp[0], r2.get("dps"), r2.get("hits"), r2.get("heavy_releases")])
	# 3) TTK per vijand: Dax bestuurd (wacht_vol / keten_snel / zwaar1 / zwaar2) bij de DEF van elke vijand, solo
	#    en als party (Dax speler wacht_vol + Seren/Vesper AI)
	for en in ([] if quick else _enemy_list()):
		var row := {"enemy": en}
		for pol in ["wacht_vol", "keten_snel", "keten_ai", "mash8", "zwaar1", "zwaar2", "keten_zwaar1"]:
			var r3 := await measure(["dennis"], "dennis", pol, false, int(en["def"]))
			var d := float(r3["dps"].get("dennis", 0.0))
			row[pol] = {"dps": d, "ttk": (float(en["max_hp"]) / d) if d > 0 else -1.0}
		var rp := await measure(["dennis", "lotte", "noor"], "dennis", "wacht_vol", true, int(en["def"]))
		var tot := 0.0
		for k in rp["dps"]: tot += float(rp["dps"][k])
		row["party_wacht_vol_ai"] = {"dps": tot, "ttk": (float(en["max_hp"]) / tot) if tot > 0 else -1.0, "per": rp["dps"]}
		results["ttk"].append(row)
		print("F5 ttk %s hp=%d def=%d %s" % [en["key"], en["max_hp"], en["def"], JSON.stringify(row)])
	results["meta"]["ms"] = Time.get_ticks_msec() - t0
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	f.close()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	print("F5SIM klaar: ", out_path)
	get_tree().quit(0)
