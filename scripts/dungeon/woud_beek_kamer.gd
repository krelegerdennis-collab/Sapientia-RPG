extends "res://scripts/map.gd"
## WM1 T2: bouwt woud_beek uit scripts/data/woud_beek.gd met de tegel-mapping van
## scripts/data/woud_tegels.gd (data/woud_tegels.json). Grondlaag met botsing, overlay boven de speler.

const Beek := preload("res://scripts/data/woud_beek.gd")
const BORD := preload("res://scenes/sign.tscn")
const OVERLAY_Z := 10


func _ready() -> void:
	_bouw()
	super._ready()


func _bouw() -> void:
	# T27: s25_check RISK woud_beek — tegelopbouw (docs/perf/s25_check.md)
	if PerfProbe.enabled:
		PerfProbe.begin("woud_beek")
	encounters = false
	sets_checkpoint = false
	map_name = Beek.NAAM
	var ts := WoudTegelsData.tileset()
	var grond: TileMapLayer = get_node("Ground")
	grond.tile_set = ts
	var over := TileMapLayer.new()
	over.name = "Overlay"
	over.tile_set = ts
	over.z_index = OVERLAY_Z
	add_child(over)
	var lagen: Dictionary = Beek.lagen()
	for t in lagen["grond"]:
		_zet(grond, t, str(lagen["grond"][t]))
	for t in lagen["overlay"]:
		_zet(over, t, str(lagen["overlay"][t]))
	for naam in Beek.SPAWNS:
		var v: Array = Beek.SPAWNS[naam]
		var sp := MapSpawn.new()
		sp.name = naam
		sp.position = Vector2(int(v[0]), int(v[1])) * 16 + Vector2(8, 8)
		sp.facing = Story.dir_of(str(v[2]))
		get_node("Spawns").add_child(sp)
	var tiles := Beek.uitgangen()
	var r := Rect2i(tiles[0], Vector2i.ONE)
	for t in tiles:
		r = r.expand(t).expand(t + Vector2i.ONE)
	var ex := MapExit.new()
	ex.name = "NaarWortelpad"
	ex.position = Vector2(r.position) * 16
	ex.size_tiles = r.size
	ex.target_map = str(Beek.EXIT["map"])
	ex.target_spawn = str(Beek.EXIT["spawn"])
	get_node("Exits").add_child(ex)
	# rand onder de uitgang (zelfde als de dungeonkamers): niet van de kaart af lopen
	for t in tiles:
		var wand := StaticBody2D.new()
		wand.name = "Rand_%d_%d" % [t.x, t.y + 1]
		wand.position = Vector2(t + Vector2i.DOWN) * 16 + Vector2(8, 8)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 14)
		cs.shape = rect
		wand.add_child(cs)
		get_node("Objects").add_child(wand)
	var bord := BORD.instantiate()
	bord.name = "Wegwijzer"
	bord.position = Vector2(int(Beek.BORD["tile"][0]), int(Beek.BORD["tile"][1])) * 16 + Vector2(8, 8)
	var regels: Array[String] = []
	for l in Beek.BORD["lines"]:
		regels.append(str(l))
	bord.lines = regels
	var spr := bord.get_node_or_null("Sprite2D")
	if spr != null:
		spr.visible = false     # de wegwijzer-tegel ligt al in de grondlaag
	get_node("Objects").add_child(bord)
	if PerfProbe.enabled:
		PerfProbe.end("woud_beek")


func _zet(laag: TileMapLayer, t: Vector2i, naam: String) -> void:
	var id := WoudTegelsData.id_van(naam)
	if id < 0:
		push_error("woud_beek: tegel '%s' staat niet in data/woud_tegels.json" % naam)
		return
	laag.set_cell(t, id, Vector2i.ZERO)
