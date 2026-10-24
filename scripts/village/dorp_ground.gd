extends TileMapLayer
## Grond van Dorp Wilgendal. Oud: tegels uit dorp.tres. SoM (KaartStijl "som"): de fase-1 terrain-
## tileset van het gebied (assets/tilesets/som/wilgendal/terrain.tres), blob47-autotiling voor pad en
## beek, een overlay-laag voor de brug en kegelbomen (RPG ART) op de rand.
## Tekens en kolommen: scripts/data/wilgendal_dorp.gd.

const Data := preload("res://scripts/data/wilgendal_dorp.gd")
const SOM_BOOM := "res://assets/sprites/som/wilgendal/kegelboom.png"
const SOM_BOOM_KLEIN := "res://assets/sprites/som/wilgendal/kegelboom_klein.png"
## blob47-bits (RPG ART fase 1): N1 NE2 E4 SE8 S16 SW32 W64 NW128.
const BITS := [[Vector2i(0, -1), 1], [Vector2i(1, -1), 2], [Vector2i(1, 0), 4], [Vector2i(1, 1), 8],
		[Vector2i(0, 1), 16], [Vector2i(-1, 1), 32], [Vector2i(-1, 0), 64], [Vector2i(-1, -1), 128]]
const PAD := "=#B"
const WATER := "~B"

var namen: Dictionary = {}


func _ready() -> void:
	if Data.som():
		_som()
		return
	for y in Data.H:
		var rij: String = Data.GROND[y]
		for x in rij.length():
			var kol: int = int(Data.TEGEL.get(rij[x], 0))
			set_cell(Vector2i(x, y), 0, Vector2i(kol, 0))


static func teken(t: Vector2i) -> String:
	var x := clampi(t.x, 0, Data.W - 1)
	var y := clampi(t.y, 0, Data.H - 1)
	return Data.GROND[y][x]


## GROND als vlak byte-raster (W*H): de buurcontroles in _som() en _v8() lezen hier i.p.v. 9x een
## string-index per cel (prestaties: het dorp bouwt 5040 cellen per binnenkomst).
static var _raster := PackedByteArray()


static func _grond_raster() -> PackedByteArray:
	if _raster.size() != Data.W * Data.H:
		_raster.resize(Data.W * Data.H)
		for y in Data.H:
			var rij: String = Data.GROND[y]
			for x in Data.W:
				_raster[y * Data.W + x] = rij.unicode_at(x)
	return _raster


