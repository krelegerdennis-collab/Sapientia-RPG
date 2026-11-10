class_name OnlineProfile
extends RefCounted
## Online co-op-profiel (mijlpaal M1). Lokaal bestand, los van de verhaal-saves.
## Formaat van bestand, look-bytes en exportcode: docs/online/ONLINE_PROFILE.md.
## Schrijft alleen user://online_profile.json en zijn .tmp/.bak. Nooit save_N of autosave.

signal profile_loaded(recovered: bool)
signal profile_changed(index: int)
signal import_refused(reason: String)

const PATH := "user://online_profile.json"
const FORMAT_VERSION := 1
const SLOT_COUNT := 3
const NAME_MAX := 5
const UID_HEX := 8

const LOOK_VERSION := 1
const LOOK_BYTES := 16
const LOOK_KEYS: Array[String] = [
	"body", "skin", "hair", "hair_color", "top", "top_color", "bottom", "bottom_color", "head",
]
## Index-max (inclusief) uit §5.3. head 0 = geen hoofddeksel, 1 en 2 = de twee opties.
const LOOK_MAX := {
	"body": 0, "skin": 3, "hair": 5, "hair_color": 7,
	"top": 3, "top_color": 5, "bottom": 2, "bottom_color": 5, "head": 2,
}

## Zelfde 31 tekens als relay/src/codes.js. Geen 0/O/1/I/L, dus dit is base31, geen RFC-base32.
const CODE_ALFABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const MAX_CODE_CHARS := 4096
const MAX_RAW_CHARS := 16384
const MAX_JSON_BYTES := 3072
const MAX_WIRE_BYTES := 8192

const MAX_UNLOCKS := 16
const MAX_UNLOCK_LEN := 16
const MAX_GRANTS := 8
const MAX_GRANT_LEN := 16
const MAX_PROFILE_EXP := 999999
const MAX_BEST_FLOOR := 100
const MAX_RUNS := 9999

## Klasse → base_hero en rol (§5.2). Stats blijven in game_data.gd; die kopiëren we niet.
const CLASS_INFO := {
	"warrior": {"base_hero": "dennis", "role": "Tank"},
	"mage": {"base_hero": "noor", "role": "Control"},
	"priest": {"base_hero": "lotte", "role": "Heal"},
	"psytech": {"base_hero": "kael", "role": "Dps"},
	"archer": {"base_hero": "orion", "role": "Dps"},
}

const MELDING := {
	"empty": "Code is leeg.",
	"too_long": "Code is te lang.",
	"alphabet": "Code heeft een teken dat er niet in hoort.",
	"checksum": "Checksum klopt niet.",
	"corrupt": "Code of bestand is kapot.",
	"version": "Versie wordt niet herkend.",
	"schema": "Profiel klopt niet.",
	"index": "Slot bestaat niet.",
	"vacant": "Slot is leeg.",
	"name": "Naam moet 1 tot 5 letters zijn.",
	"class": "Klasse bestaat niet.",
	"look": "Uiterlijk klopt niet.",
	"occupied": "Slot is bezet.",
	"progress": "Voortgang klopt niet.",
	"io": "Profielbestand kon niet worden geschreven.",
}

## Verhaal- en solo-paden. Een schrijfpoging hierheen wordt geweigerd.
const VERBODEN_PADEN: Array[String] = [
	"user://save_1.json", "user://save_2.json", "user://save_3.json", "user://save_4.json",
	"user://autosave.json", "user://autosave_1.json", "user://autosave_2.json",
	"user://autosave_3.json", "user://autosave_4.json",
	"user://som_save_1.json", "user://coop_guest_session.json", "user://coop_guest_autosave.json",
]

var last_load_reason := ""
var last_backup_path := ""

var _slots: Array = [null, null, null]
var _geladen := false
var _bezig := false
var _beschermd := false
var _backup_volg := 0


static func base_hero_for(class_id: String) -> String:
	var info: Variant = CLASS_INFO.get(class_id, null)
	if info is Dictionary:
		return str(info.get("base_hero", ""))
	return ""


