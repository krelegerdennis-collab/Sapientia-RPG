extends Node
## Stresstest op het importeren van de online profielcode (--profilecodefuzztest).
## Een geplakte code is vijandige invoer. Deze suite probeert import_code te breken met
## kapotte tekst, kapotte envelop, geldige crc met onzin-JSON, verkeerde types, grenzen,
## en een vaste-seed fuzz. Eisen bij elke poging:
##   - geen crash of SCRIPT ERROR, altijd een Dictionary met ok/reason/message terug;
##   - weigering: bekende reden, nette melding, import_refused precies 1x, en het profiel
##     (geheugen én bestand) blijft byte-gelijk;
##   - acceptatie: het opgeslagen profiel is strikt geldig en laadt terug tot hetzelfde document.
## Start: godot --path . -- --profilecodefuzztest

const Profiel := preload("res://scripts/online/online_profile.gd")

const SEED := 0x5A91E7
const MUTATIE_RONDES := 300
const JSON_RONDES := 300
const RUIS_RONDES := 120
const ROUNDTRIP_RONDES := 60
## Ruime grens: een code van MAX_CODE_CHARS tekens mag de telefoon niet seconden vastzetten.
const MAX_IMPORT_MS := 1500

## Waarden die in een veld terechtkomen bij de JSON-fuzz.
const VIJANDIG: Array = [
	null, true, false, 0, -1, 1.5, 1e300, -1e300, 9.3e18, 999999, 1000000, 100, 101, 9999, 10000,
	"", "x", "1", "abcd1234", "ABCD1234", "Mira", "mage", "bard", "hair_3", "Ä", "a b",
	[], [1], ["x"], [[[]]], {}, {"a": 1}, {"best_floor": 0, "runs": 0},
]

var failures := 0
var passes := 0
var _rng := RandomNumberGenerator.new()
var _p: Variant = null
var _geweigerd: Array[String] = []
var _basis_code := ""
var _basis_doc: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: test klaar binnen 300 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 20.0)
	_rng.seed = SEED
	_opzet()
	_tekst_tests()
	_checksum_tests()
	_envelop_tests()
	_utf8_tests()
	_json_vorm_tests()
	_versie_tests()
	_veld_tests()
	_voortgang_tests()
	_lijst_tests()
	_uid_tests()
	_mutatie_fuzz()
	_json_fuzz()
	_ruis_fuzz()
	_roundtrip_fuzz()
	_snelheid_tests()
	_eind_tests()
	print("PROFILECODEFUZZTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- opzet


func _opzet() -> void:
	_wis_online()
	_p = Profiel.new()
	_p.load_profile()
	_p.import_refused.connect(func(reason: String) -> void: _geweigerd.append(reason))
	var look := {
		"body": 0, "skin": 3, "hair": 5, "hair_color": 7,
		"top": 3, "top_color": 5, "bottom": 2, "bottom_color": 5, "head": 2,
	}
	var ok := bool(_p.create_slot(0, "Mira", "priest", look).get("ok", false))
	ok = ok and bool(_p.create_slot(1, "Dax", "warrior").get("ok", false))
	ok = ok and bool(_p.create_slot(2, "Seren", "archer").get("ok", false))
	ok = ok and bool(_p.set_progress(0, 1234, 37, 12, ["hair_3", "top_1"], ["easy_clear"]).get("ok", false))
	check("opzet: drie slots met voortgang", ok)
	_basis_doc = _p.document()
	_basis_code = str(_p.export_code().get("code", ""))
	check("opzet: basiscode gemaakt", _basis_code != "")
	check("opzet: basisprofiel is strikt geldig", _strikt_ok(_basis_doc))
	print("INFO  seed 0x%X, basiscode %d tekens" % [SEED, _basis_code.length()])


# ---------------------------------------------------------------- vaste gevallen


func _tekst_tests() -> void:
	_verwacht("leeg", "", "empty")
	_verwacht("alleen wit en streepjes", "  \n\t- - -\r ", "empty")
	_verwacht("alleen NUL-tekens", "\u0000\u0000", "empty")
	_verwacht("ruw te lang (wit)", " ".repeat(Profiel.MAX_RAW_CHARS + 1), "too_long")
	_verwacht("te lang na normaliseren", "3".repeat(Profiel.MAX_CODE_CHARS + 1), "too_long")
	for teken in ["0", "O", "1", "I", "L", "!", "é", "€", "🙂", "_", "+", "="]:
		_verwacht("vreemd teken '%s' midden in code" % teken, _basis_code.insert(_basis_code.length() / 2, teken), "alphabet")
	_verwacht("alleen nullen-cijfer", "2".repeat(12), "corrupt")
	_verwacht("heel kort", "3", "corrupt")
	_verwacht("negen bytes", Profiel.encode_base31(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9])), "corrupt")
	_verwacht("laatste teken weg", _basis_code.substr(0, _basis_code.length() - 1), "*")
	_verwacht("teken erbij", _basis_code + "3", "*")
	_verwacht("halve code", _basis_code.substr(0, _basis_code.length() / 2), "*")
	_verwacht("code twee keer", _basis_code + _basis_code, "*")
	_verwacht("kleine letters, spaties, streepjes en regeleinden", _rommel_opmaak(_basis_code), "OK")
	_verwacht("voorloop-2 (waarde nul) verandert niets", "222" + _basis_code, "OK")


