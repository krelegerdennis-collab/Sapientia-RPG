extends Node
## ITEMCONTROLE WM1 — kijkt alle itemdata na en schrijft een rapport (Markdown). Repareert niets.
##
## Gebruik (vanuit de projectmap, na één keer --import):
##   Godot --headless --path . res://tools/check_items.tscn -- --out=ITEM_AUDIT.md
## Via een scène en niet via --script: de data-scripts gebruiken autoloads (GameState), en die
## laadt Godot niet in --script-modus.
## Zonder --out komt het rapport alleen op stdout. Exitcode 0 = geen FOUT, 1 = minstens één FOUT.
##
## Catalogus (zelfde bronnen als ItemIcons.catalog_ids + de uitrusting die Equipment.is_equipment kent):
##   GameData.ITEMS / KEY_ITEMS / EQUIPMENT, GradeGear.ITEMS (bg_*), BerggrotData-uitrusting,
##   KernData.KERNFRAGMENTEN.
## Controles:
##   1. id's     — uniek binnen een tabel (ook dubbele sleutels in de bron), uniek over alle tabellen,
##                 vorm [a-z0-9_]; MAPPING.csv zonder dubbele rijen.
##   2. iconen   — MAPPING.csv-bestanden bestaan, zijn geïmporteerd en 16x16 / 32x32; "icon"-velden
##                 bestaan; categorie-iconen bestaan; MAPPING-rij zonder item; item zonder MAPPING-rij.
##   3. prijzen  — "price" > 0 in ITEMS/EQUIPMENT/berggrot; winkel- en Koopmanprijzen > 0;
##                 grade-prijs (grade² x 60) > 0. Sleutelvoorwerpen en kernfragmenten worden niet verkocht.
##   4. namen    — geen dubbele spelersnaam ("name"/"naam") over de hele catalogus.
##   5. Engels   — naam aanwezig, niet gelijk aan het id, geen Nederlandse woorden (heuristiek) in
##                 name/short/affix-naam; Nederlandse functiewoorden in desc.
##   6. verwijzingen — item-id's in winkels, Koopman, Werkplaats, START_INVENTORY, "item"-velden in
##                 scripts/data/*.gd en "teach" van spreukrollen bestaan.

