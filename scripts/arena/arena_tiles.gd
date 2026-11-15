extends RefCounted
## TileSet voor assets/tiles/arena/arena_tiles.png (16x16, 16 kolommen x 7 rijen).
## Index in layouts.json = y * 16 + x.

const PATH := "res://assets/tiles/arena/arena_tiles.png"
const COLS := 16
const ROWS := 7

static var _ts: TileSet


static func tileset() -> TileSet:
	if _ts != null:
		return _ts
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var tex := load(PATH) as Texture2D
	if tex == null:
		_ts = ts
		return ts
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	for y in ROWS:
		for x in COLS:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	_ts = ts
	return ts
