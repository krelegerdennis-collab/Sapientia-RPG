extends PvpTransport
class_name PvpLanTransport
## LAN via ENet (Godot 4.3). Geen internet-relay.
## TODO(design): relay is niet gekozen (GD-Sync / NodeTunnel / eigen VPS / TBD).
##
## Poorten (vast):
##   7777  ENet, host luistert, maximaal één vriend.
##   7778  UDP-baken. De vriend luistert hier en hoeft alleen de code in te typen.
##   7779  UDP-uitstuur van de host (broadcast naar 7778).
## Het baken is JSON: {"game":"sapientia-pvp","code":"...","port":7777}.
## Aanmaken van deze node bindt nog niets. host() en join() doen dat pas.
##
## Zelfde machine: broadcast naar 255.255.255.255 komt vaak niet terug op
## 127.0.0.1. De suite test daarom parse_beacon plus join_ip("127.0.0.1")
## met twee ENet-peers in één proces. Dat is geen tweede fysiek apparaat.
## Productie-join blijft via het baken. Poorten blijven 7777 en 7778.


const PORT := 7777
const BEACON_PORT := 7778
const BEACON_SEND_PORT := 7779
const JOIN_TIMEOUT := 8.0
const BEACON_EVERY := 0.5

var _peer: ENetMultiplayerPeer = null
var _udp: PacketPeerUDP = null
var _code: String = ""
var _hosting: bool = false
var _joining: bool = false
var _enet_up: bool = false
var _did_connect: bool = false
var _closed: bool = false
var _beacon_acc: float = 0.0
var _join_wait: float = 0.0


func host(code_text: String) -> void:
	_code = code_text
	_hosting = true
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(PORT, 1)
	if err != OK:
		_give_up("Het netwerk kon niet starten (poort %d)." % PORT)
		return
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	var bind_err := _udp.bind(BEACON_SEND_PORT)
	if bind_err != OK:
		_give_up("Het netwerk kon niet starten (baken).")
		return
	_udp.set_dest_address("255.255.255.255", BEACON_PORT)


func join(code_text: String) -> bool:
	_code = code_text
	_joining = true
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(BEACON_PORT)
	if err != OK:
		_give_up("Geen verbinding op dit netwerk. Blijf in het menu.")
		return false
	return true


## Direct ENet naar een IP, zonder het UDP-baken.
## Alleen bedoeld als het adres al bekend is (localhost-test). De code zelf
## wordt niet via het baken gecontroleerd; parse_beacon doet die controle.
func join_ip(code_text: String, ip: String) -> bool:
	if _closed:
		return false
	_code = code_text
	_joining = true
	_connect_enet(ip, PORT)
	return _peer != null and not _closed


## Puur: pakket plus verwachte code geeft de poort, of -1. Geen socket.
static func parse_beacon(packet: PackedByteArray, expected_code: String) -> int:
	var text := packet.get_string_from_utf8().strip_edges()
	if not text.begins_with("{"):
		return -1
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return -1
	var data: Dictionary = parsed
	if str(data.get("game", "")) != "sapientia-pvp":
		return -1
	if str(data.get("code", "")) != expected_code:
		return -1
	var port := int(data.get("port", -1))
	if port <= 0:
		return -1
	return port


func send(payload: Dictionary) -> void:
	if _peer == null or _closed or not _did_connect:
		return
	if _hosting:
		_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	else:
		_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	_peer.put_packet(var_to_bytes(payload))


func close() -> void:
	if _closed:
		return
	_closed = true
	_hosting = false
	_joining = false
	_enet_up = false
	if _peer != null:
		_peer.close()
		_peer = null
	if _udp != null:
		_udp.close()
		_udp = null


func _process(delta: float) -> void:
	if _closed:
		return
	if _peer != null:
		_peer.poll()
		_drain_packets()
	if _hosting and _udp != null:
		_beacon_acc += delta
		if _beacon_acc >= BEACON_EVERY:
			_beacon_acc = 0.0
			_send_beacon()
	if _joining and not _enet_up and _udp != null:
		_read_beacon()
		_join_wait += delta
		if _join_wait >= JOIN_TIMEOUT:
			_give_up("Geen vriend met die code op dit netwerk.")


func _send_beacon() -> void:
	var body := JSON.stringify({"game": "sapientia-pvp", "code": _code, "port": PORT})
	_udp.put_packet(body.to_utf8_buffer())


func _read_beacon() -> void:
	while _udp.get_available_packet_count() > 0:
		var pkt := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		var port := parse_beacon(pkt, _code)
		if port < 0:
			continue
		_connect_enet(ip, port)
		return


func _connect_enet(ip: String, port: int) -> void:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, port)
	if err != OK:
		_give_up("Verbinden op dit netwerk lukte niet.")
		return
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	_enet_up = true
	if _udp != null:
		_udp.close()
		_udp = null


func _drain_packets() -> void:
	if _peer == null:
		return
	while _peer.get_available_packet_count() > 0:
		var pkt := _peer.get_packet()
		var parsed = bytes_to_var(pkt)
		if parsed is Dictionary:
			message.emit(parsed)


func _on_peer_connected(_id: int) -> void:
	if _did_connect or _closed:
		return
	_did_connect = true
	connected.emit()


func _on_peer_disconnected(_id: int) -> void:
	if _closed:
		return
	if _hosting:
		# De vriend is weg. De server blijft op 7777 zodat dezelfde code werkt.
		_did_connect = false
		peer_left.emit()
		return
	var reason := PvpDisconnect.match_gone_message()
	close()
	disconnected.emit(reason)


func _give_up(reason: String) -> void:
	close()
	mark_failed(reason)
