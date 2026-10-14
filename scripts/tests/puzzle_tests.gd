extends Node
## ALLEEN VOOR TESTEN - puzzelsysteem (De Vergeten Archieven).
## Start:  godot --path . -- --puzzletest [--shots=/pad/map] [--only-logic]
##   Deel A: PuzzleLogic los (duwen, platen, hendels, poorten, herstellen, data-controle,
##           tegels, de bedoelde oplossing, een BFS-oplosser: oplosbaar, doodlopend, enz.)
##   Deel B: de echte scène archief_test.tscn met gesimuleerde toetsen (Input.action_press,
##           zoals debug_autotest.gd): duwen, poorten, hendel, uitgang, herstelsteen (Ja/Nee),
##           weg via E en terug (= herstel), terug uit een gevecht (= puzzel blijft), save.
## Print PASS/FAIL en sluit af met exit code 0 (alles goed) of 1.
## Hangt aan de root (blijft bestaan als de scène wisselt). Zit niet in de export.

const PuzzleRooms := preload("res://scripts/data/puzzle_rooms.gd")
const ROOM_SCENE := "res://scenes/maps/archief_test.tscn"
const U := Vector2i.UP
const D := Vector2i.DOWN
const L := Vector2i.LEFT
const R := Vector2i.RIGHT
## De bedoelde oplossing van archief_test vanaf de ingang (U/D/L/R = stap of duw, A = hendel).
const SOLUTION := "UUUU RRRRRR DD R UU R UU A DD LLLLLLLLLL D RR D R UUU RR UUUU"
## Een doodlopende stand: kast_a tegen de linkermuur (kan nooit meer naar rechts).
const DEAD_END := "UUU LL"

var failures := 0
var passes := 0
var shots := ""
var only_logic := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		elif arg == "--only-logic":
			only_logic = true
	GameState.encounter_multiplier = 0.0
	# v0.12 (samengevoegd met v0.11): de puzzels horen bij na de proloog. Zonder dit start
	# 'wakker worden' zodra de test het huis binnenloopt (stap START) en zit de speler vast.
	GameState.story_step = preload("res://scripts/data/story_data.gd").KLAAR
	seed(4242)
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: PuzzleLogic ===")
	var t0 := Time.get_ticks_msec()
	_test_push()
	_test_plates_gates()
	_test_lever_chain()
	_test_validation()
	_test_autotile()
	_test_solution()
	_test_solver()
	_test_archief_puzzel()
	print("INFO  deel A duurde %d ms" % (Time.get_ticks_msec() - t0))
	if not only_logic:
		print("=== Deel B: echte scène ===")
		await _integration()
		print("=== Deel C: puzzelkamer First Archive (3B) ===")
		await _archief_integration()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(30)   # lopende fades laten eindigen (anders 'leaked instance' bij afsluiten)
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A
func _room(layout: Array, objects: Dictionary) -> Dictionary:
	return {"layout": layout, "objects": objects,
			"entrance": {"map": "res://scenes/maps/huis_wilgendal.tscn", "spawn": "binnen"},
			"exit": {"lines": ["test"]}}


func _test_push() -> void:
	var room := _room([
		"########",
		"#......#",
		"#.a.bh.#",
		"#..1...#",
		"#.c...r#",
		"####E###",
	], {
		"a": {"type": "block", "id": "kast_a"},
		"b": {"type": "block", "id": "kast_b"},
		"c": {"type": "block", "id": "kast_c"},
		"h": {"type": "lever", "id": "hendel"},
		"1": {"type": "gate", "id": "poort", "needs": ["hendel"]},
		"r": {"type": "reset", "id": "steen"},
	})
	check("Test Room duwen is geldig: %s" % [PuzzleLogic.validate(room)], PuzzleLogic.validate(room).is_empty())
	var l := PuzzleLogic.from_room(room)
	var got := []
	l.changed.connect(func(ids): got.append_array(ids))
	check("spawn naast E (4,4), kijkt omhoog", l.spawn_tile == Vector2i(4, 4) and l.spawn_facing == U)
	check("duw kast_a naar rechts lukt", l.try_push("kast_a", R) and l.blocks["kast_a"] == Vector2i(3, 2))
	check("'changed' meldt kast_a", "kast_a" in got)
	check("kast_a tegen kast_b: geblokkeerd (kast)", l.push_block_reason("kast_a", R) == "kast" and not l.try_push("kast_a", R))
	check("kast_b tegen de hendel: geblokkeerd (hendel)", l.push_block_reason("kast_b", R) == "hendel")
	check("kast_a op een dichte poort: geblokkeerd (poort)", l.push_block_reason("kast_a", D) == "poort")
	l.toggle_lever("hendel")
	check("hendel aan -> poort open", l.gate_open("poort"))
	check("kast_a op een OPEN poort: ook geblokkeerd (poort)", l.push_block_reason("kast_a", D) == "poort")
	check("kast_b omhoog lukt", l.try_push("kast_b", U))
	check("kast_b tegen de muur: geblokkeerd (muur)", l.push_block_reason("kast_b", U) == "muur" and not l.try_push("kast_b", U))
	check("kast_c 2x naar rechts", l.try_push("kast_c", R) and l.try_push("kast_c", R) and l.blocks["kast_c"] == Vector2i(4, 4))
	check("kast_c op de ingang E: geblokkeerd (deur)", l.push_block_reason("kast_c", D) == "deur")
	check("kast_c 1x rechts, dan op de herstelsteen: geblokkeerd", l.try_push("kast_c", R) and l.push_block_reason("kast_c", R) == "herstelsteen")
	l.set_player_tile(Vector2i(4, 4))
	check("kast_c naar links op de speler: geblokkeerd (speler)", l.push_block_reason("kast_c", L) == "speler")
	l.set_player_tile(Vector2i(6, 3), Vector2i(4, 4))
	check("... ook op de tile waar de speler heen loopt", l.push_block_reason("kast_c", L) == "speler")
	check("buiten de kamer = massief", l.is_solid(Vector2i(-1, 2)) and l.is_solid(Vector2i(8, 2)))
	check("kast/hendel/steen massief, plaatvrij/deur niet", l.is_solid(Vector2i(5, 4)) and l.is_solid(Vector2i(5, 2))
			and l.is_solid(Vector2i(6, 4)) and not l.is_solid(Vector2i(4, 5)) and not l.is_solid(Vector2i(1, 1)))
	l.reset()
	check("reset: kasten terug", l.blocks["kast_a"] == Vector2i(2, 2) and l.blocks["kast_b"] == Vector2i(4, 2) and l.blocks["kast_c"] == Vector2i(2, 4))
	check("reset: hendel uit, poort dicht", not l.lever_on("hendel") and not l.gate_open("poort"))
	check("reset: index klopt (block_at)", l.block_at(Vector2i(2, 2)) == "kast_a" and l.block_at(Vector2i(5, 4)) == "")


