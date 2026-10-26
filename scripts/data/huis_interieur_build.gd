extends RefCounted
## Bouwt het Wachtershuis uit scripts/data/huis_interieur_layout.json (ART, 32x21).
## Eén gedeelde atlas voor grond/decor/props → weinig draw calls (TileMap-batching).

const LAYOUT_PATH := "res://scripts/data/huis_interieur_layout.json"
const TILE_DIR := "res://assets/tiles/huis_interieur/"
const BINNEN_DIR := "res://assets/sprites/binnen/"
const PROP_DIR := "res://assets/sprites/binnen/huis_props/"
const Atlas := preload("res://scripts/data/huis_interieur_atlas.gd")

const PUZZLE_BINNEN_SPAWN := Vector2i(4, 7)
const ARCHIEF_TEST_MAP := "res://scenes/maps/archief_test.tscn"

const MAP_SIZE := Vector2i(32, 21)
const ROOM_PX := Vector2i(512, 336)
const VP_16_9 := Vector2i(384, 216)
const VP_195_9 := Vector2i(468, 216)

const SPAWN_TEGEL := Vector2i(8, 18)
const EXIT_RECT := Rect2i(8, 19, 2, 2)

const GROND_SLEUTELS := [
	"wall_cap", "wall_face_top", "wall_face_bottom", "wall_post",
	"floor_a", "floor_b", "floor_c", "floor_d", "floor_e",
]
const DETAIL_SLEUTELS := ["detail_knot", "detail_scuff", "detail_crumbs"]

var _tile_ids: Dictionary = {}  # sleutel -> atlas_coords Vector2i
var _prop_tile: Dictionary = {}  # prop instance key -> atlas_coords
var _prop_blocks: Dictionary = {}
var _solid_tiles: Dictionary = {}
var _props_geplaatst: Array = []
var _ground_ts: TileSet
var _ground_source_id: int = -1
var _props_ts: TileSet
var _props_source_id: int = -1


static func laad() -> Dictionary:
	var txt: String = FileAccess.get_file_as_string(LAYOUT_PATH)
	return JSON.parse_string(txt) as Dictionary


static func prop_texture(naam: String) -> Texture2D:
	for root: String in [BINNEN_DIR, PROP_DIR]:
		var pad: String = root + naam + ".png"
		if ResourceLoader.exists(pad):
			return load(pad) as Texture2D
	return null


func bouw(ground: TileMapLayer, decor: TileMapLayer, props_layer: TileMapLayer, objects: Node2D) -> void:
	var data: Dictionary = laad()
	_tile_ids.clear()
	_prop_tile.clear()
	_prop_blocks.clear()
	_solid_tiles.clear()
	_props_geplaatst.clear()
	_ground_ts = _maak_grond_tileset()
	ground.tile_set = _ground_ts
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.tile_set = _ground_ts
	decor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.z_index = -2
	_teken_grid(ground, data.get("grid", []) as Array)
	_teken_details(decor, data.get("details", []) as Array)
	_props_ts = _maak_props_tileset(data.get("props", []) as Array)
	props_layer.tile_set = _props_ts
	props_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	props_layer.collision_enabled = false
	props_layer.y_sort_enabled = true
	props_layer.z_index = 0
	_plaats_props(props_layer, objects, data.get("props", []) as Array)


func _maak_grond_tileset() -> TileSet:
	var tegels: Dictionary = Atlas.bouw_grond_tegels()
	var volgorde: Array = GROND_SLEUTELS + DETAIL_SLEUTELS
	var atlas_w: int = volgorde.size() * 16
	var img := Image.create(atlas_w, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var idx := 0
	for sleutel in volgorde:
		var t: Texture2D = tegels[sleutel] as Texture2D
		if t != null:
			var ti: Image = t.get_image()
			if ti != null and not ti.is_empty():
				img.blit_rect(ti, Rect2i(0, 0, 16, 16), Vector2i(idx * 16, 0))
		_tile_ids[sleutel] = Vector2i(idx, 0)
		idx += 1
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	src.use_texture_padding = false
	_ground_source_id = ts.add_source(src)
	for sleutel in volgorde:
		var ac: Vector2i = _atlas_coords(sleutel)
		src.create_tile(ac)
		if sleutel in GROND_SLEUTELS and sleutel.begins_with("wall"):
			var td: TileData = src.get_tile_data(ac, 0)
			if td != null:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
				]))
	return ts


