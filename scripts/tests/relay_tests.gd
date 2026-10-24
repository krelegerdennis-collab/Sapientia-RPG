extends Node
## Online co-op via de relay, headless: start de Node-relay (relay/) lokaal en laat 4 gesimuleerde
## spelers (1 host + 3 gasten) met een kamercode joinen en in Action-modus syncen, inclusief
## een gast die wegvalt en terugkomt. Dezelfde LanLobby + ActionCoopSession als op LAN; alleen
## de peer is een RelayPeer (WebSocket).
## Start: godot --path . -- --relaytest   (vereist Node >= 20; npm ci in relay/ gebeurt zo nodig vanzelf)
## Of via de runner: GODOT=... .github/scripts/run_suite.sh relaytest

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Lobby := preload("res://scripts/net/lan_lobby.gd")
const Session := preload("res://scripts/net/action_coop_session.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const CoopLobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")

const STEP := 5.0
const RELAY_DIR := "res://relay"

var failures := 0
var passes := 0
var _relay_pid := 0
var _port := 0
var _url := ""
var _nodes: Array[Node] = []
var _wires: Dictionary = {}
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func wait_until(pred: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if pred.call():
			return true
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		left -= float(Time.get_ticks_msec() - before) / 1000.0
	return pred.call()


func _shot(name: String) -> void:
	if shots == "":
		return
	await _frames(3)
	DirAccess.make_dir_recursive_absolute(shots)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	OS.unset_environment(Protocol.RELAY_URL_ENV)
	_helper_tests()
	_default_is_lan_only_tests()
	if await _start_relay():
		await _unreachable_tests()
		await _ui_tests()
		await _four_player_tests()
		await _host_leaves_tests()
	_stop_relay()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


# --- relay starten en stoppen ---------------------------------------------------------

func _start_relay() -> bool:
	var dir := ProjectSettings.globalize_path(RELAY_DIR)
	var out: Array = []
	var node_ok := OS.execute("node", ["--version"], out) == 0
	check("node gevonden (%s)" % (str(out[0]).strip_edges() if node_ok and out.size() > 0 else "ontbreekt"), node_ok)
	if not node_ok:
		return false
	if not DirAccess.dir_exists_absolute(dir.path_join("node_modules/ws")):
		var npm_out: Array = []
		var code := OS.execute("npm", ["ci", "--prefix", dir, "--no-audit", "--no-fund", "--silent"], npm_out, true)
		check("npm ci in relay/", code == 0)
		if code != 0:
			print("INFO  ", str(npm_out))
			return false
	_port = _free_port()
	check("vrije poort gevonden", _port > 0)
	if _port == 0:
		return false
	OS.set_environment("RELAY_QUIET", "1")
	_relay_pid = OS.create_process("node", [dir.path_join("server.js"), "--port=%d" % _port])
	check("relay-proces gestart", _relay_pid > 0)
	if _relay_pid <= 0:
		return false
	_url = "ws://127.0.0.1:%d" % _port
	var up := await wait_until(_relay_accepts_tcp, 10.0)
	check("relay luistert op poort %d" % _port, up)
	return up


func _free_port() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 40:
		var port := rng.randi_range(41000, 49000)
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return 0


func _relay_accepts_tcp() -> bool:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host("127.0.0.1", _port) != OK:
		return false
	for i in 50:
		tcp.poll()
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTING:
			break
		OS.delay_msec(10)
	var ok := tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED
	tcp.disconnect_from_host()
	return ok


func _stop_relay() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			if n is LanLobby:
				(n as LanLobby).close()
			n.queue_free()
	_nodes.clear()
	if _relay_pid > 0:
		OS.kill(_relay_pid)
		_relay_pid = 0


# --- pure helpers en standaardgedrag -----------------------------------------------------

func _helper_tests() -> void:
	check("filter_room_code: hoofdletters en geldige tekens", Protocol.filter_room_code("ab c-d2e3f4g") == "ABCD2E")
	check("filter_room_code: dubbelzinnige tekens vallen weg", Protocol.filter_room_code("0O1IL2") == "2")
	check("is_room_code: 6 geldige tekens", Protocol.is_room_code("ABC234") and not Protocol.is_room_code("ABC23"))
	check("is_room_code: kleine letters zijn geen code", not Protocol.is_room_code("abc234"))
	check("relay-URL: ws:// en wss:// geldig", Protocol.is_valid_relay_url("wss://x.fly.dev") and Protocol.is_valid_relay_url("ws://127.0.0.1:1"))
	check("relay-URL: leeg of http is ongeldig", not Protocol.is_valid_relay_url("") and not Protocol.is_valid_relay_url("https://x.fly.dev"))
	check("alfabet zonder 0 O 1 I L", not Protocol.ROOM_CODE_ALPHABET.contains("0") and not Protocol.ROOM_CODE_ALPHABET.contains("O")
			and not Protocol.ROOM_CODE_ALPHABET.contains("1") and not Protocol.ROOM_CODE_ALPHABET.contains("I")
			and not Protocol.ROOM_CODE_ALPHABET.contains("L") and Protocol.ROOM_CODE_ALPHABET.length() == 31)
	for reason in ["unreachable", "timeout", "no_room", "room_full", "host_left", "rate_limited"]:
		check("relay-melding Engels voor '%s'" % reason, Protocol.relay_error_text(reason).length() > 8)
	check("REFUSE_TEXT heeft ROOM_NOT_FOUND", str(Protocol.REFUSE_TEXT.get(Protocol.Refuse.ROOM_NOT_FOUND, "")) != "")
	var peer: RelayPeer = RelayPeer.new()
	check("RelayPeer: geen ws-URL wordt geweigerd", peer.create_host("http://x") == ERR_INVALID_PARAMETER)
	check("RelayPeer: start DISCONNECTED", peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED)
	var lobby: LanLobby = Lobby.new()
	check("join_relay: ongeldige code geweigerd", lobby.join_relay("ws://127.0.0.1:1", "ABC", "", "Gast") == ERR_INVALID_PARAMETER)
	check("join_relay: lobby blijft idle", lobby.phase == LanLobby.Phase.IDLE and lobby.enet_peer() == null)
	lobby.free()


func _default_is_lan_only_tests() -> void:
	check("standaard relay_url is leeg (alleen LAN)", Protocol.relay_url() == "")
	check("project.godot: relay_url standaard leeg", str(ProjectSettings.get_setting(Protocol.RELAY_URL_SETTING, "x")) == "")


# --- UI -------------------------------------------------------------------------------------

func _button_labels(ui: CoopLobbyScreen) -> Array[String]:
	var out: Array[String] = []
	for b in ui.all_touch_buttons():
		out.append(str(b.get_meta("label", b.text)))
	return out


func _find_button(ui: CoopLobbyScreen, label: String) -> Button:
	for b in ui.all_touch_buttons():
		if str(b.get_meta("label", b.text)) == label:
			return b
	return null


func _ui_tests() -> void:
	var lan_ui: CoopLobbyScreen = CoopLobbyScreen.new()
	add_child(lan_ui)
	await _frames(2)
	var lan_labels := _button_labels(lan_ui)
	check("UI zonder relay-URL: alleen LAN-knoppen", lan_labels.has("Host") and lan_labels.has("Join")
			and not lan_labels.has("Host online") and not lan_labels.has("Join online"))
	lan_ui.queue_free()
	await _frames(2)

	OS.set_environment(Protocol.RELAY_URL_ENV, _url)
	check("relay_url leest de omgevingsvariabele", Protocol.relay_url() == _url)
	var host_ui: CoopLobbyScreen = CoopLobbyScreen.new()
	host_ui.name = "UiHost"
	add_child(host_ui)
	await _frames(2)
	var labels := _button_labels(host_ui)
	await _shot("relay_menu_online")
	check("UI met relay-URL: Host online en Join online", labels.has("Host online") and labels.has("Join online")
			and labels.has("Host") and labels.has("Join"))
	var online_btn := _find_button(host_ui, "Host online")
	if online_btn != null:
		online_btn.pressed.emit()
	var got_code := await wait_until(func() -> bool: return host_ui.lobby.room_code != "", STEP)
	check("UI host online toont een kamercode", got_code and Protocol.is_room_code(host_ui.lobby.room_code))
	await _frames(2)
	var shows_code := false
	for c in host_ui._box.get_children():
		if c is Label and (c as Label).text == "Room code: %s" % host_ui.lobby.room_code:
			shows_code = true
	check("UI-label 'Room code: XXXXXX'", shows_code)
	await _shot("relay_host_room_code")
	check("UI host: LAN-baken niet gestart (geen UDP voor relay)", host_ui.lobby.transport == LanLobby.Transport.RELAY)

	var guest_ui: CoopLobbyScreen = CoopLobbyScreen.new()
	guest_ui.name = "UiGuest"
	add_child(guest_ui)
	await _frames(2)
	var join_btn := _find_button(guest_ui, "Join online")
	if join_btn != null:
		join_btn.pressed.emit()
	await _frames(2)
	check("UI: invoervak voor de code", guest_ui._code_edit != null and guest_ui._screen == CoopLobbyScreen.Screen.JOIN_CODE)
	var go := _find_button(guest_ui, "Join")
	check("UI: Join uit zonder volledige code", go != null and go.disabled)
	guest_ui._code_edit.text = "ab"
	guest_ui._code_edit.text_changed.emit("ab")
	check("UI: invoer wordt hoofdletters", guest_ui._code_edit.text == "AB")
	var typed := host_ui.lobby.room_code.to_lower() + "x"
	guest_ui._code_edit.text = typed
	guest_ui._code_edit.text_changed.emit(typed)
	check("UI: code afgekapt op 6 tekens en Join aan", guest_ui._code_edit.text == host_ui.lobby.room_code
			and go != null and not go.disabled)
	await _shot("relay_join_code_entry")
	guest_ui._submit_code()
	var joined := await wait_until(func() -> bool: return guest_ui.lobby.local_slot == 1 and host_ui.lobby.player_count() == 2, STEP)
	check("UI: gast joint met de code (stoel 1)", joined)
	await _frames(2)
	var guest_sees_roster := false
	for c in guest_ui._box.get_children():
		if c is Label and (c as Label).text.begins_with("Joined "):
			guest_sees_roster = true
	check("UI gast: 'Joined <held>' scherm", guest_sees_roster)
	await _shot("relay_guest_joined")

	var bad_ui: CoopLobbyScreen = CoopLobbyScreen.new()
	add_child(bad_ui)
	await _frames(2)
	bad_ui._show_join_code()
	bad_ui._join_online("ZZZZZZ")
	var refused := await wait_until(func() -> bool: return bad_ui._screen == CoopLobbyScreen.Screen.MESSAGE, STEP)
	check("UI: onbekende code geeft melding", refused and bad_ui._message == "Room not found. Check the code.")

	for ui in [host_ui, guest_ui, bad_ui]:
		ui.queue_free()
	await _frames(3)
	OS.unset_environment(Protocol.RELAY_URL_ENV)
	check("relay_url weer leeg na de test", Protocol.relay_url() == "")


# --- onbereikbare relay ------------------------------------------------------------------------

func _unreachable_tests() -> void:
	var dead_port := _free_port()
	var guest: LanLobby = _lobby("Unreachable")
	check("join_relay naar dode poort start", guest.join_relay("ws://127.0.0.1:%d" % dead_port, "ABC234", "", "Gast") == OK)
	var refused := await wait_until(func() -> bool: return guest.phase == LanLobby.Phase.REFUSED, STEP)
	check("onbereikbare relay: join geweigerd (niet hangen)", refused and guest.refuse_reason == Protocol.Refuse.TIMEOUT)
	check("onbereikbare relay: reden 'unreachable'", guest.relay_reason == "unreachable")
	var host: LanLobby = _lobby("UnreachableHost")
	var lost := [false]
	host.link_lost.connect(func() -> void: lost[0] = true)
	check("host_relay naar dode poort start", host.host_relay("ws://127.0.0.1:%d" % dead_port, "Dax") == OK)
	await wait_until(func() -> bool: return lost[0], STEP)
	check("onbereikbare relay: host krijgt link_lost met reden", lost[0] and host.relay_reason == "unreachable"
			and host.phase == LanLobby.Phase.LOST)
	guest.close()
	host.close()


# --- 4 spelers ------------------------------------------------------------------------------------

func _lobby(n: String) -> LanLobby:
	var l: LanLobby = Lobby.new()
	l.name = n
	add_child(l)
	_nodes.append(l)
	return l


func _roster_of(lobby: LanLobby) -> Array:
	var roster: Array = []
	for row in lobby.slots:
		roster.append((row as Dictionary).duplicate())
	return roster


## Zelfde bedrading als scripts/coop/action_sandbox_scene.gd: roster -> sync_roster, member_left -> drop.
func _start_session(lobby: LanLobby) -> ActionCoopSession:
	var sess: ActionCoopSession = Session.start_session(get_tree(), lobby.enet_peer(), _roster_of(lobby), lobby.local_slot, false, lobby)
	var on_roster := func() -> void: sess.sync_roster(lobby.slots)
	var on_left := func(peer_id: int) -> void: sess.simulate_peer_drop(peer_id)
	lobby.roster_changed.connect(on_roster)
	if lobby.is_host:
		lobby.member_left.connect(on_left)
	_wires[sess] = {"lobby": lobby, "roster": on_roster, "left": on_left}
	return sess


func _stop_session(sess: ActionCoopSession) -> void:
	var wire: Dictionary = _wires.get(sess, {})
	if not wire.is_empty():
		var lobby: LanLobby = wire["lobby"]
		if lobby.roster_changed.is_connected(wire["roster"]):
			lobby.roster_changed.disconnect(wire["roster"])
		if lobby.member_left.is_connected(wire["left"]):
			lobby.member_left.disconnect(wire["left"])
		_wires.erase(sess)
	sess.shutdown(true)


func _pos(sess: ActionCoopSession, slot: int) -> Vector2i:
	var p: Dictionary = sess.sim.players[slot]
	return Vector2i(int(p["x"]), int(p["y"]))


func _active(sess: ActionCoopSession, slot: int) -> bool:
	return bool(sess.sim.players[slot]["active"])


func _stop_all_input(sessions: Array) -> void:
	for s in sessions:
		if is_instance_valid(s):
			(s as ActionCoopSession).set_local_input(Vector2.ZERO, false, false, false)


func _views_match(host_sess: ActionCoopSession, guest_sess: ActionCoopSession, slots: Array) -> bool:
	for slot in slots:
		if _pos(host_sess, int(slot)) != _pos(guest_sess, int(slot)) or _active(host_sess, int(slot)) != _active(guest_sess, int(slot)):
			return false
	return true


func _all_match(host_sess: ActionCoopSession, guests: Array) -> bool:
	for g in guests:
		if not _views_match(host_sess, g as ActionCoopSession, [0, 1, 2, 3]):
			return false
	return true


func _four_player_tests() -> void:
	var host: LanLobby = _lobby("RelayHost")
	var g1: LanLobby = _lobby("RelayG1")
	var g2: LanLobby = _lobby("RelayG2")
	var g3: LanLobby = _lobby("RelayG3")

	# 1. Kamer openen
	check("host_relay start", host.host_relay(_url, "Dax") == OK)
	check("host: transport RELAY", host.transport == LanLobby.Transport.RELAY and host.is_host)
	var ready := await wait_until(func() -> bool: return host.room_code != "", STEP)
	var code := host.room_code
	check("host krijgt kamercode van 6 tekens zonder 0/O/1/I/L", ready and Protocol.is_room_code(code))
	check("host zit op stoel 0 als Dax", host.local_slot == Protocol.HOST_SLOT and host.local_character == Protocol.HOST_CHARACTER)

	# 2. Drie gasten met de code (kleine letters en spaties worden genegeerd)
	check("g1 join_relay", g1.join_relay(_url, " " + code.to_lower(), "lotte", "Seren") == OK)
	await wait_until(func() -> bool: return g1.local_slot == 1 and host.player_count() == 2, STEP)
	check("g1 stoel 1 als Seren", g1.local_slot == 1 and g1.local_character == "lotte")
	check("g2 join_relay", g2.join_relay(_url, code, "noor", "Vesper") == OK)
	check("g3 join_relay", g3.join_relay(_url, code, "kael", "Kael") == OK)
	var full := await wait_until(func() -> bool:
		return host.player_count() == 4 and g2.local_slot == 2 and g3.local_slot == 3 and g1.player_count() == 4, STEP)
	check("vier spelers in de kamer", full)
	check("gasten kregen noor en kael", g2.local_character == "noor" and g3.local_character == "kael")
	check("gasten zien de volle roster", g2.player_count() == 4 and g3.player_count() == 4)
	var ids := {}
	for row in host.slots:
		ids[int((row as Dictionary)["peer_id"])] = true
	check("vier unieke peer-ids op de host", ids.size() == 4)

	# 3. Vijfde gast, verkeerde versie
	var fifth: LanLobby = _lobby("RelayFifth")
	check("5e join_relay start", fifth.join_relay(_url, code, "", "Extra") == OK)
	var fifth_refused := await wait_until(func() -> bool: return fifth.phase == LanLobby.Phase.REFUSED, STEP)
	check("5e speler geweigerd: party full", fifth_refused and fifth.refuse_reason == Protocol.Refuse.FULL
			and str(Protocol.REFUSE_TEXT[fifth.refuse_reason]) == "The party is full.")
	check("kamer blijft op 4 spelers", host.player_count() == 4)
	fifth.close()
	var other: LanLobby = _lobby("RelayOtherRoom")
	var other_guest: LanLobby = _lobby("RelayWrongVersion")
	check("tweede kamer", other.host_relay(_url, "Anna") == OK)
	await wait_until(func() -> bool: return other.room_code != "", STEP)
	check("kamercodes verschillen", other.room_code != code)
	check("gast met verkeerde versie", other_guest.join_relay(_url, other.room_code, "", "Oud", 99) == OK)
	var wrong := await wait_until(func() -> bool: return other_guest.phase == LanLobby.Phase.REFUSED, STEP)
	check("verkeerde versie geweigerd over relay", wrong and other_guest.refuse_reason == Protocol.Refuse.VERSION)
	check("tweede kamer bleef bij 1 speler", other.player_count() == 1)
	other_guest.close()
	other.close()

	# 4. Start + Action-sync
	var started := [0]
	for g in [g1, g2, g3]:
		(g as LanLobby).start_game_received.connect(func() -> void: started[0] += 1)
	host.host_start_game()
	await wait_until(func() -> bool: return started[0] == 3, STEP)
	check("START_GAME bij alle drie de gasten", started[0] == 3)
	var host_s := _start_session(host)
	var s1 := _start_session(g1)
	var s2 := _start_session(g2)
	var s3 := _start_session(g3)
	var snaps := [0, 0, 0]
	s1.snapshot_applied.connect(func(_t: int) -> void: snaps[0] += 1)
	s2.snapshot_applied.connect(func(_t: int) -> void: snaps[1] += 1)
	s3.snapshot_applied.connect(func(_t: int) -> void: snaps[2] += 1)
	var start1 := _pos(host_s, 1)
	var start2 := _pos(host_s, 2)
	var start3 := _pos(host_s, 3)
	host_s.set_local_input(Vector2(-1, 0), false, false, false)
	s1.set_local_input(Vector2(0, 1), false, false, false)
	s2.set_local_input(Vector2(0, -1), false, false, false)
	s3.set_local_input(Vector2(0, 1), false, false, false)
	var moved := await wait_until(func() -> bool:
		return _pos(host_s, 1).y > start1.y + 4 and _pos(host_s, 2).y < start2.y - 4 and _pos(host_s, 3).y > start3.y + 4, STEP)
	check("input van drie gasten beweegt hun stoel op de host", moved)
	var seen := await wait_until(func() -> bool:
		return _pos(s1, 2).y < start2.y - 4 and _pos(s2, 3).y > start3.y + 4 and _pos(s3, 1).y > start1.y + 4, STEP)
	check("snapshots: elke gast ziet de andere gasten bewegen", seen)
	var got_snaps := await wait_until(func() -> bool: return snaps[0] > 5 and snaps[1] > 5 and snaps[2] > 5, STEP)
	check("alle gasten ontvingen snapshots", got_snaps)
	_stop_all_input([host_s, s1, s2, s3])
	var settled := await wait_until(func() -> bool: return _all_match(host_s, [s1, s2, s3]), STEP)
	check("na stilstand: host en 3 gasten tonen dezelfde posities", settled)

	var enemy_hp0 := int((host_s.sim.enemies[0] as Dictionary)["hp"])
	for s in [s1, s2, s3]:
		(s as ActionCoopSession).set_local_input(Vector2.ZERO, true, false, true, 0)
	var hit := await wait_until(func() -> bool:
		return host_s.sim.enemies.is_empty() or int((host_s.sim.enemies[0] as Dictionary)["hp"]) < enemy_hp0, 12.0)
	check("gast-aanval raakt de vijand op de host (host-autoritair)", hit)
	var saw_damage := await wait_until(func() -> bool:
		return not s2.sim.enemies.is_empty() and int((s2.sim.enemies[0] as Dictionary)["hp"]) < enemy_hp0, STEP)
	check("gasten zien de vijand-HP dalen via snapshot", saw_damage)
	_stop_all_input([host_s, s1, s2, s3])

	# 5. Gast valt weg en komt terug
	var old_peer_id := 0
	for row in host.slots:
		if int((row as Dictionary)["slot"]) == 2:
			old_peer_id = int((row as Dictionary)["peer_id"])
	var removed := [-1]
	host_s.slot_removed.connect(func(slot: int) -> void: removed[0] = slot)
	_stop_session(s2)
	g2.close()
	var dropped := await wait_until(func() -> bool: return host.player_count() == 3 and removed[0] == 2, STEP)
	check("gast weg: host meldt stoel 2 vrij", dropped and host.character_at(2) == "")
	check("gast weg: sim deactiveert stoel 2", not _active(host_s, 2))
	var rest := await wait_until(func() -> bool: return g1.player_count() == 3 and g3.player_count() == 3, STEP)
	check("gast weg: andere gasten zien 3 spelers", rest)
	check("gast weg: kamer draait door voor de rest", g1.phase == LanLobby.Phase.IN and g3.phase == LanLobby.Phase.IN)
	check("gast weg: gasten zien stoel 2 niet meer actief", not _active(s1, 2) and not _active(s3, 2))

	check("g2 rejoin met dezelfde code", g2.join_relay(_url, code, "noor", "Vesper") == OK)
	var back := await wait_until(func() -> bool: return g2.local_slot == 2 and host.player_count() == 4, STEP)
	check("rejoin: laagste vrije stoel 2, zelfde held", back and g2.local_character == "noor")
	var new_peer_id := 0
	for row in host.slots:
		if int((row as Dictionary)["slot"]) == 2:
			new_peer_id = int((row as Dictionary)["peer_id"])
	check("rejoin: nieuw peer-id (relay hergebruikt er geen)", new_peer_id != 0 and new_peer_id != old_peer_id)
	var g2_started := [false]
	g2.start_game_received.connect(func() -> void: g2_started[0] = true)
	host.host_start_game()
	await wait_until(func() -> bool: return g2_started[0], STEP)
	s2 = _start_session(g2)
	await wait_until(func() -> bool: return _active(host_s, 2) and _active(s2, 2), STEP)
	check("rejoin: stoel 2 weer actief op host en gast", _active(host_s, 2) and _active(s2, 2))
	var before := _pos(host_s, 2)
	s2.set_local_input(Vector2(1, 0), false, false, false)
	var moved_again := await wait_until(func() -> bool: return _pos(host_s, 2).x > before.x + 4, STEP)
	check("rejoin: input van de teruggekeerde gast bereikt de host", moved_again)
	var seen_again := await wait_until(func() -> bool:
		return _pos(s1, 2).x > before.x + 4 and _pos(s3, 2).x > before.x + 4, STEP)
	check("rejoin: andere gasten zien de teruggekeerde gast bewegen", seen_again)
	_stop_all_input([host_s, s1, s2, s3])
	var final_match := await wait_until(func() -> bool: return _all_match(host_s, [s1, s2, s3]), STEP)
	check("na rejoin: weer dezelfde posities op alle 4", final_match)

	# 6. Host beëindigt netjes: SESSION_END naar gasten, kamer weg
	var ended := [0]
	for g in [g1, g2, g3]:
		(g as LanLobby).session_ended.connect(func(_r: String) -> void: ended[0] += 1)
	host.broadcast_session_end("ended")
	await _frames(2)
	for s in [host_s, s1, s2, s3]:
		_stop_session(s as ActionCoopSession)
	host.close()
	var all_ended := await wait_until(func() -> bool: return ended[0] == 3, STEP)
	check("host sluit af: alle gasten krijgen session_ended", all_ended)
	var late: LanLobby = _lobby("RelayLate")
	check("join na afsluiten", late.join_relay(_url, code, "", "Laat") == OK)
	var late_refused := await wait_until(func() -> bool: return late.phase == LanLobby.Phase.REFUSED, STEP)
	check("kamer is weg na host-vertrek (code onbekend)", late_refused and late.refuse_reason == Protocol.Refuse.ROOM_NOT_FOUND)
	late.close()
	for g in [g1, g2, g3]:
		(g as LanLobby).close()


func _host_leaves_tests() -> void:
	var host: LanLobby = _lobby("LeaveHost")
	var guest: LanLobby = _lobby("LeaveGuest")
	check("tweede host_relay", host.host_relay(_url, "Dax") == OK)
	await wait_until(func() -> bool: return host.room_code != "", STEP)
	check("gast joint", guest.join_relay(_url, host.room_code, "", "Seren") == OK)
	await wait_until(func() -> bool: return guest.local_slot == 1, STEP)
	var lost := [false]
	guest.link_lost.connect(func() -> void: lost[0] = true)
	host.close()
	var got := await wait_until(func() -> bool: return lost[0], STEP)
	check("host weg zonder SESSION_END: gast krijgt link_lost", got)
	check("link_lost reden: host_left", guest.relay_reason == "host_left" and guest.phase == LanLobby.Phase.LOST)
	guest.close()
