extends "res://scripts/npc.gd"
## Quartermaster. Loopblad en idle-blad via het directe pad (niet via KaartStijl).
## Loop: 72x128, 3x4 van 24x32, WALK_CYCLE van npc.gd. Idle: 48x128, 2x4, 600 ms.

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const ArenaShopUi := preload("res://scripts/arena/arena_shop_screen.gd")

const WALK_PATH := "res://assets/sprites/npc/arena_koopman_wm1_slim.png"
const IDLE_PATH := "res://assets/sprites/npc/arena_koopman_wm1_slim_idle.png"
const IDLE_MS := 0.6
const FRAME := Vector2i(24, 32)

var _walk_tex: Texture2D
var _idle_tex: Texture2D
var _idle_frame := 0
var _idle_acc := 0.0
var _stepping := false


func _ready() -> void:
	_walk_tex = load(WALK_PATH) as Texture2D
	_idle_tex = load(IDLE_PATH) as Texture2D
	if _walk_tex != null:
		sheet = _walk_tex
		frame_maat = FRAME
	super._ready()
	_fit_feet()
	_update_sprite()


func _process(delta: float) -> void:
	if _stepping or _idle_tex == null or sprite == null or sprite.texture != _idle_tex:
		return
	_idle_acc += delta
	if _idle_acc < IDLE_MS:
		return
	_idle_acc = 0.0
	_idle_frame = 1 - _idle_frame
	_update_sprite()


func interact(player: Node2D) -> void:
	if "facing" in player:
		facing = -player.facing
		_update_sprite()
	if not ReleaseFlags.arena_enabled():
		Dialog.show_lines(["The Colosseum is closed."], npc_name)
		return
	if get_tree().current_scene.get_node_or_null("ArenaShopScreen") != null:
		return
	if "input_locked" in player:
		player.input_locked = true
	var shop := ArenaShopUi.new()
	shop.name = "ArenaShopScreen"
	shop.closed.connect(func() -> void:
		if is_instance_valid(player) and "input_locked" in player:
			player.input_locked = false
	)
	get_tree().current_scene.add_child(shop)


func script_walk(dir: Vector2i, n: int, speed := 56.0) -> void:
	_stepping = true
	await super.script_walk(dir, n, speed)
	_stepping = false
	_idle_frame = 0
	_update_sprite()


func _update_sprite() -> void:
	if sprite == null:
		return
	if _stepping and _walk_tex != null:
		sprite.texture = _walk_tex
		sprite.hframes = 3
		sprite.vframes = 4
		MapSprite.pas_toe(sprite, FRAME)
		MapSprite.zet_frame(sprite, DIR_ROW.get(facing, 0), _col)
		return
	if _idle_tex != null:
		sprite.texture = _idle_tex
		MapSprite.pas_toe(sprite, FRAME)
		MapSprite.zet_frame(sprite, DIR_ROW.get(facing, 0), _idle_frame)
		return
	super._update_sprite()


func _fit_feet() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 6)
	col.shape = shape
	col.position = Vector2(0, 5)
