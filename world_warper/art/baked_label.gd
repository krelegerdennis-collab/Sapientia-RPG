class_name WarperBakedLabel
extends RefCounted
## Tekent een Label één keer naar een ImageTexture (nearest) = één draw call i.p.v. per glyph.


static func maak_sprite(host: Node, grootte: Vector2, positie: Vector2, setup: Callable) -> Sprite2D:
	var lbl: Label = Label.new()
	setup.call(lbl)
	lbl.size = grootte
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(maxi(1, int(grootte.x)), maxi(1, int(grootte.y)))
	vp.transparent_bg = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.add_child(lbl)
	host.add_child(vp)
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	host.remove_child(vp)
	vp.queue_free()
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.position = positie
	return spr
