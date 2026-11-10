extends Node
## Protocol v2 (online) naast LAN-v1. Start: godot --path . -- --protocolv2test [--shots=/pad]
## Start zelf de Node-relay. Bestaande --relaytest blijft onaangeroerd.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Blob := preload("res://scripts/net/avatar_blob.gd")
const Emotes := preload("res://scripts/net/emote_table.gd")
const Gate := preload("res://scripts/net/emote_gate.gd")
const Lobby := preload("res://scripts/net/lan_lobby.gd")
const SomData := preload("res://scripts/data/som_data.gd")

const STEP := 8.0
const VIEWPORT := Vector2i(384, 216)
const RELAY_DIR := "res://relay"
const LABELS: Array[String] = ["Help!", "Hier heen", "Goed gedaan", "Wacht", "Klaar", "Pas op"]

var failures := 0
var passes := 0
var shots := ""
var _relay_pid := 0
var _port := 0
var _url := ""
var _nodes: Array[Node] = []
var _profiles: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_profiles = _make_profiles()
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	OS.unset_environment(Protocol.RELAY_URL_ENV)
	_codec_tests()
	if await _start_relay():
		await _refuse_live()
		await _room_and_sandbox()
	else:
		check("relay beschikbaar voor protocol v2", false)
	_stop_relay()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _make_profiles() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"uid": "a1b2c3d4", "name": "Mira", "class": "priest", "skin": 0, "hair": 1, "hair_color": 1, "top": 0, "top_color": 1, "bottom": 0, "bottom_color": 2, "head": 0},
		{"uid": "b2c3d4e5", "name": "Dex", "class": "warrior", "skin": 1, "hair": 2, "hair_color": 3, "top": 1, "top_color": 2, "bottom": 1, "bottom_color": 3, "head": 1},
		{"uid": "c3d4e5f6", "name": "Nim", "class": "mage", "skin": 2, "hair": 3, "hair_color": 5, "top": 2, "top_color": 4, "bottom": 2, "bottom_color": 5, "head": 2},
		{"uid": "d4e5f6a7", "name": "Ash", "class": "archer", "skin": 3, "hair": 5, "hair_color": 7, "top": 3, "top_color": 0, "bottom": 0, "bottom_color": 1, "head": 0},
	]
	var out: Array[Dictionary] = []
	for row in rows:
		var look := {
			"body": 0,
			"skin": int(row["skin"]),
			"hair": int(row["hair"]),
			"hair_color": int(row["hair_color"]),
			"top": int(row["top"]),
			"top_color": int(row["top_color"]),
			"bottom": int(row["bottom"]),
			"bottom_color": int(row["bottom_color"]),
			"head": int(row["head"]),
			"class": str(row["class"]),
		}
		out.append({
			"uid": str(row["uid"]),
			"name": str(row["name"]),
			"class": str(row["class"]),
			"look": look,
		})
	return out


