extends Node
## M9a: headless actiesim van de Page Warden (PageWardenFight, de echte host-logica).
## godot --path . -- --pagewardensim [--fights=200] [--seats=1|2|3|4] [--seed=20261110]
##
## AANNAMES (sim, geen speldata; de VOORSTEL-constanten staan in PageWardenBoss):
##  - Party = DLS-start: level 1, geen uitrusting. Klas-spreuken blijven (afwijking van Classic,
##    dat spreuken stript; de rollen liggen in kisten en zijn hier de basis-kit).
##  - Level = EXP van verdieping 1..9, vol per held (online: EXP per stoel). Easy: effectieve
##    verdieping round(1+(f-1)*98/9) en mode_exp_factor 10 (PROPOSAL §7.0, niet in code).
##    Classic (factor 1, verdieping = zichzelf) wordt alleen ter vergelijking geprint.
##  - Geen drankjes. Zetel 0 ontwijkt 0,35, de rest 0,15. Iframes dekken de actieve fase.
##  - Vorm, abstract: lijn/volley alleen het doel, cirkel iedereen, waaier het doel + 45% per ander.
##  - Afstand, abstract: zetel 0 op 2,5 tegel, zetel 1 op 1,1, zetel 2 op 1,75, zetel 3 op 2,25.
##    ThreatTable
##    kiest het doel alleen bij telegraph_start. Niet altijd de host.
##  - Baas-klap zonder ENEMY_DAMAGE_MULT (zoals de Golem). De add (monster_stats vloer 10) mét.
##  - Eén papiergeest-add. Langer dan 180 s = verlies.

