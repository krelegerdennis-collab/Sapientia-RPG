class_name LanLobby
extends Node
## Host/join voor maximaal 4 spelers, over ENet (LAN) of over de relay (RelayPeer, WebSocket).
## Het protocol (HELLO/WELCOME/ROSTER/...) is voor beide transporten hetzelfde. Niet aan een scène gekoppeld.
## Zet bewust NIET de SceneTree-multiplayer: de rest van het spel blijft singleplayer
## tot een latere PR deze peer daar ophangt. Elke instantie pollt haar eigen peer.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const RelayPeerScript := preload("res://scripts/net/relay_peer.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const AvatarBlob := preload("res://scripts/net/avatar_blob.gd")
const EmoteGateScript := preload("res://scripts/net/emote_gate.gd")

signal assigned(slot: int, character_id: String)
signal refused(reason: int)
signal roster_changed
signal member_left(peer_id: int)
signal link_lost
signal start_game_received
signal session_ended(reason: String)
## Relay-host: de relay gaf een kamercode. Alleen bij transport RELAY.
signal room_ready(code: String)
## Online v2: de host heeft een emote doorgelaten. Tonen is M5.
signal emote_received(seat: int, emote_id: int)

enum Phase { IDLE, JOINING, IN, REFUSED, LOST }
enum Transport { LAN, RELAY }

var is_host := false
var phase: Phase = Phase.IDLE
var local_slot := Protocol.NO_SLOT
var local_character := ""
var refuse_reason := Protocol.Refuse.NONE
var slots: Array[Dictionary] = []
## Laatste mislukte host/join-poging (voor de melding en de logcat). OK = geen fout.
var last_error: Error = OK
var last_error_port := 0
var transport: Transport = Transport.LAN
## Relay: kamercode (host: pas na room_ready; gast: de ingetikte code).
var room_code := ""
## Relay: laatste reden van de relay/verbinding (RelayPeer.last_reason), "" = geen.
var relay_reason := ""
## 1 = LAN (fase B). 2 = online co-op. De twee praten niet door elkaar.
var protocol_version := Protocol.VERSION

var _peer: MultiplayerPeer
var _join_timeout := Protocol.JOIN_TIMEOUT_SEC
var _display_name := ""
var _want_character := ""
var _hello_version := Protocol.VERSION
var _hello_sent := false
var _join_wait := 0.0
var _suppress := false
var _remotes: Array[int] = []
var _kick_queued: Array[int] = []
var _drop_ids: Array[int] = []
var _gameplay: Node = null
var _online_profile: Dictionary = {}
var _emote_gate: EmoteGate = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func host_session(display_name: String) -> Error:
	if phase != Phase.IDLE or _peer != null:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var err := peer.create_server(Protocol.ENET_PORT, Protocol.MAX_REMOTE + Protocol.ENET_REFUSE_SLACK)
	if err != OK:
		_note_failure("host", err, Protocol.ENET_PORT)
		return err
	last_error = OK
	last_error_port = 0
	_bind(peer)
	is_host = true
	phase = Phase.IN
	_display_name = Protocol.clean_name(display_name)
	_add_slot(Protocol.HOST_PEER_ID, Protocol.HOST_SLOT, Protocol.HOST_CHARACTER, _display_name)
	local_slot = Protocol.HOST_SLOT
	local_character = Protocol.HOST_CHARACTER
	return OK


## version wijkt in de test af om een verkeerde build te weigeren.
func join_session(ip: String, character_id: String, display_name: String, version: int = Protocol.VERSION) -> Error:
	if phase != Phase.IDLE or _peer != null:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var err := peer.create_client(ip, Protocol.ENET_PORT)
	if err != OK:
		_note_failure("join %s" % ip, err, Protocol.ENET_PORT)
		return err
	last_error = OK
	last_error_port = 0
	_bind(peer)
	is_host = false
	phase = Phase.JOINING
	_want_character = character_id
	_display_name = Protocol.clean_name(display_name)
	_hello_version = version
	_hello_sent = false
	_join_wait = 0.0
	return OK


