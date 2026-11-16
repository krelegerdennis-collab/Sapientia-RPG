extends RefCounted
## Koop voor Arena Tokens. Zelfde tas als de rest van het spel (GameState.add_item).

const Data := preload("res://scripts/data/arena_shop_data.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")


static func buy(offer_id: String) -> Dictionary:
	if not ReleaseFlags.arena_enabled():
		return {"ok": false, "text": "The Colosseum is closed."}
	var row := Data.offer(offer_id)
	if row.is_empty():
		return {"ok": false, "text": "That isn't sold here."}
	var price := int(row.get("price", 0))
	var item_id := str(row.get("item_id", ""))
	if item_id == "" or price < 0:
		return {"ok": false, "text": "That isn't sold here."}
	if GameState.arena_tokens < price:
		return {"ok": false, "text": "Not enough Arena Tokens."}
	if not GameState.spend_arena_tokens(price):
		return {"ok": false, "text": "Not enough Arena Tokens."}
	GameState.add_item(item_id, 1)
	return {"ok": true, "text": "Bought.", "item_id": item_id}
