extends CanvasLayer
## SoM-proef HUD: HP/MP van Dax linksboven, Ring-knop (pauzemenu) naast MENU, korte meldingen.
## PLACEHOLDER-opmaak (balkjes in code getekend).

const SomData := preload("res://scripts/data/som_data.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const THEME := preload("res://assets/theme.tres")

var arena: Node
var root: Control
var bars: Control
var ring_button: Button
var toast_label: Label
var _toast_t := 0.0


func _ready() -> void:
	layer = 11
	name = "SomHud"
	root = Control.new()
	root.theme = THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	bars = Control.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.position = Vector2(4, 4)
	bars.size = Vector2(80, 20)
	bars.draw.connect(_draw_bars)
	root.add_child(bars)
	ring_button = UiMenu.button(SomData.TXT_RING)
	ring_button.name = "RingButton"
	ring_button.focus_mode = Control.FOCUS_NONE
	ring_button.custom_minimum_size = Vector2(38, 14)
	root.add_child(ring_button)
	ring_button.pressed.connect(func() -> void:
		if arena.active():
			arena.open_ring())
	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 8)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 2)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)
	_place()


func _place() -> void:
	var vs := root.get_viewport_rect().size
	ring_button.reset_size()
	ring_button.position = Vector2(vs.x - 4.0 - 38.0 - 4.0 - ring_button.size.x, 2.0)
	toast_label.position = Vector2(40, 24)
	toast_label.size = Vector2(vs.x - 80, 30)


func _process(delta: float) -> void:
	bars.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_label.text = ""


func toast(text: String) -> void:
	toast_label.text = text
	_toast_t = 2.2


func _draw_bars() -> void:
	if GameState.party.is_empty():
		return
	var h: Dictionary = GameState.party[0]
	var f: Font = THEME.default_font if THEME.default_font else ThemeDB.fallback_font
	bars.draw_rect(Rect2(0, 0, 70, 18), Color(0, 0, 0, 0.6))
	bars.draw_string(f, Vector2(2, 7), "%s  %d/%d" % [h["name"], int(h["hp"]), int(h["max_hp"])], HORIZONTAL_ALIGNMENT_LEFT, 68, 8)
	var r := float(h["hp"]) / maxf(1.0, float(h["max_hp"]))
	bars.draw_rect(Rect2(2, 10, 66, 3), Color(0.2, 0.05, 0.05))
	bars.draw_rect(Rect2(2, 10, 66.0 * r, 3), Color(0.3, 1, 0.4) if r > 0.25 else Color(1, 0.3, 0.3))
	var c: float = arena.charge if arena else 1.0
	bars.draw_rect(Rect2(2, 14, 66, 2), Color(0.1, 0.1, 0.15))
	bars.draw_rect(Rect2(2, 14, 66.0 * c, 2), Color(0.3, 0.9, 1.0) if c >= 1.0 else Color(1.0, 0.8, 0.2))
