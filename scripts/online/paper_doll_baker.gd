class_name PaperDollBaker
extends RefCounted
## CPU-bakker voor de co-op paper doll (M2).
##
## Eén ImageTexture per sheet, nearest, cache op de look-hash.
## Recolorkleuren komen uit assets/sprites/paperdoll/recolor_v2.json (RPG ART):
## per laag worden de 5 sleuteltonen vervangen, de lagen gestapeld, daarna
## wordt de donkere buitencontour #3a4058, en de schaduw gaat eronder.
## De baker spiegelt nooit: de rechts-rij komt uit de sheet zelf.

const RECOLOR_PATH := "res://assets/sprites/paperdoll/recolor_v2.json"
const PALETTE_PATH := "res://docs/art/masterpalet.gpl"
const LAYERS_PATH := "res://data/online/paper_doll_layers.json"

## Onder naar boven. De schaduw gaat als laatste eronder (na de contour).
const ORDER: PackedStringArray = [
	"schaduw", "lichaam", "onder", "boven", "cape",
	"haar_achter", "gezicht", "haar_voor", "hoofd", "wapen",
]

const ART_SHEETS: PackedStringArray = ["walk", "ko"]

const SHEETS: Dictionary = {
	"walk": {"w": 120, "h": 128, "cw": 24, "ch": 32, "cols": 5, "rows": 4},
	"attack": {"w": 288, "h": 192, "cw": 48, "ch": 48, "cols": 6, "rows": 4},
	"hurt": {"w": 192, "h": 48, "cw": 48, "ch": 48, "cols": 4, "rows": 1},
	"dodge": {"w": 192, "h": 48, "cw": 48, "ch": 48, "cols": 4, "rows": 1},
	"ko": {"w": 48, "h": 48, "cw": 48, "ch": 48, "cols": 1, "rows": 1},
}

const ANCHOR := Vector2i(12, 16)
const OUTLINE_MAX_SUM := 156
const TONE_COUNT := 5
const SHEET_LIST: PackedStringArray = ["walk", "attack", "hurt", "dodge", "ko"]

const SKIN_ORDER: PackedStringArray = ["licht", "midden", "getint", "donker"]
const HAIR_ORDER: PackedStringArray = [
	"zwart", "bruin", "blond", "rood", "zilver", "blauw", "paars", "groen",
]
const CLOTH_ORDER: PackedStringArray = ["nacht", "rood", "mos", "leer", "papier", "paars"]
const HEAD_ORDER: PackedStringArray = ["nacht", "rood", "mos", "leer"]

const CLASS_WEAPON: Dictionary = {
	"warrior": "zwaard", "mage": "staf", "priest": "scepter",
	"psytech": "psy", "archer": "boog",
}

const CLASS_OF: Dictionary = {
	"warrior": "warrior", "mage": "mage", "priest": "priest",
	"psytech": "psytech", "archer": "archer",
	"dennis": "warrior", "noor": "mage", "lotte": "priest",
	"kael": "psytech", "orion": "archer",
}

static var _ready := false
static var _doc: Dictionary = {}
static var _layers: Dictionary = {}
static var _key_huid := PackedColorArray()
static var _key_cloth := PackedColorArray()
static var _ramps: Dictionary = {}
static var _fixed: Dictionary = {}
static var _outline := Color8(58, 64, 88)
static var _colors: Dictionary = {}
static var _recolored: Dictionary = {}
static var _opaque_pixels: Dictionary = {}
static var _layer_rgba_cache: Dictionary = {}
static var _layer_bytes_cache: Dictionary = {}
static var _layer_size_cache: Dictionary = {}
static var _images: Dictionary = {}
static var _layer_mutex: Mutex = Mutex.new()
static var _textures: Dictionary = {}
static var _avatars: Dictionary = {}
static var bakes: int = 0
static var cache_hits: int = 0
static var last_bake_us: int = 0


static func clear_cache() -> void:
	_recolored.clear()
	_images.clear()
	# _layer_rgba_cache / _opaque_pixels blijven voor bake-prestatie
	_textures.clear()
	_avatars.clear()


static func reset_stats() -> void:
	bakes = 0
	cache_hits = 0
	last_bake_us = 0


static func layer_order() -> PackedStringArray:
	return ORDER.duplicate()


static func sheet_size(sheet: String) -> Vector2i:
	var spec: Dictionary = SHEETS.get(sheet, {})
	if spec.is_empty():
		return Vector2i.ZERO
	return Vector2i(int(spec["w"]), int(spec["h"]))


