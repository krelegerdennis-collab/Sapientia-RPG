extends RefCounted
## Vijand-read vóór de telegraaf (optie A): overlay op tick 0, '!' + oplaad-pose 2 ticks later.

const SomData := preload("res://scripts/data/som_data.gd")
const SomGameFeelData := preload("res://scripts/data/som_gamefeel_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")

const BANG_META := &"som_read_bang"


static func read_anchor(m: Node) -> Vector2:
	var f: Vector2i = m.facing
	if f.y != 0:
		return Vector2(0.0, -3.0)
	return Vector2(float(f.x) * 4.0, -1.0)


static func spawn_read(parent: Node, at: Vector2) -> void:
	var d: Dictionary = SomData.FX_ENEMY_READ
	var t := SomFx.tex(str(d["sheet"]))
	if t == null:
		return
	var a := SomFx.Anim.new()
	a.name = "SomEnemyRead"
	a.texture = t
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.hframes = int(d["frames"])
	a.centered = false
	var anc: Array = d["anchor"]
	a.offset = Vector2(-float(anc[0]), -float(anc[1]))
	a.position = at
	a.z_index = 29
	for i in int(d["frames"]):
		a.seq.append(i)
		a.ms.append(int(d["ms"]))
	parent.add_child(a)


static func begin_telegraph(arena, m: Node, parent: Node, center_fn: Callable, windup_sec: float, pose_fn: Callable) -> void:
	spawn_read(parent, center_fn.call(m) + read_anchor(m))
	var bang_life := maxf(0.05, windup_sec - SomGameFeelData.ENEMY_READ_DELAY_SEC)
	var tree: SceneTree = arena.get_tree()
	# Zwakke verwijzingen: de timer kan afgaan nadat kamer/arena/vijand al weg zijn (kamerwissel). Een lambda
	# die de nodes zelf vasthoudt, geeft dan "Lambda capture ... was freed"; een WeakRef geeft gewoon null.
	var wm: WeakRef = weakref(m)
	var wa: WeakRef = weakref(arena)
	var wp: WeakRef = weakref(parent)
	tree.create_timer(SomGameFeelData.ENEMY_READ_DELAY_SEC).timeout.connect(func() -> void:
		var mm: Node = wm.get_ref()
		var aa = wa.get_ref()
		var pp: Node = wp.get_ref()
		if mm == null or aa == null or pp == null or not aa.enemies.has(mm):
			return
		pose_fn.call()
		var bang: Node = SomFx.number(pp, center_fn.call(mm) + Vector2(0, -14), "!", SomGameFeelData.TELEGRAPH_BANG_COLOR, bang_life)
		mm.set_meta(BANG_META, weakref(bang))
	, CONNECT_ONE_SHOT)


## Vijand verslagen terwijl de '!' nog zweeft: weghalen, anders blijft hij boven het lijk hangen. Bij een lange
## frame (>= 2 ticks, trage laptop) gaat de 2-ticks-timer nog in dezelfde frame af, vóór de defeat.
static func cancel_bang(m: Node) -> void:
	if m == null or not m.has_meta(BANG_META):
		return
	var wr: WeakRef = m.get_meta(BANG_META)
	m.remove_meta(BANG_META)
	var bang: Node = wr.get_ref() if wr != null else null
	if bang != null and is_instance_valid(bang):
		var pp := bang.get_parent()
		if pp != null:
			pp.remove_child(bang)
		bang.queue_free()
