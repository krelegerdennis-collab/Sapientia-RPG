extends Node
## Opties > tab Music: volume, mute en previewlijst.
## Start: godot --path . -- --muziektest [--shots=/pad/map]

const MusicTracks := preload("res://scripts/data/music_tracks.gd")
const OptionsScreen := preload("res://scripts/ui/options_screen.gd")
const SETTINGS_TMP := "user://muziektest_settings.cfg"

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
	Settings.path = SETTINGS_TMP
	if FileAccess.file_exists(SETTINGS_TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TMP))
	Settings.load_settings()
	Settings.set_value("music_volume", 4)
	Settings.set_value("sfx_volume", 6)
	Settings.set_value("audio_mute", false)
	Settings.save_settings()
	Settings.values = Settings.DEFAULTS.duplicate()
	Settings.load_settings()
	check("volume blijft bewaard in settings.cfg na load_settings",
			int(Settings.get_value("music_volume")) == 4 and int(Settings.get_value("sfx_volume")) == 6)
	var mbus := AudioServer.get_bus_index("Music")
	var sbus := AudioServer.get_bus_index("SFX")
	check("sliders toegepast op bussen", is_equal_approx(AudioServer.get_bus_volume_db(mbus), Settings.volume_db(4))
			and is_equal_approx(AudioServer.get_bus_volume_db(sbus), Settings.volume_db(6)))
	Settings.set_value("audio_mute", true)
	check("mute zet Music-bus uit", AudioServer.is_bus_mute(mbus))
	check("mute zet SFX-bus uit", AudioServer.is_bus_mute(sbus))
	Settings.set_value("audio_mute", false)
	check("unmute herstelt hoorbaarheid (bus niet gedempt)", not AudioServer.is_bus_mute(mbus))
	Settings.set_value("music_volume", 8)
	Settings.set_value("sfx_volume", 8)
	GameState.new_game("Dax")
	GameState.heard_music = ["wereld", "donker_woud"]
	var o: CanvasLayer = OptionsScreen.new()
	o.name = "Options"
	get_tree().root.add_child(o)
	await _frames(4)
	check("opties opent op General-tab", o.tab == "general" and o.keys.size() == 13)
	o.kies_tab("music")
	await _frames(4)
	check("Music-tab zichtbaar", o.tab == "music" and o.music_root.visible)
	var locked: int = o.track_buttons.filter(func(b): return o.is_button_greyed(b)).size()
	var playable: int = o.track_buttons.size() - locked
	check("lijst toont alle tracks, alleen gehoord speelbaar", o.track_buttons.size() == MusicTracks.TRACKS.size()
			and playable == 2 and locked == MusicTracks.TRACKS.size() - 2)
	check("touch: schuifregels en tracks >= 48 px",
			o.music_sliders["music_volume"].custom_minimum_size.y >= 48.0
			and o.track_buttons.all(func(b): return b.custom_minimum_size.y >= 48.0))
	var slider: HSlider = o.music_sliders["music_volume"]
	slider.value = 2
	await _frames(2)
	check("schuifregelaar zet music_volume", int(Settings.get_value("music_volume")) == 2)
	await _shot("options_music_tab")
	o.choose_track("main_menu")
	check("vergrendelde track: melding", o.message_text() == OptionsScreen.MUSIC_LOCKED_MSG)
	o.choose_track("donker_woud")
	await _frames(3)
	check("preview speelt via Music-bus", AudioManager.get_current_music() == "donker_woud"
			and AudioManager._active_player.bus == "Music")
	o.close()
	await _frames(3)
	check("sluiten stopt preview", AudioManager._music_stack.is_empty())
	if FileAccess.file_exists(SETTINGS_TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TMP))
	Settings.path = Settings.DEFAULT_PATH
	Settings.load_settings()
	print("MUZIEKTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAILED", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)
