class_name WorldWarperWarpView
extends Control
## Twee stappen: eerst een wereld, daarna een bestemming.
## Zonder anker in de groep ww_anchor_warp vult de view de ouder
## (CanvasLayer in een test). Geen shader, geen eigen art.

signal warp_requested(wm_id: String, place_id: String)
signal warp_closed

const Destinations := preload("res://world_warper/warp/destinations.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")

const ANCHOR_GROUP := "ww_anchor_warp"
const VIEW_SIZE := Vector2(384, 216)
const RIJ_HOOG := 40

## TODO(design): stap 1 heeft geen afgesproken titel.
const TITEL_WERELDEN := "Kies een wereld"
const TITEL_BESTEMMING := "Kies een bestemming"
const LABEL_DICHT := "Vergrendeld"
const LABEL_TERUG := "Terug"
const LABEL_REIS := "Reis"
const LABEL_PLAATSHOUDER := "PLACEHOLDER"

const STEP_WORLDS := 0
const STEP_PLACES := 1

## Vlakke panelen. Tekstkleur komt uit UiStyle; de vulling blijft paars.
const COLOR_PANEL := Color("3d2158")
const COLOR_BUTTON := Color("5c3484")
const COLOR_SELECTED := Color("7344a3")
const COLOR_LOCKED := Color("2c1a40")
const COLOR_SLOT := Color("241433")
const COLOR_BORDER := Color("8d6bb0")

var _step := STEP_WORLDS
var _wm_id := ""
var _place_id := ""
var _opened := false
var _built := false

var _title: Label
var _rows: VBoxContainer
var _back: Button
var _travel: Button


func _ready() -> void:
	_ensure_ui()
	if not _opened:
		visible = false
	_place_at_anchor()
	call_deferred("_place_at_anchor")


func open() -> void:
	_opened = true
	_ensure_ui()
	_step = STEP_WORLDS
	_wm_id = ""
	_place_id = ""
	visible = true
	_place_at_anchor()
	_show_step()


func close() -> void:
	_opened = false
	visible = false
	warp_closed.emit()


func _place_at_anchor() -> void:
	if not is_inside_tree():
		return
	var nodes := get_tree().get_nodes_in_group(ANCHOR_GROUP)
	if nodes.is_empty():
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var anchor: Node = nodes[0]
	if anchor == self or not (anchor is Control or anchor is Node2D):
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	# Eerste node in de groep. Een Control-anker deelt het UI-vlak.
	# TODO(design): een Node2D-anker staat in wereldpixels; dat valt alleen
	# samen met dit scherm als die node in dezelfde canvas zit.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	if anchor is Control:
		var box := anchor as Control
		global_position = box.global_position
		size = box.size if box.size.x >= 32.0 and box.size.y >= 32.0 else VIEW_SIZE
	else:
		global_position = (anchor as Node2D).global_position
		size = VIEW_SIZE


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = VIEW_SIZE
	var thema := Theme.new()
	thema.default_font = FONT
	thema.default_font_size = 10
	thema.set_color("font_color", "Label", UiStyle.TEXT)
	thema.set_color("font_shadow_color", "Label", UiStyle.SHADOW)
	thema.set_constant("shadow_offset_x", "Label", 1)
	thema.set_constant("shadow_offset_y", "Label", 1)
	thema.set_color("font_color", "Button", UiStyle.TEXT)
	thema.set_color("font_hover_color", "Button", UiStyle.TEXT)
	thema.set_color("font_pressed_color", "Button", UiStyle.HILITE_HOT)
	thema.set_color("font_focus_color", "Button", UiStyle.TEXT)
	thema.set_color("font_disabled_color", "Button", UiStyle.TEXT_OFF)
	theme = thema

	var achtergrond := Panel.new()
	achtergrond.name = "Achtergrond"
	achtergrond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	achtergrond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	achtergrond.add_theme_stylebox_override("panel", _flat(COLOR_PANEL))
	add_child(achtergrond)

	var marge := MarginContainer.new()
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marge.add_theme_constant_override("margin_left", 6)
	marge.add_theme_constant_override("margin_top", 6)
	marge.add_theme_constant_override("margin_right", 6)
	marge.add_theme_constant_override("margin_bottom", 6)
	add_child(marge)

	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 4)
	marge.add_child(kolom)

	_title = Label.new()
	_title.name = "Titel"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiStyle.TEXT)
	kolom.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.name = "Rijen"
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	kolom.add_child(_rows)

	var balk := HBoxContainer.new()
	balk.add_theme_constant_override("separation", 8)
	kolom.add_child(balk)

	_back = _command_button(LABEL_TERUG, "Terug")
	_back.pressed.connect(_on_back)
	balk.add_child(_back)

	_travel = _command_button(LABEL_REIS, "Reis")
	_travel.pressed.connect(_on_travel)
	balk.add_child(_travel)