func _test_plates_gates() -> void:
	var room := _room([
		"#######",
		"#.a.p.#",
		"#.bq..#",
		"#12.34#",
		"###E###",
	], {
		"a": {"type": "block", "id": "kast_a"},
		"b": {"type": "block", "id": "kast_b"},
		"p": {"type": "plate", "id": "licht"},
		"q": {"type": "plate", "id": "zwaar", "heavy": true},
		"1": {"type": "gate", "id": "alle", "needs": ["licht", "zwaar"], "mode": "all"},
		"2": {"type": "gate", "id": "een", "needs": ["licht", "zwaar"], "mode": "any"},
		"3": {"type": "gate", "id": "omgekeerd", "needs": ["licht"], "invert": true},
		"4": {"type": "gate", "id": "grendel", "needs": ["licht"], "latch": true},
	})
	check("Test Room platen is geldig: %s" % [PuzzleLogic.validate(room)], PuzzleLogic.validate(room).is_empty())
	var l := PuzzleLogic.from_room(room)
	check("begin: alle/een/grendel dicht, omgekeerd open", not l.gate_open("alle") and not l.gate_open("een")
			and l.gate_open("omgekeerd") and not l.gate_open("grendel"))
	l.set_player_tile(Vector2i(4, 1))
	check("speler op lichte plaat -> ingedrukt", l.plate_pressed("licht") and l.signal_value("licht"))
	check("any: open, all: dicht, invert: dicht, latch: open", l.gate_open("een") and not l.gate_open("alle")
			and not l.gate_open("omgekeerd") and l.gate_open("grendel"))
	l.set_player_tile(Vector2i(5, 1))
	check("speler eraf -> plaat los, any dicht, invert open", not l.plate_pressed("licht") and not l.gate_open("een") and l.gate_open("omgekeerd"))
	check("latch blijft open (vergrendeld)", l.gate_open("grendel") and l.latched_ids() == ["grendel"])
	l.set_player_tile(Vector2i(3, 2))
	check("speler op ZWARE plaat -> niet ingedrukt", not l.plate_pressed("zwaar"))
	l.set_player_tile(Vector2i(1, 1))
	check("kast_b op zware plaat -> ingedrukt", l.try_push("kast_b", R) and l.plate_pressed("zwaar") and l.gate_open("een"))
	check("kast_a 2x rechts op lichte plaat -> ingedrukt door kast", l.try_push("kast_a", R) and l.try_push("kast_a", R) and l.plate_pressed("licht"))
	check("all: beide ingedrukt -> open", l.gate_open("alle"))
	# Speler in de poort 'alle', dan de kast van de plaat: poort wacht tot de speler weg is.
	l.set_player_tile(Vector2i(1, 3))
	check("kast_a van de plaat af", l.try_push("kast_a", R) and not l.plate_pressed("licht"))
	check("poort blijft open zolang de speler erin staat", l.gate_open("alle") and not l.is_solid(Vector2i(1, 3)))
	l.set_player_tile(Vector2i(1, 2), Vector2i(1, 3))
	check("... ook als hij er nog uit loopt (doel-tile)", l.gate_open("alle"))
	l.set_player_tile(Vector2i(1, 2))
	check("speler eruit -> poort dicht", not l.gate_open("alle") and l.is_solid(Vector2i(1, 3)))
	var st := l.get_state()
	l.reset()
	check("reset: kasten terug, platen los, grendel blijft open", l.blocks["kast_a"] == Vector2i(2, 1)
			and not l.plate_pressed("zwaar") and not l.plate_pressed("licht") and l.gate_open("grendel") and not l.gate_open("een"))
	l.set_state(st)
	check("set_state zet de stand terug", l.blocks["kast_a"] == Vector2i(5, 1) and l.plate_pressed("zwaar"))
	var l2 := PuzzleLogic.from_room(room, "x", ["grendel", "een"])
	check("nieuw model met latched_ids: grendel open, 'een' (geen latch) niet", l2.gate_open("grendel") and not l2.gate_open("een"))


func _test_lever_chain() -> void:
	var room := _room([
		"######",
		"#h.12#",
		"#....#",
		"##E###",
	], {
		"h": {"type": "lever", "id": "hendel", "on": false},
		"1": {"type": "gate", "id": "eerste", "needs": ["hendel"]},
		"2": {"type": "gate", "id": "tweede", "needs": ["eerste"], "invert": true},
	})
	var l := PuzzleLogic.from_room(room)
	check("keten: hendel uit -> eerste dicht, tweede (invert van eerste) open", not l.gate_open("eerste") and l.gate_open("tweede"))
	var got := []
	l.changed.connect(func(ids): got.clear(); got.append_array(ids))
	check("toggle_lever geeft de nieuwe stand", l.toggle_lever("hendel") == true and l.signal_value("hendel"))
	check("keten: hendel aan -> eerste open, tweede dicht", l.gate_open("eerste") and not l.gate_open("tweede"))
	check("'changed' meldt hendel + beide poorten: %s" % [got], "hendel" in got and "eerste" in got and "tweede" in got)
	check("hendel weer uit", l.toggle_lever("hendel") == false and not l.gate_open("eerste"))


