extends Node
## Co-op Action-sandbox: lobby-peer + ActionCoopSession + echte SomArena-kamer.

const Session := preload("res://scripts/net/action_coop_session.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")

var session: ActionCoopSession

## Voor tests: host-sessie na boot.
func get_session() -> ActionCoopSession:
	return session
var _room: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_boot.call_deferred()


func _boot() -> void:
	var lobby: LanLobby = GameState.coop_lobby()
	if lobby == null or lobby.enet_peer() == null:
		push_error("Co-op sandbox zonder lobby-peer")
		GameState.go_to_title()
		return
	var roster: Array = []
	for row in lobby.slots:
		roster.append((row as Dictionary).duplicate())
	# Gameplay gebruikt binaire pakketten op de lobby-peer (geen SceneMultiplayer-RPC).
	session = Session.start_session(get_tree(), lobby.enet_peer(), roster, lobby.local_slot, false, lobby)
	session.arena_drive = true
	session.own_peer = false
	GameState.coop_bind_session(session)
	if not lobby.roster_changed.is_connected(_on_roster_changed):
		lobby.roster_changed.connect(_on_roster_changed)
	if not lobby.member_left.is_connected(_on_member_left):
		lobby.member_left.connect(_on_member_left)
	var packed := load(SomData.START_MAP) as PackedScene
	if packed == null:
		return
	_room = packed.instantiate()
	add_child(_room)
	for i in 180:
		if _room != null and "som" in _room and _room.som != null:
			break
		await get_tree().process_frame
	if _room == null or _room.som == null:
		return
	var som: Node = _room.som
	som.setup_coop(session, roster, lobby.local_slot)
	session.attach_arena(som)


func _on_roster_changed() -> void:
	var lobby: LanLobby = GameState.coop_lobby()
	if lobby == null:
		return
	if session != null:
		session.sync_roster(lobby.slots)
	if _room != null and _room.som != null:
		_room.som.coop_sync_roster(lobby.slots)


func _on_member_left(peer_id: int) -> void:
	if session != null:
		session.simulate_peer_drop(peer_id)


func _exit_tree() -> void:
	GameState.coop_shutdown_session()
