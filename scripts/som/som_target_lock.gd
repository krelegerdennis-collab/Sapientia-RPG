extends Node2D
## Doel-lock in Action (tap op monster, auto-lock in bereik). Marker + wissel-FX (handwerk in assets/ui/lock/).

const SomData := preload("res://scripts/data/som_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const SomMove := preload("res://scripts/som/som_move.gd")

## Auto-lock: levend monster binnen deze afstand (tegels, midden-tot-midden).
const AUTO_LOCK_TILES := 6.0
const AUTO_LOCK_RADIUS := AUTO_LOCK_TILES * 16.0
## Hoe vaak (zonder manual lock) opnieuw nearest_enemy scannen in auto-modus.
const AUTO_SCAN_INTERVAL := 0.2

var arena: Node
var target: Node = null
var manual := false
var _marker: SomFx.Anim = null
var _wissel: SomFx.Anim = null
var _auto_scan_t := 0.0
## locktest: teller van getimede auto-scans (niet direct na dood/vangst).
var timed_auto_scans := 0
## Laatste tap-frame (touch_controls): interact op A in hetzelfde frame onderdrukken.
var suppress_attack_frame := -1


func setup(p_arena: Node) -> void:
	arena = p_arena
	z_index = 25


func tick(delta: float) -> void:
	if arena == null or not arena.active():
		_clear_visuals()
		return
	if not manual:
		_auto_scan_t -= delta
		if _auto_scan_t <= 0.0:
			_auto_scan_t = AUTO_SCAN_INTERVAL
			timed_auto_scans += 1
			_refresh_auto()
	_update_marker()
	if target != null and (not is_instance_valid(target) or not arena.enemies.has(target)):
		_on_target_gone(target)


## Wereldpositie van een schermtik (viewport); null = geen vijand geraakt.
func pick_enemy_at_viewport(vp: Vector2) -> Node:
	if arena == null:
		return null
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * vp
	return _pick_at(world)


func try_tap_viewport(vp: Vector2) -> bool:
	var m: Node = pick_enemy_at_viewport(vp)
	if m == null:
		return false
	suppress_attack_frame = Engine.get_process_frames()
	if target == m and manual:
		clear_lock()
	else:
		_set_target(m, true)
	return true


func clear_lock() -> void:
	manual = false
	_set_target(null, false)


func locked_enemy() -> Node:
	if target != null and is_instance_valid(target) and arena.enemies.has(target):
		return target
	return null


func facing_for_player() -> Vector2i:
	var m: Node = locked_enemy()
	if m == null:
		return Vector2i.ZERO
	var to: Vector2 = arena.center_of(m) - arena.body()
	if to.length() < 0.5:
		return Vector2i.ZERO
	return SomMove.facing_for(to.normalized(), arena.player.facing)


func on_target_gone(m: Node) -> void:
	if target != m:
		return
	target = null
	manual = false
	rescan_auto()


func _on_target_gone(m: Node) -> void:
	on_target_gone(m)


## Directe auto-scan (dood/vangst); zet de timer opnieuw zodat tick niet meteen dubbel scant.
func rescan_auto() -> void:
	_auto_scan_t = AUTO_SCAN_INTERVAL
	_refresh_auto()


func _refresh_auto() -> void:
	var cur: Node = locked_enemy()
	if cur != null:
		if arena.center_of(cur).distance_to(arena.body()) <= AUTO_LOCK_RADIUS:
			return
		cur = null
	var best: Node = arena.nearest_enemy(arena.body(), AUTO_LOCK_RADIUS)
	if best != cur:
		_set_target(best, false)


func _set_target(m: Node, is_manual: bool) -> void:
	var old: Node = target
	target = m
	manual = is_manual and m != null
	if m == null:
		_kill_marker()
		return
	if old != m:
		_play_wissel()
	_update_marker()


func _pick_at(world: Vector2) -> Node:
	var best: Node = null
	var best_d: float = 1e9
	for node in arena.enemies.keys():
		if not is_instance_valid(node):
			continue
		var c: Vector2 = arena.center_of(node)
		var half: Vector2 = Vector2(float(node.size.x), float(node.size.y)) * 8.0
		var rect: Rect2 = Rect2(c - half, half * 2.0).grow(4.0)
		if not rect.has_point(world):
			continue
		var d: float = c.distance_squared_to(world)
		if d < best_d:
			best_d = d
			best = node
	return best


func head_of(m: Node) -> Vector2:
	return arena.center_of(m) + Vector2(0, -10)


func marker_position() -> Vector2:
	var m: Node = locked_enemy()
	return head_of(m) if m != null else Vector2.ZERO


func _update_marker() -> void:
	var m: Node = locked_enemy()
	if m == null:
		_kill_marker()
		return
	var pos: Vector2 = head_of(m).round()
	if _marker == null or not is_instance_valid(_marker):
		_spawn_marker()
	if _marker:
		_marker.position = pos
	if _wissel != null and is_instance_valid(_wissel):
		_wissel.position = pos


func _spawn_marker() -> void:
	_kill_marker()
	var d: Dictionary = SomData.TARGET_LOCK
	var t := SomFx.tex(str(d["marker"]))
	if t == null:
		return
	var n := int(d["marker_frames"])
	var ms := int(1000.0 / float(d["marker_fps"]))
	_marker = SomFx.Anim.new()
	_marker.name = "SomLockMarker"
	_marker.texture = t
	_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_marker.hframes = n
	_marker.centered = false
	var anc: Array = d["marker_anchor"]
	_marker.offset = Vector2(-float(anc[0]), -float(anc[1]))
	var seq: Array = []
	var timings: Array = []
	for i in n:
		seq.append(i)
		timings.append(ms)
	_marker.seq = seq
	_marker.ms = timings
	_marker.loop = true
	_marker.z_index = z_index
	add_child(_marker)


func _play_wissel() -> void:
	if _wissel != null and is_instance_valid(_wissel):
		_wissel.queue_free()
	var d: Dictionary = SomData.TARGET_LOCK
	var t := SomFx.tex(str(d["wissel"]))
	if t == null or target == null:
		return
	var n := int(d["wissel_frames"])
	var ms := int(1000.0 / float(d["wissel_fps"]))
	_wissel = SomFx.Anim.new()
	_wissel.name = "SomLockWissel"
	_wissel.texture = t
	_wissel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wissel.hframes = n
	_wissel.centered = false
	var anc: Array = d["wissel_anchor"]
	_wissel.offset = Vector2(-float(anc[0]), -float(anc[1]))
	var seq: Array = []
	var timings: Array = []
	for i in n:
		seq.append(i)
		timings.append(ms)
	_wissel.seq = seq
	_wissel.ms = timings
	_wissel.loop = false
	_wissel.position = head_of(target).round()
	_wissel.z_index = z_index + 1
	add_child(_wissel)


func _kill_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func _clear_visuals() -> void:
	_kill_marker()
	if _wissel != null and is_instance_valid(_wissel):
		_wissel.queue_free()
	_wissel = null
