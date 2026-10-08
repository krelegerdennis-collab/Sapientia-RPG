extends StaticBody2D
## Bordje: toont tekst als je ervoor staat en op 'interact' drukt.

@export_multiline var lines: Array[String] = ["Er staat iets op het bordje."]


func interact(_player: Node2D) -> void:
	Dialog.show_lines(lines, "")
