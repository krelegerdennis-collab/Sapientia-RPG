extends Node
## TC-P titelkaart (prototype). Start: godot --path . -- --tcptest [--shots=/pad]
## Dispatch alleen via game_state.gd; geen tests.yml.

const SD := preload("res://scripts/data/story_data.gd")

const HUIS := SD.HOUSE
const SHOT_REL := "res://docs/screenshots/tc_p_titelkaart.png"

var failures := 0
var passes := 0
var shots := ""

var _tc_p_active_frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shots="):
			shots = str(arg).get_slice("=", 1)
	if not Story.tc_p_card_active_changed.is_connected(_on_tc_p_signal):
		Story.tc_p_card_active_changed.connect(_on_tc_p_signal)
	call_deferred("_run")


func _on_tc_p_signal(active: bool) -> void:
	if active:
		_tc_p_active_frames += 1


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	if has_node("/root/Crt") and Crt.has_method("set_enabled"):
		Crt.set_enabled(false)
	_hook_statisch()
	await _suite_normaal()
	await _suite_skip()
	await _suite_geen_dubbel_logica()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _hook_statisch() -> void:
	var hit := false
	for row in SD.MAP_ENTER:
		if str(row.get("event", "")) == "catastrofe" and str(row.get("map", "")) == "huis":
			var st: Variant = row.get("if", {})
			if st is Dictionary and int((st as Dictionary).get("step", -1)) == SD.AVOND:
				hit = true
				break
	check("haak: MAP_ENTER huis + stap AVOND -> catastrofe (zegel-/proloog-scène; geen CS-01-id in repo)", hit)


func _suite_normaal() -> void:
	_tc_p_active_frames = 0
	var shot_conn := Callable(self, "_on_tc_p_for_screenshot")
	if not Story.tc_p_card_active_changed.is_connected(shot_conn):
		Story.tc_p_card_active_changed.connect(shot_conn, CONNECT_ONE_SHOT)
	GameState.new_game("Dax")
	GameState.story_flags.erase(SD.TC_P_SHOWN)
	GameState.change_map(HUIS, "lezen")
	await _wacht_map(HUIS)
	var p: Node = get_tree().current_scene.get_node_or_null("Objects/Player")
	check("speler op huis-map", p != null)
	Story.run("catastrofe")
	await _advance_dialog_while_story()
	check("TC-P signaal/minstens één actief-frame", _tc_p_active_frames > 0)
	check("TC-P vlag gezet", GameState.story_flags.has(SD.TC_P_SHOWN))
	check("tc_p_card_active uit", not Story.tc_p_card_active)
	p = get_tree().current_scene.get_node_or_null("Objects/Player") if get_tree().current_scene != null else null
	if p != null and is_instance_valid(p):
		check("input hersteld na normale eind", not bool(p.get("input_locked")))


func _on_tc_p_for_screenshot(active: bool) -> void:
	if not active:
		return
	call_deferred("_deferred_screenshot_tijdens_kaart")


func _deferred_screenshot_tijdens_kaart() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_screenshot_naar_docs()


func _suite_skip() -> void:
	_tc_p_active_frames = 0
	GameState.new_game("Dax")
	GameState.story_flags.erase(SD.TC_P_SHOWN)
	GameState.change_map(HUIS, "lezen")
	await _wacht_map(HUIS)
	var p: Node = get_tree().current_scene.get_node_or_null("Objects/Player")
	Story.run("catastrofe")
	await _pump_until_tc_p()
	var deadline := Time.get_ticks_msec() + 120000
	while not Story.tc_p_card_active and Story.running and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check("kaart actief voor skip", Story.tc_p_card_active)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	deadline = Time.get_ticks_msec() + 120000
	while (Story.running or Story.tc_p_card_active) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check("story idle na skip", Story.idle())
	check("TC-P vlag na skip", GameState.story_flags.has(SD.TC_P_SHOWN))
	p = get_tree().current_scene.get_node_or_null("Objects/Player") if get_tree().current_scene != null else null
	if p != null and is_instance_valid(p):
		check("input hersteld na skip", not bool(p.get("input_locked")))


func _suite_geen_dubbel_logica() -> void:
	GameState.new_game("Dax")
	check("TC-P tonen na catastrofe (geen vlag)", Story.tc_p_should_show_after_event("catastrofe"))
	GameState.story_flags[SD.TC_P_SHOWN] = true
	check("TC-P niet nog eens (vlag gezet)", not Story.tc_p_should_show_after_event("catastrofe"))
	check("ander event: geen TC-P", not Story.tc_p_should_show_after_event("keuze"))


func _advance_dialog_while_story() -> void:
	var deadline := Time.get_ticks_msec() + 300000
	while Story.running and Time.get_ticks_msec() < deadline:
		if Dialog.is_open:
			Dialog.advance()
		await get_tree().process_frame


func _pump_until_tc_p() -> void:
	var deadline := Time.get_ticks_msec() + 300000
	while Story.running and not Story.tc_p_card_active and Time.get_ticks_msec() < deadline:
		if Dialog.is_open:
			Dialog.advance()
		await get_tree().process_frame


func _wacht_map(pad: String) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		var sc := get_tree().current_scene
		if sc != null and str(sc.scene_file_path) == pad:
			return
		await get_tree().process_frame


func _screenshot_naar_docs() -> void:
	var pad: String
	if shots != "":
		pad = shots.path_join("tc_p_titelkaart.png")
	else:
		pad = ProjectSettings.globalize_path(SHOT_REL)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		check("viewport image voor screenshot", false)
		return
	var err := img.save_png(pad)
	check("screenshot save_png ok (%s)" % pad, err == OK)
