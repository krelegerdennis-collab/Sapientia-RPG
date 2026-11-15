extends "res://scripts/npc.gd"
## Winkelier in de lobby. Bestaande npc-sheet tot de arena-koopman er is.

const Art := preload("res://scripts/data/arena_art.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const ArenaShopUi := preload("res://scripts/arena/arena_shop_screen.gd")


func _ready() -> void:
	super._ready()
	if not ReleaseFlags.arena_enabled():
		return
	var tex := Art.npc_texture()
	if tex == null or sprite == null:
		return
	sheet = tex
	sprite.texture = tex
	MapSprite.pas_toe(sprite, frame_maat)
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
