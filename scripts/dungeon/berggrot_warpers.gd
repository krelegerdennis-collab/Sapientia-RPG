extends RefCounted
class_name BerggrotWarpers
## Uitgang-warpers van de berggrot (begin, midden, eind).
## Geen baas en geen mini-baas. Geen Archief 3 tot en met 6. Geen Diepe Grot.
## Plaatje: het bestaande opslagboek, violet getint (dungeon_exit_warper.gd). Geen nieuw bestand.
##
## Alle grotkamers staan op floor 1. De Archief-regel (middelste verdieping) zou de
## midden-warper dan op de ingang zetten. Zonder mini-baas staat hij op een duidelijke
## tussenkamer: de Nerf, tussen de Grendel en de geheime kamer.
## Het eind staat in de Uitmond, de laatste kamer. De noorduitgang naar de kas blijft.

const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const ArchiefWarpers := preload("res://scripts/dungeon/archief_warpers.gd")

const BEGIN_ROOM := "berggrot_mond"
## Naast de ingang-spawn (9, 10), niet op de uitgang naar de wereldkaart.
const BEGIN_TILE := Vector2i(8, 10)
const MIDDEN_ROOM := "berggrot_nerf"
## Vrije vloer, niet op spawn, sokkel, bord of monster.
const MIDDEN_TILE := Vector2i(8, 6)
const EIND_ROOM := "berggrot_uitmond"
## Vrije vloer in de laatste kamer. Het monster van deze kamer staat op (8, 6).
const EIND_TILE := Vector2i(12, 7)


static func placements() -> Array:
	var kamers: Dictionary = BerggrotData.ROOMS
	if not kamers.has(BEGIN_ROOM) or not kamers.has(MIDDEN_ROOM) or not kamers.has(EIND_ROOM):
		return []
	return [
		_plek("begin", BEGIN_ROOM, BEGIN_TILE),
		_plek("midden", MIDDEN_ROOM, MIDDEN_TILE),
		_plek("eind", EIND_ROOM, EIND_TILE),
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
	return false


static func _plek(role: String, room_id: String, tile: Vector2i) -> Dictionary:
	return {
		"role": role,
		"room": room_id,
		"tile": tile,
		"world_scene": BerggrotData.WERELD_MAP,
		"world_spawn": BerggrotData.WERELD_SPAWN,
	}
