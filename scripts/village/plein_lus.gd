extends Node
class_name PleinLus
## Korte lus over het plein. De tegels komen uit de data.
## Elke stap is precies één tegel; er is geen padzoektocht.

const Data := preload("res://scripts/data/wilgendal_dorp.gd")
const TILE := 16.0
const SNELHEID := 32.0

var lus: Array[Vector2i] = []
var _stap := 0
var _van := Vector2.ZERO
var _naar := Vector2.ZERO
var _bezig := false
var _afstand := 0.0


func _ready() -> void:
	var npc := get_parent() as Node2D
	if npc == null:
		return
	var hier := _tegel(npc)
	for i in lus.size():
		if lus[i] == hier:
			_stap = i
			return


func _process(delta: float) -> void:
	var npc := get_parent() as Node2D
	if npc == null or lus.size() < 2:
		return
	if Dialog.is_open or Story.running or not npc.visible:
		return
	if not _bezig and not _begin(npc):
		return
	_afstand += SNELHEID * delta
	var t := clampf(_afstand / TILE, 0.0, 1.0)
	npc.position = _van.lerp(_naar, t)
	if npc.has_method("loop_frame"):
		npc.loop_frame(_richting(), true, _afstand)
	if _afstand < TILE:
		return
	npc.position = _naar
	if npc.has_method("loop_frame"):
		npc.loop_frame(_richting(), false, 0.0)
	_bezig = false
	_stap = (_stap + 1) % lus.size()


func _begin(npc: Node2D) -> bool:
	var hier := _tegel(npc)
	if hier != lus[_stap]:
		var gevonden := -1
		for i in lus.size():
			if lus[i] == hier:
				gevonden = i
				break
		if gevonden < 0:
			return false
		_stap = gevonden
	var doel: Vector2i = lus[(_stap + 1) % lus.size()]
	if not Data.stap_ok(hier, doel) or not _vrij(npc, doel):
		return false
	_van = Vector2(hier) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
	_naar = Vector2(doel) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
	_afstand = 0.0
	_bezig = true
	return true


func _tegel(npc: Node2D) -> Vector2i:
	if npc.has_method("get_tile"):
		return npc.get_tile()
	return Vector2i((npc.position / TILE).floor())


## Eén punt op de doel-tegel. Geen zoektocht: bezet, dan wachten we.
func _vrij(npc: Node2D, tegel: Vector2i) -> bool:
	var wereld := npc.get_world_2d()
	if wereld == null:
		return true
	var ruimte := wereld.direct_space_state
	if ruimte == null:
		return true
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(tegel) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1
	if npc is CollisionObject2D:
		query.exclude = [(npc as CollisionObject2D).get_rid()]
	return ruimte.intersect_point(query, 1).is_empty()


func _richting() -> Vector2i:
	var d := _naar - _van
	if absf(d.x) >= absf(d.y) and absf(d.x) > 0.01:
		return Vector2i.RIGHT if d.x > 0.0 else Vector2i.LEFT
	if d.y > 0.01:
		return Vector2i.DOWN
	if d.y < -0.01:
		return Vector2i.UP
	return Vector2i.DOWN
