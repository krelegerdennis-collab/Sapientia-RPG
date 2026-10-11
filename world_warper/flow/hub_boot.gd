class_name WorldWarperHubBoot
extends Node2D
## Koppelt de hal (of, licht, alleen de buiten-ambience).
## map.gd blijft ongewijzigd. Die stopt muziek zonder music_track ná de kinderen;
## daarom volgt een uitgestelde play_hub / play_hum op de directe aanroep.
##
## Warp-view en party-select zetten zich op het eerste lid van ww_anchor_warp /
## ww_anchor_party. Een Marker2D in de wereld zou het scherm op wereldpixels
## prikken. Die ankers gaan daarom uit de groep vóór het instantieren; het
## Marker2D blijft de plek van het interactievlak. De views hangen aan een
## CanvasLayer. Hun open() / close() blijft de publieke API.

const GIDS_SCENE := preload("res://world_warper/guide/gids.tscn")
const WANDER_SCENE := preload("res://world_warper/wander/wanderers.tscn")
const SAVE_SCENE := preload("res://world_warper/services/save_point.tscn")
const PARTY_SCENE := preload("res://world_warper/services/party_select.tscn")
const WARP_SCENE := preload("res://world_warper/warp/warp_view.tscn")
const HANGER_SCENE := preload("res://world_warper/cutscene/hanger_scene.tscn")
const AmbienceScript := preload("res://world_warper/audio/ambience.gd")

## Boven touch (10) en dialoog (5), onder de hanger-scène (30).
const SCHERM_LAAG := 20

## Buiten: alleen play_hub. Geen cutscene en geen andere onderdelen.
@export var licht := false

## Basistypes, geen class_name. Die namen staan pas in de globale cache na een
## editor-import; zonder cache weigert Godot dit script te parsen en start de hal niet.
var _ambience: RefCounted
var _gids: StaticBody2D
var _wanderers: Node2D
var _save: Control
var _party: Control
var _warp: Control
var _hanger: Node2D


func _ready() -> void:
	_ambience = AmbienceScript.new()
	if licht:
		_ambience.play_hub()
		call_deferred("_speel_hub")
		return
	_bouw_hal()
	_ambience.play_hub()
	_ambience.play_hum()
	call_deferred("_speel_hal")


func _speel_hub() -> void:
	_ambience.play_hub()


func _speel_hal() -> void:
	_ambience.play_hub()
	_ambience.play_hum()


func _bouw_hal() -> void:
	var warp_pos := _anker_positie("ww_anchor_warp")
	var party_pos := _anker_positie("ww_anchor_party")
	_ontkoppel_wereldankers("ww_anchor_warp")
	_ontkoppel_wereldankers("ww_anchor_party")

	_gids = GIDS_SCENE.instantiate() as StaticBody2D
	_gids.name = "Gids"
	add_child(_gids)

	_wanderers = WANDER_SCENE.instantiate() as Node2D
	_wanderers.name = "Wanderers"
	add_child(_wanderers)

	_save = SAVE_SCENE.instantiate() as Control
	_save.name = "Savepunt"
	add_child(_save)

	_hanger = HANGER_SCENE.instantiate() as Node2D
	_hanger.name = "HangerScene"
	add_child(_hanger)

	var scherm := CanvasLayer.new()
	scherm.name = "Scherm"
	scherm.layer = SCHERM_LAAG
	add_child(scherm)

	_warp = WARP_SCENE.instantiate() as Control
	_warp.name = "WarpView"
	scherm.add_child(_warp)

	_party = PARTY_SCENE.instantiate() as Control
	_party.name = "PartySelect"
	scherm.add_child(_party)

	_maak_vlak(warp_pos, "Warp", _open_warp)
	_maak_vlak(party_pos, "Gezelschap", _open_party)

	if not _warp.is_connected("warp_requested", _on_warp_requested):
		_warp.connect("warp_requested", _on_warp_requested)
	if not _hanger.is_connected("hanger_activated", _on_hanger_activated):
		_hanger.connect("hanger_activated", _on_hanger_activated)

	_wanderers.call("refresh")
	_hanger.call("maybe_play")


func _on_warp_requested(_wm_id: String, _place_id: String) -> void:
	_ambience.play_warp()


func _on_hanger_activated() -> void:
	_ambience.play_glitch()


## TODO(design): het andere scherm gaat dicht. Twee panelen tegelijk zijn niet afgesproken.
func _open_warp() -> void:
	if _geblokkeerd() or _warp == null:
		return
	if _party != null and bool(_party.call("is_open")):
		_party.call("close")
	_warp.call("open")


func _open_party() -> void:
	if _geblokkeerd() or _party == null:
		return
	if _warp != null and _warp.visible:
		_warp.call("close")
	_party.call("open")


func _geblokkeerd() -> bool:
	if _dialoog_open():
		return true
	if _hanger == null:
		return false
	var laag := _hanger.get_node_or_null("Layer") as CanvasItem
	return laag != null and laag.visible


func _dialoog_open() -> bool:
	var dlg := get_node_or_null("/root/Dialog")
	if dlg == null:
		return false
	return bool(dlg.get("is_open"))


func _anker_positie(groep: String) -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	for node in get_tree().get_nodes_in_group(groep):
		if node is Node2D and node != self:
			return (node as Node2D).global_position
	return global_position


func _ontkoppel_wereldankers(groep: String) -> void:
	if not is_inside_tree():
		return
	var weg: Array[Node] = []
	for node in get_tree().get_nodes_in_group(groep):
		if node is Node2D:
			weg.append(node)
	for node in weg:
		node.remove_from_group(groep)


func _maak_vlak(wereld: Vector2, tekst: String, bij_keuze: Callable) -> void:
	var vlak := Interactievlak.new()
	vlak.name = "Vlak%s" % tekst
	vlak.titel = tekst
	vlak.gekozen.connect(bij_keuze)
	add_child(vlak)
	vlak.global_position = wereld


class Interactievlak extends Area2D:
	## Placeholder-vlak. Tik of interact() opent het scherm. Geen definitieve art.
	signal gekozen
	const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")
	var titel := ""
	var _frame := -1

	func _ready() -> void:
		input_pickable = true
		monitoring = false
		monitorable = true
		collision_layer = 1
		collision_mask = 1
		var vorm := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 14)
		vorm.shape = rect
		add_child(vorm)
		var vlak := Polygon2D.new()
		vlak.color = Color(0.45, 0.22, 0.72, 0.95)
		vlak.polygon = PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
		])
		add_child(vlak)
		var rand := Polygon2D.new()
		rand.color = Color(1.0, 0.25, 0.72, 1.0)
		rand.polygon = PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, -6), Vector2(-8, -6),
		])
		add_child(rand)
		var label := Label.new()
		label.text = titel
		label.position = Vector2(-48, -22)
		label.size = Vector2(96, 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color("f2e9d8"))
		label.add_theme_color_override("font_shadow_color", Color("07060a"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(label)

	func interact(_by: Node = null) -> void:
		_kies()

	func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
		if not _tik(event):
			return
		_kies()
		get_viewport().set_input_as_handled()

	func _kies() -> void:
		var frame := Engine.get_process_frames()
		if frame == _frame:
			return
		_frame = frame
		gekozen.emit()

	func _tik(event: InputEvent) -> bool:
		if event is InputEventScreenTouch:
			return (event as InputEventScreenTouch).pressed
		if event is InputEventMouseButton:
			var muis := event as InputEventMouseButton
			return muis.pressed and muis.button_index == MOUSE_BUTTON_LEFT
		return false
