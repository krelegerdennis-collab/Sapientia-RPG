extends "res://scripts/map.gd"
## Interieur van een Wilgendal-pand. Welk pand: de spawn-naam (pantser, wapen, ...).
## Binnentegels binnen_v8.png (25 vakken; kleed 12-20 = q w e / a m f / z x c), geen tint meer. Deur terug naar het dorp.

const Data := preload("res://scripts/data/wilgendal_dorp.gd")
const NPC := preload("res://scenes/npc.tscn")
const BORD := preload("res://scenes/sign.tscn")
const TOON_TEX := preload("res://assets/sprites/buiten/wilgendal_toonbank.png")
const VITRINE_TEX := preload("res://assets/sprites/buiten/wilgendal_vitrine.png")

const BINNEN := {
	".": 0, ",": 1, "C": 2, "U": 3, "W": 4, "D": 5, "S": 6, "s": 7,
	"t": 8, "h": 9, "b": 10, "d": 11, "q": 12, "w": 13, "e": 14,
	"a": 15, "m": 16, "f": 17, "z": 18, "x": 19, "c": 20, "k": 21, "L": 23, "R": 24,
}


func _ready() -> void:
	var id := GameState.pending_spawn
	if id == "" or Data.pand(id).is_empty():
		id = "wapen"
	_bouw(id)
	super._ready()


func _bouw(id: String) -> void:
	var rij: Dictionary = Data.pand(id)
	var rijen: Array = Data.kamer_rijen(id)
	encounters = false
	sets_checkpoint = false
	map_name = str(rij.get("map_naam", "Willowdale"))
	var vloer: TileMapLayer = get_node("Ground")
	# v8 (binnen_v8.png, RPG ART): de kleur zit in de tegels zelf, dus geen sfeertint meer (SFEER_KLEUR blijft als data)
	vloer.modulate = Color(1, 1, 1)
	var keeper_tegel := Vector2i(-1, -1)
	var vitrine_tegel := Vector2i(-1, -1)
	var bord_tegel := Vector2i(-1, -1)
	var spawn_tegel := Vector2i(4, 6)
	var deur_tegel := Vector2i(4, 7)
	var toon_tegels: Array[Vector2i] = []
	for y in rijen.size():
		var regel: String = rijen[y]
		for x in regel.length():
			var teken := regel[x]
			var tegel := Vector2i(x, y)
			if teken == "K":
				keeper_tegel = tegel
				teken = "."
			elif teken == "V":
				vitrine_tegel = tegel
				teken = "."
			elif teken == "N":
				bord_tegel = tegel
				teken = "."
			elif teken == "P":
				spawn_tegel = tegel
				teken = "."
			elif teken == "D":
				deur_tegel = tegel
			elif teken == "t":
				toon_tegels.append(tegel)
			var kol: int = int(BINNEN.get(teken, 0))
			vloer.set_cell(tegel, 0, Vector2i(kol, 0))
	_spawn(spawn_tegel)
	_uitgang(deur_tegel, id)
	var objects := get_node("Objects")
	var winkelier: Node = null
	var shop_id := str(rij.get("shop_id", ""))
	if str(rij.get("keeper_naam", "")) != "" and keeper_tegel.x >= 0:
		winkelier = _winkelier(objects, rij, keeper_tegel, shop_id)
	if not toon_tegels.is_empty() and winkelier != null:
		_toonbank(objects, toon_tegels, winkelier)
	if vitrine_tegel.x >= 0:
		_vitrine(objects, vitrine_tegel)
	if bord_tegel.x >= 0 and str(rij.get("bord", "")) != "":
		_bord(objects, bord_tegel, str(rij["bord"]))


func _spawn(tegel: Vector2i) -> void:
	var spawns := get_node("Spawns")
	var id := GameState.pending_spawn
	if id == "" or Data.pand(id).is_empty():
		id = "wapen"
	var punt := MapSpawn.new()
	punt.name = id
	punt.position = _midden(tegel)
	punt.facing = Vector2i.UP
	spawns.add_child(punt)


func _uitgang(tegel: Vector2i, id: String) -> void:
	var uit := MapExit.new()
	uit.name = "NaarDorp"
	uit.position = Vector2(tegel) * 16.0
	uit.size_tiles = Vector2i.ONE
	uit.target_map = Data.DORP
	uit.target_spawn = Data.voor_spawn(id)
	get_node("Exits").add_child(uit)


func _winkelier(objects: Node, rij: Dictionary, tegel: Vector2i, shop_id: String) -> Node:
	var npc := NPC.instantiate()
	npc.name = "Winkelier"
	npc.npc_name = str(rij["keeper_naam"])
	var zinnen: Array[String] = []
	for regel in rij["keeper_lines"]:
		zinnen.append(str(regel))
	npc.lines = zinnen
	npc.facing = Vector2i.DOWN
	if shop_id != "":
		npc.event = "shop"
		npc.event_arg = shop_id
	else:
		npc.event = ""
	npc.set_meta("shop_id", shop_id)
	objects.add_child(npc)
	npc.place_at(tegel, Vector2i.DOWN)
	return npc


func _toonbank(objects: Node, tegels: Array[Vector2i], winkelier: Node) -> void:
	var midden := tegels[tegels.size() / 2]
	for tegel in tegels:
		if tegel.x == winkelier.get_tile().x and tegel.y == winkelier.get_tile().y + 1:
			midden = tegel
	var bank := Toonbank.new()
	bank.name = "Toonbank"
	bank.position = _midden(midden)
	bank.set_meta("tegel", midden)
	var vorm := RectangleShape2D.new()
	vorm.size = Vector2(14, 14)
	var bots := CollisionShape2D.new()
	bots.shape = vorm
	bank.add_child(bots)
	var plaat := Sprite2D.new()
	plaat.texture = TOON_TEX
	plaat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaat.z_index = 1
	bank.add_child(plaat)
	bank.aangesproken.connect(func(speler: Node2D) -> void:
		if is_instance_valid(winkelier) and winkelier.has_method("interact"):
			winkelier.interact(speler)
	)
	objects.add_child(bank)


func _vitrine(objects: Node, tegel: Vector2i) -> void:
	var plaat := Sprite2D.new()
	plaat.name = "Vitrine"
	plaat.texture = VITRINE_TEX
	plaat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaat.position = _midden(tegel)
	plaat.z_index = 1
	objects.add_child(plaat)


func _bord(objects: Node, tegel: Vector2i, zin: String) -> void:
	var bord := BORD.instantiate()
	bord.name = "Bord"
	bord.position = _midden(tegel)
	var zinnen: Array[String] = [zin]
	bord.lines = zinnen
	objects.add_child(bord)


func _midden(tegel: Vector2i) -> Vector2:
	return Vector2(tegel) * 16.0 + Vector2(8, 8)
