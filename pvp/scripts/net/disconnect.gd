extends RefCounted
class_name PvpDisconnect
## Verbindingsverlies terug naar het PvP-menu.
## Dezelfde hostsessie kan opnieuw, zolang de host nog leeft.
## TODO(design): reconnect via een relay is niet gekozen (GD-Sync / NodeTunnel / VPS).


const MSG_DROP := "De verbinding is verbroken. Je bent terug in het menu."
const MSG_MATCH_GONE := "Dit gevecht is weg. De host is er niet meer."
const MSG_GUEST_LEFT := "Je vriend is weg. Dezelfde code werkt nog."
const MSG_OCCUPIED := "Er speelt al iemand mee met die code."


static func drop_message() -> String:
	return MSG_DROP


static func match_gone_message() -> String:
	return MSG_MATCH_GONE


static func guest_left_message() -> String:
	return MSG_GUEST_LEFT


static func occupied_message() -> String:
	return MSG_OCCUPIED