func _checksum_tests() -> void:
	var fout := 0
	var n := 0
	var stap: int = maxi(1, _basis_code.length() / 60)
	for i in range(0, _basis_code.length(), stap):
		var oud := _basis_code[i]
		var nieuw := Profiel.CODE_ALFABET[(Profiel.CODE_ALFABET.find(oud) + 1 + i % 29) % 31]
		var code := _basis_code.substr(0, i) + nieuw + _basis_code.substr(i + 1)
		n += 1
		var r := _probeer(code, "*")
		if r != "":
			fout += 1
			print("INFO  teken %d vervangen: %s" % [i, r])
	check("%d enkele tekenwissels allemaal geweigerd" % n, fout == 0)
	fout = 0
	n = 0
	for i in range(0, _basis_code.length() - 1, stap):
		if _basis_code[i] == _basis_code[i + 1]:
			continue
		var code := _basis_code.substr(0, i) + _basis_code[i + 1] + _basis_code[i] + _basis_code.substr(i + 2)
		n += 1
		if _probeer(code, "*") != "":
			fout += 1
	check("%d buurwissels allemaal geweigerd" % n, fout == 0)
	var plain := JSON.stringify(_basis_doc).to_utf8_buffer()
	_verwacht("crc-byte omgedraaid", _wire_code(plain, 1, -1, PackedByteArray(), true), "checksum")
	_verwacht("geldige crc, eigen envelop", _wire_code(plain), "OK")


func _envelop_tests() -> void:
	var doc := _basis_doc.duplicate(true)
	for versie in [2, 3, 127, 255]:
		var c: Dictionary = Profiel.encode_profile_code(doc, versie)
		_verwacht("envelop-versie %d" % versie, str(c.get("code", "")), "version")
	for versie in [0, -1, 256, 99999]:
		var c2: Dictionary = Profiel.encode_profile_code(doc, versie)
		check("encoder weigert envelop-versie %d" % versie, c2.get("ok") == false and c2.get("reason") == "version")
	check("envelop-versie 0 is niet als code te schrijven", Profiel.encode_base31(PackedByteArray([0, 1, 2])) == "")
	var plain := JSON.stringify(doc).to_utf8_buffer()
	for claim in [0, 1, plain.size() - 1, plain.size() + 1, Profiel.MAX_JSON_BYTES + 1, 0x7FFFFFFF, 0xFFFFFFFF]:
		_verwacht("plain-lengte %d gelogen" % claim, _wire_code(plain, 1, claim), "corrupt")
	for i in 6:
		var rommel := _rng_bytes(4 + _rng.randi_range(0, 200))
		_verwacht("gecomprimeerd deel is rommel #%d" % i, _wire_code(plain, 1, plain.size(), rommel), "corrupt")
	var nul := PackedByteArray()
	nul.resize(1 << 20)
	nul.fill(0x20)
	var bom := nul.compress(FileAccess.COMPRESSION_DEFLATE)
	_verwacht("deflate-bom (1 MiB) met max lengte", _wire_code(nul, 1, Profiel.MAX_JSON_BYTES, bom), "corrupt")
	_verwacht("deflate-bom met eerlijke lengte", _wire_code(nul, 1, nul.size(), bom), "corrupt")
	var groot := ("{\"version\":1,\"slots\":[],\"x\":\"%s\"}" % "a".repeat(Profiel.MAX_JSON_BYTES)).to_utf8_buffer()
	_verwacht("JSON boven MAX_JSON_BYTES", _wire_code(groot), "corrupt")
	var te_groot_doc := {"version": 1, "slots": [], "x": "a".repeat(Profiel.MAX_JSON_BYTES)}
	check("encoder weigert te groot document", Profiel.encode_profile_code(te_groot_doc).get("reason") == "too_long")
	_verwacht("gzip i.p.v. deflate", _wire_code(plain, 1, plain.size(), plain.compress(FileAccess.COMPRESSION_GZIP)), "corrupt")
	_verwacht("ongecomprimeerd", _wire_code(plain, 1, plain.size(), plain), "corrupt")


func _utf8_tests() -> void:
	var gevallen := {
		"ff fe": PackedByteArray([0xFF, 0xFE]),
		"overlong C0 AF": PackedByteArray([0xC0, 0xAF]),
		"overlong E0 80 AF": PackedByteArray([0xE0, 0x80, 0xAF]),
		"overlong F0 80 80 AF": PackedByteArray([0xF0, 0x80, 0x80, 0xAF]),
		"surrogaat ED A0 80": PackedByteArray([0xED, 0xA0, 0x80]),
		"boven U+10FFFF F4 90 80 80": PackedByteArray([0xF4, 0x90, 0x80, 0x80]),
		"afgebroken E2 82": PackedByteArray([0xE2, 0x82]),
		"NUL-byte": PackedByteArray([0x00]),
	}
	for naam in gevallen.keys():
		var b := "{\"version\":1,\"slots\":[],\"x\":\"".to_utf8_buffer()
		b.append_array(gevallen[naam])
		b.append_array("\"}".to_utf8_buffer())
		_verwacht("ongeldige UTF-8 in JSON: %s" % naam, _wire_code(b), "corrupt")
	var goed := "{\"version\":1,\"slots\":[],\"x\":\"é€🙂\"}".to_utf8_buffer()
	_verwacht("geldige multibyte UTF-8 in onbekend topveld", _wire_code(goed), "OK")


