extends Node
## Menu > Scenes > tab Music (scripts/data/music_tracks.gd, scripts/ui/scenes_screen.gd).
## Start: godot --path . -- --musictest [--shots=/pad/map]

const MusicTracks := preload("res://scripts/data/music_tracks.gd")
const NAMEN := {
	"main_menu": "Sapientia",
	"wachtershuis": "The Guardian's Hearth",
	"wereld": "Under Open Skies",
	"dorp_wilgendal": "Wind over Willowdale",
	"donker_woud": "Where the Mist Remembers",
	"vergeten_archieven": "Dust and Forgotten Words",
	"gevecht_normaal": "Clockwork in Motion",
	"gevecht_miniboss": "The Weight of Steel",
	"berggrot": "Echoes in the Collapse",
	"levend_archief": "Shelves of Glass and Root",
	"baas_archief2": "The Overgrown Index",
	"diepe_grot": "Epoch 100",
}
const ScenesScreen := preload("res://scripts/ui/scenes_screen.gd")
const SAVE := "user://music_test.json"
const MAP := "res://scenes/maps/wilgendal.tscn"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots)
	var native_path := shots.path_join(naam + "_384x216.png")
	img.save_png(native_path)
	print("INFO  native screenshot: ", native_path)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(shots.path_join(naam + ".png"))
	print("INFO  screenshot: ", shots.path_join(naam + ".png"))


