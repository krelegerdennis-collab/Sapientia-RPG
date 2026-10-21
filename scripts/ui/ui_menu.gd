extends RefCounted
## v0.10 Hulpjes voor eenvoudige menuschermen (titel, naam, veldmenu, bestiarium) in de
## UI-stijl 'De Vergeten Bibliotheek': knoppen met een magenta '>' als ze gekozen zijn,
## donkere vensters, en besturing met toetsenbord, touch-joystick/A én tikken.
## (preload i.p.v. class_name, zodat het ook bij de allereerste import werkt)

## v0.14: menukleuren uit één bestand (menu_colors.gd), niet meer de neon van ui_style.gd
const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const THEME_PATH := "res://assets/theme.tres"


## v0.14: zacht venster (MenuColors): inkt-blauwgrijs, dunne rand, 1 px lichtere binnenrand
## bovenaan (geen harde neon). 'big' = het grote venster van een scherm (iets ruimer).
static func window_style(border := MenuColors.BORDER_DARK, alpha := MenuColors.WINDOW_ALPHA, big := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(MenuColors.WINDOW.r, MenuColors.WINDOW.g, MenuColors.WINDOW.b, alpha)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(6)
	# afgeronde hoekjes van 2 px (pixel-scherp: corner_detail 1 = schuine pixel)
	sb.set_corner_radius_all(3 if big else 2)
	sb.corner_detail = 2
	sb.anti_aliasing = false
	return sb


## v0.14: vak binnen een venster (portret, lijst, vraag): iets lichter, zonder harde rand.
static func inner_style(border := MenuColors.LINE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = MenuColors.WINDOW_INNER
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(4)
	sb.set_corner_radius_all(2)
	sb.corner_detail = 2
	sb.anti_aliasing = false
	return sb


static func panel(border := MenuColors.BORDER_DARK) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", window_style(border))
	return p


static func label(text: String, color := MenuColors.TEXT, size := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l


## Knop met '>' als hij focus heeft (en magenta tekst). Muis erover bewegen = focus.
static func button(text: String) -> Button:
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set_meta("label", text)
	b.text = "  " + text
	b.focus_entered.connect(func(): _mark(b, true))
	b.focus_exited.connect(func(): _mark(b, false))
	# muis bewogen boven de knop = focus (niet bij alleen 'verschijnen onder de cursor')
	b.gui_input.connect(func(e):
		if e is InputEventMouseMotion and e.relative.length() > 0.0 and not b.disabled and not b.has_focus():
			b.grab_focus())
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	return b


static func set_label(b: Button, text: String) -> void:
	b.set_meta("label", text)
	_mark(b, b.has_focus())


static func _mark(b: Button, on: bool) -> void:
	b.text = ("> " if on else "  ") + str(b.get_meta("label", ""))
	# gecentreerde knoppen (veldmenu): rechts even breed opvullen, zodat de tekst echt in het midden staat
	if b.alignment == HORIZONTAL_ALIGNMENT_CENTER:
		b.text += "  "
	var c := MenuColors.ACCENT if on else MenuColors.TEXT
	for k in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, c)


## Touch-joystick (move_*) en A (interact) laten werken in menu's. Toetsenbord-pijltjes en
## Enter/Spatie doet Godot zelf al (ui_up/ui_down/ui_accept), die slaan we hier over.
static func pad_nav(vp: Viewport) -> void:
	var f := vp.gui_get_focus_owner()
	if f == null or f is LineEdit:
		return
	if Input.is_action_just_pressed("move_up") and not Input.is_action_just_pressed("ui_up"):
		var n := f.find_prev_valid_focus()
		if n:
			n.grab_focus()
	elif Input.is_action_just_pressed("move_down") and not Input.is_action_just_pressed("ui_down"):
		var n := f.find_next_valid_focus()
		if n:
			n.grab_focus()
	elif Input.is_action_just_pressed("interact") and not Input.is_action_just_pressed("ui_accept"):
		if f is BaseButton and not f.disabled:
			f.pressed.emit()


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
