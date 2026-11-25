class_name SomFeelData
extends RefCounted
## F4 game feel: client-only schudden en schadekleuren (geen sim-impact).

## Alles uit = exact het oude gedrag (witte getallen, geen camera-offset).
const ENABLED := true

const TICK_DT := 1.0 / 60.0

## px, ticks per shake-soort.
const SHAKE: Dictionary = {
	"finisher": Vector2i(2, 6),
	"heavy1": Vector2i(2, 6),
	"heavy2": Vector2i(3, 8),
	"boss_slam": Vector2i(3, 10),
	"perfect": Vector2i(1, 4),
}

const PATTERN: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]

const COL_NORMAL := Color(1, 1, 1)
const COL_FINISHER := Color("FF8A3D")
## Alleen het finisher-schadegetal (keten stap 3); stagger/wankel blijft COL_FINISHER.
const COL_FINISHER_NUMBER := Color("FFD24A")
const SCALE_FINISHER_NUMBER := 1.3
const COL_HEAVY := Color("FFD24A")
const SCALE_HEAVY2 := 1.25

static func shake_px(kind: String) -> int:
	var v: Vector2i = SHAKE.get(kind, Vector2i.ZERO)
	return v.x


static func shake_ticks(kind: String) -> int:
	var v: Vector2i = SHAKE.get(kind, Vector2i.ZERO)
	return v.y


## Sterkte voor overschrijven: px * ticks (zelfde maat als in het ontwerp).
static func shake_strength(kind: String) -> int:
	return shake_px(kind) * shake_ticks(kind)
