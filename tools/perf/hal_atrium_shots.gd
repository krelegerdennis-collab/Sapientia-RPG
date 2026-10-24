extends Node
## Headless screenshots van de World Warper-hal (Atrium) voor visuele vergelijking.
## Start: godot --rendering-driver opengl3 --path . res://tools/perf/hal_atrium_shots.tscn -- --shots=/pad [--label=voor]
## Schrijft hal_atrium_<label>_<stand>.png (stand 0 = spawn, 1/2 = sub-pixel camerastanden).

const HAL := "res://world_warper/maps/hal.tscn"
const STEPS := [Vector2.ZERO, Vector2(37.37, 21.61), Vector2(-23.5, 40.25)]

var _shots := ""
var _label := "shot"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.get_slice("=", 1)
		elif arg.begins_with("--label="):
			_label = arg.get_slice("=", 1)
	if _shots == "":
		printerr("Geef --shots=/pad")
		get_tree().quit(2)
		return
	GameState.new_game("Dax")
	GameState.story_flags["cutscene_wereldkaart_gezien"] = true
	Crt.set_enabled(false)
	var packed := GameState.get_resource(HAL) as PackedScene
	var kaart := packed.instantiate()
	get_tree().root.add_child(kaart)
	get_tree().current_scene = kaart
	var speler := kaart.get_node_or_null("Objects/Player") as Node2D
	var start := speler.position if speler != null else Vector2.ZERO
	get_window().size = Vector2i(1152, 648)
	DirAccess.make_dir_recursive_absolute(_shots)
	for i in STEPS.size():
		if speler != null:
			speler.position = start + STEPS[i]
		for _f in 25:
			await get_tree().process_frame
		get_tree().paused = true
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		get_tree().paused = false
		var path := "%s/hal_atrium_%s_%d.png" % [_shots, _label, i]
		img.save_png(path)
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(img.get_data())
		print("SHOT %s sha=%s" % [path, ctx.finish().hex_encode()])
	get_tree().quit(0)
