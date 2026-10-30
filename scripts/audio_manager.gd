extends Node
## AudioManager voor SAPIENTIA (Godot 4.3).
##
## Autoload "AudioManager", in project.godot DIRECT NA Settings:
##   AudioManager="*res://scripts/audio_manager.gd"
##
## Overgenomen uit Sapientia-Audio (branch cursor/audio-systeem-blauwdruk-d676) en
## aangepast voor v0.17 (merge_staging, zie NOTES.md):
##   - Volume is van de autoload Settings (music_volume / sfx_volume, 0..10, user://settings.cfg).
##     De AudioManager slaat zelf NIETS op (geen user://audio_settings.cfg meer) en zet
##     de busvolumes niet; set_music_volume() e.d. sturen door naar Settings.
##   - De bussen "Music" en "SFX" maakt Settings aan; hier alleen een stille terugval.
##   - Manifest: res://assets/audio/audio_manifest.json, bestanden in res://assets/audio/{bgm,sfx}/.
##   - Per held en monster: res://assets/audio/actor_sfx.json (mappen helden/ en monsters/).
##   - auto_ui_sounds staat standaard UIT (focus-hover in gevechts-/veldmenu's gaf spam).
##   - Robuust zonder audio: geen manifest of geen bestanden = stil, zonder errors/warnings
##     (alleen print_verbose, zichtbaar met --verbose). Echte fouten (kapotte JSON, onbekende
##     naam terwijl het manifest WEL geladen is) melden we één keer per sleutel.
##   - Web (HTML5): browsers blokkeren geluid tot de eerste tik/toets. Op Web starten we
##     play() pas daarna, en de spelers gebruiken playback Stream. Godot 4.3+ speelt op web
##     standaard via Samples; AudioServer.add_bus() (Music/SFX) koppelt dan Master los van
##     de speakers (godotengine/godot#119026) en alles blijft stil terwijl playing true is.
##     GodotAudio zit in de engine-closure (niet op window). De Web-export zet daarom in
##     head_include een wrapper om AudioContext en hervat die context bij de eerste tik.
##
## Hoofdfuncties:
##   play_music(track_name, fade_in)  - speelt BGM met crossfade
##   stop_music(fade_out)             - stopt BGM met fade-out
##   play_sfx(sound_name)             - speelt een geluidseffect
##
## Extra: push_music()/pop_music() (gevecht en terug naar verkenning).
##
## De geluiden worden gedefinieerd in res://assets/audio/audio_manifest.json.
## Ontbrekende geluiden of bestanden veroorzaken nooit een crash; de functie geeft
## dan gewoon false terug.

signal music_started(track_name: String)
signal music_stopped
signal music_finished(track_name: String)
signal volume_changed(bus_name: String, linear_volume: float)

const MANIFEST_PATH := "res://assets/audio/audio_manifest.json"
const ACTOR_SFX_PATH := "res://assets/audio/actor_sfx.json"

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const SFX_POOL_SIZE := 16
const DEFAULT_FADE := 1.5
const SILENT_DB := -80.0
## Maximale wachttijd bij afsluiten tot de audiothread gestopte streams heeft opgeruimd.
const EXIT_MIX_WAIT_MS := 400
const MIN_LINEAR := 0.0001

const UI_SFX_CLICK := "menu_click"
const UI_SFX_HOVER := "menu_hover"
const UI_SFX_ERROR := "menu_error"
## Metadata op een knop: eigen cue (bv. "menu_cancel" voor Back, "tab_switch" voor een tab).
const UI_META_SOUND := "ui_sound"
## Zoveel beelden na een stick-/pijltjesdruk telt een focuswissel als 'cursor verplaatst'.
const NAV_WINDOW_FRAMES := 3
const NAV_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "move_up", "move_down", "move_left", "move_right"]

