class_name WorldWarperFlyover
extends Node2D
## World Warper op de wereldkaart: een levend vliegend schip, maar puur beeld.
## Geen ingang, geen botsing, geen uitgang. De enige weg naar binnen is Warp in het menu
## (scripts/ui/field_menu.gd open_warp). Pas zichtbaar na canon-scène 1 (ontgrendeld).
## Het vlieggedrag (cruise, burst, zweven, landen) zit in warper_brain.gd.

const TEX := preload("res://assets/sprites/archief2/world_warper.png")
const Brain := preload("res://world_warper/art/warper_brain.gd")
const SCHAAL := 0.5
const TILE := 16
## Terreinen waarop hij mag landen (custom data "terrain" van wereld.tres).
const LAND_TERREIN := ["gras", "hoog_gras", "zand"]
const BANK_MAX := 0.16            ## radialen kantelen in de bocht
const BANK_SMOOTH := 6.0
const GHOST_N := 2                ## getinte nabeelden tijdens een burst
const GHOST_STEP := 0.06          ## seconden tussen nabeelden
const GHOST_TINT := Color(1.35, 1.1, 2.1)  ## >1 = oplichten (goedkoop, geen shader)
const STREAK_POINTS := 14         ## punten per straal (Line2D, ~0.2 s lang)
const STREAK_WIDTH := 4.0
const STREAK_TIPS := [Vector2(-24, 3), Vector2(24, 3)]  ## vleugelpunten t.o.v. romp-midden
const STREAK_COLOR := Color(0.75, 0.95, 1.0)
const GLOW_FADE := 5.0            ## hoe snel het spoor op- en uitfadet (1/s)
const SHADOW_ALPHA := 0.5
const SPRITE_ALPHA := 0.95
const GROUND_OFFSET := Brain.HULL_LIFT       ## schip-midden boven het grondpunt (schaduw piept eronder uit)
const SQUASH_TIME := 0.28         ## touchdown/lift-off veer
const SQUASH_AMT := 0.12
## <0 = willekeurig; tests zetten een vaste seed vóór _ready.
var seed_override := -1

var sprite: Sprite2D
var shadow: Sprite2D
var brain: WarperBrain = Brain.new()
var _ghosts: Array[Sprite2D] = []
var _ghost_pos: Array[Vector2] = []
var _ghost_t := 0.0
var _streaks: Array[Line2D] = []
var _glow := 0.0                  ## 0..1, hoe sterk het burst-spoor nu is
var _grond: TileMapLayer
var _squash_t := 0.0
var _squash_sign := 1.0
var _prev_state := -1


func _ready() -> void:
	z_index = 50
	_grond = get_parent().get_node_or_null("Ground") as TileMapLayer
	var kaart := Rect2(0, 0, 1024, 1024)
	if _grond != null:
		var r := _grond.get_used_rect()
		kaart = Rect2(Vector2(r.position * TILE), Vector2(r.size * TILE))
	shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = _shadow_tex()
	shadow.z_index = -49  # net boven de grond, onder het schip
	add_child(shadow)
	for i in GHOST_N:
		var g := Sprite2D.new()
		g.texture = TEX
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.visible = false
		add_child(g)
		_ghosts.append(g)
	for tip in STREAK_TIPS:
		var l := Line2D.new()
		l.width = STREAK_WIDTH
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0.15))
		l.width_curve = curve
		var grad := Gradient.new()
		grad.set_color(0, Color(STREAK_COLOR, 0.9))
		grad.set_color(1, Color(STREAK_COLOR, 0.0))
		l.gradient = grad
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.visible = false
		add_child(l)
		_streaks.append(l)
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(SCHAAL, SCHAAL)
	sprite.modulate = Color(1, 1, 1, SPRITE_ALPHA)
	add_child(sprite)
	var s := seed_override if seed_override >= 0 else int(Time.get_ticks_usec())
	var start := kaart.get_center()
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		start = cam.get_screen_center_position() + Vector2(-160, -60)
	brain.setup(s, kaart, start)
	brain.landable = _mag_landen
	_set_visible(false)


static func actief() -> bool:
	return GameState.world_warper_is_unlocked()


func _process(delta: float) -> void:
	if not actief():
		_set_visible(false)
		return
	_set_visible(true)
	_feed_context()
	brain.step(minf(delta, 0.1))
	_render(delta)


func _feed_context() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var size := get_viewport_rect().size / cam.zoom
		brain.view = Rect2(cam.get_screen_center_position() - size * 0.5, size)
	_feed_buttons()
	var speler := get_parent().get_node_or_null("Objects/Player") as Node2D
	if speler != null:
		brain.player_pos = speler.position