## Host via de relay: opent een kamer. De code komt async via room_ready.
func host_relay(url: String, display_name: String) -> Error:
	if phase != Phase.IDLE or _peer != null:
		return ERR_ALREADY_IN_USE
	var peer: RelayPeer = RelayPeerScript.new()
	var err := peer.create_host(url)
	if err != OK:
		_note_failure("host relay", err, 0)
		return err
	last_error = OK
	last_error_port = 0
	transport = Transport.RELAY
	room_code = ""
	relay_reason = ""
	peer.room_ready.connect(_on_relay_room_ready)
	_bind(peer)
	is_host = true
	phase = Phase.IN
	_display_name = Protocol.clean_name(display_name)
	_add_slot(Protocol.HOST_PEER_ID, Protocol.HOST_SLOT, Protocol.HOST_CHARACTER, _display_name)
	local_slot = Protocol.HOST_SLOT
	local_character = Protocol.HOST_CHARACTER
	return OK


## Gast via de relay met een kamercode. version: zie join_session.
func join_relay(url: String, code: String, character_id: String, display_name: String, version: int = Protocol.VERSION) -> Error:
	if phase != Phase.IDLE or _peer != null:
		return ERR_ALREADY_IN_USE
	var clean := Protocol.filter_room_code(code)
	if not Protocol.is_room_code(clean):
		return ERR_INVALID_PARAMETER
	var peer: RelayPeer = RelayPeerScript.new()
	var err := peer.create_client(url, clean)
	if err != OK:
		_note_failure("join relay", err, 0)
		return err
	last_error = OK
	last_error_port = 0
	transport = Transport.RELAY
	room_code = clean
	relay_reason = ""
	_bind(peer)
	is_host = false
	phase = Phase.JOINING
	_want_character = character_id
	_display_name = Protocol.clean_name(display_name)
	_hello_version = version
	_hello_sent = false
	_join_wait = 0.0
	_join_timeout = Protocol.RELAY_JOIN_TIMEOUT_SEC
	return OK


## Online host (protocol v2). profile: uid, name, class, look (dict of blob).
## LAN-host_relay blijft versie 1 en wijst nog de vaste helden toe.
func host_relay_v2(url: String, profile: Dictionary) -> Error:
	if phase != Phase.IDLE or _peer != null:
		return ERR_ALREADY_IN_USE
	var norm := Codec.normalize_profile(profile)
	if not bool(norm.get("ok", false)):
		return ERR_INVALID_PARAMETER
	var peer: RelayPeer = RelayPeerScript.new()
	var err := peer.create_host(url)
	if err != OK:
		_note_failure("host relay v2", err, 0)
		return err
	last_error = OK
	last_error_port = 0
	transport = Transport.RELAY
	room_code = ""
	relay_reason = ""
	protocol_version = Protocol.VERSION_ONLINE
	_online_profile = norm
	_emote_gate = EmoteGateScript.new()
	peer.room_ready.connect(_on_relay_room_ready)
	_bind(peer)
	is_host = true
	phase = Phase.IN
	_display_name = str(norm.get("name", ""))
	_add_online_slot(Protocol.HOST_PEER_ID, Protocol.HOST_SLOT, norm, Protocol.CTRL_LOCAL)
	local_slot = Protocol.HOST_SLOT
	local_character = AvatarBlob.base_hero(str(norm.get("class_id", "")))
	return OK


## Online gast (protocol v2). Een v1-host antwoordt met REFUSE VERSION.
func join_relay_v2(url: String, code: String, profile: Dictionary) -> Error:
	if phase != Phase.IDLE or _peer != null:
		return ERR_ALREADY_IN_USE
	var norm := Codec.normalize_profile(profile)
	if not bool(norm.get("ok", false)):
		return ERR_INVALID_PARAMETER
	var clean := Protocol.filter_room_code(code)
	if not Protocol.is_room_code(clean):
		return ERR_INVALID_PARAMETER
	var peer: RelayPeer = RelayPeerScript.new()
	var err := peer.create_client(url, clean)
	if err != OK:
		_note_failure("join relay v2", err, 0)
		return err
	last_error = OK
	last_error_port = 0
	transport = Transport.RELAY
	room_code = clean
	relay_reason = ""
	protocol_version = Protocol.VERSION_ONLINE
	_online_profile = norm
	_bind(peer)
	is_host = false
	phase = Phase.JOINING
	_want_character = ""
	_display_name = str(norm.get("name", ""))
	_hello_version = Protocol.VERSION_ONLINE
	_hello_sent = false
	_join_wait = 0.0
	_join_timeout = Protocol.RELAY_JOIN_TIMEOUT_SEC
	return OK


