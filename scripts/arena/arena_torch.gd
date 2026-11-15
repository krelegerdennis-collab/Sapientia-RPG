extends Sprite2D
## Fakkel: 4 frames, 125 ms, loop. Geen load() in _process.

const STEP := 0.125

var _t := 0.0


func _process(delta: float) -> void:
	if hframes < 2:
		return
	_t += delta
	if _t < STEP:
		return
	var steps := int(_t / STEP)
	_t -= float(steps) * STEP
	frame = (frame + steps) % hframes
