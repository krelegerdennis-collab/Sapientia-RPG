extends "res://scripts/map.gd"
## Lobby 24x14 en hal 30x20 uit docs/arena/layouts.json, tegels arena_tiles.png.
## Scènes staan in scenes/arena/, niet in scenes/maps/: die map is WM1-content
## (muziek + playtest-gebied). BGM is bestaande tracks:
## lobby rustplek, hal gevecht_normaal.

const Tiles := preload("res://scripts/arena/arena_tiles.gd")
const Layout := preload("res://scripts/arena/arena_layout.gd")
const Props := preload("res://scripts/arena/arena_props.gd")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const Host := preload("res://scripts/arena/arena_host.gd")
const HudScript := preload("res://scripts/arena/arena_hud.gd")
const GateLock := preload("res://scripts/arena/arena_gate_lock.gd")
const NpcScene := preload("res://scenes/npc.tscn")
const Koopman := preload("res://scripts/arena/arena_koopman.gd")

const HALL := "res://scenes/arena/arena_hall.tscn"

@export var room_kind := "lobby"

var _gate: Array[Vector2i] = []
var _solid: Dictionary = {}


func _ready() -> void:
	encounters = false
	sets_checkpoint = false
	_paint()
	_build_gate()
	_sync_lobby_lock()
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
	return bool(_solid.get(t, true))


func _paint() -> void:
	var rows := Layout.grid(room_kind)
	ground.tile_set = Tiles.tileset()
	ground.clear()
	_solid.clear()
	# Lobby: de open nis (tegels 11-12, rijen 1-2) waar de poort op x=192 staat.
	# Hal: de gesloten monsterpoort in de noordtribune (tegels 14-15, rij 2).
	if room_kind == "lobby":
		_gate = [Vector2i(11, 2), Vector2i(12, 2)]
	else:
		_gate = [Vector2i(14, 2), Vector2i(15, 2)]
	for y in rows.size():
		var row: Array = rows[y]
		for x in row.size():
			var idx := int(row[x])
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 0, Vector2i(idx % 16, int(idx / 16.0)))
			_solid[cell] = _blocked(idx, x, y)
	Props.place(self, room_kind)
	refresh_gate()


func _blocked(idx: int, x: int, y: int) -> bool:
	# Midden van de lobbynis is loopbaar; de buitenste 8 px per kant blijft muur.
	if room_kind == "lobby" and x >= 11 and x <= 12 and y >= 1 and y <= 2:
		return false
	# Zuidelijke doorgang van de hal (indices 89-92).
	if room_kind == "hall" and idx >= 89 and idx <= 92:
		return false
	return idx >= 32


func refresh_gate() -> void:
	var objects := get_node_or_null("Objects")
	if objects == null:
		return
	var frame := 0
	if room_kind == "lobby":
		frame = 1 if GateLock.is_open() else 2
	else:
		var gs := get_node_or_null("/root/GameState")
		var arena := gs.get_node_or_null("ArenaRun") if gs != null else null
		frame = 1 if arena != null and str(arena.phase) == RunScript.PHASE_WAVE else 0
	for n in objects.get_children():
		if str(n.name).begins_with("arena_gate") and n is StaticBody2D:
			Props.set_gate_frame(n, frame)
	_sync_lobby_lock()


func _build_gate() -> void:
	if _gate.is_empty():
		return
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
	# Lobby: op de loper, voor de toonbank. Hal: in de zuidelijke doorgang, kijkend de zaal in.
	var tile := Vector2i(11, 10) if room_kind == "lobby" else Vector2i(14, 18)
	var face := Vector2i.DOWN if room_kind == "lobby" else Vector2i.UP
	s.position = Vector2(tile) * 16.0 + Vector2(8, 8)
	s.facing = face
	if player != null and GameState.pending_spawn == "":
		player.place_at(tile, face)


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
	npc.facing = Vector2i.DOWN
	# Voeten op (88, 98): de 24x32-sheet zet de voeten 8 px onder de node.
	npc.position = Vector2(88, 90)
	objects.add_child(npc)


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


func _sync_lobby_lock() -> void:
	if room_kind != "lobby":
		return
	var gate := get_node_or_null("Exits/ArenaPoort") as MapExit
	GateLock.apply(gate, HALL, "ingang")


func _gate_used() -> void:
	if not ReleaseFlags.arena_enabled():
		return
	if room_kind != "lobby":
		Dialog.show_lines(["The gate is shut."], "")
		return
	_sync_lobby_lock()
	if not GateLock.is_open():
		Dialog.show_lines([GateLock.CLOSED_LINE], "")
		return
	var arena := Host.ensure()
	if str(arena.phase) != RunScript.PHASE_LOBBY:
		return
	arena.begin()
	if GameState.change_map(HALL, "ingang"):
		player.input_locked = true