## Koppelt automatisch klik- en hovergeluiden aan elke knop (BaseButton).
## Zet op een knop `set_meta("no_ui_sound", true)` om hem over te slaan.
## v0.17: UIT. Pas aanzetten als menu_click/menu_hover bestaan en de focus-hover in de
## gevechts- en veldmenu's getest is (anders klinkt elke cursorstap).
var auto_ui_sounds: bool = false
## UX-polish (fase 6): een knop die ingedrukt wordt klikt (menu_click, of de cue uit de metadata
## "ui_sound"; een grijze knop geeft menu_error), en de cursor verplaatsen in een menu geeft een
## zacht tikje. Hover/focus bij het opbouwen van een scherm blijft stil (dat was de spam).
var ui_press_sounds: bool = true
var ui_cursor_sounds: bool = true
var _nav_frame: int = -100

var _bgm: Dictionary = {}
var _sfx: Dictionary = {}
var _bgm_dir: String = "res://assets/audio/bgm/"
var _sfx_dir: String = "res://assets/audio/sfx/"
var _manifest_loaded: bool = false

var _music_players: Array[AudioStreamPlayer] = []
var _active_player: AudioStreamPlayer
var _music_tween: Tween
var _current_track: String = ""
var _music_stack: Array[Dictionary] = []

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next_index: int = 0
var _sfx_last_played_ms: Dictionary = {}
var _sfx_last_variant: Dictionary = {}

var _stream_cache: Dictionary = {}
## Geheugen: BGM-oggs zijn 2-4 MB per stuk en blijven als ze in de cache staan altijd in het RAM.
## Alleen de laatste BGM_CACHE_MAX tracks (huidige, vorige en gevechtsmuziek) blijven gecachet;
## SFX (klein) blijven altijd staan. Oudste eerst.
const BGM_CACHE_MAX := 3
var _bgm_lru: Array[String] = []
var _reported: Dictionary = {}
var _rng := RandomNumberGenerator.new()

## Web: true tot de eerste tik/toets. play() vóór die tik blijft in de browser stil.
var _web_locked := false
## Volume van de track die klaarstaat tot de browser het geluid vrijgeeft.
var _armed_base_db := 0.0
var _web_prompt: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web_locked = OS.get_name() == "Web"
	_rng.randomize()
	_ensure_buses()
	_create_players()
	load_manifest()
	if _web_locked:
		_show_web_prompt()
	# Volume: Settings is de enige eigenaar. Wij geven alleen het signaal door.
	var settings := _settings()
	if settings != null and settings.has_signal("changed"):
		settings.changed.connect(_on_settings_changed)
	get_tree().node_added.connect(_on_node_added)
	if OS.is_debug_build() and _manifest_loaded:
		var report := validate_manifest(false)
		if report["missing"] > 0:
			print_verbose("[AudioManager] %d van de %d bestanden ontbreken nog. AudioManager.validate_manifest() geeft de lijst." % [report["missing"], report["total"]])


# ---------------------------------------------------------------------------
# Muziek
# ---------------------------------------------------------------------------

## Speelt een BGM-track. Als er al muziek speelt, volgt een crossfade.
## `fade_in` is de duur van de crossfade in seconden (0 = direct).
## Geeft true terug als de track is gestart (of al speelde).
func play_music(track_name: String, fade_in: float = DEFAULT_FADE, restart: bool = false, from_position: float = 0.0) -> bool:
	if not _bgm.has(track_name):
		if not _manifest_loaded:
			return false
		_report("bgm_unknown:" + track_name, "Muziektrack '%s' staat niet in het manifest (%s). Huidige muziek blijft doorspelen." % [track_name, MANIFEST_PATH], true)
		return false

	if track_name == _current_track and _active_player.playing and not restart:
		return true

	var entry: Dictionary = _bgm[track_name]
	var path := _bgm_dir + str(entry.get("bestand", ""))
	var stream := _load_stream(path, "bgm:" + track_name)
	if stream == null:
		return false

	_apply_loop(stream, bool(entry.get("loop", true)))

	var base_db := float(entry.get("volume_db", 0.0))
	var outgoing: AudioStreamPlayer = _active_player if _active_player.playing else null
	var incoming: AudioStreamPlayer = _get_inactive_music_player()

	_kill_music_tween()
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = base_db if fade_in <= 0.0 else SILENT_DB

	_active_player = incoming
	_current_track = track_name
	_armed_base_db = base_db

	# Op web nog geen play(): de AudioContext is suspended en een te vroege play()
	# blijft daarna stil. _unlock_web_audio() start de track bij de eerste tik.
	if not _web_locked:
		_start_music_playback(incoming, outgoing, base_db, fade_in, from_position)

	music_started.emit(track_name)
	return true


