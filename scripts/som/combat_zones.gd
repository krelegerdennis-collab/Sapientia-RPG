class_name CombatZones
extends RefCounted
## Grondzones (Combat T4b, Inktplas). Host-tick, deterministisch; gast spiegelt snapshot.
## zones[{id, shape, origin, r, ticks_left, owner_idx, atk, dot_power, slow_mult, age}]

const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")

const MAX_PER_OWNER := 2
const MAX_ARENA := 6
const MAX_TICKS := 120
const DOT_INTERVAL := 30
const SHAPE_CIRCLE := 1

var _zones: Array = []
var _next_id := 1


func clear_all() -> void:
	_zones.clear()


func count() -> int:
	return _zones.size()


func count_for_owner(owner_idx: int) -> int:
	var n := 0
	for z in _zones:
		if int(z.get("owner_idx", -1)) == owner_idx:
			n += 1
	return n


func clear_owner(owner_idx: int) -> void:
	var keep: Array = []
	for z in _zones:
		if int(z.get("owner_idx", -1)) != owner_idx:
			keep.append(z)
	_zones = keep


## Spawn cirkel-zone; false als limieten vol zijn.
func try_spawn(
	owner_idx: int,
	origin: Vector2i,
	radius_px: int,
	ticks: int,
	atk: int,
	dot_power: float,
	slow_mult: float,
) -> bool:
	if owner_idx < 0 or radius_px <= 0:
		return false
	if count_for_owner(owner_idx) >= MAX_PER_OWNER or count() >= MAX_ARENA:
		return false
	var dur := clampi(ticks, 1, MAX_TICKS)
	_zones.append({
		"id": _next_id,
		"shape": "circle",
		"origin": origin,
		"r": radius_px,
		"ticks_left": dur,
		"owner_idx": owner_idx,
		"atk": atk,
		"dot_power": dot_power,
		"slow_mult": slow_mult,
		"age": 0,
	})
	_next_id += 1
	return true


func contains_point(px: Vector2i, zone: Dictionary) -> bool:
	var sh := TelegraphShape.make_circle(zone.get("origin", Vector2i.ZERO), int(zone.get("r", 0)))
	return sh.valid and sh.contains_i(px)


func slow_mult_at(px: Vector2i) -> float:
	var best := 1.0
	for z in _zones:
		if contains_point(px, z):
			best = minf(best, float(z.get("slow_mult", 1.0)))
	return best


## Eén sim-tick: verlaag levensduur; geef zones die deze tick DoT ticken (age % 30 == 0, age > 0).
func tick() -> Array:
	var dots: Array = []
	var alive: Array = []
	for z in _zones:
		z["age"] = int(z.get("age", 0)) + 1
		var age: int = int(z["age"])
		var left: int = int(z.get("ticks_left", 0))
		if age > 0 and age % DOT_INTERVAL == 0 and left > 1:
			dots.append(z)
		z["ticks_left"] = left - 1
		if int(z["ticks_left"]) > 0:
			alive.append(z)
	_zones = alive
	return dots


func zones_for_draw() -> Array:
	return _zones.duplicate(true)


func wire_rows() -> Array:
	var out: Array = []
	for z in _zones:
		out.append({
			"owner_idx": int(z.get("owner_idx", 0)),
			"ox": int(z.get("origin", Vector2i.ZERO).x),
			"oy": int(z.get("origin", Vector2i.ZERO).y),
			"r": int(z.get("r", 0)),
			"ticks_left": int(z.get("ticks_left", 0)),
			"shape": SHAPE_CIRCLE,
		})
	return out


func apply_wire_rows(rows: Array) -> void:
	_zones.clear()
	for row in rows:
		var origin := Vector2i(int(row.get("ox", 0)), int(row.get("oy", 0)))
		_zones.append({
			"id": _next_id,
			"shape": "circle",
			"origin": origin,
			"r": int(row.get("r", 0)),
			"ticks_left": int(row.get("ticks_left", 0)),
			"owner_idx": int(row.get("owner_idx", 0)),
			"atk": 0,
			"dot_power": 0.0,
			"slow_mult": 0.6,
			"age": 0,
		})
		_next_id += 1
