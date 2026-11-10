extends SceneTree
## Genereert PLACEHOLDER-lagen voor de paper-doll-bakker.
##   godot --headless --path . --script res://tools/paper_doll/make_placeholders.gd
## Schrijft PNG's, data/online/paper_doll_layers.json en tools/placeholders_coop_paperdoll.txt.
## Geen definitieve art. De rechts-rij is hier een spiegel van links plus één markerpixel
## op lichaam; de baker spiegelt nooit en leest die rij uit de sheet.

const Baker := preload("res://scripts/online/paper_doll_baker.gd")
const OUT_DIR := "res://assets/placeholder/coop/paperdoll"
const LAYERS_PATH := "res://data/online/paper_doll_layers.json"
const LIST_PATH := "res://tools/placeholders_coop_paperdoll.txt"

const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3

const HAIR: PackedStringArray = ["kort", "lang", "stekel", "bob", "knot", "zij"]
const TOPS: PackedStringArray = ["tuniek", "mantel", "hemd", "jas"]
const BOTTOMS: PackedStringArray = ["broek", "rok", "kort"]
const HATS: PackedStringArray = ["kap", "hoed"]
const WEAPONS: PackedStringArray = ["warrior", "mage", "priest", "psytech", "archer"]

var _key := PackedColorArray()
var _huid := PackedColorArray()
var _col_shadow := Color(0, 0, 0, 0)
var _col_oog := Color(0, 0, 0, 0)
var _col_oogwit := Color(0, 0, 0, 0)
var _col_iris := Color(0, 0, 0, 0)
var _col_ondergoed := Color(0, 0, 0, 0)
var _col_goud := Color(0, 0, 0, 0)
var _laars: Array[Color] = []
var _lines: PackedStringArray = []


func _init() -> void:
	if Baker.palette_count() != 73:
		print("palet %d, verwacht 73" % Baker.palette_count())
		quit(1)
		return
	_huid = Baker.key_colors("huid")
	if _huid.size() != 5 or not Baker.palette_has(_huid[0]) or not Baker.palette_has(_huid[4]):
		print("huid-sleutelramp ongeldig")
		quit(1)
		return
	_col_shadow = Baker.fixed_color("schaduw")
	_col_oog = Baker.fixed_color("oog")
	_col_oogwit = Baker.fixed_color("oogwit")
	_col_iris = Baker.fixed_color("iris")
	_col_ondergoed = Baker.fixed_color("ondergoed")
	_col_goud = Baker.fixed_color("goud_bies")
	for i in 5:
		_laars.append(Baker.fixed_color("laarzen_riem", i))
	if not _generate():
		quit(1)
		return
	quit(0)


