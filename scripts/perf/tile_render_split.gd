extends RefCounted
## Perf (post-RC, wm1budgettest): GL Compatibility batcht alleen opeenvolgende tegels met dezelfde textuur.
## Een TileMapLayer die per cel van bron (= textuur) wisselt, kost daardoor bijna één draw call per wissel
## (woud_beek: 99 bronnen, ~335 calls; dorp SomV8: 3 bronnen door elkaar, ~110 calls).
## split() tekent dezelfde cellen in één beeldlaag per bron, direct na de bronlaag (zelfde volgorde in de boom,
## zelfde z_index/licht/modulate). De bronlaag blijft de data- en botsingslaag (cellen, custom data, botsing),
## maar wordt onzichtbaar. Alleen voor lagen met 1 tegel per cel zonder overlap (16x16 in 16x16), zonder kinderen.

const META := &"render_split"


static func split(layer: TileMapLayer, min_sources := 2, quadrant := 0) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	if layer == null or layer.tile_set == null or layer.get_child_count() > 0 or layer.y_sort_enabled:
		return out
	var by: Dictionary = {}
	for c in layer.get_used_cells():
		var sid := layer.get_cell_source_id(c)
		if not by.has(sid):
			by[sid] = []
		by[sid].append(c)
	if by.size() < min_sources:
		return out
	# Bronnen die nooit in hetzelfde rendering-kwadrant liggen, mogen één beeldlaag delen: per kwadrant blijft er
	# dan één textuur per laag (= één batch), en het aantal nodes blijft klein (greedy kleuring op kwadranten).
	var q := quadrant if quadrant > 0 else maxi(1, layer.rendering_quadrant_size)
	var ids: Array = by.keys()
	ids.sort_custom(func(a, b): return by[a].size() > by[b].size() or (by[a].size() == by[b].size() and a < b))
	var groepen: Array = []      # [{quads: Dictionary, ids: Array}]
	for sid in ids:
		var quads := {}
		for c: Vector2i in by[sid]:
			quads[Vector2i(floori(float(c.x) / q), floori(float(c.y) / q))] = true
		var plek: Dictionary = {}
		for g: Dictionary in groepen:
			var vrij := true
			for k in quads:
				if g["quads"].has(k):
					vrij = false
					break
			if vrij:
				plek = g
				break
		if plek.is_empty():
			plek = {"quads": {}, "ids": []}
			groepen.append(plek)
		plek["quads"].merge(quads)
		plek["ids"].append(sid)
	var anker: Node = layer
	for gi in groepen.size():
		var l := TileMapLayer.new()
		l.name = "%s_R%d" % [layer.name, gi]
		l.tile_set = layer.tile_set
		l.collision_enabled = false
		l.navigation_enabled = false
		l.position = layer.position
		l.z_index = layer.z_index
		l.z_as_relative = layer.z_as_relative
		l.modulate = layer.modulate
		l.self_modulate = layer.self_modulate
		l.light_mask = layer.light_mask
		l.visibility_layer = layer.visibility_layer
		l.texture_filter = layer.texture_filter
		l.texture_repeat = layer.texture_repeat
		l.material = layer.material
		l.use_parent_material = layer.use_parent_material
		l.rendering_quadrant_size = q
		l.set_meta(META + &"_of", layer.name)
		for sid in groepen[gi]["ids"]:
			for c: Vector2i in by[sid]:
				l.set_cell(c, sid, layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c))
		anker.add_sibling(l)
		anker = l
		out.append(l)
	layer.visible = false
	layer.set_meta(META, true)
	return out
