class_name Dungeon100Generator
extends RefCounted
## DUNGEON100: de Diepe Grot, een procedurele kerker van maximaal 100 verdiepingen.
## Elke verdieping wordt gegenereerd uit (run-seed, verdiepingsnummer): dezelfde invoer geeft
## ALTIJD dezelfde kaart (RandomNumberGenerator met een eigen seed, geen globale random).
## Het resultaat is gewone DungeonRoom-data (scripts/data/dungeon_rooms.gd formaat), dus de
## kamerbouwer (scripts/dungeon/dungeon_room.gd) tekent, botst en bouwt uitgangen/monsters/kisten
## zonder aanpassing. Zie HANDOFF_DUNGEON100.md voor de API (spawnpunten, trappen, haken).
##
## Algoritme (alles op een tegelraster, 1 cel = 1 tegel):
##   1. 6-10 kamers (5-10 x 4-7) zonder overlap, plus een Prim-boom van gangen (1 of 2 breed)
##      en 1-2 extra lussen: alle kamers hangen dus aan elkaar.
##   2. Dunne muren (1 dik) tussen twee vloeren worden dichtgemaakt, zodat de 2 hoge muurvoorkant
##      (docs/DUNGEON_TILES.txt) altijd past.
##   3. Ladder omhoog in de bovenmuur van de ingangskamer, trap omlaag (tegel 58) in de hoek van
##      de kamer die het verst (loopafstand) van de ingang ligt. Verdieping 100 heeft geen trap omlaag.
##   4. Steenhopen/kasten als obstakel (nooit in ingangs- of trapkamer, nooit op de rand van een kamer).
##   5. Slots voor monsters, kisten, rustpunt, baas en (op verdieping 1, 25, 50, 75 en 99) een warper;
##      kisten en de warper worden alleen gezet als de trap daarna nog bereikbaar is.
##   6. Tegels: muurtop-autotile, voorkant (2 hoog), schaduw onder de voorkant, vloerdecor.
##   7. Controle (BFS op de uiteindelijke botsing): ingang -> trap omlaag moet loopbaar zijn.

