extends RefCounted
## D3 PR B: realtime Golem-baassim (--actionsim --boss-rt). Draait GolemFight (de echte host-logica) @ 60 Hz
## tegen een geabstraheerde party (zelfde spelermodel als action_sim.gd: meter, animatie-lock, aanloop,
## ontwijkkans per telegraaf, bondgenoot-spreuken). Deterministisch: eigen RNG per gevecht (seed).
##
## AANNAMES (sim-model, geen speldata; zie PR-body):
##  - Baas-schade = SomArena.physical_damage(ATK 27, DEF held, power) ZONDER ENEMY_DAMAGE_MULT (§2/§3: geen
##    vermenigvuldiger voor bazen). Adds (papiergeest) = gewone realtime vijanden MET ENEMY_DAMAGE_MULT.
##  - Wie geraakt wordt: sweep = doel + 30% kans per andere held; book_hammer = alleen doel;
##    shockwave (3 lijnen) = doel + 33% per andere held; hammer_blow (r=3) = alle helden.
##  - Ontwijken: kans per geraakte held (speler/bondgenoot); gelukt = 15 iframe-ticks dekken de actieve fase.
##  - Speler (held 0) gebruikt items: Feniksveer op een gevallen held, Drankje/Kruid onder 30% HP.
##  - Bondgenoten slaan adds zolang die leven (behalve tijdens het open kernvenster); de speler slaat de baas.
##  - Gevecht > MAX_TICKS = verlies.

