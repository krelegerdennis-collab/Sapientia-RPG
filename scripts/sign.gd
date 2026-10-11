extends StaticBody2D
## Bordje: toont tekst als je ervoor staat en op 'interact' drukt.

@export_multiline var lines: Array[String] = ["Something is written on the sign."]


func interact(_player: Node2D) -> void:
	Dialog.show_lines(lines, "")