## Stopt de muziek met een fade-out (in seconden, 0 = direct).
func stop_music(fade_seconds: float = DEFAULT_FADE) -> void:
	_kill_music_tween()
	var was_playing := _active_player != null and _active_player.playing
	_current_track = ""
	if not was_playing:
		_stop_all_music_players()
		return

	if fade_seconds <= 0.0:
		_stop_all_music_players()
	else:
		var outgoing := _active_player
		var out_db := outgoing.volume_db
		_music_tween = create_tween()
		_music_tween.tween_method(_apply_crossfade.bind(null, 0.0, outgoing, out_db), 0.0, 1.0, fade_seconds)
		_music_tween.tween_callback(_on_fade_finished.bind(outgoing))
	music_stopped.emit()


## Bewaart de huidige track (en positie) en start een nieuwe, bijvoorbeeld bij
## het begin van een gevecht. Keer terug met pop_music().
## v0.17: de huidige stand wordt ALTIJD bewaard (ook als de nieuwe track ontbreekt),
## zodat push/pop in battle.gd in balans blijven, ook zonder audiobestanden.
func push_music(track_name: String, fade_in: float = 0.5) -> bool:
	var saved := {"track": _current_track, "position": 0.0}
	if _current_track != "" and _active_player.playing:
		saved["position"] = _active_player.get_playback_position()
	_music_stack.append(saved)
	return play_music(track_name, fade_in)


## Herstelt de muziek van vóór de laatste push_music(), op dezelfde positie.
func pop_music(fade_in: float = DEFAULT_FADE) -> bool:
	if _music_stack.is_empty():
		print_verbose("[AudioManager] pop_music() zonder push_music(); genegeerd.")
		return false
	var saved: Dictionary = _music_stack.pop_back()
	var track := str(saved.get("track", ""))
	if track == "":
		stop_music(fade_in)
		return true
	# Speelt die track nog (omdat de push-track ontbrak)? Dan niet herstarten.
	if track == _current_track and is_music_playing():
		return true
	return play_music(track, fade_in, true, float(saved.get("position", 0.0)))


func get_current_music() -> String:
	return _current_track


func is_music_playing() -> bool:
	return _current_track != "" and _active_player != null and _active_player.playing


func has_music(track_name: String) -> bool:
	return _bgm.has(track_name)


func get_music_names() -> PackedStringArray:
	return PackedStringArray(_bgm.keys())


# ---------------------------------------------------------------------------
# Geluidseffecten
# ---------------------------------------------------------------------------