const GameData := preload("res://scripts/data/game_data.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const ShopData := preload("res://scripts/data/shop_data.gd")
const KoopmanWinkel := preload("res://scripts/data/koopman_winkel.gd")
const Werkplaats := preload("res://scripts/data/werkplaats_recepten.gd")
const ItemIcons := preload("res://scripts/data/item_icons.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")

const F_GAME := "scripts/data/game_data.gd"
const F_GRADE := "scripts/data/grade_gear.gd"
const F_KERN := "scripts/data/kern_data.gd"
const F_BERG := "scripts/data/berggrot_data.gd"
const F_SHOP := "scripts/data/shop_data.gd"
const F_KOOP := "scripts/data/koopman_winkel.gd"
const F_WERK := "scripts/data/werkplaats_recepten.gd"
const F_ICONS := "scripts/data/item_icons.gd"
const F_SCAL := "scripts/data/dungeon100_scaling.gd"
const F_BLUE := "scripts/data/dungeon100_blue.gd"
const F_MAP := "assets/ui/icons/items/MAPPING.csv"

const FOUT := "FOUT"
const LET_OP := "LET OP"

## Woorden die in een Engelse itemnaam niet horen (kleine letters, hele woorden).
const NL_WOORDEN: Array[String] = [
	"de", "het", "een", "van", "en", "met", "voor", "zwaard", "staf", "schild", "harnas", "laarzen",
	"benen", "kist", "sleutel", "boek", "kruid", "drank", "drankje", "toverwater", "kern", "rol",
	"spreuk", "ijzeren", "leren", "houten", "eiken", "oude", "emmer", "veer", "gif", "bom", "notitie",
	"meel", "zaad", "steen", "vuur", "bliksem", "genees", "goud", "zilver", "zilveren", "gouden",
	"pantser", "wapen", "kling", "ketel", "ader", "berg", "kap", "mantel", "gewaad", "ringetje",
]
## Functiewoorden die in een Engelse beschrijving niet horen.
const NL_FUNCTIEWOORDEN: Array[String] = [
	"de", "het", "een", "van", "niet", "met", "voor", "zijn", "ik", "je", "wordt", "naar", "en", "ook",
]

var findings: Array[Dictionary] = []
var catalog: Array[Dictionary] = []   # {id, tabel, file, line, end, data}
var by_id: Dictionary = {}            # id -> Array[Dictionary] (catalogusregels)
var _lines_cache: Dictionary = {}
var stats: Dictionary = {}


func _ready() -> void:
	var out_path := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--out="):
			out_path = str(a).substr(6)
	_selftest()
	_build_catalog()
	_check_ids()
	_check_icons()
	_check_prices()
	_check_names()
	_check_english()
	_check_refs()
	var md := _report()
	print(md)
	if out_path != "":
		var p := out_path if out_path.is_absolute_path() else ProjectSettings.globalize_path("res://" + out_path)
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			push_error("check_items: kan %s niet schrijven" % p)
		else:
			f.store_string(md)
			f.close()
			print("check_items: rapport geschreven naar ", p)
	var n_fout := _count(FOUT)
	print("RESULT %s (%d FOUT, %d LET OP)" % ["OK" if n_fout == 0 else "FAIL", n_fout, _count(LET_OP)])
	get_tree().quit(1 if n_fout > 0 else 0)


## Vangt de heuristiek bekende gevallen? Anders zegt "geen bevindingen" niets.
func _selftest() -> void:
	var goed := [
		_dutch_hits("Ijzeren Zwaard", NL_WOORDEN, true).size() == 2,
		_dutch_hits("Maliënkolder", NL_WOORDEN, true).size() == 1,
		_dutch_hits("Short Sword", NL_WOORDEN, true).is_empty(),
		_dutch_hits("Mountain Vein Staff", NL_WOORDEN, true).is_empty(),
		_dutch_hits("Een zwaard van de Oude Man.", NL_FUNCTIEWOORDEN, false).size() == 3,
		_dutch_hits("The Old Man's sword. Light and honest.", NL_FUNCTIEWOORDEN, false).is_empty(),
	]
	for i in goed.size():
		if not bool(goed[i]):
			_add(FOUT, "engels", "tools/check_items.gd", 0, "", "zelftest %d van de Nederlands-heuristiek faalt" % i)


# ---------------------------------------------------------------- bron lezen

func _lines(file: String) -> PackedStringArray:
	if not _lines_cache.has(file):
		var t := FileAccess.get_file_as_string("res://" + file)
		_lines_cache[file] = t.split("\n")
	return _lines_cache[file]


## Sleutels op het hoogste niveau van 'const NAAM := {' ... '}' met hun regelnummer (1-based).
## Geeft [{key, line, end}] in bronvolgorde; dubbele sleutels blijven allebei staan.
func _block_keys(file: String, const_name: String) -> Array[Dictionary]:
	var lines := _lines(file)
	var head := RegEx.create_from_string("^const\\s+" + const_name + "\\b.*\\{\\s*$")
	var key_re := RegEx.create_from_string("^\\t\"([^\"]+)\"\\s*:")
	var out: Array[Dictionary] = []
	var start := -1
	for i in lines.size():
		if head.search(lines[i]) != null:
			start = i
			break
	if start < 0:
		return out
	var end := lines.size() - 1
	for i in range(start + 1, lines.size()):
		if lines[i].strip_edges(false, true) == "}":
			end = i
			break
		var m := key_re.search(lines[i])
		if m != null:
			out.append({"key": m.get_string(1), "line": i + 1, "end": end + 1})
	for j in out.size():
		out[j]["end"] = (int(out[j + 1]["line"]) - 1) if j + 1 < out.size() else end
	return out


func _find_line(file: String, pattern: String, from: int = 1, to: int = -1) -> int:
	var lines := _lines(file)
	var re := RegEx.create_from_string(pattern)
	var last := lines.size() if to < 0 else mini(to, lines.size())
	for i in range(maxi(0, from - 1), last):
		if re.search(lines[i]) != null:
			return i + 1
	return 0


## Regel van veld 'field' binnen de catalogusregel (anders de eerste regel van het item).
func _field_line(e: Dictionary, field: String) -> int:
	var l := _find_line(str(e["file"]), "\"" + field + "\"\\s*:", int(e["line"]), int(e["end"]))
	return l if l > 0 else int(e["line"])


# ---------------------------------------------------------------- catalogus

func _add_table(tabel: String, file: String, const_name: String, data: Dictionary) -> void:
	var keys := _block_keys(file, const_name)
	var seen := {}
	for k in keys:
		var id := str(k["key"])
		if seen.has(id):
			_add(FOUT, "id", file, int(k["line"]), id,
				"dubbele sleutel in %s (eerste op regel %d); Godot houdt alleen de laatste" % [const_name, int(seen[id])])
			continue
		seen[id] = int(k["line"])
		_register({"id": id, "tabel": tabel, "file": file, "line": int(k["line"]), "end": int(k["end"]),
			"data": data.get(id, {})})
	for id in data:
		if not seen.has(str(id)):
			_register({"id": str(id), "tabel": tabel, "file": file, "line": 0, "end": 0, "data": data[id]})
	stats[tabel] = data.size()


func _register(e: Dictionary) -> void:
	catalog.append(e)
	var id := str(e["id"])
	if not by_id.has(id):
		by_id[id] = []
	(by_id[id] as Array).append(e)


func _build_catalog() -> void:
	_add_table("ITEMS", F_GAME, "ITEMS", GameData.ITEMS)
	_add_table("KEY_ITEMS", F_GAME, "KEY_ITEMS", GameData.KEY_ITEMS)
	_add_table("EQUIPMENT", F_GAME, "EQUIPMENT", GameData.EQUIPMENT)
	_add_table("GradeGear", F_GRADE, "ITEMS", GradeGear.ITEMS)
	_add_table("KERNFRAGMENTEN", F_KERN, "KERNFRAGMENTEN", KernData.KERNFRAGMENTEN)
	# Berggrot: twee stukken uit een functie (_gear), sleutels zijn constanten.
	var n := 0
	for pair in [["STAF_ID", BerggrotData.STAF_ID], ["ACCESSOIRE_ID", BerggrotData.ACCESSOIRE_ID]]:
		var id := str(pair[1])
		var l := _find_line(F_BERG, "^\\s*" + str(pair[0]) + "\\s*:\\s*\\{")
		_register({"id": id, "tabel": "Berggrot", "file": F_BERG, "line": l, "end": l + 12,
			"data": BerggrotData.gear(id)})
		n += 1
	stats["Berggrot"] = n


func _name_of(d: Dictionary) -> String:
	return str(d.get("name", d.get("naam", "")))


# ---------------------------------------------------------------- 1. id's

func _check_ids() -> void:
	var id_re := RegEx.create_from_string("^[a-z0-9_]+$")
	for id in by_id:
		var rows: Array = by_id[id]
		if rows.size() > 1:
			var waar: Array[String] = []
			for e in rows:
				waar.append("%s (%s:%d)" % [e["tabel"], e["file"], e["line"]])
			for e in rows:
				_add(FOUT, "id", str(e["file"]), int(e["line"]), str(id),
					"id staat in meer dan één tabel: " + ", ".join(waar))
		if id_re.search(str(id)) == null:
			var e0: Dictionary = rows[0]
			_add(LET_OP, "id", str(e0["file"]), int(e0["line"]), str(id), "id is niet [a-z0-9_]")
	for e in catalog:
		var d: Dictionary = e["data"]
		if d.has("id") and str(d["id"]) != str(e["id"]):
			_add(FOUT, "id", str(e["file"]), _field_line(e, "id"), str(e["id"]),
				"veld \"id\" (%s) is niet gelijk aan de sleutel" % d["id"])


# ---------------------------------------------------------------- 2. iconen

func _check_icons() -> void:
	var map_ids := {}
	var rows := _lines(F_MAP)
	for i in range(1, rows.size()):
		var raw := rows[i].strip_edges()
		if raw == "":
			continue
		var cols := raw.split(",")
		var line := i + 1
		if cols.size() < 3:
			_add(FOUT, "icoon", F_MAP, line, "", "rij heeft minder dan 3 kolommen")
			continue
		var id := cols[0].strip_edges()
		if map_ids.has(id):
			_add(FOUT, "icoon", F_MAP, line, id, "dubbele rij (eerste op regel %d)" % int(map_ids[id]))
			continue
		map_ids[id] = line
		if not by_id.has(id):
			_add(FOUT, "icoon", F_MAP, line, id, "MAPPING-rij voor een id dat niet in de catalogus staat")
		_check_icon_file(F_MAP, line, id, ItemIcons.ROOT + cols[1].strip_edges(), 16)
		_check_icon_file(F_MAP, line, id, ItemIcons.ROOT + cols[2].strip_edges(), 32)
	stats["MAPPING-rijen"] = map_ids.size()
	# Expliciete "icon"-velden (schatkist-icoon, kernfragment-menu).
	for e in catalog:
		var d: Dictionary = e["data"]
		if d.has("icon"):
			_check_icon_file(str(e["file"]), _field_line(e, "icon"), str(e["id"]), str(d["icon"]), 16)
	# Terugval-iconen.
	var cats := {"CAT_VERBRUIK": ItemIcons.CAT_VERBRUIK, "CAT_SLEUTEL": ItemIcons.CAT_SLEUTEL,
		"CAT_WAPEN": ItemIcons.CAT_WAPEN, "CAT_HARNAS": ItemIcons.CAT_HARNAS, "CAT_ACCESSOIRE": ItemIcons.CAT_ACCESSOIRE}
	for c in cats:
		var p := str(cats[c])
		if not ResourceLoader.exists(p):
			_add(FOUT, "icoon", F_ICONS, _find_line(F_ICONS, "^const " + str(c)), str(c), "categorie-icoon ontbreekt: " + p)
	# Items zonder eigen icoon vallen terug op het categorie-icoon.
	for e in catalog:
		var id := str(e["id"])
		if not map_ids.has(id):
			_add(LET_OP, "icoon", str(e["file"]), int(e["line"]), id,
				"geen rij in %s: toont het categorie-icoon (%s)" % [F_MAP, ItemIcons.path16(id).get_file()])


func _check_icon_file(file: String, line: int, id: String, path: String, px: int) -> void:
	if not FileAccess.file_exists(path):
		_add(FOUT, "icoon", file, line, id, "icoonbestand bestaat niet: " + path)
		return
	if not ResourceLoader.exists(path):
		_add(FOUT, "icoon", file, line, id, "icoonbestand niet geïmporteerd (geen .import): " + path)
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) != OK:
		_add(FOUT, "icoon", file, line, id, "icoonbestand is geen leesbaar beeld: " + path)
		return
	if img.get_width() != px or img.get_height() != px:
		_add(FOUT if file == F_MAP else LET_OP, "icoon", file, line, id,
			"icoon is %dx%d, verwacht %dx%d: %s" % [img.get_width(), img.get_height(), px, px, path])