const SomData := preload("res://scripts/data/som_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
const BossCore := preload("res://scripts/battle/boss_core.gd")
const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")

const DT := 1.0 / 60.0
const MAX_TICKS := 300 * 60
const PROFILES := {
	"default": {"dodge_player": 0.35, "dodge_ally": 0.15},   # action_sim.gd params_base
	"good": {"dodge_player": 0.70, "dodge_ally": 0.15},      # §4 "goede speler"
}
const HIT_OTHERS := {"golem_sweep": 0.3, "golem_sweep_p2": 0.3, "golem_book_hammer": 0.0, "golem_book_hammer_x2": 0.0,
	"golem_shockwave": 0.33, "golem_hammer_blow": 1.0, "golem_hammer_blow_p3": 1.0}

var boss_data: Dictionary
var add_data: Dictionary
var params: Dictionary


func _init() -> void:
	boss_data = SomData.action_boss_stats(GameData.ENEMIES[GolemBoss.ENEMY_ID].duplicate(true), 1)
	add_data = (GameData.ENEMIES["papiergeest"] as Dictionary).duplicate(true)
	var p: Dictionary = {
		"charge_time": SomData.CHARGE_TIME, "floor": SomData.CHARGE_MIN_MULT, "anim": 0.71, "approach": 1.2,
		"iframes": SomData.PLAYER_IFRAMES, "ally_spell_cd": SomData.ALLY_SPELL_CD, "ally_heal_below": SomData.ALLY_HEAL_BELOW,
		"ally_dmg_chance": SomData.ALLY_DAMAGE_SPELL_CHANCE, "enemy_cd": SomData.ATTACK_COOLDOWN, "telegraph": SomData.TELEGRAPH,
		"enemy_dmg": SomData.ENEMY_DAMAGE_MULT}
	params = p


## Party (SoM-start: Dax + START_MEMBERS, START_GEAR) op level lv, vol HP/MP.
static func party_at_level(lv: int) -> Array:
	GameState._build_som_state()
	for h in GameState.party:
		var need := GameData.exp_for_level(lv) - int(h["exp"])
		if need > 0:
			GameState.give_exp(h, need)
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	return GameState.party.duplicate(true)


## Eén gevecht. Geeft {win, loss, time, phases: [{time, hp_lost, kos}], dodges, targeted, breaks, windows}.
func fight(party_in: Array, items_in: Dictionary, profile: Dictionary, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var gf := GolemFight.new(int(boss_data["max_hp"]), seed_val)
	var party: Array = party_in.duplicate(true)
	var items: Dictionary = items_in.duplicate()
	var heroes: Array = []
	var max_total := 0
	for h in party:
		max_total += int(h["max_hp"])
		heroes.append({"h": h, "charge": 1.0, "lock": 0.0, "walk": float(params["approach"]) * 0.5, "iframes": 0.0,
			"spell_cd": 1.0, "atk": float(GameState.effective_stat(h, "atk")), "def": float(GameState.effective_stat(h, "def"))})
	var adds: Array = []
	var phase_stats: Array = [{"time": 0.0, "hp_lost": 0, "kos": 0}, {"time": 0.0, "hp_lost": 0, "kos": 0}, {"time": 0.0, "hp_lost": 0, "kos": 0}]
	var target := -1
	var dodges := 0
	var targeted := 0
	var t := 0
	var reached := 0
	while t < MAX_TICKS and not gf.is_dead():
		if _alive(heroes).is_empty():
			break
		t += 1
		var ph := gf.phase_index()
		reached = maxi(reached, ph)
		phase_stats[ph]["time"] = float(phase_stats[ph]["time"]) + DT
		gf.tick()
		for ev in gf.take_events():
			match str(ev["type"]):
				"telegraph_start":
					target = _pick_target(heroes, rng)
				"attack_hit":
					var r := _boss_hit(gf, heroes, target, str(ev["id"]), float(ev["power"]), profile, rng, phase_stats[ph])
					dodges += int(r.x)
					targeted += int(r.y)
				"adds":
					for id in ev["ids"]:
						adds.append({"d": add_data, "hp": int(add_data["max_hp"]), "approach": float(params["approach"]),
							"tele": 0.0, "cd": rng.randf_range(0.2, 0.8), "target": -1})
		_heroes_tick(gf, heroes, adds, items, rng, phase_stats)
		_adds_tick(heroes, adds, profile, rng, phase_stats[gf.phase_index()])
	var end_hp := 0
	for h in party:
		end_hp += int(h["hp"])
	return {"win": gf.is_dead(), "loss": float(max_total - end_hp) / float(maxi(1, max_total)), "time": float(t) * DT,
		"phases": phase_stats, "reached": reached, "dodges": dodges, "targeted": targeted,
		"breaks": gf.core.broken_count, "windows": gf.core.opened_count, "max_total": max_total}


static func _alive(heroes: Array) -> Array:
	var out: Array = []
	for i in heroes.size():
		if int(heroes[i]["h"]["hp"]) > 0:
			out.append(i)
	return out


## Zoals action_sim._enemy_target: 50% de bestuurde held, anders een willekeurige levende held.
static func _pick_target(heroes: Array, rng: RandomNumberGenerator) -> int:
	var alive := _alive(heroes)
	if alive.is_empty():
		return -1
	if int(heroes[0]["h"]["hp"]) > 0 and rng.randf() < 0.5:
		return 0
	return int(alive[rng.randi_range(0, alive.size() - 1)])


func _hurt(hr: Dictionary, dmg: int, ps: Dictionary) -> void:
	var before := int(hr["h"]["hp"])
	hr["h"]["hp"] = maxi(0, before - maxi(1, dmg))
	ps["hp_lost"] = int(ps["hp_lost"]) + (before - int(hr["h"]["hp"]))
	hr["iframes"] = float(params["iframes"])
	if before > 0 and int(hr["h"]["hp"]) == 0:
		ps["kos"] = int(ps["kos"]) + 1


## Vector2i(ontweken, gericht)
func _boss_hit(gf, heroes: Array, target: int, id: String, power: float, profile: Dictionary, rng: RandomNumberGenerator, ps: Dictionary) -> Vector2i:
	var victims: Array = []
	var others := float(HIT_OTHERS.get(id, 0.0))
	for i in _alive(heroes):
		if i == target or rng.randf() < others:
			victims.append(i)
	var dodged := 0
	for i in victims:
		var hr: Dictionary = heroes[i]
		if float(hr["iframes"]) > 0.0:
			continue
		var p := float(profile["dodge_player"]) if i == 0 else float(profile["dodge_ally"])
		if rng.randf() < p:
			dodged += 1
			continue
		var dmg := SomArena.physical_damage(float(boss_data["atk"]), float(hr["def"]), power, rng)
		_hurt(hr, dmg, ps)
	return Vector2i(dodged, victims.size())


func _heroes_tick(gf, heroes: Array, adds: Array, items: Dictionary, rng: RandomNumberGenerator, phase_stats: Array) -> void:
	for hi in heroes.size():
		var hr: Dictionary = heroes[hi]
		if int(hr["h"]["hp"]) <= 0:
			continue
		hr["iframes"] = maxf(0.0, float(hr["iframes"]) - DT)
		if float(hr["lock"]) > 0.0:
			hr["lock"] = float(hr["lock"]) - DT
		else:
			hr["charge"] = minf(1.0, float(hr["charge"]) + DT / float(params["charge_time"]))
		if float(hr["walk"]) > 0.0:
			hr["walk"] = float(hr["walk"]) - DT
			continue
		if hi > 0:
			hr["spell_cd"] = float(hr["spell_cd"]) - DT
			if float(hr["spell_cd"]) <= 0.0:
				hr["spell_cd"] = float(params["ally_spell_cd"])
				if _ally_spell(gf, hr, heroes, adds, rng):
					hr["lock"] = float(params["anim"])
					continue
		if float(hr["lock"]) > 0.0 or float(hr["charge"]) < 1.0:
			continue
		if hi == 0 and _use_item(heroes, items):
			hr["charge"] = 0.0
			hr["lock"] = float(params["anim"])
			continue
		var live_adds := adds.filter(func(a): return int(a["hp"]) > 0 and float(a["approach"]) <= 0.0)
		var on_boss: bool = hi == 0 or live_adds.is_empty() or gf.core.open
		if on_boss and gf.is_invulnerable():
			continue      # fasewissel: wachten (meter blijft vol)
		var dmg := SomArena.physical_damage(float(hr["atk"]), float(boss_data["def"]) if on_boss else float(live_adds[0]["d"]["def"]), 1.0, rng)
		if not on_boss:
			live_adds[0]["hp"] = int(live_adds[0]["hp"]) - dmg
			live_adds[0]["tele"] = 0.0
		else:
			gf.damage(dmg)
		hr["charge"] = 0.0
		hr["lock"] = float(params["anim"])
		hr["walk"] = 0.25 if hi > 0 else 0.1


func _use_item(heroes: Array, items: Dictionary) -> bool:
	if int(items.get("feniksveer", 0)) > 0:
		for o in heroes:
			if int(o["h"]["hp"]) <= 0:
				items["feniksveer"] = int(items["feniksveer"]) - 1
				o["h"]["hp"] = maxi(1, roundi(float(o["h"]["max_hp"]) * float(GameData.ITEMS["feniksveer"].get("revive", 0.5))))
				return true
	for it in ["drankje", "kruid"]:
		if int(items.get(it, 0)) <= 0:
			continue
		for o in heroes:
			if int(o["h"]["hp"]) > 0 and float(o["h"]["hp"]) < 0.3 * float(o["h"]["max_hp"]):
				items[it] = int(items[it]) - 1
				o["h"]["hp"] = mini(int(o["h"]["max_hp"]), int(o["h"]["hp"]) + int(GameData.ITEMS[it]["heal_hp"]))
				return true
	return false


## Seren/Vesper-model uit action_sim._ally_spell: genezen onder drempel, anders schadespreuk met kans.
func _ally_spell(gf, hr: Dictionary, heroes: Array, adds: Array, rng: RandomNumberGenerator) -> bool:
	var h: Dictionary = hr["h"]
	var lvl := int(h.get("level", 1))
	for s in h.get("spells", []):
		var sp: Dictionary = GameData.SPELLS.get(str(s), {})
		if sp.is_empty() or int(h["mp"]) < int(sp.get("mp", 0)):
			continue
		if str(sp.get("type", "")) == "heal":
			var low: Dictionary = {}
			var lr := float(params["ally_heal_below"])
			for o in heroes:
				var r := float(o["h"]["hp"]) / maxf(1.0, float(o["h"]["max_hp"]))
				if int(o["h"]["hp"]) > 0 and r < lr:
					lr = r
					low = o["h"]
			if low.is_empty():
				continue
			h["mp"] = int(h["mp"]) - int(sp["mp"])
			low["hp"] = mini(int(low["max_hp"]), int(low["hp"]) + roundi(SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, str(h["id"]), {})))
			return true
		if str(sp.get("type", "")) == "damage" and rng.randf() < float(params["ally_dmg_chance"]):
			h["mp"] = int(h["mp"]) - int(sp["mp"])
			var amt := SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, str(h["id"]), {"s": boss_data})
			gf.damage(maxi(1, roundi(amt * rng.randf_range(0.9, 1.1))))
			return true
	return false


