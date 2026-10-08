extends StaticBody2D
## Herstelsteen: kijk ernaar en druk op A: 'De kamer herstellen?' Ja = alles terug naar het
## begin (kasten, hendels; vergrendelde poorten blijven open), jij terug bij de ingang.
## Gloeit MAGENTA (niet cyaan: dat is het opslagboek).
## Plaatje: assets/puzzle/herstelsteen.png, 32x16 = 2 gloei-frames (lus).

const TEX := "res://assets/puzzle/herstelsteen.png"
## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")
const FRAME_TIME := 0.5

var room: Node = null
var stone_id := ""
var tile := Vector2i.ZERO
var sprite: Sprite2D
var _t := 0.0


func setup(p_room: Node, id: String, t: Vector2i) -> void:
	room = p_room
	stone_id = id
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


func _process(delta: float) -> void:
	_t += delta
	if _t >= FRAME_TIME:
		_t -= FRAME_TIME
		sprite.frame = 1 - sprite.frame


func interact(player: Node2D) -> void:
	if room:
		room.request_reset(player)