func _generate() -> bool:
	var layers := _layer_meta()
	var parts: Array = [
		["schaduw", "", [""]],
		["lichaam", "huid", [""]],
		["onder", "kleding", BOTTOMS],
		["boven", "kleding", TOPS],
		["haar_achter", "kleding", HAIR],
		["gezicht", "huid", [""]],
		["haar_voor", "kleding", HAIR],
		["hoofd", "kleding", HATS],
		["wapen", "", WEAPONS],
	]
	var files := 0
	for row in parts:
		var part := str(row[0])
		var ramp := str(row[1])
		var ids: Array = row[2]
		for id_v in ids:
			var id := str(id_v)
			var opt := id if id != "" else "0"
			layers[part]["options"][opt] = {}
			for sheet in ["walk", "attack", "hurt", "dodge", "ko"]:
				var rel := "%s/PLACEHOLDER_%s_%s.png" % [OUT_DIR, _stem(part, id), sheet]
				var img := _paint_sheet(part, id, sheet)
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rel).get_base_dir())
				if ramp == "":
					_save_rgba(rel, img)
				else:
					var keys := Baker.key_colors("huid" if ramp == "huid" else "kleding")
					if not Baker.write_indexed_png(img, keys, rel):
						print("schrijven mislukt %s" % rel)
						return false
				layers[part]["options"][opt][sheet] = rel
				var spec: Dictionary = Baker.SHEETS[sheet]
				_lines.append("%s  %dx%d  PLACEHOLDER paper-doll %s sheet %s" % [
					rel.trim_prefix("res://"), int(spec["w"]), int(spec["h"]), _stem(part, id), sheet,
				])
				files += 1
		print("deel %s (%d)" % [part, ids.size()])
	var doc := {
		"version": 1,
		"placeholder": true,
		"generator": "tools/paper_doll/make_placeholders.gd",
		"recolor": Baker.RECOLOR_PATH,
		"directions": ["down", "left", "right", "up"],
		"anchor": [Baker.ANCHOR.x, Baker.ANCHOR.y],
		"mirrors_right": false,
		"draw_order": _order_array(),
		"outline": {"color": "#3a4058", "max_rgb_sum": Baker.OUTLINE_MAX_SUM, "shadow_under": true},
		"sheets": Baker.SHEETS,
		"layers": layers,
	}
	_write_text(LAYERS_PATH, JSON.stringify(doc, "  ") + "\n")
	var header := PackedStringArray([
		"# PLACEHOLDER paper-doll (online co-op M2). Geen definitieve art.",
		"# Vervang het bestand door RPG ART (zelfde pad + maat) en haal de regel hier weg.",
		"# Sleutel-ramp uit data/paperdoll/recolor_v1.json: 5 tonen rand, donker, schaduw, basis, licht.",
		"# Huid-sleutel = huid/licht. Kleding- en haar-sleutel = key_ramp_kleding_haar.",
		"# Index 0 is transparant. Vaste kleuren (laarzen, ogen, goud) zijn extra indices en worden niet herschikt.",
		"# Schaduw en wapen zijn RGBA, zonder sleutel-ramp.",
		"# Elke laag vult het hele sheet, uitgelijnd op dezelfde cel.",
		"# walk 72x128 (kolommen stand/stapA/stapB, rijen onder/links/rechts/boven, cel 24x32).",
		"# attack 288x192, hurt 192x48, dodge 192x48: cel 48x48, stand-pose op (12,16).",
		"# ko 48x48, één frame. Aanval-frame 0 is de stand-pose; de zwaai zit alleen op frames 1-5.",
		"# De baker leest de rechts-rij uit de sheet en spiegelt nooit.",
		"# In deze placeholder is rechts een spiegel van links, plus markerpixel (0,0) op lichaam = huid-toon licht.",
		"# Final v2 tekent rechts apart; die marker verdwijnt dan vanzelf.",
		"# Laagvolgorde onder→boven: schaduw, lichaam, onder, boven, cape, haar_achter, gezicht, haar_voor, hoofd, wapen.",
		"# head volgt M1: 0 = geen hoofddeksel, 1 = kap, 2 = hoed. Namen \"kap\" en \"hoed\" werken ook.",
		"# Cape heeft in v1 geen bestand. haar_kort_achter is leeg, zoals de proef.",
	])
	header.append_array(_lines)
	_write_text(LIST_PATH, "\n".join(header) + "\n")
	if not _selfcheck():
		return false
	print("paper-doll placeholders: %d png" % files)
	return files == 145


func _order_array() -> Array:
	var out: Array = []
	for layer in Baker.layer_order():
		out.append(layer)
	return out


func _stem(part: String, id: String) -> String:
	if part == "haar_achter":
		return "haar_%s_achter" % id
	if part == "haar_voor":
		return "haar_%s_voor" % id
	if part == "hoofd":
		return "hoofd_%s" % id
	if part == "onder":
		return "onder_%s" % id
	if part == "boven":
		return "boven_%s" % id
	if part == "wapen":
		return "wapen_%s" % id
	return part


