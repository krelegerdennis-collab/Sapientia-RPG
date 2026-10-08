extends CanvasLayer
## Autoload "Crt": scanline-filter over het HELE scherm (overworld, dialogen en gevechten).
##   - dunne donkere horizontale lijnen (om de andere beeldpixel)
##   - een licht vignet (donkere hoeken)
##   - af en toe (elke 7-16 sec) een heel korte glitch: kleuren schuiven uit elkaar en een
##     smalle band verspringt opzij
## ALLE instellingen staan op één plek: GameData.CRT in scripts/data/game_data.gd.
## Het filter vangt geen tikken/klikken af (mouse_filter = IGNORE), dus touch werkt gewoon.
## Aan/uit tijdens het spel: Crt.set_enabled(false) (of "enabled": false in GameData.CRT).
##
## v0.16 (wens Dennis) GLITCH ALLEEN IN DE ARCHIEVEN: de glitch-flitsen en een zachte pixel-ruis
## langs de randen (GlitchNoise, dezelfde node als vroeger in het tekstvak) staan UIT in het huis,
## buiten, op de wereldkaart, in de tutorial en in gevechten. In een archiefkamer is de sterkte
## glitch_intensity = DungeonRooms.glitch_intensity(scène) (0..1, sterker dichter bij de baas):
## vaker flitsen (glitch_gap_far -> glitch_gap_near), grotere verschuiving, ruis-alpha en iets
## donkerdere scanlines schalen mee. Bij elke scènewissel één opzoeking; geen extra shaders.
## De scanlines + het vignet (het CRT-filter zelf) blijven overal zoals ze waren.
##
## Prestaties (telefoon, gl_compatibility):
##   - het scanline-filter is één rechthoek die alleen donker maakt; het scherm wordt NIET
##     uitgelezen en het draait op de lage spel-resolutie (384x216 / 768x432, daarna pas
##     opgeschaald), dus het kost bijna niets
##   - de glitch leest het scherm wel uit (duurder), maar staat alleen ~0,1 sec aan
##   - beide shaders worden bij de start één keer onzichtbaar getekend ('opwarmen'), zodat
##     de eerste glitch niet hapert doordat de telefoon dan pas de shader compileert
##   - shader-waarden worden alleen gezet als ze veranderen, niet elk frame

const GameData := preload("res://scripts/data/game_data.gd")
const SCANLINES := preload("res://assets/shaders/scanlines.gdshader")
const GLITCH := preload("res://assets/shaders/glitch.gdshader")
const DungeonRoomsC := preload("res://scripts/data/dungeon_rooms.gd")
const GlitchNoiseC := preload("res://scripts/ui/glitch_noise.gd")

var settings: Dictionary = GameData.CRT.duplicate()
var scanlines: ColorRect
var glitch: ColorRect
var _mat: ShaderMaterial
var _gmat: ShaderMaterial
var _next_glitch := 9.0
var _glitch_left := 0.0
var _t := 0.0
var _last_intensity := -1.0
var _warmup_frames := 0
## v0.16 Glitch-sterkte nu (0 = geen glitch; alleen in de Archieven > 0) en de ruis-laag.
var glitch_intensity := 0.0
var noise: Control
var _scene_path := "__start__"


func _ready() -> void:
	layer = 128                          # boven alles (ook boven de fade van Transition)
	process_mode = Node.PROCESS_MODE_ALWAYS
	glitch = _make_rect("Glitch", GLITCH)
	_gmat = glitch.material
	glitch.hide()
	# v0.16 randruis (alleen in de Archieven): GlitchNoise op halve resolutie, één keer gemaakt
	noise = GlitchNoiseC.new()
	noise.name = "Noise"
	noise.inset = 0.0
	noise.resolution_scale = 0.5
	noise.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(noise)
	noise.hide()
	scanlines = _make_rect("Scanlines", SCANLINES)
	_mat = scanlines.material
	apply_settings()
	_next_glitch = randf_range(7.0, 16.0)
	_warm_up()


## Teken de glitch-shader een paar frames zonder effect (aberratie 0, geen band), zodat
## hij al gecompileerd is voor de eerste echte glitch.
func _warm_up() -> void:
	_gmat.set_shader_parameter("aberration", 0.0)
	_gmat.set_shader_parameter("band_shift", 0.0)
	glitch.show()
	_warmup_frames = 3


func _make_rect(node_name: String, shader: Shader) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color.WHITE
	var m := ShaderMaterial.new()
	m.shader = shader
	r.material = m
	add_child(r)
	return r


## Filter aan of uit (bv. vanuit een opties-menu). Uit = er wordt niets meer getekend.
func set_enabled(on: bool) -> void:
	settings["enabled"] = on
	apply_settings()


