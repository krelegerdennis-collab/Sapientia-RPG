extends Node
## Async smoke voor WarperBakedLabel (SubViewport-bake). Gestart vanuit world_warper/tests/run.gd.

signal klaar(fouten: int)

const Baked := preload("res://world_warper/art/baked_label.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")

var _fouten := 0


func _ready() -> void:
	await _draai()
	klaar.emit(_fouten)
	queue_free()


func _draai() -> void:
	await _check_null_host()
	await _check_bake()


func _check_null_host() -> void:
	var spr: Sprite2D = await Baked.maak_sprite(null, Vector2(10, 10), Vector2.ZERO, func(_l: Label) -> void: pass)
	_meld("baked null host geen sprite", spr == null)


func _check_bake() -> void:
	var host := Node2D.new()
	get_tree().root.add_child(host)
	var setup := func(l: Label) -> void:
		l.text = "Warp"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", FONT)
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", Color("f2e9d8"))
	var spr: Sprite2D = await Baked.maak_sprite(host, Vector2(48, 12), Vector2(-24, -6), setup)
	_meld("baked sprite aangemaakt", spr != null)
	if spr == null:
		host.queue_free()
		return
	_meld("baked centered uit", not spr.centered)
	_meld("baked nearest filter", spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var tex := spr.texture
	_meld("baked texture aanwezig", tex != null)
	if tex != null:
		var img: Image = tex.get_image()
		_meld("baked image gelezen", img != null and not img.is_empty())
		if img != null:
			_meld("baked pixels getekend", _heeft_zichtbare_pixels(img))
	host.queue_free()
	spr.queue_free()


func _meld(naam: String, ok: bool) -> void:
	print(("PASS %s" if ok else "FAIL %s") % naam)
	if not ok:
		_fouten += 1


func _heeft_zichtbare_pixels(img: Image) -> bool:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.01:
				return true
	return false
