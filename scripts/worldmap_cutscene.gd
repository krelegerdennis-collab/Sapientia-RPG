class_name WorldmapCutscene
extends CanvasLayer
## Eenmalige filmpje bij de EERSTE keer op de wereldkaart (Dennis in het woud bij de moswezens).
## - Vlag FLAG in GameState.story_flags (gaat mee in save/load); daarna nooit meer.
## - Portret-video (360x640 Theora .ogv) gecentreerd in het liggende beeld, links/rechts
##   donkere glitch-panelen. Echte panel-art van RPG ART: zet PANEL_TEXTURE neer (zelfde pad),
##   anders tekent de code een placeholder. Rechterpaneel = gespiegeld linkerpaneel.
## - Tik / klik / interact / ui_accept slaat over. Vangnet-timer: nooit een soft-lock.
## - Speler-input en de map-muziek komen terug na afloop.

signal finished

const FLAG := "cutscene_wereldkaart_gezien"
const VIDEO_PATH := "res://assets/video/worldmap_intro.ogv"
## Drop-in voor RPG ART (portret-paneel, bv. 96x216; wordt uitgerekt tot de randbreedte).
const PANEL_TEXTURE := "res://art/cutscene/glitch_panel.png"
const VIDEO_ASPECT := 9.0 / 16.0
## Vangnet: video ~15 s; na deze tijd sowieso klaar (bv. als de browser niets afspeelt).
const MAX_SECONDS := 20.0
## v0.23: dezelfde speler voor andere filmpjes (bv. na De Genezer): pad + vangnet per exemplaar.
var video_path := VIDEO_PATH
var max_seconds := MAX_SECONDS
## Even geen skip direct na binnenkomst (de stap-toets die je nog vasthoudt).
const SKIP_GRACE := 0.4

## Testers zetten dit aan; anders speelt de cutscene niet tijdens --xxxtest-runs.
static var allow_in_tests := false

var video: VideoStreamPlayer
var left_panel: TextureRect
var right_panel: TextureRect
var _root: Control
var _player: Node
var _map: Node
var _elapsed := 0.0
var _done := false
## Scherp beeld: tijdens het filmpje rendert de root op schermresolutie (canvas_items)
## i.p.v. de 384x216-viewport; na afloop terug, zodat de pixel-art ongewijzigd blijft.
var _old_scale_mode := -1


## Moet de cutscene nu starten voor deze scène?
static func should_play(scene_path: String) -> bool:
	if scene_path.get_file().get_basename() != "wereldkaart":
		return false
	if GameState.story_flags.has(FLAG):
		return false
	if not allow_in_tests:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--") and a.ends_with("test"):
				return false
	return true


## Start op de map (zet de vlag meteen, zodat de autosave hem al meeneemt).
static func start_on(map: Node) -> WorldmapCutscene:
	GameState.story_flags[FLAG] = true
	GameState.mark_scene_seen("wereldkaart")   # v0.22 veldmenu > Scenes
	var c := WorldmapCutscene.new()
	c.name = "WorldmapCutscene"
	map.add_child(c)
	c.begin(map)
	return c


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func begin(map: Node) -> void:
	_map = map
	SessieLog.cutscene("wereldkaart_film", true)
	_player = map.get_node_or_null("Objects/Player")
	if _player != null and "input_locked" in _player:
		_player.input_locked = true
	_sharp_on()
	_build()
	AudioManager.stop_music(0.3)
	var stream: VideoStream = null
	if ResourceLoader.exists(video_path):
		stream = load(video_path) as VideoStream
	if stream == null:
		push_warning("WorldmapCutscene: video ontbreekt, overslaan")
		_finish.call_deferred()
		return
	video.stream = stream
	video.finished.connect(_finish)
	video.play()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var tex := panel_texture()
	left_panel = _panel(tex, false)
	right_panel = _panel(tex, true)
	video = VideoStreamPlayer.new()
	video.expand = true
	video.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		video.bus = "Music"
	_root.add_child(video)
	_root.resized.connect(_layout)
	_layout()


func _panel(tex: Texture2D, mirror: bool) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.flip_h = mirror
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	return r


## Echte art als die er is, anders een placeholder (donker met cyaan/magenta glitch-strepen).
static func panel_texture() -> Texture2D:
	if ResourceLoader.exists(PANEL_TEXTURE):
		var t := load(PANEL_TEXTURE) as Texture2D
		if t != null:
			return t
	return placeholder_panel()


static func placeholder_panel() -> Texture2D:
	var w := 96
	var h := 216
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.03, 0.09))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	for i in 40:
		var y := rng.randi_range(0, h - 1)
		var x := rng.randi_range(0, w - 8)
		var l := rng.randi_range(4, 40)
		var c := Color(0.25, 0.95, 1.0, 0.55) if i % 3 == 0 else (Color(1.0, 0.3, 0.85, 0.45) if i % 3 == 1 else Color(0.2, 0.15, 0.3))
		for dx in range(l):
			if x + dx < w:
				img.set_pixel(x + dx, y, c)
	# rand richting de video (rechts in het linkerpaneel)
	for y in h:
		img.set_pixel(w - 1, y, Color(0.25, 0.95, 1.0, 0.6))
	return ImageTexture.create_from_image(img)


func _layout() -> void:
	if _root == null:
		return
	var s := _root.size
	if s.x <= 0 or s.y <= 0:
		s = _root.get_viewport_rect().size
	var vw := s.y * VIDEO_ASPECT
	var vx := (s.x - vw) * 0.5
	video.position = Vector2(vx, 0)
	video.size = Vector2(vw, s.y)
	left_panel.position = Vector2.ZERO
	left_panel.size = Vector2(max(vx, 0.0), s.y)
	right_panel.position = Vector2(vx + vw, 0)
	right_panel.size = Vector2(max(vx, 0.0), s.y)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	# een verhaal-event mag de speler niet ontgrendelen zolang het filmpje loopt
	if _player != null and is_instance_valid(_player) and "input_locked" in _player:
		_player.input_locked = true
	if _elapsed >= max_seconds:
		_finish()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed:
		skip = true
	elif event is InputEventScreenTouch and event.pressed:
		skip = true
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		skip = true
	if not skip:
		return
	get_viewport().set_input_as_handled()
	if _elapsed >= SKIP_GRACE:
		skip_now()


func skip_now() -> void:
	_finish()


func is_done() -> bool:
	return _done


func _finish() -> void:
	if _done:
		return
	_done = true
	SessieLog.cutscene("wereldkaart_film", false)
	if video != null and video.is_playing():
		video.stop()
	if _player != null and is_instance_valid(_player) and "input_locked" in _player:
		if Story.idle() and not Dialog.is_open and not GameState.changing_map and not GameState.in_battle:
			_player.input_locked = false
	if _map != null and is_instance_valid(_map) and _map.has_method("_play_map_music"):
		_map._play_map_music()
	_sharp_off()
	finished.emit()
	queue_free()


func _sharp_on() -> void:
	var w := get_tree().root
	if w.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		_old_scale_mode = w.content_scale_mode
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


func _sharp_off() -> void:
	if _old_scale_mode >= 0 and is_inside_tree():
		get_tree().root.content_scale_mode = _old_scale_mode as Window.ContentScaleMode
	_old_scale_mode = -1


func _exit_tree() -> void:
	_sharp_off()