static func anchor() -> Vector2i:
	return ANCHOR


static func option_count(layer: String) -> int:
	_ensure()
	var spec: Dictionary = _layers.get(layer, {})
	var options: Dictionary = spec.get("options", {})
	return options.size()


static func option_names(layer: String) -> PackedStringArray:
	_ensure()
	var spec: Dictionary = _layers.get(layer, {})
	var raw: Variant = spec.get("names", [])
	var out := PackedStringArray()
	if raw is Array:
		for name in raw:
			out.append(str(name))
	return out


static func color_names(group: String) -> PackedStringArray:
	if group == "huid":
		return SKIN_ORDER.duplicate()
	if group == "haar":
		return HAIR_ORDER.duplicate()
	if group == "kleding":
		return CLOTH_ORDER.duplicate()
	if group == "hoofddeksel":
		return HEAD_ORDER.duplicate()
	return PackedStringArray()


static func key_colors(which: String) -> PackedColorArray:
	_ensure()
	if which == "huid":
		return _key_huid.duplicate()
	return _key_cloth.duplicate()


static func ramp_colors(group: String, index: int) -> PackedColorArray:
	_ensure()
	var list: Array = _ramps.get(group, [])
	if list.is_empty():
		return PackedColorArray()
	var i := index
	if i < 0:
		i = 0
	if i >= list.size():
		i = list.size() - 1
	var src: PackedColorArray = list[i]
	return src.duplicate()


static func fixed_color(name: String, index: int = 0) -> Color:
	_ensure()
	var raw: Variant = _fixed.get(name, "")
	if raw is String:
		return _parse_hex(str(raw))
	if raw is Array:
		var arr: Array = raw
		if index < 0 or index >= arr.size():
			return Color(0, 0, 0, 0)
		return _parse_hex(str(arr[index]))
	return Color(0, 0, 0, 0)


static func outline_color() -> Color:
	_ensure()
	return _outline


static func palette_has(color: Color) -> bool:
	_ensure()
	if color.a8 == 0:
		return true
	return _colors.has(_pack(color))


static func class_id(raw: Variant) -> String:
	var key := str(raw).strip_edges().to_lower()
	return str(CLASS_OF.get(key, ""))


static func look_key(look: Dictionary) -> String:
	_ensure()
	var parts: PackedStringArray = PackedStringArray()
	for layer in ORDER:
		var spec: Dictionary = _layers.get(layer, {})
		if spec.is_empty():
			continue
		var id := _resolve_id(look, spec)
		var color := ""
		var group := str(spec.get("recolor", ""))
		if group != "" and id != "":
			color = _color_name(look, str(spec.get("color_key", "")), group)
		parts.append("%s=%s:%s" % [layer, id, color])
	return "|".join(parts)


static func image_for(look: Dictionary, sheet: String) -> Image:
	var key := "%s#%s" % [look_key(look), sheet]
	_layer_mutex.lock()
	var hit: Variant = _images.get(key)
	_layer_mutex.unlock()
	if hit is Image:
		return hit
	var image := _compose(look, sheet)
	_layer_mutex.lock()
	if not _images.has(key):
		_images[key] = image
	else:
		image = _images[key]
	_layer_mutex.unlock()
	return image


static func image_hash(image: Image) -> String:
	if image == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(image.get_data())
	return ctx.finish().hex_encode()


static func palette_count() -> int:
	_ensure()
	return _colors.size()


## Lege sheet bakt alle vijf sheets en geeft één texture per sheet terug.
## Tweede keer met dezelfde look is dezelfde texture, zonder opnieuw te bakken.
static func bake(look: Dictionary, sheet: String = "") -> Variant:
	if sheet == "":
		return _bake_avatar(look)
	return _bake_sheet(look, sheet, true)


static func _bake_avatar(look: Dictionary) -> Dictionary:
	_ensure()
	var key := look_key(look)
	if _avatars.has(key):
		cache_hits += 1
		return _avatars[key]
	var t0 := Time.get_ticks_usec()
	var out := {}
	var tasks: Array = []
	for sid in SHEET_LIST:
		var cap_sid := sid
		tasks.append(WorkerThreadPool.add_task(
			func() -> void:
				var tex := _bake_sheet(look, cap_sid, false)
				_layer_mutex.lock()
				out[cap_sid] = tex
				_layer_mutex.unlock()
		))
	for task_id in tasks:
		WorkerThreadPool.wait_for_task_completion(int(task_id))
	_avatars[key] = out
	bakes += 1
	last_bake_us = int(Time.get_ticks_usec() - t0)
	return out


