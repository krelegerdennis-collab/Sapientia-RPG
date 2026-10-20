extends RefCounted
class_name WoudWarpers
## Uitgang-warpers van het Donker Woud (begin, midden, eind).
## Alleen kamers uit woud_rooms.gd. Geen Archief 3 tot en met 6. Geen Diepe Grot.
## Plaatje: het bestaande opslagboek, violet getint (dungeon_exit_warper.gd). Geen nieuw bestand.

const WoudRooms := preload("res://scripts/data/woud_rooms.gd")
const ArchiefWarpers := preload("res://scripts/dungeon/archief_warpers.gd")

const BEGIN_ROOM := "woud_rand"
## Naast de ingang-spawn (13, 15; 1.4x, was 9,10), niet op de uitgang naar de wereldkaart.
const BEGIN_TILE := Vector2i(12, 15)
## Vrije vloer in de Mistpoel. Niet op spawn, kist, boom, monster of het bord.
const MIDDEN_TILE := Vector2i(6, 7)
const EIND_ROOM := "woud_open_plek"
## Zelfde terugkeer als de zuiduitgang van de Woudrand: woud-ingang op de wereldkaart.
const WORLD_SCENE := "res://scenes/maps/wereldkaart.tscn"
const WORLD_SPAWN := "van_woud"


static func mini_boss() -> Dictionary:
	for id in WoudRooms.ROOMS:
		if str(id) == WoudRooms.BOSS_ROOM:
			continue
		for m in WoudRooms.ROOMS[id].get("monsters", []):
			if m.get("mini", false) or m.get("mini_boss", false) or m.get("boss", false):
				return {"room": str(id), "id": str(m.get("id", ""))}
	return {}


static func floors() -> Array:
	var out: Array = []
	for id in WoudRooms.ROOMS:
		var f := int(WoudRooms.ROOMS[id].get("floor", 0))
		if f > 0 and not out.has(f):
			out.append(f)
	out.sort()
	return out


static func middle_floor() -> int:
	var f: Array = floors()
	if f.is_empty():
		return 1
	return int(f[f.size() / 2])


## Geen mini-baas: de eerste kamer van de middelste verdieping (Mistpoel, floor 2).
static func midden_room() -> String:
	var baas := mini_boss()
	if not baas.is_empty():
		return str(baas["room"])
	var want := middle_floor()
	for e in WoudRooms.ORDER:
		var id := str(e[0])
		if id == "" or not WoudRooms.ROOMS.has(id):
			continue
		if int(WoudRooms.ROOMS[id].get("floor", -1)) == want:
			return id
	return ""


## De noordrand van de open plek is beloopbaar, maar de cocon staat direct ten noorden
## van de Wortelkoning. De warper komt op de beloopbare buur van de sta-tegel na de
## overwinning, zodat die tegel (het verhaal zet de speler daar) vrij blijft.
static func eind_tile(room: Dictionary) -> Vector2i:
	if ArchiefWarpers.boss_monster(room).is_empty():
		return Vector2i(-1, -1)
	var stand := ArchiefWarpers.victory_tile(room)
	var rect := ArchiefWarpers.boss_rect(room)
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var t: Vector2i = stand + d
		if t == stand or rect.has_point(t):
			continue
		if ArchiefWarpers.walkable(room, t) and not bezet(room, t):
			return t
	return stand


static func placements() -> Array:
	if not WoudRooms.ROOMS.has(BEGIN_ROOM) or not WoudRooms.ROOMS.has(EIND_ROOM):
		return []
	var midden := midden_room()
	if midden == "" or not WoudRooms.ROOMS.has(midden):
		return []
	return [
		_plek("begin", BEGIN_ROOM, BEGIN_TILE),
		_plek("midden", midden, MIDDEN_TILE),
		_plek("eind", EIND_ROOM, eind_tile(WoudRooms.ROOMS[EIND_ROOM])),
	]


static func for_room(room_id: String) -> Dictionary:
	for plek in placements():
		if str(plek["room"]) == room_id:
			return plek
	return {}


static func bezet(room: Dictionary, t: Vector2i) -> bool:
	var spawns: Dictionary = room.get("spawns", {})
	for key in spawns:
		var v: Array = spawns[key]
		if v.size() >= 2 and Vector2i(int(v[0]), int(v[1])) == t:
			return true
	if room.has("save"):
		var s: Array = room["save"]
		if s.size() >= 2 and Vector2i(int(s[0]), int(s[1])) == t:
			return true
	for groep in ["books", "chests", "signs", "monsters", "objects", "npcs"]:
		for item in room.get(groep, []):
			if not (item is Dictionary):
				continue
			var d: Dictionary = item
			if not d.has("tile"):
				continue
			var tile_a: Array = d["tile"]
			if tile_a.size() < 2:
				continue
			var origin := Vector2i(int(tile_a[0]), int(tile_a[1]))
			var w := 1
			var h := 1
			if d.has("size"):
				var sz: Array = d["size"]
				if sz.size() > 0:
					w = int(sz[0])
				if sz.size() > 1:
					h = int(sz[1])
			elif d.has("tiles"):
				var span: Array = d["tiles"]
				if span.size() > 0:
					w = int(span[0])
				if span.size() > 1:
					h = int(span[1])
			if Rect2i(origin, Vector2i(maxi(w, 1), maxi(h, 1))).has_point(t):
				return true
	for tr in room.get("trees", []):
		if not (tr is Array):
			continue
		var boom: Array = tr
		if boom.size() < 2:
			continue
		var foot := Vector2i(int(boom[0]), int(boom[1]))
		if t == foot or t == foot + Vector2i.RIGHT:
			return true
	return false


static func _plek(role: String, room_id: String, tile: Vector2i) -> Dictionary:
	return {
		"role": role,
		"room": room_id,
		"tile": tile,
		"world_scene": WORLD_SCENE,
		"world_spawn": WORLD_SPAWN,
	}
