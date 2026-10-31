extends RefCounted
## Schadeberekening van het gevecht (uit battle.gd gehaald, gedrag ongewijzigd).
## Alleen static functies; battle.gd roept ze aan via dunne wrappers met de oude namen.
## Geluk gebruikt de globale randf_range(), in dezelfde volgorde als vroeger in battle.gd.

const KoopmanData := preload("res://scripts/data/koopman_data.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")


## Schadeformule: ATK - DEF/2, +/- 15% geluk, verdedigen = halve schade.
## Zwakte telt alleen als het doel weak_matters heeft (Archief 2). Andere vijanden blijven gelijk.
static func physical_damage(attacker: Dictionary, target: Dictionary, mult: float) -> int:
	var dmg := maxi(1, roundi(physical_base(attacker, target, mult) * randf_range(0.85, 1.15)))
	if target["defending"]:
		dmg = maxi(1, int(dmg / 2.0))
	dmg = maxi(1, roundi(float(dmg) * Archief2.zwakte_fysiek(attacker, target)))
	return dmg


## Spreuken: power op level 1 + power_per_level per level erboven, maal het element, +/- 10%.
static func spell_amount(caster: Dictionary, spell: Dictionary, target: Dictionary) -> int:
	return maxi(1, roundi(spell_base(caster, spell, target) * randf_range(0.9, 1.1)))


## Basis van de formules hierboven, zonder geluk en zonder randf(): de simulator-AI
## (tools/battlesim) schat er schade mee zonder de RNG-volgorde van het gevecht te verschuiven.
static func physical_base(attacker: Dictionary, target: Dictionary, mult: float) -> float:
	return float(attacker["s"]["atk"]) * buff_mult(attacker, "atk") * mult - defense_of(target) / 2.0


static func spell_base(caster: Dictionary, spell: Dictionary, target: Dictionary) -> float:
	var lvl := int(caster["s"].get("level", 1))
	return SpellRules.power_at(spell, lvl) * SpellRules.factor(spell, str(caster["s"].get("id", "")), target) * token_mult(caster)


static func buff_mult(c: Dictionary, stat: String) -> float:
	var m := token_mult(c)
	for b in c.get("buffs", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if str(b.get("stat", "")) == stat and int(b.get("turns", 0)) > 0:
			m *= 1.0 + float(b.get("pct", 0.0))
	return m


## "H-5's Token" van de Koopman (CANON §12): +10% stats voor de helden tegen dienaren van Sapientia.
static func token_mult(c: Dictionary) -> float:
	if not bool(c.get("is_hero", false)):
		return 1.0
	return KoopmanData.token_factor(GameState.koopman_token, not GameState.practice_battle)


## DEF van een doelwit, met schild omhoog (x guard_mult).
static func defense_of(t: Dictionary) -> float:
	var d := float(t["s"]["def"]) * buff_mult(t, "def") + float(t.get("buff_def", 0))
	if int(t.get("guard", 0)) > 0:
		d *= float(t.get("guard_mult", 2.0))
	return d


## Schade van een fysieke kernvaardigheid: ATK x atk_mult - DEF x def_factor, +/- 15%,
## verdedigen = helft (zoals physical_damage, maar met minder pantser).
static func kern_damage(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
	var dmg := maxi(1, roundi(kern_base(attacker, target, skill) * randf_range(0.85, 1.15)))
	if target["defending"]:
		dmg = maxi(1, int(dmg / 2.0))
	return dmg


static func kern_base(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> float:
	return float(attacker["s"]["atk"]) * float(skill.get("atk_mult", 1.5)) \
			- defense_of(target) * float(skill.get("def_factor", 0.25))
