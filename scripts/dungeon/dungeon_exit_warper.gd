extends "res://scripts/book_point.gd"
class_name DungeonExitWarper
## Warper die een dungeon in één stap verlaat, naar een vast punt op de wereldkaart.
## Het Eerste Archief zet er drie (begin, midden, eind). Archief 2 gebruikt dit nog niet.
##
## De Diepe Grot heeft een eigen warper (dungeon100_warper.gd) op verdieping 1, 25, 50, 75 en 99.
## Die verlaat de grot. Dit script roept hem niet aan. De uitgangen van het Eerste Archief blijven hier.
##
## PLAATJE PLACEHOLDER: het opslagboek, violet getint, hetzelfde als de grot-warper.
## Geen nieuw bestand. Echte art is nog open (universeel of per archief, TODO in de takenlijst).

const SCENE := "res://scenes/dungeon_exit_warper.tscn"
const TINT := Color(0.78, 0.62, 1.0)
const WARNING := "Weet je zeker dat je de dungeon wilt verlaten?"
const YES := "Ja, warpen naar worldmap"
const NO := "Nee, blijf in de dungeon"
const WORLD_SCENE := "res://scenes/maps/wereldkaart.tscn"
const WORLD_SPAWN := "van_archief"

## "begin", "midden" of "eind". Alleen voor tests en de naam; het gedrag is hetzelfde.
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
	sprite.modulate = TINT


func interact(player: Node2D) -> void:
	if busy or Dialog.is_open:
		return
	busy = true
	player.input_locked = true
	last_result = ""
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
