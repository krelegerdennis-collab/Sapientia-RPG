extends Node
## Action-sandbox co-op scène-root. Lobby-UI zit elders; roep start_from_lobby aan.

const Session := preload("res://scripts/net/action_coop_session.gd")

var session: Node


## peers: ongebruikt (peer hangt aan de lobby); roster + lobby_peer zijn leidend.
func start_session(lobby_peer: MultiplayerPeer, roster: Array, local_slot: int) -> Node:
	if session != null:
		session.shutdown()
	session = Session.start_session(get_tree(), lobby_peer, roster, local_slot, true)
	return session


func _exit_tree() -> void:
	if session != null:
		session.shutdown()
		session = null