## Adds: gewone realtime vijand (action_sim-model: telegraaf, cooldown, ENEMY_DAMAGE_MULT).
func _adds_tick(heroes: Array, adds: Array, profile: Dictionary, rng: RandomNumberGenerator, ps: Dictionary) -> void:
	for e in adds:
		if int(e["hp"]) <= 0:
			continue
		if float(e["approach"]) > 0.0:
			e["approach"] = float(e["approach"]) - DT
			continue
		if float(e["tele"]) > 0.0:
			e["tele"] = float(e["tele"]) - DT
			if float(e["tele"]) <= 0.0:
				e["cd"] = float(params["enemy_cd"])
				var ti := int(e["target"])
				if ti < 0 or ti >= heroes.size():
					continue
				var hr: Dictionary = heroes[ti]
				var dodge := float(profile["dodge_player"]) if ti == 0 else float(profile["dodge_ally"])
				if int(hr["h"]["hp"]) > 0 and float(hr["iframes"]) <= 0.0 and rng.randf() >= dodge:
					var dmg := roundi(SomArena.physical_damage(float(e["d"]["atk"]), float(hr["def"]), 1.0, rng) * float(params["enemy_dmg"]))
					_hurt(hr, dmg, ps)
			continue
		if float(e["cd"]) > 0.0:
			e["cd"] = float(e["cd"]) - DT
			continue
		var tgt := _pick_target(heroes, rng)
		if tgt < 0:
			return
		e["target"] = tgt
		e["tele"] = float(params["telegraph"])