func _show_step() -> void:
	_title.text = TITEL_BESTEMMING if _step == STEP_PLACES else TITEL_WERELDEN
	for kind in _rows.get_children():
		_rows.remove_child(kind)
		kind.queue_free()
	var flags := _story_flags()
	if _step == STEP_WORLDS:
		for wereld in Destinations.worlds():
			var wm_id := str(wereld.get("id", ""))
			var dicht := not Destinations.is_world_open(wm_id, flags)
			_add_row(wm_id, str(wereld.get("label", "")), dicht, false, _on_world_pressed.bind(wm_id))
	else:
		for place in Destinations.places(_wm_id):
			var place_id := str(place.get("id", ""))
			_add_row(place_id, str(place.get("label", "")), false, place_id == _place_id, _on_place_pressed.bind(place_id))
	var gekozen := Destinations.resolve(_wm_id, _place_id, flags)
	_travel.disabled = _step != STEP_PLACES or gekozen.is_empty()


func _add_row(row_id: String, naam: String, dicht: bool, gekozen: bool, on_press: Callable) -> void:
	var knop := Button.new()
	knop.name = "Rij_%s" % row_id
	knop.text = ""
	knop.disabled = dicht
	knop.focus_mode = Control.FOCUS_NONE if dicht else Control.FOCUS_ALL
	knop.custom_minimum_size = Vector2(0, RIJ_HOOG)
	knop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	knop.clip_contents = true
	var vulling := COLOR_LOCKED if dicht else (COLOR_SELECTED if gekozen else COLOR_BUTTON)
	_paint(knop, vulling)
	knop.pressed.connect(on_press)
	_rows.add_child(knop)

	var rij := HBoxContainer.new()
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knop.add_child(rij)
	rij.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rij.offset_left = 4
	rij.offset_top = 4
	rij.offset_right = -4
	rij.offset_bottom = -4
	rij.add_theme_constant_override("separation", 6)

	var vak := PanelContainer.new()
	vak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vak.custom_minimum_size = Vector2(78, 24)
	vak.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vak.add_theme_stylebox_override("panel", _flat(COLOR_SLOT))
	rij.add_child(vak)

	var icoon := Label.new()
	icoon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icoon.text = LABEL_PLAATSHOUDER
	icoon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icoon.add_theme_color_override("font_color", UiStyle.TEXT_DIM if not dicht else UiStyle.TEXT_OFF)
	vak.add_child(icoon)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = naam
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiStyle.TEXT_DIM if dicht else UiStyle.TEXT)
	rij.add_child(label)

	if dicht:
		var slot := Label.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.text = LABEL_DICHT
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_color_override("font_color", UiStyle.TEXT_OFF)
		rij.add_child(slot)


func _command_button(tekst: String, node_naam: String) -> Button:
	var knop := Button.new()
	knop.name = node_naam
	knop.text = tekst
	knop.custom_minimum_size = Vector2(0, RIJ_HOOG)
	knop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	knop.focus_mode = Control.FOCUS_ALL
	_paint(knop, COLOR_BUTTON)
	return knop


func _on_world_pressed(wm_id: String) -> void:
	if not Destinations.is_world_open(wm_id, _story_flags()):
		return
	_wm_id = wm_id
	_place_id = ""
	_step = STEP_PLACES
	call_deferred("_show_step")


func _on_place_pressed(place_id: String) -> void:
	_place_id = place_id
	call_deferred("_show_step")


## TODO(design): Terug op stap 1 sluit de view. Op stap 2 keert hij terug naar de werelden.
func _on_back() -> void:
	if _step == STEP_PLACES:
		_step = STEP_WORLDS
		_place_id = ""
		_show_step()
		return
	close()


func _on_travel() -> void:
	var gekozen := Destinations.resolve(_wm_id, _place_id, _story_flags())
	if gekozen.is_empty():
		return
	# change_map stopt meteen tijdens een gevecht of een lopende wissel.
	if GameState.changing_map or GameState.in_battle:
		return
	var path := str(gekozen.get("path", ""))
	var spawn := str(gekozen.get("spawn", ""))
	GameState.change_map(path, spawn)
	warp_requested.emit(_wm_id, _place_id)


func _story_flags() -> Dictionary:
	return GameState.story_flags


func _paint(knop: Button, vulling: Color) -> void:
	knop.add_theme_stylebox_override("normal", _flat(vulling))
	knop.add_theme_stylebox_override("hover", _flat(vulling))
	knop.add_theme_stylebox_override("pressed", _flat(vulling))
	knop.add_theme_stylebox_override("focus", _flat(vulling))
	knop.add_theme_stylebox_override("disabled", _flat(COLOR_LOCKED))


func _flat(vulling: Color) -> StyleBoxFlat:
	var vlak := StyleBoxFlat.new()
	vlak.bg_color = vulling
	vlak.border_color = COLOR_BORDER
	vlak.set_border_width_all(1)
	vlak.set_corner_radius_all(0)
	vlak.anti_aliasing = false
	vlak.content_margin_left = 4
	vlak.content_margin_right = 4
	vlak.content_margin_top = 2
	vlak.content_margin_bottom = 2
	vlak.shadow_size = 0
	return vlak