func _layer_meta() -> Dictionary:
	return {
		"schaduw": {"recolor": "", "under": true, "fixed_id": "0", "names": ["0"], "options": {}},
		"lichaam": {
			"recolor": "huid", "key_ramp": "huid", "color_key": "skin",
			"fixed_id": "0", "names": ["0"], "options": {},
		},
		"onder": {
			"recolor": "kleding", "key_ramp": "kleding", "color_key": "bottom_color",
			"id_key": "bottom", "names": BOTTOMS, "none_below": 0, "options": {},
		},
		"boven": {
			"recolor": "kleding", "key_ramp": "kleding", "color_key": "top_color",
			"id_key": "top", "names": TOPS, "none_below": 0, "options": {},
		},
		"cape": {
			"recolor": "kleding", "key_ramp": "kleding", "color_key": "top_color",
			"id_key": "cape", "names": [], "optional": true, "options": {},
		},
		"haar_achter": {
			"recolor": "haar", "key_ramp": "kleding", "color_key": "hair_color",
			"id_key": "hair", "names": HAIR, "none_below": 0, "options": {},
		},
		"gezicht": {
			"recolor": "huid", "key_ramp": "huid", "color_key": "skin",
			"fixed_id": "0", "names": ["0"], "options": {},
		},
		"haar_voor": {
			"recolor": "haar", "key_ramp": "kleding", "color_key": "hair_color",
			"id_key": "hair", "names": HAIR, "none_below": 0, "options": {},
		},
		"hoofd": {
			"recolor": "kleding", "key_ramp": "kleding", "color_key": "head_color",
			"id_key": "head", "names": HATS, "optional": true, "none_at": 0, "options": {},
		},
		"wapen": {
			"recolor": "", "id_key": "class", "class_map": true, "optional": true,
			"names": WEAPONS, "options": {},
		},
	}


func _selfcheck() -> bool:
	var sample := "%s/PLACEHOLDER_lichaam_walk.png" % OUT_DIR
	var png := FileAccess.get_file_as_bytes(sample)
	if png.size() < 26 or int(png[25]) != 3:
		print("SELFCHECK lichaam is niet geïndexeerd")
		return false
	var img := Image.new()
	if img.load_png_from_buffer(png) != OK:
		print("SELFCHECK png laadt niet")
		return false
	var marker := img.get_pixel(0, 64)
	var left := img.get_pixel(0, 32)
	var tone: Color = _huid[4]
	if marker.r8 != tone.r8 or marker.g8 != tone.g8 or marker.b8 != tone.b8 or marker.a8 != 255:
		print("SELFCHECK marker rechts ontbreekt ", marker)
		return false
	if left.a8 != 0:
		print("SELFCHECK links-rij heeft de marker")
		return false
	var weapon := "%s/PLACEHOLDER_wapen_warrior_walk.png" % OUT_DIR
	var wp := FileAccess.get_file_as_bytes(weapon)
	if wp.size() < 26 or int(wp[25]) == 3:
		print("SELFCHECK wapen hoort RGBA te zijn")
		return false
	print("SELFCHECK ok")
	return true


func _save_rgba(res_path: String, img: Image) -> void:
	var abs_path := ProjectSettings.globalize_path(res_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)