# ---------------------------------------------------------------- 3. prijzen

func _shop_offer_ids() -> Dictionary:
	var out := {}
	for shop_id in ShopData.SHOPS:
		for offer in ShopData.SHOPS[shop_id].get("offers", []):
			var id := str(offer.get("id", ""))
			if not out.has(id):
				out[id] = []
			(out[id] as Array).append(str(shop_id))
	return out


func _check_prices() -> void:
	var in_shop := _shop_offer_ids()
	var basis: Dictionary = KoopmanWinkel.BASIS_PRIJS
	for e in catalog:
		var tabel := str(e["tabel"])
		var id := str(e["id"])
		var d: Dictionary = e["data"]
		if tabel == "KEY_ITEMS" or tabel == "KERNFRAGMENTEN":
			continue
		if tabel == "GradeGear":
			var g := int(d.get("grade", 0))
			if g * g * 60 <= 0:
				_add(FOUT, "prijs", str(e["file"]), _field_line(e, "grade"), id,
					"grade %d geeft prijs %d (ShopData._data_price: grade² x 60)" % [g, g * g * 60])
			continue
		var effectief := ShopData.list_price(id)
		var extra := ""
		if effectief > 0:
			extra = "; winkelprijs via ShopData.list_price = %d" % effectief
		elif basis.has(id):
			extra = "; alleen KoopmanWinkel.BASIS_PRIJS = %d" % int(basis[id])
		else:
			extra = "; niet te koop en niet te verkopen (verkoopprijs 0)"
		if not d.has("price"):
			_add(LET_OP, "prijs", str(e["file"]), int(e["line"]), id, "geen \"price\"-veld" + extra)
		elif int(d["price"]) < 0:
			_add(FOUT, "prijs", str(e["file"]), _field_line(e, "price"), id, "negatieve prijs %d" % int(d["price"]))
		elif int(d["price"]) == 0:
			_add(LET_OP, "prijs", str(e["file"]), _field_line(e, "price"), id, "\"price\": 0" + extra)
		if in_shop.has(id) and effectief <= 0:
			_add(FOUT, "prijs", str(e["file"]), int(e["line"]), id,
				"ligt in winkel %s maar de vraagprijs is %d" % [", ".join(in_shop[id]), effectief])
	# Prijzen die los in winkel- en Koopmandata staan.
	for shop_id in ShopData.SHOPS:
		for offer in ShopData.SHOPS[shop_id].get("offers", []):
			if offer.has("price") and int(offer["price"]) <= 0:
				var id := str(offer.get("id", ""))
				_add(FOUT, "prijs", F_SHOP, _find_line(F_SHOP, "\"id\":\\s*\"" + id + "\".*\"price\""), id,
					"winkel %s: offer-prijs %d" % [shop_id, int(offer["price"])])
	for id in basis:
		if int(basis[id]) <= 0:
			_add(FOUT, "prijs", F_KOOP, _find_line(F_KOOP, "\"" + str(id) + "\"\\s*:"), str(id),
				"BASIS_PRIJS %d" % int(basis[id]))
	if int(KoopmanWinkel.STUNBOM_PRIJS) <= 0:
		_add(FOUT, "prijs", F_KOOP, _find_line(F_KOOP, "^const STUNBOM_PRIJS"), "stunbom", "STUNBOM_PRIJS <= 0")


