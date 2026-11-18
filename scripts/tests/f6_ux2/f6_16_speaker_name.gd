extends RefCounted
## F6-T13: als de spelernaam gelijk is aan een NPC-spreker (bv. "Old Man"), wijst de ballon
## naar de NPC, niet naar de speler. Eigen regels van de speler wijzen nog steeds naar de speler.
## Registratie: map-scan in scripts/tests/f6_ux2_tests.gd (--f6uxtest2).

const StoryData := preload("res://scripts/data/story_data.gd")
const WILGENDAL := "res://scenes/maps/wilgendal.tscn"

const GRANDPA_LINE := "Good morning, {naam}. It's cold in the Warden's House."
const PLAYER_LINE := "Grandpa? Your hands are shaking."


func needs_game() -> bool:
	return true


func _ensure_wilgendal(t: Node) -> bool:
	GameState.story_step = StoryData.START
	GameState.change_map(WILGENDAL, "start")
	for _i in 420:
		await t.pframes(1)
		var nu := t.get_tree().current_scene
		if nu != null and nu.name == "Wilgendal" and not GameState.changing_map and nu.is_node_ready():
			await t.pframes(4)
			return true
	return false


func _scene_player(t: Node) -> Node2D:
	var scene := t.get_tree().current_scene
	if scene == null:
		return null
	var p: Variant = scene.get("player") if "player" in scene else null
	return p as Node2D if p is Node2D else null


func _oude_man(t: Node) -> Node2D:
	var scene := t.get_tree().current_scene
	if scene == null:
		return null
	var objects := scene.get_node_or_null("Objects")
	if objects == null:
		return null
	var opa := objects.get_node_or_null("OudeMan") as Node2D
	if opa != null:
		opa.visible = true
	return opa


func run(t: Node) -> void:
	t.check("F6-T13: Wilgendal geladen", await _ensure_wilgendal(t))
	var player := _scene_player(t)
	var opa := _oude_man(t)
	t.check("F6-T13: speler in scène", player != null and is_instance_valid(player))
	t.check("F6-T13: OudeMan in scène", opa != null and is_instance_valid(opa))
	if player == null or opa == null:
		return

	var speaker: String = str(StoryData.SPEAKER)

	# Speler heet zoals Grandpa — zonder source (zoals Story.say).
	GameState.set_player_name(speaker)
	var line := GRANDPA_LINE.replace("{naam}", GameState.player_name)
	Dialog.show_lines([line], speaker)
	await t.pframes(6)
	t.check(
		"F6-T13: speler '%s', Grandpa spreekt → ballon bij OudeMan (niet speler)" % speaker,
		Dialog.is_open and Dialog.speaker_node == opa and Dialog.speaker_node != player)
	Dialog.close()
	await t.pframes(3)

	# Eigen regel van de speler.
	GameState.set_player_name("Dax")
	Dialog.show_lines([PLAYER_LINE], GameState.player_name)
	await t.pframes(6)
	t.check(
		"F6-T13: speler 'Dax', eigen regel → ballon bij speler",
		Dialog.is_open and Dialog.speaker_node == player)
	Dialog.close()
	await t.pframes(2)