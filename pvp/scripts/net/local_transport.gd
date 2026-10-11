extends PvpTransport
class_name PvpLocalTransport
## Hot-seat op één apparaat. Deelnemen lukt alleen als de code gelijk is
## aan de code van de levende lokale hostsessie in dit proces.


static var live_host = null

var code: String = ""
var is_host: bool = false
var peer: PvpLocalTransport = null
var _closed: bool = false


static func clear_hub() -> void:
	live_host = null


func host(code_text: String) -> void:
	code = code_text
	is_host = true
	live_host = self


func join(code_text: String) -> bool:
	var host_node: PvpLocalTransport = live_host as PvpLocalTransport
	if host_node == null or host_node.code != code_text or host_node.peer != null or host_node == self:
		mark_failed("Geen sessie met die code.")
		return false
	peer = host_node
	host_node.peer = self
	is_host = false
	code = code_text
	connected.emit()
	host_node.connected.emit()
	return true


func send(payload: Dictionary) -> void:
	if peer == null or _closed:
		return
	peer.message.emit(payload.duplicate(true))


func close() -> void:
	if _closed:
		return
	_closed = true
	if live_host == self:
		live_host = null
	var other := peer
	peer = null
	if other != null and other.peer == self:
		other.peer = null
	if other != null and not other._closed and not _silent_close:
		other.disconnected.emit(PvpDisconnect.drop_message())
