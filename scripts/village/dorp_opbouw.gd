extends Node
## Zet panden, deuren, iconen, props (RPG ART), de beek met brug en de sfeer-NPC's in Wilgendal.
## Gerrit en de molen staan al in de scène; Gerrit blijft op zijn tegel.
## De andere vijf lopen de korte lus uit de data, tegel voor tegel.

const Data := preload("res://scripts/data/wilgendal_dorp.gd")
const NPC := preload("res://scenes/npc.tscn")
const DEUR := preload("res://scenes/door.tscn")
const Lus := preload("res://scripts/village/plein_lus.gd")
const Poort := preload("res://scripts/village/hek_poort.gd")

## v0.21: bord een tegel onder de gevel (zie bord.position).
const BORD_OMLAAG := 16.0
const TEX := {
	"pantser": preload("res://assets/sprites/buiten/wilgendal_pantser.png"),
	"wapen": preload("res://assets/sprites/buiten/wilgendal_wapen.png"),
	"accessoire": preload("res://assets/sprites/buiten/wilgendal_accessoire.png"),
	"magie": preload("res://assets/sprites/buiten/wilgendal_magie.png"),
	"huis": preload("res://assets/sprites/buiten/wilgendal_huis.png"),
	"huis_dicht": preload("res://assets/sprites/buiten/wilgendal_huis_dicht.png"),
	"burgemeester": preload("res://assets/sprites/buiten/wilgendal/burgemeestershuis.png"),
	"schild": preload("res://assets/sprites/buiten/wilgendal_schild.png"),
	"zwaard": preload("res://assets/sprites/buiten/wilgendal_zwaard.png"),
	"ring": preload("res://assets/sprites/buiten/wilgendal_ring.png"),
	"ster": preload("res://assets/sprites/buiten/wilgendal_ster.png"),
}


func _ready() -> void:
	# T27: s25_check RISK dorp_wilgendal — panden/props (docs/perf/s25_check.md)
	if PerfProbe.enabled:
		PerfProbe.begin("dorp_wilgendal")
	var kaart := get_parent()
	var objects := kaart.get_node("Objects")
	_beek_en_brug(kaart)
	_props(objects)
	_poorten(kaart, objects)
	_molen(objects)
	_gerrit(objects)
	_sfeer(objects)
	for ruw in Data.PANDEN:
		_pand(objects, ruw)
	_uitgang(kaart)
	_spawn_zuid(kaart)
	_plein10(kaart, objects)
	if PerfProbe.enabled:
		PerfProbe.end("dorp_wilgendal")


## v2: beek (1 tegel, 3 frames) + brug op een eigen laag tussen de grond en de objecten.
const BEEK_FPS := 4.0
var _beek: Array[Sprite2D] = []
var _beek_t := 0.0
var _beek_frame := 0


func _beek_en_brug(kaart: Node) -> void:
	var laag := Node2D.new()
	laag.name = "Beek"
	# Kind van Ground: de kaart zelf is nog bezig met _ready (add_child daar faalt),
	# en als kind tekent de laag boven de grondtegels maar onder Objects.
	kaart.get_node("Ground").add_child(laag)
	if Data.som():
		# SoM: beek en brug zijn tegels (dorp_ground.gd); alleen de botsing blijft hier.
		for x in Data.W:
			var t := Vector2i(x, Data.BEEK_RIJ)
			if Data.beek(t):
				_blok(laag, "BeekRand_%d" % x, Rect2i(t, Vector2i.ONE))
		return
	var tex: Texture2D = load(Data.PROPS_MAP + "beek_h.png")
	for x in Data.W:
		var t := Vector2i(x, Data.BEEK_RIJ)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.hframes = 3
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(t) * 16.0
		laag.add_child(spr)
		_beek.append(spr)
		if Data.beek(t):
			_blok(laag, "BeekRand_%d" % x, Rect2i(t, Vector2i.ONE))
	var brug := Sprite2D.new()
	brug.name = "Brug"
	brug.texture = load(Data.PROPS_MAP + "brug_v.png")
	brug.centered = false
	brug.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	brug.position = Vector2(Data.BRUG.position) * 16.0
	laag.add_child(brug)