# ---------------------------------------------------------------- 4. dubbele namen

func _check_names() -> void:
	var groups := {}
	for e in catalog:
		var n := _name_of(e["data"]).strip_edges().to_lower()
		if n == "":
			continue
		if not groups.has(n):
			groups[n] = []
		(groups[n] as Array).append(e)
	for n in groups:
		var rows: Array = groups[n]
		if rows.size() < 2:
			continue
		var ids: Array[String] = []
		for e in rows:
			ids.append("%s (%s:%d)" % [e["id"], e["file"], e["line"]])
		for e in rows:
			var veld := "name" if (e["data"] as Dictionary).has("name") else "naam"
			_add(FOUT, "naam", str(e["file"]), _field_line(e, veld), str(e["id"]),
				"naam \"%s\" komt %dx voor: %s" % [_name_of(e["data"]), rows.size(), ", ".join(ids)])


# ---------------------------------------------------------------- 5. Engelse namen

func _words(s: String) -> PackedStringArray:
	var re := RegEx.create_from_string("[A-Za-zÀ-ÿ]+")
	var out := PackedStringArray()
	for m in re.search_all(s):
		out.append(m.get_string().to_lower())
	return out


## Lijst van Nederlandse kenmerken in 's' (leeg = lijkt Engels).
func _dutch_hits(s: String, woorden: Array[String], ij: bool) -> Array[String]:
	var hits: Array[String] = []
	for w in _words(s):
		if w in woorden:
			hits.append("\"" + w + "\"")
		elif ij and w.contains("ij"):
			hits.append("\"" + w + "\" (ij)")
	var lat := RegEx.create_from_string("[À-ÿ]")
	if ij and lat.search(s) != null:
		hits.append("letter met accent")
	return hits


