class_name EmoteTable
extends RefCounted
## Vaste emote-set (data/online/emotes.json). Ids 0..5, geen vrije tekst.
## De label gaat niet over het net; alleen het id.

const PATH := "res://data/online/emotes.json"
const ID_MIN := 0
const ID_MAX := 5
const LABEL_MAX := 24

static var _ready := false
static var _labels: Dictionary = {}


static func valid_id(emote_id: int) -> bool:
	_load()
	return _labels.has(emote_id)


static func label(emote_id: int) -> String:
	_load()
	return str(_labels.get(emote_id, ""))


static func ids() -> Array[int]:
	_load()
	var out: Array[int] = []
	for id in range(ID_MIN, ID_MAX + 1):
		if _labels.has(id):
			out.append(id)
	return out


static func _load() -> void:
	if _ready:
		return
	_ready = true
	_labels.clear()
	if not FileAccess.file_exists(PATH):
		push_error("EmoteTable: %s ontbreekt" % PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_error("EmoteTable: geen object")
		return
	var rows: Variant = (parsed as Dictionary).get("emotes", [])
	if not (rows is Array):
		return
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if not (row.get("id", null) is int or row.get("id", null) is float):
			continue
		var id := int(row.get("id", -1))
		var text := str(row.get("label", ""))
		if id < ID_MIN or id > ID_MAX or _labels.has(id) or not _label_ok(text):
			continue
		_labels[id] = text


static func _label_ok(text: String) -> bool:
	if text == "" or text.length() > LABEL_MAX:
		return false
	for i in text.length():
		if text.unicode_at(i) < 32:
			return false
	return true
