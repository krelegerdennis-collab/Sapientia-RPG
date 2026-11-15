extends Node
## Online co-op playtest (klus 8): echte host + echte gast in twee Godot-processen via de relay in relay/.
## Start: godot --path . -- --coopplaytesttest
## Dit proces is de host (online hal als hoofdscène); de gast is een tweede instantie
## (scripts/tests/coop_playtest_guest.gd, vlag --coopplaytestgast) met een eigen user://.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const LobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Floor := preload("res://scripts/online/online_dls_floor.gd")
const HAL_SCENE := "res://scenes/coop/online_hal.tscn"
const RELAY_DIR := "res://relay"
const STEP := 10.0

var failures := 0
var passes := 0
var _relay_pid := 0
var _guest_pid := 0
var _port := 0
var _url := ""
var _dir := ""
var _status_path := ""
var _cmd_path := ""
var _cmds: PackedStringArray = []
var _shots := ""
var _last_guest: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shots="):
			_shots = str(arg).get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func wait_until(pred: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if pred.call():
			return true
		await get_tree().process_frame
	return pred.call()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _run() -> void:
	_dir = ProjectSettings.globalize_path("user://coopplaytest")
	DirAccess.make_dir_recursive_absolute(_dir)
	await _unit_checks()
	if await _start_relay():
		await _playtest()
	else:
		check("relay beschikbaar", false)
	_stop_all()
	await _frames(4)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


# --- losse checks (geen tweede proces) -----------------------------------------

func _unit_checks() -> void:
	# grab_focus-waarschuwing: knoppen zonder focus_mode mogen geen focus pakken bij muisbeweging.
	var btn := UiMenu.button("X")
	btn.focus_mode = Control.FOCUS_NONE
	add_child(btn)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(3, 0)
	btn.gui_input.emit(motion)
	# Regressie: vroeger riep dit grab_focus() aan ("This control can't grab focus" in de host-log).
	check("UiMenu: geen grab_focus op een knop met FOCUS_NONE", not btn.has_focus())
	btn.queue_free()
	# LAN-route: na hand-off overleeft de lobby het vrijgeven van het lobby-scherm.
	var screen := LobbyScreen.new()
	add_child(screen)
	await _frames(2)
	var lob := screen.lobby
	screen._persist_net_nodes()
	screen.queue_free()
	await _frames(2)
	check("lobby-scherm: na hand-off blijft de lobby bij GameState", is_instance_valid(lob) and GameState.coop_lobby() == lob and lob.get_parent() == GameState)
	GameState.coop_clear_lobby_refs()
	if is_instance_valid(lob):
		lob.close()
		lob.queue_free()
	var disc: Node = GameState.get_node_or_null("CoopDiscovery")
	if disc != null:
		disc.queue_free()
	await _frames(2)
	# Verse installatie (APK met title.tscn): geen M1-profiel. Online maakt er een, met geldige v2-HELLO.
	var store := Profile.new()
	var had := store.has_slot(0)
	var packet := LobbyScreen.online_packet({})
	check("verse installatie: online profiel wordt aangemaakt", not had and Profile.new().has_slot(0))
	check("verse installatie: profiel is geldig voor protocol v2", bool(Codec.normalize_profile(packet).get("ok", false)))


# --- host + gast, drie rondes --------------------------------------------------

func _playtest() -> void:
	OS.set_environment(Protocol.RELAY_URL_ENV, _url)
	var store := Profile.new()
	if not store.has_slot(0):
		store.create_slot(0, "Host", "priest")
	get_tree().change_scene_to_file(HAL_SCENE)
	await _frames(4)
	var hal := _hal()
	check("host: online hal is de hoofdscène", hal != null)
	if hal == null:
		return
	var code := await _host_room(hal)
	if code == "":
		return
	# Ronde A: gast via Titel > Co-op > Join online (de APK met title.tscn).
	_spawn_guest(code, "title")
	var joined := await wait_until(func() -> bool:
		return hal.lobby != null and hal.lobby.player_count() == 2 and hal.body_at(1) != null and bool(_guest().get("in_hal", false)) and int(_guest().get("slot", -1)) == 1
	, 30.0)
	print("INFO  gast-staat: %s" % JSON.stringify(_guest()))
	check("titel-join: gast start in de co-op-lobby (titel-route)", str(_guest().get("first_scene", "")) == "res://scenes/ui/coop_lobby.tscn")
	check("titel-join: Join online brengt de gast naar de online hal", str(_guest().get("code_screen_scene", "")) == HAL_SCENE)
	check("titel-join: gast spreekt protocol v2", int(_guest().get("join_version", 0)) == Protocol.VERSION_ONLINE)
	check("titel-join: verbonden met de online host (stoel 1)", joined)
	check("codevak: geen focus meer na Join (toetsenbord dicht)", bool(_guest().get("keyboard_focus_before", false)) and not bool(_guest().get("code_focus_after_submit", true)))
	if not joined:
		return
	await _shot("online_hal_host")
	await _hal_input(hal)
	if not await _start_round(hal, "A"):
		return
	await _run_input("A")
	# Gast verlaat de run: hij is terug in de hal, de host speelt door met een stoel minder.
	_cmd("leave")
	var guest_back := await wait_until(func() -> bool:
		var g := _guest()
		return bool(g.get("in_hal", false)) and bool(g.get("menu", false)) and int(g.get("phase", -1)) == LanLobby.Phase.IDLE
	, STEP)
	check("gast: Terug naar lobby -> online hal, Host/Join-menu, verbinding dicht", guest_back)
	var run := _run_scene()
	var host_alive := await wait_until(func() -> bool:
		return run != null and run.lobby != null and run.lobby.player_count() == 1
	, STEP)
	check("host: speelt door na vertrek van de gast (1 speler)", host_alive and run.is_live())
	# Host verlaat de run via de knop.
	run.leave_button().pressed.emit()
	var host_back := await wait_until(func() -> bool:
		var h := _hal()
		return h != null and _menu_open(h)
	, STEP)
	check("host: Terug naar lobby -> online hal met Host/Join-menu", host_back)
	var fresh := GameState.coop_lobby()
	check("host: geen open sessie of run meer na verlaten", GameState.coop_role == "" and not OnlineDlsRun.active
			and (fresh == null or fresh.phase == LanLobby.Phase.IDLE) and get_tree().root.find_child("ActionCoopSession", true, false) == null)
	# Ronde B: zelfde gast joint opnieuw vanuit de hal; nu stopt de host met de gast nog in de run.
	hal = _hal()
	if hal == null:
		return
	code = await _host_room(hal)
	if code == "":
		return
	_cmd("join %s" % code)
	var rejoined := await wait_until(func() -> bool:
		return hal.lobby != null and hal.lobby.player_count() == 2 and int(_guest().get("slot", -1)) == 1 and bool(_guest().get("folded", false))
	, 20.0)
	check("ronde B: gast joint opnieuw vanuit de hal", rejoined)
	if not rejoined:
		return
	if not await _start_round(hal, "B"):
		return
	run = _run_scene()
	# Trap omhoog: alleen de host wisselt, de gast volgt naar dezelfde verdieping.
	run.room_exit("omhoog", Floor.ONLINE_SCENE)
	var floor2 := await wait_until(func() -> bool:
		return OnlineDlsRun.floor_no == 2 and run.is_live() and int(_guest().get("run_floor", 0)) == 2 and bool(_guest().get("run_ready", false))
	, STEP)
	check("verdieping 2: host en gast samen naar de volgende verdieping", floor2)
	run.leave()
	var both_back := await wait_until(func() -> bool:
		var g := _guest()
		var h := _hal()
		return h != null and _menu_open(h) and bool(g.get("in_hal", false)) and str(g.get("message", "")) != "" and int(g.get("phase", -1)) == LanLobby.Phase.IDLE
	, STEP)
	print("INFO  gast-staat: %s" % JSON.stringify(_guest()))
	check("host stopt de run: host en gast terug in de online hal, gast krijgt een melding", both_back)
	# Ronde C: verlaten in de hal zelf (voor Start), ook geen soft lock.
	hal = _hal()
	if hal == null:
		return
	code = await _host_room(hal)
	if code == "":
		return
	_cmd("join %s" % code)
	var in_c := await wait_until(func() -> bool:
		return hal.lobby != null and hal.lobby.player_count() == 2 and bool(_guest().get("folded", false))
	, 20.0)
	check("ronde C: gast in de hal", in_c)
	if not in_c:
		return
	check("hal: Verlaten-knop zichtbaar", hal.button_named("LeaveButton") != null and hal.button_named("LeaveButton").is_visible_in_tree())
	_cmd("leave")
	var guest_menu := await wait_until(func() -> bool:
		var g := _guest()
		return bool(g.get("menu", false)) and int(g.get("phase", -1)) == LanLobby.Phase.IDLE
	, STEP)
	var host_sees := await wait_until(func() -> bool: return hal.lobby != null and hal.lobby.player_count() == 1, STEP)
	print("INFO  gast-staat: %s" % JSON.stringify(_guest()))
	check("hal: gast Verlaten -> gast in het Host/Join-menu", guest_menu)
	check("hal: host ziet de stoel van de gast vrijkomen", host_sees)
	# Gast weer erin; nu verlaat de host de hal met de gast nog in de kamer.
	_cmd("join %s" % code)
	var again := await wait_until(func() -> bool:
		return hal.lobby != null and hal.lobby.player_count() == 2 and bool(_guest().get("folded", false))
	, 20.0)
	check("ronde C: gast weer in de hal", again)
	(hal.button_named("LeaveButton") as Button).pressed.emit()
	await _frames(2)
	check("hal: host Verlaten -> Host/Join-menu, kamer dicht", _menu_open(hal) and hal.lobby == null)
	var guest_told := await wait_until(func() -> bool:
		var g := _guest()
		return not bool(g.get("folded", true)) and str(g.get("message", "")) != "" and int(g.get("phase", -1)) == LanLobby.Phase.IDLE
	, STEP)
	check("hal: gast krijgt een melding en het scherm terug (geen soft lock)", guest_told)
	_cmd("quit")
	var quit := await wait_until(func() -> bool: return not OS.is_process_running(_guest_pid), STEP)
	check("gast-proces sluit netjes af (geen hang)", quit)
	if quit:
		_guest_pid = 0


func _host_room(hal: OnlineHal) -> String:
	var screen := hal.find_child("CodeScreen", true, false) as CoopLobbyScreen
	var host_btn := _button(screen, "Host online")
	check("host: Host online-knop", host_btn != null)
	if host_btn == null:
		return ""
	host_btn.pressed.emit()
	var hosted := await wait_until(func() -> bool: return hal.lobby != null and hal.lobby.room_code != "", STEP)
	check("host: kamercode", hosted)
	return hal.lobby.room_code if hosted else ""


func _hal_input(hal: OnlineHal) -> void:
	var gx := hal.body_at(1).position.x
	_cmd("stick_right")
	var guest_moves := await wait_until(func() -> bool: return hal.body_at(1) != null and hal.body_at(1).position.x > gx + 8.0, STEP)
	_cmd("stick_stop")
	check("hal: invoer van de gast beweegt zijn poppetje bij de host", guest_moves)
	var hx := hal.local_body().position.x
	Input.action_press("move_left")
	var keys := await wait_until(func() -> bool: return hal.local_body().position.x < hx - 6.0, STEP)
	Input.action_release("move_left")
	check("hal: host (laptop) loopt met het toetsenbord", keys)


func _start_round(hal: OnlineHal, tag: String) -> bool:
	hal.toggle_ready()
	_cmd("ready")
	var ready := await wait_until(func() -> bool: return hal.start_enabled(), STEP)
	check("ronde %s: host en gast Ready, Start aan" % tag, ready)
	if not ready:
		return false
	check("ronde %s: host drukt Start" % tag, hal.press_start())
	var host_live := await wait_until(func() -> bool:
		var r := _run_scene()
		return r != null and r.is_live()
	, STEP)
	check("ronde %s: host laadt de online run" % tag, host_live)
	var guest_live := await wait_until(func() -> bool: return bool(_guest().get("run_ready", false)), STEP)
	check("ronde %s: gast krijgt Start en laadt de online run" % tag, guest_live)
	if not host_live or not guest_live:
		print("INFO  gast-staat: %s" % JSON.stringify(_guest()))
		return false
	var r := _run_scene()
	check("ronde %s: zelfde seed en verdieping (gast volgt de host)" % tag, OnlineDlsRun.active and OnlineDlsRun.floor_no == 1 and int(_guest().get("run_seed", -1)) == OnlineDlsRun.run_seed)
	await _shot("online_run_%s" % tag)
	check("ronde %s: Terug naar lobby-knop zichtbaar" % tag, r.leave_button() != null and r.leave_button().is_visible_in_tree() and r.leave_button().text.strip_edges() == "Back to lobby")
	return true


func _run_input(tag: String) -> void:
	var run := _run_scene()
	if run == null or run.som == null:
		check("ronde %s: arena aanwezig" % tag, false)
		return
	var som: Node = run.som
	var body: Node2D = som._coop_body(1)
	check("ronde %s: stoel van de gast staat in de arena" % tag, body != null)
	if body == null:
		return
	var start := body.position
	_cmd("stick_right")
	var moved := await wait_until(func() -> bool: return body.position.distance_to(start) > 6.0, STEP)
	_cmd("stick_stop")
	check("ronde %s: invoer van de gast beweegt zijn held in het spel (bij de host)" % tag, moved)
	var host_body: Node2D = som._coop_body(0)
	var hs := host_body.position if host_body != null else Vector2.ZERO
	var gx := float(_guest().get("run_host_x", -1.0))
	run.set_stick(Vector2.LEFT)
	var host_moved := await wait_until(func() -> bool: return host_body != null and host_body.position.distance_to(hs) > 6.0, STEP)
	var guest_sees := await wait_until(func() -> bool: return absf(float(_guest().get("run_host_x", -1.0)) - gx) > 4.0, STEP)
	run.set_stick(Vector2.ZERO)
	check("ronde %s: host loopt in het spel" % tag, host_moved)
	check("ronde %s: gast ziet de host bewegen (snapshots)" % tag, guest_sees)


func _shot(name: String) -> void:
	if _shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute(_shots)
		img.save_png(_shots.path_join(name + ".png"))


func _hal() -> OnlineHal:
	return get_tree().current_scene as OnlineHal


func _run_scene() -> OnlineRunScene:
	return get_tree().current_scene as OnlineRunScene


func _menu_open(hal: OnlineHal) -> bool:
	var screen := hal.find_child("CodeScreen", true, false) as CoopLobbyScreen
	return screen != null and screen.visible and not screen.folded and screen._screen == CoopLobbyScreen.Screen.MENU


# --- gast-proces -------------------------------------------------------------

func _spawn_guest(code: String, via: String) -> void:
	_status_path = _dir.path_join("guest_status_%s.json" % via)
	_cmd_path = _dir.path_join("guest_cmd_%s.txt" % via)
	for p in [_status_path, _cmd_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_cmds.clear()
	_last_guest = {}
	var xdg_before := OS.get_environment("XDG_DATA_HOME")
	var guest_home := _dir.path_join("guest_xdg_%s" % via)
	DirAccess.make_dir_recursive_absolute(guest_home)
	OS.set_environment("XDG_DATA_HOME", guest_home)
	var args := PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--",
		"--coopplaytestgast", "--relay=%s" % _url, "--code=%s" % code,
		"--status=%s" % _status_path, "--cmd=%s" % _cmd_path, "--via=%s" % via,
	])
	_guest_pid = OS.create_process(OS.get_executable_path(), args)
	if xdg_before == "":
		OS.unset_environment("XDG_DATA_HOME")
	else:
		OS.set_environment("XDG_DATA_HOME", xdg_before)
	check("gast-proces gestart (%s)" % via, _guest_pid > 0)