func _test_validation() -> void:
	for id in PuzzleRooms.ROOMS:
		var e := PuzzleLogic.validate(PuzzleRooms.ROOMS[id])
		check("kamer '%s' is geldig %s" % [id, e], e.is_empty())
		var room: Dictionary = PuzzleRooms.ROOMS[id]
		check("kamer '%s': entrance-map bestaat" % id, ResourceLoader.exists(str(room["entrance"]["map"])))
	var good := _room(["#####", "#a.p#", "#...#", "##E##"],
			{"a": {"type": "block", "id": "k"}, "p": {"type": "plate", "id": "p"}})
	check("goede mini-kamer: geen fouten", PuzzleLogic.validate(good).is_empty())
	var cases := {
		"niet rechthoekig": _room(["#####", "#a.p", "#...#", "##E##"], good["objects"]),
		"twee keer E": _room(["#####", "#a.p#", "#...#", "#E#E#"], good["objects"]),
		"geen E": _room(["#####", "#a.p#", "#...#", "#####"], good["objects"]),
		"onbekend teken": _room(["#####", "#a.p#", "#.z.#", "##E##"], good["objects"]),
		"needs bestaat niet": _room(["#####", "#a.p#", "#.1.#", "##E##"], {"a": {"type": "block", "id": "k"},
				"p": {"type": "plate", "id": "p"}, "1": {"type": "gate", "id": "g", "needs": ["spook"]}}),
		"kast in de rand": _room(["#a###", "#..p#", "#...#", "##E##"], good["objects"]),
		"plaat in de rand": _room(["#####", "#a..p", "#...#", "##E##"], good["objects"]),
		"dubbel id": _room(["#####", "#a.p#", "#...#", "##E##"], {"a": {"type": "block", "id": "k"},
				"p": {"type": "plate", "id": "k"}}),
		"object 2x": _room(["#####", "#a.a#", "#.p.#", "##E##"], good["objects"]),
		"vloer in de rand": _room(["##.##", "#a.p#", "#...#", "##E##"], good["objects"]),
		"spawn niet vrij": _room(["#####", "#.p.#", "#.a.#", "##E##"], good["objects"]),
		"onbekend type": _room(["#####", "#a.p#", "#...#", "##E##"], {"a": {"type": "kist", "id": "k"},
				"p": {"type": "plate", "id": "p"}}),
	}
	for label in cases:
		var e := PuzzleLogic.validate(cases[label])
		check("ongeldige kamer '%s' wordt gevonden: %s" % [label, e], not e.is_empty())


func _test_autotile() -> void:
	var tiles := PuzzleLogic.autotile(PuzzleRooms.ROOMS["archief_test"]["layout"])
	var expect := {
		Vector2i(0, 0): 2, Vector2i(5, 0): 2, Vector2i(7, 0): 5, Vector2i(0, 1): 3, Vector2i(3, 1): 3,
		Vector2i(1, 1): 6, Vector2i(1, 2): 7, Vector2i(11, 1): 2, Vector2i(11, 2): 2, Vector2i(11, 4): 3,
		Vector2i(12, 1): 3, Vector2i(13, 1): 3, Vector2i(0, 2): 23, Vector2i(0, 9): 23,
		Vector2i(13, 2): 24, Vector2i(13, 9): 24, Vector2i(0, 10): 2, Vector2i(4, 10): 5, Vector2i(13, 10): 2,
	}
	var bad := []
	for t in expect:
		if tiles.get(t, -1) != expect[t]:
			bad.append("%s=%s (verwacht %s)" % [t, tiles.get(t, -1), expect[t]])
	check("autotile archief_test (muurtop/voorkant/zijmuur/deur/kast) %s" % [bad], bad.is_empty())
	var floor_ok := true
	for t in [Vector2i(7, 1), Vector2i(12, 4), Vector2i(3, 6), Vector2i(5, 3), Vector2i(12, 2), Vector2i(1, 9)]:
		floor_ok = floor_ok and tiles.get(t, -1) in [0, 1]
	check("onder poorten/kasten/platen/hendel/steen ligt vloer (0/1)", floor_ok)
	check("alle 14x11 cellen hebben een tegel", tiles.size() == 14 * 11)


## Speel een reeks zetten na zoals de echte speler: lopen, duwen als er een kast staat,
## A = hendel vóór je. Geeft de eind-tile van de speler.
func _sim(l: PuzzleLogic, start: Vector2i, moves: String, facing := Vector2i.UP) -> Vector2i:
	var p := start
	l.set_player_tile(p)
	for ch in moves:
		if ch == " ":
			continue
		if ch == "A":
			var o := l.object_at(p + facing)
			if l.types.get(o, "") == "lever":
				l.toggle_lever(o)
			continue
		var dir: Vector2i = {"U": U, "D": D, "L": L, "R": R}[ch]
		facing = dir
		var n := p + dir
		var b := l.block_at(n)
		if b != "":
			if l.try_push(b, dir):
				p = n
		elif not l.is_solid(n):
			p = n
		l.set_player_tile(p)
	return p


