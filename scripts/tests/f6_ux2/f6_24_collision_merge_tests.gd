extends RefCounted
## Perf (post-RC): CollisionMerge.rects voegt botsing per tegel samen tot rechthoeken. Bewijs dat de
## rechthoeken precies dezelfde tegels dekken (niets erbij, niets eraf, geen overlap), en dat add_shapes
## dezelfde punten botsend maakt als één 16x16-vorm per tegel. Registratie: f6_ux2_tests.gd (map-scan).

const CollisionMerge := preload("res://scripts/perf/collision_merge.gd")


func needs_game() -> bool:
	return false


static func _cover(rs: Array[Rect2i]) -> Dictionary:
	var c := {}
	for r in rs:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				c[Vector2i(x, y)] = int(c.get(Vector2i(x, y), 0)) + 1
	return c


func run(t: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	var ok := true
	var minder := true
	for n in 40:
		var tiles: Array = []
		var w := rng.randi_range(1, 30)
		var h := rng.randi_range(1, 20)
		var p := rng.randf_range(0.1, 0.95)
		for y in h:
			for x in w:
				if rng.randf() < p:
					tiles.append(Vector2i(x - 5, y - 3))
		var rs := CollisionMerge.rects(tiles)
		var c := _cover(rs)
		var set := {}
		for v in tiles:
			set[v] = true
		ok = ok and c.size() == set.size() and c.keys().all(func(k): return set.has(k) and int(c[k]) == 1)
		minder = minder and rs.size() <= set.size()
	t.check("collision-merge: 40 willekeurige tegelsets, rechthoeken = exact dezelfde tegels, geen overlap", ok)
	t.check("collision-merge: nooit meer vormen dan tegels", minder)
	t.check("collision-merge: lege set = geen vormen", CollisionMerge.rects([]).is_empty())
	var vol: Array = []
	for y in 4:
		for x in 10:
			vol.append(Vector2i(x, y))
	var rr := CollisionMerge.rects(vol)
	t.check("collision-merge: volle 10x4 = één rechthoek", rr.size() == 1 and rr[0] == Rect2i(0, 0, 10, 4))
	# add_shapes: vormgrootte en middelpunt in pixels
	var body := StaticBody2D.new()
	var nv := CollisionMerge.add_shapes(body, [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)])
	var cs := body.get_child(0) as CollisionShape2D
	t.check("collision-merge: 3 tegels op een rij = 1 vorm 48x16, midden op (56, 56)", nv == 1 and cs != null
			and (cs.shape as RectangleShape2D).size == Vector2(48, 16) and cs.position == Vector2(56, 56))
	body.free()
