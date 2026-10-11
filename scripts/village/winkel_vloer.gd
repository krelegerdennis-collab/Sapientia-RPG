extends TileMapLayer
## Vloer van een winkel in Wilgendal. Tegels uit binnen.tres, geen nieuwe art.

const Winkels := preload("res://scripts/data/wilgendal_winkels.gd")

@export var winkel_id := "wapen"


func _ready() -> void:
	var rows: Array = Winkels.INTERIEUR[winkel_id]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			set_cell(Vector2i(x, y), 0, Vector2i(Winkels.binnen_kolom(row[x]), 0))
