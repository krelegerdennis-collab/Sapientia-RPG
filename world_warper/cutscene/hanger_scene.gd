class_name WorldWarperHangerScene
extends Node2D
## Eerste-bezoekscène in de Hal: canon-scène 2 (De Hanger) en 3 (Sapientia's dreiging).
## Paarse hal, ECHO-hologram, paarse Hanger, roze glitch-silhouet van Sapientia, herstel.
## Geen shader. Tikken gaat verder. De zinnen staan in canon_scenes.gd (via dreiging.gd).

signal hanger_activated
signal threat_finished

const Dreiging := preload("res://world_warper/cutscene/dreiging.gd")
const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")
## Bestaande glitch-art (RPG ART), roze getint als silhouet van licht en ruis.
const SAPIENTIA_TEX := preload("res://assets/sprites/archief2/sapientia_glitch.png")
const SAPIENTIA_ROZE := Color(1.0, 0.45, 0.85, 0.9)
const FLITS_ROZE := Color(0.95, 0.3, 0.75, 1)
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")
const WarperAccent := preload("res://world_warper/art/accent.gd")
## v0.21 RPG ART: hanger_gloed.png (4 frames 16x16) vervangt het paarse vlak tijdens de gloed.
const GLOED_TEX := preload("res://world_warper/art/hanger_gloed.png")
const GLOED_SCALE := 1.5

const ANCHOR_GROUP := "ww_anchor_hanger"
const HALL_QUIET := Color("241433")
const HALL_WARM := Color("4a2a58")
const HALL_LIT := Color("3d2158")
const HALL_THREAT := Color("0c0610")
## Paars = Oude Mensheid, Codex, World Warper, ECHO. Roze blijft de Stroom.
const PURPLE := Color("b07ae8")
const METAL := Color(0.62, 0.55, 0.72, 1)

var _playing := false
var _finished := false
var _play_requested := false
var _activated := false
var _beat := 0
var _line_i := 0
var _jitter_i := 0
var _arm_frame := -1
var _advanced_frame := -1
var _lines: Array[String] = []
var _flags: Dictionary = {}
var _hanger_einde := -1
## Roze silhouet van Sapientia (beat 3). Publiek voor de tests.
var sapientia: TextureRect
var _hologram_home := Vector2.ZERO
var _motion: Tween
var _source: Node = null
## v0.21: geanimeerde gloed (kind van de Hanger, volgt zijn schaal- en kleurpuls)
var gloed: TextureRect
var gloed_frame := 0
var _gloed_t := 0.0

const WarperAccentArt := preload("res://world_warper/art/accent.gd")
const ECHO_HOLO := "res://assets/sprites/archief2/echo.png"
@onready var layer: CanvasLayer = $Layer
@onready var hall: ColorRect = $Layer/Hall
@onready var hologram: Control = $Layer/Hologram
@onready var hanger: ColorRect = $Layer/Hanger
@onready var flicker: ColorRect = $Layer/Flicker
@onready var panel: Panel = $Layer/Panel
@onready var text_label: Label = $Layer/Panel/Text
@onready var hint_label: Label = $Layer/Panel/Hint
@onready var placeholder: Label = $Layer/Hologram/Placeholder


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style()
	_maak_gloed()
	layer.visible = false
	_layout()
	call_deferred("_layout_if_idle")


func _maak_gloed() -> void:
	var at := AtlasTexture.new()
	at.atlas = GLOED_TEX
	at.region = Rect2(Vector2.ZERO, Vector2(WarperAccent.HANGER_FRAME))
	gloed = TextureRect.new()
	gloed.name = "Gloed"
	gloed.texture = at
	gloed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gloed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloed.stretch_mode = TextureRect.STRETCH_SCALE
	gloed.size = Vector2(WarperAccent.HANGER_FRAME) * GLOED_SCALE
	gloed.visible = false
	hanger.add_child(gloed)
	# Zachte halo in de engine (RPG ART: semi-alpha zit niet in de pixelart). Additief, geen shader.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.7, 1.0, 0.55))
	grad.set_color(1, Color(0.85, 0.7, 1.0, 0.0))
	var halo_tex := GradientTexture2D.new()
	halo_tex.gradient = grad
	halo_tex.fill = GradientTexture2D.FILL_RADIAL
	halo_tex.fill_from = Vector2(0.5, 0.5)
	halo_tex.fill_to = Vector2(1.0, 0.5)
	halo_tex.width = 64
	halo_tex.height = 64
	var halo_mat := CanvasItemMaterial.new()
	halo_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := TextureRect.new()
	halo.name = "Halo"
	halo.texture = halo_tex
	halo.material = halo_mat
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.show_behind_parent = true
	halo.size = gloed.size * 2.0
	halo.position = (gloed.size - halo.size) * 0.5
	gloed.add_child(halo)
	_zet_gloed(false)