func _process(delta: float) -> void:
	_anim_t += delta
	if _anim_t >= 1.0 / ANIM_FPS:
		_anim_t = 0.0
		for spr in _anim:
			if is_instance_valid(spr):
				spr.frame = (spr.frame + 1) % spr.hframes
	if _beek.is_empty():
		return
	_beek_t += delta
	if _beek_t < 1.0 / BEEK_FPS:
		return
	_beek_t = 0.0
	_beek_frame = (_beek_frame + 1) % 3
	for spr in _beek:
		spr.frame = _beek_frame


## Put, kramen, hekken, bloembakken, lantaarns, bankjes (y-sort op hun voetpunt).
func _props(objects: Node) -> void:
	var i := 0
	for ruw in Data.PROPS:
		var rij: Dictionary = ruw
		if Data.som() and Data.hek_prop(rij):
			i += 1
			continue  # SoM: hekken zijn grondtegels (dorp_ground.gd)
		var sp := Data.som_prop(rij)
		if not sp.is_empty():
			_som_prop(objects, rij, sp, i)
			i += 1
			continue
		var tex: Texture2D = load(Data.PROPS_MAP + str(rij["tex"]) + ".png")
		var t: Vector2i = rij["tegel"]
		var blok: Vector2i = rij["blok"]
		var body := StaticBody2D.new()
		body.name = "Prop_%s_%d" % [str(rij["tex"]), i]
		body.set_meta("prop", str(rij["tex"]))
		# voetpunt = onderrand van de blokkerende rij
		body.position = Vector2(t.x * 16.0 + blok.x * 8.0, (t.y + 1) * 16.0)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.flip_h = bool(rij.get("flip", false))
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		body.add_child(spr)
		if blok.x > 0 and blok.y > 0:
			var vorm := RectangleShape2D.new()
			vorm.size = Vector2(blok) * 16.0 - Vector2(2, 2)
			var bots := CollisionShape2D.new()
			bots.shape = vorm
			bots.position = Vector2(0, -blok.y * 8.0)
			body.add_child(bots)
		objects.add_child(body)
		i += 1


## SoM fase 4: elke poort (teken G) krijgt een Area die 'interact' opvangt; de botsing zit in de tegel.
func _poorten(kaart: Node, objects: Node) -> void:
	if not Data.som():
		return
	Data.poorten_open.clear()
	for t in Data.poorten():
		var p := Poort.new()
		p.name = "Poort_%d_%d" % [t.x, t.y]
		p.tegel = t
		p.grond = kaart.get_node("Ground")
		p.position = _tegel_midden(t)
		objects.add_child(p)


## SoM fase 3: prop uit props_index.json; y-sort op ysort_origin_px, botsing = collision_tiles.
func _som_prop(objects: Node, rij: Dictionary, sp: Dictionary, i: int) -> void:
	var body := StaticBody2D.new()
	body.name = "Prop_%s_%d" % [str(rij["tex"]), i]
	body.set_meta("prop", str(rij["tex"]))
	body.set_meta("som_prop", str(sp["naam"]))
	body.position = sp["voet"]
	var spr := Sprite2D.new()
	spr.texture = load(str(sp["tex"]))
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = Vector2(sp["links_boven"]) * 16.0 - body.position
	body.add_child(spr)
	var info: Dictionary = Data.P10_PROPS.get(str(rij["tex"]), {})
	if info.has("anim"):
		spr.texture = load(Data.P10 + str(info["anim"]))
		spr.hframes = int(info["frames"])
		_anim.append(spr)
	if str(sp.get("schaduw", "")) != "":
		_schaduw(str(sp["schaduw"]), Vector2(sp["links_boven"]) * 16.0)
	elif Data.P10_OUDE_SCHADUW.has(str(sp["naam"])):
		_schaduw(Data.P10 + str(Data.P10_OUDE_SCHADUW[str(sp["naam"])]), Vector2(sp["links_boven"]) * 16.0)
	var blok: Rect2i = sp["blok"]
	if blok.size.x > 0 and blok.size.y > 0:
		var vorm := RectangleShape2D.new()
		vorm.size = Vector2(blok.size) * 16.0 - Vector2(2, 2)
		var bots := CollisionShape2D.new()
		bots.shape = vorm
		bots.position = Vector2(blok.position) * 16.0 + Vector2(blok.size) * 8.0 - body.position
		body.add_child(bots)
	objects.add_child(body)


