extends Node
## Vult Ground vanuit WarperKamers.rijen. Kind van de map, dus dit loopt vóór map._ready.

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const TILESET := preload("res://world_warper/art/tiles.tres")

@export var room_id := ""


func _ready() -> void:
	var ground := get_parent().get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		return
	ground.tile_set = TILESET
	var rows := Kamers.rijen(room_id)
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			ground.set_cell(Vector2i(x, y), 0, Kamers.tegel(row.substr(x, 1)))