func _check_english() -> void:
	for e in catalog:
		var id := str(e["id"])
		var d: Dictionary = e["data"]
		var veld := "naam" if str(e["tabel"]) == "KERNFRAGMENTEN" else "name"
		var naam := str(d.get(veld, "")).strip_edges()
		if naam == "":
			_add(FOUT, "engels", str(e["file"]), int(e["line"]), id, "geen spelersnaam (\"%s\")" % veld)
			continue
		# Kan bewust zijn (een eigennaam als "Memoria"), daarom LET OP.
		if naam.to_lower() == id.to_lower() or naam.to_lower().replace(" ", "_") == id.to_lower():
			_add(LET_OP, "engels", str(e["file"]), _field_line(e, veld), id, "naam is gelijk aan het id: \"%s\"" % naam)
		var hits := _dutch_hits(naam, NL_WOORDEN, true)
		if not hits.is_empty():
			_add(FOUT, "engels", str(e["file"]), _field_line(e, veld), id,
				"naam \"%s\" lijkt Nederlands: %s" % [naam, ", ".join(hits)])
		if d.has("short"):
			var sh := str(d["short"])
			var h2 := _dutch_hits(sh, NL_WOORDEN, true)
			if sh.strip_edges() == "":
				_add(FOUT, "engels", str(e["file"]), _field_line(e, "short"), id, "lege \"short\"")
			elif not h2.is_empty():
				_add(FOUT, "engels", str(e["file"]), _field_line(e, "short"), id,
					"short \"%s\" lijkt Nederlands: %s" % [sh, ", ".join(h2)])
		for dk in ["desc", "beschrijving"]:
			if d.has(dk):
				var h3 := _dutch_hits(str(d[dk]), NL_FUNCTIEWOORDEN, false)
				if not h3.is_empty():
					_add(LET_OP, "engels", str(e["file"]), _field_line(e, dk), id,
						"%s bevat Nederlandse woorden: %s" % [dk, ", ".join(h3)])
		for a in d.get("affixen", []):
			var an := str((a as Dictionary).get("naam", ""))
			var h4 := _dutch_hits(an, NL_WOORDEN, true)
			if an == "" or not h4.is_empty():
				_add(FOUT, "engels", str(e["file"]), _field_line(e, "affixen"), id,
					"affix-naam \"%s\" ontbreekt of lijkt Nederlands" % an)


