extends Control
## Demo-fix 3: HP-balk van de baas (Golem), rechtsboven onder de strook. Leest elk frame de HP van de
## gevolgde combatant (geen eigen administratie). Pixelfont op het 10-px raster (font_size 10).

const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const MIN_W := 48.0
const BAR_H := 4.0
const FONT_SIZE := 10
const FONT_SIZE_MIN := 8
const NAME_GAP := 1.0
const BAR_PAD := 2.0

var target: Dictionary = {}
var name_label: Label
var _shown_hp := -1
var _full_name := ""


func setup(t: Dictionary) -> void:
	target = t
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_name = str(t.get("name", "Boss"))
	name_label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", FONT_SIZE)
	name_label.add_theme_color_override("font_color", UiStyleC.TEXT)
	name_label.text = _full_name
	name_label.clip_text = false
	name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.position = Vector2.ZERO
	add_child(name_label)
	relayout(MIN_W)


## Breedte tot max_w (rechts uitgelijnd in battle._place_boss_bar): volledige naam zoveel mogelijk
## op één regel; anders autowrap; font iets kleiner alleen als het echt niet past.
func relayout(max_w: float) -> void:
	max_w = maxf(MIN_W, max_w)
	var fs := FONT_SIZE
	var font := name_label.get_theme_font("font")
	while fs >= FONT_SIZE_MIN:
		name_label.add_theme_font_size_override("font_size", fs)
		var one_w := _measure_line(font, fs, _full_name)
		if one_w <= max_w + 0.5:
			name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			var bar_w := minf(max_w, maxf(MIN_W, ceilf(one_w + 1.0)))
			name_label.size = Vector2(bar_w, fs + 2.0)
			_apply_size(bar_w, name_label.size.y)
			return
		fs -= 1
	fs = FONT_SIZE_MIN
	name_label.add_theme_font_size_override("font_size", fs)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var wrapped := _measure_wrapped(font, fs, _full_name, max_w)
	var nh := maxf(float(fs) + 2.0, wrapped.y + 1.0)
	name_label.size = Vector2(max_w, nh)
	_apply_size(max_w, nh)


func _apply_size(bar_w: float, name_h: float) -> void:
	var bar_y := name_h + NAME_GAP
	size = Vector2(bar_w, bar_y + BAR_PAD + BAR_H)
	queue_redraw()


func _measure_line(font: Font, fs: int, text: String) -> float:
	if font == null:
		return float(text.length()) * 6.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _measure_wrapped(font: Font, fs: int, text: String, width: float) -> Vector2:
	if font == null:
		var lines := int(ceil(float(text.length()) * 6.0 / width))
		return Vector2(width, float(lines) * float(fs + 2))
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_RIGHT, -1, width, fs)


func ratio() -> float:
	if target.is_empty():
		return 0.0
	var mx := maxi(1, int(target["s"].get("max_hp", 1)))
	return clampf(float(target["s"]["hp"]) / float(mx), 0.0, 1.0)


func _process(_delta: float) -> void:
	if target.is_empty():
		return
	var hp := int(target["s"]["hp"])
	if hp != _shown_hp:
		_shown_hp = hp
		queue_redraw()


func _draw() -> void:
	var bar_y := name_label.size.y + NAME_GAP
	var r := Rect2(0, bar_y, size.x, BAR_H)
	draw_rect(r.grow(1.0), UiStyleC.INK)
	draw_rect(r, Color(0.25, 0.08, 0.1))
	var fill := r
	fill.size.x = roundf(size.x * ratio())
	draw_rect(fill, Color(0.86, 0.2, 0.3))
