extends Control
class_name PvpJoinPanel

signal local_picked
signal lan_picked
signal code_submitted(code: String)
signal cancel_pressed

var _box: VBoxContainer
var _mode: String = "pick"


func _ready() -> void:
	PvpStyle.fill(self)
	_box = PvpStyle.column(self)
	show_pick()


func show_pick() -> void:
	_mode = "pick"
	_rebuild()


func show_code() -> void:
	_mode = "code"
	_rebuild()


func _rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	if _mode == "pick":
		_box.add_child(PvpStyle.label("Where is your friend?", 12))
		var local := PvpStyle.button("Same device")
		local.pressed.connect(func() -> void: local_picked.emit())
		_box.add_child(local)
		var lan := PvpStyle.button("Same network")
		lan.pressed.connect(func() -> void: lan_picked.emit())
		_box.add_child(lan)
	elif _mode == "search":
		_box.add_child(PvpStyle.label("Searching the network…", 12))
	else:
		_box.add_child(PvpStyle.label("Your friend's code", 12))
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
		if _mode == "lan":
			_box.add_child(PvpStyle.label("Same network. Just the code.", 8))
	var back := PvpStyle.button("Back")
	back.pressed.connect(func() -> void: cancel_pressed.emit())
	_box.add_child(back)


func show_lan_code() -> void:
	_mode = "lan"
	_rebuild()


func show_searching() -> void:
	_mode = "search"
	_rebuild()