# ---------------------------------------------------------------- 6. verwijzingen

func _ref(file: String, line: int, id: String, waar: String) -> void:
	if not by_id.has(id):
		_add(FOUT, "verwijzing", file, line, id, waar + " verwijst naar een onbekend item")


func _check_refs() -> void:
	for shop_id in ShopData.SHOPS:
		for offer in ShopData.SHOPS[shop_id].get("offers", []):
			var id := str(offer.get("id", ""))
			_ref(F_SHOP, _find_line(F_SHOP, "\"id\":\\s*\"" + id + "\""), id, "winkel " + str(shop_id))
	for id in KoopmanWinkel.BASIS_PRIJS:
		_ref(F_KOOP, _find_line(F_KOOP, "\"" + str(id) + "\"\\s*:"), str(id), "KoopmanWinkel.BASIS_PRIJS")
	var lijsten := {"CONSUMABLES": KoopmanWinkel.CONSUMABLES, "ROTATIE": KoopmanWinkel.ROTATIE,
		"BASIS_CONSUMABLES": KoopmanWinkel.BASIS_CONSUMABLES}
	for lijst in lijsten:
		for id in lijsten[lijst]:
			_ref(F_KOOP, _find_line(F_KOOP, "^const " + str(lijst)), str(id), "KoopmanWinkel." + str(lijst))
	_ref(F_KOOP, _find_line(F_KOOP, "^const STUNBOM "), str(KoopmanWinkel.STUNBOM), "KoopmanWinkel.STUNBOM")
	for r in Werkplaats.RECEPTEN:
		var l := _find_line(F_WERK, "\"id\":\\s*\"" + str(r.get("id", "")) + "\"")
		_ref(F_WERK, l, str(r.get("uit", "")), "recept %s (uit)" % r.get("id", ""))
		for inn in r.get("in", {}):
			_ref(F_WERK, l, str(inn), "recept %s (in)" % r.get("id", ""))
	for id in GameData.START_INVENTORY:
		_ref(F_GAME, _find_line(F_GAME, "^const START_INVENTORY"), str(id), "START_INVENTORY")
	# Buitlijsten van de 100-verdiepingen-grot en de rollenpools.
	for tier in Scaling.POTIONS:
		for id in tier:
			_ref(F_SCAL, _find_line(F_SCAL, "^const POTIONS"), str(id), "Dungeon100Scaling.POTIONS")
	for soort in Scaling.GEAR:
		for id in Scaling.GEAR[soort]:
			_ref(F_SCAL, _find_line(F_SCAL, "^\\s*\"" + str(soort) + "\"\\s*:\\s*\\["), str(id), "Dungeon100Scaling.GEAR")
	for id in Scaling.SPELL_SCROLLS:
		_ref(F_SCAL, _find_line(F_SCAL, "^const SPELL_SCROLLS"), str(id), "Dungeon100Scaling.SPELL_SCROLLS")
	_ref(F_SCAL, _find_line(F_SCAL, "^const BOOK_ID"), str(Scaling.BOOK_ID), "Dungeon100Scaling.BOOK_ID")
	_ref(F_BLUE, _find_line(F_BLUE, "^const WARP_ITEM"), str(Blue.WARP_ITEM), "Dungeon100Blue.WARP_ITEM")
	for id in GradeGear.SCROLLS:
		_ref(F_GRADE, _find_line(F_GRADE, "\"" + str(id) + "\""), str(id), "GradeGear.SCROLLS")
	for id in GradeGear.LEGACY_SCROLLS:
		_ref(F_GRADE, _find_line(F_GRADE, "^const LEGACY_SCROLLS"), str(id), "GradeGear.LEGACY_SCROLLS")
	for pair in ItemIcons.SHARED_SPELLS:
		for id in pair:
			_ref(F_ICONS, _find_line(F_ICONS, "\"" + str(id) + "\""), str(id), "ItemIcons.SHARED_SPELLS")
	# Spreukrollen: "teach" moet een bestaande spreuk zijn.
	for e in catalog:
		var d: Dictionary = e["data"]
		if d.has("teach") and not GameData.SPELLS.has(str(d["teach"])):
			_add(FOUT, "verwijzing", str(e["file"]), _field_line(e, "teach"), str(e["id"]),
				"\"teach\": \"%s\" is geen spreuk in spells.gd" % d["teach"])
	# Alle letterlijke "item": "<id>" in de data (kisten, buit, beloningen, drops).
	var item_re := RegEx.create_from_string("\"item\"\\s*:\\s*\"([^\"]*)\"")
	var n := 0
	var dir := DirAccess.open("res://scripts/data")
	var files := dir.get_files() if dir != null else PackedStringArray()
	for fn in files:
		if not fn.ends_with(".gd"):
			continue
		var file := "scripts/data/" + fn
		var lines := _lines(file)
		for i in lines.size():
			if lines[i].strip_edges().begins_with("#"):
				continue
			for m in item_re.search_all(lines[i]):
				n += 1
				_ref(file, i + 1, m.get_string(1), "\"item\"-veld")
	stats["\"item\"-verwijzingen"] = n


