extends RefCounted
## Perf (post-RC, node-telling): botsing per tegel samenvoegen tot zo min mogelijk rechthoeken.
## De vereniging van de rechthoeken is exact dezelfde set tegels als vóór (geen tegel erbij of eraf),
## dus dezelfde botsing; alleen minder CollisionShape2D-nodes. Onzichtbaar: geen pixelverschil.
## Hebzuchtig: per rij aaneengesloten stukken, daarna identieke stukken op de volgende rijen eronder.


## tiles: Array van Vector2i (dubbelen mogen). Uit: Array[Rect2i] in tegels, disjunct, samen = tiles.
static func rects(tiles: Array) -> Array[Rect2i]:
	var set := {}
	for t in tiles:
		set[Vector2i(t)] = true
	var keys: Array = set.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var done := {}
	var out: Array[Rect2i] = []
	for t: Vector2i in keys:
		if done.has(t):
			continue
		var w := 1
		while set.has(t + Vector2i(w, 0)) and not done.has(t + Vector2i(w, 0)):
			w += 1
		var h := 1
		while true:
			var ok := true
			for x in w:
				var c := t + Vector2i(x, h)
				if not set.has(c) or done.has(c):
					ok = false
					break
			if not ok:
				break
			h += 1
		for y in h:
			for x in w:
				done[t + Vector2i(x, y)] = true
		out.append(Rect2i(t, Vector2i(w, h)))
	return out


## Zet per rechthoek één CollisionShape2D (RectangleShape2D) onder body. body staat op (0, 0) in tegelruimte
## van de kaart (body.position = offset in pixels). Geeft het aantal vormen terug.
static func add_shapes(body: CollisionObject2D, tiles: Array, tile := 16.0, offset := Vector2.ZERO) -> int:
	var n := 0
	for r in rects(tiles):
		var vorm := RectangleShape2D.new()
		vorm.size = Vector2(r.size) * tile
		var cs := CollisionShape2D.new()
		cs.shape = vorm
		cs.position = Vector2(r.position) * tile + Vector2(r.size) * tile * 0.5 - offset
		body.add_child(cs)
		n += 1
	return n
