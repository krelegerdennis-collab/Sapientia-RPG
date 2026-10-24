extends Control
class_name CoopLobbyScreen
## Co-op lobby (fase B): LAN, en online via de relay als er een relay-URL is ingesteld
## (Protocol.relay_url(); leeg = alleen LAN). Engelse speler-tekst; gebruikt scripts/net/* API.

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const LobbyScript := preload("res://scripts/net/lan_lobby.gd")
const DiscoveryScript := preload("res://scripts/net/lan_discovery.gd")

## Android 48dp minimum; bij viewport 384 en window override 1152 is dat 16 logische px.
const TOUCH_TARGET_DP := 48

signal leave_requested

enum Screen { MENU, HOST, JOIN, JOIN_CODE, MESSAGE }

var lobby: LanLobby
var discovery: LanDiscovery

var _screen: Screen = Screen.MENU
var _panel: PanelContainer
var _box: VBoxContainer
var _hosts: Dictionary = {}
var _message: String = ""
var _joining_ip: String = ""
var _joining_code: String = ""
var _code_edit: LineEdit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = load(UiMenu.THEME_PATH)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(384, 216)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_panel = UiMenu.panel()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 12.0
	_panel.offset_top = 10.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = -10.0
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_panel.add_child(_box)
	lobby = LobbyScript.new()
	lobby.name = "CoopLobby"
	add_child(lobby)
	discovery = DiscoveryScript.new()
	discovery.name = "CoopDiscovery"
	add_child(discovery)
	lobby.roster_changed.connect(_on_roster_changed)
	lobby.assigned.connect(_on_assigned)
	lobby.refused.connect(_on_refused)
	lobby.link_lost.connect(_on_link_lost)
	lobby.start_game_received.connect(_on_start_game_received)
	lobby.session_ended.connect(_on_session_ended)
	lobby.room_ready.connect(_on_room_ready)
	discovery.host_found.connect(_on_host_found)
	GameState.coop_register_lobby(lobby, discovery)
	_show_menu()


func _exit_tree() -> void:
	GameState.coop_clear_lobby_refs()
	_teardown_net()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and lobby.is_host:
		_end_host_session(Protocol.SESSION_END_HOST_PAUSED)


func _teardown_net() -> void:
	discovery.stop()
	lobby.close()


func _clear_box() -> void:
	for c in _box.get_children():
		c.queue_free()


func _show_menu() -> void:
	_teardown_net()
	_screen = Screen.MENU
	_hosts.clear()
	_joining_ip = ""
	_joining_code = ""
	_message = ""
	_rebuild()


func _show_host() -> void:
	_teardown_net()
	_screen = Screen.HOST
	var err := lobby.host_session(_host_display_name())
	if err != OK:
		_show_message(Protocol.net_error_text("Could not host", err, Protocol.ENET_PORT))
		return
	err = discovery.start_announce(_host_display_name(), lobby.player_count())
	if err != OK:
		lobby.close()
		_show_message(Protocol.net_error_text("Could not open LAN beacon", err, Protocol.ANNOUNCE_BIND_PORT))
		return
	GameState.coop_register_lobby(lobby, discovery)
	_rebuild()


func _show_host_online() -> void:
	_teardown_net()
	_screen = Screen.HOST
	var err := lobby.host_relay(Protocol.relay_url(), _host_display_name())
	if err != OK:
		_show_message("Could not open an online room (%s)." % Protocol.error_name(err))
		return
	GameState.coop_register_lobby(lobby, null)
	_rebuild()


func _show_join_code() -> void:
	_teardown_net()
	_screen = Screen.JOIN_CODE
	_joining_code = ""
	_rebuild()


func _join_online(code: String) -> void:
	_joining_code = code
	_rebuild()
	var err := lobby.join_relay(Protocol.relay_url(), code, "", _guest_display_name())
	if err != OK:
		_joining_code = ""
		_show_message("Could not join online (%s)." % Protocol.error_name(err))
		return
	GameState.coop_register_lobby(lobby, null)


func _on_room_ready(_code: String) -> void:
	if _screen == Screen.HOST:
		_rebuild()