func _write_text(res_path: String, text: String) -> void:
	var abs_path := ProjectSettings.globalize_path(res_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _k(shade: int) -> Color:
	return _key[clampi(shade, 0, 4)]


func _use(which: String) -> void:
	_key = _huid if which == "huid" else Baker.key_colors("kleding")


func _paint_sheet(part: String, id: String, sheet: String) -> Image:
	var spec: Dictionary = Baker.SHEETS[sheet]
	var w := int(spec["w"])
	var h := int(spec["h"])
	var cw := int(spec["cw"])
	var ch := int(spec["ch"])
	var cols := int(spec["cols"])
	var rows := int(spec["rows"])
	var ax := 0 if cw == 24 else Baker.ANCHOR.x
	var ay := 0 if ch == 32 else Baker.ANCHOR.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for row in rows:
		for col in cols:
			var dir := row if rows > 1 else col
			var cell := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
			if sheet == "ko":
				_paint_ko(cell, part, id)
			else:
				var bob := 0
				var step := 0
				if sheet == "walk" and col > 0:
					bob = -1
					step = col
				elif sheet == "attack" and col == 3:
					bob = 1
				elif sheet == "hurt":
					bob = 1
				var fig := _figure(part, id, dir, bob, step)
				var dx := 0
				if sheet == "dodge":
					dx = _dodge_dx(dir)
				cell.blend_rect(fig, Rect2i(0, 0, 24, 32), Vector2i(ax + dx, ay))
				if sheet == "attack" and part == "wapen" and col > 0:
					_swing(cell, id, col, dir)
			img.blend_rect(cell, Rect2i(0, 0, cw, ch), Vector2i(col * cw, row * ch))
	return img


func _dodge_dx(dir: int) -> int:
	if dir == DIR_LEFT:
		return -4
	if dir == DIR_RIGHT:
		return 4
	if dir == DIR_UP:
		return -2
	return 3


func _figure(part: String, id: String, dir: int, bob: int, step: int) -> Image:
	var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	var face := DIR_RIGHT if dir == DIR_LEFT else dir
	_draw(img, part, id, face, bob, step)
	if dir == DIR_LEFT:
		img.flip_x()
	# Asymmetrie: alleen de rechterrij van lichaam. De baker mag dit niet wegspiegelen.
	if dir == DIR_RIGHT and part == "lichaam":
		img.set_pixel(0, 0, _huid[4])
	return img


func _draw(img: Image, part: String, id: String, face: int, bob: int, step: int) -> void:
	match part:
		"schaduw":
			_paint_shadow(img, face, bob)
		"lichaam":
			_use("huid")
			_body(img, face, bob, step)
		"onder":
			_use("kleding")
			_bottom(img, BOTTOMS.find(id), face, bob, step)
		"boven":
			_use("kleding")
			_top(img, TOPS.find(id), face, bob)
		"haar_achter":
			_use("kleding")
			_hair(img, HAIR.find(id), false, face, bob)
		"haar_voor":
			_use("kleding")
			_hair(img, HAIR.find(id), true, face, bob)
		"gezicht":
			_use("huid")
			_face(img, face, bob)
		"hoofd":
			_use("kleding")
			_hat(img, HATS.find(id), face, bob)
		"wapen":
			_weapon_held(img, id, face, bob)


func _box(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	if w <= 0 or h <= 0 or col.a == 0:
		return
	var x0 := x
	var y0 := y
	var x1 := x + w
	var y1 := y + h
	var limit_x := img.get_width()
	var limit_y := img.get_height()
	if x0 < 0:
		x0 = 0
	if y0 < 0:
		y0 = 0
	if x1 > limit_x:
		x1 = limit_x
	if y1 > limit_y:
		y1 = limit_y
	if x1 <= x0 or y1 <= y0:
		return
	img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), col)


func _paint_shadow(img: Image, face: int, bob: int) -> void:
	var y := 30 + bob
	if face == DIR_RIGHT:
		_box(img, 8, y, 10, 1, _col_shadow)
		_box(img, 9, y + 1, 7, 1, _col_shadow)
	else:
		# (6, 30) bij bob 0 blijft schaduw: het lichaam dekt x=6 daar niet.
		_box(img, 6, y, 12, 1, _col_shadow)
		_box(img, 8, y + 1, 8, 1, _col_shadow)


func _body(img: Image, face: int, bob: int, step: int) -> void:
	var lx := 0
	var rx := 0
	if step == 1:
		lx = -1
		rx = 1
	elif step == 2:
		lx = 1
		rx = -1
	if face == DIR_RIGHT:
		_box(img, 9, 2 + bob, 8, 10, _k(0))
		_box(img, 10, 3 + bob, 6, 8, _k(2))
		_box(img, 13, 4 + bob, 2, 2, _k(4))
		_box(img, 10, 13 + bob, 5, 8, _k(2))
		_box(img, 14, 14 + bob, 3, 7, _k(1))
		_box(img, 10 + lx, 21 + bob, 3, 8, _k(1))
		_box(img, 13 + rx, 21 + bob, 2, 7, _k(2))
		_box(img, 9 + lx, 29 + bob, 4, 2, _k(0))
		return
	var head := _k(1) if face == DIR_UP else _k(2)
	# (7, 2) is toon 0 op de contour. (10, 5) is toon 4 en ligt binnenin.
	_box(img, 7, 2 + bob, 10, 10, _k(0))
	_box(img, 8, 3 + bob, 8, 8, head)
	if face == DIR_DOWN:
		_box(img, 9, 4 + bob, 3, 2, _k(3))
		_box(img, 10, 5 + bob, 2, 2, _k(4))
	_box(img, 9, 13 + bob, 6, 8, _k(2))
	_box(img, 10, 19 + bob, 4, 1, _col_ondergoed)
	_box(img, 5, 14 + bob, 3, 7, _k(1))
	_box(img, 16, 14 + bob, 3, 7, _k(1))
	_box(img, 9 + lx, 21 + bob, 3, 8, _k(1))
	_box(img, 13 + rx, 21 + bob, 3, 8, _k(2))
	_box(img, 8 + lx, 29 + bob, 4, 2, _k(0))
	_box(img, 13 + rx, 29 + bob, 4, 2, _k(0))