## Touch-knoppen (scherm) -> wereld, zodat het schip er nooit achter verdwijnt.
func _feed_buttons() -> void:
	var tc := get_parent().get_node_or_null("TouchControls/Control")
	var uit: Array[Rect2] = []
	if tc != null and tc.has_method("button_rects") and brain.view.has_area():
		var schaal: Vector2 = brain.view.size / (tc as Control).size
		for r: Rect2 in tc.button_rects():
			uit.append(Rect2(brain.view.position + r.position * schaal, r.size * schaal))
	brain.set_avoid_from_buttons(uit)


func _render(delta: float) -> void:
	var grond_pos := brain.pos.round()
	var hoogte := brain.visual_alt()
	sprite.position = (brain.pos + Vector2(0, -GROUND_OFFSET - hoogte)).round()
	if brain.state != _prev_state:
		if brain.state == WarperBrain.State.LANDED:
			_squash_t = SQUASH_TIME
			_squash_sign = 1.0
		elif brain.state == WarperBrain.State.ASCEND:
			_squash_t = SQUASH_TIME
			_squash_sign = -1.0
		_prev_state = brain.state
	var sq := 0.0
	if _squash_t > 0.0:
		_squash_t = maxf(0.0, _squash_t - delta)
		sq = sin((1.0 - _squash_t / SQUASH_TIME) * PI) * SQUASH_AMT * _squash_sign
	sprite.scale = Vector2(SCHAAL * (1.0 + sq * 0.6), SCHAAL * (1.0 - sq))
	var bank := clampf(brain.vel.x / Brain.BURST_SPEED, -1.0, 1.0) * BANK_MAX
	sprite.rotation = lerpf(sprite.rotation, bank, 1.0 - exp(-BANK_SMOOTH * delta))
	# schaduw: kleiner en vager naarmate hij hoger vliegt
	var f := clampf(hoogte / Brain.CRUISE_ALT, 0.0, 1.3)
	shadow.position = grond_pos + Vector2(0, -2)
	shadow.scale = Vector2.ONE * lerpf(1.0, 0.6, f)
	shadow.modulate = Color(0, 0, 0, lerpf(SHADOW_ALPHA, SHADOW_ALPHA * 0.55, f))
	_update_trail(delta)


func _update_trail(delta: float) -> void:
	var aan := brain.state == WarperBrain.State.BURST and brain.vel.length() > Brain.CRUISE_SPEED * 1.25
	_glow = move_toward(_glow, 1.0 if aan else 0.0, GLOW_FADE * delta)
	# vleugelstralen: Line2D met kleurverloop en taps toelopend, nieuwste punt vooraan
	for k in _streaks.size():
		var l := _streaks[k]
		var tip: Vector2 = sprite.position + (STREAK_TIPS[k] as Vector2).rotated(sprite.rotation)
		if _glow > 0.0:
			l.add_point(tip, 0)
		while l.get_point_count() > (STREAK_POINTS if _glow > 0.0 else maxi(l.get_point_count() - 2, 0)):
			l.remove_point(l.get_point_count() - 1)
		l.visible = l.get_point_count() > 1
		l.modulate.a = _glow
	# getinte nabeelden: elk iets kleiner en vager
	_ghost_t += delta
	if _ghost_t >= GHOST_STEP:
		_ghost_t = 0.0
		_ghost_pos.push_front(sprite.position)
		if _ghost_pos.size() > GHOST_N + 1:
			_ghost_pos.pop_back()
	for i in GHOST_N:
		var g := _ghosts[i]
		g.visible = _glow > 0.02 and i + 1 < _ghost_pos.size()
		if g.visible:
			g.position = _ghost_pos[i + 1]
			g.rotation = sprite.rotation
			g.scale = sprite.scale * (0.94 - 0.05 * i)
			g.modulate = Color(GHOST_TINT, (0.4 - 0.18 * i) * _glow)


func _set_visible(v: bool) -> void:
	sprite.visible = v
	shadow.visible = v
	if not v:
		for g in _ghosts:
			g.visible = false
		for l in _streaks:
			l.clear_points()
			l.visible = false


func _mag_landen(p: Vector2) -> bool:
	if _grond == null:
		return true
	# hele voetafdruk (3x1 tegels) moet landbaar zijn
	for dx in [-1, 0, 1]:
		var c := Vector2i((p / TILE).floor()) + Vector2i(dx, 0)
		var td := _grond.get_cell_tile_data(c)
		if td == null or not LAND_TERREIN.has(str(td.get_custom_data("terrain"))):
			return false
	return true


static func _shadow_tex() -> ImageTexture:
	# kleine ellips, één keer gemaakt (geen art-bestand)
	var w := 30
	var h := 8
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w * 0.5) / (w * 0.5)
			var dy := (y + 0.5 - h * 0.5) / (h * 0.5)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)
