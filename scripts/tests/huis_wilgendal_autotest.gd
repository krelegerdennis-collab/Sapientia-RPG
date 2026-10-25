extends RefCounted
## Wachtershuis ART-interieur (32x21, layout.json) binnen --autotest.
## Alleen dit blok: godot --path . -- --autotest --test-huis-wilgendal

const SD := preload("res://scripts/data/story_data.gd")
const Build := preload("res://scripts/data/huis_interieur_build.gd")
const HUIS := "res://scenes/maps/huis_wilgendal.tscn"

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	var oude_mult: float = GameState.encounter_multiplier
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	GameState.encounter_multiplier = 0.0
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.pending_spawn = "binnen"
	var huis: Node = await _laad(HUIS)
	t.check("huis_wilgendal.tscn laadt (node Huis)", huis != null and str(huis.name) == "Huis"
			and str(huis.scene_file_path).ends_with("huis_wilgendal.tscn"))
	if huis == null:
		Settings.set_value("battle_style", oude_stijl)
		GameState.encounter_multiplier = oude_mult
		return
	await t.frames(8)
	if "shot_path" in t and t.shot_path != "" and t.has_method("map_overview"):
		await t.map_overview(t.shot_path.get_basename() + "_overview.png")
	var layout: Dictionary = Build.laad()
	_kaart(huis, layout)
	_spawn_vrij(huis)
	_voordeur(huis)
	_deurpalen(huis)
	_props_volgens_layout(huis, layout)
	_camera(huis)
	_markers(huis)
	_uitgang_bereikbaar(huis)
	_alles_bereikbaar(huis)
	if t.has_method("overworld_shot"):
		await t.overworld_shot("_huis_kamers")
	await _loop_naar_deur(huis)
	Settings.set_value("battle_style", oude_stijl)
	GameState.encounter_multiplier = oude_mult


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.has_return_point = false
	t.get_tree().change_scene_to_file(pad)
	for i in 180:
		await t.get_tree().process_frame
		var s: Node = t.get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4 \
				and s.get_node_or_null("Objects/Player") != null:
			return s
	return null


func _midden(tegel: Vector2i) -> Vector2:
	return Vector2(tegel) * 16.0 + Vector2(8, 8)


func _blokkers(p: CharacterBody2D, tegel: Vector2i) -> Array:
	var cs := p.get_node("CollisionShape2D") as CollisionShape2D
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cs.shape
	q.transform = Transform2D(0.0, _midden(tegel) + cs.position)
	q.collision_mask = p.collision_mask
	q.exclude = [p.get_rid()]
	return p.get_world_2d().direct_space_state.intersect_shape(q, 6).map(
			func(h): return str(h["collider"].name) if h["collider"] else "?")


func _kaart(huis: Node, layout: Dictionary) -> void:
	var used: Rect2i = huis.ground.get_used_rect()
	t.check("interieur-Ground 32x21 (%s)" % used, used.size == Build.MAP_SIZE)
	var rijen: Array = layout.get("grid", [])
	t.check("layout.json grid 21 rijen", rijen.size() == Build.MAP_SIZE.y)


func _spawn_vrij(huis: Node) -> void:
	var spawn: Node2D = huis.get_node_or_null("Spawns/binnen")
	t.check("spawnpunt 'binnen' bestaat", spawn != null)
	if spawn == null:
		return
	var tegel: Vector2i = spawn.get_tile() if spawn.has_method("get_tile") else Vector2i((spawn.position / 16.0).floor())
	t.check("spawn 'binnen' op (8,18) omhoog", tegel == Build.SPAWN_TEGEL and spawn.facing == Vector2i.UP)
	var p: CharacterBody2D = huis.get_node("Objects/Player")
	var hit: Array = _blokkers(p, tegel)
	t.check("spawn 'binnen' niet in botsing (%s op %s)" % [hit, tegel], hit.is_empty())
	if huis.has_method("tegel_vrij"):
		t.check("spawn-tegel is vrij volgens de kaart", huis.tegel_vrij(tegel))


