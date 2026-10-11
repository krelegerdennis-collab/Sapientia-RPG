extends StaticBody2D
## Geheime kast in de Golemhal (Archief 1). Twee tegels breed en hoog.
## Dicht = boekenkast. A ervoor = een hint. Gaat alleen open als de veld-vuurbal
## (Kernkracht, pas na de Golem) hem raakt: on_kernkracht_hit(). Daarna kronkelt
## de unieke Inktwurm eruit, als die nog niet verslagen of gevangen is.
## Blijft open (story_flags "inktwurm_kast_open").

const TEX := "res://assets/puzzle/inktwurm_kast.png"
const MapMonsterScript := preload("res://scripts/dungeon/map_monster.gd")
const FRAME_TIME := 0.12
const FLAG := "inktwurm_kast_open"
const INKT_FLAG := "gloeiende_inktfles"
const LAST := 5

var room: Node = null
var tile := Vector2i(17, 5)
var is_open := false
var sprite: Sprite2D
var shape: CollisionShape2D
var _anim := false
var _t := 0.0
var _say := false
var _flask := false
var _worm: Node = null


func setup(p_room: Node, spec: Dictionary) -> void:
	room = p_room
	name = "InktwurmKast"
	var t: Array = spec.get("tile", [17, 5])
	tile = Vector2i(int(t[0]), int(t[1]))
	# voet = linkeronder-tegel; het plaatje dekt ook de tegel rechts en de rij erboven
	position = Vector2(tile) * 16 + Vector2(8, 8)
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 30)
	shape.shape = rect
	shape.position = Vector2(8, -8)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load(TEX)
	sprite.hframes = 6
	sprite.offset = Vector2(8, -8)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	if GameState.story_flags.has(FLAG):
		_set_open_now()
	else:
		sprite.frame = 0
		for b in covered_tiles():
			room._blocked[b] = true


func covered_tiles() -> Array[Vector2i]:
	return [tile, tile + Vector2i.RIGHT, tile + Vector2i.UP, tile + Vector2i.RIGHT + Vector2i.UP]


func on_kernkracht_hit() -> void:
	if is_open or _anim or not GameState.has_kern("golemkern"):
		return
	_anim = true
	_t = 0.0
	sprite.frame = 0


func interact(_player: Node2D) -> void:
	if is_open or _anim:
		return
	Dialog.show_lines(["The parchment in this cabinet is torn. Something moves behind it."])


func _set_open_now() -> void:
	is_open = true
	_anim = false
	sprite.frame = LAST
	shape.disabled = true
	for b in covered_tiles():
		if room != null and "_blocked" in room:
			room._blocked.erase(b)
	_spawn_worm()


func _process(delta: float) -> void:
	if _anim:
		_t += delta
		while _t >= FRAME_TIME and _anim:
			_t -= FRAME_TIME
			sprite.frame = mini(sprite.frame + 1, LAST)
			if sprite.frame >= LAST:
				_anim = false
				_finish()
	if not _say:
		return
	var veld: Node = room.get_node_or_null("KernKracht") if room != null else null
	if veld != null and is_instance_valid(veld) and bool(veld.get("busy")):
		return
	_say = false
	var lines: Array = []
	if _worm != null:
		lines.append("Core Power tears the parchment. An Ink Worm writhes out of the cabinet.")
	else:
		lines.append("Core Power tears the parchment. The cabinet is empty.")
	if _flask:
		lines.append("A glowing ink bottle lies among the scraps.")
		_flask = false
	Dialog.show_lines(lines)


func _finish() -> void:
	GameState.story_flags[FLAG] = true
	if not GameState.story_flags.has(INKT_FLAG):
		GameState.story_flags[INKT_FLAG] = true
		GameState.inventory["gloeiende_inktfles"] = GameState.item_count("gloeiende_inktfles") + 1
		_flask = true
	_set_open_now()
	_say = true


func _spawn_worm() -> void:
	if _worm != null and is_instance_valid(_worm):
		return
	if room == null or not GameState.unique_available("inktwurm"):
		return
	var m: MapMonster = MapMonsterScript.new()
	var out := tile + Vector2i.LEFT
	m.setup(room, {
		"id": "inktwurm",
		"enemy": "inktwurm",
		"group": ["inktwurm"],
		"tile": [out.x, out.y],
		"moves": false,
	}, 1907)
	room.get_node("Objects").add_child(m)
	room.monsters.append(m)
	_worm = m