func _maak_props_tileset(props: Array) -> TileSet:
	const SLOT := 64
	var entries: Array = []
	for raw in props:
		if not (raw is Array) or raw.size() < 7:
			continue
		var naam: String = str(raw[0])
		var tex := prop_texture(naam)
		if tex == null:
			continue
		var key := "%s_%d_%d" % [naam, int(raw[1]), int(raw[2])]
		entries.append({"key": key, "naam": naam, "tex": tex, "w": int(raw[3]), "h": int(raw[4])})
	if entries.is_empty():
		return TileSet.new()
	var cols: int = int(ceil(sqrt(float(entries.size()))))
	var rows: int = int(ceil(float(entries.size()) / float(cols)))
	var atlas_w: int = cols * SLOT
	var atlas_h: int = rows * SLOT
	var img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var idx := 0
	for e in entries:
		var t: Texture2D = e["tex"] as Texture2D
		var ti: Image = t.get_image()
		if ti == null or ti.is_empty():
			idx += 1
			continue
		var sub := Rect2i(0, 0, ti.get_width(), ti.get_height())
		if str(e["naam"]) == "keuken_fornuis_gloed":
			sub = Rect2i(0, 0, 24, 8)
		var col: int = idx % cols
		var row: int = idx / cols
		var ox: int = col * SLOT
		var oy: int = row * SLOT
		img.blit_rect(ti, sub, Vector2i(ox, oy))
		_prop_tile[str(e["key"])] = Vector2i(col, row)
		idx += 1
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(SLOT, SLOT)
	src.use_texture_padding = false
	_props_source_id = ts.add_source(src)
	for e in entries:
		var ac: Vector2i = _prop_tile.get(str(e["key"]), Vector2i(-1, -1)) as Vector2i
		if ac.x < 0:
			continue
		src.create_tile(ac)
		var td: TileData = src.get_tile_data(ac, 0)
		if td != null:
			td.set_y_sort_origin(int(e["h"]))
	return ts


func _atlas_coords(sleutel: String) -> Vector2i:
	return _tile_ids.get(sleutel, Vector2i(-1, -1)) as Vector2i


func _teken_grid(ground: TileMapLayer, rijen: Array) -> void:
	for y in rijen.size():
		var rij: String = str(rijen[y])
		for x in mini(rij.length(), MAP_SIZE.x):
			var ch := rij[x]
			var sleutel := _tegel_sleutel(ch, x, y, rijen)
			if sleutel == "":
				continue
			var ac: Vector2i = _atlas_coords(sleutel)
			if ac.x < 0:
				continue
			var tegel := Vector2i(x, y)
			ground.set_cell(tegel, _ground_source_id, ac)
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


func _teken_details(decor: TileMapLayer, lijst: Array) -> void:
	for item in lijst:
		if not (item is Array) or item.size() < 3:
			continue
		var naam: String = str(item[0])
		var tegel := Vector2i(int(item[1]), int(item[2]))
		var ac: Vector2i = _atlas_coords(naam)
		if ac.x < 0:
			continue
		decor.set_cell(tegel, _ground_source_id, ac)


func _plaats_props(props_layer: TileMapLayer, objects: Node2D, props: Array) -> void:
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
		var key := "%s_%d_%d" % [naam, tx, ty]
		var ac: Vector2i = _prop_tile.get(key, Vector2i(-1, -1)) as Vector2i
		if ac.x < 0:
			continue
		var anchor := Vector2i(tx, ty)
		props_layer.set_cell(anchor, _props_source_id, ac)
		var td: TileData = props_layer.get_cell_tile_data(anchor)
		if td != null:
			td.texture_origin = Vector2i(dx, dy)
			td.set_y_sort_origin(h)
		var top_left := Vector2(tx, ty) * 16.0 + Vector2(dx, dy)
		var node := Node2D.new()
		node.name = "%s_%d_%d" % [naam, tx, ty]
		node.position = top_left
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
