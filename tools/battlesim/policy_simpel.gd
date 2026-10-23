extends "res://tools/battlesim/sim_battle.gd"
## Policy "simpel" voor de battle simulator (--battlesim --policy=simpel). Alleen de keuze per held
## verschilt van sim_battle.gd; de rondelus, schade en effecten blijven de echte battle.gd-code.
##
## Per held:
## 1. leeft er een held onder HEAL_BELOW van zijn max HP: genezen (de laagste eerst), met de
##    sterkste genees-spreuk als er MP is, anders met het kleinste genees-item dat het gat dekt;
## 2. anders de sterkste aanval: de actie met de hoogste verwachte directe schade over alle
##    doelen (gewone aanval, schade-spreuk met genoeg MP, kernvaardigheid die klaar is).
##    Gelijke schade: het doel met de minste HP. Schatting via battle.gd physical_base /
##    spell_base / kern_base (de echte formules zonder het geluk, dus zonder randf()).
## Geen opwekken, geen MP-drankjes, geen verdedigen of vluchten: dat hoort niet bij deze policy.

const HEAL_BELOW := 0.35


func _ai_action(h: Dictionary, planned_heal: Dictionary) -> Dictionary:
	var hurt := _lowest_below(planned_heal)
	if not hurt.is_empty():
		var sp_id := _best_spell(h, "heal")
		if sp_id != "":
			planned_heal[hurt["uid"]] = true
			return {"type": "spell", "actor": h, "spell": sp_id, "target": hurt}
		var it := _best_heal_item(int(hurt["s"]["max_hp"]) - int(hurt["s"]["hp"]))
		if it != "":
			planned_heal[hurt["uid"]] = true
			return {"type": "item", "actor": h, "item": it, "target": hurt}
	return strongest_attack(h)


func _lowest_below(planned_heal: Dictionary) -> Dictionary:
	var hurt: Dictionary = {}
	var hurt_frac := HEAL_BELOW
	for x in _alive(heroes):
		if x.get("ally", false) or planned_heal.has(x["uid"]):
			continue
		var frac := float(x["s"]["hp"]) / float(maxi(1, int(x["s"]["max_hp"])))
		if frac < hurt_frac:
			hurt = x
			hurt_frac = frac
	return hurt


## Actie met de hoogste verwachte schade (zie de kop van dit bestand).
func strongest_attack(h: Dictionary) -> Dictionary:
	var foes := _alive(enemies)
	if foes.is_empty():
		return {"type": "defend", "actor": h}
	var s: Dictionary = h["s"]
	var best: Dictionary = {}
	var best_val := -1.0
	var best_hp := 0
	for f in foes:
		var hp := int(f["s"]["hp"])
		var cands: Array = [[{"type": "attack", "actor": h, "target": f}, expected_physical(h, f)]]
		for kid in _kern_skills(h):
			if kern_ready(h, kid):
				cands.append([{"type": "kern_skill", "actor": h, "skill": kid, "target": f},
						expected_kern(h, f, KernData.KERN_SKILLS[kid])])
		for id in s["spells"]:
			var sp: Dictionary = GameData.SPELLS[id]
			if str(sp.get("type", "damage")) != "damage" or int(s["mp"]) < int(sp["mp"]) or sp["target"] != "enemy":
				continue
			cands.append([{"type": "spell", "actor": h, "spell": id, "target": f}, expected_spell(h, sp, f)])
		for c in cands:
			if float(c[1]) > best_val or (is_equal_approx(float(c[1]), best_val) and hp < best_hp):
				best = c[0]
				best_val = float(c[1])
				best_hp = hp
	for id in s["spells"]:
		var sp_all: Dictionary = GameData.SPELLS[id]
		if str(sp_all.get("type", "damage")) != "damage" or int(s["mp"]) < int(sp_all["mp"]) or sp_all["target"] != "all_enemies":
			continue
		var total := 0.0
		for f in foes:
			total += expected_spell(h, sp_all, f)
		if total > best_val:
			best = {"type": "spell", "actor": h, "spell": id, "target": null}
			best_val = total
	return best


func expected_physical(h: Dictionary, f: Dictionary) -> float:
	var v := maxf(1.0, physical_base(h, f, 1.0)) * Archief2.zwakte_fysiek(h, f)
	return v * (0.5 if f.get("defending", false) else 1.0)


func expected_spell(h: Dictionary, sp: Dictionary, f: Dictionary) -> float:
	var v := maxi(1, roundi(spell_base(h, sp, f)))
	return float(Archief2.schaal_element(v, f, str(sp.get("element", ""))))


func expected_kern(h: Dictionary, f: Dictionary, skill: Dictionary) -> float:
	return maxf(1.0, kern_base(h, f, skill)) * (0.5 if f.get("defending", false) else 1.0)
