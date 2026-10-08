class_name DungeonProp
extends StaticBody2D
## v0.14 Los meubelstuk in een dungeonkamer (dungeon_rooms.gd "props", soorten in PROPS):
## staande boekenkast, kandelaar (vlam flakkert), golemdeur. 16x32-stukken: de voet staat op de
## tile, de bovenste helft steekt een tile omhoog (y-sort in Objects). Botsing op "solid_h" tiles
## vanaf de voet omhoog (standaard 1), of geen botsing ("solid": false, bv. de golemdeur: daar
## doen de tegels eronder het werk).

## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")

var kind := ""
var sprite: Sprite2D
var _fps := 0.0
var _t := 0.0


func setup(d: Dictionary, info: Dictionary) -> void:
	kind = str(d.get("type", ""))
	var t: Array = d.get("tile", [0, 0])
	var w := int(info.get("w", 16))
	var h := int(info.get("h", 16))
	var foot := Vector2i(int(t[0]), int(t[1]))
	name = "Prop_%s_%d_%d" % [kind, foot.x, foot.y]
	if kind == "golemdeur":
		# 2x2 tiles, linksboven = de opgegeven tile; y-sort op de onderste rij
		position = Vector2(foot) * 16 + Vector2(w / 2.0, h - 8.0)
	else:
		position = Vector2(foot) * 16 + Vector2(8, 8)
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(DungeonRoomsTheme.themed(str(info["texture"])))
	sprite.hframes = int(info.get("hframes", 1))
	sprite.frame = clampi(int(d.get("frame", 0)), 0, sprite.hframes - 1)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# onderkant van het plaatje = onderkant van de voet-tile
	sprite.offset = Vector2(0, 8.0 - h / 2.0)
	add_child(sprite)
	_fps = float(info.get("fps", 0.0))
	if bool(d.get("solid", info.get("solid", true))):
		var n := maxi(1, int(d.get("solid_h", 1)))
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 16 * n - 2)
		cs.shape = rect
		cs.position = Vector2(0, -8.0 * (n - 1))
		add_child(cs)
	else:
		collision_layer = 0
		collision_mask = 0


## Tiles die dit stuk blokkeert (voor de map-monsters).
func blocked_tiles(d: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if collision_layer == 0:
		return out
	var t: Array = d.get("tile", [0, 0])
	for i in maxi(1, int(d.get("solid_h", 1))):
		out.append(Vector2i(int(t[0]), int(t[1]) - i))
	return out


func _process(delta: float) -> void:
	if _fps <= 0.0:
		return
	_t += delta
	if _t >= 1.0 / _fps:
		_t -= 1.0 / _fps
		sprite.frame = (sprite.frame + 1) % sprite.hframes
