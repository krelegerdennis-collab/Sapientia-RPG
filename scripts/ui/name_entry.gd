extends Control
## v0.10 Naam kiezen: 'Hoe heet je?' met een LineEdit, voorgevuld met 'Dennis',
## max. 10 tekens, en een OK-knop. Leeg = 'Dennis'.
## De eerste toets vervangt Dennis (alles geselecteerd). Op de telefoon (web en Android)
## opent een tik het schermtoetsenbord. Daarna begint het nieuwe spel in Wilgendal.

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")

var edit: LineEdit
var ok_button: Button
var _done := false
## Zolang de speler nog niets getypt heeft, vervangt de eerste letter 'Dennis'.
var _pristine := true


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
	edit.editable = true
	edit.virtual_keyboard_enabled = true
	edit.select_all_on_focus = true
	edit.caret_blink = true
	edit.custom_minimum_size = Vector2(140, 32)
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
	ok_button.custom_minimum_size = Vector2(44, 32)
	row.add_child(ok_button)
	col.add_child(UiMenu.label("Tik het vak aan en typ je eigen naam.", UiStyleC.TEXT_DIM))
	col.add_child(UiMenu.label("max. %d tekens, leeg = %s" % [GameState.NAME_MAX, GameState.DEFAULT_NAME], UiStyleC.TEXT_DIM))
	edit.text_submitted.connect(func(_t): confirm())
	edit.text_changed.connect(func(_t): _sync_web_name())
	edit.gui_input.connect(_on_edit_input)
	edit.focus_entered.connect(_show_keyboard)
	ok_button.pressed.connect(confirm)
	resized.connect(_center.bind(box))
	_center.call_deferred(box)
	edit.grab_focus.call_deferred()
	_select_default.call_deferred()
	_set_web_name_mode(true)
	Transition.fade_in()


func _exit_tree() -> void:
	_set_web_name_mode(false)


## Een tik (ook als het vak al focus heeft) opent het toetsenbord. Zonder dit blijft
## 'Dennis' staan op een telefoon: de browser weigert een toetsenbord zonder tik.
func _select_default() -> void:
	if edit != null and _pristine:
		edit.select_all()


func _on_edit_input(event: InputEvent) -> void:
	var press := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		press = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
	elif _pristine and event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.unicode >= 32:
			edit.text = ""
			edit.caret_column = 0
			_pristine = false
	if press:
		_show_keyboard()
		if _pristine:
			edit.select_all.call_deferred()


func _show_keyboard() -> void:
	var text := edit.text
	DisplayServer.virtual_keyboard_show(text, edit.get_global_rect(), DisplayServer.KEYBOARD_TYPE_DEFAULT, GameState.NAME_MAX, 0, text.length())
	_sync_web_name()


func _sync_web_name() -> void:
	_set_web_name_mode(true)


func _set_web_name_mode(on: bool) -> void:
	if not OS.has_feature("web") or edit == null:
		return
	var text := edit.text.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("window.sapientiaWantName=%s;window.sapientiaNameText='%s';" % ["true" if on else "false", text], true)


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
	_set_web_name_mode(false)
	DisplayServer.virtual_keyboard_hide()
	GameState.start_new_game(edit.text)
