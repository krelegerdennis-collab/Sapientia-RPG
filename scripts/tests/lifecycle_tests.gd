extends Node
## ALLEEN VOOR TESTEN - app-levenscyclus (docs/qa/ANDROID_LIFECYCLE.md, scripts/core/app_lifecycle.gd).
## Start:  godot --path . -- --lifecycletest [--shots=/pad/map]
##   A: export- en projectinstellingen die de safe-area-code nodig heeft (cutout, immersive, landscape)
##   B: pauze/hervatten via de échte notificaties (propagate_notification, zoals Android): framerate-cap, geluid
##   C: menu's -> OS.low_processor_usage_mode (echte titelscherm, afgeleid menu, veldmenu in een kaart)
##   D: pauze-save blijft (0e9178b), er komt géén extra save bij suspend/hervatten
##   E: scherm-diagnose voor een echt toestel
## Zit niet in de export (scripts/tests/*).

const TOWN := "res://scenes/maps/wilgendal.tscn"
const MenuScreen := preload("res://scripts/ui/menu_screen.gd")

var failures := 0
var passes := 0
var _orig_fps := 0
var _orig_autosave := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.encounter_multiplier = 0.0
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


func _wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := get_tree().current_scene
		if s != null and s.name == scene_name and s.is_node_ready():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


## Android stuurt de notificatie naar de hele boom; zo doen wij het ook.
func _notify(what: int) -> void:
	get_tree().root.propagate_notification(what)


