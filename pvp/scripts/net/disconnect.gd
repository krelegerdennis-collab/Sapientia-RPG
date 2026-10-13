extends RefCounted
class_name PvpDisconnect
## Verbindingsverlies terug naar het PvP-menu.
## Dezelfde hostsessie kan opnieuw, zolang de host nog leeft.
## TODO(design): reconnect via een relay is niet gekozen (GD-Sync / NodeTunnel / VPS).


const MSG_DROP := "The connection was lost. You are back in the menu."
const MSG_MATCH_GONE := "This battle is gone. The host has left."
const MSG_GUEST_LEFT := "Your friend left. The same code still works."
const MSG_OCCUPIED := "Someone is already playing with that code."


static func drop_message() -> String:
	return MSG_DROP


static func match_gone_message() -> String:
	return MSG_MATCH_GONE


static func guest_left_message() -> String:
	return MSG_GUEST_LEFT


static func occupied_message() -> String:
	return MSG_OCCUPIED