func _test_solution() -> void:
	var room: Dictionary = PuzzleRooms.ROOMS["archief_test"]
	var l := PuzzleLogic.from_room(room, "archief_test")
	check("archief_test: spawn (4,9) omhoog", l.spawn_tile == Vector2i(4, 9) and l.spawn_facing == U)
	check("begin: poort_1 en poort_2 dicht", not l.gate_open("poort_1") and not l.gate_open("poort_2"))
	var p := _sim(l, l.spawn_tile, "UUUURRRRRRDD")
	check("kast_b op plaat q -> poort_2 open", l.blocks["kast_b"] == Vector2i(10, 8) and l.plate_pressed("plaat_q") and l.gate_open("poort_2"))
	l = PuzzleLogic.from_room(room, "archief_test")
	p = _sim(l, l.spawn_tile, SOLUTION)
	check("bedoelde oplossing: speler op X (7,0): %s" % p, p == Vector2i(7, 0))
	check("bedoelde oplossing: kast_a op p, kast_b op q, hendel aan", l.blocks["kast_a"] == Vector2i(5, 3)
			and l.blocks["kast_b"] == Vector2i(10, 8) and l.lever_on("hendel_h"))
	check("poort_1 open en vergrendeld", l.gate_open("poort_1") and l.latched_ids().has("poort_1"))
	l.reset()
	check("reset na oplossen: kasten terug, poort_1 BLIJFT open", l.blocks["kast_a"] == Vector2i(3, 6) and l.gate_open("poort_1") and not l.gate_open("poort_2"))
	# Valsspelen: zonder kast op p en q gaat poort_1 niet open, ook niet met de speler op een plaat.
	l = PuzzleLogic.from_room(room, "archief_test")
	_sim(l, l.spawn_tile, "UUUURRRRRRDD R UU R UU A DD")
	l.set_player_tile(Vector2i(5, 3))
	check("speler op zware plaat p (hendel aan, kast op q): poort_1 blijft dicht", not l.gate_open("poort_1"))
	# Doodlopend: kast_a tegen de linkermuur
	l = PuzzleLogic.from_room(room, "archief_test")
	p = _sim(l, l.spawn_tile, DEAD_END)
	check("doodlopend: kast_a op (1,6), speler (2,6)", l.blocks["kast_a"] == Vector2i(1, 6) and p == Vector2i(2, 6))
	check("kast_a kan niet verder naar links", l.push_block_reason("kast_a", L) == "muur")


## BFS-oplosser over (kasten, hendels, latch, gebied van de speler). Gebruikt de REGELS van
## PuzzleLogic zelf (can_push, is_solid, _evaluate); alleen het vlak-vullen gebeurt op een
## snel rooster dat één keer uit is_solid() wordt afgeleid (kasten/dichte poorten per stand).
## De speler drukt in deze oplosser geen (lichte) platen in: in archief_test zijn alle
## platen zwaar, dus dat klopt.
## Geeft {solved, states, no_escape (standen zonder weg naar steen of ingang), capped}.
func _bfs(room: Dictionary, start_state: Dictionary, start_player: Vector2i, max_states := 60000) -> Dictionary:
	var l := PuzzleLogic.from_room(room, "bfs")
	l.set_state(start_state)
	var bids: Array = l.blocks.keys()
	bids.sort()
	var lids: Array = l.levers.keys()
	var gids: Array = l.gates.keys()
	var w := l.size.x
	var n_cells := l.size.x * l.size.y
	var first := _pack(l, bids, lids, gids)
	# Vast rooster: massief zonder kasten en met alle poorten open (afgeleid uit is_solid).
	l._block_at.clear()
	for id in gids:
		l.gates[id]["open"] = true
	var base := PackedByteArray()
	base.resize(n_cells)
	var kind := PackedByteArray()   # 1 = X (doel), 2 = E, 3 = naast herstelsteen
	kind.resize(n_cells)
	var lever_at := {}
	for y in l.size.y:
		for x in w:
			var t := Vector2i(x, y)
			base[y * w + x] = 1 if l.is_solid(t) else 0
			if l.exits.get(t, "") == "X":
				kind[y * w + x] = 1
			elif l.exits.get(t, "") == "E":
				kind[y * w + x] = 2
			var o := l.object_at(t)
			if o != "" and l.types[o] == "lever":
				lever_at[y * w + x] = o
	for id in l.resets:
		for d in PuzzleLogic.DIRS:
			var a: Vector2i = l.resets[id] + d
			if l.inside(a) and kind[a.y * w + a.x] == 0:
				kind[a.y * w + a.x] = 3
	var gate_idx := []
	for id in gids:
		gate_idx.append(l.gates[id]["tile"].y * w + l.gates[id]["tile"].x)
	var offs := [-w, w, -1, 1]
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var queue: Array = [[first, start_player.y * w + start_player.x]]
	var queued := {queue[0]: true}
	var head := 0
	var seen := {}
	var solved := false
	var no_escape := 0
	var states := 0
	while head < queue.size():
		var item: Array = queue[head]
		head += 1
		_unpack(l, item[0], bids, lids, gids)
		var grid := base.duplicate()
		for id in bids:
			grid[l.blocks[id].y * w + l.blocks[id].x] = 2
		for gi in gids.size():
			if not l.gates[gids[gi]]["open"]:
				grid[gate_idx[gi]] = 1
		# vlak vullen
		var visited := PackedByteArray()
		visited.resize(n_cells)
		var start: int = item[1]
		visited[start] = 1
		var region := PackedInt32Array([start])
		var k := 0
		var min_i := start
		var escape := false
		while k < region.size():
			var c := region[k]
			k += 1
			if c < min_i:
				min_i = c
			var kd := kind[c]
			if kd == 1:
				solved = true
			if kd == 2 or kd == 3:
				escape = true
			if kd == 1 or kd == 2:
				continue   # door een deur ga je de kamer uit
			for o in offs:
				var nb: int = c + o
				if visited[nb] == 0 and grid[nb] == 0:
					visited[nb] = 1
					region.append(nb)
		var packed := _pack(l, bids, lids, gids)   # na _evaluate (latch kan net veranderd zijn)
		var key := [packed, min_i]
		if seen.has(key):
			continue
		seen[key] = true
		states += 1
		if states > max_states:
			return {"solved": solved, "states": states, "no_escape": no_escape, "capped": true}
		if not escape:
			no_escape += 1
		for c in region:
			if kind[c] == 1 or kind[c] == 2:
				continue
			for di in 4:
				var nb: int = c + offs[di]
				var nxt: Array = []
				if grid[nb] == 2:
					var t := Vector2i(nb % w, nb / w)
					var b := l.block_at(t)
					var d: Vector2i = dirs[di]
					if l.can_push(b, d):
						var ns := packed.duplicate()
						var i := bids.find(b) * 2
						ns[i] = t.x + d.x
						ns[i + 1] = t.y + d.y
						nxt = [ns, nb]
				elif lever_at.has(nb):
					var ns := packed.duplicate()
					var j := bids.size() * 2 + lids.find(lever_at[nb])
					ns[j] = 1 - ns[j]
					nxt = [ns, c]
				if not nxt.is_empty() and not queued.has(nxt):
					queued[nxt] = true
					queue.append(nxt)
	return {"solved": solved, "states": states, "no_escape": no_escape, "capped": false}


