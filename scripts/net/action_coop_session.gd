class_name ActionCoopSession
extends Node
## Host-autoritaire sync in de Action-sandbox. SceneTree-multiplayer alleen hier.
## Ingang: start_session(tree, peer, roster, local_slot) — zie docs/fase_b/SYNC_API.md.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Sim := preload("res://scripts/net/action_sandbox_sim.gd")

signal slot_removed(slot: int)
signal snapshot_applied(tick: int)

var is_host := false
var local_slot := Protocol.NO_SLOT
var sim: Sim
var arena: Node

var _peer: MultiplayerPeer
var _acc := 0.0
var _input_send_acc := 0.0
var _inputs: Array = []
var _interp: Array[Dictionary] = []
var _display: Dictionary = {}
var _stick := Vector2.ZERO
var _buttons := 0
var _lock_idx := -1
var _peer_to_slot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## peer: bestaande ENetMultiplayerPeer (lobby of test). roster: lobby-slots (Dictionary per stoel).
## use_tree_mp: in de sandbox-scène true (SceneTree-multiplayer); headless tests false.
static func start_session(
		tree: SceneTree,
		peer: MultiplayerPeer,
		roster: Array,
		local_slot_in: int,
		use_tree_mp: bool = true,
) -> ActionCoopSession:
	var n := ActionCoopSession.new()
	n.name = "ActionCoopSession"
	tree.root.add_child(n)
	n._begin(peer, roster, local_slot_in, use_tree_mp)
	return n


func _begin(peer: MultiplayerPeer, roster: Array, local_slot_in: int, use_tree_mp: bool) -> void:
	_peer = peer
	local_slot = local_slot_in
	is_host = local_slot == Protocol.HOST_SLOT
	if use_tree_mp:
		var mp := get_tree().get_multiplayer()
		mp.multiplayer_peer = peer
		mp.peer_connected.connect(_on_peer_connected)
		mp.peer_disconnected.connect(_on_peer_disconnected)
	if peer is ENetMultiplayerPeer:
		(peer as ENetMultiplayerPeer).peer_disconnected.connect(_on_peer_disconnected)
	sim = Sim.new()
	sim.reset(roster, 4242)
	_build_peer_map(roster)


func attach_arena(p_arena: Node) -> void:
	arena = p_arena
	if arena and "coop_ring_no_pause" in arena:
		arena.coop_ring_no_pause = true


## Tests / lobby: stoel vrijmaken als ENet de peer laat vallen.
func simulate_peer_drop(peer_id: int) -> void:
	_on_peer_disconnected(peer_id)


func set_local_input(stick: Vector2, attack: bool, ring: bool, lock_tap: bool, lock_idx: int = -1) -> void:
	_stick = stick
	_buttons = 0
	if attack:
		_buttons |= Codec.BTN_ATTACK
	if ring:
		_buttons |= Codec.BTN_RING
	if lock_tap:
		_buttons |= Codec.BTN_LOCK_TAP
	_lock_idx = lock_idx


func shutdown() -> void:
	var mp := get_tree().get_multiplayer()
	if mp != null and mp.multiplayer_peer == _peer:
		mp.multiplayer_peer = null
	if _peer != null:
		_peer.close()
	_peer = null
	queue_free()


func _process(delta: float) -> void:
	if _peer != null:
		_peer.poll()
	_drain_packets()
	if is_host:
		_host_frame(delta)
	else:
		_guest_frame(delta)
	_push_arena()


func _host_frame(delta: float) -> void:
	_collect_local_input()
	_acc += delta
	var input_dt := 1.0 / float(Protocol.INPUT_HZ)
	_input_send_acc += delta
	while _input_send_acc >= input_dt:
		_input_send_acc -= input_dt
		_flush_guest_inputs()
	while _acc >= Sim.TICK_DT:
		_acc -= Sim.TICK_DT
		sim.host_tick(_inputs.duplicate())
		_inputs.clear()
		if sim.tick % (Protocol.SIM_HZ / Protocol.SNAPSHOT_HZ) == 0:
			_broadcast_snapshot(sim.encode_snapshot())


func _guest_frame(delta: float) -> void:
	_input_send_acc += delta
	var input_dt := 1.0 / float(Protocol.INPUT_HZ)
	while _input_send_acc >= input_dt:
		_input_send_acc -= input_dt
		_send_input_packet()
	_apply_interpolation(delta)


func _collect_local_input() -> void:
	if local_slot == Protocol.NO_SLOT:
		return
	_inputs.append({
		"slot": local_slot,
		"stick": _stick,
		"buttons": _buttons,
		"lock_idx": _lock_idx,
	})


func _flush_guest_inputs() -> void:
	# Host verwerkt lokale input al in _inputs; gasten sturen via packets.
	pass


func _send_input_packet() -> void:
	if _peer == null or local_slot == Protocol.NO_SLOT:
		return
	var raw := Codec.pack_wire_input(local_slot, _stick, _buttons, _lock_idx)
	_peer.set_target_peer(Protocol.HOST_PEER_ID)
	_peer.put_packet(raw)


func _broadcast_snapshot(raw: PackedByteArray) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_peer.put_packet(raw)


func _drain_packets() -> void:
	if _peer == null:
		return
	while _peer.get_available_packet_count() > 0:
		var raw := _peer.get_packet()
		if raw.is_empty():
			continue
		var kind := int(raw[0])
		if kind == Protocol.BinKind.INPUT and is_host:
			var body := Codec.unpack_wire_input(raw)
			if not body.is_empty():
				_inputs.append(body)
		elif kind == Protocol.BinKind.SNAPSHOT and not is_host:
			var snap := Codec.unpack_snapshot(raw)
			if not snap.is_empty():
				_push_interp(snap)


func _push_interp(snap: Dictionary) -> void:
	_interp.append(snap)
	while _interp.size() > 4:
		_interp.pop_front()
	sim.apply_snapshot(snap)
	snapshot_applied.emit(int(snap.get("tick", 0)))


func _apply_interpolation(_delta: float) -> void:
	if _interp.is_empty():
		return
	_display = _interp.back()


func _push_arena() -> void:
	if arena == null or not arena.has_method("apply_coop_snapshot"):
		return
	var snap := sim.snapshot_rows() if is_host else _display
	if snap.is_empty():
		return
	arena.apply_coop_snapshot(snap)


func _build_peer_map(roster: Array) -> void:
	_peer_to_slot.clear()
	for row in roster:
		_peer_to_slot[int(row.get("peer_id", 0))] = int(row.get("slot", Protocol.NO_SLOT))


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		shutdown()
		return
	var slot := int(_peer_to_slot.get(id, Protocol.NO_SLOT))
	if slot == Protocol.NO_SLOT:
		return
	sim.deactivate_slot(slot)
	_peer_to_slot.erase(id)
	slot_removed.emit(slot)
	_broadcast_snapshot(sim.encode_snapshot())
