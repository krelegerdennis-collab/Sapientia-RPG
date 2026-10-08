extends Control
## v0.13 Titel-glitch (SAPIENTIA): goedkoop, zonder shader.
## Elke paar seconden (GAP_MIN..GAP_MAX) een korte 'burst' (BURST s) van:
##   - RGB-split: twee kopieën van de titel in GLITCH-roze en TEAL, 1-2 px opzij;
##   - 1-2 horizontale plakjes van de titel die een paar pixels verschuiven
##     (een geknipte kopie in een Control met clip_contents).
## De inhoud is een Label (tekst met het pixelfont) of een TextureRect (title_logo.png).
## Optioneel ook een lichte glitch op de achtergrond: set_background(TextureRect) ->
## tijdens de burst schuift één smal plakje van de achtergrond opzij, met een vage roze lijn.
## Met art van RPG ART (setup_strip: title_logo_glitch.png, 6 frames, frame 0 = schoon):
## geen RGB-split/plakjes in code, maar de strook speelt 1x (frames 1..5, STRIP_FPS) elke
## STRIP_GAP_MIN..MAX s, daarna weer frame 0 (het gewone logo).
## Voor de autotest: bursts (teller), is_glitching(), force_glitch(), strip_frame.

const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const GAP_MIN := 2.5
const GAP_MAX := 4.5
const BURST := 0.22
const STEP := 0.05            # om de 50 ms een nieuw glitch-beeld tijdens de burst

var content: Control           # Label of TextureRect (het echte logo)
var bursts := 0
var _split: Array[Control] = []
var _slices: Array[Control] = []     # Control (clip) met een kopie erin
var _bg: TextureRect
var _bg_slice: Control
var _bg_line: ColorRect
var _rng := RandomNumberGenerator.new()
const STRIP_FPS := 14.0
const STRIP_GAP_MIN := 3.0
const STRIP_GAP_MAX := 5.0

var strip_frames: Array[Texture2D] = []   # leeg = tekst-glitch in code
var strip_rect: TextureRect
var strip_frame := 0
var _strip_t := 0.0
var _wait := 1.2               # eerste burst snel, zodat je het ziet
var _burst_left := 0.0
var _step_left := 0.0


func setup(node: Control) -> void:
	content = node
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	# kopieën achter de echte titel
	for col in [UiStyleC.GLITCH, UiStyleC.TEAL]:
		var c := _copy(col)
		add_child(c)
		_split.append(c)
	add_child(content)
	# plakjes voor de echte titel
	for k in 2:
		var clip := Control.new()
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(_copy(Color.WHITE))
		add_child(clip)
		_slices.append(clip)
	_hide_all()
	resized.connect(_fit)
	_fit()


## Logo-glitch van RPG ART: strook van n frames (frame_w breed) over het logo.
func setup_strip(tex: Texture2D, frame_w: int) -> void:
	var n := int(tex.get_width() / frame_w)
	for f in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(f * frame_w, 0, frame_w, tex.get_height())
		strip_frames.append(at)
	strip_rect = TextureRect.new()
	strip_rect.name = "LogoGlitch"
	strip_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip_rect.texture = strip_frames[0]
	strip_rect.size = Vector2(frame_w, tex.get_height())
	add_child(strip_rect)
	strip_rect.hide()
	# v0.13: ook de eerste keer na een willekeurige 3-5 s (frame 0 = het schone logo)
	_wait = _rng.randf_range(STRIP_GAP_MIN, STRIP_GAP_MAX)


func set_background(bg: TextureRect) -> void:
	_bg = bg
	_bg_slice = Control.new()
	_bg_slice.name = "BgGlitch"
	_bg_slice.clip_contents = true
	_bg_slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dup := bg.duplicate() as TextureRect
	dup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bg_slice.add_child(dup)
	_bg_line = ColorRect.new()
	_bg_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_line.color = Color(UiStyleC.GLITCH, 0.18)
	bg.add_sibling(_bg_slice)
	_bg_slice.add_sibling(_bg_line)
	_bg_slice.hide()
	_bg_line.hide()