func _show_join_listen() -> void:
	_teardown_net()
	_screen = Screen.JOIN
	_hosts.clear()
	var err := discovery.start_listen()
	if err != OK:
		_show_message(Protocol.net_error_text("Could not listen for hosts", err, Protocol.DISCOVERY_PORT))
		return
	GameState.coop_register_lobby(lobby, discovery)
	_rebuild()


func _show_message(text: String) -> void:
	_screen = Screen.MESSAGE
	_message = text
	_rebuild()


func _rebuild() -> void:
	_clear_box()
	match _screen:
		Screen.MENU:
			_build_menu()
		Screen.HOST:
			_build_host()
		Screen.JOIN:
			_build_join()
		Screen.JOIN_CODE:
			_build_join_code()
		Screen.MESSAGE:
			_build_message()


func _build_menu() -> void:
	var online := Protocol.relay_url() != ""
	_box.add_child(UiMenu.label("Co-op (LAN / Online)" if online else "Co-op (LAN)", UiStyleC.HILITE, 12))
	_box.add_child(UiMenu.label("Action sandbox, up to 4 players.", UiStyleC.TEXT_DIM, 8))
	var host := _touch_button("Host")
	host.pressed.connect(func() -> void: _show_host())
	_box.add_child(host)
	var join := _touch_button("Join")
	join.pressed.connect(func() -> void: _show_join_listen())
	_box.add_child(join)
	if online:
		var host_online := _touch_button("Host online")
		host_online.pressed.connect(func() -> void: _show_host_online())
		_box.add_child(host_online)
		var join_online := _touch_button("Join online")
		join_online.pressed.connect(func() -> void: _show_join_code())
		_box.add_child(join_online)
	_box.add_child(UiMenu.label("Friend mode (PvP) is separate.", UiStyleC.TEXT_DIM, 8))
	var back := _touch_button("Back")
	back.pressed.connect(_on_back)
	_box.add_child(back)


func _build_host() -> void:
	var online := lobby.transport == LanLobby.Transport.RELAY
	_box.add_child(UiMenu.label("Hosting online as Dax" if online else "Hosting as Dax", UiStyleC.HILITE, 10))
	if online:
		if lobby.room_code == "":
			_box.add_child(UiMenu.label("Connecting to the online server…", UiStyleC.TEXT_DIM, 8))
		else:
			_box.add_child(UiMenu.label("Room code: %s" % lobby.room_code, UiStyleC.HILITE, 12))
			_box.add_child(UiMenu.label("Friends tap Join online and enter this code.", UiStyleC.TEXT_DIM, 8))
	else:
		_box.add_child(UiMenu.label("Waiting for friends on Wi‑Fi…", UiStyleC.TEXT_DIM, 8))
	_add_roster_rows(true)
	var start := _touch_button("Start Action sandbox")
	start.disabled = not lobby.is_host or (online and lobby.room_code == "")
	start.pressed.connect(_on_host_start)
	_box.add_child(start)
	var cancel := _touch_button("Cancel")
	cancel.pressed.connect(_show_menu)
	_box.add_child(cancel)


func _build_join() -> void:
	if _joining_ip != "":
		_box.add_child(UiMenu.label("Joining %s…" % _joining_ip, UiStyleC.TEXT_DIM, 8))
		var cancel := _touch_button("Cancel")
		cancel.pressed.connect(_show_join_listen)
		_box.add_child(cancel)
		return
	_box.add_child(UiMenu.label("Nearby hosts", UiStyleC.HILITE, 10))
	_box.add_child(UiMenu.label("Tap a host to join.", UiStyleC.TEXT_DIM, 8))
	if _hosts.is_empty():
		_box.add_child(UiMenu.label("Searching…", UiStyleC.TEXT_DIM, 8))
	else:
		for ip in _hosts.keys():
			var info: Dictionary = _hosts[ip]
			var line := "%s  (%d/%d)" % [str(info.get("name", "?")), int(info.get("players", 0)), Protocol.MAX_PLAYERS]
			var btn := _touch_button(line)
			btn.pressed.connect(func() -> void: _join_host(ip))
			_box.add_child(btn)
	var back := _touch_button("Back")
	back.pressed.connect(_show_menu)
	_box.add_child(back)


