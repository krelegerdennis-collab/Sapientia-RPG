extends Node
class_name D100ModeSim
## M9b: headless sim van een online co-op Easy-run door de DLS.
##
##   godot --path . -- --d100modesim --mode=easy [--factors=4,7,10,25] [--runs=N] [--seed=N]
##        [--floors=10] [--seats=1,2,3,4] [--out=res://docs/combat/m9b_easy_sim.md]
##
## De factor is alleen een sim-parameter. OnlineDlsModes.mode_exp_factor blijft 100/N.
## Host-autoritatief: één RNG per gevecht (mix_seed), nooit globale randf()/randi().
## Schrijft geen user:// saves. --out weigert user://.
##
## Aannames (geen speldata):
##  - Partijvolgorde: Dax, Seren, Vesper, Kael Voss, Orion. Stoel 0 = host, de rest AI.
##    Bij 4 stoelen valt Orion buiten (max 4). De hypo-kolom "Orion" gebruikt de partij
##    van de Page Warden-sim uit #420 (Dax, Seren, Vesper, Orion).
##  - Vloer via OnlineDlsFloor.build: generate(seed, eff), cap 8, groep = één vijand.
##  - Troep: golf 2, SomData-tijden, schade via SomArena.physical_damage(rng).
##    Keten zoals het spel: hit1/hit2/finisher, vervolg 6 ticks na de animatie.
##    AI na de finisher: zware slag niveau 1. Doel = een vijand die al aangekomen is.
##  - EXP per verslagen vijand, meteen, aan elke levende held (give_exp, level-up vult HP bij).
##  - Vloer 10: die troep, daarna Page Warden. Doel, klap, spreuk en adds komen uit
##    page_warden_rt_sim.gd. De slag blijft de keten (die sim laadt nog een volle meter).
##  - Rust (Easy vloer 5) heelt levenden vóór het gevecht. Geen drankjes, geen feniksveer:
##    die zijn in het spel een handmatige ring-actie, en de bondgenoot-AI gebruikt ze niet.
##  - M8a (down/revive) zit niet in de code. Eén down is geen verlies; de vloer stopt
##    pas als iedereen op 0 ligt, de tick-cap raakt, of de vijanden dood zijn.