static func role_for(class_id: String) -> String:
	var info: Variant = CLASS_INFO.get(class_id, null)
	if info is Dictionary:
		return str(info.get("role", ""))
	return ""


static func default_look() -> Dictionary:
	var uit := {}
	for k in LOOK_KEYS:
		uit[k] = 0
	return uit


## 16 bytes: versie, 9 look-velden, 5 gereserveerd (0), checksum over byte 0..14.
static func encode_look(look: Dictionary) -> PackedByteArray:
	if not _look_ok(look):
		return PackedByteArray()
	var b := PackedByteArray()
	b.resize(LOOK_BYTES)
	b.fill(0)
	b[0] = LOOK_VERSION
	for i in LOOK_KEYS.size():
		b[i + 1] = int(look[LOOK_KEYS[i]])
	b[15] = _look_som(b)
	return b


static func decode_look(data: PackedByteArray) -> Dictionary:
	if data.size() != LOOK_BYTES:
		return {}
	if int(data[0]) != LOOK_VERSION:
		return {}
	for i in range(10, 15):
		if int(data[i]) != 0:
			return {}
	if int(data[15]) != _look_som(data):
		return {}
	var uit := {}
	for i in LOOK_KEYS.size():
		var n: Variant = _als_int(int(data[i + 1]), 0, int(LOOK_MAX[LOOK_KEYS[i]]))
		if n == null:
			return {}
		uit[LOOK_KEYS[i]] = int(n)
	return uit


static func crc32_ieee(data: PackedByteArray) -> int:
	var crc := 0xFFFFFFFF
	for b in data:
		crc = (crc ^ (int(b) & 0xFF)) & 0xFFFFFFFF
		for _bit in 8:
			if (crc & 1) != 0:
				crc = ((crc >> 1) ^ 0xEDB88320) & 0xFFFFFFFF
			else:
				crc = (crc >> 1) & 0xFFFFFFFF
	return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


## Base31 met CODE_ALFABET. Het eerste byte van data moet niet 0 zijn (de versiebyte).
static func encode_base31(data: PackedByteArray) -> String:
	if data.is_empty() or int(data[0]) == 0:
		return ""
	var acc := data.duplicate()
	var digits: Array = []
	while not acc.is_empty():
		var quot := PackedByteArray()
		var rem := 0
		for b in acc:
			var cur := rem * 256 + (int(b) & 0xFF)
			var q := int(cur / 31)
			rem = cur % 31
			if not quot.is_empty() or q != 0:
				quot.append(q)
		digits.append(rem)
		acc = quot
	var uit := ""
	for i in range(digits.size() - 1, -1, -1):
		uit += CODE_ALFABET[int(digits[i])]
	return uit


static func decode_base31(code: String) -> Dictionary:
	var norm := _normaliseer_code(code)
	if not bool(norm.get("ok", false)):
		return norm
	var tekst: String = norm.get("code", "")
	var n := PackedByteArray()
	for i in tekst.length():
		var d := CODE_ALFABET.find(tekst[i])
		if d < 0:
			return _fout("alphabet")
		n = _mul31_add(n, d)
		if n.size() > MAX_WIRE_BYTES:
			return _fout("too_long")
	return _goed({"bytes": n})


## Envelope-versie 1 is de enige die import accepteert. Een andere versie is alleen
## om een oude code te bouwen (test of een latere weigering).
static func encode_profile_code(document: Dictionary, envelope_version: int = FORMAT_VERSION) -> Dictionary:
	if envelope_version < 1 or envelope_version > 255:
		return _fout("version")
	var plain := JSON.stringify(document).to_utf8_buffer()
	if plain.is_empty() or plain.size() > MAX_JSON_BYTES:
		return _fout("too_long")
	var compressed := plain.compress(FileAccess.COMPRESSION_DEFLATE)
	if compressed.is_empty():
		return _fout("io")
	var wire := PackedByteArray()
	wire.append(envelope_version & 0xFF)
	_append_u32(wire, plain.size())
	wire.append_array(compressed)
	if wire.size() + 4 > MAX_WIRE_BYTES:
		return _fout("too_long")
	_append_u32(wire, crc32_ieee(wire))
	var code := encode_base31(wire)
	if code.is_empty() or code.length() > MAX_CODE_CHARS:
		return _fout("too_long")
	return _goed({"code": code})