static func _bake_sheet(look: Dictionary, sheet: String, count: bool) -> ImageTexture:
	var key := "%s#%s" % [look_key(look), sheet]
	_layer_mutex.lock()
	var hit: Variant = _textures.get(key)
	_layer_mutex.unlock()
	if hit is ImageTexture:
		if count:
			cache_hits += 1
		return hit
	var t0 := Time.get_ticks_usec()
	var image := image_for(look, sheet)
	var texture := ImageTexture.create_from_image(image)
	apply_nearest(texture)
	_layer_mutex.lock()
	if not _textures.has(key):
		_textures[key] = texture
	else:
		texture = _textures[key]
	_layer_mutex.unlock()
	if count:
		bakes += 1
		last_bake_us = int(Time.get_ticks_usec() - t0)
	return texture


static func apply_nearest(target: Object) -> void:
	if target == null:
		return
	if target is CanvasItem:
		(target as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	elif target is Texture2D:
		(target as Texture2D).set_meta("_paper_doll_filter", CanvasItem.TEXTURE_FILTER_NEAREST)


## Vervangt de 5 sleuteltonen in een losse laag. Extra kleuren blijven staan.
static func recolor_image(src: Image, keys: PackedColorArray, ramp: PackedColorArray) -> Image:
	if src == null:
		return null
	return _recolor_bytes(src, keys, ramp)


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_ready = false
	_ensure()
	if _doc.is_empty():
		errors.append("recolor ontbreekt")
		return errors
	if _key_huid.size() != TONE_COUNT or _key_cloth.size() != TONE_COUNT:
		errors.append("sleutelramp is geen 5 tonen")
	if _outline != Color8(58, 64, 88):
		errors.append("buitenrand is niet #3a4058")
	var groups: PackedStringArray = PackedStringArray(["huid", "haar", "kleding", "hoofddeksel"])
	var expected: PackedInt32Array = PackedInt32Array([4, 8, 6, 4])
	for i in groups.size():
		var list: Array = _ramps.get(groups[i], [])
		if list.size() != expected[i]:
			errors.append("%s telt %d, verwacht %d" % [groups[i], list.size(), expected[i]])
		for ramp_v in list:
			var ramp: PackedColorArray = ramp_v
			if ramp.size() != TONE_COUNT:
				errors.append("%s ramp heeft %d tonen" % [groups[i], ramp.size()])
			for color in ramp:
				if not _colors.has(_pack(color)):
					errors.append("%s buiten masterpalet" % groups[i])
	for layer in ORDER:
		if not _layers.has(layer):
			errors.append("laag %s ontbreekt in het manifest" % layer)
	for layer in ORDER:
		var spec: Dictionary = _layers.get(layer, {})
		var options: Dictionary = spec.get("options", {})
		for id in options.keys():
			for sheet in ART_SHEETS:
				var rel := _option_path(options[id], sheet)
				if rel == "" or not FileAccess.file_exists(rel):
					errors.append("mist %s/%s/%s" % [layer, str(id), sheet])
	_warm_opaque_caches()
	return errors


static func _warm_opaque_caches() -> void:
	for layer in ORDER:
		var spec: Dictionary = _layers.get(layer, {})
		if spec.is_empty():
			continue
		var options: Dictionary = spec.get("options", {})
		var do_recolor := str(spec.get("recolor", "")) != ""
		for id in options:
			for sid in SHEET_LIST:
				var rel := _option_path(options[id], sid)
				if rel == "" or not FileAccess.file_exists(rel):
					continue
				var cached: Variant = _layer_rgba_cache.get(rel)
				if not (cached is Image):
					_layer_rgba(rel)
					cached = _layer_rgba_cache.get(rel)
				if not _layer_bytes_cache.has(rel) and cached is Image:
					_layer_bytes_cache[rel] = (cached as Image).get_data()
					_layer_size_cache[rel] = Vector2i((cached as Image).get_width(), (cached as Image).get_height())
				if do_recolor and _layer_bytes_cache.has(rel) and not _opaque_pixels.has(rel):
					_opaque_list_for(rel, _layer_bytes_cache[rel])


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	_load_palette()
	_load_recolor()
	_load_layers()


static func _load_palette() -> void:
	_colors.clear()
	var file := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	if file == null:
		return
	for line in file.get_as_text().split("\n"):
		var parts := line.strip_edges().split(" ", false)
		if parts.size() < 3:
			continue
		if not parts[0].is_valid_int():
			continue
		_colors[_pack(Color8(int(parts[0]), int(parts[1]), int(parts[2])))] = true


static func _load_recolor() -> void:
	_doc = {}
	_ramps.clear()
	_fixed.clear()
	_key_huid = PackedColorArray()
	_key_cloth = PackedColorArray()
	var file := FileAccess.open(RECOLOR_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	_doc = parsed
	_key_huid = _parse_ramp(_doc.get("key_ramp_huid", []))
	var cloth_keys: Variant = _doc.get("key_ramp_kleding_haar_hoofd_cape", _doc.get("key_ramp_kleding_haar", []))
	_key_cloth = _parse_ramp(cloth_keys)
	_ramps["huid"] = _named_ramps(_doc.get("huid", {}), SKIN_ORDER)
	_ramps["haar"] = _named_ramps(_doc.get("haar", {}), HAIR_ORDER)
	_ramps["kleding"] = _named_ramps(_doc.get("kleding", {}), CLOTH_ORDER)
	_ramps["hoofddeksel"] = _named_ramps(_doc.get("hoofddeksel", {}), HEAD_ORDER)
	var fixed: Variant = _doc.get("vaste_kleuren_niet_kleuren", {})
	if fixed is Dictionary:
		_fixed = fixed
	var edge: Variant = _doc.get("buitenrand_na_bakken", {})
	if edge is Dictionary:
		_outline = _parse_hex(str(edge.get("kleur", "#3a4058")))


static func _named_ramps(src: Variant, order: PackedStringArray) -> Array:
	var out: Array = []
	if not (src is Dictionary):
		return out
	var table: Dictionary = src
	for name in order:
		out.append(_parse_ramp(table.get(name, [])))
	return out


static func _parse_ramp(raw: Variant) -> PackedColorArray:
	var ramp := PackedColorArray()
	if raw is Array:
		for hex in raw:
			ramp.append(_parse_hex(str(hex)))
	return ramp


static func _parse_hex(text: String) -> Color:
	var h := text.strip_edges().trim_prefix("#")
	if h.length() != 6:
		return Color(0, 0, 0, 0)
	return Color8(h.substr(0, 2).hex_to_int(), h.substr(2, 2).hex_to_int(), h.substr(4, 2).hex_to_int())


static func _load_layers() -> void:
	_layers = {}
	var file := FileAccess.open(LAYERS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("layers", {}) is Dictionary:
		_layers = parsed["layers"]


static func _compose(look: Dictionary, sheet: String) -> Image:
	_ensure()
	var size := sheet_size(sheet)
	var blank := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	blank.fill(Color(0, 0, 0, 0))
	if size == Vector2i.ZERO:
		return blank
	var prepared := _prepare_layers_parallel(look, sheet, size)
	var figure := blank.duplicate()
	var shadow: Image = null
	for layer in ORDER:
		var painted: Variant = prepared.get(layer)
		if not (painted is Image):
			continue
		var spec: Dictionary = _layers.get(layer, {})
		if bool(spec.get("under", false)):
			shadow = painted
		else:
			figure.blend_rect(painted, Rect2i(0, 0, size.x, size.y), Vector2i.ZERO)
	var outlined := _outline_pass(figure)
	var dest := blank.duplicate()
	if shadow != null:
		dest.blend_rect(shadow, Rect2i(0, 0, size.x, size.y), Vector2i.ZERO)
	dest.blend_rect(outlined, Rect2i(0, 0, size.x, size.y), Vector2i.ZERO)
	return dest


static func _prepare_layers_parallel(look: Dictionary, sheet: String, size: Vector2i) -> Dictionary:
	var out := {}
	var big := size.x * size.y >= 20000
	if not big:
		for layer in ORDER:
			var spec: Dictionary = _layers.get(layer, {})
			if spec.is_empty():
				continue
			out[layer] = _prepare_layer(look, spec, sheet, size)
		return out
	var tasks: Array = []
	for layer in ORDER:
		var spec: Dictionary = _layers.get(layer, {})
		if spec.is_empty():
			continue
		var cap_layer := layer
		var cap_spec := spec
		tasks.append(WorkerThreadPool.add_task(
			func() -> void:
				var painted := _prepare_layer(look, cap_spec, sheet, size)
				_layer_mutex.lock()
				out[cap_layer] = painted
				_layer_mutex.unlock()
		))
	for task_id in tasks:
		WorkerThreadPool.wait_for_task_completion(int(task_id))
	return out


static func _prepare_layer(look: Dictionary, spec: Dictionary, sheet: String, size: Vector2i) -> Image:
	var id := _resolve_id(look, spec)
	if id == "":
		return null
	var options: Dictionary = spec.get("options", {})
	if not options.has(id):
		return null
	var path := _option_path(options[id], sheet)
	if not FileAccess.file_exists(path):
		return null
	var group := str(spec.get("recolor", ""))
	var key_name := str(spec.get("key_ramp", ""))
	var cache_key := path
	var ramp := PackedColorArray()
	var keys := PackedColorArray()
	if group != "":
		var color_name := _color_name(look, str(spec.get("color_key", "")), group)
		var names := color_names(group)
		var index := names.find(color_name)
		ramp = ramp_colors(group, index)
		keys = key_colors(key_name if key_name != "" else "kleding")
		cache_key = "%s@%s:%s" % [path, group, color_name]
	_layer_mutex.lock()
	var cached: Variant = _recolored.get(cache_key)
	_layer_mutex.unlock()
	if cached is Image:
		return cached
	var painted := _load_layer(path, group != "", keys, ramp)
	if painted == null or painted.get_width() != size.x or painted.get_height() != size.y:
		return null
	_layer_mutex.lock()
	if not _recolored.has(cache_key):
		_recolored[cache_key] = painted
	else:
		painted = _recolored[cache_key]
	_layer_mutex.unlock()
	return painted


static func _option_path(raw: Variant, sheet: String) -> String:
	if raw is String:
		return str(raw).replace("{sheet}", sheet)
	if raw is Dictionary:
		return str((raw as Dictionary).get(sheet, ""))
	return ""


static func _load_layer(path: String, do_recolor: bool, keys: PackedColorArray, ramp: PackedColorArray) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	if do_recolor and bytes.size() >= 26 and bytes[25] == 3:
		return _load_patched(bytes, ramp)
	if do_recolor:
		var data := _layer_bytes(path)
		if data.is_empty():
			return null
		var size_v: Variant = _layer_size_cache.get(path)
		var size: Vector2i = size_v if size_v is Vector2i else Vector2i.ZERO
		var touch := _opaque_list_for(path, _layer_bytes_cache.get(path, data))
		return _recolor_data(size.x, size.y, data, touch, keys, ramp)
	var image := _layer_rgba(path)
	return image


static func _layer_rgba(path: String) -> Image:
	var cached: Variant = _layer_rgba_cache.get(path)
	if cached is Image:
		return (cached as Image).duplicate()
	var image := _load_png(path)
	if image != null:
		_layer_rgba_cache[path] = image
		_layer_bytes_cache[path] = image.get_data()
		_layer_size_cache[path] = Vector2i(image.get_width(), image.get_height())
		return image.duplicate()
	return null


static func _layer_bytes(path: String) -> PackedByteArray:
	var hit: Variant = _layer_bytes_cache.get(path)
	if hit is PackedByteArray:
		return (hit as PackedByteArray).duplicate()
	var image := _layer_rgba(path)
	if image == null:
		return PackedByteArray()
	return image.get_data()


## Vervangt PLTE-index 1..5 en laat Godot decoderen. Zelfde ramp → dezelfde bytes.
static func _load_patched(png: PackedByteArray, ramp: PackedColorArray) -> Image:
	var patched := png.duplicate()
	var i := 8
	while i + 12 <= patched.size():
		var length := (int(patched[i]) << 24) | (int(patched[i + 1]) << 16) | (int(patched[i + 2]) << 8) | int(patched[i + 3])
		if length < 0 or i + 12 + length > patched.size():
			break
		var is_plte := patched[i + 4] == 80 and patched[i + 5] == 76 and patched[i + 6] == 84 and patched[i + 7] == 69
		if is_plte:
			var slots := mini(ramp.size(), int(length / 3) - 1)
			for t in slots:
				var o := i + 8 + (t + 1) * 3
				var dest: Color = ramp[t]
				patched[o] = dest.r8
				patched[o + 1] = dest.g8
				patched[o + 2] = dest.b8
			var crc := _crc32(patched.slice(i + 4, i + 8 + length))
			var c := i + 8 + length
			patched[c] = (crc >> 24) & 255
			patched[c + 1] = (crc >> 16) & 255
			patched[c + 2] = (crc >> 8) & 255
			patched[c + 3] = crc & 255
			break
		i += 12 + length
	var image := Image.new()
	if image.load_png_from_buffer(patched) != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


static func _resolve_id(look: Dictionary, spec: Dictionary) -> String:
	var fixed := str(spec.get("fixed_id", ""))
	if fixed != "":
		return fixed
	var names := PackedStringArray()
	var raw_names: Variant = spec.get("names", [])
	if raw_names is Array:
		for name in raw_names:
			names.append(str(name))
	var key := str(spec.get("id_key", ""))
	var optional := bool(spec.get("optional", false))
	if bool(spec.get("class_map", false)):
		var mapped := class_id(look.get(key, ""))
		var weapon := str(CLASS_WEAPON.get(mapped, ""))
		if names.find(weapon) >= 0:
			return weapon
		return ""
	if key == "cape":
		if not look.has("cape"):
			return ""
		var cape_val: Variant = look["cape"]
		if cape_val == null:
			return ""
		if cape_val is String:
			var cape_text := str(cape_val).strip_edges().to_lower()
			if cape_text == "" or cape_text == "none" or cape_text == "geen":
				return ""
			return "cape"
		if cape_val is int and int(cape_val) <= 0:
			return ""
		return "cape"
	if key == "" or not look.has(key) or look[key] == null:
		if optional:
			return ""
		if names.is_empty():
			return ""
		return names[0]
	var value: Variant = look[key]
	if value is String:
		var text := str(value).strip_edges().to_lower()
		if text == "" or text == "none" or text == "geen":
			return ""
		if names.find(text) >= 0:
			return text
		return ""
	var index := int(value)
	# M1: head 0 = geen hoofddeksel, 1 en 2 = kap en hoed. none_at is die 0.
	if spec.has("none_at"):
		var none_at := int(spec["none_at"])
		if index < 0 or index == none_at:
			return ""
		var slot := index - none_at - 1
		if slot < 0 or slot >= names.size():
			return ""
		return names[slot]
	if index < int(spec.get("none_below", 0)):
		return ""
	if index < 0 or index >= names.size():
		return ""
	return names[index]


static func _color_name(look: Dictionary, key: String, group: String) -> String:
	var names := color_names(group)
	if names.is_empty():
		return ""
	if key == "cape" and look.has("cape") and look["cape"] is String:
		var cape_color := str(look["cape"]).strip_edges().to_lower()
		if names.find(cape_color) >= 0:
			return cape_color
	if key == "" or not look.has(key) or look[key] == null:
		return names[0]
	var value: Variant = look[key]
	if value is String:
		var text := str(value).strip_edges().to_lower()
		if names.find(text) >= 0:
			return text
		return names[0]
	var index := int(value)
	if index < 0:
		index = 0
	if index >= names.size():
		index = names.size() - 1
	return names[index]


static func _load_png(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	if bytes.size() >= 26 and bytes[25] == 3:
		return _decode_indexed(bytes)
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


static func _decode_indexed(png: PackedByteArray) -> Image:
	var image := Image.new()
	if image.load_png_from_buffer(png) != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var plte := _chunk(png, "PLTE")
	var trns := _chunk(png, "tRNS")
	if plte.is_empty():
		return image
	var count := int(plte.size() / 3)
	var data := image.get_data()
	var i := 0
	var pixels := int(data.size() / 4)
	while i < pixels:
		var o := i * 4
		if int(data[o + 3]) == 0:
			i += 1
			continue
		var index := _index_of(data[o], data[o + 1], data[o + 2], plte, count)
		if index < 0:
			i += 1
			continue
		if index < trns.size() and trns[index] == 0:
			data[o + 3] = 0
		elif index >= 1 and index <= TONE_COUNT:
			# Sleuteltonen blijven de sleutelkleur tot de recolor-stap.
			data[o] = plte[index * 3]
			data[o + 1] = plte[index * 3 + 1]
			data[o + 2] = plte[index * 3 + 2]
			data[o + 3] = 255
		i += 1
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)
	return image


static func _index_of(r: int, g: int, b: int, plte: PackedByteArray, count: int) -> int:
	for i in count:
		if plte[i * 3] == r and plte[i * 3 + 1] == g and plte[i * 3 + 2] == b:
			return i
	return -1


static func _opaque_list_for(path: String, data: PackedByteArray) -> PackedInt32Array:
	var cached: Variant = _opaque_pixels.get(path)
	if cached is PackedInt32Array:
		return cached
	var pixels := int(data.size() / 4)
	var list := PackedInt32Array()
	for i in pixels:
		if int(data[i * 4 + 3]) != 0:
			list.append(i)
	_opaque_pixels[path] = list
	return list


static func _recolor_bytes_sparse(path: String, src: Image, keys: PackedColorArray, ramp: PackedColorArray) -> Image:
	var data := _layer_bytes(path)
	if data.is_empty():
		return null
	var touch := _opaque_list_for(path, _layer_bytes_cache.get(path, data))
	return _recolor_data(src.get_width(), src.get_height(), data, touch, keys, ramp)


static func _recolor_bytes(src: Image, keys: PackedColorArray, ramp: PackedColorArray) -> Image:
	var data := src.get_data()
	var touch := PackedInt32Array()
	var pixels := int(data.size() / 4)
	for i in pixels:
		if int(data[i * 4 + 3]) != 0:
			touch.append(i)
	return _recolor_pixels(src, touch, keys, ramp)


static func _recolor_pixels(src: Image, touch: PackedInt32Array, keys: PackedColorArray, ramp: PackedColorArray) -> Image:
	return _recolor_data(src.get_width(), src.get_height(), src.get_data(), touch, keys, ramp)


static func _recolor_data(w: int, h: int, data: PackedByteArray, touch: PackedInt32Array, keys: PackedColorArray, ramp: PackedColorArray) -> Image:
	var key_packed := PackedInt32Array()
	var ramp_r := PackedByteArray()
	var ramp_g := PackedByteArray()
	var ramp_b := PackedByteArray()
	key_packed.resize(keys.size())
	ramp_r.resize(keys.size())
	ramp_g.resize(keys.size())
	ramp_b.resize(keys.size())
	for i in keys.size():
		key_packed[i] = _pack(keys[i])
		if i < ramp.size():
			var dest: Color = ramp[i]
			ramp_r[i] = dest.r8
			ramp_g[i] = dest.g8
			ramp_b[i] = dest.b8
	var n := touch.size()
	var t := 0
	while t < n:
		var o := int(touch[t]) * 4
		var packed := (int(data[o]) << 16) | (int(data[o + 1]) << 8) | int(data[o + 2])
		var slot := _tone_slot_packed(packed, key_packed)
		if slot >= 0:
			data[o] = ramp_r[slot]
			data[o + 1] = ramp_g[slot]
			data[o + 2] = ramp_b[slot]
			data[o + 3] = 255
		else:
			data[o + 3] = 255
		t += 1
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


static func _tone_slot_packed(packed: int, keys: PackedInt32Array) -> int:
	var n := keys.size()
	if n >= 1 and packed == keys[0]:
		return 0
	if n >= 2 and packed == keys[1]:
		return 1
	if n >= 3 and packed == keys[2]:
		return 2
	if n >= 4 and packed == keys[3]:
		return 3
	if n >= 5 and packed == keys[4]:
		return 4
	return -1


static func _outline_pass(figure: Image) -> Image:
	var src := figure.get_data()
	var w := figure.get_width()
	var h := figure.get_height()
	var out := src.duplicate()
	var er := _outline.r8
	var eg := _outline.g8
	var eb := _outline.b8
	var touch := PackedInt32Array()
	var pixels := w * h
	for i in pixels:
		if int(src[i * 4 + 3]) == 255:
			touch.append(i)
	for idx in touch:
		var i := int(idx)
		var x := i % w
		var y := int(i / w)
		var o := i * 4
		if not _on_contour(src, w, h, x, y):
			continue
		var sum := int(src[o]) + int(src[o + 1]) + int(src[o + 2])
		if sum <= OUTLINE_MAX_SUM:
			out[o] = er
			out[o + 1] = eg
			out[o + 2] = eb
			out[o + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


static func _on_contour(data: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	return (
		_alpha_at(data, w, h, x - 1, y) == 0
		or _alpha_at(data, w, h, x + 1, y) == 0
		or _alpha_at(data, w, h, x, y - 1) == 0
		or _alpha_at(data, w, h, x, y + 1) == 0
	)


static func _alpha_at(data: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 0
	return int(data[(y * w + x) * 4 + 3])


static func _pack(color: Color) -> int:
	return (color.r8 << 16) | (color.g8 << 8) | color.b8


static func _chunk(png: PackedByteArray, kind: String) -> PackedByteArray:
	var i := 8
	var want := kind.to_ascii_buffer()
	while i + 12 <= png.size():
		var length := (int(png[i]) << 24) | (int(png[i + 1]) << 16) | (int(png[i + 2]) << 8) | int(png[i + 3])
		if i + 12 + length > png.size() or length < 0:
			return PackedByteArray()
		if png[i + 4] == want[0] and png[i + 5] == want[1] and png[i + 6] == want[2] and png[i + 7] == want[3]:
			return png.slice(i + 8, i + 8 + length)
		i += 12 + length
	return PackedByteArray()


static func write_indexed_png(image: Image, keys: PackedColorArray, path: String) -> bool:
	var extras: Array[Color] = []
	var seen := {}
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a8 == 0:
				continue
			var packed := _pack(c)
			if _tone_slot(keys, packed) >= 0 or seen.has(packed):
				continue
			seen[packed] = true
			extras.append(Color8(c.r8, c.g8, c.b8))
	var count := 1 + keys.size() + extras.size()
	if count > 256:
		return false
	var indices := PackedByteArray()
	indices.resize(image.get_width() * image.get_height())
	var p := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a8 == 0:
				indices[p] = 0
			else:
				var slot := _tone_slot(keys, _pack(c))
				if slot >= 0:
					indices[p] = slot + 1
				else:
					var extra := 0
					for i in extras.size():
						var e: Color = extras[i]
						if e.r8 == c.r8 and e.g8 == c.g8 and e.b8 == c.b8:
							extra = i
							break
					indices[p] = 1 + keys.size() + extra
			p += 1
	var raw := PackedByteArray()
	var stride := image.get_width()
	for y in image.get_height():
		raw.append(0)
		raw.append_array(indices.slice(y * stride, (y + 1) * stride))
	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var plte := PackedByteArray()
	plte.resize(count * 3)
	for i in keys.size():
		var key: Color = keys[i]
		plte[(i + 1) * 3] = key.r8
		plte[(i + 1) * 3 + 1] = key.g8
		plte[(i + 1) * 3 + 2] = key.b8
	for i in extras.size():
		var extra: Color = extras[i]
		var at := (1 + keys.size() + i) * 3
		plte[at] = extra.r8
		plte[at + 1] = extra.g8
		plte[at + 2] = extra.b8
	var trns := PackedByteArray()
	trns.resize(count)
	trns[0] = 0
	for i in range(1, count):
		trns[i] = 255
	var png := PackedByteArray()
	png.append_array(PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]))
	_png_chunk(png, "IHDR", _ihdr(image.get_width(), image.get_height()))
	_png_chunk(png, "PLTE", plte)
	_png_chunk(png, "tRNS", trns)
	_png_chunk(png, "IDAT", compressed)
	_png_chunk(png, "IEND", PackedByteArray())
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(png)
	return true


static func _tone_slot(keys: PackedColorArray, packed: int) -> int:
	for i in keys.size():
		if _pack(keys[i]) == packed:
			return i
	return -1


static func _ihdr(w: int, h: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(13)
	b[0] = (w >> 24) & 255
	b[1] = (w >> 16) & 255
	b[2] = (w >> 8) & 255
	b[3] = w & 255
	b[4] = (h >> 24) & 255
	b[5] = (h >> 16) & 255
	b[6] = (h >> 8) & 255
	b[7] = h & 255
	b[8] = 8
	b[9] = 3
	return b


static func _png_chunk(png: PackedByteArray, kind: String, data: PackedByteArray) -> void:
	var n := data.size()
	png.append((n >> 24) & 255)
	png.append((n >> 16) & 255)
	png.append((n >> 8) & 255)
	png.append(n & 255)
	var name := kind.to_ascii_buffer()
	png.append_array(name)
	png.append_array(data)
	var crc_src := PackedByteArray()
	crc_src.append_array(name)
	crc_src.append_array(data)
	var crc := _crc32(crc_src)
	png.append((crc >> 24) & 255)
	png.append((crc >> 16) & 255)
	png.append((crc >> 8) & 255)
	png.append(crc & 255)


static func _crc32(data: PackedByteArray) -> int:
	var crc := 0xffffffff
	for b in data:
		crc = crc ^ int(b)
		for _i in 8:
			if (crc & 1) != 0:
				crc = (crc >> 1) ^ 0xedb88320
			else:
				crc = crc >> 1
	return (crc ^ 0xffffffff) & 0xffffffff
