class_name OnlineRunScene
extends Node
## Online DLS-run na Start in de online hal (klus 8). Host en gast laden deze scène:
## lobby-peer (via GameState) + ActionCoopSession + OnlineDlsRoom met SomArena in co-op.
## Verdieping wisselen doet alleen de host; hij stuurt START_GAME {seed, mode, floor, spawn}
## en elke gast laadt dezelfde verdieping. "Terug naar lobby" sluit de verbinding netjes.

const Session := preload("res://scripts/net/action_coop_session.gd")
const Run := preload("res://scripts/online/online_dls_run.gd")
const Floor := preload("res://scripts/online/online_dls_floor.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const LobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const THEME := preload("res://assets/theme.tres")

const HALL_SCENE := "res://scenes/coop/online_hal.tscn"
const END_HOST_LEFT := "host_left"
const END_RUN_DONE := "run_done"
const LEAVE_TEXT := "Back to lobby"
const MSG_HOST_LEFT := "The host stopped the run."
const MSG_LINK_LOST := "Connection to the host lost."
const MSG_RUN_DONE := "Run finished. Back in the lobby."
const MSG_NO_LOBBY := "No connection to the room."
const LEAVE_W := 92.0
const LEAVE_H := 20.0
## Zo lang wachten we op de SomArena van een nieuwe kamer (frames).
const SOM_WAIT_FRAMES := 180

var session: ActionCoopSession
var lobby: LanLobby
## SomArena van de huidige kamer (touch_controls leest current_scene.som voor lock-tikken).
var som: Node
var room: Node
var leaving := false
## Testhaak: vaste stick voor de lokale stoel (anders joystick/toetsenbord van de arena).
var forced_stick := Vector2.ZERO

var _hud: CanvasLayer
var _leave_btn: Button
var _loading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("online_run")
	add_to_group("touch_priority")
	_build_hud()
	_boot.call_deferred()


func _exit_tree() -> void:
	if session != null and is_instance_valid(session):
		session.shutdown(true)
	session = null


func _process(_delta: float) -> void:
	if som != null and is_instance_valid(som) and "forced_joy" in som:
		som.forced_joy = forced_stick
	if leaving or _loading or lobby == null or not lobby.is_host:
		return
	if Run.exit_reached or Run.returned_to_hall:
		Run.exit_reached = false
		Run.returned_to_hall = false
		_end_run(END_RUN_DONE, MSG_RUN_DONE)


## Spel draait: sessie open en een arena in co-op.
func is_live() -> bool:
	return not leaving and session != null and is_instance_valid(session) and som != null and is_instance_valid(som)


func set_stick(stick: Vector2) -> void:
	forced_stick = stick


## GameState: wij sturen zelf terug naar de hal bij sessie-einde of verbindingsverlies.
func handles_coop_end() -> bool:
	return true


func claims_touch(viewport_pos: Vector2) -> bool:
	return _leave_btn != null and _leave_btn.is_visible_in_tree() and _leave_btn.get_global_rect().has_point(viewport_pos)


func leave_button() -> Button:
	return _leave_btn


## "Terug naar lobby": host stopt de run voor iedereen, een gast vertrekt alleen zelf.
func leave() -> void:
	if leaving:
		return
	if lobby != null and lobby.is_host:
		_end_run(END_HOST_LEFT, "")
		return
	_back_to_hall("", true)


## Host: de kamer vraagt een andere verdieping (zie OnlineDlsRoom._use_exit).
func room_exit(spawn: String, target_map: String) -> void:
	if lobby == null or not lobby.is_host or leaving or _loading:
		return
	if spawn == "uitgang" or spawn == "hal":
		_end_run(END_RUN_DONE, MSG_RUN_DONE)
		return
	if target_map != Floor.ONLINE_SCENE:
		return
	var next := Run.floor_no
	if spawn == "omhoog":
		next = mini(Run.floor_no + 1, Run.floors_total())
	elif spawn == "omlaag":
		next = maxi(Run.floor_no - 1, 1)
	if next == Run.floor_no:
		return
	var body := {"seed": Run.run_seed, "mode": Run.mode, "floor": next, "spawn": spawn}
	lobby.host_start_game(body)
	_goto_floor(next, spawn)


# --- intern -----------------------------------------------------------------

func _boot() -> void:
	lobby = GameState.coop_lobby()
	if lobby == null or lobby.enet_peer() == null or lobby.phase != LanLobby.Phase.IN or not Run.active:
		_back_to_hall(MSG_NO_LOBBY, false)
		return
	lobby.session_ended.connect(_on_session_ended)
	lobby.link_lost.connect(_on_link_lost)
	lobby.roster_changed.connect(_on_roster_changed)
	lobby.member_left.connect(_on_member_left)
	lobby.start_game_received.connect(_on_start_game)
	session = Session.start_session(get_tree(), lobby.enet_peer(), _roster(), lobby.local_slot, false, lobby)
	session.arena_drive = true
	session.own_peer = false
	GameState.coop_bind_session(session)
	session.link_lost.connect(_on_link_lost)
	await _load_room(Run.floor_no, "")


func _roster() -> Array:
	var out: Array = []
	for row in lobby.slots:
		out.append((row as Dictionary).duplicate())
	return out


func _load_room(floor_no: int, spawn: String) -> void:
	_loading = true
	if session != null:
		session.attach_arena(null)
	som = null
	if room != null and is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	room = null
	Run.floor_no = clampi(floor_no, 1, Run.floors_total())
	Run.exit_reached = false
	Run.returned_to_hall = false
	GameState.pending_spawn = spawn
	var packed := load(Run.SCENE) as PackedScene
	if packed == null:
		_loading = false
		return
	room = packed.instantiate()
	add_child(room)
	for _i in SOM_WAIT_FRAMES:
		if leaving or room == null or not is_instance_valid(room):
			_loading = false
			return
		if "som" in room and room.som != null:
			break
		await get_tree().process_frame
	_loading = false
	if leaving or room == null or not is_instance_valid(room) or room.som == null or session == null:
		return
	som = room.som
	som.setup_coop(session, _roster(), lobby.local_slot)
	session.attach_arena(som)


func _goto_floor(floor_no: int, spawn: String) -> void:
	await _load_room(floor_no, spawn)


func _on_start_game() -> void:
	if lobby == null or lobby.is_host or leaving:
		return
	var body := lobby.start_body
	var floor_no := int(body.get("floor", Run.floor_no))
	if int(body.get("seed", Run.run_seed)) != Run.run_seed or floor_no == Run.floor_no:
		return
	_goto_floor(floor_no, str(body.get("spawn", "")))


func _on_roster_changed() -> void:
	if session != null and lobby != null:
		session.sync_roster(lobby.slots)


func _on_member_left(peer_id: int) -> void:
	if session != null:
		session.simulate_peer_drop(peer_id)


func _on_session_ended(reason: String) -> void:
	var msg := MSG_HOST_LEFT
	if reason == END_RUN_DONE:
		msg = MSG_RUN_DONE
	elif reason != END_HOST_LEFT:
		msg = GameState.coop_session_end_message(reason)
	_back_to_hall(msg, false)


func _on_link_lost() -> void:
	_back_to_hall(MSG_LINK_LOST, false)


## Host: iedereen terug (SESSION_END), dan zelf terug.
func _end_run(reason: String, message: String) -> void:
	if lobby != null and lobby.is_host and lobby.phase == LanLobby.Phase.IN:
		lobby.broadcast_session_end(reason)
	_back_to_hall(message, false)


## Alles netjes dicht en naar de online hal (die opent met Host/Join of de melding).
func _back_to_hall(message: String, send_leave: bool) -> void:
	if leaving:
		return
	leaving = true
	if _hud != null:
		_hud.visible = false
	if session != null and is_instance_valid(session):
		session.shutdown(true)
	session = null
	GameState.coop_shutdown_session()
	som = null
	var lob := lobby
	lobby = null
	if lob != null and is_instance_valid(lob):
		for pair in [[lob.session_ended, _on_session_ended], [lob.link_lost, _on_link_lost],
				[lob.roster_changed, _on_roster_changed], [lob.member_left, _on_member_left],
				[lob.start_game_received, _on_start_game]]:
			var sig: Signal = pair[0]
			if sig.is_connected(pair[1]):
				sig.disconnect(pair[1])
		if send_leave and not lob.is_host:
			lob.leave_session()
		else:
			lob.close()
		lob.queue_free()
	GameState.coop_role = ""
	GameState.coop_clear_lobby_refs()
	Run.stop()
	LobbyScreen.hall_message = message
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file.call_deferred(HALL_SCENE)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "RunHud"
	_hud.layer = 40
	add_child(_hud)
	var root := Control.new()
	root.name = "RunHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = THEME
	_hud.add_child(root)
	_leave_btn = UiMenu.button(LEAVE_TEXT)
	_leave_btn.name = "LeaveButton"
	_leave_btn.focus_mode = Control.FOCUS_NONE
	_leave_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_leave_btn.add_theme_font_size_override("font_size", 10)
	var normal: StyleBoxFlat = UiStyleC.panel("button")
	_leave_btn.add_theme_stylebox_override("normal", normal)
	_leave_btn.add_theme_stylebox_override("hover", normal)
	_leave_btn.add_theme_stylebox_override("pressed", UiStyleC.panel("button", UiStyleC.BORDER))
	# Onder in het midden: links zit het HP-paneel en de joystick, rechts A/B, boven RUN/SWAP/RING/MENU.
	_leave_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_leave_btn.custom_minimum_size = Vector2(LEAVE_W, LEAVE_H)
	_leave_btn.offset_left = -LEAVE_W * 0.5
	_leave_btn.offset_right = LEAVE_W * 0.5
	_leave_btn.offset_top = -LEAVE_H - 2.0
	_leave_btn.offset_bottom = -2.0
	_leave_btn.pressed.connect(leave)
	root.add_child(_leave_btn)