# ---------------------------------------------------------------- rapport

func _add(sev: String, check: String, file: String, line: int, id: String, msg: String) -> void:
	findings.append({"sev": sev, "check": check, "file": file, "line": line, "id": id, "msg": msg})


func _count(sev: String, check: String = "") -> int:
	var n := 0
	for f in findings:
		if str(f["sev"]) == sev and (check == "" or str(f["check"]) == check):
			n += 1
	return n


func _report() -> String:
	var checks := [
		["id", "1. Unieke id's"],
		["icoon", "2. Iconen"],
		["prijs", "3. Prijzen"],
		["naam", "4. Dubbele namen"],
		["engels", "5. Engelse spelersnamen"],
		["verwijzing", "6. Verwijzingen naar items"],
	]
	var s := "# ITEM_AUDIT — WM1-itemdata\n\n"
	s += "Gegenereerd door `tools/check_items.gd` (Godot %s). Het script repareert niets.\n\n" % Engine.get_version_info().get("string", "?")
	s += "```\nGodot --headless --path . res://tools/check_items.tscn -- --out=ITEM_AUDIT.md\n```\n\n"
	s += "## Gecontroleerd\n\n| bron | aantal |\n|---|---|\n"
	for k in stats:
		s += "| %s | %d |\n" % [k, int(stats[k])]
	s += "| **catalogus totaal** | %d |\n\n" % catalog.size()
	s += "## Samenvatting\n\n| controle | FOUT | LET OP |\n|---|---|---|\n"
	for c in checks:
		s += "| %s | %d | %d |\n" % [c[1], _count(FOUT, c[0]), _count(LET_OP, c[0])]
	s += "| **totaal** | **%d** | **%d** |\n\n" % [_count(FOUT), _count(LET_OP)]
	s += "FOUT = in strijd met de regel. LET OP = afwijking die (waarschijnlijk) bewust is of alleen een terugval geeft.\n\n"
	for c in checks:
		s += "## %s\n\n" % c[1]
		var rows: Array[Dictionary] = []
		for f in findings:
			if str(f["check"]) == c[0]:
				rows.append(f)
		if rows.is_empty():
			s += "Geen bevindingen.\n\n"
			continue
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["sev"] != b["sev"]:
				return a["sev"] == FOUT
			if a["file"] != b["file"]:
				return str(a["file"]) < str(b["file"])
			return int(a["line"]) < int(b["line"]))
		s += "| ernst | bestand:regel | id | probleem |\n|---|---|---|---|\n"
		for f in rows:
			s += "| %s | `%s:%d` | `%s` | %s |\n" % [f["sev"], f["file"], f["line"], f["id"],
				str(f["msg"]).replace("|", "\\|")]
		s += "\n"
	return s
