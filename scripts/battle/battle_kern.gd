extends RefCounted
## Kernvaardigheden (uit battle.gd gehaald, gedrag ongewijzigd); _kern_fireball blijft op battle.gd (sim-override).
## battle.gd roept dit aan via dunne wrappers met de oude namen (sim en tests roepen die).

const KernData := preload("res://scripts/data/kern_data.gd")
const DamageCalc := preload("res://scripts/battle/damage_calc.gd")
const ActorSfx := preload("res://scripts/data/actor_sfx.gd")
const KERN_TINT := Color(1.45, 0.85, 1.9)       # v0.16: paarse flits (Kernkracht)
const KERN_HIT_TEXT := "%s: %s!"

var battle: Control


func _init(b: Control) -> void:
	battle = b


func kern_skills(hero: Dictionary) -> Array:
	if not hero.get("is_hero", false):
		return []
	return GameState.kern_skills_of(str(hero["s"].get("id", "")))


## Rondes tot de vaardigheid weer klaar is (0 = klaar).
func kern_charge(hero: Dictionary, id: String) -> int:
	return int(hero.get("kern_cd", {}).get(id, 0))


func kern_ready(hero: Dictionary, id: String) -> bool:
	return kern_charge(hero, id) <= 0


## Regel in het menu: "Kernkracht KERN" (klaar) of "Kernkracht (2)" (nog 2 rondes opladen).
func kern_entry_text(hero: Dictionary, id: String) -> String:
	var n := str(KernData.KERN_SKILLS[id]["name"])
	var cd := kern_charge(hero, id)
	return ("%-10s CORE" % n) if cd <= 0 else ("%-10s (%d)" % [n, cd])


## Schade van een fysieke kernvaardigheid: ATK x atk_mult - DEF x def_factor, +/- 15%,
## verdedigen = helft (zoals _physical_damage, maar met minder pantser).
func kern_damage(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
	return DamageCalc.kern_damage(attacker, target, skill)


func kern_base(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> float:
	return DamageCalc.kern_base(attacker, target, skill)


func kern_strike(a: Dictionary) -> void:
	var actor: Dictionary = a["actor"]
	var id: String = a["skill"]
	var skill: Dictionary = KernData.KERN_SKILLS.get(id, {})
	if skill.is_empty() or not kern_ready(actor, id):
		return
	var t = battle._valid_target(a["target"], false)
	if t == null:
		return
	if not actor.has("kern_cd"):
		actor["kern_cd"] = {}
	actor["kern_cd"][id] = int(skill.get("cooldown", 3))
	battle.show_message(KERN_HIT_TEXT % [actor["name"], skill["name"]])
	ActorSfx.play(actor, "vaardigheid")
	if actor["node"]:
		var tw: Tween = battle.create_tween()
		tw.tween_property(actor["node"], "modulate", KERN_TINT, 0.15)
		tw.tween_property(actor["node"], "modulate", Color.WHITE, 0.35)
	if str(skill.get("fx", "")) == "vuurbal":
		await battle._kern_fireball(actor, t)     # v0.16: hand vooruit, vuurbal, inslag
	else:
		await battle._hero_wind_up(actor, true)
	if t["node"]:
		var tw2: Tween = battle.create_tween()
		tw2.tween_property(t["node"], "modulate", KERN_TINT, 0.08)
		tw2.tween_property(t["node"], "modulate", battle.GUARD_TINT if int(t.get("guard", 0)) > 0 else Color.WHITE, 0.3)
	await battle._damage(t, kern_damage(actor, t, skill))
	battle._hero_rest(actor)


func kern_tick(c: Dictionary) -> void:
	if not c.has("kern_cd"):
		return
	for id in c["kern_cd"]:
		c["kern_cd"][id] = maxi(0, int(c["kern_cd"][id]) - 1)