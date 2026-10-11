class_name WorldWarperSavePoint
extends Control
## Savepunt van de World Warper. Paars placeholder-paneel, tik op Opslaan.
## Geen instance van scenes/book_point.tscn: die bevestigt via Dialog in het
## Engels (book_data.gd) en interact() eist een speler met get_tile() en facing.
## Dit paneel vraagt zelf en roept GameState.save_game aan.
##
## Anker: eerste Control of Node2D in de groep ww_anchor_save, deze node zelf
## niet. Zonder anker blijft het paneel op zijn eigen plek (past in 384x216).

signal save_requested

const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")

const ANCHOR_GROUP := "ww_anchor_save"
const PANEL_SIZE := Vector2(176, 128)
const RIJ_HOOG := 40
const PLACEHOLDER_TEKST := "PLACEHOLDER"

## TODO(design): de tegel en de kijkrichting van de speler zijn hier niet
## betrouwbaar af te leiden. NPC's hebben ook get_tile(), en er is geen vaste
## spelergroep. Tot die API er is: tegel (0, 0), kijkrichting (0, 1).
const SAVE_TILE := Vector2i(0, 0)
const SAVE_FACING := Vector2i(0, 1)

const COLOR_PANEL := Color("3d2158")
const COLOR_BUTTON := Color("5c3484")
const COLOR_SLOT := Color("241433")
const COLOR_BORDER := Color("8d6bb0")

var _built := false
var _asking := false
var _saving := false
var _idle: Control
var _ask: Control
var _status: Label


func _ready() -> void:
	_ensure_ui()
	_place_at_anchor()
	call_deferred("_place_at_anchor")


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = PANEL_SIZE
	if size.x < PANEL_SIZE.x or size.y < PANEL_SIZE.y:
		size = PANEL_SIZE
	var thema := Theme.new()
	thema.default_font = FONT
	thema.default_font_size = 10
	thema.set_color("font_color", "Label", UiStyle.TEXT)
	thema.set_color("font_shadow_color", "Label", UiStyle.SHADOW)
	thema.set_color("font_color", "Button", UiStyle.TEXT)
	thema.set_color("font_hover_color", "Button", UiStyle.TEXT)
	thema.set_color("font_pressed_color", "Button", UiStyle.HILITE_HOT)
	thema.set_color("font_focus_color", "Button", UiStyle.TEXT)
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
	kolom.add_theme_constant_override("separation", 0)
	marge.add_child(kolom)

	_idle = VBoxContainer.new()
	_idle.name = "Idle"
	_idle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_idle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_idle.add_theme_constant_override("separation", 4)
	kolom.add_child(_idle)

	var icoon := PanelContainer.new()
	icoon.name = "Icoon"
	icoon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icoon.custom_minimum_size = Vector2(0, 32)
	icoon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icoon.add_theme_stylebox_override("panel", _flat(COLOR_SLOT))
	_idle.add_child(icoon)

	var mark := Label.new()
	mark.name = "Placeholder"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.text = PLACEHOLDER_TEKST
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mark.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	icoon.add_child(mark)

	var opslaan := _knop("Opslaan", "Opslaan")
	opslaan.pressed.connect(_on_save_pressed)
	_idle.add_child(opslaan)

	_status = Label.new()
	_status.name = "Status"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 14)
	_status.add_theme_color_override("font_color", UiStyle.TEXT)
	_idle.add_child(_status)

	_ask = VBoxContainer.new()
	_ask.name = "Vraagvak"
	_ask.visible = false
	_ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ask.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ask.add_theme_constant_override("separation", 4)
	kolom.add_child(_ask)

	var vraag := Label.new()
	vraag.name = "Vraag"
	vraag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vraag.text = "Opslaan?"
	vraag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vraag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vraag.add_theme_color_override("font_color", UiStyle.TEXT)
	_ask.add_child(vraag)

	var ja := _knop("Ja", "Ja")
	ja.pressed.connect(_on_yes)
	_ask.add_child(ja)

	var nee := _knop("Nee", "Nee")
	nee.pressed.connect(_on_no)
	_ask.add_child(nee)


func _place_at_anchor() -> void:
	if not is_inside_tree():
		return
	var anchor := _first_anchor()
	if anchor == null:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var doel := PANEL_SIZE
	if anchor is Control:
		var box := anchor as Control
		global_position = box.global_position
		if box.size.x >= PANEL_SIZE.x and box.size.y >= PANEL_SIZE.y:
			doel = box.size
	elif anchor is Node2D:
		global_position = (anchor as Node2D).global_position
	size = doel


func _first_anchor() -> Node:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group(ANCHOR_GROUP):
		if node == self or is_ancestor_of(node):
			continue
		if node is Control or node is Node2D:
			return node
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not _asking:
		return
	if event.is_action_pressed("cancel"):
		_on_no()
		get_viewport().set_input_as_handled()


func _on_save_pressed() -> void:
	if _asking or _saving:
		return
	_asking = true
	_idle.visible = false
	_ask.visible = true


func _on_yes() -> void:
	if _saving or not _asking:
		return
	_saving = true
	_asking = false
	save_requested.emit()
	var ok := GameState.save_game(SAVE_TILE, SAVE_FACING)
	_status.text = "Opgeslagen." if ok else "Opslaan mislukt."
	_ask.visible = false
	_idle.visible = true
	_saving = false


func _on_no() -> void:
	if not _asking:
		return
	_asking = false
	_ask.visible = false
	_idle.visible = true


func _knop(tekst: String, node_naam: String) -> Button:
	var knop := Button.new()
	knop.name = node_naam
	knop.text = tekst
	knop.focus_mode = Control.FOCUS_ALL
	knop.custom_minimum_size = Vector2(0, RIJ_HOOG)
	knop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint(knop)
	return knop


func _paint(knop: Button) -> void:
	knop.add_theme_stylebox_override("normal", _flat(COLOR_BUTTON))
	knop.add_theme_stylebox_override("hover", _flat(COLOR_BUTTON))
	knop.add_theme_stylebox_override("pressed", _flat(COLOR_BUTTON))
	knop.add_theme_stylebox_override("focus", _flat(COLOR_BUTTON))


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
