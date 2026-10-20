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
const TRAIL_N := 3                ## nabeelden tijdens een burst
const TRAIL_STEP := 0.05          ## seconden tussen nabeelden
const SHADOW_ALPHA := 0.5
const SPRITE_ALPHA := 0.95
## <0 = willekeurig; tests zetten een vaste seed vóór _ready.
var seed_override := -1

var sprite: Sprite2D
var shadow: Sprite2D
var brain: WarperBrain = Brain.new()
var _trail: Array[Sprite2D] = []
var _history: Array[Vector2] = []
var _hist_t := 0.0
var _grond: TileMapLayer


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
	for i in TRAIL_N:
		var g := Sprite2D.new()
		g.texture = TEX
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.scale = Vector2(SCHAAL, SCHAAL)
		g.visible = false
		add_child(g)
		_trail.append(g)
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
	var speler := get_parent().get_node_or_null("Objects/Player") as Node2D
	if speler != null:
		brain.player_pos = speler.position


func _render(delta: float) -> void:
	var grond_pos := brain.pos.round()
	var hoogte := brain.visual_alt()
	sprite.position = (brain.pos + Vector2(0, -8.0 - hoogte)).round()
	var bank := clampf(brain.vel.x / Brain.BURST_SPEED, -1.0, 1.0) * BANK_MAX
	sprite.rotation = lerpf(sprite.rotation, bank, 1.0 - exp(-BANK_SMOOTH * delta))
	# schaduw: kleiner en vager naarmate hij hoger vliegt
	var f := clampf(hoogte / Brain.CRUISE_ALT, 0.0, 1.3)
	shadow.position = grond_pos + Vector2(0, -2)
	shadow.scale = Vector2.ONE * lerpf(1.0, 0.6, f)
	shadow.modulate = Color(0, 0, 0, lerpf(SHADOW_ALPHA, SHADOW_ALPHA * 0.55, f))
	_update_trail(delta)


func _update_trail(delta: float) -> void:
	_hist_t += delta
	if _hist_t >= TRAIL_STEP:
		_hist_t = 0.0
		_history.push_front(sprite.position)
		if _history.size() > TRAIL_N + 1:
			_history.pop_back()
	var aan := brain.state == WarperBrain.State.BURST and brain.vel.length() > Brain.CRUISE_SPEED * 1.3
	for i in TRAIL_N:
		var g := _trail[i]
		g.visible = aan and i + 1 < _history.size()
		if g.visible:
			g.position = _history[i + 1]
			g.rotation = sprite.rotation
			g.modulate = Color(0.75, 0.8, 1.0, 0.32 - 0.09 * i)


func _set_visible(v: bool) -> void:
	sprite.visible = v
	shadow.visible = v
	if not v:
		for g in _trail:
			g.visible = false


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
