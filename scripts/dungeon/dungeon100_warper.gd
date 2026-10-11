extends "res://scripts/book_point.gd"
class_name Dungeon100Warper
## WARPER van de Diepe Grot (Dungeon100Rules.WARPER_FLOORS).
## Verdieping 1 is de start: een korte uitleg, geen waarschuwing, geen verplaatsing.
## 25, 50, 75 en 99 vragen of je de dungeon verlaat. Ja gaat naar de wereldkaart bij de
## ingang. Nee of annuleren laat je staan.
##
## PLAATJE PLACEHOLDER: het opslagboek, violet getint. Geen eigen bestand.
## Zie tools/placeholders_v17.txt. Echte art: assets/sprites/dungeon100_warper.png (64x16).

const RulesC := preload("res://scripts/dungeon/dungeon100_rules.gd")
const SCENE := "res://scenes/dungeon100_warper.tscn"
const TINT := Color(0.78, 0.62, 1.0)

## Voor de tests: "" | "start" | "cancelled" | "travel".
var last_dest := -1


func _init() -> void:
	type = "warper"


static func create(tile: Vector2i) -> Node2D:
	var node: Node2D = load(SCENE).instantiate()
	node.position = Vector2(tile) * 16.0 + Vector2(8, 8)
	return node


func _ready() -> void:
	super._ready()
	sprite.modulate = TINT


func interact(player: Node2D) -> void:
	if busy or Dialog.is_open:
		return
	busy = true
	player.input_locked = true
	last_result = ""
	last_dest = -1
	var here := GameState.dungeon100_floor
	GameState.dungeon100_reach_floor(here)
	if not RulesC.warper_warns(here):
		Dialog.show_lines([RulesC.GROT_INTRO])
		await Dialog.finished
		last_result = "start"
		_release(player)
		return
	var warn: int = await Dialog.ask(RulesC.WARPER_WARNING, [RulesC.WARPER_YES, RulesC.WARPER_NO])
	if warn != 0:
		last_result = "cancelled"
		_release(player)
		return
	last_result = "travel"
	last_dest = 0
	_release(player)
	GameState.dungeon100_warper_exit()


func _release(player: Node2D) -> void:
	busy = false
	if is_instance_valid(player):
		player.input_locked = false
