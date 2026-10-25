extends "res://scripts/map.gd"
## Wachtershuis: ART-interieur 32x21 (layout.json), camera 512x336.

const Build := preload("res://scripts/data/huis_interieur_build.gd")

var _build := Build.new()
var details: Node2D


func _ready() -> void:
	details = get_node_or_null("Details") as Node2D
	if details == null:
		details = Node2D.new()
		details.name = "Details"
		add_child(details)
		move_child(details, ground.get_index())
	ground.clear()
	_build.bouw(ground, details, get_node("Objects"))
	_story_objecten()
	_spawns()
	_uitgang()
	var void_node := get_node_or_null("Void")
	if void_node:
		void_node.visible = false
	super._ready()


func _fit_camera() -> void:
	player.set_camera_limits(Rect2i(0, 0, Build.ROOM_PX.x, Build.ROOM_PX.y))


func _story_objecten() -> void:
	var boek: Node2D = get_node_or_null("Objects/SaveBook") as Node2D
	if boek:
		boek.position = Vector2(8, 3) * TILE + Vector2(8, 8)
	var opa: Node2D = get_node_or_null("Objects/OudeMan") as Node2D
	if opa:
		opa.position = Vector2(9, 3) * TILE + Vector2(8, 8)
	var sch: Node2D = get_node_or_null("Objects/Schilderij") as Node2D
	if sch:
		sch.position = Vector2(6, 1) * TILE + Vector2(8, 8)


func _spawns() -> void:
	_spawn("binnen", Build.SPAWN_TEGEL, Vector2i.UP)
	_spawn("bed", Vector2i(2, 3), Vector2i.DOWN)
	_spawn("lezen", Vector2i(9, 5), Vector2i.LEFT)


func _spawn(naam: String, tegel: Vector2i, richting: Vector2i) -> void:
	var s: Node = get_node_or_null("Spawns/" + naam)
	if s == null:
		return
	s.position = Vector2(tegel) * TILE + Vector2(8, 8)
	if "facing" in s:
		s.facing = richting


func _uitgang() -> void:
	var uit: Node = get_node_or_null("Exits/NaarDorp")
	if uit == null:
		return
	uit.position = Vector2(Build.EXIT_RECT.position) * TILE
	uit.size_tiles = Build.EXIT_RECT.size
	uit.target_spawn = "voor_huis"


func tegel_heeft_cel(tegel: Vector2i) -> bool:
	return ground.get_cell_source_id(tegel) != -1


func tegel_vrij(tegel: Vector2i) -> bool:
	return Build.tegel_vrij(ground, tegel, _build.prop_blocks())


func vrije_tegels() -> Array[Vector2i]:
	var uit: Array[Vector2i] = []
	for tegel in ground.get_used_cells():
		if tegel_vrij(tegel):
			uit.append(tegel)
	return uit


func bereik_van(start: Vector2i) -> Dictionary:
	var gezien := {}
	if not tegel_vrij(start):
		return gezien
	var rij: Array[Vector2i] = [start]
	gezien[start] = true
	while not rij.is_empty():
		var nu: Vector2i = rij.pop_front()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var volg: Vector2i = nu + dir
			if gezien.has(volg) or not tegel_vrij(volg):
				continue
			gezien[volg] = true
			rij.append(volg)
	return gezien


func dek_camera(vp: Vector2i) -> bool:
	return Build.dek_camera(ground, vp)


func voordeur_tegels() -> Array[Vector2i]:
	var uit: Array[Vector2i] = []
	for y in range(Build.EXIT_RECT.position.y, Build.EXIT_RECT.end.y):
		for x in range(Build.EXIT_RECT.position.x, Build.EXIT_RECT.end.x):
			uit.append(Vector2i(x, y))
	return uit


func layout_props() -> Array:
	return _build.props_geplaatst()


func prop_maat(naam: String) -> Vector2i:
	for p in _build.props_geplaatst():
		if str(p["name"]) == naam and p["node"] is Node2D:
			var spr: Sprite2D = (p["node"] as Node2D).get_child(0) as Sprite2D
			if spr and spr.texture:
				return Vector2i(spr.texture.get_width(), spr.texture.get_height())
	return Vector2i.ZERO
