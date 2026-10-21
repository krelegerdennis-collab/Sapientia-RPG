extends RefCounted
## Veldmenu > Scenes > tab Music: de Suno-tracks van Dennis, met Engelse namen.
## Een track staat pas in de lijst (speelbaar) als de speler hem in het spel gehoord heeft
## (GameState.heard_music, in de save). "ids" = de manifest-tracks (assets/audio/audio_manifest.json)
## die deze muziek spelen; de eerste wordt afgespeeld.

const LOCKED_NAME := "???"
const TRACKS := [
	{"id": "main_menu", "ids": ["main_menu"], "name": "Sapientia Battle Theme", "where": "Title screen"},
	{"id": "dorp_wilgendal", "ids": ["dorp_wilgendal"], "name": "Morning in a Safe Village", "where": "Willowdale"},
	{"id": "donker_woud", "ids": ["donker_woud"], "name": "Sapientia Lament", "where": "The Dark Wood"},
	{"id": "levend_archief", "ids": ["levend_archief"], "name": "Nature's Pulse", "where": "The Living Archive"},
	{"id": "baas_archief2", "ids": ["baas_archief2"], "name": "Machine of War", "where": "Archive 2 boss"},
	{"id": "berggrot", "ids": ["berggrot"], "name": "Subterranean Wonder", "where": "The Mountain Cave"},
	{"id": "diepe_grot", "ids": ["diepe_grot", "ww_ambient"], "name": "Biomechanical Dungeon", "where": "The World Warper"},
]


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
