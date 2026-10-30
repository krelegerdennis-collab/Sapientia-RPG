extends RefCounted
## WM1 T2: Donker Woud 16x16-tegels (data/woud_tegels.json) en de zijkamer woud_beek, binnen --autotest.
## Alleen dit blok: godot --path . -- --autotest --test-woud-tiles
## Controleert: elke tegel gemapt (bestand bestaat, 16x16 x frames), elke gebruikte tegelnaam heeft een id,
## lijst voor RPG ART compleet (docs/art/woud_tiles_16px.md), beloopbaarheid, uitgangen/warps, geen softlock.

const Beek := preload("res://scripts/data/woud_beek.gd")
const WoudRooms := preload("res://scripts/data/woud_rooms.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DOC := "res://docs/art/woud_tiles_16px.md"
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	_mapping()
	_gebruik()
	_lopen()
	_warps()
	await _scene()


func _mapping() -> void:
	var lijst: Array = WoudTegelsData.tegels()
	t.check("woud-tegels: mapping geladen (%d tegels)" % lijst.size(), lijst.size() >= 60)
	var fout: Array[String] = []
	var namen := {}
	for i in lijst.size():
		var r: Dictionary = lijst[i]
		var naam := str(r.get("naam", ""))
		if int(r.get("id", -1)) != i or namen.has(naam) or naam == "":
			fout.append("id/naam %s" % naam)
		namen[naam] = true
		var pad := str(r.get("file", ""))
		var tex: Texture2D = load(pad) if ResourceLoader.exists(pad) else null
		var frames := maxi(1, int(r.get("frames", 1)))
		if tex == null:
			fout.append("%s: geen bestand %s" % [naam, pad])
		elif tex.get_width() != 16 * frames or tex.get_height() != 16:
			fout.append("%s: maat %dx%d" % [naam, tex.get_width(), tex.get_height()])
		if not (str(r.get("laag", "")) in ["grond", "overlay"]) or str(r.get("functie", "")) == "":
			fout.append("%s: laag/functie" % naam)
		if str(r.get("laag")) == "overlay" and bool(r.get("solid", false)):
			fout.append("%s: overlay mag niet massief zijn" % naam)
	t.check("woud-tegels: elke tegel heeft id, bestand (16x16 x frames), laag en functie %s" % [fout], fout.is_empty())
	var ph := lijst.filter(func(r): return WoudTegelsData.is_placeholder(str(r["naam"])))
	t.check("woud-tegels: placeholders staan in assets/placeholder/woud/ met README (%d)" % ph.size(),
			FileAccess.file_exists(WoudTegelsData.PLACEHOLDER_MAP + "README.md")
			and FileAccess.get_file_as_string(WoudTegelsData.PLACEHOLDER_MAP + "README.md").contains("PLACEHOLDER - replaced by RPG ART"))
	var ts := WoudTegelsData.tileset()
	var bots := true
	for r in lijst:
		var src := ts.get_source(int(r["id"])) as TileSetAtlasSource
		var td := src.get_tile_data(Vector2i.ZERO, 0) if src != null else null
		if td == null or (td.get_collision_polygons_count(0) > 0) != bool(r["solid"]) \
				or str(td.get_custom_data("terrain")) != "woud":
			bots = false
	t.check("woud-tegels: TileSet heeft per tegel een bron, botsing = solid, terrein woud", ts.get_source_count() == lijst.size() and bots)
	var doc := FileAccess.get_file_as_string(DOC)
	var mist: Array = lijst.filter(func(r): return not doc.contains("`%s`" % r["naam"]))
	t.check("woud-tegels: elke tegel staat in docs/art/woud_tiles_16px.md (mist: %s)" % [mist.map(func(r): return r["naam"])],
			doc != "" and mist.is_empty())


## Elke tegelnaam die de kamer gebruikt (ook via autotegels/bomen/mist) bestaat in de mapping.
func _gebruik() -> void:
	var lagen: Dictionary = Beek.lagen()
	var onbekend := {}
	var gebruikt := {}
	for laag in ["grond", "overlay"]:
		for p in lagen[laag]:
			var n := str(lagen[laag][p])
			gebruikt[n] = true
			if WoudTegelsData.id_van(n) < 0:
				onbekend[n] = true
	for c in Beek.LEGEND:
		if WoudTegelsData.id_van(str(Beek.LEGEND[c])) < 0:
			onbekend[Beek.LEGEND[c]] = true
	t.check("woud-tegels: elke gebruikte tegel is gemapt (onbekend: %s)" % [onbekend.keys()], onbekend.is_empty())
	var w := str(Beek.LAYOUT[0]).length()
	var vol := Beek.LAYOUT.all(func(r): return str(r).length() == w)
	t.check("woud-tegels: layout rechthoekig %dx%d, elke cel een grondtegel" % [w, Beek.LAYOUT.size()],
			vol and lagen["grond"].size() == w * Beek.LAYOUT.size() and not lagen["grond"].values().has(""))
	var groepen := {}
	for n in gebruikt:
		groepen[str(WoudTegelsData.tegel(n).get("groep", ""))] = true
	t.check("woud-tegels: de Beek toont alle groepen (%s)" % [groepen.keys()],
			["grond", "pad", "rand", "boom", "water", "brug", "prop", "uitgang"].all(func(g): return groepen.has(g)))
	t.check("woud-tegels: water krijgt oevers en een midden", gebruikt.has("water_m") and gebruikt.has("water_oever_w")
			and gebruikt.has("water_oever_o") and gebruikt.has("brug_midden") and gebruikt.has("stapsteen"))


func _bereik(van: Vector2i) -> Dictionary:
	var gezien := {van: true}
	var todo: Array[Vector2i] = [van]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		for d in DIRS:
			var n := c + d
			if not gezien.has(n) and Beek.beloopbaar(n):
				gezien[n] = true
				todo.append(n)
	return gezien


func _lopen() -> void:
	var sp: Array = Beek.SPAWNS["pad"]
	var start := Vector2i(int(sp[0]), int(sp[1]))
	t.check("woud-tegels: spawn 'pad' is beloopbaar", Beek.beloopbaar(start))
	var w := str(Beek.LAYOUT[0]).length()
	var h := Beek.LAYOUT.size()
	var rand_open: Array[Vector2i] = []
	for y in h:
		for x in w:
			if (x == 0 or y == 0 or x == w - 1 or y == h - 1) and Beek.beloopbaar(Vector2i(x, y)) \
					and not Beek.uitgangen().has(Vector2i(x, y)):
				rand_open.append(Vector2i(x, y))
	t.check("woud-tegels: rand dicht behalve de uitgang %s" % [rand_open], rand_open.is_empty())
	var bereik := _bereik(start)
	t.check("woud-tegels: uitgang bereikbaar vanaf de spawn", Beek.uitgangen().all(func(u): return bereik.has(u)))
	t.check("woud-tegels: overkant van de beek bereikbaar (brug/stapstenen)", bereik.has(Vector2i(22, 8)) and bereik.has(Vector2i(20, 12)))
	var bord := Vector2i(int(Beek.BORD["tile"][0]), int(Beek.BORD["tile"][1]))
	t.check("woud-tegels: wegwijzer massief en leesbaar (buur bereikbaar)", not Beek.beloopbaar(bord)
			and DIRS.any(func(d): return bereik.has(bord + d)))
	t.check("woud-tegels: water is niet beloopbaar", not Beek.beloopbaar(Vector2i(13, 5)) and not Beek.beloopbaar(Vector2i(12, 10)))
	# geen softlock: van ELKE beloopbare tegel kom je bij de uitgang
	var vast: Array[Vector2i] = []
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if Beek.beloopbaar(p) and not bereik.has(p):
				vast.append(p)
	t.check("woud-tegels: geen afgesloten stukken (softlock) %s" % [vast], vast.is_empty())


func _warps() -> void:
	t.check("woud-tegels: uitgang -> Wortelpad, spawn 'beek'", str(Beek.EXIT["map"]) == Beek.PAD and ResourceLoader.exists(Beek.PAD))
	var pad: Dictionary = WoudRooms.ROOMS["woud_pad"]
	var sp: Array = pad["spawns"].get("beek", [])
	var obj: Array = pad.get("objects", [])
	t.check("woud-tegels: Wortelpad heeft spawn 'beek' en de struik-opening", sp.size() == 3 and obj.size() == 1
			and str(obj[0]["event"]) == "woud_beek" and ResourceLoader.exists(str(obj[0]["texture"])))
	t.check("woud-tegels: oude Wortelpad-spawns gelijk", pad["spawns"]["zuid"] == [3, 15, "up"] and pad["spawns"]["boog"] == [42, 3, "down"])
	var naar := false
	for c in SD.EVENTS.get("woud_beek", [{}])[0].get("do", []):
		if c is Array and str(c[0]) == "map" and str(c[1]) == Beek.SCENE and Beek.SPAWNS.has(str(c[2])):
			naar = true
	t.check("woud-tegels: event woud_beek -> de Beek (bestaande spawn)", naar and ResourceLoader.exists(Beek.SCENE))


func _scene() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.pending_spawn = "beek"
	var pad: Node = await _laad(Beek.PAD)
	t.check("woud-tegels: Wortelpad laadt met spawn beek", pad != null)
	if pad == null:
		return
	var p: Node = pad.get_node("Objects/Player")
	t.check("woud-tegels: speler op (42,15) naast de opening", p.get_tile() == Vector2i(42, 15))
	var opening: Node = pad.get_node_or_null("Objects/BeekOpening")
	t.check("woud-tegels: struik-opening staat in het Wortelpad", opening != null)
	if opening == null:
		return
	Story.trigger("woud_beek", opening)
	var beek: Node = await _wacht_op(Beek.SCENE)
	t.check("woud-tegels: opening brengt je naar de Beek", beek != null)
	if beek == null:
		return
	await t.frames(4)
	p = beek.get_node("Objects/Player")
	t.check("woud-tegels: in de Beek op spawn pad (4,14)", p.get_tile() == Vector2i(4, 14))
	t.check("woud-tegels: kaartnaam en geen gevechten", str(beek.map_name) == Beek.NAAM and beek.encounters == false)
	var g: TileMapLayer = beek.get_node("Ground")
	var ok := true
	var lagen: Dictionary = Beek.lagen()
	for c in lagen["grond"]:
		if g.get_cell_source_id(c) != WoudTegelsData.id_van(str(lagen["grond"][c])):
			ok = false
	t.check("woud-tegels: grondlaag = mapping", ok and beek.get_node_or_null("Overlay") != null)
	# echte botsing: water blokkeert, pad niet
	p.place_at(Vector2i(11, 5), Vector2i.RIGHT)
	await t.frames(2)
	var blok_water: bool = not p._can_move(Vector2i.RIGHT)
	p.place_at(Vector2i(4, 10), Vector2i.UP)
	await t.frames(2)
	t.check("woud-tegels: botsing: water blokkeert, pad is vrij", blok_water and p._can_move(Vector2i.UP))
	var ex: Node = beek.get_node_or_null("Exits/NaarWortelpad")
	t.check("woud-tegels: uitgang naar het Wortelpad (spawn beek)", ex != null and str(ex.target_map) == Beek.PAD and str(ex.target_spawn) == "beek")
	if ex == null:
		return
	beek._use_exit(ex)
	var terug: Node = await _wacht_op(Beek.PAD)
	t.check("woud-tegels: terug op het Wortelpad bij (42,15)", terug != null and terug.get_node("Objects/Player").get_tile() == Vector2i(42, 15))


func _wacht_op(pad: String) -> Node:
	for i in 600:
		await t.get_tree().process_frame
		if Dialog.is_open and i % 10 == 9:
			Dialog.advance()
		var s: Node = t.get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and s.get_node_or_null("Objects/Player") != null \
				and not GameState.changing_map:
			return s
	return null


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.has_return_point = false
	t.get_tree().change_scene_to_file(pad)
	for i in 180:
		await t.get_tree().process_frame
		var s: Node = t.get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4 \
				and s.get_node_or_null("Objects/Player") != null:
			return s
	return null
