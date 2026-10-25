@tool
class_name WorldWarperLockedExit
extends Node2D
## Deur naar een World Warper-kamer die dicht kan zitten.
##
## map.gd loopt elke node onder Exits af. target_map en lines blijven leeg,
## zodat map.gd zelf geen map wisselt en geen tekst toont. Deze deur doet dat:
## dicht = Nederlandse melding, open = GameState.change_map.
##
## TODO(design): één vaste melding, zonder spreker en zonder tekst per kamer.
## TODO(design): de tegel buiten de kaart is een onzichtbare blokkade, zodat een
## dichte deur niet de leegte in loopt. De speler wisselt vanaf de deurtegel.

const Rooms := preload("res://world_warper/data/rooms.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const TILE := 16
const GESLOTEN := "This room is still closed."

## Leeg laten: map.gd mag deze deur niet zelf afhandelen.
var target_map := ""
var target_spawn := ""
var lines: Array[String] = []
var event := ""

@export var size_tiles := Vector2i.ONE:
	set(value):
		size_tiles = value
		queue_redraw()
@export var room_id := ""
@export_file("*.tscn") var destination := ""
@export var destination_spawn := "ingang"
## Tegelrichting van de onzichtbare blokkade, buiten de deurtegel. (0, 0) = geen.
@export var blokkeer := Vector2i.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_plaats_blokkade()
	var player := _player()
	if player != null and player.has_signal("stepped"):
		var stap: Signal = player.stepped
		if not stap.is_connected(_on_player_stepped):
			stap.connect(_on_player_stepped)


func tile_rect() -> Rect2i:
	return Rect2i(Vector2i((position / float(TILE)).floor()), size_tiles)


func contains(tile: Vector2i) -> bool:
	return tile_rect().has_point(tile)


func _on_player_stepped(tile: Vector2i) -> void:
	if not contains(tile):
		return
	if GameState.changing_map or GameState.in_battle:
		return
	if ReleaseFlags.hub_niche_cut(room_id) or not Rooms.is_open(room_id, GameState.story_flags):
		if not Dialog.is_open:
			Dialog.show_lines([GESLOTEN], "")
		return
	if destination == "":
		return
	var player := _player()
	if player != null and "input_locked" in player:
		player.input_locked = true
	GameState.change_map(destination, destination_spawn)


func _plaats_blokkade() -> void:
	if blokkeer == Vector2i.ZERO:
		return
	var body := StaticBody2D.new()
	body.name = "Blokkade"
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = Vector2(blokkeer) * float(TILE) + Vector2(size_tiles) * (float(TILE) * 0.5)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_tiles) * float(TILE)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _player() -> Node:
	var room := _room()
	if room == null:
		return null
	return room.get_node_or_null("Objects/Player")


func _room() -> Node:
	var exits := get_parent()
	if exits == null:
		return null
	return exits.get_parent()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(Vector2.ZERO, Vector2(size_tiles * TILE))
	draw_rect(rect, Color(0.9, 0.15, 0.2, 0.35))
	draw_rect(rect, Color(0.9, 0.15, 0.2, 0.9), false, 1.0)
