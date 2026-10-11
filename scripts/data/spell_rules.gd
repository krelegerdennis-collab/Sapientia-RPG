extends RefCounted
## Wie welke spreuk mag leren, en tot welke grade de winkel gaat.
## Dennis: geen shop-magie (alleen kernkrachten). Grade 4 nooit in de winkel.
## TODO(design): de volledige lijst van 4×16 spreuken per element is nog niet ontworpen.
## Bevestigd: de grade- en personageregels gelden voor de kleine lijst van 20.

const GameData := preload("res://scripts/data/game_data.gd")

## Hoogste grade per element. Ontbreekt het element, dan is de spreuk verboden.
const CAP := {
	"dennis": {},
	"noor": {"vuur": 4, "natuur": 4, "bliksem": 4, "licht": 1},
	"lotte": {"licht": 4, "ijs": 4},
}


static func max_grade(hero_id: String, element: String) -> int:
	var row = CAP.get(hero_id, {})
	if not (row is Dictionary):
		return 0
	return int((row as Dictionary).get(element, 0))


static func can_learn(hero_id: String, spell_id: String) -> bool:
	if not GameData.SPELLS.has(spell_id):
		return false
	var sp: Dictionary = GameData.SPELLS[spell_id]
	var grade := int(sp.get("grade", 1))
	return grade >= 1 and grade <= max_grade(hero_id, str(sp.get("element", "")))


## Act 1 = grade 1. Grade 4 is nooit te koop (mini met 3).
static func shop_max_grade(act: int) -> int:
	return mini(maxi(act, 1), 3)


static func in_shop(spell_id: String, act: int) -> bool:
	if not GameData.SPELLS.has(spell_id):
		return false
	var grade := int(GameData.SPELLS[spell_id].get("grade", 1))
	return grade >= 1 and grade <= shop_max_grade(act)


static func block_reason(hero: Dictionary, spell_id: String) -> String:
	if can_learn(str(hero.get("id", "")), spell_id):
		return ""
	if str(hero.get("id", "")) == "dennis":
		return "Dennis leert geen magie."
	return "%s kan deze spreuk niet leren." % str(hero.get("name", "Deze held"))