func _pack(l: PuzzleLogic, bids: Array, lids: Array, gids: Array) -> PackedInt32Array:
	var a := PackedInt32Array()
	for id in bids:
		a.append(l.blocks[id].x)
		a.append(l.blocks[id].y)
	for id in lids:
		a.append(1 if l.levers[id]["on"] else 0)
	for id in gids:
		a.append(1 if l.gates[id]["latched"] else 0)
	return a


## Stand snel in het model zetten (zonder 'changed'), daarna de gewone _evaluate().
func _unpack(l: PuzzleLogic, a: PackedInt32Array, bids: Array, lids: Array, gids: Array) -> void:
	l._block_at.clear()
	var k := 0
	for id in bids:
		var t := Vector2i(a[k], a[k + 1])
		k += 2
		l.blocks[id] = t
		l._block_at[t] = id
	for id in lids:
		l.levers[id]["on"] = a[k] == 1
		k += 1
	for id in gids:
		l.gates[id]["latched"] = a[k] == 1
		l.gates[id]["open"] = false
		k += 1
	l._evaluate()


func _region_min(region: Dictionary) -> Vector2i:
	var best := Vector2i(9999, 9999)
	for t in region:
		if t.y < best.y or (t.y == best.y and t.x < best.x):
			best = t
	return best


func _flood(l: PuzzleLogic, start: Vector2i) -> Dictionary:
	var region := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_back()
		if l.exits.has(t):
			continue   # door een deur ga je de kamer uit
		for d in PuzzleLogic.DIRS:
			var n: Vector2i = t + d
			if not region.has(n) and not l.is_solid(n):
				region[n] = true
				todo.append(n)
	return region


func _key(l: PuzzleLogic, region: Dictionary) -> String:
	var ids := l.blocks.keys()
	ids.sort()
	var s := ""
	for id in ids:
		s += "%d,%d;" % [l.blocks[id].x, l.blocks[id].y]
	for id in l.levers:
		s += "1" if l.levers[id]["on"] else "0"
	s += str(l.latched_ids())
	return s + "|" + str(_region_min(region))


func _test_solver() -> void:
	var room: Dictionary = PuzzleRooms.ROOMS["archief_test"]
	var l := PuzzleLogic.from_room(room, "archief_test")
	var t0 := Time.get_ticks_msec()
	var r := _bfs(room, l.get_state(), l.spawn_tile)
	print("INFO  BFS archief_test: %d standen, %d ms, capped=%s" % [r["states"], Time.get_ticks_msec() - t0, r["capped"]])
	check("BFS: archief_test is oplosbaar", r["solved"])
	check("BFS: alle standen doorzocht (niet afgekapt)", not r["capped"])
	check("BFS: in ELKE bereikbare stand kan de speler bij de herstelsteen of de ingang (%d zonder)" % r["no_escape"], r["no_escape"] == 0)
	# Doodlopende stand: niet meer op te lossen, na reset wel weer.
	_sim(l, l.spawn_tile, DEAD_END)
	var dead := _bfs(room, l.get_state(), Vector2i(2, 6))
	check("BFS: na '%s' (kast_a tegen de muur) NIET meer oplosbaar (%d standen)" % [DEAD_END, dead["states"]], not dead["solved"] and not dead["capped"])
	l.reset()
	var again := _bfs(room, l.get_state(), l.spawn_tile, 200)
	check("BFS: na reset weer de beginstand (zelfde sleutel)", _key(l, _flood(l, l.spawn_tile)) == _key(PuzzleLogic.from_room(room), _flood(PuzzleLogic.from_room(room), l.spawn_tile)))
	check("na reset weer oplosbaar (bedoelde oplossing)", _sim(l, l.spawn_tile, SOLUTION) == Vector2i(7, 0) and again["states"] > 0)
	# Met maar één kast is de kamer niet op te lossen (beide kasten zijn echt nodig).
	var one: Dictionary = room.duplicate(true)
	var rows: Array = one["layout"]
	rows[6] = str(rows[6]).replace("a", ".")
	one["objects"].erase("a")
	var lo := PuzzleLogic.from_room(one, "een_kast")
	var r1 := _bfs(one, lo.get_state(), lo.spawn_tile)
	check("BFS: met alleen kast_b NIET oplosbaar (%d standen)" % r1["states"], not r1["solved"] and not r1["capped"])


# ================================================================ deel B
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


## Loop precies n tiles (duwen gaat vanzelf: tegen de kast lopen).
func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for i in n:
		var p := player()
		if p == null or scene() != start_scene or GameState.changing_map:
			return
		# Flake-fix (CI, trage frames): de stap ging soms verloren als de speler niet binnen 6 physics-
		# frames begon te lopen. Nu: tot 20 physics-frames wachten.
		# (geen herhaalde druk: een tweede druk duwt een kast soms twee keer)
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(p) and not p.is_moving and waited < 20:
			await get_tree().physics_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		await get_tree().physics_frame
		if GameState.changing_map or Dialog.is_open:
			return


func moves(seq: String) -> void:
	var act := {"U": "move_up", "D": "move_down", "L": "move_left", "R": "move_right"}
	for ch in seq:
		if ch == " ":
			continue
		if ch == "A":
			await press_interact()
		else:
			await walk(act[ch], 1)
		if GameState.changing_map:
			return


func press_interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func wait_choices() -> bool:
	return await wait_until(_choices_ready)


func _choices_ready() -> bool:
	return Dialog.has_choices() and not Dialog._is_typing() and Dialog._choice_box != null and Dialog._choice_box.visible


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(shots)
	var path := shots.path_join(name + ".png")
	img.save_png(path)
	print("INFO  screenshot: ", path, " ", img.get_size())