## n gevechten op level lv. Geeft samenvatting.
func run(lv: int, n: int, profile_name: String, base_seed: int) -> Dictionary:
	var party := party_at_level(lv)
	var items: Dictionary = SomData.START_ITEMS.duplicate()
	var prof: Dictionary = PROFILES[profile_name]
	var wins := 0
	var losses: Array = []
	var times: Array = []
	var win_times: Array = []
	var ph_time := [0.0, 0.0, 0.0]
	var ph_loss := [0.0, 0.0, 0.0]
	var ph_kos := [0, 0, 0]
	var ph_reached := [0, 0, 0]
	var dodges := 0
	var targeted := 0
	var breaks := 0
	var windows := 0
	for i in n:
		var r := fight(party, items, prof, hash([base_seed, lv, profile_name, i]))
		if r["win"]:
			wins += 1
			win_times.append(r["time"])
		losses.append(r["loss"])
		times.append(r["time"])
		for k in 3:
			if int(r["reached"]) >= k:
				ph_reached[k] += 1
				ph_time[k] += float(r["phases"][k]["time"])
				ph_loss[k] += float(r["phases"][k]["hp_lost"]) / float(r["max_total"])
				ph_kos[k] += int(r["phases"][k]["kos"])
		dodges += int(r["dodges"])
		targeted += int(r["targeted"])
		breaks += int(r["breaks"])
		windows += int(r["windows"])
	losses.sort()
	var out := {"level": lv, "profile": profile_name, "n": n, "win": float(wins) / float(maxi(1, n)),
		"loss": _mean(losses), "p90": losses[mini(losses.size() - 1, int(losses.size() * 0.9))] if not losses.is_empty() else 0.0,
		"time": _mean(times), "win_time": _mean(win_times), "phases": [],
		"dodge_rate": float(dodges) / float(maxi(1, targeted)), "break_rate": float(breaks) / float(maxi(1, windows)),
		"windows_per_fight": float(windows) / float(maxi(1, n))}
	for k in 3:
		var c := maxi(1, ph_reached[k])
		out["phases"].append({"reached": ph_reached[k], "time": ph_time[k] / c, "hp_loss": ph_loss[k] / c, "kos": float(ph_kos[k]) / c})
	return out


static func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(maxi(1, a.size()))
