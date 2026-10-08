extends Control
## v0.14 (RPG CODE, menu L2) Pijltje tussen oude en nieuwe stat in het Uitrusting-scherm
## (zoals Lufia 2: 'ATK 17 > 21'). Getekend met hele pixels (het lettertype heeft geen
## pijl omhoog):
##   dir =  1  groen driehoekje omhoog  (beter)
##   dir = -1  rood driehoekje omlaag   (slechter)
##   dir =  0  klein grijs pijltje naar rechts (gelijk)
## Kleuren uit menu_colors.gd.

const MenuColors := preload("res://scripts/ui/menu_colors.gd")

const SIZE := Vector2(9, 10)

var dir := 0:
	set(v):
		dir = v
		queue_redraw()
## false = niets tekenen (de plek blijft bestaan, zodat een raster niet verschuift)
var shown := true:
	set(v):
		shown = v
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func color() -> Color:
	if dir > 0:
		return MenuColors.BETTER
	if dir < 0:
		return MenuColors.WORSE
	return MenuColors.SAME


func _draw() -> void:
	if not shown:
		return
	var c := color()
	var x0 := 1
	var mid := int(size.y / 2.0)
	if dir > 0:
		# omhoog: rijen van 1, 3, 5, 7 pixels, plus een steeltje
		for i in 4:
			draw_rect(Rect2(x0 + 3 - i, mid - 3 + i, 1 + 2 * i, 1), c)
		draw_rect(Rect2(x0 + 2, mid + 1, 3, 2), c)
	elif dir < 0:
		draw_rect(Rect2(x0 + 2, mid - 3, 3, 2), c)
		for i in 4:
			draw_rect(Rect2(x0 + i, mid - 1 + i, 7 - 2 * i, 1), c)
	else:
		# naar rechts: kolommen van 5, 3, 1 pixels
		for i in 3:
			draw_rect(Rect2(x0 + 2 + i, mid - 2 + i, 1, 5 - 2 * i), c)