static func decode_profile_code(code: String) -> Dictionary:
	var dec := decode_base31(code)
	if not bool(dec.get("ok", false)):
		return dec
	var bytes: PackedByteArray = dec.get("bytes", PackedByteArray())
	if bytes.size() < 10:
		return _fout("corrupt")
	var body := bytes.size() - 4
	var verwacht := _read_u32(bytes, body)
	if verwacht != crc32_ieee(bytes.slice(0, body)):
		return _fout("checksum")
	if int(bytes[0]) != FORMAT_VERSION:
		return _fout("version")
	var plain_len := _read_u32(bytes, 1)
	if plain_len < 2 or plain_len > MAX_JSON_BYTES:
		return _fout("corrupt")
	var compressed := bytes.slice(5, body)
	var plain := compressed.decompress(plain_len, FileAccess.COMPRESSION_DEFLATE)
	if plain.size() != plain_len or not _utf8_ok(plain):
		return _fout("corrupt")
	var tekst := plain.get_string_from_utf8().strip_edges()
	if not tekst.begins_with("{"):
		return _fout("corrupt")
	var data: Variant = JSON.parse_string(tekst)
	if data == null or not (data is Dictionary):
		return _fout("corrupt")
	var doc: Dictionary = data
	if _als_int(doc.get("version"), 1, 1) == null:
		return _fout("version")
	var slots: Variant = _slots_uit_json(doc.get("slots"))
	if slots == null:
		return _fout("schema")
	var lijst: Array = slots
	return _goed({"slots": lijst, "document": _document_van(lijst)})


func load_profile() -> Dictionary:
	_bezig = true
	_beschermd = false
	last_load_reason = ""
	last_backup_path = ""
	if not FileAccess.file_exists(PATH):
		_slots = _lege_slots()
		_geladen = true
		_bezig = false
		profile_loaded.emit(false)
		return _goed({"recovered": false, "backup": ""})
	var ruw := FileAccess.get_file_as_bytes(PATH)
	var oordeel := _beoordeel_bytes(ruw)
	if bool(oordeel.get("ok", false)):
		_slots = (oordeel.get("slots", _lege_slots()) as Array).duplicate(true)
		_geladen = true
		_bezig = false
		profile_loaded.emit(false)
		return _goed({"recovered": false, "backup": ""})
	var reden := str(oordeel.get("reason", "corrupt"))
	var backup := _backup_ruw(ruw)
	last_load_reason = reden
	last_backup_path = backup
	_slots = _lege_slots()
	if backup == "":
		_beschermd = true
		_geladen = true
		_bezig = false
		profile_loaded.emit(true)
		return _fout(reden)
	if not _opslaan():
		_beschermd = true
		_geladen = true
		_bezig = false
		profile_loaded.emit(true)
		return _fout("io")
	_geladen = true
	_bezig = false
	profile_loaded.emit(true)
	profile_changed.emit(-1)
	return {
		"ok": true,
		"reason": reden,
		"message": "Profielbestand is apart gezet. Er is een leeg profiel geladen.",
		"recovered": true,
		"backup": backup,
	}


func document() -> Dictionary:
	_ensure_loaded()
	return _document_van(_slots)


func has_slot(index: int) -> bool:
	_ensure_loaded()
	return index >= 0 and index < SLOT_COUNT and _slots[index] != null


func get_slot(index: int) -> Dictionary:
	_ensure_loaded()
	if not has_slot(index):
		return {}
	return (_slots[index] as Dictionary).duplicate(true)