func _bottom(img: Image, style: int, face: int, bob: int, step: int) -> void:
	var lx := 0
	var rx := 0
	if step == 1:
		lx = -1
		rx = 1
	elif step == 2:
		lx = 1
		rx = -1
	if style == 2:
		var x := 8 if face == DIR_RIGHT else 7
		var w := 8 if face == DIR_RIGHT else 10
		_box(img, x, 20 + bob, w, 8, _k(0))
		_box(img, x + 1, 21 + bob, w - 2, 6, _k(2))
		return
	var leg_h := 4 if style == 1 else 8
	if face == DIR_RIGHT:
		_box(img, 10 + lx, 21 + bob, 3, leg_h, _k(1))
		_box(img, 13 + rx, 21 + bob, 2, leg_h, _k(2))
		_box(img, 10 + lx, 28 + bob, 3, 3, _laars[0])
		_box(img, 13 + rx, 28 + bob, 2, 3, _laars[2])
		return
	_box(img, 9 + lx, 21 + bob, 3, leg_h, _k(0))
	_box(img, 10 + lx, 21 + bob, 2, leg_h, _k(2))
	_box(img, 13 + rx, 21 + bob, 3, leg_h, _k(1))
	_box(img, 9 + lx, 28 + bob, 3, 3, _laars[0])
	_box(img, 13 + rx, 28 + bob, 3, 3, _laars[3])


func _top(img: Image, style: int, face: int, bob: int) -> void:
	if face == DIR_RIGHT:
		if style == 2:
			_box(img, 8, 13 + bob, 10, 14, _k(0))
			_box(img, 9, 14 + bob, 8, 12, _k(2))
		elif style == 3:
			_box(img, 9, 13 + bob, 6, 8, _k(2))
			_box(img, 14, 14 + bob, 4, 6, _k(0))
			_box(img, 9, 13 + bob, 6, 1, _k(4))
		elif style == 1:
			_box(img, 9, 13 + bob, 6, 11, _k(2))
			_box(img, 9, 13 + bob, 6, 1, _k(4))
			_box(img, 14, 16 + bob, 1, 4, _col_goud)
		else:
			_box(img, 9, 13 + bob, 6, 7, _k(2))
			_box(img, 9, 13 + bob, 6, 1, _k(4))
		return
	if style == 2:
		_box(img, 5, 12 + bob, 14, 16, _k(0))
		_box(img, 6, 13 + bob, 12, 14, _k(2))
		_box(img, 8, 13 + bob, 4, 2, _k(4))
	elif style == 3:
		_box(img, 9, 13 + bob, 6, 8, _k(2))
		_box(img, 4, 14 + bob, 4, 6, _k(0))
		_box(img, 16, 14 + bob, 4, 6, _k(1))
		_box(img, 9, 13 + bob, 6, 1, _k(4))
	elif style == 1:
		_box(img, 8, 13 + bob, 8, 12, _k(0))
		_box(img, 9, 14 + bob, 6, 10, _k(2))
		_box(img, 11, 16 + bob, 2, 4, _col_goud)
	else:
		_box(img, 9, 13 + bob, 6, 8, _k(2))
		_box(img, 9, 13 + bob, 6, 2, _k(4))
		_box(img, 10, 16 + bob, 4, 1, _col_goud)
		_box(img, 9, 19 + bob, 6, 1, _k(0))