func _build_join_code() -> void:
	if _joining_code != "":
		_box.add_child(UiMenu.label("Joining room %s…" % _joining_code, UiStyleC.TEXT_DIM, 8))
		var cancel := _touch_button("Cancel")
		cancel.pressed.connect(_show_join_code)
		_box.add_child(cancel)
		return
	_box.add_child(UiMenu.label("Join online", UiStyleC.HILITE, 10))
	_box.add_child(UiMenu.label("Enter the %d-character room code." % Protocol.ROOM_CODE_LENGTH, UiStyleC.TEXT_DIM, 8))
	_code_edit = LineEdit.new()
	_code_edit.max_length = Protocol.ROOM_CODE_LENGTH
	_code_edit.placeholder_text = "ROOM CODE"
	_code_edit.virtual_keyboard_enabled = true
	_code_edit.custom_minimum_size = Vector2(0.0, float(touch_min_height_px()))
	_code_edit.add_theme_stylebox_override("normal", UiMenu.window_style(UiStyleC.BORDER_DARK, 1.0))
	_code_edit.add_theme_stylebox_override("focus", UiMenu.window_style(UiStyleC.MAGENTA, 1.0))
	_code_edit.add_theme_color_override("font_color", UiStyleC.TEXT)
	_code_edit.add_theme_color_override("caret_color", UiStyleC.MAGENTA)
	_box.add_child(_code_edit)
	var go := _touch_button("Join")
	go.disabled = true
	go.pressed.connect(func() -> void: _submit_code())
	_box.add_child(go)
	_code_edit.text_changed.connect(func(t: String) -> void: _on_code_changed(t, go))
	_code_edit.text_submitted.connect(func(_t: String) -> void: _submit_code())
	var back := _touch_button("Back")
	back.pressed.connect(_show_menu)
	_box.add_child(back)


func _on_code_changed(raw: String, go: Button) -> void:
	var clean := Protocol.filter_room_code(raw)
	if clean != raw:
		_code_edit.text = clean
		_code_edit.caret_column = clean.length()
	go.disabled = not Protocol.is_room_code(clean)


func _submit_code() -> void:
	if _code_edit == null:
		return
	var code := Protocol.filter_room_code(_code_edit.text)
	if Protocol.is_room_code(code):
		_join_online(code)


func _build_message() -> void:
	var msg := UiMenu.label(_message, UiStyleC.TEXT, 9)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_child(msg)
	var ok := _touch_button("Back to title")
	ok.pressed.connect(_leave_to_title)
	_box.add_child(ok)


static func touch_min_height_px() -> int:
	var vw := int(ProjectSettings.get_setting("display/window/size/viewport_width", 384))
	var ow := int(ProjectSettings.get_setting("display/window/size/window_width_override", vw))
	var scale := maxf(1.0, float(ow) / float(vw))
	return int(ceil(float(TOUCH_TARGET_DP) / scale))


func _touch_button(text: String) -> Button:
	var btn := UiMenu.button(text)
	var h := float(touch_min_height_px())
	btn.custom_minimum_size = Vector2(0.0, maxf(btn.custom_minimum_size.y, h))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn


func all_touch_buttons() -> Array[Button]:
	var out: Array[Button] = []
	_collect_buttons(_box, out)
	return out


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)


func _add_roster_rows(host_view: bool) -> void:
	var seat_names: Array[String] = ["Dax", "Seren", "Vesper", "Kael"]
	for slot in Protocol.MAX_PLAYERS:
		var who := _seat_label(slot)
		if who == "":
			who = "Empty"
		var prefix := "Seat %d: " % slot
		if host_view and slot == Protocol.HOST_SLOT:
			prefix = "Host: "
		_box.add_child(UiMenu.label(prefix + who, UiStyleC.TEXT_DIM if who == "Empty" else UiStyleC.TEXT, 8))


func _seat_label(slot: int) -> String:
	var cid := lobby.character_at(slot)
	if cid == "":
		return ""
	return _hero_name(cid)


func _hero_name(character_id: String) -> String:
	for row in GameData.HEROES:
		if str(row.get("id", "")) == character_id:
			return str(row.get("name", character_id))
	return character_id