## Speelt een geluidseffect uit het manifest. Bij meerdere varianten wordt er
## willekeurig gekozen. `volume_offset_db` en `pitch_scale` zijn optionele
## aanpassingen bovenop de manifest-waarden.
func play_sfx(sound_name: String, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> bool:
	if not _sfx.has(sound_name):
		if not _manifest_loaded:
			return false
		_report("sfx_unknown:" + sound_name, "Geluidseffect '%s' staat niet in het manifest (%s)." % [sound_name, MANIFEST_PATH], true)
		return false

	var entry: Dictionary = _sfx[sound_name]

	var interval := int(entry.get("min_interval_ms", 0))
	if interval > 0:
		var now := Time.get_ticks_msec()
		if now - int(_sfx_last_played_ms.get(sound_name, -interval)) < interval:
			return false
		_sfx_last_played_ms[sound_name] = now

	var files: Array = entry.get("bestanden", [])
	if files.is_empty():
		_report("sfx_nofiles:" + sound_name, "Geluidseffect '%s' heeft geen 'bestanden' in het manifest." % sound_name, true)
		return false

	var file_name := str(_pick_variant(sound_name, files))
	var stream := _load_stream(_sfx_dir + file_name, "sfx:" + file_name)
	if stream == null:
		return false

	var player := _get_free_sfx_player()
	var variation := float(entry.get("pitch_variatie", 0.0))
	player.stream = stream
	player.volume_db = float(entry.get("volume_db", 0.0)) + volume_offset_db
	player.pitch_scale = maxf(pitch_scale * _rng.randf_range(1.0 - variation, 1.0 + variation), 0.01)
	if _web_locked:
		return false
	player.play()
	return true


func has_sfx(sound_name: String) -> bool:
	return _sfx.has(sound_name)


func get_sfx_names() -> PackedStringArray:
	return PackedStringArray(_sfx.keys())


func stop_all_sfx() -> void:
	for player in _sfx_pool:
		player.stop()


## Laadt SFX vooraf in het geheugen om haperingen tijdens het spelen te voorkomen.
## Voorbeeld: AudioManager.preload_sfx(["sword_swing", "sword_hit_flesh"]).
func preload_sfx(sound_names: Array) -> void:
	for sound_name in sound_names:
		if not _sfx.has(sound_name):
			if not _manifest_loaded:
				return
			_report("sfx_unknown:" + str(sound_name), "preload_sfx: '%s' staat niet in het manifest." % str(sound_name), true)
			continue
		for file_name in _sfx[sound_name].get("bestanden", []):
			_load_stream(_sfx_dir + str(file_name), "sfx:" + str(file_name))


# ---------------------------------------------------------------------------
# Volume
# ---------------------------------------------------------------------------

## v0.17: Settings (autoload) is de enige eigenaar van het volume: 0..Settings.VOLUME_STEPS
## stappen, opgeslagen in user://settings.cfg, toegepast op de bussen "Music" en "SFX".
## Deze functies zijn alleen gemaksdoorgeefluiken met een lineaire waarde 0.0..1.0.
## Er is geen apart Master-volume (dat kent Settings niet).

func set_music_volume(linear_volume: float) -> void:
	_set_setting_volume("music_volume", linear_volume)


func set_sfx_volume(linear_volume: float) -> void:
	_set_setting_volume("sfx_volume", linear_volume)


func get_music_volume() -> float:
	return _get_setting_volume("music_volume")


func get_sfx_volume() -> float:
	return _get_setting_volume("sfx_volume")


func _set_setting_volume(key: String, linear_volume: float) -> void:
	var settings := _settings()
	if settings == null:
		return
	var steps := _volume_steps(settings)
	settings.set_value(key, roundi(clampf(linear_volume, 0.0, 1.0) * steps))


func _get_setting_volume(key: String) -> float:
	var settings := _settings()
	if settings == null:
		return 1.0
	var steps := _volume_steps(settings)
	return clampf(float(settings.get_value(key)) / maxf(float(steps), 1.0), 0.0, 1.0)


func _on_settings_changed(key: String) -> void:
	match key:
		"music_volume":
			volume_changed.emit(BUS_MUSIC, get_music_volume())
		"sfx_volume":
			volume_changed.emit(BUS_SFX, get_sfx_volume())


## Settings.VOLUME_STEPS (10) via de constantentabel, zonder harde afhankelijkheid.
func _volume_steps(settings: Node) -> int:
	var scr: Script = settings.get_script()
	if scr == null:
		return 10
	return maxi(int(scr.get_script_constant_map().get("VOLUME_STEPS", 10)), 1)


func _settings() -> Node:
	return get_node_or_null("/root/Settings")


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

## Leest res://assets/audio/audio_manifest.json opnieuw in. Geeft true bij succes.
func load_manifest() -> bool:
	_bgm.clear()
	_sfx.clear()
	_stream_cache.clear()
	_bgm_lru.clear()
	_manifest_loaded = false

	if not FileAccess.file_exists(MANIFEST_PATH):
		# Normaal zolang er nog geen audio is (of als *.json niet in include_filter staat).
		print_verbose("[AudioManager] Geen audio-manifest (%s): stil, geen geluid." % MANIFEST_PATH)
		return false

	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		_report("manifest_parse", "Audio-manifest bevat een JSON-fout op regel %d: %s" % [json.get_error_line(), json.get_error_message()], true)
		return false
	if typeof(json.data) != TYPE_DICTIONARY:
		_report("manifest_format", "Audio-manifest moet een JSON-object zijn.", true)
		return false

	var data: Dictionary = json.data
	var paths: Dictionary = data.get("paden", {})
	_bgm_dir = _normalize_dir(str(paths.get("bgm", _bgm_dir)))
	_sfx_dir = _normalize_dir(str(paths.get("sfx", _sfx_dir)))

	var bgm_data = data.get("bgm", {})
	var sfx_data = data.get("sfx", {})
	if typeof(bgm_data) == TYPE_DICTIONARY:
		_bgm = bgm_data
	else:
		_report("manifest_bgm", "Sectie 'bgm' in het manifest moet een object zijn.", true)
	if typeof(sfx_data) == TYPE_DICTIONARY:
		_sfx = sfx_data
	else:
		_report("manifest_sfx", "Sectie 'sfx' in het manifest moet een object zijn.", true)

	_merge_actor_sfx()
	_manifest_loaded = true
	return true


## Held- en monstergeluiden staan niet in het grote manifest maar in actor_sfx.json,
## naast de mappen res://assets/audio/sfx/helden/ en monsters/. Sleutel:
## held_<id>_<slot> of monster_<id>_<slot>, slot is aanval/raak/dood/vaardigheid.
func _merge_actor_sfx() -> void:
	if not FileAccess.file_exists(ACTOR_SFX_PATH):
		print_verbose("[AudioManager] Geen acteur-sfx (%s)." % ACTOR_SFX_PATH)
		return
	var text := FileAccess.get_file_as_string(ACTOR_SFX_PATH)
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		_report("actor_sfx_parse", "Acteur-sfx bevat een JSON-fout op regel %d: %s" % [json.get_error_line(), json.get_error_message()], true)
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		_report("actor_sfx_format", "Acteur-sfx moet een JSON-object zijn.", true)
		return
	var data: Dictionary = json.data
	var slots: Array = data.get("slots", ["aanval", "raak", "dood", "vaardigheid"])
	for soort in ["helden", "monsters"]:
		var groep = data.get(soort, {})
		if typeof(groep) != TYPE_DICTIONARY:
			_report("actor_sfx_" + soort, "Sectie '%s' in de acteur-sfx moet een object zijn." % soort, true)
			continue
		var prefix := "held" if soort == "helden" else "monster"
		for id in groep:
			var entry = groep[id]
			if typeof(entry) != TYPE_DICTIONARY:
				_report("actor_sfx_entry:" + str(id), "Acteur '%s' moet een object zijn." % str(id), true)
				continue
			var slot_map: Dictionary = entry.get("slots", {})
			for slot in slots:
				var sleutel := "%s_%s_%s" % [prefix, str(id), str(slot)]
				if _sfx.has(sleutel):
					_report("actor_sfx_dup:" + sleutel, "Acteur-sfx '%s' botst met een bestaand geluid." % sleutel, true)
					continue
				var beschrijving := str(slot_map.get(slot, entry.get("stem", "")))
				_sfx[sleutel] = {
					"bestanden": ["%s/%s/%s.wav" % [soort, str(id), str(slot)]],
					"categorie": "acteur",
					"beschrijving": beschrijving,
					"volume_db": float(entry.get("volume_db", -6.0)),
					"pitch_variatie": float(entry.get("pitch_variatie", 0.04)),
					"min_interval_ms": 0,
				}


## Controleert of alle bestanden uit het manifest bestaan.
## Geeft {"total": int, "missing": int, "missing_files": Array} terug.
## Met `print_report = true` wordt de lijst ontbrekende bestanden geprint.
func validate_manifest(print_report: bool = true) -> Dictionary:
	var total := 0
	var missing_files: Array[String] = []

	for track_name in _bgm:
		total += 1
		var path := _bgm_dir + str(_bgm[track_name].get("bestand", ""))
		if not ResourceLoader.exists(path):
			missing_files.append(path)

	for sound_name in _sfx:
		for file_name in _sfx[sound_name].get("bestanden", []):
			total += 1
			var path := _sfx_dir + str(file_name)
			if not ResourceLoader.exists(path):
				missing_files.append(path)

	if print_report:
		if missing_files.is_empty():
			print("[AudioManager] Alle %d bestanden uit het manifest zijn aanwezig." % total)
		else:
			print("[AudioManager] %d van de %d bestanden ontbreken:" % [missing_files.size(), total])
			for path in missing_files:
				print("  - " + path)

	return {"total": total, "missing": missing_files.size(), "missing_files": missing_files}


# ---------------------------------------------------------------------------
# Interne hulpfuncties
# ---------------------------------------------------------------------------

## Settings (eerder geladen autoload) maakt "Music" en "SFX" al aan; dit is alleen een
## stille terugval (bijv. in een losse testscène zonder Settings). Volume zet Settings.
func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, BUS_MASTER)


