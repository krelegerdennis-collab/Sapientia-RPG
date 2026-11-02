class_name WorldWarperOpeningEcho
extends RefCounted
## ECHO in story-only modus: beschadigd geheugen, korte missie-uitleg (geen H-6 / Hanger / proefpersoon).

const EchoGlitch := preload("res://world_warper/opening/echo_glitch.gd")

const NAAM := "ECHO"

const REGELS: Array[String] = [
	"Signal unstable. Can you hear me, Dax?",
	"I am ECHO. Or what remains of me.",
	"Memory sectors are corrupted. Ignore the gaps.",
	"You are aboard the World Warper.",
	"Sapientia seeks every Archive. All six cores.",
	"We drift between worlds so she cannot take them all.",
	"Your work begins where the Watcher waits.",
	"I will send you there now. Stay alive.",
]


static func speel(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	await host.get_tree().process_frame
	var map := _hal(host)
	if map == null:
		return
	var player := map.get_node_or_null("Objects/Player")
	if player != null and "input_locked" in player:
		player.input_locked = true
	var gids := map.find_child("Gids", true, false) as Node2D
	var glitch: OpeningEchoGlitch = null
	if gids != null:
		glitch = EchoGlitch.new()
		glitch.attach(gids)
	Dialog.show_lines(REGELS, NAAM)
	await Dialog.finished
	if glitch != null:
		glitch.detach()
	if is_instance_valid(player) and "input_locked" in player and not GameState.changing_map:
		player.input_locked = false


static func _hal(_host: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var cur := tree.current_scene
	if cur != null and str(cur.scene_file_path).ends_with("world_warper/maps/hal.tscn"):
		return cur
	return null

