class_name CoopAvatar
extends CharacterBody2D
## Visuele stand-in voor een remote co-op stoel (host simuleert, gasten tekenen).

const MapSprite := preload("res://scripts/map_sprite.gd")

const DIR_ROW := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}

var slot: int = -1
var hero_id := ""
var facing := Vector2i.DOWN
var sprite: Sprite2D


func setup(p_slot: int, p_hero_id: String, tex: Texture2D) -> void:
	slot = p_slot
	hero_id = p_hero_id
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	sprite.texture = tex
	MapSprite.pas_toe(sprite)
	collision_layer = 0
	collision_mask = 0
	_update_frame()


func place(pos: Vector2, face: Vector2i) -> void:
	position = pos
	facing = face
	_update_frame()


func _update_frame() -> void:
	if sprite == null or sprite.texture == null:
		return
	var rij: int = int(DIR_ROW.get(facing, 0))
	MapSprite.zet_frame(sprite, rij, 1)