## Eigen stoel stuurt een emote. De host keurt goed; gasten wachten op de broadcast.
func send_emote(emote_id: int) -> void:
	if phase != Phase.IN or protocol_version != Protocol.VERSION_ONLINE:
		return
	if local_slot == Protocol.NO_SLOT:
		return
	if is_host:
		_accept_emote(local_slot, local_slot, emote_id)
		return
	var raw := Codec.encode_emote(local_slot, emote_id)
	if raw.is_empty() or _peer == null:
		return
	_peer.set_target_peer(Protocol.HOST_PEER_ID)
	_peer.put_packet(raw)
	_peer.poll()


func _on_relay_room_ready(code: String) -> void:
	room_code = code
	room_ready.emit(code)


func _note_failure(what: String, err: Error, port: int) -> void:
	last_error = err
	last_error_port = port
	push_warning("LanLobby: %s failed: %s, UDP port %d" % [what, Protocol.error_name(err), port])


## Maakt de peer los. Daarna mag host_session of join_session opnieuw.
func close() -> void:
	_suppress = true
	unbind_gameplay()
	var peer := _peer
	_peer = null
	if peer != null:
		peer.close()
	is_host = false
	phase = Phase.IDLE
	local_slot = Protocol.NO_SLOT
	local_character = ""
	refuse_reason = Protocol.Refuse.NONE
	slots.clear()
	_remotes.clear()
	_kick_queued.clear()
	_drop_ids.clear()
	_hello_sent = false
	_join_wait = 0.0
	_join_timeout = Protocol.JOIN_TIMEOUT_SEC
	transport = Transport.LAN
	room_code = ""
	relay_reason = ""
	protocol_version = Protocol.VERSION
	_online_profile = {}
	_emote_gate = null
	_suppress = false


func player_count() -> int:
	return slots.size()


## De open peer (ENet of RelayPeer); de naam blijft voor bestaande aanroepers.
func enet_peer() -> MultiplayerPeer:
	return _peer


## ActionCoopSession: lobby pollt de peer; JSON blijft hier, INPUT/SNAPSHOT naar de sessie.
func bind_gameplay(session: Node) -> void:
	_gameplay = session


func unbind_gameplay() -> void:
	_gameplay = null


## Host: iedereen mag de Action-sandbox laden.
func host_start_game() -> void:
	if not is_host or _peer == null:
		return
	_unicast_remotes(Protocol.Kind.START_GAME, {})


## Host: sessie beëindigen (bv. app op pauze). Gasten krijgen session_ended.
func broadcast_session_end(reason: String) -> void:
	if not is_host or _peer == null:
		return
	_unicast_remotes(Protocol.Kind.SESSION_END, {"reason": reason})


func remote_link_count() -> int:
	return _remotes.size()


func character_at(slot: int) -> String:
	for row in slots:
		if int(row["slot"]) == slot:
			return str(row["character_id"])
	return ""


func character_ids() -> Array[String]:
	var out: Array[String] = []
	for row in slots:
		out.append(str(row["character_id"]))
	return out


func _process(delta: float) -> void:
	if _peer == null:
		return
	# poll() levert vorige frame (REFUSE/WELCOME) af en haalt dode peers weg.
	# Alleen wie dan nog in _remotes staat, sluiten we zelf.
	_peer.poll()
	_apply_drops()
	_flush_kicks()
	_drain()
	_apply_drops()
	_check_relay_host()
	if phase != Phase.JOINING or _peer == null:
		return
	var status := _peer.get_connection_status()
	# ENet weigert boven MAX_REMOTE vóór HELLO: geen pakket, wel meteen DISCONNECTED.
	# Relay: een fout van de relay (geen kamer, vol, onbereikbaar) komt ook zo binnen.
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED and local_slot == Protocol.NO_SLOT and refuse_reason == Protocol.Refuse.NONE:
		_set_refused(_join_failure_reason())
		return
	if status == MultiplayerPeer.CONNECTION_CONNECTED and not _hello_sent:
		if protocol_version == Protocol.VERSION_ONLINE:
			_send_to(Protocol.HOST_PEER_ID, Protocol.Kind.HELLO, Codec.hello_body(_online_profile), Protocol.VERSION_ONLINE)
		else:
			_send_to(Protocol.HOST_PEER_ID, Protocol.Kind.HELLO, {
				"character_id": _want_character,
				"display_name": _display_name,
			}, _hello_version)
		_hello_sent = true
	_join_wait += minf(delta, Protocol.JOIN_TICK_CAP_SEC)
	if _join_wait >= _join_timeout and local_slot == Protocol.NO_SLOT and refuse_reason == Protocol.Refuse.NONE:
		_set_refused(Protocol.Refuse.TIMEOUT)


