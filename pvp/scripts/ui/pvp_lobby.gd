extends Control
class_name PvpLobby
## Ingang van Vriendenmodus. Een toekomstige menuknop laadt deze scène.
## De sessies horen bij deze node; er is geen extra autoload.

signal leave_requested

const MENU_SCENE := preload("res://pvp/scenes/pvp_menu.tscn")
const HOST_SCENE := preload("res://pvp/scenes/lobby/host_menu.tscn")
const JOIN_SCENE := preload("res://pvp/scenes/lobby/join_menu.tscn")
const MODE_SCENE := preload("res://pvp/scenes/lobby/mode_select.tscn")
const TEAM_SCENE := preload("res://pvp/scenes/lobby/team_select.tscn")
const DROP_SCENE := preload("res://pvp/scenes/lobby/disconnect_panel.tscn")
const BATTLE_SCENE := preload("res://pvp/scenes/battle/pvp_battle.tscn")
const RESULT_SCENE := preload("res://pvp/scenes/result/result.tscn")

var host_session: PvpSession
var guest_session: PvpSession
var net_kind: String = ""
var role_on_device: String = ""
var _screen: String = "menu"
var _team_seat: String = ""
var _panels: Array[Control] = []

var _menu: PvpMenu
var _host: PvpHostPanel
var _join: PvpJoinPanel
var _mode: PvpModePanel
var _team: PvpTeamPanel
var _drop: PvpDisconnectPanel
var _battle: PvpBattleView
var _result: PvpResultView


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(384, 216)
	PvpStyle.fill(self)
	host_session = PvpSession.new()
	host_session.name = "HostSession"
	add_child(host_session)
	guest_session = PvpSession.new()
	guest_session.name = "GuestSession"
	add_child(guest_session)
	_menu = MENU_SCENE.instantiate() as PvpMenu
	_host = HOST_SCENE.instantiate() as PvpHostPanel
	_join = JOIN_SCENE.instantiate() as PvpJoinPanel
	_mode = MODE_SCENE.instantiate() as PvpModePanel
	_team = TEAM_SCENE.instantiate() as PvpTeamPanel
	_drop = DROP_SCENE.instantiate() as PvpDisconnectPanel
	_battle = BATTLE_SCENE.instantiate() as PvpBattleView
	_result = RESULT_SCENE.instantiate() as PvpResultView
	_panels = [_menu, _host, _join, _mode, _team, _drop, _battle, _result]
	for panel in _panels:
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(panel)
	_menu.host_pressed.connect(_on_menu_host)
	_menu.join_pressed.connect(_on_menu_join)
	_menu.back_pressed.connect(_on_menu_back)
	_host.local_picked.connect(_on_host_local)
	_host.lan_picked.connect(_on_host_lan)
	_host.code_submitted.connect(_on_hotseat_code)
	_host.cancel_pressed.connect(_on_cancel)
	_join.local_picked.connect(_on_join_local)
	_join.lan_picked.connect(_on_join_lan)
	_join.code_submitted.connect(_on_join_code)
	_join.cancel_pressed.connect(_on_cancel)
	_mode.mode_picked.connect(_on_mode_picked)
	_mode.back_pressed.connect(_on_drop_link)
	_team.team_picked.connect(_on_team_picked)
	_team.back_pressed.connect(_on_drop_link)
	_drop.menu_pressed.connect(_on_error_menu)
	_drop.reconnect_pressed.connect(_on_reconnect)
	_battle.action_chosen.connect(_on_action)
	_result.rematch_pressed.connect(_on_rematch)
	_result.rechoose_pressed.connect(_on_rechoose)
	_result.stop_pressed.connect(_on_stop)
	for session in [host_session, guest_session]:
		session.peer_joined.connect(_on_peer.bind(session))
		session.mode_chosen.connect(_on_mode_chosen)
		session.battle_started.connect(_on_battle_started)
		session.battle_finished.connect(_on_battle_finished)
		session.action_resolved.connect(_on_action_resolved)
		session.disconnected.connect(_on_disconnected)
		session.error_message.connect(_on_error)
		session.stopped.connect(_on_stopped)
		session.resumed.connect(_on_resumed)
		session.guest_dropped.connect(_on_guest_dropped)
	_show_menu()


