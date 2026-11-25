extends Node
## Minimale kamerstub voor --perfectdodgetest (geen scène).

var room_id := "archief_v1_gang"


func tier() -> int:
	return 1


func start_invuln(_t: float) -> void:
	pass


func monster_can_enter(_m: Node, _t: Vector2i) -> String:
	return "free"