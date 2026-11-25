class_name MpCharacterCreate
extends CanvasLayer
## Co-op-only: naam + klasse voor een nieuw online-profielslot (OnlineProfile).

signal finished(created: bool)
signal cancelled()

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const Profile := preload("res://scripts/online/online_profile.gd")

const LAYER := 21
const CLASS_IDS: Array[String] = ["warrior", "mage", "priest", "psytech", "archer"]
const TOUCH_H := 25.0

var slot_index := 0
var _store: OnlineProfile
var _edit: LineEdit
var _class_id := "warrior"
var _class_buttons: Dictionary = {}
var _error: Label


func _ready() -> void:
	layer = LAYER
	if _store == null:
		_store = Profile.new()
	_store.load_profile()
	var root := Control.new()
	root.theme = load(UiMenu.THEME_PATH)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := UiMenu.panel()
	box.name = "Panel"
	root.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	col.add_child(UiMenu.label("New character", UiStyleC.HILITE))
	col.add_child(UiMenu.label("Name (1-5 letters)", UiStyleC.TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	_edit = LineEdit.new()
	_edit.max_length = Profile.NAME_MAX
	_edit.virtual_keyboard_enabled = true
	_edit.custom_minimum_size = Vector2(100, 28)
	_edit.placeholder_text = "Name"
	_edit.add_theme_stylebox_override("normal", UiMenu.window_style(UiStyleC.BORDER_DARK, 1.0))
	_edit.add_theme_stylebox_override("focus", UiMenu.window_style(UiStyleC.MAGENTA, 1.0))
	row.add_child(_edit)
	col.add_child(UiMenu.label("Class", UiStyleC.TEXT_DIM))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 2)
	col.add_child(crow)
	for cid in CLASS_IDS:
		var b := UiMenu.button(cid.capitalize())
		b.custom_minimum_size = Vector2(0, TOUCH_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_class.bind(cid))
		crow.add_child(b)
		_class_buttons[cid] = b
	_pick_class("warrior")
	_error = UiMenu.label("", UiStyleC.TEXT)
	col.add_child(_error)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	col.add_child(actions)
	var ok := UiMenu.button("Create")
	ok.custom_minimum_size = Vector2(0, TOUCH_H)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_on_create)
	actions.add_child(ok)
	var back := UiMenu.button("Back")
	back.custom_minimum_size = Vector2(0, TOUCH_H)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_on_back)
	actions.add_child(back)
	_center_box.call_deferred(box, root)
	_edit.grab_focus.call_deferred()


func setup(store: OnlineProfile, index: int) -> void:
	_store = store
	slot_index = index


func _pick_class(cid: String) -> void:
	_class_id = cid
	for id in _class_buttons.keys():
		var b: Button = _class_buttons[id]
		b.disabled = id == cid


func _filter_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var c := raw.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			out += raw.substr(i, 1)
		if out.length() >= Profile.NAME_MAX:
			break
	return out


func _on_create() -> void:
	var naam := _filter_name(_edit.text)
	if naam == "":
		_error.text = "Enter a name."
		return
	var res := _store.create_slot(slot_index, naam, _class_id)
	if not bool(res.get("ok", false)):
		_error.text = "Could not create (%s)." % str(res.get("reason", "?"))
		return
	finished.emit(true)
	queue_free()


func _on_back() -> void:
	cancelled.emit()
	queue_free()


func _center_box(box: PanelContainer, root: Control) -> void:
	box.reset_size()
	var vp := root.size
	box.position = ((vp - box.size) / 2.0).floor()