extends StaticBody2D
## Simpele NPC: staat stil, draait naar de speler toe en praat.
## Pas de tekst aan in de Inspector (property "Lines").
## v0.11: met 'event' ingevuld praat hij via het verhaal (scripts/data/story_data.gd)
## in plaats van 'lines'; 'show_if' bepaalt wanneer hij er is. Cutscenes laten hem
## lopen (script_walk) en draaien (face).

@export var npc_name := "Old Man"
@export_multiline var lines: Array[String] = ["Hello!"]
@export var facing := Vector2i.DOWN
@export var event := ""
@export var event_arg := ""
@export var show_if := {}
## v0.13: eigen spritesheet (zelfde indeling als npc.png/player.png: 48x96, 3 loopframes x
## 4 richtingen: omlaag, links, rechts, omhoog). Leeg = npc.png uit de scène.
@export var sheet: Texture2D
## SoM-stijl: framemaat (16x24 oud, 24x32 nieuw). ZERO = uit de sheet afleiden.
@export var frame_maat := Vector2i.ZERO

const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const DIR_ROW := {
	Vector2i.DOWN: 0,
	Vector2i.LEFT: 1,
	Vector2i.RIGHT: 2,
	Vector2i.UP: 3,
}
const WALK_CYCLE := [1, 0, 2, 0]

@onready var sprite: Sprite2D = $Sprite2D
var _col := 0


func _ready() -> void:
	if sheet:
		sprite.texture = sheet
	MapSprite.pas_toe(sprite, frame_maat)
	add_to_group("story")
	_update_sprite()
	story_refresh()


func interact(player: Node2D) -> void:
	# Kijk de speler aan (tegenovergestelde van de kijkrichting van de speler).
	if "facing" in player:
		facing = -player.facing
		_update_sprite()
	if event == "shop" and event_arg != "":
		_open_shop(player)
		return
	if event != "" and Story.trigger(event, self, event_arg):
		return
	Dialog.show_lines(lines, npc_name, self)


func _open_shop(player: Node2D) -> void:
	if get_tree().current_scene.get_node_or_null("ShopScreen") != null:
		return
	if "input_locked" in player:
		player.input_locked = true
	var shop := ShopScreen.new()
	shop.name = "ShopScreen"
	shop.shop_id = event_arg
	shop.closed.connect(func() -> void:
		if is_instance_valid(player) and "input_locked" in player:
			player.input_locked = false
	)
	get_tree().current_scene.add_child(shop)


func story_refresh() -> void:
	if not show_if.is_empty():
		set_story_visible(Story.check(show_if, event_arg))


func set_story_visible(on: bool) -> void:
	visible = on
	collision_layer = 1 if on else 0


func face(dir: Vector2i) -> void:
	facing = dir
	_col = 0
	_update_sprite()


func get_tile() -> Vector2i:
	return Vector2i((position / 16.0).floor())


func place_at(tile: Vector2i, dir: Vector2i) -> void:
	position = Vector2(tile) * 16.0 + Vector2(8, 8)
	face(dir)


## Pose op een korte plein-lus. afstand is het aantal pixels van deze ene stap.
func loop_frame(dir: Vector2i, lopend: bool, afstand: float) -> void:
	facing = dir
	if lopend:
		_col = WALK_CYCLE[int(afstand / 8.0) % WALK_CYCLE.size()]
	else:
		_col = 0
	_update_sprite()


## Cutscene: n tiles lopen (botsing telt niet, het script kiest de route).
func script_walk(dir: Vector2i, n: int, speed := 56.0) -> void:
	facing = dir
	var dist := 0.0
	for i in n:
		var from := position
		var to := from + Vector2(dir) * 16.0
		var t := 0.0
		var dur := 16.0 / speed
		while t < dur:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			dist += speed * dt
			position = from.lerp(to, minf(t / dur, 1.0))
			_col = WALK_CYCLE[int(dist / 8.0) % WALK_CYCLE.size()]
			_update_sprite()
		position = to
	_col = 0
	_update_sprite()


func _update_sprite() -> void:
	if sprite == null:
		return
	MapSprite.zet_frame(sprite, DIR_ROW.get(facing, 0), _col)
