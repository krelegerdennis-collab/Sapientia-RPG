extends Node
## Finisher nagloed: 3 gepoolde kopieën van de aanvalssprite (client-only, geen sim/net).

const SomFx := preload("res://scripts/som/som_fx.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")

var sim_driven := true
var _anim: SomFx.Anim
var _hero_id := ""
var _sprites: Array[Sprite2D] = []
var _back := Vector2.ZERO
var _tail_ticks := 0
var _ephemeral := false
const TAIL_TICKS := 4

static var _pools: Dictionary = {}


static func attach(hero: Node2D, anim: SomFx.Anim, hero_id: String) -> Node:
	var ctrl: Node = load("res://scripts/som/som_chain_feel.gd").new()
	ctrl.name = "SomChainAfterimage"
	ctrl._anim = anim
	ctrl._hero_id = hero_id
	var f := Vector2(hero.facing)
	if f.length_squared() < 0.01:
		f = Vector2.RIGHT
	ctrl._back = -f.normalized()
	var borrowed := _borrow(hero_id)
	if borrowed.is_empty():
		borrowed = _alloc_ephemeral()
		ctrl._ephemeral = true
	ctrl._sprites = borrowed
	for s in ctrl._sprites:
		if s.get_parent() != null and s.get_parent() != ctrl:
			s.get_parent().remove_child(s)
		ctrl.add_child(s)
		s.visible = false
	hero.add_child(ctrl)
	anim.hit.connect(func() -> void: ctrl._tail_ticks = TAIL_TICKS)
	anim.finished.connect(ctrl._done, CONNECT_ONE_SHOT)
	return ctrl


static func _borrow(hero_id: String) -> Array[Sprite2D]:
	if not _pools.has(hero_id):
		var arr: Array[Sprite2D] = []
		for _i in 3:
			var s := Sprite2D.new()
			s.name = "SomAfterimage%d" % _i
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.centered = true
			s.visible = false
			arr.append(s)
		_pools[hero_id] = arr
	for s in _pools[hero_id]:
		var p: Node = s.get_parent()
		if p != null and is_instance_valid(p) and p.name == "SomChainAfterimage":
			return []
	return _pools[hero_id]


static func _alloc_ephemeral() -> Array[Sprite2D]:
	var arr: Array[Sprite2D] = []
	for _i in 3:
		var s := Sprite2D.new()
		s.name = "SomAfterimageTmp%d" % _i
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = true
		s.visible = false
		arr.append(s)
	return arr


func step(delta: float) -> void:
	if not is_instance_valid(_anim):
		_done()
		return
	_sync_sprites()
	if _tail_ticks > 0:
		_tail_ticks -= 1
		if _tail_ticks <= 0 and _anim.elapsed_ms >= _anim.total_ms() - 0.5:
			_done()


func _sync_sprites() -> void:
	var tint: Color = SomChainData.AFTERIMAGE_TINT.get(_hero_id, Color(1, 1, 1, 0.5))
	for i in _sprites.size():
		var lag := i + 1
		var idx := maxi(0, _anim.index - lag)
		var spr := _sprites[i]
		spr.texture = _anim.texture
		spr.hframes = _anim.hframes
		spr.vframes = _anim.vframes
		spr.frame = int(_anim.seq[idx]) if idx < _anim.seq.size() else _anim.frame
		spr.rotation = _anim.rotation
		spr.flip_h = _anim.flip_h
		spr.offset = _anim.offset
		spr.position = _anim.position + _back * SomChainData.AFTERIMAGE_OFFSETS[i]
		spr.z_index = _anim.z_index - 1 - i
		var c := tint
		c.a = SomChainData.AFTERIMAGE_ALPHAS[i]
		spr.modulate = c
		spr.visible = _anim.index >= lag


func _done() -> void:
	for s in _sprites:
		if is_instance_valid(s):
			s.visible = false
			if s.get_parent() == self:
				remove_child(s)
		if _ephemeral and is_instance_valid(s):
			s.queue_free()
	_sprites.clear()
	queue_free()