class_name LanLobby
extends Node
## Host/join over ENet voor maximaal 4 spelers. Niet aan een scène gekoppeld.
## Zet bewust NIET de SceneTree-multiplayer: de rest van het spel blijft singleplayer
## tot een latere PR deze peer daar ophangt. Elke instantie pollt haar eigen peer.

const Protocol := preload("res://scripts/net/net_protocol.gd")

signal assigned(slot: int, character_id: String)
signal refused(reason: int)
signal roster_changed
signal member_left(peer_id: int)
signal link_lost
signal start_game_received
signal session_ended(reason: String)

enum Phase { IDLE, JOINING, IN, REFUSED, LOST }

var is_host := false
var phase: Phase = Phase.IDLE
var local_slot := Protocol.NO_SLOT
var local_character := ""
var refuse_reason := Protocol.Refuse.NONE
var slots: Array[Dictionary] = []

var _peer: ENetMultiplayerPeer
var _display_name := ""
var _want_character := ""
var _hello_version := Protocol.VERSION
var _hello_sent := false
var _join_wait := 0.0
var _suppress := false
var _remotes: Array[int] = []
var _kick_queued: Array[int] = []
var _drop_ids: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func host_session(display_name: String) -> Error:
	if phase != Phase.IDLE or _peer != null:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var err := peer.create_server(Protocol.ENET_PORT, Protocol.MAX_REMOTE + Protocol.ENET_REFUSE_SLACK)
	if err != OK:
		return err
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
		return err
	_bind(peer)
	is_host = false
	phase = Phase.JOINING
	_want_character = character_id
	_display_name = Protocol.clean_name(display_name)
	_hello_version = version
	_hello_sent = false
	_join_wait = 0.0
	return OK


## Maakt de peer los. Daarna mag host_session of join_session opnieuw.
func close() -> void:
	_suppress = true
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
	_suppress = false


func player_count() -> int:
	return slots.size()


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
	if phase != Phase.JOINING or _peer == null:
		return
	var status := _peer.get_connection_status()
	# ENet weigert boven MAX_REMOTE vóór HELLO: geen pakket, wel meteen DISCONNECTED.
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED and local_slot == Protocol.NO_SLOT and refuse_reason == Protocol.Refuse.NONE:
		_set_refused(Protocol.Refuse.FULL)
		return
	if status == MultiplayerPeer.CONNECTION_CONNECTED and not _hello_sent:
		_send_to(Protocol.HOST_PEER_ID, Protocol.Kind.HELLO, {
			"character_id": _want_character,
			"display_name": _display_name,
		}, _hello_version)
		_hello_sent = true
	_join_wait += minf(delta, Protocol.JOIN_TICK_CAP_SEC)
	if _join_wait >= Protocol.JOIN_TIMEOUT_SEC and local_slot == Protocol.NO_SLOT and refuse_reason == Protocol.Refuse.NONE:
		_set_refused(Protocol.Refuse.TIMEOUT)


func _bind(peer: ENetMultiplayerPeer) -> void:
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
				_broadcast(Protocol.Kind.ROSTER, {"roster": _roster_payload()})
				member_left.emit(id)
		else:
			_on_link_lost()
	_drop_ids.clear()


func _on_link_lost() -> void:
	if phase == Phase.IN:
		phase = Phase.LOST
		local_slot = Protocol.NO_SLOT
		local_character = ""
		link_lost.emit()
		_drop_socket()
		return
	if phase == Phase.JOINING and refuse_reason == Protocol.Refuse.NONE and local_slot == Protocol.NO_SLOT:
		_set_refused(Protocol.Refuse.FULL)


func _drain() -> void:
	if _peer == null:
		return
	while _peer != null and _peer.get_available_packet_count() > 0:
		var from_id := _peer.get_packet_peer()
		var raw := _peer.get_packet()
		var msg := Protocol.decode(raw)
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
	match int(msg["kind"]):
		Protocol.Kind.HELLO:
			_on_hello(from_id, msg["body"])
		Protocol.Kind.LEAVE:
			if _remove_peer(from_id):
				_broadcast(Protocol.Kind.ROSTER, {"roster": _roster_payload()})
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
	_broadcast(Protocol.Kind.ROSTER, {"roster": _roster_payload()})


func _on_client_packet(msg: Dictionary) -> void:
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
	_send_to(peer_id, Protocol.Kind.REFUSE, {"reason": reason})
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
		_send_to(peer_id, kind, body)


func _broadcast(kind: int, body: Dictionary) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_peer.put_packet(Protocol.encode(kind, body))
	_peer.poll()


func _send_to(peer_id: int, kind: int, body: Dictionary, version: int = Protocol.VERSION) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(peer_id)
	_peer.put_packet(Protocol.encode(kind, body, version))
	_peer.poll()
