extends Node
## Online profiel (--onlineprofiletest): roundtrip, kapot bestand, 3 slots,
## exportcode, look-bytes, en geen schrijven in de verhaal-saves.
## Start: godot --path . -- --onlineprofiletest

const Profiel := preload("res://scripts/online/online_profile.gd")

const VERHAAL: Array[String] = [
	"user://save_1.json", "user://save_2.json", "user://save_3.json", "user://save_4.json",
	"user://autosave.json", "user://autosave_1.json", "user://autosave_2.json",
	"user://autosave_3.json", "user://autosave_4.json",
	"user://som_save_1.json", "user://coop_guest_session.json", "user://coop_guest_autosave.json",
]

var failures := 0
var passes := 0
var _sentinels: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: test klaar binnen 120 s", false)
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
	_zet_sentinels()
	_codec_tests()
	_look_tests()
	_klasse_tests()
	_slot_tests()
	_bestand_tests()
	_code_tests()
	_verhaal_tests()
	print("ONLINEPROFILETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _codec_tests() -> void:
	var ascii := "123456789".to_utf8_buffer()
	check("crc32 van 123456789 is CBF43926", Profiel.crc32_ieee(ascii) == 0xCBF43926)
	check("crc32 van leeg is 0", Profiel.crc32_ieee(PackedByteArray()) == 0)
	check("base31: 01 00 is AA", Profiel.encode_base31(PackedByteArray([1, 0])) == "AA")
	check("base31: 01 is 3", Profiel.encode_base31(PackedByteArray([1])) == "3")
	var lang := PackedByteArray([1, 0, 0, 255])
	check("base31: 01 00 00 FF is M77CS", Profiel.encode_base31(lang) == "M77CS")
	var rond := PackedByteArray([1, 2, 3, 0, 31, 32, 255, 0])
	check("base31: lang voorbeeld", Profiel.encode_base31(rond) == "4VMT88XARQVK")
	var terug: PackedByteArray = Profiel.decode_base31("aa").get("bytes", PackedByteArray())
	check("base31 decode AA negeert kast", terug == PackedByteArray([1, 0]))
	var met_spatie: PackedByteArray = Profiel.decode_base31("A A").get("bytes", PackedByteArray())
	check("base31 decode negeert spatie", met_spatie == PackedByteArray([1, 0]))
	check("base31: voorloopnul weigert encoder", Profiel.encode_base31(PackedByteArray([0, 1])) == "")
	for teken in ["0", "O", "1", "I", "L"]:
		var geweigerd: Dictionary = Profiel.decode_base31(teken)
		check("alfabet weigert %s" % teken, not geweigerd.get("ok", true) and geweigerd.get("reason") == "alphabet")
	check("lege code", Profiel.decode_base31("  \n-").get("reason") == "empty")
	var te_lang := "2".repeat(Profiel.MAX_CODE_CHARS + 1)
	check("te lange code", Profiel.decode_base31(te_lang).get("reason") == "too_long")


func _look_tests() -> void:
	var basis := Profiel.default_look()
	var vol := {
		"body": 0, "skin": 3, "hair": 5, "hair_color": 7,
		"top": 3, "top_color": 5, "bottom": 2, "bottom_color": 5, "head": 2,
	}
	var a := Profiel.encode_look(basis)
	var b := Profiel.encode_look(vol)
	check("look is 16 bytes", a.size() == Profiel.LOOK_BYTES and b.size() == 16)
	check("look roundtrip standaard", Profiel.decode_look(a) == basis)
	check("look roundtrip grens", Profiel.decode_look(b) == vol)
	check("look weigert skin buiten bereik", Profiel.encode_look({"body": 0, "skin": 4, "hair": 0, "hair_color": 0, "top": 0, "top_color": 0, "bottom": 0, "bottom_color": 0, "head": 0}).is_empty())
	check("look weigert verkeerde lengte", Profiel.decode_look(a.slice(0, 15)).is_empty())
	var kapot := a.duplicate()
	kapot[0] = 2
	check("look weigert versie 2", Profiel.decode_look(kapot).is_empty())
	var som := b.duplicate()
	som[15] = (int(som[15]) + 1) % 256
	check("look weigert checksum", Profiel.decode_look(som).is_empty())
	var gereserveerd := b.duplicate()
	gereserveerd[10] = 1
	gereserveerd[15] = (int(gereserveerd[15]) + 1) % 256
	check("look weigert gereserveerde byte", Profiel.decode_look(gereserveerd).is_empty())


func _klasse_tests() -> void:
	check("warrior is dennis Tank", Profiel.base_hero_for("warrior") == "dennis" and Profiel.role_for("warrior") == "Tank")
	check("mage is noor Control", Profiel.base_hero_for("mage") == "noor" and Profiel.role_for("mage") == "Control")
	check("priest is lotte Heal", Profiel.base_hero_for("priest") == "lotte" and Profiel.role_for("priest") == "Heal")
	check("psytech is kael Dps", Profiel.base_hero_for("psytech") == "kael" and Profiel.role_for("psytech") == "Dps")
	check("archer is orion Dps", Profiel.base_hero_for("archer") == "orion" and Profiel.role_for("archer") == "Dps")
	check("onbekende klasse is leeg", Profiel.base_hero_for("bard") == "" and Profiel.role_for("bard") == "")


func _slot_tests() -> void:
	_wis_online()
	var p = Profiel.new()
	var wijzigingen: Array[int] = []
	p.profile_changed.connect(func(index: int) -> void: wijzigingen.append(index))
	var leeg: Dictionary = p.load_profile()
	check("ontbrekend bestand laadt leeg", leeg.get("ok") and not leeg.get("recovered") and not FileAccess.file_exists(Profiel.PATH))
	check("naam van 6 letters geweigerd", p.create_slot(0, "Vesper", "mage").get("reason") == "name")
	check("cijfer in naam geweigerd", p.create_slot(0, "A1", "mage").get("reason") == "name")
	check("lege naam geweigerd", p.create_slot(0, "  ", "mage").get("reason") == "name")
	check("onbekende klasse geweigerd", p.create_slot(0, "Mira", "bard").get("reason") == "class")
	check("slot 3 bestaat niet", p.create_slot(3, "Mira", "priest").get("reason") == "index")
	var look := {
		"body": 0, "skin": 2, "hair": 3, "hair_color": 5,
		"top": 1, "top_color": 0, "bottom": 2, "bottom_color": 4, "head": 0,
	}
	var s0: Dictionary = p.create_slot(0, "Mira", "Priest", look)
	var s1: Dictionary = p.create_slot(1, "Dax", "warrior")
	var s2: Dictionary = p.create_slot(2, "Seren", "priest")
	check("drie slots gemaakt", s0.get("ok") and s1.get("ok") and s2.get("ok"))
	check("naam van 5 letters mag", str(s2.get("slot", {}).get("name", "")) == "Seren")
	check("klasse wordt kleine letters", str(s0.get("slot", {}).get("class", "")) == "priest")
	check("bezet slot geweigerd", p.create_slot(1, "Kael", "psytech").get("reason") == "occupied")
	check("twee keer priest mag", str(p.get_slot(2).get("class", "")) == "priest" and str(p.get_slot(0).get("class", "")) == "priest")
	var uid0 := str(p.get_slot(0).get("uid", ""))
	var uid1 := str(p.get_slot(1).get("uid", ""))
	check("uid is 8 hex en uniek", _hex8(uid0) and _hex8(uid1) and uid0 != uid1 and _hex8(str(p.get_slot(2).get("uid", ""))))
	check("standaard look als die ontbreekt", p.get_slot(1).get("look") == Profiel.default_look())
	check("look bewaard", p.get_slot(0).get("look") == look)
	check("leeg slot geeft lege dict", p.get_slot(9).is_empty())
	var voortgang: Dictionary = p.set_progress(0, 12, 10, 3, ["hair_3", "top_1"], ["easy_clear"])
	check("voortgang gezet", voortgang.get("ok") and int(p.get_slot(0).get("profile_exp", -1)) == 12)
	check("stats_seen en grants", p.get_slot(0).get("stats_seen") == {"best_floor": 10, "runs": 3} and p.get_slot(0).get("applied_grants") == ["easy_clear"])
	check("te veel unlocks geweigerd", p.set_progress(0, 1, 0, 0, _ids(17), []).get("reason") == "progress")
	check("wissen van het midden laat de rest staan", p.clear_slot(1).get("ok") and not p.has_slot(1) and p.has_slot(0) and p.has_slot(2))
	check("signalen per slot %s" % str(wijzigingen), wijzigingen == [0, 1, 2, 0, 1])
	var opnieuw = Profiel.new()
	var geladen: Dictionary = opnieuw.load_profile()
	check("laden uit bestand lukt", geladen.get("ok") and not geladen.get("recovered"))
	check("roundtrip gelijk aan geheugen", opnieuw.document() == p.document())
	check("gewist slot blijft leeg na laden", not opnieuw.has_slot(1) and str(opnieuw.get_slot(0).get("name", "")) == "Mira")


func _bestand_tests() -> void:
	_wis_online()
	var rot := PackedByteArray([0xff, 0xfe, 0x7b, 0x00])
	_schrijf_bytes(Profiel.PATH, rot)
	var p = Profiel.new()
	var geladen_flag := {"n": 0, "recovered": false}
	p.profile_loaded.connect(func(recovered: bool) -> void:
		geladen_flag["n"] = int(geladen_flag["n"]) + 1
		geladen_flag["recovered"] = recovered)
	var r: Dictionary = p.load_profile()
	check("kapot bestand crasht niet", r.get("ok") == true and r.get("recovered") == true and r.get("reason") == "corrupt")
	check("kapot bestand: signal profile_loaded", geladen_flag["n"] == 1 and geladen_flag["recovered"] == true)
	var backup := str(r.get("backup", ""))
	check("kapot bestand staat in de backup", backup != "" and FileAccess.get_file_as_bytes(backup) == rot)
	check("na kapot bestand zijn de slots leeg", not p.has_slot(0) and not p.has_slot(1) and not p.has_slot(2))
	var bak_voor := FileAccess.get_file_as_bytes(backup)
	var r2: Dictionary = p.load_profile()
	check("tweede load laat de backup met rust", r2.get("ok") and not r2.get("recovered") and FileAccess.get_file_as_bytes(backup) == bak_voor)
	_wis_online()
	var slot := _voorbeeld_slot()
	var oud := JSON.stringify({"version": 99, "slots": [slot]})
	_schrijf_tekst(Profiel.PATH, oud)
	var q = Profiel.new()
	var rv: Dictionary = q.load_profile()
	check("onbekende versie wordt niet toegepast", rv.get("recovered") and rv.get("reason") == "version" and not q.has_slot(0))
	check("onbekende versie staat in de backup", FileAccess.get_file_as_string(str(rv.get("backup", ""))) == oud)
	_wis_online()
	var kort := JSON.stringify({"version": 1, "slots": [slot]})
	_schrijf_tekst(Profiel.PATH, kort)
	var k = Profiel.new()
	check("kort bestand laadt in slot 0", k.load_profile().get("ok") and str(k.get_slot(0).get("name", "")) == "Mira" and not k.has_slot(1))
	check("kort bestand bewaart unlock", k.get_slot(0).get("unlocks") == ["hair_3"])
	_wis_online()
	var extra := slot.duplicate(true)
	extra["cape"] = 1
	_schrijf_tekst(Profiel.PATH, JSON.stringify({"version": 1, "slots": [extra, null, null]}))
	var e = Profiel.new()
	var re: Dictionary = e.load_profile()
	check("onbekend veld is kapot en wordt niet half geladen", re.get("reason") == "corrupt" and not e.has_slot(0))


func _code_tests() -> void:
	_wis_online()
	var p = Profiel.new()
	p.load_profile()
	var look := {
		"body": 0, "skin": 2, "hair": 3, "hair_color": 5,
		"top": 1, "top_color": 0, "bottom": 2, "bottom_color": 4, "head": 1,
	}
	check("slot 0 voor export", p.create_slot(0, "Mira", "priest", look).get("ok"))
	check("slot 1 voor export", p.create_slot(1, "Orion", "archer").get("ok"))
	check("slot 2 voor export", p.create_slot(2, "Kael", "psytech").get("ok"))
	var vol := _ids(Profiel.MAX_UNLOCKS)
	var grants := _ids(Profiel.MAX_GRANTS)
	check("volle voortgang", p.set_progress(0, Profiel.MAX_PROFILE_EXP, Profiel.MAX_BEST_FLOOR, Profiel.MAX_RUNS, vol, grants).get("ok"))
	var exp: Dictionary = p.export_code()
	var code := str(exp.get("code", ""))
	check("export lukt", exp.get("ok") == true and code != "")
	var tekens_ok := true
	for i in code.length():
		if Profiel.CODE_ALFABET.find(code[i]) < 0:
			tekens_ok = false
			break
	check("exporttekens in het alfabet", tekens_ok)
	check("export is compact", code.length() > 0 and code.length() <= Profiel.MAX_CODE_CHARS and code.length() < 2500)
	print("INFO  exportcode %d tekens" % code.length())
	check("export tweemaal gelijk", p.export_code().get("code") == code)
	var q = Profiel.new()
	var imp: Dictionary = q.import_code(_met_wit(code))
	check("import met spaties en kleine letters", imp.get("ok") == true)
	check("export naar import is gelijk", q.document() == p.document())
	_wis_online()
	var leeg = Profiel.new()
	leeg.load_profile()
	var code_leeg := str(leeg.export_code().get("code", ""))
	check("lege export importeert lege slots", code_leeg != "" and _import_gelijk(leeg, code_leeg))
	var geweigerd: Array[String] = []
	p.import_refused.connect(func(reason: String) -> void: geweigerd.append(reason))
	var voor := p.document()
	check("lege import geweigerd", p.import_code("").get("reason") == "empty" and p.document() == voor)
	check("0 in de code geweigerd", p.import_code("0").get("reason") == "alphabet" and p.document() == voor)
	check("te lange import geweigerd", p.import_code("2".repeat(Profiel.MAX_CODE_CHARS + 1)).get("reason") == "too_long")
	var gedraaid := _draai(code)
	var checksum: Dictionary = p.import_code(gedraaid)
	check("gedraaide code geweigerd op checksum", checksum.get("ok") == false and checksum.get("reason") == "checksum" and p.document() == voor)
	var v2: Dictionary = Profiel.encode_profile_code(p.document(), 2)
	check("versie 2 is te bouwen", v2.get("ok") == true)
	check("oude code geweigerd", p.import_code(str(v2.get("code", ""))).get("reason") == "version" and p.document() == voor)
	var schema_doc := p.document().duplicate(true)
	schema_doc["slots"][1]["class"] = "bard"
	var schema_code: Dictionary = Profiel.encode_profile_code(schema_doc, 1)
	check("foute klasse in de code geweigerd", p.import_code(str(schema_code.get("code", ""))).get("reason") == "schema" and p.document() == voor)
	var json_v: Dictionary = p.document().duplicate(true)
	json_v["version"] = 99
	var json_code: Dictionary = Profiel.encode_profile_code(json_v, 1)
	check("json-versie 99 geweigerd", p.import_code(str(json_code.get("code", ""))).get("reason") == "version" and p.document() == voor)
	check("weigeringen zijn de verwachte redenen", geweigerd == ["empty", "alphabet", "too_long", "checksum", "version", "schema", "version"])
	var een := {"version": 1, "slots": [p.get_slot(0)]}
	var een_code: Dictionary = Profiel.encode_profile_code(een, 1)
	var r = Profiel.new()
	check("code met één slot vult alleen slot 0", r.import_code(str(een_code.get("code", ""))).get("ok") and r.has_slot(0) and not r.has_slot(1))


func _verhaal_tests() -> void:
	var gelijk := true
	for pad in VERHAAL:
		var nu := FileAccess.get_file_as_bytes(pad) if FileAccess.file_exists(pad) else PackedByteArray()
		if nu != _sentinels.get(pad, PackedByteArray()):
			gelijk = false
			print("INFO  verhaalbestand veranderd: %s" % pad)
	check("save_N.json en autosave.json byte-gelijk", gelijk)
	check("profielpad is niet een verhaalpad", not (Profiel.PATH in VERHAAL))
	check("profielbestand bestaat naast de sentinels", FileAccess.file_exists(Profiel.PATH))


func _zet_sentinels() -> void:
	for pad in VERHAAL:
		var tekst := "STORY-SENTINEL\n%s\nonline-profile-m1\n" % pad
		var f := FileAccess.open(pad, FileAccess.WRITE)
		f.store_string(tekst)
		f.flush()
		f.close()
		_sentinels[pad] = FileAccess.get_file_as_bytes(pad)


func _wis_online() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var namen: Array[String] = []
	dir.list_dir_begin()
	var naam := dir.get_next()
	while naam != "":
		if naam.begins_with("online_profile"):
			namen.append(naam)
		naam = dir.get_next()
	dir.list_dir_end()
	for naam2 in namen:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://%s" % naam2))


func _schrijf_bytes(pad: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(pad, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()


func _schrijf_tekst(pad: String, tekst: String) -> void:
	var f := FileAccess.open(pad, FileAccess.WRITE)
	f.store_string(tekst)
	f.close()


func _voorbeeld_slot() -> Dictionary:
	return {
		"uid": "abcd1234",
		"name": "Mira",
		"class": "priest",
		"look": Profiel.default_look(),
		"profile_exp": 0,
		"unlocks": ["hair_3"],
		"stats_seen": {"best_floor": 0, "runs": 0},
		"applied_grants": [],
	}


func _ids(n: int) -> Array:
	var uit: Array = []
	for i in n:
		uit.append("id_" + str(i).pad_zeros(2))
	return uit


func _hex8(uid: String) -> bool:
	if uid.length() != 8:
		return false
	for i in uid.length():
		var c := uid.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 97 and c <= 102)):
			return false
	return true


func _met_wit(code: String) -> String:
	var uit := ""
	for i in code.length():
		uit += code[i].to_lower()
		if i % 16 == 15:
			uit += "\n"
		elif i % 4 == 3:
			uit += "-"
	return uit


func _draai(code: String) -> String:
	var i := mini(4, code.length() - 1)
	var nu := Profiel.CODE_ALFABET.find(code[i])
	var ander := Profiel.CODE_ALFABET[(nu + 1) % Profiel.CODE_ALFABET.length()]
	return code.substr(0, i) + ander + code.substr(i + 1)


func _import_gelijk(bron, code: String) -> bool:
	var q = Profiel.new()
	if not q.import_code(code).get("ok", false):
		return false
	return q.document() == bron.document()


func _wacht(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
