extends Node
## ALLEEN VOOR TESTEN - v0.15 (ARCHIEF1): geheime deur + schatkist + Vonkzwaard, en het
## trucje 'Schild omhoog' van de Mech. Wachter.
## Start:  godot --path . -- --archieftest [--shots=/pad/map]
##   Deel A: PuzzleLogic los: los boek -> geheime deur (vergrendelt), verborgen vloer, kist,
##           duwregels, herstellen, opslaan/terugzetten, data-controle (fouten worden gevonden).
##   Deel B: de echte kamer archief_puzzel.tscn met gesimuleerde toetsen: hint op de dichte
##           deur, deur gaat ALLEEN open na de runeplaat, kist geeft het zwaard één keer, autosave,
##           save/laden, opnieuw binnenkomen, oude save (save-scum) = nooit dubbel.
##   Deel C: Vonkzwaard in het uitrustingsscherm (Wapen-vak, pijlen ATK +12) en bij Sterkste.
##   Deel D: echt gevecht tegen de Mech. Wachter: 'Schild omhoog' (bericht, strook, DEF x2, duur).
##   Deel E: Levende Archief, verdieping 1 (kas en groei-plaat).
##   Deel F: uitgang-warpers begin/midden/eind. De ingang waarschuwt niet.
##           Midden: waarschuwing kan annuleren; Ja zet je op de wereldkaart.
## Kamer: archief_puzzel (Forge's puzzelkamer 3B + de schatkamer ten noorden, zelfde kaart).
## Met --shots=map: archief_geheim_dicht, archief_geheim_open, archief_kist_zwaard,
## archief_uitrusting_zwaard, archief_wachter_schild (native + _3x).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const AW := preload("res://scripts/dungeon/archief_warpers.gd")
const ExitWarper := preload("res://scripts/dungeon/dungeon_exit_warper.gd")
const D100Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")
const SD := preload("res://scripts/data/story_data.gd")
const PuzzleRooms := preload("res://scripts/data/puzzle_rooms.gd")
const Equipment := preload("res://scripts/equipment.gd")
const ROOM_ID := "archief_puzzel"
const ROOM_SCENE := "res://scenes/maps/archief_puzzel.tscn"
const SCENE_NAME := "ArchiefPuzzel"
const HOUSE := "res://scenes/maps/huis_wilgendal.tscn"
const DOOR := Vector2i(16, 8)         # onderste tegel van de geheime deur (v14-plattegrond van Forge)
const DOOR_TOP := Vector2i(16, 7)
const PLATE_S := Vector2i(15, 9)
const CHEST := Vector2i(13, 3)
const CHEST_FRONT := Vector2i(13, 4)  # hier staan, omhoog kijken, A
const START := Vector2i(5, 17)        # spawn 'ingang' (naast E)
const SWORD := "vonkzwaard"
const FLAG := "kist_vonkzwaard"      # eigen vlag uit Forge's data (zonder "flag" zou het "kist:<id>" zijn)
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const AANVAL := 0
const VERDEDIG := 3

