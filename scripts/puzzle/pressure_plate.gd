extends Node2D
## Drukplaat (geen botsing, je loopt eroverheen). Ingedrukt door een kast, of door de speler
## als hij niet 'heavy' is. Ligt in de laag PuzzleFloor (onder de speler en de kasten).
## Plaatje: assets/puzzle/drukplaat.png, 32x16 = 2 frames (0 omhoog, 1 ingedrukt).

const TEX := "res://assets/puzzle/drukplaat.png"
## v0.15: verborgen runeplaat ("hidden": true): runetegel, licht roze op als hij ingedrukt is.
## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")
const TEX_RUNE := "res://assets/puzzle/drukplaat_rune.png"

var plate_id := ""
var tile := Vector2i.ZERO
var heavy := false
var sprite: Sprite2D


func setup(id: String, t: Vector2i, p_heavy: bool, rune := false) -> void:
	plate_id = id
	name = id
	tile = t
	heavy = p_heavy
	position = Vector2(t) * 16 + Vector2(8, 8)
	sprite = Sprite2D.new()
	sprite.texture = load(DungeonRoomsTheme.themed(TEX_RUNE if rune and ResourceLoader.exists(TEX_RUNE) else TEX))
	sprite.hframes = 2
	add_child(sprite)


func set_pressed(pressed: bool) -> void:
	sprite.frame = 1 if pressed else 0
