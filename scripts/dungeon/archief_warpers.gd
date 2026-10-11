extends RefCounted
class_name ArchiefWarpers
## Waar de drie uitgang-warpers van het Eerste Archief staan.
## Alleen kamers uit DungeonRooms.ROOMS (Archief 1). Archief 2 heeft hier geen kamers.
## De Diepe Grot (verdieping 1, 50 en 99) staat hier niet in.

const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")

## Naast de start-spawn van de ingang (9, 10), niet op de uitgang naar de wereldkaart.
const BEGIN_ROOM := "archief_ingang"
const BEGIN_TILE := Vector2i(8, 10)
## Eerste tegel van de middelste verdieping, naast de ladder waar je die verdieping op komt.
const MIDDEN_TILE := Vector2i(3, 4)


## TODO(design): het Eerste Archief heeft geen mini-baas. De stilstaande kennis-beesten
## in de trapzaal en de voorhal zijn bewakers, geen baas. De enige baas is de Golem.
## Zolang mini_boss() leeg is, staat de midden-warper op de middelste verdieping.
## Vier verdiepingen (1-4): bij een even aantal de bovenste van de twee middelste
## (index size/2), dat is verdieping 3. De eerste kamer daarvan is de Zuilenhal.
static func mini_boss() -> Dictionary:
	for id in DungeonRooms.ROOMS:
		if str(id) == str(DungeonRooms.GLITCH_BOSS_ROOM):
			continue
		for m in DungeonRooms.ROOMS[id].get("monsters", []):
			if m.get("mini", false) or m.get("mini_boss", false) or m.get("boss", false):
				return {"room": str(id), "id": str(m.get("id", ""))}
	return {}


static func floors() -> Array:
	var out: Array = []
	for id in DungeonRooms.ROOMS:
		var f := int(DungeonRooms.ROOMS[id].get("floor", 0))
		if f > 0 and not out.has(f):
			out.append(f)
	out.sort()
	return out


static func middle_floor() -> int:
	var f: Array = floors()
	if f.is_empty():
		return 1
	return int(f[f.size() / 2])


static func midden_room() -> String:
	var want := middle_floor()
	for e in DungeonRooms.ORDER:
		var id := str(e[0])
		if id == "" or not DungeonRooms.ROOMS.has(id):
			continue
		if int(DungeonRooms.ROOMS[id].get("floor", -1)) == want:
			return id
	return ""


static func boss_monster(room: Dictionary) -> Dictionary:
	for m in room.get("monsters", []):
		if m.get("boss", false):
			return m
	return {}


static func boss_rect(room: Dictionary) -> Rect2i:
	var m := boss_monster(room)
	if m.is_empty():
		return Rect2i()
	var t: Array = m.get("tile", [0, 0])
	var sz: Array = m.get("size", [1, 1])
	return Rect2i(int(t[0]), int(t[1]), int(sz[0]), int(sz[1]))


static func _cell(room: Dictionary, t: Vector2i) -> String:
	var layout: Array = room.get("layout", [])
	if t.y < 0 or t.y >= layout.size():
		return ""
	var row := str(layout[t.y])
	if t.x < 0 or t.x >= row.length():
		return ""
	return row.substr(t.x, 1)


## Beloopbaar voor de speler, en geen uitgangstegel.
static func walkable(room: Dictionary, t: Vector2i) -> bool:
	var ch := _cell(room, t)
	if ch == "" or DungeonRooms.EXIT_CHARS.has(ch):
		return false
	var legend: Dictionary = DungeonRooms.legend_of(room)
	if not legend.has(ch):
		return false
	return not DungeonRooms.is_solid(int(legend[ch]), DungeonRooms.theme_of(room))


## Eerste beloopbare tegel ten noorden van de baas (kleinere y). (-1, -1) = geen.
static func tile_past_boss(room: Dictionary) -> Vector2i:
	var rect := boss_rect(room)
	if rect.size == Vector2i.ZERO:
		return Vector2i(-1, -1)
	var layout: Array = room.get("layout", [])
	for y in rect.position.y:
		if y < 0 or y >= layout.size():
			continue
		var row := str(layout[y])
		for x in row.length():
			var t := Vector2i(x, y)
			if rect.has_point(t):
				continue
			if walkable(room, t):
				return t
	return Vector2i(-1, -1)


## Tegel waar je staat als je van onderen de baas inloopt: direct ten zuiden van zijn linkerkolom.
static func victory_tile(room: Dictionary) -> Vector2i:
	var rect := boss_rect(room)
	return Vector2i(rect.position.x, rect.position.y + rect.size.y)


## Na de baas. Geen veilige tegel ten noorden van de Golem (muur): dan de beloopbare buur
## van de tegel direct na de overwinning, zodat die sta-tegel vrij blijft.
static func eind_tile(room: Dictionary) -> Vector2i:
	if boss_monster(room).is_empty():
		return Vector2i(-1, -1)
	var past := tile_past_boss(room)
	if past.x >= 0:
		return past
	var stand := victory_tile(room)
	var rect := boss_rect(room)
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var t: Vector2i = stand + d
		if rect.has_point(t):
			continue
		if walkable(room, t):
			return t
	return stand


static func placements() -> Array:
	var boss_id := str(DungeonRooms.GLITCH_BOSS_ROOM)
	var boss_room: Dictionary = DungeonRooms.ROOMS[boss_id]
	return [
		{"role": "begin", "room": BEGIN_ROOM, "tile": BEGIN_TILE},
		{"role": "midden", "room": midden_room(), "tile": MIDDEN_TILE},
		{"role": "eind", "room": boss_id, "tile": eind_tile(boss_room)},
	]


static func for_room(room_id: String) -> Dictionary:
	for p in placements():
		if str(p["room"]) == room_id:
			return p
	return {}
