extends TileMapLayer
## v8-stadsgrond van RPG ART (gebakken per kaart, zie tools/som/esdoorn_v8_grond.py) als beeldlaag boven
## de oude grondlaag (Ground blijft: botsing, terrain-data, camera-grenzen). Alleen op gras, pad en plein;
## bomen, water, hekken, heggen, bloembakken en tonnen van dorp.png blijven zichtbaar. Geen botsing.
## Past de json niet bij de grondlaag (andere maat), dan blijft deze laag leeg (opnieuw bakken).

@export_file("*.json") var json_pad := ""
@export_file("*.png") var png_pad := ""
## Atlas-kolommen van dorp.png waarop de v8-grond komt: gras (0, 1, 8-10), pad (2, 11-25), keien (33-48).
const ONDER := [0, 1, 2, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
		33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48]


func _ready() -> void:
	var grond: TileMapLayer = get_parent().get_node_or_null("Ground")
	if grond == null or not FileAccess.file_exists(json_pad) or not ResourceLoader.exists(png_pad):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(json_pad))
	var maat := grond.get_used_rect().size
	if not (d is Dictionary) or int(d.get("w", 0)) != maat.x or int(d.get("h", 0)) != maat.y:
		push_warning("%s past niet bij de kaart (opnieuw bakken)" % json_pad)
		return
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var bron := TileSetAtlasSource.new()
	bron.texture = load(png_pad)
	bron.texture_region_size = Vector2i(16, 16)
	var kol := int(d["kolommen"])
	for i in int(d["uniek"]):
		bron.create_tile(Vector2i(i % kol, i / kol))
	ts.add_source(bron, 0)
	tile_set = ts
	var cellen: Array = d["cellen"]
	for y in maat.y:
		for x in maat.x:
			var t := Vector2i(x, y)
			if grond.get_cell_source_id(t) != 0 or not ONDER.has(grond.get_cell_atlas_coords(t).x):
				continue
			var i := int(cellen[y * maat.x + x])
			set_cell(t, 0, Vector2i(i % kol, i / kol))