func _codec_tests() -> void:
	check("LAN VERSION blijft 1", Protocol.VERSION == 1)
	check("online VERSION is 2", Protocol.VERSION_ONLINE == 2)
	check("HELLO en START_GAME houden hun nummers", Protocol.Kind.HELLO == 1 and Protocol.Kind.START_GAME == 8)
	check("nieuwe kinds staan in protocol en codec",
			Protocol.Kind.READY == Codec.KIND_READY and Codec.KIND_READY == 9
			and Protocol.Kind.SIM_SELECT == 10 and Protocol.Kind.RUN_RESULT == 11
			and Protocol.Kind.REWARD_BUNDLE == 12 and Protocol.Kind.HOST_PAUSED == 13
			and Protocol.Kind.EMOTE == Codec.KIND_EMOTE and Codec.KIND_EMOTE == 14
			and Protocol.Kind.VOTE == 15)
	check("emote-cooldown is 1,5 s", is_equal_approx(Protocol.EMOTE_COOLDOWN_SEC, 1.5))
	var labels_ok := Emotes.ids().size() == 6
	for i in LABELS.size():
		if Emotes.label(i) != LABELS[i] or not Emotes.valid_id(i):
			labels_ok = false
	check("emotes.json ids 0..5 met vaste labels", labels_ok and not Emotes.valid_id(6) and not Emotes.valid_id(-1))
	var file_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Emotes.PATH))
	var file_match := file_parsed is Dictionary
	if file_match:
		var rows: Variant = (file_parsed as Dictionary).get("emotes", [])
		file_match = rows is Array and (rows as Array).size() == 6
		if file_match:
			for item in rows:
				var id := int((item as Dictionary).get("id", -1))
				file_match = file_match and Emotes.label(id) == str((item as Dictionary).get("label", ""))
	check("tabel leest data/online/emotes.json", file_match)
	var gate: EmoteGate = Gate.new()
	check("gate: eerste emote van een stoel", gate.allow(1, 10.0))
	check("gate: binnen 1,5 s geweigerd", not gate.allow(1, 11.49))
	check("gate: op 1,5 s weer toegestaan", gate.allow(1, 11.5))
	check("gate: andere stoel heeft een eigen cooldown", gate.allow(2, 11.0))
	var blobs: Array[PackedByteArray] = []
	var blobs_ok := true
	for profile in _profiles:
		var blob := Blob.encode(profile["look"])
		blobs.append(blob)
		var back := Blob.decode(blob)
		blobs_ok = blobs_ok and blob.size() == Protocol.LOOK_BYTES and bool(back.get("ok", false))
		blobs_ok = blobs_ok and str(back.get("class_id", "")) == str(profile["class"])
		blobs_ok = blobs_ok and int(back.get("skin", -1)) == int(profile["look"]["skin"])
		blobs_ok = blobs_ok and int(back.get("hair_color", -1)) == int(profile["look"]["hair_color"])
	check("vier looks coderen naar 16 bytes en terug", blobs_ok)
	var distinct := true
	for i in blobs.size():
		for j in range(i + 1, blobs.size()):
			if blobs[i] == blobs[j]:
				distinct = false
	check("vier avatars hebben een verschillende look", distinct)
	var wild := Blob.encode({"class": "priest", "body": 1, "skin": 0, "hair": 0, "hair_color": 0, "top": 0, "top_color": 0, "bottom": 0, "bottom_color": 0, "head": 0})
	check("look buiten de v1-grenzen wordt geweigerd", wild.is_empty())
	var mismatch := Codec.normalize_profile({
		"uid": "a1b2c3d4",
		"name": "Mira",
		"class": "mage",
		"look": blobs[0],
	})
	check("klasse in HELLO en in de blob moeten gelijk zijn", not bool(mismatch.get("ok", false)))
	check("kapot profiel start geen join", Lobby.new().join_relay_v2("ws://127.0.0.1:1", "ABC234", {"uid": "zz", "name": "Mira", "class": "priest"}) == ERR_INVALID_PARAMETER)
	var hello := Codec.encode_v2(Protocol.Kind.HELLO, Codec.hello_body(Codec.normalize_profile(_profiles[0])))
	var hello_msg := Codec.decode_v2(hello)
	var hello_body := Codec.read_hello_v2(hello_msg.get("body", {}))
	check("HELLO v2 roundtrip", hello.size() < 2048 and bool(hello_msg.get("compatible", false))
			and str(hello_body.get("uid", "")) == "a1b2c3d4" and str(hello_body.get("name", "")) == "Mira"
			and str(hello_body.get("class_id", "")) == "priest"
			and (hello_body.get("look", PackedByteArray()) as PackedByteArray) == blobs[0])
	var lan_sees_v2 := Protocol.decode(hello)
	check("oude LAN-decode weigert HELLO v2 met VERSION", bool(lan_sees_v2.get("ok", false))
			and not bool(lan_sees_v2.get("compatible", false))
			and int(lan_sees_v2.get("reason", -1)) == Protocol.Refuse.VERSION)
	var v1_hello := Protocol.encode(Protocol.Kind.HELLO, {"character_id": "lotte", "display_name": "Seren"})
	var v2_sees_v1 := Codec.decode_v2(v1_hello)
	check("online-decode weigert HELLO v1 met VERSION", bool(v2_sees_v1.get("ok", false))
			and not bool(v2_sees_v1.get("compatible", false))
			and int(v2_sees_v1.get("reason", -1)) == Protocol.Refuse.VERSION)
	check("LAN HELLO v1 blijft compatible", bool(Protocol.decode(v1_hello).get("compatible", false)))
	var wire_slots: Array[Dictionary] = []
	for i in _profiles.size():
		var norm: Dictionary = Codec.normalize_profile(_profiles[i])
		wire_slots.append({
			"seat": i,
			"slot": i,
			"uid": str(norm.get("uid", "")),
			"name": str(norm.get("name", "")),
			"class": str(norm.get("class_id", "")),
			"wire_controller": Protocol.CTRL_LOCAL if i == 0 else Protocol.CTRL_REMOTE,
			"look": norm.get("look", PackedByteArray()),
		})
	var roster_raw := Codec.encode_v2(Protocol.Kind.ROSTER, Codec.roster_body_from_slots(wire_slots))
	var roster_msg := Codec.decode_v2(roster_raw)
	var roster := Codec.read_roster_v2(roster_msg.get("body", {}))
	var roster_ok := roster_raw.size() > 0 and roster_raw.size() < 2048 and roster_raw.size() <= 2046
	roster_ok = roster_ok and bool(roster.get("ok", false)) and (roster.get("seats", []) as Array).size() == 4
	if roster_ok:
		for i in 4:
			var seat: Dictionary = (roster.get("seats", []) as Array)[i]
			var want: Dictionary = wire_slots[i]
			roster_ok = roster_ok and int(seat.get("seat", -1)) == i
			roster_ok = roster_ok and str(seat.get("uid", "")) == str(want["uid"])
			roster_ok = roster_ok and str(seat.get("name", "")) == str(want["name"])
			roster_ok = roster_ok and str(seat.get("class_id", "")) == str(want["class"])
			roster_ok = roster_ok and str(seat.get("controller", "")) == str(want["wire_controller"])
			roster_ok = roster_ok and (seat.get("look", PackedByteArray()) as PackedByteArray) == (want["look"] as PackedByteArray)
	check("ROSTER v2 roundtrip van 4 avatars onder 2048 bytes (%d)" % roster_raw.size(), roster_ok)
	var old_roster := Protocol.decode(roster_raw)
	check("oude build leest het roster-pakket als REFUSE VERSION", bool(old_roster.get("ok", false))
			and not bool(old_roster.get("compatible", false))
			and int(old_roster.get("reason", -1)) == Protocol.Refuse.VERSION)
	_kind_roundtrip("READY", Codec.encode_ready(1, true), Codec.KIND_READY, func(body: Dictionary) -> bool:
		var got := Codec.read_ready(body)
		return bool(got.get("ok", false)) and int(got.get("seat", -1)) == 1 and bool(got.get("ready", false)))
	_kind_roundtrip("SIM_SELECT", Codec.encode_sim_select("dls", "easy"), Codec.KIND_SIM_SELECT, func(body: Dictionary) -> bool:
		var got := Codec.read_sim_select(body)
		return bool(got.get("ok", false)) and str(got.get("sim", "")) == "dls" and str(got.get("mode", "")) == "easy")
	_kind_roundtrip("RUN_RESULT", Codec.encode_run_result(10, 4, 1, "easy"), Codec.KIND_RUN_RESULT, func(body: Dictionary) -> bool:
		var got := Codec.read_run_result(body)
		return bool(got.get("ok", false)) and int(got.get("floors", -1)) == 10 and int(got.get("kills", -1)) == 4 and int(got.get("revives", -1)) == 1)
	_kind_roundtrip("REWARD_BUNDLE", Codec.encode_reward_bundle("a1b2c3d4", 7, 120, 15, ["hair_3"]), Codec.KIND_REWARD_BUNDLE, func(body: Dictionary) -> bool:
		var got := Codec.read_reward_bundle(body)
		var unlocks: Array = got.get("unlocks", [])
		return bool(got.get("ok", false)) and str(got.get("uid", "")) == "a1b2c3d4" and int(got.get("profile_exp", -1)) == 15 and unlocks.size() == 1 and str(unlocks[0]) == "hair_3")
	_kind_roundtrip("HOST_PAUSED", Codec.encode_host_paused(true), Codec.KIND_HOST_PAUSED, func(body: Dictionary) -> bool:
		var got := Codec.read_host_paused(body)
		return bool(got.get("ok", false)) and bool(got.get("paused", false)))
	var emote_raw := Codec.encode_emote(2, 1)
	_kind_roundtrip("EMOTE", emote_raw, Codec.KIND_EMOTE, func(body: Dictionary) -> bool:
		var got := Codec.read_emote(body)
		return bool(got.get("ok", false)) and int(got.get("seat", -1)) == 2 and int(got.get("emote_id", -1)) == 1)
	check("EMOTE-draad heeft geen labeltekst", emote_raw.get_string_from_utf8().find("Hier heen") < 0 and emote_raw.get_string_from_utf8().find("Help!") < 0)
	check("ongeldig emote-id wordt niet verstuurd", Codec.encode_emote(1, 9).is_empty() and Codec.encode_emote(1, -1).is_empty())
	_kind_roundtrip("VOTE", Codec.encode_vote(3, 2), Codec.KIND_VOTE, func(body: Dictionary) -> bool:
		var got := Codec.read_vote(body)
		return bool(got.get("ok", false)) and int(got.get("seat", -1)) == 3 and int(got.get("choice", -1)) == 2)
	check("SIM_SELECT weigert vrije tekst", Codec.encode_sim_select("dls", "een eigen verhaal").is_empty())
	check("VOTE weigert een keuze buiten 0..7", Codec.encode_vote(0, 8).is_empty())
	var huge := PackedByteArray()
	huge.resize(Protocol.MAX_ONLINE_PACKET_BYTES)
	check("pakket van 2048 bytes wordt geweigerd", not bool(Codec.decode_v2(huge).get("ok", false)))


