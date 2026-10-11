extends TileMapLayer
## Grond van Dorp Wilgendal. Bestaande tegels uit dorp.tres (geen nieuwe art).
## Kolommen: 0 gras, 2 pad, 3 boom (blokkeert). Zie tools/build_maps.gd TOWN_LEGEND.

const W := 20
const H := 14


func _ready() -> void:
	for y in H:
		for x in W:
			var col := 0
			var edge := x == 0 or y == 0 or x == W - 1 or y == H - 1
			var pad := x == 10 or y == 6
			if edge and not (y == H - 1 and x >= 9 and x <= 11):
				col = 3
			elif pad and y < H - 1:
				col = 2
			elif y == H - 1 and x >= 9 and x <= 11:
				col = 2
			set_cell(Vector2i(x, y), 0, Vector2i(col, 0))
