class_name PortraitBaker
extends RefCounted
## Portretbakker voor het online co-op karakter: look -> 32x32 borstbeeld.
##
## Stapelt de portretlagen van RPG ART (assets/ui/portret/) in de laagvolgorde van de
## paper-doll baker en herkleurt ze met dezelfde 5-tonen-tabellen (recolor_v2.json).
## Daarna dezelfde buitenrand-pass. Lagen zonder portretbestand (schaduw, onder, wapen)
## blijven leeg, zoals recolor_v2.json bij "portret_32x32" voorschrijft.
## Deterministisch: zelfde look = zelfde pixels. Cache per look; vrijgeven via
## release_cache(), dat PaperDollBaker.release_warm_cache() ook aanroept.
##
## Later gebruik (partybalk, revive-ring, resultatenscherm) is één regel:
##   rect.texture = PortraitBaker.texture_or(look, vast_portret)

const PORTRAIT_DIR := "res://assets/ui/portret/"
const SIZE := 32
## Bron van de bestandsnamen: de portretlaag heet hetzelfde als de kaart-laag.
const NAME_SHEET := "walk"

static var _textures: Dictionary = {}
static var _images: Dictionary = {}
static var _base: Dictionary = {}
static var _painted: Dictionary = {}
static var bakes: int = 0
static var cache_hits: int = 0
static var failures: int = 0
static var last_bake_us: int = 0


## Look uit een dictionary (profiel), een AvatarBlob van 16 bytes (seat-data) of de
## look-bytes van het profiel. Leeg als de look onbekend of kapot is.
static func look_from(raw: Variant) -> Dictionary:
	var src: Dictionary = {}
	if raw is Dictionary:
		src = raw
	elif raw is PackedByteArray:
		var bytes: PackedByteArray = raw
		src = AvatarBlob.decode(bytes)
		if not bool(src.get("ok", false)):
			src = OnlineProfile.decode_look(bytes)
	else:
		return {}
	var out := {}
	for key in OnlineProfile.LOOK_KEYS:
		var v: Variant = src.get(key, null)
		# JSON levert floats; alleen hele getallen tellen.
		if v is float and float(v) == floorf(float(v)):
			v = int(v)
		if not (v is int):
			return {}
		var n: int = v
		if n < 0 or n > int(OnlineProfile.LOOK_MAX[key]):
			return {}
		out[key] = n
	return out


## Cache-sleutel: alle look-velden, met de look-versie ervoor.
static func look_key(look: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in OnlineProfile.LOOK_KEYS:
		parts.append(str(int(look.get(key, 0))))
	return "v%d:%s" % [OnlineProfile.LOOK_VERSION, ",".join(parts)]


## Gebakken portret, of null bij een onbekende/kapotte look of ontbrekende lagen.
static func bake(raw: Variant) -> ImageTexture:
	var look := look_from(raw)
	if look.is_empty():
		failures += 1
		return null
	var key := look_key(look)
	var hit: Variant = _textures.get(key)
	if hit is ImageTexture:
		cache_hits += 1
		return hit
	var t0 := Time.get_ticks_usec()
	var image := _compose(look)
	if image == null:
		failures += 1
		return null
	var texture := ImageTexture.create_from_image(image)
	_images[key] = image
	_textures[key] = texture
	bakes += 1
	last_bake_us = int(Time.get_ticks_usec() - t0)
	return texture


## Eén regel voor elk scherm: gebakken portret, anders het vaste portret.
static func texture_or(raw: Variant, fallback: Texture2D) -> Texture2D:
	var baked := bake(raw)
	if baked != null:
		return baked
	return fallback


## Losse image (zonder cache), voor tests en hashes. Null bij een fout.
static func image_for(raw: Variant) -> Image:
	var look := look_from(raw)
	if look.is_empty():
		return null
	return _compose(look)


static func image_hash(image: Image) -> String:
	if image == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(image.get_data())
	return ctx.finish().hex_encode()


static func cache_size() -> int:
	return _textures.size()


static func warm_size() -> int:
	return _base.size() + _painted.size()


static func release_cache() -> void:
	_textures.clear()
	_images.clear()
	_base.clear()
	_painted.clear()


static func reset_stats() -> void:
	bakes = 0
	cache_hits = 0
	failures = 0
	last_bake_us = 0


## Portretbestand per laag voor deze look ("" = laag blijft leeg).
static func layer_path(look: Dictionary, layer: String) -> String:
	var src := PaperDollBaker.layer_source(look, layer, NAME_SHEET)
	if src == "":
		return ""
	var path := PORTRAIT_DIR + src.get_file()
	if not ResourceLoader.exists(path):
		return ""
	return path


static func _compose(look: Dictionary) -> Image:
	var figure := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var drawn := 0
	for layer in PaperDollBaker.layer_order():
		var path := layer_path(look, layer)
		if path == "":
			continue
		var painted := _painted_layer(path, PaperDollBaker.layer_group(layer), PaperDollBaker.layer_color(look, layer))
		if painted == null:
			return null
		figure.blend_rect(painted, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
		drawn += 1
	if drawn == 0:
		return null
	var edged := PaperDollBaker.outline_bytes(figure.get_data(), SIZE, SIZE)
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, edged)


static func _painted_layer(path: String, group: String, color_name: String) -> Image:
	var key := "%s@%s:%s" % [path, group, color_name]
	var hit: Variant = _painted.get(key)
	if hit is Image:
		return hit
	var base := _base_bytes(path)
	if base.is_empty():
		return null
	var bytes := base
	if group != "":
		bytes = PaperDollBaker.recolor_layer_bytes(base, group, color_name)
		if bytes.is_empty():
			return null
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, bytes)
	_painted[key] = image
	return image


## RGBA-bytes van een portretlaag. Via de geïmporteerde texture, dus ook in de APK.
static func _base_bytes(path: String) -> PackedByteArray:
	var hit: Variant = _base.get(path)
	if hit is PackedByteArray:
		return hit
	var tex := load(path) as Texture2D
	if tex == null:
		return PackedByteArray()
	var image := tex.get_image()
	if image == null or image.get_width() != SIZE or image.get_height() != SIZE:
		return PackedByteArray()
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	_base[path] = data
	return data
