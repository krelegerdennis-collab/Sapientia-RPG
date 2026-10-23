extends Node
## Headless Action-co-op sync (sim + ENet roundtrip).
## Start: godot --path . -- --netsynctest

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Sim := preload("res://scripts/net/action_sandbox_sim.gd")
const Session := preload("res://scripts/net/action_coop_session.gd")
const SomRing := preload("res://scripts/som/som_ring.gd")

const RUN_SEC := 2.5
const STEP := 2.0

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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


func _run() -> void:
	_codec_tests()
	_sim_input_tests()
	_lock_per_player_tests()
	await _enet_roundtrip_tests()
	await _ring_no_pause_tests()
	await _despawn_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _codec_tests() -> void:
	var wire := Codec.pack_wire_input(1, Vector2(0.5, -1.0), Codec.BTN_ATTACK, 2)
	check("wire input lengte", wire.size() == 1 + Codec.INPUT_SIZE)
	var inp := Codec.unpack_wire_input(wire)
	check("wire input slot", int(inp.get("slot", -1)) == 1)
	var snap := Codec.pack_snapshot(42, [{"slot": 0, "x": 10, "y": 20, "face": 1, "frame": 0, "hp": 90, "mp": 5, "flags": 0}], [])
	check("snapshot tick", int(Codec.unpack_snapshot(snap).get("tick", -1)) == 42)
	check("snapshot payload <= budget", snap.size() <= Protocol.snapshot_payload_bytes() + 1)


func _sim_input_tests() -> void:
	var sim := Sim.new()
	var roster := [
		{"slot": 0, "character_id": Protocol.HOST_CHARACTER, "peer_id": 1},
		{"slot": 1, "character_id": "lotte", "peer_id": 2},
	]
	sim.reset(roster, 99)
	var x0 := int(sim.players[0]["x"])
	for i in 30:
		sim.host_tick([{
			"slot": 0,
			"stick": Vector2(1, 0),
			"buttons": 0,
			"lock_idx": -1,
		}])
	check("host input verplaatst", int(sim.players[0]["x"]) > x0)
	check("enemy jaagt host stoel", sim.enemies[0]["target_slot"] == Protocol.HOST_SLOT)


func _lock_per_player_tests() -> void:
	var sim := Sim.new()
	sim.reset([
		{"slot": 0, "character_id": Protocol.HOST_CHARACTER, "peer_id": 1},
		{"slot": 1, "character_id": "lotte", "peer_id": 2},
	], 7)
	for i in 40:
		sim.host_tick([
			{"slot": 0, "stick": Vector2.ZERO, "buttons": Codec.BTN_LOCK_TAP, "lock_idx": 0},
			{"slot": 1, "stick": Vector2.ZERO, "buttons": Codec.BTN_LOCK_TAP, "lock_idx": 0},
		])
	check("slot0 lock", int(sim.players[0]["lock_idx"]) == 0)
	check("slot1 eigen lock", int(sim.players[1]["lock_idx"]) == 0)


func _roster() -> Array:
	return [
		{"slot": 0, "character_id": Protocol.HOST_CHARACTER, "peer_id": 1, "display_name": "Dax"},
		{"slot": 1, "character_id": "lotte", "peer_id": 2, "display_name": "Seren"},
	]


func _make_peers() -> Array:
	var host_peer := ENetMultiplayerPeer.new()
	host_peer.create_server(Protocol.SYNC_TEST_PORT, 1)
	var guest_peer := ENetMultiplayerPeer.new()
	guest_peer.create_client(Protocol.LOOPBACK, Protocol.SYNC_TEST_PORT)
	return [host_peer, guest_peer]


func _enet_roundtrip_tests() -> void:
	var peers := _make_peers()
	var host_peer: ENetMultiplayerPeer = peers[0]
	var guest_peer: ENetMultiplayerPeer = peers[1]
	var connected := await wait_until(func() -> bool:
		host_peer.poll()
		guest_peer.poll()
		return guest_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	, STEP)
	check("ENet sync test verbonden", connected)
	var host_sess: Node = Session.start_session(get_tree(), host_peer, _roster(), Protocol.HOST_SLOT, false)
	var guest_sess: Node = Session.start_session(get_tree(), guest_peer, _roster(), 1, false)
	guest_sess.set_local_input(Vector2(1, 0), false, false, false)
	var moved := false
	var left := RUN_SEC
	while left > 0.0:
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		left -= float(Time.get_ticks_msec() - before) / 1000.0
		if int(guest_sess.sim.players[1]["x"]) > 80:
			moved = true
	check("gast input -> host state -> snapshot", moved)
	host_sess.shutdown()
	guest_sess.shutdown()
	host_peer.close()
	guest_peer.close()


func _ring_no_pause_tests() -> void:
	var arena := _RingArenaMock.new()
	var ring: Node = SomRing.new()
	ring.arena = arena
	add_child(ring)
	get_tree().paused = false
	ring.open()
	check("ring co-op pauzeert boom niet", not get_tree().paused)
	ring.is_open = false
	ring.root.visible = false
	ring.queue_free()
	arena.queue_free()


class _RingArenaMock:
	extends Node
	var coop_ring_no_pause := true

	func ring_entries() -> Array:
		return []

	func on_ring_closed(_choice: Dictionary) -> void:
		pass


func _despawn_tests() -> void:
	var peers := _make_peers()
	var host_peer: ENetMultiplayerPeer = peers[0]
	var guest_peer: ENetMultiplayerPeer = peers[1]
	var remote_id := 0
	host_peer.peer_connected.connect(func(id: int) -> void:
		remote_id = id
	)
	await wait_until(func() -> bool:
		host_peer.poll()
		guest_peer.poll()
		return guest_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and remote_id != 0
	, STEP)
	var host_sess: Node = Session.start_session(get_tree(), host_peer, _roster(), Protocol.HOST_SLOT, false)
	host_sess._peer_to_slot[remote_id] = 1
	host_sess.simulate_peer_drop(remote_id)
	var gone := not bool(host_sess.sim.players[1]["active"])
	check("disconnect despawn gast stoel", gone)
	host_sess.shutdown()
	guest_peer.close()
	host_peer.close()