func _kind_roundtrip(label: String, raw: PackedByteArray, kind: int, pred: Callable) -> void:
	var msg := Codec.decode_v2(raw)
	var fields: bool = pred.call(msg.get("body", {})) if bool(msg.get("compatible", false)) else false
	check("%s codec-roundtrip < 2048 (%d bytes)" % [label, raw.size()],
			raw.size() > 0 and raw.size() < 2048 and int(msg.get("kind", -1)) == kind and fields)


func _start_relay() -> bool:
	var dir := ProjectSettings.globalize_path(RELAY_DIR)
	var out: Array = []
	var node_ok := OS.execute("node", ["--version"], out) == 0
	check("node gevonden", node_ok)
	if not node_ok:
		return false
	if not DirAccess.dir_exists_absolute(dir.path_join("node_modules/ws")):
		var npm_out: Array = []
		var code := OS.execute("npm", ["ci", "--prefix", dir, "--no-audit", "--no-fund", "--silent"], npm_out, true)
		check("npm ci in relay/", code == 0)
		if code != 0:
			return false
	_port = _free_port()
	check("vrije poort", _port > 0)
	if _port == 0:
		return false
	OS.set_environment("RELAY_QUIET", "1")
	_relay_pid = OS.create_process("node", [dir.path_join("server.js"), "--port=%d" % _port])
	check("relay-proces gestart", _relay_pid > 0)
	if _relay_pid <= 0:
		return false
	_url = "ws://127.0.0.1:%d" % _port
	var up := await wait_until(_relay_accepts_tcp, 10.0)
	check("relay luistert", up)
	return up


