extends RefCounted
## Pure gevechtsregels (uit battle.gd gehaald, gedrag ongewijzigd).
## Alleen static functies; battle.gd roept ze aan via dunne wrappers met de oude namen.

const GameData := preload("res://scripts/data/game_data.gd")
const Archief2Vijanden := preload("res://scripts/data/archief2_vijanden.gd")


## Alleen de baas van Archief 2 (De Genezer) heeft een eigen track; de rest blijft zoals het was.
static func battle_music_for(enemies: Array, boss: bool) -> String:
	if boss and "genezer" in enemies:
		return "baas_archief2"
	return "gevecht_miniboss" if boss else "gevecht_normaal"


## Heeft dit item een effect in het gevecht? (genezen, revive, tegengif, vangen, spreuk leren)
static func battle_usable(it: Dictionary) -> bool:
	return int(it.get("heal_hp", 0)) > 0 or int(it.get("heal_mp", 0)) > 0 \
			or float(it.get("revive", 0.0)) > 0.0 or bool(it.get("cure", false)) \
			or bool(it.get("capture", false)) or str(it.get("teach", "")) != ""


## Zou een genees-item (heal_hp/heal_mp) dit doel helpen? Zelfde regel als het veld (#2).
static func heal_would_help(t: Dictionary, it: Dictionary) -> bool:
	if t.is_empty():
		return false
	var s: Dictionary = t["s"]
	return (int(it.get("heal_hp", 0)) > 0 and int(s["hp"]) < int(s["max_hp"])) \
			or (int(it.get("heal_mp", 0)) > 0 and int(s["mp"]) < int(s["max_mp"]))


## Telt als baas voor verlamming/bevriezing: een vijand in een baasgevecht of met "is_boss".
static func is_boss_target(t: Dictionary) -> bool:
	if bool(t.get("is_hero", false)):
		return false
	return GameState.pending_boss or bool(t["s"].get("is_boss", false))


## #3/#4/#17: wie opstaat begint schoon. Binden/bevriezing (skip), gif/brand, HoT en buffs van
## voor de KO vervallen, ongeacht in welke ronde de revive valt.
static func clear_ko_status(c: Dictionary) -> void:
	c["skip"] = 0
	c.erase("skip_reden")
	c.erase("stun_immune")
	c["dots"] = []
	c["hots"] = []
	c["buffs"] = []
	c["defending"] = false


## Tegengif: valt er iets te genezen (gif-DoT of gebonden door een Rankje)?
static func has_curable(t: Dictionary) -> bool:
	if t.is_empty():
		return false
	for d in t.get("dots", []):
		if bool(d.get("gif", false)):
			return true
	return str(t.get("skip_reden", "")) == Archief2Vijanden.SKIP_REDEN_BIND and int(t.get("skip", 0)) > 0


static func avg_agi(living: Array) -> float:
	if living.is_empty():
		return 0.0
	var total := 0.0
	for c in living:
		total += float(c["s"]["agi"])
	return total / living.size()


## Tekst van de eerste overwinningspagina (breedte en helden komen van battle.gd).
static func victory_text(exp_total: int, gold_total: int, loot_lines: Array, heroes: Array, width: float) -> String:
	var lines: Array[String] = ["Gained %d EXP." % exp_total, "Gained %d GOLD." % gold_total]
	for line in loot_lines:
		lines.append(str(line))
	lines.append("")
	var cols := maxi(30, int((width - 28.0) / 6.0) - 1)
	var col_label := int(cols * 0.36)
	for h in heroes:
		var s: Dictionary = h["s"]
		var need: int = maxi(0, GameData.exp_for_level(int(s["level"]) + 1) - int(s["exp"]))
		var left := str(s["name"]).rpad(col_label - 1) + " NEXT LEVEL"
		lines.append(left + " " + str(need).lpad(cols - left.length() - 1))
	return "\n".join(lines)