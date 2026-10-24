class_name RelayPeer
extends MultiplayerPeerExtension
## MultiplayerPeer over een WebSocket naar de SAPIENTIA-relay (relay/). Gedraagt zich als de
## ENet-peer van de LAN-lobby: host = peer 1, gasten krijgen een peer-id van de relay,
## set_target_peer/put_packet/get_packet/peer_connected/peer_disconnected werken hetzelfde.
## Daardoor draaien LanLobby en ActionCoopSession ongewijzigd over LAN én relay.
## Protocol: relay/README.md. Tekstframes = besturing (JSON), binaire frames = data
## ([doel of afzender u16 BE][payload]).

const PROTOCOL_VERSION := 1
## Frame-limiet van de relay (MAX_MESSAGE_BYTES) min de kop van 2 bytes.
const MAX_PAYLOAD_BYTES := 2046
const HEADER_BYTES := 2
const HOST_ID := 1
const TARGET_ALL := 0
## Koude start van een gratis host (Render slaapt na 15 min) kan ~1 min duren; de lobby wacht zo lang.
const CONNECT_TIMEOUT_SEC := 60.0

enum Role { NONE, HOST, GUEST }

## Host: de relay heeft een kamer geopend. De code is voor de andere spelers.
signal room_ready(code: String)
## De relay of de verbinding gaf een fout (reden = relay-reden of "unreachable"/"timeout").
signal failed(reason: String)

var room_code := ""
var last_reason := ""

var _ws := WebSocketPeer.new()
var _role: Role = Role.NONE
var _url := ""
var _join_code := ""
var _status: ConnectionStatus = CONNECTION_DISCONNECTED
var _unique_id := 0
var _target := TARGET_ALL
var _transfer_mode: TransferMode = TRANSFER_MODE_RELIABLE
var _transfer_channel := 0
var _refuse_new := false
var _incoming: Array[Dictionary] = []
var _current_from := 0
var _connected_ids: Array[int] = []
var _pending_drops: Array[int] = []
var _dead_pending := false
var _ended := false
var _hello_sent := false
var _opened := false
var _wait := 0.0
var _last_poll_msec := 0


func create_host(url: String) -> Error:
	return _start(Role.HOST, url, "")


func create_client(url: String, code: String) -> Error:
	return _start(Role.GUEST, url, code)


## NetProtocol.Refuse voor een mislukte join (voor de lobby-melding).
func refuse_reason() -> int:
	const Protocol := preload("res://scripts/net/net_protocol.gd")
	match last_reason:
		"no_room":
			return Protocol.Refuse.ROOM_NOT_FOUND
		"room_full":
			return Protocol.Refuse.FULL
		"bad_version":
			return Protocol.Refuse.VERSION
		"bad_message":
			return Protocol.Refuse.BAD_PACKET
		_:
			return Protocol.Refuse.TIMEOUT


func connected_peer_ids() -> Array[int]:
	return _connected_ids.duplicate()


func _start(role: Role, url: String, code: String) -> Error:
	if _role != Role.NONE:
		return ERR_ALREADY_IN_USE
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		return ERR_INVALID_PARAMETER
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK:
		return err
	_role = role
	_url = url
	_join_code = code
	_status = CONNECTION_CONNECTING
	_wait = 0.0
	_last_poll_msec = Time.get_ticks_msec()
	room_code = ""
	last_reason = ""
	return OK


func _poll() -> void:
	if _role == Role.NONE:
		return
	_flush_drops()
	if _ws == null:
		return
	var now := Time.get_ticks_msec()
	var dt := minf(float(now - _last_poll_msec) / 1000.0, 0.5)
	_last_poll_msec = now
	_ws.poll()
	if _ended:
		return
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			_wait += dt
			if _wait >= CONNECT_TIMEOUT_SEC:
				_fail("timeout")
		WebSocketPeer.STATE_OPEN:
			_opened = true
			if not _hello_sent:
				_send_hello()
			_read_frames()
			if _status == CONNECTION_CONNECTING:
				_wait += dt
				if _wait >= CONNECT_TIMEOUT_SEC:
					_fail("timeout")
		WebSocketPeer.STATE_CLOSING:
			_read_frames()
		WebSocketPeer.STATE_CLOSED:
			_read_frames()
			_on_ws_closed()


func _send_hello() -> void:
	_hello_sent = true
	var msg := {"t": "create", "v": PROTOCOL_VERSION}
	if _role == Role.GUEST:
		msg = {"t": "join", "v": PROTOCOL_VERSION, "code": _join_code}
	_ws.send_text(JSON.stringify(msg))


func _read_frames() -> void:
	while _ws != null and _ws.get_available_packet_count() > 0:
		var pkt := _ws.get_packet()
		if _ws.was_string_packet():
			_on_control(pkt.get_string_from_utf8())
		elif pkt.size() > HEADER_BYTES:
			var from := (int(pkt[0]) << 8) | int(pkt[1])
			_incoming.append({"from": from, "data": pkt.slice(HEADER_BYTES)})


