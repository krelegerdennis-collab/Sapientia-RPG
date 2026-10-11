extends RefCounted
## Eén winkelraam voor Wilgendal: wapen, pantser, accessoire, magie, plus de kruiden van Tante Mien.
## Bevestigd: prijzen en welke stukken pas in een latere act liggen.
## Act = hoogste level in de party (level_scale), niet een aparte verhaalvlag. Bevestigd.
## Bevestigd: verkoop is de helft van de vraagprijs (naar beneden).
## Bevestigd: Jelle Hamer heeft twee balies (wapen en pantser), één smid.

const GameData := preload("res://scripts/data/game_data.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")
const PartyActions := preload("res://scripts/party_actions.gd")

## Bevestigd: ijzeren helm, maliënkolder en groenring pas vanaf act 2, zodat act 1 niet alles toont.
const SHOPS := {
	"wilgendal_wapen": {
		"name": "Wapens",
		"offers": [
			{"id": "kort_zwaard", "min_act": 1},
			{"id": "dolk", "min_act": 1},
			{"id": "eiken_staf", "min_act": 1},
		],
	},
	"wilgendal_pantser": {
		"name": "Pantser",
		"offers": [
			{"id": "houten_schild", "min_act": 1},
			{"id": "kaftschild", "min_act": 1},
			{"id": "leren_kap", "min_act": 1},
			{"id": "reisgewaad", "min_act": 1},
			{"id": "leren_harnas", "min_act": 1},
			{"id": "ijzeren_helm", "min_act": 2},
			{"id": "malienkolder", "min_act": 2},
		],
	},
	"wilgendal_accessoire": {
		"name": "Accessoires",
		"offers": [
			{"id": "bladwijzer", "min_act": 1},
			{"id": "groenring", "min_act": 2},
		],
	},
	"wilgendal_kruiden": {
		"name": "Kruiden",
		"offers": [
			{"id": "kruidenthee", "min_act": 1, "price": 20},
		],
	},
	"wilgendal_magie": {"name": "Magie", "magic": true},
}


static func shop_name(shop_id: String) -> String:
	return str(SHOPS.get(shop_id, {}).get("name", "Winkel"))


static func is_magic(shop_id: String) -> bool:
	return bool(SHOPS.get(shop_id, {}).get("magic", false))


static func current_act() -> int:
	var lv := 1
	for h in GameState.party:
		lv = maxi(lv, int(h.get("level", 1)))
	return maxi(1, GameData.act_for_level(lv))


static func _offer_price(offer: Dictionary) -> int:
	if offer.has("price"):
		return int(offer["price"])
	return _data_price(str(offer.get("id", "")))


static func _data_price(id: String) -> int:
	if GameData.ITEMS.has(id):
		return int(GameData.ITEMS[id].get("price", 0))
	if GameData.EQUIPMENT.has(id):
		return int(GameData.EQUIPMENT[id].get("price", 0))
	if GradeGear.has_item(id):
		return int(GradeGear.item(id).get("grade", 1)) * 30
	return 0


static func list_price(id: String) -> int:
	for shop_id in SHOPS:
		var shop: Dictionary = SHOPS[shop_id]
		if bool(shop.get("magic", false)):
			continue
		for offer in shop.get("offers", []):
			if str(offer.get("id", "")) == id and offer.has("price"):
				return int(offer["price"])
	if GameData.SPELLS.has(id):
		var g := int(GameData.SPELLS[id].get("grade", 1))
		# Bevestigd: vraagprijs magie = 160 × grade². Grade 4 ligt niet in de winkel.
		return 160 * g * g
	return _data_price(id)


static func sell_price(id: String) -> int:
	if GameData.KEY_ITEMS.has(id):
		return 0
	var p := list_price(id)
	if p <= 0:
		return 0
	return maxi(1, int(p / 2.0))


