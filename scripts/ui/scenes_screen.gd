extends "res://scripts/ui/menu_screen.gd"
## v0.22 Veldmenu > Scenes (Dennis): alle cutscenes (scripts/data/scenes_data.gd) om opnieuw te bekijken.
## Bekeken = speelbaar; nog niet bekeken = '???' (grijs, op slot). Na het afspelen ben je terug in dit scherm.
## Afspelen zet niets in het echte verhaal: de wereldkaart-film speelt los (zonder map/vlag), de
## Hanger-scène krijgt een eigen (lege) vlaggenbron.

const ScenesData := preload("res://scripts/data/scenes_data.gd")
const WorldmapCutsceneScript := preload("res://scripts/worldmap_cutscene.gd")
const HANGER_SCENE := preload("res://world_warper/cutscene/hanger_scene.tscn")
const GenezerScene := preload("res://world_warper/cutscene/genezer_scene.gd")
const HINT := "A: watch   Left/Right: tab   B: back"
## Tab Music (Dennis, 21 okt 2026): de Suno-tracks die je in het spel gehoord hebt (scripts/data/music_tracks.gd).
## Afspelen gaat over de Music-bus (dus met het muziekvolume uit Settings) en pauzeert de mapmuziek
## (AudioManager.push_music); stoppen of het scherm sluiten zet de mapmuziek terug op dezelfde plek (pop_music).
const MusicTracks := preload("res://scripts/data/music_tracks.gd")
const TABS := ["scenes", "music"]
const TAB_NAMES := {"scenes": "Scenes", "music": "Music"}
const MUSIC_HINT := "A: play/stop   Left/Right: tab   B: back"
const MUSIC_LOCKED_MSG := "You haven't heard this track yet."
const MUSIC_PLAYING := "Now playing: %s"
const MUSIC_STOPPED := "Music stopped."
const PLAY_ROW_H := 22         # muziekregels: ruim tikdoel
var tab := "scenes"
var tab_buttons := {}
## Track-id (music_tracks.gd) die nu vanuit dit scherm speelt, "" = geen (mapmuziek).
var preview := ""
const LOCKED_MSG := "You haven't seen this scene yet."
const REPLAY_LAYER := 125

var buttons: Array[Button] = []
var list: VBoxContainer
## Lopende herhaling (null = geen)
var playing: Node = null
var last_played := ""
var _dialog_layer := 5


func _build() -> void:
	header.text = "Scenes & Music"
	set_hint(HINT)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	content.add_child(bar)
	for t in TABS:
		var tb := UiMenu.button(TAB_NAMES[t])
		tb.name = "Tab_" + t
		tb.custom_minimum_size = Vector2(64, PLAY_ROW_H)
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(kies_tab.bind(t))
		bar.add_child(tb)
		tab_buttons[t] = tb
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
	if list.get_child_count() > 0:
		clear_message()
	for b in buttons:
		b.queue_free()
	buttons.clear()
	for t in tab_buttons:
		var tb: Button = tab_buttons[t]
		tb.add_theme_color_override("font_color", MenuColors.TITLE if t == tab else MenuColors.TEXT_DIM)
		UiMenu.set_label(tb, ("[%s]" if t == tab else "%s") % TAB_NAMES[t])
	if tab == "music":
		_fill_music()
		return
	set_hint(HINT)
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
	stop_preview()      # een herhaling speelt zijn eigen muziek; daarna komt de mapmuziek terug
	last_played = id
	match str(ScenesData.scene(id).get("kind", "")):
		"worldmap":
			_play_worldmap()
		"hanger":
			_play_hanger()
		"sapientia":
			_play_hanger({ScenesData.CANON_HANGER_FLAG: true})   # alleen scène 3 (de dreiging)
		"genezer":
			_play_genezer()


func _play_worldmap() -> void:
	var c: CanvasLayer = WorldmapCutsceneScript.new()
	c.name = "SceneReplay"
	c.layer = REPLAY_LAYER
	get_tree().root.add_child(c)
	playing = c
	c.finished.connect(_replay_done)
	# Bewust niet de echte map meegeven: dan zou de film de speler-input vrijgeven terwijl dit menu open is.
	c.begin(c)


func _play_hanger(preset: Dictionary = {}) -> void:
	var h: Node = HANGER_SCENE.instantiate()
	h.name = "SceneReplay"
	var bron := ScenesData.FlagBron.new()
	bron.story_flags = preset.duplicate()
	h.add_child(bron)
	get_tree().root.add_child(h)
	h.get_node("Layer").layer = REPLAY_LAYER
	playing = h
	h.threat_finished.connect(func() -> void:
		h.queue_free()
		_replay_done(), CONNECT_ONE_SHOT)
	h.maybe_play(bron)


## Canon-scène 1 als herhaling: geen vlaggen, geen mapwissel (WorldWarperGenezerScene.herhaal).
func _play_genezer() -> void:
	var holder := Node.new()
	holder.name = "SceneReplay"
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(holder)
	var achter_laag := CanvasLayer.new()
	achter_laag.layer = REPLAY_LAYER - 1
	holder.add_child(achter_laag)
	var achter := ColorRect.new()
	achter.color = Color(0.02, 0.01, 0.04)
	achter.set_anchors_preset(Control.PRESET_FULL_RECT)
	achter_laag.add_child(achter)
	# de dialoog (laag 5) moet boven de herhaling en het menu staan; daarna terug
	_dialog_layer = Dialog.layer
	Dialog.layer = REPLAY_LAYER + 1
	playing = holder
	var s: Node = GenezerScene.herhaal(holder)
	var laag := s.get_node_or_null("Laag") as CanvasLayer
	if laag != null:
		laag.layer = REPLAY_LAYER
	s.klaar.connect(func() -> void:
		holder.name = "SceneReplayWeg"
		holder.queue_free()
		_replay_done(), CONNECT_ONE_SHOT)


