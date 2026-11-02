class_name WorldWarperGenezerScene
extends Node
## Canon-scène 1 (CANON.md punt 17): na De Genezer verschijnt de World Warper.
## Kern zweeft, de kas glitcht weg, paarse straal, de World Warper in de lucht, ECHO,
## paarse cirkel, flits en warp naar de Hal. Dialoog via de Dialog-autoload.
## Alleen bestaande art: levenskern.png, world_warper_groen.png (accent Archief 2).
## Hangt als kind aan de kamer; beeld op een CanvasLayer onder de dialoog (laag 5).

signal klaar

const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")
const KERN_TEX := preload("res://assets/ui/icons/levenskern.png")
const WARPER_TEX := preload("res://assets/sprites/archief2/world_warper_groen.png")
const PAARS := Color("b07ae8")
const LUCHT := Color("1a0f26")
const GRIJS := Color(0.55, 0.57, 0.55, 1)
const LAAG := 4

## v0.23 filmpje van Dennis (~21 s, 720x1280): de kern, de Hanger licht op, straal door de kas,
## de lucht scheurt open en de World Warper verschijnt. Speelt vóór de dialoog, één keer (vlag),
## en altijd in de herhaling (veldmenu > Scenes > The World Warper).
const VIDEO := "res://assets/video/genezer_warper.ogv"
const VIDEO_FLAG := "cutscene_genezer_video_gezien"
const VIDEO_MAX := 26.0
const CutsceneSpeler := preload("res://scripts/worldmap_cutscene.gd")
var video_speler: CanvasLayer = null

## Eén scène tegelijk (kern-signaal en kamer-fallback mogen niet dubbel starten).
static var bezig := false

var cue := ""
var regels_getoond: Array[String] = []
var _laag: CanvasLayer
var _lucht: ColorRect
var _straal: ColorRect
var _kern: TextureRect
var _warper: TextureRect
var _cirkel: Control
var _flits: ColorRect
var _kamer: Node2D
var _motion: Array[Tween] = []
var herhaling := false
var _klaar_gemeld := false


static func mag_spelen(flags: Dictionary) -> bool:
	return not bezig and Canon.genezer_speelt(flags)


## Speelt de scène in kamer `kamer` en warpt daarna naar de Hal. Geeft false als hij niet speelt.
static func speel(kamer: Node) -> bool:
	if kamer == null or not mag_spelen(GameState.story_flags):
		return false
	bezig = true
	var s: Node = load("res://world_warper/cutscene/genezer_scene.gd").new()
	s.name = "CanonGenezer"
	kamer.add_child(s)
	s.call_deferred("_speel")
	return true


## Veldmenu > Scenes: speelt de scène los af, zonder vlaggen of mapwissel. Eindigt met 'klaar'.
static func herhaal(ouder: Node) -> Node:
	var s: Node = load("res://world_warper/cutscene/genezer_scene.gd").new()
	s.name = "CanonGenezer"
	s.herhaling = true
	ouder.add_child(s)
	s.call_deferred("_speel")
	return s


## Herhaling meteen afronden (overslaan / testhaakje).
func stop_herhaling() -> void:
	if not herhaling or _klaar_gemeld:
		return
	if video_speler != null and is_instance_valid(video_speler):
		video_speler.skip_now()
	if Dialog.is_open and Dialog.has_method("close"):
		Dialog.close()
	_stop()
	_klaar_gemeld = true
	klaar.emit()
	queue_free()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_kamer = get_parent() as Node2D
	_bouw()


func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size


func _bouw() -> void:
	var vs := _vs()
	_laag = CanvasLayer.new()
	_laag.name = "Laag"
	_laag.layer = LAAG
	add_child(_laag)
	_lucht = _rect("Lucht", LUCHT, Rect2(Vector2.ZERO, vs))
	_lucht.modulate.a = 0.0
	_warper = _tex("Warper", WARPER_TEX, Vector2(160, 80))
	_warper.position = Vector2((vs.x - 160) * 0.5, -100)
	_warper.visible = false
	_straal = _rect("Straal", PAARS, Rect2(vs.x * 0.5 - 14, 0, 28, vs.y * 0.74))
	_straal.modulate.a = 0.0
	_cirkel = Ring.new()
	_cirkel.name = "Cirkel"
	_cirkel.position = Vector2(vs.x * 0.5, vs.y * 0.82)
	_cirkel.visible = false
	_laag.add_child(_cirkel)
	_kern = _tex("Kern", KERN_TEX, Vector2(32, 32))
	_kern.position = Vector2(vs.x * 0.5 - 16, vs.y * 0.66)
	_kern.visible = false
	_flits = _rect("Flits", Color.WHITE, Rect2(Vector2.ZERO, vs))
	_flits.modulate.a = 0.0


func _rect(n: String, c: Color, r: Rect2) -> ColorRect:
	var cr := ColorRect.new()
	cr.name = n
	cr.color = c
	cr.position = r.position
	cr.size = r.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_laag.add_child(cr)
	return cr