func _hair(img: Image, style: int, front_layer: bool, face: int, bob: int) -> void:
	var back := face == DIR_UP
	if front_layer:
		if back:
			return
		var thick := 2 + (style % 3)
		var y := 3 + bob
		if face == DIR_DOWN:
			_box(img, 8, y, 8, thick, _k(2))
			_box(img, 8, y, 8, 1, _k(4))
			if style >= 3:
				_box(img, 7, y + thick, 2, 3, _k(1))
		else:
			_box(img, 12, y, 5, thick, _k(2))
		return
	# haar_kort_achter is leeg, zoals de proef.
	if style == 0:
		return
	if back:
		_box(img, 6, 1 + bob, 12, 12, _k(0))
		_box(img, 7, 2 + bob, 10, 10, _k(2))
		_box(img, 9, 3 + bob, 4, 2, _k(4))
		if style == 2:
			_box(img, 5, 12 + bob, 3, 10, _k(1))
			_box(img, 16, 12 + bob, 3, 10, _k(1))
		elif style == 5:
			_box(img, 9, bob, 6, 4, _k(1))
		return
	if style == 1:
		_box(img, 6, 1 + bob, 12, 5, _k(1))
		_box(img, 6, 6 + bob, 2, 6, _k(2))
		_box(img, 16, 6 + bob, 2, 6, _k(2))
	elif style == 2:
		_box(img, 6, bob, 12, 5, _k(2))
		_box(img, 5, 5 + bob, 3, 12, _k(1))
		_box(img, 16, 5 + bob, 3, 12, _k(1))
	elif style == 3:
		_box(img, 8, bob, 2, 4, _k(0))
		_box(img, 11, bob - 1, 2, 5, _k(2))
		_box(img, 14, bob, 2, 4, _k(1))
		_box(img, 7, 3 + bob, 10, 2, _k(2))
	elif style == 4:
		_box(img, 8, 1 + bob, 10, 4, _k(2))
		_box(img, 15, 4 + bob, 4, 8, _k(1))
		_box(img, 16, 2 + bob, 2, 2, _k(4))
	else:
		_box(img, 7, 2 + bob, 10, 3, _k(2))
		_box(img, 9, bob, 6, 4, _k(1))
		_box(img, 10, bob, 3, 2, _k(4))


func _face(img: Image, face: int, bob: int) -> void:
	if face == DIR_UP:
		return
	if face == DIR_RIGHT:
		_box(img, 14, 6 + bob, 2, 2, _col_oogwit)
		img.set_pixel(15, 6 + bob, _col_iris)
		img.set_pixel(15, 7 + bob, _col_oog)
		return
	_box(img, 9, 6 + bob, 2, 2, _col_oogwit)
	_box(img, 13, 6 + bob, 2, 2, _col_oogwit)
	img.set_pixel(10, 6 + bob, _col_iris)
	img.set_pixel(14, 6 + bob, _col_iris)
	img.set_pixel(9, 7 + bob, _col_oog)
	img.set_pixel(13, 7 + bob, _col_oog)


func _hat(img: Image, style: int, face: int, bob: int) -> void:
	if style == 1:
		var brim_x := 6 if face == DIR_RIGHT else 4
		var brim_w := 12 if face == DIR_RIGHT else 16
		_box(img, brim_x, 3 + bob, brim_w, 2, _k(0))
		_box(img, 8, bob, 8, 4, _k(2))
		_box(img, 10, bob, 3, 2, _k(4))
		return
	_box(img, 8, bob, 8, 4, _k(1))
	_box(img, 8, bob, 8, 1, _k(4))
	_box(img, 8, 3 + bob, 8, 1, _k(0))


func _weapon_pair(id: String) -> Array:
	match id:
		"warrior":
			return [Color8(184, 180, 172), Color8(224, 176, 64)]
		"mage":
			return [Color8(64, 120, 200), Color8(168, 168, 224)]
		"priest":
			return [Color8(248, 232, 144), Color8(255, 250, 240)]
		"psytech":
			return [Color8(164, 102, 240), Color8(64, 224, 232)]
		_:
			return [Color8(212, 168, 104), Color8(116, 150, 62)]


