extends RefCounted
## Veldmenu > Scenes & Music > tab Music: de Suno-tracks van Dennis, met Engelse namen.
## Een track staat pas in de lijst (speelbaar) als de speler hem in het spel gehoord heeft
## (GameState.heard_music, in de save). "ids" = de manifest-tracks (assets/audio/audio_manifest.json)
## die deze muziek spelen; de eerste wordt afgespeeld.

## Namen en volgorde staan in res://data/music_tracks.json (Dennis, 21 okt 2026).
const JSON_PATH := "res://data/music_tracks.json"
const LOCKED_NAME := "???"
static var TRACKS: Array = _laad()


static func _laad() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	if d is Dictionary and d.get("tracks") is Array:
		return d["tracks"]
	push_error("music_tracks.json ontbreekt of is ongeldig")
	return []


## Track-id (uit TRACKS) bij een manifest-track, "" = geen Suno-track uit deze lijst.
static func track_for(manifest_id: String) -> String:
	for t in TRACKS:
		if (t["ids"] as Array).has(manifest_id):
			return str(t["id"])
	return ""


static func track(id: String) -> Dictionary:
	for t in TRACKS:
		if str(t["id"]) == id:
			return t
	return {}


static func ids() -> Array:
	return TRACKS.map(func(t): return str(t["id"]))
