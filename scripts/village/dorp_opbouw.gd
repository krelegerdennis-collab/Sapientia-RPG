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
	var gm = JSON.parse_string(FileAccess.get_file_as_string(Data.P10 + "plein_grond_map.json"))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var bron := TileSetAtlasSource.new()
	bron.texture = load(Data.P10 + "plein_grond_tileset.png")
	bron.texture_region_size = Vector2i(16, 16)
	var kol := int(gm["cols"])
	var rijen := bron.texture.get_height() / 16
	for y in rijen:
		for x in kol:
			bron.create_tile(Vector2i(x, y))
	ts.add_source(bron, 0)
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
	for t in tegels:
		var vorm := RectangleShape2D.new()
		vorm.size = Vector2(16, 16)
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
