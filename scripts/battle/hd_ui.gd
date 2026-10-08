class_name HdUi
extends RefCounted
## Hulpjes voor de '16-bit plus' gevechts-UI.
##
## Het gevechtsscherm tekent op een 2x zo fijn raster (768x432), maar alle UI rekent nog
## in de gewone eenheden (384x216, de wortel-node staat op schaal 2). Een venster-
## texture van 12x12 zou daardoor 2x2 'blokpixels' krijgen. De HD-vensters zijn 24x24;
## we laten Godot ze behandelen alsof ze 12x12 zijn (set_size_override). De 9-slice-
## marges blijven dan 4 eenheden, maar elke texture-pixel is precies 1 echte pixel:
## dunne, scherpe randen.
##
## Lukt het niet om het plaatje te lezen (bv. headless zonder GPU), dan krijg je
## gewoon de oude 12x12-texture terug. De lay-out is in beide gevallen hetzelfde.


## Al gemaakte halve textures (v7, prestaties): get_image() leest een texture terug van
## de GPU en dat laat een telefoon even haperen. Daarom doen we het maar één keer per
## plaatje en bewaren we het resultaat voor alle volgende gevechten.
static var _cache := {}


## Texture op halve grootte (1 texture-pixel = 1 echte pixel op het 2x-raster).
## Geeft 'fallback' terug als het niet lukt.
static func half_texture(path: String, fallback: Texture2D = null) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return fallback
	var tex: Texture2D = load(path)
	if tex == null:
		return fallback
	var img := tex.get_image()
	if img == null or img.is_empty():
		return fallback
	var it := ImageTexture.create_from_image(img)
	it.set_size_override(Vector2i(img.get_width() / 2, img.get_height() / 2))
	_cache[path] = it
	return it


## Kopie van een StyleBoxTexture met de HD-versie van zijn texture.
## (De marges in de stylebox blijven gelijk, want ze gelden voor de 'halve' maat.)
static func hd_style(style: StyleBox, hd_path: String) -> StyleBox:
	if not (style is StyleBoxTexture):
		return style
	var sb: StyleBoxTexture = style.duplicate()
	sb.texture = half_texture(hd_path, sb.texture)
	return sb


## Is deze texture de HD-versie? (handig voor de autotest)
static func is_hd(style: StyleBox) -> bool:
	return style is StyleBoxTexture and (style as StyleBoxTexture).texture is ImageTexture
