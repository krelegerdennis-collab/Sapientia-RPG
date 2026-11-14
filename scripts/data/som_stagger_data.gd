class_name SomStaggerData
extends RefCounted
## F2 stagger-meter (Action): vulling, wankel, verval. Geen impact op Classic/turn-based.

const MAX_NORMAL := 100
const MAX_BOSS_UNIQUE := 160

const FILL_HIT1 := 8
const FILL_HIT2 := 10
const FILL_FINISHER := 22
const FILL_HEAVY_L1 := 30
const FILL_HEAVY_L2 := 45
const FILL_SPELL := 5
## F1 perfect-counter (+20); pas koppelen als F1 landt.
const FILL_PERFECT_COUNTER := 20

const DECAY_GRACE_TICKS := 60
const DECAY_EVERY_TICKS := 2

const WANKEL_TICKS := 90
const IMMUNE_TICKS := 180
const WANKEL_DAMAGE_MULT := 1.3

const KIND_NONE := -1
const KIND_HIT1 := 0
const KIND_HIT2 := 1
const KIND_FINISHER := 2
const KIND_HEAVY_L1 := 3
const KIND_HEAVY_L2 := 4
const KIND_SPELL := 5
const KIND_PERFECT_COUNTER := 6

const STAGGER_BAR_W := 20
const STAGGER_BAR_H := 2


static func fill_for_kind(kind: int) -> int:
	match kind:
		KIND_HIT1:
			return FILL_HIT1
		KIND_HIT2:
			return FILL_HIT2
		KIND_FINISHER:
			return FILL_FINISHER
		KIND_HEAVY_L1:
			return FILL_HEAVY_L1
		KIND_HEAVY_L2:
			return FILL_HEAVY_L2
		KIND_SPELL:
			return FILL_SPELL
		KIND_PERFECT_COUNTER:
			return FILL_PERFECT_COUNTER
		_:
			return 0


static func max_meter(data: Dictionary, m: Node) -> int:
	if bool(data.get("unique", false)):
		return MAX_BOSS_UNIQUE
	if m != null and bool(m.get("boss")):
		return MAX_BOSS_UNIQUE
	return MAX_NORMAL


static func in_wankel(e: Dictionary) -> bool:
	return int(e.get("stg_wankel", 0)) > 0


static func immune(e: Dictionary) -> bool:
	return int(e.get("stg_immune", 0)) > 0