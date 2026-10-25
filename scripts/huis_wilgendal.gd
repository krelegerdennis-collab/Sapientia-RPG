extends "res://scripts/map.gd"
## Wachtershuis: woonkamer (bestaande 12x9) + twee slaapkamers en een keukenhoek.
## Annex-tegels vullen de camerapadding (16:9 en 19,5:9); Ground blijft 12x9.

const Kamers := preload("res://scripts/data/huis_wilgendal_kamers.gd")
const FornuisTex := preload("res://assets/sprites/binnen/keuken_fornuis_PLACEHOLDER.png")
const KozijnTex := preload("res://assets/sprites/binnen/deurkozijn_PLACEHOLDER.png")
const KastTex := preload("res://assets/sprites/dungeon/staande_kast.png")

const PROP_NAMEN: Array[String] = [
	"Kitchen", "KitchenShelf", "CupboardDax", "CupboardOpa", "DoorFrameDax", "DoorFrameOpa",
]

var annex: TileMapLayer


func _ready() -> void:
	_bouw_vleugels()
	super._ready()


func _bouw_vleugels() -> void:
	annex = TileMapLayer.new()
	annex.name = "Annex"
	annex.tile_set = ground.tile_set
	annex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(annex)
	move_child(annex, ground.get_index() + 1)
	Kamers.verf(annex, ground)
	_zet_prop("Kitchen", Kamers.KEUKEN_FORNUIS, FornuisTex, Vector2(24, 32), true)
	_zet_prop("KitchenShelf", Kamers.KEUKEN_KAST, KastTex, Vector2(16, 32), true)
	_zet_prop("CupboardDax", Kamers.KAST_DAX, KastTex, Vector2(16, 32), true)
	_zet_prop("CupboardOpa", Kamers.KAST_OPA, KastTex, Vector2(16, 32), true)
	_zet_prop("DoorFrameDax", Kamers.KOZIJN_DAX, KozijnTex, Vector2(24, 32), true)
	_zet_prop("DoorFrameOpa", Kamers.KOZIJN_OPA, KozijnTex, Vector2(24, 32), true)
	_marker("BedDax", Kamers.BED_DAX)
	_marker("BedOpa", Kamers.BED_OPA)
	_marker("DoorDax", Kamers.DEUR_DAX)
	_marker("DoorOpa", Kamers.DEUR_OPA)
	_marker("Chair2", Kamers.STOEL_2)


func _midden(tegel: Vector2i) -> Vector2:
	return Vector2(tegel) * TILE + Vector2(8, 8)


func _marker(naam: String, tegel: Vector2i) -> void:
	var objects := get_node("Objects")
	if objects.get_node_or_null(naam) != null:
		return
	var m := Marker2D.new()
	m.name = naam
	m.position = _midden(tegel)
	objects.add_child(m)


func _zet_prop(naam: String, tegel: Vector2i, tex: Texture2D, maat: Vector2, blok: bool) -> void:
	var objects := get_node("Objects")
	if objects.get_node_or_null(naam) != null:
		return
	var body := StaticBody2D.new()
	body.name = naam
	body.position = _midden(tegel)
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.offset = Vector2(0, -(maat.y * 0.5 - 8.0))
	body.add_child(spr)
	if blok:
		var vorm := RectangleShape2D.new()
		vorm.size = Vector2(14, 14)
		var bots := CollisionShape2D.new()
		bots.name = "CollisionShape2D"
		bots.shape = vorm
		body.add_child(bots)
	objects.add_child(body)


func tegel_heeft_cel(tegel: Vector2i) -> bool:
	if ground.get_cell_source_id(tegel) != -1:
		return true
	return annex != null and annex.get_cell_source_id(tegel) != -1


func tegel_vrij(tegel: Vector2i) -> bool:
	if not tegel_heeft_cel(tegel):
		return false
	if Kamers.laag_blokkeert(ground, tegel) or Kamers.laag_blokkeert(annex, tegel):
		return false
	var objects := get_node_or_null("Objects")
	if objects == null:
		return true
	for kind in objects.get_children():
		# Verborgen story-NPC's (collision_layer 0) tellen niet; de speler loopt erdoor.
		if kind is StaticBody2D and kind.collision_layer != 0 \
				and kind.position.distance_to(_midden(tegel)) < 8.1:
			return false
	return true


func vrije_tegels() -> Array[Vector2i]:
	var gezien := {}
	var uit: Array[Vector2i] = []
	for laag in [ground, annex]:
		if laag == null:
			continue
		for tegel in laag.get_used_cells():
			if gezien.has(tegel):
				continue
			gezien[tegel] = true
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
	var r: Rect2i = Kamers.camera_rect(ground.get_used_rect(), vp)
	var t0 := Vector2i(int(floor(float(r.position.x) / TILE)), int(floor(float(r.position.y) / TILE)))
	var t1 := Vector2i(int(ceil(float(r.end.x) / TILE)) - 1, int(ceil(float(r.end.y) / TILE)) - 1)
	for y in range(t0.y, t1.y + 1):
		for x in range(t0.x, t1.x + 1):
			if not tegel_heeft_cel(Vector2i(x, y)):
				return false
	return true


func bed_tegels() -> Array[Vector2i]:
	var uit: Array[Vector2i] = []
	for laag in [ground, annex]:
		if laag == null:
			continue
		for tegel in laag.get_used_cells():
			var atlas: Vector2i = laag.get_cell_atlas_coords(tegel)
			if atlas.y == 0 and atlas.x in [10, 11]:
				uit.append(tegel)
	return uit


func prop_heeft_botsing(naam: String) -> bool:
	var n: Node = get_node_or_null("Objects/" + naam)
	return n is StaticBody2D and n.get_node_or_null("CollisionShape2D") != null


func prop_maat(naam: String) -> Vector2i:
	var spr: Sprite2D = get_node_or_null("Objects/" + naam + "/Sprite") as Sprite2D
	if spr == null or spr.texture == null:
		return Vector2i.ZERO
	return Vector2i(spr.texture.get_width(), spr.texture.get_height())


func atlas_van(tegel: Vector2i) -> Vector2i:
	if ground.get_cell_source_id(tegel) != -1:
		return ground.get_cell_atlas_coords(tegel)
	if annex != null and annex.get_cell_source_id(tegel) != -1:
		return annex.get_cell_atlas_coords(tegel)
	return Vector2i(-1, -1)


func lege_vloeren() -> Array[Vector2i]:
	var uit: Array[Vector2i] = []
	for zone in [Kamers.SLAAP_DAX, Kamers.SLAAP_OPA, Kamers.KEUKEN_ZONE]:
		for y in range(zone.position.y, zone.end.y):
			for x in range(zone.position.x, zone.end.x):
				var tegel := Vector2i(x, y)
				var atlas: Vector2i = atlas_van(tegel)
				# 0 = platte vloer A, 1 = vloer B: beide lezen als lege vloer.
				if atlas.y == 0 and atlas.x in [0, 1]:
					uit.append(tegel)
	return uit