func _tex(n: String, t: Texture2D, sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = n
	tr.texture = t
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = sz
	_laag.add_child(tr)
	return tr


func _speel() -> void:
	await _speel_video()
	# v0.25 Bug (Dennis): in de herhaling (veldmenu > Scenes > The World Warper) speelde na zijn filmpje
	# nog de gescripte canon-scène (dialoog + effecten). De herhaling is nu alleen het filmpje; het echte
	# verhaal speelt ongewijzigd filmpje + scène.
	if herhaling:
		if not _klaar_gemeld:
			_klaar_gemeld = true
			klaar.emit()
			queue_free()
		return
	var speler: Node = _kamer.get("player") if _kamer != null and "player" in _kamer else null
	if is_instance_valid(speler):
		speler.set("input_locked", true)
	for r in Canon.GENEZER:
		var c := str(r.get("cue", ""))
		if c != cue:
			cue = c
			_cue(c)
		var wie := str(r.get("who", ""))
		if wie == "Dax":
			wie = GameState.player_name
		regels_getoond.append(str(r.get("text", "")))
		await get_tree().create_timer(0.25).timeout
		Dialog.show_lines([str(r.get("text", ""))], wie)
		await Dialog.finished
	await _einde()


## Filmpje vóór de dialoog. Echt verhaal: vlag meteen zetten (save-veilig: nooit twee keer).
func _speel_video() -> void:
	if not ResourceLoader.exists(VIDEO):
		return
	if not herhaling:
		if GameState.story_flags.has(VIDEO_FLAG):
			return
		GameState.story_flags[VIDEO_FLAG] = true
	var c: CanvasLayer = CutsceneSpeler.new()
	c.name = "GenezerVideo"
	c.video_path = VIDEO
	c.max_seconds = VIDEO_MAX
	c.layer = 127          # boven het veldmenu én de herhalingsachtergrond (125/124); CRT-filter = 128
	add_child(c)
	video_speler = c
	c.begin(c)
	if not c.is_done():
		await c.finished
	video_speler = null


func _tween() -> Tween:
	var t := create_tween()
	_motion.append(t)
	return t


func _stop() -> void:
	for t in _motion:
		if t != null and t.is_valid():
			t.kill()
	_motion.clear()


func _cue(c: String) -> void:
	match c:
		"kern":
			_kern.visible = true
			var t := _tween().set_loops(0)
			t.tween_property(_kern, "position:y", _kern.position.y - 6, 0.6).set_trans(Tween.TRANS_SINE)
			t.tween_property(_kern, "position:y", _kern.position.y, 0.6).set_trans(Tween.TRANS_SINE)
		"glitch":
			# groen wordt grijs, planten vervagen
			if _kamer != null:
				_tween().tween_property(_kamer, "modulate", GRIJS, 1.2)
			var t := _tween().set_loops(4)
			t.tween_property(_lucht, "modulate:a", 0.25, 0.06)
			t.tween_property(_lucht, "modulate:a", 0.0, 0.1)
		"dreun":
			if _kamer != null:
				var basis := _kamer.position
				var t := _tween().set_loops(6)
				t.tween_property(_kamer, "position", basis + Vector2(2, 0), 0.04)
				t.tween_property(_kamer, "position", basis + Vector2(-2, 1), 0.04)
				t.tween_property(_kamer, "position", basis, 0.04)
		"straal":
			_tween().tween_property(_straal, "modulate:a", 0.85, 0.35)
		"warper":
			# het plafond verdwijnt: de kas wijkt voor de lucht, de Warper daalt
			_warper.visible = true
			var t := _tween()
			t.tween_property(_lucht, "modulate:a", 0.88, 0.8)
			t.parallel().tween_property(_warper, "position:y", 54.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(_straal, "modulate:a", 0.45, 0.8)
		"puls":
			var t := _tween().set_loops(0)
			t.tween_property(_kern, "modulate", PAARS, 0.4)
			t.parallel().tween_property(_warper, "modulate", Color(1.3, 1.0, 1.5, 1), 0.4)
			t.tween_property(_kern, "modulate", Color.WHITE, 0.4)
			t.parallel().tween_property(_warper, "modulate", Color.WHITE, 0.4)
		"cirkel":
			_cirkel.visible = true
			(_cirkel as Ring).straal = 4.0
			_tween().tween_property(_cirkel, "straal", 70.0, 1.4).set_trans(Tween.TRANS_SINE)
		"flits":
			_tween().tween_property(_flits, "modulate:a", 0.35, 0.3)


func _einde() -> void:
	var t := create_tween()
	t.tween_property(_flits, "modulate:a", 1.0, 0.25)
	await t.finished
	_stop()
	if herhaling:
		if not _klaar_gemeld:
			_klaar_gemeld = true
			klaar.emit()
			queue_free()
		return
	GameState.story_flags[Canon.FLAG_GENEZER] = true
	GameState.story_flags["archief2_naar_warper"] = true
	GameState.try_unlock_world_warper()
	var NaGenezer := load("res://world_warper/flow/na_genezer.gd")
	NaGenezer.set("pending", false)
	bezig = false
	klaar.emit()
	if _kamer != null:
		_kamer.modulate = Color.WHITE
	GameState.change_map(Canon.HAL_SCENE, Canon.HAL_SPAWN)


## Paarse cirkel die zich uitbreidt (geen shader, alleen draw_arc).
class Ring extends Control:
	var straal := 4.0:
		set(v):
			straal = v
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(Vector2.ZERO, straal, 0, TAU, 48, Color(0.69, 0.48, 0.91, 0.9), 2.0)
		draw_arc(Vector2.ZERO, straal * 0.7, 0, TAU, 40, Color(0.69, 0.48, 0.91, 0.45), 1.0)
