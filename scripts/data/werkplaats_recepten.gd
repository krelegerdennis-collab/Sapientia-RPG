extends RefCounted
## RECEPTEN VAN DE WERKPLAATS (World Warper, act 4). Data + regels, geen node, geen UI.
## UI: scripts/ui/werkplaats_scherm.gd. Kamer: world_warper/kamers/werkplaats.tscn.
##
## Bron van de ingrediënten: er bestaan (nog) geen aparte materialen in de game. Daarom gebruikt
## elk recept alleen items die monsters laten vallen (GameData.ENEMIES "drops"):
##   drankje (Potion), toverwater (Magic Water), sterk_drankje (Strong Potion),
##   toverbrouwsel (Magic Brew), elixer (Elixir).
## De uitkomst is steeds een bestaand item, één stap hoger in dezelfde soort (HP / MP / beide).
## TODO(design, Dennis): aantallen per recept zijn een voorstel (3 -> 1, 2+2 -> Elixir).
## Nieuwe materialen (monster-onderdelen) komen hier als extra regels, zodra ze in GameData staan.
##
## Recept: {"id", "uit": item-id, "n": aantal, "in": {item-id: aantal}, "min_act"}.

const GameData := preload("res://scripts/data/game_data.gd")

const RECEPTEN: Array = [
	{"id": "sterk_drankje", "uit": "sterk_drankje", "n": 1, "in": {"drankje": 3}, "min_act": 4},
	{"id": "toverbrouwsel", "uit": "toverbrouwsel", "n": 1, "in": {"toverwater": 3}, "min_act": 4},
	{"id": "elixer", "uit": "elixer", "n": 1, "in": {"sterk_drankje": 2, "toverbrouwsel": 2}, "min_act": 4},
]

const TITEL := "Workshop"
const LEEG := "There are no recipes yet."
const GEMAAKT := "Crafted: %s."
const TE_WEINIG := "Not enough materials."
const ONBEKEND := "That recipe doesn't exist."


static func recept(id: String) -> Dictionary:
	for r in RECEPTEN:
		if str((r as Dictionary).get("id", "")) == id:
			return r
	return {}


static func item_naam(id: String) -> String:
	if GameData.ITEMS.has(id):
		return str(GameData.ITEMS[id].get("name", id))
	return id


## Recepten die in deze act zichtbaar zijn.
static func lijst(act: int) -> Array:
	var out: Array = []
	for r in RECEPTEN:
		if int((r as Dictionary).get("min_act", 1)) <= act:
			out.append(r)
	return out


static func kan_maken(r: Dictionary, inventory: Dictionary) -> bool:
	if r.is_empty():
		return false
	var ingr: Dictionary = r.get("in", {})
	for id in ingr:
		if int(inventory.get(id, 0)) < int(ingr[id]):
			return false
	return true


## "3x Potion" etc., voor de knop.
static func ingredienten_tekst(r: Dictionary, inventory: Dictionary) -> String:
	var delen: PackedStringArray = []
	var ingr: Dictionary = r.get("in", {})
	for id in ingr:
		delen.append("%d %s (%d)" % [int(ingr[id]), item_naam(str(id)), int(inventory.get(id, 0))])
	return ", ".join(delen)


## Maakt het recept met de zak van de speler (in-place). {ok, text}.
static func maak(id: String, inventory: Dictionary) -> Dictionary:
	var r := recept(id)
	if r.is_empty():
		return {"ok": false, "text": ONBEKEND}
	if not kan_maken(r, inventory):
		return {"ok": false, "text": TE_WEINIG}
	var ingr: Dictionary = r.get("in", {})
	for ing in ingr:
		var rest := int(inventory.get(ing, 0)) - int(ingr[ing])
		if rest <= 0:
			inventory.erase(ing)
		else:
			inventory[ing] = rest
	var uit := str(r["uit"])
	inventory[uit] = int(inventory.get(uit, 0)) + int(r.get("n", 1))
	return {"ok": true, "text": GEMAAKT % item_naam(uit)}


## Elk ingrediënt valt bij een monster; elke uitkomst bestaat. Voor de tests.
static func fouten() -> Array[String]:
	var drops := {}
	for eid in GameData.ENEMIES:
		var d: Variant = GameData.ENEMIES[eid].get("drops", [])
		if d is Array:
			for x in d:
				if x is Dictionary:
					drops[str(x.get("item", ""))] = true
	var out: Array[String] = []
	for r in RECEPTEN:
		if not GameData.ITEMS.has(str(r.get("uit", ""))):
			out.append("uitkomst bestaat niet: " + str(r.get("id")))
		for ing in (r.get("in", {}) as Dictionary):
			if not GameData.ITEMS.has(str(ing)):
				out.append("ingrediënt bestaat niet: " + str(ing))
			elif not drops.has(str(ing)):
				out.append("ingrediënt valt bij geen monster: " + str(ing))
	return out


static func speler_teksten() -> Array[String]:
	return [TITEL, LEEG, GEMAAKT % "Elixir", TE_WEINIG, ONBEKEND]