## Relay-host zonder relay (onbereikbaar, kamer verlopen): zelfde afhandeling als een gast die de host verliest.
func _check_relay_host() -> void:
	if not is_host or transport != Transport.RELAY or _peer == null or phase != Phase.IN:
		return
	if _peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	_note_relay_reason()
	phase = Phase.LOST
	local_slot = Protocol.NO_SLOT
	local_character = ""
	link_lost.emit()
	_drop_socket()


func _join_failure_reason() -> int:
	_note_relay_reason()
	if _peer is RelayPeer:
		return (_peer as RelayPeer).refuse_reason()
	return Protocol.Refuse.FULL


func _note_relay_reason() -> void:
	if _peer is RelayPeer:
		relay_reason = (_peer as RelayPeer).last_reason


func _bind(peer: MultiplayerPeer) -> void:
	_peer = peer
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(id: int) -> void:
	if _suppress or not is_host:
		return
	if not _remotes.has(id):
		_remotes.append(id)


func _on_peer_disconnected(id: int) -> void:
	if _suppress:
		return
	_drop_ids.append(id)


func _apply_drops() -> void:
	for id in _drop_ids:
		if is_host:
			_remotes.erase(id)
			if _remove_peer(id):
				_emit_roster()
				member_left.emit(id)
		else:
			_on_link_lost()
	_drop_ids.clear()


func _on_link_lost() -> void:
	if phase == Phase.IN:
		_note_relay_reason()
		phase = Phase.LOST
		local_slot = Protocol.NO_SLOT
		local_character = ""
		link_lost.emit()
		_drop_socket()
		return
	if phase == Phase.JOINING and refuse_reason == Protocol.Refuse.NONE and local_slot == Protocol.NO_SLOT:
		_set_refused(_join_failure_reason())


func _drain() -> void:
	if _peer == null:
		return
	while _peer != null and _peer.get_available_packet_count() > 0:
		var from_id := _peer.get_packet_peer()
		var raw := _peer.get_packet()
		if Protocol.is_binary_gameplay(raw):
			if _gameplay != null and _gameplay.has_method("ingest_packet"):
				_gameplay.ingest_packet(from_id, raw)
			continue
		var msg := Codec.decode_v2(raw) if protocol_version == Protocol.VERSION_ONLINE else Protocol.decode(raw)
		if is_host:
			_on_host_packet(from_id, msg)
		else:
			_on_client_packet(msg)


func _on_host_packet(from_id: int, msg: Dictionary) -> void:
	if not bool(msg["ok"]):
		_refuse(from_id, Protocol.Refuse.BAD_PACKET)
		return
	if not bool(msg["compatible"]):
		_refuse(from_id, Protocol.Refuse.VERSION)
		return
	if protocol_version == Protocol.VERSION_ONLINE:
		_on_host_v2(from_id, msg)
		return
	match int(msg["kind"]):
		Protocol.Kind.HELLO:
			_on_hello(from_id, msg["body"])
		Protocol.Kind.LEAVE:
			if _remove_peer(from_id):
				_emit_roster()
				member_left.emit(from_id)
			_queue_kick(from_id)


func _on_hello(from_id: int, body: Dictionary) -> void:
	if from_id == Protocol.HOST_PEER_ID or _peer_slotted(from_id):
		return
	if slots.size() >= Protocol.MAX_PLAYERS:
		_refuse(from_id, Protocol.Refuse.FULL)
		return
	var taken: Array[String] = []
	var used: Array[int] = []
	for row in slots:
		taken.append(str(row["character_id"]))
		used.append(int(row["slot"]))
	var character := Protocol.assign_character(taken, str(body.get("character_id", "")))
	var slot := Protocol.free_slot(used)
	if character == "" or slot == Protocol.NO_SLOT:
		_refuse(from_id, Protocol.Refuse.FULL)
		return
	var display := Protocol.clean_name(str(body.get("display_name", "")))
	_add_slot(from_id, slot, character, display)
	_send_to(from_id, Protocol.Kind.WELCOME, {"slot": slot, "character_id": character})
	_emit_roster()


