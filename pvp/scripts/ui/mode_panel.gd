extends Control
class_name PvpModePanel

signal mode_picked(mode_id: String)
signal back_pressed

var _box: VBoxContainer
var _host: bool = true


func _ready() -> void:
	PvpStyle.fill(self)
	_box = PvpStyle.column(self)


func show_host() -> void:
	_host = true
	_rebuild()


func show_guest() -> void:
	_host = false
	_rebuild()


func _pick_mode(id: String) -> void:
	mode_picked.emit(id)


func _add_back() -> void:
	var back := PvpStyle.button("Terug")
	back.pressed.connect(func() -> void: back_pressed.emit())
	_box.add_child(back)


func _rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	if not _host:
		_box.add_child(PvpStyle.label("De host kiest…", 12))
		_add_back()
		return
	_box.add_child(PvpStyle.label("Kies de modus", 12))
	for id in PvpModes.ORDER:
		var label := "%s (level %d)" % [PvpModes.display_name(id), PvpModes.level_of(id)]
		var btn := PvpStyle.button(label)
		btn.pressed.connect(_pick_mode.bind(id))
		_box.add_child(btn)
	_add_back()
