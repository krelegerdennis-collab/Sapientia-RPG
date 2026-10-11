extends StaticBody2D
## Groei-plaat. Kijk ernaar en druk op A: één stadium verder, als de needs kloppen.
## De plaat zelf blijft massief. De spleet (het pad) zit in een aparte body op PuzzleFloor,
## zodat de speler eroverheen loopt zodra het laatste stadium open is.
## Plaatje: assets/puzzle/groei_plaat.png, 48x16 = 3 frames (0 zaad, 1 scheut, 2 volgroeid).
## PLACEHOLDER, magenta hoekjes. Echte art: dezelfde naam en maat.

const TEX := "res://assets/puzzle/groei_plaat.png"

var room: Node = null
var grow_id := ""
var tile := Vector2i.ZERO
var sprite: Sprite2D
var pad: StaticBody2D
var gap_shapes: Array[CollisionShape2D] = []
var gap_sprites: Array[Sprite2D] = []
var _stage := 0
var _open := false


func setup(p_room: Node, id: String, t: Vector2i, stage: int, open: bool) -> void:
	room = p_room
	grow_id = id
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
	sprite.hframes = 3
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	set_stage(stage, open)


## Spleet-tegels: botsing tot het pad open is, beeld vanaf scheut. parent = PuzzleFloor.
func attach_pad(parent: Node2D, gaps: Array) -> void:
	pad = StaticBody2D.new()
	pad.name = grow_id + "_pad"
	parent.add_child(pad)
	var tex: Texture2D = sprite.texture
	for g in gaps:
		var gt: Vector2i = g
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 16)
		cs.shape = rect
		cs.position = Vector2(gt) * 16 + Vector2(8, 8)
		pad.add_child(cs)
		gap_shapes.append(cs)
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.hframes = 3
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = Vector2(gt) * 16 + Vector2(8, 8)
		sp.visible = false
		pad.add_child(sp)
		gap_sprites.append(sp)
	set_stage(_stage, _open)


func interact(p: Node2D) -> void:
	if room:
		room.request_grow(self, p)


func set_stage(stage: int, open: bool) -> void:
	_stage = clampi(stage, 0, 2)
	_open = open
	if sprite:
		sprite.frame = _stage
	for cs in gap_shapes:
		cs.disabled = open
	for sp in gap_sprites:
		sp.visible = _stage > 0
		sp.frame = _stage
