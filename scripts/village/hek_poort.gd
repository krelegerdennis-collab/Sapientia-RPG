extends Area2D
## Poort in een SoM-hek (grondteken G). De tegel (hekken.png) geeft de botsing: dicht = vol blok,
## open = geen botsing. Deze Area vangt 'interact' op en wisselt de tegel via de grond (zet_poort).
## De Area zelf blokkeert niemand en blijft ook open bereikbaar (om weer te sluiten).

const Data := preload("res://scripts/data/wilgendal_dorp.gd")

var tegel := Vector2i.ZERO
var grond: Node


func _ready() -> void:
	var vorm := RectangleShape2D.new()
	vorm.size = Vector2(14, 14)
	var bots := CollisionShape2D.new()
	bots.shape = vorm
	add_child(bots)


func is_open() -> bool:
	return Data.poort_open(tegel)


func interact(_player: Node2D) -> void:
	zet(not is_open())


func zet(open: bool) -> void:
	if grond != null and grond.has_method("zet_poort"):
		grond.zet_poort(tegel, open)
