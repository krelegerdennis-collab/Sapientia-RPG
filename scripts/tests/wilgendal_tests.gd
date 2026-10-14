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
	await _panden()
	print("WILGENDALTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data() -> void:
	check("grond is 56 bij 30 (v3, westdeel voor de reuzenmolen)", Data.grond_ok() and Data.W == 56 and Data.H == 30)
	check("max %d sfeer-NPC's op het marktplein (%d)" % [Data.PLEIN_MAX, Data.op_plein_aantal()],
			Data.op_plein_aantal() <= Data.PLEIN_MAX and Data.op_plein_aantal() >= 1)
	var beek_ok := true
	for x in Data.W:
		var t := Vector2i(x, Data.BEEK_RIJ)
		if Data.BRUG.has_point(t) != Data.beloopbaar(t) and x > 0 and x < Data.W - 1:
			beek_ok = false
	check("beek is 1 tegel breed, alleen de brug is beloopbaar", beek_ok
			and Data.beloopbaar(Vector2i(20, Data.BEEK_RIJ - 1)) and Data.beloopbaar(Vector2i(20, Data.BEEK_RIJ + 1)))
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
	check("props in de scène (%d)" % props, props == Data.PROPS.size())
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
		var tint: Color = Data.SFEER_KLEUR[str(rij["sfeer"])]
		check("sfeer %s" % id, kamer.get_node("Ground").modulate.is_equal_approx(tint))
		var uit: Node = kamer.get_node("Exits/NaarDorp")
		check("deur terug %s" % id, uit.target_map == DORP and uit.target_spawn == Data.voor_spawn(id))
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