func _weapon_held(img: Image, id: String, face: int, bob: int) -> void:
	var pair: Array = _weapon_pair(id)
	var blade: Color = pair[0]
	var accent: Color = pair[1]
	if id == "warrior":
		var x := 16 if face == DIR_RIGHT else 17
		_box(img, x, 8 + bob, 2, 12, blade)
		_box(img, x - 1, 19 + bob, 4, 2, accent)
	elif id == "mage":
		_box(img, 18, 4 + bob, 2, 22, blade)
		_box(img, 17, 4 + bob, 4, 3, accent)
	elif id == "priest":
		_box(img, 17, 12 + bob, 2, 12, blade)
		_box(img, 16, 11 + bob, 4, 3, accent)
	elif id == "psytech":
		_box(img, 15, 15 + bob, 7, 2, blade)
		_box(img, 20, 14 + bob, 2, 4, accent)
	else:
		_box(img, 16, 8 + bob, 2, 14, blade)
		_box(img, 18, 8 + bob, 1, 14, accent)
		_box(img, 16, 8 + bob, 3, 1, accent)
		_box(img, 16, 21 + bob, 3, 1, accent)


func _swing(cell: Image, id: String, frame: int, dir: int) -> void:
	var reach_tbl: Array[int] = [0, 6, 12, 18, 10, 4]
	var reach := reach_tbl[frame]
	if reach <= 0:
		return
	var pair: Array = _weapon_pair(id)
	var blade: Color = pair[0]
	var accent: Color = pair[1]
	if dir == DIR_LEFT:
		_box(cell, 12 - reach, 22, reach, 2, blade)
		_box(cell, 12 - reach, 21, 2, 4, accent)
	elif dir == DIR_UP:
		_box(cell, 22, 16 - reach, 2, reach, blade)
		_box(cell, 21, 16 - reach, 4, 2, accent)
	else:
		_box(cell, 36, 18, reach, 2, blade)
		_box(cell, 34 + reach, 17, 2, 4, accent)


func _paint_ko(cell: Image, part: String, id: String) -> void:
	match part:
		"schaduw":
			_box(cell, 8, 40, 32, 2, _col_shadow)
			_box(cell, 12, 42, 24, 1, _col_shadow)
		"lichaam":
			_use("huid")
			_box(cell, 6, 28, 10, 10, _k(0))
			_box(cell, 7, 29, 8, 8, _k(2))
			_box(cell, 8, 30, 3, 2, _k(4))
			_box(cell, 16, 30, 22, 8, _k(2))
			_box(cell, 36, 32, 8, 5, _k(1))
		"gezicht":
			_box(cell, 8, 31, 2, 2, _col_oogwit)
			cell.set_pixel(9, 31, _col_iris)
			cell.set_pixel(8, 32, _col_oog)
		"haar_achter":
			if HAIR.find(id) == 0:
				return
			_use("kleding")
			_box(cell, 5, 27, 12, 6, _k(1))
		"haar_voor":
			_use("kleding")
			_box(cell, 7, 29, 6, 2, _k(4))
		"onder":
			_use("kleding")
			_box(cell, 30, 32, 12, 6, _k(2))
			_box(cell, 34, 36, 6, 3, _laars[2])
		"boven":
			_use("kleding")
			_box(cell, 16, 30, 12, 8, _k(2))
			_box(cell, 16, 30, 12, 1, _k(4))
		"hoofd":
			_use("kleding")
			if HATS.find(id) == 1:
				_box(cell, 4, 26, 14, 2, _k(0))
			_box(cell, 6, 24, 8, 4, _k(2))
		"wapen":
			var pair: Array = _weapon_pair(id)
			var blade: Color = pair[0]
			var accent: Color = pair[1]
			_box(cell, 18, 22, 16, 2, blade)
			_box(cell, 32, 21, 3, 4, accent)
