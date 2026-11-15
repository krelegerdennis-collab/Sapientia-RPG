extends Node
## F6-3 + F6-4: Android-systeemterug en de Back-knop op het naamscherm.
## Start: godot --path . -- --androidbacktest [--shots=/pad]
## Niet in de CI-matrix. Bestaande suites worden niet aangepast.
##
## Systeemterug = NOTIFICATION_WM_GO_BACK_REQUEST op de boom, daarna het
## Window-signaal go_back_requested (zo doet de engine het). Dat mag niet stoppen.

const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const StoryData := preload("res://scripts/data/story_data.gd")
const TOWN := "res://scenes/maps/wilgendal.tscn"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shots="):
			shots = str(arg).get_slice("=", 1)
	GameState.encounter_multiplier = 0.0
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _scene() -> Node:
	return get_tree().current_scene


func _wait(pred: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if bool(pred.call()):
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(pred.call())


## Aanroepen na een beeldgrens. De melding landt vóór _process; het volgende beeld
## ziet het resultaat (menu dicht, scène gewisseld) en het spel nog in leven.
func _go_back() -> void:
	await get_tree().process_frame
	get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not get_tree().quit_on_go_back:
		get_tree().root.go_back_requested.emit()
	await get_tree().process_frame


func _alive(where: String) -> void:
	var tree := get_tree()
	check("%s: geen quit, scène staat er nog" % where, tree != null and is_inside_tree() and tree.current_scene != null)


func _run() -> void:
	_config()
	await _title_back()
	await _field_menu_back()
	await _name_back()
	await _name_button()
	await _name_ok()
	await _name_enter()
	print("ANDROIDBACKTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _config() -> void:
	check("quit_on_go_back staat uit", not get_tree().quit_on_go_back)
	check("project: application/config/quit_on_go_back = false",
			not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_BACK
	check("KEY_BACK zit op de actie cancel", InputMap.event_is_action(key, "cancel"))
	check("start_new_game is nog niet aangeroepen", GameState.new_game_starts == 0)


func _title_back() -> void:
	var on_title := await _wait(func() -> bool:
		var s := _scene()
		return s != null and s.name == "Title" and s.is_node_ready()
	, 15.0)
	check("spel start op het titelscherm", on_title)
	if not on_title:
		return
	var starts := GameState.new_game_starts
	await _go_back()
	var s := _scene()
	check("titel + systeemterug: blijft op het titelscherm", s != null and s.name == "Title")
	check("titel + systeemterug: start_new_game niet aangeroepen", GameState.new_game_starts == starts)
	_alive("titel + systeemterug")


func _field_menu_back() -> void:
	GameState.new_game("Kees")
	GameState.story_step = StoryData.KLAAR
	GameState.change_map(TOWN, "start")
	var loaded := await _wait(func() -> bool:
		var s := _scene()
		return s != null and s.name == "Wilgendal" and s.is_node_ready() and not GameState.changing_map \
				and s.get_node_or_null("Objects/Player") != null
	, 20.0)
	check("Wilgendal geladen", loaded)
	if not loaded:
		return
	var map := _scene()
	var starts := GameState.new_game_starts
	map.open_field_menu()
	var opened := await _wait(func() -> bool:
		return map.get_node_or_null("FieldMenu") != null
	, 3.0)
	check("veldmenu is open", opened)
	if not opened:
		return
	await _go_back()
	check("veldmenu + systeemterug: menu dicht", map.get_node_or_null("FieldMenu") == null)
	check("veldmenu + systeemterug: nog in Wilgendal", _scene() == map and map.name == "Wilgendal")
	check("veldmenu + systeemterug: start_new_game niet aangeroepen", GameState.new_game_starts == starts)
	_alive("veldmenu + systeemterug")

	map.open_field_menu()
	var again := await _wait(func() -> bool:
		return map.get_node_or_null("FieldMenu") != null
	, 3.0)
	check("veldmenu opnieuw open", again)
	if not again:
		return
	var menu: Node = map.get_node("FieldMenu")
	menu.choose("options")
	var opts := await _wait(func() -> bool:
		return is_instance_valid(menu) and menu.sub != null and str(menu.sub.name) == "Options" and menu.sub.is_node_ready()
	, 5.0)
	check("opties zijn open", opts)
	if not opts:
		return
	await _go_back()
	check("opties + systeemterug: terug in het veldmenu", is_instance_valid(menu) and not menu.is_queued_for_deletion() \
			and menu.sub == null and map.get_node_or_null("FieldMenu") == menu)
	check("opties + systeemterug: nog in Wilgendal", _scene() == map)
	check("opties + systeemterug: start_new_game niet aangeroepen", GameState.new_game_starts == starts)
	_alive("opties + systeemterug")
	if is_instance_valid(menu):
		menu.close()
		await _wait(func() -> bool: return map.get_node_or_null("FieldMenu") == null, 2.0)


func _open_name() -> Node:
	get_tree().change_scene_to_file(GameState.NAME_SCENE)
	var ok := await _wait(func() -> bool:
		var s := _scene()
		if s == null or s.name != "NameEntry" or not s.is_node_ready():
			return false
		var edit: LineEdit = s.get("edit")
		var back: Control = s.get("back_button")
		return edit != null and edit.has_focus() and back != null and back.size.y >= UiTouchC.TOUCH_MIN - 0.01
	, 8.0)
	if not ok:
		return null
	return _scene()


func _name_back() -> void:
	var s := await _open_name()
	check("naamscherm: vak heeft focus", s != null)
	if s == null:
		return
	var starts := GameState.new_game_starts
	check("naamscherm: LineEdit heeft focus vlak voor systeemterug", (s.get("edit") as LineEdit).has_focus())
	await _go_back()
	var now := _scene()
	check("naamscherm + systeemterug (vak focused): naar het titelscherm", now != null and now.name == "Title")
	check("naamscherm + systeemterug: start_new_game niet aangeroepen", GameState.new_game_starts == starts)
	_alive("naamscherm + systeemterug")


func _name_button() -> void:
	var s := await _open_name()
	check("naamscherm voor de Back-knop", s != null)
	if s == null:
		return
	var back: Button = s.get("back_button")
	var ok_button: Button = s.get("ok_button")
	check("Back-knop bestaat", back != null and ok_button != null)
	if back == null or ok_button == null:
		return
	check("Back-knop label is exact Back", str(back.get_meta("label", "")) == "Back")
	check("Back-knop zichtbaar", back.visible and not back.disabled)
	check("Back-knop hoogte >= tikmaat", back.size.y >= UiTouchC.TOUCH_MIN - 0.01)
	check("Back-knop dezelfde tikmaat als OK", back.custom_minimum_size == ok_button.custom_minimum_size \
			and ok_button.size.y >= UiTouchC.TOUCH_MIN - 0.01)
	await _shot("android_back_name")
	var starts := GameState.new_game_starts
	back.pressed.emit()
	var back_home := await _wait(func() -> bool:
		var now := _scene()
		return now != null and now.name == "Title" and now.is_node_ready()
	, 8.0)
	check("Back-knop: naar het titelscherm", back_home)
	check("Back-knop: start_new_game niet aangeroepen", GameState.new_game_starts == starts)
	_alive("Back-knop")


func _name_ok() -> void:
	var s := await _open_name()
	check("naamscherm voor OK", s != null)
	if s == null:
		return
	var before := GameState.new_game_starts
	var ok_button: Button = s.get("ok_button")
	ok_button.pressed.emit()
	check("OK roept start_new_game aan", GameState.new_game_starts == before + 1)
	var started := await _wait(func() -> bool:
		var now := _scene()
		return now != null and now.name == "Huis" and now.is_node_ready() and not GameState.changing_map
	, 20.0)
	check("OK start een nieuw spel (huis)", started)
	_alive("OK")


func _name_enter() -> void:
	var s := await _open_name()
	check("naamscherm voor Enter", s != null)
	if s == null:
		return
	var before := GameState.new_game_starts
	var edit: LineEdit = s.get("edit")
	check("Enter: vak heeft nog focus", edit != null and edit.has_focus())
	await get_tree().process_frame
	var down := InputEventKey.new()
	down.keycode = KEY_ENTER
	down.physical_keycode = KEY_ENTER
	down.pressed = true
	Input.parse_input_event(down)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	var started := await _wait(func() -> bool:
		return GameState.new_game_starts == before + 1
	, 3.0)
	check("Enter start een nieuw spel", started and GameState.new_game_starts == before + 1)
	var left := await _wait(func() -> bool:
		var now := _scene()
		return now != null and now.name != "NameEntry"
	, 20.0)
	check("Enter verlaat het naamscherm", left)
	_alive("Enter")


func _shot(file_name: String) -> void:
	if shots == "":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(file_name + ".png"))
