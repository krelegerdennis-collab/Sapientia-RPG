class_name HuisInterieurAtlas
extends RefCounted
## Horizontale grond-atlas (16×16 tegels) voor Wachtershuis — één textuur, minder draw calls.

const TILE_DIR := "res://assets/tiles/huis_interieur/"
const TILE_PX := 16

const GROND_BESTANDEN := {
	"wall_cap": "wall_cap.png",
	"wall_face_top": "wall_face_top.png",
	"wall_face_bottom": "wall_face_bottom.png",
	"wall_post": "wall_post_bottom.png",
	"floor_a": "floor_a.png",
	"floor_b": "floor_b.png",
	"floor_c": "floor_c.png",
	"floor_d": "floor_d.png",
	"floor_e": "floor_e.png",
}

const WALL_SLEUTELS := ["wall_cap", "wall_face_top", "wall_face_bottom", "wall_post"]


static func maak_grond_atlas(volgorde: Array) -> Dictionary:
	## texture: ImageTexture, coords: sleutel -> Vector2i atlas-coördinaten
	var atlas_w: int = volgorde.size() * TILE_PX
	var img := Image.create(atlas_w, TILE_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var coords: Dictionary = {}
	var idx := 0
	for sleutel in volgorde:
		var fname: String = str(GROND_BESTANDEN.get(sleutel, ""))
		if not fname.is_empty():
			var tex: Texture2D = load(TILE_DIR + fname) as Texture2D
			var ti: Image = _rgba8_van_texture(tex)
			if ti != null:
				img.blit_rect(ti, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i(idx * TILE_PX, 0))
		coords[sleutel] = Vector2i(idx, 0)
		idx += 1
	return {
		"texture": ImageTexture.create_from_image(img),
		"coords": coords,
	}


static func _rgba8_van_texture(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var ti: Image = tex.get_image()
	if ti == null or ti.is_empty():
		return null
	if ti.get_format() != Image.FORMAT_RGBA8:
		ti = ti.duplicate()
		ti.convert(Image.FORMAT_RGBA8)
	return ti


static func blit_texture_16(canvas: Image, tex: Texture2D, at: Vector2i) -> void:
	var ti: Image = _rgba8_van_texture(tex)
	if ti == null:
		return
	canvas.blit_rect(ti, Rect2i(0, 0, TILE_PX, TILE_PX), at)


static func voeg_wand_fysiek(td: TileData) -> void:
	if td == null:
		return
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	]))