func _json_vorm_tests() -> void:
	for tekst in ["", " ", "{", "}", "nope", "[]", "\"x\"", "123", "null", "true", "[{\"version\":1,\"slots\":[]}]",
			"{\"version\":1,\"slots\":[]", "{'version':1}", "{\"version\":1 \"slots\":[]}"]:
		var plain := (tekst as String).to_utf8_buffer()
		if plain.size() < 2:
			plain.append_array("  ".to_utf8_buffer())
		_verwacht("geen geldig document: %s" % tekst, _wire_code(plain), "*")
	# De JSON-parser van Godot slikt een komma op het eind; dat mag, zolang het resultaat strikt geldig is.
	_verwacht("komma op het eind (Godot-JSON is mild)", _wire_code("{\"version\":1,\"slots\":[],}".to_utf8_buffer()), "*?")
	_verwacht("leeg object (geen versie)", _wire_code("{}".to_utf8_buffer()), "version")
	var diep := "[".repeat(1400) + "]".repeat(1400)
	_verwacht("te diepe JSON (1400 niveaus)", _wire_code(("{\"version\":1,\"slots\":%s}" % diep).to_utf8_buffer()), "*")
	var middel := "[".repeat(300) + "]".repeat(300)
	_verwacht("diepe JSON (300) als slots", _wire_code(("{\"version\":1,\"slots\":[%s]}" % middel).to_utf8_buffer()), "schema")
	var slot := _voorbeeld_slot()
	var s_tekst := JSON.stringify(slot)
	var diep_look := s_tekst.replace("\"look\":{", "\"look\":%s,\"_\":{" % middel)
	_verwacht("diepe JSON (300) als look", _wire_code(("{\"version\":1,\"slots\":[%s]}" % diep_look).to_utf8_buffer()), "schema")
	_verwacht("diepe JSON als uid", _doc_code({"version": 1, "slots": [_met(slot, "uid", _nest(200))]}), "schema")
	var veel := []
	for i in 300:
		veel.append(i)
	_verwacht("lange array als slots", _doc_code({"version": 1, "slots": veel}), "schema")
	_verwacht("vier slots", _doc_code({"version": 1, "slots": [null, null, null, null]}), "schema")
	_verwacht("lege slots-lijst", _doc_code({"version": 1, "slots": []}), "OK")
	_verwacht("onbekend topveld wordt genegeerd", _doc_code({"version": 1, "slots": [null, slot], "extra": [1, 2]}), "OK")


func _versie_tests() -> void:
	for v in [0, 2, -1, 99, 1.5, "1", true, false, null, [1], {"v": 1}, 1e300]:
		_verwacht("JSON-versie %s" % str(v), _doc_code({"version": v, "slots": []}), "version")
	_verwacht("JSON-versie ontbreekt", _doc_code({"slots": []}), "version")
	_verwacht("JSON-versie 1.0 (float) mag", _doc_code({"version": 1.0, "slots": []}), "OK")