## Koopregels die nu in de schappen liggen: {id, name, price, kind}.
static func stock(shop_id: String) -> Array:
	var shop: Dictionary = SHOPS.get(shop_id, {})
	var act := current_act()
	var out: Array = []
	if bool(shop.get("magic", false)):
		for sid in GameData.SPELLS:
			if not SpellRules.in_shop(str(sid), act):
				continue
			var sp: Dictionary = GameData.SPELLS[sid]
			out.append({
				"id": str(sid),
				"name": str(sp.get("name", sid)),
				"price": list_price(str(sid)),
				"kind": "spell",
				"grade": int(sp.get("grade", 1)),
			})
		return out
	for offer in shop.get("offers", []):
		if int(offer.get("min_act", 1)) > act:
			continue
		var id := str(offer.get("id", ""))
		var naam := id
		if GameData.ITEMS.has(id):
			naam = str(GameData.ITEMS[id].get("name", id))
		elif GameData.EQUIPMENT.has(id):
			naam = str(GameData.EQUIPMENT[id].get("name", id))
		out.append({"id": id, "name": naam, "price": _offer_price(offer), "kind": "item", "grade": 0})
	return out


static func _in_stock(shop_id: String, id: String) -> Dictionary:
	for row in stock(shop_id):
		if str(row.get("id", "")) == id:
			return row
	return {}


static func buy_item(shop_id: String, id: String) -> Dictionary:
	var row := _in_stock(shop_id, id)
	if row.is_empty() or str(row.get("kind", "")) != "item":
		return {"ok": false, "text": "Dat ligt hier niet."}
	var price := int(row["price"])
	if GameState.gold < price:
		return {"ok": false, "text": "Te weinig goud."}
	GameState.gold -= price
	GameState.inventory[id] = int(GameState.inventory.get(id, 0)) + 1
	return {"ok": true, "text": "Gekocht."}


static func buy_spell(shop_id: String, spell_id: String, hero: Dictionary) -> Dictionary:
	var row := _in_stock(shop_id, spell_id)
	if row.is_empty() or str(row.get("kind", "")) != "spell":
		return {"ok": false, "text": "Dat ligt hier niet."}
	if not (hero.get("spells") is Array):
		hero["spells"] = []
	if (hero["spells"] as Array).has(spell_id):
		return {"ok": false, "text": "Kent deze spreuk al."}
	var why := SpellRules.block_reason(hero, spell_id)
	if why != "":
		return {"ok": false, "text": why}
	var price := int(row["price"])
	if GameState.gold < price:
		return {"ok": false, "text": "Te weinig goud."}
	if not PartyActions.teach_spell(hero, spell_id):
		return {"ok": false, "text": why if why != "" else "Niemand kan dit leren."}
	GameState.gold -= price
	return {"ok": true, "text": "Gekocht."}


static func sell(id: String) -> Dictionary:
	if int(GameState.inventory.get(id, 0)) <= 0:
		return {"ok": false, "text": "Dat heb je niet."}
	var price := sell_price(id)
	if price <= 0:
		return {"ok": false, "text": "Dat koop ik niet."}
	GameState.inventory[id] = int(GameState.inventory[id]) - 1
	if int(GameState.inventory[id]) <= 0:
		GameState.inventory.erase(id)
	GameState.gold += price
	return {"ok": true, "text": "Verkocht.", "gold": price}


## Wat de speler nu kan verkopen: id -> aantal, alleen met een verkoopprijs.
static func sellable() -> Array:
	var out: Array = []
	for id in GameState.inventory:
		if int(GameState.inventory[id]) <= 0:
			continue
		var price := sell_price(str(id))
		if price <= 0:
			continue
		var naam := str(id)
		if GameData.ITEMS.has(id):
			naam = str(GameData.ITEMS[id].get("name", id))
		elif GameData.EQUIPMENT.has(id):
			naam = str(GameData.EQUIPMENT[id].get("name", id))
		elif GradeGear.has_item(str(id)):
			naam = str(GradeGear.item(str(id)).get("name", id))
		out.append({"id": str(id), "name": naam, "price": price, "n": int(GameState.inventory[id])})
	return out