func _copy(col: Color) -> Control:
	var c := content.duplicate() as Control
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c is Label:
		c.add_theme_color_override("font_color", Color(col, 0.75 if col != Color.WHITE else 1.0))
		c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	elif col != Color.WHITE:
		c.modulate = Color(col, 0.7)
	return c


func _fit() -> void:
	if content == null:
		return
	content.position = Vector2.ZERO
	custom_minimum_size = content.get_combined_minimum_size()
	content.size = size
	for c in _split:
		c.size = size
	for clip in _slices:
		clip.get_child(0).size = size


func is_glitching() -> bool:
	return _burst_left > 0.0


func force_glitch() -> void:
	_wait = 0.0


func _process(delta: float) -> void:
	if content == null:
		return
	if not strip_frames.is_empty():
		_process_strip(delta)
		return
	if _burst_left > 0.0:
		_burst_left -= delta
		_step_left -= delta
		if _burst_left <= 0.0:
			_hide_all()
			_wait = _rng.randf_range(GAP_MIN, GAP_MAX)
		elif _step_left <= 0.0:
			_step_left = STEP
			_frame()
		return
	_wait -= delta
	if _wait <= 0.0:
		bursts += 1
		_burst_left = BURST
		_step_left = 0.0


func _process_strip(delta: float) -> void:
	if _burst_left > 0.0:
		_strip_t += delta
		var f := 1 + int(_strip_t * STRIP_FPS)
		if f >= strip_frames.size():
			_burst_left = 0.0
			_set_strip(0)
			_hide_all()
			_wait = _rng.randf_range(STRIP_GAP_MIN, STRIP_GAP_MAX)
			return
		if f != strip_frame:
			_set_strip(f)
			_bg_frame()
		return
	_wait -= delta
	if _wait <= 0.0:
		bursts += 1
		_strip_t = 0.0
		_burst_left = float(strip_frames.size()) / STRIP_FPS
		_set_strip(1)
		_bg_frame()


func _set_strip(f: int) -> void:
	strip_frame = f
	strip_rect.texture = strip_frames[f]
	strip_rect.visible = f != 0
	content.visible = f == 0       # frame 0 = het gewone logo


## Eén glitch-beeld: split + plakjes op willekeurige hoogtes.
func _frame() -> void:
	var dx := float(_rng.randi_range(1, 2))
	_split[0].position = Vector2(-dx, 0)
	_split[1].position = Vector2(dx, 0)
	for c in _split:
		c.visible = _rng.randf() < 0.85
	var h := size.y
	for clip in _slices:
		var band := roundf(_rng.randf_range(2.0, maxf(3.0, h * 0.25)))
		var y := roundf(_rng.randf_range(0.0, maxf(0.0, h - band)))
		clip.position = Vector2(0, y)
		clip.size = Vector2(size.x + 8.0, band)
		clip.get_child(0).position = Vector2(float(_rng.randi_range(-4, 4)), -y)
		clip.visible = _rng.randf() < 0.7
	_bg_frame()


## Lichte glitch op de achtergrond: één smal verschoven plakje + vage roze lijn.
func _bg_frame() -> void:
	if _bg and _bg_slice:
		var bh := roundf(_rng.randf_range(2.0, 6.0))
		var by := roundf(_rng.randf_range(0.0, _bg.size.y - bh))
		_bg_slice.position = Vector2(_bg.position.x, by)
		_bg_slice.size = Vector2(_bg.size.x, bh)
		var dup: TextureRect = _bg_slice.get_child(0)
		dup.size = _bg.size
		dup.position = Vector2(float(_rng.randi_range(-3, 3)), -by)
		_bg_slice.visible = _rng.randf() < 0.6
		_bg_line.position = Vector2(0, by + bh)
		_bg_line.size = Vector2(_bg.size.x, 1)
		_bg_line.visible = _bg_slice.visible


func _hide_all() -> void:
	for c in _split:
		c.hide()
	for clip in _slices:
		clip.hide()
	if _bg_slice:
		_bg_slice.hide()
		_bg_line.hide()
