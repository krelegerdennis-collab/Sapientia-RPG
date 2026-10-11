extends RefCounted
class_name Archief2Warpers
## Waar de drie uitgang-warpers van Het Levende Archief staan.
## Alleen kamers uit archief2_rooms.gd. ArchiefWarpers blijft het Eerste Archief;
## deze kamers staan daar niet in. De Diepe Grot staat hier ook niet in.
##
## Begin: naast de start van de ingang, zonder waarschuwing, niet op een uitgangstegel.
## Midden: na De Wurger (verdieping 3). Eind: na De Genezer.
## Midden en eind vragen dezelfde waarschuwing als het Eerste Archief.

const Rooms := preload("res://scripts/data/archief2_rooms.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")

## Naast de start-spawn van de ingang (9, 10), niet op de zuiduitgang naar de berggrot.
const BEGIN_ROOM := "archief_2_v1_entree"
const BEGIN_TILE := Vector2i(8, 10)


static func room_of(room_id: String) -> Dictionary:
	if Rooms.ROOMS.has(room_id):
		return Rooms.ROOMS[room_id]
	return Rooms.rooms().get(room_id, {})


## De Genezer: eindbaas, niet de mini-baas. Lotte is een verhaalbaas en telt hier niet.
static func eind_boss() -> Dictionary:
	var kamers: Dictionary = Rooms.rooms()
	for id in kamers:
		for m in kamers[id].get("monsters", []):
			if m.get("boss", false) and str(m.get("enemy", "")) == "genezer":
				return {"room": str(id), "id": str(m.get("id", "")), "enemy": "genezer"}
	return {}


## De Wurger (verdieping 3). Vlag "mini" in de kamerdata; anders het enemy-id.
## De eindbaas en Lotte vallen hier buiten.
static func mini_boss() -> Dictionary:
	var eind_id := str(eind_boss().get("room", ""))
	var kamers: Dictionary = Rooms.rooms()
	for id in kamers:
		if str(id) == eind_id:
			continue
		for m in kamers[id].get("monsters", []):
			if m.get("mini", false) or m.get("mini_boss", false):
				return _baas(str(id), m)
	for id in kamers:
		if str(id) == eind_id or int(kamers[id].get("floor", 0)) != 3:
			continue
		for m in kamers[id].get("monsters", []):
			if str(m.get("enemy", "")) == "wurger":
				return _baas(str(id), m)
	return {}


static func _baas(room_id: String, m: Dictionary) -> Dictionary:
	return {"room": room_id, "id": str(m.get("id", "")), "enemy": str(m.get("enemy", ""))}


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


static func is_exit(room: Dictionary, t: Vector2i) -> bool:
	return DungeonRooms.EXIT_CHARS.has(_cell(room, t))


## Beloopbaar voor de speler, en geen uitgangstegel.
static func walkable(room: Dictionary, t: Vector2i) -> bool:
	var ch := _cell(room, t)
	if ch == "" or DungeonRooms.EXIT_CHARS.has(ch):
		return false
	var legend: Dictionary = DungeonRooms.legend_of(room)
	if not legend.has(ch):
		return false
	return not DungeonRooms.is_solid(int(legend[ch]), DungeonRooms.theme_of(room))


## Eerste beloopbare tegel recht ten noorden van de baas (kleinere y, linkerkolom).
## Het pad van de kas loopt door de baas naar het noorden. De schaduwstrook links
## telt niet: die ligt naast de muur, niet na de baas. (-1, -1) = geen.
static func tile_boven_baas(room: Dictionary) -> Vector2i:
	var rect := boss_rect(room)
	if rect.size == Vector2i.ZERO:
		return Vector2i(-1, -1)
	var x := rect.position.x
	for y in range(rect.position.y - 1, -1, -1):
		var t := Vector2i(x, y)
		if rect.has_point(t):
			continue
		if walkable(room, t):
			return t
	return Vector2i(-1, -1)


## Tegel waar je staat als je van onderen de baas inloopt.
static func victory_tile(room: Dictionary) -> Vector2i:
	var rect := boss_rect(room)
	return Vector2i(rect.position.x, rect.position.y + rect.size.y)


## Na de baas. Geen tegel ten noorden: dan een beloopbare buur van de sta-tegel,
## zodat die vrij blijft. Zelfde terugval als het Eerste Archief.
static func tile_na_baas(room: Dictionary) -> Vector2i:
	if boss_monster(room).is_empty():
		return Vector2i(-1, -1)
	var past := tile_boven_baas(room)
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
	var out: Array = [
		{"role": "begin", "room": BEGIN_ROOM, "tile": BEGIN_TILE, "warn": false},
	]
	var mid := mini_boss()
	if not mid.is_empty():
		var mid_room: Dictionary = room_of(str(mid["room"]))
		out.append({
			"role": "midden", "room": str(mid["room"]), "tile": tile_na_baas(mid_room), "warn": true,
		})
	var eind := eind_boss()
	if not eind.is_empty():
		var eind_room: Dictionary = room_of(str(eind["room"]))
		out.append({
			"role": "eind", "room": str(eind["room"]), "tile": tile_na_baas(eind_room), "warn": true,
		})
	return out


static func for_room(room_id: String) -> Dictionary:
	for p in placements():
		if str(p["room"]) == room_id:
			return p
	return {}
