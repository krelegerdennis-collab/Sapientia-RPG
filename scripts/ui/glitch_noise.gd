class_name GlitchNoise
extends Control
## Pixel-ruis / glitch-textuur in een tekstvak (zoals de mockup): grijze pixelblokjes,
## dicht langs de randen en in een paar 'storings'-vlekken, rustig in het midden zodat de
## tekst leesbaar blijft. Wordt één keer als plaatje gemaakt (1 pixel = 1 echte pixel,
## ook op het 2x-raster van het gevecht) en ververst af en toe heel even (flikkering).
## Gebruik: zet hem als eerste kind in een Panel; hij vult het venster (binnen de rand).

## (preload i.p.v. class_name: dit script wordt al door een autoload geladen)
const UiStyleC := preload("res://scripts/ui/ui_style.gd")

@export var inset := 4.0             # afstand tot de rand van het venster (eenheden)
@export var density := 1.0           # 0 = geen ruis, 1 = normaal
@export var flicker := true          # af en toe heel even een andere ruis
## v0.16 (Crt-overlay in de Archieven): ruis op een lagere resolutie (0.5 = blokjes van 2x2,
## 4x minder rekenwerk) en hoe vaak hij flikkert (sec, min..max; Crt maakt dit korter bij de baas).
@export var resolution_scale := 1.0
@export var flicker_gap := Vector2(3.0, 8.0)

var _tex: Array = [null, null]       # twee varianten: normaal en 'flikker'
## Gedeeld door alle tekstvakken en alle gevechten (prestaties): het plaatje van een
## bepaalde grootte wordt maar één keer per speelsessie uitgerekend.
static var _cache := {}
var _built_for := Vector2i.ZERO
var _variant := 0
var _t := 0.0
var _next_flicker := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = inset
	offset_top = inset
	offset_right = -inset
	offset_bottom = -inset
	resized.connect(queue_redraw)
	_next_flicker = randf_range(3.0, 7.0)


func _process(delta: float) -> void:
	if not flicker or not is_visible_in_tree():
		return
	_t += delta
	if _t >= _next_flicker:
		# kort (een paar beeldjes) de andere ruis, dan terug. Beide plaatjes zijn al
		# gemaakt, dus dit kost niets.
		_variant = 1 - _variant
		queue_redraw()
		if _variant == 1:
			_next_flicker = _t + 0.08
		else:
			_next_flicker = _t + randf_range(flicker_gap.x, flicker_gap.y)


## Hoeveel echte pixels per eenheid (2 in het gevecht, 1 in de overworld).
func _pixel_scale() -> int:
	var s := get_global_transform_with_canvas().get_scale().x
	return maxi(1, roundi(s))


## Beide ruis-plaatjes voor een grootte in echte pixels (uit de cache als dat kan).
## Dialog roept dit al bij de start aan, zodat het eerste gesprek niet hapert.
func textures_for(px: Vector2i, dens: float) -> Array:
	var key := "%dx%d@%.2f" % [px.x, px.y, dens]
	if not _cache.has(key):
		_cache[key] = [_build(px, 0), _build(px, 1)]
	return _cache[key]


func _build(px: Vector2i, variant: int) -> ImageTexture:
	var img := Image.create(maxi(px.x, 1), maxi(px.y, 1), false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + variant * 31
	var w := px.x
	var h := px.y
	var cols: Array = preload("res://scripts/ui/ui_style.gd").NOISE   # v0.13: palet (ui_style.gd)
	# een paar 'storingsvlekken' (meer ruis)
	var blobs := []
	for i in 4:
		blobs.append(Vector3(rng.randf_range(0.0, w), rng.randf_range(0.0, h), rng.randf_range(0.12, 0.3) * w))
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var ex := minf(x, w - 1 - x) / maxf(1.0, h * 0.55)
			var ey := minf(y, h - 1 - y) / maxf(1.0, h * 0.5)
			var edge := clampf(1.0 - minf(ex, ey), 0.0, 1.0)
			var p := 0.006 + 0.55 * pow(edge, 3.0)
			for b in blobs:
				var d: float = Vector2(x - b.x, (y - b.y) * 2.2).length() / b.z
				if d < 1.0:
					p += 0.16 * (1.0 - d) * (1.0 - d)
			# rechts iets drukker (zoals de mockup)
			p += 0.08 * clampf((float(x) / w - 0.7) * 3.0, 0.0, 1.0)
			p *= density
			var run := 1 + int(rng.randf() * rng.randf() * 4.0)     # korte horizontale streepjes
			if rng.randf() < p:
				var c: Color = cols[mini(int(rng.randf() * rng.randf() * cols.size() * 1.6), cols.size() - 1)]
				if rng.randf() < 0.004:
					c = UiStyleC.MAGENTA if rng.randf() < 0.6 else UiStyleC.CYAN
				for k in run:
					if x + k < w:
						img.set_pixel(x + k, y, c)
			x += run
		y += 1
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	if density <= 0.0 or size.x < 2 or size.y < 2:
		return
	var s := _pixel_scale() * resolution_scale
	var px := Vector2i(maxi(1, int(size.x * s)), maxi(1, int(size.y * s)))
	if px != _built_for or _tex[0] == null:
		_tex = textures_for(px, density)
		_built_for = px
	draw_texture_rect(_tex[_variant], Rect2(Vector2.ZERO, size), false)
