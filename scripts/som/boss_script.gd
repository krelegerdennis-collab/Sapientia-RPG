extends RefCounted
class_name BossScript
## D3: data voor realtime bazen in Action (COMBAT_DESIGN §12). PR B vult REGISTRY per vijand.

## enemy_id -> { "phases": [{ hp_until, attacks, adds, on_enter }] }
static var REGISTRY: Dictionary = {}


static func has_script(enemy_id: String) -> bool:
	return REGISTRY.has(enemy_id)


static func script_for(enemy_id: String) -> Dictionary:
	return REGISTRY.get(enemy_id, {})


## Normaliseer fase-blokken uit content-data (PR B) of tests.
static func parse_phases(raw: Array) -> Array:
	var out: Array = []
	for item in raw:
		if item is Dictionary:
			var p: Dictionary = item
			out.append({
				"hp_until": float(p.get("hp_until", 0.0)),
				"attacks": p.get("attacks", []),
				"adds": p.get("adds", []),
				"on_enter": str(p.get("on_enter", "")),
			})
	return out


static func register(enemy_id: String, data: Dictionary) -> void:
	var copy := data.duplicate(true)
	if copy.has("phases"):
		copy["phases"] = parse_phases(copy["phases"])
	REGISTRY[enemy_id] = copy


static func unregister(enemy_id: String) -> void:
	REGISTRY.erase(enemy_id)
