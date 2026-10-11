extends Control
class_name PvpMenu

signal host_pressed
signal join_pressed
signal back_pressed


func _ready() -> void:
	PvpStyle.fill(self)
	var box := PvpStyle.column(self)
	box.add_child(PvpStyle.label("Vriendenmodus", 14))
	box.add_child(PvpStyle.label("1 tegen 1, met een code.", 8))
	var host := PvpStyle.button("Host")
	host.pressed.connect(func() -> void: host_pressed.emit())
	box.add_child(host)
	var join := PvpStyle.button("Deelnemen")
	join.pressed.connect(func() -> void: join_pressed.emit())
	box.add_child(join)
	var back := PvpStyle.button("Terug")
	back.pressed.connect(func() -> void: back_pressed.emit())
	box.add_child(back)
