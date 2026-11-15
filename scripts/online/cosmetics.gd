class_name OnlineCosmetics
extends RefCounted
## Co-op cosmetics: data-gedreven lijst van kiesbare onderdelen (data/online/cosmetics.json).
## Zegt alleen of een onderdeel beschikbaar is voor een profiel (standaard of via unlocks).
## Puur cosmetisch: geen stats, raakt gevechtssim, netcode en look-codering niet.
## Onbekende of vervalste unlock-id's worden genegeerd, nooit een crash.

const Profiel := preload("res://scripts/online/online_profile.gd")

const PATH := "res://data/online/cosmetics.json"
const SHEETS: PackedStringArray = ["walk", "attack", "hurt", "dodge", "ko"]
const GEEN_PORTRET := "geen_portret"
const BRON_STANDAARD := "standaard"
const BRON_UNLOCK := "unlock:"

static var _cache: Dictionary = {}


## Hele document (lagen + items), gecachet. Leeg bij een kapot bestand.
static func catalog(path: String = PATH) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var doc: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			doc = parsed
	_cache[path] = doc
	return doc


static func clear_cache() -> void:
	_cache.clear()


## Alle goed gevormde items. Kapotte regels vallen weg (zie validate voor de redenen).
static func items(doc: Dictionary = {}) -> Array:
	var d := doc if not doc.is_empty() else catalog()
	var raw: Variant = d.get("items", [])
	var uit: Array = []
	if not (raw is Array):
		return uit
	for it in raw:
		if it is Dictionary and _item_vorm_ok(it):
			uit.append(it)
	return uit


static func item(id: String, doc: Dictionary = {}) -> Dictionary:
	for it in items(doc):
		if str(it["id"]) == id:
			return it
	return {}


static func item_for_look(look_key: String, index: int, doc: Dictionary = {}) -> Dictionary:
	for it in items(doc):
		if str(it["look_key"]) == look_key and int(it["look_index"]) == index:
			return it
	return {}


## "" voor standaard-items, anders de unlock-id na "unlock:" (ook als die id ongeldig is).
static func unlock_id(it: Dictionary) -> String:
	var bron := str(it.get("bron", ""))
	if bron.begins_with(BRON_UNLOCK):
		return bron.substr(BRON_UNLOCK.length())
	return ""


static func is_standard(it: Dictionary) -> bool:
	return str(it.get("bron", "")) == BRON_STANDAARD


## Profiel-unlocks opgeschoond: alleen geldige id's (a-z0-9_, max 16), max 16 stuks, geen dubbele.
## Alles wat geen Array is of er niet aan voldoet wordt genegeerd.
static func clean_unlocks(unlocks: Variant) -> PackedStringArray:
	var uit := PackedStringArray()
	if not (unlocks is Array):
		return uit
	for u in unlocks:
		if uit.size() >= Profiel.MAX_UNLOCKS:
			break
		if not (u is String):
			continue
		var s: String = u
		if Profiel._id_tekens(s, Profiel.MAX_UNLOCK_LEN) and not uit.has(s):
			uit.append(s)
	return uit


static func is_available(item_id: String, unlocks: Variant, doc: Dictionary = {}) -> bool:
	var it := item(item_id, doc)
	if it.is_empty():
		return false
	return _beschikbaar(it, clean_unlocks(unlocks))


## Zelfde, maar met een profielslot (OnlineProfile.get_slot). Leeg/kapot slot = alleen standaard.
static func is_available_for_slot(item_id: String, slot: Variant, doc: Dictionary = {}) -> bool:
	var unlocks: Variant = slot.get("unlocks", []) if slot is Dictionary else []
	return is_available(item_id, unlocks, doc)


## Beschikbare items, optioneel per laag ("haar", "boven", "onder", "hoofd").
static func available_items(unlocks: Variant, laag: String = "", doc: Dictionary = {}) -> Array:
	var schoon := clean_unlocks(unlocks)
	var uit: Array = []
	for it in items(doc):
		if laag != "" and str(it["laag"]) != laag:
			continue
		if _beschikbaar(it, schoon):
			uit.append(it)
	return uit


## True als elk look-veld met een cosmetic-item naar een beschikbaar item wijst.
## Velden zonder items (body, kleuren) en de geen-index (head 0) tellen altijd als goed.
static func look_allowed(look: Dictionary, unlocks: Variant, doc: Dictionary = {}) -> bool:
	var d := doc if not doc.is_empty() else catalog()
	var lagen: Variant = d.get("lagen", {})
	if not (lagen is Dictionary):
		return false
	var schoon := clean_unlocks(unlocks)
	for laag in lagen:
		var info: Variant = lagen[laag]
		if not (info is Dictionary):
			continue
		var key := str(info.get("look_key", ""))
		if not look.has(key):
			continue
		var idx := int(look[key])
		if idx == int(info.get("geen_index", -1)):
			continue
		var it := item_for_look(key, idx, d)
		if it.is_empty() or not _beschikbaar(it, schoon):
			return false
	return true


## Problemen in de lijst (leeg = goed). Controleert vorm, dubbele id's en dubbele look-indexen.
static func validate(doc: Dictionary = {}) -> PackedStringArray:
	var d := doc if not doc.is_empty() else catalog()
	var fout := PackedStringArray()
	var raw: Variant = d.get("items", null)
	if not (raw is Array):
		fout.append("items ontbreekt")
		return fout
	var ids := {}
	var looks := {}
	for it in raw:
		if not (it is Dictionary) or not _item_vorm_ok(it):
			fout.append("kapot item: %s" % str(it))
			continue
		var id := str(it["id"])
		if ids.has(id):
			fout.append("dubbele id: %s" % id)
		ids[id] = true
		var lk := "%s:%d" % [it["look_key"], int(it["look_index"])]
		if looks.has(lk):
			fout.append("dubbele look-index: %s" % lk)
		looks[lk] = true
	return fout


static func _beschikbaar(it: Dictionary, schoon: PackedStringArray) -> bool:
	if is_standard(it):
		return true
	var u := unlock_id(it)
	if not Profiel._id_tekens(u, Profiel.MAX_UNLOCK_LEN):
		return false
	return schoon.has(u)


static func _item_vorm_ok(it: Dictionary) -> bool:
	for k in ["id", "laag", "look_key", "bron"]:
		if not (it.get(k, null) is String) or str(it[k]) == "":
			return false
	var idx: Variant = Profiel._als_int(it.get("look_index", null), 0, 255)
	if idx == null:
		return false
	var bron := str(it["bron"])
	if bron != BRON_STANDAARD and not bron.begins_with(BRON_UNLOCK):
		return false
	if not (it.get("sheets", null) is Dictionary):
		return false
	var portret: Variant = it.get("portret", null)
	return portret is Dictionary or (portret is String and portret == GEEN_PORTRET)