func px(t: Vector2i) -> Vector2:
	return Vector2(t) * 16 + Vector2(8, 8)


## Welke bodies raakt een punt midden op deze tile?
func bodies_at(t: Vector2i) -> Array:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = px(t)
	q.collide_with_bodies = true
	var out := []
	for hit in scene().get_world_2d().direct_space_state.intersect_point(q):
		out.append(hit["collider"])
	return out


func block_ok(room: Node, id: String, t: Vector2i) -> bool:
	var n: Node2D = room.nodes[id]
	return room.logic.blocks[id] == t and n.position == px(t) and n in bodies_at(t)


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


## Vluchten zoals een speler (D-pad naar 'Vluchten' + A), berichten doorklikken.
func _flee_battle() -> void:
	Engine.time_scale = 3.0
	for guard in 40:
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "":
			break
		if st == "command":
			await pframes(2)
			var b := battle()
			for k in 8:
				if b.menu.selected == 4:
					break
				await tap("move_down")
			await tap("interact")
		else:
			await tap("interact")
	Engine.time_scale = 1.0


func _integration() -> void:
	GameState.change_map(ROOM_SCENE, "ingang")
	check("Test Room geladen (scène 'ArchiefTest')", await wait_scene("ArchiefTest"))
	var room := scene()
	if room == null or room.name != "ArchiefTest":
		return
	await wait_fade()
	check("map = archief_test.tscn", GameState.current_map == ROOM_SCENE)
	check("speler bij de ingang (4,9), kijkt omhoog: %s" % tile(), tile() == Vector2i(4, 9) and player().facing == U)
	var g: TileMapLayer = room.get_node("Ground")
	check("Ground gebouwd: 14x11, deur op (4,10), muurvoorkant op (3,1)", g.get_used_rect() == Rect2i(0, 0, 14, 11)
			and g.get_cell_atlas_coords(Vector2i(4, 10)) == Vector2i(5, 0) and g.get_cell_atlas_coords(Vector2i(3, 1)) == Vector2i(3, 0))
	check("objecten gemaakt (2 kasten, 2 platen, hendel, 2 poorten, steen)", room.nodes.size() == 8)
	check("kasten/hendel/steen in Objects (y-sort), platen/poorten in PuzzleFloor",
			room.nodes["kast_a"].get_parent().name == "Objects" and room.nodes["herstelsteen"].get_parent().name == "Objects"
			and room.nodes["poort_1"].get_parent().name == "PuzzleFloor" and room.nodes["plaat_p"].get_parent().name == "PuzzleFloor"
			and room.get_node("PuzzleFloor").get_index() < room.get_node("Objects").get_index())
	check("spawn 'ingang' en uitgangen gemaakt", room.get_node_or_null("Spawns/ingang") != null and room.get_node("Exits").get_child_count() == 2)
	check("poort_1 en poort_2 dicht (botsing aan)", not room.nodes["poort_1"].shape.disabled and not room.nodes["poort_2"].shape.disabled)
	await screenshot("01_start")

	# --- doodlopend + herstelsteen ---
	await moves("UUU")
	# Eerste duw met de hand: kijk of het plaatje meeglijdt terwijl de speler loopt.
	Input.action_press("move_left")
	await wait_until(func(): return player().is_moving, 1.0)
	var kv: Node2D = room.nodes["kast_a"].visual
	check("duw: node meteen op (2,6), plaatje glijdt nog (offset %s)" % kv.position,
			room.nodes["kast_a"].position == px(Vector2i(2, 6)) and room.nodes["kast_a"].is_sliding() and kv.position.x > 0.0)
	Input.action_release("move_left")
	await wait_until(func(): return not player().is_moving and not room.nodes["kast_a"].is_sliding(), 1.0)
	check("echte duw: kast_a naar (2,6), node + botsing mee, speler (3,6): %s" % tile(),
			block_ok(room, "kast_a", Vector2i(2, 6)) and tile() == Vector2i(3, 6) and not (room.nodes["kast_a"] in bodies_at(Vector2i(3, 6)))
			and kv.position == Vector2.ZERO)
	await moves("L")
	await moves("L")
	check("kast_a tegen de muur (1,6) en blijft daar; speler (2,6): %s" % tile(), block_ok(room, "kast_a", Vector2i(1, 6)) and tile() == Vector2i(2, 6))
	await screenshot("02_doodlopend")
	await moves("DDD L")
	check("voor de herstelsteen (2,9), kijkt links: %s" % tile(), tile() == Vector2i(2, 9) and player().facing == L)
	await press_interact()
	check("vraag 'De kamer herstellen?'", await wait_choices() and Dialog.text_label.text == "Restore the room?")
	await screenshot("03_herstelvraag")
	await tap("cancel")
	await pframes(3)
	check("B = Nee: niets veranderd", not Dialog.is_open and room.last_reset_result == "declined" and block_ok(room, "kast_a", Vector2i(1, 6)))
	await press_interact()
	check("vraag opnieuw", await wait_choices())
	await press_interact()   # keuze 0 = Ja
	await wait_until(func(): return room.last_reset_result == "reset", 3.0)
	await wait_fade()
	check("Ja: kamer hersteld", room.last_reset_result == "reset")
	check("kast_a terug op (3,6) (node + botsing), oude plek vrij", block_ok(room, "kast_a", Vector2i(3, 6)) and bodies_at(Vector2i(1, 6)).is_empty())
	check("speler terug bij de ingang (4,9), kijkt omhoog, kan weer lopen", tile() == Vector2i(4, 9) and player().facing == U and not player().input_locked)

	# --- de puzzel oplossen met echte toetsen ---
	await moves("UUUU RRRRRR")
	await pframes(10)
	await screenshot("03b_achter_kast")   # y-sort: de kast staat vóór de speler
	check("speler achter kast_b: kast half doorzichtig (doorzicht)", room.nodes["kast_b"].visual.modulate.a < 1.0
			and room.nodes["kast_a"].visual.modulate.a == 1.0)
	await moves("D")
	check("kast_b 1x omlaag (10,7)", block_ok(room, "kast_b", Vector2i(10, 7)))
	await moves("D")
	check("kast_b op plaat q (10,8): node + botsing verplaatst", block_ok(room, "kast_b", Vector2i(10, 8)) and not (room.nodes["kast_b"] in bodies_at(Vector2i(10, 7))))
	check("plaat q ingedrukt (frame 1)", room.logic.plate_pressed("plaat_q") and room.nodes["plaat_q"].sprite.frame == 1)
	await wait_until(func(): return not room.nodes["poort_2"].is_animating(), 1.0)
	check("poort_2 open: botsing uit, frame 3", room.nodes["poort_2"].shape.disabled and room.nodes["poort_2"].sprite.frame == 3)
	await moves("R UU R U")
	check("speler IN poort_2 (12,4): %s" % tile(), tile() == Vector2i(12, 4))
	await moves("U")
	check("speler voor de hendel (12,3): %s" % tile(), tile() == Vector2i(12, 3))
	check("hendel uit (frame 0)", room.nodes["hendel_h"].sprite.frame == 0 and not room.logic.lever_on("hendel_h"))
	await moves("A")
	check("A: hendel aan (frame 1, signaal aan)", room.nodes["hendel_h"].sprite.frame == 1 and room.logic.signal_value("hendel_h"))
	check("poort_1 nog dicht (plaat p nog leeg)", not room.logic.gate_open("poort_1"))
	await moves("DD LLLLLLLLLL D RR D R UU")
	check("kast_a op (5,4), speler (5,5): %s" % tile(), block_ok(room, "kast_a", Vector2i(5, 4)) and tile() == Vector2i(5, 5))
	await moves("U")
	check("kast_a op plaat p (5,3)", block_ok(room, "kast_a", Vector2i(5, 3)) and room.logic.plate_pressed("plaat_p"))
	await wait_until(func(): return not room.nodes["poort_1"].is_animating(), 1.0)
	check("poort_1 open (botsing uit, frame 3) en vergrendeld", room.nodes["poort_1"].shape.disabled
			and room.nodes["poort_1"].sprite.frame == 3 and room.logic.latched_ids().has("poort_1"))
	check("vergrendeling onthouden in GameState.puzzle_latched", GameState.puzzle_latched.get("archief_test", []).has("poort_1"))
	await moves("RR UU")
	check("onder poort_1 (7,2): %s" % tile(), tile() == Vector2i(7, 2))
	await pframes(20)
	await screenshot("04_opgelost")
	await moves("UU")
	check("op de uitgang X (7,0): %s" % tile(), tile() == Vector2i(7, 0))
	check("bericht bij X ('donkere gang')", Dialog.is_open and "dark corridor" in Dialog.text_label.text)
	await wait_until(func(): return not Dialog._is_typing(), 3.0)
	await pframes(2)
	await screenshot("05_uitgang_bericht")
	var guard := 0
	while Dialog.is_open and guard < 10:
		await press_interact()
		guard += 1
	await moves("U")
	check("boven X kun je niet verder (onzichtbare rand): %s" % tile(), tile() == Vector2i(7, 0) and not Dialog.is_open)

	# --- weg via E en terug = herstel (vergrendelde poort blijft open) ---
	await moves("DDDDDDDDD LLL D")
	check("via E naar het huis", await wait_scene("Huis"))
	check("in het huis op spawn 'binnen' (4,7): %s" % tile(), tile() == Vector2i(4, 7))
	await wait_fade()
	await tap("debug_puzzle")
	check("F4 (tijdelijk): terug naar de Test Room", await wait_scene("ArchiefTest"))
	room = scene()
	await wait_fade()
	check("terug: kasten op hun beginplek", block_ok(room, "kast_a", Vector2i(3, 6)) and block_ok(room, "kast_b", Vector2i(10, 6)))
	check("terug: hendel uit, poort_2 dicht", not room.logic.lever_on("hendel_h") and room.nodes["hendel_h"].sprite.frame == 0
			and not room.nodes["poort_2"].shape.disabled)
	check("terug: poort_1 nog open (vergrendeld, zelfde sessie)", room.logic.gate_open("poort_1") and room.nodes["poort_1"].shape.disabled
			and room.nodes["poort_1"].sprite.frame == 3)

	# --- gevecht midden in de puzzel: daarna staat alles nog zo ---
	await moves("UUUU RRRRRR D")
	check("kast_b naar (10,7) voor het gevecht", block_ok(room, "kast_b", Vector2i(10, 7)) and tile() == Vector2i(10, 6))
	GameState.start_battle(GameState.pick_encounter_group(), tile(), player().facing, "binnen")
	check("gevecht gestart", await wait_scene("Battle", 20.0))
	await _flee_battle()
	check("gevlucht (uitslag flee)", GameState.last_battle_result == "flee")
	check("terug in de Test Room na het gevecht", await wait_scene("ArchiefTest", 20.0))
	room = scene()
	await wait_fade()
	check("na gevecht: kast_b nog op (10,7), speler op (10,6): %s" % tile(), block_ok(room, "kast_b", Vector2i(10, 7)) and tile() == Vector2i(10, 6))

	# --- save/laden van de vergrendelde poort ---
	check("opslaan", GameState.save_game(tile(), player().facing))
	GameState.puzzle_latched.clear()
	check("laden: puzzle_latched terug uit de save", GameState.load_game() and GameState.puzzle_latched.get("archief_test", []).has("poort_1"))
	GameState.has_return_point = false


