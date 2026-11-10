class_name SomShake
extends Node
## Client-only screenshake op Camera2D.offset (deterministisch, geen randf).

const SomFeelData := preload("res://scripts/data/som_feel_data.gd")

var _cam: Camera2D
var _kind := ""
var _remaining_ticks := 0
var _total_ticks := 0
var _px := 0
var _pattern_i := 0
var _acc := 0.0


func setup(cam: Camera2D) -> void:
	_cam = cam


func kick(kind: String) -> void:
	if not SomFeelData.ENABLED or _cam == null or kind == "":
		return
	var incoming := SomFeelData.shake_strength(kind)
	if _remaining_ticks > 0 and SomFeelData.shake_strength(_kind) >= incoming:
		return
	_kind = kind
	_px = SomFeelData.shake_px(kind)
	_total_ticks = SomFeelData.shake_ticks(kind)
	_remaining_ticks = _total_ticks
	_pattern_i = 0
	_acc = 0.0


func stop() -> void:
	_remaining_ticks = 0
	_total_ticks = 0
	_kind = ""
	_pattern_i = 0
	_acc = 0.0
	if _cam != null:
		_cam.offset = Vector2.ZERO


func offset_now() -> Vector2:
	return _cam.offset if _cam != null else Vector2.ZERO


func busy() -> bool:
	return _remaining_ticks > 0


## Tests: één visuele stap (60 Hz).
func test_tick() -> void:
	_process(SomFeelData.TICK_DT)


func _exit_tree() -> void:
	stop()


func _process(delta: float) -> void:
	if not SomFeelData.ENABLED or _cam == null or _remaining_ticks <= 0:
		return
	_acc += delta
	while _acc >= SomFeelData.TICK_DT and _remaining_ticks > 0:
		_acc -= SomFeelData.TICK_DT
		_apply_offset()
		_remaining_ticks -= 1
		_pattern_i += 1
	if _remaining_ticks <= 0:
		stop()


func _apply_offset() -> void:
	var pat: Vector2i = SomFeelData.PATTERN[_pattern_i % SomFeelData.PATTERN.size()]
	var falloff := float(_remaining_ticks) / float(maxi(1, _total_ticks))
	var amp := float(_px) * falloff
	_cam.offset = Vector2(float(pat.x) * amp, float(pat.y) * amp)