func _on_control(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	match str(msg.get("t", "")):
		"created":
			room_code = str(msg.get("code", ""))
			_unique_id = int(msg.get("peer", HOST_ID))
			_status = CONNECTION_CONNECTED
			room_ready.emit(room_code)
		"joined":
			_unique_id = int(msg.get("peer", 0))
			_status = CONNECTION_CONNECTED
			_add_connected(HOST_ID)
		"peer_joined":
			if _role == Role.HOST:
				_add_connected(int(msg.get("peer", 0)))
		"peer_left":
			if _role == Role.HOST:
				_queue_drop(int(msg.get("peer", 0)))
		"closed":
			last_reason = str(msg.get("reason", "closed"))
			_end_link()
		"error":
			_fail(str(msg.get("reason", "error")))


func _add_connected(id: int) -> void:
	if id <= 0 or _connected_ids.has(id):
		return
	_connected_ids.append(id)
	peer_connected.emit(id)


func _queue_drop(id: int) -> void:
	if _connected_ids.has(id) and not _pending_drops.has(id):
		_pending_drops.append(id)


## Verbinding is weg: wie nog gekoppeld was, krijgt peer_disconnected, daarna DISCONNECTED.
func _end_link() -> void:
	if _ended:
		return
	_ended = true
	for id in _connected_ids:
		_queue_drop(id)
	_dead_pending = true
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close(1000)


func _fail(reason: String) -> void:
	if _ended:
		return
	if last_reason == "":
		last_reason = reason
	failed.emit(last_reason)
	_end_link()


func _on_ws_closed() -> void:
	if _ended:
		return
	if not _opened and last_reason == "":
		last_reason = "unreachable"
	elif last_reason == "":
		last_reason = "link_lost"
	failed.emit(last_reason)
	_end_link()


## Disconnects pas melden als alle ontvangen pakketten zijn opgehaald: een REFUSE of
## SESSION_END vlak voor het sluiten moet de lobby nog kunnen lezen (zoals bij ENet).
func _flush_drops() -> void:
	if not _incoming.is_empty():
		return
	var ids := _pending_drops.duplicate()
	_pending_drops.clear()
	for id in ids:
		if _connected_ids.has(id):
			_connected_ids.erase(id)
			peer_disconnected.emit(id)
	if _dead_pending and _pending_drops.is_empty():
		_dead_pending = false
		_status = CONNECTION_DISCONNECTED


func _close() -> void:
	if _ws != null and _role != Role.NONE:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws.close(1000)
			_ws.poll()
	_ws = null
	_role = Role.NONE
	_status = CONNECTION_DISCONNECTED
	_unique_id = 0
	_incoming.clear()
	_connected_ids.clear()
	_pending_drops.clear()
	_dead_pending = false
	_ended = false
	_hello_sent = false
	_opened = false


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _role != Role.HOST or _ws == null:
		return
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify({"t": "kick", "peer": peer}))
	_ws.poll()


func _put_packet_script(p_buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED or _ws == null:
		return ERR_UNCONFIGURED
	if p_buffer.size() > MAX_PAYLOAD_BYTES or p_buffer.is_empty():
		return ERR_INVALID_PARAMETER
	if _role == Role.GUEST:
		return _send_frame(HOST_ID, p_buffer)
	if _target >= TARGET_ALL:
		return _send_frame(_target, p_buffer)
	var err := OK
	for id in _connected_ids:
		if id != -_target:
			err = _send_frame(id, p_buffer)
	return err


func _send_frame(target: int, payload: PackedByteArray) -> Error:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_CONNECTION_ERROR
	var frame := PackedByteArray()
	frame.append((target >> 8) & 0xFF)
	frame.append(target & 0xFF)
	frame.append_array(payload)
	return _ws.send(frame, WebSocketPeer.WRITE_MODE_BINARY)


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	var item: Dictionary = _incoming.pop_front()
	_current_from = int(item["from"])
	return item["data"]


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_max_packet_size() -> int:
	return MAX_PAYLOAD_BYTES


func _set_target_peer(p_peer: int) -> void:
	_target = p_peer


## Zoals ENet: de afzender van het eerstvolgende pakket (de lobby vraagt dit vóór get_packet).
func _get_packet_peer() -> int:
	if not _incoming.is_empty():
		return int((_incoming[0] as Dictionary)["from"])
	return _current_from


func _get_packet_mode() -> TransferMode:
	return TRANSFER_MODE_RELIABLE


func _get_packet_channel() -> int:
	return 0


func _set_transfer_channel(p_channel: int) -> void:
	_transfer_channel = p_channel


func _get_transfer_channel() -> int:
	return _transfer_channel


func _set_transfer_mode(p_mode: TransferMode) -> void:
	_transfer_mode = p_mode


func _get_transfer_mode() -> TransferMode:
	return _transfer_mode


func _set_refuse_new_connections(p_enable: bool) -> void:
	_refuse_new = p_enable


func _is_refusing_new_connections() -> bool:
	return _refuse_new


func _is_server() -> bool:
	return _role == Role.HOST


func _get_unique_id() -> int:
	return _unique_id


func _get_connection_status() -> ConnectionStatus:
	return _status


func _is_server_relay_supported() -> bool:
	return false
