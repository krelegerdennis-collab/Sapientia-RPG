extends StaticBody2D
## Deur van een huis. Loop ertegenaan of druk op A ervoor:
##   - target_map ingevuld (v0.10) -> korte fade naar die map, speler op target_spawn
##   - anders -> de tekst uit 'lines' (bv. "De deur is op slot.")

@export_multiline var lines: Array[String] = ["The door is locked."]
@export_file("*.tscn") var target_map := ""
## Naam van een MapSpawn-node in de doel-map (onder "Spawns").
@export var target_spawn := ""
## v0.11: verhaal-event (story_data.gd) dat eerst mag reageren (bv. "op slot").
@export var event := ""

const WorldSfx := preload("res://scripts/audio/world_sfx.gd")


func interact(player: Node2D) -> void:
	if event != "" and Story.trigger(event, self):
		return
	if target_map != "":
		_enter(player)
	else:
		WorldSfx.play(WorldSfx.DOOR_LOCKED)
		Dialog.show_lines(lines, "")


## Wordt aangeroepen door player.gd als de speler tegen de deur aan loopt.
func bump(player: Node2D) -> void:
	if event != "" and not Dialog.is_open and Story.trigger(event, self):
		return
	if target_map != "":
		_enter(player)
	elif not Dialog.is_open:
		WorldSfx.play(WorldSfx.DOOR_LOCKED)
		Dialog.show_lines(lines, "")


func _enter(player: Node2D) -> void:
	if GameState.changing_map or Dialog.is_open:
		return
	# Alleen vastzetten als de wissel echt start. Een ontbrekend of ongeldig pad
	# geeft false vóór de fade: de deur blijft dan bruikbaar (geen softlock).
	if GameState.change_map(target_map, target_spawn):
		WorldSfx.play(WorldSfx.DOOR_OPEN)
		if "input_locked" in player:
			player.input_locked = true