func _veld_tests() -> void:
	var slot := _voorbeeld_slot()
	for v in [null, "x", 1, true, {}, {"0": slot}]:
		_verwacht("slots is %s" % str(v), _doc_code({"version": 1, "slots": v}), "schema")
	for v in [1, true, "x", [], [slot]]:
		_verwacht("slot is %s" % str(v), _doc_code({"version": 1, "slots": [v]}), "schema")
	for k in slot.keys():
		var zonder: Dictionary = slot.duplicate(true)
		zonder.erase(k)
		_verwacht("veld %s ontbreekt" % k, _doc_code({"version": 1, "slots": [zonder]}), "schema")
	_verwacht("extra veld in slot", _doc_code({"version": 1, "slots": [_met(slot, "cape", 1)]}), "schema")
	# verkeerde types: alleen een echte String telt als uid/naam/klasse
	for v in [12345678, 12345678.0, true, null, [], ["abcd1234"], {"uid": "abcd1234"}]:
		_verwacht("uid als %s" % JSON.stringify(v), _doc_code({"version": 1, "slots": [_met(slot, "uid", v)]}), "schema")
	for v in ["ABCD1234", "abcd123", "abcd12345", "abcdefgz", " abcd123", "abcd-123", "\u0000bcd1234"]:
		_verwacht("uid '%s'" % v.c_escape(), _doc_code({"version": 1, "slots": [_met(slot, "uid", v)]}), "schema")
	for v in [true, false, 12, 1.5, null, ["Mira"], {"n": "Mira"}]:
		_verwacht("naam als %s" % JSON.stringify(v), _doc_code({"version": 1, "slots": [_met(slot, "name", v)]}), "schema")
	for v in ["", "Abcdef", "A1", "Mïra", "A B", " Mira", "Mira\n", "M_ra", "a".repeat(2000)]:
		_verwacht("naam '%s'" % v.substr(0, 12).c_escape(), _doc_code({"version": 1, "slots": [_met(slot, "name", v)]}), "schema")
	_verwacht("naam van 5 letters mag", _doc_code({"version": 1, "slots": [_met(slot, "name", "Seren")]}), "OK")
	for v in ["bard", "Mage", "MAGE", " mage", "mage ", "", "dennis", 1, true, null, ["mage"]]:
		_verwacht("klasse %s" % JSON.stringify(v), _doc_code({"version": 1, "slots": [_met(slot, "class", v)]}), "schema")
	for klasse in Profiel.CLASS_INFO.keys():
		_verwacht("klasse %s mag" % klasse, _doc_code({"version": 1, "slots": [_met(slot, "class", klasse)]}), "OK")
	# look
	for k in Profiel.LOOK_KEYS:
		var hoog: Dictionary = Profiel.default_look()
		hoog[k] = int(Profiel.LOOK_MAX[k]) + 1
		_verwacht("look %s boven LOOK_MAX" % k, _doc_code({"version": 1, "slots": [_met(slot, "look", hoog)]}), "schema")
		var laag: Dictionary = Profiel.default_look()
		laag[k] = -1
		_verwacht("look %s negatief" % k, _doc_code({"version": 1, "slots": [_met(slot, "look", laag)]}), "schema")
		var grens: Dictionary = Profiel.default_look()
		grens[k] = int(Profiel.LOOK_MAX[k])
		_verwacht("look %s op LOOK_MAX mag" % k, _doc_code({"version": 1, "slots": [_met(slot, "look", grens)]}), "OK")
		var zonder: Dictionary = Profiel.default_look()
		zonder.erase(k)
		_verwacht("look %s ontbreekt" % k, _doc_code({"version": 1, "slots": [_met(slot, "look", zonder)]}), "schema")
	for v in [0.5, "1", true, null, [], {}, 1e300, -1e300, 9.3e18, -9.3e18]:
		var raar: Dictionary = Profiel.default_look()
		raar["hair"] = v
		_verwacht("look hair als %s" % JSON.stringify(v), _doc_code({"version": 1, "slots": [_met(slot, "look", raar)]}), "schema")
	var extra: Dictionary = Profiel.default_look()
	extra["cape"] = 0
	_verwacht("look met extra sleutel", _doc_code({"version": 1, "slots": [_met(slot, "look", extra)]}), "schema")
	for v in [[0, 0, 0, 0, 0, 0, 0, 0, 0], "AQAAAAAAAAAAAAAAAAAAAQ==", null, 0]:
		_verwacht("look als %s" % JSON.stringify(v), _doc_code({"version": 1, "slots": [_met(slot, "look", v)]}), "schema")


func _voortgang_tests() -> void:
	var slot := _voorbeeld_slot()
	var grenzen := {
		"profile_exp": Profiel.MAX_PROFILE_EXP,
		"best_floor": Profiel.MAX_BEST_FLOOR,
		"runs": Profiel.MAX_RUNS,
	}
	for veld in grenzen.keys():
		var hi := int(grenzen[veld])
		for v in [-1, -0.5, hi + 1, hi + 0.5, 1e300, -1e300, 9.3e18, -9.3e18, 1.8446744073709552e19, "5", true, null, [], {}]:
			_verwacht("%s = %s" % [veld, JSON.stringify(v)], _doc_code({"version": 1, "slots": [_met_voortgang(slot, veld, v)]}), "schema")
		for v in [0, hi, float(hi)]:
			_verwacht("%s = %s mag" % [veld, JSON.stringify(v)], _doc_code({"version": 1, "slots": [_met_voortgang(slot, veld, v)]}), "OK")
	for v in [null, [], [0, 0], "x", {"best_floor": 0}, {"best_floor": 0, "runs": 0, "x": 0}, {"best_floor": 0, "run": 0}]:
		_verwacht("stats_seen %s" % JSON.stringify(v), _doc_code({"version": 1, "slots": [_met(slot, "stats_seen", v)]}), "schema")


func _lijst_tests() -> void:
	var slot := _voorbeeld_slot()
	var lijsten := {
		"unlocks": [Profiel.MAX_UNLOCKS, Profiel.MAX_UNLOCK_LEN],
		"applied_grants": [Profiel.MAX_GRANTS, Profiel.MAX_GRANT_LEN],
	}
	for veld in lijsten.keys():
		var max_n := int(lijsten[veld][0])
		var max_len := int(lijsten[veld][1])
		_verwacht("%s: precies %d mag" % [veld, max_n], _doc_code({"version": 1, "slots": [_met(slot, veld, _ids(max_n))]}), "OK")
		_verwacht("%s: %d is te veel" % [veld, max_n + 1], _doc_code({"version": 1, "slots": [_met(slot, veld, _ids(max_n + 1))]}), "schema")
		_verwacht("%s: 300 is te veel" % veld, _doc_code({"version": 1, "slots": [_met(slot, veld, _ids(300))]}), "*")
		_verwacht("%s: id van %d tekens mag" % [veld, max_len], _doc_code({"version": 1, "slots": [_met(slot, veld, ["a".repeat(max_len)])]}), "OK")
		_verwacht("%s: id van %d tekens te lang" % [veld, max_len + 1], _doc_code({"version": 1, "slots": [_met(slot, veld, ["a".repeat(max_len + 1)])]}), "schema")
		_verwacht("%s: id van 2000 tekens" % veld, _doc_code({"version": 1, "slots": [_met(slot, veld, ["a".repeat(2000)])]}), "*")
		for item in ["", "Hair", "a-b", "a b", "é", "hair\n", "\u0000", 1, 1.0, true, null, [], ["a"], {}]:
			_verwacht("%s: item %s" % [veld, JSON.stringify(item)], _doc_code({"version": 1, "slots": [_met(slot, veld, [item])]}), "schema")
		_verwacht("%s: dubbel item" % veld, _doc_code({"version": 1, "slots": [_met(slot, veld, ["a", "a"])]}), "schema")
		for v in [null, "a", 1, {}, {"0": "a"}, true]:
			_verwacht("%s als %s" % [veld, JSON.stringify(v)], _doc_code({"version": 1, "slots": [_met(slot, veld, v)]}), "schema")


