extends Control
## Klein neon-pijltje omlaag ('druk op A om verder te gaan') voor tekstvakken.
## Getekend i.p.v. een '▼'-teken: dat teken zit niet in het pixel-lettertype.

@export var color := Color("f0c674")   # v0.13: UiStyle.HILITE (palet)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var c := Vector2(w / 2.0, 0)
	var tri := PackedVector2Array([Vector2(0.5, 1), Vector2(w - 0.5, 1), Vector2(w / 2.0, w / 2.0 + 1.5)])
	draw_colored_polygon(PackedVector2Array([Vector2(-1, 0), Vector2(w + 1, 0), Vector2(c.x, w / 2.0 + 3)]),
			Color(color.r, color.g, color.b, 0.25))
	draw_colored_polygon(tri, color)