func _on_host_v2(from_id: int, msg: Dictionary) -> void:
	match int(msg["kind"]):
		Protocol.Kind.HELLO:
			_on_hello_v2(from_id, msg["body"])
		Protocol.Kind.LEAVE:
			if _remove_peer(from_id):
				_emit_roster()
				member_left.emit(from_id)
			_queue_kick(from_id)
		Protocol.Kind.EMOTE:
			_on_emote_packet(from_id, msg["body"])


func _on_hello_v2(from_id: int, body: Dictionary) -> void:
	if from_id == Protocol.HOST_PEER_ID or _peer_slotted(from_id):
		return
	if slots.size() >= Protocol.MAX_PLAYERS:
		_refuse(from_id, Protocol.Refuse.FULL)
		return
	var norm := Codec.read_hello_v2(body)
	if not bool(norm.get("ok", false)):
		_refuse(from_id, Protocol.Refuse.BAD_PACKET)
		return
	var uid := str(norm.get("uid", ""))
	var used: Array[int] = []
	for row in slots:
		if str(row.get("uid", "")) == uid:
			_refuse(from_id, Protocol.Refuse.BAD_PACKET)
			return
		used.append(int(row.get("slot", Protocol.NO_SLOT)))
	var slot := Protocol.free_slot(used)
	if slot == Protocol.NO_SLOT:
		_refuse(from_id, Protocol.Refuse.FULL)
		return
	_add_online_slot(from_id, slot, norm, Protocol.CTRL_REMOTE)
	_send_to(from_id, Protocol.Kind.WELCOME, {"slot": slot, "uid": uid}, Protocol.VERSION_ONLINE)
	_emit_roster()


func _on_emote_packet(from_id: int, body: Dictionary) -> void:
	var parsed := Codec.read_emote(body)
	if not bool(parsed.get("ok", false)):
		return
	_accept_emote(_seat_of_peer(from_id), int(parsed.get("seat", Protocol.NO_SLOT)), int(parsed.get("emote_id", -1)))


## seat moet de stoel van de afzender zijn, id uit de tabel, en de cooldown voorbij.
func _accept_emote(sender_seat: int, claimed_seat: int, emote_id: int) -> void:
	if sender_seat == Protocol.NO_SLOT or sender_seat != claimed_seat:
		return
	if not Codec.read_emote(Codec.emote_body(claimed_seat, emote_id)).get("ok", false):
		return
	if _emote_gate == null or not _emote_gate.allow(sender_seat, _emote_now()):
		return
	_broadcast(Protocol.Kind.EMOTE, Codec.emote_body(sender_seat, emote_id))
	emote_received.emit(sender_seat, emote_id)


func _emote_now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _seat_of_peer(peer_id: int) -> int:
	for row in slots:
		if int(row.get("peer_id", 0)) == peer_id:
			return int(row.get("slot", Protocol.NO_SLOT))
	return Protocol.NO_SLOT


func _on_client_v2(msg: Dictionary) -> void:
	if not bool(msg.get("ok", false)):
		_set_refused(Protocol.Refuse.BAD_PACKET)
		return
	var kind := int(msg.get("kind", 0))
	var body: Dictionary = msg.get("body", {})
	if not bool(msg.get("compatible", false)):
		if kind == Protocol.Kind.REFUSE:
			_set_refused(int(body.get("reason", Protocol.Refuse.VERSION)))
		else:
			_set_refused(Protocol.Refuse.VERSION)
		return
	match kind:
		Protocol.Kind.REFUSE:
			_set_refused(int(body.get("reason", Protocol.Refuse.BAD_PACKET)))
		Protocol.Kind.WELCOME:
			_take_welcome_v2(body)
		Protocol.Kind.ROSTER:
			_apply_roster_v2(body)
		Protocol.Kind.EMOTE:
			_emit_emote_local(body)
		Protocol.Kind.SESSION_END:
			_on_session_end(body)
		Protocol.Kind.START_GAME:
			if phase == Phase.IN:
				start_game_received.emit()