func _run() -> void:
	await _wacht_preload()
	_orig_fps = Engine.max_fps
	_orig_autosave = Settings.autosave_enabled()
	_config_tests()
	_title_tests()
	_background_tests()
	await _menu_tests()
	await _map_tests()
	_diag_tests()
	Settings.set_value("autosave", _orig_autosave)
	Engine.max_fps = _orig_fps
	print("LIFECYCLETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _wacht_preload() -> void:
	var t := 0.0
	while not GameState._preloading.is_empty() and t < 15.0:
		await get_tree().process_frame
		t += get_process_delta_time()


# ---------------------------------------------------------------- A: instellingen
func _config_tests() -> void:
	check("autoload AppLifecycle bestaat", get_node_or_null("/root/AppLifecycle") != null)
	check("AppLifecycle staat in project.godot als autoload",
			str(ProjectSettings.get_setting("autoload/AppLifecycle", "")).ends_with("scripts/core/app_lifecycle.gd"))
	check("framerate-cap staat op 60 (project-instelling run/max_fps)",
			int(ProjectSettings.get_setting("application/run/max_fps", 0)) == 60)
	check("achtergrond-cap is lager dan de gewone cap", AppLifecycle.BACKGROUND_FPS < 60 and AppLifecycle.BACKGROUND_FPS > 0)
	check("basisresolutie 384x216, stretch viewport + expand (brede telefoons krijgen extra breedte)",
			int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 384
			and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 216
			and str(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport"
			and str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand")
	check("oriëntatie: sensor-landscape (4); de cutout wisselt dus van kant bij draaien",
			int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 4)
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	check("export_presets.cfg is te lezen", err == OK)
	if err != OK:
		return
	var android := 0
	var immersive := 0
	for section in cfg.get_sections():
		if section.ends_with(".options") or str(cfg.get_value(section, "platform", "")) != "Android":
			continue
		android += 1
		var opts := section + ".options"
		if bool(cfg.get_value(opts, "screen/immersive_mode", false)):
			immersive += 1
	check("beide Android-presets: screen/immersive_mode = true (systeembalken weg, cutout als echte inset)",
			android >= 2 and immersive == android)
	for section in cfg.get_sections():
		if section.ends_with(".options"):
			var keystore_leeg := true
			for key in cfg.get_section_keys(section):
				if key.begins_with("keystore/") and str(cfg.get_value(section, key)) != "":
					keystore_leeg = false
			check("%s: geen signing-gegevens in de repo" % section, keystore_leeg)


# ---------------------------------------------------------------- titelscherm (echt)
func _title_tests() -> void:
	var s := get_tree().current_scene
	check("het spel start op het titelscherm", s != null and s.scene_file_path.ends_with("title.tscn"))
	check("het titelscherm telt als menu", AppLifecycle.is_menu_mode())
	check("testrun (user-args): laag-processor-gedrag standaard uit, zodat screenshots frames krijgen",
			not AppLifecycle.low_processor_enabled and not OS.low_processor_usage_mode)


# ---------------------------------------------------------------- B: pauze / hervatten
func _background_tests() -> void:
	Engine.max_fps = 60
	AppLifecycle.set_low_processor_enabled(false)
	var seen: Array[String] = []
	var on_bg := func() -> void: seen.append("bg")
	var on_fg := func() -> void: seen.append("fg")
	AppLifecycle.backgrounded.connect(on_bg)
	AppLifecycle.foregrounded.connect(on_fg)

	var playing := _maak_speler(true)
	var stil := _maak_speler(false)
	var al_gepauzeerd := _maak_speler(true)
	al_gepauzeerd.stream_paused = true
	check("beginsituatie: voorgrond", not AppLifecycle.is_background() and Engine.max_fps == 60)

	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("PAUSED: app staat in de achtergrond", AppLifecycle.is_background())
	check("PAUSED: framerate-cap omlaag", Engine.max_fps == AppLifecycle.BACKGROUND_FPS)
	check("PAUSED: spelende audio gepauzeerd (stream_paused; positie blijft behouden)", playing.stream_paused)
	check("PAUSED: niet-spelende speler blijft ongemoeid", not stil.stream_paused)
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("dubbele PAUSED: bewaarde cap blijft 60 (geen 10 als 'normaal')", AppLifecycle._saved_fps == 60)

	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("RESUMED: terug op voorgrond", not AppLifecycle.is_background())
	check("RESUMED: framerate-cap hersteld op 60", Engine.max_fps == 60)
	check("RESUMED: audio hervat en speelt weer", playing.playing and not playing.stream_paused)
	check("RESUMED: speler die al gepauzeerd was blijft gepauzeerd", al_gepauzeerd.stream_paused)
	check("signalen: precies één backgrounded en één foregrounded", seen == ["bg", "fg"])

	# desktop: focusverlies is geen achtergrond (alt-tab mag het spel niet dempen)
	AppLifecycle.force_mobile = false
	if not OS.has_feature("mobile"):
		_notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check("desktop: FOCUS_OUT is geen achtergrond", not AppLifecycle.is_background() and Engine.max_fps == 60)
		_notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

	# telefoon: FOCUS_OUT (meldingenbalk) -> PAUSED -> RESUMED -> FOCUS_IN, zoals Android het stuurt
	AppLifecycle.force_mobile = true
	seen.clear()
	_notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("mobiel: FOCUS_OUT = achtergrond, cap omlaag, audio gepauzeerd",
			AppLifecycle.is_background() and Engine.max_fps == AppLifecycle.BACKGROUND_FPS and playing.stream_paused)
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("RESUMED terwijl focus nog weg is: blijft achtergrond (cap laag, audio gepauzeerd)",
			AppLifecycle.is_background() and Engine.max_fps == AppLifecycle.BACKGROUND_FPS and playing.stream_paused)
	_notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check("FOCUS_IN daarna: alles terug (cap 60, audio hervat)",
			not AppLifecycle.is_background() and Engine.max_fps == 60 and not playing.stream_paused)
	check("signalen bij FOCUS_OUT/PAUSED/RESUMED/FOCUS_IN: één bg en één fg", seen == ["bg", "fg"])
	_notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("hervatten zonder voorafgaande pauze doet niets", Engine.max_fps == 60 and seen == ["bg", "fg"])

	# volgorde omgekeerd: PAUSED vóór FOCUS_OUT
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	_notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check("PAUSED + FOCUS_OUT, dan alleen FOCUS_IN: nog steeds achtergrond", AppLifecycle.is_background())
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("RESUMED sluit af: voorgrond, cap 60", not AppLifecycle.is_background() and Engine.max_fps == 60)
	AppLifecycle.force_mobile = false

	# onbegrensde cap (0) wordt ook weer 0
	Engine.max_fps = 0
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("cap 0 (onbegrensd): in de achtergrond toch begrensd", Engine.max_fps == AppLifecycle.BACKGROUND_FPS)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("cap 0 wordt na hervatten weer 0", Engine.max_fps == 0)
	Engine.max_fps = 60

	# een speler die tijdens de pauze verdwijnt mag het hervatten niet breken
	var weg := _maak_speler(true)
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	weg.free()
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("verwijderde speler tijdens pauze: hervatten gaat gewoon door",
			not AppLifecycle.is_background() and not playing.stream_paused)

	_audiomanager_tests()
	AppLifecycle.backgrounded.disconnect(on_bg)
	AppLifecycle.foregrounded.disconnect(on_fg)
	for p in [playing, stil, al_gepauzeerd]:
		p.queue_free()


func _maak_speler(spelen: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = AudioStreamGenerator.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	if spelen:
		p.play()
	return p


func _audiomanager_tests() -> void:
	var tracks: Array = AudioManager._bgm.keys()
	if tracks.is_empty():
		check("AudioManager: geen BGM in het manifest (overgeslagen)", true)
		return
	var started: bool = AudioManager.play_music(str(tracks[0]), 0.0, true)
	var actief: AudioStreamPlayer = AudioManager._active_player
	if not started or actief == null or not actief.playing:
		check("AudioManager: muziek start niet headless (overgeslagen)", true)
		return
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("AudioManager: BGM staat gepauzeerd in de achtergrond", actief.stream_paused)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("AudioManager: BGM speelt na hervatten door en is niet gestopt",
			actief.playing and not actief.stream_paused and AudioManager._current_track == str(tracks[0]))
	AudioManager.stop_music(0.0)


# ---------------------------------------------------------------- C: menu's / low-processor
func _menu_tests() -> void:
	AppLifecycle.set_low_processor_enabled(true)
	check("titelscherm + laag-processor aan: modus aan", OS.low_processor_usage_mode)
	AppLifecycle.set_low_processor_enabled(false)
	check("laag-processor uitgezet: modus uit", not OS.low_processor_usage_mode)
	AppLifecycle.set_low_processor_enabled(true)

	var title := get_tree().current_scene
	GameState.new_game("Kees")
	GameState.story_step = preload("res://scripts/data/story_data.gd").KLAAR
	GameState.change_map(TOWN, "start")
	var script := GDScript.new()
	script.source_code = "extends \"res://scripts/ui/menu_screen.gd\"\n"
	var ok := script.reload() == OK
	check("testscript dat van menu_screen.gd erft is geldig", ok)
	await _frames(1)
	if not await _wait_scene("Wilgendal"):
		check("Wilgendal laadt", false)
		return
	await _frames(5)
	check("kaart zonder menu: modus uit", not AppLifecycle.is_menu_mode() and not OS.low_processor_usage_mode)
	check("titelscherm is weg uit de menu-teller", not is_instance_valid(title) or not AppLifecycle._menus.has(title.get_instance_id()))

	var a: Node = script.new()
	var b: Node = MenuScreen.new()
	add_child(a)
	check("afgeleid menu (erft menu_screen.gd) schakelt de modus in", AppLifecycle.is_menu_mode() and OS.low_processor_usage_mode)
	add_child(b)
	a.queue_free()
	await _frames(2)
	check("twee menu's, één dicht: modus blijft aan", AppLifecycle.is_menu_mode() and OS.low_processor_usage_mode)
	b.queue_free()
	await _frames(2)
	check("alle menu's dicht: modus uit", not AppLifecycle.is_menu_mode() and not OS.low_processor_usage_mode)
	var ander := Node.new()
	var ander_script := GDScript.new()
	ander_script.source_code = "extends Node\n"
	ander_script.reload()
	ander.set_script(ander_script)
	add_child(ander)
	check("node met een ander script is geen menu", not AppLifecycle.is_menu_mode())
	ander.queue_free()

	var c: Node = MenuScreen.new()
	add_child(c)
	check("menu open: modus aan", OS.low_processor_usage_mode)
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("menu open + app naar achtergrond: modus uit (cap en pauze regelen het dan)",
			not OS.low_processor_usage_mode and AppLifecycle.is_background())
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("menu open + hervat: modus weer aan", OS.low_processor_usage_mode and not AppLifecycle.is_background())
	var wissel := []
	var on_mode := func(active: bool) -> void: wissel.append(active)
	AppLifecycle.menu_mode_changed.connect(on_mode)
	AppLifecycle.set_low_processor_enabled(false)
	AppLifecycle.set_low_processor_enabled(false)
	AppLifecycle.menu_mode_changed.disconnect(on_mode)
	check("uitzetten geeft één menu_mode_changed(false)", wissel == [false])
	check("uitgezet terwijl een menu open is: modus uit", not OS.low_processor_usage_mode)
	AppLifecycle.set_low_processor_enabled(true)
	c.queue_free()
	await _frames(2)
	check("menu dicht: modus uit", not OS.low_processor_usage_mode)
	check("MENU_SCRIPTS verwijst naar bestaande scripts", _menu_scripts_bestaan())
	AppLifecycle.set_low_processor_enabled(false)


func _menu_scripts_bestaan() -> bool:
	for path in AppLifecycle.MENU_SCRIPTS:
		if not ResourceLoader.exists(path):
			return false
	return true


# ---------------------------------------------------------------- C+D: echte kaart, pauze-save
func _map_tests() -> void:
	GameState.new_game("Kees")
	GameState.story_step = preload("res://scripts/data/story_data.gd").KLAAR
	GameState.change_map(TOWN, "start")
	var ok := await _wait_scene("Wilgendal")
	check("testwereld: Wilgendal geladen", ok)
	if not ok:
		return
	await _frames(20)
	var map: Node = get_tree().current_scene
	var player: Node = map.get_node_or_null("Objects/Player")
	check("speler staat in de kaart", player != null)
	if player == null:
		return
	_remove(GameState.autosave_path)
	AppLifecycle.set_low_processor_enabled(true)
	check("vrije wereld: modus uit", not OS.low_processor_usage_mode)
	await _tap("menu")
	await _frames(3)
	var menu: Node = map.get_node_or_null("FieldMenu")
	check("veldmenu is open", menu != null)
	check("veldmenu open: low-processor aan", OS.low_processor_usage_mode)

	# D: pauze-save met 'Autom. opslaan' UIT blijft werken (0e9178b); hervatten en focus schrijven niets
	Settings.set_value("autosave", false)
	var count := GameState.autosave_count
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("autosave-optie uit + PAUSED (echte propagatie): pauze-save geschreven, reden achtergrond",
			GameState.autosave_count == count + 1 and GameState.last_autosave_reason == "achtergrond"
			and FileAccess.file_exists(GameState.autosave_path))
	var stamp := FileAccess.get_file_as_string(GameState.autosave_path)
	check("tijdens de pauze: modus uit, cap laag", not OS.low_processor_usage_mode and Engine.max_fps == AppLifecycle.BACKGROUND_FPS)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	_notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(3)
	check("RESUMED/FOCUS_IN schrijven niets (geen autosave bij hervatten)",
			GameState.autosave_count == count + 1 and FileAccess.get_file_as_string(GameState.autosave_path) == stamp)
	check("na hervatten: menu nog open, modus weer aan, cap 60",
			is_instance_valid(menu) and OS.low_processor_usage_mode and Engine.max_fps == 60)
	var vorige := GameState.autosave_count
	AppLifecycle.force_mobile = false
	_notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check("desktop-focuswissel: geen extra save", GameState.autosave_count == vorige or OS.has_feature("mobile"))
	check("gewone autosave-reden 'map' blijft geblokkeerd met de optie uit",
			not GameState.autosave(player.get_tile(), player.facing, "map"))
	check("autosave-redenen: map + achtergrond, geen 'suspend'",
			GameState.AUTOSAVE_REASONS == ["map", "achtergrond"])

	# blokkades blijven gelden tijdens pauze
	var voor := GameState.autosave_count
	Dialog.is_open = true
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	Dialog.is_open = false
	GameState.in_battle = true
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	GameState.in_battle = false
	GameState.changing_map = true
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	GameState.changing_map = false
	check("pauze tijdens dialoog, gevecht en mapwissel: geen save", GameState.autosave_count == voor)
	check("na die pauzes staat alles weer op voorgrond", not AppLifecycle.is_background() and Engine.max_fps == 60)

	if is_instance_valid(menu):
		menu.close()
	await _frames(3)
	check("veldmenu dicht: low-processor uit", not OS.low_processor_usage_mode)
	AppLifecycle.set_low_processor_enabled(false)
	Settings.set_value("autosave", _orig_autosave)
	_remove(GameState.autosave_path)


func _remove(path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


# ---------------------------------------------------------------- E: scherm-diagnose
func _diag_tests() -> void:
	var info: Dictionary = AppLifecycle.display_info()
	for key in ["display", "screen", "window", "safe_area", "cutouts", "refresh_hz", "dpi", "max_fps", "view"]:
		check("display_info heeft '%s'" % key, info.has(key))
	check("display_info: venster en viewport hebben een grootte",
			(info["window"] as Array)[0] > 0 and (info["window"] as Array)[1] > 0
			and (info["view"] as Array)[0] >= 384 and (info["view"] as Array)[1] >= 216)
	check("display_info: safe_area is [x, y, b, h]", (info["safe_area"] as Array).size() == 4 and info["cutouts"] is Array)
	check("display_info is JSON-baar (SessieLog/logcat)", JSON.parse_string(JSON.stringify(info)) != null)

	var sl := get_node_or_null("/root/SessieLog")
	var regels_voor: int = sl.regels if sl != null else 0
	AppLifecycle._last_info_key = ""
	AppLifecycle.force_mobile = false
	AppLifecycle._log_display_info()
	check("PC: geen diagnose-regel (SessieLog van de tests blijft ongewijzigd)",
			AppLifecycle._last_info_key == "" and (sl == null or sl.regels == regels_voor))
	AppLifecycle.force_mobile = true
	AppLifecycle._log_display_info()
	var na_eerste: int = sl.regels if sl != null else 0
	AppLifecycle._log_display_info()
	check("mobiel: diagnose één keer gelogd, daarna alleen bij een wijziging",
			AppLifecycle._last_info_key != "" and (sl == null or not sl.actief or (na_eerste == regels_voor + 1 and sl.regels == na_eerste)))
	AppLifecycle.force_mobile = false
