extends RefCounted
## DUNGEON100 INHOUD per verdieping: welke monsters en kisten op de slots van de generator komen.
## Dit is de ENIGE plek waar de generator iets van spelbalans weet; schaal, loot, bazen en
## rustpunten (aparte taken) haken hier in zonder de generator aan te raken:
##   tier_for_floor(f)      monsterniveau 1-4 voor game_data.gd TIERS (komt in room["tier"])
##   monsters(data)         Array met "monsters"-regels (formaat: scripts/data/dungeon_rooms.gd)
##   chests(data)           Array met "chests"-regels
##   fill_room(room, data)  zet het resultaat in de kamerdata; hier kun je ook baas/rustpunt aan
##                          room toevoegen (data["boss_slot"], data["rest_slot"], data["is_boss_floor"])
## 'data' = het resultaat van Dungeon100Generator.generate() (zonder "room"): "floor", "floor_seed",
## "monster_slots", "chest_slots", "boss_slot", "rest_slot", "is_boss_floor", ...
## Alles is deterministisch: de willekeur komt uit data["floor_seed"], nooit uit randi().

## Vijanden die op een verdieping kunnen voorkomen (game_data.gd ENEMIES, geen bazen).
const POOLS := [
	{"from": 1, "enemies": ["mosslijm", "moskonijn", "papiergeest"]},
	{"from": 11, "enemies": ["glitchmot"]},
	{"from": 31, "enemies": ["mech_wachter"]},
	{"from": 51, "enemies": ["wortelkruiper", "mistuil"]},
	{"from": 71, "enemies": ["sporenzwam"]},
]
## Voorwerpen in kisten (game_data.gd ITEMS).
const CHEST_ITEMS := ["drankje", "drankje", "kruid", "toverwater"]


## Monsterniveau (TIERS 1-4): per 25 verdiepingen een stap.
static func tier_for_floor(floor_no: int) -> int:
	return clampi(1 + (floor_no - 1) / 25, 1, 4)


static func enemy_pool(floor_no: int) -> Array:
	var out: Array = []
	for p in POOLS:
		if floor_no >= int(p["from"]):
			out.append_array(p["enemies"])
	return out


static func monsters(data: Dictionary) -> Array:
	var f: int = data["floor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data["floor_seed"]) + 101
	var pool := enemy_pool(f)
	var out: Array = []
	var i := 0
	for t in data["monster_slots"]:
		i += 1
		var size := 1 + (1 if rng.randf() < 0.25 + f / 200.0 else 0) + (1 if f > 40 and rng.randf() < 0.3 else 0)
		var group: Array = []
		for k in size:
			group.append(pool[rng.randi_range(0, pool.size() - 1)])
		out.append({"id": "m%d" % i, "enemy": group[0], "group": group, "tile": [t.x, t.y], "moves": true})
	return out


static func chests(data: Dictionary) -> Array:
	var f: int = data["floor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data["floor_seed"]) + 202
	var out: Array = []
	var i := 0
	for t in data["chest_slots"]:
		i += 1
		out.append({"id": "d100_%d_%d_%d" % [int(data["run_seed"]), f, i], "tile": [t.x, t.y],
				"item": CHEST_ITEMS[rng.randi_range(0, CHEST_ITEMS.size() - 1)], "n": 1 + f / 34})
	return out


static func fill_room(room: Dictionary, data: Dictionary) -> void:
	room["monsters"] = monsters(data)
	room["chests"] = chests(data)
