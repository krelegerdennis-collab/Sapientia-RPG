extends Node
## Co-op cosmetics (--cosmeticstest): data/online/cosmetics.json tegen schijf, LOOK_MAX en de baker,
## en beschikbaarheid via profiel-unlocks (vervalste/onbekende id's genegeerd, geen crash).
## Start: godot --path . -- --cosmeticstest

const Cos := preload("res://scripts/online/cosmetics.gd")
const Profiel := preload("res://scripts/online/online_profile.gd")
const Baker := preload("res://scripts/online/paper_doll_baker.gd")

var failures := 0
var passes := 0


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
	_lijst_tests()
	_bestanden_tests()
	_look_tests()
	_baker_tests()
	_beschikbaar_tests()
	_vervalst_tests()
	_look_codering_tests()
	print("COSMETICSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _lijst_tests() -> void:
	var doc := Cos.catalog()
	check("cosmetics.json laadt", not doc.is_empty())
	check("look_version in lijst is LOOK_VERSION", int(doc.get("look_version", -1)) == Profiel.LOOK_VERSION)
	var raw: Array = doc.get("items", [])
	check("alle items goed gevormd", Cos.items().size() == raw.size() and raw.size() > 0)
	check("validate geeft geen problemen", Cos.validate().is_empty())
	var ids := {}
	var dubbel := false
	for it in raw:
		if ids.has(str(it.get("id", ""))):
			dubbel = true
		ids[str(it.get("id", ""))] = true
	check("geen dubbele id's", not dubbel)
	var sheets: Array = doc.get("sheets", [])
	check("sheets-lijst is walk/attack/hurt/dodge/ko", PackedStringArray(sheets) == Cos.SHEETS)
	# Dubbele id in een nep-lijst wordt gemeld
	var nep := {"items": [raw[0], raw[0]], "lagen": doc["lagen"]}
	var p := Cos.validate(nep)
	check("validate meldt dubbele id", _bevat(p, "dubbele id"))
	check("validate meldt dubbele look-index", _bevat(p, "dubbele look-index"))
	check("validate zonder items crasht niet", Cos.validate({"x": 1}).size() == 1)


func _bestanden_tests() -> void:
	var lagen: Dictionary = Cos.catalog()["lagen"]
	for it in Cos.items():
		var id := str(it["id"])
		var info: Dictionary = lagen.get(str(it["laag"]), {})
		check("%s: laag bestaat" % id, not info.is_empty())
		var bl: Array = info.get("baker_layers", [])
		var sheets: Dictionary = it["sheets"]
		check("%s: sheets voor elke baker-laag" % id, sheets.size() == bl.size() and _alle_keys(sheets, bl))
		for b in bl:
			var per: Dictionary = sheets.get(b, {})
			for s in Cos.SHEETS:
				var pad := str(per.get(s, ""))
				var maat := Baker.sheet_size(s)
				check("%s/%s/%s op schijf %dx%d" % [id, b, s, maat.x, maat.y], _png_maat(pad) == maat)
		var portret: Variant = it["portret"]
		if bool(info.get("portret", true)):
			check("%s: portret per baker-laag" % id, portret is Dictionary and _alle_keys(portret, bl) and (portret as Dictionary).size() == bl.size())
			if portret is Dictionary:
				for b in bl:
					var pp := str((portret as Dictionary).get(b, ""))
					check("%s: portret %s 32x32 op schijf" % [id, b], pp.begins_with("res://assets/ui/portret/") and _png_maat(pp) == Vector2i(32, 32))
		else:
			check("%s: expliciet geen_portret" % id, portret is String and portret == Cos.GEEN_PORTRET)
	check("onderstuk heeft geen portret", Cos.item("onder_broek")["portret"] == Cos.GEEN_PORTRET)


func _look_tests() -> void:
	var lagen: Dictionary = Cos.catalog()["lagen"]
	for laag in lagen:
		var info: Dictionary = lagen[laag]
		var key := str(info["look_key"])
		check("%s: look_key %s in LOOK_KEYS" % [laag, key], key in Profiel.LOOK_KEYS)
		if not Profiel.LOOK_MAX.has(key):
			continue
		var geen := int(info.get("geen_index", -1))
		var verwacht: Array = []
		for i in int(Profiel.LOOK_MAX[key]) + 1:
			if i != geen:
				verwacht.append(i)
		var echt: Array = []
		for it in Cos.items():
			if str(it["laag"]) == laag:
				check("%s: look_key klopt met laag" % it["id"], str(it["look_key"]) == key)
				echt.append(int(it["look_index"]))
		echt.sort()
		check("%s: look-indexen dekken 0..LOOK_MAX precies (%s)" % [laag, str(verwacht)], echt == verwacht)


func _baker_tests() -> void:
	var file := FileAccess.open(Baker.LAYERS_PATH, FileAccess.READ)
	var lagen_json: Dictionary = (JSON.parse_string(file.get_as_text()) as Dictionary)["layers"]
	for it in Cos.items():
		var look := Profiel.default_look()
		look[str(it["look_key"])] = int(it["look_index"])
		for b in it["sheets"]:
			var spec: Dictionary = lagen_json.get(b, {})
			check("%s: baker-laag %s bestaat" % [it["id"], b], not spec.is_empty())
			check("%s: id_key van %s is look_key" % [it["id"], b], str(spec.get("id_key", "")) == str(it["look_key"]))
			# Zelfde keuze als de baker zelf maakt voor deze look-index.
			var naam := Baker._resolve_id(look, spec)
			check("%s: baker kiest een optie in %s" % [it["id"], b], naam != "")
			var opt: Dictionary = (spec.get("options", {}) as Dictionary).get(naam, {})
			var zelfde := not opt.is_empty()
			for s in Cos.SHEETS:
				if str(opt.get(s, "")) != str(it["sheets"][b].get(s, "?")):
					zelfde = false
			check("%s: sheets gelijk aan baker-optie %s/%s" % [it["id"], b, naam], zelfde)
	# hoofd 0 = geen hoofddeksel: geen item, baker kiest niets
	var kaal := Profiel.default_look()
	check("head 0 heeft geen item", Cos.item_for_look("head", 0).is_empty())
	check("head 0: baker kiest niets", Baker._resolve_id(kaal, lagen_json["hoofd"]) == "")


func _beschikbaar_tests() -> void:
	check("standaard-item zonder unlocks beschikbaar", Cos.is_available("haar_kort", []))
	check("alle huidige items zijn standaard", Cos.available_items([]).size() == Cos.items().size())
	check("onbekend item niet beschikbaar", not Cos.is_available("bestaat_niet", []))
	check("lege id niet beschikbaar", not Cos.is_available("", []))
	check("available_items per laag: 6 kapsels", Cos.available_items([], "haar").size() == 6)
	check("available_items per laag: 2 hoofddeksels", Cos.available_items([], "hoofd").size() == 2)
	check("look_allowed: standaard look", Cos.look_allowed(Profiel.default_look(), []))
	var hoed := Profiel.default_look()
	hoed["head"] = 2
	check("look_allowed: hoed", Cos.look_allowed(hoed, []))
	var raar := Profiel.default_look()
	raar["hair"] = 9
	check("look_allowed: index zonder item geweigerd", not Cos.look_allowed(raar, []))
	# Nep-lijst met een unlock-item (ruimte voor latere items).
	var doc := _nep_doc()
	check("unlock-item zonder unlock niet beschikbaar", not Cos.is_available("hoofd_kroon", [], doc))
	check("unlock-item met unlock beschikbaar", Cos.is_available("hoofd_kroon", ["kroon_d50"], doc))
	check("unlock-item met andere unlock niet beschikbaar", not Cos.is_available("hoofd_kroon", ["kroon_d40"], doc))
	check("unlock_id leest id", Cos.unlock_id(Cos.item("hoofd_kroon", doc)) == "kroon_d50")
	check("unlock_id standaard is leeg", Cos.unlock_id(Cos.item("haar_kort")) == "")
	var slot := {"uid": "abcd1234", "unlocks": ["kroon_d50"]}
	check("via profielslot beschikbaar", Cos.is_available_for_slot("hoofd_kroon", slot, doc))
	check("leeg slot: alleen standaard", not Cos.is_available_for_slot("hoofd_kroon", null, doc) and Cos.is_available_for_slot("haar_kort", null))
	var kroon := Profiel.default_look()
	kroon["head"] = 3
	check("look_allowed: unlock-look zonder unlock geweigerd", not Cos.look_allowed(kroon, [], doc))
	check("look_allowed: unlock-look met unlock", Cos.look_allowed(kroon, ["kroon_d50"], doc))
	check("available_items telt unlock-item mee", Cos.available_items(["kroon_d50"], "hoofd", doc).size() == 3)


func _vervalst_tests() -> void:
	var doc := _nep_doc()
	var vals: Array = [
		null, 42, "kroon_d50", {"kroon_d50": true}, [null], [42], [1.5], [true],
		["KROON_D50"], ["kroon d50"], ["kroon_d50_veel_te_lang_id"], [""], ["kroon-d50"],
		["../kroon_d50"], [["kroon_d50"]], [{"id": "kroon_d50"}],
	]
	for v in vals:
		check("vervalst %s: genegeerd, geen crash" % str(v).c_escape(), not Cos.is_available("hoofd_kroon", v, doc))
	check("vervalst tussen echte: echte telt nog", Cos.is_available("hoofd_kroon", [42, "x y", "kroon_d50"], doc))
	var veel: Array = []
	for i in 40:
		veel.append("nep_%d" % i)
	veel.append("kroon_d50")
	check("meer dan MAX_UNLOCKS: alleen eerste 16 tellen", not Cos.is_available("hoofd_kroon", veel, doc))
	check("clean_unlocks max 16", Cos.clean_unlocks(veel).size() == Profiel.MAX_UNLOCKS)
	check("clean_unlocks ontdubbelt", Cos.clean_unlocks(["a", "a", "b"]).size() == 2)
	check("standaard blijft beschikbaar bij rommel-unlocks", Cos.is_available("haar_kort", [null, 1, {}], doc))
	# Vervalste bron in de lijst zelf: ongeldige unlock-id nooit beschikbaar.
	check("item met ongeldige unlock-id nooit beschikbaar", not Cos.is_available("boven_vals", ["VALS"], doc) and not Cos.is_available("boven_vals", ["vals"], doc))
	check("item met onbekende bron valt weg", Cos.item("onder_raar", doc).is_empty())
	check("kapotte nep-lijst crasht niet", Cos.items({"items": "geen lijst"}).is_empty() and not Cos.look_allowed(Profiel.default_look(), [], {"lagen": 5}))


func _look_codering_tests() -> void:
	check("LOOK_VERSION blijft 1", Profiel.LOOK_VERSION == 1)
	check("LOOK_BYTES blijft 16", Profiel.LOOK_BYTES == 16)
	for it in Cos.items():
		var look := Profiel.default_look()
		look[str(it["look_key"])] = int(it["look_index"])
		var bytes := Profiel.encode_look(look)
		var terug := Profiel.decode_look(bytes)
		check("%s: look roundtrip via 16 bytes" % it["id"], bytes.size() == 16 and terug == look)


func _nep_doc() -> Dictionary:
	var echt := Cos.catalog()
	var lijst: Array = (echt["items"] as Array).duplicate(true)
	var kap: Dictionary = Cos.item("hoofd_kap").duplicate(true)
	kap["id"] = "hoofd_kroon"
	kap["look_index"] = 3
	kap["bron"] = "unlock:kroon_d50"
	lijst.append(kap)
	var vals: Dictionary = Cos.item("boven_tuniek").duplicate(true)
	vals["id"] = "boven_vals"
	vals["look_index"] = 9
	vals["bron"] = "unlock:VALS"
	lijst.append(vals)
	var raar: Dictionary = Cos.item("onder_rok").duplicate(true)
	raar["id"] = "onder_raar"
	raar["look_index"] = 7
	raar["bron"] = "gekocht"
	lijst.append(raar)
	return {"version": 1, "look_version": 1, "sheets": echt["sheets"], "lagen": echt["lagen"], "items": lijst}


func _png_maat(pad: String) -> Vector2i:
	if pad == "" or not FileAccess.file_exists(pad):
		return Vector2i(-1, -1)
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(pad)) != OK:
		return Vector2i(-2, -2)
	return img.get_size()


func _alle_keys(d: Dictionary, keys: Array) -> bool:
	for k in keys:
		if not d.has(k):
			return false
	return true


func _bevat(lijst: PackedStringArray, deel: String) -> bool:
	for r in lijst:
		if r.contains(deel):
			return true
	return false
