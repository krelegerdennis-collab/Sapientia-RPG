class_name TelegraphAttack
extends RefCounted
## Eén vijandaanval op TelegraphState + vastgezette TelegraphShape (Combat T4a).
## Geen nodes, geen RNG. Treffer alleen op de tick waar de fase ACTIVE begint (`phase_changed`).

const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")

var _state := TelegraphState.new()
var _shape: TelegraphShape
var _attack_id: String = ""
var _origin: Vector2i = Vector2i.ZERO
var _dir: Vector2i = Vector2i.ZERO
var _shape_data: Dictionary = {}


func _init() -> void:
	_shape = TelegraphShape.make_circle(Vector2i.ZERO, 1)


## Zet fasen uit aanvalsdata + cooldown (ms, uit SomActionAttacks.cooldown_ms).
func configure(def: Dictionary, cooldown_ms: int) -> void:
	_attack_id = str(def.get("id", ""))
	_shape_data = _shape_params(def)
	_state.set_phase_ms(int(def.get("windup_ms", 0)), int(def.get("active_ms", 0)), int(def.get("recovery_ms", 0)), cooldown_ms)


func valid() -> bool:
	return _state.valid


func can_start() -> bool:
	return _state.can_start


func is_busy() -> bool:
	return _state.state != TelegraphState.State.IDLE


func in_windup() -> bool:
	return _state.state == TelegraphState.State.WINDUP


func in_cooldown() -> bool:
	return _state.state == TelegraphState.State.COOLDOWN


func state() -> int:
	return _state.state


func ticks_left_in_phase() -> int:
	return _state.ticks_left


## Origin en richting vastgezet bij start (WINDUP); shape gebouwd met from_data.
func start(origin: Vector2i, direction: Vector2i, shape_id: String) -> bool:
	if not _state.start():
		return false
	_origin = origin
	_dir = direction
	_shape = TelegraphShape.from_data(shape_id, _origin, _dir, _shape_data)
	return true


func tick() -> void:
	_state.tick()


## true op precies de eerste tick van ACTIVE (en geldige vorm).
func entered_active_this_tick() -> bool:
	return _state.phase_changed and _state.entered_state == TelegraphState.State.ACTIVE


func shape() -> TelegraphShape:
	return _shape


func locked_origin() -> Vector2i:
	return _origin


func locked_dir() -> Vector2i:
	return _dir


func attack_id() -> String:
	return _attack_id


## Deterministische treffer op pixelpositie (geen float in de beslissing).
func hits_point_i(point: Vector2i) -> bool:
	return _shape.valid and _shape.contains_i(point)


func cancel() -> bool:
	return _state.cancel()


func interrupt() -> bool:
	return _state.interrupt()


static func _shape_params(def: Dictionary) -> Dictionary:
	var out := {}
	for k in ["reach", "width", "angle", "inner"]:
		if def.has(k):
			out[k] = int(def[k])
	return out
