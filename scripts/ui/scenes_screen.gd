extends "res://scripts/ui/menu_screen.gd"
## v0.22 Veldmenu > Scenes (Dennis): alle cutscenes (scripts/data/scenes_data.gd) om opnieuw te bekijken.
## Bekeken = speelbaar; nog niet bekeken = '???' (grijs, op slot). Na het afspelen ben je terug in dit scherm.
## Afspelen zet niets in het echte verhaal: de wereldkaart-film speelt los (zonder map/vlag), de
## Hanger-scène krijgt een eigen (lege) vlaggenbron.

const ScenesData := preload("res://scripts/data/scenes_data.gd")
const WorldmapCutsceneScript := preload("res://scripts/worldmap_cutscene.gd")
const HANGER_SCENE := preload("res://world_warper/cutscene/hanger_scene.tscn")
const HINT := "A: watch   B: back"
const LOCKED_MSG := "You haven't seen this scene yet."
const REPLAY_LAYER := 125

var buttons: Array[Button] = []
var list: VBoxContainer
## Lopende herhaling (null = geen)
var playing: Node = null
var last_played := ""


func _build() -> void:
	header.text = "Scenes"
	set_hint(HINT)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	_fill()


func _fill() -> void:
	for b in buttons:
		b.queue_free()
	buttons.clear()
	var first: Button = null
	for i in ScenesData.SCENES.size():
		var sc: Dictionary = ScenesData.SCENES[i]
		var seen: bool = GameState.scene_seen(str(sc["id"]))
		var b := UiMenu.button("%d. %s" % [i + 1, str(sc["title"]) if seen else ScenesData.LOCKED_TITLE])
		b.name = "Scene_" + str(sc["id"])
		b.custom_minimum_size = Vector2(0, ROW_H)
		b.pressed.connect(choose.bind(str(sc["id"])))
		if not seen:
			_grey(b)
		elif first == null:
			first = b
		list.add_child(b)
		buttons.append(b)
	(first if first != null else (buttons[0] if not buttons.is_empty() else back_button)).grab_focus.call_deferred()


func is_locked(i: int) -> bool:
	return is_button_greyed(buttons[i])


func choose(id: String) -> void:
	if playing != null:
		return
	if not GameState.scene_seen(id):
		show_message(LOCKED_MSG)
		return
	last_played = id
	match str(ScenesData.scene(id).get("kind", "")):
		"worldmap":
			_play_worldmap()
		"hanger":
			_play_hanger()


func _play_worldmap() -> void:
	var c: CanvasLayer = WorldmapCutsceneScript.new()
	c.name = "SceneReplay"
	c.layer = REPLAY_LAYER
	get_tree().root.add_child(c)
	playing = c
	c.finished.connect(_replay_done)
	# Bewust niet de echte map meegeven: dan zou de film de speler-input vrijgeven terwijl dit menu open is.
	c.begin(c)


func _play_hanger() -> void:
	var h: Node = HANGER_SCENE.instantiate()
	h.name = "SceneReplay"
	var bron := ScenesData.FlagBron.new()
	h.add_child(bron)
	get_tree().root.add_child(h)
	h.get_node("Layer").layer = REPLAY_LAYER
	playing = h
	h.threat_finished.connect(func() -> void:
		h.queue_free()
		_replay_done(), CONNECT_ONE_SHOT)
	h.maybe_play(bron)


func _replay_done() -> void:
	playing = null
	var map := get_tree().current_scene
	if map != null and map.has_method("_play_map_music"):
		map._play_map_music()
	quiet()
	_fill()


## Testhaakje: de lopende herhaling meteen afronden (zelfde weg als overslaan).
func finish_replay() -> void:
	if playing == null or not is_instance_valid(playing):
		return
	if playing.has_method("_finish"):
		playing._finish()


func _process(delta: float) -> void:
	if playing != null:
		return       # de cutscene heeft de invoer; B sluit dit scherm dan niet
	super._process(delta)