func _blok(ouder: Node, naam: String, r: Rect2i) -> void:
	var body := StaticBody2D.new()
	body.name = naam
	var vorm := RectangleShape2D.new()
	vorm.size = Vector2(r.size) * 16.0
	var bots := CollisionShape2D.new()
	bots.shape = vorm
	body.position = Vector2(r.position) * 16.0 + Vector2(r.size) * 8.0
	body.add_child(bots)
	ouder.add_child(body)


## v3: de reuzenmolen (MolenWieken in de scène) naar zijn plek in het westdeel.
func _molen(objects: Node) -> void:
	var molen := objects.get_node_or_null("MolenWieken")
	if molen != null:
		molen.position = Data.molen_positie()


func _gerrit(objects: Node) -> void:
	var gerrit := objects.get_node_or_null("Gerrit")
	if gerrit == null:
		return
	gerrit.set_meta("rol", "gerrit")
	_som_sheet(gerrit)
	if gerrit.has_method("place_at"):
		gerrit.place_at(Data.GERRIT_TEGEL, Vector2i.DOWN)


func _sfeer(objects: Node) -> void:
	for ruw in Data.SFEER:
		var rij: Dictionary = ruw
		var npc := NPC.instantiate()
		npc.name = str(rij["node"])
		npc.npc_name = str(rij["naam"])
		npc.lines = _zinnen(rij["lines"])
		npc.facing = Vector2i.DOWN
		npc.event = ""
		npc.set_meta("rol", str(rij["rol"]))
		var sheet := Data.som_npc_sheet(str(rij["node"]))
		if sheet != "":
			npc.sheet = load(sheet)
		objects.add_child(npc)
		npc.place_at(rij["tegel"], Vector2i.DOWN)
		var loper := Lus.new()
		loper.name = "PleinLus"
		loper.lus = Data.lus_tegels(rij)
		npc.add_child(loper)


## SoM fase 3: 24x32-sheet op een NPC die al in de scène staat (Gerrit).
func _som_sheet(npc: Node) -> void:
	var pad := Data.som_npc_sheet(str(npc.name))
	if pad == "":
		return
	npc.sheet = load(pad)
	var spr: Sprite2D = npc.get_node("Sprite2D")
	spr.texture = npc.sheet
	MapSprite.pas_toe(spr)
	if npc.has_method("_update_sprite"):
		npc._update_sprite()


