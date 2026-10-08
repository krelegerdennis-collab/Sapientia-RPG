extends StaticBody2D
## v0.15 Geheime deur in de achterwand, 2 tegels hoog (zijn tegel + de tegel erboven).
## Dicht = muur met een gebarsten rune; beide tegels massief. A ervoor = de hint uit de data.
## Gaat open (4 frames: dicht, rune ontwaakt, glitch/oplossen, open) zodra de "needs" kloppen
## en blijft dan voor altijd open (latch, onthouden in GameState.puzzle_latched); dan zijn
## beide tegels beloopbaar. Ligt in de laag PuzzleFloor (de speler loopt er altijd vóór langs).
## Plaatje (RPG ART): assets/puzzle/geheime_deur_archief.png (v14-naam), 64x32 = 4 frames van 16x32,
## linksboven = de bovenste tegel.

const TEX := "res://assets/puzzle/geheime_deur_archief.png"
## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")
const FRAME_TIME := 0.1

var room: Node = null
var door_id := ""
var tile := Vector2i.ZERO
var is_open := false
var sprite: Sprite2D
var shape: CollisionShape2D
var _anim := false
var _t := 0.0


func setup(p_room: Node, id: String, t: Vector2i, open: bool) -> void:
	room = p_room
	door_id = id
	name = id
	tile = t
	position = Vector2(t) * 16 + Vector2(8, 8)
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 30)           # beide tegels
	shape.shape = rect
	shape.position = Vector2(0, -8)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load(DungeonRoomsTheme.themed(TEX))
	sprite.hframes = 4
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	set_open(open, false)


func interact(player: Node2D) -> void:
	if room and not is_open:
		room.request_secret(self, player)


## Open of dicht (dicht alleen bij opbouwen/herstellen van een oude stand).
func set_open(open: bool, animate := true) -> void:
	is_open = open
	shape.disabled = open
	_anim = animate and open
	_t = 0.0
	if not _anim:
		sprite.frame = 3 if open else 0


func is_animating() -> bool:
	return _anim


func _process(delta: float) -> void:
	if not _anim:
		return
	_t += delta
	while _t >= FRAME_TIME and _anim:
		_t -= FRAME_TIME
		sprite.frame = mini(sprite.frame + 1, 3)
		_anim = sprite.frame < 3
