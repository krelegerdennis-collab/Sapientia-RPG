extends TileMapLayer
## Grond van Dorp Wilgendal. Bestaande tegels uit dorp.tres (geen nieuwe art).
## Tekens en kolommen: scripts/data/wilgendal_dorp.gd.

const Data := preload("res://scripts/data/wilgendal_dorp.gd")


func _ready() -> void:
	for y in Data.H:
		var rij: String = Data.GROND[y]
		for x in rij.length():
			var kol: int = int(Data.TEGEL.get(rij[x], 0))
			set_cell(Vector2i(x, y), 0, Vector2i(kol, 0))