func _run() -> void:
	AudioManager.stop_music(0.0)
	GameState.new_game("Dax")
	# --- data
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/audio_manifest.json"))
	var actual_files: Array[String] = []
	for bestand in DirAccess.get_files_at("res://assets/audio/bgm"):
		if bestand.ends_with(".ogg"):
			actual_files.append(bestand)
	var listed_files: Array[String] = []
	var data_ok := MusicTracks.TRACKS.size() == NAMEN.size()
	for t in MusicTracks.TRACKS:
		for mid in t["ids"]:
			var e: Dictionary = m["bgm"].get(mid, {})
			var bestand := str(e.get("bestand", ""))
			data_ok = data_ok and not e.is_empty() and FileAccess.file_exists("res://assets/audio/bgm/" + bestand)
			if bestand != "" and not listed_files.has(bestand):
				listed_files.append(bestand)
		data_ok = data_ok and str(t["name"]) == str(NAMEN.get(str(t["id"]), "?")) and str(t["where"]) != ""
	actual_files.sort()
	listed_files.sort()
	check("tracklijst dekt elk aanwezig BGM-bestand met Engelse naam en locatie", data_ok and listed_files == actual_files)
	# --- vrijspelen
	check("nieuw spel: niets gehoord (titelmuziek speelde niet)", GameState.heard_music.is_empty())
	AudioManager.play_music("wereld", 0.0)
	await _frames(2)
	check("wereldkaart gehoord -> 'Under Open Skies' vrij", GameState.heard_music == ["wereld"])
	AudioManager.play_music("donker_woud", 0.0)
	await _frames(2)
	check("Donker Woud gehoord -> 'Where the Mist Remembers' vrij", GameState.heard_music.has("donker_woud"))
	AudioManager.play_music("ww_ambient", 0.0)
	await _frames(2)
	check("ww_ambient (zelfde bestand) speelt 'Epoch 100' vrij", GameState.heard_music.has("diepe_grot"))
	AudioManager.play_music("donker_woud", 0.0, true)
	await _frames(2)
	check("nog eens horen = niet dubbel", GameState.heard_music.count("donker_woud") == 1)
	# --- save/load
	AudioManager.stop_music(0.0)
	await _frames(2)
	check("opslaan", GameState.save_game(Vector2i(5, 5), Vector2i.DOWN, SAVE))
	GameState.new_game("Dax")
	check("nieuw spel wist de lijst", GameState.heard_music.is_empty())
	check("laden zet de gehoorde tracks terug", GameState.load_game(SAVE) and GameState.heard_music.has("donker_woud")
			and GameState.heard_music.has("diepe_grot") and GameState.heard_music.has("wereld")
			and GameState.heard_music.size() == 3)
	var f := FileAccess.open(SAVE, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	d.erase("heard_music")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	check("oude save zonder heard_music laadt (lege lijst)", GameState.load_game(SAVE) and GameState.heard_music.is_empty())
	GameState.load_game(SAVE)
	# --- scherm
	GameState.changing_map = false
	get_tree().change_scene_to_file(MAP)
	await _frames(20)
	AudioManager.play_music("wereld", 0.0, true)
	await get_tree().create_timer(0.6).timeout
	# De kaart kan tijdens het laden zelf muziek starten; voor dit schermscenario kiezen we exact vier unlocks.
	GameState.heard_music = ["wereld", "donker_woud", "diepe_grot", "levend_archief"]
	var pos0: float = AudioManager._active_player.get_playback_position()
	var s: CanvasLayer = ScenesScreen.new()
	get_tree().root.add_child(s)
	await _frames(3)
	check("scherm opent op Scenes en Music-tab is beschikbaar", s.tab == "scenes" and s.tab_buttons.has("music"))
	s.kies_tab("music")
	await _frames(3)
	var greyed: int = s.buttons.filter(func(b): return s.is_button_greyed(b)).size()
	check("tab Music: 12 regels, 8 op slot (???), 4 speelbaar", s.buttons.size() == 12 and greyed == 8
			and s.buttons.filter(func(b): return UiMenu_text(b).contains("???")).size() == 8)
	check("touch: regels en tabs >= 22 px hoog", s.buttons.all(func(b): return b.size.y >= 22.0)
			and s.tab_buttons.values().all(func(b): return b.size.y >= 22.0))
	await _shot("music_tab")
	s.choose_track("main_menu")
	check("op slot: melding, geen muziek", s.message_text() == ScenesScreen.MUSIC_LOCKED_MSG and AudioManager.get_current_music() == "wereld")
	s.choose_track("donker_woud")
	await _frames(3)
	check("afspelen: track speelt, mapmuziek gepauzeerd (stapel 1)", AudioManager.get_current_music() == "donker_woud"
			and AudioManager._music_stack.size() == 1 and str(AudioManager._music_stack[0]["track"]) == "wereld")
	check("via de Music-bus (muziekvolume uit Settings)", AudioManager._active_player.bus == "Music")
	var vol0 = Settings.get_value("music_volume")
	Settings.set_value("music_volume", 3)
	var db3 := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	Settings.set_value("music_volume", 8)
	var db8 := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	Settings.set_value("music_volume", vol0)
	check("muziekvolume stuurt de bus (3: %.1f dB < 8: %.1f dB)" % [db3, db8], db3 < db8)
	check("regel toont wat er speelt", UiMenu_text(_track_button(s, "donker_woud")).contains("[Playing]"))
	await _shot("music_tab_playing")
	s.choose_track("levend_archief")
	await _frames(3)
	check("andere track: wisselt, stapel blijft 1", AudioManager.get_current_music() == "levend_archief" and AudioManager._music_stack.size() == 1)
	s.choose_track("levend_archief")
	await _frames(3)
	check("zelfde nog eens = stop: mapmuziek terug (positie %.2f)" % AudioManager._active_player.get_playback_position(),
			AudioManager.get_current_music() == "wereld" and AudioManager._music_stack.is_empty()
			and AudioManager._active_player.get_playback_position() >= pos0 - 0.05)
	s.choose_track("donker_woud")
	await _frames(2)
	s.kies_tab("scenes")
	await _frames(3)
	check("Music-tab verlaten herstelt mapmuziek", s.preview == "" and AudioManager.get_current_music() == "wereld"
			and AudioManager._music_stack.is_empty())
	s.kies_tab("music")
	await _frames(3)
	s.choose_track("donker_woud")
	await _frames(2)
	s.close()
	await _frames(3)
	check("scherm sluiten tijdens afspelen: mapmuziek terug", AudioManager.get_current_music() == "wereld" and AudioManager._music_stack.is_empty())
	check("afspelen in het menu ontgrendelt geen onbekende tracks", GameState.heard_music.size() == 4)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("MUSICTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAILED", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


static func UiMenu_text(b: Button) -> String:
	return str(b.get_meta("label", b.text))


static func _track_button(s: CanvasLayer, id: String) -> Button:
	return s.list.get_node("Track_" + id) as Button
