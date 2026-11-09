extends RefCounted
## Eén tabel voor de WM1-filmpjes. De speler is scripts/worldmap_cutscene.gd
## (skip na 0,4 s, vangnet-timer, ontbrekend bestand is meteen klaar).
## Nieuwe filmpjes zijn 16:9 en nearest. De klasse-default van de speler blijft 9:16.
## Poort: tijdens --*test speelt play() niet, tenzij allow_in_tests (eigen static, niet die van de speler).
## De vlag gaat aan als het filmpje écht start (bestand bestaat), niet bij de poort.

const PORTRAIT := 9.0 / 16.0
const WIDE := 16.0 / 9.0
## Zelfde knop als WorldmapCutscene.allow_in_tests, apart zodat de tabel de speler niet preloadt.
## De nieuwe tests zetten allebei. De wereldkaart-poort leest de speler-var (should_play).
static var allow_in_tests := false

const VIDEOS := {
	"cs01": {
		"path": "res://assets/video/cs01_v3_echo.ogv",
		"flag": "cutscene_cs01_gezien",
		"aspect": WIDE,
		"max_seconds": 28.0,
		"nearest": true,
		"scene_id": "cs01",
		"title": "The Breaking Seal",
	},
	"cs02": {
		"path": "res://assets/video/cs02_after_kustos.ogv",
		"flag": "cutscene_cs02_gezien",
		"aspect": WIDE,
		"max_seconds": 34.0,
		"nearest": true,
		"scene_id": "cs02",
		"title": "The Dry Core",
	},
	"cs03": {
		"path": "res://assets/video/cs03_vesper_join.ogv",
		"flag": "cutscene_cs03_gezien",
		"aspect": WIDE,
		"max_seconds": 32.0,
		"nearest": true,
		"scene_id": "cs03",
		"title": "Vesper Freed",
	},
	"cs04": {
		"path": "res://assets/video/cs04_seren_mender.ogv",
		"flag": "cutscene_cs04_gezien",
		"aspect": WIDE,
		"max_seconds": 32.0,
		"nearest": true,
		"scene_id": "cs04",
		"title": "The Mender",
	},
	"cs05": {
		"path": "res://assets/video/genezer_warper.ogv",
		"flag": "cutscene_genezer_video_gezien",
		"aspect": WIDE,
		"max_seconds": 34.0,
		"nearest": false,
		"scene_id": "",
		"title": "The World Warper",
	},
	"cs06": {
		"path": "res://assets/video/cs06_atrium.ogv",
		"flag": "cutscene_cs06_gezien",
		"aspect": WIDE,
		"max_seconds": 32.0,
		"nearest": true,
		"scene_id": "cs06",
		"title": "The Atrium",
	},
	"cs07": {
		"path": "res://assets/video/cs07_orion_intro.ogv",
		"flag": "cutscene_cs07_gezien",
		"aspect": WIDE,
		"max_seconds": 32.0,
		"nearest": true,
		"scene_id": "cs07",
		"title": "Orion",
	},
	"cs08": {
		"path": "res://assets/video/cs08_h5_recognition.ogv",
		"flag": "cutscene_cs08_gezien",
		"aspect": WIDE,
		"max_seconds": 32.0,
		"nearest": true,
		"scene_id": "cs08",
		"title": "The Merchant",
	},
	"worldmap": {
		"path": "res://assets/video/worldmap_intro_v2.ogv",
		"flag": "cutscene_wereldkaart_gezien",
		"aspect": WIDE,
		"max_seconds": 24.0,
		"nearest": false,
		"scene_id": "wereldkaart",
		"title": "Into the Wide World",
	},
}


static func ids() -> Array:
	return VIDEOS.keys()


static func spec(id: String) -> Dictionary:
	var raw = VIDEOS.get(id, {})
	return raw.duplicate() if raw is Dictionary else {}


static func blocked_by_tests() -> bool:
	if allow_in_tests:
		return false
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--") and str(a).ends_with("test"):
			return true
	return false


## true = play() zou nu een speler starten (bestand er, nog niet gezien, poort dicht).
static func will_play(id: String, replay := false) -> bool:
	var s := spec(id)
	if s.is_empty():
		return false
	if not replay and blocked_by_tests():
		return false
	var flag := str(s.get("flag", ""))
	if not replay and flag != "" and GameState.story_flags.has(flag):
		return false
	return ResourceLoader.exists(str(s.get("path", "")))


static func apply(c: Node, id: String) -> void:
	var s := spec(id)
	if s.is_empty() or c == null:
		return
	c.set("video_path", str(s["path"]))
	c.set("video_aspect", float(s["aspect"]))
	c.set("max_seconds", float(s["max_seconds"]))
	c.set("pixel_perfect", bool(s.get("nearest", false)))


## Start id op host. null = niet gestart (poort, al gezien, onbekend, of herhaling uit).
## opts: replay (negeert vlag en poort, zet geen vlag), map (voor input-lock), node_name, layer.
static func play(id: String, host: Node, opts: Dictionary = {}) -> Node:
	var s := spec(id)
	if s.is_empty() or host == null:
		return null
	var replay := bool(opts.get("replay", false))
	if not replay and blocked_by_tests():
		return null
	var flag := str(s.get("flag", ""))
	if not replay and flag != "" and GameState.story_flags.has(flag):
		return null
	var path := str(s.get("path", ""))
	var started := ResourceLoader.exists(path)
	if started and not replay and flag != "":
		GameState.story_flags[flag] = true
		var scene_id := str(s.get("scene_id", ""))
		if scene_id != "":
			GameState.mark_scene_seen(scene_id)
	var script := load("res://scripts/worldmap_cutscene.gd") as GDScript
	var c: Node = script.new()
	c.name = str(opts.get("node_name", "CutsceneVideo"))
	apply(c, id)
	if opts.has("layer"):
		c.set("layer", int(opts["layer"]))
	host.add_child(c)
	var map: Node = opts.get("map", host)
	c.call("begin", map)
	return c


## true = het filmpje is gestart (vlag gezet of herhaling). Ontbrekend bestand: speler
## eindigt meteen en geeft false, zodat het verhaal het oude pad kan houden.
static func play_await(id: String, host: Node, opts: Dictionary = {}) -> bool:
	var replay := bool(opts.get("replay", false))
	var s := spec(id)
	var flag := str(s.get("flag", ""))
	var c := play(id, host, opts)
	if c == null:
		return false
	if c.has_method("is_done") and not bool(c.call("is_done")):
		await c.finished
	if replay:
		return true
	return flag != "" and GameState.story_flags.has(flag)