## Opnieuw toepassen na een wijziging in 'settings' (bv. Crt.settings["scanlines"] = 0.3).
func apply_settings() -> void:
	visible = bool(settings.get("enabled", true))
	set_process(visible)
	_last_intensity = -1.0
	_mat.set_shader_parameter("vignette", float(settings.get("vignette", 0.28)))
	_gmat.set_shader_parameter("aberration", float(settings.get("aberration", 1.5)))
	_update_density()


## Sterkte van de lijnen nu (gevecht: fijn raster, overworld: grover). v0.16: in de Archieven
## iets donkerder (x glitch-sterkte).
func current_intensity() -> float:
	var base := float(settings.get("scanlines" if _is_detail() else "scanlines_overworld", 0.2))
	return base + float(settings.get("scanlines_archief", 0.0)) * glitch_intensity


## v0.16 Glitch-sterkte (0..1) zetten; 0 = alles van de glitch uit (flitsen + ruis).
func set_glitch_intensity(v: float) -> void:
	glitch_intensity = clampf(v, 0.0, 1.0)
	var on := glitch_intensity > 0.0 and bool(settings.get("glitch", true))
	noise.visible = on
	noise.modulate.a = float(settings.get("noise_alpha", 0.3)) * glitch_intensity
	noise.flicker_gap = Vector2(lerpf(4.0, 0.6, glitch_intensity), lerpf(9.0, 2.0, glitch_intensity))
	_next_glitch = _t + glitch_gap()
	if not on and _glitch_left > 0.0 and _warmup_frames == 0:
		_glitch_left = 0.0
		glitch.hide()
		_mat.set_shader_parameter("flash", 0.0)
	_last_intensity = -1.0


## v0.16 Tijd tot de volgende glitch-flits bij de huidige sterkte (sec).
func glitch_gap() -> float:
	var far: Array = settings.get("glitch_gap_far", [9.0, 16.0])
	var near: Array = settings.get("glitch_gap_near", [2.5, 5.0])
	var lo := lerpf(float(far[0]), float(near[0]), glitch_intensity)
	var hi := lerpf(float(far[1]), float(near[1]), glitch_intensity)
	return randf_range(lo, hi)


## v0.16 Bij elke scènewissel: sterkte van de nieuwe scène (archiefkamer > 0, de rest 0).
func _check_scene() -> void:
	var s := get_tree().current_scene
	var path := s.scene_file_path if s != null else ""
	if path == _scene_path:
		return
	_scene_path = path
	set_glitch_intensity(DungeonRoomsC.glitch_intensity(path))


func _is_detail() -> bool:
	return get_window().content_scale_size.y > 300


func _update_density() -> void:
	var v := current_intensity()
	if v == _last_intensity:
		return
	_last_intensity = v
	_mat.set_shader_parameter("intensity", v)
	_mat.set_shader_parameter("period", 2.0)
	scanlines.visible = v > 0.0 or float(settings.get("vignette", 0.0)) > 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_check_scene()
	_update_density()
	if _warmup_frames > 0:
		_warmup_frames -= 1
		if _warmup_frames == 0:
			glitch.hide()
			_gmat.set_shader_parameter("aberration", float(settings.get("aberration", 1.5)))
		return
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			glitch.hide()
			_mat.set_shader_parameter("flash", 0.0)
	elif bool(settings.get("glitch", true)) and glitch_intensity > 0.0 and _t >= _next_glitch:
		start_glitch()
		_next_glitch = _t + glitch_gap()


## Eén korte glitch (ook handig om te testen).
## v0.16: sterker bij een hogere glitch-sterkte (verschuiving, kleurrand, flits); zonder sterkte
## (handmatig, bv. de test) gewoon zoals vroeger.
func start_glitch(duration := -1.0) -> void:
	var k := 1.0 if glitch_intensity <= 0.0 else 0.55 + 0.75 * glitch_intensity
	_glitch_left = duration if duration > 0.0 else randf_range(0.06, 0.14) * (0.8 + 0.4 * glitch_intensity)
	_gmat.set_shader_parameter("band_y", randf_range(0.1, 0.9))
	_gmat.set_shader_parameter("band_h", randf_range(0.01, 0.04) * k)
	_gmat.set_shader_parameter("band_shift", randf_range(3.0, 10.0) * k * (1.0 if randf() < 0.5 else -1.0))
	_gmat.set_shader_parameter("aberration", float(settings.get("aberration", 1.5)) * k)
	_mat.set_shader_parameter("flash", 0.04 * k)
	glitch.show()
