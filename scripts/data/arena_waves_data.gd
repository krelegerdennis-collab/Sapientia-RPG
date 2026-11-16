extends RefCounted
class_name ArenaWavesData
## PLACEHOLDER: balans door Dennis. Alleen aantallen, HP-schaal en vijandpools voor de arena-hal.

const GameData := preload("res://scripts/data/game_data.gd")

# PLACEHOLDER: balans door Dennis — vijanden per golf
const WAVE_COUNT := {
	1: 3,
	2: 4,
	3: 5,
	4: 6,
	5: 7,
}

# PLACEHOLDER: balans door Dennis — HP-vermenigvuldiger t.o.v. game_data-basis
const HP_MULT := {
	1: 1.0,
	2: 1.1,
	3: 1.2,
	4: 1.35,
	5: 1.5,
}

## Hal-ingang (zuid), zelfde tegel als arena_room._ensure_spawn voor room_kind hall.
const HALL_SPAWN_FALLBACK := Vector2i(14, 18)
## Minimale Chebyshev-afstand spawnpunt → vijand-tegel.
const MIN_TILE_DIST_FROM_SPAWN := 3
## Max frames wachten op arena_hall voordat de golf wordt overgeslagen (geen soft lock).
const HALL_FIND_MAX_FRAMES := 120
## RNG-stap per monster binnen één golf (zelfde patroon als arena_room.add_monster).
const MONSTER_RNG_STRIDE := 7919

## Alleen gewone WM1-mapmonsters (geen bazen/golems).
const WM1_ENEMY_IDS: Array[String] = [
	"mosslijm",
	"moskonijn",
	"papiergeest",
	"glitchmot",
	"mech_wachter",
	"wortelkruiper",
	"mistuil",
	"sporenzwam",
]

# PLACEHOLDER: balans door Dennis — per golf 3–5 ids uit de WM1-set
const WAVE_POOLS := {
	1: ["mosslijm", "moskonijn", "papiergeest"],
	2: ["moskonijn", "papiergeest", "glitchmot"],
	3: ["papiergeest", "glitchmot", "mech_wachter", "wortelkruiper"],
	4: ["glitchmot", "mech_wachter", "wortelkruiper", "mistuil"],
	5: ["mech_wachter", "wortelkruiper", "mistuil", "sporenzwam", "mosslijm"],
}


static func enemy_count(wave: int) -> int:
	return int(WAVE_COUNT.get(wave, 3))


static func hp_multiplier(wave: int) -> float:
	return float(HP_MULT.get(wave, 1.0))


static func pool_for_wave(wave: int) -> Array[String]:
	var raw = WAVE_POOLS.get(wave, WM1_ENEMY_IDS.slice(0, 3))
	var out: Array[String] = []
	for id in raw:
		var sid := str(id)
		if sid != "" and GameData.ENEMIES.has(sid) and not _is_boss(sid):
			out.append(sid)
	if out.is_empty():
		return WM1_ENEMY_IDS.slice(0, mini(3, WM1_ENEMY_IDS.size()))
	return out


static func all_wm1_ids() -> Array[String]:
	var out: Array[String] = []
	for id in WM1_ENEMY_IDS:
		if GameData.ENEMIES.has(id) and not _is_boss(id):
			out.append(id)
	return out


static func _is_boss(enemy_id: String) -> bool:
	var d: Dictionary = GameData.ENEMIES.get(enemy_id, {})
	return bool(d.get("is_boss", false)) or enemy_id == "kennis_beest"