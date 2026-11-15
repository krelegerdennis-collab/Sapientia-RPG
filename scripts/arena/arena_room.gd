extends "res://scripts/map.gd"
## Lobby 24x14 en hal 30x20, tegels 16x16. Bestaande binnentegels tot arena_tiles.png er is.
## De poort zit in het midden van de noordmuur.
## Scènes staan in scenes/arena/, niet in scenes/maps/: die map is WM1-content
## (muziek + playtest-gebied). BGM is bestaande tracks tot er een Colosseum-track is:
## lobby rustplek, hal gevecht_normaal.

const Tiles := preload("res://assets/tiles/binnen.tres")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const Host := preload("res://scripts/arena/arena_host.gd")
const HudScript := preload("res://scripts/arena/arena_hud.gd")
const NpcScene := preload("res://scenes/npc.tscn")
const Koopman := preload("res://scripts/arena/arena_koopman.gd")

const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(2, 0)
const HALL := "res://scenes/arena/arena_hall.tscn"

@export var room_kind := "lobby"

var _gate: Array[Vector2i] = []


func _ready() -> void:
	encounters = false
	sets_checkpoint = false
	_paint()
	_build_gate()
	_ensure_spawn()
	if room_kind == "lobby":
		_build_shopkeeper()
	super._ready()
	_attach_hud()


func map_width() -> int:
	return 24 if room_kind == "lobby" else 30


func map_height() -> int:
	return 14 if room_kind == "lobby" else 20


func gate_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in _gate:
		out.append(t)
	return out


func is_wall(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= map_width() or t.y >= map_height():
		return true
	return not _gate.has(t) and (t.x == 0 or t.y == 0 or t.x == map_width() - 1 or t.y == map_height() - 1)


func _paint() -> void:
	var w := map_width()
	var h := map_height()
	var gx := int(w / 2) - 1
	_gate = [Vector2i(gx, 0), Vector2i(gx + 1, 0)]
	ground.tile_set = Tiles
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			ground.set_cell(t, 0, WALL if is_wall(t) else FLOOR)


func _build_gate() -> void:
	var exits := get_node("Exits")
	var old := exits.get_node_or_null("ArenaPoort")
	if old != null:
		exits.remove_child(old)
		old.free()
	var gate := MapExit.new()
	gate.name = "ArenaPoort"
	gate.position = Vector2(_gate[0]) * 16.0
	gate.size_tiles = Vector2i(_gate.size(), 1)
	exits.add_child(gate)


func _ensure_spawn() -> void:
	var spawns := get_node("Spawns")
	var s := spawns.get_node_or_null("ingang")
	if s == null:
		s = MapSpawn.new()
		s.name = "ingang"
		spawns.add_child(s)
	var tile := Vector2i(11, 10) if room_kind == "lobby" else Vector2i(14, 4)
	s.position = Vector2(tile) * 16.0 + Vector2(8, 8)
	s.facing = Vector2i.DOWN


func _build_shopkeeper() -> void:
	var objects := get_node("Objects")
	if objects.get_node_or_null("ArenaShopkeeper") != null:
		return
	var npc := NpcScene.instantiate()
	npc.set_script(Koopman)
	npc.name = "ArenaShopkeeper"
	npc.npc_name = "Quartermaster"
	var lines: Array[String] = ["Training stock. Arena Tokens only."]
	npc.lines = lines
	objects.add_child(npc)
	npc.place_at(Vector2i(6, 7), Vector2i.DOWN)


func _attach_hud() -> void:
	if not ReleaseFlags.arena_enabled():
		return
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var arena := gs.get_node_or_null("ArenaRun")
	if arena == null:
		return
	var hud := HudScript.new()
	hud.name = "ArenaHud"
	add_child(hud)
	hud.bind(arena)


func _use_exit(exit: Node) -> void:
	if str(exit.name) == "ArenaPoort":
		_gate_used()
		return
	super._use_exit(exit)


func _gate_used() -> void:
	if not ReleaseFlags.arena_enabled():
		return
	if room_kind != "lobby":
		Dialog.show_lines(["The gate is shut."], "")
		return
	var arena := Host.ensure()
	if str(arena.phase) != RunScript.PHASE_LOBBY:
		return
	arena.begin()
	if GameState.change_map(HALL, "ingang"):
		player.input_locked = true
