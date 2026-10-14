extends RefCounted
class_name PvpItems
## PvP-drankjes. Alleen in het gevecht, geen opslag daarbuiten.
## Drankje: 30 HP. Toverwater: 10 MP. Aantallen per modus zitten in de tassen.


const ITEMS := {
	"drankje": {"name": "Potion", "heal_hp": 30, "heal_mp": 0},
	"toverwater": {"name": "Magic Water", "heal_hp": 0, "heal_mp": 10},
}

const BAGS := {
	"early": {"drankje": 2, "toverwater": 1},
	"mid": {"drankje": 3, "toverwater": 2},
	"high": {"drankje": 4, "toverwater": 2},
}


static func has_item(id: String) -> bool:
	return ITEMS.has(id)


static func get_item(id: String) -> Dictionary:
	if not ITEMS.has(id):
		return {}
	return (ITEMS[id] as Dictionary).duplicate(true)


static func bag_for(mode_id: String) -> Dictionary:
	var src: Dictionary = BAGS["early"]
	if BAGS.has(mode_id):
		src = BAGS[mode_id]
	return src.duplicate(true)


static func display_name(id: String) -> String:
	var item := get_item(id)
	return str(item.get("name", id))
