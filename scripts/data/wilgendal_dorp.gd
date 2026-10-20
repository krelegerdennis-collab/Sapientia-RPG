extends RefCounted
## Dorp Wilgendal (v2, Dennis 14 okt 2026: ruimer, ~3x zo groot): winkelstraat, marktplein, beek met
## brug, zijstraten. Vier winkelpanden, vier woonhuizen, vijf sfeer-NPC's verspreid (max 2 op het plein).
## Props (put, kramen, hekken, bloembakken, beek, brug, lantaarns, bankjes): RPG ART, zie PROPS.
## Prijzen en voorraad blijven in shop_data.gd. De molen blijft de molen.
## Winkels zijn altijd open. Er is geen tijdsysteem.

const DORP := "res://scenes/maps/dorp_wilgendal.tscn"
const BINNEN := "res://scenes/maps/wilgendal_binnen.tscn"
const WERELD := "res://scenes/maps/wereldkaart.tscn"
const ALTIJD_OPEN := true
const W := 64
const H := 40
const PLEIN := Rect2i(26, 11, 19, 5)
## v3 (Dennis 14 okt 2026): reuzenmolen v2 (RPG ART, 14x20 tegels) in het nieuwe westdeel. De molen
## steekt uit over de beek: alleen de voet (sprite-rijen 17-19, kolommen 2-11) blokkeert; achter (noord
## van) de molen loop je vrij en verdwijn je achter de toren (y-sort op de onderrand).
const MOLEN_OORSPRONG := Vector2i(1, 1)
const MOLEN_MAAT := Vector2i(14, 20)
const MOLEN := Rect2i(MOLEN_OORSPRONG + Vector2i(2, 17), Vector2i(10, 3))
const MOLEN_DEUR: Array[Vector2i] = [Vector2i(7, 20), Vector2i(8, 20)]
const SPAWN_ZUID := "zuid_ingang"
const SPAWN_TEGEL := Vector2i(35, 37)
const EXIT_TEGEL := Vector2i(34, 39)
const EXIT_MAAT := Vector2i(3, 1)
const GERRIT_TEGEL := Vector2i(10, 22)
## v4 (Dennis 14 okt 2026): grotere SoM-huizen (6 breed) en paden van 2-3 tegels; kaart 64x40.
## Beek: één tegel breed, rij BEEK_RIJ over de hele breedte; de brug (BRUG) is beloopbaar.
const BEEK_RIJ := 17
const BRUG := Rect2i(34, 16, 3, 3)
## Hoogstens zoveel sfeer-NPC's op het marktplein (besluit Dennis: 2-3).
const PLEIN_MAX := 2