func _create_players() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % i
		player.bus = BUS_MUSIC
		# Stream, niet Sample: op web maakt add_bus() de Sample-busgrafiek stil.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.finished.connect(_on_music_player_finished.bind(player))
		add_child(player)
		_music_players.append(player)
	_active_player = _music_players[0]

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = BUS_SFX
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player)
		_sfx_pool.append(player)


func _start_music_playback(incoming: AudioStreamPlayer, outgoing: AudioStreamPlayer, base_db: float, fade_in: float, from_position: float) -> void:
	incoming.play(maxf(from_position, 0.0))
	if fade_in <= 0.0:
		if outgoing != null:
			outgoing.stop()
		return
	var out_db := outgoing.volume_db if outgoing != null else SILENT_DB
	_music_tween = create_tween()
	_music_tween.tween_method(_apply_crossfade.bind(incoming, base_db, outgoing, out_db), 0.0, 1.0, fade_in)
	_music_tween.tween_callback(_on_fade_finished.bind(outgoing))


## Eerste tik, muisklik, toets of gamepad. De knoppen op het titelscherm krijgen
## dezelfde tik daarna nog gewoon (we markeren het event niet als afgehandeld).
func _input(event: InputEvent) -> void:
	# toets/pad/pijltje: de cursor beweegt in dit beeld (de GUI-focus volgt ná _input); zie ui_cursor_sounds
	if event.is_pressed() and not event is InputEventMouse:
		for a in NAV_ACTIONS:
			if event.is_action_pressed(a):
				_nav_frame = Engine.get_process_frames()
				break
	if not _web_locked or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey or event is InputEventJoypadButton:
		_unlock_web_audio()