# ================================================================ v0.14 puzzelkamer 3B (Eerste Archief)
const ARCHIEF_SCENE := "res://scenes/maps/archief_puzzel.tscn"
## Zelfde oplossing als de testkamer; de kamer is 1 rij hoger (eerst 1x omhoog).
const ARCHIEF_SOLUTION := "U " + SOLUTION


func _test_archief_puzzel() -> void:
	var room: Dictionary = PuzzleRooms.ROOMS["archief_puzzel"]
	check("archief_puzzel: geldig (%s)" % [PuzzleLogic.validate(room)], PuzzleLogic.validate(room).is_empty())
	var l := PuzzleLogic.from_room(room, "archief_puzzel")
	check("archief_puzzel: spawn (5,17) omhoog, X (8,7) binnenin met richting omlaag", l.spawn_tile == Vector2i(5, 17)
			and l.spawn_facing == U and l.inward_dir(Vector2i(8, 7)) == D)
	# v0.15 (RPG CODE): de haakjes zijn nu echte componenten (secret / plate / chest)
	check("componenten: geheime deur G (16,8) en schatkist T (13,3) massief, runeplaat s (15,9) niet",
			l.hooks.is_empty() and l.types["geheime_deur"] == "secret" and l.types["kist_vonkzwaard"] == "chest"
			and l.plates["plaat_s"]["hidden"] and l.is_solid(Vector2i(16, 8)) and l.is_solid(Vector2i(13, 3)) and not l.is_solid(Vector2i(15, 9)))
	check("schatkamer op dezelfde map: deur dicht = (16,7) ook massief; (16,6) doorgang, (16,5) schatkamervloer",
			l.is_solid(Vector2i(16, 7)) and not l.is_solid(Vector2i(16, 6)) and not l.is_solid(Vector2i(16, 5)))
	var p := _sim(l, l.spawn_tile, ARCHIEF_SOLUTION)
	check("bedoelde oplossing: speler op X (8,7): %s, poort 1 vergrendeld" % p, p == Vector2i(8, 7) and l.latched_ids().has("poort_1"))
	l = PuzzleLogic.from_room(room, "archief_puzzel")
	# geheime route: kast c 1x rechts, 6x omhoog op de (placeholder-)runeplaat
	p = _sim(l, Vector2i(13, 15), "R")
	p = _sim(l, Vector2i(15, 16), "UUUUUU")
	check("kast c kan op de runeplaat (15,9) (%s)" % l.blocks["kast_c"], l.blocks["kast_c"] == Vector2i(15, 9))
	check("runeplaat ingedrukt, maar zonder poort 1 blijft de geheime deur dicht (massief)", l.plate_pressed("plaat_s")
			and not l.gate_open("geheime_deur"))
	check("de kast kan niet verder de muur in", l.is_solid(Vector2i(16, 8))
			and l.push_block_reason("kast_c", U) == "muur")