func _free_port() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2048
	for i in 40:
		var port := rng.randi_range(50000, 58000)
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
		if is_instance_valid(n) and n.has_method("close"):
			n.close()
			n.queue_free()
	_nodes.clear()
	if _relay_pid > 0:
		OS.kill(_relay_pid)
		_relay_pid = 0


func _lobby(node_name: String) -> LanLobby:
	var lobby := Lobby.new()
	lobby.name = node_name
	add_child(lobby)
	_nodes.append(lobby)
	return lobby


func _refuse_live() -> void:
	var host: LanLobby = _lobby("V2HostRefuse")
	check("v2 host start", host.host_relay_v2(_url, _profiles[0]) == OK)
	var ready := await wait_until(func() -> bool: return host.room_code != "", STEP)
	check("v2 host krijgt een kamercode", ready and Protocol.is_room_code(host.room_code))
	var old := Lobby.new()
	old.name = "V1Guest"
	add_child(old)
	_nodes.append(old)
	check("v1-gast probeert de v2-kamer", old.join_relay(_url, host.room_code, "lotte", "Seren") == OK)
	var refused := await wait_until(func() -> bool: return old.phase == LanLobby.Phase.REFUSED, STEP)
	check("oude build krijgt REFUSE VERSION van een v2-host", refused and old.refuse_reason == Protocol.Refuse.VERSION)
	old.close()
	host.close()
	var lan_host: LanLobby = _lobby("V1HostRefuse")
	check("v1 host start", lan_host.host_relay(_url, "Dax") == OK)
	await wait_until(func() -> bool: return lan_host.room_code != "", STEP)
	var newbie: LanLobby = _lobby("V2GuestRefuse")
	check("v2-gast probeert de v1-kamer", newbie.join_relay_v2(_url, lan_host.room_code, _profiles[1]) == OK)
	var refused_v2 := await wait_until(func() -> bool: return newbie.phase == LanLobby.Phase.REFUSED, STEP)
	check("v2-gast krijgt REFUSE VERSION van een v1-host", refused_v2 and newbie.refuse_reason == Protocol.Refuse.VERSION)
	newbie.close()
	lan_host.close()


