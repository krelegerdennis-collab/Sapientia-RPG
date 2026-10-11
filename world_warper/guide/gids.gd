class_name WorldWarperGids
extends StaticBody2D
## Hologram van de gids bij de hoofd-PC. Placeholder: paars vlak, geen art.
## Tik op het vlak, of interact/accept vanaf de tegel ervoor (player.gd).
## Dialog.show_lines toont de stap. De vlag komt in GameState.story_flags.

signal guide_advanced(step_id: String)

const Dialoog := preload("res://world_warper/guide/dialoog.gd")
const ANKER_GROEP := "ww_anchor_gids"
const PLACEHOLDER_TEKST := "PLACEHOLDER"

var _laatste_frame := -1

@onready var naam_label: Label = $Naam
@onready var placeholder_label: Label = $Placeholder


func _ready() -> void:
	input_pickable = true
	_stijl_labels()
	_volg_anker()


func _volg_anker() -> void:
	if snap_to_anchor():
		return
	var boom := get_tree()
	if boom == null:
		return
	await boom.process_frame
	if is_instance_valid(self) and is_inside_tree():
		snap_to_anchor()


## Zet de gids op het eerste Node2D-anker in de groep. false = geen anker.
func snap_to_anchor() -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group(ANKER_GROEP):
		if node == self or not (node is Node2D):
			continue
		global_position = (node as Node2D).global_position
		return true
	return false


func interact(_by: Node = null) -> void:
	if _dialog_open():
		return
	var frame := Engine.get_process_frames()
	if frame == _laatste_frame:
		return
	var stappen: Array = Dialoog.steps()
	var idx := int(Dialoog.step_index(_flags()))
	if idx < 0 or idx >= stappen.size():
		return
	var stap: Dictionary = stappen[idx]
	_laatste_frame = frame
	_toon(stap)
	_zet_vlag(str(stap.get("flag", "")))
	guide_advanced.emit(str(stap.get("id", "")))


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _is_tik(event) or _dialog_open():
		return
	var idx := int(Dialoog.step_index(_flags()))
	if idx < 0 or idx >= Dialoog.steps().size():
		return
	interact(null)
	get_viewport().set_input_as_handled()


func _stijl_labels() -> void:
	if naam_label != null:
		naam_label.text = str(Dialoog.NAAM)
		naam_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		naam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if placeholder_label != null:
		placeholder_label.text = PLACEHOLDER_TEKST
		placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _toon(stap: Dictionary) -> void:
	if not is_inside_tree() or get_node_or_null("/root/Dialog") == null:
		return
	var regels: Array = stap.get("lines", [])
	Dialog.show_lines(regels, str(Dialoog.NAAM), self)


func _zet_vlag(vlag: String) -> void:
	if vlag == "" or not is_inside_tree():
		return
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var raw = gs.get("story_flags")
	if raw is Dictionary:
		var flags: Dictionary = raw
		flags[vlag] = true


func _flags() -> Dictionary:
	if not is_inside_tree():
		return {}
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return {}
	var raw = gs.get("story_flags")
	if raw is Dictionary:
		return raw
	return {}


func _dialog_open() -> bool:
	if not is_inside_tree():
		return false
	var dlg := get_node_or_null("/root/Dialog")
	if dlg == null:
		return false
	return bool(dlg.get("is_open"))


## Tik op het vlak. Accept/interact komt via interact() (de speler, tegel ervoor).
func _is_tik(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var muis := event as InputEventMouseButton
		return muis.pressed and muis.button_index == MOUSE_BUTTON_LEFT
	return false
