extends StaticBody2D
## v0.11 Verhaal-object: put, zegelsteen, kist, schilderij, ingang van de Archieven...
## Sta ervoor en druk op A -> Story.trigger(event, self, event_arg, "examine") (zie story_data.gd).
## - show_if:     voorwaarde om zichtbaar/aanwezig te zijn ({} = altijd)
## - frame_rules: [[voorwaarde, frame], ...]  de LAATSTE passende regel bepaalt het frame
##                (geen = frame 0). Bv. kist: [[{"flags": ["kist_open"]}, 1]]
## - glow_if:     voorwaarde voor een zachte, pulserende gloed (additief) in glow_color
## - tiles:       grootte in tiles (de node staat op het midden van de linkerboven-tile)
## - bump_event:  ook afgaan als je ertegenaan loopt (bv. de open ingang)
## - loop_if:     v0.13: voorwaarde om de frames rond te laten lopen (elke loop_time s), bv. de
##                rune van een gecontroleerde zegelsteen of de flakkerende open ingang. Met
##                loop_texture (+ loop_frames) loopt die strook i.p.v. het eigen plaatje.

@export var event := ""
@export var event_arg := ""
@export var show_if := {}
@export var frame_rules: Array = []
@export var glow_if := {}
@export var glow_color := Color("3ff0ff")
@export var glow_radius := 14.0
@export var tiles := Vector2i.ONE
@export var bump_event := false
@export var texture: Texture2D
@export var hframes := 1
@export var loop_if := {}
@export var loop_time := 0.5
@export var loop_texture: Texture2D
@export var loop_frames := 2

## v0.13: loopt de frame-animatie nu (loop_if)?
var looping := false
var _loop_t := 0.0

var sprite: Sprite2D
var glow: Sprite2D
var _t := 0.0
static var _glow_cache := {}


func _ready() -> void:
	add_to_group("story")
	sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	if texture:
		sprite.texture = texture
	sprite.hframes = maxi(1, hframes)
	var block := Vector2(tiles - Vector2i.ONE) * 8.0
	sprite.position = block
	if sprite.texture:
		var fh := sprite.texture.get_height()
		sprite.offset.y = -(fh - tiles.y * 16) / 2.0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tiles * 16) - Vector2(2, 2)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	cs.shape = shape
	cs.position = block
	glow = Sprite2D.new()
	glow.name = "Glow"
	glow.texture = glow_texture(glow_radius)
	glow.show_behind_parent = true
	glow.position = block
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)
	move_child(glow, 0)
	story_refresh()


static func glow_texture(radius: float) -> Texture2D:
	var key := int(radius)
	if not _glow_cache.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = key * 2
		t.height = key * 2
		_glow_cache[key] = t
	return _glow_cache[key]


## Zichtbaarheid, frame en gloed opnieuw bepalen (Story.refresh roept dit aan).
func story_refresh() -> void:
	set_story_visible(Story.check(show_if, event_arg))
	var f := 0
	for r in frame_rules:
		if Story.check(r[0], event_arg):
			f = int(r[1])
	var was_looping := looping
	looping = not loop_if.is_empty() and Story.check(loop_if, event_arg)
	if looping and loop_texture:
		sprite.texture = loop_texture
		sprite.hframes = maxi(1, loop_frames)
	elif texture:
		sprite.texture = texture
		sprite.hframes = maxi(1, hframes)
	if looping:
		if not was_looping:
			_loop_t = 0.0
			sprite.frame = clampi(f, 0, sprite.hframes - 1)
	else:
		sprite.frame = clampi(f, 0, sprite.hframes - 1)
	glow.visible = not glow_if.is_empty() and Story.check(glow_if, event_arg)
	set_process(glow.visible or looping)


func set_story_visible(on: bool) -> void:
	visible = on
	collision_layer = 1 if on else 0


func _process(delta: float) -> void:
	if looping:
		_loop_t += delta
		if _loop_t >= loop_time:
			_loop_t -= loop_time
			sprite.frame = (sprite.frame + 1) % maxi(1, sprite.hframes)
	if not glow.visible:
		return
	_t = fmod(_t + delta, 2.0)
	var k := 0.5 - 0.5 * cos(TAU * _t / 2.0)
	glow.modulate = Color(glow_color, lerpf(0.35, 0.75, k))
	glow.scale = Vector2.ONE * lerpf(0.9, 1.08, k)


func interact(_player: Node2D) -> void:
	if visible and not Dialog.is_open:
		Story.trigger(event, self, event_arg, "examine")


func bump(_player: Node2D) -> void:
	if bump_event and visible and not Dialog.is_open:
		Story.trigger(event, self, event_arg)
