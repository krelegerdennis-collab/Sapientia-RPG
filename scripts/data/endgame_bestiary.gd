extends RefCounted
## Eindbazen van de Diepe Grot. Ze hergebruiken een bestaand monster (sprite, elementen).
## Geen nieuwe canon: de regel is feitelijk uit dungeon100_scaling.gd. Lore-tekst blijft
## open tot Dennis die schrijft.

const GameData := preload("res://scripts/data/game_data.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")


static func id_for_floor(floor_nr: int) -> String:
	if not Scaling.BOSSES.has(floor_nr):
		return ""
	return "d100_baas_%d" % floor_nr


static func _floor_of(id: String) -> int:
	if not id.begins_with("d100_baas_"):
		return 0
	var n := id.trim_prefix("d100_baas_").to_int()
	return n if Scaling.BOSSES.has(n) else 0


static func has(id: String) -> bool:
	return _floor_of(id) > 0


static func ids() -> Array:
	var floors: Array = Scaling.BOSSES.keys()
	floors.sort()
	var out: Array = []
	for f in floors:
		out.append(id_for_floor(int(f)))
	return out


static func entry(id: String) -> Dictionary:
	var floor := _floor_of(id)
	if floor <= 0:
		return {}
	var b: Dictionary = Scaling.BOSSES[floor]
	var base: Dictionary = GameData.ENEMIES[str(b["enemy"])]
	var stats := Scaling.boss_stats(base, floor)
	return {
		"name": str(b["name"]),
		"no": 12 + int(floor / 10),
		"desc": "Baas op verdieping %d van de Diepe Grot. Zelfde gedaante als %s." % [floor, str(base.get("name", ""))],
		"max_hp": int(stats.get("max_hp", 1)),
		"atk": int(stats.get("atk", 1)),
		"def": int(stats.get("def", 0)),
		"agi": int(stats.get("agi", 1)),
		"exp": int(stats.get("exp", 0)),
		"gold": int(stats.get("gold", 0)),
		"mp": int(stats.get("mp", base.get("mp", 0))),
		"weak": base.get("weak", []),
		"resist": base.get("resist", []),
		"sprite": str(base.get("sprite", "")),
		"sprite_placeholder": str(base.get("sprite_placeholder", "")),
		"drops": [],
		"habitat": ["dungeon100"],
	}
