extends Node
## Gast-instantie voor --coopplaytesttest (eigen Godot-proces, geen losse suite).
## Start: godot --path . -- --coopplaytestgast --relay=ws://.. --code=XXXXXX --status=/pad --cmd=/pad [--via=title|hal]
## Speelt de gast zoals op de telefoon: titel/hal -> Join online -> code -> Ready -> spel -> terug.
## Schrijft zijn staat als JSON naar --status en leest opdrachten (één per regel) uit --cmd.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const HalScene :="res://scenes/coop/online_hal.tscn"
const CoopLobbyScene := "res://scenes/ui/coop_lobby.tscn"
const LIFETIME_SEC := 150.0

var relay := ""
var code := ""
var status_path := ""
var cmd_path := ""
var via := "hal"
var _done_cmds := 0
var _state: Dictionary = {}
var _stick := Vector2.ZERO
var _born := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_born = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		var s := str(arg)
		if s.begins_with("--relay="):
			relay = s.get_slice("=", 1)
		elif s.begins_with("--code="):
			code = s.get_slice("=", 1)
		elif s.begins_with("--status="):
			status_path = s.get_slice("=", 1)
		elif s.begins_with("--cmd="):
			cmd_path = s.get_slice("=", 1)
		elif s.begins_with("--via="):
			via = s.get_slice("=", 1)
	OS.set_environment(Protocol.RELAY_URL_ENV, relay)
	# Eigen user:// (de host start ons met een eigen XDG_DATA_HOME): eigen M1-profiel, zoals op de telefoon.
	var store := Profile.new()
	if not store.has_slot(0):
		store.create_slot(0, "Guest", "warrior")
	_note("boot", true)
	_begin.call_deferred()


func _begin() -> void:
	if via == "title":
		# Zoals Titel > Co-op: de gewone (LAN/online) lobby als hoofdscène.
		get_tree().change_scene_to_file(CoopLobbyScene)
	else:
		get_tree().change_scene_to_file(HalScene)
	await _frames(4)
	_note("first_scene", _scene_path())
	await _join(code)


func _join(room: String) -> void:
	var screen := _screen()
	if screen == null:
		_note("error", "geen lobby-scherm")
		return
	if screen._screen != CoopLobbyScreen.Screen.MENU:
		screen._show_menu()
		await _frames(1)
	var join := _button(screen, "Join online")
	if join == null:
		_note("error", "geen Join online")
		return
	join.pressed.emit()
	# Titel-route: de knop brengt de gast naar de online hal. Wacht op het codevak daar.
	var edit_ok := await _wait(func() -> bool:
		var s := _screen()
		return s != null and s._code_edit != null and is_instance_valid(s._code_edit)
	, 5.0)
	if not edit_ok:
		_note("error", "geen codevak")
		return
	var s2 := _screen()
	_note("code_screen_scene", _scene_path())
	# Zoals een tik op het vak: focus (op de telefoon gaat dan het toetsenbord open).
	s2._code_edit.grab_focus()
	_note("keyboard_focus_before", s2._code_edit.has_focus())
	s2._code_edit.text = room
	s2._submit_code()
	_note("join_version", s2.lobby.protocol_version)
	_note("code_focus_after_submit", is_instance_valid(s2._code_edit) and s2._code_edit.has_focus())


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _born > int(LIFETIME_SEC * 1000.0):
		_note("timeout", true)
		get_tree().quit(2)
		return
	_publish()
	_read_cmds()


func _publish() -> void:
	var hal := _hal()
	var lob := _lobby()
	_state["scene"] = _scene_path()
	_state["in_hal"] = hal != null
	_state["phase"] = int(lob.phase) if lob != null else -1
	_state["slot"] = int(lob.local_slot) if lob != null else -1
	_state["version"] = int(lob.protocol_version) if lob != null else 0
	_state["players"] = lob.player_count() if lob != null else 0
	_state["hal_started"] = hal != null and hal.started
	var screen := _screen()
	_state["menu"] = screen != null and screen.visible and screen._screen == CoopLobbyScreen.Screen.MENU
	_state["message"] = screen._message if screen != null and screen.visible and screen._screen == CoopLobbyScreen.Screen.MESSAGE else ""
	_state["folded"] = screen != null and screen.folded
	_state["in_run"] = _run() != null
	var run := _run()
	_state["run_ready"] = run != null and run.has_method("is_live") and run.is_live()
	if hal != null and hal.local_body() != null:
		_state["hal_x"] = hal.local_body().position.x
	if hal != null:
		hal.set_stick(_stick)
	if run != null and run.has_method("set_stick"):
		run.set_stick(_stick)
	_state["run_seed"] = OnlineDlsRun.run_seed if OnlineDlsRun.active else -1
	_state["run_floor"] = OnlineDlsRun.floor_no if OnlineDlsRun.active else 0
	if run != null and run.som != null and is_instance_valid(run.som):
		var host_body: Node2D = run.som._coop_body(0)
		if host_body != null:
			_state["run_host_x"] = host_body.position.x
	if status_path != "":
		# Eerst naar .tmp, dan hernoemen: de host leest nooit een half bestand.
		var tmp := status_path + ".tmp"
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_state))
			f.close()
			DirAccess.rename_absolute(tmp, status_path)


func _read_cmds() -> void:
	if cmd_path == "" or not FileAccess.file_exists(cmd_path):
		return
	var lines := FileAccess.get_file_as_string(cmd_path).split("\n", false)
	while _done_cmds < lines.size():
		var c := str(lines[_done_cmds]).strip_edges()
		_done_cmds += 1
		_do(c)


func _do(c: String) -> void:
	_note("last_cmd", c)
	if c.begins_with("join "):
		_join(c.substr(5).strip_edges())
		return
	match c:
		"stick_right":
			_stick = Vector2.RIGHT
		"stick_left":
			_stick = Vector2.LEFT
		"stick_stop":
			_stick = Vector2.ZERO
		"ready":
			var hal := _hal()
			if hal != null:
				hal.toggle_ready()
		"leave":
			var run := _run()
			if run != null and run.has_method("leave"):
				run.leave()
			else:
				var hal := _hal()
				if hal != null and hal.has_method("leave"):
					hal.leave()
		"quit":
			get_tree().quit(0)


func _note(key: String, value: Variant) -> void:
	_state[key] = value


func _scene_path() -> String:
	var cs := get_tree().current_scene
	return cs.scene_file_path if cs != null else ""


func _hal() -> OnlineHal:
	return get_tree().current_scene as OnlineHal


func _run() -> Node:
	var cs := get_tree().current_scene
	if cs != null and cs.is_in_group("online_run"):
		return cs
	return null


func _lobby() -> LanLobby:
	var hal := _hal()
	if hal != null and hal.active_lobby() != null:
		return hal.active_lobby()
	var s := _screen()
	if s != null:
		return s.lobby
	return GameState.coop_lobby()


func _screen() -> CoopLobbyScreen:
	var cs := get_tree().current_scene
	if cs == null:
		return null
	if cs is CoopLobbyScreen:
		return cs
	return cs.find_child("CodeScreen", true, false) as CoopLobbyScreen


func _button(screen: CoopLobbyScreen, label: String) -> Button:
	for b in screen.all_touch_buttons():
		if str(b.get_meta("label", "")) == label:
			return b
	return null


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _wait(pred: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if pred.call():
			return true
		await get_tree().process_frame
	return pred.call()