const Content := preload("res://scripts/dungeon/dungeon100_content.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const Layouts := preload("res://scripts/data/grot_layouts.gd")
const GrotKamers := preload("res://scripts/data/grot_kamers.gd")

const MAX_FLOOR := 100
const SCENE := "res://scenes/maps/dungeon100.tscn"
const WORLD_SCENE := EchoGrot.KAMER
const WORLD_SPAWN := EchoGrot.KAMER_SPAWN
const ROOM_PREFIX := "dungeon100_"
## Spawnpuntnamen in de kamer: aankomst van boven (via de ladder) en van onder (via de trap).
const SPAWN_FROM_ABOVE := "omhoog"
const SPAWN_FROM_BELOW := "omlaag"
## Ontwaken bij het rustpunt na een nederlaag (alleen op rustverdiepingen; zelfde naam als Dungeon100Rules.REST_SPAWN).
const SPAWN_REST := "rustpunt"
## Aankomst via een warper, naast het kristal (zelfde naam als Dungeon100Rules.WARPER_SPAWN).
const SPAWN_WARPER := "warper"
const NO_TILE := Vector2i(-1, -1)
## Tegelthema (scripts/data/dungeon_rooms.gd THEMES, RPG ART). Basis; per verdieping: theme_for_floor.
const THEME := "diepe_grot"
const THEME_INTERVAL := 15
const THEME_VARIANTS := 7


## Tegelvariant 1-7 van een verdieping: 1-15 -> 1, 16-30 -> 2, ... 91-100 -> 7.
@warning_ignore("integer_division")
static func theme_variant(floor_no: int) -> int:
	return mini(maxi(floor_no - 1, 0) / THEME_INTERVAL, THEME_VARIANTS - 1) + 1


static func theme_for_floor(floor_no: int) -> String:
	return "%s_v%d" % [THEME, theme_variant(floor_no)]

const MIN_ROOMS := 1
## Minimum aantal kamers op een MEDIUM-kaart (25x25).
const MIN_ROOMS_MEDIUM := 3
const MAX_ATTEMPTS := 24
const MIN_SLOT_DISTANCE := 6      # monsters beginnen minstens zoveel tegels (Manhattan) van de ingang

# celsoorten in het logische raster
const WALL := 0
const FLOOR := 1
const BLOCK := 2        # steenhoop / kast (massief)
const CHEST := 3        # kist (object, blokkeert)
const STAIRS := 4       # trap omlaag (loopbaar)

const DIRS4: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const BLOCK_CHARS := ["#", "B", "N"]
const DECOR_CHARS := ["w", "x", "p", ",", "X"]

static var _cache := {}


# ---------------------------------------------------------------- API
## Zaad voor één verdieping: vast per (run_seed, verdieping). 31 bit, nooit 0.
static func floor_seed(run_seed: int, floor_no: int) -> int:
	var h: int = (run_seed ^ (floor_no * 0x9E3779B1)) & 0xFFFFFFFF
	for i in 3:
		h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
		h = (h + floor_no * 0x27D4EB2F + i) & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0x7FFFFFFF
	return h if h != 0 else 1


## Kamer-id van een verdieping ("dungeon100_<seed>_<verdieping>"); DungeonRooms.room() zoekt die op.
static func room_id(run_seed: int, floor_no: int) -> String:
	return "%s%d_%d" % [ROOM_PREFIX, run_seed, floor_no]


## [run_seed, verdieping] uit een kamer-id, of [] als het geen dungeon100-id is.
static func parse_room_id(id: String) -> Array:
	if not id.begins_with(ROOM_PREFIX):
		return []
	var parts := id.trim_prefix(ROOM_PREFIX).rsplit("_", true, 1)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return []
	var f := int(parts[1])
	if f < 1 or f > MAX_FLOOR:
		return []
	return [int(parts[0]), f]


## De DungeonRoom-data van een dungeon100-kamer-id ({} = geen geldig id).
static func room_for_id(id: String) -> Dictionary:
	var p := parse_room_id(id)
	if p.is_empty():
		return {}
	return generate(int(p[0]), int(p[1])).get("room", {})


static func is_boss_floor(floor_no: int) -> bool:
	return Scaling.is_boss_floor(floor_no)


## Eén verdieping. Zie HANDOFF_DUNGEON100.md voor alle sleutels. {} alleen bij een programmeerfout.
static func generate(run_seed: int, floor_no: int) -> Dictionary:
	var f := clampi(floor_no, 1, MAX_FLOOR)
	var key := room_id(run_seed, f)
	if _cache.has(key):
		return _cache[key]
	var data := {}
	for attempt in MAX_ATTEMPTS + 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = floor_seed(run_seed, f) + attempt * 7919
		data = _build(rng, run_seed, f, attempt == MAX_ATTEMPTS)
		if not data.is_empty():
			break
	if data.is_empty():
		push_error("Dungeon100: verdieping %d (seed %d) kon niet gegenereerd worden" % [f, run_seed])
		return {}
	if _cache.size() > 8:
		_cache.clear()
	_cache[key] = data
	return data


## Alle loopbare tegels van de uiteindelijke kamerdata bereikbaar vanaf 'from' (BFS op de
## echte botsing: DungeonRooms.is_solid). Wordt ook door de tests gebruikt.
static func reachable_tiles(room: Dictionary, from: Vector2i) -> Dictionary:
	var DR := preload("res://scripts/data/dungeon_rooms.gd")
	var legend := DR.legend_of(room)
	var layout: Array = room["layout"]
	var blocked := {}
	for c in room.get("chests", []):
		blocked[Vector2i(int(c["tile"][0]), int(c["tile"][1]))] = true
	for p in room.get("props", []):
		blocked[Vector2i(int(p["tile"][0]), int(p["tile"][1]))] = true
	var seen := {from: 0}
	var queue: Array[Vector2i] = [from]
	var qi := 0
	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		for d in DIRS4:
			var n: Vector2i = cur + d
			if seen.has(n) or n.y < 0 or n.y >= layout.size() or n.x < 0 or n.x >= str(layout[n.y]).length():
				continue
			var ch := str(layout[n.y])[n.x]
			if not legend.has(ch) or DR.is_solid(int(legend[ch]), DR.DEFAULT_THEME) or blocked.has(n):
				continue
			seen[n] = int(seen[cur]) + 1
			queue.append(n)
	return seen


# ---------------------------------------------------------------- opbouw
## Layout-type van een verdieping (scripts/data/grot_layouts.gd), met de koopmanregel van GrotKamers.
static func layout_type(run_seed: int, floor_no: int) -> String:
	return GrotKamers.layout_soort(run_seed, floor_no)


## Kamers per kaartmaat: [aantal min, max, breedte min, max, hoogte min, max, marge, minimum].
static func _room_plan(size: Vector2i) -> Array:
	if size.x >= 50:
		return [10, 16, 6, 12, 5, 9, 3, 8]
	if size.x <= 12:
		return [1, 1, 8, 8, 7, 7, 0, 1]
	return [3, 5, 5, 8, 4, 6, 2, MIN_ROOMS_MEDIUM]


static func _build(rng: RandomNumberGenerator, run_seed: int, f: int, fixed: bool) -> Dictionary:
	var lt := layout_type(run_seed, f)
	var size := Layouts.maat(lt)
	var w := size.x
	var h := size.y
	var plan := _room_plan(size)
	if lt == Layouts.KOOPMAN:
		plan = [3, 4, 8, 9, 6, 6, 2, MIN_ROOMS_MEDIUM]      # ruimte voor de kraam (6x4 vrij, GrotKamers.koopman_plek)
	var rooms: Array[Rect2i] = _fixed_rooms_for(size) if fixed else _random_rooms(rng, w, h, plan)
	if rooms.size() < int(plan[7]):
		return {}
	var cells := PackedByteArray()
	cells.resize(w * h)
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				cells[y * w + x] = FLOOR
	_connect(rng, cells, w, h, rooms)
	_fill_thin_walls(cells, w, h)

	# ingang (ladder omhoog)
	var up := _pick_ladder(rng, cells, w, h, rooms)
	if up.is_empty():
		return {}
	var entry_room: int = up["room"]
	var spawn_up: Vector2i = up["spawn"]

	# trap omlaag in de verste kamer
	var dist := _distances(cells, w, h, spawn_up)
	var has_down := f < MAX_FLOOR
	var stairs_room := -1
	var best := -1
	for i in rooms.size():
		if i == entry_room:
			continue
		var c := _center(rooms[i])
		var d: int = dist.get(c, -1)
		if d > best:
			best = d
			stairs_room = i
	if stairs_room < 0 and rooms.size() == 1:
		stairs_room = entry_room
	if stairs_room < 0:
		return {}
	var sr: Rect2i = rooms[stairs_room]
	var stairs := Vector2i(sr.end.x - 1, sr.end.y - 1) if has_down else NO_TILE
	var spawn_down := Vector2i(sr.end.x - 2, sr.end.y - 1) if has_down else NO_TILE
	var boss_slot := Vector2i(sr.position.x + sr.size.x / 2 - 1, sr.position.y + sr.size.y / 2 - 1) if is_boss_floor(f) else NO_TILE
	if has_down:
		cells[stairs.y * w + stairs.x] = STAIRS

	# vaste slots
	var er: Rect2i = rooms[entry_room]
	var rest_slot := _center(er)
	var reserved := {spawn_up: true, rest_slot: true}
	if has_down:
		reserved[stairs] = true
		reserved[spawn_down] = true
	if boss_slot != NO_TILE:
		for dx in 2:
			for dy in 2:
				reserved[boss_slot + Vector2i(dx, dy)] = true

	# warper bij de ingang (verdieping 1, 25, 50, 75, 99). De tegel blokkeert straks als object;
	# de buren en de trap moeten bereikbaar blijven.
	var warper_slot := NO_TILE
	var warper_spawn := NO_TILE
	if Rules.is_warper_floor(f):
		var picked := _pick_warper(cells, w, h, er, reserved, spawn_up, has_down, stairs)
		if not picked.is_empty():
			warper_slot = picked["tile"]
			warper_spawn = picked["spawn"]
			reserved[warper_slot] = true
			if warper_spawn != spawn_up:
				reserved[warper_spawn] = true

	# obstakels
	for i in rooms.size():
		if i == entry_room or i == stairs_room or lt == Layouts.KOOPMAN:
			continue
		_place_blocks(rng, cells, w, rooms[i])

	# monsters, kisten: aantallen uit het layout-type (Layouts)
	var min_dist := Layouts.min_afstand(lt)
	var want_monsters := Layouts.monsters(run_seed, f, lt)
	var monster_slots: Array[Vector2i] = []
	var free_tiles: Array[Vector2i] = []
	for i in rooms.size():
		if i == stairs_room and boss_slot != NO_TILE:
			continue
		var r: Rect2i = rooms[i]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var t := Vector2i(x, y)
				if cells[t.y * w + t.x] == FLOOR and not reserved.has(t) \
						and absi(t.x - spawn_up.x) + absi(t.y - spawn_up.y) >= min_dist:
					free_tiles.append(t)
	for k in free_tiles.size():
		var j := rng.randi_range(k, free_tiles.size() - 1)
		var tmp := free_tiles[k]
		free_tiles[k] = free_tiles[j]
		free_tiles[j] = tmp
	for t in free_tiles:
		if monster_slots.size() >= want_monsters:
			break
		var near := false
		for o in monster_slots:
			if absi(o.x - t.x) + absi(o.y - t.y) < 2:
				near = true
				break
		if not near:
			monster_slots.append(t)
	# Blauwe kisten: blijft de bestaande kans per kist (Dungeon100Blue.kind_for); de overrides per
	# kamer-type (Chest Room 2 blauw enz.) horen bij de loot-taak van RPG CODE.
	var want_chests := Layouts.kisten(run_seed, f, lt)
	var chest_slots: Array[Vector2i] = _place_chests(rng, cells, w, rooms, reserved, monster_slots, spawn_up, want_chests)

	# controle op het logische raster: trap bereikbaar met kisten dicht
	if has_down and not _distances(cells, w, h, spawn_up).has(stairs):
		return {}

	var layout := _render(rng, cells, w, h, f, spawn_up, spawn_down, stairs)
	var data := {
		"floor": f, "run_seed": run_seed, "floor_seed": floor_seed(run_seed, f),
		"size": Vector2i(w, h), "layout": layout, "rooms": rooms,
		"entry_room": entry_room, "stairs_room": stairs_room,
		"spawn_up": spawn_up, "stairs_up": spawn_up + Vector2i.UP,
		"has_stairs_down": has_down, "stairs_down": stairs, "spawn_down": spawn_down,
		"monster_slots": monster_slots, "chest_slots": chest_slots,
		"boss_slot": boss_slot, "rest_slot": rest_slot,
		"warper_slot": warper_slot, "warper_spawn": warper_spawn,
		"is_boss_floor": is_boss_floor(f), "is_milestone": f % 10 == 0,
		"tier": Content.tier_for_floor(f),
		"layout_type": lt, "min_slot_distance": min_dist,
	}
	data["room"] = _room_dict(data)
	# eindcontrole op de echte tegels
	if has_down and not reachable_tiles(data["room"], spawn_up).has(stairs):
		return {}
	return data


## Kamerdata in het formaat van scripts/data/dungeon_rooms.gd + extra sleutels "dungeon100*".
static func _room_dict(d: Dictionary) -> Dictionary:
	var f: int = d["floor"]
	var exits := {}
	var here := SCENE
	exits["h"] = {"map": WORLD_SCENE, "spawn": WORLD_SPAWN} if f == 1 else {"map": here, "spawn": SPAWN_FROM_BELOW}
	if d["has_stairs_down"]:
		exits["v"] = {"map": here, "spawn": SPAWN_FROM_ABOVE}
	var spawns := {SPAWN_FROM_ABOVE: _spawn_arr(d["spawn_up"], "down")}
	if d["has_stairs_down"]:
		spawns[SPAWN_FROM_BELOW] = _spawn_arr(d["spawn_down"], "down")
	var room := {
		"name": "Deep Cave - Floor %d" % f,
		"floor": f, "tier": d["tier"],
		"layout": d["layout"], "spawns": spawns, "exits": exits,
		"monsters": [], "chests": [],
		"dungeon100": true, "dungeon100_floor": f, "dungeon100_layout": d["layout_type"],
		"theme": theme_for_floor(f),
	}
	Content.fill_room(room, d)
	# Empty Room: soms een lore-notitie (GrotKamers.notitie, ~30%).
	if d["layout_type"] == Layouts.LEEG:
		var nt := GrotKamers.notitie(int(d["run_seed"]), room, d)
		if not nt.is_empty():
			var t: Vector2i = nt["tile"]
			room["props"] = room.get("props", []) + [{"type": GrotKamers.NOTITIE_PROP, "tile": [t.x, t.y]}]
			room["signs"] = room.get("signs", []) + [{"tile": [t.x, t.y], "lines": nt["lines"]}]
			room["notitie"] = [t.x, t.y]
	if room.has("rustpunt"):
		var rp: Array = room["rustpunt"]
		var sp := _rest_spawn(room, d, Vector2i(int(rp[0]), int(rp[1])))
		if sp.has("tile"):
			spawns[SPAWN_REST] = _spawn_arr(sp["tile"], sp["facing"])
	var ws: Vector2i = d.get("warper_slot", NO_TILE)
	var wspawn: Vector2i = d.get("warper_spawn", NO_TILE)
	if ws != NO_TILE and wspawn != NO_TILE:
		room["warper"] = [ws.x, ws.y]
		spawns[SPAWN_WARPER] = _spawn_arr(wspawn, _facing_toward(wspawn, ws))
	return room


## Plek waar je ontwaakt na een nederlaag bij het rustpunt (spawn 'rustpunt'): een vrije,
## bereikbare buurtegel van het rustpunt, kijkend ernaartoe. {} als die er niet is (valt terug op de ladder).
static func _rest_spawn(room: Dictionary, d: Dictionary, rest: Vector2i) -> Dictionary:
	var reach := reachable_tiles(room, d["spawn_up"])
	var taken := {rest: true}
	for m in room.get("monsters", []):
		var sz: Array = m.get("size", [1, 1])
		for dx in int(sz[0]):
			for dy in int(sz[1]):
				taken[Vector2i(int(m["tile"][0]) + dx, int(m["tile"][1]) + dy)] = true
	for c in room.get("chests", []):
		taken[Vector2i(int(c["tile"][0]), int(c["tile"][1]))] = true
	for dir in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var t: Vector2i = rest + dir
		if reach.has(t) and not taken.has(t):
			var facing := "up" if dir == Vector2i.DOWN else "down" if dir == Vector2i.UP else "right" if dir == Vector2i.LEFT else "left"
			return {"tile": t, "facing": facing}
	return {}


static func _spawn_arr(t: Vector2i, facing: String) -> Array:
	return [t.x, t.y, facing]


static func _facing_toward(from: Vector2i, to: Vector2i) -> String:
	var dir := to - from
	if dir == Vector2i.UP:
		return "up"
	if dir == Vector2i.DOWN:
		return "down"
	if dir == Vector2i.LEFT:
		return "left"
	return "right"


## Warper in de ingangskamer, dicht bij de ladder. Geeft {tile, spawn} of {}.
## De warper-tegel mag de trap niet afsluiten; de spawn is een vrije buur (ook de ladder-tegel).
static func _pick_warper(cells: PackedByteArray, w: int, h: int, room_rect: Rect2i, reserved: Dictionary,
		spawn_up: Vector2i, has_down: bool, stairs: Vector2i) -> Dictionary:
	var near: Array[Vector2i] = []
	var far: Array[Vector2i] = []
	for y in range(room_rect.position.y, room_rect.end.y):
		for x in range(room_rect.position.x, room_rect.end.x):
			var t := Vector2i(x, y)
			if cells[y * w + x] != FLOOR or reserved.has(t):
				continue
			var dist := absi(t.x - spawn_up.x) + absi(t.y - spawn_up.y)
			if dist < 1:
				continue
			if dist <= 4:
				near.append(t)
			else:
				far.append(t)
	var picked := _first_safe_warper(cells, w, h, near, reserved, spawn_up, has_down, stairs)
	if not picked.is_empty():
		return picked
	return _first_safe_warper(cells, w, h, far, reserved, spawn_up, has_down, stairs)


static func _first_safe_warper(cells: PackedByteArray, w: int, h: int, tiles: Array[Vector2i],
		reserved: Dictionary, spawn_up: Vector2i, has_down: bool, stairs: Vector2i) -> Dictionary:
	var ordered: Array[Vector2i] = tiles.duplicate()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := absi(a.x - spawn_up.x) + absi(a.y - spawn_up.y)
		var db := absi(b.x - spawn_up.x) + absi(b.y - spawn_up.y)
		if da != db:
			return da < db
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y)
	for t in ordered:
		var spawn := _warper_neighbor(cells, w, t, reserved, spawn_up)
		if spawn == NO_TILE:
			continue
		var before := _distances(cells, w, h, spawn_up).size()
		cells[t.y * w + t.x] = BLOCK
		var after := _distances(cells, w, h, spawn_up)
		cells[t.y * w + t.x] = FLOOR
		if after.size() != before - 1:
			continue
		if has_down and not after.has(stairs):
			continue
		if not after.has(spawn):
			continue
		return {"tile": t, "spawn": spawn}
	return {}


