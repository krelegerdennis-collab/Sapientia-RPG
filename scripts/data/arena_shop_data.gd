extends RefCounted
## Colosseum-winkel (akkoord Dennis 25-11).
## Niet sterker dan de grot-loot grade 1 (GradeGear):
## bg_g1_zwaard atk 6, bg_g1_staf mag 6, bg_g1_helm def 3,
## bg_g1_harnas def 4, bg_g1_laarzen agi 1.
## Deze stukken blijven daar onder.

const GameData := preload("res://scripts/data/game_data.gd")

const POTION_PRICE := 6
const BLADE_PRICE := 28
const BLADE_ATK := 5
const CAP_PRICE := 18
const CAP_DEF := 2
const MAIL_PRICE := 22
const MAIL_DEF := 3

const GEAR := {
	"arena_blade": {
		"name": "Training Blade",
		"slot": "wapen",
		"atk": BLADE_ATK,
		"wie": ["krijger"],
		"desc": "A blunt blade for the Colosseum. Training stock.",
	},
	"arena_cap": {
		"name": "Training Cap",
		"slot": "helm",
		"def": CAP_DEF,
		"desc": "A soft cap. It will not stop a cave blow.",
	},
	"arena_mail": {
		"name": "Training Mail",
		"slot": "harnas",
		"def": MAIL_DEF,
		"wie": ["krijger"],
		"desc": "Light rings for practice. Weaker than cave armor.",
	},
}

const OFFERS := {
	"potion": {"item_id": "drankje", "price": POTION_PRICE},
	"blade": {"item_id": "arena_blade", "price": BLADE_PRICE},
	"cap": {"item_id": "arena_cap", "price": CAP_PRICE},
	"mail": {"item_id": "arena_mail", "price": MAIL_PRICE},
}


static func has_gear(id: String) -> bool:
	return GEAR.has(id)


static func gear(id: String) -> Dictionary:
	var raw = GEAR.get(id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func offer_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in OFFERS:
		ids.append(str(k))
	return ids


static func offer(id: String) -> Dictionary:
	var raw = OFFERS.get(id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func display_name(item_id: String) -> String:
	if has_gear(item_id):
		return str(gear(item_id).get("name", item_id))
	if GameData.ITEMS.has(item_id):
		return str(GameData.ITEMS[item_id].get("name", item_id))
	return item_id