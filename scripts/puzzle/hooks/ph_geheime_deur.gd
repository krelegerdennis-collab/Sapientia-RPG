extends StaticBody2D
## v0.14 PLACEHOLDER (haakje) voor de GEHEIME DEUR van RPG CODE in de puzzelkamer van het Eerste
## Archief (puzzle_rooms.gd "archief_puzzel", teken G). Toont de echte art van RPG ART
## (assets/puzzle/geheime_deur_archief.png, 4 frames 16x32: 0 dicht .. 3 open) over de deur-tile
## en de tile erboven, en BLOKKEERT ze allebei. Er zit GEEN deurlogica in: hij gaat in het spel
## nooit open. set_open() is er alleen voor tests/debug (dan zijn beide tiles beloopbaar en is
## de schatkamer erachter te bereiken). Vervangen: zie docs/HANDOFF_ARCHIEF1.md.

const PLACEHOLDER := true
const TEX := "res://assets/puzzle/geheime_deur_archief.png"

var room: Node
var hook_id := ""
var tile := Vector2i.ZERO
var data := {}
var is_open := false
var sprite: Sprite2D
var shape: CollisionShape2D


func setup(p_room: Node, id: String, t: Vector2i, d: Dictionary) -> void:
	room = p_room
	hook_id = id
	name = "PH_" + id
	tile = t
	data = d
	position = Vector2(t) * 16 + Vector2(8, 8)
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(TEX)
	sprite.hframes = 4
	sprite.offset = Vector2(0, -8)       # linksboven = de tile boven de deur
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 30)          # deur-tile + tile erboven
	shape.shape = rect
	shape.position = Vector2(0, -8)
	add_child(shape)
	set_open(false)


## Alleen voor tests/debug: open = frame 3 en beide tiles beloopbaar.
func set_open(open: bool) -> void:
	is_open = open
	sprite.frame = 3 if open else 0
	shape.set_deferred("disabled", open)


func interact(_by: Node) -> void:
	var lines: Array = data.get("hint", [])
	if not is_open and not lines.is_empty() and not Dialog.is_open:
		Dialog.show_lines(lines)
