extends RefCounted
## Wereldkaart-ingang. Met de vlag uit keert dit meteen terug: geen node, geen art-load.
## Plek en unlock (na Vesper) zijn nog open. Tot die keuze staat de tegel hier.

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const Art := preload("res://scripts/data/arena_art.gd")

const EXIT_NAME := "NaarArena"
const MARKER_NAME := "ArenaMarker"
const LOBBY := "res://scenes/arena/arena_lobby.tscn"
## PLACEHOLDER tegel tot Dennis de plek tussen Vesper en de grot kiest.
const TILE := Vector2i(34, 21)


static func consider(map: Node2D) -> void:
	if not ReleaseFlags.arena_enabled():
		return
	var exits := map.get_node_or_null("Exits")
	if exits == null or exits.get_node_or_null(EXIT_NAME) != null:
		return
	var gate := MapExit.new()
	gate.name = EXIT_NAME
	gate.position = Vector2(TILE) * 16.0
	gate.size_tiles = Vector2i(1, 1)
	gate.target_map = LOBBY
	gate.target_spawn = "ingang"
	exits.add_child(gate)
	_marker(map)


static func _marker(map: Node2D) -> void:
	var objects := map.get_node_or_null("Objects")
	if objects == null or objects.get_node_or_null(MARKER_NAME) != null:
		return
	var spr := Sprite2D.new()
	spr.name = MARKER_NAME
	spr.position = Vector2(TILE) * 16.0 + Vector2(16, 16)
	var tex := Art.world_texture()
	if tex != null:
		spr.texture = tex
	else:
		# Geen bestand: magenta vlak, 32x32, tot RPG ART wereld_v18_arena.png levert.
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 1, 1))
		spr.texture = ImageTexture.create_from_image(img)
	objects.add_child(spr)
