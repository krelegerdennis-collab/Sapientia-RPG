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

## Partij-ids (game_data-helden).
const HERO_IDS: Array[String] = ["dennis", "lotte", "noor", "kael", "orion"]


static func is_active() -> bool:
	if force_active != null:
		return bool(force_active)
	return ENABLED and Settings.action_battles()