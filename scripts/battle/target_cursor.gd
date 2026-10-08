extends Control
## v0.13: met art van RPG ART (assets/ui/richtpijl.png = 24x12, 2 frames van 12x12 die
## om en om spelen = op-en-neer wippen). Zonder dat plaatje: het oude getekende pijltje.
## Doel-pijltje (v7: neon magenta met een donkere rand en een zachte gloed) dat boven een
## vijand of held zweeft.
## point_at(p) zet de punt van het pijltje op punt p; het pijltje wipt zacht op en neer.

## Op het 2x-raster van het gevechtsscherm getekend met halve pixels (21x15 fijne
## pixels): lichte rand linksboven, donkerder goud rechts, donkere omlijning.
const TIP := Vector2(5, 7)
const OUTLINE := Color(0.03, 0.02, 0.04)
const SHINE := Color("ffe4fc")
const LIGHT := Color("ff8af4")
const MID := Color("ff1ee6")
const DARK := Color("a0109a")

const ART := "res://assets/ui/richtpijl.png"
const ART_TIP := Vector2(6, 11)       # punt van het pijltje in een frame van 12x12
const ART_FRAME_TIME := 0.25

var _tip := Vector2.ZERO
var _art: Texture2D
var _t := 0.0
var frame := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ART):
		_art = load(ART)
	size = Vector2(12, 12) if _art else Vector2(11, 8)


func has_art() -> bool:
	return _art != null


func point_at(p: Vector2) -> void:
	_tip = p.round()
	_update_position()


## Waar de punt nu wijst (voor de autotest).
func tip() -> Vector2:
	return _tip


func _process(delta: float) -> void:
	if visible:
		if _art:
			_t += delta
			if _t >= ART_FRAME_TIME:
				_t -= ART_FRAME_TIME
				frame = 1 - frame
				queue_redraw()
		_update_position()


func _update_position() -> void:
	if _art:
		position = _tip - ART_TIP     # de art wipt zelf (2 frames)
		return
	var bob := roundf(sin(Time.get_ticks_msec() / 130.0) * 1.0 - 1.0)   # 0 .. -2 pixels
	position = _tip - TIP + Vector2(0, bob)


func _draw() -> void:
	if _art:
		draw_texture_rect_region(_art, Rect2(0, 0, 12, 12), Rect2(frame * 12, 0, 12, 12))
		return
	# gloed
	draw_colored_polygon(PackedVector2Array([Vector2(-1.5, -1.5), Vector2(11.5, -1.5), Vector2(5, 8.5)]),
			Color(1, 0.12, 0.9, 0.22))
	# 15 rijen fijne pixels; rij y is (2*hw+1) breed, punt op (10, 14) = TIP * 2
	for y in 15:
		var hw := int(round(10.0 * (1.0 - y / 14.0)))
		for x in range(-hw, hw + 1):
			var c: Color
			if y == 0 or absi(x) == hw:
				c = OUTLINE
			elif y == 1 or x == -hw + 1:
				c = SHINE
			elif x > hw * 0.3 or y >= 11:
				c = DARK
			elif y < 5:
				c = LIGHT
			else:
				c = MID
			draw_rect(Rect2(Vector2(10 + x, y) * 0.5, Vector2(0.5, 0.5)), c)
