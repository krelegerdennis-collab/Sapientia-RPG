extends Node
## Berggrot naar de kas van het Levende Archief.
## Start:  godot --path . -- --berggrottest [--shots=/pad/map]
##   Geen baas, puzzels aanwezig en oplosbaar, geheime kamer heeft staf en
##   accessoire op Archief 2-schaal, de grot start zonder de wereldkaart.

const BG := preload("res://scripts/data/berggrot_data.gd")
const Logic := preload("res://scripts/puzzle/puzzle_logic.gd")
const Equipment := preload("res://scripts/equipment.gd")
const Gear := preload("res://scripts/data/grade_gear.gd")
const GD := preload("res://scripts/data/game_data.gd")
const Scale := preload("res://scripts/data/level_scale.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const SD := preload("res://scripts/data/story_data.gd")
const Unlock := preload("res://world_warper/flow/unlock.gd")
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
	check("Bergnerfstaf is een staf voor magiër en priester", staf.get("name") == "Bergnerfstaf"
			and staf.get("slot") == "wapen" and int(staf.get("mag", 0)) == BG.staf_mag()
			and str(staf.get("wie", [])).contains("magier") and str(staf.get("wie", [])).contains("priester"))
	check("Adersteen is een accessoire op die band", steen.get("name") == "Adersteen"
			and steen.get("slot") == "accessoire" and int(steen.get("mdef", 0)) == BG.accessoire_mdef()
			and int(steen.get("mag", 0)) == maxi(1, int(BG.staf_mag() / 6.0)))
	check("uitrusting vindt de twee stukken", Equipment.is_equipment(BG.STAF_ID)
			and Equipment.is_equipment(BG.ACCESSOIRE_ID)
			and Equipment.item_name(BG.STAF_ID) == "Bergnerfstaf"
			and Equipment.slot_of(BG.ACCESSOIRE_ID) == "accessoire")
	check("Noor kan de staf, Dennis niet; de steen kan iedereen",
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
	var ph := FileAccess.get_file_as_string("res://tools/placeholders_v17.txt")
	check("placeholders geregistreerd", ph.contains("assets/tiles/dungeon/berggrot_tiles.png")
			and ph.contains("256x80") and ph.contains("assets/sprites/enemies/steenluis.png")
			and ph.contains("90x90") and ph.contains("assets/map_monsters/adermot.png")
			and ph.contains("32x64"))
	var bron := FileAccess.get_file_as_string("res://scripts/data/berggrot_data.gd")
	check("start() wisselt naar de grotmond", bron.contains("func start")
			and bron.contains("change_map(SCENE, SPAWN_INGANG)"))
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
	var grot: Node = kaart.get_node("Exits/NaarBerggrot")
	var spawn: Node2D = kaart.get_node("Spawns/van_berggrot")
	var grot_tegel := Vector2i((grot.position / 16.0).floor())
	var spawn_tegel := Vector2i((spawn.position / 16.0).floor())
	check("spawn van_berggrot aan de voet van de bergen", grot_tegel == Vector2i(14, 19)
			and spawn_tegel == Vector2i(14, 20) and spawn.facing == Vector2i(0, 1)
			and _terrein(grond, Vector2i(14, 18)) == "berg"
			and _loopbaar(grond, grot_tegel) and _loopbaar(grond, spawn_tegel)
			and _afstand(grond, Vector2i(14, 31), grot_tegel) > 0)
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
	var platform: Node = kaart.get_node("Exits/NaarWorldWarper")
	check("warper-platform op de kaart", str(platform.event) == "naar_world_warper"
			and Vector2i((platform.position / 16.0).floor()) == Vector2i(26, 22)
			and str(platform.target_map).ends_with("exterieur.tscn")
			and str(platform.target_spawn) == "ingang"
			and _loopbaar(grond, Vector2i(26, 22)) and _afstand(grond, Vector2i(14, 31), Vector2i(26, 22)) > 0)
	kaart.free()
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	check("Genezer-vlag is de unlock", Unlock.BEWAKER_VLAG == GENEZER_VLAG)
	GameState.story_flags[TRAPZAAL_VLAG] = true
	check("bewaker van verdieping 2 opent de warper niet", not GameState.try_unlock_world_warper()
			and not GameState.world_warper_is_unlocked())
	var dicht: Dictionary = Story.pick("naar_world_warper")
	check("dicht platform wijst terug", dicht.get("do") is Array and str(dicht["do"]).contains("nog niet"))
	GameState.story_flags.erase(TRAPZAAL_VLAG)
	GameState.story_flags[GENEZER_VLAG] = true
	check("warper-vlag na De Genezer", GameState.try_unlock_world_warper()
			and GameState.world_warper_is_unlocked()
			and str(Story.pick("naar_world_warper").get("do", "")) == "default")
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
	player().place_at(Vector2i(14, 20), Vector2i.UP)
	await pframes(2)
	await walk("move_up", 1)
	var mond_ok := await wait_scene("BerggrotMond", 20.0)
	check("de berggrot start vanaf de voet", mond_ok and str(GameState.current_map).ends_with("berggrot_mond.tscn"))


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