var failures := 0
var passes := 0
var shots := ""
var messages: Array = []
var enemy_hits: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	GameState.encounter_multiplier = 0.0
	seed(1515)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: logica geheime deur / kist ===")
	_logic_tests()
	_validation_tests()
	print("=== Deel B: echte Test Room ===")
	await _room_tests()
	print("=== Deel C: Spark Sword uitrusten ===")
	_strongest_tests()
	await _equip_screen_tests()
	print("=== Deel D: Mech. Warden - Shield Up ===")
	await _guard_tests()
	print("=== Deel E: Levende Archief, verdieping 1 ===")
	await _leven_tests()
	print("=== Deel F: uitgang-warpers Eerste Archief ===")
	await _warper_tests()
	print("ARCHIEFTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(30)
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A
func _room(layout: Array, objects: Dictionary) -> Dictionary:
	return {"layout": layout, "objects": objects,
			"entrance": {"map": HOUSE, "spawn": "binnen"}}


func _flood(l: PuzzleLogic, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo := [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in PuzzleLogic.DIRS:
			var t: Vector2i = c + d
			if not seen.has(t) and l.inside(t) and not l.is_solid(t) and not l.exits.has(t):
				seen[t] = true
				todo.append(t)
	return seen


func _logic_tests() -> void:
	check("Eerste Archief doel-level is 7", GD.EERSTE_ARCHIEF_DOEL == 7)
	var room: Dictionary = PuzzleRooms.ROOMS[ROOM_ID]
	check("puzzelkamer '%s' is geldig: %s" % [ROOM_ID, PuzzleLogic.validate(room)], PuzzleLogic.validate(room).is_empty())
	var l := PuzzleLogic.from_room(room, ROOM_ID)
	var got := []
	l.changed.connect(func(ids): got.append_array(ids))
	check("{type: gate, style: geheim} = geheime deur; runeplaat verborgen; kist", l.types["geheime_deur"] == "secret"
			and l.gates["geheime_deur"]["secret"] and l.gates["geheime_deur"]["latch"] and l.plates["plaat_s"]["hidden"]
			and l.plates["plaat_s"]["heavy"] and l.types["kist_vonkzwaard"] == "chest")
	check("deur op (16,8) + bovenste tegel (16,7), plaat s (15,9), kist (13,3)", l.gates["geheime_deur"]["tile"] == DOOR
			and l.door_tops.get(DOOR_TOP, "") == "geheime_deur" and l.plates["plaat_s"]["tile"] == PLATE_S
			and l.chests["kist_vonkzwaard"]["tile"] == CHEST)
	check("kist-data: Spark Sword x1, vlag '%s'" % FLAG, l.chests["kist_vonkzwaard"]["item"] == SWORD
			and l.chests["kist_vonkzwaard"]["n"] == 1 and l.chests["kist_vonkzwaard"]["flag"] == FLAG)
	check("dungeon-stijl: schatkamer afgedekt met Forge's \"dek\" (geen ','-tegels)", l.hidden.is_empty() and room.has("dek"))
	check("dicht: BEIDE deurtegels massief, kist massief", l.is_solid(DOOR) and l.is_solid(DOOR_TOP) and l.is_solid(CHEST)
			and not l.any_secret_open())
	var far := Vector2i(1, 17)
	l.set_player_tile(far)
	check("schatkamer niet bereikbaar vanaf de ingang", not _flood(l, START).has(CHEST_FRONT))
	# kast c eerst op de runeplaat: deur blijft dicht (poort 1 is nog niet open)
	check("kast c 1x rechts, 6x omhoog op de runeplaat", l.try_push("kast_c", Vector2i.RIGHT)
			and [1, 2, 3, 4, 5, 6].all(func(_i): return l.try_push("kast_c", Vector2i.UP)) and l.blocks["kast_c"] == PLATE_S)
	check("runeplaat ingedrukt, maar deur dicht zolang poort 1 dicht is", l.plate_pressed("plaat_s") and not l.gate_open("geheime_deur"))
	# hoofdpuzzel
	got.clear()
	check("kast b 2x omlaag op q -> poort 2 open", l.try_push("kast_b", Vector2i.DOWN) and l.try_push("kast_b", Vector2i.DOWN)
			and l.gate_open("poort_2"))
	l.toggle_lever("hendel_h")
	check("kast a 2x rechts + 3x omhoog op p -> poort 1 open (vergrendeld)", l.try_push("kast_a", Vector2i.RIGHT)
			and l.try_push("kast_a", Vector2i.RIGHT) and l.try_push("kast_a", Vector2i.UP) and l.try_push("kast_a", Vector2i.UP)
			and l.try_push("kast_a", Vector2i.UP) and l.gate_open("poort_1") and l.gates["poort_1"]["latched"])
	check("-> geheime deur open + vergrendeld, schatkamer zichtbaar", l.gate_open("geheime_deur")
			and l.gates["geheime_deur"]["latched"] and l.any_secret_open() and "geheime_deur" in got)
	check("open: BEIDE deurtegels beloopbaar", not l.is_solid(DOOR) and not l.is_solid(DOOR_TOP))
	check("schatkamer nu bereikbaar (tegel voor de kist)", _flood(l, START).has(CHEST_FRONT))
	check("kast c van de plaat af: deur blijft open", l.try_push("kast_c", Vector2i.DOWN) and not l.plate_pressed("plaat_s")
			and l.gate_open("geheime_deur"))
	check("latched_ids: %s" % [l.latched_ids()], "geheime_deur" in l.latched_ids() and "poort_1" in l.latched_ids())
	l.reset()
	check("herstellen: deur blijft open, kasten terug", l.gate_open("geheime_deur") and l.blocks["kast_c"] == Vector2i(14, 15))
	var l2 := PuzzleLogic.from_room(room, ROOM_ID, ["poort_1", "geheime_deur"])
	check("opnieuw bouwen met onthouden ids: deur open", l2.gate_open("geheime_deur") and not l2.is_solid(DOOR_TOP))
	var st := l.get_state()
	var l3 := PuzzleLogic.from_room(room, ROOM_ID)
	l3.set_state(st)
	check("get_state/set_state (gevecht): deur open", l3.gate_open("geheime_deur"))
	# herbruikbaar: los boek -> geheime deur (type "secret"), kist met 3 drankjes, duwregels
	var r2 := _room([
		"#########",
		"#,,k,####",
		"###,#####",
		"###s#####",
		"#..a..b.#",
		"#..p....#",
		"####E####",
	], {
		"a": {"type": "block", "id": "kast"},
		"p": {"type": "plate", "id": "plaat", "heavy": true},
		"s": {"type": "secret", "id": "deur", "needs": ["boek"]},
		"k": {"type": "chest", "id": "kist", "item": "drankje", "n": 3, "flag": "test_kist_drank"},
		"b": {"type": "book", "id": "boek"},
	})
	check("tweede kamer (los boek -> deur) is geldig: %s" % [PuzzleLogic.validate(r2)], PuzzleLogic.validate(r2).is_empty())
	var m := PuzzleLogic.from_room(r2)
	check("kast op de dichte geheime deur: geblokkeerd (poort)", m.push_block_reason("kast", Vector2i.UP) == "poort")
	check("kast tegen het boek: geblokkeerd (boek)", m.try_push("kast", Vector2i.RIGHT) and m.try_push("kast", Vector2i.RIGHT)
			and m.push_block_reason("kast", Vector2i.RIGHT) == "boek")
	check("boek terugduwen -> deur open; nog eens = niets (eenmalig)", m.press_book("boek") and m.gate_open("deur")
			and not m.press_book("boek") and "boek" in m.latched_ids())
	m.reset()
	check("herstellen: boek blijft ingedrukt, deur open", m.book_pressed("boek") and m.gate_open("deur"))
	# alle kist-vlaggen in het spel zijn uniek
	var flags := {}
	var dup := []
	for id in PuzzleRooms.ROOMS:
		for c in PuzzleRooms.ROOMS[id]["objects"]:
			var d: Dictionary = PuzzleRooms.ROOMS[id]["objects"][c]
			if d.get("type", "") == "chest":
				var f := PuzzleLogic.chest_flag(d)
				if flags.has(f):
					dup.append(f)
				flags[f] = true
	check("alle kist-vlaggen in puzzle_rooms.gd zijn uniek (%d, dubbel: %s)" % [flags.size(), dup], dup.is_empty() and flags.size() >= 1)


func _validation_tests() -> void:
	var bad := func(layout: Array, objects: Dictionary, part: String) -> bool:
		var e := PuzzleLogic.validate(_room(layout, objects))
		var hit := e.any(func(x): return part in x)
		if not hit:
			print("INFO  verwacht '%s', kreeg %s" % [part, e])
		return hit
	check("fout: los boek zonder muur erboven", bad.call(["#####", "#...#", "#.b.#", "##E##"],
			{"b": {"type": "book", "id": "boek"}}, "geen muur erboven"))
	check("fout: geheime deur met muur eronder", bad.call(["#####", "#.,.#", "#.s.#", "#.#.#", "#...#", "##E##"],
			{"s": {"type": "secret", "id": "d", "needs": ["x"]}, }, "2 tegels hoog"))
	check("fout: geheime deur zonder doorgang erboven (2 tegels)", bad.call(["#####", "#####", "##G##", "#...#", "##E##"],
			{"G": {"type": "gate", "style": "geheim", "id": "d", "needs": ["x"]}}, "2 tegels hoog"))
	check("fout: kist met onbekend item", bad.call(["#####", "#.k.#", "#...#", "##E##"],
			{"k": {"type": "chest", "id": "k", "item": "toverzwaard", "flag": "f"}}, "bestaat niet"))
	var kr := _room(["#####", "#.k.#", "#...#", "##E##"], {"k": {"type": "chest", "id": "k", "item": "drankje"}})
	check("kist zonder eigen vlag: geldig, vlag 'kist:<id>' (zoals DungeonChest)", PuzzleLogic.validate(kr).is_empty()
			and PuzzleLogic.from_room(kr).chests["k"]["flag"] == "kist:k")
	check("fout: twee kisten met dezelfde vlag", bad.call(["#####", "#kj.#", "#...#", "##E##"],
			{"k": {"type": "chest", "id": "k", "item": "drankje", "flag": "f"},
			"j": {"type": "chest", "id": "j", "item": "drankje", "flag": "f"}}, "dubbel"))
	check("fout: geheime deur wacht op een kist (geeft geen signaal)", bad.call(["#####", "#,k,#", "##,##", "##s##", "#...#", "##E##"],
			{"k": {"type": "chest", "id": "k", "item": "drankje", "flag": "f2"},
			"s": {"type": "secret", "id": "d", "needs": ["k"]}}, "geeft geen signaal"))
	check("fout: verborgen vloer in de rand", bad.call(["##,##", "#...#", "##E##"], {}, "rand"))


# ================================================================ deel B
func _enter_room() -> Node:
	GameState.has_return_point = false
	GameState.change_map(ROOM_SCENE, "ingang")
	if not await wait_scene(SCENE_NAME):
		return null
	await wait_fade()
	return scene()


func _room_tests() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.encounter_multiplier = 0.0
	# de hoofdpuzzel (poort 1) is al opgelost: dat test --puzzletest; hier gaat het om de geheime deur
	GameState.puzzle_latched[ROOM_ID] = ["poort_1"]
	var room := await _enter_room()
	check("puzzelkamer geladen", room != null)
	if room == null:
		return
	var door: Node = room.nodes.get("geheime_deur")
	var chest: Node = room.nodes.get("kist_vonkzwaard")
	var plate: Node = room.nodes.get("plaat_s")
	check("nodes: geheime deur, schatkist, runeplaat", door != null and chest != null and plate != null)
	if door == null or chest == null or plate == null:
		return
	check("speler bij de ingang (5,17): %s" % tile(), tile() == START)
	# v0.14 tekstvak-plek; v0.16: laag (boven de touch-knoppen) als dat de speler niet bedekt, anders bovenin
	await pframes(2)
	Dialog.show_lines(["Test."])
	var over := false
	for f in Dialog._focus_rects():
		for bx in Dialog._rects_for(Dialog.box_rect()):
			over = over or bx.intersects(f)
	check("v0.16: speler onderin (scherm-y %d): tekstvak bedekt speler/doel niet (%s, plek %s)"
			% [int(player().get_global_transform_with_canvas().origin.y), Dialog.box_rect(), Dialog.placement],
			Dialog.is_open and not over and Dialog.style_kind == "vak")
	await close_dialog()
	check("poort 1 open (uit de save), geheime deur dicht", room.logic.gate_open("poort_1") and not room.logic.gate_open("geheime_deur"))
	check("deur: frame 0, botsing op BEIDE tegels, schatkamer afgedekt, kist dicht, runeplaat-art",
			not door.is_open and door.sprite.frame == 0 and door in bodies_at(DOOR) and door in bodies_at(DOOR_TOP)
			and room.hidden_layer == null and room.hidden_cover != null and room.hidden_cover.visible and chest.sprite.frame == 0
			and plate.sprite.texture.resource_path.ends_with("drukplaat_rune.png"))
	check("art van RPG ART: geheime_deur_archief.png 64x32 (4 frames), schatkist 48x16 (3 frames)", door.sprite.texture.get_size() == Vector2(64, 32)
			and door.sprite.hframes == 4 and chest.sprite.texture.get_size() == Vector2(48, 16) and chest.sprite.hframes == 3)
	check("save vóór de kist", GameState.save_game(tile(), player().facing))
	# --- naar de dichte deur: hint
	await walk("move_right", 11)
	await walk("move_up", 9)
	check("onder de dichte deur (16,9), kan niet verder: %s" % tile(), tile() == Vector2i(16, 9))
	await pframes(4)
	await screenshot("archief_geheim_dicht")
	for i in 3:                  # met beeld (xvfb) valt een druk soms tussen twee beelden: nog eens
		await press_interact()
		if await wait_until(func(): return Dialog.is_open, 0.5):
			break
	check("A op de dichte deur: hint '%s'" % (Dialog._lines[0] if Dialog.is_open else ""),
			Dialog.is_open and "pink crack" in str(Dialog._lines[0]) and Dialog._lines.size() == 2)
	await close_dialog()
	check("hint opent de deur NIET", not room.logic.gate_open("geheime_deur") and not door.is_open)
	# --- kast c op de runeplaat
	await walk("move_down", 7)
	await walk("move_left", 3)
	await walk("move_up", 1)
	check("naast kast c (13,15): %s" % tile(), tile() == Vector2i(13, 15))
	await walk("move_right", 1)
	check("kast c 1x naar rechts (15,15)", room.logic.blocks["kast_c"] == Vector2i(15, 15))
	await walk("move_down", 1)
	await walk("move_right", 1)
	await walk("move_up", 5)
	check("na 5 duwen: deur nog dicht (kast op (15,10))", room.logic.blocks["kast_c"] == Vector2i(15, 10) and not door.is_open)
	await walk("move_up", 1)
	check("6e duw: kast op de runeplaat (15,9), plaat licht op (frame 1)", room.logic.blocks["kast_c"] == PLATE_S
			and plate.sprite.frame == 1)
	check("-> geheime deur gaat open + vergrendeld", room.logic.gate_open("geheime_deur") and door.is_open
			and GameState.puzzle_latched.get(ROOM_ID, []).has("geheime_deur"))
	await wait_until(func(): return Dialog.is_open, 2.0)
	check("bericht: '%s' / '%s'" % [Dialog._lines[0] if Dialog.is_open else "", Dialog._lines[-1] if Dialog.is_open else ""],
			Dialog.is_open and "scrape" in str(Dialog._lines[0]))
	await close_dialog()
	await wait_until(func(): return not door.is_animating() and not room.hidden_cover.visible, 3.0)
	check("deur-animatie klaar (frame 3), botsing uit op beide tegels, schatkamer zichtbaar", door.sprite.frame == 3
			and not door in bodies_at(DOOR) and not door in bodies_at(DOOR_TOP) and not room.hidden_cover.visible)
	await pframes(4)
	await walk("move_right", 1)
	await walk("move_up", tile().y - 9)   # na het duwen staat de speler een paar tegels lager
	check("onder de open deur (16,9): %s" % tile(), tile() == Vector2i(16, 9))
	await pframes(6)
	await screenshot("archief_geheim_open")
	# --- door de deur (beide tegels) naar de kist
	await pframes(4)
	await walk("move_up", 1)
	check("op de onderste deurtegel (16,8): %s" % tile(), tile() == DOOR)
	await walk("move_up", 1)
	check("op de bovenste deurtegel (16,7): %s" % tile(), tile() == DOOR_TOP)
	await walk("move_up", 2)      # doorgang (16,6) in de onderrand, dan de schatkamer in
	await walk("move_left", 3)
	await walk("move_up", 2)
	check("voor de kist (13,4), kijkt omhoog: %s" % tile(), tile() == CHEST_FRONT and player().facing == Vector2i.UP)
	var autosaves := GameState.autosave_count
	check("nog geen zwaard, vlag niet gezet", GameState.item_count(SWORD) == 0 and not GameState.story_flags.has(FLAG))
	await interact_dialog()
	check("A op de kist: '%s'" % (Dialog._lines[0] if Dialog.is_open else ""), Dialog.is_open
			and str(Dialog._lines[1]) == "Dax finds the Spark Sword!" and room.last_chest_result == "gekregen")
	# v0.14 (handoff par. 9): de kist staat bovenin beeld -> tekstvak onderin, niet over kist + icoon
	var chest_pos: Vector2 = chest.get_global_transform_with_canvas().origin
	var chest_rect := Rect2(chest_pos + Vector2(-8, -26), Vector2(16, 34))   # kist + icoon erboven
	var box_rect: Rect2 = Dialog.panel.get_global_rect().grow_side(SIDE_TOP, 12)   # + naamtabje
	check("tekstvak onderin en NIET over de kist (kist %s, vak %s)" % [chest_rect, box_rect],
			Dialog.at_bottom and not box_rect.intersects(chest_rect))
	check("zwaard 1x in de tas, vlag gezet, kist open met gloed (frame 2), Spark Sword-icoon boven de kist",
			GameState.item_count(SWORD) == 1 and GameState.story_flags.has(FLAG) and chest.sprite.frame == 2 and chest.icon.visible
			and chest.icon.texture != null and chest.icon.texture.resource_path.ends_with("icons/vonkzwaard.png"))
	for i in 4:                  # naar regel 2 (het zwaard); een druk tijdens het typen maakt eerst de regel af
		if not Dialog.is_open or Dialog._index >= 1:
			break
		await wait_until(func(): return not Dialog._is_typing(), 4.0)
		await press_interact()
	await wait_until(func(): return not Dialog._is_typing(), 4.0)
	await pframes(4)
	await screenshot("archief_kist_zwaard")
	await close_dialog()
	await pframes(4)
	await screenshot("archief_kist_open")   # zonder tekstvak: de open kist zelf
	check("na het bericht: icoon weg, kist gewoon open (frame 1), autosave 'kist' (%s)" % GameState.last_autosave_reason,
			not chest.icon.visible and chest.sprite.frame == 1
			and GameState.autosave_count == autosaves + 1 and GameState.last_autosave_reason == "kist")
	var auto := GameState.read_save(GameState.autosave_path)
	check("autosave bevat de vlag en het zwaard", FLAG in auto.get("story", {}).get("flags", [])
			and int(auto.get("inventory", {}).get(SWORD, 0)) == 1)
	await interact_dialog()
	check("A nog eens: 'De kist is leeg.', niets erbij", Dialog.is_open and str(Dialog._lines[0]) == "The chest is empty."
			and GameState.item_count(SWORD) == 1 and room.last_chest_result == "leeg")
	await close_dialog()
	# --- opnieuw binnenkomen: geen tweede zwaard
	GameState.change_map(HOUSE, "binnen")
	await wait_scene("Huis", 15.0)
	await wait_fade()
	room = await _enter_room()
	check("opnieuw de kamer in", room != null)
	if room == null:
		return
	check("na terugkomen: deur open, schatkamer zichtbaar, kist open", room.nodes["geheime_deur"].is_open
			and not room.hidden_cover.visible and room.nodes["kist_vonkzwaard"].is_open and not room.logic.is_solid(DOOR_TOP))
	player().place_at(CHEST_FRONT, Vector2i.UP)
	await pframes(3)
	await interact_dialog()
	check("kist na terugkomen: leeg, nog steeds 1 zwaard", room.last_chest_result == "leeg" and GameState.item_count(SWORD) == 1)
	await close_dialog()
	# --- handmatige save + laden
	var sp := GameState.save_path
	GameState.save_path = "user://archieftest_save_2.json"
	check("opslaan (met zwaard)", GameState.save_game(tile(), player().facing))
	GameState.story_flags.erase(FLAG)
	GameState.inventory.erase(SWORD)
	GameState.puzzle_latched.clear()
	check("laden: vlag, zwaard (1) en deur terug", GameState.load_game() and GameState.story_flags.has(FLAG)
			and GameState.item_count(SWORD) == 1 and GameState.puzzle_latched.get(ROOM_ID, []).has("geheime_deur"))
	GameState.save_path = sp
	check("autosave laden: vlag + 1 zwaard", GameState.load_game(GameState.autosave_path) and GameState.story_flags.has(FLAG)
			and GameState.item_count(SWORD) == 1)
	# --- save-scum: de save van vóór de kist
	check("oude save (vóór de kist) laden: geen vlag, geen zwaard, deur weer dicht",
			GameState.load_game(sp) and not GameState.story_flags.has(FLAG) and GameState.item_count(SWORD) == 0
			and not GameState.puzzle_latched.get(ROOM_ID, []).has("geheime_deur"))
	room = await _enter_room()
	check("kamer uit de oude save: deur dicht, kist dicht", room != null and not room.nodes["geheime_deur"].is_open
			and not room.nodes["kist_vonkzwaard"].is_open)
	if room == null:
		return
	room.logic.set_state({"blocks": {}, "levers": {}, "latched": ["poort_1", "geheime_deur"]})
	await pframes(3)
	await close_dialog()
	player().place_at(CHEST_FRONT, Vector2i.UP)
	await pframes(3)
	await interact_dialog()
	await close_dialog()
	check("oude save: kist opnieuw open -> precies 1 zwaard (nooit 2)", GameState.item_count(SWORD) == 1
			and GameState.story_flags.has(FLAG) and Equipment.total_count(GameState.party, GameState.inventory, SWORD) == 1)
	await interact_dialog()
	await close_dialog()
	check("en daarna weer leeg", GameState.item_count(SWORD) == 1 and room.last_chest_result == "leeg")


# ================================================================ deel C
func _strongest_tests() -> void:
	var h := GameState.hero_template(GameState.MAIN_HERO)
	var inv := {"kort_zwaard": 1, "dolk": 1, SWORD: 1}
	var base_atk: int = h["base"]["atk"]
	check("Spark Sword: naam '%s', vak Wapen, ATK +12" % Equipment.item_name(SWORD),
			Equipment.item_name(SWORD) == "Spark Sword" and Equipment.slot_of(SWORD) == "wapen" and int(GD.EQUIPMENT[SWORD]["atk"]) == 12)
	var n := Equipment.strongest(h, inv)
	check("Sterkste kiest het Spark Sword (boven Dagger en Short Sword): %s" % h["equip"]["wapen"],
			n >= 1 and h["equip"]["wapen"] == SWORD and h["atk"] == base_atk + 12 and inv.get("dolk", 0) == 1 and inv.get("kort_zwaard", 0) == 1)
	var noor := GameState.hero_template("noor")
	check("Vesper (magier) kan het Spark Sword niet dragen", not Equipment.equip(noor, {SWORD: 1}, "wapen", SWORD)["ok"])


func menu() -> Node:
	var s := scene()
	return s.get_node_or_null("FieldMenu") if s != null else null


func _equip_screen_tests() -> void:
	# Dennis met het Kort zwaard + het Vonkzwaard in de tas
	var h: Dictionary = GameState.party[0]
	GameState.equip_weapon(GameState.MAIN_HERO, "kort_zwaard")
	GameState.inventory[SWORD] = 1
	var atk0: int = h["atk"]
	await tap("menu")
	await pframes(4)
	var m := menu()
	check("veldmenu open", m != null)
	if m == null:
		return
	var target: Button = m.buttons["equip"]
	for i in 10:
		if target.has_focus():
			break
		await tap("move_down")
	await tap("interact")
	await pframes(3)
	var s: Node = m.get_node_or_null("Equipment")
	check("uitrustingsscherm open", s != null)
	if s == null:
		return
	await tap("interact")          # Uitrusten
	await tap("interact")          # Wapen
	check("Wapen-lijst bevat het Spark Sword (%s)" % [s.list_ids], s.mode == "item" and SWORD in s.list_ids)
	for i in 6:
		if s.list_ids[s.list_buttons.find(focused())] == SWORD if s.list_buttons.find(focused()) >= 0 else false:
			break
		await tap("move_down")
	check("pijl bij het Spark Sword: ATK %s -> %s omhoog (+9 t.o.v. Short Sword)" % [s.old_value_text("atk"), s.new_value_text("atk")],
			s.arrow_dir("atk") == 1 and s.old_value_text("atk") == str(atk0) and s.new_value_text("atk") == str(atk0 + 9)
			and s.arrow_dir("def") == 0)
	await pframes(4)
	await screenshot("archief_uitrusting_zwaard")
	await tap("interact")
	check("uitgerust: ATK = basis + 12 (%d), Short Sword terug in de tas" % h["atk"], h["equip"]["wapen"] == SWORD
			and h["atk"] == int(h["base"]["atk"]) + 12 and GameState.item_count("kort_zwaard") == 1 and GameState.item_count(SWORD) == 0
			and GameState.weapon_name(h) == "Spark Sword")
	for i in 4:
		await tap("cancel")
		await pframes(3)
	await pframes(6)


# ================================================================ deel D
func _guard_tests() -> void:
	var h: Dictionary = GameState.party[0]
	h["hp"] = h["max_hp"]
	var p := player()
	if p == null:
		check("speler in de kamer voor het gevecht", false)
		return
	GameState.start_battle(["mech_wachter"], p.get_tile(), p.facing, "archief")
	check("gevecht tegen de Mech. Warden", await wait_scene("Battle", 20.0))
	var b := battle()
	if b == null:
		return
	messages.clear()
	enemy_hits.clear()
	_watch(b)
	b.damage_shown.connect(func(who: String, amount: int):
		if who != GameState.party[0]["name"]:
			enemy_hits.append(amount))
	await wait_battle_state(["command"])
	var w: Dictionary = b.enemies[0]
	check("Warden in het gevecht: HP 30, DEF 8, skill 'Shield Up'", int(w["s"]["max_hp"]) == 30 and int(w["s"]["def"]) == 8
			and w["s"]["skills"].any(func(sk): return sk.get("type", "") == "guard"))
	# zoals op monsterniveau 4 (Forge): DEF 15, HP 69 -> verschil met/zonder schild goed meetbaar
	w["s"]["def"] = 15
	w["s"]["max_hp"] = 69
	w["s"]["hp"] = 69
	# het trucje afdwingen (anders 20%): alleen 'Schild omhoog', kans 1
	w["s"]["skills"] = [{"name": "Shield Up", "chance": 1.0, "type": "guard", "def_mult": 2.0}]
	Engine.time_scale = 2.0
	await do_round(b, VERDEDIG)
	check("ronde 1: '%s'" % b.GUARD_TEXT % w["name"], seen_message("raises a shield! (DEF x2)") and int(w.get("guard", 0)) == 1)
	check("Warden blauw getint", w["node"].modulate == b.GUARD_TINT)
	await get_tree().create_timer(0.4).timeout
	check("ronde 2 (kiezen): strook '%s'" % b.message_label.text, b.state == "command" and b.caption.visible
			and b.message_label.text == b.GUARD_BANNER % w["name"])
	Engine.time_scale = 1.0
	await screenshot("archief_wachter_schild")
	Engine.time_scale = 2.0
	var atk := float(h["atk"])
	var wdef := float(w["s"]["def"])
	var max_guarded := maxi(1, roundi((atk - wdef * 2.0 / 2.0) * 1.15))
	var min_normal := roundi((atk - wdef / 2.0) * 0.85)
	await do_round(b, AANVAL)
	check("ronde 2: aanval op het schild = DEF x2 (%s, max %d; zonder schild min %d)" % [enemy_hits, max_guarded, min_normal],
			enemy_hits.size() == 1 and enemy_hits[0] <= max_guarded and max_guarded < min_normal)
	check("ronde 2: de Warden zet het schild niet nog eens op (valt aan)", not messages.slice(1).any(func(x): return "raises a shield" in x)
			or messages.filter(func(x): return "raises a shield" in x).size() == 1)
	check("na ronde 2: schild weg, tint weg", int(w.get("guard", 0)) == 0 and w["node"].modulate == Color.WHITE)
	await get_tree().create_timer(0.4).timeout
	check("ronde 3 (kiezen): geen strook meer", b.state == "command" and not b.caption.visible)
	w["s"]["skills"] = []
	var hits := enemy_hits.size()
	await do_round(b, AANVAL)
	check("ronde 3: gewone schade (%s >= %d)" % [enemy_hits.slice(hits), min_normal], enemy_hits.size() == hits + 1
			and enemy_hits[hits] >= min_normal)
	# afmaken
	for guard in 40:
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "":
			break
		if st == "command":
			w["s"]["hp"] = mini(int(w["s"]["hp"]), 1)
			await do_round(b, AANVAL)
		else:
			await tap("interact")
	check("gewonnen, terug in de kamer", await wait_scene(SCENE_NAME, 20.0) and GameState.last_battle_result == "win")
	Engine.time_scale = 1.0


# ================================================================ deel E: kas, verdieping 1
const A2 := preload("res://scripts/data/archief2_rooms.gd")
const Follower := preload("res://scripts/field_follower.gd")
const LEVEN_ID := "leven_ingang"
const PLAAT_ID := "leven_v1_plaat"
const LEVEN_SCENE := "res://scenes/maps/leven_ingang.tscn"
const PLAAT_SCENE := "res://scenes/maps/leven_v1_plaat.tscn"
const GAP := Vector2i(7, 2)
const NOORD := Vector2i(7, 1)
const BRUG := "groei_brug"
const HENDEL := "hendel_kas"


func _leven_tests() -> void:
	var room: Dictionary = A2.ROOMS[LEVEN_ID]
	check("verdieping 1 bestaat, verdieping 1, thema kas", not room.is_empty() and int(room["floor"]) == 1
			and str(room["theme"]) == "kas" and A2.ORDER[0][0] == LEVEN_ID)
	check("niet in de lijst van het Eerste Archief", not DR.ROOMS.has(LEVEN_ID) and DR.ORDER.size() == 12
			and DR.room(LEVEN_ID)["floor"] == 1)
	check("scènes bestaan", ResourceLoader.exists(LEVEN_SCENE) and ResourceLoader.exists(PLAAT_SCENE)
			and DR.scene_of(LEVEN_ID) == LEVEN_SCENE)
	var known := true
	var ids: Array = []
	for m in room["monsters"]:
		var eid := str(m["enemy"])
		ids.append(eid)
		known = known and GD.ENEMIES.has(eid)
	check("vijanden zijn bestaande soorten (mosslijm, moskonijn): %s" % [ids], known
			and ids == ["mosslijm", "moskonijn"])
	var had: bool = GameState.story_flags.has(SD.GOLEM_FLAG)
	GameState.story_flags.erase(SD.GOLEM_FLAG)
	var closed: Dictionary = Story.pick("naar_leven")
	var closed_do: Array = closed.get("do", [])
	var closed_txt := ""
	if closed_do.size() > 0 and closed_do[0] is Array and closed_do[0].size() > 2:
		closed_txt = " ".join(closed_do[0][2])
	check("dicht zonder Eerste Archief", closed_do is Array and closed_txt.contains("sealed shut")
			and closed_txt.contains("Eerste Archief") and closed_do.size() > 1
			and closed_do[1][0] == "walk")
	GameState.story_flags[SD.GOLEM_FLAG] = true
	var opened: Dictionary = Story.pick("naar_leven")
	check("open na de golem-vlag", str(opened.get("do", "")) == "default")
	if not had:
		GameState.story_flags.erase(SD.GOLEM_FLAG)
	var exit_lines: Array = PuzzleRooms.ROOMS[PLAAT_ID]["exit"].get("lines", [])
	var lore := closed_txt + " " + " ".join(exit_lines)
	check("geen verzonnen lore in de nieuwe zinnen", not lore.contains("H-6") and not lore.contains("Genezer")
			and not lore.contains("Wurger") and not lore.contains("Stille Vlam") and not lore.contains("ECHO"))
	var wereld: Node = (load("res://scenes/maps/wereldkaart.tscn") as PackedScene).instantiate()
	var ex: Node = wereld.get_node("Exits/NaarKas")
	var sp: Node = wereld.get_node("Spawns/van_kas")
	check("wereldkaart: kas achter de bergen, event naar_leven", ex.event == "naar_leven"
			and ex.target_map == LEVEN_SCENE and ex.target_spawn == "ingang"
			and Vector2i((ex.position / 16.0).floor()) == Vector2i(14, 8)
			and not ex.contains(Vector2i(19, 34)))
	check("terugspawn (14,9) kijkt omhoog, naast de uitgang", Vector2i((sp.position / 16.0).floor()) == Vector2i(14, 9)
			and sp.facing == Vector2i(0, -1) and wereld.get_node_or_null("Objects/KasIngang") != null)
	wereld.free()
	var pr: Dictionary = PuzzleRooms.ROOMS[PLAAT_ID]
	check("groeiplaat-kamer geldig: %s" % [PuzzleLogic.validate(pr)], PuzzleLogic.validate(pr).is_empty())
	check("noorduitgang gaat naar verdieping 2", str(pr["exit"].get("map", "")).ends_with("archief_2_v2_gang.tscn")
			and str(pr["exit"].get("spawn", "")) == "zuid")
	check("puzzel hoort bij set leven, niet bij de archief-glitch", str(pr.get("dungeon_set", "")) == "leven"
			and DR.glitch_intensity(PLAAT_SCENE) == 0.0 and DR.glitch_intensity(LEVEN_SCENE) == 0.0
			and DR.glitch_intensity(DR.scene_of("archief_golemhal")) == 1.0)
	check("volger mag de kas in", Follower.allowed(LEVEN_SCENE) and Follower.allowed(PLAAT_SCENE))
	var l := PuzzleLogic.from_room(pr, PLAAT_ID)
	check("start: stadium 0, spleet dicht, noorden onbereikbaar", l.grow_stage(BRUG) == 0 and l.is_solid(GAP)
			and not _bereikbaar(l, l.spawn_tile, NOORD))
	check("groeien vóór de hendel doet niets", l.try_grow(BRUG) == "wacht" and l.grow_stage(BRUG) == 0
			and l.is_solid(GAP) and not (BRUG in l.latched_ids()))
	check("hendel aan, eerste groei is scheut en blijft dicht", l.toggle_lever(HENDEL) and l.try_grow(BRUG) == "groei"
			and l.grow_stage(BRUG) == 1 and l.is_solid(GAP) and not _bereikbaar(l, l.spawn_tile, NOORD)
			and not (BRUG in l.latched_ids()))
	var half := l.get_state()
	l.reset()
	check("herstellen voor het eind: plaat terug naar zaad", l.grow_stage(BRUG) == 0 and l.is_solid(GAP))
	l.set_state(half)
	check("set_state bewaart scheut, pad nog dicht", l.grow_stage(BRUG) == 1 and l.is_solid(GAP) and l.lever_on(HENDEL))
	check("tweede groei opent het pad", l.try_grow(BRUG) == "open" and l.grow_stage(BRUG) == 2
			and not l.is_solid(GAP) and _bereikbaar(l, l.spawn_tile, NOORD) and BRUG in l.latched_ids())
	check("nog een keer is klaar, slaat geen stadium over", l.try_grow(BRUG) == "klaar" and l.grow_stage(BRUG) == 2)
	l.reset()
	check("volgroeid blijft open na herstellen", l.grow_open(BRUG) and _bereikbaar(l, l.spawn_tile, NOORD))
	var l2 := PuzzleLogic.from_room(pr, PLAAT_ID, [BRUG])
	check("opnieuw binnen met latch: pad open, ook als de hendel uit staat", l2.grow_open(BRUG)
			and not l2.lever_on(HENDEL) and _bereikbaar(l2, l2.spawn_tile, NOORD))
	var l3 := PuzzleLogic.from_room(pr, PLAAT_ID)
	l3.try_grow(BRUG)
	l3.toggle_lever(HENDEL)
	check("eerst plaat dan hendel blijft op stadium 0 tot je daarna groeit", l3.grow_stage(BRUG) == 0 and l3.is_solid(GAP))
	check("daarna alsnog scheut: verkeerde volgorde zet niets vast", l3.try_grow(BRUG) == "groei" and l3.grow_stage(BRUG) == 1)
	GameState.encounter_multiplier = 0.0
	GameState.change_map(LEVEN_SCENE, "ingang")
	check("kas laadt", await wait_scene("LevenIngang"))
	var kas := scene()
	var m1: Node = kas.get_node_or_null("Objects/Monster_m1") if kas else null
	var m2: Node = kas.get_node_or_null("Objects/Monster_m2") if kas else null
	var bord: Node = kas.get_node_or_null("Objects/Lees_12_5") if kas else null
	check("kas: tint, monsters, bord, opslag", kas != null and kas.get_node_or_null("ThemaTint") != null
			and m1 != null and m1.enemy_id == "mosslijm" and m2 != null and m2.enemy_id == "moskonijn"
			and bord != null and str(bord.lines[0]).contains("greenhouse") and kas.get_node_or_null("Objects/SaveBook") != null)
	GameState.change_map(PLAAT_SCENE, "ingang")
	check("groeiplaat-scène laadt", await wait_scene("LevenV1Plaat"))
	var plaat := scene()
	var pl: Node = plaat.get_node_or_null("Objects/groei_brug") if plaat else null
	var pad: Node = plaat.get_node_or_null("PuzzleFloor/groei_brug_pad") if plaat else null
	var dicht := false
	if pad:
		for c in pad.get_children():
			if c is CollisionShape2D and not (c as CollisionShape2D).disabled:
				dicht = true
	check("plaat staat en de spleet blokkeert", pl != null and plaat.logic.grow_stage(BRUG) == 0
			and plaat.logic.is_solid(GAP) and pad != null and dicht
			and plaat.get_node_or_null("Objects/hendel_kas") != null
			and plaat.get_node_or_null("ThemaTint") != null)


func _bereikbaar(l: PuzzleLogic, start: Vector2i, goal: Vector2i) -> bool:
	var seen := {}
	var q: Array[Vector2i] = [start]
	seen[start] = true
	while not q.is_empty():
		var t: Vector2i = q.pop_front()
		if t == goal:
			return true
		for d in PuzzleLogic.DIRS:
			var n: Vector2i = t + d
			if seen.has(n) or not l.inside(n) or l.is_solid(n):
				continue
			seen[n] = true
			q.append(n)
	return false


# ================================================================ deel F: uitgang-warpers
func _warper_tests() -> void:
	var spots: Array = AW.placements()
	var roles := {}
	for p in spots:
		roles[str(p["role"])] = p
	check("begin, midden en eind bestaan", spots.size() == 3 and roles.has("begin") and roles.has("midden") and roles.has("eind"))
	check("geen mini-baas: midden op verdieping %d (%s)" % [AW.middle_floor(), AW.midden_room()],
			AW.mini_boss().is_empty() and AW.middle_floor() == 3 and AW.midden_room() == "archief_v3_zuilenhal"
			and str(roles["midden"]["room"]) == "archief_v3_zuilenhal"
			and int(DR.ROOMS["archief_v3_zuilenhal"]["floor"]) == AW.middle_floor())
	var src := FileAccess.get_file_as_string("res://scripts/dungeon/archief_warpers.gd")
	check("TODO(design) omdat er geen mini-baas is", "TODO(design)" in src and "geen mini-baas" in src)
	var boss_room: Dictionary = DR.ROOMS["archief_golemhal"]
	var past: Vector2i = AW.tile_past_boss(boss_room)
	var stand: Vector2i = AW.victory_tile(boss_room)
	var eind: Vector2i = roles["eind"]["tile"]
	check("eindbaas is de Golem; geen tegel ten noorden van hem", str(roles["eind"]["room"]) == "archief_golemhal"
			and AW.boss_monster(boss_room).get("id", "") == "golem" and past == Vector2i(-1, -1))
	check("eind-warper naast de tegel direct na de overwinning %s (warper %s)" % [stand, eind],
			eind != stand and AW.walkable(boss_room, eind) and not AW.boss_rect(boss_room).has_point(eind)
			and absi(eind.x - stand.x) + absi(eind.y - stand.y) == 1)
	var begin: Vector2i = roles["begin"]["tile"]
	var spawn: Array = DR.ROOMS["archief_ingang"]["spawns"]["ingang"]
	check("begin bij de ingang, niet op de wereld-uitgang", str(roles["begin"]["room"]) == "archief_ingang"
			and begin == AW.BEGIN_TILE and absi(begin.x - int(spawn[0])) + absi(begin.y - int(spawn[1])) == 1
			and AW.walkable(DR.ROOMS["archief_ingang"], begin))
	check("midden-tegel beloopbaar in de Zuilenhal", AW.walkable(DR.ROOMS["archief_v3_zuilenhal"], roles["midden"]["tile"]))
	check("Diepe Grot-warpers zijn 1, 25, 50, 75 en 99", D100Rules.WARPER_FLOORS == [1, 25, 50, 75, 99])
	var only_a1 := true
	for p in spots:
		if not DR.ROOMS.has(str(p["room"])):
			only_a1 = false
	check("alleen kamers van het Eerste Archief", only_a1)

	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.encounter_multiplier = 0.0
	if Dialog.is_open:
		Dialog.close()
	var ingang := await _enter_map("res://scenes/maps/archief_ingang.tscn", "ingang", "ArchiefIngang")
	var wp: DungeonExitWarper = null
	if ingang != null:
		wp = ingang.get_node_or_null("Objects/ExitWarper") as DungeonExitWarper
	check("begin-warper in de ingang op %s" % [AW.BEGIN_TILE], wp != null and wp.role == "begin"
			and _warper_tile(wp) == AW.BEGIN_TILE and wp.sprite.texture.resource_path.ends_with("save_book.png")
			and wp.sprite.modulate == ExitWarper.TINT)
	if wp == null or player() == null:
		return
	var stay := tile()
	wp.interact(player())
	var ingang_zin: bool = await wait_until(func() -> bool:
		return wp.last_result == "start" and Dialog.is_open and Dialog.choices.is_empty() \
				and not Dialog._lines.is_empty() and str(Dialog._lines[0]) == ExitWarper.INGANG
	, 3.0)
	check("begin-warper waarschuwt niet", ingang_zin and not wp.waarschuwt())
	Dialog.advance()
	if Dialog.is_open:
		Dialog.advance()
	await wait_until(func(): return not Dialog.is_open and not wp.busy, 2.0)
	check("begin laat je staan", wp.last_result == "start" and scene() == ingang and tile() == stay
			and player() != null and not player().input_locked and GameState.current_map.ends_with("archief_ingang.tscn"))

	var mid := await _enter_map("res://scenes/maps/archief_v3_zuilenhal.tscn", "ladder", "ArchiefV3Zuilenhal")
	var mid_wp: DungeonExitWarper = null
	if mid != null:
		mid_wp = mid.get_node_or_null("Objects/ExitWarper") as DungeonExitWarper
	check("midden-warper in de Zuilenhal op %s" % [roles["midden"]["tile"]], mid_wp != null
			and mid_wp.role == "midden" and _warper_tile(mid_wp) == roles["midden"]["tile"]
			and mid_wp.waarschuwt())
	if mid_wp != null and player() != null:
		var mid_stay := tile()
		mid_wp.interact(player())
		var warned: bool = await wait_until(_exit_warning_open, 3.0)
		check("midden waarschuwt: '%s'" % ExitWarper.WARNING, warned)
		Dialog.choose(1)
		await wait_until(func(): return mid_wp.last_result == "cancelled" and not mid_wp.busy, 2.0)
		check("annuleren laat je in de dungeon", mid_wp.last_result == "cancelled" and scene() == mid and tile() == mid_stay
				and player() != null and not player().input_locked)
		mid_wp.interact(player())
		warned = await wait_until(_exit_warning_open, 3.0)
		check("waarschuwing opnieuw voor de bevestiging", warned
				and ExitWarper.YES == "Yes, warp to the world map"
				and ExitWarper.NO == "No, stay in the dungeon")
		Dialog.choose(0)
		var world_ok := await wait_scene("Wereldkaart", 20.0)
		await wait_fade()
		var spawn_node: Node2D = null
		if world_ok:
			spawn_node = scene().get_node_or_null("Spawns/van_archief") as Node2D
		var expect := Vector2i((spawn_node.position / 16.0).floor()) if spawn_node != null else Vector2i(-99, -99)
		check("bevestigen zet je op de wereldkaart bij het Eerste Archief %s" % [tile()],
				world_ok and GameState.current_map == ExitWarper.WORLD_SCENE and spawn_node != null
				and tile() == expect and tile() != mid_stay)
	var eind_room := await _enter_map("res://scenes/maps/archief_golemhal.tscn", "zuid", "ArchiefGolemhal")
	var eind_wp: DungeonExitWarper = null
	if eind_room != null:
		eind_wp = eind_room.get_node_or_null("Objects/ExitWarper") as DungeonExitWarper
	check("eind-warper in de Golemhal op %s" % [eind], eind_wp != null and eind_wp.role == "eind"
			and eind_wp.waarschuwt() and _warper_tile(eind_wp) == eind)


func _enter_map(path: String, spawn_name: String, scene_name: String) -> Node:
	GameState.has_return_point = false
	GameState.change_map(path, spawn_name)
	if not await wait_scene(scene_name, 20.0):
		check("kamer geladen: %s" % scene_name, false)
		return null
	await wait_fade()
	return scene()


func _warper_tile(node: Node2D) -> Vector2i:
	return Vector2i((node.position / 16.0).floor())


func _exit_warning_open() -> bool:
	return Dialog.is_open and Dialog.choices.size() == 2 and not Dialog._lines.is_empty() \
			and str(Dialog._lines[0]) == ExitWarper.WARNING and str(Dialog.choices[0]) == ExitWarper.YES \
			and str(Dialog.choices[1]) == ExitWarper.NO


# ================================================================ hulp
func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for i in n:
		var p := player()
		if p == null or scene() != start_scene or GameState.changing_map:
			return
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(p) and not p.is_moving and waited < 20:   # draaien kost even
			await get_tree().physics_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		if GameState.changing_map or Dialog.is_open:
			return


## A drukken bij een object en wachten op het tekstvak (met beeld/xvfb valt een druk soms
## tussen twee beelden; dan nog eens, max. 3x).
func interact_dialog() -> void:
	for i in 3:
		await press_interact()
		if await wait_until(func(): return Dialog.is_open, 0.5):
			return


func press_interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func close_dialog() -> void:
	for i in 30:
		if not Dialog.is_open:
			break
		await press_interact()
		await pframes(2)
	await pframes(2)


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func px(t: Vector2i) -> Vector2:
	return Vector2(t) * 16 + Vector2(8, 8)


func bodies_at(t: Vector2i) -> Array:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = px(t)
	q.collide_with_bodies = true
	var out := []
	for hit in scene().get_world_2d().direct_space_state.intersect_point(q):
		out.append(hit["collider"])
	return out


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


func wait_battle_state(states: Array, timeout := 30.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var b := battle()
		if b == null and Time.get_ticks_msec() - t0 > 500 and not GameState.in_battle:
			return ""
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
	return ""


func cross_to(b: Node, index: int) -> void:
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	for k in 3:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])


func do_round(b: Node, cmd: int) -> String:
	if await wait_battle_state(["command"]) != "command":
		return ""
	await cross_to(b, cmd)
	await tap("interact")
	if cmd == AANVAL:
		if await wait_battle_state(["target_enemy", "busy"], 5) == "target_enemy":
			await tap("interact")
	await wait_battle_state(["busy", "message_wait"], 5)
	return await wait_battle_state(["command", "message_wait"], 40)


func _watch(b: Node) -> void:
	var last := ""
	while is_instance_valid(b):
		var t: String = b.message_label.text
		if t != last:
			last = t
			messages.append(t)
		await get_tree().process_frame


func seen_message(part: String) -> bool:
	return messages.any(func(x): return part in x)


## Screenshot: native (veld 384x216, gevecht 768x432) + _3x (1152x648).
func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	var big := img.duplicate()
	big.resize(1152, 648, Image.INTERPOLATE_NEAREST)
	big.save_png(shots.path_join(name + "_3x.png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"), " ", img.get_size(), " + _3x ", big.get_size())
