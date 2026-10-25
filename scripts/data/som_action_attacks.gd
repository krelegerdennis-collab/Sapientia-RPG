## Action-telegraafaanvallen (Combat T4a). Data voor TelegraphShape.from_data + TelegraphState-fasen.
## Schade en globale cooldown blijven in SomData / enemy_stats; hier alleen vorm en fase-ms.
## windup/active/recovery zijn milliseconden (omgezet via TelegraphState.ms_to_ticks).

const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const _SomData := preload("res://scripts/data/som_data.gd")

## Volledige aanvalsdefinitie per id (COMBAT_DESIGN.md §11).
const ATTACKS := {
	"inktspuw": {
		"id": "inktspuw",
		"shape": "line",
		## Lengte/breedte in pixels: benader de oude ENEMY_REACH-check (22 px middelpunt-middelpunt,
		## size 1x1). Breedte 44 = ±22 om de as (gesloten band), gelijk aan een schijf met straal 22.
		"reach": 22,
		"width": 44,
		## Fasen (ms): windup = SomData.TELEGRAPH; active = 1 tick treffer; recovery = 0 (animatie
		## loopt los van de sim, zoals voorheen). Cooldown-ms komt per kamer uit attack_cooldown().
		"windup_ms": 450,
		"active_ms": 1,
		"recovery_ms": 0,
	},
}

## Standaard Action-aanval per vijand-id (eerste telegraaf-gedreven vijand: Inktwurm).
const ENEMY_DEFAULT_ATTACK := {
	"inktwurm": "inktspuw",
}


static func attack(id: String) -> Dictionary:
	return (ATTACKS.get(id, {}) as Dictionary).duplicate(true)


static func default_attack_for_enemy(enemy_id: String) -> String:
	return str(ENEMY_DEFAULT_ATTACK.get(enemy_id, ""))


static func has_telegraph_attack(enemy_id: String) -> bool:
	return default_attack_for_enemy(enemy_id) != "" and ATTACKS.has(default_attack_for_enemy(enemy_id))


## Cooldown in ms voor deze kamer/tier (SomData.attack_cooldown, geen stats-wijziging).
static func cooldown_ms(room_id: String, tier: int) -> int:
	return int(roundf(float(_SomData.attack_cooldown(room_id, tier)) * 1000.0))


## Totale tickduur van één cyclus (windup+active+recovery+cooldown) bij 60 Hz — voor tests en mapping.
static func cycle_ticks(def: Dictionary, cooldown_ms_val: int) -> int:
	return TelegraphState.ms_to_ticks(int(def.get("windup_ms", 0))) + TelegraphState.ms_to_ticks(int(def.get("active_ms", 0))) \
			+ TelegraphState.ms_to_ticks(int(def.get("recovery_ms", 0))) + TelegraphState.ms_to_ticks(cooldown_ms_val)
