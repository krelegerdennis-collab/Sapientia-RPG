class_name SomSignatureData
extends RefCounted
## F3 signature-eigenschap per held (keten/charge). Host-tick, deterministisch.

const ENABLED := true

## Tests zetten dit (null = standaard).
static var force_active: Variant = null

## Vesper backstab: vijand-facing · aanvalrichting > drempel.
const BACKSTAB_DOT := 0.5
const CRIT_MULT := 1.5

## Dax (dennis): knockback-tegels (finisher / heavy L1 / L2).
const DAX_KNOCK_FIN := 3
const DAX_KNOCK_HEAVY1 := 3
const DAX_KNOCK_HEAVY2 := 4
const DAX_STAGGER_MULT := 1.25

## Seren (lotte): na finisher met treffer.
const SEREN_HEAL_PCT := 0.04
const SEREN_HEAL_RADIUS_PX := 48.0
const SEREN_ICD_TICKS := 120

## Kael (kael): aggro lock na finisher.
const KAEL_LOCK_TICKS := 150
const KAEL_ICD_TICKS := 240

## Orion (orion): slow + windup-verlenging (geen Golem-windup).
const ORION_SLOW_MULT := 0.6
const ORION_SLOW_TICKS := 90
const ORION_WINDUP_EXTRA_TICKS := 6

## Partij-ids per rij (zelfde als game_data-helden).
const HERO_IDS: Array[String] = ["dennis", "lotte", "noor", "kael", "orion"]

const ROWS := {
	"dennis": {"trait": "dax", "knock_fin": DAX_KNOCK_FIN, "knock_h1": DAX_KNOCK_HEAVY1, "knock_h2": DAX_KNOCK_HEAVY2,
			"stagger_mult": DAX_STAGGER_MULT},
	"lotte": {"trait": "seren", "heal_pct": SEREN_HEAL_PCT, "heal_radius": SEREN_HEAL_RADIUS_PX, "icd": SEREN_ICD_TICKS},
	"noor": {"trait": "vesper", "backstab_dot": BACKSTAB_DOT, "crit_mult": CRIT_MULT},
	"kael": {"trait": "kael", "lock_ticks": KAEL_LOCK_TICKS, "icd": KAEL_ICD_TICKS},
	"orion": {"trait": "orion", "slow_mult": ORION_SLOW_MULT, "slow_ticks": ORION_SLOW_TICKS,
			"windup_extra": ORION_WINDUP_EXTRA_TICKS},
}


static func is_active() -> bool:
	if force_active != null:
		return bool(force_active)
	return ENABLED and Settings.action_battles()


static func row(hero_id: String) -> Dictionary:
	return ROWS.get(hero_id, {})