func _pand(objects: Node, ruw: Dictionary) -> void:
	ruw = Data.som_pand(ruw)
	var id := str(ruw["id"])
	var oorsprong: Vector2i = ruw["oorsprong"]
	var maat: Vector2i = ruw["maat"]
	var blok := Data.pand_blok(ruw)
	var lichaam := StaticBody2D.new()
	lichaam.name = "Pand_%s" % id
	# v3: y-sort op de onderrand; alleen de onderste blok-rijen botsen (dak/gevel = erachter lopen)
	lichaam.position = Vector2(oorsprong.x * 16.0 + maat.x * 8.0, (oorsprong.y + maat.y) * 16.0)
	lichaam.set_meta("pand_id", id)
	lichaam.set_meta("kind", str(ruw["kind"]))
	var vorm := RectangleShape2D.new()
	vorm.size = Vector2(blok.size) * 16.0 - Vector2(2, 2)
	var bots := CollisionShape2D.new()
	bots.shape = vorm
	bots.position = Vector2(0, -blok.size.y * 8.0)
	lichaam.add_child(bots)
	var plaat := Sprite2D.new()
	plaat.texture = load(str(ruw["som_tex"])) if ruw.has("som_tex") else TEX[str(ruw["tex"])]
	plaat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaat.position = Vector2(0, -maat.y * 8.0)
	plaat.flip_h = bool(ruw.get("flip", false))
	lichaam.add_child(plaat)
	if ruw.has("schaduw"):
		_schaduw(str(ruw["schaduw"]), Vector2(oorsprong) * 16.0)
	objects.add_child(lichaam)

	var deur := DEUR.instantiate()
	deur.name = "Deur_%s" % id
	deur.position = _tegel_midden(ruw["deur"])
	deur.set_meta("pand_id", id)
	deur.set_meta("kind", str(ruw["kind"]))
	var dicht := str(ruw.get("dicht", ""))
	if ruw.has("warp_map"):
		deur.target_map = str(ruw["warp_map"])
		deur.target_spawn = str(ruw["warp_spawn"])
		deur.lines = _zinnen([])
	elif dicht == "":
		deur.target_map = Data.BINNEN
		deur.target_spawn = id
		deur.lines = _zinnen([])
	else:
		deur.target_map = ""
		deur.target_spawn = ""
		deur.lines = _zinnen([dicht])
	objects.add_child(deur)
	_spawn_voor(objects.get_parent(), id, Data.voor_tegel(ruw))

	var icoon := str(ruw.get("icoon", ""))
	if icoon != "":
		var bord := Uithangbord.new()
		bord.name = "Uithang_%s" % id
		bord.texture = TEX[icoon]
		bord.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bord.icoon = icoon
		bord.winkel_id = id
		bord.z_index = 2
		# v0.21: met de echte panden (RPG ART batch 13) hangt het bord een tegel lager, boven de deur,
		# zodat de gevelversiering (helm, zwaarden, sterraam) zichtbaar blijft.
		bord.position = Vector2(float(ruw["deur"].x) * 16.0 + 8.0, float(oorsprong.y) * 16.0 + 8.0 + BORD_OMLAAG)
		# SoM: het uithangbord zit in de gevel (bord_* tegel); het oude icoon blijft als knoop maar onzichtbaar.
		if ruw.has("som_tex"):
			bord.visible = false
		objects.add_child(bord)


func _spawn_voor(kaart: Node, id: String, tegel: Vector2i) -> void:
	var spawns := kaart.get_node("Spawns")
	var naam := Data.voor_spawn(id)
	if spawns.get_node_or_null(naam) != null:
		return
	var punt := MapSpawn.new()
	punt.name = naam
	punt.position = _tegel_midden(tegel)
	punt.facing = Vector2i.DOWN
	spawns.add_child(punt)


func _spawn_zuid(kaart: Node) -> void:
	var punt := kaart.get_node_or_null("Spawns/zuid_ingang")
	if punt == null:
		return
	punt.position = _tegel_midden(Data.SPAWN_TEGEL)
	punt.facing = Vector2i.UP


func _uitgang(kaart: Node) -> void:
	var uit := kaart.get_node_or_null("Exits/NaarWereld")
	if uit == null:
		return
	uit.position = Vector2(Data.EXIT_TEGEL) * 16.0
	uit.size_tiles = Data.EXIT_MAAT
	uit.target_map = Data.WERELD
	uit.target_spawn = "van_wilgendal"


func _midden(oorsprong: Vector2i, maat: Vector2i) -> Vector2:
	return Vector2(oorsprong) * 16.0 + Vector2(maat) * 8.0


func _tegel_midden(tegel: Vector2i) -> Vector2:
	return Vector2(tegel) * 16.0 + Vector2(8, 8)


func _zinnen(bron: Array) -> Array[String]:
	var uit: Array[String] = []
	for regel in bron:
		uit.append(str(regel))
	return uit