func _take_welcome_v2(body: Dictionary) -> void:
	var slot := int(body.get("slot", Protocol.NO_SLOT))
	var uid := str(body.get("uid", ""))
	if slot < 0 or slot >= Protocol.MAX_PLAYERS or uid != str(_online_profile.get("uid", "")):
		_set_refused(Protocol.Refuse.BAD_PACKET)
		return
	local_slot = slot
	local_character = AvatarBlob.base_hero(str(_online_profile.get("class_id", "")))
	if local_character == "":
		_set_refused(Protocol.Refuse.BAD_PACKET)
		return
	phase = Phase.IN
	refuse_reason = Protocol.Refuse.NONE
	_refresh_view_controllers()
	assigned.emit(local_slot, local_character)


func _apply_roster_v2(body: Dictionary) -> void:
	var parsed := Codec.read_roster_v2(body)
	if not bool(parsed.get("ok", false)):
		return
	var next: Array[Dictionary] = []
	for item in parsed.get("seats", []):
		if not (item is Dictionary):
			return
		var seat_row: Dictionary = item
		var seat := int(seat_row.get("seat", Protocol.NO_SLOT))
		var class_id := str(seat_row.get("class_id", ""))
		var wire := str(seat_row.get("controller", ""))
		var display := str(seat_row.get("name", ""))
		var look: PackedByteArray = seat_row.get("look", PackedByteArray())
		next.append({
			"peer_id": 0,
			"slot": seat,
			"seat": seat,
			"character_id": AvatarBlob.base_hero(class_id),
			"display_name": display,
			"uid": str(seat_row.get("uid", "")),
			"name": display,
			"class": class_id,
			"wire_controller": wire,
			"controller": Codec.view_controller(wire, seat, local_slot),
			"look": look,
		})
	slots = next
	roster_changed.emit()


func _refresh_view_controllers() -> void:
	if local_slot == Protocol.NO_SLOT:
		return
	for row in slots:
		var wire := str(row.get("wire_controller", ""))
		if wire == "":
			continue
		row["controller"] = Codec.view_controller(wire, int(row.get("seat", Protocol.NO_SLOT)), local_slot)


func _emit_emote_local(body: Dictionary) -> void:
	if phase != Phase.IN:
		return
	var parsed := Codec.read_emote(body)
	if not bool(parsed.get("ok", false)):
		return
	emote_received.emit(int(parsed.get("seat", 0)), int(parsed.get("emote_id", 0)))


func _add_online_slot(peer_id: int, seat: int, norm: Dictionary, controller: String) -> void:
	var class_id := str(norm.get("class_id", ""))
	var display := str(norm.get("name", ""))
	var look: PackedByteArray = norm.get("look", PackedByteArray())
	slots.append({
		"peer_id": peer_id,
		"slot": seat,
		"seat": seat,
		"character_id": AvatarBlob.base_hero(class_id),
		"display_name": display,
		"uid": str(norm.get("uid", "")),
		"name": display,
		"class": class_id,
		"controller": controller,
		"wire_controller": controller,
		"look": look,
	})
	roster_changed.emit()


func _emit_roster() -> void:
	if protocol_version == Protocol.VERSION_ONLINE:
		_broadcast(Protocol.Kind.ROSTER, Codec.roster_body_from_slots(slots))
	else:
		_broadcast(Protocol.Kind.ROSTER, {"roster": _roster_payload()})


func _on_client_packet(msg: Dictionary) -> void:
	if protocol_version == Protocol.VERSION_ONLINE:
		_on_client_v2(msg)
		return
	if not bool(msg["ok"]) or not bool(msg["compatible"]):
		_set_refused(Protocol.Refuse.BAD_PACKET)
		return
	match int(msg["kind"]):
		Protocol.Kind.REFUSE:
			_set_refused(int((msg["body"] as Dictionary).get("reason", Protocol.Refuse.BAD_PACKET)))
		Protocol.Kind.WELCOME:
			_take_welcome(msg["body"])
		Protocol.Kind.ROSTER:
			_apply_roster(msg["body"])
		Protocol.Kind.SESSION_END:
			_on_session_end(msg["body"])
		Protocol.Kind.START_GAME:
			if phase == Phase.IN:
				start_game_received.emit()


