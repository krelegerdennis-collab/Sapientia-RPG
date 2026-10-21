extends RefCounted
class_name Archief2Warpers
## Uitgang-warpers van Het Levende Archief (begin, midden, eind).
## Alleen kamers uit archief2_rooms.gd. Geen Archief 3 tot en met 6.
## De Diepe Grot staat hier niet in.

const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const ArchiefWarpers := preload("res://scripts/dungeon/archief_warpers.gd")

const BEGIN_ROOM := "archief_2_v1_entree"
## Naast de ingang-spawn (13, 15), niet op de uitgang (1.4x: was (8, 10)).
const BEGIN_TILE := Vector2i(12, 15)
const MIDDEN_ROOM := "archief_2_v3_wurger"
const EIND_ROOM := "archief_2_v4_genezer"
const WORLD_SCENE := "res://scenes/maps/wereldkaart.tscn"
const WORLD_SPAWN := "van_kas"


static func _rooms() -> Dictionary:
	return DungeonRooms.archief2().rooms()


## Beloopbare tegel direct ten noorden van de baas. Anders de Archief-1-regel.
static func na_baas(room: Dictionary) -> Vector2i:
	var rect := ArchiefWarpers.boss_rect(room)
	if rect.size != Vector2i.ZERO:
		var noord := Vector2i(rect.position.x, rect.position.y - 1)
		if ArchiefWarpers.walkable(room, noord) and not rect.has_point(noord):
			return noord
	return ArchiefWarpers.eind_tile(room)


static func placements() -> Array:
	var kamers := _rooms()
	if not kamers.has(BEGIN_ROOM) or not kamers.has(MIDDEN_ROOM) or not kamers.has(EIND_ROOM):
		return []
	return [
		_plek("begin", BEGIN_ROOM, BEGIN_TILE),
		_plek("midden", MIDDEN_ROOM, na_baas(kamers[MIDDEN_ROOM])),
		_plek("eind", EIND_ROOM, na_baas(kamers[EIND_ROOM])),
	]


static func for_room(room_id: String) -> Dictionary:
	for plek in placements():
		if str(plek["room"]) == room_id:
			return plek
	return {}


static func _plek(role: String, room_id: String, tile: Vector2i) -> Dictionary:
	return {
		"role": role,
		"room": room_id,
		"tile": tile,
		"world_scene": WORLD_SCENE,
		"world_spawn": WORLD_SPAWN,
	}
