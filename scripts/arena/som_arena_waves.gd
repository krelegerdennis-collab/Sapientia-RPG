extends Node
class_name SomArenaWaves
## Geseede golf-spawner voor de Colosseum-hal. Zelfde interface als de oude stub.

const WavesData := preload("res://scripts/data/arena_waves_data.gd")
const MapMonsterScript := preload("res://scripts/dungeon/map_monster.gd")

signal wave_started(n: int)
signal wave_cleared(n: int)
signal party_wiped()

var active_wave := 0

var _room: Node = null
var _spawned: Array = []
var _alive: int = 0
var _cleared_for: int = 0
var _wiped_for: int = 0
var _som_hooked := false


func start_wave(n: int) -> void:
	active_wave = n
	_cleared_for = 0
	_wiped_for = 0
	_teardown_wave()
	wave_started.emit(n)
	if not _spawn_authority():
		return
	call_deferred("_spawn_when_ready", n)


func _spawn_authority() -> bool:
	return not GameState.coop_in_session() or GameState.coop_is_host()


func _run_seed() -> int:
	var run := get_parent()
	if run != null and "run_seed" in run:
		return int(run.run_seed)
	return 0


func _wave_seed(n: int) -> int:
	var base := _run_seed()
	return hash("arena_wave|%d|%d" % [base, n])


func _spawn_when_ready(n: int) -> void:
	if not is_inside_tree() or active_wave != n:
		return
	for _i in WavesData.HALL_FIND_MAX_FRAMES:
		if not is_inside_tree():
			return
		if active_wave != n:
			return
		var room := _find_hall()
		if room != null:
			_room = room
			_bind_som(room)
			_spawn_wave(room, n)
			return
		await get_tree().process_frame
	if not is_inside_tree() or active_wave != n:
		return
	push_warning(
		"SomArenaWaves: hal niet gevonden na %d frames; wave %d wordt overgeslagen (wave_cleared)."
		% [WavesData.HALL_FIND_MAX_FRAMES, n]
	)
	_emit_wave_cleared(n)


func _find_hall() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var sc := tree.current_scene
	if _is_hall(sc):
		return sc
	for node in tree.get_nodes_in_group("arena_hall"):
		if _is_hall(node):
			return node
	return null


func _is_hall(node: Node) -> bool:
	if node == null:
		return false
	if not node.has_method("is_wall") or not node.has_method("gate_tiles"):
		return false
	if "room_kind" in node and str(node.room_kind) != "hall":
		return false
	return node.has_node("Objects")


func _bind_som(room: Node) -> void:
	if _som_hooked:
		return
	var som: Node = room.get("som") if "som" in room else null
	if som == null:
		return
	if not som.enemy_defeated.is_connected(_on_enemy_defeated):
		som.enemy_defeated.connect(_on_enemy_defeated)
	if not som.player_defeated.is_connected(_on_player_defeated):
		som.player_defeated.connect(_on_player_defeated)
	_som_hooked = true


func _spawn_wave(room: Node, n: int) -> void:
	var pool := WavesData.pool_for_wave(n)
	var count := WavesData.enemy_count(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = _wave_seed(n)
	var tiles := _pick_tiles(room, count, rng)
	var hp_mult := WavesData.hp_multiplier(n)
	_spawned.clear()
	_alive = 0
	for i in count:
		var enemy_id := pool[rng.randi_range(0, pool.size() - 1)]
		var tile: Vector2i = tiles[i] if i < tiles.size() else tiles[0]
		var d := {
			"id": "arena_w%d_%d" % [n, i],
			"enemy": enemy_id,
			"group": [enemy_id],
			"tile": [tile.x, tile.y],
			"moves": false,
		}
		var m: Node = _add_monster(room, d, _wave_seed(n) + i * WavesData.MONSTER_RNG_STRIDE, hp_mult)
		if m != null:
			_spawned.append(m)
			_alive += 1


func _add_monster(room: Node, d: Dictionary, rng_seed: int, hp_mult: float) -> Node:
	if room.has_method("add_monster"):
		var m: Node = room.add_monster(d, rng_seed, hp_mult)
		return m
	var m: MapMonster = MapMonsterScript.new()
	m.setup(room, d, rng_seed)
	room.get_node("Objects").add_child(m)
	if "monsters" in room:
		room.monsters.append(m)
	var som: Node = room.get("som") if "som" in room else null
	if som != null and som.has_method("register"):
		som.register(m)
		_apply_hp_mult(som, m, hp_mult)
	return m


static func _apply_hp_mult(som: Node, m: Node, hp_mult: float) -> void:
	if hp_mult <= 1.0001 or not som.enemies.has(m):
		return
	var e: Dictionary = som.enemies[m]
	var mx := maxi(1, int(e.get("max_hp", 1)))
	var scaled := maxi(1, int(ceil(float(mx) * hp_mult)))
	e["max_hp"] = scaled
	e["hp"] = scaled


func _pick_tiles(room: Node, count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var spawn := _spawn_tile(room)
	var gates: Array = []
	if room.has_method("gate_tiles"):
		gates = room.gate_tiles()
	var gate_set := {}
	for g in gates:
		gate_set[g] = true
	var w := 30
	var h := 20
	if room.has_method("map_width"):
		w = int(room.map_width())
	if room.has_method("map_height"):
		h = int(room.map_height())
	var opts: Array[Vector2i] = []
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			if bool(gate_set.get(t, false)):
				continue
			if room.is_wall(t):
				continue
			if _tile_dist(t, spawn) < WavesData.MIN_TILE_DIST_FROM_SPAWN:
				continue
			opts.append(t)
	_seeded_shuffle(opts, rng)
	var out: Array[Vector2i] = []
	for i in mini(count, opts.size()):
		out.append(opts[i])
	while out.size() < count and not opts.is_empty():
		out.append(opts[rng.randi_range(0, opts.size() - 1)])
	return out


static func _spawn_tile(room: Node) -> Vector2i:
	if room.has_method("_ensure_spawn"):
		room._ensure_spawn()
	var spawns: Node = room.get_node_or_null("Spawns")
	if spawns != null:
		var ingang: Node2D = spawns.get_node_or_null("ingang") as Node2D
		if ingang != null:
			var p := ingang.position
			return Vector2i(int((p.x - 8.0) / 16.0), int((p.y - 8.0) / 16.0))
	return WavesData.HALL_SPAWN_FALLBACK


static func _tile_dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _seeded_shuffle(opts: Array, rng: RandomNumberGenerator) -> void:
	for i in range(opts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = opts[i]
		opts[i] = opts[j]
		opts[j] = tmp


func _on_enemy_defeated(monster: Node, _exp: int, _gold: int, _drops: Array) -> void:
	if _spawned.is_empty() or not _spawned.has(monster):
		return
	if active_wave <= 0:
		return
	_alive = maxi(0, _alive - 1)
	if _alive > 0 or _cleared_for == active_wave:
		return
	_emit_wave_cleared(active_wave)


func _emit_wave_cleared(n: int) -> void:
	if _cleared_for == n:
		return
	_cleared_for = n
	wave_cleared.emit(n)


func _on_player_defeated() -> void:
	if active_wave <= 0 or _wiped_for == active_wave:
		return
	if not GameState.alive_heroes().is_empty():
		return
	_wiped_for = active_wave
	party_wiped.emit()


func _teardown_wave() -> void:
	for m in _spawned:
		if is_instance_valid(m):
			if _room != null and "monsters" in _room:
				_room.monsters.erase(m)
			m.queue_free()
	_spawned.clear()
	_alive = 0