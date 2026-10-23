class_name CoopAvatar
extends CharacterBody2D
## Visuele stand-in voor een remote co-op stoel (host simuleert, gasten tekenen).

var slot: int = -1
var hero_id := ""
var facing := Vector2i.DOWN
var sprite: Sprite2D


func setup(p_slot: int, p_hero_id: String, tex: Texture2D) -> void:
	slot = p_slot
	hero_id = p_hero_id
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	collision_layer = 0
	collision_mask = 0


func place(pos: Vector2, face: Vector2i) -> void:
	position = pos
	facing = face
	_update_frame()


func _update_frame() -> void:
	if sprite == null or sprite.texture == null:
		return
	var hf := maxi(1, sprite.texture.get_width() / 4)
	var vf := maxi(1, sprite.texture.get_height() / 4)
	sprite.hframes = 4
	sprite.vframes = vf
	var col := 1
	if facing.x > 0:
		col = 2
	elif facing.x < 0:
		col = 0
	elif facing.y > 0:
		col = 3
	sprite.frame = col
