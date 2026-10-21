extends SceneTree
## Hele kaart als PNG (voor voor/na-vergelijkingen bij het 1.4x-schalen). Geen test.
## Gebruik: xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/som/kaart_shots.gd -- --uit=/map kaart1.tscn kaart2.tscn
## Kaartnamen zonder pad = res://scenes/maps/<naam>.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var uit := "/tmp/kaart_shots"
	var kaarten: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uit="):
			uit = a.get_slice("=", 1)
		elif a.ends_with(".tscn"):
			kaarten.append(a if a.begins_with("res://") else "res://scenes/maps/" + a)
	DirAccess.make_dir_recursive_absolute(uit)
	for pad in kaarten:
		var vp := SubViewport.new()
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(vp)
		var kaart: Node = (load(pad) as PackedScene).instantiate()
		vp.add_child(kaart)
		for i in 20:
			await process_frame
		var grond: TileMapLayer = kaart.get_node_or_null("Ground")
		var r := grond.get_used_rect() if grond else Rect2i(0, 0, 24, 14)
		vp.size = Vector2i(r.size * 16)
		for n in kaart.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		var cam := Camera2D.new()
		cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		cam.position = Vector2(r.position * 16)
		cam.limit_left = -100000
		cam.limit_top = -100000
		cam.limit_right = 100000
		cam.limit_bottom = 100000
		kaart.add_child(cam)
		cam.make_current()
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var naam := pad.get_file().get_basename()
		img.save_png(uit.path_join(naam + ".png"))
		print("SHOT ", naam, " ", r.size)
		vp.queue_free()
		await process_frame
		var gs := root.get_node_or_null("GameState")
		if gs:
			gs.changing_map = false
	quit(0)