const GROND: Array[String] = [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"T..............................................................T",
	"T..............................................................T",
	"T..............................................................T",
	"T..............................................................T",
	"T..............................................................T",
	"T..............................................................T",
	"T..............................................................T",
	"T..............................................................T",
	"T.============================================================.T",
	"T.============================================================.T",
	"T.........................###################..................T",
	"T.........................###################..................T",
	"T.................T.......###################......T...........T",
	"T.....................T...###################.............T....T",
	"T.........................###################..................T",
	"T..............FFGFF..............===.........FFFFF............T",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBB~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"T.................................===..........................T",
	"T.................................===..........................T",
	"T.................................===..........................T",
	"T...=================================..........................T",
	"T...=================================..........................T",
	"T.................................===..........................T",
	"T.................................===..........................T",
	"T.....FFFFFF................T.....===..........................T",
	"T.....F....F......................===............==............T",
	"T.....F....F......................===............==............T",
	"T.....FFGFFF......................===...T........==............T",
	"T.................................===............==............T",
	"T...........T.....................===............==............T",
	"T...............==============================================.T",
	"T...............==============================================.T",
	"T.................................===..........................T",
	"T.......T.........................===..........................T",
	"T.................................===..........................T",
	"T.....................T...........===.......T.....T............T",
	"T............................T....===..........................T",
	"T.................................===..........................T",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT===TTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

const TEGEL := {
	"T": 3,
	".": 0,
	"=": 2,
	"#": 33,
	"~": 0,      # beek: gras eronder, de beek-art ligt erover (PROPS/dorp_opbouw)
	"B": 2,      # pad onder de brug
	"F": 0,      # hek (SoM: autotile uit hekken.png, oud: props hek_*)
	"G": 0,      # poort (E-W)
}

const SFEER_KLEUR := {
	"stoer": Color(0.72, 0.76, 0.84),
	"ambacht": Color(1.0, 0.84, 0.62),
	"sier": Color(1.0, 0.78, 0.86),
	"mystiek": Color(0.72, 0.62, 1.0),
	"kruid": Color(0.78, 0.95, 0.75),
	"haard": Color(1.0, 0.9, 0.72),
}

## id, kind (winkel|huis), shop_id leeg als er niets te koop is.
const PANDEN := [
	{
		"id": "pantser",
		"kind": "winkel",
		"shop_id": "wilgendal_pantser",
		"oorsprong": Vector2i(19, 6),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(20, 8),
		"icoon": "schild",
		"tex": "pantser",
		"bewoond": false,
		"keeper_naam": "Jack Hammond",
		"keeper_lines": ["Armor and helmets."],
		"sfeer": "stoer",
		"map_naam": "Armor Shop",
		"dicht": "",
	},
	{
		"id": "wapen",
		"kind": "winkel",
		"shop_id": "wilgendal_wapen",
		"oorsprong": Vector2i(26, 6),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(27, 8),
		"icoon": "zwaard",
		"tex": "wapen",
		"bewoond": false,
		"keeper_naam": "Jack Hammond",
		"keeper_lines": ["Steel. What do you need?"],
		"sfeer": "ambacht",
		"map_naam": "Weapon Shop",
		"dicht": "",
	},
	{
		"id": "accessoire",
		"kind": "winkel",
		"shop_id": "wilgendal_accessoire",
		"oorsprong": Vector2i(41, 6),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(42, 8),
		"icoon": "ring",
		"tex": "accessoire",
		"bewoond": false,
		"keeper_naam": "Accessories",
		"keeper_lines": ["Rings and bookmarks."],
		"sfeer": "sier",
		"map_naam": "Accessory Shop",
		"dicht": "",
	},
	{
		"id": "magie",
		"kind": "winkel",
		"shop_id": "wilgendal_magie",
		"oorsprong": Vector2i(48, 6),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(49, 8),
		"icoon": "ster",
		"tex": "magie",
		"bewoond": false,
		"keeper_naam": "Magic Shop",
		"keeper_lines": ["Spells. What are you looking for?"],
		"sfeer": "mystiek",
		"map_naam": "Magic Shop",
		"dicht": "",
	},
	{
		"id": "mien",
		"kind": "huis",
		"shop_id": "wilgendal_kruiden",
		"oorsprong": Vector2i(56, 6),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(57, 8),
		"icoon": "",
		"tex": "huis",
		"bewoond": true,
		"keeper_naam": "Aunt Minna",
		"keeper_lines": ["Herbs. What do you need?"],
		"sfeer": "kruid",
		"map_naam": "Aunt Minna's House",
		"dicht": "",
	},
	{
		"id": "echtpaar",
		"kind": "huis",
		"shop_id": "",
		"oorsprong": Vector2i(56, 28),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(57, 30),
		"icoon": "",
		"tex": "huis",
		"bewoond": true,
		"keeper_naam": "",
		"keeper_lines": [],
		"sfeer": "haard",
		"map_naam": "Bramwell and Elsie's House",
		"dicht": "",
		"bord": "The hearth is still glowing. Bramwell and Elsie are out on the square.",
	},
	{
		"id": "dicht_west",
		"kind": "huis",
		"shop_id": "",
		"oorsprong": Vector2i(19, 28),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(20, 30),
		"icoon": "",
		"tex": "huis_dicht",
		"bewoond": false,
		"keeper_naam": "",
		"keeper_lines": [],
		"sfeer": "",
		"map_naam": "",
		"dicht": "The shutters are closed. Nobody lives here.",
	},
	{
		"id": "burgemeester",
		"kind": "huis",
		"shop_id": "",
		"oorsprong": Vector2i(46, 20),
		"maat": Vector2i(7, 6),
		"blok_rijen": 3,
		"deur": Vector2i(49, 25),
		"icoon": "",
		"tex": "burgemeester",
		"bewoond": false,
		"keeper_naam": "",
		"keeper_lines": [],
		"sfeer": "",
		"map_naam": "",
		"dicht": "The Mayor's House. The double doors are locked today.",
	},
]

const KAMERS := {
	"pantser": [
		"CCCCCCCCC",
		"LWW.V.WWR",
		"L...K...R",
		"L.ttttt.R",
		"L.......R",
		"L.......R",
		"L...P...R",
		"CCCCDCCCC",
	],
	"wapen": [
		"CCCCCCCCC",
		"LS..V..sR",
		"L...K..hR",
		"L.ttttt.R",
		"L..h....R",
		"L.......R",
		"L...P...R",
		"CCCCDCCCC",
	],
	"accessoire": [
		"CCCCCCCCC",
		"L..qwe..R",
		"L.V.K...R",
		"L..z.c..R",
		"L.ttttt.R",
		"L.......R",
		"L...P...R",
		"CCCCDCCCC",
	],
	"magie": [
		"CCCCCCCCC",
		"LSk.V.kSR",
		"L...K...R",
		"L.ttttt.R",
		"L...k...R",
		"L.......R",
		"L...P...R",
		"CCCCDCCCC",
	],
	"mien": [
		"CCCCCCCCC",
		"LS..V..sR",
		"L...K...R",
		"L..ttt..R",
		"L..h.h..R",
		"L.......R",
		"L...P...R",
		"CCCCDCCCC",
	],
	"echtpaar": [
		"CCCCCCCCC",
		"LS.....SR",
		"L...k...R",
		"L..hNh..R",
		"L..qwe..R",
		"L..amf..R",
		"L...P...R",
		"CCCCDCCCC",
	],
}

const SFEER := [
	{
		"node": "Bram",
		"rol": "echtpaar",
		"naam": "Bramwell",
		"tegel": Vector2i(30, 12),
		"lus": [Vector2i(30, 12), Vector2i(31, 12), Vector2i(31, 13), Vector2i(30, 13)],
		"lines": ["Elsie wants to go to the smith soon. I'm staying here on the square."],
	},
	{
		"node": "Els",
		"rol": "echtpaar",
		"naam": "Elsie",
		"tegel": Vector2i(47, 13),
		"lus": [Vector2i(47, 13), Vector2i(48, 13), Vector2i(48, 14), Vector2i(47, 14)],
		"lines": ["The shops never close. That keeps things calm."],
	},
	{
		"node": "Fien",
		"rol": "kind",
		"naam": "Fern",
		"tegel": Vector2i(39, 13),
		"lus": [Vector2i(39, 13), Vector2i(40, 13), Vector2i(40, 14), Vector2i(39, 14)],
		"lines": ["That star over there is the magic shop. I'm only allowed to look."],
	},
	{
		"node": "Wout",
		"rol": "veteraan",
		"naam": "Walt",
		"tegel": Vector2i(40, 24),
		"lus": [Vector2i(40, 24), Vector2i(41, 24), Vector2i(41, 25), Vector2i(40, 25)],
		"lines": ["I've fought enough. Now I drink tea on the square."],
	},
	{
		"node": "Siem",
		"rol": "koerier",
		"naam": "Simon",
		"tegel": Vector2i(26, 33),
		"lus": [Vector2i(26, 33), Vector2i(27, 33), Vector2i(27, 34), Vector2i(26, 34)],
		"lines": ["Mail for Willowdale. Nothing for you today."],
	},
]

## Props van RPG ART (assets/sprites/buiten/wilgendal/). "tegel" = linksboven van de blokkerende
## onderste rij, "blok" = blokkerende tegels (0 = loopbaar, bv. de brug). "flip" spiegelt horizontaal.
const PROPS_MAP := "res://assets/sprites/buiten/wilgendal/"
const PROPS := [
	{"tex": "put", "tegel": Vector2i(31, 14), "blok": Vector2i(2, 1)},
	{"tex": "marktkraam_1", "tegel": Vector2i(38, 12), "blok": Vector2i(3, 1)},
	{"tex": "marktkraam_2", "tegel": Vector2i(41, 14), "blok": Vector2i(3, 1)},
	{"tex": "marktkraam_3", "tegel": Vector2i(27, 14), "blok": Vector2i(2, 1)},
	{"tex": "bloembak_1", "tegel": Vector2i(26, 11), "blok": Vector2i(1, 1)},
	{"tex": "bloembak_2", "tegel": Vector2i(44, 11), "blok": Vector2i(1, 1)},
	{"tex": "bloembak_2", "tegel": Vector2i(26, 15), "blok": Vector2i(1, 1)},
	{"tex": "bloembak_1", "tegel": Vector2i(44, 15), "blok": Vector2i(1, 1)},
	{"tex": "lantaarnpaal", "tegel": Vector2i(33, 8), "blok": Vector2i(1, 1)},
	{"tex": "lantaarnpaal", "tegel": Vector2i(37, 8), "blok": Vector2i(1, 1)},
	{"tex": "lantaarnpaal", "tegel": Vector2i(33, 16), "blok": Vector2i(1, 1)},
	{"tex": "lantaarnpaal", "tegel": Vector2i(37, 20), "blok": Vector2i(1, 1)},
	{"tex": "lantaarnpaal", "tegel": Vector2i(24, 12), "blok": Vector2i(1, 1)},
	{"tex": "lantaarnpaal", "tegel": Vector2i(46, 12), "blok": Vector2i(1, 1)},
	{"tex": "bankje_voor", "tegel": Vector2i(38, 16), "blok": Vector2i(2, 1)},
	{"tex": "bankje_voor", "tegel": Vector2i(24, 16), "blok": Vector2i(2, 1)},
	{"tex": "bankje_voor", "tegel": Vector2i(30, 11), "blok": Vector2i(2, 1)},
	{"tex": "hek_eind", "tegel": Vector2i(15, 16), "blok": Vector2i(1, 1)},
	{"tex": "hek_h", "tegel": Vector2i(16, 16), "blok": Vector2i(1, 1)},
	{"tex": "hek_h", "tegel": Vector2i(17, 16), "blok": Vector2i(1, 1)},
	{"tex": "hek_h", "tegel": Vector2i(18, 16), "blok": Vector2i(1, 1)},
	{"tex": "hek_eind", "tegel": Vector2i(19, 16), "blok": Vector2i(1, 1), "flip": true},
	{"tex": "hek_eind", "tegel": Vector2i(46, 16), "blok": Vector2i(1, 1)},
	{"tex": "hek_h", "tegel": Vector2i(47, 16), "blok": Vector2i(1, 1)},
	{"tex": "hek_h", "tegel": Vector2i(48, 16), "blok": Vector2i(1, 1)},
	{"tex": "hek_h", "tegel": Vector2i(49, 16), "blok": Vector2i(1, 1)},
	{"tex": "hek_eind", "tegel": Vector2i(50, 16), "blok": Vector2i(1, 1), "flip": true},
]

const ICOON_VAN_WINKEL := {
	"pantser": "schild",
	"wapen": "zwaard",
	"accessoire": "ring",
	"magie": "ster",
}


## Blokkerend deel van een pand: de onderste "blok_rijen" rijen (standaard het hele pand).
## SoM-stijl: een huis uit huizen.json vervangt oorsprong/maat/blok_rijen (zie som_pand()).
static func pand_blok(rij: Dictionary) -> Rect2i:
	rij = som_pand(rij)
	var o: Vector2i = rij["oorsprong"]
	var m: Vector2i = rij["maat"]
	var n := int(rij.get("blok_rijen", m.y))
	return Rect2i(o.x, o.y + m.y - n, m.x, n)


## --- SoM-pilot (fase 3) ---
const SOM_HUIZEN := "res://assets/tilesets/som/wilgendal/huizen.json"
static var _som_huizen: Variant = null


static func som() -> bool:
	return KaartStijl.is_som(DORP)


## Alleen voor tests: huizen.json opnieuw lezen.
static func som_herladen() -> void:
	_som_huizen = null


static func som_huizen() -> Dictionary:
	if _som_huizen == null:
		_som_huizen = {}
		if FileAccess.file_exists(SOM_HUIZEN):
			var d = JSON.parse_string(FileAccess.get_file_as_string(SOM_HUIZEN))
			if d is Dictionary:
				_som_huizen = d
	return _som_huizen


## Pand in de actieve stijl. SoM: zelfde deurtegel, het huis eromheen uit huizen.json
## (alleen de muurrijen botsen; achter het dak lopen). Oud of geen SoM-huis: ongewijzigd.
static func som_pand(rij: Dictionary) -> Dictionary:
	if not som():
		return rij
	var h: Dictionary = som_huizen().get(str(rij.get("id", "")), {})
	if h.is_empty():
		return rij
	var uit := rij.duplicate()
	var deur: Vector2i = rij["deur"]
	var maat := Vector2i(int(h["maat"][0]), int(h["maat"][1]))
	var dc := Vector2i(int(h["deur"][0]), int(h["deur"][1]))
	uit["oorsprong"] = deur - dc
	uit["maat"] = maat
	uit["blok_rijen"] = int(h["muur_rijen"])
	uit["som_tex"] = SOM_HUIZEN.get_base_dir() + "/huizen/" + str(rij["id"]) + ".png"
	return uit


## Molen-node: linksonder van de basis (y-sort op de onderrand), in pixels.
static func molen_positie() -> Vector2:
	return Vector2(MOLEN_OORSPRONG.x * 16.0, (MOLEN_OORSPRONG.y + MOLEN_MAAT.y) * 16.0)


static func pand(id: String) -> Dictionary:
	for ruw in PANDEN:
		var rij: Dictionary = ruw
		if str(rij.get("id", "")) == id:
			return rij
	return {}


static func kamer_rijen(id: String) -> Array:
	return KAMERS.get(id, [])


static func winkels() -> Array:
	var uit: Array = []
	for ruw in PANDEN:
		var rij: Dictionary = ruw
		if str(rij.get("kind", "")) == "winkel":
			uit.append(rij)
	return uit


static func huizen() -> Array:
	var uit: Array = []
	for ruw in PANDEN:
		var rij: Dictionary = ruw
		if str(rij.get("kind", "")) == "huis":
			uit.append(rij)
	return uit


static func voor_tegel(rij: Dictionary) -> Vector2i:
	var deur: Vector2i = rij["deur"]
	return deur + Vector2i.DOWN


static func voor_spawn(id: String) -> String:
	return "voor_" + id


static func geen_klok() -> bool:
	if not ALTIJD_OPEN:
		return false
	for ruw in PANDEN:
		var rij: Dictionary = ruw
		for sleutel in rij:
			var naam := str(sleutel)
			if naam.contains("uur") or naam == "klok" or naam.contains("tijd"):
				return false
	return true


static func grond_ok() -> bool:
	if GROND.size() != H:
		return false
	for rij in GROND:
		if rij.length() != W:
			return false
	return true


static func beloopbaar(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= W or t.y >= H:
		return false
	if GROND[t.y][t.x] == "T":
		return false
	if MOLEN.has_point(t):
		return false
	if beek(t):
		return false
	if prop_op(t) or hek_blok(t):
		return false
	for ruw in PANDEN:
		var rij: Dictionary = ruw
		if pand_blok(rij).has_point(t):
			return false
	return true


static func bereikbaar(van: Vector2i, naar: Vector2i) -> bool:
	if van == naar:
		return beloopbaar(van)
	var gezien := {}
	var rij: Array[Vector2i] = [van]
	gezien[van] = true
	while not rij.is_empty():
		var nu: Vector2i = rij.pop_front()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var volg: Vector2i = nu + dir
			if gezien.has(volg) or not beloopbaar(volg):
				continue
			if volg == naar:
				return true
			gezien[volg] = true
			rij.append(volg)
	return false


## Beektegel (niet de brug)?
static func beek(t: Vector2i) -> bool:
	return t.y == BEEK_RIJ and not BRUG.has_point(t)


## Staat er een blokkerende prop op t?
static func prop_op(t: Vector2i) -> bool:
	for ruw in PROPS:
		if hek_prop(ruw) and som():
			continue  # SoM: de hekken zijn grondtegels (hek_blok)
		if prop_blok(ruw).has_point(t):
			return true
	return false


## Oude hek-prop (hek_eind/hek_h)? In SoM vervangen door de hek-autotiles.
static func hek_prop(rij: Dictionary) -> bool:
	return str(rij.get("tex", "")).begins_with("hek")


## --- SoM-hekken (RPG ART fase 4): grondtekens F (hek) en G (poort, E-W) ---
## Poortstand per tegel; ontbreekt = dicht. Open poort botst niet (tegel hek_poort_h_open).
static var poorten_open := {}


static func hek_teken(t: Vector2i) -> String:
	if t.x < 0 or t.y < 0 or t.x >= W or t.y >= H:
		return ""
	return GROND[t.y][t.x]


static func hek_aanwezig(t: Vector2i) -> bool:
	var c := hek_teken(t)
	return c == "F" or c == "G"


## Tegel blokkeert door een hek of een gesloten poort (alleen in SoM; oud = props).
static func hek_blok(t: Vector2i) -> bool:
	if not som():
		return false
	var c := hek_teken(t)
	return c == "F" or (c == "G" and not poort_open(t))


static func poort_open(t: Vector2i) -> bool:
	return bool(poorten_open.get(t, false))


static func poorten() -> Array[Vector2i]:
	var uit: Array[Vector2i] = []
	for y in H:
		for x in W:
			if GROND[y][x] == "G":
				uit.append(Vector2i(x, y))
	return uit


## Hekmasker N1 E2 S4 W8: buur is hek of poort.
static func hek_masker(t: Vector2i) -> int:
	var m := 0
	if hek_aanwezig(t + Vector2i.UP):
		m |= 1
	if hek_aanwezig(t + Vector2i.RIGHT):
		m |= 2
	if hek_aanwezig(t + Vector2i.DOWN):
		m |= 4
	if hek_aanwezig(t + Vector2i.LEFT):
		m |= 8
	return m


## Tegelnaam in hekken_namen.json: hek_<masker>, met een paalvariant op elke 3e rechte tegel.
static func hek_tegel(t: Vector2i) -> String:
	if hek_teken(t) == "G":
		return "hek_poort_h_open" if poort_open(t) else "hek_poort_h_dicht"
	var m := hek_masker(t)
	if m == 10 and t.x % 3 == 0:
		return "hek_10_b"
	if m == 5 and t.y % 3 == 0:
		return "hek_05_b"
	return "hek_%02d" % m


## Blokkerende tegels van een prop in de actieve stijl.
static func prop_blok(rij: Dictionary) -> Rect2i:
	var sp := som_prop(rij)
	if not sp.is_empty():
		return sp["blok"]
	return Rect2i(rij["tegel"], rij["blok"])


## --- SoM fase 3 (RPG ART): props, NPC-sheets (24x32) ---
## Oude prop -> SoM-prop uit props_index.json (botsing, y-sort-oorsprong). Hekken blijven de oude.
## "tegel" blijft linksonder van de botsing; de sprite komt erboven/eromheen volgens de index.
const SOM_PROPS_MAP := "res://assets/sprites/som/wilgendal/props/"
const SOM_PROP_VAN := {
	"put": "put",
	"marktkraam_1": "kraam_rood",
	"marktkraam_2": "kraam_blauw",
	"marktkraam_3": "kraam_groen",
	"bloembak_1": "bloembak",
	"bloembak_2": "bloembak",
	"lantaarnpaal": "lantaarn",
	"bankje_voor": "bank",
}
## NPC-node -> 72x128-sheet (3x4, offset (0,-8)). Wie hier niet staat houdt zijn oude sprite.
const SOM_NPC_MAP := "res://assets/sprites/som/wilgendal/npcs/"
const SOM_NPC := {
	"Gerrit": "gerrit",
	"Bram": "bram",
	"Els": "els",
	"Fien": "fien",
	"Wout": "wout",
	"Siem": "siem",
	"OudeMan": "oude_man",
	"Marit": "marit",
	"Ilse": "ilse",
	"Voorman": "henrik",
}
static var _som_props: Variant = null


static func som_props_index() -> Dictionary:
	if _som_props == null:
		_som_props = {}
		var pad := SOM_PROPS_MAP + "props_index.json"
		if FileAccess.file_exists(pad):
			var d = JSON.parse_string(FileAccess.get_file_as_string(pad))
			if d is Dictionary:
				_som_props = d.get("props", {})
	return _som_props


## SoM-prop voor een PROPS-rij: {naam, tex, links_boven (tegel), blok (Rect2i), voet (px)}; leeg = oude prop.
static func som_prop(rij: Dictionary) -> Dictionary:
	if not som():
		return {}
	var naam := str(SOM_PROP_VAN.get(str(rij.get("tex", "")), ""))
	var info: Dictionary = som_props_index().get(naam, {})
	if info.is_empty():
		return {}
	var t: Vector2i = rij["tegel"]
	var c := Vector2i(0, 0)
	var m := Vector2i(int(info["size_tiles"][0]), 1)
	var bots: Array = info.get("collision_tiles", [])
	if not bots.is_empty():
		c = Vector2i(int(bots[0][0]), int(bots[0][1]))
		m = Vector2i(int(bots[0][2]), int(bots[0][3]))
	var lb := Vector2i(t.x - c.x, t.y - (c.y + m.y - 1))
	var blok := Rect2i(lb + c, m) if not bots.is_empty() else Rect2i(t, Vector2i.ZERO)
	var o: Array = info["ysort_origin_px"]
	return {
		"naam": naam,
		"tex": SOM_PROPS_MAP + str(info["file"]),
		"links_boven": lb,
		"blok": blok,
		"voet": Vector2(lb) * 16.0 + Vector2(float(o[0]), float(o[1]) + 1.0),
	}


## Sheet voor een NPC-node in SoM-stijl, of "" (oude sprite houden).
static func som_npc_sheet(node: String) -> String:
	if not som() or not SOM_NPC.has(node):
		return ""
	var pad := SOM_NPC_MAP + str(SOM_NPC[node]) + ".png"
	return pad if ResourceLoader.exists(pad) else ""


## Hoeveel sfeer-NPC's beginnen op het marktplein (max PLEIN_MAX).
static func op_plein_aantal() -> int:
	var n := 0
	for ruw in SFEER:
		if op_plein((ruw as Dictionary)["tegel"]):
			n += 1
	return n


static func op_plein(t: Vector2i) -> bool:
	return PLEIN.has_point(t)


## Eén tegel verder. Geen zoektocht: de lus staat al vast. v2: de lopers staan verspreid door het
## dorp (niet allemaal op het plein). Muren, panden, molen, beek en props vallen af via beloopbaar.
static func stap_ok(van: Vector2i, naar: Vector2i) -> bool:
	var d := naar - van
	if absi(d.x) + absi(d.y) != 1:
		return false
	if naar == GERRIT_TEGEL:
		return false
	return beloopbaar(naar)


static func lus_tegels(rij: Dictionary) -> Array[Vector2i]:
	var uit: Array[Vector2i] = []
	for t in rij.get("lus", []):
		uit.append(t)
	return uit


## Gesloten lus van minstens twee verschillende plein-tegels, start op "tegel".
static func lus_geldig(rij: Dictionary) -> bool:
	var tegels := lus_tegels(rij)
	if tegels.size() < 2:
		return false
	if tegels[0] != rij.get("tegel", Vector2i(-999, -999)):
		return false
	var gezien := {}
	for i in tegels.size():
		var a: Vector2i = tegels[i]
		var b: Vector2i = tegels[(i + 1) % tegels.size()]
		if gezien.has(a) or not stap_ok(a, b):
			return false
		gezien[a] = true
	return true


## De vijf sfeer-NPC's (niet Gerrit) hebben elk een eigen lus.
static func lussen_vrij() -> bool:
	if SFEER.size() != 5:
		return false
	var bezet := {}
	for ruw in SFEER:
		var rij: Dictionary = ruw
		if not lus_geldig(rij):
			return false
		for t in lus_tegels(rij):
			if bezet.has(t) or t == GERRIT_TEGEL or MOLEN.has_point(t):
				return false
			bezet[t] = true
	return true
