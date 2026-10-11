extends RefCounted
class_name PvpSpells
## Gekopieerde spreuken die de drie helden nodig hebben.
## mp en power zijn de startwaarden: vuur 4/14, bliksem 7/9, genees 3/22.
## get_spell geeft altijd een kopie, zodat een gevecht de tabel niet wijzigt.


const SPELLS := {
	"vuur": {
		"name": "Vuur", "mp": 4, "target": "enemy", "type": "damage", "power": 14,
	},
	"bliksem": {
		"name": "Bliksem", "mp": 7, "target": "all_enemies", "type": "damage", "power": 9,
	},
	"genees": {
		"name": "Genees", "mp": 3, "target": "ally", "type": "heal", "power": 22,
	},
}


static func has_spell(id: String) -> bool:
	return SPELLS.has(id)


static func get_spell(id: String) -> Dictionary:
	if not SPELLS.has(id):
		return {}
	return (SPELLS[id] as Dictionary).duplicate(true)


static func display_name(id: String) -> String:
	var spell := get_spell(id)
	return str(spell.get("name", id))
