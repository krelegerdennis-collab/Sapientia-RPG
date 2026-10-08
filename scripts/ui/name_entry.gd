extends Control
## v0.10 Naam kiezen: 'Hoe heet je?' met een LineEdit (op Android opent het
## schermtoetsenbord), voorgevuld met 'Dennis', max. 10 tekens, en een OK-knop.
## Leeg = 'Dennis'. Daarna begint het nieuwe spel in Wilgendal.

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")

var edit: LineEdit
var ok_button: Button
var _done := false


func _ready() -> void:
	theme = load(UiMenu.THEME_PATH)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0b0b0d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# bovenin, zodat het schermtoetsenbord (onderste helft) niets bedekt
	var box := UiMenu.panel(UiStyleC.MAGENTA_DIM)
	box.position = Vector2(0, 22)
	add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	col.add_child(UiMenu.label("Hoe heet je?", UiStyleC.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	edit = LineEdit.new()
	edit.text = GameState.DEFAULT_NAME
	edit.max_length = GameState.NAME_MAX
	edit.virtual_keyboard_enabled = true
	edit.select_all_on_focus = true
	edit.custom_minimum_size = Vector2(110, 16)
	edit.placeholder_text = GameState.DEFAULT_NAME
	edit.add_theme_stylebox_override("normal", UiMenu.window_style(UiStyleC.BORDER_DARK, 1.0))
	edit.add_theme_stylebox_override("focus", UiMenu.window_style(UiStyleC.MAGENTA, 1.0))
	for sb in ["normal", "focus"]:
		var s: StyleBoxFlat = edit.get_theme_stylebox(sb)
		s.content_margin_top = 2
		s.content_margin_bottom = 2
	edit.add_theme_color_override("font_color", UiStyleC.TEXT)
	edit.add_theme_color_override("caret_color", UiStyleC.MAGENTA)
	edit.add_theme_color_override("selection_color", Color(UiStyleC.MAGENTA_DIM, 0.8))
	row.add_child(edit)
	ok_button = UiMenu.button("OK")
	ok_button.custom_minimum_size = Vector2(36, 16)
	row.add_child(ok_button)
	col.add_child(UiMenu.label("max. %d tekens" % GameState.NAME_MAX, UiStyleC.TEXT_DIM))
	edit.text_submitted.connect(func(_t): confirm())
	ok_button.pressed.connect(confirm)
	resized.connect(_center.bind(box))
	_center.call_deferred(box)
	edit.grab_focus.call_deferred()
	Transition.fade_in()


func _center(box: Control) -> void:
	box.reset_size()
	box.position.x = roundf((size.x - box.size.x) / 2.0)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("cancel") and not edit.has_focus():
		set_process(false)
		get_tree().change_scene_to_file(GameState.TITLE_SCENE)
		return
	UiMenu.pad_nav(get_viewport())


## De naam zoals hij gebruikt wordt (leeg = Dennis).
func chosen_name() -> String:
	return GameState.clean_name(edit.text)


func confirm() -> void:
	if _done:
		return
	_done = true
	DisplayServer.virtual_keyboard_hide()
	GameState.start_new_game(edit.text)
