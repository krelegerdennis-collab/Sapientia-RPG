class_name EnemyAttacks
extends RefCounted
## Action-telegraafaanvallen (Combat T4a/T4b). Data voor TelegraphShape + zone-spawn.
## Schade-multipliers (`power`, `zone_dot_power`) zijn relatief t.o.v. de huidige Action-klap (hit_member).

const TILE_PX := 16
## Inktplas: cirkel r 1,5 tegel (vast bij windup-start op doelpositie).
const INKPLAS_RADIUS_PX := 24

const ATTACKS := {
	"inktspuw": {
		"id": "inktspuw",
		"shape": "line",
		"reach": 22,
		"width": 44,
		"windup_ms": 450,
		"active_ms": 1,
		"recovery_ms": 0,
		"power": 1.0,
	},
	"inktplas": {
		"id": "inktplas",
		"shape": "circle",
		"reach": INKPLAS_RADIUS_PX,
		"windup_ms": 700,
		"active_ms": 1,
		"recovery_ms": 0,
		"power": 0.8,
		"aim": "target",
		"spawns_zone": true,
		"zone_ticks": 120,
		"zone_dot_power": 0.3,
		"zone_slow_mult": 0.6,
	},
}

## Gewogen pool per vijand-id (uniform; host-RNG in SomArena).
const ENEMY_ATTACK_POOLS := {
	"inktwurm": ["inktspuw", "inktplas"],
}

const ENEMY_DEFAULT_ATTACK := {
	"inktwurm": "inktspuw",
}


static func attack(id: String) -> Dictionary:
	return (ATTACKS.get(id, {}) as Dictionary).duplicate(true)


static func default_attack_for_enemy(enemy_id: String) -> String:
	return str(ENEMY_DEFAULT_ATTACK.get(enemy_id, ""))


static func has_telegraph_attack(enemy_id: String) -> bool:
	return not ENEMY_ATTACK_POOLS.get(enemy_id, []).is_empty() or default_attack_for_enemy(enemy_id) != ""


static func pick_attack(enemy_id: String, rng: RandomNumberGenerator) -> String:
	var pool: Array = ENEMY_ATTACK_POOLS.get(enemy_id, [])
	if pool.is_empty():
		return default_attack_for_enemy(enemy_id)
	return str(pool[rng.randi_range(0, pool.size() - 1)])