func _voordeur(huis: Node) -> void:
	var deur: Array[Vector2i] = huis.voordeur_tegels()
	t.check("voordeur 2x2 op (8-9,19-20) (%s)" % [deur], deur.size() == 4
			and Vector2i(8, 19) in deur and Vector2i(9, 20) in deur)
	var uit := huis.get_node_or_null("Exits/NaarDorp")
	t.check("uitgang dekt de voordeur en blijft voor_huis", uit != null
			and uit.size_tiles == Build.EXIT_RECT.size and str(uit.target_spawn) == "voor_huis"
			and uit.tile_rect() == Build.EXIT_RECT)
	t.check("doormat-prop geplaatst", _prop_gevonden(huis, "doormat") != null)
	t.check("front_door-prop geplaatst", _prop_gevonden(huis, "front_door") != null)


func _deurpalen(huis: Node) -> void:
	for x in [7, 10]:
		for y in [19, 20]:
			var tegel := Vector2i(x, y)
			t.check("stenen deurpaal %s geblokkeerd" % tegel, not huis.tegel_vrij(tegel))
	for x in [8, 9]:
		for y in [19, 20]:
			t.check("uitgang-tegel %s vrij" % Vector2i(x, y), huis.tegel_vrij(Vector2i(x, y)))


func _prop_gevonden(huis: Node, naam: String) -> Dictionary:
	for p in huis.layout_props():
		if str(p["name"]) == naam:
			return p
	return {}


func _prop_op_tegel(huis: Node, naam: String, tegel: Vector2i) -> Dictionary:
	for p in huis.layout_props():
		if str(p["name"]) == naam and p["tile"] == tegel:
			return p
	return {}


func _props_volgens_layout(huis: Node, layout: Dictionary) -> void:
	var verwacht: Array = layout.get("props", [])
	var geplaatst: Array = huis.layout_props()
	t.check("alle layout-props geplaatst (%d/%d)" % [geplaatst.size(), verwacht.size()],
			geplaatst.size() == verwacht.size())
	for raw in verwacht:
		if not (raw is Array) or raw.size() < 8:
			continue
		var naam: String = str(raw[0])
		var tx: int = int(raw[1])
		var ty: int = int(raw[2])
		var w: int = int(raw[3])
		var h: int = int(raw[4])
		var dx: int = int(raw[5])
		var dy: int = int(raw[6])
		var coll: Variant = raw[7]
		var gev := _prop_op_tegel(huis, naam, Vector2i(tx, ty))
		if gev.is_empty():
			t.check("prop %s op (%d,%d) ontbreekt" % [naam, tx, ty], false)
			continue
		t.check("prop %s op tegel (%d,%d)" % [naam, tx, ty],
				gev["tile"] == Vector2i(tx, ty) and gev["offset"] == Vector2i(dx, dy)
				and gev["size"] == Vector2i(w, h))
		if naam == "doorframe_32":
			t.check("doorframe_32 is 32x32", gev["size"] == Vector2i(32, 32))
		if coll is Array and not coll.is_empty():
			for c in coll:
				if c is Array and c.size() >= 2:
					var tegel := Vector2i(int(c[0]), int(c[1]))
					t.check("prop %s blokkeert %s" % [naam, tegel], not huis.tegel_vrij(tegel))


func _camera(huis: Node) -> void:
	t.check("camera 16:9 (384x216) zonder zwart vlak", huis.dek_camera(Build.VP_16_9))
	t.check("camera 19,5:9 (468x216) zonder zwart vlak", huis.dek_camera(Build.VP_195_9))
	var p: CharacterBody2D = huis.get_node("Objects/Player")
	var cam: Camera2D = p.camera
	t.check("camera-limieten 0..512 x 0..336",
			cam.limit_left == 0 and cam.limit_top == 0
			and cam.limit_right == Build.ROOM_PX.x and cam.limit_bottom == Build.ROOM_PX.y)


func _alles_bereikbaar(huis: Node) -> void:
	var start := Build.SPAWN_TEGEL
	var bereik: Dictionary = huis.bereik_van(start)
	var vrij: Array[Vector2i] = huis.vrije_tegels()
	var gemist: Array[Vector2i] = []
	for tegel in vrij:
		if not bereik.has(tegel):
			gemist.append(tegel)
	t.check("elke vrije tegel bereikbaar vanaf spawn (BFS %d vrij, %d bereik, gemist %s)" % [
			vrij.size(), bereik.size(), gemist],
			gemist.is_empty() and vrij.size() == bereik.size() and vrij.size() > 80)