func _replay_done() -> void:
	playing = null
	_herstel_na_herhaling()
	var map := get_tree().current_scene
	if map != null and map.has_method("_play_map_music"):
		map._play_map_music()
	quiet()
	_fill()


## v0.24 Terug uit een herhaling: dialoog dicht en op zijn eigen laag, geen restanten van de scène,
## focus terug in de lijst. Zo blijft het scherm nooit hangen, wat de scène ook achterlaat.
func _herstel_na_herhaling() -> void:
	Dialog.layer = _dialog_layer
	if Dialog.is_open:
		Dialog.close()
	var rest := get_tree().root.get_node_or_null("SceneReplay")
	if rest != null:
		rest.name = "SceneReplayWeg"
		rest.queue_free()


## v0.24 Bug (Dennis): in de herhaling van 'The World Warper' bleef het eerste tekstvak ('The core of the
## second Archive ...') op het zwarte scherm staan. Het tekstvak gaat verder via de speler (A/B) of de
## A-knop van de touch-besturing, maar die is verborgen zolang het veldmenu open is. Op de telefoon kon je
## dus niet verder en kwam je nooit meer terug in de lijst. Nu: tikken/klikken klikt de tekst door.
func _input(event: InputEvent) -> void:
	if playing == null or not Dialog.is_open:
		return
	var tik: bool = (event is InputEventScreenTouch and event.pressed) or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
			and event.device != InputEvent.DEVICE_ID_EMULATION)    # tik = ook een nagebootste muisklik: niet dubbel
	if tik:
		get_viewport().set_input_as_handled()
		Dialog.advance()


## Testhaakje: de lopende herhaling meteen afronden (zelfde weg als overslaan).
func finish_replay() -> void:
	if playing == null or not is_instance_valid(playing):
		return
	if playing.has_method("_finish"):
		playing._finish()
		return
	var g := playing.get_node_or_null("CanonGenezer")
	if g != null and g.has_method("stop_herhaling"):
		g.stop_herhaling()


func _process(delta: float) -> void:
	if playing != null:
		return       # de cutscene heeft de invoer; B sluit dit scherm dan niet
	super._process(delta)


# ---------------------------------------------------------------- tab Music
func _handle_input() -> void:
	if playing != null:
		return
	var d := horizontal_pressed()
	if d != 0:
		kies_tab(TABS[(TABS.find(tab) + d + TABS.size()) % TABS.size()])


func kies_tab(t: String) -> void:
	if t == tab or not t in TABS or playing != null:
		return
	tab = t
	header.text = TAB_NAMES[t]
	quiet()
	_fill()


func _fill_music() -> void:
	set_hint(MUSIC_HINT)
	var first: Button = null
	for i in MusicTracks.TRACKS.size():
		var tr: Dictionary = MusicTracks.TRACKS[i]
		var tid := str(tr["id"])
		var heard: bool = GameState.heard_music.has(tid)
		var b := UiMenu.button(_music_label(i, tr, heard))
		b.name = "Track_" + tid
		b.custom_minimum_size = Vector2(0, PLAY_ROW_H)
		b.pressed.connect(choose_track.bind(tid))
		if not heard:
			_grey(b)
		elif first == null:
			first = b
		list.add_child(b)
		buttons.append(b)
	(first if first != null else (buttons[0] if not buttons.is_empty() else back_button)).grab_focus.call_deferred()


func _music_label(i: int, tr: Dictionary, heard: bool) -> String:
	if not heard:
		return "%d. %s" % [i + 1, MusicTracks.LOCKED_NAME]
	var mark := "[Playing] " if str(tr["id"]) == preview else ""
	return "%d. %s%s  (%s)" % [i + 1, mark, str(tr["name"]), str(tr["where"])]


func _relabel_music() -> void:
	for i in mini(buttons.size(), MusicTracks.TRACKS.size()):
		var tr: Dictionary = MusicTracks.TRACKS[i]
		UiMenu.set_label(buttons[i], _music_label(i, tr, GameState.heard_music.has(str(tr["id"]))))


## Track afspelen; dezelfde track nog eens = stoppen (mapmuziek terug).
func choose_track(tid: String) -> void:
	if not GameState.heard_music.has(tid):
		show_message(MUSIC_LOCKED_MSG)
		return
	if tid == preview:
		stop_preview()
		show_message(MUSIC_STOPPED)
		_relabel_music()
		return
	var tr: Dictionary = MusicTracks.track(tid)
	var mid := str((tr["ids"] as Array)[0])
	if preview == "":
		AudioManager.push_music(mid, 0.3)      # bewaart de mapmuziek + positie
	else:
		AudioManager.play_music(mid, 0.3, true)
	preview = tid
	show_message(MUSIC_PLAYING % str(tr["name"]))
	_relabel_music()


func stop_preview() -> void:
	if preview == "":
		return
	preview = ""
	AudioManager.pop_music(0.3)


func close() -> void:
	stop_preview()
	super.close()
