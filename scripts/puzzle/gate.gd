extends StaticBody2D
## Poort (ijzeren hek). Dicht = botsing aan; open = botsing uit. Open/dicht gaat met een
## animatie van 4 frames. Onder het hek ligt een donkere doorgang (het plaatje is
## doorzichtig tussen de spijlen). Ligt in de laag PuzzleFloor: de speler loopt er altijd
## vóór langs.
## Plaatje: assets/puzzle/poort.png, 64x16 = 4 frames (0 dicht .. 3 open).

const TEX := "res://assets/puzzle/poort.png"
## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")
const FRAME_TIME := 0.06
const PASSAGE_COLOR := Color("0b0a10")

var gate_id := ""
var tile := Vector2i.ZERO
var is_open := false
var sprite: Sprite2D
var shape: CollisionShape2D
var _anim_dir := 0       # +1 = opengaan, -1 = dichtgaan, 0 = stil
var _t := 0.0


func setup(id: String, t: Vector2i, open: bool) -> void:
	gate_id = id
	name = id
	tile = t
	position = Vector2(t) * 16 + Vector2(8, 8)
	var passage := ColorRect.new()
	passage.name = "Doorgang"
	passage.color = PASSAGE_COLOR
	passage.position = Vector2(-8, -8)
	passage.size = Vector2(16, 16)
	passage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(passage)
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load(DungeonRoomsTheme.themed(TEX))
	sprite.hframes = 4
	add_child(sprite)
	set_open(open, false)


## Open of dicht; animate = met de 4 frames. De botsing verandert METEEN (dichtgaan
## gebeurt alleen als de speler er niet in staat, dat regelt PuzzleLogic).
func set_open(open: bool, animate := true) -> void:
	is_open = open
	shape.disabled = open
	if animate:
		_anim_dir = 1 if open else -1
		_t = 0.0
	else:
		_anim_dir = 0
		sprite.frame = 3 if open else 0


func is_animating() -> bool:
	return _anim_dir != 0


func _process(delta: float) -> void:
	if _anim_dir == 0:
		return
	_t += delta
	while _t >= FRAME_TIME and _anim_dir != 0:
		_t -= FRAME_TIME
		var f := sprite.frame + _anim_dir
		sprite.frame = clampi(f, 0, 3)
		if (_anim_dir > 0 and sprite.frame == 3) or (_anim_dir < 0 and sprite.frame == 0):
			_anim_dir = 0
