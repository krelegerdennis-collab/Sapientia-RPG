extends Node2D
## v0.17 Zachte MIST over een kamer van het Donker Woud (thema "mist": true in
## dungeon_rooms.gd THEMES). Een paar grote, halfdoorzichtige vlekken die langzaam over de
## kamer drijven, boven de objecten (z_index), zonder botsing en zonder invloed op het spel.
## Vast patroon per kamer (zelfde seed), dus screenshots zijn reproduceerbaar.

const COUNT := 7
const SPEED := 5.0          # px per seconde
const COLOR := Color(0.78, 0.86, 0.84, 0.16)
## Rond de speler dunt de mist uit, zodat hij nooit "verdwijnt" (bv. op de open plek):
## een vlek die over de speler ligt, wordt tot CLEAR_MIN van zijn alpha doorzichtiger.
const CLEAR_MIN := 0.2
## Donkere speler op een donkere bosvloer viel weg (open plek): een zacht warm "lantaarn"-schijnsel
## ONDER de speler (additief, boven de grond, onder de objecten) + de speler zelf iets lichter.
const LANTERN_COLOR := Color(1.0, 0.9, 0.72, 0.30)
const LANTERN_SCALE := 1.5          # x 64 px = ~96 px doorsnee
const PLAYER_BRIGHT := Color(1.3, 1.3, 1.3)

var _lantern: Sprite2D = null
var _player: Node2D

var _blobs: Array = []      # [Sprite2D, snelheid]
var _rect := Rect2()
static var _tex: Texture2D
## T27: s25_check — `enabled` één keer in _ready, niet elke frame in _process.
var _pp_on := false


func _ready() -> void:
	_pp_on = PerfProbe.enabled
	name = "WoudMist"
	z_index = 20
	var map := get_parent()
	var ground: TileMapLayer = map.get_node("Ground")
	var used := ground.get_used_rect()
	_rect = Rect2(Vector2(used.position * 16), Vector2(used.size * 16))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(map.get("room_id")))
	for i in COUNT:
		var s := Sprite2D.new()
		s.texture = _texture()
		s.modulate = COLOR
		s.scale = Vector2(rng.randf_range(1.6, 2.6), rng.randf_range(0.7, 1.1))
		s.position = _rect.position + Vector2(rng.randf() * _rect.size.x, rng.randf() * _rect.size.y)
		add_child(s)
		_blobs.append([s, rng.randf_range(0.5, 1.0) * SPEED * (1.0 if i % 2 == 0 else -1.0)])
	_add_lantern.call_deferred()


func _add_lantern() -> void:
	var map := get_parent()
	var ground: Node = map.get_node_or_null("Ground")
	var pl: Node2D = map.get_node_or_null("Objects/Player") as Node2D
	if ground == null or pl == null:
		return
	_player = pl
	if pl.get("sprite") is Sprite2D:
		(pl.get("sprite") as Sprite2D).self_modulate = PLAYER_BRIGHT
	_lantern = Sprite2D.new()
	_lantern.name = "WoudLantaarn"
	_lantern.texture = _texture()
	_lantern.modulate = LANTERN_COLOR
	_lantern.scale = Vector2(LANTERN_SCALE, LANTERN_SCALE * 0.8)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lantern.material = mat
	map.add_child(_lantern)
	map.move_child(_lantern, ground.get_index() + 1)      # boven de grond, onder Objects/Overlay
	_lantern.global_position = pl.global_position


static func _texture() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex = t
	return _tex


func _process(delta: float) -> void:
	# T27: s25_check — Donker Woud mist/overlay; `_pp_on` uit _ready
	if _pp_on:
		PerfProbe.begin("woud_mist")
	var pl: Node2D = _player
	if _lantern != null and pl != null:
		_lantern.global_position = pl.global_position + Vector2(0, -4)
	for b in _blobs:
		var s: Sprite2D = b[0]
		s.position.x += float(b[1]) * delta
		var half := 32.0 * s.scale.x
		if s.position.x > _rect.end.x + half:
			s.position.x = _rect.position.x - half
		elif s.position.x < _rect.position.x - half:
			s.position.x = _rect.end.x + half
		var a := COLOR.a
		if pl != null:
			# afstand tot het vlekmidden in "straal-eenheden" (ellips van de vlek)
			var d := (pl.global_position + Vector2(0, -8) - s.global_position) / (Vector2(32, 32) * s.scale)
			a *= lerpf(CLEAR_MIN, 1.0, clampf(d.length(), 0.0, 1.0))
		s.modulate.a = a
	if _pp_on:
		PerfProbe.end("woud_mist")
