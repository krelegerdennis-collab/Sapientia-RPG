extends Area2D
## v0.14 Leesbare plek zonder botsing (bv. het boek op de leestafel, de golemdeur):
## A ervoor = tekst. Ligt over een tile (die zelf massief kan zijn).

var lines: Array = []


func setup(d: Dictionary) -> void:
	var t: Array = d.get("tile", [0, 0])
	name = "Lees_%d_%d" % [int(t[0]), int(t[1])]
	position = Vector2(int(t[0]), int(t[1])) * 16 + Vector2(8, 8)
	lines = d.get("lines", [])
	monitoring = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	cs.shape = rect
	add_child(cs)


func interact(_player: Node2D) -> void:
	if not Dialog.is_open:
		Dialog.show_lines(lines)
