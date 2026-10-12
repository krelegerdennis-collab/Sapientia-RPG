extends StaticBody2D
class_name Toonbank
## Toonbank. De winkelier staat erachter; aanspreken opent dezelfde winkel.

signal aangesproken(speler: Node2D)


func interact(speler: Node2D) -> void:
	aangesproken.emit(speler)
