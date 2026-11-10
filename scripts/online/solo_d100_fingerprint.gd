class_name SoloD100Fingerprint
extends RefCounted
## Vaste vingerafdruk van de solo-DLS (Classic) op de start-commit van M7.
## monster_stats, boss_stats, chest_loot en generate(seed, f). Geen online-pad.

const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const GameData := preload("res://scripts/data/game_data.gd")

const SEEDS: Array[int] = [1, 42]
const BOSS_BASE_ID := "papiergeest"


static func djb2(s: String) -> String:
	var h := 5381
	for i in s.length():
		h = ((h << 5) + h + s.unicode_at(i)) & 0x7FFFFFFF
	return "%08x" % h


static func canon(v) -> String:
	if v is Dictionary:
		var keys: Array = v.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		var parts: PackedStringArray = []
		for k in keys:
			parts.append("%s:%s" % [str(k), canon(v[k])])
		return "{" + "|".join(parts) + "}"
	if v is Array:
		var parts: PackedStringArray = []
		for item in v:
			parts.append(canon(item))
		return "[" + ",".join(parts) + "]"
	if v is float:
		return "%.6f" % v
	if v is bool:
		return "1" if v else "0"
	if v is Vector2i:
		return "%d,%d" % [v.x, v.y]
	if v is Vector2:
		return "%.3f,%.3f" % [v.x, v.y]
	return str(v)


static func monster_hash(floor_no: int) -> String:
	var ids: Array = GameData.ENEMIES.keys()
	ids.sort()
	var parts: PackedStringArray = []
	for id in ids:
		var base: Dictionary = GameData.ENEMIES[id]
		if not base.has("max_hp") or not base.has("atk") or not base.has("def"):
			continue
		parts.append("%s=%s" % [str(id), canon(Scaling.monster_stats(base, floor_no))])
	return djb2("|".join(parts))


static func boss_hash(floor_no: int) -> String:
	var base: Dictionary = GameData.ENEMIES[BOSS_BASE_ID]
	return djb2(canon(Scaling.boss_stats(base, floor_no)))


static func chest_hash(floor_no: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 910000 + floor_no
	var normal: Dictionary = Scaling.chest_loot(floor_no, rng, false)
	rng.seed = 920000 + floor_no
	var boss: Dictionary = Scaling.chest_loot(floor_no, rng, true)
	return djb2(canon(normal) + "#" + canon(boss))


static func generate_hash(seed: int, floor_no: int) -> String:
	var data := Gen.generate(seed, floor_no)
	if data.is_empty():
		return djb2("EMPTY")
	var room: Dictionary = data.get("room", {})
	var parts: PackedStringArray = []
	parts.append("f=%s" % str(data.get("floor", 0)))
	parts.append("fs=%s" % str(data.get("floor_seed", 0)))
	parts.append("boss=%s" % str(data.get("is_boss_floor", false)))
	parts.append("mile=%s" % str(data.get("is_milestone", false)))
	parts.append("lt=%s" % str(data.get("layout_type", "")))
	var layout: Array = room.get("layout", [])
	for row in layout:
		parts.append(str(row))
	var mons: Array = room.get("monsters", []).duplicate()
	mons.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	for m in mons:
		parts.append("m:%s" % canon(m))
	var chests: Array = room.get("chests", []).duplicate()
	chests.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	for c in chests:
		parts.append("c:%s" % canon(c))
	parts.append("rest:%s" % canon(room.get("rustpunt", [])))
	parts.append("warp:%s" % canon(room.get("warper", [])))
	parts.append("pz:%s" % canon(room.get("puzzel", {})))
	return djb2("|".join(parts))


static func snapshot() -> Dictionary:
	var monster := {}
	var boss := {}
	var chest := {}
	var gen := {}
	for f in range(1, Scaling.MAX_FLOOR + 1):
		var key := str(f)
		monster[key] = monster_hash(f)
		boss[key] = boss_hash(f)
		chest[key] = chest_hash(f)
		var per_seed := {}
		for seed in SEEDS:
			per_seed[str(seed)] = generate_hash(seed, f)
		gen[key] = per_seed
	return {
		"version": 1,
		"note": "Golden solo-DLS op coop/easy @5101abab, vóór het online-pad. Hashes, geen balanswijziging.",
		"seeds": [1, 42],
		"monster": monster,
		"boss": boss,
		"chest": chest,
		"generate": gen,
	}
