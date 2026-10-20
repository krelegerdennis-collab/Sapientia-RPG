extends CanvasLayer
## SoM-proef HUD: HP/MP van Dax linksboven, Ring-knop (pauzemenu) naast MENU, korte meldingen.
## PLACEHOLDER-opmaak (balkjes in code getekend).

const SomData := preload("res://scripts/data/som_data.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const THEME := preload("res://assets/theme.tres")
const SomFx := preload("res://scripts/som/som_fx.gd")

var arena: Node
var root: Control
var bars: Control
var ring_button: Button
var switch_button: Button
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
	bars.size = Vector2(80, 64)
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
	switch_button = UiMenu.button(SomData.TXT_SWITCH)
	switch_button.name = "SwitchButton"
	switch_button.focus_mode = Control.FOCUS_NONE
	switch_button.custom_minimum_size = Vector2(38, 14)
	root.add_child(switch_button)
	switch_button.pressed.connect(func() -> void:
		if arena.active():
			arena.switch_hero())
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
	switch_button.reset_size()
	switch_button.position = Vector2(ring_button.position.x - 4.0 - switch_button.size.x, 2.0)
	toast_label.position = Vector2(80, 24)
	toast_label.size = Vector2(vs.x - 160, 30)


func _process(delta: float) -> void:
	bars.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_label.text = ""


func toast(text: String) -> void:
	toast_label.text = text
	_toast_t = 2.2


## Eén vak per partylid (hud_frame.png 72x20 van RPG ART, anders getekend): naam + HP, HP-balk;
## de bestuurde held geel gemarkeerd + zijn wapenmeter.
func _draw_bars() -> void:
	if GameState.party.is_empty() or arena == null:
		return
	var f: Font = THEME.default_font if THEME.default_font else ThemeDB.fallback_font
	var frame: Texture2D = SomFx.tex(SomData.UI_HUD_FRAME)
	var y := 0.0
	for h in GameState.party:
		var id := str(h.get("id", ""))
		var act: bool = id == arena.active_id
		var ko := int(h["hp"]) <= 0
		if frame:
			bars.draw_texture(frame, Vector2(0, y), Color(1, 0.9, 0.45) if act else Color(0.8, 0.8, 0.85, 0.9))
		else:
			bars.draw_rect(Rect2(0, y, 72, 20), Color(0, 0, 0, 0.65))
			if act:
				bars.draw_rect(Rect2(0, y, 72, 20), Color(1, 0.85, 0.3), false, 1.0)
		var col := Color(0.6, 0.6, 0.65) if ko else (Color(1, 0.95, 0.6) if act else Color(1, 1, 1))
		bars.draw_string(f, Vector2(4, y + 9), "%s %d/%d" % [h["name"], int(h["hp"]), int(h["max_hp"])], HORIZONTAL_ALIGNMENT_LEFT, 66, 8, col)
		var r := float(h["hp"]) / maxf(1.0, float(h["max_hp"]))
		bars.draw_rect(Rect2(4, y + 12, 64, 2), Color(0.2, 0.05, 0.05))
		bars.draw_rect(Rect2(4, y + 12, 64.0 * r, 2), Color(0.3, 1, 0.4) if r > 0.25 else Color(1, 0.3, 0.3))
		if act:
			var c: float = arena.charge
			bars.draw_rect(Rect2(4, y + 15, 64.0 * c, 2), Color(0.3, 0.9, 1.0) if c >= 1.0 else Color(1.0, 0.8, 0.2))
		y += 21.0
