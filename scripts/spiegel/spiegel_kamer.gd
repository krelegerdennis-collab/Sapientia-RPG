extends Node2D
## Kamer van De Spiegel (Archief 4). De spiegel breekt door de weigering.
## Deze scène zet geen story_step en geen story_flags, en staat niet op de wereldkaart.

const Data := preload("res://scripts/data/spiegel_data.gd")
const KAPOT := preload("res://assets/bg/spiegel_kamer_gebroken.png")
const STILTE_SEC := 0.35

@onready var achtergrond: Sprite2D = $Achtergrond

var gebroken := false
var kern_opgenomen := false
var klaar := false
var breek_zin := ""
const MUSIC_TRACK := "levend_archief"

var gespeeld: Array[String] = []
var getoond: Array[String] = []


func _ready() -> void:
	achtergrond.centered = false
	achtergrond.position = Vector2.ZERO
	achtergrond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Geen map.gd hier, dus zelf de BGM starten (zonder track zou de kamer stil blijven).
	AudioManager.play_music(MUSIC_TRACK)
	_volgende()


func _volgende() -> void:
	if not is_inside_tree():
		return
	var i := gespeeld.size()
	if i >= Data.BEATS.size():
		klaar = true
		return
	var beat: Dictionary = Data.BEATS[i]
	var id := str(beat.get("id", ""))
	if bool(beat.get("stilte", false)):
		await get_tree().create_timer(STILTE_SEC).timeout
		if not is_inside_tree():
			return
		gespeeld.append(id)
		_volgende()
		return
	var regels: Array = beat.get("tekst", [])
	var wie := str(beat.get("wie", ""))
	if not regels.is_empty():
		Dialog.show_lines(regels, wie)
		await Dialog.finished
		if not is_inside_tree():
			return
		for regel in regels:
			getoond.append(str(regel))
	gespeeld.append(id)
	if Data.breek_door(id):
		breek_zin = str(regels[0]) if not regels.is_empty() else ""
		_breek()
	if bool(beat.get("kern", false)):
		kern_opgenomen = true
	_volgende()


func _breek() -> void:
	gebroken = true
	if is_instance_valid(achtergrond):
		achtergrond.texture = KAPOT
		achtergrond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