## Gloed aan = het plaatje, het vlak zelf onzichtbaar (kleur blijft de status). Uit = metalen Hanger.
func _zet_gloed(aan: bool) -> void:
	if gloed == null:
		return
	gloed.visible = aan
	hanger.self_modulate.a = 0.0 if aan else 1.0
	var hs := _control_size(hanger, Vector2(14, 22))
	gloed.position = ((hs - gloed.size) * 0.5).round()
	if aan:
		gloed_frame = 0
		_gloed_t = 0.0
		_toon_frame()


func _toon_frame() -> void:
	(gloed.texture as AtlasTexture).region = Rect2(Vector2(gloed_frame * WarperAccent.HANGER_FRAME.x, 0),
			Vector2(WarperAccent.HANGER_FRAME))


func _process(delta: float) -> void:
	if gloed == null or not gloed.visible:
		return
	_gloed_t += delta
	while _gloed_t >= WarperAccent.HANGER_FRAME_TIME:
		_gloed_t -= WarperAccent.HANGER_FRAME_TIME
		gloed_frame = (gloed_frame + 1) % WarperAccent.HANGER_FRAMES
		_toon_frame()


func maybe_play(flags_source: Node = null) -> void:
	if _playing or _finished:
		return
	if not is_node_ready():
		_source = flags_source
		_play_requested = true
		if not ready.is_connected(_play_when_ready):
			ready.connect(_play_when_ready, CONNECT_ONE_SHOT)
		return
	_start(flags_source)


func _play_when_ready() -> void:
	if not _play_requested or _playing or _finished:
		return
	_play_requested = false
	var source := _source
	_source = null
	_start(source)


func _start(flags_source: Node) -> void:
	if _playing or _finished:
		return
	_source = flags_source
	_layout()
	if not Dreiging.should_play(_read_flags(flags_source)):
		_source = null
		return
	_flags = _read_flags(flags_source).duplicate()
	_lines = Dreiging.lines(_flags)
	_hanger_einde = Dreiging.einde_hanger(_flags)
	if _lines.is_empty():
		_mark_intro_seen()
		_finished = true
		_source = null
		threat_finished.emit()
		return
	_playing = true
	_beat = 0
	_activated = false
	_jitter_i = 0
	_arm_frame = Engine.get_process_frames()
	layer.visible = true
	_enter(0)


func _input(event: InputEvent) -> void:
	if not _playing:
		return
	if not _is_advance(event):
		return
	# De tik die maybe_play opende mag de eerste zin niet overslaan.
	if Engine.get_process_frames() <= _arm_frame:
		get_viewport().set_input_as_handled()
		return
	if Engine.get_process_frames() == _advanced_frame:
		get_viewport().set_input_as_handled()
		return
	_advanced_frame = Engine.get_process_frames()
	_advance()
	get_viewport().set_input_as_handled()


