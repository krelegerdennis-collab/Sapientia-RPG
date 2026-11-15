extends RefCounted
## Wereldkaart-ingang. Met de vlag uit keert dit meteen terug: geen node, geen art-load.
## Plek: tegels (30,32)-(31,33). Spawn van_wilgendal (30,25) blijft vrij.
## De wereldkaart-uitgang is altijd open (Dennis 16:31). Het slot zit op de lobbypoort.

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const Art := preload("res://scripts/data/arena_art.gd")

const EXIT_NAME := "NaarArena"
const OVERLAY_NAME := "ArenaOverlay"
const LOBBY := "res://scenes/arena/arena_lobby.tscn"
const SITE := [Vector2i(30, 32), Vector2i(31, 32), Vector2i(30, 33), Vector2i(31, 33)]
const OPEN := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const EXIT_POS := Vector2(480, 512)

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
		for i in SITE.size():
			layer.set_cell(SITE[i], 0, OPEN[i])
	var gate := map.get_node_or_null("Exits/" + EXIT_NAME) as MapExit
	if gate == null:
		return
	gate.target_map = LOBBY
	gate.target_spawn = "ingang"
	var empty: Array[String] = []
	gate.lines = empty


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
	gate.position = EXIT_POS
	gate.size_tiles = Vector2i(2, 2)
	exits.add_child(gate)


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
