class_name WorldWarperOpeningDrift
extends CanvasLayer
## Korte drift-cutscene vóór de story-Hal (CANON Drift). Parallax + wormhole + warper-loop.
## Stretch-aspect expand (brede telefoon): de achtergrond vult het hele viewport, zoals het
## titelscherm. Tekst, wormhole en schip blijven in een 384×216-stage in het midden.

signal finished

const Art := preload("res://world_warper/opening/art.gd")
const FONT_PATH := "res://assets/fonts/Dauwpixel-Regular.ttf"

const REGELS: Array[String] = [
	"Something ancient still moves between the Archives.",
	"Sapientia wants every core. Every Archive. All of humanity's memory.",
	"The World Warper keeps watch in the gaps between worlds.",
	"For now, you only drift.",
]

const SKIP_GRACE := 0.35
const MAX_SECONDS := 45.0
## Tegel i=-1..2: bij gecentreerde stage dekt de scroll ook de randen links en rechts
## (viewport tot ~3×384 breed; een 20:9-telefoon is ~480).
const _TILE_START := -1
const _TILE_COUNT := 4

var _root: Control
var _backfill: TextureRect
var _stage_host: Control
var _scroll_far := 0.0
var _scroll_nebula := 0.0
var _scroll_near := 0.0
var _layers: Array[_ParallaxPair] = []
var _wormhole: Sprite2D
var _worm_tick := 0
var _warper: Sprite2D
var _warper_frame := 0
var _warper_tick := 0
var _elapsed := 0.0
var _line_i := 0
var _done := false
var _label: Label
var _hint: Label


static func play(host: Node) -> void:
	var d := WorldWarperOpeningDrift.new()
	d.name = "OpeningDrift"
	host.add_child(d)
	await d.finished


func _init() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	SessieLog.cutscene("warper_drift", true)
	_build()
	set_process(true)


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.clip_contents = true
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_backfill = TextureRect.new()
	_backfill.name = "Backfill"
	_backfill.texture = load(Art.BG_FAR) as Texture2D
	_backfill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backfill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backfill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backfill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backfill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_backfill)
	_stage_host = Control.new()
	_stage_host.name = "Stage"
	_stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_host.size = Vector2(Art.VIEW_W, Art.VIEW_H)
	_root.add_child(_stage_host)
	var stage := Node2D.new()
	stage.name = "Parallax"
	_stage_host.add_child(stage)
	_layers.append(_parallax(stage, Art.BG_FAR, 1.0))
	var nebula := _parallax(stage, Art.BG_NEBULA, 2.0)
	_layers.append(nebula)
	_wormhole = _strip_sprite(Art.WORMHOLE, Art.WORMHOLE_FRAME, Art.WORMHOLE_FRAMES)
	_wormhole.position = Vector2(Art.WORMHOLE_POS)
	nebula.node.add_child(_wormhole)
	_layers.append(_parallax(stage, Art.BG_NEAR, 4.0))
	_warper = _strip_sprite(Art.WARPER, Art.WARPER_FRAME, Art.WARPER_FRAMES)
	_warper.position = Art.WARPER_POS
	stage.add_child(_warper)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(340, 0)
	_label.position = Vector2(22, 168)
	_label.z_index = 10
	_label.add_theme_font_override("font", _font())
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color("f2e9d8"))
	_stage_host.add_child(_label)
	_hint = Label.new()
	_hint.text = "Tap to skip"
	_hint.position = Vector2(22, 200)
	_hint.z_index = 10
	_hint.add_theme_font_override("font", _font())
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8, 0.9))
	_stage_host.add_child(_hint)
	_toon_regel()
	_root.resized.connect(_plaats_stage)
	if not get_viewport().size_changed.is_connected(_plaats_stage):
		get_viewport().size_changed.connect(_plaats_stage)
	_plaats_stage()
	_plaats_stage.call_deferred()


## 384×216-stage in het midden van het (mogelijk bredere) viewport. Zelfde idee als het titelscherm.
func _plaats_stage() -> void:
	if _root == null or _stage_host == null:
		return
	var vs := _root.size
	if (vs.x < 1.0 or vs.y < 1.0) and is_inside_tree():
		vs = get_viewport().get_visible_rect().size
	if vs.x < 1.0 or vs.y < 1.0:
		return
	_stage_host.size = Vector2(Art.VIEW_W, Art.VIEW_H)
	_stage_host.position = ((vs - _stage_host.size) * 0.5).floor()


func _font() -> Font:
	return load(FONT_PATH) as Font


class _ParallaxPair:
	var node: Node2D
	var tiles: Array[Sprite2D] = []
	var speed := 1.0


func _parallax(parent: Node2D, pad: String, speed: float) -> _ParallaxPair:
	var pair := _ParallaxPair.new()
	pair.speed = speed
	pair.node = Node2D.new()
	pair.node.name = pad.get_file().get_basename()
	parent.add_child(pair.node)
	var tex := load(pad) as Texture2D
	for i in _TILE_COUNT:
		var s := _tile_sprite(tex)
		s.position.x = float((_TILE_START + i) * Art.VIEW_W)
		pair.node.add_child(s)
		pair.tiles.append(s)
	return pair


func _tile_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	return s


func _strip_sprite(pad: String, fr: Vector2i, count: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(pad) as Texture2D
	s.hframes = count
	s.frame = 0
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	return s


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_scroll_far += delta * Art.SCROLL_BASE * 1.0
	_scroll_nebula += delta * Art.SCROLL_BASE * 2.0
	_scroll_near += delta * Art.SCROLL_BASE * 4.0
	_apply_scroll(_layers[0], _scroll_far)
	_apply_scroll(_layers[1], _scroll_nebula)
	_apply_scroll(_layers[2], _scroll_near)
	_worm_tick += 1
	if _worm_tick % Art.WORMHOLE_TICKS_PER_FRAME == 0 and _wormhole != null:
		_wormhole.frame = (_wormhole.frame + 1) % Art.WORMHOLE_FRAMES
	_warper_tick += 1
	if _warper_tick % 4 == 0 and _warper != null:
		_warper_frame = (_warper_frame + 1) % Art.WARPER_FRAMES
		_warper.frame = _warper_frame
	if _elapsed > 2.2 and int(_elapsed / 4.5) != _line_i and _line_i + 1 < REGELS.size():
		_line_i += 1
		_toon_regel()
	if _elapsed >= MAX_SECONDS:
		_klaar()


func _apply_scroll(pair: _ParallaxPair, scroll: float) -> void:
	var x := -fmod(scroll, float(Art.VIEW_W))
	for i in pair.tiles.size():
		pair.tiles[i].position.x = x + float((_TILE_START + i) * Art.VIEW_W)


func _toon_regel() -> void:
	if _line_i < REGELS.size():
		_label.text = REGELS[_line_i]


func _input(event: InputEvent) -> void:
	if _done or _elapsed < SKIP_GRACE:
		return
	if event is InputEventMouseButton and event.pressed:
		_klaar()
	elif event is InputEventScreenTouch and event.pressed:
		_klaar()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_klaar()


func _klaar() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	SessieLog.cutscene("warper_drift", false)
	finished.emit()
