extends Node
## Berggrot naar de kas van het Levende Archief.
## Start:  godot --path . -- --berggrottest [--shots=/pad/map]
##   Geen baas, puzzels aanwezig en oplosbaar, geheime kamer heeft staf en
##   accessoire op Archief 2-schaal, de grot start zonder de wereldkaart.
##   Deel E: uitgang-warpers begin/midden/eind. De ingang waarschuwt niet.
##   Ja gaat naar de bestaande grotuitgang op de wereldkaart.

const BG := preload("res://scripts/data/berggrot_data.gd")
const Logic := preload("res://scripts/puzzle/puzzle_logic.gd")
const Equipment := preload("res://scripts/equipment.gd")
const Gear := preload("res://scripts/data/grade_gear.gd")
const GD := preload("res://scripts/data/game_data.gd")
const Scale := preload("res://scripts/data/level_scale.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const GDb := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const Unlock := preload("res://world_warper/flow/unlock.gd")
const BW := preload("res://scripts/dungeon/berggrot_warpers.gd")
const ExitWarper := preload("res://scripts/dungeon/dungeon_exit_warper.gd")
const AW := preload("res://scripts/dungeon/archief_warpers.gd")
const GENEZER_VLAG := "bewaker:archief_2_v4_genezer/genezer"
const TRAPZAAL_VLAG := "bewaker:archief_v2_trapzaal/m2"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	GameState.encounter_multiplier = 0.0
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: data, geen baas, schaal ===")
	_data()
	print("=== Deel B: puzzels ===")
	_puzzels()
	print("=== Deel C: wereldkaart ===")
	await _kaart()
	print("=== Deel D: grot start zonder wereldkaart ===")
	await _start()
	print("=== Deel D2: Archief 2-kant van de grot ===")
	await _archief2_kant()
	await _rust()
	print("=== Deel E: uitgang-warpers berggrot ===")
	await _warper_tests()
	print("=== Deel F: World Warper vlieg-AI (wereldkaart) ===")
	await _warper_brain()
	print("BERGGROTTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(8)
	get_tree().quit(1 if failures else 0)


func _data() -> void:
	check("doel is Act 2, level 14", BG.doel_level() == 14 and int(Scale.band(2).get("min", 0)) == 14
			and Scale.act_for_level(BG.doel_level()) == 2)
	check("staf-mag volgt de grade-2-staf", BG.staf_mag() == int(Gear.item("bg_g2_staf").get("mag", -1))
			and BG.staf_mag() == 12)
	check("adersteen-mdef volgt de koperring", BG.accessoire_mdef() == int(GD.EQUIPMENT["koperring"].get("mdef", -1))
			and BG.accessoire_mdef() == 5)
	var staf := BG.gear(BG.STAF_ID)
	var steen := BG.gear(BG.ACCESSOIRE_ID)
	check("Mountain Vein Staff is een staf voor magiër en priester", staf.get("name") == "Mountain Vein Staff"
			and staf.get("slot") == "wapen" and int(staf.get("mag", 0)) == BG.staf_mag()
			and str(staf.get("wie", [])).contains("magier") and str(staf.get("wie", [])).contains("priester"))
	check("Veinstone is een accessoire op die band", steen.get("name") == "Veinstone"
			and steen.get("slot") == "accessoire" and int(steen.get("mdef", 0)) == BG.accessoire_mdef()
			and int(steen.get("mag", 0)) == maxi(1, int(BG.staf_mag() / 6.0)))
	check("uitrusting vindt de twee stukken", Equipment.is_equipment(BG.STAF_ID)
			and Equipment.is_equipment(BG.ACCESSOIRE_ID)
			and Equipment.item_name(BG.STAF_ID) == "Mountain Vein Staff"
			and Equipment.slot_of(BG.ACCESSOIRE_ID) == "accessoire")
	check("Vesper kan de staf, Dax niet; de steen kan iedereen",
			Equipment.can_wear({"equip_type": "magier"}, BG.STAF_ID)
			and Equipment.can_wear({"equip_type": "priester"}, BG.STAF_ID)
			and not Equipment.can_wear({"equip_type": "krijger"}, BG.STAF_ID)
			and Equipment.can_wear({"equip_type": "krijger"}, BG.ACCESSOIRE_ID))
	check("monsters staan buiten game_data", BG.MONSTERS.size() == 3
			and not GD.ENEMIES.has("steenluis") and not GD.ENEMIES.has("druipslak") and not GD.ENEMIES.has("adermot"))
	var baas := false
	for id in BG.MONSTERS:
		var e: Dictionary = BG.MONSTERS[id]
		if bool(e.get("boss", false)) or e.has("boss"):
			baas = true
		check("monster %s heeft een Nederlandse naam en stats" % id,
				str(e.get("name", "")) != "" and int(e.get("max_hp", 0)) > 0 and not str(e.get("name", "")).contains("ECHO"))
	for rid in BG.ROOMS:
		for m in BG.ROOMS[rid].get("monsters", []):
			if bool(m.get("boss", false)):
				baas = true
			check("kamer %s verwijst naar een grotmonster" % rid, BG.has_enemy(str(m.get("enemy", ""))))
	check("geen baas in monsters of kamers", not baas)
	check("track staat in het manifest", AudioManager.has_music(BG.BGM))
	var pad := "res://assets/audio/bgm/" + BG.BGM_BESTAND
	if ResourceLoader.exists(pad):
		check("ogg speelt als het bestand er is", AudioManager.play_music(BG.BGM))
	else:
		check("zonder ogg blijft play_music stil", not AudioManager.play_music(BG.BGM))
	# v0.21: echte art van RPG ART (batch 1). Staat in handwerk.txt, geen "art_pending" meer.
	var hw := FileAccess.get_file_as_string("res://tools/handwerk.txt")
	var echt := true
	for bestand in ["assets/tiles/dungeon/berggrot_tiles.png", "assets/tiles/dungeon/berggrot_bibliotheek.png",
			"assets/sprites/enemies/steenluis.png", "assets/sprites/enemies/druipslak_rug.png",
			"assets/map_monsters/adermot.png"]:
		echt = echt and hw.contains(bestand) and ResourceLoader.exists("res://" + bestand)
	for id in BG.MONSTERS:
		echt = echt and not bool(BG.MONSTERS[id].get("art_pending", false))
	var tegels: Texture2D = load("res://assets/tiles/dungeon/berggrot_tiles.png")
	var mon: Texture2D = load("res://assets/map_monsters/adermot.png")
	check("echte grot-art geregistreerd (handwerk), geen art_pending", echt
			and tegels.get_width() == 256 and tegels.get_height() == 80
			and mon.get_width() == 32 and mon.get_height() == 64)
	var bron := FileAccess.get_file_as_string("res://scripts/data/berggrot_data.gd")
	check("start() wisselt naar de grotmond", bron.contains("func start")
			and bron.contains("change_map(SCENE, SPAWN_INGANG)"))
	# v0.21 (RPG ART batch 13): eigen gevechtsachtergronden voor Berggrot en Diepe Grot
	var bb: Texture2D = load(GDb.backdrop_path(GDb.backdrop_id_for(DR.terrain_of("berggrot"))))
	var dg: Texture2D = load(GDb.backdrop_path(GDb.backdrop_id_for("dungeon100")))
	check("gevechtsachtergrond: berggrot -> cave_berg, Deep Learning Simulation -> cave_deep (1280x432)",
			DR.terrain_of("berggrot") == "berggrot" and GDb.backdrop_id_for("berggrot") == "cave_berg"
			and GDb.backdrop_id_for("dungeon100") == "cave_deep"
			and bb != null and bb.get_size() == Vector2(1280, 432) and dg != null and dg.get_size() == Vector2(1280, 432)
			and str(GDb.backdrop_path("cave_berg")).ends_with("berggrot.png")
			and FileAccess.get_file_as_string("res://scripts/dungeon/dungeon100_room.gd").contains("return \"dungeon100\""))
	check("kamers hangen aan het dungeon-thema", not DR.room("berggrot_mond").is_empty()
			and DR.theme_of(DR.room("berggrot_mond")) == "berggrot")


func _puzzels() -> void:
	check("twee puzzelkamers", BG.PUZZLES.has("berggrot_grendel") and BG.PUZZLES.has("berggrot_geheim"))
	for pid in BG.PUZZLES:
		var fouten: Array = Logic.validate(BG.puzzle(pid))
		check("puzzel %s is geldig (%s)" % [pid, fouten], fouten.is_empty())
	var grendel := Logic.from_room(BG.puzzle("berggrot_grendel"), "berggrot_grendel", [])
	check("grendel dicht tot plaat en hendel", not grendel.gate_open("poort_uit"))
	var geduwd := true
	for _i in 4:
		geduwd = geduwd and grendel.try_push("kast_grendel", Vector2i.RIGHT)
	for _i in 2:
		geduwd = geduwd and grendel.try_push("kast_grendel", Vector2i.DOWN)
	check("kast op de zware plaat", geduwd and grendel.plate_pressed("plaat_grendel")
			and not grendel.gate_open("poort_uit"))
	check("hendel opent de grendel", grendel.toggle_lever("hendel_grendel") and grendel.gate_open("poort_uit"))
	var geheim := Logic.from_room(BG.puzzle("berggrot_geheim"), "berggrot_geheim", [])
	var ader := true
	for _j in 7:
		ader = ader and geheim.try_push("kast_ader", Vector2i.RIGHT)
	check("geheime deur gaat open na de plaat", ader and geheim.plate_pressed("plaat_ader")
			and geheim.gate_open("geheime_deur"))
	check("uitgang blijft een eigen hendel", not geheim.gate_open("poort_uit")
			and geheim.toggle_lever("hendel_uit") and geheim.gate_open("poort_uit"))
	var items := {}
	for cid in geheim.chests:
		var c: Dictionary = geheim.chests[cid]
		items[str(c.get("item", ""))] = str(c.get("flag", ""))
		check("kist %s is geen blauwe kist" % cid, str(c.get("kind", "")) != "blauw" and str(c.get("kind", "")) != "mimic")
	check("geheime kamer heeft staf en accessoire", items.get(BG.STAF_ID, "") == "kist_bergnerfstaf"
			and items.get(BG.ACCESSOIRE_ID, "") == "kist_adersteen" and items.size() == 2)
	check("buit-vakken kloppen", Equipment.slot_of(BG.STAF_ID) == "wapen"
			and Equipment.slot_of(BG.ACCESSOIRE_ID) == "accessoire")


func _kaart() -> void:
	var packed: PackedScene = load(BG.WERELD_MAP)
	var kaart := packed.instantiate()
	var grond: TileMapLayer = kaart.get_node("Ground")
	var grot: Node = kaart.get_node("Exits/NaarBouwplaats")
	var spawn: Node2D = kaart.get_node("Spawns/van_berggrot")
	var grot_tegel := Vector2i((grot.position / 16.0).floor())
	var spawn_tegel := Vector2i((spawn.position / 16.0).floor())
	check("spawn van_berggrot aan de voet van de bergen", grot_tegel == Vector2i(21, 17)
			and spawn_tegel == Vector2i(21, 18) and spawn.facing == Vector2i(0, 1)
			and _terrein(grond, grot_tegel) == "berg" and not _loopbaar(grond, grot_tegel)
			and _terrein(grond, Vector2i(20, 17)) == "berg" and _terrein(grond, Vector2i(22, 17)) == "berg"
			and _loopbaar(grond, spawn_tegel)
			and _afstand(grond, Vector2i(14, 31), spawn_tegel) > 0)
	var kas: Node = kaart.get_node("Exits/NaarKas")
	var van_kas: Node2D = kaart.get_node("Spawns/van_kas")
	var kas_tegel := Vector2i((kas.position / 16.0).floor())
	check("kas achter de bergen", kas_tegel == Vector2i(14, 8)
			and Vector2i((van_kas.position / 16.0).floor()) == Vector2i(14, 9)
			and van_kas.facing == Vector2i(0, -1)
			and str(kas.event) == "naar_leven"
			and not kas.contains(Vector2i(19, 34)) and not kas.contains(Vector2i(20, 34))
			and _loopbaar(grond, kas_tegel) and _afstand(grond, Vector2i(14, 31), kas_tegel) < 0
			and kaart.get_node("Exits/Trap").contains(Vector2i(20, 34)))
	var oud := Vector2i(9, 26)
	var bezet := false
	for uit in kaart.get_node("Exits").get_children():
		if uit.tile_rect().has_point(oud) or str(uit.target_map).ends_with("dungeon100.tscn"):
			bezet = true
	check("de grot start niet meer van de kaart", kaart.get_node_or_null("Exits/NaarDiepeGrot") == null
			and not bezet and grond.get_cell_source_id(oud) == 0
			and grond.get_cell_atlas_coords(oud) == Vector2i(0, 0))
	# Dennis 2026-10-13: de World Warper is geen plek op de kaart. Alleen Warp in het menu.
	var ww_uitgang := false
	for uit in kaart.get_node("Exits").get_children():
		if str(uit.target_map).begins_with("res://world_warper/") or str(uit.name).contains("WorldWarper"):
			ww_uitgang = true
	var fly: Node = kaart.get_node_or_null("WorldWarperFlyover")
	var botsing := false
	if fly != null:
		for c in fly.find_children("*", "CollisionObject2D", true, false):
			botsing = true
	check("World Warper: geen uitgang of plek op de kaart, alleen een flyover zonder botsing", not ww_uitgang
			and kaart.get_node_or_null("Objects/WorldWarper") == null and fly != null
			and str(fly.get_script().resource_path).ends_with("world_warper/art/flyover.gd") and not botsing)
	kaart.free()
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	check("Genezer-vlag is de unlock", Unlock.BEWAKER_VLAG == GENEZER_VLAG)
	GameState.story_flags[TRAPZAAL_VLAG] = true
	check("bewaker van verdieping 2 opent de warper niet", not GameState.try_unlock_world_warper()
			and not GameState.world_warper_is_unlocked())
	check("geen kaart-event naar de World Warper", not SD.EVENTS.has("naar_world_warper"))
	GameState.story_flags.erase(TRAPZAAL_VLAG)
	GameState.story_flags[GENEZER_VLAG] = true
	check("warper-vlag na The Mender", GameState.try_unlock_world_warper()
			and GameState.world_warper_is_unlocked())
	# Enige ingang: de Warp-knop in het menu (field_menu.open_warp) -> hub van Enter.
	var menu_bron := FileAccess.get_file_as_string("res://scripts/ui/field_menu.gd")
	check("World Warper alleen via Warp in het menu", menu_bron.contains("func open_warp")
			and menu_bron.contains("GameState.change_map(hub_scene_path(), spawn)")
			and not FileAccess.get_file_as_string("res://scripts/map.gd").contains("NaarWorldWarper"))
	GameState.change_map(BG.WERELD_MAP, "van_dorp")
	var wereld_ok := await wait_scene("Wereldkaart", 20.0)
	check("wereldkaart geladen", wereld_ok)
	if not wereld_ok:
		return
	await wait_fade()
	player().place_at(oud + Vector2i.DOWN, Vector2i.UP)
	await pframes(2)
	await walk("move_up", 1)
	check("op de oude grottegel blijft de wereldkaart", scene().name == "Wereldkaart" and tile() == oud
			and not Dialog.is_open and GameState.dungeon100_floor == 0 and not GameState.dungeon100_run_active())
	var flyover := scene().get_node_or_null("WorldWarperFlyover")
	await pframes(2)
	check("flyover vliegt over na ontgrendeling (puur beeld)", flyover != null and flyover.sprite.visible
			and flyover.shadow.visible)
	if flyover != null:
		await _warper_in_scene(flyover)
	# Grotmond zichtbaar op de kaart: sprite in de bergwand recht boven de ingang (14,19).
	var mond_sprite := scene().get_node_or_null("Objects/BerggrotIngang") as Sprite2D
	check("grotmond-sprite boven de berggrot-ingang", mond_sprite != null and mond_sprite.visible
			and mond_sprite.texture != null and mond_sprite.texture.get_size() == Vector2(16, 16)
			and Vector2i((mond_sprite.position / 16.0).floor()) == Vector2i(21, 17)
			and Vector2i((mond_sprite.position / 16.0).floor()) == Vector2i((kaart_grot_pos() / 16.0).floor()))
	var noord: Dictionary = BG.ROOMS["berggrot_uitmond"]["exits"]["n"]
	check("berggrot leidt naar Archief 2 (kas-entree)", str(noord.get("map", "")) == BG.KAS_SCENE
			and BG.KAS_SCENE.ends_with("archief_2_v1_entree.tscn") and ResourceLoader.exists(BG.KAS_SCENE))
	player().place_at(Vector2i(20, 18), Vector2i.UP)
	await pframes(2)
	await walk("move_up", 1)
	await pframes(10)
	check("de rest van de bergwand blokkeert (20,17)", scene().name == "Wereldkaart" and tile() == Vector2i(20, 18)
			and not GameState.changing_map)
	player().place_at(Vector2i(21, 18), Vector2i.UP)
	await pframes(4)
	await screenshot("wereldkaart_grotmond")
	await pframes(2)
	await walk("move_up", 1)
	var bouw_ok := await wait_scene("BerggrotBouwplaats", 20.0)
	check("tegen de grotmond lopen laadt eerst de bouwplaats", bouw_ok and str(GameState.current_map) == BG.BOUWPLAATS)
	await _bouwplaats()


func _start() -> void:
	BG.start()
	var mond_ok := await wait_scene("BerggrotMond", 20.0)
	check("start() laadt de grotmond", mond_ok)
	if not mond_ok:
		return
	await wait_fade()
	var mond := scene()
	check("grot start zonder wereldkaart", mond != null
			and str(mond.scene_file_path).ends_with("berggrot_mond.tscn")
			and not str(GameState.current_map).contains("wereldkaart"))
	check("eigen track op de kamer", str(mond.music_track) == BG.BGM)
	check("tint van het grot-thema", mond.get_node_or_null("ThemaTint") != null)
	var baas := false
	var n := 0
	for m in mond.monsters:
		n += 1
		if m.boss:
			baas = true
	var baas_data := false
	for m in mond.room.get("monsters", []):
		if bool(m.get("boss", false)):
			baas_data = true
	check("mond heeft monsters en geen baas", n >= 2 and not baas and not baas_data)
	await screenshot("berggrot_mond")
	GameState.change_map("res://scenes/maps/berggrot_geheim.tscn", "ingang")
	var geheim_ok := await wait_scene("BerggrotGeheim", 20.0)
	check("geheime kamer is een scène", geheim_ok)
	if not geheim_ok:
		return
	await wait_fade()
	var geheim := scene()
	var heeft_staf := false
	var heeft_steen := false
	if geheim != null and geheim.logic != null:
		for cid in geheim.logic.chests:
			var item := str(geheim.logic.chests[cid].get("item", ""))
			if item == BG.STAF_ID:
				heeft_staf = true
			if item == BG.ACCESSOIRE_ID:
				heeft_steen = true
	check("scène van de geheime kamer heeft beide kisten", heeft_staf and heeft_steen
			and not str(GameState.current_map).contains("wereldkaart"))
	await screenshot("berggrot_geheim")
	GameState.change_map("res://scenes/maps/berggrot_grendel.tscn", "ingang")
	var grendel_ok := await wait_scene("BerggrotGrendel", 20.0)
	check("grendelkamer is een scène", grendel_ok)
	if grendel_ok:
		await wait_fade()
		var grendel := scene()
		check("grendel heeft een poort", grendel != null and grendel.logic != null
				and grendel.logic.gates.has("poort_uit") and not grendel.logic.gate_open("poort_uit"))
		await screenshot("berggrot_grendel")


func _warper_tests() -> void:
	var spots: Array = BW.placements()
	var roles := {}
	for p in spots:
		roles[str(p["role"])] = p
	var uit: Dictionary = BG.ROOMS["berggrot_mond"]["exits"]["E"]
	check("begin, midden en eind bestaan", spots.size() == 3 and roles.has("begin")
			and roles.has("midden") and roles.has("eind"))
	if not roles.has("begin") or not roles.has("midden") or not roles.has("eind"):
		return
	check("geen mini-baas: midden op de Nerf, eind in de Outlet",
			str(roles["begin"]["room"]) == "berggrot_mond"
			and str(roles["midden"]["room"]) == "berggrot_nerf"
			and str(roles["eind"]["room"]) == "berggrot_uitmond"
			and BW.for_room("berggrot_grendel").is_empty()
			and BW.for_room("berggrot_geheim").is_empty())
	check("begin bij de ingang, niet op de wereld-uitgang", roles["begin"]["tile"] == BW.BEGIN_TILE
			and _naast(roles["begin"]["tile"], _spawn_tile(BG.ROOMS["berggrot_mond"], "ingang"))
			and AW.walkable(BG.ROOMS["berggrot_mond"], roles["begin"]["tile"])
			and not BW.bezet(BG.ROOMS["berggrot_mond"], roles["begin"]["tile"]))
	check("midden-tegel vrij in de Nerf", roles["midden"]["tile"] == BW.MIDDEN_TILE
			and AW.walkable(BG.ROOMS["berggrot_nerf"], roles["midden"]["tile"])
			and not BW.bezet(BG.ROOMS["berggrot_nerf"], roles["midden"]["tile"]))
	check("eind-tegel vrij in de laatste kamer", roles["eind"]["tile"] == BW.EIND_TILE
			and AW.walkable(BG.ROOMS["berggrot_uitmond"], roles["eind"]["tile"])
			and not BW.bezet(BG.ROOMS["berggrot_uitmond"], roles["eind"]["tile"]))
	var doel_ok := true
	for p in spots:
		var rid := str(p["room"])
		if not BG.ROOMS.has(rid) or rid.begins_with("archief") or rid.begins_with("dungeon100"):
			doel_ok = false
		if str(p["world_scene"]) != BG.WERELD_MAP or str(p["world_spawn"]) != BG.WERELD_SPAWN:
			doel_ok = false
		if str(p["world_scene"]) == BG.KAS_SCENE:
			doel_ok = false
	check("warpers: alleen grotkamers, terug naar de wereldkaart (21,18); zuiduitgang naar de bouwplaats", doel_ok
			and str(uit["map"]) == BG.BOUWPLAATS and str(uit["spawn"]) == BG.BOUWPLAATS_SPAWN)
	if spots.size() != 3:
		return
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.encounter_multiplier = 0.0
	if Dialog.is_open:
		Dialog.close()
	var ingang := await _enter("res://scenes/maps/berggrot_mond.tscn", "ingang", "BerggrotMond")
	await _rust()
	await _weg_monsters(ingang)
	var wp: DungeonExitWarper = _warper_van(ingang)
	check("begin-warper in de grotmond op %s" % [BW.BEGIN_TILE], wp != null and wp.role == "begin"
			and _warper_tile(wp) == BW.BEGIN_TILE and not wp.waarschuwt()
			and wp.sprite.texture.resource_path.ends_with("save_book.png")
			and wp.sprite.modulate == ExitWarper.TINT
			and wp.world_scene == BG.WERELD_MAP and wp.world_spawn == BG.WERELD_SPAWN)
	if wp == null or player() == null:
		return
	var stay := tile()
	wp.interact(player())
	var ingang_zin: bool = await wait_until(func() -> bool:
		return wp.last_result == "start" and Dialog.is_open and Dialog.choices.is_empty() \
				and not Dialog._lines.is_empty() and str(Dialog._lines[0]) == ExitWarper.INGANG
	, 3.0)
	check("begin-warper waarschuwt niet", ingang_zin and not wp.waarschuwt())
	_klik_dicht()
	await wait_until(func() -> bool: return not Dialog.is_open and not wp.busy, 2.0)
	check("begin laat de party staan", wp.last_result == "start" and scene() == ingang and tile() == stay
			and player() != null and not player().input_locked
			and str(GameState.current_map).ends_with("berggrot_mond.tscn"))
	await _warper_kamer("res://scenes/maps/berggrot_nerf.tscn", "zuid", "BerggrotNerf", "midden", roles["midden"]["tile"])
	await _warper_kamer("res://scenes/maps/berggrot_uitmond.tscn", "zuid", "BerggrotUitmond", "eind", roles["eind"]["tile"])


func _warper_kamer(pad: String, spawn: String, scene_name: String, role: String, tegel: Vector2i) -> void:
	var kamer := await _enter(pad, spawn, scene_name)
	await _rust()
	await _weg_monsters(kamer)
	var wp: DungeonExitWarper = _warper_van(kamer)
	check("%s-warper op %s" % [role, tegel], wp != null and wp.role == role and wp.waarschuwt()
			and _warper_tile(wp) == tegel and wp.sprite.texture.resource_path.ends_with("save_book.png")
			and wp.sprite.modulate == ExitWarper.TINT)
	if wp == null or player() == null:
		return
	var stay := tile()
	wp.interact(player())
	var warned: bool = await wait_until(_exit_warning_open, 3.0)
	check("%s waarschuwt: '%s'" % [role, ExitWarper.WARNING], warned
			and ExitWarper.YES == "Yes, warp to the world map"
			and ExitWarper.NO == "No, stay in the dungeon")
	Dialog.choose(1)
	await wait_until(func() -> bool: return wp.last_result == "cancelled" and not wp.busy, 2.0)
	check("%s annuleren laat de party staan" % role, wp.last_result == "cancelled" and scene() == kamer
			and tile() == stay and player() != null and not player().input_locked)
	wp.interact(player())
	warned = await wait_until(_exit_warning_open, 3.0)
	check("%s vraagt opnieuw om bevestiging" % role, warned)
	Dialog.choose(0)
	var wereld_ok := await wait_scene("Wereldkaart", 20.0)
	await wait_fade()
	var sp: Node2D = null
	if wereld_ok:
		sp = scene().get_node_or_null("Spawns/" + BG.WERELD_SPAWN) as Node2D
	var verwacht := Vector2i((sp.position / 16.0).floor()) if sp != null else Vector2i(-99, -99)
	check("%s ja gaat naar de wereldkaart bij %s %s" % [role, BG.WERELD_SPAWN, tile()],
			wereld_ok and GameState.current_map == BG.WERELD_MAP and sp != null
			and tile() == verwacht and tile() != stay)


func _enter(pad: String, spawn_name: String, scene_name: String) -> Node:
	GameState.has_return_point = false
	GameState.change_map(pad, spawn_name)
	if not await wait_scene(scene_name, 20.0):
		check("kamer geladen: %s" % scene_name, false)
		return null
	await wait_fade()
	return scene()


func _warper_van(kamer: Node) -> DungeonExitWarper:
	if kamer == null:
		return null
	return kamer.get_node_or_null("Objects/ExitWarper") as DungeonExitWarper


func _warper_tile(node: Node2D) -> Vector2i:
	if node == null:
		return Vector2i(-99, -99)
	return Vector2i((node.position / 16.0).floor())


func _spawn_tile(room: Dictionary, spawn: String) -> Vector2i:
	var v: Array = room["spawns"][spawn]
	return Vector2i(int(v[0]), int(v[1]))


func _naast(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _exit_warning_open() -> bool:
	return Dialog.is_open and Dialog.choices.size() == 2 and not Dialog._lines.is_empty() \
			and str(Dialog._lines[0]) == ExitWarper.WARNING and str(Dialog.choices[0]) == ExitWarper.YES \
			and str(Dialog.choices[1]) == ExitWarper.NO


func _klik_dicht() -> void:
	if Dialog.is_open:
		Dialog.advance()
	if Dialog.is_open:
		Dialog.advance()


func _weg_monsters(kamer: Node) -> void:
	if kamer == null or not ("monsters" in kamer):
		return
	for m in kamer.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	kamer.monsters.clear()
	await pframes(2)


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _terrein(grond: TileMapLayer, t: Vector2i) -> String:
	var td := grond.get_cell_tile_data(t)
	if td == null:
		return "leeg"
	return str(td.get_custom_data("terrain"))


func _loopbaar(grond: TileMapLayer, t: Vector2i) -> bool:
	return not (_terrein(grond, t) in ["berg", "zee", "leeg"])


func _afstand(grond: TileMapLayer, van: Vector2i, naar: Vector2i) -> int:
	var dist := {van: 0}
	var todo: Array[Vector2i] = [van]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		if t == naar:
			return dist[t]
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = t + d
			if not dist.has(n) and _loopbaar(grond, n):
				dist[n] = dist[t] + 1
				todo.append(n)
	return -1


func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	return s.get_node_or_null("Objects/Player") if s else null


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for _i in n:
		var p := player()
		if p == null or scene() != start_scene or GameState.changing_map or GameState.in_battle:
			return
		Input.action_press(action)
		var gewacht := 0
		while is_instance_valid(p) and not p.is_moving and gewacht < 8:
			await get_tree().physics_frame
			gewacht += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		if GameState.changing_map or Dialog.is_open or GameState.in_battle:
			return


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_fade() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		if Transition._rect != null and Transition._rect.color.a <= 0.01:
			break
		await get_tree().process_frame
	await pframes(2)


func pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func screenshot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(naam + ".png"))
	print("INFO  screenshot: ", shots.path_join(naam + ".png"), " ", img.get_size())


func kaart_grot_pos() -> Vector2:
	var g := scene().get_node_or_null("Exits/NaarBouwplaats") as Node2D
	return g.position if g != null else Vector2(-1, -1)


## Uitmond: de boog in de noordwand (9,2) is de tunnel naar de kas (archief_2_v1_entree).
## De kas-entree heeft onderin de dubbele deur (9-10,11) terug naar de Uitmond (spawn boog).
func _archief2_kant() -> void:
	var lay: Array = BG.ROOMS["berggrot_uitmond"]["layout"]
	check("Outlet: tunnelboog 'n' in de noordwand op (9,2)", str(lay[2]).find("n") == 9 and str(lay[1])[9] == "A")
	GameState.change_map("res://scenes/maps/berggrot_uitmond.tscn", "boog")
	var ok := await wait_scene("BerggrotUitmond", 20.0)
	if ok:
		await wait_fade()
		await pframes(4)
		await screenshot("berggrot_uitmond_boog")
	check("Outlet geladen bij de boog", ok and tile() == Vector2i(9, 3))
	# Geen kas-intro (archief2_keten) tijdens deze check: die dialoog blokkeerde de warpers in Deel E.
	var had_keten := GameState.story_flags.has("archief2_keten")
	GameState.story_flags["archief2_keten"] = true
	GameState.change_map("res://scenes/maps/archief_2_v1_entree.tscn", "ingang")
	ok = await wait_scene("Archief2V1Entree", 20.0)
	if ok:
		await wait_fade()
		await pframes(4)
		await screenshot("archief2_entree_zuid")
	var terug := false
	if ok:
		for uit in scene().get_node("Exits").get_children():
			if str(uit.target_map).ends_with("berggrot_uitmond.tscn") and str(uit.target_spawn) == "boog":
				terug = true
	check("kas-entree heeft de weg terug naar de Outlet", ok and terug)
	for _i in 300:
		if Dialog.is_open:
			if Dialog._is_typing():
				Dialog.advance()
			else:
				Dialog.advance()
		elif not Story.running:
			break
		await get_tree().process_frame
	print("INFO  na D2: story.running=%s dialog=%s" % [Story.running, Dialog.is_open])
	if not had_keten:
		GameState.story_flags.erase("archief2_keten")
	await _rust()


func _praat(npc_naam: String) -> String:
	var n := scene().get_node_or_null("Objects/" + npc_naam)
	if n == null:
		return ""
	var gezien := ""
	Story.trigger(str(n.get("event")), n)
	for _i in 200:
		if Dialog.is_open:
			if Dialog._is_typing():
				Dialog.advance()
			else:
				gezien += str(Dialog.text_label.text) + " "
				Dialog.advance()
		elif not Story.running:
			break
		await get_tree().process_frame
	return gezien


## Bouwplaats voor de tunnel: dicht zonder noor_lid, open erna. Save-veilig (alleen de vlag telt).
func _bouwplaats() -> void:
	await wait_fade()
	var hek := scene().get_node_or_null("Objects/Hek")
	var voorman_tekst := await _praat("Voorman")
	var werker_tekst := await _praat("Werker")
	check("bouwplaats: werkers, karretje, gereedschap, balken", scene().get_node_or_null("Objects/Voorman") != null
			and scene().get_node_or_null("Objects/Werker") != null and scene().get_node_or_null("Objects/Karretje") != null
			and scene().get_node_or_null("Objects/Gereedschap") != null and scene().get_node_or_null("Objects/Balken") != null)
	check("dicht: voorman zegt dat de tunnel niet veilig is (%s)" % voorman_tekst, voorman_tekst.contains("isn't safe yet"))
	check("dicht: werker praat Engels", werker_tekst.contains("Mind the cart"))
	var sheet_ok := true
	for nm in ["Werker", "Werker2", "Werker3"]:
		var npc := scene().get_node_or_null("Objects/" + nm)
		sheet_ok = sheet_ok and npc != null and npc.sheet != null and npc.sheet.resource_path.ends_with("bouw_werker.png")
	check("bouwplaats: drie werkers met de bouwvakker-sheet van RPG ART", sheet_ok)
	var vm := scene().get_node_or_null("Objects/Voorman")
	check("bouwplaats: Voorman heeft eigen WM1-sheet (henrik.png 24x32, offset -8)", vm != null and vm.sheet != null
			and vm.sheet.resource_path.ends_with("som/wilgendal/npcs/henrik.png") and vm.sprite.hframes == 3
			and vm.sprite.vframes == 4 and vm.sprite.offset == Vector2(0, -8))
	check("dicht: hek staat en blokkeert", hek != null and hek.visible and int(hek.get("collision_layer")) != 0)
	player().place_at(Vector2i(12, 5), Vector2i.UP)
	await pframes(4)
	await screenshot("bouwplaats_dicht")
	await walk("move_up", 2)
	await pframes(20)
	for _i in 30:
		if Dialog.is_open:
			Dialog.advance()
		await get_tree().process_frame
	check("dicht: de tunnel laat je niet door", scene().name == "BerggrotBouwplaats" and tile() == Vector2i(12, 5))
	# Zuid terug naar de wereldkaart (21,18)
	var uit := scene().get_node("Exits/NaarWereld")
	check("zuiduitgang naar de wereldkaart, spawn van_berggrot (21,18)", str(uit.target_map) == BG.WERELD_MAP
			and str(uit.target_spawn) == "van_berggrot")
	# Open na noor_lid. Via save/load: alleen de vlag telt.
	GameState.story_flags[BG.TUNNEL_VLAG] = true
	var data: Dictionary = GameState.state_data(Vector2i(12, 11), Vector2i.UP, BG.BOUWPLAATS)
	GameState.story_flags.erase(BG.TUNNEL_VLAG)
	print("INFO  na bouwplaats: story.running=%s dialog=%s locked=%s" % [Story.running, Dialog.is_open,
			player().input_locked if player() != null else null])
	for _i in 60:
		if Dialog.is_open:
			Dialog.advance()
		await get_tree().process_frame
	var geladen := GameState.apply_state(data)
	GameState.change_map(BG.BOUWPLAATS, "zuid")
	await wait_scene("BerggrotBouwplaats", 20.0)
	await wait_fade()
	await pframes(4)
	hek = scene().get_node_or_null("Objects/Hek")
	check("open: hek weg", hek != null and (not hek.visible or int(hek.get("collision_layer")) == 0))
	voorman_tekst = await _praat("Voorman")
	check("open: voorman zegt dat de tunnel open is", voorman_tekst.contains("tunnel's open"))
	check("open na laden van een save met noor_lid", geladen and bool(GameState.story_flags.get(BG.TUNNEL_VLAG, false)))
	player().place_at(Vector2i(12, 5), Vector2i.UP)
	await pframes(4)
	await screenshot("bouwplaats_open")
	await walk("move_up", 1)
	await pframes(2)
	await walk("move_up", 1)
	var mond_ok := await wait_scene("BerggrotMond", 20.0)
	check("open: tunnel leidt de berggrot in", mond_ok and str(GameState.current_map).ends_with("berggrot_mond.tscn"))
	GameState.story_flags.erase(BG.TUNNEL_VLAG)
	print("INFO  na bouwplaats: story.running=%s dialog=%s locked=%s" % [Story.running, Dialog.is_open,
			player().input_locked if player() != null else null])
	for _i in 60:
		if Dialog.is_open:
			Dialog.advance()
		await get_tree().process_frame


## Wacht tot er geen dialoog, event of kaartwissel meer loopt (stabiel op trage CI).
func _rust() -> void:
	for _i in 600:
		if Dialog.is_open:
			Dialog.close()
		if not Dialog.is_open and not Story.running and not GameState.changing_map:
			break
		await get_tree().process_frame
	await pframes(5)


## World Warper op de wereldkaart: gesimuleerd met vaste seed, sneller dan realtime.
func _warper_brain() -> void:
	await pframes(1)
	var gebied := Rect2(0, 0, 1024, 800)
	var speler := Vector2(500, 400)
	for seed_nr in [1, 7, 42]:
		var b := WarperBrain.new()
		b.setup(seed_nr, gebied, Vector2(300, 300))
		b.player_pos = speler
		b.landable = func(p: Vector2) -> bool: return p.x < 700.0
		var dt := 1.0 / 60.0
		var binnen := true
		var eindig := true
		var octanten := {}
		var max_v := 0.0
		var max_vy := 0.0
		var land_ok := true
		var vast := false
		var venster_start := b.pos
		var venster_t := 0.0
		var vorige: int = b.state
		for i in int(600.0 / dt):
			b.step(dt)
			if not gebied.has_point(b.pos):
				binnen = false
			if is_nan(b.pos.x) or is_nan(b.pos.y) or is_nan(b.alt) or is_inf(b.vel.x) or is_inf(b.vel.y):
				eindig = false
				break
			var v := b.vel.length()
			max_v = maxf(max_v, v)
			max_vy = maxf(max_vy, absf(b.vel.y))
			if v > 30.0:
				octanten[int(posmod(roundi(b.vel.angle() / (TAU / 8.0)), 8))] = true
			if b.state == WarperBrain.State.LANDED and vorige != WarperBrain.State.LANDED:
				if b.pos.x >= 700.0 or b.pos.distance_to(speler) < WarperBrain.LAND_PLAYER_MIN - 2.0 or b.alt != 0.0:
					land_ok = false
			vorige = b.state
			venster_t += dt
			if venster_t >= 12.0:
				if b.pos.distance_to(venster_start) < 8.0:
					vast = true
				venster_start = b.pos
				venster_t = 0.0
		check("warper seed %d: 600 s binnen de kaart" % seed_nr, binnen)
		check("warper seed %d: nooit NaN/inf" % seed_nr, eindig)
		check("warper seed %d: alle kanten op (>=6 van 8 richtingen, ook verticaal)" % seed_nr,
				octanten.size() >= 6 and max_vy > 60.0)
		check("warper seed %d: bursts (%d) en landingen (%d)" % [seed_nr, b.bursts, b.landings],
				b.bursts >= 2 and b.landings >= 2)
		check("warper seed %d: burst haalt voertuigsnelheid (%.0f px/s)" % [seed_nr, max_v],
				max_v > WarperBrain.BURST_SPEED * 0.8 and max_v <= WarperBrain.BURST_SPEED + 1.0)
		check("warper seed %d: landt alleen op landbaar terrein, niet bij de speler" % seed_nr, land_ok)
		check("warper seed %d: nooit 12 s stil" % seed_nr, not vast)
	# deterministisch per seed
	var a := WarperBrain.new()
	var c := WarperBrain.new()
	a.setup(99, gebied, Vector2(200, 200))
	c.setup(99, gebied, Vector2(200, 200))
	for i in 3600:
		a.step(1.0 / 60.0)
		c.step(1.0 / 60.0)
	check("warper: zelfde seed = zelfde vlucht", a.pos == c.pos and a.state == c.state)
	# speler loopt naar het gelande schip -> het stijgt op
	var l := WarperBrain.new()
	l.setup(5, gebied, Vector2(400, 300))
	var geland := false
	for i in 60 * 120:
		l.step(1.0 / 60.0)
		if l.state == WarperBrain.State.LANDED:
			geland = true
			break
	l.player_pos = l.pos + Vector2(4, 0)
	l.step(1.0 / 60.0)
	check("warper: speler dichtbij een gelande warper -> hij stijgt op", geland
			and l.state == WarperBrain.State.ASCEND)
	# camera-voorkeur: waypoints rond het beeld, dus hij blijft in de buurt
	var z := WarperBrain.new()
	z.setup(3, gebied, Vector2(150, 150))
	z.view = Rect2(40, 40, 384, 216)
	var dichtbij := 0
	var n := 0
	for i in 60 * 300:
		z.step(1.0 / 60.0)
		n += 1
		if z.view.grow(64.0).has_point(z.pos):
			dichtbij += 1
	check("warper: blijft meestal rond het beeld (%d%%)" % (100 * dichtbij / n), dichtbij > n * 0.9)
	await _warper_knoppen()


## Touch-knoppen: echte rechthoeken uit touch_controls.gd; romp komt er 600 s nooit in (3 seeds).
func _warper_knoppen() -> void:
	var laag: CanvasLayer = load("res://scenes/ui/touch_controls.tscn").instantiate()
	add_child(laag)
	await pframes(2)
	var tc := laag.get_node("Control")
	tc.show_menu = true
	tc.show_run = true
	tc.show_kern = true
	var scherm: Array[Rect2] = tc.button_rects()
	laag.queue_free()
	check("touch: knop-rechthoeken voor d-pad, A, B, MENU, RUN, CORE", scherm.size() == 6)
	var beeld := Rect2(200, 200, 384, 216)
	var wereld: Array[Rect2] = []
	for r in scherm:
		wereld.append(Rect2(beeld.position + r.position, r.size))
	for seed_nr in [2, 13, 77]:
		var b := WarperBrain.new()
		b.setup(seed_nr, Rect2(0, 0, 1024, 800), beeld.get_center())
		b.view = beeld
		b.set_avoid_from_buttons(wereld)
		var raak := 0
		var in_beeld := 0
		var n := int(600.0 * 60.0)
		for i in n:
			b.step(1.0 / 60.0)
			var romp := Rect2(b.hull_center(b.pos, b.visual_alt()) - WarperBrain.HULL_HALF, WarperBrain.HULL_HALF * 2.0)
			for r in wereld:
				if romp.intersects(r):
					raak += 1
					break
			if beeld.has_point(romp.get_center()):
				in_beeld += 1
		check("warper seed %d: 600 s nooit over een touch-knop (%d frames raak)" % [seed_nr, raak], raak == 0)
		check("warper seed %d: zacht om knoppen heen, zelden noodduw (%d)" % [seed_nr, b.hard_pushes],
				b.hard_pushes < n / 200)
		check("warper seed %d: met knoppen nog steeds levend (bursts %d, landingen %d, %d%% in beeld)"
				% [seed_nr, b.bursts, b.landings, 100 * in_beeld / n],
				b.bursts >= 2 and b.landings >= 2 and in_beeld > n * 0.85)


## In de echte wereldkaart: beweegt, geen botsing/ingang, schaduw los van het schip.
func _warper_in_scene(fly: WorldWarperFlyover) -> void:
	var start: Vector2 = fly.brain.pos
	var knop_frames := 0
	var frames := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--warperframes="):
			frames = int(arg.get_slice("=", 1))
	if frames > 0 and shots != "":
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--warperseed="):
				fly.brain.rng.seed = int(arg.get_slice("=", 1))
		for i in frames:
			await get_tree().create_timer(0.25).timeout
			screenshot("wf_%03d" % i)
			print("INFO  wf_%03d %s pos=%s alt=%.1f v=%.0f inbeeld=%d" % [i, WarperBrain.State.keys()[fly.brain.state],
					fly.brain.pos.round(), fly.brain.alt, fly.brain.vel.length(),
					int(fly.brain.view.has_point(fly.sprite.global_position))])
			if fly.brain.blocked(fly.brain.pos, fly.brain.visual_alt()):
				knop_frames += 1
	else:
		await get_tree().create_timer(1.5).timeout
	var r: Rect2i = (scene().get_node("Ground") as TileMapLayer).get_used_rect()
	var kaart := Rect2(Vector2(r.position * 16), Vector2(r.size * 16))
	check("warper beweegt op de kaart en blijft erbinnen", fly.brain.pos.distance_to(start) > 20.0
			and kaart.has_point(fly.brain.pos))
	check("warper: schaduw op de grond, schip erboven", fly.shadow.position.y > fly.sprite.position.y)
	check("warper: nog steeds geen botsing of interactie-area",
			fly.find_children("*", "CollisionObject2D", true, false).is_empty())
	var land_ok := true
	for p in [Vector2(-50, -50), Vector2(kaart.end.x + 40, 10)]:
		if fly._mag_landen(p):
			land_ok = false
	check("warper: landt niet buiten de kaart", land_ok)
	check("warper: kent de echte touch-knoppen van de kaart", fly.brain.avoid.size() >= 3)
	check("warper: in de kaart-capture nooit achter een knop (%d)" % knop_frames, knop_frames == 0)
