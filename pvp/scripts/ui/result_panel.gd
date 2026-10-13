extends Control
class_name PvpResultView

signal rematch_pressed
signal rechoose_pressed
signal stop_pressed

var _box: VBoxContainer
var _body: Label


func _ready() -> void:
	PvpStyle.fill(self)
	_box = PvpStyle.column(self)
	_body = PvpStyle.label("", 8)
	_box.add_child(_body)
	var rematch := PvpStyle.button("Rematch")
	rematch.pressed.connect(func() -> void: rematch_pressed.emit())
	_box.add_child(rematch)
	var again := PvpStyle.button("Choose again")
	again.pressed.connect(func() -> void: rechoose_pressed.emit())
	_box.add_child(again)
	var stop := PvpStyle.button("Quit")
	stop.pressed.connect(func() -> void: stop_pressed.emit())
	_box.add_child(stop)


func present(result: Dictionary) -> void:
	var winner := str(result.get("winner", ""))
	var title := "Player 1 wins" if winner == "host" else "Player 2 wins"
	var lines := title
	for raw in result.get("hp", []):
		var row: Dictionary = raw
		var who := "Player 1" if str(row.get("seat", "")) == "host" else "Player 2"
		lines += "\n%s · %s  %d/%d" % [who, str(row.get("name", "")), int(row.get("hp", 0)), int(row.get("max_hp", 0))]
	if _body != null:
		_body.text = lines
