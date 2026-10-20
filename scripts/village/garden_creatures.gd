extends Node2D
## Tuin van opa (wilgendal.tscn): een moslijm en een moskonijn die samen spelen (om elkaar
## heen huppen). Loopt Dennis richting de uitgang naar de wereldkaart (zuid), dan lopen ze
## achter hem aan (spoor van de speler, zoals field_follower.gd) tot aan de uitgang.
## Geen botsing: puur decor.
##
## Art (RPG ART, batch 14, v0.21):
##   art/map_creatures/<id>_speel.png  96x24  speel-sprong, 6 frames van 16x24 (horizontaal)
##   art/map_creatures/<id>_volg.png   64x96  lopen, 16x24 frames, rijen omlaag/links/rechts/omhoog,
##                                            4 frames per rij. Voeten onderaan, schaduw erin.
## Ontbreekt een sheet, dan valt de code terug op assets/map_monsters/<id>.png (16x16, 2x4).

const TILE := 16.0
const IDS: Array[String] = ["mosslijm", "moskonijn"]
const ART_DIR := "res://art/map_creatures/"
const FALLBACK_DIR := "res://assets/map_monsters/"
const DIR_ROW := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}
## Speelplek in de tuin (naast het pad, onder het huis).
const PLAY_CENTER := Vector2(440, 232)   # 1.4x-erf (45x31), was (312, 184)
const PLAY_RADIUS := 12.0
const PLAY_SPEED := 1.6          # rad/s rondje om elkaar heen
const PLAY_FPS := 8.0
const WALK_FPS := 8.0
## Komt de speler zuidelijker dan dit (richting uitgang NaarWereld, y=480), dan volgen ze.
const FOLLOW_TRIGGER_Y := 296.0   # 1.4x-erf, was 232
const FOLLOW_GAP := 16.0         # afstand per volger op het spoor
const CATCH_UP_SPEED := 96.0     # px/s om bij het spoor te komen

enum Mode { PLAY, FOLLOW }

var mode := Mode.PLAY
var player: Node2D
var exit_node: Node2D
var creatures: Array[Sprite2D] = []
var _uses_art := {}              # id -> bool (echte sheets geladen?)
var _facing: Array[Vector2i] = []
var _anim_t := 0.0
var _phase := 0.0
var _path: Array[Vector2] = []
var _path_len := 0.0


static func applies_to(scene_path: String) -> bool:
	return scene_path.get_file() == "wilgendal.tscn"


static func follow_sheet_path(id: String) -> String:
	return ART_DIR + id + "_volg.png"


static func play_sheet_path(id: String) -> String:
	return ART_DIR + id + "_speel.png"


func setup(p_player: Node2D, p_exit: Node2D = null) -> void:
	player = p_player
	exit_node = p_exit
	for i in IDS.size():
		var s := Sprite2D.new()
		s.name = IDS[i].capitalize()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		creatures.append(s)
		_facing.append(Vector2i.DOWN)
		_uses_art[IDS[i]] = ResourceLoader.exists(follow_sheet_path(IDS[i])) and ResourceLoader.exists(play_sheet_path(IDS[i]))
		_apply_play_sheet(i)
	_place_play(0.0)


func _apply_play_sheet(i: int) -> void:
	var id := IDS[i]
	var s := creatures[i]
	if _uses_art[id]:
		s.texture = load(play_sheet_path(id))
		s.hframes = max(1, s.texture.get_width() / 16)
		s.vframes = 1
		s.offset = Vector2(0, -4)
	else:
		_apply_fallback(i)


func _apply_follow_sheet(i: int) -> void:
	var id := IDS[i]
	var s := creatures[i]
	if _uses_art[id]:
		s.texture = load(follow_sheet_path(id))
		s.hframes = 4
		s.vframes = 4
		s.offset = Vector2(0, -4)
	else:
		_apply_fallback(i)


func _apply_fallback(i: int) -> void:
	var s := creatures[i]
	s.texture = load(FALLBACK_DIR + IDS[i] + ".png")
	s.hframes = 2
	s.vframes = 4
	s.offset = Vector2.ZERO


func start_follow() -> void:
	if mode == Mode.FOLLOW:
		return
	mode = Mode.FOLLOW
	_path = [player.position]
	_path_len = 0.0
	for i in creatures.size():
		_apply_follow_sheet(i)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_anim_t += delta
	if mode == Mode.PLAY:
		_phase += delta * PLAY_SPEED
		_place_play(_phase)
		if player.position.y > FOLLOW_TRIGGER_Y:
			start_follow()
	else:
		_record_path()
		for i in creatures.size():
			_follow_step(i, delta)


## Rondje om elkaar: tegenover elkaar op een cirkel; de sprong zit in de speel-frames
## (placeholder: een sinus-hupje).
func _place_play(phase: float) -> void:
	for i in creatures.size():
		var a := phase + PI * i
		var s := creatures[i]
		var hop := 0.0
		if not _uses_art[IDS[i]]:
			hop = -absf(sin(_anim_t * 6.0 + i)) * 4.0
		s.position = PLAY_CENTER + Vector2(cos(a) * PLAY_RADIUS, sin(a) * PLAY_RADIUS * 0.5) - position
		s.position.y += hop
		var tangent := Vector2(-sin(a), cos(a) * 0.5)
		_facing[i] = _dir_of(tangent)
		if _uses_art[IDS[i]]:
			s.frame = (int(_anim_t * PLAY_FPS) + i * 3) % s.hframes
		else:
			s.frame = DIR_ROW[_facing[i]] * 2 + (int(_anim_t * PLAY_FPS) % 2)


func _record_path() -> void:
	var p: Vector2 = player.position
	var last: Vector2 = _path[_path.size() - 1]
	if p.distance_to(last) > 0.01:
		_path_len += p.distance_to(last)
		_path.append(p)
		while _path.size() > 64:
			_path_len -= _path[0].distance_to(_path[1])
			_path.remove_at(0)


## Punt op het spoor, 'back' pixels achter de speler.
func _trail_point(back: float) -> Vector2:
	var remain := back
	for k in range(_path.size() - 1, 0, -1):
		var seg := _path[k].distance_to(_path[k - 1])
		if remain <= seg and seg > 0.0:
			return _path[k].lerp(_path[k - 1], remain / seg)
		remain -= seg
	return _path[0]


func _follow_step(i: int, delta: float) -> void:
	var s := creatures[i]
	var target := _trail_point(FOLLOW_GAP * (i + 1)) - position
	var before := s.position
	s.position = s.position.move_toward(target, CATCH_UP_SPEED * delta)
	var moved := s.position - before
	var walking := moved.length() > 0.05
	if walking:
		_facing[i] = _dir_of(moved)
	var row: int = DIR_ROW[_facing[i]]
	if _uses_art[IDS[i]]:
		s.frame = row * 4 + ((int(_anim_t * WALK_FPS) % 4) if walking else 0)
	else:
		s.frame = row * 2 + ((int(_anim_t * WALK_FPS) % 2) if walking else 0)


static func _dir_of(v: Vector2) -> Vector2i:
	if absf(v.x) > absf(v.y):
		return Vector2i.RIGHT if v.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if v.y > 0 else Vector2i.UP


func creature_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s in creatures:
		out.append(s.global_position)
	return out
