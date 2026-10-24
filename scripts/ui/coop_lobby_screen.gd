extends Control
class_name CoopLobbyScreen
## LAN co-op lobby (fase B). Engelse speler-tekst; gebruikt scripts/net/* API.

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const LobbyScript := preload("res://scripts/net/lan_lobby.gd")
const DiscoveryScript := preload("res://scripts/net/lan_discovery.gd")

## Android 48dp minimum. Eerder gerekend met het testvenster (window override 1152 = 3x): 16 eenheden, op een
## telefoon van 1440 px hoog (6,7 px per eenheid) maar 34dp. Nu UiTouch.MIN_UNITS (26 eenheden = 48dp op 412dp).
const TOUCH_TARGET_DP := 48
const UiTouch := preload("res://scripts/ui/ui_touch.gd")

signal leave_requested

enum Screen { MENU, HOST, JOIN, MESSAGE }

var lobby: LanLobby
var discovery: LanDiscovery

var _screen: Screen = Screen.MENU
var _panel: PanelContainer
var _box: VBoxContainer
var _hosts: Dictionary = {}
var _message: String = ""
var _joining_ip: String = ""


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
		Screen.MESSAGE:
			_build_message()


func _build_menu() -> void:
	_box.add_child(UiMenu.label("Co-op (LAN)", UiStyleC.HILITE, 12))
	_box.add_child(UiMenu.label("Action sandbox, up to 4 players.", UiStyleC.TEXT_DIM, 8))
	var host := _touch_button("Host")
	host.pressed.connect(func() -> void: _show_host())
	_box.add_child(host)
	var join := _touch_button("Join")
	join.pressed.connect(func() -> void: _show_join_listen())
	_box.add_child(join)
	_box.add_child(UiMenu.label("Friend mode (PvP) is separate.", UiStyleC.TEXT_DIM, 8))
	var back := _touch_button("Back")
	back.pressed.connect(_on_back)
	_box.add_child(back)


func _build_host() -> void:
	_box.add_child(UiMenu.label("Hosting as Dax", UiStyleC.HILITE, 10))
	_box.add_child(UiMenu.label("Waiting for friends on Wi‑Fi…", UiStyleC.TEXT_DIM, 8))
	_add_roster_rows(true)
	var start := _touch_button("Start Action sandbox")
	start.disabled = not lobby.is_host
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


func _build_message() -> void:
	var msg := UiMenu.label(_message, UiStyleC.TEXT, 9)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_child(msg)
	var ok := _touch_button("Back to title")
	ok.pressed.connect(_leave_to_title)
	_box.add_child(ok)


static func touch_min_height_px() -> int:
	return int(UiTouch.MIN_UNITS)


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
	if _screen == Screen.JOIN:
		_joining_ip = ""
		_rebuild_join_guest()


func _on_roster_changed() -> void:
	if lobby.is_host:
		discovery.set_player_count(lobby.player_count())
		if lobby.player_count() >= Protocol.MAX_PLAYERS:
			discovery.stop()
	if _screen == Screen.HOST:
		_rebuild()
	if _screen == Screen.JOIN and lobby.phase == LanLobby.Phase.IN:
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
	_joining_ip = ""
	_show_message(text)


func _on_link_lost() -> void:
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