## --- Plein 10 (RPG ART art_10) ---
## Grondlaag "Plein10" (kind van Ground, boven SomV8/SomOverlay, onder Objects): keienplein, brug en
## alle schaduwen. Schaduwen hebben hetzelfde linksboven-anker als hun object (README art_10).
const ANIM_FPS := 3.0
var _anim: Array[Sprite2D] = []
var _anim_t := 0.0
var _grond10: Node2D = null


func _grondlaag() -> Node2D:
	if _grond10 == null:
		var kaart := get_parent()
		_grond10 = Node2D.new()
		_grond10.name = "Plein10"
		kaart.get_node("Ground").add_child(_grond10)
		for naam in ["Grond", "Bosrand", "Schaduwen", "Brug"]:
			var n := Node2D.new()
			n.name = naam
			_grond10.add_child(n)
	return _grond10


func _plat(ouder: Node, pad: String, pos: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = load(pad)
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	ouder.add_child(spr)
	return spr


func _schaduw(pad: String, linksboven: Vector2) -> void:
	if not Data.som() or not ResourceLoader.exists(pad):
		return
	var s := _plat(_grondlaag().get_node("Schaduwen"), pad, linksboven)
	s.name = pad.get_file().get_basename()


## Plein 10: gebakken grond van RPG ART (plein_grond_tileset.png + plein_grond_map.json) als tegellaag op het
## blok, de bosrand, de brug, decor (bomen, kar, kratten, tonnen, zakken, bloemen, wegwijzer, hekken, struiken,
## stenen) met botsing uit layout.json, schoorsteenrook en extra dorpelingen.
func _plein10(kaart: Node, objects: Node) -> void:
	if not Data.som():
		return
	var lay := Data.p10_layout()
	if lay.is_empty():
		push_warning("plein10/layout.json ontbreekt (python3 tools/plein10_bouw.py)")
		return
	var laag := _grondlaag()
	var o := Vector2(float(lay["ox"]), float(lay["oy"])) * 16.0
	# pass 5: bake13 van RPG ART (wilgendal_grond_*) vervangt plein_grond 1:1; keien, keien-zandovergang en
	# beekoevers zitten erin gebakken, dus dan geen keien-autotile erover (die blijft de terugval).
	var bake := Data.p10_bake()
	var gm = JSON.parse_string(FileAccess.get_file_as_string(Data.P10 + bake + "_map.json"))
	var kol := int(gm["cols"])
	var ts := _p10_tileset(bake, kol)
	var grond := TileMapLayer.new()
	grond.name = "GrondTegels"
	grond.tile_set = ts
	grond.position = o
	grond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	laag.get_node("Grond").add_child(grond)
	var kaartje: Array = gm["map"]
	for y in kaartje.size():
		var rij: Array = kaartje[y]
		for x in rij.size():
			var i := int(rij[x])
			grond.set_cell(Vector2i(x, y), 0, Vector2i(i % kol, i / kol))
	if bake == "plein_grond":
		_keien10(laag.get_node("Grond"), o)
	_plat(laag.get_node("Bosrand"), Data.P10 + "bos_rand.png", o).name = "BosDak"
	var bp: Array = lay["brug_px"]
	_plat(laag.get_node("Brug"), Data.P10 + "brug_11.png", Vector2(float(bp[0]), float(bp[1]))).name = "Brug10"
	# botsing: bosdak (W) en vaste decortegels
	var vast := StaticBody2D.new()
	vast.name = "Vast10"
	objects.add_child(vast)
	var tegels: Array = Data.p10_vast_tegels()
	for y in Data.H:
		for x in Data.W:
			if Data.GROND[y][x] == "W":
				tegels.append(Vector2i(x, y))
	var vorm := RectangleShape2D.new()      # alle vaste tegels delen dezelfde 16x16-botsvorm
	vorm.size = Vector2(16, 16)
	for t in tegels:
		var bots := CollisionShape2D.new()
		bots.shape = vorm
		bots.position = Vector2(t) * 16.0 + Vector2(8, 8)
		vast.add_child(bots)
	# decor: y-sort op de voet
	var decor := Node2D.new()
	decor.name = "Decor10"
	decor.y_sort_enabled = true
	objects.add_child(decor)
	var i := 0
	for ruw in lay["decor"]:
		var d: Dictionary = ruw
		var lb := Vector2(float(d["x"]), float(d["y"]))
		var knoop := Node2D.new()
		knoop.name = "%s_%d" % [str(d["file"]).get_basename(), i]
		knoop.position = Vector2(lb.x, float(d["voet"]))
		knoop.set_meta("soort", str(d["soort"]))
		decor.add_child(knoop)
		var spr := _plat(knoop, Data.P10 + str(d["file"]), lb - knoop.position)
		spr.name = "Sprite"
		if str(d["schaduw"]) != "":
			_schaduw(Data.P10 + str(d["schaduw"]), lb)
		i += 1
	# rook op de schoorstenen (4 frames), boven alles
	var j := 0
	for r in lay["rook"]:
		var spr := _plat(objects, Data.P10 + "rook_4f.png", Vector2(float(r["x"]), float(r["y"])))
		spr.name = "Rook_%d" % j
		spr.hframes = 4
		spr.frame = j % 4
		spr.z_index = 3
		spr.modulate.a = 0.9
		_anim.append(spr)
		j += 1
	# extra dorpelingen (geen rol: tellen niet als sfeer-NPC), vast op hun tegel
	for ruw in Data.P10_DORPELINGEN:
		var rij: Dictionary = ruw
		var npc := NPC.instantiate()
		npc.name = str(rij["node"])
		npc.npc_name = str(rij["naam"])
		npc.lines = _zinnen(rij["lines"])
		npc.facing = rij["kijk"]
		npc.event = ""
		npc.sheet = load(Data.P10 + str(rij["sheet"]) + ".png")
		objects.add_child(npc)
		npc.place_at(rij["tegel"], rij["kijk"])


## De plein-tileset (~1300 tegels, create_tile ~20 us per stuk = ~26 ms) is statisch voor de sessie: één keer
## bouwen. De atlas is klein (~1 MB), dus de cache houdt geen grote textuur vast (de v8-grond doet dat wel en
## wordt daarom per bezoek opgebouwd, zie dorp_ground.gd).
static var _p10_ts: TileSet = null
static var _p10_ts_sleutel := ""


static func _p10_tileset(bake: String, kol: int) -> TileSet:
	var sleutel := "%s|%d" % [bake, kol]
	if _p10_ts != null and _p10_ts_sleutel == sleutel:
		return _p10_ts
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var bron := TileSetAtlasSource.new()
	bron.texture = load(Data.P10 + bake + "_tileset.png")
	bron.texture_region_size = Vector2i(16, 16)
	var rijen := bron.texture.get_height() / 16
	for y in rijen:
		for x in kol:
			bron.create_tile(Vector2i(x, y))
	ts.add_source(bron, 0)
	_p10_ts = ts
	_p10_ts_sleutel = sleutel
	return ts


## Plein 10 pass 3: het keienplein als autotile (RPG ART rand10/rand11) boven de gebakken grond.
## Terrain-set 0 (MATCH_CORNERS_AND_SIDES): terrain 0 = gras (gras_licht), 1 = kei (plein_rand + keien_licht).
## Daarna macro-keien (2x2), put_ring onder de put en looplijnen op volle (masker 255) keitegels.
## keien_map.json (tools/plein10_keien.py): k = kei, g = gras_licht over de gebakken keienrand.
const KEI_RICHTING := {"N": TileSet.CELL_NEIGHBOR_TOP_SIDE, "NE": TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		"E": TileSet.CELL_NEIGHBOR_RIGHT_SIDE, "SE": TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
		"S": TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, "SW": TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		"W": TileSet.CELL_NEIGHBOR_LEFT_SIDE, "NW": TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER}
const KEI_VARIANT_KANS := 0.7
var keien10: TileMapLayer


static func kei_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0, 0)
	ts.set_terrain_name(0, 0, "gras")
	ts.set_terrain_color(0, 0, Color(0.45, 0.6, 0.25))
	ts.add_terrain(0, 1)
	ts.set_terrain_name(0, 1, "kei")
	ts.set_terrain_color(0, 1, Color(0.8, 0.78, 0.7))
	# bron 0: rand (47 blob-maskers + varianten)
	var rand := TileSetAtlasSource.new()
	rand.texture = load(Data.P10 + "plein_rand_tileset.png")
	rand.texture_region_size = Vector2i(16, 16)
	ts.add_source(rand, 0)
	var rl = JSON.parse_string(FileAccess.get_file_as_string(Data.P10 + "plein_rand_layout.json"))
	for ruw in rl["tiles"]:
		var t: Dictionary = ruw
		var a := Vector2i(int(t["atlas"][0]), int(t["atlas"][1]))
		rand.create_tile(a)
		var td := rand.get_tile_data(a, 0)
		td.terrain_set = 0
		td.terrain = 1
		var peer: Array = t["peering"]
		for r in KEI_RICHTING:
			td.set_terrain_peering_bit(KEI_RICHTING[r], 1 if peer.has(r) else 0)
		td.probability = 1.0 if int(t["variant"]) == 0 else KEI_VARIANT_KANS
		td.set_meta("masker", int(t["mask"]))
	# bron 1: lichte keien (vulling, masker 255, gewogen)
	var licht := TileSetAtlasSource.new()
	licht.texture = load(Data.P10 + "keien_licht_tileset.png")
	licht.texture_region_size = Vector2i(16, 16)
	ts.add_source(licht, 1)
	var ll = JSON.parse_string(FileAccess.get_file_as_string(Data.P10 + "keien_licht_layout.json"))
	for ruw in ll["tiles"]:
		var t: Dictionary = ruw
		var a := Vector2i(int(t["atlas"][0]), int(t["atlas"][1]))
		licht.create_tile(a)
		var td := licht.get_tile_data(a, 0)
		td.terrain_set = 0
		td.terrain = 1
		for r in KEI_RICHTING:
			td.set_terrain_peering_bit(KEI_RICHTING[r], 1)
		td.probability = float(t["probability"])
		td.set_meta("masker", 255)
	# bron 2: macro-blokken en decals (geen terrain: tweede pass)
	var macro := TileSetAtlasSource.new()
	macro.texture = load(Data.P10 + "keien_macro_tileset.png")
	macro.texture_region_size = Vector2i(16, 16)
	ts.add_source(macro, 2)
	var ml = JSON.parse_string(FileAccess.get_file_as_string(Data.P10 + "keien_macro_layout.json"))
	for ruw in ml["blocks"]:
		var b: Dictionary = ruw
		for dy in int(b["size_tiles"][1]):
			for dx in int(b["size_tiles"][0]):
				macro.create_tile(Vector2i(int(b["atlas_tiles"][0]) + dx, int(b["atlas_tiles"][1]) + dy))
	# bron 3: licht gras (terrain 0)
	var gras := TileSetAtlasSource.new()
	gras.texture = load(Data.P10 + "gras_licht_tileset.png")
	gras.texture_region_size = Vector2i(16, 16)
	ts.add_source(gras, 3)
	for i in gras.texture.get_width() / 16:
		gras.create_tile(Vector2i(i, 0))
		var td := gras.get_tile_data(Vector2i(i, 0), 0)
		td.terrain_set = 0
		td.terrain = 0
		for r in KEI_RICHTING:
			td.set_terrain_peering_bit(KEI_RICHTING[r], 0)
	return ts