func _archief_integration() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.change_map(ARCHIEF_SCENE, "ingang")
	check("puzzelkamer 3B geladen", await wait_scene("ArchiefPuzzel"))
	await wait_fade()
	var r := scene()
	check("3B: ingang (5,17)", tile() == Vector2i(5, 17))
	var g: TileMapLayer = r.get_node("Ground")
	check("3B: dungeontegels (v0.15 grijs thema), boog boven X (8,8)=43", str(g.tile_set.get_source(0).texture.resource_path).ends_with("archief_grijs_tiles.png")
			and g.get_cell_atlas_coords(Vector2i(8, 8)) == Vector2i(11, 2) and g.get_cell_atlas_coords(Vector2i(5, 18)) == Vector2i(0, 4))
	var door: Node = r.nodes.get("geheime_deur")
	var plate: Node = r.nodes.get("plaat_s")
	var chest: Node = r.nodes.get("kist_vonkzwaard")
	check("componenten (v0.15): geheime deur (16,8), runeplaat (15,9), schatkist (13,3)", door != null and plate != null and chest != null
			and door.tile == Vector2i(16, 8) and plate.tile == Vector2i(15, 9) and chest.tile == Vector2i(13, 3) and not door.is_open)
	check("schatkamer afgedekt (PH_SchatkamerDek)", r.hidden_cover != null and r.hidden_cover.visible)
	check("vaste kasten = kast_vast.png (grijs thema)", r.get_node_or_null("Objects/VasteKast_1_9") != null
			and str(r.get_node("Objects/VasteKast_1_9").texture.resource_path).ends_with("grijs/kast_vast.png"))
	await pframes(10)
	await screenshot("v14_puzzelkamer")
	await moves(ARCHIEF_SOLUTION)
	check("oplossing gelopen -> X -> Gang 3C (spawn zuid)", await wait_scene("ArchiefV3Gang"))
	await wait_fade()
	check("3C: bij (8,10)", tile() == Vector2i(8, 10))
	await walk("move_down", 1)
	check("3C onderrand -> terug in de puzzelkamer bij X (uit_x)", await wait_scene("ArchiefPuzzel"))
	await wait_fade()
	r = scene()
	check("3B: bij uit_x (8,9), poort 1 blijft open", tile() == Vector2i(8, 9) and r.logic.gate_open("poort_1"))
	await walk("move_down", 3)
	await walk("move_right", 8)
	await walk("move_up", 3)
	check("voor de geheime deur (16,9): %s" % tile(), tile() == Vector2i(16, 9))
	await walk("move_up", 1)
	check("geheime deur blokkeert (dicht)", tile() == Vector2i(16, 9))
	# snelweg (de echte route test --archieftest): deur als 'al geopend' (zoals uit een save)
	r.logic.set_state({"blocks": {}, "levers": {}, "latched": ["poort_1", "geheime_deur"]})
	await wait_until(func():
		var d: Node = r.nodes.get("geheime_deur")
		return is_instance_valid(d) and not d.is_animating(), 3.0)
	for i in 30:   # eventueel bericht ('schrapen...') wegklikken
		if not Dialog.is_open:
			break
		Dialog.advance()
		await frames(2)
	await frames(3)
	await walk("move_up", 4)
	check("deur open: beide deurtegels beloopbaar, de schatkamer in (16,5): %s" % tile(), tile() == Vector2i(16, 5)
			and not r.hidden_cover.visible)
	await pframes(4)
	await screenshot("v14_schatkamer")
