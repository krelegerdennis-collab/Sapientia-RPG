class_name HuisInterieurAtlas
extends RefCounted
## Runtime-atlas voor Wachtershuis-tegels en props (één textuur → minder draw calls).

const TILE_PX := 16

var _image: Image
var _w := 0
var _h := 0
var _cursor_x := 0
var _cursor_y := 0
var _row_h := 0
var _regions: Dictionary = {}  # sleutel -> Rect2i in atlas


func _init(pad: int = 1) -> void:
	_pad = pad


var _pad: int = 1


func pack_texture(sleutel: String, tex: Texture2D, region: Rect2i = Rect2i()) -> Rect2i:
	if _regions.has(sleutel):
		return _regions[sleutel]
	if tex == null:
		return Rect2i()
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return Rect2i()
	var w: int = region.size.x if region.size.x > 0 else img.get_width()
	var h: int = region.size.y if region.size.y > 0 else img.get_height()
	var ox: int = region.position.x
	var oy: int = region.position.y
	if _cursor_x + w + _pad > _w:
		_cursor_x = 0
		_cursor_y += _row_h + _pad
		_row_h = 0
	if _image == null:
		_groeien(_cursor_x + w + _pad, _cursor_y + h + _pad)
	elif _cursor_y + h + _pad > _h:
		_groeien(_w, _cursor_y + h + _pad)
	_image.blit_rect(img, Rect2i(ox, oy, w, h), Vector2i(_cursor_x, _cursor_y))
	var reg := Rect2i(_cursor_x, _cursor_y, w, h)
	_regions[sleutel] = reg
	_cursor_x += w + _pad
	_row_h = maxi(_row_h, h)
	return reg


func _groeien(min_w: int, min_h: int) -> void:
	var nw: int = maxi(_w, min_w)
	var nh: int = maxi(_h, min_h)
	if _image == null:
		_image = Image.create(nw, nh, false, Image.FORMAT_RGBA8)
		_image.fill(Color(0, 0, 0, 0))
		_w = nw
		_h = nh
		return
	var nieuw := Image.create(nw, nh, false, Image.FORMAT_RGBA8)
	nieuw.fill(Color(0, 0, 0, 0))
	nieuw.blit_rect(_image, Rect2i(0, 0, _w, _h), Vector2i.ZERO)
	_image = nieuw
	_w = nw
	_h = nh


func maak_texture() -> Texture2D:
	if _image == null or _image.is_empty():
		return null
	_trim_transparant()
	return ImageTexture.create_from_image(_image)


func region(sleutel: String) -> Rect2i:
	return _regions.get(sleutel, Rect2i()) as Rect2i


func _trim_transparant() -> void:
	# Atlas blijft rechthoekig; geen trim nodig voor correctheid.
	pass


static func bouw_grond_tegels() -> Dictionary:
	## sleutel -> Texture2D (16x16) voor vloer/muur
	var dir := "res://assets/tiles/huis_interieur/"
	var defs := {
		"wall_cap": "wall_cap.png",
		"wall_face_top": "wall_face_top.png",
		"wall_face_bottom": "wall_face_bottom.png",
		"wall_post": "wall_post_bottom.png",
		"floor_a": "floor_a.png",
		"floor_b": "floor_b.png",
		"floor_c": "floor_c.png",
		"floor_d": "floor_d.png",
		"floor_e": "floor_e.png",
		"detail_knot": "detail_knot.png",
		"detail_scuff": "detail_scuff.png",
		"detail_crumbs": "detail_crumbs.png",
	}
	var uit: Dictionary = {}
	for k in defs:
		uit[k] = load(dir + defs[k]) as Texture2D
	return uit
