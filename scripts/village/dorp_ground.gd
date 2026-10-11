extends Node
## Schildert het plein van Wilgendal op Ground en de vier huis-tegels op Gebouwen.
## Bestaande tegels uit dorp.tres (gras, pad, kassei, boom, huis.png). Geen nieuwe art.

const Winkels := preload("res://scripts/data/wilgendal_winkels.gd")

const _LEGEND := {".": 0, "=": 2, "T": 3, "#": 33, "h": 0}
const _GROEN := [".", "T"]


func _ready() -> void:
	var grond := get_parent().get_node("Ground") as TileMapLayer
	var gebouwen := get_parent().get_node("Gebouwen") as TileMapLayer
	var rows := Winkels.PLEIN
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			grond.set_cell(Vector2i(x, y), 0, Vector2i(_kolom(rows, x, y), 0))
	for id in Winkels.WINKELS:
		var oorsprong: Vector2i = Winkels.WINKELS[id]["oorsprong"]
		for hy in Winkels.HUIS:
			for hx in Winkels.HUIS:
				gebouwen.set_cell(oorsprong + Vector2i(hx, hy), 1, Vector2i(hx, hy))


func _kolom(rows: PackedStringArray, x: int, y: int) -> int:
	var ch := _cel(rows, x, y)
	var base: int = int(_LEGEND[ch])
	if ch == ".":
		var schaduw := 0
		if _cel(rows, x, y - 1) in ["T", "h"]:
			schaduw |= 1
		if _cel(rows, x - 1, y) in ["T", "h"]:
			schaduw |= 2
		if schaduw > 0:
			return 7 + schaduw
		return base
	if ch == "=" or ch == "#":
		var m := 0
		if _groen(_cel(rows, x, y - 1)):
			m |= 1
		if _groen(_cel(rows, x + 1, y)):
			m |= 2
		if _groen(_cel(rows, x, y + 1)):
			m |= 4
		if _groen(_cel(rows, x - 1, y)):
			m |= 8
		if m == 0:
			return base
		return (10 if ch == "=" else 33) + m
	return base


func _cel(rows: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return ""
	return rows[y][x]


func _groen(ch: String) -> bool:
	return ch in _GROEN
