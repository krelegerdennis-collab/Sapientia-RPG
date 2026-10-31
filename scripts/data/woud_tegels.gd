extends RefCounted
class_name WoudTegelsData
## WM1 T2: tegels van het Donker Woud als DATA (16x16, besluit Dennis). data/woud_tegels.json = de mapping
## tegel-id -> bestand (+ naam, groep, functie, solid, laag, frames). Echte art staat in
## assets/tiles/woud16/ via het veld "file"; placeholders blijven in assets/placeholder/woud/ als reserve.
## RPG ART wisselt een tegel in door alleen "file" aan te passen (zelfde maat 16x16, frames naast elkaar).
## De bestaande vijf woudkamers (woud_rooms.gd, atlas woud_tiles_v9b.png van RPG ART) blijven zoals ze zijn;
## deze mapping bouwt de nieuwe kamer woud_beek (scripts/data/woud_beek.gd).
## Animaties (water, gloed, stapsteen): horizontale strip, breedte = frames x 16, atlas-animatie 4 fps.

const JSON_PAD := "res://data/woud_tegels.json"
const TEGEL := 16
const FPS := 4.0
const PLACEHOLDER_MAP := "res://assets/placeholder/woud/"

static var _data: Dictionary = {}
static var _op_naam: Dictionary = {}
static var _tileset: TileSet = null


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(JSON_PAD))
		_data = d if d is Dictionary else {"tegels": []}
		for r in _data.get("tegels", []):
			_op_naam[str(r["naam"])] = r
	return _data


static func tegels() -> Array:
	return data().get("tegels", [])


static func tegel(naam: String) -> Dictionary:
	data()
	return _op_naam.get(naam, {})


static func id_van(naam: String) -> int:
	return int(tegel(naam).get("id", -1))


static func is_placeholder(naam: String) -> bool:
	return str(tegel(naam).get("file", "")).begins_with(PLACEHOLDER_MAP)


## TileSet met één atlasbron per tegel (bron-id = tegel-id): botsing als "solid", terrein "woud".
static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TEGEL, TEGEL)
	ts.add_physics_layer()
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "terrain")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	for r in tegels():
		var tex: Texture2D = load(str(r["file"])) if ResourceLoader.exists(str(r["file"])) else null
		if tex == null:
			push_error("woud_tegels: bestand ontbreekt voor %s (%s)" % [r["naam"], r["file"]])
			continue
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TEGEL, TEGEL)
		src.create_tile(Vector2i.ZERO)
		var frames := maxi(1, int(r.get("frames", 1)))
		if frames > 1:
			# horizontale strip: breedte = frames x 16, één atlas-tegel met frames naast elkaar
			src.set_tile_animation_frames_count(Vector2i.ZERO, frames)
			for f in frames:
				src.set_tile_animation_frame_duration(Vector2i.ZERO, f, 1.0 / FPS)
		ts.add_source(src, int(r["id"]))
		var td := src.get_tile_data(Vector2i.ZERO, 0)
		td.set_custom_data("terrain", "woud")
		if bool(r.get("solid", false)):
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	_tileset = ts
	return ts


## Autotegel voor een gebied (pad, water): stuk op basis van de 4 buren en de diagonalen.
## Geeft "nw", "n", ..., "m" of "binnen_nw" enz.
static func stuk(binnen: Callable, t: Vector2i) -> String:
	var n: bool = binnen.call(t + Vector2i.UP)
	var z: bool = binnen.call(t + Vector2i.DOWN)
	var w: bool = binnen.call(t + Vector2i.LEFT)
	var o: bool = binnen.call(t + Vector2i.RIGHT)
	var v := ("n" if not n else ("z" if not z else "")) + ("w" if not w else ("o" if not o else ""))
	if v != "":
		return v
	for d in [["nw", Vector2i(-1, -1)], ["no", Vector2i(1, -1)], ["zw", Vector2i(-1, 1)], ["zo", Vector2i(1, 1)]]:
		if not binnen.call(t + d[1]):
			return "binnen_" + d[0]
	return "m"