func _show_only(panel: Control) -> void:
	for item in _panels:
		item.visible = item == panel


func _show_menu() -> void:
	_screen = "menu"
	net_kind = ""
	role_on_device = ""
	_team_seat = ""
	_show_only(_menu)


func _on_menu_host() -> void:
	_host.show_pick()
	_screen = "host_pick"
	_show_only(_host)


func _on_menu_join() -> void:
	_join.show_pick()
	_screen = "join_pick"
	_show_only(_join)


func _on_menu_back() -> void:
	leave_requested.emit()
	# Alleen als dit scherm zelf de scène is (vanaf de titel). In een test
	# hangt de lobby aan een andere node en blijft Terug een signaal.
	if get_parent() == get_tree().root:
		get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


func _on_host_local() -> void:
	net_kind = "local"
	role_on_device = "both"
	if not host_session.begin_host("local"):
		return
	_host.show_waiting(host_session.code, true)
	_screen = "host_wait"
	_show_only(_host)


func _on_host_lan() -> void:
	net_kind = "lan"
	role_on_device = "host"
	if not host_session.begin_host("lan"):
		return
	_host.show_waiting(host_session.code, false)
	_screen = "host_wait"
	_show_only(_host)


func _on_hotseat_code(raw: String) -> void:
	if net_kind != "local":
		return
	guest_session.begin_join("local", raw)


func _on_join_local() -> void:
	net_kind = "local"
	role_on_device = "guest"
	_join.show_code()
	_screen = "join_code"
	_show_only(_join)


func _on_join_lan() -> void:
	net_kind = "lan"
	role_on_device = "guest"
	_join.show_lan_code()
	_screen = "join_code"
	_show_only(_join)


func _on_join_code(raw: String) -> void:
	if not guest_session.begin_join(net_kind, raw):
		return
	if guest_session.phase == "wait_peer":
		_join.show_searching()
		_screen = "join_wait"
		_show_only(_join)


func _on_cancel() -> void:
	host_session.abandon()
	guest_session.abandon()
	_show_menu()


func _on_drop_link() -> void:
	if role_on_device == "guest":
		guest_session.force_disconnect()
	else:
		host_session.force_disconnect()


func _on_peer(session: PvpSession) -> void:
	if session == guest_session and role_on_device == "both":
		return
	if session == guest_session and role_on_device != "guest":
		return
	if session == host_session and role_on_device == "guest":
		return
	var as_host := session == host_session and role_on_device != "guest"
	if role_on_device == "both":
		as_host = true
	_show_mode(as_host)


func _show_mode(as_host: bool) -> void:
	if _screen == "mode" or _screen == "team" or _screen == "battle" or _screen == "result":
		return
	if as_host:
		_mode.show_host()
	else:
		_mode.show_guest()
	_screen = "mode"
	_show_only(_mode)


func _on_mode_picked(id: String) -> void:
	host_session.choose_mode(id)


func _on_mode_chosen(_id: String) -> void:
	if _screen == "team" or _screen == "battle" or _screen == "result":
		return
	_screen = "team"
	if role_on_device == "guest":
		_ask_team("guest")
	else:
		_ask_team("host")


func _ask_team(seat: String) -> void:
	_team_seat = seat
	var who := "Player 1" if seat == "host" else "Player 2"
	var text := who + ", choose your team."
	if net_kind == "local" and seat == "guest":
		text = "Pass the device on. " + text
	_team.set_waiting(false)
	_team.prompt(text)
	_screen = "team"
	_show_only(_team)


func _on_team_picked(id: String) -> void:
	var session := host_session if _team_seat == "host" else guest_session
	if not session.choose_team(id):
		return
	if host_session.phase == "battle" or guest_session.phase == "battle":
		return
	if net_kind == "local" and _team_seat == "host" and guest_session.guest_team == "":
		_ask_team("guest")
		return
	_team.set_waiting(true)
	_team.prompt("Waiting for the other player…")


func _on_battle_started() -> void:
	_screen = "battle"
	_refresh_battle()


func _on_action_resolved(_info: Dictionary) -> void:
	if _screen != "battle":
		return
	if host_session.phase == "result" or guest_session.phase == "result":
		return
	_refresh_battle()