func _room_and_sandbox() -> void:
	var host: LanLobby = _lobby("V2Host")
	var guests: Array[LanLobby] = []
	check("kamer-host v2", host.host_relay_v2(_url, _profiles[0]) == OK)
	var code_ready := await wait_until(func() -> bool: return host.room_code != "", STEP)
	check("kamercode", code_ready)
	if not code_ready:
		return
	var code := host.room_code
	for i in range(1, 4):
		var guest: LanLobby = _lobby("V2G%d" % i)
		guests.append(guest)
		check("gast %d join v2" % i, guest.join_relay_v2(_url, code, _profiles[i]) == OK)
	var full := await wait_until(func() -> bool:
		if host.player_count() != 4:
			return false
		for g in guests:
			if g.player_count() != 4 or g.local_slot == Protocol.NO_SLOT:
				return false
		return true
	, STEP)
	check("vier spelers via de relay", full)
	if not full:
		return
	_assert_roster(host, 0)
	for i in guests.size():
		_assert_roster(guests[i], i + 1)
	await _emote_live(host, guests)
	await _sandbox(host)


func _assert_roster(lobby: LanLobby, local_seat: int) -> void:
	var ok := lobby.player_count() == 4 and lobby.local_slot == local_seat
	for i in 4:
		var row := _seat_row(lobby, i)
		var want: Dictionary = _profiles[i]
		var look: PackedByteArray = row.get("look", PackedByteArray())
		var blob := Blob.encode(want["look"])
		ok = ok and not row.is_empty()
		ok = ok and str(row.get("uid", "")) == str(want["uid"])
		ok = ok and str(row.get("name", "")) == str(want["name"])
		ok = ok and str(row.get("class", "")) == str(want["class"])
		ok = ok and look == blob
		ok = ok and str(row.get("character_id", "")) == Blob.base_hero(str(want["class"]))
		var ctrl := str(row.get("controller", ""))
		if i == local_seat:
			ok = ok and ctrl == Protocol.CTRL_LOCAL
		else:
			ok = ok and ctrl == Protocol.CTRL_REMOTE
	check("roster stoel %d ziet 4 avatars (eigen controller local)" % local_seat, ok)


func _seat_row(lobby: LanLobby, seat: int) -> Dictionary:
	for row in lobby.slots:
		if int((row as Dictionary).get("seat", -1)) == seat:
			return row
	return {}


func _emote_live(host: LanLobby, guests: Array[LanLobby]) -> void:
	var counts := [0, 0, 0, 0]
	var last: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1)]
	var lobbies: Array[LanLobby] = [host]
	for g in guests:
		lobbies.append(g)
	for i in lobbies.size():
		var idx := i
		lobbies[i].emote_received.connect(func(seat: int, emote_id: int) -> void:
			counts[idx] += 1
			last[idx] = Vector2i(seat, emote_id)
		)
	_push_emote(guests[0], 0, 0)
	await _frames(20)
	var quiet := true
	for n in counts:
		if n != 0:
			quiet = false
	check("EMOTE met andermans stoel wordt geweigerd", quiet)
	guests[0].send_emote(2)
	var got := await wait_until(func() -> bool:
		for n in counts:
			if n != 1:
				return false
		return true
	, STEP)
	var payload_ok := true
	for seen in last:
		if seen != Vector2i(1, 2):
			payload_ok = false
	check("EMOTE roundtrip naar host en 3 gasten", got and payload_ok)
	guests[0].send_emote(2)
	await _frames(25)
	var still := true
	for n in counts:
		if n != 1:
			still = false
	check("EMOTE binnen 1,5 s wordt door de host gedropt", still)


func _push_emote(lobby: LanLobby, seat: int, emote_id: int) -> void:
	var peer := lobby.enet_peer()
	if peer == null:
		return
	var raw := Codec.encode_emote(seat, emote_id)
	peer.set_target_peer(Protocol.HOST_PEER_ID)
	peer.put_packet(raw)
	peer.poll()


