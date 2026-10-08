extends StaticBody2D
## Duwbare boekenkast (Sokoban): loop ertegenaan en hij schuift 1 tile op, als dat mag
## (PuzzleLogic beslist). De node springt meteen naar de nieuwe tile (dus de botsing ook);
## alleen het plaatje glijdt in de looptijd van de speler (0,25 s) mee.
## Plaatje: assets/puzzle/kast_duwbaar.png (16x32, bovenste helft steekt boven de tile uit).
## Ontbreekt dat bestand, dan de boekenkast-tegels 6 (boven) en 7 (onder) uit binnen.png.

const TEX := "res://assets/puzzle/kast_duwbaar.png"
## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")
const TILES := "res://assets/tiles/binnen.png"

var room: Node = null
var block_id := ""
var tile := Vector2i.ZERO
var visual: Node2D
var _tween: Tween


## v0.15 zware kast (heavy): donkerder steen-paars + een roze rune. Alleen te duwen met de
## wereldvaardigheid 'Zware blokken duwen' (kernfragment), dat beslist PuzzleLogic.
## (Eigen art kan later: assets/puzzle/kast_zwaar.png 16x32 wordt dan gebruikt als hij bestaat.)
const TEX_HEAVY := "res://assets/puzzle/kast_zwaar.png"
const HEAVY_TINT := Color(0.66, 0.6, 0.86)
const RUNE_COLOR := Color(1.0, 0.36, 0.78)

var heavy := false


func setup(p_room: Node, id: String, t: Vector2i, p_heavy := false) -> void:
	heavy = p_heavy
	room = p_room
	block_id = id
	name = id
	tile = t
	position = Vector2(t) * 16 + Vector2(8, 8)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	add_child(shape)
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	if ResourceLoader.exists(TEX):
		var s := Sprite2D.new()
		s.texture = load(DungeonRoomsTheme.themed(TEX))
		s.offset = Vector2(0, -8)          # 16x32: onderkant op de onderrand van de tile
		visual.add_child(s)
	else:
		for i in 2:   # terugval: tegel 6 (bovenkant) boven tegel 7 (onderkant)
			var s := Sprite2D.new()
			var at := AtlasTexture.new()
			at.atlas = load(TILES)
			at.region = Rect2(16 * (6 + i), 0, 16, 16)
			s.texture = at
			s.position = Vector2(0, -16 + 16 * i)
			visual.add_child(s)
	_apply_heavy_look()


## v0.15: uiterlijk van een zware kast (aangeroepen aan het eind van setup).
func _apply_heavy_look() -> void:
	if not heavy:
		return
	if ResourceLoader.exists(TEX_HEAVY):
		for c in visual.get_children():
			if c is Sprite2D:
				c.texture = load(DungeonRoomsTheme.themed(TEX_HEAVY))
				return
	visual.modulate = HEAVY_TINT
	var img := Image.create(5, 7, false, Image.FORMAT_RGBA8)
	for p in [Vector2i(2, 0), Vector2i(1, 1), Vector2i(3, 1), Vector2i(0, 2), Vector2i(4, 2), Vector2i(2, 2),
			Vector2i(2, 3), Vector2i(0, 4), Vector2i(4, 4), Vector2i(2, 4), Vector2i(1, 5), Vector2i(3, 5), Vector2i(2, 6)]:
		img.set_pixelv(p, RUNE_COLOR)
	var rune := Sprite2D.new()
	rune.name = "Rune"
	rune.texture = ImageTexture.create_from_image(img)
	rune.position = Vector2(0, -6)
	rune.modulate = Color(1.3, 1.3, 1.3)   # tegen de tint in: de rune blijft fel
	visual.add_child(rune)


## Wordt aangeroepen door player.gd als de speler ertegenaan loopt.
func bump(player: Node2D) -> void:
	if room:
		room.request_push(self, player)


## Na een gelukte duw: node + botsing meteen naar de nieuwe tile, plaatje glijdt mee.
func slide_to(t: Vector2i, dir: Vector2i, duration: float) -> void:
	tile = t
	position = Vector2(t) * 16 + Vector2(8, 8)
	if _tween:
		_tween.kill()
	visual.position = Vector2(-dir * 16)
	_tween = create_tween()
	_tween.tween_property(visual, "position", Vector2.ZERO, duration)


## Direct op een tile (herstellen / terugkomen).
func snap_to(t: Vector2i) -> void:
	if _tween:
		_tween.kill()
	tile = t
	position = Vector2(t) * 16 + Vector2(8, 8)
	visual.position = Vector2.ZERO


func is_sliding() -> bool:
	return _tween != null and _tween.is_running()
