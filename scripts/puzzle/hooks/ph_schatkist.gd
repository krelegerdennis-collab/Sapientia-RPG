extends StaticBody2D
## v0.14 PLACEHOLDER (haakje) voor de SCHATKIST met het Vonkzwaard van RPG CODE (puzzelkamer van
## het Eerste Archief, in de schatkamer achter de geheime deur, teken T). Dichte kist met de art
## van RPG ART (assets/sprites/dungeon/schatkist.png, 3 frames: dicht/open/gloed), massief.
## Geeft NIETS (het zwaard en de kistlogica komen van RPG CODE). In het spel onbereikbaar zolang
## de geheime deur een placeholder is. Vervangen: zie docs/HANDOFF_ARCHIEF1.md.

const PLACEHOLDER := true
const TEX := "res://assets/sprites/dungeon/schatkist.png"

var room: Node
var hook_id := ""
var tile := Vector2i.ZERO
var data := {}
var sprite: Sprite2D


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
	sprite.hframes = 3
	sprite.frame = 0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	cs.shape = rect
	add_child(cs)


func interact(_by: Node) -> void:
	if not Dialog.is_open:
		Dialog.show_lines(["De kist zit muurvast. (komt later)"])
