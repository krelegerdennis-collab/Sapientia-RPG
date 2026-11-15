extends RefCounted
## Wereldkaart-ingang. Met de vlag uit keert dit meteen terug: geen node, geen art-load.
## Plek: Art.WORLD_TILE, 2x2. Spawn van_wilgendal (30,25) blijft vrij.
## De uitgang naar de lobby werkt alleen met noor_lid. Anders: "The gate is closed."

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const Art := preload("res://scripts/data/arena_art.gd")

const EXIT_NAME := "NaarArena"
const OVERLAY_NAME := "ArenaOverlay"
const LOBBY := "res://scenes/arena/arena_lobby.tscn"
const CLOSED := "The gate is closed."
const OPEN := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

static var _world_ts: TileSet


static func consider(map: Node2D) -> void:
	if not ReleaseFlags.arena_enabled():
		return
	_ensure_overlay(map)
	_ensure_exit(map)
	refresh(map)


static func refresh(map: Node2D) -> void:
	if map == null or not ReleaseFlags.arena_enabled():
		return
	var layer := map.get_node_or_null(OVERLAY_NAME) as TileMapLayer
	if layer != null and layer.tile_set != null:
		var site := _site()
		for i in site.size():
			layer.set_cell(site[i], 0, OPEN[i])
	var gate := map.get_node_or_null("Exits/" + EXIT_NAME) as MapExit
	if gate == null:
		return
	if Story.has_flag("noor_lid"):
		gate.target_map = LOBBY
		gate.target_spawn = "ingang"
		var empty: Array[String] = []
		gate.lines = empty
	else:
		gate.target_map = ""
		gate.target_spawn = ""
		var closed: Array[String] = [CLOSED]
		gate.lines = closed


static func _ensure_overlay(map: Node2D) -> void:
	if map.get_node_or_null(OVERLAY_NAME) != null:
		return
	var tex := Art.world_texture()
	if tex == null:
		return
	var layer := TileMapLayer.new()
	layer.name = OVERLAY_NAME
	layer.tile_set = _tileset(tex)
	var ground := map.get_node_or_null("Ground")
	if ground != null:
		ground.add_sibling(layer)
	else:
		map.add_child(layer)


static func _ensure_exit(map: Node2D) -> void:
	var exits := map.get_node_or_null("Exits")
	if exits == null or exits.get_node_or_null(EXIT_NAME) != null:
		return
	var gate := MapExit.new()
	gate.name = EXIT_NAME
	gate.position = Vector2(Art.WORLD_TILE) * 16.0
	gate.size_tiles = Vector2i(2, 2)
	exits.add_child(gate)


static func _site() -> Array[Vector2i]:
	var t := Art.WORLD_TILE
	var out: Array[Vector2i] = []
	out.append(t)
	out.append(t + Vector2i(1, 0))
	out.append(t + Vector2i(0, 1))
	out.append(t + Vector2i(1, 1))
	return out


static func _tileset(tex: Texture2D) -> TileSet:
	if _world_ts != null:
		return _world_ts
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
		src.create_tile(c)
	ts.add_source(src, 0)
	_world_ts = ts
	return ts
