## Action-telegraafaanvallen (Combat T4a/T4b). Data voor TelegraphShape.from_data + TelegraphState-fasen.
## Definities staan in `scripts/som/enemy_attacks.gd`; hier alleen helpers + cooldown uit SomData.

const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const EnemyAttacks := preload("res://scripts/som/enemy_attacks.gd")
const _SomData := preload("res://scripts/data/som_data.gd")


static func attack(id: String) -> Dictionary:
	return EnemyAttacks.attack(id)


static func default_attack_for_enemy(enemy_id: String) -> String:
	return EnemyAttacks.default_attack_for_enemy(enemy_id)


static func has_telegraph_attack(enemy_id: String) -> bool:
	return EnemyAttacks.has_telegraph_attack(enemy_id)


static func pick_attack(enemy_id: String, rng: RandomNumberGenerator) -> String:
	return EnemyAttacks.pick_attack(enemy_id, rng)


## Cooldown in ms voor deze kamer/tier (SomData.attack_cooldown, geen stats-wijziging).
static func cooldown_ms(room_id: String, tier: int) -> int:
	return int(roundf(float(_SomData.attack_cooldown(room_id, tier)) * 1000.0))


## Totale tickduur van één cyclus (windup+active+recovery+cooldown) bij 60 Hz — voor tests en mapping.
static func cycle_ticks(def: Dictionary, cooldown_ms_val: int) -> int:
	return TelegraphState.ms_to_ticks(int(def.get("windup_ms", 0))) + TelegraphState.ms_to_ticks(int(def.get("active_ms", 0))) \
			+ TelegraphState.ms_to_ticks(int(def.get("recovery_ms", 0))) + TelegraphState.ms_to_ticks(cooldown_ms_val)
