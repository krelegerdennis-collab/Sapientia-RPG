extends Node
## ALLEEN VOOR TESTEN - DUNGEON100 GENERATOR (de Diepe Grot, 100 verdiepingen).
## Start:  godot --path . -- --dungeon100gentest [--shots=/pad/map]
##   Deel A: generator als data (determinisme, alle 100 verdiepingen geldig, ingang -> trap omlaag
##           loopbaar op de ECHTE botsing, slots voor monsters/kisten/rustpunt/baas, kamerdata).
##   Deel B: GameState (velden, save/load, reset buiten de grot) en de ingang op de wereldkaart.
##   Deel C: echte scènes: wereldkaart -> verdieping 1 -> (lopend) trap omlaag -> 2 -> ladder omhoog
##           -> 1 -> wereldkaart; zelfde seed = zelfde verdieping; opslaan/laden in de grot.
## Zit niet in de export (scripts/tests/*).

const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const Content := preload("res://scripts/dungeon/dungeon100_content.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const DUNGEON := "res://scenes/maps/dungeon100.tscn"
const SEEDS := [1, 42, 20240607, 987654321, 2147483647]
const U := Vector2i.UP
const D := Vector2i.DOWN
const L := Vector2i.LEFT
const R := Vector2i.RIGHT

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	seed(1100)
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 600 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: generator ===")
	_generator_tests()
	print("=== Deel B: GameState + wereldkaart ===")
	_state_tests()
	print("=== Deel C: echte scènes ===")
	await _scene_tests()
	print("DUNGEON100GENTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(10)
	get_tree().quit(1 if failures else 0)


# ================================================================ helpers
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


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


## Wacht tot de Diepe Grot op verdieping n staat (een nieuwe scène-instantie, klaar en uitgefaded).
func wait_floor(n: int, timeout := 12.0) -> bool:
	var ok := await wait_until(func():
		var s := scene()
		return s != null and s.name == "Dungeon100" and s.is_node_ready() and not GameState.changing_map \
				and int(s.get("floor_no")) == n and GameState.dungeon100_floor == n, timeout)
	await wait_fade()
	return ok


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func clear_monsters(r: Node) -> void:
	if "monsters" in r and r.get("monsters") is Array:
		for m in r.monsters:
			m.queue_free()
		r.monsters.clear()


func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for i in n:
		var p := player()
		if p == null or scene() != start_scene or GameState.changing_map or GameState.in_battle:
			return
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(p) and not p.is_moving and waited < 6:
			await get_tree().physics_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		if GameState.changing_map or Dialog.is_open or GameState.in_battle:
			return


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	var path := shots.path_join(name + ".png")
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("INFO  screenshot: ", path, " ", img.get_size())


## Fresh genereren (geen cache), zodat determinisme echt getest wordt.
func fresh(run_seed: int, f: int) -> Dictionary:
	Gen._cache.clear()
	return Gen.generate(run_seed, f)


func tile_of(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func ch_at(layout: Array, t: Vector2i) -> String:
	if t.y < 0 or t.y >= layout.size() or t.x < 0 or t.x >= str(layout[t.y]).length():
		return ""
	return str(layout[t.y])[t.x]


# ================================================================ deel A
func _generator_tests() -> void:
	# --- zaden en id's
	var s1: int = Gen.floor_seed(42, 7)
	check("floor_seed: zelfde invoer = zelfde zaad, 31 bit, nooit 0", s1 == Gen.floor_seed(42, 7) and s1 > 0 and s1 <= 0x7FFFFFFF
			and Gen.floor_seed(0, 0) > 0)
	var uniq := {}
	for f in range(1, 101):
		uniq[Gen.floor_seed(42, f)] = true
	check("floor_seed: 100 verdiepingen geven 100 verschillende zaden", uniq.size() == 100)
	check("floor_seed: ander run-seed = ander zaad", Gen.floor_seed(42, 7) != Gen.floor_seed(43, 7))
	check("room_id/parse_room_id round trip", Gen.parse_room_id(Gen.room_id(777, 55)) == [777, 55]
			and Gen.parse_room_id("archief_ingang").is_empty() and Gen.parse_room_id("dungeon100_5_0").is_empty()
			and Gen.parse_room_id("dungeon100_5_101").is_empty() and Gen.parse_room_id("dungeon100_x_3").is_empty())
	check("DungeonRooms.room() kent dungeon100-id's (en laat de rest met rust)",
			not DR.room(Gen.room_id(5, 3)).is_empty() and DR.room("archief_ingang").has("layout") and DR.room("dungeon100_5_0").is_empty())
	check("is_boss_floor: 10, 20 ... 100 (niet 0, niet 5)", Gen.is_boss_floor(10) and Gen.is_boss_floor(100)
			and not Gen.is_boss_floor(0) and not Gen.is_boss_floor(5) and not Gen.is_boss_floor(95))

	# --- determinisme
	var det_ok := true
	var diff_seed := false
	var diff_floor := false
	for sd in SEEDS:
		for f in [1, 2, 10, 33, 99, 100]:
			var a := fresh(sd, f)
			var b := fresh(sd, f)
			if a.is_empty() or JSON.stringify(_plain(a)) != JSON.stringify(_plain(b)):
				det_ok = false
			if a["layout"] != fresh(sd + 1, f)["layout"]:
				diff_seed = true
			if a["layout"] != fresh(sd, f + 1 if f < 100 else 99)["layout"]:
				diff_floor = true
	check("determinisme: (seed, verdieping) -> exact dezelfde data (layout, slots, kamerdata) bij opnieuw genereren", det_ok)
	check("andere seed geeft een andere kaart", diff_seed)
	check("andere verdieping geeft een andere kaart", diff_floor)
	Gen._cache.clear()
	var c1 := Gen.generate(9, 4)
	check("cache geeft hetzelfde object terug", is_same(c1, Gen.generate(9, 4)))

	# --- alle verdiepingen 1..100 geldig, meerdere seeds
	var t0 := Time.get_ticks_msec()
	var bad: Array[String] = []
	var rooms_min := 99
	var monsters_total := 0
	var chests_total := 0
	var boss_floors := 0
	var checked := 0
	for sd in SEEDS:
		for f in range(1, 101):
			var why := _validate(fresh(sd, f), sd, f)
			checked += 1
			if why != "":
				bad.append("seed %d vd %d: %s" % [sd, f, why])
			else:
				var d := Gen.generate(sd, f)
				rooms_min = mini(rooms_min, d["rooms"].size())
				monsters_total += d["monster_slots"].size()
				chests_total += d["chest_slots"].size()
				if d["is_boss_floor"]:
					boss_floors += 1
	check("%d verdiepingen (%d seeds x 100) geldig: layout, tegels, botsing, trappen, slots, kamerdata (fouten: %s)" % [checked, SEEDS.size(), bad.slice(0, 3)],
			bad.is_empty())
	check("elke verdieping heeft minstens %d kamers (min = %d)" % [Gen.MIN_ROOMS, rooms_min], rooms_min >= Gen.MIN_ROOMS)
	check("monster- en kistslots komen voor (%d monsters, %d kisten)" % [monsters_total, chests_total], monsters_total > checked * 2 and chests_total > checked / 2)
	check("bazen-slots alleen op verdieping 10, 20 ... 100 (%d keer)" % boss_floors, boss_floors == SEEDS.size() * 10)
	print("INFO  %d verdiepingen gegenereerd+gecontroleerd in %d ms" % [checked, Time.get_ticks_msec() - t0])

	# --- noodindeling
	var fb_ok := true
	for i in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + i
		var d: Dictionary = Gen._build(rng, 31 + i, 1 + i * 19, true)
		if d.is_empty() or _validate(d, 31 + i, 1 + i * 19) != "":
			fb_ok = false
	check("noodindeling (4-5 vaste kamers) levert geldige verdiepingen", fb_ok)

	# --- verdieping 1 en 100
	var f1 := fresh(1, 1)
	check("verdieping 1: ladder omhoog -> wereldkaart 'van_dungeon100', trap omlaag -> dezelfde scène 'omhoog'",
			f1["room"]["exits"]["h"] == {"map": Gen.WORLD_SCENE, "spawn": Gen.WORLD_SPAWN}
			and f1["room"]["exits"]["v"] == {"map": Gen.SCENE, "spawn": "omhoog"})
	var f2 := fresh(1, 2)
	check("verdieping 2: ladder omhoog -> dezelfde scène, spawn 'omlaag'", f2["room"]["exits"]["h"] == {"map": Gen.SCENE, "spawn": "omlaag"})
	var f100 := fresh(1, 100)
	check("verdieping 100: geen trap omlaag (tegel 'v', exit 'v', spawn 'omlaag') maar wel een baas-slot",
			not f100["has_stairs_down"] and f100["stairs_down"] == Gen.NO_TILE and not f100["room"]["exits"].has("v")
			and not f100["room"]["spawns"].has("omlaag") and f100["boss_slot"] != Gen.NO_TILE
			and not "\n".join(f100["layout"]).contains("v"))

	# --- inhoud
	check("tier_for_floor: 1 t/m 4, nooit omlaag", Content.tier_for_floor(1) == 1 and Content.tier_for_floor(25) == 1
			and Content.tier_for_floor(26) == 2 and Content.tier_for_floor(100) == 4
			and range(1, 100).all(func(i): return Content.tier_for_floor(i) <= Content.tier_for_floor(i + 1)))
	check("vijanden-pool groeit mee met de verdieping", Content.enemy_pool(1).size() < Content.enemy_pool(30).size()
			and Content.enemy_pool(30).size() < Content.enemy_pool(100).size())
	check("alle vijanden en voorwerpen in de inhoud bestaan in game_data.gd",
			range(1, 101).all(func(i): return Content.enemy_pool(i).all(func(e): return GD.ENEMIES.has(e)))
			and range(1, 101).all(func(i): return fresh(1, i)["room"]["chests"].all(func(c): return c["loot"]["items"].all(
					func(e): return GD.ITEMS.has(e["item"]) or GD.EQUIPMENT.has(e["item"])))))


## Een dictionary zonder Vector2i/Rect2i (zodat JSON.stringify ze vergelijkbaar maakt).
func _plain(v) -> Variant:
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _plain(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _plain(x))
	if v is Vector2i or v is Rect2i:
		return str(v)
	return v


## "" = geldig, anders de reden.
func _validate(d: Dictionary, run_seed: int, f: int) -> String:
	if d.is_empty():
		return "leeg"
	var room: Dictionary = d["room"]
	var layout: Array = d["layout"]
	var size: Vector2i = d["size"]
	if int(d["floor"]) != f or int(d["run_seed"]) != run_seed or layout.size() != size.y:
		return "kop klopt niet"
	var legend := DR.legend_of(room)
	var up_ladder := 0
	var down := 0
	for y in layout.size():
		var row := str(layout[y])
		if row.length() != size.x:
			return "rij %d verkeerde lengte" % y
		for x in row.length():
			if not legend.has(row[x]):
				return "onbekend teken '%s'" % row[x]
			up_ladder += 1 if row[x] == "H" else 0
			down += 1 if row[x] == "v" else 0
	# rand dicht (geen vloer op de buitenrand)
	for x in size.x:
		for y in [0, size.y - 1]:
			if not DR.is_solid(int(legend[ch_at(layout, Vector2i(x, y))]), DR.DEFAULT_THEME):
				return "buitenrand open op (%d,%d)" % [x, y]
	for y in size.y:
		for x in [0, size.x - 1]:
			if not DR.is_solid(int(legend[ch_at(layout, Vector2i(x, y))]), DR.DEFAULT_THEME):
				return "buitenrand open op (%d,%d)" % [x, y]
	# ladder: H boven h, spawn eronder, exits bestaan voor elk exit-teken
	var spawn_up: Vector2i = d["spawn_up"]
	if ch_at(layout, spawn_up + U) != "h" or ch_at(layout, spawn_up + U * 2) != "H" or up_ladder != 1:
		return "ladder omhoog klopt niet"
	if tile_of(room["spawns"]["omhoog"]) != spawn_up:
		return "spawn 'omhoog' klopt niet"
	var chars := {}
	for row in layout:
		for c in str(row):
			if DR.EXIT_CHARS.has(c):
				chars[DR.EXIT_CHARS[c]] = true
	for key in chars:
		if not room["exits"].has(key):
			return "exit-teken '%s' zonder doel" % key
	for key in room["exits"]:
		if not chars.has(key):
			return "exit '%s' zonder tegels" % key
	var reach := Gen.reachable_tiles(room, spawn_up)
	if f < Gen.MAX_FLOOR:
		var st: Vector2i = d["stairs_down"]
		if down != 1 or ch_at(layout, st) != "v":
			return "trap omlaag ontbreekt"
		if not reach.has(st):
			return "trap omlaag niet bereikbaar vanaf de ingang"
		var sdn: Vector2i = d["spawn_down"]
		if not reach.has(sdn) or absi(sdn.x - st.x) + absi(sdn.y - st.y) != 1 or tile_of(room["spawns"]["omlaag"]) != sdn:
			return "spawn 'omlaag' klopt niet"
	elif down != 0 or d["has_stairs_down"]:
		return "verdieping 100 heeft een trap omlaag"
	# alle kamers bereikbaar
	var rooms: Array = d["rooms"]
	for r in rooms:
		var found := false
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				found = found or reach.has(Vector2i(x, y))
		if not found:
			return "kamer %s niet bereikbaar" % [r]
	# slots: loopbaar, bereikbaar, uniek, ver van de ingang
	var seen := {}
	for t in d["monster_slots"]:
		if not reach.has(t) or seen.has(t):
			return "monster-slot %s onbereikbaar of dubbel" % [t]
		if absi(t.x - spawn_up.x) + absi(t.y - spawn_up.y) < Gen.MIN_SLOT_DISTANCE:
			return "monster-slot %s te dicht bij de ingang" % [t]
		seen[t] = true
	for t in d["chest_slots"]:
		if seen.has(t):
			return "kist-slot %s dubbel/op monster" % [t]
		seen[t] = true
		if ch_at(layout, t) == "v" or DR.is_solid(int(legend[ch_at(layout, t)]), DR.DEFAULT_THEME):
			return "kist-slot %s niet op vloer" % [t]
	if not reach.has(d["rest_slot"]) or seen.has(d["rest_slot"]):
		return "rustpunt-slot onbereikbaar of bezet"
	if bool(d["is_boss_floor"]) != (f % 10 == 0) or (d["boss_slot"] != Gen.NO_TILE) != bool(d["is_boss_floor"]):
		return "baas-slot klopt niet met de verdieping"
	if d["boss_slot"] != Gen.NO_TILE:
		for dx in 2:
			for dy in 2:
				var bt: Vector2i = d["boss_slot"] + Vector2i(dx, dy)
				if not reach.has(bt) or seen.has(bt) or bt == d["stairs_down"]:
					return "baas-gebied %s niet vrij" % [bt]
	# kamerdata: monsters/kisten uit de inhoud
	var ids := {}
	for m in room["monsters"]:
		if ids.has(m["id"]) or not GD.ENEMIES.has(m["enemy"]) or not (m["group"] as Array).all(func(e): return GD.ENEMIES.has(e)):
			return "monster %s ongeldig" % [m]
		ids[m["id"]] = true
		if not reach.has(tile_of(m["tile"])):
			return "monster %s staat op een onbereikbare tegel" % [m["id"]]
	var boss_n := 1 if d["is_boss_floor"] else 0     # de baas (Dungeon100Content.boss) staat op boss_slot, niet op een monster-slot
	if room["monsters"].size() != d["monster_slots"].size() + boss_n or room["chests"].size() != d["chest_slots"].size():
		return "aantal monsters/kisten komt niet overeen met de slots"
	for c in room["chests"]:
		if ids.has(c["id"]) or not (GD.ITEMS.has(c["item"]) or GD.EQUIPMENT.has(c["item"])) or int(c["n"]) < 1:
			return "kist %s ongeldig" % [c]
		ids[c["id"]] = true
	if int(room["tier"]) != Content.tier_for_floor(f) or not str(room["name"]).contains(str(f)) or int(room["dungeon100_floor"]) != f:
		return "kamerkop klopt niet"
	return ""


# ================================================================ deel B
func _state_tests() -> void:
	GameState.new_game("Dennis")
	check("GameState: dungeon100_floor en dungeon100_seed beginnen op 0", GameState.dungeon100_floor == 0 and GameState.dungeon100_seed == 0)
	GameState.dungeon100_floor = 37
	GameState.dungeon100_seed = 123456789
	check("opslaan lukt", GameState.save_game(Vector2i(3, 4), Vector2i.DOWN))
	GameState.new_game("Dennis")
	check("new_game zet de velden terug op 0", GameState.dungeon100_floor == 0 and GameState.dungeon100_seed == 0)
	check("load_game: verdieping en seed komen terug", GameState.load_game() and GameState.dungeon100_floor == 37 and GameState.dungeon100_seed == 123456789)
	var raw := GameState.read_save()
	raw.erase("dungeon100")
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	GameState.dungeon100_floor = 5
	check("oude save zonder 'dungeon100' laadt gewoon (0/0)", GameState.load_game() and GameState.dungeon100_floor == 0 and GameState.dungeon100_seed == 0)
	raw["dungeon100"] = {"floor": 999, "seed": "kapot"}
	f = FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	check("kapotte/te grote waarden worden begrensd (floor 999 = ongeldig = 0, seed 0)", GameState.load_game() and GameState.dungeon100_floor == 0 and GameState.dungeon100_seed == 0)
	GameState.dungeon100_floor = 12
	GameState.enter_map("res://scenes/maps/wilgendal.tscn")
	check("enter_map buiten de grot zet de verdieping op 0 (ook na game over)", GameState.dungeon100_floor == 0)
	GameState.dungeon100_floor = 12
	GameState.enter_map(DUNGEON)
	check("enter_map in de grot laat de verdieping staan", GameState.dungeon100_floor == 12)
	GameState.dungeon100_floor = 0

	# wereldkaart: ingang
	var ws: PackedScene = GameState.get_resource(WORLD)
	var w: Node = ws.instantiate()
	var ex: Node = w.get_node_or_null("Exits/NaarDiepeGrot")
	check("wereldkaart: uitgang 'NaarDiepeGrot' -> dungeon100.tscn, spawn 'omhoog'",
			ex != null and ex.target_map == DUNGEON and ex.target_spawn == "omhoog" and ResourceLoader.exists(DUNGEON))
	var sp: Node2D = w.get_node_or_null("Spawns/van_dungeon100")
	check("wereldkaart: spawn 'van_dungeon100' bestaat", sp != null)
	var ground: TileMapLayer = w.get_node("Ground")
	var et: Vector2i = ex.tile_rect().position if ex else Vector2i.ZERO
	check("ingang ligt op een loopbare wereldtegel met het grot-icoon (iconen-atlas, geen nieuwe art): %s" % et,
			ground.get_cell_source_id(et) == 1 and ground.get_cell_atlas_coords(et) == Vector2i(4, 0)
			and _world_walkable(ground, et))
	var st: Vector2i = Vector2i((sp.position / 16.0).floor()) if sp else Vector2i.ZERO
	var dist_arch := _world_dist(ground, st, Vector2i(20, 34))
	var dist_town := _world_dist(ground, st, Vector2i(30, 24))
	check("de spawn bij de ingang is loopbaar en verbonden met het Wachtershuis en Willowdale (%d / %d stappen)" % [dist_arch, dist_town],
			_world_walkable(ground, st) and dist_arch > 0 and dist_town > 0 and st == et + D)
	var overlap := false
	for e in w.get_node("Exits").get_children():
		if e != ex and e.tile_rect().intersects(ex.tile_rect()):
			overlap = true
	check("geen andere uitgang op de ingang-tegel", not overlap)
	w.free()


func _world_walkable(g: TileMapLayer, t: Vector2i) -> bool:
	var td := g.get_cell_tile_data(t)
	return td != null and not (str(td.get_custom_data("terrain")) in ["berg", "zee"])


func _world_dist(g: TileMapLayer, from: Vector2i, to: Vector2i) -> int:
	var dist := {from: 0}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		if t == to:
			return dist[t]
		for d in [U, D, L, R]:
			var n: Vector2i = t + d
			if not dist.has(n) and _world_walkable(g, n):
				dist[n] = dist[t] + 1
				todo.append(n)
	return -1


# ================================================================ deel C
## Kortste route (tegels) over de echte botsing van de gebouwde kamer.
func _route(r: Node, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev := {from: from}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		if t == to:
			break
		for d in [U, D, L, R]:
			var n: Vector2i = t + d
			if prev.has(n) or r.is_wall(n):
				continue
			prev[n] = t
			todo.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var cur := to
	while cur != from:
		out.push_front(cur)
		cur = prev[cur]
	return out


func _walk_route(path: Array[Vector2i]) -> void:
	for t in path:
		var d: Vector2i = t - tile()
		if d.length() != 1:
			return
		await walk({U: "move_up", D: "move_down", L: "move_left", R: "move_right"}[d], 1)
		if GameState.changing_map:
			return


func _scene_tests() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.change_map(WORLD, "van_dorp")
	check("wereldkaart geladen", await wait_scene("Wereldkaart"))
	await wait_fade()
	# de echte ingang: naast de tegel staan en erop stappen
	var ex: Node = scene().get_node("Exits/NaarDiepeGrot")
	var et: Vector2i = ex.tile_rect().position
	player().place_at(et + D, U)
	await pframes(2)
	await walk("move_up", 1)
	check("op de ingang stappen -> Deep Cave", await wait_scene("Dungeon100"))
	await wait_fade()
	var r := scene()
	check("verdieping 1 en een gekozen seed: %d / %d" % [GameState.dungeon100_floor, GameState.dungeon100_seed],
			GameState.dungeon100_floor == 1 and GameState.dungeon100_seed > 0 and r.floor_no == 1)
	var run_seed: int = GameState.dungeon100_seed
	var d: Dictionary = Gen.generate(run_seed, 1)
	clear_monsters(r)
	check("speler staat op de ingang (spawn_up %s), kijkt omlaag" % [d["spawn_up"]], tile() == d["spawn_up"] and player().facing == D)
	check("kamer is dezelfde als de generator: id, naam, layout, monsters en kisten",
			r.room_id == Gen.room_id(run_seed, 1) and r.map_name == "Deep Cave - Floor 1" and r.room["layout"] == d["layout"]
			and r.chests.size() == d["chest_slots"].size() and r.cell(d["stairs_down"]) == 58 and r.cell(d["stairs_up"]) == 45
			and not r.is_wall(d["spawn_up"]) and r.is_wall(d["spawn_up"] + Vector2i(-3, -3)))
	check("geen random encounters in de grot, terrein = archief", not r.encounters and r.terrain_at(d["spawn_up"]) == "archief")
	await screenshot("d100_verdieping1")
	# lopend van de ingang naar de trap omlaag (echte botsing, 1 tegel per stap)
	var route := _route(r, d["spawn_up"], d["stairs_down"])
	check("route ingang -> trap omlaag bestaat op de echte botsing (%d stappen)" % route.size(), not route.is_empty())
	await _walk_route(route.slice(0, route.size() - 1))
	check("vlak voor de trap (naast %s): %s" % [d["stairs_down"], tile()], (tile() - d["stairs_down"]).length() == 1)
	await screenshot("d100_bij_de_trap")
	await walk({U: "move_up", D: "move_down", L: "move_left", R: "move_right"}[d["stairs_down"] - tile()], 1)
	check("op de trap stappen -> verdieping 2 (dezelfde scène opnieuw)", await wait_floor(2))
	var r2 := scene()
	var d2: Dictionary = Gen.generate(run_seed, 2)
	check("verdieping 2: nieuwe kamer, speler op de ingang (ladder) van 2: %s" % tile(),
			r2 != r and r2.floor_no == 2 and r2.map_name == "Deep Cave - Floor 2" and tile() == d2["spawn_up"]
			and r2.room["layout"] == d2["layout"] and d2["layout"] != d["layout"])
	clear_monsters(r2)
	await screenshot("d100_verdieping2")
	# ladder omhoog: terug naar verdieping 1, aankomst bij de trap omlaag
	await walk("move_up", 1)
	check("ladder omhoog -> verdieping 1", await wait_floor(1))
	var r3 := scene()
	check("terug op verdieping 1: dezelfde kaart (zelfde seed), speler naast de trap omlaag %s" % tile(),
			r3.floor_no == 1 and r3.room["layout"] == d["layout"] and tile() == d["spawn_down"])
	clear_monsters(r3)
	# opslaan midden in de grot en laden
	GameState.dungeon100_floor = 1
	check("opslaan op verdieping 1", GameState.save_game(tile(), player().facing))
	var saved := GameState.read_save()
	check("save bevat verdieping en seed", int(saved["dungeon100"]["floor"]) == 1 and int(saved["dungeon100"]["seed"]) == run_seed
			and str(saved["map"]) == DUNGEON)
	# via de ladder naar buiten
	var up_route := _route(r3, tile(), d["spawn_up"])
	await _walk_route(up_route)
	await walk("move_up", 1)
	check("ladder op verdieping 1 vraagt eerst om bevestiging (Het Gesimuleerde Archief)",
			await wait_until(func(): return Dialog.has_choices(), 5.0))
	Dialog.choose(0)       # Verlaten
	check("ladder op verdieping 1 -> wereldkaart", await wait_scene("Wereldkaart"))
	await wait_fade()
	var wsp: Node2D = scene().get_node("Spawns/van_dungeon100")
	check("buiten de grot: verdieping 0, speler bij de ingang op de wereldkaart %s" % tile(),
			GameState.dungeon100_floor == 0 and tile() == Vector2i((wsp.position / 16.0).floor()) and GameState.dungeon100_seed == 0
			and not GameState.dungeon100_run_active())
	# opnieuw naar binnen: een nieuwe run kiest een nieuwe seed
	player().place_at(et + D, U)
	await pframes(2)
	await walk("move_up", 1)
	await wait_floor(1)
	var seed2: int = GameState.dungeon100_seed
	check("opnieuw binnen: nieuwe run, verdieping 1 met een nieuwe seed (%d)" % seed2,
			GameState.dungeon100_floor == 1 and seed2 != 0 and seed2 != run_seed and GameState.dungeon100_run_active()
			and scene().room["layout"] == Gen.generate(seed2, 1)["layout"])
	# laden uit de save: verdieping 3 op een bossen-verdieping (10) opent ook gewoon
	GameState.dungeon100_floor = 10
	GameState.change_map(DUNGEON, "omhoog")
	await wait_floor(10)
	var rb := scene()
	var db: Dictionary = Gen.generate(seed2, 10)
	check("verdieping 10 (baasverdieping) laadt: baas-slot %s vrij en bereikbaar" % [db["boss_slot"]],
			rb.floor_no == 10 and db["boss_slot"] != Gen.NO_TILE and not rb.is_wall(db["boss_slot"]) and not rb.is_wall(db["boss_slot"] + Vector2i(1, 1)))
	check("floor_ready-signaal en floor_data aanwezig", rb.floor_data == db)
	await screenshot("d100_verdieping10")
	# verdieping 100
	GameState.dungeon100_floor = 100
	GameState.change_map(DUNGEON, "omhoog")
	await wait_floor(100)
	check("verdieping 100 laadt zonder trap omlaag", scene().floor_no == 100 and not scene().floor_data["has_stairs_down"]
			and scene().get_node("Exits").get_children().size() == 1)
	# laden uit de save
	GameState.new_game("Dennis")
	check("load_game (uit de save op verdieping 1)", GameState.load_game())
	check("na laden: verdieping 1, seed %d" % run_seed, GameState.dungeon100_floor == 1 and GameState.dungeon100_seed == run_seed)
	GameState._go_to_scene(GameState.return_map)
	await wait_floor(1)
	check("na laden: Deep Cave verdieping 1, speler op de opgeslagen tegel %s" % tile(),
			scene().floor_no == 1 and scene().room["layout"] == d["layout"] and tile() == d["spawn_down"])
	GameState.encounter_multiplier = 1.0
