class_name PlaytestGebieden
extends RefCounted
## WM1-gebieden voor de playtest-log (res://data/playtest_gebieden.json).
## Kaart-id (bestandsnaam zonder .tscn) -> gebied-id. Exacte kaartnaam gaat voor, anders de langste prefix.

const PAD := "res://data/playtest_gebieden.json"
const ONBEKEND := "overig"

static var _cache: Array = []
static var _geladen := false


static func gebieden() -> Array:
	if not _geladen:
		_geladen = true
		_cache = []
		if FileAccess.file_exists(PAD):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PAD))
			if d is Dictionary and d.get("gebieden") is Array:
				_cache = d["gebieden"]
	return _cache


static func gebied_van(kaart_id: String) -> String:
	var beste := ""
	var beste_len := -1
	for g in gebieden():
		if not (g is Dictionary):
			continue
		if (g.get("maps", []) as Array).has(kaart_id):
			return str(g.get("id", ONBEKEND))
		for p in g.get("prefix", []):
			var ps := str(p)
			if kaart_id.begins_with(ps) and ps.length() > beste_len:
				beste = str(g.get("id", ONBEKEND))
				beste_len = ps.length()
	return beste if beste != "" else ONBEKEND