func _take_welcome(body: Dictionary) -> void:
	local_slot = int(body.get("slot", Protocol.NO_SLOT))
	local_character = str(body.get("character_id", ""))
	if local_slot == Protocol.NO_SLOT or local_character == "":
		_set_refused(Protocol.Refuse.BAD_PACKET)
		return
	phase = Phase.IN
	refuse_reason = Protocol.Refuse.NONE
	assigned.emit(local_slot, local_character)


func _on_session_end(body: Dictionary) -> void:
	if phase != Phase.IN and phase != Phase.JOINING:
		return
	var reason := str((body as Dictionary).get("reason", "ended"))
	phase = Phase.LOST
	local_slot = Protocol.NO_SLOT
	local_character = ""
	session_ended.emit(reason)
	_drop_socket()


func _apply_roster(body: Dictionary) -> void:
	var raw_v: Variant = body.get("roster", [])
	if not (raw_v is Array):
		return
	var next: Array[Dictionary] = []
	for item in raw_v:
		if item is Dictionary:
			next.append(_row_from_net(item))
	slots = next
	roster_changed.emit()


func _refuse(peer_id: int, reason: int) -> void:
	# Versie-weigering gaat als v1 de deur uit, zodat een oude build de reden leest.
	var ver := Protocol.VERSION if reason == Protocol.Refuse.VERSION else protocol_version
	_send_to(peer_id, Protocol.Kind.REFUSE, {"reason": reason}, ver)
	_queue_kick(peer_id)


func _queue_kick(peer_id: int) -> void:
	if not _kick_queued.has(peer_id):
		_kick_queued.append(peer_id)


func _flush_kicks() -> void:
	if _peer == null:
		_kick_queued.clear()
		return
	for id in _kick_queued:
		if _remotes.has(id):
			_peer.disconnect_peer(id)
	_kick_queued.clear()


func _set_refused(reason: int) -> void:
	if phase == Phase.IN:
		return
	refuse_reason = reason
	phase = Phase.REFUSED
	local_slot = Protocol.NO_SLOT
	refused.emit(reason)
	_drop_socket()


## Peer loslaten zonder de stoel of de weiger-reden te wissen. Niet nog eens pollen:
## een dode ENet-peer geeft anders een fout in poll().
func _drop_socket() -> void:
	if _peer == null:
		return
	_suppress = true
	var peer := _peer
	_peer = null
	peer.close()
	_suppress = false


func _add_slot(peer_id: int, slot: int, character_id: String, display_name: String) -> void:
	slots.append({
		"peer_id": peer_id,
		"slot": slot,
		"character_id": character_id,
		"display_name": display_name,
	})
	roster_changed.emit()


func _remove_peer(peer_id: int) -> bool:
	var next: Array[Dictionary] = []
	var removed := false
	for row in slots:
		if int(row["peer_id"]) == peer_id:
			removed = true
			continue
		next.append(row)
	if removed:
		slots = next
		roster_changed.emit()
	return removed


func _peer_slotted(peer_id: int) -> bool:
	for row in slots:
		if int(row["peer_id"]) == peer_id:
			return true
	return false


func _roster_payload() -> Array:
	var out: Array = []
	for row in slots:
		out.append(_row_from_net(row))
	return out


func _row_from_net(raw: Dictionary) -> Dictionary:
	return {
		"peer_id": int(raw.get("peer_id", 0)),
		"slot": int(raw.get("slot", Protocol.NO_SLOT)),
		"character_id": str(raw.get("character_id", "")),
		"display_name": str(raw.get("display_name", "")),
	}


func _unicast_remotes(kind: int, body: Dictionary) -> void:
	for row in slots:
		var peer_id := int(row["peer_id"])
		if peer_id == Protocol.HOST_PEER_ID:
			continue
		_send_to(peer_id, kind, body, protocol_version)


func _broadcast(kind: int, body: Dictionary) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_peer.put_packet(Protocol.encode(kind, body, protocol_version))
	_peer.poll()


func _send_to(peer_id: int, kind: int, body: Dictionary, version: int = Protocol.VERSION) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(peer_id)
	_peer.put_packet(Protocol.encode(kind, body, version))
	_peer.poll()
