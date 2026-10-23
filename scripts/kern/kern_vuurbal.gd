extends Node2D
## v0.16 KERNKRACHT: de paarse VUURBAL (gevecht en veld, zie HANDOFF_KERNKRACHT.md).
## Art van RPG ART (wordt vanzelf gebruikt als het bestand bestaat, anders een placeholder in code):
##   res://assets/fx/kern_vuurbal.png         64x16 = 4 frames 16x16, wijst naar RECHTS (rotation =
##                                            vliegrichting), loop 0,08 s/frame, kern op (10,8)
##   res://assets/fx/kern_vuurbal_trail.png   48x16 = 3 frames 16x16, achter de bal, 0,06 s/frame, dan weg
##   res://assets/fx/kern_vuurbal_inslag.png  96x24 = 4 frames 24x24, midden (12,12), 0,07 s/frame, niet loopen
## Alleen volle alpha in de art; de zachte gloed eromheen is additief in code.
## Gebruik:  var vb := KernVuurbal.new(); parent.add_child(vb); vb.scale = ...
##           await vb.fly(van, naar, snelheid)     (px/s in de ruimte van 'parent')
##           KernVuurbal.impact(parent, plek, schaal)   (los, ruimt zichzelf op)

const BALL := "res://assets/fx/kern_vuurbal.png"
const TRAIL := "res://assets/fx/kern_vuurbal_trail.png"
const IMPACT := "res://assets/fx/kern_vuurbal_inslag.png"
const BALL_FRAMES := 4
const BALL_FRAME_TIME := 0.08
const TRAIL_FRAMES := 3
const TRAIL_FRAME_TIME := 0.06
const TRAIL_SPACING := 2.0          # elke ~2 px (art-pixels) een trail-sprite
const IMPACT_FRAMES := 4
const IMPACT_FRAME_TIME := 0.07
const BALL_SIZE := 16
const IMPACT_SIZE := 24
## kern van de bal ligt op (10,8) in het 16x16-frame: 2 px voor het midden
const BALL_CORE_OFFSET := Vector2(2, 0)
const PURPLE := Color(0.62, 0.3, 1.0)
const PURPLE_HOT := Color(0.92, 0.72, 1.0)

static var _tex_cache := {}

signal arrived

var ball: Sprite2D
var glow: Sprite2D
## voor de tests / screenshots
var flying := false
var placeholder := false
var trail_spawned := 0
var _anim_t := 0.0
var _trail_dist := 0.0
## Afgelegde baanlengte (px, ruimte van de ouder) en de trail-afstand daarbij; tests rekenen hiermee
## (trail_spawned = floor(traveled / trail_step)), los van de beeldsnelheid.
var traveled := 0.0
var trail_step := 0.0


func _init() -> void:
	name = "KernVuurbal"
	z_index = 20
	glow = Sprite2D.new()
	glow.name = "Gloed"
	glow.texture = glow_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.modulate = Color(1, 1, 1, 0.55)
	add_child(glow)
	ball = Sprite2D.new()
	ball.name = "Bal"
	ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ball.texture = ball_texture()
	ball.hframes = BALL_FRAMES
	ball.offset = -BALL_CORE_OFFSET     # de kern (10,8) op de node-positie
	add_child(ball)
	placeholder = not ResourceLoader.exists(BALL)


func _process(delta: float) -> void:
	_anim_t += delta
	if ball:
		ball.frame = int(_anim_t / BALL_FRAME_TIME) % BALL_FRAMES
	if glow:
		glow.scale = Vector2.ONE * (1.0 + 0.12 * sin(_anim_t * 18.0))


## Vlieg van 'from' naar 'to' (in de ruimte van de ouder) met 'speed' px/s; trail erachter.
## 'arc' > 0: in een boog (top 'arc' px boven de rechte lijn), de bal draait mee met de baan.
func fly(from: Vector2, to: Vector2, speed: float, arc := 0.0) -> void:
	position = from
	var d := to - from
	rotation = d.angle() if d.length() > 0.01 else 0.0
	flying = true
	var path_len := d.length() + arc * 1.5          # benadering van de booglengte
	var total := path_len / maxf(speed, 1.0)
	var t := 0.0
	var step_px := TRAIL_SPACING * scale.x
	trail_step = step_px
	var prev := from
	while t < total:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		t = minf(total, t + get_process_delta_time())
		var k := t / total
		var p := from + d * k + Vector2(0, -arc * 4.0 * k * (1.0 - k))
		var mv := p - prev
		if mv.length() > 0.01:
			rotation = mv.angle()
		position = p
		_trail_dist += mv.length()
		traveled += mv.length()
		prev = p
		while _trail_dist >= step_px:
			_trail_dist -= step_px
			_spawn_trail()
	position = to
	flying = false
	arrived.emit()