static func _warper_neighbor(cells: PackedByteArray, w: int, tile: Vector2i, reserved: Dictionary, spawn_up: Vector2i) -> Vector2i:
	for dir in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var n: Vector2i = tile + dir
		if reserved.has(n) and n != spawn_up:
			continue
		if _at(cells, w, n.x, n.y) != FLOOR:
			continue
		return n
	return NO_TILE


# ---------------------------------------------------------------- kamers en gangen
static func _center(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)


static func _random_rooms(rng: RandomNumberGenerator, w: int, h: int, plan: Array) -> Array[Rect2i]:
	var want := rng.randi_range(int(plan[0]), int(plan[1]))
	var rooms: Array[Rect2i] = []
	if want == 1:
		rooms.append(Rect2i(2, 3, mini(int(plan[2]), w - 4), mini(int(plan[4]), h - 5)))
		return rooms
	for tries in 60 * want:
		if rooms.size() >= want:
			break
		var rw := rng.randi_range(int(plan[2]), int(plan[3]))
		var rh := rng.randi_range(int(plan[4]), int(plan[5]))
		if w - 2 - rw < 2 or h - 2 - rh < 3:
			continue
		var r := Rect2i(rng.randi_range(2, w - 2 - rw), rng.randi_range(3, h - 2 - rh), rw, rh)
		var ok := true
		for o in rooms:
			if r.grow(int(plan[6])).intersects(o):
				ok = false
				break
		if ok:
			rooms.append(r)
	rooms.sort_custom(func(a: Rect2i, b: Rect2i): return a.position.x < b.position.x or (a.position.x == b.position.x and a.position.y < b.position.y))
	return rooms


