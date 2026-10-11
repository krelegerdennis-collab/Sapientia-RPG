extends Node2D
## Deur naar een extra World Warper-kamer.
## target_map blijft leeg: map.gd wisselt deze deur niet zelf.
## Dicht = Nederlandse melding. Open = GameState.change_map.

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const TILE := 16

var target_map := ""
var target_spawn := ""
var lines: Array[String] = []
var event := ""

@export var size_tiles := Vector2i.ONE
@export var room_id := ""
@export_file("*.tscn") var destination := ""
@export var destination_spawn := "ingang"
@export var blokkeer := Vector2i.ZERO


func _ready() -> void:
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
	if not Kamers.is_open(room_id, GameState.story_flags, GameState.party):
		if not Dialog.is_open:
			Dialog.show_lines([Kamers.GESLOTEN], "")
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
