extends RefCounted
## Item-iconen v1.5: mapping uit assets/ui/icons/items/MAPPING.csv.
## 16px in lijsten, 32px alleen in het detailvak. Geen autoload: eenmaal inlezen,
## textures cachen. Ontbrekende item_id valt terug op het categorie-icoon.

const GameData := preload("res://scripts/data/game_data.gd")
const Equipment := preload("res://scripts/equipment.gd")
const KernData := preload("res://scripts/data/kern_data.gd")

const ROOT := "res://assets/ui/icons/items/"
const MAP_PATH := ROOT + "MAPPING.csv"
const SIZE16 := 16
const SIZE32 := 32

const CAT_VERBRUIK := "res://assets/ui/icons/cat_verbruik.png"
const CAT_SLEUTEL := "res://assets/ui/icons/cat_sleutel.png"
const CAT_WAPEN := "res://assets/ui/icons/cat_wapen.png"
const CAT_HARNAS := "res://assets/ui/icons/cat_harnas.png"
const CAT_ACCESSOIRE := "res://assets/ui/icons/cat_accessoire.png"

## Zelfde spreuk onder twee ids deelt het beeld (MAPPING.md).
const SHARED_SPELLS: Array[Array] = [
	["spreuk_donderslag", "spreuk_g4_donderslag"],
	["spreuk_aureool", "spreuk_g4_aureool"],
	["spreuk_ijskern", "spreuk_g4_ijskern"],
]

static var _loaded := false
static var _file16: Dictionary = {}
static var _file32: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(MAP_PATH, FileAccess.READ)
	if f == null:
		push_warning("ItemIcons: MAPPING.csv ontbreekt")
		return
	var header := true
	while not f.eof_reached():
		var cols: PackedStringArray = f.get_csv_line()
		if header:
			header = false
			continue
		if cols.size() < 3:
			continue
		var id := String(cols[0]).strip_edges()
		if id == "":
			continue
		_file16[id] = ROOT + String(cols[1]).strip_edges()
		_file32[id] = ROOT + String(cols[2]).strip_edges()


## Alle item_ids uit de catalogus (ITEMS, KEY_ITEMS, EQUIPMENT, kernfragmenten).
static func catalog_ids() -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for bron in [GameData.ITEMS, GameData.KEY_ITEMS, GameData.EQUIPMENT, KernData.KERNFRAGMENTEN]:
		for id in bron:
			var s := str(id)
			if seen.has(s):
				continue
			seen[s] = true
			out.append(s)
	out.sort()
	return out


static func has_mapping(id: String) -> bool:
	_ensure()
	return _file16.has(id)


static func path16(id: String) -> String:
	return _resolve(id, true)


static func path32(id: String) -> String:
	return _resolve(id, false)


## Eén ingang: icoon voor item_id op maat 16 of 32 (andere maten -> 16). Gecachet;
## ontbrekend bestand -> categorie-icoon; ook dat weg -> null (aanroepers verbergen dan het vak).
static func icon_for(id: String, size: int = SIZE16) -> Texture2D:
	return tex32(id) if size == SIZE32 else tex16(id)


## Gemapt pad als het bestand echt bestaat, anders het categorie-icoon (nooit een leeg gat).
static func _resolve(id: String, use16: bool) -> String:
	_ensure()
	var p := _mapped(id, use16)
	if p != "" and ResourceLoader.exists(p):
		return p
	return _category_path(id)


static func tex16(id: String) -> Texture2D:
	return _tex(path16(id))


static func tex32(id: String) -> Texture2D:
	return _tex(path32(id))


static func apply16(b: Button, id: String) -> void:
	if b == null:
		return
	if id == "":
		clear16(b)
		return
	var tex := tex16(id)
	if tex == null:
		# geen enkel icoon te vinden: rij zonder icoon (geen leeg 16px-vak), tekst blijft
		clear16(b)
		return
	b.icon = tex
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", SIZE16)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.set_meta("item_icon_id", id)
	b.set_meta("item_icon_size", SIZE16)


static func clear16(b: Button) -> void:
	if b == null:
		return
	b.icon = null
	b.remove_meta("item_icon_id")
	b.remove_meta("item_icon_size")


static func make_rect(px: int) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(px, px)
	r.size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	return r


static func show32(r: TextureRect, id: String) -> void:
	if r == null:
		return
	if id == "":
		r.texture = null
		r.visible = false
		r.set_meta("item_icon_id", "")
		r.set_meta("item_icon_size", 0)
		return
	var tex := tex32(id)
	if tex == null:
		# geen 32px- en geen categorie-icoon: vak verbergen in plaats van een leeg gat
		r.texture = null
		r.visible = false
		r.set_meta("item_icon_id", "")
		r.set_meta("item_icon_size", 0)
		return
	r.texture = tex
	r.visible = true
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_meta("item_icon_id", id)
	r.set_meta("item_icon_size", SIZE32)


static func is_px(tex: Texture2D, px: int) -> bool:
	return tex != null and tex.get_width() == px and tex.get_height() == px


static func _mapped(id: String, use16: bool) -> String:
	var tab: Dictionary = _file16 if use16 else _file32
	if tab.has(id):
		return str(tab[id])
	if GameData.SPELLS.has(id):
		var scroll_id := "spreuk_" + id
		if tab.has(scroll_id):
			return str(tab[scroll_id])
	return ""


static func _category_path(id: String) -> String:
	if Equipment.is_equipment(id):
		var slot := Equipment.slot_of(id)
		if slot == "wapen":
			return CAT_WAPEN
		if slot == "accessoire":
			return CAT_ACCESSOIRE
		return CAT_HARNAS
	if GameData.KEY_ITEMS.has(id) or KernData.KERNFRAGMENTEN.has(id):
		return CAT_SLEUTEL
	return CAT_VERBRUIK


static func _tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex != null:
		_tex_cache[path] = tex
	return tex
