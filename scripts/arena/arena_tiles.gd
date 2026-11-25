extends RefCounted
## TileSet voor assets/tiles/arena/arena_tiles.png (16x16, 16 kolommen x 7 rijen).
## Index in layouts.json = y * 16 + x.

const PATH := "res://assets/tiles/arena/arena_tiles.png"
const COLS := 16
const ROWS := 9
## Tegel 140 (atlas 12,8) animeert met de buurkolom 141. 250 ms.
const GLITCH := Vector2i(12, 8)
## v3-vloerdecor (docs/arena/ART_README): kerb/schaduw/sleet/zand/littekens — loopbaar, geen muur.
const WALKABLE_FLOOR_DECO: Dictionary = {
	108: true, 109: true, 110: true, 111: true,
	112: true, 113: true, 114: true, 115: true, 116: true, 117: true,
	120: true, 121: true, 122: true, 123: true,
	124: true, 125: true, 126: true, 127: true,
}


static func is_walkable_floor_deco(idx: int) -> bool:
	return bool(WALKABLE_FLOOR_DECO.get(idx, false))


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
