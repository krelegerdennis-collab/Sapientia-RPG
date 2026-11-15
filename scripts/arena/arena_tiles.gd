extends RefCounted
## TileSet voor assets/tiles/arena/arena_tiles.png (16x16, 16 kolommen x 7 rijen).
## Index in layouts.json = y * 16 + x.

const PATH := "res://assets/tiles/arena/arena_tiles.png"
const COLS := 16
const ROWS := 9
## Tegel 140 (atlas 12,8) animeert met de buurkolom 141. 250 ms.
const GLITCH := Vector2i(12, 8)

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
			var c := Vector2i(x, y)
			# Kolom naast de glitch-tegel is frame 2, geen eigen tegel.
			if c == GLITCH + Vector2i(1, 0):
				continue
			src.create_tile(c)
	src.set_tile_animation_columns(GLITCH, 2)
	src.set_tile_animation_frames_count(GLITCH, 2)
	src.set_tile_animation_frame_duration(GLITCH, 0, 0.25)
	src.set_tile_animation_frame_duration(GLITCH, 1, 0.25)
	ts.add_source(src, 0)
	_ts = ts
	return ts
