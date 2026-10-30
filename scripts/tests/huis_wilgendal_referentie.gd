extends RefCounted
## Vastgezette main-renderer (losse TileSet-bronnen + Sprite2D) voor pixel-regressie.

const Build := preload("res://scripts/data/huis_interieur_build.gd")
const TILE_DIR := "res://assets/tiles/huis_interieur/"


static func bouw_statisch(wortel: Node2D) -> void:
	var data: Dictionary = Build.laad()
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wortel.add_child(ground)
	var details := Node2D.new()
	details.name = "Details"
	wortel.add_child(details)
	wortel.move_child(details, ground.get_index())
	var objects := Node2D.new()
	objects.name = "Objects"
	objects.y_sort_enabled = true
	wortel.add_child(objects)
	var tile_ids: Dictionary = {}
	ground.tile_set = _maak_tileset(tile_ids)
	_teken_grid(ground, data.get("grid", []) as Array, tile_ids)
	_teken_details(details, data.get("details", []) as Array)
	_plaats_props(objects, data.get("props", []) as Array)


static func _maak_tileset(tile_ids: Dictionary) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)
	var defs := {
		"wall_cap": {"file": "wall_cap.png", "solid": true},
		"wall_face_top": {"file": "wall_face_top.png", "solid": true},
		"wall_face_bottom": {"file": "wall_face_bottom.png", "solid": true},
		"wall_post": {"file": "wall_post_bottom.png", "solid": true},
		"floor_a": {"file": "floor_a.png", "solid": false},
		"floor_b": {"file": "floor_b.png", "solid": false},
		"floor_c": {"file": "floor_c.png", "solid": false},
		"floor_d": {"file": "floor_d.png", "solid": false},
		"floor_e": {"file": "floor_e.png", "solid": false},
	}
	for sleutel in defs.keys():
		var tex: Texture2D = load(TILE_DIR + str(defs[sleutel]["file"]))
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(16, 16)
		src.use_texture_padding = false
		src.create_tile(Vector2i.ZERO)
		if defs[sleutel]["solid"]:
			var td: TileData = src.get_tile_data(Vector2i.ZERO, 0)
			if td != null:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
				]))
		var sid: int = ts.add_source(src)
		tile_ids[sleutel] = sid
	return ts


static func _teken_grid(ground: TileMapLayer, rijen: Array, tile_ids: Dictionary) -> void:
	for y in rijen.size():
		var rij: String = str(rijen[y])
		for x in mini(rij.length(), Build.MAP_SIZE.x):
			var ch := rij[x]
			var sleutel := _tegel_sleutel(ch, x, y, rijen)
			if sleutel == "":
				continue
			var sid: int = int(tile_ids.get(sleutel, -1))
			if sid < 0:
				continue
			ground.set_cell(Vector2i(x, y), sid, Vector2i.ZERO)


static func _tegel_sleutel(ch: String, x: int, y: int, rijen: Array) -> String:
	match ch:
		"#":
			return "wall_cap"
		"F":
			if y + 1 < rijen.size() and str(rijen[y + 1])[x] in ".dEX":
				return "wall_face_top"
			return "wall_face_bottom"
		"J":
			return "wall_post"
		"d", "E", "S", "X", ".":
			var variant := ["floor_a", "floor_b", "floor_c", "floor_d", "floor_e"]
			return variant[(x + y * 3) % variant.size()]
		_:
			return ""


static func _teken_details(details: Node2D, lijst: Array) -> void:
	for item in lijst:
		if not (item is Array) or item.size() < 3:
			continue
		var naam: String = str(item[0])
		var tegel := Vector2i(int(item[1]), int(item[2]))
		var tex: Texture2D = load(TILE_DIR + naam + ".png")
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.position = Vector2(tegel) * 16.0
		spr.z_index = -1
		details.add_child(spr)


static func _plaats_props(objects: Node2D, props: Array) -> void:
	for raw in props:
		if not (raw is Array) or raw.size() < 7:
			continue
		var naam: String = str(raw[0])
		var tx: int = int(raw[1])
		var ty: int = int(raw[2])
		var dx: int = int(raw[5])
		var dy: int = int(raw[6])
		var tex := Build.prop_texture(naam)
		if tex == null:
			continue
		var node := Node2D.new()
		node.position = Vector2(tx, ty) * 16.0 + Vector2(dx, dy)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		if naam == "keuken_fornuis_gloed":
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, 24, 8)
		node.add_child(spr)
		objects.add_child(node)
