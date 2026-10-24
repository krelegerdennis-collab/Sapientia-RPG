extends SceneTree
## -s-entrypoint (Godot eist hier SceneTree of MainLoop). Laadt de meting pas als de
## project-autoload (GameState) er is. Zie wm1_sim.gd.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/wm1balans/wm1_main.gd -- \
##       [--seed=N] [--fights=N] [--only=id,id]


func _initialize() -> void:
	var sim: Node = load("res://tools/wm1balans/wm1_sim.gd").new()
	sim.name = "Wm1Sim"
	root.add_child(sim)
