extends RefCounted
## PUZZLE ROOM van de Diepe Grot (Layouts.PUZZEL, besluit Dennis 14 okt 2026). Kleine vaste puzzels
## uit BESTAANDE puzzelstukken van Archief 1 en 2 (duwbare kast, zware drukplaat, poort, hendel,
## groei-plaat + spleet, vaste kast). Geen nieuwe speler-mechaniek (duwen/rennen is van RPG CODE).
## Per (run-seed, verdieping) kiest de generator één puzzel (deterministisch) en een vrije plek in een
## kamer; Dungeon100Puzzel (scripts/dungeon/dungeon100_puzzel.gd) bouwt hem met PuzzleLogic.
## De beloning is 1 blauwe kist in de nis achter de poort/spleet. Bij binnenkomst één korte hint van ECHO.
##
## Tekens (lokaal, linksboven = "origin" in de kamer). Alle tegels BINNEN het vak moeten vloer zijn;
## daarbuiten telt voor PuzzleLogic alles als muur (een kast verlaat het vak nooit):
##   '.' vloer   'B' vaste kast (massief)   'c' de blauwe kist (nis; voor de logica massief)
##   '~' spleet (massief tot de groei-plaat volgroeid is)   'r' herstelsteen   andere tekens: zie "objects".

const BREEDTE := 7
const HOOGTE := 6
## Spreker van de hint.
const HINT_SPREKER := "ECHO"

const PUZZELS := {
	"kast_plaat": {
		"layout": [
			"BBBBBBB",
			"BBBcBBB",
			"BBB1BBB",
			".......",
			"..a.p..",
			"......r",
		],
		"objects": {
			"r": {"type": "reset", "id": "herstelsteen"},
			"a": {"type": "block", "id": "kast_a"},
			"p": {"type": "plate", "id": "plaat_p", "heavy": true},
			"1": {"type": "gate", "id": "poort", "needs": ["plaat_p"], "mode": "all", "latch": true},
		},
		"hint": "Weight opens what hands cannot. Find the plate.",
	},
	"twee_kasten": {
		"layout": [
			"BBBBBBB",
			"BBBcBBB",
			"BBB1BBB",
			".p...q.",
			"..a.b..",
			"......r",
		],
		"objects": {
			"r": {"type": "reset", "id": "herstelsteen"},
			"a": {"type": "block", "id": "kast_a"},
			"b": {"type": "block", "id": "kast_b"},
			"p": {"type": "plate", "id": "plaat_l", "heavy": true},
			"q": {"type": "plate", "id": "plaat_r", "heavy": true},
			"1": {"type": "gate", "id": "poort", "needs": ["plaat_l", "plaat_r"], "mode": "all", "latch": true},
		},
		"hint": "Two plates, two cabinets. The gate counts both.",
	},
	"hendel_groei": {
		"layout": [
			"BBBBBBB",
			"BBBcBBB",
			"BBB~BBB",
			".g.....",
			"....h..",
			"......r",
		],
		"objects": {
			"r": {"type": "reset", "id": "herstelsteen"},
			"h": {"type": "lever", "id": "hendel", "on": false},
			"g": {"type": "grow", "id": "groei", "needs": ["hendel"], "stages": 3, "gap": true},
		},
		"hint": "The seed sleeps until the lever wakes it.",
	},
	"kast_groei": {
		"layout": [
			"BBBBBBB",
			"BBBcBBB",
			"BBB~BBB",
			".g.....",
			"...a.p.",
			"......r",
		],
		"objects": {
			"r": {"type": "reset", "id": "herstelsteen"},
			"a": {"type": "block", "id": "kast_a"},
			"p": {"type": "plate", "id": "plaat_p", "heavy": true},
			"g": {"type": "grow", "id": "groei", "needs": ["plaat_p"], "stages": 3, "gap": true},
		},
		"hint": "Press the plate first. Then let it grow.",
	},
}
## Vaste volgorde (zelfde seed = zelfde puzzel).
const VOLGORDE := ["kast_plaat", "twee_kasten", "hendel_groei", "kast_groei"]
## Teksten van de groei-plaat (dezelfde als in Het Levende Archief).
const GROEI_WACHT := ["The plate does nothing.", "Something else comes first."]
const GROEI_STAP := ["The plate grows."]
const GROEI_OPEN := ["The vines close into a path."]
const GROEI_KLAAR := ["The path is already there."]


