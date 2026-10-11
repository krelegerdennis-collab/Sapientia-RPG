extends "res://scripts/story_object.gd"
## Toonbank. De speler praat hier; de winkelier staat erachter en opent de winkel.


@export var winkelier_pad: NodePath = NodePath("../Winkelier")


func interact(player: Node2D) -> void:
	if _naar_winkelier(player):
		return
	super.interact(player)


func bump(player: Node2D) -> void:
	if _naar_winkelier(player):
		return
	super.bump(player)


func _naar_winkelier(player: Node2D) -> bool:
	if Dialog.is_open:
		return true
	var winkelier := get_node_or_null(winkelier_pad)
	if winkelier != null and winkelier.has_method("interact"):
		winkelier.interact(player)
		return true
	return false
