extends Control
class_name PvpHostPanel

signal local_picked
signal lan_picked
signal code_submitted(code: String)
signal cancel_pressed

var _box: VBoxContainer
var _code: String = ""
var _hotseat: bool = false
var _mode: String = "pick"


func _ready() -> void:
	PvpStyle.fill(self)
	_box = PvpStyle.column(self)
	show_pick()


func show_pick() -> void:
	_mode = "pick"
	_rebuild()


func show_waiting(code: String, hotseat: bool) -> void:
	_mode = "wait"
	_code = code
	_hotseat = hotseat
	_rebuild()


func _rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	if _mode == "pick":
		_box.add_child(PvpStyle.label("How are you playing?", 12))
		var local := PvpStyle.button("Same device")
		local.pressed.connect(func() -> void: local_picked.emit())
		_box.add_child(local)
		var lan := PvpStyle.button("Same network")
		lan.pressed.connect(func() -> void: lan_picked.emit())
		_box.add_child(lan)
		var back := PvpStyle.button("Back")
		back.pressed.connect(func() -> void: cancel_pressed.emit())
		_box.add_child(back)
		return
	_box.add_child(PvpStyle.label("Your code", 8))
	var code := PvpStyle.label(_code, 16)
	code.name = "CodeLabel"
	_box.add_child(code)
	_box.add_child(PvpStyle.label("Waiting for your friend…", 8))
	if _hotseat:
		_box.add_child(PvpStyle.label("The second player enters the code.", 8))
		var edit := LineEdit.new()
		edit.name = "CodeEdit"
		edit.placeholder_text = "K7NP2Q"
		edit.max_length = 8
		edit.custom_minimum_size = Vector2(120, 16)
		edit.add_theme_font_size_override("font_size", 10)
		edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(edit)
		var go := PvpStyle.button("Connect")
		go.pressed.connect(func() -> void: code_submitted.emit(edit.text))
		_box.add_child(go)
	var cancel := PvpStyle.button("Cancel")
	cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	_box.add_child(cancel)