func _sandbox(host: LanLobby) -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.call("_build_som_state")
	GameState.coop_role = "host"
	GameState.coop_register_lobby(host, null)
	var vp := SubViewport.new()
	vp.name = "ProtocolV2Sandbox"
	vp.size = VIEWPORT
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = true
	add_child(vp)
	var sandbox: Node = load("res://scenes/coop/action_sandbox.tscn").instantiate()
	vp.add_child(sandbox)
	var som: SomArena = null
	var ready := false
	for i in 600:
		var room: Node = sandbox.get("_room")
		if room != null and room.get("som") != null:
			som = room.get("som") as SomArena
			if som != null and som.coop_remote_avatar_count() == 3:
				ready = true
				break
		await get_tree().process_frame
	check("sandbox via relay toont 3 remote avatars", ready and som != null and som.coop_remote_avatar_count() == 3)
	if som == null:
		vp.queue_free()
		return
	var sess: ActionCoopSession = sandbox.get_session()
	if sess != null:
		sess.arena_drive = false
	som.coop_sim_host = false
	# De SubViewport tekent wereld 0..384. Rij rechtsboven de speler, sprites raken elkaar niet.
	var origin := som.player.global_position
	som.player.z_index = 20
	for slot in [1, 2, 3]:
		if som._coop_avatars.has(slot):
			var body := som._coop_avatars[slot] as Node2D
			body.z_index = 20
			body.global_position = origin + Vector2(slot * 34, -40)
	await _frames(4)
	var sprites := som.coop_party_texture_sprite_count()
	check("sandbox telt 4 partij-sprites (speler + 3 avatars)", sprites == 4)
	var looks_ok := true
	var hero_ok := som.active_id == Blob.base_hero("priest")
	var host_look: PackedByteArray = som.player.get_meta("online_look", PackedByteArray())
	looks_ok = looks_ok and host_look == Blob.encode(_profiles[0]["look"])
	var host_sprite := som.player.get_node_or_null("Sprite2D") as Sprite2D
	if host_sprite != null:
		looks_ok = looks_ok and _tint_near(host_sprite.modulate, Blob.placeholder_tint(Blob.decode(host_look)))
	else:
		looks_ok = false
	for slot in [1, 2, 3]:
		if not som._coop_avatars.has(slot):
			hero_ok = false
			looks_ok = false
			continue
		var av: CoopAvatar = som._coop_avatars[slot] as CoopAvatar
		var want: Dictionary = _profiles[slot]
		hero_ok = hero_ok and av.hero_id == Blob.base_hero(str(want["class"]))
		hero_ok = hero_ok and av.sprite != null and av.sprite.texture != null and av.sprite.visible
		looks_ok = looks_ok and av.look_blob == Blob.encode(want["look"])
		if av.sprite != null:
			looks_ok = looks_ok and _tint_near(av.sprite.modulate, Blob.placeholder_tint(Blob.decode(av.look_blob)))
	check("vier klassen gebruiken de bestaande held-sheets", hero_ok)
	check("look-blob kleurt de vier avatars", looks_ok)
	var in_view := _sprite_in_view(som, som.player)
	for slot in [1, 2, 3]:
		if som._coop_avatars.has(slot):
			in_view = in_view and _sprite_in_view(som, som._coop_avatars[slot] as Node2D)
		else:
			in_view = false
	check("vier avatars staan in beeld", in_view)
	var img := await _save_sandbox(vp)
	var varied := false
	if img != null:
		var colors := {}
		for y in range(0, img.get_height(), 6):
			for x in range(0, img.get_width(), 6):
				colors[img.get_pixel(x, y).to_html(false)] = true
		varied = img.get_width() == VIEWPORT.x and img.get_height() == VIEWPORT.y and colors.size() > 8
	check("sandbox-beeld is gevuld (%s)" % (_shot_path()), varied)
	vp.queue_free()


func _sprite_in_view(som: SomArena, body: Node2D) -> bool:
	if som.player == null or body == null:
		return false
	# action_sandbox in een SubViewport tekent de wereld vanaf (0, 0); de Camera2D
	# van de speler is daar niet current (get_screen_center_position blijft 192,96).
	var p := body.global_position
	return p.x > 8.0 and p.x < float(VIEWPORT.x - 8) and p.y > 8.0 and p.y < float(VIEWPORT.y - 8)


func _tint_near(got: Color, want: Color) -> bool:
	return is_equal_approx(got.r, want.r) and is_equal_approx(got.g, want.g) and is_equal_approx(got.b, want.b)


func _shot_path() -> String:
	var dir := shots if shots != "" else "/opt/cursor/artifacts"
	return dir.path_join("protocol_v2_four_avatars.png")


func _save_sandbox(vp: SubViewport) -> Image:
	await _frames(2)
	var tex := vp.get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	var path := _shot_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("INFO  screenshot: ", path)
	return img
