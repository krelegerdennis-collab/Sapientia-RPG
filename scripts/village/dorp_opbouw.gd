extends Node
## Zet panden, deuren, iconen, props (RPG ART), de beek met brug en de sfeer-NPC's in Wilgendal.
## Gerrit en de molen staan al in de scène; Gerrit blijft op zijn tegel.
## De andere vijf lopen de korte lus uit de data, tegel voor tegel.

const Data := preload("res://scripts/data/wilgendal_dorp.gd")
const NPC := preload("res://scenes/npc.tscn")
const DEUR := preload("res://scenes/door.tscn")
const Lus := preload("res://scripts/village/plein_lus.gd")

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
	_molen(objects)
	_gerrit(objects)
	_sfeer(objects)
	for ruw in Data.PANDEN:
		_pand(objects, ruw)
	_uitgang(kaart)
	_spawn_zuid(kaart)


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
		objects.add_child(npc)
		npc.place_at(rij["tegel"], Vector2i.DOWN)
		var loper := Lus.new()
		loper.name = "PleinLus"
		loper.lus = Data.lus_tegels(rij)
		npc.add_child(loper)


func _pand(objects: Node, ruw: Dictionary) -> void:
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
	plaat.texture = TEX[str(ruw["tex"])]
	plaat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaat.position = Vector2(0, -maat.y * 8.0)
	lichaam.add_child(plaat)
	objects.add_child(lichaam)

	var deur := DEUR.instantiate()
	deur.name = "Deur_%s" % id
	deur.position = _tegel_midden(ruw["deur"])
	deur.set_meta("pand_id", id)
	deur.set_meta("kind", str(ruw["kind"]))
	var dicht := str(ruw.get("dicht", ""))
	if dicht == "":
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
