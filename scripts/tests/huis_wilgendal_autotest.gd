extends RefCounted
## Wachtershuis multi-kamer (scenes/maps/huis_wilgendal.tscn) binnen --autotest.
## Alleen dit blok: godot --path . -- --autotest --test-huis-wilgendal
## Zonder de vlag draait het blok aan het eind van de volledige --autotest mee.
## t = de autotest-node (check/frames/walk/...).
## Controleert: scène laadt, spawn niet in botsing, uitgang bereikbaar, beide bedden
## en de keuken bestaan, proloog-markers staan er.

const SD := preload("res://scripts/data/story_data.gd")
const Kamers := preload("res://scripts/data/huis_wilgendal_kamers.gd")
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
	_spawn_vrij(huis)
	_meubels(huis)
	_markers(huis)
	_uitgang_bereikbaar(huis)
	await _loop_naar_deur(huis)
	if t.has_method("overworld_shot"):
		await t.overworld_shot("_huis_kamers")
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


func _spawn_vrij(huis: Node) -> void:
	var p: CharacterBody2D = huis.get_node("Objects/Player")
	var spawn: Node2D = huis.get_node_or_null("Spawns/binnen")
	t.check("spawnpunt 'binnen' bestaat", spawn != null)
	if spawn == null:
		return
	var tegel: Vector2i = spawn.get_tile() if spawn.has_method("get_tile") else Vector2i((spawn.position / 16.0).floor())
	var hit: Array = _blokkers(p, tegel)
	t.check("spawn 'binnen' niet in botsing (%s op %s)" % [hit, tegel], hit.is_empty())
	if huis.has_method("tegel_vrij"):
		t.check("spawn-tegel is vrij volgens de kaart", huis.tegel_vrij(tegel))


func _meubels(huis: Node) -> void:
	var tops: Array[Vector2i] = []
	for laag in [huis.ground, huis.annex]:
		if laag == null:
			continue
		for tegel in laag.get_used_cells():
			if laag.get_cell_atlas_coords(tegel) == Vector2i(10, 0):
				tops.append(tegel)
	t.check("beide slaapkamers hebben een bed (bed-tegels %s)" % [tops], tops.size() >= 2
			and huis.get_node_or_null("Objects/BedDax") != null
			and huis.get_node_or_null("Objects/BedOpa") != null)
	t.check("keuken bestaat (fornuis + aanrecht)", huis.get_node_or_null("Objects/Kitchen") != null
			and huis.ground.get_cell_atlas_coords(Kamers.KEUKEN_FORNUIS) == Vector2i(8, 0)
			and huis.ground.get_cell_atlas_coords(Kamers.KEUKEN_AANRECHT) == Vector2i(8, 0))
	t.check("twee stoelen in de woonkamer (tafelstoel + extra)", 
			huis.ground.get_cell_atlas_coords(Vector2i(9, 5)) == Vector2i(9, 0)
			and huis.ground.get_cell_atlas_coords(Kamers.STOEL_2) == Vector2i(9, 0))
	t.check("kasten in beide slaapkamers", huis.get_node_or_null("Objects/CupboardDax") != null
			and huis.get_node_or_null("Objects/CupboardOpa") != null)
	t.check("binnendeuren tussen de kamers", huis.get_node_or_null("Objects/DoorDax") != null
			and huis.get_node_or_null("Objects/DoorOpa") != null
			and huis.ground.get_cell_atlas_coords(Kamers.DEUR_DAX) == Vector2i(5, 0)
			and huis.ground.get_cell_atlas_coords(Kamers.DEUR_OPA) == Vector2i(5, 0))
	var used: Rect2i = huis.ground.get_used_rect()
	t.check("woonkamer-Ground blijft 12x9 (%s)" % used, used.size == Vector2i(12, 9))


func _markers(huis: Node) -> void:
	for naam in ["bed", "lezen", "binnen"]:
		t.check("cutscene-spawn '%s' aanwezig" % naam, huis.get_node_or_null("Spawns/" + naam) != null)
	t.check("Schilderij-marker aanwezig", huis.get_node_or_null("Objects/Schilderij") != null)
	t.check("opslagboek-marker aanwezig", huis.get_node_or_null("Objects/SaveBook") != null)
	t.check("Opa-marker aanwezig", huis.get_node_or_null("Objects/OudeMan") != null)
	var boek: Node = huis.get_node_or_null("Objects/SaveBook")
	t.check("opslagboek nog op (8,3)", boek != null and boek.position == Vector2(8 * 16 + 8, 3 * 16 + 8))
	var bed: Node2D = huis.get_node_or_null("Spawns/bed")
	t.check("spawn 'bed' nog op (2,3)", bed != null and bed.has_method("get_tile") and bed.get_tile() == Vector2i(2, 3))
	var lezen: Node2D = huis.get_node_or_null("Spawns/lezen")
	t.check("spawn 'lezen' nog op (9,5)", lezen != null and lezen.has_method("get_tile") and lezen.get_tile() == Vector2i(9, 5))


func _uitgang_bereikbaar(huis: Node) -> void:
	var uit := huis.get_node_or_null("Exits/NaarDorp")
	t.check("uitgang NaarDorp bestaat en wijst naar Wilgendal", uit != null
			and str(uit.target_map).ends_with("wilgendal.tscn") and str(uit.target_spawn) == "voor_huis"
			and str(uit.event) == "huis_uit")
	if uit == null or not huis.has_method("tegel_vrij"):
		return
	var start := Vector2i(4, 7)
	var doel: Vector2i = uit.tile_rect().position
	t.check("uitgang bereikbaar vanaf spawn (BFS %s -> %s)" % [start, doel], _bereikbaar(huis, start, doel))


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
	# Vanuit (4,7) dezelfde route als de bestaande huis-test: naar de voordeur.
	await t.walk("move_down", 1)
	t.check("voordeur-tegel bereikt te voet", t.map_name() == "Wilgendal" or (
			t.map_name() == "Huis" and t.tile() == Vector2i(4, 8)))
	if t.map_name() == "Huis":
		# Nog één stap als de uitgang nog niet afging (fade).
		await t.walk("move_down", 1)
	t.check("uitgang werkt: terug naar buiten of op de drempel", 
			t.map_name() == "Wilgendal" or (huis.is_inside_tree() and t.tile().y >= 7))
