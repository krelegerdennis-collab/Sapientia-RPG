extends Node2D
## Test-hal voor --arenawavesfollowuptest (punt B): voldoet aan SomArenaWaves._is_hall,
## maar elke tegel is muur. Er is dus geen geldige spawntegel en er komen 0 monsters.

var room_kind := "hall"
var monsters: Array = []
var wall_calls := 0


func _init() -> void:
	var objects := Node2D.new()
	objects.name = "Objects"
	add_child(objects)
	add_to_group("arena_hall")


func is_wall(_t: Vector2i) -> bool:
	wall_calls += 1
	return true


func gate_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	return out


func map_width() -> int:
	return 6


func map_height() -> int:
	return 4