func _uid_tests() -> void:
	var a := _voorbeeld_slot()
	var b := _met(_voorbeeld_slot(), "name", "Dax")
	_verwacht("dubbele uid in slot 0 en 1", _doc_code({"version": 1, "slots": [a, b]}), "schema")
	_verwacht("dubbele uid in slot 0 en 2", _doc_code({"version": 1, "slots": [a, null, b]}), "schema")
	_verwacht("dubbele uid in drie slots", _doc_code({"version": 1, "slots": [a, b, a]}), "schema")
	var c := _met(b, "uid", "abcd1235")
	_verwacht("zelfde naam, andere uid mag", _doc_code({"version": 1, "slots": [a, _met(c, "name", "Mira")]}), "OK")


# ---------------------------------------------------------------- fuzz (vaste seed)


func _mutatie_fuzz() -> void:
	var fout := 0
	var geaccepteerd := 0
	for ronde in MUTATIE_RONDES:
		var code := _muteer(_basis_code, 1 + _rng.randi_range(0, 3))
		var r := _probeer(code, "*?")
		if r == "ok":
			geaccepteerd += 1
			r = "" if _p.document() == _basis_doc else "geaccepteerd met ander profiel"
		if r != "":
			fout += 1
			if fout <= 5:
				print("INFO  mutatie %d: %s (%s)" % [ronde, r, code.substr(0, 40)])
	print("INFO  mutatie-fuzz: %d rondes, %d geaccepteerd (alleen gelijkwaardige codes)" % [MUTATIE_RONDES, geaccepteerd])
	check("mutatie-fuzz %d rondes: invarianten heel" % MUTATIE_RONDES, fout == 0)


func _json_fuzz() -> void:
	var fout := 0
	var ok_n := 0
	for ronde in JSON_RONDES:
		var doc := _basis_doc.duplicate(true)
		for _stap in 1 + _rng.randi_range(0, 2):
			_verstoor(doc)
		var code := _doc_code(doc)
		if code == "":
			continue
		var r := _probeer(code, "*?")
		if r == "ok":
			ok_n += 1
			r = ""
			_herstel()
		if r != "":
			fout += 1
			if fout <= 5:
				print("INFO  json-fuzz %d: %s (%s)" % [ronde, r, JSON.stringify(doc).substr(0, 120)])
	print("INFO  json-fuzz: %d rondes, %d geaccepteerd (strikt geldig)" % [JSON_RONDES, ok_n])
	check("json-fuzz %d rondes: invarianten heel" % JSON_RONDES, fout == 0)


func _ruis_fuzz() -> void:
	var fout := 0
	for ronde in RUIS_RONDES:
		var code := ""
		match ronde % 3:
			0:
				var b := _rng_bytes(10 + _rng.randi_range(0, 400))
				b[0] = 1
				code = Profiel.encode_base31(b)
			1:
				var plain := _rng_bytes(2 + _rng.randi_range(0, 300))
				code = _wire_code(plain)
			_:
				for _i in _rng.randi_range(1, 600):
					code += Profiel.CODE_ALFABET[_rng.randi_range(0, 30)]
		if _probeer(code, "*") != "":
			fout += 1
	check("ruis-fuzz %d rondes allemaal geweigerd" % RUIS_RONDES, fout == 0)


func _roundtrip_fuzz() -> void:
	var fout := 0
	for ronde in ROUNDTRIP_RONDES:
		var doc := _willekeurig_document()
		var c: Dictionary = Profiel.encode_profile_code(doc)
		var code := str(c.get("code", ""))
		if code == "":
			fout += 1
			print("INFO  roundtrip %d: export mislukt (%s)" % [ronde, str(c.get("reason"))])
			continue
		var r := _probeer(code, "OK")
		if r == "" and _p.document() != doc:
			r = "document na import anders"
		if r == "" and str(_p.export_code().get("code", "")) != code:
			r = "export na import geeft andere code"
		if r != "":
			fout += 1
			if fout <= 5:
				print("INFO  roundtrip %d: %s" % [ronde, r])
	_herstel()
	check("roundtrip %d willekeurige profielen: export → import → export gelijk" % ROUNDTRIP_RONDES, fout == 0)


func _snelheid_tests() -> void:
	var lang := ""
	for _i in Profiel.MAX_CODE_CHARS:
		lang += Profiel.CODE_ALFABET[_rng.randi_range(1, 30)]
	var t0 := Time.get_ticks_msec()
	var r := _probeer(lang, "*")
	var ms := Time.get_ticks_msec() - t0
	print("INFO  import van %d tekens rommel: %d ms" % [lang.length(), ms])
	check("code van MAX_CODE_CHARS tekens netjes geweigerd", r == "")
	check("code van MAX_CODE_CHARS tekens binnen %d ms (%d ms)" % [MAX_IMPORT_MS, ms], ms <= MAX_IMPORT_MS)
	var t1 := Time.get_ticks_msec()
	var wit := _probeer(" ".repeat(Profiel.MAX_RAW_CHARS - 1) + "3", "corrupt")
	check("%d tekens wit plus één cijfer netjes geweigerd" % Profiel.MAX_RAW_CHARS, wit == "")
	print("INFO  import van %d tekens wit: %d ms" % [Profiel.MAX_RAW_CHARS, Time.get_ticks_msec() - t1])