func _keien10(ouder: Node, o: Vector2) -> void:
	var km := Data.p10_keien()
	if km.is_empty() or not ResourceLoader.exists(Data.P10 + "plein_rand_tileset.png"):
		return
	var ts := kei_tileset()
	keien10 = TileMapLayer.new()
	keien10.name = "Keien10"
	keien10.tile_set = ts
	keien10.position = o
	keien10.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ouder.add_child(keien10)
	var w := int(km["w"])
	var h := int(km["h"])
	var kei: Array[Vector2i] = []
	var gras: Array[Vector2i] = []
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			if Data.p10_kei(t):
				kei.append(t)
			else:
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if Data.p10_kei(t + Vector2i(dx, dy)) and not gras.has(t):
							gras.append(t)
	# eerst de grasrand (terrain 0), dan de keien (terrain 1): Godot kiest per cel de tegel met passende peering-bits
	keien10.set_cells_terrain_connect(gras, 0, 0, false)
	keien10.set_cells_terrain_connect(kei, 0, 1, false)
	# gras alleen waar de kaart 'g' zegt (anders gebakken grond: zandpad, bloemen), in gras_licht-varianten
	for t in gras:
		if Data.p10_keien_teken(t) == "g":
			keien10.set_cell(t, 3, Vector2i(Data.p10_hash(t) % 4, 0))
		else:
			keien10.erase_cell(t)
	_kei_macro(km)


