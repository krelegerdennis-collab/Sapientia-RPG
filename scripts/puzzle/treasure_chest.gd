extends StaticBody2D
## v0.15 Schatkist. Kijk ernaar en druk op A: dicht = openen, het voorwerp komt in de tas
## (eenmalig, via een story-vlag die mee gaat in de save); open = 'De kist is leeg.'
## Het voorwerp zweeft even boven de kist (zoals in Lufia 2) zolang het bericht er staat.
## Massief, staat in Objects (y-sort).
## Plaatjes (RPG ART): assets/sprites/dungeon/schatkist.png, 48x16 = 3 frames (0 dicht, 1 open,
## 2 open met roze-oranje gloed = net geopend) en een icoon van het voorwerp ("icon" in de
## item-data, anders geen icoon).

const TEX := "res://assets/sprites/dungeon/schatkist.png"
## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")

var room: Node = null
var chest_id := ""
var tile := Vector2i.ZERO
var is_open := false
var sprite: Sprite2D
var icon: Sprite2D


func setup(p_room: Node, id: String, t: Vector2i, open: bool, icon_path := "") -> void:
	room = p_room
	chest_id = id
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
	sprite.hframes = 3
	add_child(sprite)
	icon = Sprite2D.new()
	icon.name = "Icoon"
	icon.position = Vector2(0, -14)
	icon.visible = false
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	add_child(icon)
	set_open(open)


func interact(player: Node2D) -> void:
	if room:
		room.request_chest(self, player)


func set_open(open: bool) -> void:
	is_open = open
	sprite.frame = 1 if open else 0


## Voorwerp boven de kist laten zien (true) of weer weg (false).
func show_icon(on: bool) -> void:
	icon.visible = on and icon.texture != null
	if is_open:
		sprite.frame = 2 if on else 1      # gloed zolang het voorwerp boven de kist zweeft
