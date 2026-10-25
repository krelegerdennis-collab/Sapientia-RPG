extends "res://scripts/map.gd"
## Wachtershuis: woonkamer (bestaande 12x9) + twee slaapkamers en een keukenhoek.
## Annex-tegels vullen de camerapadding; Ground blijft 12x9 voor de bestaande tests.

const Kamers := preload("res://scripts/data/huis_wilgendal_kamers.gd")
const FornuisTex := preload("res://assets/sprites/binnen/keuken_fornuis_PLACEHOLDER.png")
const KastTex := preload("res://assets/sprites/dungeon/staande_kast.png")

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
	_zet_prop("CupboardDax", Vector2i(-4, 5), KastTex, Vector2(16, 32), true)
	_zet_prop("CupboardOpa", Vector2i(15, 5), KastTex, Vector2(16, 32), true)
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
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.offset = Vector2(0, -(maat.y * 0.5 - 8.0))
	body.add_child(spr)
	if blok:
		var vorm := RectangleShape2D.new()
		vorm.size = Vector2(14, 14)
		var bots := CollisionShape2D.new()
		bots.shape = vorm
		body.add_child(bots)
	objects.add_child(body)


func tegel_vrij(tegel: Vector2i) -> bool:
	if Kamers.laag_blokkeert(ground, tegel) or Kamers.laag_blokkeert(annex, tegel):
		return false
	var objects := get_node_or_null("Objects")
	if objects == null:
		return true
	for kind in objects.get_children():
		if kind is StaticBody2D and kind.position.distance_to(_midden(tegel)) < 8.1:
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
