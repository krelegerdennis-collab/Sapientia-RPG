extends Node
## Wilgendal: vier winkelpanden, iconen, vier huizen, zes sfeer-NPC's.
## Vijf lopen een korte lus op het plein. Gerrit blijft op zijn molentegel.
## Start: godot --path . -- --wilgendaltest

const Data := preload("res://scripts/data/wilgendal_dorp.gd")
const Shop := preload("res://scripts/data/shop_data.gd")
const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DORP := "res://scenes/maps/dorp_wilgendal.tscn"
const BINNEN := "res://scenes/maps/wilgendal_binnen.tscn"
const WERELD := "res://scenes/maps/wereldkaart.tscn"
const BIEB := "res://scenes/maps/archief_bibliotheek.tscn"

const ART := {
	"res://assets/sprites/buiten/wilgendal_pantser.png": Vector2i(48, 48),
	"res://assets/sprites/buiten/wilgendal_wapen.png": Vector2i(48, 48),
	"res://assets/sprites/buiten/wilgendal_accessoire.png": Vector2i(48, 48),
	"res://assets/sprites/buiten/wilgendal_magie.png": Vector2i(48, 48),
	"res://assets/sprites/buiten/wilgendal_huis.png": Vector2i(48, 48),
	"res://assets/sprites/buiten/wilgendal_huis_dicht.png": Vector2i(48, 48),
	"res://assets/sprites/buiten/wilgendal_schild.png": Vector2i(48, 16),
	"res://assets/sprites/buiten/wilgendal_zwaard.png": Vector2i(48, 16),
	"res://assets/sprites/buiten/wilgendal_ring.png": Vector2i(48, 16),
	"res://assets/sprites/buiten/wilgendal_ster.png": Vector2i(48, 16),
	"res://assets/sprites/buiten/wilgendal_toonbank.png": Vector2i(48, 16),
	"res://assets/sprites/buiten/wilgendal_vitrine.png": Vector2i(48, 16),
}

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_data()
	_art()
	_wereld()
	await _dorp()
	await _plein10()
	_kleed_vakken()
	await _panden()
	await _som()
	print("WILGENDALTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data() -> void:
	check("grond is 90 bij 56 (schaal 1.4x voor 24x32-helden, paden 2-3 breed)", Data.grond_ok() and Data.W == 90 and Data.H == 56)
	check("max %d sfeer-NPC's op het marktplein (%d)" % [Data.PLEIN_MAX, Data.op_plein_aantal()],
			Data.op_plein_aantal() <= Data.PLEIN_MAX and Data.op_plein_aantal() >= 1)
	var beek_ok := true
	for x in Data.W:
		var t := Vector2i(x, Data.BEEK_RIJ)
		if Data.BRUG.has_point(t) != Data.beloopbaar(t) and x > 0 and x < Data.W - 1:
			beek_ok = false
	check("beek is 1 tegel breed, alleen de brug is beloopbaar", beek_ok
			and Data.beloopbaar(Vector2i(26, Data.BEEK_RIJ - 1)) and Data.beloopbaar(Vector2i(26, Data.BEEK_RIJ + 1)))
	var props_ok := true
	for ruw in Data.PROPS:
		if not ResourceLoader.exists(Data.PROPS_MAP + str(ruw["tex"]) + ".png"):
			props_ok = false
	check("props van RPG ART bestaan (put, kramen, hek, bloembak, lantaarn, bankje, beek, brug)", props_ok
			and ResourceLoader.exists(Data.PROPS_MAP + "beek_h.png") and ResourceLoader.exists(Data.PROPS_MAP + "brug_v.png"))
	check("dorp en interieurs zijn geen kerker voor de autosave",
			not GameState.is_dungeon_transition(WERELD, DORP) and not GameState.is_dungeon_transition(DORP, WERELD)
			and not GameState.is_dungeon_transition(WERELD, BINNEN) and not GameState.is_dungeon_transition(BINNEN, WERELD)
			and GameState.NON_DUNGEON_MAPS.has(DORP.get_file().get_basename())
			and GameState.NON_DUNGEON_MAPS.has(BINNEN.get_file().get_basename()))
	check("vier winkelpanden", Data.winkels().size() == 4)
	var ids: Array = []
	for ruw in Data.winkels():
		var rij: Dictionary = ruw
		ids.append(str(rij["id"]))
		check("winkel %s heeft een bestaande shop" % str(rij["id"]), Shop.SHOPS.has(str(rij["shop_id"])))
	check("panden armour wapen accessoire magic", ids == ["pantser", "wapen", "accessoire", "magie"])
	check("iconen schild zwaard ring ster", Data.ICOON_VAN_WINKEL["pantser"] == "schild"
			and Data.ICOON_VAN_WINKEL["wapen"] == "zwaard"
			and Data.ICOON_VAN_WINKEL["accessoire"] == "ring"
			and Data.ICOON_VAN_WINKEL["magie"] == "ster")
	var huizen: Array = Data.huizen()
	var bewoond := 0
	var decor := 0
	for ruw in huizen:
		var rij: Dictionary = ruw
		if bool(rij["bewoond"]):
			bewoond += 1
			check("bewoond huis %s gaat open" % str(rij["id"]), str(rij["dicht"]) == "")
		else:
			decor += 1
			check("decorhuis %s heeft een dichte deur" % str(rij["id"]), str(rij["dicht"]) != "")
	check("vier huizen, twee bewoond, twee decor", huizen.size() == 4 and bewoond == 2 and decor == 2)
	var rollen: Array = []
	for ruw in Data.SFEER:
		rollen.append(str(ruw["rol"]))
	rollen.append("gerrit")
	rollen.sort()
	var verwacht: Array = ["echtpaar", "echtpaar", "gerrit", "kind", "koerier", "veteraan"]
	check("zes sfeerrollen", rollen == verwacht)
	var lopers := 0
	for ruw in Data.SFEER:
		var rij: Dictionary = ruw
		var geldig := Data.lus_geldig(rij)
		if geldig:
			lopers += 1
		check("lus %s minstens 2 tegels" % str(rij["node"]), geldig and Data.lus_tegels(rij).size() >= 2)
	check("vijf lopers hebben een lus", lopers == 5 and Data.lussen_vrij())
	check("winkels zonder klok", Data.geen_klok() and Data.ALTIJD_OPEN)
	check("korte zwaard houdt de databronprijs", Shop.list_price("kort_zwaard") == int(GD.EQUIPMENT["kort_zwaard"]["price"]))
	check("kruiden blijven 20 goud", Shop.list_price("kruidenthee") == 20)
	check("Gerrit-citaat blijft de canonzin", SD.QUOTE_GRAAN_BEZOEK == "Oh, a visitor. Sit down, lad. Or stay standing — doesn't matter. The mill doesn't turn anymore anyway."
			and SD.GERRIT == "Garrett the Miller")
	for doel in [Data.voor_tegel(Data.pand("pantser")), Data.voor_tegel(Data.pand("wapen")),
			Data.voor_tegel(Data.pand("accessoire")), Data.voor_tegel(Data.pand("magie")),
			Data.voor_tegel(Data.pand("mien")), Data.voor_tegel(Data.pand("echtpaar")),
			Data.voor_tegel(Data.pand("dicht_west")), Data.voor_tegel(Data.pand("burgemeester"))]:
		check("deur bereikbaar %s" % str(doel), Data.bereikbaar(Data.SPAWN_TEGEL, doel))
	check("bronnen noemen geen tijdsysteem", _zonder_klok("res://scripts/data/wilgendal_dorp.gd")
			and _zonder_klok("res://scripts/village/dorp_opbouw.gd")
			and _zonder_klok("res://scripts/village/pand_binnen.gd"))


func _art() -> void:
	for pad in ART:
		var maat: Vector2i = ART[pad]
		var tex := load(pad) as Texture2D
		var ok := tex != null and tex.get_width() == maat.x and tex.get_height() == maat.y
		if ok:
			var img := tex.get_image()
			var hoek := img.get_pixel(0, 0)
			var inkt := img.get_pixel(2, 2)
			# v0.21: echte art van RPG ART (batch 13): geen magenta placeholder-hoek meer, wel in handwerk.txt
			ok = not (hoek.r > 0.9 and hoek.g < 0.15 and hoek.b > 0.9 and inkt.r > 0.9 and inkt.g > 0.8) \
					and FileAccess.get_file_as_string("res://tools/handwerk.txt").contains(pad.trim_prefix("res://"))
		check("echte art %s %dx%d" % [pad.get_file(), maat.x, maat.y], ok)


func _wereld() -> void:
	var tekst := FileAccess.get_file_as_string(WERELD)
	var dorp_y := _tscn_y(tekst, "NaarWilgendal")
	var trap_y := _tscn_y(tekst, "Trap")
	check("Willowdale blijft op de wereldkaart", tekst.contains("target_map = \"res://scenes/maps/dorp_wilgendal.tscn\"")
			and tekst.contains("target_spawn = \"zuid_ingang\""))
	check("archieftrap ligt ten zuiden van Willowdale", dorp_y >= 0.0 and trap_y > dorp_y)
	check("codex-bibliotheek bestaat nog", ResourceLoader.exists(BIEB))


func _tscn_y(tekst: String, node_naam: String) -> float:
	var kop := "[node name=\"%s\"" % node_naam
	var vanaf := tekst.find(kop)
	if vanaf < 0:
		return -1.0
	var stuk := tekst.substr(vanaf, 240)
	var regel := stuk.find("position = Vector2(")
	if regel < 0:
		return -1.0
	var rest := stuk.substr(regel + "position = Vector2(".length())
	var komma := rest.find(",")
	var eind := rest.find(")")
	if komma < 0 or eind < 0:
		return -1.0
	return float(rest.substr(komma + 1, eind - komma - 1).strip_edges())


func _dorp() -> void:
	var dorp := await enter(DORP, "zuid_ingang")
	check("dorp geladen", dorp != null and dorp.name == "DorpWilgendal" and dorp.encounters == false)
	if dorp == null:
		return
	var uit: Node = dorp.get_node("Exits/NaarWereld")
	check("uitgang naar de wereld blijft zuid", uit.target_map == WERELD and uit.target_spawn == "van_wilgendal"
			and uit.tile_rect().position.y == Data.H - 1)
	check("geen uitgang naar de bibliotheek", dorp.get_node("Exits").get_children().all(func(e):
		return str(e.target_map) != BIEB))
	var g: Node = dorp.get_node("Objects/Gerrit")
	check("Garrett staat bij de molen", g != null and g.npc_name == SD.GERRIT and g.lines.is_empty()
			and g.event == "gerrit" and g.get_tile() == Data.GERRIT_TEGEL
			and str(g.get_meta("rol")) == "gerrit")
	var molen: Node = dorp.get_node("Objects/MolenWieken")
	check("reuzenmolen op zijn plek (linksonder van de basis, y-sort op de onderrand)", molen != null and molen.position == Data.molen_positie()
			and molen.get_node("Basis").position == Vector2(0, -320) and molen.sprite.z_index == 1)
	var rollen: Array = []
	var winkel_op_plein := false
	for kind in dorp.get_node("Objects").get_children():
		if kind.get_meta("rol", "") != "":
			rollen.append(str(kind.get_meta("rol")))
		if str(kind.get("event")) == "shop":
			winkel_op_plein = true
	rollen.sort()
	check("zes sfeer-NPC's in het dorp", rollen == ["echtpaar", "echtpaar", "gerrit", "kind", "koerier", "veteraan"])
	check("shopkeepers niet op het plein", not winkel_op_plein
			and dorp.get_node_or_null("Objects/JelleWapen") == null
			and dorp.get_node_or_null("Objects/JellePantser") == null
			and dorp.get_node_or_null("Objects/TanteMien") == null
			and dorp.get_node_or_null("Objects/Magie") == null
			and dorp.get_node_or_null("Objects/Accessoire") == null)
	for id in ["pantser", "wapen", "accessoire", "magie"]:
		var deur: Node = dorp.get_node("Objects/Deur_%s" % id)
		var bord: Node = dorp.get_node("Objects/Uithang_%s" % id)
		check("winkeldeur %s" % id, deur.target_map == BINNEN and deur.target_spawn == id and str(deur.event) == "")
		check("icoon %s is %s" % [id, Data.ICOON_VAN_WINKEL[id]], bord.icoon == Data.ICOON_VAN_WINKEL[id]
				and bord.winkel_id == id)
	for id in ["mien", "echtpaar"]:
		var deur: Node = dorp.get_node("Objects/Deur_%s" % id)
		check("bewoond huis %s gaat open" % id, deur.target_map == BINNEN and deur.target_spawn == id)
	for id in ["dicht_west", "burgemeester"]:
		var deur: Node = dorp.get_node("Objects/Deur_%s" % id)
		var zin := str(Data.pand(id)["dicht"])
		check("dichte deur %s" % id, deur.target_map == "" and deur.lines.size() == 1 and deur.lines[0] == zin)
		deur.bump(dorp.get_node("Objects/Player"))
		await get_tree().process_frame
		check("dichte deur zegt Nederlands", Dialog.is_open and Dialog.text_label.text == zin)
		Dialog.close()
	var bram: Node = dorp.get_node("Objects/Bram")
	var els: Node = dorp.get_node("Objects/Els")
	check("echtpaar praat Nederlands", bram.npc_name == "Bramwell" and els.npc_name == "Elsie"
			and bram.lines[0] != "" and els.lines[0] != "")
	check("kind veteraan en koerier hebben een praatje", dorp.get_node("Objects/Fien").lines[0] != ""
			and dorp.get_node("Objects/Wout").lines[0] != ""
			and dorp.get_node("Objects/Siem").lines[0] != "")
	var props := 0
	for kind in dorp.get_node("Objects").get_children():
		if str(kind.get_meta("prop", "")) != "":
			props += 1
	var verwacht := 0
	for ruw in Data.PROPS:
		if not (Data.som() and Data.hek_prop(ruw)):
			verwacht += 1
	check("props in de scène (%d; SoM-hekken zijn grondtegels)" % props, props == verwacht)
	if Data.som():
		await _som_pilot(dorp)
	else:
		check("beek + brug op een eigen laag", dorp.get_node_or_null("Ground/Beek/Brug") != null)
	await _overzicht(dorp)
	await _molen(dorp)
	await _rondlopen(dorp)


## v3: reuzenmolen. Stille wieken tot de quest van Gerrit klaar is (zingend_graan_klaar), dan draaiend.
## Achter (noord van) de molen kun je lopen; alleen de voet botst; de toren tekent over de speler.
func _molen(dorp: Node) -> void:
	var molen: Node = dorp.get_node("Objects/MolenWieken")
	var Wk := preload("res://scripts/village/molen_wieken.gd")
	var vlag := "zingend_graan_klaar"
	var had := GameState.story_flags.has(vlag)
	GameState.story_flags.erase(vlag)
	molen.story_refresh()
	check("wieken stil vóór de quest van Garrett", molen.stil() and not molen.draait()
			and molen.sprite.texture == Wk.wieken_stil() and molen.sprite.hframes == 1)
	GameState.story_flags[vlag] = true
	molen.story_refresh()
	var f0: int = molen.frame_nu()
	await get_tree().create_timer(0.5).timeout
	check("na de quest: draaiende wieken (4 frames, 5 fps)", not molen.stil() and molen.draait()
			and molen.sprite.texture == Wk.wieken_sheet() and molen.sprite.hframes == 4 and molen.frame_nu() != f0)
	GameState.story_flags.erase(vlag)
	if had:
		GameState.story_flags[vlag] = true
	molen.story_refresh()
	check("wieken boven de speler (z+1), naaf op (112,112) van de basis", molen.sprite.z_index == 1
			and molen.sprite.position == Vector2(112, 112 - 320))
	var o := Data.MOLEN_OORSPRONG
	var achter_ok := true
	for x in range(o.x, o.x + Data.MOLEN_MAAT.x):
		for y in range(o.y + 1, Data.BEEK_RIJ):
			achter_ok = achter_ok and Data.beloopbaar(Vector2i(x, y))
	check("molen steekt uit over de beek, achter de molen vrij lopen, alleen de voet botst", achter_ok
			and Data.BEEK_RIJ > o.y and Data.BEEK_RIJ < o.y + 17
			and not Data.beloopbaar(o + Vector2i(6, 19)) and not Data.beloopbaar(o + Vector2i(2, 17))
			and Data.bereikbaar(Data.SPAWN_TEGEL, o + Vector2i(6, 10))
			and Data.bereikbaar(Data.SPAWN_TEGEL, Data.MOLEN_DEUR[0] + Vector2i.DOWN))
	var bg := Data.pand("burgemeester")
	check("burgemeestershuis 7x6, botst alleen op de onderste 3 rijen, dubbele deur op (3,5)", bg.get("tex") == "burgemeester"
			and Data.pand_blok(bg) == Rect2i(bg["oorsprong"] + Vector2i(0, 3), Vector2i(7, 3))
			and bg["deur"] == bg["oorsprong"] + Vector2i(3, 5) and Data.beloopbaar(bg["oorsprong"] + Vector2i(3, 1))
			and Data.bereikbaar(Data.SPAWN_TEGEL, Data.voor_tegel(bg)))
	var p: Node2D = dorp.get_node("Objects/Player")
	var oud := p.position
	p.position = Vector2(o + Vector2i(6, 12)) * 16.0 + Vector2(8, 8)
	var achter := p.position.y < (molen as Node2D).position.y
	await get_tree().process_frame
	p.position = Vector2(Data.MOLEN_DEUR[0] + Vector2i.DOWN) * 16.0 + Vector2(8, 8)
	check("y-sort: achter de molen verdwijnt de speler, ervoor staat hij voor de molen", achter
			and p.position.y > (molen as Node2D).position.y)
	p.position = oud


func _rondlopen(dorp: Node) -> void:
	if Dialog.is_open:
		Dialog.close()
	var gerrit: Node = dorp.get_node_or_null("Objects/Gerrit")
	check("quest-node Gerrit bestaat nog", gerrit != null and gerrit.event == "gerrit" and gerrit.name == "Gerrit")
	if gerrit == null:
		return
	var vast: Vector2 = gerrit.position
	var voor := {}
	for naam in ["Bram", "Els", "Fien", "Wout", "Siem"]:
		var npc: Node = dorp.get_node("Objects/%s" % naam)
		var loper := npc.get_node_or_null("PleinLus")
		var n := 0
		if loper != null:
			n = loper.lus.size()
		check("%s loopt een lus van minstens 2 tegels" % naam, n >= 2)
		voor[naam] = npc.position
	check("Gerrit heeft geen lus", gerrit.get_node_or_null("PleinLus") == null)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		await get_tree().process_frame
	for naam in ["Bram", "Els", "Fien", "Wout", "Siem"]:
		var npc: Node = dorp.get_node("Objects/%s" % naam)
		var loper := npc.get_node_or_null("PleinLus")
		var tegel: Vector2i = npc.get_tile()
		var op_lus := false
		if loper != null:
			op_lus = tegel in loper.lus
		check("%s loopt zijn rondje" % naam, loper != null and op_lus and Data.beloopbaar(tegel)
				and tegel != Data.GERRIT_TEGEL and not Data.MOLEN.has_point(tegel)
				and npc.position.distance_to(voor[naam]) > 6.0)
	check("Garrett blijft op de molentegel", gerrit.get_tile() == Data.GERRIT_TEGEL
			and gerrit.position.distance_to(vast) < 0.5
			and dorp.get_node_or_null("Objects/Gerrit") == gerrit)


## Kleed 3x3 in binnen_v8.png = vakken 12-20 (q w e / a m f / z x c): elk vak heeft een teken in BINNEN, en elk
## kleed in KAMERS heeft geen gat (onderrij z?c heeft x in het midden).
func _kamer_shot(naam: String) -> void:
	var map := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			map = a.get_slice("=", 1)
	if map == "":
		return
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(map.path_join(naam + ".png"))
	print("INFO  screenshot: ", map.path_join(naam + ".png"))


func _kleed_vakken() -> void:
	const PB := preload("res://scripts/village/pand_binnen.gd")
	var vakken: Array = PB.BINNEN.values()
	var mis := []
	for n in range(12, 21):
		if not vakken.has(n):
			mis.append(n)
	check("kleed: elk vak 12-20 heeft een teken in BINNEN (mist %s)" % [mis], mis.is_empty() and PB.BINNEN.get("x", -1) == 19)
	var gat := ""
	for id in Data.KAMERS:
		for regel in Data.KAMERS[id]:
			var r := str(regel)
			var z := r.find("z")
			if z >= 0 and z + 2 < r.length() and r[z + 2] == "c" and r[z + 1] != "x":
				gat += "%s '%s'; " % [id, r]
	check("kleed: geen gat in de onderrij (%s)" % (gat if gat != "" else "ok"), gat == "")


func _panden() -> void:
	var sfeer_tegel := {
		"pantser": Vector2i(1, 1),
		"wapen": Vector2i(7, 2),
		"accessoire": Vector2i(3, 1),
		"magie": Vector2i(2, 1),
	}
	var sfeer_atlas := {"pantser": 4, "wapen": 9, "accessoire": 12, "magie": 21}
	for id in ["pantser", "wapen", "accessoire", "magie", "mien", "echtpaar"]:
		var kamer := await enter(BINNEN, id)
		var rij: Dictionary = Data.pand(id)
		check("binnen %s" % id, kamer != null and kamer.map_name == str(rij["map_naam"]) and kamer.encounters == false)
		if kamer == null:
			continue
		# v8: geen sfeertint meer, binnen.tres = binnen_v8.png
		check("v8 zonder tint %s (binnen_v8.png)" % id, kamer.get_node("Ground").modulate.is_equal_approx(Color(1, 1, 1))
				and (kamer.get_node("Ground").tile_set.get_source(0) as TileSetAtlasSource).texture.resource_path.ends_with("binnen_v8.png"))
		var uit: Node = kamer.get_node("Exits/NaarDorp")
		check("deur terug %s" % id, uit.target_map == DORP and uit.target_spawn == Data.voor_spawn(id))
		if id == "accessoire":
			await _kamer_shot("binnen_v8_accessoire")
		if id in sfeer_atlas:
			var tegel: Vector2i = sfeer_tegel[id]
			var atlas: Vector2i = kamer.get_node("Ground").get_cell_atlas_coords(tegel)
			check("eigen interieur %s" % id, atlas.x == int(sfeer_atlas[id]))
		if str(rij["shop_id"]) != "":
			var man: Node = kamer.get_node("Objects/Winkelier")
			var bank: Node = kamer.get_node("Objects/Toonbank")
			var bank_tegel: Vector2i = bank.get_meta("tegel")
			check("winkelier achter de toonbank %s" % id, man.npc_name == str(rij["keeper_naam"])
					and man.event == "shop" and man.event_arg == str(rij["shop_id"])
					and man.get_tile().y < bank_tegel.y and man.get_tile().x == bank_tegel.x)
			check("vitrine %s" % id, kamer.get_node_or_null("Objects/Vitrine") != null)
			bank.interact(kamer.get_node("Objects/Player"))
			await get_tree().process_frame
			var scherm := kamer.get_node_or_null("ShopScreen")
			check("winkel open %s" % id, scherm != null and scherm.shop_id == str(rij["shop_id"])
					and scherm.header.text == Shop.shop_name(str(rij["shop_id"])))
			if scherm != null:
				scherm.close()
				await get_tree().process_frame
		else:
			check("huis zonder winkelier", kamer.get_node_or_null("Objects/Winkelier") == null
					and kamer.get_node("Objects/Bord").lines[0] == str(rij["bord"]))
	var terug := await enter(DORP, "voor_pantser")
	check("terug voor de pantserdeur", terug != null and terug.get_node("Objects/Player").get_tile() == Data.voor_tegel(Data.pand("pantser")))


func _zonder_klok(pad: String) -> bool:
	var bestand := FileAccess.open(pad, FileAccess.READ)
	if bestand == null:
		return false
	var tekst := bestand.get_as_text()
	return not tekst.contains("Time.get_datetime") and not tekst.contains("OS.get_time") and not tekst.contains("uur_open")


func scene() -> Node:
	return get_tree().current_scene


func enter(pad: String, spawn: String) -> Node:
	if Dialog.is_open:
		Dialog.close()
	GameState.change_map(pad, spawn)
	if not await _wacht(_node_naam(pad)):
		return null
	await _fade()
	return scene()


func _node_naam(pad: String) -> String:
	var uit := ""
	for deel in pad.get_file().get_basename().split("_"):
		uit += deel.capitalize().replace(" ", "")
	return uit


func _wacht(naam: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == naam and s.is_node_ready() and not GameState.changing_map:
			await get_tree().process_frame
			await get_tree().process_frame
			return true
		await get_tree().process_frame
	return false


func _fade() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000.0:
		if Transition._rect.color.a <= 0.01:
			break
		await get_tree().process_frame
	await get_tree().process_frame


## Overzichtsfoto van het hele dorp (camera uitgezoomd).
func _overzicht(dorp: Node) -> void:
	var shots := OS.get_environment("WILGENDAL_SHOTS")
	if shots == "":
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var keep_zoom := cam.zoom
	var keep_pos := cam.global_position
	var keep_smooth := cam.position_smoothing_enabled
	cam.position_smoothing_enabled = false
	var vp := get_viewport().get_visible_rect().size
	var z := minf(vp.x / (Data.W * 16.0), vp.y / (Data.H * 16.0))
	cam.zoom = Vector2(z, z)
	cam.limit_left = -10000; cam.limit_top = -10000; cam.limit_right = 10000; cam.limit_bottom = 10000
	cam.top_level = true
	cam.global_position = Vector2(Data.W, Data.H) * 8.0
	for _i in 8:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(shots.path_join("wilgendal_nieuw.png"))
	cam.top_level = false
	cam.zoom = keep_zoom
	cam.position_smoothing_enabled = keep_smooth
	cam.position = Vector2.ZERO
	dorp.get_node("Objects/Player").set_camera_limits(Rect2i(0, 0, Data.W * 16, Data.H * 16))
	for _i in 4:
		await get_tree().process_frame


## SoM-voorbereiding (Dennis 14 okt 2026): 24x32-kaartsprites, slot-tilesets per gebied, stijl per gebied.
## Fase 3: Wilgendal in SoM-stijl (live dorp).
func _som_pilot(dorp: Node) -> void:
	var g: TileMapLayer = dorp.get_node("Ground")
	check("som: grond = fase-1 terrain-tileset", g.has_meta("som_klaar")
			and g.tile_set.resource_path == KaartStijl.tileset_pad("wilgendal", "terrain"))
	var namen: Dictionary = g.namen
	var w := Vector2i(10, Data.BEEK_RIJ)
	var wc: Array = g.water_anim.get("water_068", [-1, -1])
	check("som: beek = geanimeerd water blob47 (E+W = 068, bron 1) en botst", g.get_cell_source_id(w) == 1
			and g.get_cell_atlas_coords(w) == Vector2i(int(wc[0]), int(wc[1]))
			and g.get_cell_tile_data(w).get_collision_polygons_count(0) > 0 and not Data.beloopbaar(w))
	var wbron := g.tile_set.get_source(1) as TileSetAtlasSource
	var wt := Vector2i(int(wc[0]), int(wc[1]))
	check("som: water 4 frames, ~5 fps, kolommen 0, separatie (7,0)", wbron != null
			and wbron.get_tile_animation_frames_count(wt) == 4 and wbron.get_tile_animation_columns(wt) == 0
			and wbron.get_tile_animation_separation(wt) == Vector2i(7, 0) and is_equal_approx(wbron.get_tile_animation_speed(wt), 5.0))
	var props_ok := true
	var n_som := 0
	for i in Data.PROPS.size():
		var rij: Dictionary = Data.PROPS[i]
		if Data.hek_prop(rij):
			props_ok = props_ok and dorp.get_node_or_null("Objects/Prop_%s_%d" % [str(rij["tex"]), i]) == null
			continue
		var body: Node = dorp.get_node_or_null("Objects/Prop_%s_%d" % [str(rij["tex"]), i])
		var sp := Data.som_prop(rij)
		if body == null:
			props_ok = false
		elif not sp.is_empty():
			n_som += 1
			var b: Rect2i = sp["blok"]
			props_ok = props_ok and body.get_meta("som_prop") == sp["naam"] and (body as Node2D).position == sp["voet"]
			props_ok = props_ok and not Data.beloopbaar(b.position) and Data.prop_blok(rij) == b
	check("som: fase-3 props (put, kramen, lantaarns, bank, bloembak) met botsing/y-sort uit de index (%d)" % n_som,
			props_ok and n_som == 17)
	var npc_ok := true
	for naam in ["Gerrit", "Bram", "Els", "Fien", "Wout", "Siem"]:
		var spr: Sprite2D = dorp.get_node("Objects/%s/Sprite2D" % naam)
		npc_ok = npc_ok and spr.texture.resource_path == Data.som_npc_sheet(naam)
		npc_ok = npc_ok and spr.hframes == 3 and spr.vframes == 4 and spr.offset == Vector2(0, -8)
	check("som: fase-3 NPC-sheets 24x32 (Gerrit, Bram, Els, Fien, Wout, Siem)", npc_ok)
	check("som: slanke WM1-NPC's (20 okt): Gerrit = gerrit_wm1_slim_v2.png (stapframes-fix; handwerk blijft), Bram = bram.png (vervangen)",
			Data.som_npc_sheet("Gerrit").ends_with("npcs/gerrit_wm1_slim_v2.png")
			and Data.som_npc_sheet("Bram").ends_with("npcs/bram.png")
			and Data.som_npc_sheet("OudeMan").ends_with("npcs/oude_man_wm1_slim.png"))
	var ov: TileMapLayer = dorp.get_node("Ground/SomOverlay")
	var bm: Array = namen["brug_v_m"]
	check("som: brug over de beek beloopbaar", ov.get_cell_atlas_coords(Vector2i(Data.BRUG.position.x, Data.BEEK_RIJ)) == Vector2i(int(bm[0]), int(bm[1]))
			and Data.beloopbaar(Vector2i(Data.BRUG.position.x, Data.BEEK_RIJ)) and dorp.get_node_or_null("Ground/Beek/Brug") == null)
	var pad := Vector2i(14, 16)
	check("som: pad met autotile-masker", g.get_cell_tile_data(pad).get_custom_data("terrain").begins_with("pad_"))
	check("som: kegelbomen op de rand", dorp.get_node("Objects/SomBomen").get_child_count() > 150)
	var v8: TileMapLayer = dorp.get_node_or_null("Ground/SomV8")
	var v8tex: Texture2D = v8.tile_set.get_source(0).texture if v8 != null else null
	check("som: v8-grond (RPG ART) over de hele kaart, atlas <= 2048x2048, beek blijft geanimeerd water",
			v8 != null and v8tex != null and v8tex.get_width() <= 2048 and v8tex.get_height() <= 2048
			and v8.get_used_cells().size() == Data.W * Data.H - Data.W + Data.BRUG.size.x
			and v8.get_cell_source_id(Vector2i(10, Data.BEEK_RIJ)) == -1 and v8.get_cell_source_id(pad) == 0)
	var ok := true
	for ruw in Data.PANDEN:
		var rij: Dictionary = Data.som_pand(ruw)
		var body: Node = dorp.get_node("Objects/Pand_%s" % rij["id"])
		var tex: Texture2D = body.get_child(1).texture
		if str(rij["id"]) == "burgemeester":
			ok = ok and not rij.has("som_tex") and tex.resource_path.ends_with("burgemeestershuis.png")
		elif Data.P10_HUIZEN.has(str(rij["id"])):
			# Plein 10 (art_10): nieuwe panden, zelfde deur, dak beloopbaar, muur botst
			var p10: Dictionary = Data.P10_HUIZEN[str(rij["id"])]
			ok = ok and tex.resource_path == rij["som_tex"] and rij["deur"] == ruw["deur"]
			ok = ok and tex.get_size() == Vector2(p10["maat"]) * 16.0 and Data.pand_blok(ruw).size.y == int(p10["muur_rijen"])
			ok = ok and Data.beloopbaar(rij["oorsprong"] + Vector2i(1, 1)) and not Data.beloopbaar(ruw["deur"] + Vector2i.UP)
		else:
			ok = ok and rij.has("som_tex") and tex.resource_path == rij["som_tex"] and rij["deur"] == ruw["deur"]
			ok = ok and tex.get_size() == Vector2(rij["maat"]) * 16.0 and Data.pand_blok(ruw).size.y == 3 and rij["maat"].x == 6
			ok = ok and Data.beloopbaar(rij["oorsprong"] + Vector2i(1, rij["maat"].y - 4)) and not Data.beloopbaar(ruw["deur"] + Vector2i.UP)
	check("som: huizen uit fase 1 / plein 10 (zelfde deur, dak beloopbaar), burgemeestershuis blijft", ok)
	var molen: Node = dorp.get_node("Objects/MolenWieken")
	check("som: molen v2 blijft (positie, stille wieken tot Garrett)", molen.position == Data.molen_positie()
			and molen.get_node_or_null("Basis") != null)
	var sp: Sprite2D = dorp.get_node("Objects/Player/Sprite2D")
	check("som: speler = fase-2 heldsheet 24x32 (%s)" % sp.texture.resource_path,
			sp.texture.resource_path.begins_with("res://assets/sprites/som/kaart/")
			and sp.hframes == 3 and sp.vframes == 4 and sp.offset == Vector2(0, -8))
	check("som: Dax/Seren in WM1 (slanke sheets 20 okt), WM2 in de wacht", sp.texture.resource_path.ends_with("dax_wm1_slim.png")
			and KaartStijl.gebieden()["wilgendal"]["held_variant"] == "wm1_slim"
			and ResourceLoader.exists("res://assets/sprites/som/kaart/seren_wm1_slim.png")
			and ResourceLoader.exists("res://assets/sprites/som/kaart/vesper_wm1_slim.png")
			and ResourceLoader.exists("res://assets/sprites/som/kaart/seren_wm1.png")
			and ResourceLoader.exists("res://assets/sprites/som/kaart/vesper.png")
			and not ResourceLoader.exists("res://assets/sprites/som/kaart/dax_wm2.png")
			and not ResourceLoader.exists("res://assets/sprites/som/kaart/seren_wm2.png"))
	await _hekken(dorp, g, ov)


## Fase 4: SoM-hekken (autotiles uit hekken.png, bron 2), botsing en poorten.
func _hekken(dorp: Node, g: TileMapLayer, ov: TileMapLayer) -> void:
	var hn: Dictionary = g.hekken
	var bron := g.tile_set.get_source(2) as TileSetAtlasSource
	check("som: hekken-bron 2 in terrain.tres (256x32, 22 tegels, namen)", bron != null and hn.size() == 22
			and bron.texture.get_size() == Vector2(256, 32) and hn.has("hek_10") and hn.has("hek_poort_h_open"))
	var poorten := Data.poorten()
	check("som: 2 poorten (west hek, tuin), oude hek-props weg", poorten.size() == 2 and Data.hek_prop(Data.PROPS[Data.PROPS.size() - 1]))
	var ok := true
	var n := 0
	for y in Data.H:
		for x in Data.W:
			var t := Vector2i(x, y)
			if not Data.hek_aanwezig(t):
				continue
			n += 1
			var naam := Data.hek_tegel(t)
			var c: Array = hn[naam]
			ok = ok and ov.get_cell_source_id(t) == 2 and ov.get_cell_atlas_coords(t) == Vector2i(int(c[0]), int(c[1]))
			ok = ok and Data.hek_blok(t) == (ov.get_cell_tile_data(t).get_collision_polygons_count(0) > 0)
			ok = ok and not Data.beloopbaar(t) and ov.get_cell_tile_data(t).get_custom_data("terrain").begins_with("hek_")
	check("som: elk hek-teken (%d) = hek-tegel met masker, botsing zoals Data.hek_blok, niet beloopbaar" % n, ok and n > 20)
	var e := Vector2i(21, 24)
	var m := Vector2i(22, 24)
	var h := Vector2i(9, 35)
	check("som: masker N1 E2 S4 W8: einde (E)=hek_02, midden=hek_10(_b), hoek NW=hek_06 (SE)", Data.hek_masker(e) == 2 and Data.hek_tegel(e) == "hek_02"
			and Data.hek_masker(m) == 10 and Data.hek_tegel(m).begins_with("hek_10")
			and Data.hek_masker(h) == 6 and Data.hek_tegel(h) == "hek_06" and Data.hek_masker(Vector2i(9, 36)) == 5)
	var p0: Vector2i = poorten[0]
	var gate: Node = dorp.get_node_or_null("Objects/Poort_%d_%d" % [p0.x, p0.y])
	var dicht := not Data.beloopbaar(p0) and ov.get_cell_atlas_coords(p0) == Vector2i(int(hn["hek_poort_h_dicht"][0]), int(hn["hek_poort_h_dicht"][1]))
	dicht = dicht and ov.get_cell_tile_data(p0).get_collision_polygons_count(0) > 0
	check("som: poort start dicht (tegel hek_poort_h_dicht, botst)", gate != null and dicht)
	if gate == null:
		return
	gate.interact(null)
	var open := Data.beloopbaar(p0) and ov.get_cell_atlas_coords(p0) == Vector2i(int(hn["hek_poort_h_open"][0]), int(hn["hek_poort_h_open"][1]))
	open = open and ov.get_cell_tile_data(p0).get_collision_polygons_count(0) == 0
	check("som: poort open = tegel hek_poort_h_open, geen botsing, beloopbaar", open and gate.is_open())
	gate.interact(null)
	check("som: poort weer dicht", not Data.beloopbaar(p0) and not gate.is_open()
			and ov.get_cell_tile_data(p0).get_collision_polygons_count(0) > 0)
	var tuin := Vector2i(11, 36)
	var poort2: Vector2i = poorten[1]
	gate = dorp.get_node("Objects/Poort_%d_%d" % [poort2.x, poort2.y])
	var voor := poort2 + Vector2i.DOWN
	check("som: tuin: binnen onbereikbaar bij dichte poort", not Data.bereikbaar(voor, tuin) and Data.beloopbaar(tuin))
	gate.interact(null)
	check("som: tuin: met open poort bereikbaar", Data.bereikbaar(voor, tuin))
	gate.interact(null)
	check("som: hekken-resources bestaan (hekken.png, namen)", ResourceLoader.exists("res://assets/tilesets/som/wilgendal/hekken.png")
			and FileAccess.file_exists("res://assets/tilesets/som/wilgendal/hekken_namen.json"))


func _som() -> void:
	const DAX := "res://assets/sprites/som/kaart/dax_wm1.png"
	const PROEF := "res://tools/som/test/uit/"
	# oude sprites blijven precies zoals ze waren
	var speler: Node = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(speler)
	var spr: Sprite2D = speler.sprite
	check("oude spelersprite ongewijzigd (3x4 van 16x24, offset -4)", spr.hframes == 3 and spr.vframes == 4
			and spr.offset == Vector2(0, -4) and MapSprite.frame_maat(spr.texture) == MapSprite.OUD)
	# Dax WM1 (24x32-sheet 72x128) via zet_sheet: voeten op de tegelrand, botsing blijft 14x14
	speler.zet_sheet(load(DAX))
	var vorm := (speler.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check("Dax WM1 24x32: 3x4 frames, voeten op +8, botsing 14x14 aan de voeten", spr.hframes == 3 and spr.vframes == 4
			and is_equal_approx(spr.offset.y + 16.0, 8.0) and vorm.size == Vector2(14, 14)
			and (speler.get_node("CollisionShape2D") as Node2D).position == Vector2.ZERO
			and MapSprite.frame_maat(spr.texture) == MapSprite.NIEUW)
	speler.facing = Vector2i.UP
	speler._update_sprite()
	check("richting omhoog kiest rij 3 van de sheet", spr.frame >= 9 and spr.frame <= 11)
	# één los frame (24x32, in het geheugen): geen loop- of richtingsanimatie
	speler.zet_sheet(ImageTexture.create_from_image(Image.create(24, 32, false, Image.FORMAT_RGBA8)))
	speler._update_sprite()
	check("los frame 24x32: één frame, voeten op +8, richting kiest geen ongeldig frame", spr.hframes == 1
			and spr.vframes == 1 and is_equal_approx(spr.offset.y + 16.0, 8.0) and spr.frame == 0)
	speler.queue_free()
	# 20 okt 2026: slanke WM1-NPC-sheets. Voeten op de onderste rij van elk frame, zodat offset -8 ze op de tegelrand zet.
	var voeten_ok := true
	var slank := ["som/wilgendal/npcs/oude_man_wm1_slim", "som/wilgendal/npcs/gerrit_wm1_slim", "som/wilgendal/npcs/henrik_wm1_slim",
			"npc_wm1_slim", "buiten/bouw_werker_wm1_slim", "som/wilgendal/npcs/gerrit_wm1_slim_v2",
			"buiten/waard", "buiten/bouw_werker_b", "buiten/bouw_werker_c"]
	for id in ["bram", "els", "fien", "wout", "siem", "mien", "jelle", "magier", "accessoire"]:
		slank.append("som/wilgendal/npcs/" + id)
	for id in slank:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % id)
		var im := tex.get_image() if tex != null else null
		voeten_ok = voeten_ok and im != null and im.get_size() == Vector2i(72, 128)
		if im == null:
			continue
		if im.is_compressed():
			im.decompress()
		for rij in 4:
			var r := im.get_region(Rect2i(0, rij * 32, 24, 32)).get_used_rect()
			voeten_ok = voeten_ok and r.end.y == 32
	check("slanke WM1-NPC-sheets 72x128, voeten op de onderrand van elk staand frame", voeten_ok)
	check("npc_variant wm1_slim: npc.png -> npc_wm1_slim.png, sheet zonder variant blijft",
			KaartStijl.npc_sheet_pad("res://assets/sprites/npc.png") == "res://assets/sprites/npc_wm1_slim.png"
			and KaartStijl.npc_sheet_pad("res://assets/sprites/buiten/bouw_werker.png") == "res://assets/sprites/buiten/bouw_werker_wm1_slim.png"
			and KaartStijl.npc_sheet_pad("res://assets/sprites/som/wilgendal/npcs/marit.png") == "res://assets/sprites/som/wilgendal/npcs/marit.png"
			and KaartStijl.npc_sheet_pad("res://assets/sprites/npc_wm1_slim.png") == "res://assets/sprites/npc_wm1_slim.png"
			and KaartStijl.npc_sheet_pad("res://assets/sprites/som/wilgendal/npcs/gerrit.png") == "res://assets/sprites/som/wilgendal/npcs/gerrit_wm1_slim_v2.png"
			and KaartStijl.npc_sheet_pad("res://assets/sprites/som/wilgendal/npcs/gerrit_wm1_slim_v2.png") == "res://assets/sprites/som/wilgendal/npcs/gerrit_wm1_slim_v2.png"
			and KaartStijl.npc_sheet_pad("res://assets/sprites/buiten/bouw_werker_b.png") == "res://assets/sprites/buiten/bouw_werker_b.png")
	var gen: Node = (load("res://scenes/npc.tscn") as PackedScene).instantiate()
	add_child(gen)
	var gs: Sprite2D = gen.get_node("Sprite2D")
	check("generieke NPC (npc.tscn) = npc_wm1_slim.png 3x4 van 24x32, voeten op +8", gs.texture.resource_path.ends_with("npc_wm1_slim.png")
			and gs.hframes == 3 and gs.vframes == 4 and gs.offset == Vector2(0, -8))
	gen.queue_free()
	var oud: Node = (load("res://scenes/npc.tscn") as PackedScene).instantiate()
	oud.sheet = load("res://assets/sprites/player.png")
	add_child(oud)
	var os_: Sprite2D = oud.get_node("Sprite2D")
	check("NPC met een oude 48x96-sheet zonder slanke variant blijft 3x4 van 16x24, offset -4",
			os_.texture.resource_path.ends_with("player.png") and os_.hframes == 3 and os_.vframes == 4 and os_.offset == Vector2(0, -4))
	oud.queue_free()
	# volledige 24x32-sheet (3 loopframes x 4 richtingen = 72x128)
	var img := Image.create(72, 128, false, Image.FORMAT_RGBA8)
	var sheet := ImageTexture.create_from_image(img)
	var s2 := Sprite2D.new()
	s2.texture = sheet
	var f := MapSprite.pas_toe(s2)
	MapSprite.zet_frame(s2, 2, 1)
	check("sheet 72x128 = 3x4 frames 24x32, offset -8, frame rij 2 kolom 1 = 7", f == MapSprite.NIEUW
			and s2.hframes == 3 and s2.vframes == 4 and s2.offset == Vector2(0, -8) and s2.frame == 7)
	s2.free()
	# stijl per gebied: de echte config is overal nog oud
	check("pilot: Wilgendal som, binnen + andere maps oud", KaartStijl.stijl("wilgendal") == KaartStijl.SOM
			and KaartStijl.is_som(DORP) and KaartStijl.gebied_van_map(DORP) == "wilgendal"
			and not KaartStijl.is_som(Data.BINNEN) and KaartStijl.gevraagd("") == KaartStijl.OUD
			and not KaartStijl.is_som("res://scenes/maps/wereldkaart.tscn"))
	# proef-config: som met complete art -> som; één tileset kwijt -> het HELE gebied oud
	KaartStijl.zet_config({"map": PROEF, "gebieden": {"proef_herfst": {"stijl": "som", "maps": ["dorp_wilgendal"],
			"tilesets": ["proef"], "speler": DAX}}})
	check("som-gebied met alle art -> som", KaartStijl.stijl_van_map(DORP) == KaartStijl.SOM
			and KaartStijl.ontbreekt("proef_herfst").is_empty())
	var kaart := Node2D.new()
	kaart.scene_file_path = DORP
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	kaart.add_child(ground)
	var objs := Node2D.new()
	objs.name = "Objects"
	kaart.add_child(objs)
	var p2: Node = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	p2.name = "Player"
	objs.add_child(p2)
	add_child(kaart)
	var toegepast := KaartStijl.toepassen(kaart)
	var ts := ground.tile_set
	var bron := ts.get_source(0) as TileSetAtlasSource if ts != null else null
	var water := bron.get_tile_data(Vector2i(2, 0), 0) if bron != null else null
	var gras := bron.get_tile_data(Vector2i(0, 0), 0) if bron != null else null
	check("toepassen: Ground krijgt de gebied-tileset, speler 24x32", toegepast and ts != null
			and ts.resource_path.ends_with("proef_herfst/proef.tres") and (p2.sprite as Sprite2D).hframes == 3
			and is_equal_approx((p2.sprite as Sprite2D).offset.y, -8.0))
	check("geëxporteerde tileset: 16px, botsing op solid, terreinnaam", bron != null
			and bron.texture_region_size == Vector2i(16, 16) and water != null and gras != null
			and water.get_collision_polygons_count(0) == 1 and gras.get_collision_polygons_count(0) == 0
			and str(water.get_custom_data("terrain")) == "water")
	var normaal: Texture2D = load(PROEF + "proef_normaal/proef.png")
	var herfst: Texture2D = load(PROEF + "proef_herfst/proef.png")
	check("paletvariant: herfst kleurt gras om, omlijning blijft", normaal.get_image().get_pixel(8, 8)
			!= herfst.get_image().get_pixel(8, 8) and normaal.get_image().get_pixel(0, 0) == herfst.get_image().get_pixel(0, 0))
	KaartStijl.zet_config({"map": PROEF, "gebieden": {"proef_herfst": {"stijl": "som", "maps": ["dorp_wilgendal"],
			"tilesets": ["proef", "bestaat_niet"], "speler": DAX}}})
	check("som-gebied met ontbrekende tileset -> hele gebied oud", KaartStijl.stijl_van_map(DORP) == KaartStijl.OUD
			and KaartStijl.ontbreekt("proef_herfst").size() == 1 and not KaartStijl.toepassen(kaart))
	KaartStijl.zet_config({})
	kaart.queue_free()
	await get_tree().process_frame


## --- Plein 10 (RPG ART art_10): plein, huis van Dax, brug ---
## Echt lopen (invoer, botsing via test_move) van de zuidingang naar de deur van Dax, naar binnen en terug,
## dan over de brug naar het plein. Elke deur en uitgang bereikbaar (geen soft lock) en de botsing van de
## scène klopt met Data.beloopbaar. Screenshots op native resolutie (--shots=map).
func _plein10() -> void:
	var dorp := await enter(DORP, "zuid_ingang")
	check("plein10: dorp geladen", dorp != null)
	if dorp == null:
		return
	check("plein10: grondlaag met keien, brug en schaduwen", dorp.get_node_or_null("Ground/Plein10/Keien") != null
			and dorp.get_node("Ground/Plein10/Keien").get_child_count() == Data.PLEIN.size.x * Data.PLEIN.size.y
			and dorp.get_node_or_null("Ground/Plein10/Brug10") != null
			and dorp.get_node("Ground/Plein10").get_index() > dorp.get_node("Ground/SomV8").get_index())
	# schaduw: zelfde linksboven-anker als het object, op de grondlaag (onder Objects)
	var sch: Node = dorp.get_node("Ground/Plein10/Schaduwen")
	var dax: Dictionary = Data.som_pand(Data.pand("dax"))
	var dax_s: Sprite2D = sch.get_node_or_null("huis_dax_11_schaduw")
	var dax_body: Node2D = dorp.get_node_or_null("Objects/Pand_dax")
	var dax_spr: Sprite2D = dax_body.get_child(1) if dax_body != null else null
	check("plein10: huis van Dax (huis_dax_11) met schaduw op hetzelfde linksboven-anker", dax_s != null and dax_spr != null
			and dax_spr.texture.resource_path.ends_with("huis_dax_11.png")
			and dax_s.position == dax_spr.global_position - dax_spr.texture.get_size() / 2.0
			and dax_s.position == Vector2(dax["oorsprong"]) * 16.0)
	var n_sch := 0
	var anker_ok := true
	for b in dorp.get_node("Objects/Bomen10").get_children():
		var spr: Sprite2D = b.get_node("Sprite")
		var s: Sprite2D = null
		for k in sch.get_children():
			if (k as Sprite2D).position == spr.global_position and k.name.begins_with(spr.texture.resource_path.get_file().get_basename()):
				s = k
		anker_ok = anker_ok and s != null
	for i in Data.PROPS.size():
		var rij: Dictionary = Data.PROPS[i]
		if not Data.P10_PROPS.has(str(rij["tex"])):
			continue
		var sp := Data.som_prop(rij)
		var body: Node2D = dorp.get_node("Objects/Prop_%s_%d" % [str(rij["tex"]), i])
		var spr: Sprite2D = body.get_child(0)
		var gevonden := false
		for k in sch.get_children():
			if k.name.begins_with(str(rij["tex"])) and (k as Sprite2D).position == spr.global_position:
				gevonden = true
		anker_ok = anker_ok and gevonden and spr.hframes == 3 and spr.global_position == Vector2(sp["links_boven"]) * 16.0
		n_sch += 1
	check("plein10: kramen (3 frames) en bomen hebben hun schaduw op hetzelfde anker (%d kramen)" % n_sch, anker_ok and n_sch == 3)
	var filter_ok := true
	for spr in dorp.find_children("*", "Sprite2D", true, false):
		if spr.texture != null and spr.texture.resource_path.contains("/plein10/"):
			var lb: Vector2 = spr.global_position
			if spr.centered:
				lb -= Vector2(spr.texture.get_width() / spr.hframes, spr.texture.get_height()) / 2.0
			filter_ok = filter_ok and spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and lb.round() == lb
	check("plein10: pixel-perfect (Nearest, hele pixels)", filter_ok)
	# botsing van de scène = Data.beloopbaar (huizen, bomen, kramen, put, beek dicht; brug open)
	var p: Node2D = dorp.get_node("Objects/Player")
	var ruimte := p.get_world_2d().direct_space_state
	var mis: Array = []
	var gebied := Rect2i(18, 4, 60, 38)
	for y in range(gebied.position.y, gebied.end.y):
		for x in range(gebied.position.x, gebied.end.x):
			var t := Vector2i(x, y)
			var q := PhysicsPointQueryParameters2D.new()
			q.position = Vector2(t) * 16.0 + Vector2(8, 8)
			q.collide_with_bodies = true
			q.collide_with_areas = false
			var dicht := false
			for hit in ruimte.intersect_point(q, 8):
				var c: Object = hit["collider"]
				if c is CharacterBody2D or c.get("npc_name") != null:
					continue
				dicht = true
			if dicht == Data.beloopbaar(t):
				mis.append(t)
	check("plein10: botsing klopt met de kaartdata rond plein, huizen en brug (verschil %s)" % [mis.slice(0, 6)], mis.is_empty())
	var b := Data.BRUG
	var brug_open := true
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			brug_open = brug_open and Data.beloopbaar(Vector2i(x, y))
	check("plein10: brug beloopbaar, beek ernaast niet", brug_open and not Data.beloopbaar(Vector2i(b.position.x - 1, Data.BEEK_RIJ))
			and not Data.beloopbaar(Vector2i(b.end.x, Data.BEEK_RIJ)))
	# elke warp (deur en uitgang) bereikbaar vanaf de ingang: geen soft lock
	var warps := 0
	var vast: Array = []
	for d in dorp.get_node("Objects").get_children():
		if not str(d.name).begins_with("Deur_"):
			continue
		warps += 1
		var voor: Vector2i = Vector2i((d.position / 16.0).floor()) + Vector2i.DOWN
		if not Data.bereikbaar(Data.SPAWN_TEGEL, voor):
			vast.append(str(d.name))
		elif str(d.target_map) != "" and not Data.bereikbaar(voor, Data.SPAWN_TEGEL):
			vast.append(str(d.name) + " (terug)")
	for e in dorp.get_node("Exits").get_children():
		warps += 1
		var r: Rect2i = e.tile_rect()
		var ok := false
		for x in range(r.position.x, r.end.x):
			ok = ok or Data.bereikbaar(Data.SPAWN_TEGEL, Vector2i(x, r.position.y - 1))
		if not ok:
			vast.append(str(e.name))
	for id in ["dax", "pantser", "wapen", "accessoire", "magie", "mien", "echtpaar"]:
		var spawn: Node = dorp.get_node_or_null("Spawns/" + Data.voor_spawn(id))
		if spawn == null or not Data.bereikbaar(Vector2i((spawn.position / 16.0).floor()), Data.SPAWN_TEGEL):
			vast.append("spawn " + id)
	check("plein10: alle %d warps bereikbaar en terug (%s)" % [warps, vast], vast.is_empty() and warps == Data.PANDEN.size() + 1)
	# NPC's verspreid
	check("plein10: hoogstens %d NPC's op het plein (%d)" % [Data.PLEIN_MAX, Data.op_plein_aantal()], Data.op_plein_aantal() <= Data.PLEIN_MAX)
	# echt lopen: ingang -> deur van Dax
	var doel: Vector2i = Data.voor_tegel(Data.pand("dax"))
	var gelopen := await _loop(p, doel)
	check("plein10: gelopen van de zuidingang naar de deur van Dax (%s)" % str(p.get_tile()), gelopen)
	await _shot(dorp, "plein10_dax")
	Input.action_press("move_up")
	var binnen := await _wacht("Huis", 6.0)
	Input.action_release("move_up")
	await _fade()
	check("plein10: deur van Dax warpt naar het bestaande interieur (huis_wilgendal.tscn, spawn binnen)", binnen
			and scene().scene_file_path == "res://scenes/maps/huis_wilgendal.tscn"
			and scene().get_node("Objects/Player").get_tile() == Vector2i((scene().get_node("Spawns/binnen").position / 16.0).floor()))
	if not binnen:
		return
	# het interieur (RPG CODE) leidt terug naar wilgendal.tscn; hier terug via de spawn voor de deur
	dorp = await enter(DORP, "voor_dax")
	var terug := dorp != null
	p = dorp.get_node("Objects/Player")
	check("plein10: weer buiten voor de deur van Dax", terug and p.get_tile() == doel)
	# over de brug: van zuid naar noord en het plein op
	var zuid := Vector2i(b.position.x + 1, b.end.y)
	var noord := Vector2i(b.position.x + 1, b.position.y - 1)
	var naar_zuid := await _loop(p, zuid)
	var over := naar_zuid and await _loop(p, noord)
	check("plein10: over de brug gelopen (%s -> %s)" % [str(zuid), str(noord)], over and p.get_tile() == noord)
	await _shot(dorp, "plein10_brug", Vector2(0, 40))
	var midden := Vector2i(Data.PLEIN.position.x + Data.PLEIN.size.x / 2, Data.PLEIN.position.y + 1)
	var plein := await _loop(p, midden)
	check("plein10: het plein op gelopen (%s)" % str(p.get_tile()), plein)
	await _shot(dorp, "plein10_plein", Vector2(0, 8))


## Pad over beloopbare tegels (Data), zonder NPC-lussen, Gerrit en uitgangen. Daarna echt lopen met invoer.
func _pad(van: Vector2i, naar: Vector2i) -> Array[Vector2i]:
	var npc := {Data.GERRIT_TEGEL: true}
	for ruw in Data.SFEER:
		for t in Data.lus_tegels(ruw):
			npc[t] = true
	var vorige := {van: van}
	var rij: Array[Vector2i] = [van]
	while not rij.is_empty():
		var nu: Vector2i = rij.pop_front()
		if nu == naar:
			break
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var v: Vector2i = nu + dir
			if vorige.has(v) or not Data.beloopbaar(v) or npc.has(v) or v.y >= Data.H - 1:
				continue
			vorige[v] = nu
			rij.append(v)
	var uit: Array[Vector2i] = []
	if not vorige.has(naar):
		return uit
	var t := naar
	while t != van:
		uit.push_front(t)
		t = vorige[t]
	return uit


func _loop(p: Node2D, naar: Vector2i) -> bool:
	var pad := _pad(p.get_tile(), naar)
	if pad.is_empty() and p.get_tile() != naar:
		print("INFO  geen pad naar ", naar)
		return false
	var acties := {Vector2i.UP: "move_up", Vector2i.DOWN: "move_down", Vector2i.LEFT: "move_left", Vector2i.RIGHT: "move_right"}
	for stap in pad:
		var dir: Vector2i = stap - p.get_tile()
		if not acties.has(dir):
			return false
		var actie: String = acties[dir]
		Input.action_press(actie)
		var t0 := Time.get_ticks_msec()
		while p.get_tile() != stap and Time.get_ticks_msec() - t0 < 2000:
			await get_tree().process_frame
		Input.action_release(actie)
		while p.is_moving and Time.get_ticks_msec() - t0 < 2500:
			await get_tree().process_frame
		if p.get_tile() != stap:
			print("INFO  vast op ", p.get_tile(), " richting ", stap)
			return false
	return p.get_tile() == naar


## Screenshot op native resolutie (viewport, geen schaling), camera op de speler (+ verschuiving), zonder HUD.
func _shot(dorp: Node, naam: String, schuif := Vector2.ZERO) -> void:
	var map := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			map = a.get_slice("=", 1)
	if map == "":
		return
	var tc: Node = dorp.get_node_or_null("TouchControls")
	var zicht: Array = []
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		zicht.append([c, c.visible])
		c.visible = false
	var cam: Camera2D = get_viewport().get_camera_2d()
	var oud := Vector2.ZERO
	if cam != null:
		oud = cam.offset
		cam.offset = schuif
		cam.reset_smoothing()
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(map.path_join(naam + ".png"))
	print("INFO  screenshot (native %dx%d): %s" % [img.get_width(), img.get_height(), map.path_join(naam + ".png")])
	if cam != null:
		cam.offset = oud
	for z in zicht:
		z[0].visible = z[1]
	if tc != null:
		pass
