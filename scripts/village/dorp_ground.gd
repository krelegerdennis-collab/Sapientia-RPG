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
	for y in Data.H:
		for x in Data.W:
			var t := Vector2i(x, y)
			var c := teken(t)
			var h := absi((x * 73856093) ^ (y * 19349663)) % gras.size()
			match c:
				"=", "#":
					_zet(self, t, "pad_%03d" % masker(t, PAD))
				"~":
					_zet(self, t, "water_%03d" % masker(t, WATER))
				"B":
					_zet(self, t, "pad_%03d" % masker(t, PAD))
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
	for y in Data.H:
		for x in Data.W:
			var t := Vector2i(x, y)
			if teken(t) != "T":
				continue
			var body := StaticBody2D.new()
			body.name = "Boom_%d_%d" % [x, y]
			body.position = Vector2(t) * 16.0 + Vector2(8, 8)
			var vorm := RectangleShape2D.new()
			vorm.size = Vector2(16, 16)
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


func _v8() -> void:
	if not FileAccess.file_exists(V8_JSON) or not ResourceLoader.exists(V8_PNG):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(V8_JSON))
	if not (d is Dictionary) or int(d.get("w", 0)) != Data.W or int(d.get("h", 0)) != Data.H:
		push_warning("grond_v8.json past niet bij de kaart (opnieuw bakken)")
		return
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var bron := TileSetAtlasSource.new()
	bron.texture = load(V8_PNG)
	bron.texture_region_size = Vector2i(16, 16)
	var kol := int(d["kolommen"])
	for i in int(d["uniek"]):
		bron.create_tile(Vector2i(i % kol, i / kol))
	ts.add_source(bron, 0)
	# pass 3: licht gras (RPG ART gras_licht, 4 varianten) buiten het plein-blok: zelfde basis (74963e) als
	# de gebakken plein-grond, dus geen naad meer tussen blok en dorp. Paden en hekken houden hun v8-tegel.
	var licht: Texture2D = load(GRAS_LICHT) if ResourceLoader.exists(GRAS_LICHT) else null
	if licht != null:
		var gb := TileSetAtlasSource.new()
		gb.texture = licht
		gb.texture_region_size = Vector2i(16, 16)
		for i in licht.get_width() / 16:
			gb.create_tile(Vector2i(i, 0))
		ts.add_source(gb, 1)
	# pass 4: padcellen en hun graszoom in de omgekleurde v8-atlas (grasplukjes blijven, geen donkere rand)
	var v8l: Texture2D = load(V8_LICHT) if ResourceLoader.exists(V8_LICHT) else null
	if v8l != null:
		var lb := TileSetAtlasSource.new()
		lb.texture = v8l
		lb.texture_region_size = Vector2i(16, 16)
		for i in int(d["uniek"]):
			lb.create_tile(Vector2i(i % kol, i / kol))
		ts.add_source(lb, 2)
	var blok := Rect2i()
	var lay := Data.p10_layout()
	if not lay.is_empty():
		blok = Rect2i(int(lay["ox"]), int(lay["oy"]), int(lay["w"]), int(lay["h"]))
	v8 = TileMapLayer.new()
	v8.name = "SomV8"
	v8.tile_set = ts
	add_child(v8)
	var cellen: Array = d["cellen"]
	for y in Data.H:
		for x in Data.W:
			if Data.GROND[y][x] == "~":
				continue
			if v8l != null and pad_zoom(Vector2i(x, y), blok):
				var j := int(cellen[y * Data.W + x])
				v8.set_cell(Vector2i(x, y), 2, Vector2i(j % kol, j / kol))
				continue
			if licht != null and gras_licht_hier(Vector2i(x, y), blok):
				v8.set_cell(Vector2i(x, y), 1, Vector2i(Data.p10_hash(Vector2i(x, y)) % (licht.get_width() / 16), 0))
				continue
			var i := int(cellen[y * Data.W + x])
			v8.set_cell(Vector2i(x, y), 0, Vector2i(i % kol, i / kol))
