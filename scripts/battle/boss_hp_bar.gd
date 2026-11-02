extends Control
## Demo-fix 3: HP-balk van de baas (Golem), rechtsboven onder de strook. Leest elk frame de HP van de
## gevolgde combatant (geen eigen administratie). Pixelfont op het 10-px raster (font_size 10).

const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const W := 96.0
const BAR_H := 4.0
const FONT_SIZE := 10

var target: Dictionary = {}
var name_label: Label
var _shown_hp := -1


func setup(t: Dictionary) -> void:
	target = t
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", FONT_SIZE)
	name_label.add_theme_color_override("font_color", UiStyleC.TEXT)
	name_label.text = str(t.get("name", "Boss"))
	name_label.position = Vector2.ZERO
	name_label.size = Vector2(W, 10)
	add_child(name_label)
	size = Vector2(W, 12 + BAR_H)


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
	var r := Rect2(0, 12, W, BAR_H)
	draw_rect(r.grow(1.0), UiStyleC.INK)
	draw_rect(r, Color(0.25, 0.08, 0.1))
	var fill := r
	fill.size.x = roundf(W * ratio())
	draw_rect(fill, Color(0.86, 0.2, 0.3))
