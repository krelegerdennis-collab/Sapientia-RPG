extends RefCounted
## Headless 512×336 render van statisch huis-interieur (zonder speler/UI).

const Build := preload("res://scripts/data/huis_interieur_build.gd")


static func verberg_dynamisch(wortel: Node) -> void:
	for naam in ["Void", "TouchControls", "Player", "OudeMan", "SaveBook", "Schilderij"]:
		var n: Node = wortel.find_child(naam, true, false)
		if n is CanvasItem:
			(n as CanvasItem).visible = false


static func maak_viewport(wortel: Node2D) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Build.ROOM_PX
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.add_child(wortel)
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.position = Vector2.ZERO
	wortel.add_child(cam)
	cam.make_current()
	return vp


static func render_node(wortel: Node2D, tree: SceneTree) -> Image:
	verberg_dynamisch(wortel)
	var vp := maak_viewport(wortel)
	tree.root.add_child(vp)
	for _i in 12:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var tex: Texture2D = vp.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	tree.root.remove_child(vp)
	vp.queue_free()
	return img


static func tel_pixels_verschil(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var w: int = a.get_width()
	var h: int = a.get_height()
	var diff := 0
	for y in h:
		for x in w:
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				diff += 1
	return diff
