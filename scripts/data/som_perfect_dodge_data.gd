class_name SomPerfectDodgeData
extends RefCounted
## F1 perfect dodge (Action WM1). Standaard uit tot de balanspas.

const ENABLED := false

## Testsuite zet dit op true (byte-identiek gedrag als uit wanneer false).
static var force_active: Variant = null

const WINDOW_TICKS := 6
const GUEST_BONUS_TICKS := 3
const HITSTOP_TICKS := 18
const GOLEM_HITSTOP_TICKS := 0
const COUNTER_WINDOW_TICKS := 30
const COUNTER_DAMAGE_MULT := 1.5
const STAMINA_REFUND := 15
const ICD_TICKS := 90
const FLASH_TICKS := 4
const COUNTER_NUM_SCALE := 1.25

const COL_FREEZE_TINT := Color("#7FE7FF")

## Bit 0 in vijand snapshot pose-byte.
const POSE_FREEZE_BIT := 1


static func is_active() -> bool:
	if force_active != null:
		return bool(force_active)
	return ENABLED


static func window_for_hero(arena: Node, hero_id: String) -> int:
	var w := WINDOW_TICKS
	if arena != null and "coop_mode" in arena and bool(arena.coop_mode) and arena.has_method("_slot_for_hero"):
		var slot: int = arena._slot_for_hero(hero_id)
		if slot > 0:
			w += GUEST_BONUS_TICKS
	return w