func create_slot(index: int, avatar_name: String, class_id: String, look: Dictionary = {}) -> Dictionary:
	_ensure_loaded()
	if _beschermd:
		return _fout("io")
	if index < 0 or index >= SLOT_COUNT:
		return _fout("index")
	if _slots[index] != null:
		return _fout("occupied")
	var naam := avatar_name.strip_edges()
	if not _naam_ok(naam):
		return _fout("name")
	var klasse := class_id.strip_edges().to_lower()
	if not CLASS_INFO.has(klasse):
		return _fout("class")
	var gebruik := default_look() if look.is_empty() else look
	if not _look_ok(gebruik):
		return _fout("look")
	var uid := _nieuwe_uid()
	if uid == "":
		return _fout("io")
	var slot := _maak_slot(uid, naam, klasse, _canon_look(gebruik))
	var vorige = _slots[index]
	_slots[index] = slot
	if not _opslaan():
		_slots[index] = vorige
		return _fout("io")
	profile_changed.emit(index)
	return _goed({"slot": slot.duplicate(true)})


func clear_slot(index: int) -> Dictionary:
	_ensure_loaded()
	if _beschermd:
		return _fout("io")
	if index < 0 or index >= SLOT_COUNT:
		return _fout("index")
	if _slots[index] == null:
		return _goed()
	var vorige = _slots[index]
	_slots[index] = null
	if not _opslaan():
		_slots[index] = vorige
		return _fout("io")
	profile_changed.emit(index)
	return _goed()


## Blijvende laag: rang (profile_exp), stats_seen en cosmetica. Geen run-stats of items.
func set_progress(index: int, profile_exp: int, best_floor: int, runs: int, unlocks: Array, applied_grants: Array) -> Dictionary:
	_ensure_loaded()
	if _beschermd:
		return _fout("io")
	if index < 0 or index >= SLOT_COUNT:
		return _fout("index")
	if _slots[index] == null:
		return _fout("vacant")
	if _als_int(profile_exp, 0, MAX_PROFILE_EXP) == null:
		return _fout("progress")
	if _als_int(best_floor, 0, MAX_BEST_FLOOR) == null:
		return _fout("progress")
	if _als_int(runs, 0, MAX_RUNS) == null:
		return _fout("progress")
	var ontgrendeld: Variant = _id_lijst(unlocks, MAX_UNLOCKS, MAX_UNLOCK_LEN)
	var grants: Variant = _id_lijst(applied_grants, MAX_GRANTS, MAX_GRANT_LEN)
	if ontgrendeld == null or grants == null:
		return _fout("progress")
	var vorige: Dictionary = (_slots[index] as Dictionary).duplicate(true)
	var slot: Dictionary = vorige.duplicate(true)
	slot["profile_exp"] = profile_exp
	slot["unlocks"] = ontgrendeld
	slot["stats_seen"] = {"best_floor": best_floor, "runs": runs}
	slot["applied_grants"] = grants
	_slots[index] = slot
	if not _opslaan():
		_slots[index] = vorige
		return _fout("io")
	profile_changed.emit(index)
	return _goed({"slot": slot.duplicate(true)})


func export_code() -> Dictionary:
	_ensure_loaded()
	return encode_profile_code(document(), FORMAT_VERSION)


func import_code(code: String) -> Dictionary:
	var dec := decode_profile_code(code)
	if not bool(dec.get("ok", false)):
		import_refused.emit(str(dec.get("reason", "corrupt")))
		return dec
	_ensure_loaded()
	if _beschermd:
		import_refused.emit("io")
		return _fout("io")
	var vorige: Array = _slots.duplicate(true)
	_slots = (dec.get("slots", _lege_slots()) as Array).duplicate(true)
	if not _opslaan():
		_slots = vorige
		import_refused.emit("io")
		return _fout("io")
	profile_changed.emit(-1)
	var uit := _goed()
	uit["message"] = "Profiel geïmporteerd."
	return uit


# ---------------------------------------------------------------- intern


func _ensure_loaded() -> void:
	if _geladen or _bezig:
		return
	load_profile()


func _lege_slots() -> Array:
	return [null, null, null]


