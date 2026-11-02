class_name OpeningEchoGlitch
extends Node
## Story-Hal: ECHO-hologram met echo_glitch_strip (frame 0 rust; bursts 1–3).

const Art := preload("res://world_warper/opening/art.gd")

var _spr: Sprite2D
var _hidden: Array[CanvasItem] = []
var _tick := 0
var _burst_ticks := 0
var _rng := RandomNumberGenerator.new()


func attach(gids: Node2D) -> void:
	if gids == null or not gids.is_inside_tree():
		return
	_rng.randomize()
	for kind in ["Sprite", "Hologram"]:
		var n := gids.get_node_or_null(kind) as CanvasItem
		if n != null and n.visible:
			n.visible = false
			_hidden.append(n)
	var extra := gids.find_child("Sprite", true, false) as CanvasItem
	if extra != null and extra.visible and not _hidden.has(extra):
		extra.visible = false
		_hidden.append(extra)
	_spr = Sprite2D.new()
	_spr.name = "OpeningEchoGlitch"
	_spr.texture = load(Art.ECHO_GLITCH) as Texture2D
	_spr.hframes = Art.ECHO_FRAMES
	_spr.frame = 0
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -10)
	gids.add_child(_spr)
	gids.add_child(self)


func detach() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	if is_instance_valid(_spr):
		_spr.queue_free()
	_spr = null
	queue_free()


func _process(_delta: float) -> void:
	if _spr == null:
		return
	_tick += 1
	if _burst_ticks > 0:
		_burst_ticks -= 1
		_spr.frame = 1 + ((_tick / 2) % 3)
		return
	_spr.frame = 0
	if _tick % 75 == 0 and _rng.randf() < 0.4:
		_burst_ticks = 10
