extends Sprite2D
## Stille placeholder (de hoofd-PC naast ECHO). Geen botsing, geen dialoog.

const Kamers := preload("res://world_warper/kamers/kamers.gd")

@export var bron := "pc"


func _ready() -> void:
	var p: Dictionary = Kamers.plaatje(bron)
	var pad := str(p.get("pad", ""))
	if pad != "" and ResourceLoader.exists(pad):
		texture = load(pad)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	hframes = maxi(1, int(p.get("h", 1)))
	vframes = maxi(1, int(p.get("v", 1)))
	offset = p.get("offset", Vector2.ZERO)
