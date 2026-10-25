class_name WarperBakedLabel
extends RefCounted
## Tekent een Label één keer naar een ImageTexture (nearest) = één draw call i.p.v. per glyph.


static func maak_sprite(host: Node, grootte: Vector2, positie: Vector2, setup: Callable) -> Sprite2D:
	if host == null or not is_instance_valid(host):
		return null
	var lbl: Label = Label.new()
	setup.call(lbl)
	lbl.size = grootte
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(maxi(1, int(grootte.x)), maxi(1, int(grootte.y)))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var root_ui := Control.new()
	root_ui.custom_minimum_size = grootte
	root_ui.size = grootte
	root_ui.add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(root_ui)
	host.add_child(vp)
	var tree := host.get_tree()
	if tree == null or not is_instance_valid(host):
		_free_vp(vp)
		return null
	await tree.process_frame
	if not is_instance_valid(host) or not host.is_inside_tree():
		_free_vp(vp)
		return null
	await RenderingServer.frame_post_draw
	if not is_instance_valid(host) or not host.is_inside_tree():
		_free_vp(vp)
		return null
	var tex := vp.get_texture()
	if tex == null:
		_free_vp(vp)
		return null
	var img: Image = tex.get_image()
	if host.is_inside_tree():
		host.remove_child(vp)
	_free_vp(vp)
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.position = positie
	return spr


static func _free_vp(vp: SubViewport) -> void:
	if vp == null or not is_instance_valid(vp):
		return
	var p := vp.get_parent()
	if p != null and is_instance_valid(p):
		p.remove_child(vp)
	vp.queue_free()
