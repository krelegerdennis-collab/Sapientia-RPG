extends Control
class_name PvpTeamPanel

signal team_picked(team_id: String)
signal back_pressed

var _box: VBoxContainer
var _prompt: String = "Choose your team."
var _waiting: bool = false


func _ready() -> void:
	PvpStyle.fill(self)
	_box = PvpStyle.column(self)
	_rebuild()


func prompt(text: String) -> void:
	_prompt = text
	_rebuild()


func set_waiting(waiting: bool) -> void:
	_waiting = waiting
	_rebuild()


func _pick_team(id: String) -> void:
	team_picked.emit(id)


func _rebuild() -> void:
	if _box == null:
		return
	for child in _box.get_children():
		child.queue_free()
	_box.add_child(PvpStyle.label(_prompt, 10))
	if _waiting:
		var leave := PvpStyle.button("Back")
		leave.pressed.connect(func() -> void: back_pressed.emit())
		_box.add_child(leave)
		return
	for id in PvpTeams.ORDER:
		var btn := PvpStyle.button(PvpTeams.display_name(id))
		btn.pressed.connect(_pick_team.bind(id))
		_box.add_child(btn)
		var sub := PvpStyle.label(PvpTeams.member_line(id) + " — " + PvpTeams.blurb(id), 8)
		sub.add_theme_color_override("font_color", PvpStyle.DIM)
		_box.add_child(sub)
	var back := PvpStyle.button("Back")
	back.pressed.connect(func() -> void: back_pressed.emit())
	_box.add_child(back)
