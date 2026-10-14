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


func _zet(laag: TileMapLayer, t: Vector2i, naam: String) -> void:
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