static func _set_van(tekens: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	for i in tekens.length():
		out[tekens.unicode_at(i)] = 1
	return out


## Zelfde uitkomst als masker(t, soort), met het raster en een opzoektabel (_set_van) voor 'soort'.
static func _masker_r(r: PackedByteArray, x: int, y: int, soort: PackedByteArray) -> int:
	var m := 0
	for i in [0, 2, 4, 6]:
		var d: Vector2i = BITS[i][0]
		if soort[r[clampi(y + d.y, 0, Data.H - 1) * Data.W + clampi(x + d.x, 0, Data.W - 1)]] == 1:
			m |= int(BITS[i][1])
	for i in [1, 3, 5, 7]:
		var a: int = BITS[i - 1][1]
		var b: int = BITS[(i + 1) % 8][1]
		if (m & a) and (m & b):
			var d2: Vector2i = BITS[i][0]
			if soort[r[clampi(y + d2.y, 0, Data.H - 1) * Data.W + clampi(x + d2.x, 0, Data.W - 1)]] == 1:
				m |= int(BITS[i][1])
	return m


## blob47-masker: buur hoort bij dezelfde soort; schuin telt alleen als beide rechte buren er zijn.
static func masker(t: Vector2i, soort: String) -> int:
	var m := 0
	for i in [0, 2, 4, 6]:
		if soort.contains(teken(t + BITS[i][0])):
			m |= int(BITS[i][1])
	for i in [1, 3, 5, 7]:
		var a: int = BITS[i - 1][1]
		var b: int = BITS[(i + 1) % 8][1]
		if (m & a) and (m & b) and soort.contains(teken(t + BITS[i][0])):
			m |= int(BITS[i][1])
	return m


## Fase 3: geanimeerd water (bron 1 van terrain.tres, tools/som/water_anim.py), anders het stilstaande water.
var water_anim: Dictionary = {}
## Fase 4: hek-autotiles (bron 2 van terrain.tres, tools/som/hekken.py), tegelnaam -> atlas.
var hekken: Dictionary = {}
var overlay: TileMapLayer


func _zet(laag: TileMapLayer, t: Vector2i, naam: String) -> void:
	if hekken.has(naam):
		var h: Array = hekken[naam]
		laag.set_cell(t, 2, Vector2i(int(h[0]), int(h[1])))
		return
	if water_anim.has(naam):
		var w: Array = water_anim[naam]
		laag.set_cell(t, 1, Vector2i(int(w[0]), int(w[1])))
		return
	if not namen.has(naam):
		push_warning("SoM-tegel ontbreekt: " + naam)
		return
	var c: Array = namen[naam]
	laag.set_cell(t, 0, Vector2i(int(c[0]), int(c[1])))


func _som() -> void:
	set_meta("som_klaar", true)
	tile_set = load(KaartStijl.tileset_pad("wilgendal", "terrain"))
	namen = JSON.parse_string(FileAccess.get_file_as_string(
			KaartStijl.tileset_pad("wilgendal", "terrain").replace(".tres", "_namen.json")))
	var wpad := KaartStijl.tileset_pad("wilgendal", "terrain").get_base_dir().path_join("water_anim_namen.json")
	if FileAccess.file_exists(wpad) and tile_set.has_source(1):
		var wd = JSON.parse_string(FileAccess.get_file_as_string(wpad))
		if wd is Dictionary:
			water_anim = wd
	var hpad := KaartStijl.tileset_pad("wilgendal", "terrain").get_base_dir().path_join("hekken_namen.json")
	if FileAccess.file_exists(hpad) and tile_set.has_source(2):
		var hd = JSON.parse_string(FileAccess.get_file_as_string(hpad))
		if hd is Dictionary:
			hekken = hd
	_v8()
	var over := TileMapLayer.new()
	over.name = "SomOverlay"
	over.tile_set = tile_set
	add_child(over)
	# bomen in Objects: y-sort met de speler (achter een boom langs lopen)
	var bomen := Node2D.new()
	bomen.name = "SomBomen"
	bomen.y_sort_enabled = true
	get_parent().get_node("Objects").add_child(bomen)
	var gras := ["gras_0", "gras_0", "gras_1", "gras_2", "gras_0", "gras_3", "gras_klaver", "gras_1",
			"gras_0", "gras_bloem", "gras_2", "gras_kiezel"]
	var r := _grond_raster()
	var pad_set := _set_van(PAD)
	var water_set := _set_van(WATER)
	for y in Data.H:
		for x in Data.W:
			var t := Vector2i(x, y)
			var h := absi((x * 73856093) ^ (y * 19349663)) % gras.size()
			match char(r[y * Data.W + x]):
				"=", "#":
					_zet(self, t, "pad_%03d" % _masker_r(r, x, y, pad_set))
				"~":
					_zet(self, t, "water_%03d" % _masker_r(r, x, y, water_set))
				"B":
					_zet(self, t, "pad_%03d" % _masker_r(r, x, y, pad_set))
				"T":
					_zet(self, t, "gras_hoog")
				_:
					_zet(self, t, gras[h])
	overlay = over
	# hekken en poorten: overlay-tegel op gras, botsing uit de tegel (open poort botst niet)
	for y in Data.H:
		for x in Data.W:
			var t := Vector2i(x, y)
			if Data.hek_aanwezig(t):
				_zet(over, t, Data.hek_tegel(t))
	# brug: noord-zuid over de beek (BRUG = 2 breed, 3 hoog)
	var b := Data.BRUG
	for x in range(b.position.x, b.end.x):
		_zet(over, Vector2i(x, b.position.y), "brug_v_t")
		for y in range(b.position.y + 1, b.end.y - 1):
			_zet(over, Vector2i(x, y), "brug_v_m")
		_zet(over, Vector2i(x, b.end.y - 1), "brug_v_b")
	_bomen(bomen)


## Kegelbomen op de 'T'-tegels; botsing per tegel (zoals de oude boomtegel).
func _bomen(ouder: Node2D) -> void:
	var groot: Texture2D = load(SOM_BOOM)
	var klein: Texture2D = load(SOM_BOOM_KLEIN)
	# één gedeelde botsvorm voor alle bomen (was: een nieuwe RectangleShape2D per boom)
	var vorm := RectangleShape2D.new()
	vorm.size = Vector2(16, 16)
	for y in Data.H:
		for x in Data.W:
			var t := Vector2i(x, y)
			if teken(t) != "T":
				continue
			var body := StaticBody2D.new()
			body.name = "Boom_%d_%d" % [x, y]
			body.position = Vector2(t) * 16.0 + Vector2(8, 8)
			var bots := CollisionShape2D.new()
			bots.shape = vorm
			body.add_child(bots)
			var rand := x == 0 or y == 0 or x == Data.W - 1 or y == Data.H - 1
			var spr := Sprite2D.new()
			spr.texture = groot if rand else klein
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.centered = false
			spr.position = Vector2(-16, 8 - spr.texture.get_height())
			# om en om iets verschoven zodat de rand een bos lijkt, geen hek
			if rand and (x + y) % 2 == 1:
				spr.position += Vector2(0, -6)
			body.add_child(spr)
			ouder.add_child(body)


## Poort open/dicht: wisselt de tegel (en dus de botsing).
func zet_poort(t: Vector2i, open: bool) -> void:
	Data.poorten_open[t] = open
	if overlay != null:
		_zet(overlay, t, Data.hek_tegel(t))


## v8-grond (RPG ART, 20 okt 2026): gebakken gras/pad/plein per cel (tools/som/wilgendal_v8_grond.py),
## een eigen laag boven de semantische grondlaag (die blijft: terrain-data, water-animatie, tests).
## Op beek-cellen blijft het geanimeerde water zichtbaar. Geen botsing: alleen beeld.
const V8_JSON := "res://assets/tilesets/som/wilgendal/grond_v8.json"
const V8_PNG := "res://assets/tilesets/som/wilgendal/grond_v8.png"
var v8: TileMapLayer
const V8_LICHT := "res://assets/sprites/buiten/wilgendal/plein10/grond_v8_licht.png"


## Pad of gras direct naast een pad (8 buren), buiten het plein-blok: omgekleurde v8-tegel.
static func pad_zoom(t: Vector2i, blok: Rect2i) -> bool:
	if blok.has_point(t) or not ".TFG=#B".contains(Data.GROND[t.y][t.x]):
		return false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var n := t + Vector2i(dx, dy)
			if n.x >= 0 and n.y >= 0 and n.x < Data.W and n.y < Data.H and PAD.contains(Data.GROND[n.y][n.x]):
				return true
	return false


const GRAS_LICHT := "res://assets/sprites/buiten/wilgendal/plein10/gras_licht_tileset.png"


## Licht gras op deze cel? Gras (ook onder bomen en hekken), buiten het plein-blok (dat heeft eigen grond).
static func gras_licht_hier(t: Vector2i, blok: Rect2i) -> bool:
	return ".TFG".contains(Data.GROND[t.y][t.x]) and not blok.has_point(t)


## grond_v8.json hoeft maar één keer per sessie geparsed (data, geen resources).
static var _v8_json: Variant = null


func _v8() -> void:
	if not FileAccess.file_exists(V8_JSON) or not ResourceLoader.exists(V8_PNG):
		return
	if _v8_json == null:
		_v8_json = JSON.parse_string(FileAccess.get_file_as_string(V8_JSON))
	var d = _v8_json
	if not (d is Dictionary) or int(d.get("w", 0)) != Data.W or int(d.get("h", 0)) != Data.H:
		push_warning("grond_v8.json past niet bij de kaart (opnieuw bakken)")
		return
	var kol := int(d["kolommen"])
	var uniek := int(d["uniek"])
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var bron := TileSetAtlasSource.new()
	bron.texture = load(V8_PNG)
	bron.texture_region_size = Vector2i(16, 16)
	# pass 3: licht gras (RPG ART gras_licht, 4 varianten) buiten het plein-blok: zelfde basis (74963e) als
	# de gebakken plein-grond, dus geen naad meer tussen blok en dorp. Paden en hekken houden hun v8-tegel.
	var licht: Texture2D = load(GRAS_LICHT) if ResourceLoader.exists(GRAS_LICHT) else null
	var gb: TileSetAtlasSource = null
	if licht != null:
		gb = TileSetAtlasSource.new()
		gb.texture = licht
		gb.texture_region_size = Vector2i(16, 16)
		for i in licht.get_width() / 16:
			gb.create_tile(Vector2i(i, 0))
	# pass 4: padcellen en hun graszoom in de omgekleurde v8-atlas (grasplukjes blijven, geen donkere rand)
	var v8l: Texture2D = load(V8_LICHT) if ResourceLoader.exists(V8_LICHT) else null
	var lb: TileSetAtlasSource = null
	if v8l != null:
		lb = TileSetAtlasSource.new()
		lb.texture = v8l
		lb.texture_region_size = Vector2i(16, 16)
	var blok := Rect2i()
	var lay := Data.p10_layout()
	if not lay.is_empty():
		blok = Rect2i(int(lay["ox"]), int(lay["oy"]), int(lay["w"]), int(lay["h"]))
	v8 = TileMapLayer.new()
	v8.name = "SomV8"
	# Eerst per cel bepalen welke bron en tegel, dan alleen de tegels aanmaken die er echt gebruikt
	# worden (create_tile kost ~20 us; het atlas heeft ~1300 tegels, het dorp gebruikt er ~380 + ~140).
	var cellen: Array = d["cellen"]
	var r := _grond_raster()
	var pad_set := _set_van(PAD)
	var gras_set := _set_van(".TFG")
	var pad_zoom_set := _set_van(".TFG=#B")
	var bron_van := PackedInt32Array()      # per cel: -1 = niets, anders bron-id
	var atlas_van := PackedInt32Array()     # per cel: tegel-index (bron 0/2) of kolom (bron 1)
	bron_van.resize(Data.W * Data.H)
	atlas_van.resize(Data.W * Data.H)
	var nodig0 := PackedByteArray()
	var nodig2 := PackedByteArray()
	nodig0.resize(uniek)
	nodig2.resize(uniek)
	var licht_kol := licht.get_width() / 16 if licht != null else 1
	for y in Data.H:
		for x in Data.W:
			var k := y * Data.W + x
			bron_van[k] = -1
			var c := r[k]
			if char(c) == "~":
				continue
			var t := Vector2i(x, y)
			if lb != null and not blok.has_point(t) and pad_zoom_set[c] == 1 and _buur_is_pad(r, x, y, pad_set):
				var j := int(cellen[k])
				bron_van[k] = 2
				atlas_van[k] = j
				if j < uniek:
					nodig2[j] = 1
				continue
			if licht != null and gras_set[c] == 1 and not blok.has_point(t):
				bron_van[k] = 1
				atlas_van[k] = Data.p10_hash(t) % licht_kol
				continue
			var i := int(cellen[k])
			bron_van[k] = 0
			atlas_van[k] = i
			if i < uniek:
				nodig0[i] = 1
	for i in uniek:
		if nodig0[i] == 1:
			bron.create_tile(Vector2i(i % kol, i / kol))
		if lb != null and nodig2[i] == 1:
			lb.create_tile(Vector2i(i % kol, i / kol))
	# bronnen pas toevoegen als de tegels er zijn (add_source op een gevuld atlas is goedkoper dan andersom)
	ts.add_source(bron, 0)
	if gb != null:
		ts.add_source(gb, 1)
	if lb != null:
		ts.add_source(lb, 2)
	v8.tile_set = ts
	add_child(v8)
	for y in Data.H:
		for x in Data.W:
			var k := y * Data.W + x
			var b := bron_van[k]
			if b == 1:
				v8.set_cell(Vector2i(x, y), 1, Vector2i(atlas_van[k], 0))
			elif b >= 0:
				v8.set_cell(Vector2i(x, y), b, Vector2i(atlas_van[k] % kol, atlas_van[k] / kol))


## Zelfde als de buurcontrole in pad_zoom() (3x3 rond de cel, alleen binnen de kaart), met het raster.
static func _buur_is_pad(r: PackedByteArray, x: int, y: int, pad_set: PackedByteArray) -> bool:
	for dy in range(maxi(0, y - 1), mini(Data.H - 1, y + 1) + 1):
		for dx in range(maxi(0, x - 1), mini(Data.W - 1, x + 1) + 1):
			if pad_set[r[dy * Data.W + dx]] == 1:
				return true
	return false