func _host_display_name() -> String:
	var n := str(GameState.player_name).strip_edges()
	if n == "":
		return "Dax"
	return Protocol.clean_name(n)


func _guest_display_name() -> String:
	return Protocol.clean_name(str(GameState.player_name))


func _on_host_found(info: Dictionary) -> void:
	var ip := str(info.get("ip", ""))
	if ip == "":
		return
	_hosts[ip] = info
	if _screen == Screen.JOIN and _joining_ip == "":
		_rebuild()


func _join_host(ip: String) -> void:
	_joining_ip = ip
	discovery.stop()
	_rebuild()
	var err := lobby.join_session(ip, "", _guest_display_name())
	if err != OK:
		_joining_ip = ""
		_show_message(Protocol.net_error_text("Could not connect", err, Protocol.ENET_PORT))
		return
	GameState.coop_register_lobby(lobby, null)


func _on_assigned(_slot: int, _character_id: String) -> void:
	if _is_join_screen():
		_joining_ip = ""
		_joining_code = ""
		_rebuild_join_guest()


func _is_join_screen() -> bool:
	return _screen == Screen.JOIN or _screen == Screen.JOIN_CODE


func _on_roster_changed() -> void:
	if lobby.is_host and lobby.transport == LanLobby.Transport.LAN:
		discovery.set_player_count(lobby.player_count())
		if lobby.player_count() >= Protocol.MAX_PLAYERS:
			discovery.stop()
	if _screen == Screen.HOST:
		_rebuild()
	if _is_join_screen() and lobby.phase == LanLobby.Phase.IN:
		_rebuild_join_guest()


func _rebuild_join_guest() -> void:
	_clear_box()
	_box.add_child(UiMenu.label("Joined %s" % _hero_name(lobby.local_character), UiStyleC.HILITE, 10))
	_add_roster_rows(false)
	_box.add_child(UiMenu.label("Waiting for the host to start…", UiStyleC.TEXT_DIM, 8))
	var leave := UiMenu.button("Leave")
	leave.pressed.connect(_show_menu)
	_box.add_child(leave)


func _on_refused(reason: int) -> void:
	var text := str(Protocol.REFUSE_TEXT.get(reason, "Could not join."))
	if lobby.transport == LanLobby.Transport.RELAY and reason == Protocol.Refuse.TIMEOUT:
		text = Protocol.relay_error_text(lobby.relay_reason)
	_joining_ip = ""
	_joining_code = ""
	_show_message(text)


func _on_link_lost() -> void:
	if lobby.transport == LanLobby.Transport.RELAY and lobby.relay_reason != "":
		_show_message(Protocol.relay_error_text(lobby.relay_reason))
		return
	_show_message("Connection lost.")


func _on_session_ended(reason: String) -> void:
	_teardown_net()
	GameState.coop_role = ""
	_show_message(GameState.coop_session_end_message(reason))


func _on_host_start() -> void:
	if not lobby.is_host:
		return
	discovery.stop()
	_persist_net_nodes()
	lobby.host_start_game()
	await GameState.start_som_coop_host()


func _on_start_game_received() -> void:
	discovery.stop()
	_persist_net_nodes()
	await GameState.start_som_coop_guest(lobby.local_character)


func _persist_net_nodes() -> void:
	if lobby.get_parent() != GameState:
		lobby.reparent(GameState)
	if discovery.get_parent() != GameState:
		discovery.reparent(GameState)
	GameState.coop_register_lobby(lobby, discovery)


func _end_host_session(reason: String) -> void:
	if not lobby.is_host:
		return
	lobby.broadcast_session_end(reason)
	_teardown_net()
	GameState.coop_role = ""
	_show_message(GameState.coop_session_end_message(reason))


func _on_back() -> void:
	if _screen == Screen.MENU:
		_leave_to_title()
	else:
		_show_menu()


func _leave_to_title() -> void:
	GameState.coop_end_session()
	_teardown_net()
	leave_requested.emit()
	if get_parent() == get_tree().root:
		get_tree().change_scene_to_file(GameState.TITLE_SCENE)
