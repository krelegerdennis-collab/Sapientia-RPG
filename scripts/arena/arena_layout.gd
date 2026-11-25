extends RefCounted
## Leest docs/arena/layouts.json (hall 30x20, lobby 24x14). Het bestand zelf blijft van RPG ART.

const PATH := "res://docs/arena/layouts.json"

static var _data: Dictionary = {}


static func grid(kind: String) -> Array:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	var rows: Variant = _data.get(kind, [])
	return rows if rows is Array else []