func _nieuwe_uid() -> String:
	var crypto := Crypto.new()
	for _poging in 8:
		var b := crypto.generate_random_bytes(4)
		if b.size() != UID_HEX / 2:
			continue
		var uid := b.hex_encode().to_lower()
		if _uid_ok(uid) and _uid_vrij(uid):
			return uid
	return ""


func _uid_vrij(uid: String) -> bool:
	for s in _slots:
		if s is Dictionary and str(s.get("uid", "")) == uid:
			return false
	return true


func _opslaan() -> bool:
	if _beschermd:
		return false
	var tekst := JSON.stringify(_document_van(_slots), "  ")
	return _schrijf_tekst(PATH, tekst)


func _backup_ruw(ruw: PackedByteArray) -> String:
	var doel := PATH + ".bak"
	if FileAccess.file_exists(doel):
		_backup_volg += 1
		doel = "user://online_profile.%d_%d.bak" % [Time.get_ticks_msec(), _backup_volg]
	if _schrijf_bytes(doel, ruw):
		return doel
	return ""


## Geldige UTF-8, inclusief ASCII. Ongeldige reeksen gaan niet door de JSON-parser.
static func _utf8_ok(ruw: PackedByteArray) -> bool:
	var i := 0
	while i < ruw.size():
		var c := int(ruw[i]) & 0xFF
		var nodig := 1
		if c <= 0x7F:
			nodig = 1
		elif c >= 0xC2 and c <= 0xDF:
			nodig = 2
		elif c >= 0xE0 and c <= 0xEF:
			nodig = 3
		elif c >= 0xF0 and c <= 0xF4:
			nodig = 4
		else:
			return false
		if i + nodig > ruw.size():
			return false
		for j in range(1, nodig):
			var volg := int(ruw[i + j]) & 0xFF
			if volg < 0x80 or volg > 0xBF:
				return false
		i += nodig
	return true


static func _beoordeel_bytes(ruw: PackedByteArray) -> Dictionary:
	if ruw.is_empty() or not _utf8_ok(ruw):
		return _fout("corrupt")
	var tekst := ruw.get_string_from_utf8().strip_edges()
	if not tekst.begins_with("{"):
		return _fout("corrupt")
	var data: Variant = JSON.parse_string(tekst)
	if data == null or not (data is Dictionary):
		return _fout("corrupt")
	var doc: Dictionary = data
	if _als_int(doc.get("version"), 1, 1) == null:
		return _fout("version")
	var slots: Variant = _slots_uit_json(doc.get("slots"))
	if slots == null:
		return _fout("corrupt")
	return _goed({"slots": slots})


## null = ongeldig. Een korte array (0..3) wordt aangevuld met lege slots.
static func _slots_uit_json(raw: Variant) -> Variant:
	if not (raw is Array):
		return null
	var arr: Array = raw
	if arr.size() > SLOT_COUNT:
		return null
	var uit := _lege_slots_static()
	var gezien: Array[String] = []
	for i in arr.size():
		if arr[i] == null:
			continue
		var slot := _slot_uit_json(arr[i])
		if slot.is_empty():
			return null
		var uid := str(slot.get("uid", ""))
		if uid in gezien:
			return null
		gezien.append(uid)
		uit[i] = slot
	return uit


static func _lege_slots_static() -> Array:
	return [null, null, null]