func _markers(huis: Node) -> void:
	for naam in ["bed", "lezen", "binnen"]:
		t.check("cutscene-spawn '%s' aanwezig" % naam, huis.get_node_or_null("Spawns/" + naam) != null)
	t.check("Schilderij-marker aanwezig", huis.get_node_or_null("Objects/Schilderij") != null)
	t.check("opslagboek-marker aanwezig", huis.get_node_or_null("Objects/SaveBook") != null)
	t.check("Opa-marker aanwezig", huis.get_node_or_null("Objects/OudeMan") != null)
	var boek: Node = huis.get_node_or_null("Objects/SaveBook")
	t.check("opslagboek op (8,3)", boek != null and boek.position == Vector2(8 * 16 + 8, 3 * 16 + 8))
	var bed: Node2D = huis.get_node_or_null("Spawns/bed")
	t.check("spawn 'bed' op (2,3)", bed != null and bed.has_method("get_tile") and bed.get_tile() == Vector2i(2, 3))
	var lezen: Node2D = huis.get_node_or_null("Spawns/lezen")
	t.check("spawn 'lezen' op (9,5)", lezen != null and lezen.has_method("get_tile") and lezen.get_tile() == Vector2i(9, 5))
	t.check("twee bedden (bed_rood + bed_blauw)",
			_prop_gevonden(huis, "bed_rood") != {} and _prop_gevonden(huis, "bed_blauw") != {})
	t.check("keuken (fornuis + kast)",
			_prop_gevonden(huis, "keuken_fornuis") != {} and _prop_gevonden(huis, "keukenkast") != {})
	t.check("twee deurframe_32 in gang", _telt_props(huis, "doorframe_32") == 2)


func _telt_props(huis: Node, naam: String) -> int:
	var n := 0
	for p in huis.layout_props():
		if str(p["name"]) == naam:
			n += 1
	return n


func _uitgang_bereikbaar(huis: Node) -> void:
	var uit := huis.get_node_or_null("Exits/NaarDorp")
	t.check("uitgang NaarDorp bestaat en wijst naar Wilgendal", uit != null
			and str(uit.target_map).ends_with("wilgendal.tscn") and str(uit.target_spawn) == "voor_huis"
			and str(uit.event) == "huis_uit")
	if uit == null or not huis.has_method("tegel_vrij"):
		return
	var start := Build.SPAWN_TEGEL
	var doel: Vector2i = uit.tile_rect().position
	t.check("uitgang bereikbaar vanaf spawn (BFS %s -> %s)" % [start, doel], _bereikbaar(huis, start, doel))
	t.check("slaapkamer links bereikbaar", _bereikbaar(huis, start, Vector2i(2, 5)))
	t.check("slaapkamer rechts bereikbaar", _bereikbaar(huis, start, Vector2i(28, 5)))
	t.check("keuken bereikbaar", _bereikbaar(huis, start, Vector2i(14, 5)))


func _bereikbaar(huis: Node, van: Vector2i, naar: Vector2i) -> bool:
	if van == naar:
		return true
	var gezien := {}
	var rij: Array[Vector2i] = [van]
	gezien[van] = true
	while not rij.is_empty():
		var nu: Vector2i = rij.pop_front()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var volg: Vector2i = nu + dir
			if gezien.has(volg):
				continue
			if volg != naar and not huis.tegel_vrij(volg):
				continue
			if volg == naar:
				return true
			gezien[volg] = true
			rij.append(volg)
	return false


func _loop_naar_deur(huis: Node) -> void:
	if t.player() == null:
		return
	await t.walk("move_up", 1)
	t.check("vanaf spawn één stap omhoog vrij", t.map_name() == "Huis" and t.tile() == Vector2i(8, 17))
	await t.walk("move_down", 2)
	t.check("voordeur-tegel bereikt te voet", t.map_name() == "Wilgendal" or (
			t.map_name() == "Huis" and t.tile().y >= 19))
	if t.map_name() == "Huis":
		await t.walk("move_down", 1)
	t.check("uitgang werkt: terug naar buiten of op de drempel",
			t.map_name() == "Wilgendal" or (huis.is_inside_tree() and t.tile().y >= 19))
