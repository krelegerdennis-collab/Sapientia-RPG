extends RefCounted
## Bouwt het Wachtershuis uit scripts/data/huis_interieur_layout.json (ART, 32x21).

const LAYOUT_PATH := "res://scripts/data/huis_interieur_layout.json"
const TILE_DIR := "res://assets/tiles/huis_interieur/"
const BINNEN_DIR := "res://assets/sprites/binnen/"
const PROP_DIR := "res://assets/sprites/binnen/huis_props/"

const PUZZLE_BINNEN_SPAWN := Vector2i(4, 7)
const ARCHIEF_TEST_MAP := "res://scenes/maps/archief_test.tscn"

const MAP_SIZE := Vector2i(32, 21)
const ROOM_PX := Vector2i(512, 336)
const VP_16_9 := Vector2i(384, 216)
const VP_195_9 := Vector2i(468, 216)

const SPAWN_TEGEL := Vector2i(8, 18)
const EXIT_RECT := Rect2i(8, 19, 2, 2)

var _tile_ids: Dictionary = {}
var _prop_blocks: Dictionary = {}
var _solid_tiles: Dictionary = {}
var _props_geplaatst: Array = []


static func laad() -> Dictionary:
	var txt: String = FileAccess.get_file_as_string(LAYOUT_PATH)
	return JSON.parse_string(txt) as Dictionary


static func prop_texture(naam: String) -> Texture2D:
	for root in [BINNEN_DIR, PROP_DIR]:
		var pad := root + naam + ".png"
		if ResourceLoader.exists(pad):
			return load(pad) as Texture2D
	return null


func bouw(ground: TileMapLayer, details: Node2D, objects: Node2D) -> void:
	var data: Dictionary = laad()
	_tile_ids.clear()
	_prop_blocks.clear()
	_solid_tiles.clear()
	_props_geplaatst.clear()
	ground.tile_set = _maak_tileset()
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_teken_grid(ground, data.get("grid", []) as Array)
	_teken_details(details, data.get("details", []) as Array)
	_plaats_props(objects, data.get("props", []) as Array)


func _maak_tileset() -> TileSet:
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
		src.create_tile(Vector2i.ZERO)
		if defs[sleutel]["solid"]:
			var td: TileData = src.get_tile_data(Vector2i.ZERO, 0)
			if td != null:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
				]))
		var sid: int = ts.add_source(src)
		_tile_ids[sleutel] = sid
	return ts


func _source_id(sleutel: String) -> int:
	return int(_tile_ids.get(sleutel, -1))


func _teken_grid(ground: TileMapLayer, rijen: Array) -> void:
	for y in rijen.size():
		var rij: String = str(rijen[y])
		for x in mini(rij.length(), MAP_SIZE.x):
			var ch := rij[x]
			var sleutel := _tegel_sleutel(ch, x, y, rijen)
			if sleutel == "":
				continue
			var sid: int = _source_id(sleutel)
			if sid < 0:
				continue
			var tegel := Vector2i(x, y)
			ground.set_cell(tegel, sid, Vector2i.ZERO)
			if _tegel_is_solid(ch):
				_solid_tiles[tegel] = true


func _tegel_is_solid(ch: String) -> bool:
	return ch in ["#", "F", "J"]


func _tegel_sleutel(ch: String, x: int, y: int, rijen: Array) -> String:
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


func _teken_details(details: Node2D, lijst: Array) -> void:
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


func _plaats_props(objects: Node2D, props: Array) -> void:
	for raw in props:
		if not (raw is Array) or raw.size() < 7:
			continue
		var naam: String = str(raw[0])
		var tx: int = int(raw[1])
		var ty: int = int(raw[2])
		var w: int = int(raw[3])
		var h: int = int(raw[4])
		var dx: int = int(raw[5])
		var dy: int = int(raw[6])
		var coll: Variant = raw[7]
		var tex := prop_texture(naam)
		if tex == null:
			continue
		var top_left := Vector2(tx, ty) * 16.0 + Vector2(dx, dy)
		var node := Node2D.new()
		node.name = "%s_%d_%d" % [naam, tx, ty]
		node.position = top_left
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.position = Vector2.ZERO
		if naam == "keuken_fornuis_gloed":
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, 24, 8)
		node.add_child(spr)
		objects.add_child(node)
		var entry := {
			"name": naam,
			"tile": Vector2i(tx, ty),
			"offset": Vector2i(dx, dy),
			"size": Vector2i(w, h),
			"collision": coll,
			"node": node,
		}
		_props_geplaatst.append(entry)
		if coll is Array:
			for c in coll:
				if c is Array and c.size() >= 2:
					_prop_blocks[Vector2i(int(c[0]), int(c[1]))] = true


func prop_blocks() -> Dictionary:
	return _prop_blocks


func props_geplaatst() -> Array:
	return _props_geplaatst


static func tegel_geblokkeerd(
		ground: TileMapLayer,
		tegel: Vector2i,
		blocks: Dictionary,
		solid: Dictionary = {},
) -> bool:
	if blocks.has(tegel):
		return true
	if solid.has(tegel):
		return true
	var data: TileData = ground.get_cell_tile_data(tegel)
	if data == null:
		return true
	return data.get_collision_polygons_count(0) > 0


static func tegel_vrij(
		ground: TileMapLayer,
		tegel: Vector2i,
		blocks: Dictionary,
		solid: Dictionary = {},
) -> bool:
	if tegel.x < 0 or tegel.y < 0 or tegel.x >= MAP_SIZE.x or tegel.y >= MAP_SIZE.y:
		return false
	if ground.get_cell_source_id(tegel) == -1:
		return false
	return not tegel_geblokkeerd(ground, tegel, blocks, solid)


func solid_tiles() -> Dictionary:
	return _solid_tiles


static func dek_camera(ground: TileMapLayer, vp: Vector2i) -> bool:
	var r := Rect2i(Vector2i.ZERO, ROOM_PX)
	if r.size.x < vp.x:
		r.position.x -= (vp.x - r.size.x) / 2
		r.size.x = vp.x
	if r.size.y < vp.y:
		r.position.y -= (vp.y - r.size.y) / 2
		r.size.y = vp.y
	var t0 := Vector2i(int(floor(float(r.position.x) / 16.0)), int(floor(float(r.position.y) / 16.0)))
	var t1 := Vector2i(int(ceil(float(r.end.x) / 16.0)) - 1, int(ceil(float(r.end.y) / 16.0)) - 1)
	for y in range(t0.y, t1.y + 1):
		for x in range(t0.x, t1.x + 1):
			if ground.get_cell_source_id(Vector2i(x, y)) == -1:
				return false
	return true