func _unlock_web_audio() -> void:
	if not _web_locked:
		return
	_web_locked = false
	_hide_web_prompt()
	_resume_web_context()
	var playing := false
	if _active_player != null and _current_track != "" and _active_player.stream != null:
		_active_player.volume_db = _armed_base_db
		_active_player.play(0.0)
		playing = _active_player.playing
	print("[AudioManager] geluid aan (track=%s playing=%s)" % [_current_track, str(playing)])


func _resume_web_context() -> void:
	if OS.get_name() != "Web" or not ClassDB.class_exists("JavaScriptBridge"):
		return
	JavaScriptBridge.eval("if(window.sapientiaResumeAudio){window.sapientiaResumeAudio();}", true)


func _show_web_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WebAudioPrompt"
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var label := Label.new()
	label.name = "Prompt"
	label.text = "Tap for sound"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -22.0
	label.offset_bottom = -4.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var gs := get_node_or_null("/root/GameState")
	if gs != null and "ui_theme" in gs and gs.ui_theme != null:
		label.theme = gs.ui_theme
	label.add_theme_color_override("font_color", Color("f2e9d8"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(label)
	add_child(layer)
	_web_prompt = layer


func _hide_web_prompt() -> void:
	if _web_prompt != null and is_instance_valid(_web_prompt):
		_web_prompt.queue_free()
	_web_prompt = null


func _get_inactive_music_player() -> AudioStreamPlayer:
	return _music_players[1] if _active_player == _music_players[0] else _music_players[0]


func _get_free_sfx_player() -> AudioStreamPlayer:
	for candidate in _sfx_pool:
		if not candidate.playing:
			return candidate
	# Alle spelers bezet: de oudste wordt hergebruikt (round-robin).
	var reused := _sfx_pool[_sfx_next_index]
	_sfx_next_index = (_sfx_next_index + 1) % _sfx_pool.size()
	return reused


func _pick_variant(sound_name: String, files: Array) -> Variant:
	if files.size() == 1:
		return files[0]
	var last := int(_sfx_last_variant.get(sound_name, -1))
	var index := _rng.randi_range(0, files.size() - 1)
	if index == last:
		index = (index + 1 + _rng.randi_range(0, files.size() - 2)) % files.size()
	_sfx_last_variant[sound_name] = index
	return files[index]


func _load_stream(path: String, report_key: String) -> AudioStream:
	var is_bgm := report_key.begins_with("bgm:")
	if _stream_cache.has(path):
		if is_bgm:
			_bgm_cache_aanraken(path)
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		# Verwacht zolang de audio nog niet gemaakt is: geen warning, alleen --verbose.
		if not _reported.has("file_missing:" + report_key):
			_reported["file_missing:" + report_key] = true
			print_verbose("[AudioManager] Audiobestand ontbreekt: %s" % path)
		return null
	var resource := load(path)
	if not resource is AudioStream:
		_report("file_invalid:" + report_key, "Bestand is geen geldige audio-stream: %s" % path, true)
		return null
	_stream_cache[path] = resource
	if is_bgm:
		_bgm_cache_aanraken(path)
	return resource


## Zet `path` als meest recent gebruikte BGM en laat de oudste los boven BGM_CACHE_MAX. Een track die nog
## speelt blijft leven via zijn AudioStreamPlayer; alleen de cache-verwijzing verdwijnt.
func _bgm_cache_aanraken(path: String) -> void:
	_bgm_lru.erase(path)
	_bgm_lru.append(path)
	while _bgm_lru.size() > BGM_CACHE_MAX:
		_stream_cache.erase(_bgm_lru.pop_front())


func _apply_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = should_loop
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if should_loop and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		elif not should_loop:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED


## t loopt van 0 naar 1. Equal-power crossfade houdt het totale volume gelijk.
func _apply_crossfade(t: float, incoming: AudioStreamPlayer, incoming_db: float, outgoing: AudioStreamPlayer, outgoing_db: float) -> void:
	if incoming != null and is_instance_valid(incoming):
		incoming.volume_db = incoming_db + linear_to_db(maxf(sin(t * PI * 0.5), MIN_LINEAR))
	if outgoing != null and is_instance_valid(outgoing):
		outgoing.volume_db = outgoing_db + linear_to_db(maxf(cos(t * PI * 0.5), MIN_LINEAR))


func _on_fade_finished(outgoing: AudioStreamPlayer) -> void:
	if outgoing != null and is_instance_valid(outgoing):
		outgoing.stop()


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _stop_all_music_players() -> void:
	for player in _music_players:
		player.stop()


func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	if player != _active_player or _current_track == "":
		return
	var finished_track := _current_track
	_current_track = ""
	music_finished.emit(finished_track)


## Afsluiten (autoload: alleen bij quit). Een stream die nog speelt staat in de afspeellijst
## van de AudioServer; die ruimt hem pas op na een mix-stap van de audiothread. Na quit() komt
## die stap vaak niet meer -> "ObjectDB instances leaked" / "resources still in use" (bv. de
## titelmuziek in snelle testsuites). Daarom: alles stoppen en kort wachten op twee mix-stappen.
## De spelers (kinderen) verlaten de boom eerder en stoppen dan zelf al, dus `playing` is hier
## al false; "heeft een stream gehad" is de enige betrouwbare aanwijzing.
func _exit_tree() -> void:
	_kill_music_tween()
	_music_stack.clear()
	_current_track = ""
	var had_stream := false
	for player: AudioStreamPlayer in _music_players + _sfx_pool:
		if player.stream != null:
			had_stream = true
		player.stop()
		player.stream = null
	if had_stream:
		_wacht_op_mix(2, EXIT_MIX_WAIT_MS)


## Blokkeert tot de audiothread `stappen` keer gemixt heeft (of `max_ms` voorbij is).
## get_time_since_last_mix() valt terug naar ~0 bij elke mix-stap.
func _wacht_op_mix(stappen: int, max_ms: int) -> void:
	var einde := Time.get_ticks_msec() + max_ms
	var vorige := AudioServer.get_time_since_last_mix()
	while stappen > 0 and Time.get_ticks_msec() < einde:
		OS.delay_msec(2)
		var nu := AudioServer.get_time_since_last_mix()
		if nu < vorige:
			stappen -= 1
		vorige = nu


func _process(_delta: float) -> void:
	for a in NAV_ACTIONS:
		if Input.is_action_just_pressed(a):
			_nav_frame = Engine.get_process_frames()
			return


func _on_node_added(node: Node) -> void:
	if not node is BaseButton:
		return
	if node.has_meta("_ui_sound_hooked"):
		return
	node.set_meta("_ui_sound_hooked", true)
	var button := node as BaseButton
	button.pressed.connect(_on_ui_button_pressed.bind(button))
	button.mouse_entered.connect(_on_ui_button_hover.bind(button))
	button.focus_entered.connect(_on_ui_button_hover.bind(button))


func _on_ui_button_pressed(button: BaseButton) -> void:
	if not (auto_ui_sounds or ui_press_sounds) or button.has_meta("no_ui_sound"):
		return
	play_sfx(ui_cue_for(button))


## Welke cue hoort bij een druk op deze knop? Grijs = error, anders de metadata of de klik.
func ui_cue_for(button: BaseButton) -> String:
	if bool(button.get_meta("greyed", false)):
		return UI_SFX_ERROR
	return str(button.get_meta(UI_META_SOUND, UI_SFX_CLICK))


func _on_ui_button_hover(button: BaseButton) -> void:
	if button.disabled or button.has_meta("no_ui_sound"):
		return
	if auto_ui_sounds:
		play_sfx(UI_SFX_HOVER)
	elif ui_cursor_sounds and Engine.get_process_frames() - _nav_frame <= NAV_WINDOW_FRAMES:
		play_sfx(UI_SFX_HOVER)


func _normalize_dir(path: String) -> String:
	return path if path.ends_with("/") else path + "/"


## Meldt een probleem één keer per sleutel, zodat de Output niet volloopt.
func _report(key: String, message: String, is_error: bool) -> void:
	if _reported.has(key):
		return
	_reported[key] = true
	if is_error:
		push_error("[AudioManager] " + message)
	else:
		push_warning("[AudioManager] " + message)
