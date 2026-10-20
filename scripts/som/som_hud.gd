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
	skin_button(ring_button, "ring")
	skin_button(switch_button, "swap")
	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 8)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 2)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)
	_place()


## Knop-art (38x14, normaal/ingedrukt) van RPG ART; de tekst zit in de art. Zonder art: tekstknop.
static func skin_button(b: Button, key: String) -> bool:
	var paths: Array = SomData.UI_BTN.get(key, [])
	if paths.size() < 2:
		return false
	var n := SomFx.tex(str(paths[0]))
	var p := SomFx.tex(str(paths[1]))
	if n == null or p == null:
		return false
	# groter touch-vak (SomData.TOP_BUTTON_SIZE), de 38x14-art gecentreerd erin (negatieve expand-marges)
	var pad: Vector2 = (SomData.TOP_BUTTON_SIZE - n.get_size()) / 2.0
	var sn := StyleBoxTexture.new()
	sn.texture = n
	var sp := StyleBoxTexture.new()
	sp.texture = p
	for sb in [sn, sp]:
		sb.expand_margin_left = -pad.x
		sb.expand_margin_right = -pad.x
		sb.expand_margin_top = -pad.y
		sb.expand_margin_bottom = -pad.y
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sn)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("hover_pressed", sp)
	b.tooltip_text = b.text
	b.text = ""
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.custom_minimum_size = SomData.TOP_BUTTON_SIZE
	b.size = SomData.TOP_BUTTON_SIZE
	b.set_meta("som_skin", key)
	return true


func _place() -> void:
	var vs := root.get_viewport_rect().size
	var tc: Control = arena.touch if arena != null else null
	if tc and tc.has_method("som_row_slot"):
		# één rij rechtsboven naast MENU: [RUN][Swap][Ring][MENU] (RUN zet touch_controls zelf neer)
		var rr: Rect2 = tc.som_row_slot(0)
		var sr: Rect2 = tc.som_row_slot(1)
		ring_button.position = tc.position + rr.position
		ring_button.size = rr.size
		switch_button.position = tc.position + sr.position
		switch_button.size = sr.size
	else:
		ring_button.reset_size()
		ring_button.position = Vector2(vs.x - 4.0 - 38.0 - 4.0 - ring_button.size.x, 2.0)
		switch_button.reset_size()
		switch_button.position = Vector2(ring_button.position.x - 4.0 - switch_button.size.x, 2.0)
	toast_label.position = Vector2(80, 24)
	toast_label.size = Vector2(vs.x - 160, 30)


func _process(delta: float) -> void:
	_place()
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
