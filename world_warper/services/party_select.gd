class_name WorldWarperPartySelect
extends Control
## Kijk-scherm Gezelschap. Toont iedereen in GameState.party, met Nederlandse
## naam en niveau. Geen reservebank.
##
## TODO(design): wisselen wacht op een bestaande publieke API die de volgorde
## of samenstelling veilig zet. add_member en join_member voegen een held toe;
## ze herschikken de party niet. Dit scherm muteert GameState.party niet.
## party_changed blijft daarom stil.
##
## Anker: eerste Control of Node2D in ww_anchor_party (deze node telt niet).
## Zonder anker vult het scherm de ouder. Past in 384x216.

signal party_changed

const PartyLines := preload("res://world_warper/services/party_view_test.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")

const ANCHOR_GROUP := "ww_anchor_party"
const PANEL_SIZE := Vector2(220, 180)
const RIJ_HOOG := 40
const LEEG := "Niemand in het gezelschap."

const COLOR_PANEL := Color("3d2158")
const COLOR_BUTTON := Color("5c3484")
const COLOR_BORDER := Color("8d6bb0")

var _open := false
var _built := false
var _empty: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer


func _ready() -> void:
	_ensure_ui()
	refresh()
	if not _open:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_at_anchor()
	call_deferred("_place_at_anchor")


func open() -> void:
	_open = true
	_ensure_ui()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_place_at_anchor()
	refresh()


func close() -> void:
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return _open and visible


func refresh() -> void:
	if not _built:
		return
	var regels: Array = PartyLines.lines(_party())
	for kind in _rows.get_children():
		_rows.remove_child(kind)
		kind.queue_free()
	var leeg := regels.is_empty()
	_empty.visible = leeg
	_scroll.visible = not leeg
	for regel in regels:
		var lab := Label.new()
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.text = str(regel)
		lab.custom_minimum_size = Vector2(0, 28)
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", UiStyle.TEXT)
		_rows.add_child(lab)


func _party() -> Array:
	return GameState.party


func _place_at_anchor() -> void:
	if not is_inside_tree():
		return
	var anchor := _first_anchor()
	if anchor == null:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var doel := PANEL_SIZE
	if anchor is Control:
		var box := anchor as Control
		global_position = box.global_position
		# Kleiner dan het paneel zou de tikknop afsnijden (clip_contents).
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
	if not _open or not visible:
		return
	if event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = PANEL_SIZE
	clip_contents = true
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
	kolom.add_theme_constant_override("separation", 4)
	marge.add_child(kolom)

	var titel := Label.new()
	titel.name = "Titel"
	titel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titel.text = "Gezelschap"
	titel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titel.add_theme_color_override("font_color", UiStyle.HILITE)
	kolom.add_child(titel)

	_empty = Label.new()
	_empty.name = "Leeg"
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.text = LEEG
	_empty.visible = false
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.add_theme_color_override("font_color", UiStyle.TEXT)
	kolom.add_child(_empty)

	_scroll = ScrollContainer.new()
	_scroll.name = "Lijst"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kolom.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.name = "Rijen"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows)

	var sluiten := Button.new()
	sluiten.name = "Sluiten"
	sluiten.text = "Sluiten"
	sluiten.focus_mode = Control.FOCUS_ALL
	sluiten.custom_minimum_size = Vector2(0, RIJ_HOOG)
	sluiten.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sluiten.add_theme_stylebox_override("normal", _flat(COLOR_BUTTON))
	sluiten.add_theme_stylebox_override("hover", _flat(COLOR_BUTTON))
	sluiten.add_theme_stylebox_override("pressed", _flat(COLOR_BUTTON))
	sluiten.add_theme_stylebox_override("focus", _flat(COLOR_BUTTON))
	sluiten.pressed.connect(close)
	kolom.add_child(sluiten)


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
