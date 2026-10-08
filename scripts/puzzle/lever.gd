extends StaticBody2D
## Hendel: kijk ernaar en druk op A = om. Geeft het signaal met zijn eigen id (aan/uit).
## Plaatje: assets/puzzle/hendel.png, 32x16 = 2 frames (0 uit, 1 aan).

const TEX := "res://assets/puzzle/hendel.png"
## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")

var room: Node = null
var lever_id := ""
var tile := Vector2i.ZERO
var sprite: Sprite2D


func setup(p_room: Node, id: String, t: Vector2i, on: bool) -> void:
	room = p_room
	lever_id = id
	name = id
	tile = t
	position = Vector2(t) * 16 + Vector2(8, 8)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load(DungeonRoomsTheme.themed(TEX))
	sprite.hframes = 2
	add_child(sprite)
	set_on(on)


func interact(player: Node2D) -> void:
	if room:
		room.request_lever(self, player)


func set_on(on: bool) -> void:
	sprite.frame = 1 if on else 0
