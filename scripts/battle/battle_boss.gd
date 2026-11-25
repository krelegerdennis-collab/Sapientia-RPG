extends RefCounted
## Golem-kern, schild en Archief 2-opening/leech (uit battle.gd gehaald, gedrag ongewijzigd).
## battle.gd roept dit aan via dunne wrappers met de oude namen (sim en tests roepen die).

const BossCore := preload("res://scripts/battle/boss_core.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const ActorSfx := preload("res://scripts/data/actor_sfx.gd")
const DamageCalc := preload("res://scripts/battle/damage_calc.gd")

var battle: Control


func _init(b: Control) -> void:
	battle = b


## De Genezer: eerste klap is scripted (ongeveer 30%). true = het gevecht is daar gestopt.
func archief2_opening() -> bool:
	for e in battle.enemies:
		if not bool(e["s"].get("archief2_open", false)):
			continue
		var pool: Array = []
		for c in battle.heroes:
			if not bool(c.get("ally", false)) and int(c["s"]["hp"]) > 0:
				pool.append(c)
		if pool.is_empty():
			return false
		var t: Dictionary = pool[0]
		var dmg := Archief2.openingslag(int(t["s"]["max_hp"]))
		var zin := str(e["s"].get("archief2_zin", Archief2.KERN_ZIN))
		await battle.say(zin)
		if str(e["s"].get("id", "")) == "genezer" and GameState.has_member("lotte"):
			await battle.say("Seren: You call that healing?")
		await battle._damage(t, dmg)
		GameState.archief2_last_open = {"schade": dmg, "max": int(t["s"]["max_hp"]), "id": str(t["s"].get("id", ""))}
		if battle.codex.party_down():
			await battle._defeat()
			return true
	return false


## Daarna 8-12% van het doel, en hij herstelt hetzelfde aantal.
func archief2_leech(actor: Dictionary) -> void:
	var pool: Array = []
	for c in battle._alive(battle.heroes):
		if not bool(c.get("ally", false)):
			pool.append(c)
	if pool.is_empty():
		pool = battle._alive(battle.heroes)
	if pool.is_empty():
		return
	var t: Dictionary = pool[0]
	var n := Archief2.leech_hoeveelheid(randf(), int(t["s"]["max_hp"]))
	battle.show_message("%s corrects %s." % [actor["name"], t["name"]])
	await battle._damage(t, n)
	var voor := int(actor["s"]["hp"])
	actor["s"]["hp"] = mini(int(actor["s"]["max_hp"]), voor + n)
	GameState.archief2_last_leech = {"schade": n, "heal": n, "bij": int(actor["s"]["hp"]) - voor}
	battle.show_message("%s recovers %d." % [actor["name"], n])
	await battle._wait(battle.MESSAGE_TIME)


## Vijanden met een kern (alleen de Golem in een baasgevecht).
func core_enemies() -> Array:
	return battle.enemies.filter(func(e): return e.has("core"))


## Tekst voor de roze strook tijdens het kiezen ("" = geen kern open).
func core_banner() -> String:
	for e in core_enemies():
		if e["s"]["hp"] > 0 and e["core"].open:
			return BossCore.MSG_WINDOW
	for e in battle.enemies:   # v0.15: schild omhoog (Mech. Wachter)
		if e["s"]["hp"] > 0 and int(e.get("guard", 0)) > 0:
			return battle.GUARD_BANNER % e["name"]
	return ""


func guard_up(actor: Dictionary, skill: Dictionary) -> void:
	ActorSfx.play(actor, "vaardigheid")
	actor["guard"] = 2
	actor["guard_mult"] = float(skill.get("def_mult", 2.0))
	if actor["node"]:
		actor["node"].modulate = battle.GUARD_TINT
	battle.show_message(battle.GUARD_TEXT % actor["name"])
	await battle._wait(battle.MESSAGE_TIME)


func guard_tick(c: Dictionary) -> void:
	if int(c.get("guard", 0)) <= 0:
		return
	c["guard"] = int(c["guard"]) - 1
	if c["guard"] == 0 and c["node"] and c["s"]["hp"] > 0:
		c["node"].modulate = Color.WHITE


## DEF van een doelwit, met schild omhoog (x guard_mult).
func defense_of(t: Dictionary) -> float:
	return DamageCalc.defense_of(t)


## Eén keer aan het begin: uitleg in één regel.
func core_hint() -> void:
	if not core_enemies().is_empty():
		await battle.say(BossCore.MSG_HINT)


## Begin van een ronde: gaat de kern open, dan het bericht 'De kern gloeit roze!'.
func core_round_start() -> void:
	for e in core_enemies():
		if e["s"]["hp"] > 0 and e["core"].start_round(battle.round_no):
			battle._flash_enemy(e)
			await battle.say(BossCore.MSG_OPEN % e["name"])


## Actie van de Golem aan het eind van de oplaad-ronde: wankelen of Hamerslag.
func core_resolve(a: Dictionary) -> void:
	var actor: Dictionary = a["actor"]
	var core = actor["core"]
	if core.resolve() == "break":
		battle.show_message(BossCore.MSG_BREAK % actor["name"])
		battle._shake(actor["node"], 4.0)
		await battle._wait(battle.MESSAGE_TIME * 1.5)
	else:
		var t = battle._valid_target(a["target"], true)
		if t == null:
			return
		battle.show_message(BossCore.MSG_SLAM % [actor["name"], core.slam_name])
		ActorSfx.play(actor, "vaardigheid")
		await battle._enemy_lunge(actor, t)
		await battle._damage(t, battle._physical_damage(actor, t, core.slam_power))
	if battle._alive(battle.heroes).size() > 0:
		battle.show_message(BossCore.MSG_CLOSE)
		await battle._wait(battle.MESSAGE_TIME)