func _refresh_battle() -> void:
	var state := _live_battle()
	if state == null or state.over:
		return
	var actor := state.fighter(state.current_uid())
	var banner := "Waiting…"
	var can := false
	if not actor.is_empty():
		banner = "It's %s's turn" % str(actor["display"])
		can = true
		if net_kind == "local":
			banner = "Pass the device on. " + banner
		elif net_kind == "lan" and str(actor["seat"]) != role_on_device:
			can = false
	_battle.present(state, can, banner)
	_show_only(_battle)


func _live_battle() -> PvpBattleState:
	if role_on_device == "guest":
		return guest_session.battle
	return host_session.battle


func _on_action(action: String, target_uid: String, extra: Dictionary) -> void:
	var state := _live_battle()
	if state == null:
		return
	var uid := state.current_uid()
	var actor := state.fighter(uid)
	if actor.is_empty():
		return
	var session := host_session if str(actor["seat"]) == "host" else guest_session
	session.submit_action(uid, action, target_uid, extra)
	if host_session.phase == "result" or guest_session.phase == "result":
		return
	if _screen == "battle":
		_refresh_battle()


func _on_battle_finished(result: Dictionary) -> void:
	_screen = "result"
	_result.present(result)
	_show_only(_result)


func _authority() -> PvpSession:
	if role_on_device == "guest":
		return guest_session
	return host_session


func _on_rematch() -> void:
	_authority().rematch()


func _on_rechoose() -> void:
	_authority().rechoose()
	if role_on_device == "guest":
		_ask_team("guest")
	else:
		_ask_team("host")


func _on_stop() -> void:
	_authority().stop_match()


func _on_stopped() -> void:
	if _screen == "menu":
		return
	_show_menu()


func _on_disconnected(message: String) -> void:
	if _screen == "menu":
		return
	_drop.set_text(message)
	_screen = "error"
	_show_only(_drop)


func _on_error(text: String) -> void:
	if _screen == "battle":
		_battle.set_log(text)
		return
	if _screen == "menu":
		return
	_drop.set_text(text)
	_screen = "error"
	_show_only(_drop)


func _on_guest_dropped(message: String) -> void:
	if _screen == "battle":
		_battle.set_log(message)


func _on_resumed(phase_name: String) -> void:
	if phase_name == "battle" or phase_name == "result":
		return
	if phase_name == "mode_select":
		_show_mode(role_on_device != "guest")
		return
	if phase_name == "team_select":
		_resume_teams()


func _resume_teams() -> void:
	if role_on_device == "guest":
		if guest_session.guest_team != "":
			_team.set_waiting(true)
			_team.prompt("Waiting for the other player…")
			_screen = "team"
			_show_only(_team)
			return
		_ask_team("guest")
		return
	if host_session.host_team == "":
		_ask_team("host")
		return
	if net_kind == "local" and role_on_device == "both" and host_session.guest_team == "":
		_ask_team("guest")
		return
	_team.set_waiting(true)
	_team.prompt("Waiting for the other player…")
	_screen = "team"
	_show_only(_team)


func _on_reconnect() -> void:
	var session: PvpSession = null
	if guest_session.reconnect_code != "":
		session = guest_session
		net_kind = guest_session.reconnect_kind
		if role_on_device == "":
			role_on_device = "guest"
	elif host_session.reconnect_code != "":
		session = host_session
		net_kind = host_session.reconnect_kind
		if role_on_device == "":
			role_on_device = "host"
	if session == null:
		_drop.set_text(PvpDisconnect.match_gone_message())
		_screen = "error"
		_show_only(_drop)
		return
	if not session.request_reconnect():
		return
	_follow(session)


func _follow(session: PvpSession) -> void:
	match session.phase:
		"mode_select":
			_show_mode(role_on_device != "guest")
		"team_select":
			_resume_teams()
		"battle":
			_screen = "battle"
			_refresh_battle()
		"result":
			_on_battle_finished(session.last_result)
		_:
			_show_menu()


func _on_error_menu() -> void:
	host_session.abandon()
	guest_session.abandon()
	_show_menu()