## Tweede pass: put_ring onder de put, looplijnen (N-Z), daarna 2x2 macro-keien op vrije volle keitegels.
func _kei_macro(km: Dictionary) -> void:
	var lay := Data.p10_layout()
	var ob := Vector2i(int(lay["ox"]), int(lay["oy"]))
	var bezet := {}
	var vol := func(t: Vector2i) -> bool: return Data.p10_kei_masker(t) == 255 and not bezet.has(t)
	var past := func(p: Vector2i, m: Vector2i) -> bool:
		for dy in m.y:
			for dx in m.x:
				if not vol.call(p + Vector2i(dx, dy)):
					return false
		return true
	var leg := func(p: Vector2i, atlas: Vector2i, m: Vector2i) -> void:
		for dy in m.y:
			for dx in m.x:
				keien10.set_cell(p + Vector2i(dx, dy), 2, atlas + Vector2i(dx, dy))
				bezet[p + Vector2i(dx, dy)] = true
	# put_ring: 48x48, de put (48x48, links_boven op het raster) staat precies op +24,+24
	var put_mid := Vector2i(-100, -100)
	for ruw in Data.PROPS:
		if str(ruw.get("tex", "")) == "put":
			var sp := Data.som_prop(ruw)
			if not sp.is_empty():
				var p: Vector2i = Vector2i(sp["links_boven"]) - ob
				put_mid = p + Vector2i(1, 1)
				if past.call(p, Vector2i(3, 3)):
					leg.call(p, Vector2i(6, 0), Vector2i(3, 3))
					keien10.set_meta("put_ring", p)
	# looplijnen: 2x3, zo dicht mogelijk bij de as van de put, onder elkaar
	var lijnen := 0
	for y in int(km["h"]):
		for dx in [0, -1, 1, -2, 2, -3, 3, 2, -4, 4]:
			var p := Vector2i(put_mid.x + dx - 1, y)
			if lijnen < 3 and past.call(p, Vector2i(2, 3)):
				leg.call(p, Vector2i(0, 4) if lijnen % 2 == 0 else Vector2i(2, 4), Vector2i(2, 3))
				lijnen += 1
				break
	keien10.set_meta("looplijnen", lijnen)
	# macro 0..5 (2x2) op ~ de helft van de vrije volle plekken, vaste volgorde (hash)
	var macro := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0), Vector2i(0, 2), Vector2i(2, 2), Vector2i(4, 2)]
	var n := 0
	for y in int(km["h"]):
		for x in int(km["w"]):
			var p := Vector2i(x, y)
			if Data.p10_hash(p) % 5 < 2 and past.call(p, Vector2i(2, 2)):
				leg.call(p, macro[Data.p10_hash(p + Vector2i(7, 3)) % macro.size()], Vector2i(2, 2))
				n += 1
	keien10.set_meta("macro", n)
