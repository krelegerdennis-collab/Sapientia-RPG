class_name LanDiscovery
extends Node
## UDP-baken voor de fase-B-lobby. Niet aan een scène gekoppeld.
## De host bindt ANNOUNCE_BIND_PORT en stuurt naar DISCOVERY_PORT (broadcast).
## Broadcast naar 255.255.255.255 komt op dezelfde machine vaak niet terug;
## push_to() stuurt naar een bekend adres (de test gebruikt de loopback).

const Protocol := preload("res://scripts/net/net_protocol.gd")

signal host_found(info: Dictionary)

var last_info: Dictionary = {}
## Laatste mislukte bind (voor de melding en de logcat). OK = geen fout.
var last_error: Error = OK
var last_error_port := 0
var _udp: PacketPeerUDP
var _announcing := false
var _listening := false
var _session_name := ""
var _player_count := 1
var _acc := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_announce(session_name: String, players: int) -> Error:
	if _udp != null:
		return ERR_ALREADY_IN_USE
	_session_name = Protocol.clean_name(session_name)
	_player_count = clampi(players, 0, Protocol.MAX_PLAYERS)
	var udp := PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	var err := udp.bind(Protocol.ANNOUNCE_BIND_PORT)
	if err != OK:
		_note_failure("announce", err, Protocol.ANNOUNCE_BIND_PORT)
		return err
	_udp = udp
	_announcing = true
	return OK


func start_listen() -> Error:
	if _udp != null:
		return ERR_ALREADY_IN_USE
	var udp := PacketPeerUDP.new()
	var err := udp.bind(Protocol.DISCOVERY_PORT)
	if err != OK:
		_note_failure("listen", err, Protocol.DISCOVERY_PORT)
		return err
	_udp = udp
	_listening = true
	return OK


func _note_failure(what: String, err: Error, port: int) -> void:
	last_error = err
	last_error_port = port
	push_warning("LanDiscovery: %s failed: %s, UDP port %d" % [what, Protocol.error_name(err), port])


func stop() -> void:
	_announcing = false
	_listening = false
	if _udp != null:
		_udp.close()
		_udp = null


## Eén baken naar addr:port. Productie gebruikt _process (broadcast).
func push_to(addr: String, port: int) -> Error:
	if _udp == null or not _announcing:
		return ERR_UNCONFIGURED
	return _send(addr, port)


func set_player_count(players: int) -> void:
	_player_count = clampi(players, 0, Protocol.MAX_PLAYERS)


func _process(delta: float) -> void:
	if _udp == null:
		return
	if _announcing:
		_acc += delta
		if _acc >= Protocol.ANNOUNCE_INTERVAL_SEC:
			_acc = 0.0
			_send(Protocol.BROADCAST_ADDR, Protocol.DISCOVERY_PORT)
	if _listening:
		_drain()


func _send(addr: String, port: int) -> Error:
	_udp.set_dest_address(addr, port)
	return _udp.put_packet(Protocol.encode_announce(_session_name, _player_count))


func _drain() -> void:
	while _udp.get_available_packet_count() > 0:
		var raw := _udp.get_packet()
		var info := Protocol.parse_announce(raw)
		if not bool(info["ok"]) or not bool(info["compatible"]):
			continue
		info["ip"] = _udp.get_packet_ip()
		last_info = info
		host_found.emit(info)
