class_name MpCharacterSlots
extends PanelContainer
## Co-op-only titelmenu: drie online-profielslots (OnlineProfile), los van verhaal-saves.

signal play_slot(index: int)
signal create_slot(index: int)
signal delete_slot(index: int)

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")

const TOUCH_H := 25.0
const ROW_GAP := 1.0

var _store: OnlineProfile
var _rows: VBoxContainer
var _slot_buttons: Array[Button] = []
var _delete_buttons: Array[Button] = []


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyleC.panel("window"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", ROW_GAP)
	add_child(col)
	col.add_child(UiMenu.label(ReleaseFlags.COOP_ONLY_PLAYER_LABEL, UiStyleC.HILITE))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", ROW_GAP)
	col.add_child(_rows)
	for i in Profile.SLOT_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_rows.add_child(row)
		var main := UiMenu.button("")
		main.custom_minimum_size = Vector2(0, TOUCH_H)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.pressed.connect(_on_main_pressed.bind(i))
		row.add_child(main)
		_slot_buttons.append(main)
		var del := UiMenu.button("Del")
		del.custom_minimum_size = Vector2(28, TOUCH_H)
		del.pressed.connect(_on_delete_pressed.bind(i))
		row.add_child(del)
		_delete_buttons.append(del)


func bind_store(store: OnlineProfile) -> void:
	_store = store


func refresh() -> void:
	if _store == null:
		_store = Profile.new()
	if not _store.document().has("slots"):
		_store.load_profile()
	for i in Profile.SLOT_COUNT:
		var main := _slot_buttons[i]
		var del := _delete_buttons[i]
		if _store.has_slot(i):
			var row := _store.get_slot(i)
			var role := Profile.role_for(str(row.get("class", "")))
			main.text = "%s  (%s)" % [str(row.get("name", "?")), role]
			del.visible = true
			del.disabled = false
		else:
			main.text = "New character"
			del.visible = false
			del.disabled = true
			del.focus_mode = Control.FOCUS_NONE
	wire_focus_neighbors()


## Slot/Del-knoppen in een ring (boven/onder wikkelen) voor pad-navigatie.
func wire_focus_neighbors() -> void:
	var chain: Array[Button] = []
	for i in Profile.SLOT_COUNT:
		chain.append(_slot_buttons[i])
		var del := _delete_buttons[i]
		if del.visible and not del.disabled:
			del.focus_mode = Control.FOCUS_ALL
			chain.append(del)
		else:
			del.focus_mode = Control.FOCUS_NONE
	if chain.is_empty():
		return
	for j in chain.size():
		var b: Button = chain[j]
		var prev: Button = chain[(j - 1 + chain.size()) % chain.size()]
		var next: Button = chain[(j + 1) % chain.size()]
		b.focus_neighbor_top = prev.get_path()
		b.focus_neighbor_bottom = next.get_path()
	for i in Profile.SLOT_COUNT:
		var main := _slot_buttons[i]
		var del := _delete_buttons[i]
		if del.visible and not del.disabled:
			main.focus_neighbor_right = del.get_path()
			del.focus_neighbor_left = main.get_path()
			del.focus_neighbor_right = del.get_path()
		else:
			main.focus_neighbor_right = main.get_path()


func focus_first_playable() -> void:
	if not _slot_buttons.is_empty():
		_slot_buttons[0].grab_focus()


func _on_main_pressed(index: int) -> void:
	if _store == null or not _store.has_slot(index):
		create_slot.emit(index)
	else:
		play_slot.emit(index)


func _on_delete_pressed(index: int) -> void:
	if _store != null and _store.has_slot(index):
		delete_slot.emit(index)