func _eind_tests() -> void:
	check("basisprofiel staat er nog", _p.document() == _basis_doc)
	var ander = Profiel.new()
	check("bestand laadt terug tot het basisprofiel", ander.load_profile().get("ok") == true and ander.document() == _basis_doc)
	check("geen backup of tmp achtergebleven", _online_bestanden() == ["online_profile.json"])


# ---------------------------------------------------------------- kern: één poging


## Verwacht: "OK" (moet lukken), "*" (elke nette weigering), "*?" (weigering of strikt-geldige
## acceptatie), of een exacte reden. Geeft "" bij succes, "ok" als "*?" accepteerde, anders wat er misging.
func _probeer(code: String, verwacht: String) -> String:
	var doc_voor: Dictionary = _p.document()
	var bestand_voor := FileAccess.get_file_as_bytes(Profiel.PATH)
	var n_voor := _geweigerd.size()
	var r: Variant = _p.import_code(code)
	if not (r is Dictionary):
		return "geen Dictionary terug (%s)" % type_string(typeof(r))
	var d: Dictionary = r
	if not (d.get("ok") is bool) or not (d.get("reason") is String) or not (d.get("message") is String):
		return "antwoord mist ok/reason/message: %s" % str(d)
	if bool(d["ok"]):
		var fout := _na_acceptatie()
		if fout != "":
			return fout
		if verwacht == "OK":
			return ""
		if verwacht == "*?":
			return "ok"
		_herstel()
		return "geaccepteerd, verwacht %s" % verwacht
	var reden: String = d["reason"]
	if not Profiel.MELDING.has(reden):
		return "onbekende reden '%s'" % reden
	if str(d["message"]) != str(Profiel.MELDING[reden]) or str(d["message"]).strip_edges() == "":
		return "geen nette melding bij '%s'" % reden
	if _geweigerd.size() != n_voor + 1 or _geweigerd[-1] != reden:
		return "import_refused niet precies 1x met '%s'" % reden
	if _p.document() != doc_voor:
		return "profiel in geheugen veranderd na weigering '%s'" % reden
	if FileAccess.get_file_as_bytes(Profiel.PATH) != bestand_voor:
		return "profielbestand veranderd na weigering '%s'" % reden
	if verwacht == "OK":
		return "geweigerd ('%s'), verwacht OK" % reden
	if verwacht == "*" or verwacht == "*?" or verwacht == reden:
		return ""
	return "reden '%s', verwacht '%s'" % [reden, verwacht]


func _verwacht(label: String, code: String, verwacht: String) -> void:
	var r := _probeer(code, verwacht)
	if r == "ok":
		r = ""
	check("%s → %s%s" % [label, verwacht, "" if r == "" else " (%s)" % r], r == "")
	if verwacht == "OK" or verwacht == "*?":
		_herstel()


## Na een geaccepteerde import: geheugen strikt geldig, bestand laadt terug tot hetzelfde.
func _na_acceptatie() -> String:
	var doc: Dictionary = _p.document()
	if not _strikt_ok(doc):
		return "geaccepteerd profiel is niet strikt geldig: %s" % JSON.stringify(doc).substr(0, 160)
	var ander = Profiel.new()
	var r: Dictionary = ander.load_profile()
	if not bool(r.get("ok", false)) or bool(r.get("recovered", false)):
		return "opgeslagen profiel laadt niet schoon terug"
	if ander.document() != doc:
		return "opgeslagen profiel wijkt af van geheugen"
	return ""


func _herstel() -> void:
	if _p.document() == _basis_doc:
		return
	var r: Dictionary = _p.import_code(_basis_code)
	if not bool(r.get("ok", false)) or _p.document() != _basis_doc:
		check("herstel naar basisprofiel", false)


## Onafhankelijke, strikte controle (eigen regels, niet de validator van online_profile.gd).
func _strikt_ok(doc: Variant) -> bool:
	if not (doc is Dictionary) or (doc as Dictionary).size() != 2:
		return false
	if typeof(doc.get("version")) != TYPE_INT or int(doc["version"]) != 1:
		return false
	if not (doc.get("slots") is Array) or (doc["slots"] as Array).size() != 3:
		return false
	var uids: Array = []
	for s in doc["slots"]:
		if s == null:
			continue
		if not (s is Dictionary) or (s as Dictionary).size() != 8:
			return false
		var uid: Variant = s.get("uid")
		if typeof(uid) != TYPE_STRING or not _hex8(uid) or uid in uids:
			return false
		uids.append(uid)
		var naam: Variant = s.get("name")
		if typeof(naam) != TYPE_STRING or not _letters(naam, 1, 5):
			return false
		if typeof(s.get("class")) != TYPE_STRING or not Profiel.CLASS_INFO.has(s["class"]):
			return false
		var look: Variant = s.get("look")
		if not (look is Dictionary) or (look as Dictionary).size() != Profiel.LOOK_KEYS.size():
			return false
		for k in Profiel.LOOK_KEYS:
			if not _int_in(look.get(k), 0, int(Profiel.LOOK_MAX[k])):
				return false
		if not _int_in(s.get("profile_exp"), 0, Profiel.MAX_PROFILE_EXP):
			return false
		var st: Variant = s.get("stats_seen")
		if not (st is Dictionary) or (st as Dictionary).size() != 2:
			return false
		if not _int_in(st.get("best_floor"), 0, Profiel.MAX_BEST_FLOOR) or not _int_in(st.get("runs"), 0, Profiel.MAX_RUNS):
			return false
		if not _ids_ok(s.get("unlocks"), Profiel.MAX_UNLOCKS, Profiel.MAX_UNLOCK_LEN):
			return false
		if not _ids_ok(s.get("applied_grants"), Profiel.MAX_GRANTS, Profiel.MAX_GRANT_LEN):
			return false
	return true


