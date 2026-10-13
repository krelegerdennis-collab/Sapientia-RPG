extends "res://scripts/book_point.gd"
class_name DungeonExitWarper
## Warper die een dungeon in één stap verlaat, naar een vast punt op de wereldkaart.
## Het Eerste Archief, Archief 2, het Donker Woud en de berggrot zetten er drie (begin, midden, eind).
##
## De Diepe Grot heeft een eigen warper (dungeon100_warper.gd) op verdieping 1, 25, 50, 75 en 99.
## Die verlaat de grot. Dit script roept hem niet aan. De uitgangen van het Eerste Archief blijven hier.
##
## PLAATJE PLACEHOLDER: het opslagboek, violet getint, hetzelfde als de grot-warper.
## Geen nieuw bestand. Echte art is nog open (universeel of per archief, TODO in de takenlijst).

const SCENE := "res://scenes/dungeon_exit_warper.tscn"
const TINT := Color(0.78, 0.62, 1.0)
const BOOK_TEX := "res://assets/sprites/save_book.png"
const WARNING := "Are you sure you want to leave the dungeon?"
const YES := "Yes, warp to the world map"
const NO := "No, stay in the dungeon"
const INGANG := "This is the entrance. You stay in the dungeon."
const WORLD_SCENE := "res://scenes/maps/wereldkaart.tscn"
const WORLD_SPAWN := "van_archief"

## "begin", "midden" of "eind". Begin waarschuwt niet en verlaat de dungeon niet.
var role := ""
var world_scene := WORLD_SCENE
var world_spawn := WORLD_SPAWN


func _init() -> void:
	type = "warper"


## load() en geen preload: de scène wijst terug naar dit script.
static func create(tile: Vector2i) -> Node2D:
	var node: Node2D = load(SCENE).instantiate()
	node.position = Vector2(tile) * 16.0 + Vector2(8, 8)
	return node


func _ready() -> void:
	type = "warper"
	super._ready()
	# v0.21: BookData "warper" is nu de eigen art van de Diepe Grot-warper; deze uitgang-warper
	# blijft (tot hij eigen art heeft) het violet getinte opslagboek.
	sprite.texture = load(BOOK_TEX)
	sprite.modulate = TINT


func waarschuwt() -> bool:
	return role != "begin"


func interact(player: Node2D) -> void:
	if busy or Dialog.is_open:
		return
	busy = true
	player.input_locked = true
	last_result = ""
	if not waarschuwt():
		last_result = "start"
		Dialog.show_lines([INGANG])
		await Dialog.finished
		_release(player)
		return
	var warn: int = await Dialog.ask(WARNING, [YES, NO])
	if warn != 0:
		last_result = "cancelled"
		_release(player)
		return
	last_result = "travel"
	_release(player)
	GameState.change_map(world_scene, world_spawn)


func _release(player: Node2D) -> void:
	busy = false
	if is_instance_valid(player):
		player.input_locked = false
