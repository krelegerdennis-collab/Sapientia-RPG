extends StaticBody2D
## v0.15 Los boek: een kast waar één boek uitsteekt. Kijk ernaar en druk op A = het boek
## terugduwen ('klik'). Eenmalig: daarna blijft het ingedrukt (onthouden zoals een
## vergrendelde poort). Geeft het signaal met zijn eigen id, bv. voor een geheime deur.
## Massief, 2 tiles hoog (zoals een duwbare kast), staat in Objects (y-sort).
## Plaatje: assets/puzzle/los_boek.png, 32x32 = 2 frames 16x32 (0 steekt uit, 1 ingedrukt).

const TEX := "res://assets/puzzle/los_boek.png"

var room: Node = null
var book_id := ""
var tile := Vector2i.ZERO
var sprite: Sprite2D


func setup(p_room: Node, id: String, t: Vector2i, pressed: bool) -> void:
	room = p_room
	book_id = id
	name = id
	tile = t
	position = Vector2(t) * 16 + Vector2(8, 8)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load(TEX)
	sprite.hframes = 2
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	set_pressed(pressed)


func interact(player: Node2D) -> void:
	if room:
		room.request_book(self, player)


func set_pressed(pressed: bool) -> void:
	sprite.frame = 1 if pressed else 0
