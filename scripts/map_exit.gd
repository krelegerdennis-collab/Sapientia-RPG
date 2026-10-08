@tool
class_name MapExit
extends Node2D
## Uitgang-zone op een map. Zet de node met zijn linkerbovenhoek op een tile
## (positie = veelvoud van 16) en kies hoe groot de zone is (in tiles).
## Stapt de speler erop:
##   - target_map ingevuld  -> fade naar die map, speler op spawnpunt target_spawn
##   - anders, lines ingevuld -> alleen een bericht (bv. "de dungeon komt later")
##   - v0.11: event ingevuld -> eerst het verhaal (Story.trigger)
## In de editor zie je de zone als roze vlak.

@export var size_tiles := Vector2i.ONE:
	set(value):
		size_tiles = value
		queue_redraw()
@export_file("*.tscn") var target_map := ""
## Naam van een MapSpawn-node in de doel-map (onder "Spawns").
@export var target_spawn := ""
@export_multiline var lines: Array[String] = []
## v0.11: verhaal-event dat eerst mag reageren (bv. "niet vandaag" / "op slot");
## geeft het event "default", dan werkt de uitgang gewoon.
@export var event := ""


func tile_rect() -> Rect2i:
	return Rect2i(Vector2i((position / 16.0).floor()), size_tiles)


func contains(tile: Vector2i) -> bool:
	return tile_rect().has_point(tile)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(size_tiles * 16)), Color(1, 0.3, 0.9, 0.35))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size_tiles * 16)), Color(1, 0.3, 0.9, 0.9), false, 1.0)
