extends RefCounted
## Houdt de run vast aan GameState zodat een kaartwissel hem niet weggooit.
## Geen autoload: de node bestaat alleen als de poort echt opengaat.

const RunScript := preload("res://scripts/arena/arena_run.gd")


static func ensure() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var n := gs.get_node_or_null("ArenaRun")
	if n != null:
		return n
	n = RunScript.new()
	n.name = "ArenaRun"
	gs.add_child(n)
	return n
