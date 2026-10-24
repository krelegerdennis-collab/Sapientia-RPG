extends Node
## Autoload "AppLifecycle": gedrag van de app bij pauze/hervatten en accuverbruik (Android).
##
## Wat het doet (en wat niet):
##  - App naar de achtergrond (Android: PAUSED, op telefoons ook FOCUS_OUT, bv. meldingenbalk of
##    een telefoontje): geluid pauzeren (stream_paused, positie blijft behouden) en de
##    framerate-cap tijdelijk verlagen. Bij RESUMED/FOCUS_IN gaat alles terug zoals het was.
##  - Menu's en titelscherm: OS.low_processor_usage_mode aan. De engine tekent dan alleen als er
##    iets verandert (_process blijft gewoon draaien) en slaapt tussen de frames. Zodra er geen
##    menu meer open is gaat het weer uit. Uitzetten kan met project-instelling
##    sapientia/perf/low_processor_menus = false.
##  - Scherm-diagnose voor een echt toestel: display_info() (venster, veilige rechthoek, cutouts,
##    verversingssnelheid). Op een telefoon geprint (adb logcat -s godot) en in de SessieLog gezet.
##  - NIETS opslaan. De pauze-save blijft in GameState (commit 0e9178b: reden "achtergrond", alle
##    blokkades blijven gelden). Een autosave bij suspend komt niet terug (besluit Dennis).
##
## Testen: godot -- --lifecycletest (scripts/tests/lifecycle_tests.gd).

signal backgrounded
signal foregrounded
signal menu_mode_changed(active: bool)

## Zo laag gaat Engine.max_fps in de achtergrond (venster zonder focus, maar nog zichtbaar).
const BACKGROUND_FPS := 10
const SETTING_LOW_PROCESSOR := "sapientia/perf/low_processor_menus"

## Scripts waarvan een instantie (of afgeleide) een 'menu' is. Pad -> true.
const MENU_SCRIPTS := {
	"res://scripts/ui/menu_screen.gd": true,
	"res://scripts/ui/field_menu.gd": true,
	"res://scripts/ui/title_screen.gd": true,
	"res://scripts/ui/save_prompt.gd": true,
	"res://scripts/ui/load_screen.gd": true,
	"res://scripts/ui/bestiary_screen.gd": true,
}

## Aan/uit voor het laag-processor-gedrag in menu's. Standaard aan, behalve als het spel met
## user-args draait (de testsuites): daar wachten screenshots op frame_post_draw en dat komt
## niet als de engine een ongewijzigd beeld overslaat.
var low_processor_enabled := true
## Tests: doe alsof dit een telefoon is (FOCUS_OUT telt dan als achtergrond).
var force_mobile := false

var _reasons: Dictionary = {}
var _saved_fps := 0
var _paused_players: Array[WeakRef] = []
var _menus: Dictionary = {}
var _script_cache: Dictionary = {}
var _last_info_key := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	low_processor_enabled = bool(ProjectSettings.get_setting(SETTING_LOW_PROCESSOR, true)) \
			and OS.get_cmdline_user_args().is_empty()
	get_tree().node_added.connect(_on_node_added)
	var win := get_window()
	if win != null:
		win.size_changed.connect(_log_display_info)
	_log_display_info.call_deferred()
	_scan_menus.call_deferred(get_tree().root)


func is_background() -> bool:
	return not _reasons.is_empty()


func is_menu_mode() -> bool:
	return not _menus.is_empty()


func _is_mobile() -> bool:
	return force_mobile or OS.has_feature("mobile")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_enter_background("paused")
		NOTIFICATION_APPLICATION_RESUMED:
			_leave_background("paused")
			_log_display_info()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _is_mobile():
				_enter_background("focus")
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_leave_background("focus")


# ---------------------------------------------------------------------------
# Achtergrond: geluid + framerate
# ---------------------------------------------------------------------------

func _enter_background(reason: String) -> void:
	var was_background := is_background()
	_reasons[reason] = true
	if was_background:
		return
	_saved_fps = Engine.max_fps
	Engine.max_fps = BACKGROUND_FPS if _saved_fps == 0 else mini(_saved_fps, BACKGROUND_FPS)
	_pause_audio()
	if OS.low_processor_usage_mode:
		OS.low_processor_usage_mode = false
	backgrounded.emit()


func _leave_background(reason: String) -> void:
	if not _reasons.has(reason):
		return
	_reasons.erase(reason)
	if is_background():
		return
	Engine.max_fps = _saved_fps
	_resume_audio()
	_apply_menu_mode()
	foregrounded.emit()


