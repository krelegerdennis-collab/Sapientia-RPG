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
const ShopTalk := preload("res://scripts/arena/arena_shop_talk.gd")
const Entry := preload("res://scripts/arena/arena_entry.gd")
const LOBBY := "res://scenes/arena/arena_lobby.tscn"
const MapMonsterScript := preload("res://scripts/dungeon/map_monster.gd")
const SomArenaScript := preload("res://scripts/som/som_arena.gd")
## Post-RC sfx: luistert naar de SomArena-signalen (zwaard, spreuk, raak, KO).
const SomSfx := preload("res://scripts/audio/som_sfx.gd")
## Bron van MONSTER_RNG_STRIDE (RNG-stap per monster), gedeeld met SomArenaWaves.
const WavesData := preload("res://scripts/data/arena_waves_data.gd")

const HALL := "res://scenes/arena/arena_hall.tscn"

@export var room_kind := "lobby"

## MapLighting-presets: arena_hal / arena_lobby (wordt in _ready gezet).
var room_id := ""
var monsters: Array = []
var som: Node = null
var _gate: Array[Vector2i] = []
var _solid: Dictionary = {}
var invuln_left := 0.0
var _blink_t := 0.0
const INVULN := 1.5
const BLINK := 0.1


func _ready() -> void:
	room_id = "arena_hal" if room_kind == "hall" else "arena_lobby"
	encounters = false
	sets_checkpoint = false
	_paint()
	_build_gate()
	if room_kind == "lobby":
		_build_lobby_world_exit()
	_sync_lobby_lock()
	_ensure_spawn()
	if room_kind == "lobby":
		_build_shopkeeper()
	if room_kind == "hall":
		_setup_arena_combat()
		call_deferred("_redirect_stale_hall")
	super._ready()
	_attach_hud()


func tier() -> int:
	return 0


func monsters_active() -> bool:
	return is_node_ready() and som != null and is_instance_valid(player) \
			and not GameState.scene_busy() and not Dialog.is_open and not menu_open() and not Story.running


func add_monster(d: Dictionary, rng_seed: int = 0, hp_mult: float = 1.0) -> MapMonster:
	var m: MapMonster = MapMonsterScript.new()
	var seed := rng_seed if rng_seed != 0 else hash(room_id) + monsters.size() * WavesData.MONSTER_RNG_STRIDE
	m.setup(self, d, seed)
	$Objects.add_child(m)
	monsters.append(m)
	if som != null and som.has_method("register"):
		som.register(m)
		if hp_mult > 1.0001 and som.enemies.has(m):
			var e: Dictionary = som.enemies[m]
			var mx := maxi(1, int(e.get("max_hp", 1)))
			var scaled := maxi(1, int(ceil(float(mx) * hp_mult)))
			e["max_hp"] = scaled
			e["hp"] = scaled
	return m


func _setup_arena_combat() -> void:
	if not ReleaseFlags.arena_enabled():
		return
	if som != null:
		return
	add_to_group("arena_hall")
	som = SomArenaScript.new()
	add_child(som)
	som.setup(self)
	som.arena_mode = true
	SomSfx.attach(som)


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


## Tiles van de speler (zelfde idee als DungeonRoom; SoM gebruikt meerdere voet-tegels).
func player_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = [player.get_tile()]
	if som != null:
		for off in [Vector2(-5, 0), Vector2(5, 0), Vector2(-5, 7), Vector2(5, 7)]:
			var t2 := Vector2i(((player.position + off) / 16.0).floor())
			if not out.has(t2):
				out.append(t2)
	if player.is_moving:
		var tp: Vector2 = player.get("_target")
		var t := Vector2i((tp / 16.0).floor())
		if not out.has(t):
			out.append(t)
	return out


## Mag monster m naar tile 'to'? Zelfde semantiek als dungeon_room.gd; binnen loopbare hal.
func monster_can_enter(m: Node, to: Vector2i) -> String:
	for dx in m.size.x:
		for dy in m.size.y:
			var t: Vector2i = to + Vector2i(dx, dy)
			if is_wall(t):
				return "wall"
			if t in _gate:
				return "wall"
			if t in player_tiles():
				return "blocked" if invuln_left > 0.0 else "player"
			for o in monsters:
				if o != m and is_instance_valid(o) and o.covers(t):
					return "blocked"
	return "free"


func monster_touch(m: Node) -> void:
	if som != null and (not m.boss or som.enemies.has(m)):
		return
	if not is_instance_valid(m) or not (m in monsters):
		return


func start_invuln(sec := INVULN) -> void:
	invuln_left = sec
	_blink_t = 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player):
		return
	if invuln_left > 0.0:
		invuln_left = maxf(0.0, invuln_left - delta)
		_blink_t += delta
		player.sprite.modulate.a = 1.0 if invuln_left <= 0.0 or int(_blink_t / BLINK) % 2 == 0 else 0.25


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
	if Tiles.is_walkable_floor_deco(idx):
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


## Zuidelijke doorgang (tegels 13, rij 10–13): terug naar wereldkaart bij het Colosseum.
func _build_lobby_world_exit() -> void:
	var exits := get_node("Exits")
	var old := exits.get_node_or_null("NaarWereld")
	if old != null:
		exits.remove_child(old)
		old.free()
	var out := MapExit.new()
	out.name = "NaarWereld"
	out.position = Vector2(10, 13) * 16.0
	out.size_tiles = Vector2i(4, 1)
	out.target_map = Entry.WORLD_MAP
	out.target_spawn = Entry.RETURN_SPAWN
	exits.add_child(out)


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
	_add_shop_talk(npc)


func _add_shop_talk(npc: Node2D) -> void:
	var zone := Area2D.new()
	zone.name = "ShopTalk"
	zone.set_script(ShopTalk)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 44)
	col.shape = shape
	col.position = Vector2(0, 12)
	zone.add_child(col)
	npc.add_child(zone)


## Hall na laden zonder actieve run (bv. save in hal): terug naar lobby i.p.v. dode hal.
func _redirect_stale_hall() -> void:
	if room_kind != "hall" or not is_inside_tree():
		return
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var arena: Node = gs.get_node_or_null("ArenaRun")
	if arena != null and str(arena.phase) != RunScript.PHASE_LOBBY:
		return
	GameState.change_map(LOBBY, "ingang")


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
	# Review #487 punt D: geen arena-sync in co-op, dus de poort blijft dicht.
	if RunScript.coop_blocked():
		Dialog.show_lines([RunScript.COOP_CLOSED_LINE], "")
		return
	var arena := Host.ensure()
	if str(arena.phase) != RunScript.PHASE_LOBBY:
		return
	arena.begin()
	if GameState.change_map(HALL, "ingang"):
		player.input_locked = true