func _int_in(v: Variant, lo: int, hi: int) -> bool:
	return typeof(v) == TYPE_INT and int(v) >= lo and int(v) <= hi


func _ids_ok(v: Variant, max_n: int, max_len: int) -> bool:
	if not (v is Array) or (v as Array).size() > max_n:
		return false
	var gezien: Array = []
	for item in v:
		if typeof(item) != TYPE_STRING or (item as String).length() < 1 or (item as String).length() > max_len:
			return false
		for i in (item as String).length():
			var c := (item as String).unicode_at(i)
			if not ((c >= 48 and c <= 57) or (c >= 97 and c <= 122) or c == 95):
				return false
		if item in gezien:
			return false
		gezien.append(item)
	return true


func _letters(s: String, lo: int, hi: int) -> bool:
	if s.length() < lo or s.length() > hi:
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122)):
			return false
	return true


func _hex8(uid: String) -> bool:
	if uid.length() != 8:
		return false
	for i in uid.length():
		var c := uid.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 97 and c <= 102)):
			return false
	return true


# ---------------------------------------------------------------- bouwstenen


## Eigen envelop: versie, u32 plain-lengte, gecomprimeerd deel, u32 crc32. Zo kan de suite
## een geldige crc om elke inhoud zetten (de crc is geen geheim; een aanvaller kan dat ook).
func _wire_code(plain: PackedByteArray, versie: int = 1, claim: int = -1, compressed: PackedByteArray = PackedByteArray(), crc_fout: bool = false) -> String:
	var wire := PackedByteArray()
	wire.append(versie & 0xFF)
	var lengte := plain.size() if claim < 0 else claim
	for sh in [24, 16, 8, 0]:
		wire.append((lengte >> sh) & 0xFF)
	wire.append_array(compressed if not compressed.is_empty() else plain.compress(FileAccess.COMPRESSION_DEFLATE))
	var crc := Profiel.crc32_ieee(wire)
	if crc_fout:
		crc = crc ^ 0x00010000
	for sh in [24, 16, 8, 0]:
		wire.append((crc >> sh) & 0xFF)
	return Profiel.encode_base31(wire)


func _doc_code(doc: Variant) -> String:
	return _wire_code(JSON.stringify(doc).to_utf8_buffer())


func _voorbeeld_slot() -> Dictionary:
	return {
		"uid": "abcd1234",
		"name": "Mira",
		"class": "priest",
		"look": Profiel.default_look(),
		"profile_exp": 5,
		"unlocks": ["hair_3"],
		"stats_seen": {"best_floor": 3, "runs": 2},
		"applied_grants": [],
	}


func _met(slot: Dictionary, veld: String, waarde: Variant) -> Dictionary:
	var uit := slot.duplicate(true)
	uit[veld] = waarde
	return uit


func _met_voortgang(slot: Dictionary, veld: String, waarde: Variant) -> Dictionary:
	if veld == "profile_exp":
		return _met(slot, veld, waarde)
	var uit := slot.duplicate(true)
	uit["stats_seen"][veld] = waarde
	return uit


func _nest(n: int) -> Variant:
	var v: Variant = "abcd1234"
	for _i in n:
		v = [v]
	return v


func _ids(n: int) -> Array:
	var uit: Array = []
	for i in n:
		uit.append("id_" + str(i).pad_zeros(3))
	return uit