## Noodindeling per kaartmaat als willekeurige plaatsing mislukt.
static func _fixed_rooms_for(size: Vector2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if size.x <= 12:
		out.append(Rect2i(2, 3, 8, 7))
		return out
	if size.x >= 50:
		for gx in 3:
			for gy in 3:
				out.append(Rect2i(3 + gx * 16, 4 + gy * 15, 9, 7))
		return out
	return [Rect2i(2, 3, 7, 5), Rect2i(15, 3, 7, 5), Rect2i(2, 15, 7, 6), Rect2i(15, 15, 7, 6)]


static func _connect(rng: RandomNumberGenerator, cells: PackedByteArray, w: int, h: int, rooms: Array[Rect2i]) -> void:
	var linked: Array[int] = [0]
	var rest: Array[int] = []
	for i in range(1, rooms.size()):
		rest.append(i)
	while not rest.is_empty():
		var bi := -1
		var bj := -1
		var bd := 1 << 30
		for i in linked:
			for j in rest:
				var a := _center(rooms[i])
				var b := _center(rooms[j])
				var d := absi(a.x - b.x) + absi(a.y - b.y)
				if d < bd:
					bd = d
					bi = i
					bj = j
		_corridor(rng, cells, w, h, _center(rooms[bi]), _center(rooms[bj]))
		linked.append(bj)
		rest.erase(bj)
	for k in rng.randi_range(1, 2):
		var a := rng.randi_range(0, rooms.size() - 1)
		var b := rng.randi_range(0, rooms.size() - 1)
		if a != b:
			_corridor(rng, cells, w, h, _center(rooms[a]), _center(rooms[b]))


static func _corridor(rng: RandomNumberGenerator, cells: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i) -> void:
	var width := rng.randi_range(1, 2)
	if rng.randi() % 2 == 0:
		_hline(cells, w, h, a.x, b.x, a.y, width)
		_vline(cells, w, h, a.y, b.y, b.x, width)
	else:
		_vline(cells, w, h, a.y, b.y, a.x, width)
		_hline(cells, w, h, a.x, b.x, b.y, width)


static func _carve(cells: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	if x >= 1 and x <= w - 2 and y >= 3 and y <= h - 2 and cells[y * w + x] == WALL:
		cells[y * w + x] = FLOOR


static func _hline(cells: PackedByteArray, w: int, h: int, x1: int, x2: int, y: int, width: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		for k in width:
			_carve(cells, w, h, x, y + k)


static func _vline(cells: PackedByteArray, w: int, h: int, y1: int, y2: int, x: int, width: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		for k in width:
			_carve(cells, w, h, x + k, y)


static func _walkable(k: int) -> bool:
	return k == FLOOR or k == CHEST or k == STAIRS


static func _at(cells: PackedByteArray, w: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y * w + x >= cells.size():
		return WALL
	return cells[y * w + x]


## Een muur van 1 dik tussen twee vloeren boven elkaar wordt vloer (anders past de 2 hoge voorkant niet).
static func _fill_thin_walls(cells: PackedByteArray, w: int, h: int) -> void:
	for pass_i in 8:
		var changed := false
		for y in range(3, h - 2):
			for x in range(1, w - 1):
				if cells[y * w + x] == WALL and cells[(y - 1) * w + x] == FLOOR and cells[(y + 1) * w + x] == FLOOR:
					cells[y * w + x] = FLOOR
					changed = true
		if not changed:
			return


# ---------------------------------------------------------------- ladder, afstanden, obstakels
## Zoekt in de kamers (van links naar rechts) een plek in de bovenrij waar een ladder past:
## de twee cellen erboven moeten muur zijn en de cellen ernaast ook. Geeft {room, spawn} of {}.
static func _pick_ladder(rng: RandomNumberGenerator, cells: PackedByteArray, w: int, _h: int, rooms: Array[Rect2i]) -> Dictionary:
	for i in rooms.size():
		var r: Rect2i = rooms[i]
		var xs: Array[int] = []
		for x in range(r.position.x + 1, r.end.x - 1):
			xs.append(x)
		for k in xs.size():
			var j := rng.randi_range(k, xs.size() - 1)
			var tmp := xs[k]
			xs[k] = xs[j]
			xs[j] = tmp
		var y := r.position.y
		for x in xs:
			var ok := true
			for dx in range(-1, 2):
				for dy in [1, 2]:
					if _at(cells, w, x + dx, y - dy) != WALL:
						ok = false
			if ok and _at(cells, w, x, y) == FLOOR:
				return {"room": i, "spawn": Vector2i(x, y)}
	return {}


static func _distances(cells: PackedByteArray, w: int, h: int, from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var qi := 0
	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		for d in DIRS4:
			var n: Vector2i = cur + d
			if dist.has(n) or n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			var k: int = cells[n.y * w + n.x]
			if k != FLOOR and k != STAIRS:       # een kist blokkeert
				continue
			dist[n] = int(dist[cur]) + 1
			queue.append(n)
	return dist


## Obstakels op de binnenste cellen van een kamer (rand blijft vrij), nooit buren van elkaar.
static func _place_blocks(rng: RandomNumberGenerator, cells: PackedByteArray, w: int, r: Rect2i) -> void:
	if r.size.x < 6 or r.size.y < 5:
		return
	for y in range(r.position.y + 1, r.end.y - 1):
		for x in range(r.position.x + 1, r.end.x - 1):
			if rng.randf() > 0.09 or cells[y * w + x] != FLOOR:
				continue
			var lonely := true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if _at(cells, w, x + dx, y + dy) == BLOCK:
						lonely = false
			if lonely:
				cells[y * w + x] = BLOCK


## Kisten in kamerhoeken; een kist die iets afsluit (trap, kamer of gang erachter) komt er niet.
static func _place_chests(rng: RandomNumberGenerator, cells: PackedByteArray, w: int, rooms: Array[Rect2i],
		reserved: Dictionary, monster_slots: Array[Vector2i], spawn_up: Vector2i, want := 4) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if want <= 0:
		return out
	var h := cells.size() / w
	# kandidaten: eerst de hoeken van elke kamer, dan de randtegels (in willekeurige volgorde)
	var corners: Array[Vector2i] = []
	var edges: Array[Vector2i] = []
	for r in rooms:
		for t in [r.position, Vector2i(r.end.x - 1, r.position.y), Vector2i(r.position.x, r.end.y - 1), Vector2i(r.end.x - 1, r.end.y - 1)]:
			corners.append(t)
		for x in range(r.position.x + 1, r.end.x - 1):
			edges.append(Vector2i(x, r.position.y))
			edges.append(Vector2i(x, r.end.y - 1))
		for y in range(r.position.y + 1, r.end.y - 1):
			edges.append(Vector2i(r.position.x, y))
			edges.append(Vector2i(r.end.x - 1, y))
	for arr in [corners, edges]:
		for k in arr.size():
			var j := rng.randi_range(k, arr.size() - 1)
			var tmp: Vector2i = arr[k]
			arr[k] = arr[j]
			arr[j] = tmp
	var cands: Array[Vector2i] = []
	cands.append_array(corners)
	cands.append_array(edges)
	var reach := _distances(cells, w, h, spawn_up).size()
	for t in cands:
		if out.size() >= want:
			break
		if cells[t.y * w + t.x] != FLOOR or reserved.has(t) or monster_slots.has(t) or t == spawn_up + Vector2i.DOWN:
			continue
		cells[t.y * w + t.x] = CHEST
		var now := _distances(cells, w, h, spawn_up).size()
		if now != reach - 1:     # de kist mag niets afsluiten
			cells[t.y * w + t.x] = FLOOR
			continue
		reach = now
		out.append(t)
	return out


# ---------------------------------------------------------------- tegels
static func _is_front_low(cells: PackedByteArray, w: int, x: int, y: int) -> bool:
	return _at(cells, w, x, y) == WALL and _walkable(_at(cells, w, x, y + 1))


static func _is_front_up(cells: PackedByteArray, w: int, x: int, y: int) -> bool:
	return _at(cells, w, x, y) == WALL and _at(cells, w, x, y + 1) == WALL and _is_front_low(cells, w, x, y + 1)


static func _is_front(cells: PackedByteArray, w: int, x: int, y: int) -> bool:
	return _is_front_low(cells, w, x, y) or _is_front_up(cells, w, x, y)


## Open = vloer, blok of een muurvoorkant: daar "kijkt" de muurtop naartoe.
static func _open(cells: PackedByteArray, w: int, x: int, y: int) -> bool:
	var k := _at(cells, w, x, y)
	return k != WALL or _is_front(cells, w, x, y)


static func _render(rng: RandomNumberGenerator, cells: PackedByteArray, w: int, h: int, f: int,
		spawn_up: Vector2i, spawn_down: Vector2i, stairs: Vector2i) -> Array:
	var ladder_low := spawn_up + Vector2i.UP
	var ladder_up := spawn_up + Vector2i(0, -2)
	var glitch_p := 0.004 + 0.03 * float(f) / float(MAX_FLOOR)
	var layout: Array = []
	for y in h:
		var row := ""
		for x in w:
			var k := _at(cells, w, x, y)
			var ch := "."
			var t := Vector2i(x, y)
			if k == WALL:
				if t == ladder_up:
					ch = "H"
				elif t == ladder_low:
					ch = "h"
				elif _is_front_low(cells, w, x, y):
					ch = _front_char(cells, w, x, y, "f", "l", "r")
				elif _is_front_up(cells, w, x, y):
					ch = _front_char(cells, w, x, y, "F", "L", "R")
				else:
					ch = _top_char(cells, w, x, y)
			elif k == STAIRS:
				ch = "v"
			elif k == BLOCK:
				ch = BLOCK_CHARS[rng.randi_range(0, BLOCK_CHARS.size() - 1)]
			else:
				var n_wall := _at(cells, w, x, y - 1) == WALL
				var w_wall := _at(cells, w, x - 1, y) == WALL
				if n_wall and w_wall:
					ch = "Z"
				elif n_wall:
					ch = "s"
				elif w_wall:
					ch = "S"
				elif k == FLOOR and t != spawn_up and t != spawn_down and t != stairs:
					var roll := rng.randf()
					if roll < glitch_p:
						ch = "*"
					elif roll < glitch_p + 0.05:
						ch = DECOR_CHARS[rng.randi_range(0, DECOR_CHARS.size() - 1)]
			row += ch
		layout.append(row)
	return layout


## Voorkant: linker-/rechtereinde als de buurman geen voorkant is; 1 breed = gewoon.
static func _front_char(cells: PackedByteArray, w: int, x: int, y: int, plain: String, left: String, right: String) -> String:
	var l := not _is_front(cells, w, x - 1, y)
	var r := not _is_front(cells, w, x + 1, y)
	if l and not r:
		return left
	if r and not l:
		return right
	return plain


## Muurtop-autotile (docs/DUNGEON_TILES.txt): 1-9 = 16-24 (NW N NO W midden O ZW Z ZO), a-d = binnenhoeken.
static func _top_char(cells: PackedByteArray, w: int, x: int, y: int) -> String:
	var n := _open(cells, w, x, y - 1)
	var s := _open(cells, w, x, y + 1)
	var e := _open(cells, w, x + 1, y)
	var wst := _open(cells, w, x - 1, y)
	if n:
		return "1" if wst else ("3" if e else "2")
	if s:
		return "7" if wst else ("9" if e else "8")
	if wst:
		return "4"
	if e:
		return "6"
	if _open(cells, w, x - 1, y - 1):
		return "d"
	if _open(cells, w, x + 1, y - 1):
		return "c"
	if _open(cells, w, x - 1, y + 1):
		return "b"
	if _open(cells, w, x + 1, y + 1):
		return "a"
	return "5"