const SomData := preload("res://scripts/data/som_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const DamageCalc := preload("res://scripts/battle/damage_calc.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Generator := preload("res://scripts/dungeon/dungeon100_generator.gd")
const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
const PageWardenFight := preload("res://scripts/som/page_warden_fight.gd")
const ThreatTable := preload("res://scripts/som/threat_table.gd")
const Equipment := preload("res://scripts/equipment.gd")

const DT := 1.0 / 60.0
const MAX_TICKS := 180 * 60
const LEVEL_SEED := 20261110
const MODE_EXP_FACTOR := 10
const DODGE_PLAYER := 0.35
const DODGE_ALLY := 0.15
const FAN_SPLASH := 0.45
const SEAT_IDS := ["dennis", "lotte", "noor", "orion"]

var _add_data: Dictionary = {}
var _params: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var fights := 200
	var only := 0
	var seed_val := LEVEL_SEED
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--fights="):
			fights = maxi(1, int(s.trim_prefix("--fights=")))
		elif s.begins_with("--seats="):
			only = clampi(int(s.trim_prefix("--seats=")), 1, 4)
		elif s.begins_with("--seed="):
			seed_val = int(s.trim_prefix("--seed="))
	_add_data = Scaling.monster_stats((GameData.ENEMIES["papiergeest"] as Dictionary).duplicate(true), PageWardenBoss.BOSS_KEY)
	_params = fight_params()
	var easy_exp := _exp_over_floors(true)
	var classic_exp := _exp_over_floors(false)
	var easy_lv := _level_for_exp(easy_exp)
	var classic_lv := _level_for_exp(classic_exp)
	print("PAGE WARDEN SIM")
	print("aanname Easy: vloeren 1-9, eff round(1+(f-1)*98/9), mode_exp_factor %d (voorstel), seed %d" % [MODE_EXP_FACTOR, seed_val])
	print("EXP per held Easy %d → level %d | Classic (factor 1, vloer=zichzelf) EXP %d → level %d" % [easy_exp, easy_lv, classic_exp, classic_lv])
	print("kit: naakt, klas-spreuken aan, 0 items, dodge %.2f / %.2f, add papiergeest vloer 10 HP %d ATK %d" % [DODGE_PLAYER, DODGE_ALLY, int(_add_data["max_hp"]), int(_add_data["atk"])])
	print("VOORSTEL ACTION_HP_MULT %.2f ACTION_ATK_MULT %.2f SEAT_HP %s SEAT_ATK %s break %d" % [
		PageWardenBoss.ACTION_HP_MULT, PageWardenBoss.ACTION_ATK_MULT, str(PageWardenBoss.SEAT_HP), str(PageWardenBoss.SEAT_ATK),
		int(PageWardenBoss.STAGGER["break_damage"])])
	print("| stoelen | n | win%% | tijd s | HP-verlies | p90 | downs | doel≠host |")
	var from_s := 1 if only == 0 else only
	var to_s := 4 if only == 0 else only
	for seats in range(from_s, to_s + 1):
		var row := _run_seats(seats, fights, seed_val, easy_exp)
		print("| %d | %d | %.1f | %.1f | %.1f%% | %.1f%% | %.2f | %.1f%% |" % [
			seats, fights, float(row["win"]) * 100.0, float(row["time"]), float(row["loss"]) * 100.0,
			float(row["p90"]) * 100.0, float(row["downs"]), float(row["off_host"]) * 100.0])
	print("RESULT SIM klaar")
	get_tree().quit(0)


func _run_seats(seats: int, n: int, seed_val: int, exp_each: int) -> Dictionary:
	var ids: Array = []
	for i in seats:
		ids.append(SEAT_IDS[i])
	var party := _party(ids, exp_each)
	var boss := PageWardenBoss.stats_for_seats(seats)
	print("  stoel %d party L%s HP %s ATK %s | baas HP %d ATK %d DEF %d" % [
		seats, _levels(party), _hps(party), _atks(party), int(boss["max_hp"]), int(boss["atk"]), int(boss["def"])])
	var wins := 0
	var losses: Array = []
	var times: Array = []
	var downs := 0
	var off := 0
	var telegraphs := 0
	for i in n:
		var r := _fight(party, boss, hash([seed_val, seats, i]))
		if r["win"]:
			wins += 1
		losses.append(r["loss"])
		times.append(r["time"])
		downs += int(r["downs"])
		off += int(r["off_host"])
		telegraphs += int(r["telegraphs"])
	losses.sort()
	return {
		"win": float(wins) / float(n),
		"time": _mean(times),
		"loss": _mean(losses),
		"p90": losses[mini(losses.size() - 1, int(float(losses.size()) * 0.9))],
		"downs": float(downs) / float(n),
		"off_host": float(off) / float(maxi(1, telegraphs)),
	}


func _fight(party_in: Array, boss: Dictionary, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var gf := PageWardenFight.new(int(boss["max_hp"]), seed_val)
	var threat := ThreatTable.new()
	var heroes: Array = []
	var max_total := 0
	var i := 0
	for h in party_in:
		var copy: Dictionary = (h as Dictionary).duplicate(true)
		max_total += int(copy["max_hp"])
		heroes.append({
			"h": copy, "slot": i, "charge": 1.0, "lock": 0.0,
			"walk": float(_params["approach"]) * 0.5, "iframes": 0.0, "spell_cd": 1.0,
			"atk": float(Equipment.effective_stat(copy, "atk")),
			"def": float(Equipment.effective_stat(copy, "def")),
			"downed": false,
		})
		i += 1
	var adds: Array = []
	var target := -1
	var downs := 0
	var off_host := 0
	var telegraphs := 0
	var t := 0
	while t < MAX_TICKS and not gf.is_dead():
		if _alive(heroes).is_empty():
			break
		t += 1
		gf.tick()
		for ev in gf.take_events():
			match str(ev.get("type", "")):
				"telegraph_start":
					target = _choose(threat, heroes, bool(ev.get("ranged", false)), t)
					telegraphs += 1
					if target > 0:
						off_host += 1
				"attack_hit":
					_boss_hit(heroes, boss, target, str(ev.get("id", "")), float(ev.get("power", 1.0)), rng)
				"adds":
					_spawn_adds(adds, ev.get("ids", []))
				"stagger_break":
					target = -1
		_heroes_tick(gf, heroes, adds, boss, rng, threat)
		_adds_tick(heroes, adds, target, rng)
		for hr in heroes:
			if not bool(hr["downed"]) and int(hr["h"]["hp"]) <= 0:
				hr["downed"] = true
				downs += 1
				threat.clear_slot(int(hr["slot"]))
	var end_hp := 0
	for hr in heroes:
		end_hp += maxi(0, int(hr["h"]["hp"]))
	return {
		"win": gf.is_dead(),
		"loss": float(max_total - end_hp) / float(maxi(1, max_total)),
		"time": float(t) * DT,
		"downs": downs,
		"off_host": off_host,
		"telegraphs": telegraphs,
	}


func _choose(threat: ThreatTable, heroes: Array, ranged: bool, tick: int) -> int:
	var rows: Array = []
	for hr in heroes:
		if int(hr["h"]["hp"]) <= 0:
			continue
		# Vaste opstelling (de loop is alleen de aanlooptijd tot de eerste slag).
		# Zetel 0 staat op 2,5 tegel; de anderen dichter. Bij gelijke threat wint de dichtstbijzijnde,
		# dus het eerste doel is niet de host zodra er een bondgenoot leeft.
		var dist := 40.0
		match int(hr["slot"]):
			1:
				dist = 18.0
			2:
				dist = 28.0
			3:
				dist = 36.0
		rows.append({"slot": int(hr["slot"]), "dist": dist})
	rows.sort_custom(func(a, b):
		if is_equal_approx(float(a["dist"]), float(b["dist"])):
			return int(a["slot"]) < int(b["slot"])
		return float(a["dist"]) < float(b["dist"]))
	var ids: Array = []
	var near: Array = []
	for row in rows:
		ids.append(int(row["slot"]))
		if float(row["dist"]) <= 32.0:
			near.append(int(row["slot"]))
	return threat.choose(ids, near, ranged, tick)


func _boss_hit(heroes: Array, boss: Dictionary, target: int, id: String, power: float, rng: RandomNumberGenerator) -> void:
	var victims: Array = []
	for hr in heroes:
		if int(hr["h"]["hp"]) <= 0:
			continue
		var slot := int(hr["slot"])
		if id == "page_circle":
			victims.append(hr)
		elif id == "page_fan":
			if slot == target or rng.randf() < FAN_SPLASH:
				victims.append(hr)
		elif slot == target:
			victims.append(hr)
	for hr in victims:
		if float(hr["iframes"]) > 0.0:
			continue
		var dodge := DODGE_PLAYER if int(hr["slot"]) == 0 else DODGE_ALLY
		if rng.randf() < dodge:
			hr["iframes"] = float(SomData.DODGE_IFRAME_TICKS) * DT
			continue
		var dmg := SomArena.physical_damage(float(boss["atk"]), float(hr["def"]), power, rng)
		_hurt(hr, dmg)


func _hurt(hr: Dictionary, dmg: int) -> void:
	hr["h"]["hp"] = maxi(0, int(hr["h"]["hp"]) - maxi(1, dmg))
	hr["iframes"] = float(SomData.DODGE_IFRAME_TICKS) * DT


func _heroes_tick(gf: PageWardenFight, heroes: Array, adds: Array, boss: Dictionary, rng: RandomNumberGenerator, threat: ThreatTable) -> void:
	for hr in heroes:
		if int(hr["h"]["hp"]) <= 0:
			continue
		hr["iframes"] = maxf(0.0, float(hr["iframes"]) - DT)
		if float(hr["lock"]) > 0.0:
			hr["lock"] = float(hr["lock"]) - DT
		else:
			hr["charge"] = minf(1.0, float(hr["charge"]) + DT / float(_params["charge_time"]))
		if float(hr["walk"]) > 0.0:
			hr["walk"] = float(hr["walk"]) - DT
			continue
		if int(hr["slot"]) > 0:
			hr["spell_cd"] = float(hr["spell_cd"]) - DT
			if float(hr["spell_cd"]) <= 0.0 and _ally_spell(gf, hr, heroes, boss, rng, threat):
				hr["spell_cd"] = float(_params["ally_spell_cd"])
				hr["lock"] = float(_params["anim"])
				continue
			if float(hr["spell_cd"]) <= 0.0:
				hr["spell_cd"] = 0.0
		if float(hr["lock"]) > 0.0 or float(hr["charge"]) < 1.0:
			continue
		var live := _live_adds(adds)
		var on_boss: bool = int(hr["slot"]) == 0 or live.is_empty() or gf.core.open
		if on_boss and gf.is_invulnerable():
			continue
		var defn := float(boss["def"]) if on_boss else float(live[0]["d"]["def"])
		var dmg := SomArena.physical_damage(float(hr["atk"]), defn, 1.0, rng)
		if on_boss:
			var dealt := gf.damage(dmg)
			if dealt > 0:
				threat.note_damage(int(hr["slot"]), dealt, PageWardenBoss.is_tank(str(hr["h"]["id"])))
		else:
			live[0]["hp"] = int(live[0]["hp"]) - dmg
		hr["charge"] = 0.0
		hr["lock"] = float(_params["anim"])


func _ally_spell(gf: PageWardenFight, hr: Dictionary, heroes: Array, boss: Dictionary, rng: RandomNumberGenerator, threat: ThreatTable) -> bool:
	var h: Dictionary = hr["h"]
	for s in h.get("spells", []):
		var sp: Dictionary = GameData.SPELLS.get(str(s), {})
		if sp.is_empty() or int(h["mp"]) < int(sp.get("mp", 0)):
			continue
		if str(sp.get("type", "")) == "heal":
			var low: Dictionary = {}
			var lr := float(_params["ally_heal_below"])
			for o in heroes:
				var ratio := float(o["h"]["hp"]) / maxf(1.0, float(o["h"]["max_hp"]))
				if int(o["h"]["hp"]) > 0 and ratio < lr:
					lr = ratio
					low = o["h"]
			if low.is_empty():
				continue
			h["mp"] = int(h["mp"]) - int(sp["mp"])
			var gain := roundi(DamageCalc.spell_base({"s": h, "is_hero": true, "buffs": []}, sp, {}))
			var before := int(low["hp"])
			low["hp"] = mini(int(low["max_hp"]), before + gain)
			threat.note_heal(int(hr["slot"]), int(low["hp"]) - before, PageWardenBoss.is_tank(str(h["id"])))
			return true
		if str(sp.get("type", "")) == "damage" and rng.randf() < float(_params["ally_dmg_chance"]) and not gf.is_invulnerable():
			h["mp"] = int(h["mp"]) - int(sp["mp"])
			var amt := DamageCalc.spell_base({"s": h, "is_hero": true, "buffs": []}, sp, {"s": boss})
			var dealt := gf.damage(maxi(1, roundi(amt * rng.randf_range(0.9, 1.1))))
			if dealt > 0:
				threat.note_damage(int(hr["slot"]), dealt, PageWardenBoss.is_tank(str(h["id"])))
			return true
	return false


func _spawn_adds(adds: Array, ids: Array) -> void:
	var living := 1
	for a in adds:
		if int(a["hp"]) > 0:
			living += 1
	var kept: Array = PageWardenBoss.clamp_adds(living, ids, PageWardenBoss.SNAPSHOT_ENEMY_BUDGET)
	for id in kept:
		if str(id) != "papiergeest":
			continue
		adds.append({"d": _add_data, "hp": int(_add_data["max_hp"]), "approach": float(_params["approach"]), "tele": 0.0, "cd": 0.4})


func _adds_tick(heroes: Array, adds: Array, target: int, rng: RandomNumberGenerator) -> void:
	for e in adds:
		if int(e["hp"]) <= 0:
			continue
		if float(e["approach"]) > 0.0:
			e["approach"] = float(e["approach"]) - DT
			continue
		if float(e["tele"]) > 0.0:
			e["tele"] = float(e["tele"]) - DT
			if float(e["tele"]) <= 0.0:
				e["cd"] = float(_params["enemy_cd"])
				var hr := _hero_slot(heroes, target if target >= 0 else 0)
				if hr.is_empty() or int(hr["h"]["hp"]) <= 0 or float(hr["iframes"]) > 0.0:
					continue
				var dodge := DODGE_PLAYER if int(hr["slot"]) == 0 else DODGE_ALLY
				if rng.randf() >= dodge:
					var dmg := roundi(SomArena.physical_damage(float(e["d"]["atk"]), float(hr["def"]), 1.0, rng) * float(_params["enemy_dmg"]))
					_hurt(hr, dmg)
			continue
		if float(e["cd"]) > 0.0:
			e["cd"] = float(e["cd"]) - DT
			continue
		e["tele"] = float(_params["telegraph"])


func _hero_slot(heroes: Array, slot: int) -> Dictionary:
	for hr in heroes:
		if int(hr["slot"]) == slot and int(hr["h"]["hp"]) > 0:
			return hr
	for hr in heroes:
		if int(hr["h"]["hp"]) > 0:
			return hr
	return {}


func _live_adds(adds: Array) -> Array:
	var out: Array = []
	for a in adds:
		if int(a["hp"]) > 0 and float(a["approach"]) <= 0.0:
			out.append(a)
	return out


func _alive(heroes: Array) -> Array:
	var out: Array = []
	for hr in heroes:
		if int(hr["h"]["hp"]) > 0:
			out.append(hr)
	return out


func _party(ids: Array, exp_each: int) -> Array:
	var out: Array = []
	for id in ids:
		var src := {}
		for h in GameData.HEROES:
			if str(h["id"]) == str(id):
				src = (h as Dictionary).duplicate(true)
		Equipment.init_hero(src)
		if exp_each > 0:
			GameState.give_exp(src, exp_each)
		src["hp"] = src["max_hp"]
		src["mp"] = src["max_mp"]
		out.append(src)
	return out


func _exp_over_floors(easy: bool) -> int:
	var total := 0
	for f in range(1, 10):
		var eff := _easy_eff(f) if easy else f
		var gen := Generator.generate(LEVEL_SEED, f)
		var room: Dictionary = gen.get("room", {})
		for m in room.get("monsters", []):
			if bool(m.get("boss", false)):
				continue
			var group: Array = m.get("group", [])
			if group.is_empty():
				group = [str(m.get("enemy", ""))]
			for eid in group:
				if not GameData.ENEMIES.has(str(eid)):
					continue
				var st := Scaling.monster_stats((GameData.ENEMIES[str(eid)] as Dictionary).duplicate(true), eff)
				total += int(st.get("exp", 0))
	if easy:
		total *= MODE_EXP_FACTOR
	return total


func _easy_eff(mode_floor: int) -> int:
	return roundi(1.0 + float(mode_floor - 1) * 98.0 / 9.0)


func _level_for_exp(exp: int) -> int:
	var lv := 1
	while exp >= GameData.exp_for_level(lv + 1) and lv < 200:
		lv += 1
	return lv


func _levels(party: Array) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for h in party:
		bits.append(str(int(h["level"])))
	return "/".join(bits)


func _hps(party: Array) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for h in party:
		bits.append(str(int(h["max_hp"])))
	return "/".join(bits)


func _atks(party: Array) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for h in party:
		bits.append(str(Equipment.effective_stat(h, "atk")))
	return "/".join(bits)


func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(maxi(1, a.size()))


## Zelfde dictionary als het gevecht. Eén bron, zodat de paritytest de sim-parameters meeneemt.
func fight_params() -> Dictionary:
	return {
		"charge_time": SomData.CHARGE_TIME, "anim": 0.71, "approach": 1.2,
		"ally_spell_cd": SomData.ALLY_SPELL_CD, "ally_heal_below": SomData.ALLY_HEAL_BELOW,
		"ally_dmg_chance": SomData.ALLY_DAMAGE_SPELL_CHANCE, "enemy_cd": SomData.ATTACK_COOLDOWN,
		"telegraph": SomData.TELEGRAPH, "enemy_dmg": SomData.ENEMY_DAMAGE_MULT,
	}


## Zet de add en de gevechtsparameters. Geen ander gedrag dan `_run`.
func parity_bind(add_data: Dictionary) -> void:
	_add_data = add_data
	_params = fight_params()


func parity_choose(threat: ThreatTable, heroes: Array, ranged: bool, tick: int) -> int:
	return _choose(threat, heroes, ranged, tick)


func parity_boss_hit(heroes: Array, boss: Dictionary, target: int, id: String, power: float, rng: RandomNumberGenerator) -> void:
	_boss_hit(heroes, boss, target, id, power, rng)


func parity_ally_spell(gf: PageWardenFight, hr: Dictionary, heroes: Array, boss: Dictionary, rng: RandomNumberGenerator, threat: ThreatTable) -> bool:
	return _ally_spell(gf, hr, heroes, boss, rng, threat)


func parity_spawn_adds(adds: Array, ids: Array) -> void:
	_spawn_adds(adds, ids)


func parity_adds_tick(heroes: Array, adds: Array, target: int, rng: RandomNumberGenerator) -> void:
	_adds_tick(heroes, adds, target, rng)