func _spawn_trail() -> void:
	var p := get_parent()
	if p == null:
		return
	var t := Sprite2D.new()
	t.name = "Spoor"
	t.texture = trail_texture()
	t.hframes = TRAIL_FRAMES
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = position
	t.rotation = rotation
	t.scale = scale
	t.z_index = z_index - 1
	p.add_child(t)
	trail_spawned += 1
	var tw := t.create_tween()
	tw.tween_interval(TRAIL_FRAME_TIME)
	tw.tween_callback(func(): t.frame = 1)
	tw.tween_interval(TRAIL_FRAME_TIME)
	tw.tween_callback(func(): t.frame = 2)
	tw.tween_interval(TRAIL_FRAME_TIME)
	tw.tween_callback(t.queue_free)


## Inslag (24x24, 4 frames, 0,07 s, niet loopen) + korte additieve flits; ruimt zichzelf op.
## Geeft de node terug (tests); 'done' wordt aan het eind met meta "klaar" = true gemarkeerd.
static func impact(parent: Node, pos: Vector2, s := 1.0) -> Node2D:
	var root := Node2D.new()
	root.name = "KernInslag"
	root.position = pos
	root.z_index = 21
	root.scale = Vector2.ONE * s
	var g := Sprite2D.new()
	g.texture = glow_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	g.scale = Vector2.ONE * 1.6
	root.add_child(g)
	var sp := Sprite2D.new()
	sp.name = "Inslag"
	sp.texture = impact_texture()
	sp.hframes = IMPACT_FRAMES
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true                 # 24x24: midden (12,12)
	root.add_child(sp)
	parent.add_child(root)
	var gt := root.create_tween()
	gt.tween_property(g, "modulate:a", 0.0, IMPACT_FRAME_TIME * IMPACT_FRAMES)
	var tw := root.create_tween()
	for i in range(1, IMPACT_FRAMES):
		tw.tween_interval(IMPACT_FRAME_TIME)
		tw.tween_callback(func(): sp.frame = i)
	tw.tween_interval(IMPACT_FRAME_TIME)
	tw.tween_callback(func(): root.set_meta("klaar", true))
	tw.tween_callback(root.queue_free)
	return root


## Duur van een inslag (s).
static func impact_time() -> float:
	return IMPACT_FRAME_TIME * (IMPACT_FRAMES + 1)


# ---------------------------------------------------------------- textures (art of placeholder)
static func ball_texture() -> Texture2D:
	return _tex(BALL, "bal")


static func trail_texture() -> Texture2D:
	return _tex(TRAIL, "spoor")


static func impact_texture() -> Texture2D:
	return _tex(IMPACT, "inslag")


static func _tex(path: String, kind: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if not _tex_cache.has(kind):
		_tex_cache[kind] = ImageTexture.create_from_image(_placeholder_image(kind))
	return _tex_cache[kind]


## PLACEHOLDER (alleen als RPG ART's bestanden ontbreken): zelfde maten en frames als de art.
static func _placeholder_image(kind: String) -> Image:
	var fs := IMPACT_SIZE if kind == "inslag" else BALL_SIZE
	var n := IMPACT_FRAMES if kind == "inslag" else (TRAIL_FRAMES if kind == "spoor" else BALL_FRAMES)
	var img := Image.create(fs * n, fs, false, Image.FORMAT_RGBA8)
	for f in n:
		var c := Vector2(f * fs + fs / 2.0, fs / 2.0)
		for y in fs:
			for x in fs:
				var p := Vector2(f * fs + x + 0.5, y + 0.5)
				var d := p.distance_to(c + (Vector2(2, 0) if kind == "bal" else Vector2.ZERO))
				var r: float
				match kind:
					"bal":
						r = 4.5 + (f % 2) * 0.6
					"spoor":
						r = 3.5 - f * 1.0
					_:
						r = [4.0, 9.0, 11.0, 8.0][f]
				if kind == "inslag" and f >= 2:
					if absf(d - r) < 1.0 and (x + y + f) % 2 == 0:
						img.set_pixel(f * fs + x, y, PURPLE)
				elif d <= r:
					img.set_pixel(f * fs + x, y, PURPLE_HOT if d <= r * 0.45 else PURPLE)
	return img


static func glow_texture() -> Texture2D:
	if not _tex_cache.has("gloed"):
		var g := Gradient.new()
		g.set_color(0, Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.9))
		g.set_color(1, Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 24
		t.height = 24
		_tex_cache["gloed"] = t
	return _tex_cache["gloed"]