## Pauzeert elke speler die nu speelt en onthoudt welke. Alleen die worden later hervat,
## zodat een speler die al door andere code is gepauzeerd gepauzeerd blijft.
func _pause_audio() -> void:
	_paused_players.clear()
	_walk_players(get_tree().root, func(p: Node) -> void:
		if bool(p.get("playing")) and not bool(p.get("stream_paused")):
			p.set("stream_paused", true)
			_paused_players.append(weakref(p)))


func _resume_audio() -> void:
	for ref in _paused_players:
		var p: Object = ref.get_ref()
		if p != null and is_instance_valid(p):
			p.set("stream_paused", false)
	_paused_players.clear()


func _walk_players(n: Node, fn: Callable) -> void:
	if n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D:
		fn.call(n)
	for c in n.get_children():
		_walk_players(c, fn)


# ---------------------------------------------------------------------------
# Menu's: low_processor_usage_mode
# ---------------------------------------------------------------------------

## Het hoofdscherm (titel) kan al in de boom staan voordat deze autoload klaar is.
func _scan_menus(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_scan_menus(c)


func _on_node_added(n: Node) -> void:
	var s: Script = n.get_script()
	if s == null or not _is_menu_script(s):
		return
	var id := n.get_instance_id()
	if _menus.has(id):
		return
	_menus[id] = true
	n.tree_exiting.connect(_on_menu_exiting.bind(id), CONNECT_ONE_SHOT)
	_apply_menu_mode()


func _on_menu_exiting(id: int) -> void:
	_menus.erase(id)
	_apply_menu_mode()


func _is_menu_script(s: Script) -> bool:
	var key := s.get_instance_id()
	if _script_cache.has(key):
		return _script_cache[key]
	var found := false
	var cur: Script = s
	while cur != null:
		if MENU_SCRIPTS.has(cur.resource_path):
			found = true
			break
		cur = cur.get_base_script()
	_script_cache[key] = found
	return found


func _apply_menu_mode() -> void:
	var want := low_processor_enabled and is_menu_mode() and not is_background()
	if OS.low_processor_usage_mode != want:
		OS.low_processor_usage_mode = want
		menu_mode_changed.emit(want)


## Tests en opties: laag-processor-gedrag aan/uit zetten en meteen toepassen.
func set_low_processor_enabled(on: bool) -> void:
	low_processor_enabled = on
	_apply_menu_mode()


# ---------------------------------------------------------------------------
# Scherm-diagnose (echt toestel)
# ---------------------------------------------------------------------------

## Alles wat de safe-area-code nodig heeft, in schermpixels. Pure uitlezing, geen effect.
func display_info() -> Dictionary:
	var win_size := Vector2i.ZERO
	var win := get_window()
	if win != null:
		win_size = win.size
	var cutouts: Array = []
	for r in DisplayServer.get_display_cutouts():
		cutouts.append(_rect_array(r))
	var safe := DisplayServer.get_display_safe_area()
	return {
		"display": DisplayServer.get_name(),
		"screen": _vec_array(DisplayServer.screen_get_size()),
		"window": _vec_array(win_size),
		"safe_area": _rect_array(safe),
		"cutouts": cutouts,
		"refresh_hz": _refresh_hz(),
		"dpi": DisplayServer.screen_get_dpi(),
		"max_fps": Engine.max_fps,
		"view": _vec_array(get_tree().root.get_visible_rect().size),
	}


## -1 (onbekend) en NaN worden 0, zodat het JSON blijft.
func _refresh_hz() -> float:
	var hz := DisplayServer.screen_get_refresh_rate()
	return snappedf(hz, 0.1) if is_finite(hz) and hz > 0.0 else 0.0


func _vec_array(v: Vector2i) -> Array:
	return [v.x, v.y]


func _rect_array(r: Rect2) -> Array:
	return [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]


## Alleen op een telefoon (op PC geen cutouts; zo blijft de SessieLog van de tests ongewijzigd).
## Alleen bij een wijziging: draaien van het toestel of een nieuwe inset geeft een nieuwe regel.
func _log_display_info() -> void:
	if not is_inside_tree() or not _is_mobile():
		return
	var info := display_info()
	var key := JSON.stringify(info)
	if key == _last_info_key:
		return
	_last_info_key = key
	print("[AppLifecycle] display ", key)
	var sl := get_node_or_null("/root/SessieLog")
	if sl != null and sl.has_method("noteer"):
		sl.call("noteer", "scherm", info)
