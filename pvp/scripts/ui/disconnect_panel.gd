extends Control
class_name PvpDisconnectPanel

signal menu_pressed
signal reconnect_pressed

var _box: VBoxContainer
var _text: Label


func _ready() -> void:
	PvpStyle.fill(self)
	_box = PvpStyle.column(self)
	_text = PvpStyle.label("", 8)
	_box.add_child(_text)
	var again := PvpStyle.button("Opnieuw verbinden")
	again.pressed.connect(func() -> void: reconnect_pressed.emit())
	_box.add_child(again)
	var menu := PvpStyle.button("Naar het menu")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	_box.add_child(menu)


func set_text(text: String) -> void:
	if _text != null:
		_text.text = text