const SomData := preload("res://scripts/data/som_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const DamageCalc := preload("res://scripts/battle/damage_calc.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Equipment := preload("res://scripts/equipment.gd")
const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
const PageWardenFight := preload("res://scripts/som/page_warden_fight.gd")
const PageWardenRt := preload("res://tools/battlesim/page_warden_rt_sim.gd")
const ThreatTableSc := preload("res://scripts/som/threat_table.gd")
const Chain := preload("res://scripts/data/som_chain_data.gd")
const Heavy := preload("res://scripts/data/som_heavy_data.gd")
const Modes := preload("res://scripts/online/online_dls_modes.gd")
const Floor := preload("res://scripts/online/online_dls_floor.gd")
const Generator := preload("res://scripts/dungeon/dungeon100_generator.gd")

const DT := 1.0 / 60.0
const TRASH_MAX_TICKS := 120 * 60
const BOSS_MAX_TICKS := 180 * 60
const WAVE := 2
const DODGE_PLAYER := 0.35
const DODGE_ALLY := 0.15
const APPROACH := 1.2
const ANIM := 0.71
const RUN_SEED_STEP := 10007
const DEFAULT_SEED := 20261110
const DEFAULT_RUNS := 24

## Stoel 0 eerst. Orion is de 5e held en past niet in 4 stoelen.
const PARTY_IDS := ["dennis", "lotte", "noor", "kael", "orion"]
## Partij van tools/battlesim/page_warden_rt_sim.gd (#420), alleen als vergelijking.
const ORION_IDS := ["dennis", "lotte", "noor", "orion"]

const KIND_TRASH := 1
const KIND_BOSS := 2
const KIND_HYPO := 3
const KIND_HYPO_ORION := 4


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var cfg := _cfg_from_args()
	if str(cfg.get("error", "")) != "":
		print(str(cfg["error"]))
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	print("SIM start mode=%s factors=%s runs=%d seed=%d" % [cfg["mode"], str(cfg["factors"]), int(cfg["runs"]), int(cfg["base_seed"])])
	var result := run_cfg(cfg)
	var classic := {}
	if bool(cfg.get("classic_ref", true)):
		print("SIM classic-referentie (één seed, vloeren 1-98)...")
		classic = classic_arrival(int(cfg["base_seed"]))
	var ms := Time.get_ticks_msec() - t0
	var md := markdown(result, cfg, classic, ms)
	print(md)
	var out := str(cfg.get("out", ""))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			print("SIM kon %s niet schrijven" % out)
			get_tree().quit(1)
			return
		f.store_string(md)
		f.close()
		print("SIM geschreven: %s" % out)
	print("RESULT SIM klaar")
	get_tree().quit(0)


static func _cfg_from_args() -> Dictionary:
	var mode := "easy"
	var factors: Array = []
	var seats: Array = []
	var runs := DEFAULT_RUNS
	var seed_val := DEFAULT_SEED
	var floors := 0
	var hypo := true
	var classic_ref := true
	var out := ""
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--mode="):
			mode = s.trim_prefix("--mode=")
		elif s.begins_with("--factors="):
			factors = _ints(s.trim_prefix("--factors="))
		elif s.begins_with("--factor="):
			factors = _ints(s.trim_prefix("--factor="))
		elif s.begins_with("--seats="):
			seats = _ints(s.trim_prefix("--seats="))
		elif s.begins_with("--runs="):
			runs = int(s.trim_prefix("--runs="))
		elif s.begins_with("--seed="):
			seed_val = int(s.trim_prefix("--seed="))
		elif s.begins_with("--floors="):
			floors = int(s.trim_prefix("--floors="))
		elif s == "--no-hypo":
			hypo = false
		elif s == "--no-classic":
			classic_ref = false
		elif s.begins_with("--out="):
			out = s.trim_prefix("--out=")
	if mode != "easy":
		return {"error": "M9b simuleert alleen --mode=easy. Normal/Hard hebben nog geen realtime baas."}
	if out.begins_with("user://"):
		return {"error": "SIM weigert --out op user:// (geen saves)."}
	if factors.is_empty():
		factors = [Modes.mode_exp_factor(mode)]
	if seats.is_empty():
		seats = [1, 2, 3, 4]
	var max_f := Modes.floors(mode)
	if floors <= 0:
		floors = max_f
	floors = clampi(floors, 1, max_f)
	runs = maxi(1, runs)
	if seed_val <= 0:
		seed_val = 1
	return {
		"mode": mode,
		"factors": factors,
		"seats": _clean_seats(seats),
		"runs": runs,
		"base_seed": seed_val,
		"floors": floors,
		"hypothetical": hypo,
		"classic_ref": classic_ref,
		"out": out,
		"verbose": true,
	}


static func _ints(s: String) -> Array:
	var out: Array = []
	for part in s.split(","):
		var n := int(str(part).strip_edges())
		if n > 0:
			out.append(n)
	return out


static func _clean_seats(seats: Array) -> Array:
	var out: Array = []
	for n in seats:
		var s := clampi(int(n), 1, 4)
		if not out.has(s):
			out.append(s)
	if out.is_empty():
		return [1, 2, 3, 4]
	return out


## Zelfde invoer → zelfde Dictionary (ints). Geen bestanden, geen globale RNG.
static func run_cfg(cfg: Dictionary) -> Dictionary:
	var mode := str(cfg.get("mode", "easy"))
	var runs := maxi(1, int(cfg.get("runs", 1)))
	var base_seed := int(cfg.get("base_seed", DEFAULT_SEED))
	var floor_n := clampi(int(cfg.get("floors", Modes.floors(mode))), 1, maxi(1, Modes.floors(mode)))
	var factors: Array = cfg.get("factors", [Modes.mode_exp_factor(mode)])
	var seats: Array = _clean_seats(cfg.get("seats", [1, 2, 3, 4]))
	var hypo := bool(cfg.get("hypothetical", true))
	var verbose := bool(cfg.get("verbose", false))
	var maps: Array = []
	var run_seeds: Array = []
	var fp_parts: PackedStringArray = PackedStringArray()
	for i in runs:
		var rs := run_seed_for(base_seed, i)
		run_seeds.append(rs)
		var built: Array = _build_run(mode, rs, floor_n)
		maps.append(built)
		fp_parts.append(str(rs))
		for fl in built:
			fp_parts.append("%d:%d:%d" % [int(fl["floor"]), int(fl["eff"]), int(fl["boss_key"])])
			for e in fl["enemies"]:
				fp_parts.append("%s:%d" % [str(e["id"]), int(e["exp_base"])])
	var rows: Array = []
	var examples: Array = []
	var caps := {"high": 0, "wipe": 0}
	for factor in factors:
		var fac := maxi(1, int(factor))
		for seat_n in seats:
			var t0 := Time.get_ticks_msec()
			rows.append(_simulate_cell(maps, run_seeds, fac, int(seat_n), hypo, examples, caps))
			if verbose:
				print("SIM factor %d stoelen %d klaar (%d ms)" % [fac, int(seat_n), Time.get_ticks_msec() - t0])
	return {
		"mode": mode,
		"base_seed": base_seed,
		"runs": runs,
		"floors": floor_n,
		"run_seeds": run_seeds,
		"map_fp": _djb2("|".join(fp_parts)),
		"rows": rows,
		"hypothetical": hypo,
		"examples": examples,
	}


static func _build_run(mode: String, run_seed: int, floor_n: int) -> Array:
	var out: Array = []
	var cap := Modes.enemy_cap()
	for f in range(1, floor_n + 1):
		var eff := Modes.eff_floor(mode, f)
		var bkey := Modes.boss_key(mode, f)
		var built := Floor.build(mode, run_seed, f)
		var enemies: Array = []
		var room: Dictionary = built.get("room", {})
		for m in room.get("monsters", []):
			if enemies.size() >= cap:
				break
			var eid := str(m.get("enemy", ""))
			if eid == "" or not GameData.ENEMIES.has(eid):
				continue
			var st: Dictionary = Scaling.monster_stats(GameData.ENEMIES[eid], eff)
			enemies.append({"id": eid, "d": st, "exp_base": int(st.get("exp", 0))})
		out.append({
			"floor": f,
			"eff": eff,
			"boss_key": bkey,
			"rest": Modes.is_rest(mode, f),
			"enemies": enemies,
		})
	return out


static func _empty_floor(floor_no: int, eff: int, boss_key: int) -> Dictionary:
	return {
		"floor": floor_no, "eff": eff, "boss_key": boss_key,
		"entered": 0, "wins": 0, "losses": 0, "wipes": 0, "ticks": 0, "level_sum": 0,
		"hp_sum": 0, "hp_max_sum": 0, "enemy_sum": 0,
		"hp_end_sum": 0, "hp_end_max": 0, "hp_end_n": 0,
		"cause_wipe": 0, "cause_timeout": 0, "cause_soft": 0, "cause_other": 0,
		"boss_entered": 0, "boss_wins": 0, "boss_wipes": 0, "boss_ticks": 0, "boss_level_sum": 0,
	}


static func _simulate_cell(maps: Array, run_seeds: Array, factor: int, seats: int, hypo: bool, examples: Array, caps: Dictionary) -> Dictionary:
	var ids := party_ids_for(seats)
	var floor_rows: Array = []
	var proto: Array = maps[0]
	for fl in proto:
		floor_rows.append(_empty_floor(int(fl["floor"]), int(fl["eff"]), int(fl["boss_key"])))
	var exp_clear_sum := 0
	var hypo_n := 0
	var hypo_wins := 0
	var hypo_ticks := 0
	var hypo_level_sum := 0
	var hypo_orion_wins := 0
	var hypo_orion_ticks := 0
	var boss_floor := 0
	for fl0 in proto:
		if int(fl0["boss_key"]) == PageWardenBoss.BOSS_KEY:
			boss_floor = int(fl0["floor"])
	for built0 in maps:
		var bi := 0
		for fl0 in built0:
			var row0: Dictionary = floor_rows[bi]
			row0["enemy_sum"] = int(row0["enemy_sum"]) + (fl0["enemies"] as Array).size()
			bi += 1
	for i in maps.size():
		var built: Array = maps[i]
		var rs := int(run_seeds[i])
		var clear := 0
		for fl in built:
			if int(fl["boss_key"]) > 0:
				continue
			for e in fl["enemies"]:
				clear += scaled_exp(int(e["exp_base"]), factor)
		exp_clear_sum += clear
		_climb(built, rs, factor, seats, ids, floor_rows, examples, caps)
		if hypo and boss_floor > 0:
			var party := make_party(ids, clear)
			var bf: Dictionary = _boss_fight(party, seats, combat_seed(rs, boss_floor, seats, factor, KIND_HYPO))
			hypo_n += 1
			hypo_ticks += int(bf["ticks"])
			hypo_level_sum += level_of(party)
			if bool(bf["win"]):
				hypo_wins += 1
			if seats == 4:
				var orion := make_party(ORION_IDS, clear)
				var bo: Dictionary = _boss_fight(orion, 4, combat_seed(rs, boss_floor, 4, factor, KIND_HYPO_ORION))
				hypo_orion_ticks += int(bo["ticks"])
				if bool(bo["win"]):
					hypo_orion_wins += 1
	return {
		"factor": factor,
		"seats": seats,
		"party": ids,
		"floors": floor_rows,
		"exp_clear_sum": exp_clear_sum,
		"hypo_n": hypo_n,
		"hypo_wins": hypo_wins,
		"hypo_ticks": hypo_ticks,
		"hypo_level_sum": hypo_level_sum,
		"hypo_orion_wins": hypo_orion_wins,
		"hypo_orion_ticks": hypo_orion_ticks,
	}


static func _climb(built: Array, run_seed: int, factor: int, seats: int, ids: Array, floor_rows: Array, examples: Array, caps: Dictionary) -> void:
	var party := make_party(ids, 0)
	for i in built.size():
		if not any_alive(party):
			break
		var fl: Dictionary = built[i]
		var row: Dictionary = floor_rows[i]
		var floor_no := int(fl["floor"])
		row["entered"] = int(row["entered"]) + 1
		row["level_sum"] = int(row["level_sum"]) + level_of(party)
		var hp_now := 0
		var hp_max := 0
		for h in party:
			hp_now += maxi(0, int(h["hp"]))
			hp_max += int(h["max_hp"])
		row["hp_sum"] = int(row["hp_sum"]) + hp_now
		row["hp_max_sum"] = int(row["hp_max_sum"]) + hp_max
		if bool(fl["rest"]):
			rest_heal(party)
		var meta := {"factor": factor, "seats": seats, "floor": floor_no, "seed": run_seed, "hp_in": hp_now, "hp_in_max": hp_max}
		var trash: Dictionary = _trash_fight(party, fl["enemies"], combat_seed(run_seed, floor_no, seats, factor, KIND_TRASH), factor)
		row["ticks"] = int(row["ticks"]) + int(trash["ticks"])
		if not bool(trash["win"]):
			_note_loss(row, trash, examples, caps, meta)
			break
		# EXP valt al per verslagen vijand, tijdens het gevecht.
		if int(fl["boss_key"]) <= 0:
			row["wins"] = int(row["wins"]) + 1
			continue
		if int(fl["boss_key"]) != PageWardenBoss.BOSS_KEY:
			_note_loss(row, {"cause": "other", "hp_end": hp_now, "hp_max": hp_max, "log": PackedStringArray()}, examples, caps, meta)
			break
		row["boss_entered"] = int(row["boss_entered"]) + 1
		row["boss_level_sum"] = int(row["boss_level_sum"]) + level_of(party)
		var bf: Dictionary = _boss_fight(party, seats, combat_seed(run_seed, floor_no, seats, factor, KIND_BOSS))
		row["ticks"] = int(row["ticks"]) + int(bf["ticks"])
		row["boss_ticks"] = int(row["boss_ticks"]) + int(bf["ticks"])
		if bool(bf["win"]):
			row["wins"] = int(row["wins"]) + 1
			row["boss_wins"] = int(row["boss_wins"]) + 1
		else:
			if bool(bf["wipe"]):
				row["boss_wipes"] = int(row["boss_wipes"]) + 1
			_note_loss(row, bf, examples, caps, meta)
			break


static func _trash_fight(party: Array, enemies: Array, seed_val: int, factor: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var heroes := _runtime(party)
	var queue: Array = []
	for e in enemies:
		var d: Dictionary = e["d"]
		queue.append({
			"d": d, "hp": int(d["max_hp"]), "approach": APPROACH,
			"tele": 0.0, "cd": rng.randf_range(0.2, 0.8), "stun": 0.0, "target": -1,
			"exp": scaled_exp(int(e["exp_base"]), factor),
		})
	if queue.is_empty():
		var pools := _pool_hp(heroes)
		var alive := not _runtime_alive(heroes).is_empty()
		return _fight_result(alive, alive, 0, 0, 0, pools.x, pools.y, PackedStringArray())
	var active: Array = []
	var events: Array = []
	var ticks := 0
	var quiet := 0
	var swings := 0
	while ticks < TRASH_MAX_TICKS:
		if _runtime_alive(heroes).is_empty():
			break
		while active.size() < WAVE and not queue.is_empty():
			active.append(queue.pop_front())
		if active.is_empty():
			break
		ticks += 1
		var acted := _trash_heroes(heroes, active, rng, events, ticks)
		var hurt := _trash_enemies(heroes, active, rng, events, ticks)
		if acted or hurt:
			quiet = 0
		else:
			quiet += 1
		swings += 1 if acted else 0
	var alive_end := not _runtime_alive(heroes).is_empty()
	var win := queue.is_empty() and active.is_empty() and alive_end
	var pools_end := _pool_hp(heroes)
	return _fight_result(win, alive_end, ticks, swings, quiet, pools_end.x, pools_end.y, _tail_log(events, ticks))


static func _trash_heroes(heroes: Array, active: Array, rng: RandomNumberGenerator, events: Array, tick: int) -> bool:
	var swung := false
	var killed := false
	for hr in heroes:
		if int(hr["h"]["hp"]) <= 0:
			continue
		_tick_hero_clock(hr)
		if float(hr["walk"]) > 0.0:
			hr["walk"] = float(hr["walk"]) - DT
			continue
		if int(hr["slot"]) > 0:
			hr["spell_cd"] = float(hr["spell_cd"]) - DT
			if float(hr["spell_cd"]) <= 0.0:
				hr["spell_cd"] = SomData.ALLY_SPELL_CD
				_trash_spell(hr, heroes, active, rng)
		if float(hr["lock"]) > 0.0 or active.is_empty():
			continue
		var plan := _swing_plan(hr)
		if plan.is_empty():
			continue
		var e := _in_range(active, rng, int(hr["slot"]) > 0)
		if e.is_empty():
			continue
		if str(plan["kind"]) == "arm":
			_arm_heavy(hr)
			continue
		var dmg := SomArena.physical_damage(float(hr["atk"]), float(e["d"]["def"]), float(plan["mult"]), rng)
		e["hp"] = int(e["hp"]) - dmg
		var stun := _stagger_time(plan)
		if stun > 0.0:
			e["tele"] = 0.0
			e["stun"] = maxf(float(e["stun"]), stun)
		_commit_swing(hr, plan)
		swung = true
		_push_log(events, tick, "slag %s x%.2f %d naar %d/%d" % [
			str(hr["h"]["name"]), float(plan["mult"]), dmg, maxi(0, int(e["hp"])), int(e["d"]["max_hp"])])
	var i := active.size() - 1
	while i >= 0:
		if int(active[i]["hp"]) <= 0:
			killed = true
			_grant_kill(heroes, int(active[i].get("exp", 0)))
			var ed: Dictionary = active[i]["d"]
			_push_log(events, tick, "neer %s" % str(ed.get("name", "vijand")))
			active.remove_at(i)
		i -= 1
	return swung or killed


static func _trash_spell(hr: Dictionary, heroes: Array, active: Array, rng: RandomNumberGenerator) -> void:
	var h: Dictionary = hr["h"]
	for s in h.get("spells", []):
		var sp: Dictionary = GameData.SPELLS.get(str(s), {})
		if sp.is_empty() or int(h["mp"]) < int(sp.get("mp", 0)):
			continue
		if str(sp.get("type", "")) == "heal":
			var low: Dictionary = {}
			var lr := SomData.ALLY_HEAL_BELOW
			for o in heroes:
				var ratio := float(o["h"]["hp"]) / maxf(1.0, float(o["h"]["max_hp"]))
				if int(o["h"]["hp"]) > 0 and ratio < lr:
					lr = ratio
					low = o["h"]
			if low.is_empty():
				continue
			h["mp"] = int(h["mp"]) - int(sp["mp"])
			var gain := roundi(DamageCalc.spell_base({"s": h, "is_hero": true, "buffs": []}, sp, {}))
			low["hp"] = mini(int(low["max_hp"]), int(low["hp"]) + gain)
			return
		if str(sp.get("type", "")) == "damage" and rng.randf() < SomData.ALLY_DAMAGE_SPELL_CHANCE and not active.is_empty():
			h["mp"] = int(h["mp"]) - int(sp["mp"])
			var caster := {"s": h, "is_hero": true, "buffs": []}
			var targets: Array = active if str(sp.get("target", "")) == "all_enemies" else [active[0]]
			for e in targets:
				var amt := DamageCalc.spell_base(caster, sp, {"s": e["d"]})
				e["hp"] = int(e["hp"]) - maxi(1, roundi(amt * rng.randf_range(0.9, 1.1)))
			return


static func _trash_enemies(heroes: Array, active: Array, rng: RandomNumberGenerator, events: Array, tick: int) -> bool:
	var hurt := false
	var i := active.size() - 1
	while i >= 0:
		var e: Dictionary = active[i]
		if int(e["hp"]) <= 0:
			active.remove_at(i)
			i -= 1
			continue
		if float(e["approach"]) > 0.0:
			e["approach"] = float(e["approach"]) - DT
			i -= 1
			continue
		if float(e["stun"]) > 0.0:
			e["stun"] = float(e["stun"]) - DT
			i -= 1
			continue
		if float(e["tele"]) > 0.0:
			e["tele"] = float(e["tele"]) - DT
			if float(e["tele"]) <= 0.0:
				e["cd"] = SomData.ATTACK_COOLDOWN
				var slot := int(e["target"])
				var hr := _runtime_slot(heroes, slot)
				if not hr.is_empty() and int(hr["h"]["hp"]) > 0 and float(hr["iframes"]) <= 0.0:
					var dodge := DODGE_PLAYER if int(hr["slot"]) == 0 else DODGE_ALLY
					if rng.randf() >= dodge:
						var dmg := roundi(SomArena.physical_damage(float(e["d"]["atk"]), float(hr["def"]), 1.0, rng) * SomData.ENEMY_DAMAGE_MULT)
						_hurt(hr, dmg)
						hurt = true
						_push_log(events, tick, "raak %s %d → %d/%d" % [
							str(hr["h"]["name"]), dmg, int(hr["h"]["hp"]), int(hr["h"]["max_hp"])])
			i -= 1
			continue
		if float(e["cd"]) > 0.0:
			e["cd"] = float(e["cd"]) - DT
			i -= 1
			continue
		e["target"] = _trash_target(heroes, rng)
		if int(e["target"]) >= 0:
			e["tele"] = SomData.TELEGRAPH
		i -= 1
	return hurt


static func _trash_target(heroes: Array, rng: RandomNumberGenerator) -> int:
	var alive: Array = []
	for hr in heroes:
		if int(hr["h"]["hp"]) > 0:
			alive.append(int(hr["slot"]))
	if alive.is_empty():
		return -1
	if int(heroes[0]["h"]["hp"]) > 0 and rng.randf() < 0.5:
		return 0
	return int(alive[rng.randi() % alive.size()])


## Zelfde parameters als page_warden_rt_sim.gd `_run`, zodat de gedeelde functies dezelfde tijden zien.
static func _warden_rt(add_data: Dictionary) -> Object:
	var sim: Object = PageWardenRt.new()
	sim.set("_add_data", add_data)
	sim.set("_params", {
		"charge_time": SomData.CHARGE_TIME,
		"anim": ANIM,
		"approach": APPROACH,
		"ally_spell_cd": SomData.ALLY_SPELL_CD,
		"ally_heal_below": SomData.ALLY_HEAL_BELOW,
		"ally_dmg_chance": SomData.ALLY_DAMAGE_SPELL_CHANCE,
		"enemy_cd": SomData.ATTACK_COOLDOWN,
		"telegraph": SomData.TELEGRAPH,
		"enemy_dmg": SomData.ENEMY_DAMAGE_MULT,
	})
	return sim


static func _boss_fight(party: Array, seats: int, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var boss: Dictionary = PageWardenBoss.stats_for_seats(seats)
	var gf: PageWardenFight = PageWardenFight.new(int(boss["max_hp"]), seed_val)
	var threat: ThreatTable = ThreatTableSc.new()
	var heroes := _runtime(party)
	var add_data: Dictionary = Scaling.monster_stats((GameData.ENEMIES["papiergeest"] as Dictionary).duplicate(true), PageWardenBoss.BOSS_KEY)
	var warden := _warden_rt(add_data)
	var adds: Array = []
	var target := -1
	var events: Array = []
	var ticks := 0
	var quiet := 0
	var swings := 0
	while ticks < BOSS_MAX_TICKS and not gf.is_dead():
		if _runtime_alive(heroes).is_empty():
			break
		ticks += 1
		var before := _pool_hp(heroes).x
		var swings_before := _swing_total(heroes)
		gf.tick()
		for ev in gf.take_events():
			match str(ev.get("type", "")):
				"telegraph_start":
					target = int(warden.call("_choose", threat, heroes, bool(ev.get("ranged", false)), ticks))
				"attack_hit":
					warden.call("_boss_hit", heroes, boss, target, str(ev.get("id", "")), float(ev.get("power", 1.0)), rng)
				"adds":
					warden.call("_spawn_adds", adds, ev.get("ids", []))
				"stagger_break":
					target = -1
		_boss_heroes(warden, gf, heroes, adds, boss, rng, threat)
		warden.call("_adds_tick", heroes, adds, target, rng)
		for hr in heroes:
			if not bool(hr["downed"]) and int(hr["h"]["hp"]) <= 0:
				hr["downed"] = true
				threat.clear_slot(int(hr["slot"]))
		var after := _pool_hp(heroes).x
		var did := _swing_total(heroes) > swings_before
		if did or after < before:
			quiet = 0
			_push_log(events, ticks, "partij %d baas-tick %s" % [after, "slag" if did else "raak"])
		else:
			quiet += 1
		swings = _swing_total(heroes)
	var alive_end := not _runtime_alive(heroes).is_empty()
	var pools := _pool_hp(heroes)
	(warden as Node).free()
	return _fight_result(gf.is_dead(), alive_end, ticks, swings, quiet, pools.x, pools.y, _tail_log(events, ticks))


## De slag is de keten. Doel, klap, spreuk en adds blijven in page_warden_rt_sim.gd.
static func _boss_heroes(warden: Object, gf: PageWardenFight, heroes: Array, adds: Array, boss: Dictionary, rng: RandomNumberGenerator, threat: ThreatTable) -> void:
	for hr in heroes:
		if int(hr["h"]["hp"]) <= 0:
			continue
		_tick_hero_clock(hr)
		if float(hr["walk"]) > 0.0:
			hr["walk"] = float(hr["walk"]) - DT
			continue
		if int(hr["slot"]) > 0:
			hr["spell_cd"] = float(hr["spell_cd"]) - DT
			if float(hr["spell_cd"]) <= 0.0 and bool(warden.call("_ally_spell", gf, hr, heroes, boss, rng, threat)):
				hr["spell_cd"] = SomData.ALLY_SPELL_CD
				hr["lock"] = ANIM
				continue
			if float(hr["spell_cd"]) <= 0.0:
				hr["spell_cd"] = 0.0
		if float(hr["lock"]) > 0.0:
			continue
		var plan := _swing_plan(hr)
		if plan.is_empty():
			continue
		var live := _live_adds(adds)
		var on_boss: bool = int(hr["slot"]) == 0 or live.is_empty() or gf.core.open
		if on_boss and gf.is_invulnerable():
			continue
		if str(plan["kind"]) == "arm":
			_arm_heavy(hr)
			continue
		var defn := float(boss["def"]) if on_boss else float(live[0]["d"]["def"])
		var dmg := SomArena.physical_damage(float(hr["atk"]), defn, float(plan["mult"]), rng)
		if on_boss:
			var dealt := gf.damage(dmg)
			if dealt > 0:
				threat.note_damage(int(hr["slot"]), dealt, PageWardenBoss.is_tank(str(hr["h"]["id"])))
		else:
			live[0]["hp"] = int(live[0]["hp"]) - dmg
		_commit_swing(hr, plan)


static func _hurt(hr: Dictionary, dmg: int) -> void:
	hr["h"]["hp"] = maxi(0, int(hr["h"]["hp"]) - maxi(1, dmg))
	hr["iframes"] = float(SomData.DODGE_IFRAME_TICKS) * DT


static func _runtime(party: Array) -> Array:
	var heroes: Array = []
	var i := 0
	for h in party:
		heroes.append({
			"h": h, "slot": i, "charge": 1.0, "lock": 0.0,
			"walk": APPROACH * 0.5, "iframes": 0.0, "spell_cd": 1.0,
			"atk": float(Equipment.effective_stat(h, "atk")),
			"def": float(Equipment.effective_stat(h, "def")),
			"downed": int(h["hp"]) <= 0,
			"chain": 0, "gap": 0.0, "heavy": -1, "arm_heavy": false, "swings": 0,
		})
		i += 1
	return heroes


## Zelfde keten als het spel: vervolg 6 ticks ná de animatie, schade × SomChainData, AI-zware slag na de finisher.
static func chain_swing_count(ticks: int) -> int:
	var party := make_party(["dennis"], 0)
	var heroes := _runtime(party)
	var dummy := {
		"d": {"def": 0, "max_hp": 999999, "atk": 0, "name": "zak"},
		"hp": 999999, "approach": 0.0, "tele": 0.0, "cd": 99.0, "stun": 0.0, "target": -1, "exp": 0,
	}
	var active: Array = [dummy]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var n := maxi(1, ticks)
	for _i in n:
		_trash_heroes(heroes, active, rng, [], _i + 1)
	return int(heroes[0]["swings"])


static func _tick_hero_clock(hr: Dictionary) -> void:
	hr["iframes"] = maxf(0.0, float(hr["iframes"]) - DT)
	if float(hr["lock"]) > 0.0:
		hr["lock"] = float(hr["lock"]) - DT
	else:
		hr["charge"] = minf(1.0, float(hr["charge"]) + DT / SomData.CHARGE_TIME)
		if float(hr["gap"]) > 0.0:
			hr["gap"] = float(hr["gap"]) - DT
		if int(hr["heavy"]) >= 0:
			hr["heavy"] = int(hr["heavy"]) + 1


static func _swing_plan(hr: Dictionary) -> Dictionary:
	if float(hr["lock"]) > 0.0:
		return {}
	if int(hr["heavy"]) >= 0:
		if int(hr["heavy"]) >= int(Heavy.LEVEL_TICKS[0]):
			return {
				"kind": "heavy", "step": -1,
				"mult": Heavy.damage_mult(Heavy.ALLY_LEVEL),
				"anim": _anim_sec(Chain.STEP_FINISHER),
			}
		return {}
	var follow := int(hr["chain"]) > 0 and float(hr["gap"]) <= 0.0
	var gauged := float(hr["charge"]) >= 1.0
	if not follow and not gauged:
		return {}
	if not follow and bool(hr["arm_heavy"]):
		return {"kind": "arm", "step": -1, "mult": 0.0, "anim": 0.0}
	var step := int(hr["chain"]) if follow else 0
	var meter := 1.0 if follow else SomArena.charge_mult_with(float(hr["charge"]), SomData.CHARGE_MIN_MULT)
	if follow:
		meter = maxf(meter, Chain.FOLLOWUP_MIN_METER)
	return {
		"kind": "swing", "step": step,
		"mult": meter * Chain.damage_mult(step),
		"anim": _anim_sec(step),
	}


static func _arm_heavy(hr: Dictionary) -> void:
	hr["arm_heavy"] = false
	hr["heavy"] = 0
	hr["charge"] = 0.0
	hr["chain"] = 0
	hr["gap"] = 0.0


static func _commit_swing(hr: Dictionary, plan: Dictionary) -> void:
	hr["swings"] = int(hr["swings"]) + 1
	hr["charge"] = 0.0
	hr["lock"] = float(plan["anim"])
	hr["heavy"] = -1
	hr["walk"] = 0.25 if int(hr["slot"]) > 0 else 0.1
	if str(plan["kind"]) == "heavy":
		hr["chain"] = 0
		hr["gap"] = 0.0
		hr["arm_heavy"] = false
		return
	var step := int(plan["step"])
	if Chain.is_finisher(step):
		hr["chain"] = 0
		hr["gap"] = 0.0
		hr["arm_heavy"] = int(hr["slot"]) > 0
		return
	hr["chain"] = step + 1
	hr["gap"] = float(Chain.ALLY_FOLLOWUP_TICKS) * DT
	hr["arm_heavy"] = false


static func _stagger_time(plan: Dictionary) -> float:
	var stun := 0.0
	var step := int(plan["step"])
	var full := str(plan["kind"]) == "heavy" or (step >= 0 and (step == 0 or Chain.is_finisher(step) or float(plan["mult"]) >= 1.0))
	if full:
		stun = SomData.KNOCKBACK_TIME + 0.15
	if str(plan["kind"]) == "heavy":
		stun += float(Heavy.hitstop_ticks(Heavy.ALLY_LEVEL)) * DT
	elif step >= 0 and Chain.is_finisher(step):
		stun += float(Chain.hitstop_ticks(step)) * DT
	return stun


static func _anim_sec(step: int) -> float:
	var ms: Array = Chain.STEP_MS.get(Chain.state_for(step), [])
	if ms.is_empty():
		ms = SomData.ATTACK_MS
	var tot := 0.0
	for v in ms:
		tot += float(v)
	return tot / 1000.0


static func _in_range(active: Array, rng: RandomNumberGenerator, randomize: bool) -> Dictionary:
	var ready: Array = []
	for e in active:
		if float(e["approach"]) <= 0.0 and int(e["hp"]) > 0:
			ready.append(e)
	if ready.is_empty():
		return {}
	if randomize and ready.size() > 1:
		return ready[rng.randi() % ready.size()]
	return ready[0]


static func _grant_kill(heroes: Array, amount: int) -> void:
	if amount <= 0:
		return
	for hr in heroes:
		var hero: Dictionary = hr["h"]
		if int(hero["hp"]) <= 0:
			continue
		GameState.give_exp(hero, amount)
		hr["atk"] = float(Equipment.effective_stat(hero, "atk"))
		hr["def"] = float(Equipment.effective_stat(hero, "def"))


static func _pool_hp(heroes: Array) -> Vector2i:
	var hp := 0
	var mx := 0
	for hr in heroes:
		hp += maxi(0, int(hr["h"]["hp"]))
		mx += int(hr["h"]["max_hp"])
	return Vector2i(hp, mx)


static func _swing_total(heroes: Array) -> int:
	var n := 0
	for hr in heroes:
		n += int(hr["swings"])
	return n


static func _push_log(events: Array, tick: int, line: String) -> void:
	events.append({"t": tick, "s": "t=%d %s" % [tick, line]})


static func _tail_log(events: Array, ticks: int) -> PackedStringArray:
	var out := PackedStringArray()
	var start := ticks - 300
	for ev in events:
		if int(ev["t"]) >= start:
			out.append(str(ev["s"]))
	return out


static func _fight_result(win: bool, alive: bool, ticks: int, swings: int, quiet: int, hp: int, hp_max: int, log: PackedStringArray) -> Dictionary:
	var cause := "win"
	if not win:
		if not alive:
			cause = "wipe"
		elif swings == 0 or quiet >= 300:
			cause = "soft"
		else:
			cause = "timeout"
	return {
		"win": win, "wipe": cause == "wipe", "ticks": ticks, "cause": cause,
		"hp_end": hp, "hp_max": hp_max, "log": log, "swings": swings,
	}


static func _note_loss(row: Dictionary, fight: Dictionary, examples: Array, caps: Dictionary, meta: Dictionary) -> void:
	var cause := str(fight.get("cause", "other"))
	match cause:
		"wipe":
			row["cause_wipe"] = int(row["cause_wipe"]) + 1
			row["wipes"] = int(row["wipes"]) + 1
		"timeout":
			row["cause_timeout"] = int(row["cause_timeout"]) + 1
		"soft":
			row["cause_soft"] = int(row["cause_soft"]) + 1
		_:
			row["cause_other"] = int(row["cause_other"]) + 1
	row["losses"] = int(row["losses"]) + 1
	row["hp_end_sum"] = int(row["hp_end_sum"]) + int(fight.get("hp_end", 0))
	row["hp_end_max"] = int(row["hp_end_max"]) + int(fight.get("hp_max", 0))
	row["hp_end_n"] = int(row["hp_end_n"]) + 1
	_keep_example(examples, caps, meta, fight)


static func _keep_example(examples: Array, caps: Dictionary, meta: Dictionary, fight: Dictionary) -> void:
	var mx := maxi(1, int(fight.get("hp_max", 0)))
	var pct := float(fight.get("hp_end", 0)) / float(mx)
	var kind := ""
	if pct >= 0.60 and pct <= 0.90 and int(caps.get("high", 0)) < 2:
		kind = "high"
		caps["high"] = int(caps["high"]) + 1
	elif str(fight.get("cause", "")) == "wipe" and int(caps.get("wipe", 0)) < 1:
		kind = "wipe"
		caps["wipe"] = int(caps["wipe"]) + 1
	if kind == "":
		return
	var row := meta.duplicate()
	row["kind"] = kind
	row["cause"] = str(fight.get("cause", ""))
	row["pct"] = pct
	row["log"] = fight.get("log", PackedStringArray())
	examples.append(row)


static func _runtime_alive(heroes: Array) -> Array:
	var out: Array = []
	for hr in heroes:
		if int(hr["h"]["hp"]) > 0:
			out.append(hr)
	return out


static func _runtime_slot(heroes: Array, slot: int) -> Dictionary:
	for hr in heroes:
		if int(hr["slot"]) == slot and int(hr["h"]["hp"]) > 0:
			return hr
	for hr in heroes:
		if int(hr["h"]["hp"]) > 0:
			return hr
	return {}


static func _live_adds(adds: Array) -> Array:
	var out: Array = []
	for a in adds:
		if int(a["hp"]) > 0 and float(a["approach"]) <= 0.0:
			out.append(a)
	return out


static func party_ids_for(seats: int) -> Array:
	var out: Array = []
	var n := clampi(seats, 1, mini(4, PARTY_IDS.size()))
	for i in n:
		out.append(PARTY_IDS[i])
	return out


static func party_label(ids: Array) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for id in ids:
		bits.append(_hero_name(str(id)))
	return ", ".join(bits)


static func _hero_name(id: String) -> String:
	for h in GameData.HEROES:
		if str(h["id"]) == id:
			return str(h["name"])
	return id


static func make_party(ids: Array, exp_each: int) -> Array:
	var out: Array = []
	for id in ids:
		var src := {}
		for h in GameData.HEROES:
			if str(h["id"]) == str(id):
				src = (h as Dictionary).duplicate(true)
				break
		if src.is_empty():
			continue
		Equipment.init_hero(src)
		if exp_each > 0:
			GameState.give_exp(src, exp_each)
		src["hp"] = int(src["max_hp"])
		src["mp"] = int(src["max_mp"])
		out.append(src)
	return out


static func grant_exp(party: Array, amount: int) -> void:
	if amount <= 0:
		return
	for h in party:
		var hero: Dictionary = h
		var down := int(hero["hp"]) <= 0
		GameState.give_exp(hero, amount)
		if down:
			hero["hp"] = 0


static func rest_heal(party: Array) -> void:
	for h in party:
		var hero: Dictionary = h
		if int(hero["hp"]) <= 0:
			continue
		hero["hp"] = int(hero["max_hp"])
		hero["mp"] = int(hero["max_mp"])


static func level_of(party: Array) -> int:
	if party.is_empty():
		return 1
	return int(party[0]["level"])


static func any_alive(party: Array) -> bool:
	for h in party:
		if int(h["hp"]) > 0:
			return true
	return false


static func scaled_exp(base_exp: int, factor: int) -> int:
	return GameData.round_half_even(float(base_exp) * float(maxi(1, factor)))


## run_seed = (base + index * 10007) & 0x7FFFFFFF, 0 wordt 1.
static func run_seed_for(base_seed: int, index: int) -> int:
	var s := (base_seed + index * RUN_SEED_STEP) & 0x7FFFFFFF
	return s if s > 0 else 1


## combat_seed = mix(run_seed, vloer * 1000 + stoelen * 10 + soort, factor).
## soort: 1 troep, 2 baas in de klim, 3 hypo vol HP, 4 hypo Orion-partij.
static func combat_seed(run_seed: int, floor_no: int, seats: int, factor: int, kind: int) -> int:
	return mix_seed(run_seed, floor_no * 1000 + seats * 10 + kind, factor)


static func mix_seed(a: int, b: int, c: int) -> int:
	var x := (a & 0x7FFFFFFF) ^ (b & 0x7FFFFFFF) ^ ((c & 0x7FFFFFFF) << 1)
	x = (x * 1103515245 + 12345) & 0x7FFFFFFF
	x = (x * 1103515245 + (c & 0x7FFFF)) & 0x7FFFFFFF
	return x if x > 0 else 1


static func _djb2(s: String) -> int:
	var h := 5381
	for i in s.length():
		h = ((h << 5) + h + s.unicode_at(i)) & 0x7FFFFFFF
	return h


## Classic DLS, één seed, vloeren 1..98 (aankomst op eff 99). Factor 1, volledige groepen.
## Alleen een referentie in het rapport. Niet de online-run.
static func classic_arrival(seed_val: int) -> Dictionary:
	var total := 0
	var fights := 0
	for f in range(1, 99):
		var data := Generator.generate(seed_val, f)
		var room: Dictionary = data.get("room", {})
		var boss_done := false
		for m in room.get("monsters", []):
			var eid := str(m.get("enemy", ""))
			if eid == "" or not GameData.ENEMIES.has(eid):
				continue
			if bool(m.get("boss", false)):
				if boss_done:
					continue
				boss_done = true
				var bst: Dictionary = Scaling.boss_stats(GameData.ENEMIES[eid], f)
				total += int(bst.get("exp", 0))
				fights += 1
				continue
			var group: Array = m.get("group", [])
			if group.is_empty():
				group = [eid]
			for gid in group:
				if not GameData.ENEMIES.has(str(gid)):
					continue
				var st: Dictionary = Scaling.monster_stats(GameData.ENEMIES[str(gid)], f)
				total += int(st.get("exp", 0))
				fights += 1
	return {"seed": seed_val, "exp": total, "level": _level_for_exp(total), "fights": fights}


static func _level_for_exp(exp: int) -> int:
	var lv := 1
	while exp >= GameData.exp_for_level(lv + 1) and lv < 200:
		lv += 1
	return lv


static func signature(result: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("m=%s" % str(result.get("mode", "")))
	parts.append("b=%d" % int(result.get("base_seed", 0)))
	parts.append("r=%d" % int(result.get("runs", 0)))
	parts.append("f=%d" % int(result.get("floors", 0)))
	parts.append("map=%d" % int(result.get("map_fp", 0)))
	for s in result.get("run_seeds", []):
		parts.append("s=%d" % int(s))
	for row in result.get("rows", []):
		parts.append("F%d.S%d" % [int(row["factor"]), int(row["seats"])])
		parts.append("e=%d" % int(row["exp_clear_sum"]))
		parts.append("h=%d/%d/%d/%d" % [int(row["hypo_n"]), int(row["hypo_wins"]), int(row["hypo_ticks"]), int(row["hypo_level_sum"])])
		parts.append("o=%d/%d" % [int(row["hypo_orion_wins"]), int(row["hypo_orion_ticks"])])
		for fl in row["floors"]:
			parts.append("%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [
				int(fl["floor"]), int(fl["eff"]), int(fl["boss_key"]), int(fl["entered"]), int(fl["wins"]),
				int(fl["losses"]), int(fl["wipes"]), int(fl["ticks"]), int(fl["level_sum"]),
				int(fl["hp_sum"]), int(fl["hp_max_sum"]), int(fl["enemy_sum"]),
				int(fl["boss_entered"]), int(fl["boss_wins"]), int(fl["boss_wipes"]), int(fl["boss_ticks"]),
			])
			parts.append("bl=%d" % int(fl["boss_level_sum"]))
			parts.append("c=%d/%d/%d/%d/%d/%d/%d" % [
				int(fl["cause_wipe"]), int(fl["cause_timeout"]), int(fl["cause_soft"]), int(fl["cause_other"]),
				int(fl["hp_end_sum"]), int(fl["hp_end_max"]), int(fl["hp_end_n"]),
			])
	var ex_bits := PackedStringArray()
	for ex in result.get("examples", []):
		ex_bits.append("%s:%s:%d:%d" % [str(ex.get("kind", "")), str(ex.get("cause", "")), int(ex.get("floor", 0)), int(ex.get("seed", 0))])
	parts.append("ex=%d" % _djb2("|".join(ex_bits)))
	return "|".join(parts)


static func markdown(result: Dictionary, cfg: Dictionary, classic: Dictionary, ms: int) -> String:
	var mode := str(result["mode"])
	var runs := int(result["runs"])
	var base_seed := int(result["base_seed"])
	var factors: Array = cfg.get("factors", [])
	var game_factor := Modes.mode_exp_factor(mode)
	var s := "# M9b — Easy-sim (voorstel)\n\n"
	s += "VOORSTEL voor Dennis. Geen balanswijziging: `OnlineDlsModes.mode_exp_factor` blijft %d " % game_factor
	s += "(`PROPOSAL_MODE_EXP_NUMERATOR` %d / %d vloeren). " % [Modes.PROPOSAL_MODE_EXP_NUMERATOR, Modes.floors(mode)]
	s += "De factor hier is alleen een parameter van deze sim.\n\n"
	s += "Host-autoritatief, één RNG per gevecht. Zelfde seed = zelfde uitkomst.\n\n"
	s += "- Modus: `%s`. Runs: %d. Vloeren: %d (Page Warden, boss_key %d, op de laatste baasvloer).\n" % [mode, runs, int(result["floors"]), PageWardenBoss.BOSS_KEY]
	s += "- Basis-seed: `%d`. `run_seed = (base + index * %d) & 0x7FFFFFFF` (0 wordt 1).\n" % [base_seed, RUN_SEED_STEP]
	s += "- `combat_seed = mix(run_seed, vloer * 1000 + stoelen * 10 + soort, factor)` met soort 1=troep, 2=baas, 3=hypo vol HP, 4=hypo Orion-partij. `mix_seed` staat in `tools/battlesim/d100_mode_sim.gd`.\n"
	s += "- Run-seeds:"
	for rs in result["run_seeds"]:
		s += " %d" % int(rs)
	s += "\n"
	s += "- Page Warden VOORSTEL (ongewijzigd, #420): ACTION_HP_MULT %.2f, ACTION_ATK_MULT %.2f, SEAT_HP %s, SEAT_ATK %s.\n" % [
		PageWardenBoss.ACTION_HP_MULT, PageWardenBoss.ACTION_ATK_MULT, str(PageWardenBoss.SEAT_HP), str(PageWardenBoss.SEAT_ATK)]
	s += "- Partij: %s. Stoel 0 is de host (ontwijk %.2f), de rest is AI (ontwijk %.2f). Bij 4 stoelen zit Orion er niet bij.\n" % [party_label(PARTY_IDS), DODGE_PLAYER, DODGE_ALLY]
	s += "- Kaart: `OnlineDlsFloor.build` (eff, cap %d, groep = één vijand). Troep max %d s, baas max %d s, golf %d.\n" % [Modes.enemy_cap(), TRASH_MAX_TICKS / 60, BOSS_MAX_TICKS / 60, WAVE]
	s += "- Rust op Easy vloer 5 heelt levenden. Geen drankjes en geen feniksveer (handmatig in het spel, de AI gebruikt ze niet). M8a zit niet in de code: een held op 0 HP blijft liggen. Eén down is geen verlies.\n"
	s += "- EXP per stoel, vol, meteen per vijand (`round_half_even(basis × factor)`). Keten: hit1/hit2/finisher, vervolg 6 ticks na de animatie. Klassieke DLS stript spreuken; deze sim houdt de klasse-spreuken.\n"
	s += "- Duur is gevechtstijd (60 Hz), zonder looptijd. Tooltijd %.1f s.\n\n" % [ms / 1000.0]
	s += "Herhalen:\n\n```\n%s\n```\n\n" % _command(cfg)
	s += "## Per vloer\n\n"
	s += "Level bij binnenkomst, vóór het gevecht. Winst = de vloer leeg (op vloer 10: troep én Page Warden). Een wipe telt ook als verlies. Niet bereikt = eerdere wipe of verlies.\n\n"
	s += "HP in = partij-HP bij binnenkomst, vóór het rustpunt. Vijanden = gemiddelde op die vloer (zelfde kaarten voor elke factor).\n\n"
	s += "| factor | stoelen | vloer | eff | level in | HP in | vijanden | bereikt | winst | verlies | wipes | duur s |\n"
	s += "|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for row in result["rows"]:
		for fl in row["floors"]:
			s += "| %d | %d | %d | %d | %s | %s | %s | %d/%d | %s | %s | %d | %s |\n" % [
				int(row["factor"]), int(row["seats"]), int(fl["floor"]), int(fl["eff"]),
				_lvl(int(fl["level_sum"]), int(fl["entered"])),
				_pct_plain(int(fl["hp_sum"]), int(fl["hp_max_sum"])),
				_lvl(int(fl["enemy_sum"]), runs),
				int(fl["entered"]), runs,
				_pct(int(fl["wins"]), int(fl["entered"])),
				_pct(int(fl["losses"]), int(fl["entered"])),
				int(fl["wipes"]),
				_sec(int(fl["ticks"]), int(fl["entered"])),
			]
	s += "\n## Oorzaak van een verlies\n\n"
	s += "HP in (tabel hierboven) is de partij-HP bij binnenkomst. HP uit is de partij-HP op het moment dat de vloer verloren gaat. "
	s += "Wipe = iedereen op 0. Time-out = tick-cap (troep 120 s, baas 180 s) terwijl er nog iemand leeft en er nog geslagen wordt. "
	s += "Softlock = tick-cap zonder een enkele slag, of de laatste 5 s geen slag en geen treffer.\n\n"
	s += "| factor | stoelen | vloer | verliezen | wipe | time-out | softlock | anders | HP uit |\n"
	s += "|---|---|---|---|---|---|---|---|---|\n"
	for row in result["rows"]:
		for fl in row["floors"]:
			var losses := int(fl["losses"])
			if losses <= 0:
				continue
			s += "| %d | %d | %d | %d | %d | %d | %d | %d | %s |\n" % [
				int(row["factor"]), int(row["seats"]), int(fl["floor"]), losses,
				int(fl["cause_wipe"]), int(fl["cause_timeout"]), int(fl["cause_soft"]), int(fl["cause_other"]),
				_pct_plain(int(fl["hp_end_sum"]), int(fl["hp_end_max"])),
			]
	s += "\n## Wat de sim gelijk doet aan de online Easy-run\n\n"
	s += "- Tussen vloeren blijven HP en MP staan. Alleen rustvloer 5 (BookPoint.restore) vult levenden bij. Wie op 0 staat, blijft liggen.\n"
	s += "- Eén down is geen verlies. De vloer eindigt als de vijanden dood zijn, als iedereen op 0 ligt, of op de tick-cap.\n"
	s += "- Feniksveer en drankjes zijn een handmatige ring-actie (`PartyActions.use_item`). De bondgenoot-AI gebruikt ze niet. Deze sim ook niet. M8a ontbreekt, dus geen automatische revive.\n"
	s += "- EXP valt per verslagen vijand, vol, aan elke levende held, meteen (`give_exp`). Een level-up vult HP bij met de groei.\n"
	s += "- Aanvalsketen zoals `som_ally.gd`: hit1 ×1.0, hit2 ×1.1, finisher ×1.6, vervolg %d ticks na de animatie (venster %d). " % [Chain.ALLY_FOLLOWUP_TICKS, Chain.CHAIN_WINDOW_TICKS]
	s += "De host ketent hetzelfde. Na de finisher laadt een AI-bondgenoot een zware slag niveau %d (%d ticks, ×%.1f).\n" % [Heavy.ALLY_LEVEL, int(Heavy.LEVEL_TICKS[0]), Heavy.damage_mult(Heavy.ALLY_LEVEL)]
	s += "- Page Warden: doelkeuze, klapvorm, bondgenoot-spreuk en adds komen uit `page_warden_rt_sim.gd`. De slag zelf blijft de keten; die sim laadt nog een volle meter.\n"
	s += "- Doel is een vijand die al aangekomen is. Een nog lopende vijand verspilt de slag niet.\n"
	s += "- Vijandschade × `ENEMY_DAMAGE_MULT` %.1f, dezelfde factor als `enemy_damage_mult` op een kamer zonder gebiedsregel.\n\n" % SomData.ENEMY_DAMAGE_MULT
	s += _example_section(result)
	s += "\n## Page Warden (klim)\n\n"
	s += "Alleen wie de troep op de baasvloer overleeft, vecht de baas. Level is dán (na de EXP van die troep). Winst-alle-runs telt een run die de baas niet haalt als verlies.\n\n"
	s += "| factor | stoelen | level bij baas | baas bereikt | winst van aankomst | winst van alle runs | wipes | duur s |\n"
	s += "|---|---|---|---|---|---|---|---|\n"
	for row in result["rows"]:
		var fl := _boss_floor(row)
		if fl.is_empty():
			continue
		s += "| %d | %d | %s | %d/%d | %s | %s | %d | %s |\n" % [
			int(row["factor"]), int(row["seats"]),
			_lvl(int(fl["boss_level_sum"]), int(fl["boss_entered"])),
			int(fl["boss_entered"]), runs,
			_pct(int(fl["boss_wins"]), int(fl["boss_entered"])),
			_pct(int(fl["boss_wins"]), runs),
			int(fl["boss_wipes"]),
			_sec(int(fl["boss_ticks"]), int(fl["boss_entered"])),
		]
	s += "\n## Page Warden bij vol HP (hypothese)\n\n"
	s += "Elke run krijgt de EXP van de vloeren vóór de baas (niet de troep op de baasvloer) en vecht de Page Warden op vol HP, zonder slijtage. "
	s += "Dit is de vergelijking met #420, dat de baas op één vast level zette. "
	s += "Orion-partij = Dax, Seren, Vesper, Orion (de 4-stoel-partij van die sim). De klim hierboven gebruikt bij 4 stoelen Kael Voss in plaats van Orion.\n\n"
	if not bool(result.get("hypothetical", false)):
		s += "Hypothese uit (`--no-hypo`).\n\n"
	else:
		s += "| factor | stoelen | level | n | winst | duur s | Orion-winst |\n"
		s += "|---|---|---|---|---|---|---|\n"
		for row in result["rows"]:
			var orion := "—"
			if int(row["seats"]) == 4 and int(row["hypo_n"]) > 0:
				orion = _pct(int(row["hypo_orion_wins"]), int(row["hypo_n"]))
			s += "| %d | %d | %s | %d | %s | %s | %s |\n" % [
				int(row["factor"]), int(row["seats"]),
				_lvl(int(row["hypo_level_sum"]), int(row["hypo_n"])),
				int(row["hypo_n"]),
				_pct(int(row["hypo_wins"]), int(row["hypo_n"])),
				_sec(int(row["hypo_ticks"]), int(row["hypo_n"])),
				orion,
			]
		s += "\n"
	s += "## Classic-referentie\n\n"
	if classic.is_empty():
		s += "Niet meegerekend (`--no-classic`).\n\n"
	else:
		s += "Solo Classic, seed %d, vloeren 1–98, factor 1, volledige monstergroepen inclusief bazen: EXP %d → level %d (%d gevechten). " % [
			int(classic["seed"]), int(classic["exp"]), int(classic["level"]), int(classic["fights"])]
		s += "Het ontwerp wil dat Easy-vloer 10 ongeveer dit level haalt (eff 99). Dat getal is een referentie, geen doel dat deze PR afdwingt.\n\n"
	s += "## Kandidaat-factoren\n\n"
	s += "Huidige spelwaarde: **%d** (= %d/%d). " % [game_factor, Modes.PROPOSAL_MODE_EXP_NUMERATOR, Modes.floors(mode)]
	s += "Gesimuleerd:"
	for fac in factors:
		s += " %d" % int(fac)
	s += ". Voor Easy is 100/N hetzelfde getal als 10; de andere waarden zijn extra kandidaten, geen nieuwe standaard.\n\n"
	s += "## Aanbeveling (voorstel)\n\n"
	s += "<!-- AANBEVELING -->\n"
	s += "In te vullen bij deze run. Geen getal in dit bestand is canon.\n"
	return s


static func _example_section(result: Dictionary) -> String:
	var examples: Array = result.get("examples", [])
	if examples.is_empty():
		return "Geen verlies-log (elke bereikte vloer viel).\n\n"
	var s := "## Logs van een verlies (laatste 300 ticks)\n\n"
	s += "Alleen als de partij bij het verlies nog 60–90% HP heeft, of — als dat niet voorkomt — één wipe waarbij de HP naar 0 loopt. "
	s += "HP in is de binnenkomst van die vloer.\n\n"
	for ex in examples:
		var inn := _pct_plain(int(ex.get("hp_in", 0)), int(ex.get("hp_in_max", 0)))
		s += "### %s, factor %d, %d stoelen, vloer %d, seed %d\n\n" % [
			str(ex.get("kind", "")), int(ex.get("factor", 0)), int(ex.get("seats", 0)), int(ex.get("floor", 0)), int(ex.get("seed", 0))]
		s += "Oorzaak `%s`. HP in %s. HP uit %.0f%%.\n\n```\n" % [str(ex.get("cause", "")), inn, float(ex.get("pct", 0.0)) * 100.0]
		var log: PackedStringArray = ex.get("log", PackedStringArray())
		var shown := 0
		for line in log:
			s += line + "\n"
			shown += 1
			if shown >= 80:
				s += "…\n"
				break
		s += "```\n\n"
	return s


static func _boss_floor(row: Dictionary) -> Dictionary:
	for fl in row["floors"]:
		if int(fl["boss_key"]) == PageWardenBoss.BOSS_KEY:
			return fl
	return {}


static func _command(cfg: Dictionary) -> String:
	var factors: Array = cfg.get("factors", [])
	var bits: PackedStringArray = PackedStringArray()
	for fac in factors:
		bits.append(str(int(fac)))
	var seats: Array = cfg.get("seats", [])
	var sb: PackedStringArray = PackedStringArray()
	for n in seats:
		sb.append(str(int(n)))
	var extra := ""
	if not bool(cfg.get("hypothetical", true)):
		extra += " --no-hypo"
	if not bool(cfg.get("classic_ref", true)):
		extra += " --no-classic"
	var out := str(cfg.get("out", ""))
	if out != "":
		extra += " --out=%s" % out
	return "xvfb-run -a godot --rendering-driver opengl3 --path . -- --d100modesim --mode=%s --factors=%s --seats=%s --runs=%d --seed=%d --floors=%d%s" % [
		str(cfg.get("mode", "easy")), ",".join(bits), ",".join(sb), int(cfg.get("runs", DEFAULT_RUNS)),
		int(cfg.get("base_seed", DEFAULT_SEED)), int(cfg.get("floors", 10)), extra]


static func _lvl(sum: int, n: int) -> String:
	if n <= 0:
		return "—"
	return "%.1f" % (float(sum) / float(n))


static func _pct_plain(num: int, den: int) -> String:
	if den <= 0:
		return "—"
	return "%.0f%%" % (float(num) * 100.0 / float(den))


static func _pct(num: int, den: int) -> String:
	if den <= 0:
		return "—"
	return "%.1f%% (%d)" % [float(num) * 100.0 / float(den), num]


static func _sec(ticks: int, n: int) -> String:
	if n <= 0:
		return "—"
	return "%.1f" % (float(ticks) / float(n) / 60.0)
