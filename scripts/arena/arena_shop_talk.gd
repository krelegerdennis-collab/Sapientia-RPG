extends Area2D
## Stuurt A (player._try_interact) door naar de winkelier (parent).


func interact(player: Node2D) -> void:
	var npc := get_parent()
	if npc != null and npc.has_method("interact"):
		npc.interact(player)
