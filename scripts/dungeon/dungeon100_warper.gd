extends "res://scripts/book_point.gd"
class_name Dungeon100Warper
## WARPER van de Diepe Grot: één per verdieping 1, 50 en 99 (Dungeon100Rules.WARPER_FLOORS).
## A = kies een andere open warper. Vóór de sprong een waarschuwing; annuleren laat je staan.
## Een warper die je nog niet bereikt hebt, staat niet in de lijst.
##
## PLAATJE PLACEHOLDER: het opslagboek, violet getint. Geen eigen bestand.
## Zie tools/placeholders_v17.txt. Echte art: assets/sprites/dungeon100_warper.png (64x16).

const RulesC := preload("res://scripts/dungeon/dungeon100_rules.gd")
const SCENE := "res://scenes/dungeon100_warper.tscn"
const TINT := Color(0.78, 0.62, 1.0)
const CLOSED_LINE := "De andere warpers zijn nog dicht."
const PICK_QUESTION := "Kies een warper."

## Voor de tests: "" | "closed" | "cancelled" | "travel", en de gekozen verdieping.
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
	var dests: Array[int] = RulesC.warper_destinations(GameState.dungeon100_warpers, here)
	var dest := -1
	if dests.is_empty():
		Dialog.show_lines([CLOSED_LINE])
		await Dialog.finished
		last_result = "closed"
		_release(player)
		return
	if dests.size() == 1:
		dest = dests[0]
	else:
		var labels: Array = []
		for f in dests:
			labels.append("Verdieping %d" % f)
		labels.append(RulesC.WARPER_NO)
		var pick: int = await Dialog.ask(PICK_QUESTION, labels)
		if pick < 0 or pick >= dests.size():
			last_result = "cancelled"
			_release(player)
			return
		dest = dests[pick]
	# TODO(design): de zin staat in Dungeon100Rules.WARPER_WARNING.
	var warn: int = await Dialog.ask(RulesC.WARPER_WARNING, [RulesC.WARPER_YES, RulesC.WARPER_NO])
	if warn != 0:
		last_result = "cancelled"
		_release(player)
		return
	last_dest = dest
	last_result = "travel"
	_release(player)
	GameState.dungeon100_warper_go(dest)


func _release(player: Node2D) -> void:
	busy = false
	if is_instance_valid(player):
		player.input_locked = false
