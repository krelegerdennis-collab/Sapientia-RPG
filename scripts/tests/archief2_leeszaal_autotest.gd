extends RefCounted
## WM1 T3: de optionele puzzelkamer van Archief 2 (leven_v2_leeszaal, vanaf de Kasgang).
## Binnen --autotest (scripts/debug_autotest.gd). Alleen dit blok: godot --path . -- --autotest --test-archief2-leeszaal
## Controleert: data geldig, ingang in de Kasgang, oplosbaar (vaste oplossing + BFS), geen softlock (in elke
## bereikbare stand kan de speler bij de herstelsteen of de ingang), herstellen werkt, en de echte scène.

const PuzzleRooms := preload("res://scripts/data/puzzle_rooms.gd")
const Rooms := preload("res://scripts/data/archief2_rooms.gd")
const SD := preload("res://scripts/data/story_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const ID := "leven_v2_leeszaal"
const SCENE := "res://scenes/maps/leven_v2_leeszaal.tscn"
const GANG := "res://scenes/maps/archief_2_v2_gang.tscn"
const L := Vector2i.LEFT
const R := Vector2i.RIGHT
const U := Vector2i.UP

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	var room: Dictionary = PuzzleRooms.ROOMS.get(ID, {})
	t.check("leeszaal: kamer staat in puzzle_rooms.gd", not room.is_empty())
	if room.is_empty():
		return
	_data(room)
	_oplossing(room)
	_herstel(room)
	_bfs_tests(room)
	await _scene_tests()


func _data(room: Dictionary) -> void:
	var e := PuzzleLogic.validate(room)
	t.check("leeszaal: validate zonder fouten %s" % [e], e.is_empty())
	var lay: Array = room["layout"]
	var look: Array = room["look"]
	t.check("leeszaal: look even groot als layout", look.size() == lay.size() and str(look[0]).length() == str(lay[0]).length())
	t.check("leeszaal: eigen dungeon_set (niet in de glitch-graaf van Archief 1)", str(room.get("dungeon_set", "")) == "leven")
	t.check("leeszaal: scène bestaat en wijst naar de kamer", ResourceLoader.exists(SCENE)
			and FileAccess.get_file_as_string(SCENE).contains('room_id = "%s"' % ID))
	t.check("leeszaal: ingang terug naar de Kasgang (spawn leeszaal)", str(room["entrance"]["map"]) == GANG
			and str(room["entrance"]["spawn"]) == "leeszaal")
	var gang: Dictionary = Rooms.rooms()["archief_2_v2_gang"]
	var sp: Array = gang["spawns"].get("leeszaal", [])
	var obj: Array = gang.get("objects", [])
	t.check("leeszaal: Kasgang heeft spawn 'leeszaal' op vloer", sp.size() == 3
			and str(gang["layout"][int(sp[1])])[int(sp[0])] == ".")
	t.check("leeszaal: Kasgang heeft de kier-kast met event archief2_leeszaal", obj.size() == 1
			and str(obj[0]["event"]) == "archief2_leeszaal" and ResourceLoader.exists(str(obj[0]["texture"])))
	t.check("leeszaal: de oude Kasgang-spawns blijven gelijk", gang["spawns"]["zuid"] == [13, 15, "up"]
			and gang["spawns"]["noord"] == [13, 3, "down"] and gang["spawns"]["ingang"] == [13, 15, "up"])
	var cmds: Array = SD.EVENTS.get("archief2_leeszaal", [{}])[0].get("do", [])
	var naar_kamer := false
	for c in cmds:
		if c is Array and c.size() >= 3 and str(c[0]) == "map" and str(c[1]) == SCENE and str(c[2]) == "ingang":
			naar_kamer = true
	t.check("leeszaal: event archief2_leeszaal gaat naar de kamer", naar_kamer)
	var kist: Dictionary = room["objects"]["T"]
	t.check("leeszaal: kist met bestaand voorwerp en eigen vlag", GameData.ITEMS.has(str(kist["item"]))
			and PuzzleLogic.chest_flag(kist) == "kist_leeszaal")


## De bedoelde oplossing, alleen met PuzzleLogic.
func _oplossing(room: Dictionary) -> void:
	var l := PuzzleLogic.from_room(room, ID)
	t.check("leeszaal: begin dicht", not l.gate_open("poort_leeszaal") and l.is_solid(l.gates["poort_leeszaal"]["tile"]))
	var ok := l.try_push("kast_l", L) and l.try_push("kast_l", U) and l.try_push("kast_l", U)
	ok = ok and l.try_push("kast_r", R) and l.try_push("kast_r", U) and l.try_push("kast_r", U)
	t.check("leeszaal: twee kasten op de zware platen", ok and l.plate_pressed("plaat_l") and l.plate_pressed("plaat_r"))
	t.check("leeszaal: zonder hendel nog dicht", not l.gate_open("poort_leeszaal"))
	l.toggle_lever("hendel_leeszaal")
	t.check("leeszaal: met hendel open en vergrendeld", l.gate_open("poort_leeszaal") and "poort_leeszaal" in l.latched_ids())
	l.toggle_lever("hendel_leeszaal")
	t.check("leeszaal: hendel terug -> poort blijft open (latch)", l.gate_open("poort_leeszaal"))
	# alleen de hendel of één kast is niet genoeg
	var l2 := PuzzleLogic.from_room(room, ID)
	l2.toggle_lever("hendel_leeszaal")
	l2.try_push("kast_l", L)
	l2.try_push("kast_l", U)
	l2.try_push("kast_l", U)
	t.check("leeszaal: één kast + hendel = dicht", not l2.gate_open("poort_leeszaal"))


func _herstel(room: Dictionary) -> void:
	var l := PuzzleLogic.from_room(room, ID)
	# kast_l in de hoek linksonder: vast (kan niet meer naar plaat_l)
	var ok := l.try_push("kast_l", Vector2i.DOWN) and l.try_push("kast_l", Vector2i.DOWN) and l.try_push("kast_l", Vector2i.DOWN)
	t.check("leeszaal: kast_l tegen de onderwand gedrukt (%s)" % [l.blocks["kast_l"]], ok and l.blocks["kast_l"] == Vector2i(4, 9))
	l.toggle_lever("hendel_leeszaal")
	l.reset()
	t.check("leeszaal: herstellen zet kasten en hendel terug", l.blocks["kast_l"] == l.block_start["kast_l"]
			and l.blocks["kast_r"] == l.block_start["kast_r"] and not l.lever_on("hendel_leeszaal"))
	# na de oplossing: herstellen houdt de grendelpoort open
	l.try_push("kast_l", L); l.try_push("kast_l", U); l.try_push("kast_l", U)
	l.try_push("kast_r", R); l.try_push("kast_r", U); l.try_push("kast_r", U)
	l.toggle_lever("hendel_leeszaal")
	l.reset()
	t.check("leeszaal: na herstellen blijft de opgeloste poort open", l.gate_open("poort_leeszaal"))
	var l3 := PuzzleLogic.from_room(room, ID, l.latched_ids())
	t.check("leeszaal: grendel blijft open bij terugkomen", l3.gate_open("poort_leeszaal"))


## BFS over (kasten, hendel, gebied van de speler) met de regels van PuzzleLogic.
func _bfs_tests(room: Dictionary) -> void:
	var l := PuzzleLogic.from_room(room, ID)
	var res := _bfs(l)
	t.check("leeszaal: BFS vindt een oplossing (%d standen)" % res["states"], res["solved"] and not res["capped"])
	t.check("leeszaal: geen softlock: in elke stand bij herstelsteen of ingang (%d zonder)" % res["no_escape"], res["no_escape"] == 0)
	t.check("leeszaal: kist bereikbaar in een opgeloste stand", res["chest"])


func _bfs(l: PuzzleLogic) -> Dictionary:
	var start := l.get_state()
	var queue: Array = [[start, l.spawn_tile]]
	var seen := {}
	var head := 0
	var solved := false
	var chest := false
	var no_escape := 0
	var reset_tile: Vector2i = l.resets["herstelsteen"]
	var kist_tile: Vector2i = l.chests["kist_leeszaal"]["tile"]
	while head < queue.size():
		var st: Dictionary = queue[head][0]
		var pos: Vector2i = queue[head][1]
		head += 1
		l.set_state(st)
		var region := _region(l, pos)
		var key := [st["blocks"], st["levers"], st["latched"], _min_tile(region)]
		if seen.has(str(key)):
			continue
		seen[str(key)] = true
		if seen.size() > 100000:
			return {"solved": solved, "states": seen.size(), "no_escape": no_escape, "capped": true, "chest": chest}
		if l.gate_open("poort_leeszaal"):
			solved = true
		var escape := false
		for c in region:
			for d in PuzzleLogic.DIRS:
				if c + d == reset_tile or c == l.spawn_tile:
					escape = true
				if c + d == kist_tile:
					chest = true
		if not escape:
			no_escape += 1
		if l.gate_open("poort_leeszaal"):
			continue   # opgelost en vergrendeld: verder zoeken hoeft niet (herstellen houdt hem open)
		for c in region:
			for d in PuzzleLogic.DIRS:
				var nb: Vector2i = c + d
				var b := l.block_at(nb)
				if b != "" and l.can_push(b, d):
					l.set_state(st)
					l.try_push(b, d)
					queue.append([l.get_state(), nb])
				var o := l.object_at(nb)
				if o != "" and l.types.get(o, "") == "lever":
					l.set_state(st)
					l.toggle_lever(o)
					queue.append([l.get_state(), c])
		l.set_state(st)
	return {"solved": solved, "states": seen.size(), "no_escape": no_escape, "capped": false, "chest": chest}


func _region(l: PuzzleLogic, start: Vector2i) -> Array:
	var out := [start]
	var gezien := {start: true}
	var k := 0
	while k < out.size():
		var c: Vector2i = out[k]
		k += 1
		for d in PuzzleLogic.DIRS:
			var nb: Vector2i = c + d
			if gezien.has(nb) or l.is_solid(nb) or l.exits.has(nb):
				continue
			gezien[nb] = true
			out.append(nb)
	return out


func _min_tile(region: Array) -> Vector2i:
	var m: Vector2i = region[0]
	for c in region:
		if c.y < m.y or (c.y == m.y and c.x < m.x):
			m = c
	return m


## De echte scènes: de kamer bouwt, de kier-kast in de Kasgang brengt je erheen, herstellen via de kamer.
func _scene_tests() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.pending_spawn = "leeszaal"
	var gang: Node = await _laad(GANG)
	t.check("leeszaal: Kasgang laadt met spawn leeszaal", gang != null)
	if gang == null:
		return
	var kast: Node = gang.get_node_or_null("Objects/LeeszaalKast")
	var p: Node = gang.get_node_or_null("Objects/Player")
	t.check("leeszaal: kier-kast staat in de Kasgang op (1,9)", kast != null and kast.position == Vector2(1, 9) * 16 + Vector2(8, 8))
	t.check("leeszaal: speler komt naast de kast binnen (2,9)", p != null and p.get_tile() == Vector2i(2, 9))
	if kast == null:
		return
	Story.trigger("archief2_leeszaal", kast)
	var kamer: Node = null
	for i in 600:
		await t.get_tree().process_frame
		if Dialog.is_open and i % 10 == 9:
			Dialog.advance()
		var s: Node = t.get_tree().current_scene
		if s != null and str(s.scene_file_path) == SCENE and s.is_node_ready() and s.get_node_or_null("Objects/Player") != null:
			kamer = s
			break
	t.check("leeszaal: de kier-kast brengt je in de puzzelkamer", kamer != null)
	if kamer == null:
		return
	await t.frames(6)
	var lg: PuzzleLogic = kamer.logic
	t.check("leeszaal: kamer gebouwd (2 kasten, 1 hendel, poort dicht)", lg != null and lg.blocks.size() == 2
			and lg.levers.size() == 1 and not lg.gate_open("poort_leeszaal"))
	t.check("leeszaal: kaartnaam Engels", str(kamer.map_name) == "The Living Archive - Reading Room")
	var speler: Node = kamer.get_node("Objects/Player")
	t.check("leeszaal: speler bij de ingang (7,9)", speler.get_tile() == Vector2i(7, 9))
	lg.try_push("kast_l", Vector2i.DOWN)
	lg.toggle_lever("hendel_leeszaal")
	lg.reset()
	t.check("leeszaal: herstellen in de scène", lg.blocks["kast_l"] == lg.block_start["kast_l"] and not lg.lever_on("hendel_leeszaal"))
	var ingang: Node = kamer.get_node_or_null("Exits/Ingang")
	t.check("leeszaal: ingang van de kamer wijst naar de Kasgang", ingang != null and str(ingang.target_map) == GANG
			and str(ingang.target_spawn) == "leeszaal")


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