func _is_advance(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	return event.is_action_pressed("interact")


func _advance() -> void:
	var leaving := _beat
	if _line_i == _hanger_einde:
		_set_flag(_source, Canon.FLAG_HANGER)
		_set_flag(_game_state(), Canon.FLAG_HANGER)
	if _line_i >= _lines.size() - 1:
		if leaving == 2:
			_emit_activated()
		_finish()
		return
	if leaving == 2:
		_emit_activated()
	_enter(_line_i + 1)


func _enter(line_index: int) -> void:
	_line_i = line_index
	var beat := Dreiging.beat_at(_line_i, _flags)
	if beat != _beat:
		_beat = beat
		_apply_beat(beat)
	_show_line()


func _show_line() -> void:
	if _line_i < 0 or _line_i >= _lines.size():
		return
	text_label.text = _lines[_line_i]


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_playing = false
	_kill_motion()
	_mark_intro_seen()
	_zet_gloed(false)
	layer.visible = false
	_source = null
	threat_finished.emit()


func _emit_activated() -> void:
	if _activated:
		return
	_activated = true
	hanger_activated.emit()


func _apply_beat(beat: int) -> void:
	match beat:
		1:
			_beat_purple()
		2:
			_beat_gloed()
		3:
			_beat_threat()
		4:
			_beat_restore()
		_:
			_beat_purple()


func _layout_if_idle() -> void:
	if _playing or not is_inside_tree():
		return
	_layout()


func _toon_sapientia(aan: bool) -> void:
	if sapientia == null:
		return
	sapientia.visible = aan
	var vs := Vector2(384, 216)
	if get_viewport() != null:
		vs = get_viewport().get_visible_rect().size
	sapientia.position = (Vector2(vs.x * 0.5 - 96.0, vs.y * 0.6) - sapientia.size * 0.5).round()


func _beat_purple() -> void:
	_kill_motion()
	_toon_sapientia(false)
	hall.color = HALL_QUIET
	_set_flicker(0.0)
	hologram.modulate = Color(0.78, 0.74, 0.9, 1)
	hologram.position = _hologram_home
	hanger.color = METAL
	hanger.modulate = Color.WHITE
	hanger.scale = Vector2.ONE
	_zet_gloed(false)


func _beat_gloed() -> void:
	_kill_motion()
	hologram.modulate = Color(0.92, 0.86, 1, 1)
	hologram.position = _hologram_home
	hall.color = HALL_WARM
	hanger.color = PURPLE
	_zet_gloed(true)
	_toon_sapientia(false)
	hanger.scale = Vector2.ONE
	hanger.modulate = Color(0.55, 0.35, 0.95, 1)
	_motion = create_tween()
	_motion.set_loops(3)
	_motion.tween_property(hanger, "scale", Vector2(1.18, 1.18), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.parallel().tween_property(hanger, "modulate", Color(0.86, 0.72, 1, 1), 0.32)
	_motion.tween_property(hanger, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.parallel().tween_property(hanger, "modulate", Color(0.42, 0.22, 0.78, 1), 0.32)


func _beat_threat() -> void:
	_kill_motion()
	_zet_gloed(false)
	hanger.scale = Vector2.ONE
	hanger.modulate = Color(0.55, 0.5, 0.6, 1)
	hall.color = HALL_THREAT
	hologram.modulate = Color.WHITE
	_set_flicker(0.0)
	flicker.color = FLITS_ROZE
	_toon_sapientia(true)
	_motion = create_tween()
	_motion.set_loops(8)
	_motion.tween_callback(_jitter_hologram)
	_motion.tween_property(flicker, "modulate:a", 0.45, 0.05)
	_motion.parallel().tween_property(sapientia, "modulate:a", 0.35, 0.05)
	_motion.parallel().tween_property(hologram, "modulate:a", 0.15, 0.05)
	_motion.tween_property(flicker, "modulate:a", 0.0, 0.07)
	_motion.parallel().tween_property(sapientia, "modulate:a", 0.9, 0.07)
	_motion.parallel().tween_property(hologram, "modulate:a", 1.0, 0.07)


func _set_flicker(alpha: float) -> void:
	flicker.color = Color(0, 0, 0, 1)
	flicker.modulate = Color(1, 1, 1, alpha)


func _beat_restore() -> void:
	_kill_motion()
	_toon_sapientia(false)
	_set_flicker(0.0)
	hall.color = HALL_LIT
	hologram.modulate = Color.WHITE
	hologram.position = _hologram_home
	hanger.color = Color(0.72, 0.55, 0.95, 1)
	_zet_gloed(false)
	hanger.modulate = Color.WHITE
	hanger.scale = Vector2.ONE


func _jitter_hologram() -> void:
	hologram.position = _hologram_home + _kick(_jitter_i)
	if sapientia != null and sapientia.visible:
		sapientia.position += _kick(_jitter_i + 2)
	_jitter_i += 1


func _kick(i: int) -> Vector2:
	match i % 6:
		0:
			return Vector2(-2, 0)
		2:
			return Vector2(2, -1)
		4:
			return Vector2(-1, 1)
		_:
			return Vector2.ZERO


func _layout() -> void:
	var anchor := _anchor_screen()
	var hz := _control_size(hologram, Vector2(96, 68))
	hologram.position = anchor - hz * 0.5
	_hologram_home = hologram.position
	var hs := _control_size(hanger, Vector2(14, 22))
	hanger.position = Vector2(
		hologram.position.x + (hz.x - hs.x) * 0.5,
		hologram.position.y + hz.y - 6.0
	)
	hanger.pivot_offset = hs * 0.5
	hanger.scale = Vector2.ONE


func _anchor_screen() -> Vector2:
	var tree := get_tree()
	if tree == null:
		return _fallback_anchor()
	for node in tree.get_nodes_in_group(ANCHOR_GROUP):
		if node == self or is_ancestor_of(node):
			continue
		if node is Node2D:
			var body := node as Node2D
			global_position = body.global_position
			return body.get_global_transform_with_canvas().origin
		if node is Control:
			return (node as Control).get_global_rect().get_center()
	return _fallback_anchor()


func _fallback_anchor() -> Vector2:
	var s := Vector2(384, 216)
	var vp := get_viewport()
	if vp != null:
		s = vp.get_visible_rect().size
	return Vector2(s.x * 0.5, s.y * 0.58)


func _control_size(ctrl: Control, fallback: Vector2) -> Vector2:
	var s := ctrl.size
	if s.x < 1.0 or s.y < 1.0:
		s = ctrl.custom_minimum_size
	if s.x < 1.0 or s.y < 1.0:
		return fallback
	return s


func _read_flags(source: Node) -> Dictionary:
	if source != null and source.get("story_flags") is Dictionary:
		return _flags_of(source)
	return _flags_of(_game_state())


func _flags_of(node: Node) -> Dictionary:
	if node == null:
		return {}
	var raw: Variant = node.get("story_flags")
	if raw is Dictionary:
		return raw as Dictionary
	return {}


func _mark_intro_seen() -> void:
	for f in [Dreiging.FLAG, Canon.FLAG_HANGER, Canon.FLAG_DREIGING]:
		_set_flag(_source, f)
		_set_flag(_game_state(), f)
	var gs := _game_state()
	if gs != null and gs.has_method("mark_scene_seen"):
		gs.mark_scene_seen("hanger")    # v0.22 veldmenu > Scenes


func _set_flag(node: Node, flag: String = Dreiging.FLAG) -> void:
	if node == null:
		return
	var raw: Variant = node.get("story_flags")
	if raw is Dictionary:
		var flags := raw as Dictionary
		flags[flag] = true
		node.set("story_flags", flags)


func _game_state() -> Node:
	if not is_instance_valid(GameState):
		return null
	return GameState


func _style() -> void:
	panel.add_theme_stylebox_override("panel", UiStyleC.panel("window"))
	_font_label(text_label, 10, UiStyleC.TEXT)
	text_label.add_theme_color_override("font_shadow_color", UiStyleC.SHADOW)
	text_label.add_theme_constant_override("shadow_offset_x", 1)
	text_label.add_theme_constant_override("shadow_offset_y", 1)
	_font_label(hint_label, 8, UiStyleC.TEXT_DIM)
	_font_label(placeholder, 10, Color(0.1, 0.06, 0.14, 1))
	if sapientia == null:
		sapientia = TextureRect.new()
		sapientia.name = "Sapientia"
		sapientia.texture = SAPIENTIA_TEX
		sapientia.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sapientia.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sapientia.stretch_mode = TextureRect.STRETCH_SCALE
		sapientia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sapientia.size = Vector2(72, 72)
		sapientia.modulate = SAPIENTIA_ROZE
		sapientia.visible = false
		layer.add_child(sapientia)
		layer.move_child(sapientia, hologram.get_index())
	# Hologram: ECHO-art van RPG ART in plaats van het woord PLACEHOLDER.
	if hologram != null and hologram.get_node_or_null("EchoArt") == null:
		var pad := WarperAccentArt.path(ECHO_HOLO, WarperAccentArt.current())
		if ResourceLoader.exists(pad):
			var art := TextureRect.new()
			art.name = "EchoArt"
			art.texture = load(pad) as Texture2D
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.modulate.a = 0.6     # ECHO doorschijnend (RPG ART: alpha in de engine)
			hologram.add_child(art)


func _font_label(lbl: Label, size: int, color: Color) -> void:
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)


func _kill_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