static func _slot_uit_json(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var toegestaan := ["uid", "name", "class", "look", "profile_exp", "unlocks", "stats_seen", "applied_grants"]
	for k in d.keys():
		if not (str(k) in toegestaan):
			return {}
	if d.size() != toegestaan.size():
		return {}
	var uid := str(d.get("uid", ""))
	if not _uid_ok(uid):
		return {}
	var naam := str(d.get("name", ""))
	if not _naam_ok(naam):
		return {}
	var klasse := str(d.get("class", ""))
	if not CLASS_INFO.has(klasse):
		return {}
	if not (d.get("look") is Dictionary) or not _look_ok(d.get("look")):
		return {}
	var exp: Variant = _als_int(d.get("profile_exp"), 0, MAX_PROFILE_EXP)
	if exp == null:
		return {}
	var ontgrendeld: Variant = _id_lijst(d.get("unlocks"), MAX_UNLOCKS, MAX_UNLOCK_LEN)
	var grants: Variant = _id_lijst(d.get("applied_grants"), MAX_GRANTS, MAX_GRANT_LEN)
	if ontgrendeld == null or grants == null:
		return {}
	if not (d.get("stats_seen") is Dictionary):
		return {}
	var stats: Dictionary = d.get("stats_seen")
	if stats.size() != 2 or not stats.has("best_floor") or not stats.has("runs"):
		return {}
	var vloer: Variant = _als_int(stats.get("best_floor"), 0, MAX_BEST_FLOOR)
	var runs: Variant = _als_int(stats.get("runs"), 0, MAX_RUNS)
	if vloer == null or runs == null:
		return {}
	return _maak_slot_static(uid, naam, klasse, _canon_look(d.get("look")), int(exp), ontgrendeld as Array, int(vloer), int(runs), grants as Array)


static func _document_van(slots: Array) -> Dictionary:
	var lijst: Array = []
	for i in SLOT_COUNT:
		if i >= slots.size() or slots[i] == null:
			lijst.append(null)
		else:
			lijst.append((slots[i] as Dictionary).duplicate(true))
	return {"version": FORMAT_VERSION, "slots": lijst}


func _maak_slot(uid: String, naam: String, klasse: String, look: Dictionary) -> Dictionary:
	return _maak_slot_static(uid, naam, klasse, look, 0, [], 0, 0, [])


static func _maak_slot_static(uid: String, naam: String, klasse: String, look: Dictionary, exp: int, unlocks: Array, vloer: int, runs: int, grants: Array) -> Dictionary:
	return {
		"uid": uid,
		"name": naam,
		"class": klasse,
		"look": look.duplicate(true),
		"profile_exp": exp,
		"unlocks": unlocks.duplicate(),
		"stats_seen": {"best_floor": vloer, "runs": runs},
		"applied_grants": grants.duplicate(),
	}


static func _look_ok(look: Dictionary) -> bool:
	if look.size() != LOOK_KEYS.size():
		return false
	for k in LOOK_KEYS:
		if not look.has(k):
			return false
		if _als_int(look[k], 0, int(LOOK_MAX[k])) == null:
			return false
	return true


static func _canon_look(look: Dictionary) -> Dictionary:
	var uit := {}
	for k in LOOK_KEYS:
		uit[k] = int(_als_int(look[k], 0, int(LOOK_MAX[k])))
	return uit


static func _look_som(b: PackedByteArray) -> int:
	var som := 0
	for i in 15:
		som = (som + int(b[i])) & 0xFF
	return som


static func _naam_ok(naam: String) -> bool:
	if naam.length() < 1 or naam.length() > NAME_MAX:
		return false
	for i in naam.length():
		var c := naam.unicode_at(i)
		var letter := (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
		if not letter:
			return false
	return true


static func _uid_ok(uid: String) -> bool:
	if uid.length() != UID_HEX:
		return false
	for i in uid.length():
		var c := uid.unicode_at(i)
		var hex := (c >= 48 and c <= 57) or (c >= 97 and c <= 102)
		if not hex:
			return false
	return true


static func _id_tekens(id: String, max_len: int) -> bool:
	if id.length() < 1 or id.length() > max_len:
		return false
	for i in id.length():
		var c := id.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 97 and c <= 122) or c == 95
		if not ok:
			return false
	return true


static func _id_lijst(raw: Variant, max_count: int, max_len: int) -> Variant:
	if not (raw is Array):
		return null
	var arr: Array = raw
	if arr.size() > max_count:
		return null
	var uit: Array = []
	for item in arr:
		if not (item is String) or not _id_tekens(item, max_len):
			return null
		if item in uit:
			return null
		uit.append(item)
	return uit


static func _als_int(v: Variant, lo: int, hi: int) -> Variant:
	var n := 0
	if v is bool or typeof(v) == TYPE_BOOL:
		return null
	if v is int:
		n = v
	elif v is float:
		if v != floor(v):
			return null
		n = int(v)
	else:
		return null
	if n < lo or n > hi:
		return null
	return n


static func _normaliseer_code(code: String) -> Dictionary:
	if code.length() > MAX_RAW_CHARS:
		return _fout("too_long")
	var uit := ""
	for i in code.length():
		var ch := code[i]
		var c := ch.unicode_at(0)
		if c <= 32 or c == 45:
			continue
		uit += ch.to_upper()
	if uit.is_empty():
		return _fout("empty")
	if uit.length() > MAX_CODE_CHARS:
		return _fout("too_long")
	return _goed({"code": uit})


static func _mul31_add(n: PackedByteArray, digit: int) -> PackedByteArray:
	if n.is_empty():
		if digit == 0:
			return PackedByteArray()
		return PackedByteArray([digit])
	var out := PackedByteArray()
	var carry := digit
	for i in range(n.size() - 1, -1, -1):
		var cur := int(n[i]) * 31 + carry
		out.append(cur % 256)
		carry = int(cur / 256)
	while carry > 0:
		out.append(carry % 256)
		carry = int(carry / 256)
	out.reverse()
	return out


static func _append_u32(b: PackedByteArray, n: int) -> void:
	var v := n & 0xFFFFFFFF
	b.append((v >> 24) & 0xFF)
	b.append((v >> 16) & 0xFF)
	b.append((v >> 8) & 0xFF)
	b.append(v & 0xFF)


static func _read_u32(b: PackedByteArray, at: int) -> int:
	return ((int(b[at]) & 0xFF) << 24) | ((int(b[at + 1]) & 0xFF) << 16) | ((int(b[at + 2]) & 0xFF) << 8) | (int(b[at + 3]) & 0xFF)


static func _fout(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": str(MELDING.get(reason, reason))}


static func _goed(extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true, "reason": "", "message": ""}
	for k in extra.keys():
		d[k] = extra[k]
	return d


static func _pad_ok(path: String) -> bool:
	if path in VERBODEN_PADEN or path.contains("..") or path.contains("\\"):
		return false
	if path == PATH or path == PATH + ".tmp":
		return true
	var rest := ""
	if path.begins_with("user://online_profile.") and path.ends_with(".bak.tmp"):
		rest = path.trim_prefix("user://online_profile.").trim_suffix(".bak.tmp")
	elif path.begins_with("user://online_profile.") and path.ends_with(".bak"):
		rest = path.trim_prefix("user://online_profile.").trim_suffix(".bak")
	else:
		return false
	if rest == "json":
		return true
	if rest.is_empty():
		return false
	for i in rest.length():
		var c := rest.unicode_at(i)
		if not ((c >= 48 and c <= 57) or c == 95):
			return false
	return true


static func _verwijder(path: String) -> void:
	if not _pad_ok(path):
		push_error("OnlineProfile wist geen vreemd pad: %s" % path)
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _schrijf_bytes(path: String, data: PackedByteArray) -> bool:
	if not _pad_ok(path):
		push_error("OnlineProfile weigert pad: %s" % path)
		return false
	var tmp := path + ".tmp"
	_verwijder(tmp)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.flush()
	var fout := f.get_error()
	f.close()
	if fout != OK:
		_verwijder(tmp)
		return false
	return _vervang(tmp, path)


static func _schrijf_tekst(path: String, tekst: String) -> bool:
	if not _pad_ok(path):
		push_error("OnlineProfile weigert pad: %s" % path)
		return false
	var tmp := path + ".tmp"
	_verwijder(tmp)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(tekst)
	f.flush()
	var fout := f.get_error()
	f.close()
	if fout != OK:
		_verwijder(tmp)
		return false
	var terug := FileAccess.get_file_as_string(tmp)
	if terug != tekst:
		_verwijder(tmp)
		return false
	return _vervang(tmp, path)


static func _vervang(tmp: String, path: String) -> bool:
	if not _pad_ok(tmp) or not _pad_ok(path):
		push_error("OnlineProfile weigert pad: %s" % path)
		return false
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		_verwijder(tmp)
		return false
	return true