static func kies(run_seed: int, floor_no: int) -> String:
	return VOLGORDE[hash("%d|%d|grotpuzzel" % [run_seed, floor_no]) % VOLGORDE.size()]


static func puzzel(id: String) -> Dictionary:
	return PUZZELS.get(id, {})


## Besluit Dennis (14 okt 2026): een puzzelkamer met een drukplaat krijgt precies 1 monster, zodat de
## speler het (verlamd) op de plaat kan duwen. Lokale opstelling: {"monster": Vector2i, "speler": Vector2i,
## "dir": Vector2i, "plaat": id} met speler - monster - plaat op één rij over vrije vloer ('.'), of {}
## zonder plaat. Eerste plaat in leesvolgorde; richtingen in vaste volgorde (deterministisch).
static func duw_plan(id: String) -> Dictionary:
	var d := puzzel(id)
	var rows: Array = d.get("layout", [])
	var objs: Dictionary = d.get("objects", {})
	var vrij := func(t: Vector2i) -> bool:
		return t.y >= 0 and t.y < rows.size() and t.x >= 0 and t.x < str(rows[t.y]).length() \
				and str(rows[t.y])[t.x] == "."
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var ch := row[x]
			if not objs.has(ch) or str(objs[ch]["type"]) != "plate":
				continue
			var p := Vector2i(x, y)
			for dir in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				if vrij.call(p - dir) and vrij.call(p - 2 * dir):
					return {"monster": p - dir, "speler": p - 2 * dir, "dir": dir, "plaat": str(objs[ch]["id"])}
	return {}


## Lokale tegel van de kist ('c').
static func kist_lokaal(id: String) -> Vector2i:
	var rows: Array = puzzel(id).get("layout", [])
	for y in rows.size():
		var x := str(rows[y]).find("c")
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## Tegels (kamer-coördinaten) die bij het begin massief zijn: vaste kasten, kist, poort, spleet en
## de objecten die botsen (kast, hendel, groei-plaat). Voor de bereikbaarheidscontrole van de generator.
static func massief(id: String, origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := puzzel(id)
	var rows: Array = d.get("layout", [])
	var objs: Dictionary = d.get("objects", {})
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var ch := row[x]
			var solid := ch in ["B", "c", "~"]
			if objs.has(ch):
				solid = str(objs[ch]["type"]) in ["block", "gate", "lever", "grow", "reset"]
			if solid:
				out.append(origin + Vector2i(x, y))
	return out


## Volledige kamer voor PuzzleLogic.from_room: 'size' groot, overal muur behalve het puzzelvak.
## 'c' wordt muur (de kist zelf is een gewone DungeonChest van de kamer).
static func logica_kamer(id: String, origin: Vector2i, size: Vector2i) -> Dictionary:
	var d := puzzel(id)
	var rows: Array = d.get("layout", [])
	var out: Array = []
	for y in size.y:
		var line := ""
		for x in size.x:
			var lx := x - origin.x
			var ly := y - origin.y
			var ch := "#"
			if ly >= 0 and ly < rows.size() and lx >= 0 and lx < str(rows[ly]).length():
				ch = str(rows[ly])[lx]
				if ch == "c":
					ch = "#"
			line += ch
		out.append(line)
	var objs: Dictionary = d.get("objects", {}).duplicate(true)
	return {"name": "Deep Cave Puzzle", "layout": out, "objects": objs}
