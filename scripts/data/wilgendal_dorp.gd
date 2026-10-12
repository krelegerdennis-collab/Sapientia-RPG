extends RefCounted
## Dorp Wilgendal: plein, vier winkelpanden, vier woonhuizen, zes sfeer-NPC's.
## Prijzen en voorraad blijven in shop_data.gd. De molen blijft de molen.
## Winkels zijn altijd open. Er is geen tijdsysteem.

const DORP := "res://scenes/maps/dorp_wilgendal.tscn"
const BINNEN := "res://scenes/maps/wilgendal_binnen.tscn"
const WERELD := "res://scenes/maps/wereldkaart.tscn"
const ALTIJD_OPEN := true
const W := 24
const H := 16
const PLEIN := Rect2i(7, 6, 10, 6)
const MOLEN := Rect2i(1, 1, 3, 4)
const SPAWN_ZUID := "zuid_ingang"
const SPAWN_TEGEL := Vector2i(12, 14)
const EXIT_TEGEL := Vector2i(11, 15)
const EXIT_MAAT := Vector2i(3, 1)
const GERRIT_TEGEL := Vector2i(8, 7)

const GROND: Array[String] = [
	"TTTTTTTTTTTTTTTTTTTTTTTT",
	"T......................T",
	"T......................T",
	"T......................T",
	"T...=================..T",
	"T.....=...=...=...=....T",
	"T.....=##########.=....T",
	"T......##########......T",
	"T......##########......T",
	"T.=....##########....=.T",
	"T......##########......T",
	"T......##########......T",
	"T..........===.........T",
	"T..........===.........T",
	"T.====================.T",
	"TTTTTTTTTTT===TTTTTTTTTT",
]

const TEGEL := {
	"T": 3,
	".": 0,
	"=": 2,
	"#": 33,
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
		"oorsprong": Vector2i(5, 1),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(6, 3),
		"icoon": "schild",
		"tex": "pantser",
		"bewoond": false,
		"keeper_naam": "Jelle Hamer",
		"keeper_lines": ["Harnas en helmen."],
		"sfeer": "stoer",
		"map_naam": "Pantserwinkel",
		"dicht": "",
	},
	{
		"id": "wapen",
		"kind": "winkel",
		"shop_id": "wilgendal_wapen",
		"oorsprong": Vector2i(9, 1),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(10, 3),
		"icoon": "zwaard",
		"tex": "wapen",
		"bewoond": false,
		"keeper_naam": "Jelle Hamer",
		"keeper_lines": ["Staal. Wat heb je nodig?"],
		"sfeer": "ambacht",
		"map_naam": "Wapenwinkel",
		"dicht": "",
	},
	{
		"id": "accessoire",
		"kind": "winkel",
		"shop_id": "wilgendal_accessoire",
		"oorsprong": Vector2i(13, 1),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(14, 3),
		"icoon": "ring",
		"tex": "accessoire",
		"bewoond": false,
		"keeper_naam": "Accessoire",
		"keeper_lines": ["Ringen en bladwijzers."],
		"sfeer": "sier",
		"map_naam": "Accessoirewinkel",
		"dicht": "",
	},
	{
		"id": "magie",
		"kind": "winkel",
		"shop_id": "wilgendal_magie",
		"oorsprong": Vector2i(17, 1),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(18, 3),
		"icoon": "ster",
		"tex": "magie",
		"bewoond": false,
		"keeper_naam": "Magiewinkel",
		"keeper_lines": ["Spreuken. Wat zoek je?"],
		"sfeer": "mystiek",
		"map_naam": "Magiewinkel",
		"dicht": "",
	},
	{
		"id": "mien",
		"kind": "huis",
		"shop_id": "wilgendal_kruiden",
		"oorsprong": Vector2i(1, 6),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(2, 8),
		"icoon": "",
		"tex": "huis",
		"bewoond": true,
		"keeper_naam": "Tante Mien",
		"keeper_lines": ["Kruiden. Wat heb je nodig?"],
		"sfeer": "kruid",
		"map_naam": "Huis van Tante Mien",
		"dicht": "",
	},
	{
		"id": "echtpaar",
		"kind": "huis",
		"shop_id": "",
		"oorsprong": Vector2i(20, 6),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(21, 8),
		"icoon": "",
		"tex": "huis",
		"bewoond": true,
		"keeper_naam": "",
		"keeper_lines": [],
		"sfeer": "haard",
		"map_naam": "Huis van Bram en Els",
		"dicht": "",
		"bord": "De haard gloeit nog. Bram en Els staan op het plein.",
	},
	{
		"id": "dicht_west",
		"kind": "huis",
		"shop_id": "",
		"oorsprong": Vector2i(1, 11),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(2, 13),
		"icoon": "",
		"tex": "huis_dicht",
		"bewoond": false,
		"keeper_naam": "",
		"keeper_lines": [],
		"sfeer": "",
		"map_naam": "",
		"dicht": "De luiken zijn dicht. Hier woont niemand.",
	},
	{
		"id": "dicht_oost",
		"kind": "huis",
		"shop_id": "",
		"oorsprong": Vector2i(20, 11),
		"maat": Vector2i(3, 3),
		"deur": Vector2i(21, 13),
		"icoon": "",
		"tex": "huis_dicht",
		"bewoond": false,
		"keeper_naam": "",
		"keeper_lines": [],
		"sfeer": "",
		"map_naam": "",
		"dicht": "Een dichte deur. Binnen blijft het stil.",
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
		"naam": "Bram",
		"tegel": Vector2i(11, 8),
		"lines": ["Els wil zo naar de smid. Ik blijf hier op het plein."],
	},
	{
		"node": "Els",
		"rol": "echtpaar",
		"naam": "Els",
		"tegel": Vector2i(12, 8),
		"lines": ["De winkels gaan nooit dicht. Dat is wel zo rustig."],
	},
	{
		"node": "Fien",
		"rol": "kind",
		"naam": "Fien",
		"tegel": Vector2i(14, 10),
		"lines": ["Die ster daar is de magiewinkel. Ik mag alleen kijken."],
	},
	{
		"node": "Wout",
		"rol": "veteraan",
		"naam": "Wout",
		"tegel": Vector2i(16, 8),
		"lines": ["Ik heb genoeg gevochten. Nu drink ik thee op het plein."],
	},
	{
		"node": "Siem",
		"rol": "koerier",
		"naam": "Siem",
		"tegel": Vector2i(9, 11),
		"lines": ["Post voor Wilgendal. Vandaag niets voor jou."],
	},
]

const ICOON_VAN_WINKEL := {
	"pantser": "schild",
	"wapen": "zwaard",
	"accessoire": "ring",
	"magie": "ster",
}


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
	for ruw in PANDEN:
		var rij: Dictionary = ruw
		var o: Vector2i = rij["oorsprong"]
		var m: Vector2i = rij["maat"]
		if Rect2i(o, m).has_point(t):
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


static func op_plein(t: Vector2i) -> bool:
	return PLEIN.has_point(t)