func _guest() -> Dictionary:
	if _status_path == "" or not FileAccess.file_exists(_status_path):
		return _last_guest
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_status_path))
	if parsed is Dictionary:
		_last_guest = parsed
	return _last_guest


func _cmd(c: String) -> void:
	_cmds.append(c)
	var f := FileAccess.open(_cmd_path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_cmds) + "\n")
		f.close()


func _stop_guest() -> void:
	if _guest_pid > 0:
		OS.kill(_guest_pid)
		_guest_pid = 0


# --- relay -------------------------------------------------------------------

func _start_relay() -> bool:
	var dir := ProjectSettings.globalize_path(RELAY_DIR)
	var out: Array = []
	if OS.execute("node", ["--version"], out) != 0:
		check("node gevonden", false)
		return false
	if not DirAccess.dir_exists_absolute(dir.path_join("node_modules/ws")):
		var npm_out: Array = []
		var code := OS.execute("npm", ["ci", "--prefix", dir, "--no-audit", "--no-fund", "--silent"], npm_out, true)
		check("npm ci in relay/", code == 0)
		if code != 0:
			return false
	_port = _free_port()
	if _port == 0:
		check("vrije poort", false)
		return false
	OS.set_environment("RELAY_QUIET", "1")
	_relay_pid = OS.create_process("node", [dir.path_join("server.js"), "--port=%d" % _port])
	_url = "ws://127.0.0.1:%d" % _port
	var up := await wait_until(_relay_accepts, 10.0)
	check("relay luistert", up)
	return up


func _free_port() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8088
	for _i in 40:
		var port := rng.randi_range(50000, 58000)
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return 0


func _relay_accepts() -> bool:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", _port) != OK:
		return false
	var left := 50
	while left > 0 and peer.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		peer.poll()
		left -= 1
		OS.delay_msec(10)
	var ok := peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
	peer.disconnect_from_host()
	return ok


func _stop_all() -> void:
	_stop_guest()
	if _relay_pid > 0:
		OS.kill(_relay_pid)
		_relay_pid = 0
	OS.unset_environment(Protocol.RELAY_URL_ENV)


func _button(screen: CoopLobbyScreen, label: String) -> Button:
	if screen == null:
		return null
	for b in screen.all_touch_buttons():
		if str(b.get_meta("label", "")) == label:
			return b
	return null
