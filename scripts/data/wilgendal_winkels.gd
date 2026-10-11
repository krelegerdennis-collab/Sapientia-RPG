extends RefCounted
## Vier winkelpanden van Wilgendal. Voorraad en prijzen blijven in shop_data.gd.
## Tante Mien (kruiden) heeft hier geen pand: dat aantal staat niet in de opdracht.
## Geen openingstijden: de deuren werken zolang het dorp open is.

const DORP := "res://scenes/maps/dorp_wilgendal.tscn"
const HUIS := 5
const DEUR := Vector2i(2, 4)
const W := 22
const H := 16

## Grond van het plein. h = huis (gras eronder, het pand op Gebouwen), = pad, # kassei, T boom.
const PLEIN: PackedStringArray = [
	"TTTTTTTTTTTTTTTTTTTTTT",
	"T..hhhhh.....hhhhh...T",
	"T..hhhhh.....hhhhh...T",
	"T..hhhhh.....hhhhh...T",
	"T..hhhhh.....hhhhh...T",
	"T..hhhhh.....hhhhh...T",
	"T....===========.....T",
	"T.........=..........T",
	"T..hhhhh#####hhhhh...T",
	"T..hhhhh#####hhhhh...T",
	"T..hhhhh#####hhhhh...T",
	"T..hhhhh#####hhhhh...T",
	"T..hhhhh#####hhhhh...T",
	"T....===========.....T",
	"T.........=..........T",
	"TTTTTTTTT===TTTTTTTTTT",
]

const WINKELS := {
	"wapen": {
		"scene": "res://scenes/maps/winkel_wapen.tscn",
		"node": "WinkelWapen",
		"map_name": "Wilgendal - Wapens",
		"keeper": "JelleWapen",
		"keeper_name": "Jelle Hamer",
		"line": "Staal. Wat heb je nodig?",
		"shop_id": "wilgendal_wapen",
		"spawn_buiten": "voor_wapen",
		"deur_node": "DeurWapen",
		"oorsprong": Vector2i(3, 1),
		"keeper_art": "res://assets/sprites/wilgendal/wapen_shopkeeper.png",
		"toonbank_art": "res://assets/sprites/wilgendal/wapen_toonbank.png",
		"display_art": "res://assets/sprites/wilgendal/wapen_display.png",
	},
	"pantser": {
		"scene": "res://scenes/maps/winkel_pantser.tscn",
		"node": "WinkelPantser",
		"map_name": "Wilgendal - Pantser",
		"keeper": "JellePantser",
		"keeper_name": "Jelle Hamer",
		"line": "Harnas en helmen.",
		"shop_id": "wilgendal_pantser",
		"spawn_buiten": "voor_pantser",
		"deur_node": "DeurPantser",
		"oorsprong": Vector2i(13, 1),
		"keeper_art": "res://assets/sprites/wilgendal/pantser_shopkeeper.png",
		"toonbank_art": "res://assets/sprites/wilgendal/pantser_toonbank.png",
		"display_art": "res://assets/sprites/wilgendal/pantser_display.png",
	},
	"accessoire": {
		"scene": "res://scenes/maps/winkel_accessoire.tscn",
		"node": "WinkelAccessoire",
		"map_name": "Wilgendal - Accessoires",
		"keeper": "Accessoire",
		"keeper_name": "Accessoire",
		"line": "Ringen en bladwijzers.",
		"shop_id": "wilgendal_accessoire",
		"spawn_buiten": "voor_accessoire",
		"deur_node": "DeurAccessoire",
		"oorsprong": Vector2i(3, 8),
		"keeper_art": "res://assets/sprites/wilgendal/accessoire_shopkeeper.png",
		"toonbank_art": "res://assets/sprites/wilgendal/accessoire_toonbank.png",
		"display_art": "res://assets/sprites/wilgendal/accessoire_display.png",
	},
	"magie": {
		"scene": "res://scenes/maps/winkel_magie.tscn",
		"node": "WinkelMagie",
		"map_name": "Wilgendal - Magie",
		"keeper": "Magie",
		"keeper_name": "Magiewinkel",
		"line": "Spreuken. Wat zoek je?",
		"shop_id": "wilgendal_magie",
		"spawn_buiten": "voor_magie",
		"deur_node": "DeurMagie",
		"oorsprong": Vector2i(13, 8),
		"keeper_art": "res://assets/sprites/wilgendal/magie_shopkeeper.png",
		"toonbank_art": "res://assets/sprites/wilgendal/magie_toonbank.png",
		"display_art": "res://assets/sprites/wilgendal/magie_display.png",
	},
}

## Bestaande kolommen uit binnen.png. Geen nieuwe tegel-art.
const BINNEN := {
	".": 0, ",": 1, "C": 2, "U": 3, "W": 4, "D": 5, "k": 21,
	"q": 12, "w": 13, "e": 14, "a": 15, "m": 16, "f": 17,
	"L": 23, "R": 24,
}

const INTERIEUR := {
	"wapen": [
		"CCCCCCCCCCCC",
		"UUUUUUUUUUUU",
		"L..........R",
		"L..........R",
		"L..........R",
		"L..........R",
		"L...qwe....R",
		"L...amf....R",
		"CCCCCDCCCCCC",
	],
	"pantser": [
		"CCCCCCCCCCCC",
		"UUUUUUUUUUUU",
		"L..........R",
		"L..........R",
		"L..........R",
		"L..........R",
		"L..........R",
		"L..........R",
		"CCCCCDCCCCCC",
	],
	"accessoire": [
		"CCCCCCCCCCCC",
		"UWWWWWWWWWWU",
		"L,,,,,,,,,,R",
		"L,,,,,,,,,,R",
		"L,,,,,,,,,,R",
		"L,,,,,,,,,,R",
		"L,,,qwe,,,,R",
		"L,,,amf,,,,R",
		"CCCCCDCCCCCC",
	],
	"magie": [
		"CCCCCCCCCCCC",
		"UWWWWWWWWWWU",
		"L.k......k.R",
		"L.,.,.,.,.,R",
		"L..........R",
		"L..........R",
		"L...qwe....R",
		"L...amf....R",
		"CCCCCDCCCCCC",
	],
}

## Tegel van de winkelier, de toonbank (linksboven, 3x1) en de uitstalling (linksboven, 2x2).
const KEEPER_TEGEL := Vector2i(5, 4)
const TOONBANK_TEGEL := Vector2i(4, 5)
const DISPLAY_TEGEL := Vector2i(4, 2)
const SPAWN_BINNEN := Vector2i(5, 7)
const UITGANG_TEGEL := Vector2i(5, 8)
const ZUID := Vector2i(10, 14)
const MOLEN := Vector2i(9, 2)
const GERRIT := Vector2i(10, 6)
const MIEN := Vector2i(9, 10)


static func deur_tegel(id: String) -> Vector2i:
	return (WINKELS[id]["oorsprong"] as Vector2i) + DEUR


static func voor_deur(id: String) -> Vector2i:
	return deur_tegel(id) + Vector2i.DOWN


static func binnen_kolom(ch: String) -> int:
	return int(BINNEN[ch])


static func tegel_midden(t: Vector2i) -> Vector2:
	return Vector2(t) * 16.0 + Vector2(8, 8)
