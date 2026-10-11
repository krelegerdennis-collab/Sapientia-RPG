extends RefCounted
class_name PvpDisconnect
## Verbindingsverlies: terug naar het PvP-menu.
## TODO(design): reconnect is nog niet beschikbaar.


const MSG_DROP := "De verbinding is verbroken. Je bent terug in het menu."
const MSG_RECONNECT := "Opnieuw verbinden is nog niet beschikbaar."


static func drop_message() -> String:
	return MSG_DROP


static func reconnect_message() -> String:
	return MSG_RECONNECT
