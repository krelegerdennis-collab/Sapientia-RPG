extends CanvasLayer
## Autoload "Transition": flits- en fade-effecten tussen scènes.
##   await Transition.encounter_out()   (flits + naar zwart, begin gevecht)
##   await Transition.fade_out()        (naar zwart)
##   await Transition.fade_in()         (van zwart naar beeld)
##   await Transition.flash(Color.WHITE, 0.6)   (v0.11: verblindende flits die wegebt)

var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, 0)
	add_child(_rect)


func encounter_out() -> void:
	# Twee keer wit flitsen (zoals op de SNES), daarna naar zwart.
	for i in 2:
		_rect.color = Color(1, 1, 1, 0.9)
		await get_tree().create_timer(0.06).timeout
		_rect.color = Color(1, 1, 1, 0)
		await get_tree().create_timer(0.06).timeout
	await _fade_to(Color(0, 0, 0, 1), 0.3)


func fade_out(duration := 0.3) -> void:
	await _fade_to(Color(0, 0, 0, 1), duration)


func fade_in(duration := 0.3) -> void:
	await _fade_to(Color(0, 0, 0, 0), duration)


func _fade_to(target: Color, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color", target, duration)
	await tween.finished


func flash(color: Color, duration := 0.6) -> void:
	_rect.color = Color(color, 1.0)
	await get_tree().create_timer(0.06).timeout
	await _fade_to(Color(color, 0.0), duration)
	_rect.color = Color(0, 0, 0, 0)
