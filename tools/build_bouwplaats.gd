extends SceneTree
## Bouwt scenes/maps/berggrot_bouwplaats.tscn (bouwplaats voor de berggrot-tunnel).
## Tegels gekopieerd van de wereldkaart (zelfde tileset). Start:
##   godot --headless --path . --script res://tools/build_bouwplaats.gd

const UIT := "res://scenes/maps/berggrot_bouwplaats.tscn"
const W := 24
const H := 13
const TUNNEL := Vector2i(12, 3)


var _klaar := false


func _process(_d: float) -> bool:
	if not _klaar:
		_klaar = true
		_bouw()
	return true


func _bouw() -> void:
	var wereld: Node = load("res://scenes/maps/wereldkaart.tscn").instantiate()
	var wg: TileMapLayer = wereld.get_node("Ground")
	var root := Node2D.new()
	root.name = "BerggrotBouwplaats"
	root.set_script(load("res://scripts/map.gd"))
	root.set("map_name", "Tunnel Worksite")
	root.set("music_track", "wereld")
	root.set("encounters", false)
	var g := TileMapLayer.new()
	g.name = "Ground"
	g.tile_set = wg.tile_set
	root.add_child(g)
	for y in H:
		for x in W:
			var bron: Vector2i
			if y <= 3:
				bron = Vector2i(8 + x % 16, 12 + y % 2)
			elif x >= 11 and x <= 12:
				bron = Vector2i(16 + x % 2, 18)
			else:
				bron = Vector2i(17 + x % 10, 20 + y % 3)
			g.set_cell(Vector2i(x, y), wg.get_cell_source_id(bron), wg.get_cell_atlas_coords(bron), wg.get_cell_alternative_tile(bron))
	var obj := Node2D.new()
	obj.name = "Objects"
	obj.y_sort_enabled = true
	root.add_child(obj)
	var speler: Node2D = load("res://scenes/player.tscn").instantiate()
	speler.name = "Player"
	speler.position = _mid(Vector2i(12, 11))
	obj.add_child(speler)
	var mond := Sprite2D.new()
	mond.name = "Tunnel"
	mond.texture = load("res://assets/sprites/buiten/berggrot_ingang.png")
	mond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mond.position = _mid(TUNNEL)
	obj.add_child(mond)
	_prop(obj, "Hek", "res://assets/sprites/buiten/bouw_hek.png", Vector2i(12, 4), "bouwplaats_hek", {"not_flags": ["noor_lid"]})
	_prop(obj, "Karretje", "res://assets/sprites/buiten/bouw_karretje.png", Vector2i(15, 4), "", {})
	_prop(obj, "Gereedschap", "res://assets/sprites/buiten/bouw_gereedschap.png", Vector2i(8, 4), "", {})
	_prop(obj, "Balken", "res://assets/sprites/buiten/bouw_balken.png", Vector2i(17, 6), "", {})
	_prop(obj, "Balken2", "res://assets/sprites/buiten/bouw_balken.png", Vector2i(6, 7), "", {})
	_npc(obj, "Voorman", "Foreman Hendrik", Vector2i(10, 5), Vector2i.RIGHT, "bouwplaats_voorman", Color(1.0, 0.85, 0.55))
	_npc(obj, "Werker", "Worker Sanne", Vector2i(15, 6), Vector2i.LEFT, "bouwplaats_werker", Color(0.75, 0.85, 1.0))
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	_spawn(spawns, "zuid", Vector2i(12, 11), Vector2i.UP)
	_spawn(spawns, "van_tunnel", Vector2i(12, 4), Vector2i.DOWN)
	var exits := Node2D.new()
	exits.name = "Exits"
	root.add_child(exits)
	_exit(exits, "NaarWereld", Vector2i(11, 12), Vector2i(2, 1), "res://scenes/maps/wereldkaart.tscn", "van_berggrot", "")
	_exit(exits, "NaarBerggrot", TUNNEL, Vector2i.ONE, "", "", "bouwplaats_hek")
	var touch: Node = load("res://scenes/ui/touch_controls.tscn").instantiate()
	touch.name = "TouchControls"
	root.add_child(touch)
	_own(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	print("save ", ResourceSaver.save(ps, UIT))
	wereld.free()
	root.free()


func _mid(t: Vector2i) -> Vector2:
	return Vector2(t * 16) + Vector2(8, 8)


func _prop(p: Node, n: String, tex: String, t: Vector2i, ev: String, show: Dictionary) -> void:
	var o: Node = load("res://scenes/story_object.tscn").instantiate()
	o.name = n
	o.position = _mid(t)
	o.set("texture", load(tex))
	o.set("event", ev)
	o.set("bump_event", ev != "")
	o.set("show_if", show)
	p.add_child(o)


func _npc(p: Node, n: String, naam: String, t: Vector2i, f: Vector2i, ev: String, tint: Color) -> void:
	var o: Node2D = load("res://scenes/npc.tscn").instantiate()
	o.name = n
	o.position = _mid(t)
	o.modulate = tint
	o.set("npc_name", naam)
	o.set("lines", ["..."] as Array[String])
	o.set("facing", f)
	o.set("event", ev)
	p.add_child(o)


func _spawn(p: Node, n: String, t: Vector2i, f: Vector2i) -> void:
	var m := Marker2D.new()
	m.name = n
	m.set_script(load("res://scripts/map_spawn.gd"))
	m.position = _mid(t)
	m.set("facing", f)
	p.add_child(m)


func _exit(p: Node, n: String, t: Vector2i, sz: Vector2i, map: String, spawn: String, ev: String) -> void:
	var e := Node2D.new()
	e.name = n
	e.set_script(load("res://scripts/map_exit.gd"))
	e.position = Vector2(t * 16)
	e.set("size_tiles", sz)
	e.set("target_map", map)
	e.set("target_spawn", spawn)
	e.set("event", ev)
	p.add_child(e)


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)