func _rng_bytes(n: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	for i in n:
		b[i] = _rng.randi_range(0, 255)
	return b


func _rommel_opmaak(code: String) -> String:
	var uit := ""
	for i in code.length():
		uit += code[i].to_lower() if i % 2 == 0 else code[i]
		if i % 5 == 4:
			uit += [" ", "-", "\n", "\t"][(i / 5) % 4]
	return "  " + uit + "\n"


func _muteer(code: String, n: int) -> String:
	var uit := code
	for _i in n:
		var pos := _rng.randi_range(0, maxi(0, uit.length() - 1))
		var teken := Profiel.CODE_ALFABET[_rng.randi_range(0, 30)]
		match _rng.randi_range(0, 6):
			0:
				uit = uit.substr(0, pos) + teken + uit.substr(pos + 1)
			1:
				uit = uit.insert(pos, teken)
			2:
				uit = uit.substr(0, pos) + uit.substr(pos + 1)
			3:
				uit = uit.substr(0, pos)
			4:
				uit = uit.insert(pos, uit.substr(pos, _rng.randi_range(1, 20)))
			5:
				uit = uit.insert(pos, ["0", "O", "1", "I", "L", "?", "ä", " ", "-"][_rng.randi_range(0, 8)])
			_:
				if pos + 1 < uit.length():
					uit = uit.substr(0, pos) + uit[pos + 1] + uit[pos] + uit.substr(pos + 2)
	return uit


## Verstoor één plek in het document: een veld vervangen, wissen of toevoegen.
func _verstoor(doc: Dictionary) -> void:
	var slots: Array = doc["slots"] if doc.get("slots") is Array else []
	var keuze := _rng.randi_range(0, 9)
	if keuze == 0:
		doc[["version", "slots", "extra"][_rng.randi_range(0, 2)]] = _vijandig()
		return
	if slots.is_empty():
		return
	var i := _rng.randi_range(0, slots.size() - 1)
	if not (slots[i] is Dictionary):
		slots[i] = _vijandig() if keuze == 1 else null
		return
	var slot: Dictionary = slots[i]
	var velden := slot.keys()
	var veld: String = str(velden[_rng.randi_range(0, velden.size() - 1)])
	match keuze:
		1:
			slot.erase(veld)
		2:
			slot["x_" + str(_rng.randi_range(0, 9))] = _vijandig()
		3, 4:
			if slot.get("look") is Dictionary:
				var k: String = Profiel.LOOK_KEYS[_rng.randi_range(0, Profiel.LOOK_KEYS.size() - 1)]
				slot["look"][k] = _vijandig() if keuze == 3 else _rng.randi_range(-2, 9)
		5:
			if slot.get("stats_seen") is Dictionary:
				slot["stats_seen"][["best_floor", "runs"][_rng.randi_range(0, 1)]] = _vijandig()
		6:
			if slot.get("unlocks") is Array:
				(slot["unlocks"] as Array).append(_vijandig() if _rng.randi_range(0, 1) == 0 else "u_%d" % _rng.randi_range(0, 30))
		7:
			var j := _rng.randi_range(0, slots.size() - 1)
			if j != i and slots[j] is Dictionary and slot.has("uid"):
				slots[j]["uid"] = slot["uid"]
		_:
			slot[veld] = _vijandig()


func _vijandig() -> Variant:
	var v: Variant = VIJANDIG[_rng.randi_range(0, VIJANDIG.size() - 1)]
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v


func _willekeurig_document() -> Dictionary:
	var letters := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var id_tekens := "abcdefghijklmnopqrstuvwxyz0123456789_"
	var hex := "0123456789abcdef"
	var klassen: Array = Profiel.CLASS_INFO.keys()
	var slots: Array = []
	var uids: Array = []
	for _i in Profiel.SLOT_COUNT:
		if _rng.randi_range(0, 3) == 0:
			slots.append(null)
			continue
		var uid := ""
		while uid == "" or uid in uids:
			uid = ""
			for _j in 8:
				uid += hex[_rng.randi_range(0, 15)]
		uids.append(uid)
		var naam := ""
		for _j in _rng.randi_range(1, Profiel.NAME_MAX):
			naam += letters[_rng.randi_range(0, letters.length() - 1)]
		var look := {}
		for k in Profiel.LOOK_KEYS:
			look[k] = _rng.randi_range(0, int(Profiel.LOOK_MAX[k]))
		var unlocks := _willekeurige_ids(id_tekens, Profiel.MAX_UNLOCKS, Profiel.MAX_UNLOCK_LEN)
		var grants := _willekeurige_ids(id_tekens, Profiel.MAX_GRANTS, Profiel.MAX_GRANT_LEN)
		slots.append({
			"uid": uid,
			"name": naam,
			"class": str(klassen[_rng.randi_range(0, klassen.size() - 1)]),
			"look": look,
			"profile_exp": _rng.randi_range(0, Profiel.MAX_PROFILE_EXP),
			"unlocks": unlocks,
			"stats_seen": {"best_floor": _rng.randi_range(0, Profiel.MAX_BEST_FLOOR), "runs": _rng.randi_range(0, Profiel.MAX_RUNS)},
			"applied_grants": grants,
		})
	return {"version": 1, "slots": slots}


func _willekeurige_ids(tekens: String, max_n: int, max_len: int) -> Array:
	var uit: Array = []
	for _i in _rng.randi_range(0, max_n):
		var id := ""
		for _j in _rng.randi_range(1, max_len):
			id += tekens[_rng.randi_range(0, tekens.length() - 1)]
		if not (id in uit):
			uit.append(id)
	return uit


func _online_bestanden() -> Array:
	var uit: Array = []
	var dir := DirAccess.open("user://")
	if dir == null:
		return uit
	dir.list_dir_begin()
	var naam := dir.get_next()
	while naam != "":
		if naam.begins_with("online_profile"):
			uit.append(naam)
		naam = dir.get_next()
	dir.list_dir_end()
	uit.sort()
	return uit


func _wis_online() -> void:
	for naam in _online_bestanden():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://%s" % naam))


func _wacht(cond: Callable, max_s: float) -> void:
	var t := 0.0
	while not cond.call() and t < max_s:
		await get_tree().process_frame
		t += get_process_delta_time()
