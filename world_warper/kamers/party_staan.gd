extends Node2D
## De rest van de party staat in De Hal. De leider is de speler zelf.

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")
const TILE := 16


func _ready() -> void:
	var n := 0
	for h in GameState.party:
		if n == 0:
			n += 1
			continue
		if not (h is Dictionary):
			n += 1
			continue
		var held := h as Dictionary
		var spr := Sprite2D.new()
		spr.name = "Lid%s" % str(held.get("id", n))
		var pad := str(held.get("field_sprite", ""))
		var sheet := false
		if pad != "" and ResourceLoader.exists(pad):
			spr.texture = load(pad)
			sheet = true
		else:
			var ph: Dictionary = Kamers.plaatje("party")
			spr.texture = load(str(ph["pad"]))
			sheet = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		if sheet:
			spr.hframes = 3
			spr.vframes = 4
			spr.frame = 0
			spr.offset = Vector2(0, -10)
		spr.position = Vector2(2 + (n - 1), 6) * float(TILE) + Vector2(8, 8)
		add_child(spr)
		var lab := Label.new()
		lab.text = str(held.get("name", ""))
		lab.position = Vector2(-20, -36)
		lab.size = Vector2(56, 12)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_font_override("font", FONT)
		lab.add_theme_font_size_override("font_size", 8)
		lab.add_theme_color_override("font_color", Color("f2e9d8"))
		spr.add_child(lab)
		n += 1
