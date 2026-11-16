extends RefCounted
## Vijand-read vóór de telegraaf (optie A): overlay op tick 0, '!' + oplaad-pose 2 ticks later.

const SomData := preload("res://scripts/data/som_data.gd")
const SomGameFeelData := preload("res://scripts/data/som_gamefeel_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")


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
	tree.create_timer(SomGameFeelData.ENEMY_READ_DELAY_SEC).timeout.connect(func() -> void:
		if not is_instance_valid(m) or not is_instance_valid(arena) or not arena.enemies.has(m):
			return
		pose_fn.call()
		SomFx.number(parent, center_fn.call(m) + Vector2(0, -14), "!", SomGameFeelData.TELEGRAPH_BANG_COLOR, bang_life)
	, CONNECT_ONE_SHOT)
