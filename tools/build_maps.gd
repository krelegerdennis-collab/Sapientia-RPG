extends Node
## Hulpscript dat de TileSets en de map-scènes opnieuw opbouwt vanuit de
## tekst-maps hieronder. Je hoeft dit NIET te gebruiken: je kunt de maps ook
## gewoon in de editor schilderen (open scenes/maps/..., selecteer "Ground").
##
## Let op: dit OVERSCHRIJFT:
##   assets/tiles/dorp.tres, assets/tiles/wereld.tres, assets/tiles/binnen.tres,
##   scenes/maps/wilgendal.tscn, scenes/maps/wereldkaart.tscn, scenes/maps/huis_wilgendal.tscn
##   v0.17 ook: scenes/maps/esdoorn.tscn, esdoorn_huis_noor.tscn, esdoorn_herberg.tscn
## Starten (vanuit de projectmap):
##     godot --headless --path . res://tools/build_maps.tscn
## v0.17 alleen de wereldkaart + Esdoorn (laat dorp.tres/binnen.tres/Wachtershuis ongemoeid):
##     godot --headless --path . res://tools/build_maps.tscn -- --only=v17
## (of open tools/build_maps.tscn in de editor en druk op F6)
##
## Elke tile krijgt custom data "terrain" (een woord, bv. "gras" of "bos").
## scripts/map.gd leest dat bij elke stap; game_data.gd ENCOUNTER_RATES zegt
## per terrein hoe groot de kans op een gevecht is.

const TILE := 16
const TOWN_PATH := "res://scenes/maps/wilgendal.tscn"
const WORLD_PATH := "res://scenes/maps/wereldkaart.tscn"
const HOUSE_PATH := "res://scenes/maps/huis_wilgendal.tscn"
## v0.13: eerste dungeonkamer (wordt NIET door dit script gebouwd: scripts/dungeon/dungeon_room.gd
## bouwt hem uit scripts/data/dungeon_rooms.gd).
const ARCHIEF_PATH := "res://scenes/maps/archief_ingang.tscn"
const StoryData := preload("res://scripts/data/story_data.gd")

# =====================================================================
#  BINNEN: het huis in Wilgendal (v0.10)  (assets/tiles/binnen.png van RPG ART:
#  400x16, één rij van 25 tiles van 16x16, zie docs/ARTSTYLE.md 10g)
# =====================================================================
## teken -> [atlas-kolom, blokkeert?]
const INSIDE_LEGEND := {
	".": [0, false],   # vloer A
	",": [1, false],   # vloer B
	"C": [2, true],    # muur boven (ook de onderrand van de kamer)
	"U": [3, true],    # muur voorkant
	"W": [4, true],    # muur met raam
	"D": [5, false],   # deur/uitgang (onderste muurrij; erop stappen = naar buiten)
	"S": [6, true],    # boekenkast boven
	"s": [7, true],    # boekenkast onder
	"t": [8, true],    # tafel
	"h": [9, false],   # stoel
	"b": [10, true],   # bed boven
	"d": [11, true],   # bed onder
	"q": [12, false], "w": [13, false], "e": [14, false],   # kleed NW N NO
	"a": [15, false], "m": [16, false], "f": [17, false],   # kleed W midden O
	"z": [18, false], "P": [19, false], "c": [20, false],   # kleed ZW Z ZO (P = ook spawnpunt)
	"k": [21, true],   # kaars (geanimeerd: tile 21 en 22 wisselen)
	"L": [23, true],   # muur zijkant links
	"R": [24, true],   # muur zijkant rechts
	"X": [0, false],   # opslagpunt (boek op lessenaar; object, blokkeert zelf)
	"O": [0, false],   # v0.11: de Oude Man ('s avonds; object, blokkeert zelf)
	"G": [3, true],    # v0.11: muur met schilderij (object 'Schilderij' op de muur-tile)
	"Z": [9, false],   # v0.11: stoel waar je 's avonds leest (spawnpunt 'lezen')
	"B": [10, true],   # v0.11: bed boven. Update 5: spawn 'bed' staat één tile rechts (beloopbaar).
}
## Tile 22 is het 2e frame van de kaars (geen eigen tile in de TileSet).
const INSIDE_ANIM := {21: 2}
const INSIDE_ANIM_FRAME_TIME := 0.45
## 12 x 9 tiles. Deur onderin op (4,8), spawn op het kleed (4,7), opslagboek op (8,3).
## v0.11: bedmeubel (1,3), stoel (9,5) = spawn 'lezen', Oude Man (9,3) 's avonds,
## Update 5: spawn 'bed' staat op (2,3), naast het bed. De bed-tile zelf blokkeert lopen.
## schilderij op de muur (6,1) met Opa's zwaard erachter.
const INSIDE_MAP := [
	"CCCCCCCCCCCC",
	"USSUSWGSSWUU",
	"Lss,s.,ss.,R",
	"LB.,.,.,XOkR",
	"Ld,.,.,.,.,R",
	"L.,qwe,.tZ.R",
	"L,.amf.,.,.R",
	"L,.zPc.,.,kR",
	"CCCCDCCCCCCC",
]


# =====================================================================
#  DORP  (assets/tiles/dorp.png: één rij tiles, zie tools/art_maps.py)
# =====================================================================
## Atlas-kolom in dorp.png per teken in de dorp-map.
const TOWN_LEGEND := {
	".": 0,   # gras
	",": 1,   # bloemen
	"=": 2,   # zandpad
	"T": 3,   # boom        (blokkeert)
	"~": 5,   # water       (blokkeert)
	"r": 7,   # rots        (blokkeert)
	"#": 33,  # kassei (keien)
	"o": 49,  # heg         (blokkeert)
	"-": 50,  # hek         (blokkeert)
	"w": 51,  # lage muur   (blokkeert)
	"*": 52,  # bloemenperk
	"b": 53,  # ton         (blokkeert, staat op kassei)
	"h": 0,   # huis: gras eronder, het huis zelf staat op de laag "Gebouwen"
	"N": 33,  # NPC (op kassei)
	"S": 0,   # bordje (op gras)
	# v0.11 proloog (objecten op gras):
	"W": 0,   # waterput
	"Z": 0,   # (v0.16 weg: zegelsteen; teken niet meer in TOWN_MAP)
	"K": 0,   # kist (naast het huis)
	"O": 0,   # de Oude Man ('s ochtends, starend naar de ruïnes)
	"A": 0,   # ingang De Vergeten Archieven (linkerboven-tile; v0.13: 3x2 tiles, RPG ART 48x32)
	"a": 0,   # (rest van de ingang)
	# v0.11 TEST-PLEK (eigenlijk voor dungeons): boekpunten naast de ingang van de Archieven
	"R": 0,   # rood boek: HP vol
	"M": 0,   # groen boek: MP vol
	# v0.13: ruïne-stukken van RPG ART rond de ingang (blokkeren; welk stuk: RUIN_PIECES)
	"U": 0,
	"j": 0,   # v0.13: rest van de waterput (2x2)
}
## Dorp-tiles die blokkeren (incl. water-oevers 26..32).
const TOWN_SOLID := [3, 4, 5, 7, 26, 27, 28, 29, 30, 31, 32, 49, 50, 51, 53]
## Terrein-naam per dorp-tile (voor ENCOUNTER_RATES; in het dorp staan
## gevechten sowieso uit, maar zo werkt het ook als je deze tiles elders gebruikt).
const TOWN_TERRAIN := {0: "gras", 1: "gras", 2: "pad", 3: "boom", 4: "muur", 5: "water",
	6: "brug", 7: "rots", 33: "kassei", 49: "heg", 50: "hek", 51: "muur", 52: "bloemen", 53: "ton"}
const GRASS_SHADOW_BASE := 7    # 8..10  gras met schaduw (1 = van boven, 2 = van links)
const PATH_EDGE_BASE := 10      # 11..25 zandpad met grasrand (masker N1 E2 S4 W8)
const WATER_BANK_BASE := 25     # 26..32 water met oever (1 = boven, 2 = rechts, 4 = links)
const COBBLE_EDGE_BASE := 33    # 34..48 kassei met grasrand (masker N1 E2 S4 W8)
## Het huis (assets/tiles/huis.png, 5x5 tiles) en de plek van de deur in het huis.
## v0.13: de Oude Man / Wachter (RPG ART, 48x96, zelfde indeling als player.png).
const WACHTER_SHEET := "res://assets/sprites/wachter.png"
const HOUSE_SIZE := Vector2i(5, 5)
## v0.13: buiten-art van RPG ART (assets/sprites/buiten/, lijst in docs/BUITEN_TILES.txt)
const BUITEN := "res://assets/sprites/buiten/"
## Ruïne-stukken ('U' in TOWN_MAP): tile -> index in ruine.png (10 stukken van 16x16):
## 0 hoek lb, 1 rand h, 2 hoek rb, 3 rand v, 4 hoek lo, 5 hoek ro, 6 eind, 7 eind l, 8 pilaar, 9 midden
const RUIN_PIECES := {
	Vector2i(24, 2): 7, Vector2i(28, 2): 6,    # afgebrokkelde muurstukjes naast de boog
	Vector2i(24, 3): 8, Vector2i(28, 3): 8,    # twee pilaren naast de ingang
	Vector2i(24, 5): 9, Vector2i(28, 5): 9,    # overwoekerde blokken
}
const HOUSE_DOOR := Vector2i(2, 4)

## v0.11: geen dorp meer maar het eenzame huis op een stenen fundering, omringd door groen
## en een oud bos (proloog). Rechtsboven, achter de bomen en een rotsheuvel: de overwoekerde
## ingang van De Vergeten Archieven. Het pad naar het zuiden (wereldkaart) is tijdens de
## proloog dicht ("Niet vandaag"). Huis/deur/spawns staan op dezelfde plek als in v0.10.
const TOWN_MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTrrrrrTTTT",
	"TTTTTT..TTTT..hhhhh..TTrUAaaUTTT",
	"TTTT......T...hhhhh...TTUaaaUTTT",
	"TTT...,.......hhhhh....TR,.MTTTT",
	"TT.......Wj.,.hhhhh.....U...UTTT",
	"TT.......jj...hhhhhK...TT...TTTT",
	"TT.....,....#########...T.,..TTT",
	"TT..,........#######.O..T....TTT",
	"TT.........,...=........,....TTT",
	"TT..T..........=.........,...TTT",
	"TTT.....,......=......,......TTT",
	"TT.....~~~.....=.............TTT",
	"TT.....~~~,....=......T.......TT",
	"TT..,..........=..........,...TT",
	"TT.T...........=...........T..TT",
	"TT.............=....,.........TT",
	"TT....,........=..........,..TTT",
	"TTT............=.............TTT",
	"TTTT.......,...=.......,...TTTTT",
	"TTTTTTT........=........TTTTTTTT",
	"TTTTTTTTTTTTTT===TTTTTTTTTTTTTTT",
]

# =====================================================================
#  WERELDKAART  (assets/tiles/wereld.png: raster van 16 kolommen)
# =====================================================================
##   ~ zee (blokkeert)   . gras   , licht gras   : zand   T bos
##   ^ berg (blokkeert)  HH Wachtershuis (2 tiles breed; v0.13, was de stad)  D trap
##   VV/VV Wilgendal (v0.13, eerste dorp, 2x2)  p spawnpunt "van_dorp" (op gras)
##   v0.17: EE/EE Esdoorn (dorp van Noor, 2x2, open na de Golem)  W ingang Donker Woud
##   (iconen uit een 2e atlas: assets/tiles/wereld_v17_iconen.png, tegel 0-3 = Esdoorn, 4 = woud)
## v0.13: atlas = assets/tiles/wereld_v14.png (wereld.png + RPG ART's nieuwe iconen op rij 8)
const W_COLS := 16
const W_GRASS := 0       # 0..1   gras (2 varianten)
const W_LIGHT := 2       # 2..17  licht gras  (+ masker: welke buren ook licht gras zijn)
const W_SAND := 18       # 18..33 zand
const W_FOREST := 34     # 34..49 bos
const W_MOUNT := 50      # 50..65 berg variant A
const W_SEA := 66        # 66..112 zee met kust (47 varianten, zie sea_masks())
const W_TOWN := 113      # 113 = linkerhelft stad, 114 = rechterhelft
const W_STAIRS := 115
const W_MOUNT_B := 116   # 116..131 berg variant B (dambord met A)
## v0.13 (RPG ART, art_wereld_v14/out/INBOUW.md): 132/133 = Wachtershuis links/rechts,
## 134..137 = Wilgendal LB, RB, LO, RO (terrein 'stad'). 113/114 blijven ongebruikt staan.
const W_HOUSE := 132
const W_VILLAGE := 134
const W_COUNT := 138
const WORLD_ATLAS := "res://assets/tiles/wereld_v14.png"
## v0.13: het eerste dorp Wilgendal (bestaat nog niet: tot die scène er is, zegt de uitgang
## 'Wilgendal (komt later)', zie scripts/map.gd _use_exit)
const VILLAGE_PATH := "res://scenes/maps/dorp_wilgendal.tscn"

const WORLD_MAP := [
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,~~~~~~~~~~~~~~~~~~~~~~...~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~TTTT,,,,~~~~~~~~~~~~~~~~~.......~~~~",
	"~~~~~~~~~~~~~~~....,^^^^^TT,,,,,.~~~~~~~~~~~~~~~~.......~~~~",
	"~~~~~~~~~^TTT......,^^^^^TT,,,,,..~~~~~~~~~~~~~~~~......~~~~",
	"~~~~~~~~^^TT...,,..^^^^^^,,,,,.,..~~~~~~~~~..~~~~~~~..~~~~~~",
	"~~~~~~~^^^....,,,..^^^^^^^,,,,,^^.~~~~~~......~~~~~~~~~~~~~~",
	"~~~~~~~^^^^...,,,.^^^^^^^^,,,,TT^^.~~~~~...........~~~~~~~~~",
	"~~~~~~~^^^^...,,,^^^^^^^^^,,,,,,...~~~:............~~~~~~~~~",
	"~~~~~~^^^^^^^^^^^^^^^^^^^^..,,,,..:^:::............~~~~~~~~~",
	"~~~~~~~^^^^^^^^^^^^^^^^^^^T.......:^:::............~~~~~~~~~",
	"~~~~~~~^^^.^^^^^^^^^^^^^^^TT......::^::TTT......,,~~~~~~~~~~",
	"~~~~~~~~~~~~^^^.^^^^^^^^^^TT......::^:.TTT......,,~~~~~~~~~~",
	"~~~~~~~~~~~~^^~~~~~^^^^^^TTT.......::^^TTT.....,,,~~~~~~~~~~",
	"~~:~~~~~~~~~~~~~~~~.^^^TTTTT.......:::^^^..^^^,,,,~~~~~~~~~~",
	"~~:..~~~~~~~~~^^:::......T......TTTTTT..^^^^,,,,,,~~~~~~~~~~",
	"~~...~~~~~~~~~,^,:::........TTTTTTTTTT.....,,,,,~~~~~~~~~~~~",
	"~~~..~~~~~~~~,,,,...........TTTTTTTTTT..^^^^TT,.~~~,~~~~~~~~",
	"~~~~~~~~~~~~,,,,,...........TTTTTTTTTT.^^^^^,,,,~~,,~~~~~~~~",
	"~~~~~~~~~~~~.,,,,......................^^^^^,,,,,,,,.~~~~~~~",
	"~~~~~~~..TT..,,,,.......,,....VV........^^^^,,,,,....~~~~~~~",
	"~~~~~~~..TT...,,,......,,,,...VV.......TT^^,...EE....~~~~~~~",
	"~~~~~~~~~..............^^^^............TTT,,...EE....~~~~~~~",
	"~~~~~~~~~.....T.........^^^............TTTW,........~~~~~~~~",
	"~~~~~~~~...TTTT..........^^^^^........TTTT.........~~~~~~~~~",
	"~~~~~~~~..TTTTT.....,,,..^^^^^^......TTTTT..,,....~~~~~~~~~~",
	"~~~~~~~~...TTT.....,,,,..^^^^^::..T^^^TTTTT.,,,...~~~~~~~~~~",
	"~~~~~~~~......HH....,,...^^^^^::.TT^^^^^TTT.,,,...~~~~~~~~~~",
	"~~~~~~~~......p.........^^^:::::.TT^^^^^^TT.,,,....~~~~~~~~~",
	"~~~~~~~~~...........:...^^^......TTT^^^^^^T.,,,....~~~~~~~~~",
	"~~~~~~~~~.....TTTT.::..^^^^.T.....,TT^^^^^^^,,....~~~~~~~~~~",
	"~~~~~~~~~~...TTTTT..D^^^^^^.TTTT.,,,,,.^^^^^^^^^^^~~~~~~~~~~",
	"~~~~~~~~~~~..TTTT...^^^^^^^.TTTT.,,,,,..^^^^^^^^^~~~~~~~~~~~",
	"~~~~~~~~~~~~...T...^^^^^^...TTT...,,,,...^^^^^^^^~~~~~~~~~~~",
	"~~~~~~~~~~~~.^^^^^^^^^^^~~~~~~~....,,......^^^^^~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~^^^^^^^~~~~~~~.............~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~^^^^^^^^~~~..............~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~^^^^^^^^^.............~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^~~~~~....~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]

# =====================================================================
#  v0.17 ESDOORN: het dorp van Noor (zelfde dorp-tegels als het Wachtershuis, dorp.tres)
# =====================================================================
const ESDOORN_PATH := "res://scenes/maps/esdoorn.tscn"
const NOOR_HUIS_PATH := "res://scenes/maps/esdoorn_huis_noor.tscn"
const HERBERG_PATH := "res://scenes/maps/esdoorn_herberg.tscn"
const WOUD_PATH := "res://scenes/maps/woud_rand.tscn"
const V17_ICONS := "res://assets/tiles/wereld_v17_iconen.png"
const NOOR_SHEET := "res://assets/sprites/noor_dorp.png"
## Huizen (5x5 uit huis.png, deur op HOUSE_DOOR): linksboven -> [doel-scène, spawn binnen, spawn ervoor]
## ("" = op slot: een deur met tekst).
const ESDOORN_HOUSES := [
	[Vector2i(5, 4), NOOR_HUIS_PATH, "binnen", "voor_noor"],
	[Vector2i(14, 3), HERBERG_PATH, "binnen", "voor_herberg"],
	[Vector2i(24, 4), "", "", "voor_dicht"],
]
## Dorpelingen: [node, naam, tile, richting, event, kleur (modulate van npc.png)].
const ESDOORN_NPCS := [
	["Marit", "Marit", Vector2i(19, 14), Vector2i.DOWN, "marit", Color(1.0, 0.82, 0.78)],
	["Bram", "Old Bram", Vector2i(6, 12), Vector2i.LEFT, "bram", Color(0.78, 0.78, 0.9)],
	["Jens", "Jens", Vector2i(24, 18), Vector2i.DOWN, "jens", Color(0.85, 1.0, 0.8)],
	["Tobias", "Tobias", Vector2i(26, 14), Vector2i.RIGHT, "tobias", Color(0.8, 0.92, 1.0)],
]
## Noor op het plein (alleen tot de ontmoeting) en de wortelgreep (cocon, alleen in de cutscene).
const ESDOORN_NOOR := Vector2i(16, 15)
const ESDOORN_GREEP := Vector2i(16, 16)
## 34 x 24. Legenda = TOWN_LEGEND (h = huis, W/j = put, S = bordje). Uitgang onderaan (15-17).
## Het westen (links) is donker bos: daar ligt op de wereldkaart het Donker Woud.
const ESDOORN_MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTT.........T.....T.........TTTT",
	"TTT...........hhhhh............TTT",
	"TT...hhhhh,...hhhhh.....hhhhh,o.TT",
	"TT...hhhhh..*.hhhhh.*,..hhhhh.o.TT",
	"TT...hhhhh.,..hhhhh.....hhhhh.o.TT",
	"TT...hhhhh....hhhhh...,.hhhhh.o.TT",
	"TT...hhhhh......=.......hhhhh.o.TT",
	"TT..,*.=*.......=.........=.....TT",
	"TT.....====================...T.TT",
	"TTTT.S.....b#########b.........TTT",
	"TTTTT......#####Wj####..........TT",
	"TTTTT......#####jj####.....~~~..TT",
	"TTTT.......##########b.....~~~..TT",
	"TTTT..,....*#########*..........TT",
	"TTTT.-----......=...............TT",
	"TTTTT...........=........,......TT",
	"TTTT.T......,...=...............TT",
	"TTTT............=...,..........TTT",
	"TTTT.....,...,..=.............TTTT",
	"TTTTT...........=.............TTTT",
	"TTTTTTTTTTTTTTT===TTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTT===TTTTTTTTTTTTTTTT",
]
const ESDOORN_SIGN := Vector2i(5, 11)
const ESDOORN_SIGN_LINES: Array[String] = ["<- The Dark Wood. Not after sunset!", "(Someone scratched under it: 'Not in the daytime either.')"]
const ESDOORN_LOCKED_LINES: Array[String] = ["The door is locked.", "A note hangs there: 'Gone to market. Back when the mist lifts.'"]

## Interieurs (binnen.png, INSIDE_LEGEND; D = deur naar buiten, P = spawn 'binnen', X = opslagboek).
const NOOR_HUIS_MAP := [
	"CCCCCCCCCC",
	"UUSWUUWSUU",
	"Lbs.,.,s.R",
	"Ld,.,.,.kR",
	"L.,qwe.,.R",
	"L,.amf,.tR",
	"L.,zPc.,.R",
	"CCCCDCCCCC",
]
const NOOR_HUIS_NPCS := [["Ilse", "Ilse", Vector2i(6, 3), Vector2i.DOWN, "ilse", Color(1.0, 0.9, 0.75)]]
const HERBERG_MAP := [
	"CCCCCCCCCCCC",
	"USSUWUUWUSSU",
	"Lss.,.,.,ssR",
	"L.,tt.,.X,kR",
	"L,.hh.,.,.,R",
	"L.,.,qwe.,.R",
	"Lb,.,amf,.,R",
	"Ld.,.zPc.,.R",
	"CCCCCCDCCCCC",
]
const HERBERG_NPCS := [["Waard", "Innkeeper Wout", Vector2i(6, 3), Vector2i.DOWN, "herbergier", Color(0.95, 0.85, 0.7)]]



func _ready() -> void:
	# v0.17: "--only=v17" = alleen wereldkaart (+ tileset) en Esdoorn opnieuw bouwen
	if "--only=v17" in OS.get_cmdline_user_args():
		build_v17()
		get_tree().quit()
		return
	var town_ts := build_town_tileset()
	print("dorp.tres opgeslagen: ", error_string(ResourceSaver.save(town_ts, "res://assets/tiles/dorp.tres")))
	# Esdoorn (Mapleton) gebruikt v8-props van RPG ART: zelfde tileset, textuur dorp_v8.png
	var town_v8 := build_town_tileset()
	(town_v8.get_source(0) as TileSetAtlasSource).texture = load("res://assets/tiles/dorp_v8.png")
	print("dorp_v8.tres opgeslagen: ", error_string(ResourceSaver.save(town_v8, "res://assets/tiles/dorp_v8.tres")))
	var world_ts := build_world_tileset()
	print("wereld.tres opgeslagen: ", error_string(ResourceSaver.save(world_ts, "res://assets/tiles/wereld.tres")))
	save_scene(build_town(load("res://assets/tiles/dorp.tres")), TOWN_PATH)
	save_scene(build_world(load("res://assets/tiles/wereld.tres")), WORLD_PATH)
	var inside_ts := build_inside_tileset()
	print("binnen.tres opgeslagen: ", error_string(ResourceSaver.save(inside_ts, "res://assets/tiles/binnen.tres")))
	save_scene(build_inside(load("res://assets/tiles/binnen.tres")), HOUSE_PATH)
	build_esdoorn_all()
	get_tree().quit()


## v0.17 wereldkaart + Esdoorn (dorp, huis van Noor, herberg).
func build_v17() -> void:
	var world_ts := build_world_tileset()
	print("wereld.tres opgeslagen: ", error_string(ResourceSaver.save(world_ts, "res://assets/tiles/wereld.tres")))
	save_scene(build_world(load("res://assets/tiles/wereld.tres")), WORLD_PATH)
	build_esdoorn_all()


func build_esdoorn_all() -> void:
	save_scene(build_esdoorn(load("res://assets/tiles/dorp_v8.tres")), ESDOORN_PATH)
	var inside: TileSet = load("res://assets/tiles/binnen.tres")
	save_scene(build_interior("EsdoornHuisNoor", "Mapleton - Vesper's House", NOOR_HUIS_MAP, NOOR_HUIS_NPCS,
			"voor_noor"), NOOR_HUIS_PATH)
	save_scene(build_interior("EsdoornHerberg", "Mapleton - The Maple Inn", HERBERG_MAP, HERBERG_NPCS,
			"voor_herberg"), HERBERG_PATH)


func save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	print(path.get_file(), " opgeslagen: ", error_string(ResourceSaver.save(packed, path)))
	root.free()


# ---------------------------------------------------------------- tilesets
func new_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "terrain")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	return ts


func add_tile(src: TileSetAtlasSource, coords: Vector2i, solid: bool, terrain: String) -> void:
	src.create_tile(coords)
	var data := src.get_tile_data(coords, 0)
	data.set_custom_data("terrain", terrain)
	if solid:
		var h := TILE / 2.0
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))


func build_town_tileset() -> TileSet:
	var ts := new_tileset()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/dorp.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	@warning_ignore("integer_division")
	var count := src.texture.get_width() / TILE
	for i in count:
		add_tile(src, Vector2i(i, 0), i in TOWN_SOLID, town_terrain(i))
	# Bron 1: het huis (5x5 tiles, alles blokkeert; de deur is een apart object)
	var house := TileSetAtlasSource.new()
	house.texture = load("res://assets/tiles/huis.png")
	house.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(house, 1)
	for y in HOUSE_SIZE.y:
		for x in HOUSE_SIZE.x:
			add_tile(house, Vector2i(x, y), true, "huis")
	return ts


func town_terrain(i: int) -> String:
	if TOWN_TERRAIN.has(i):
		return TOWN_TERRAIN[i]
	if i > GRASS_SHADOW_BASE and i <= PATH_EDGE_BASE:
		return "gras"
	if i > PATH_EDGE_BASE and i <= WATER_BANK_BASE:
		return "pad"
	if i > WATER_BANK_BASE and i <= 32:
		return "water"
	if i > COBBLE_EDGE_BASE and i <= COBBLE_EDGE_BASE + 15:
		return "kassei"
	return ""


func build_world_tileset() -> TileSet:
	var ts := new_tileset()
	var src := TileSetAtlasSource.new()
	src.texture = load(WORLD_ATLAS)
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for i in W_COUNT:
		var terrain := world_terrain(i)
		add_tile(src, Vector2i(i % W_COLS, i / W_COLS), terrain in ["berg", "zee"], terrain)
	# v0.17 bron 1: Esdoorn (0-3) en de ingang van het Donker Woud (4); geen monsters ("stad")
	var icons := TileSetAtlasSource.new()
	icons.texture = load(V17_ICONS)
	icons.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(icons, 1)
	for i in 5:
		add_tile(icons, Vector2i(i, 0), false, "stad")
	return ts


func world_terrain(i: int) -> String:
	if i < W_LIGHT: return "gras"
	if i < W_SAND: return "hoog_gras"
	if i < W_FOREST: return "zand"
	if i < W_MOUNT: return "bos"
	if i < W_SEA: return "berg"
	if i < W_TOWN: return "zee"
	if i < W_STAIRS: return "stad"
	if i == W_STAIRS: return "trap"
	if i >= W_HOUSE: return "stad"
	return "berg"


# ---------------------------------------------------------------- algemene opbouw
func new_map_root(root_name: String, map_name: String, encounters: bool) -> Node2D:
	var root := Node2D.new()
	root.name = root_name
	root.set_script(load("res://scripts/map.gd"))
	root.map_name = map_name
	root.encounters = encounters
	return root


func add_node(parent: Node, owner_node: Node, node: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = owner_node
	return node


func add_instance(parent: Node, owner_node: Node, path: String, node_name: String, pos: Vector2) -> Node2D:
	var inst: Node2D = load(path).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	inst.position = pos
	return add_node(parent, owner_node, inst, node_name)


## v0.11: boekpunt (scripts/book_point.gd); type "save", "hp" of "mp" (scripts/data/book_data.gd).
func add_book(parent: Node, owner_node: Node, node_name: String, t: Vector2i, type: String) -> Node2D:
	var book := add_instance(parent, owner_node, "res://scenes/book_point.tscn", node_name, tile_center(t))
	book.type = type
	return book


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t * TILE) + Vector2(TILE, TILE) / 2.0


func add_spawn(root: Node, spawn_name: String, t: Vector2i, facing: Vector2i) -> void:
	var sp := Marker2D.new()
	sp.set_script(load("res://scripts/map_spawn.gd"))
	sp.position = tile_center(t)
	sp.facing = facing
	add_node(root.get_node("Spawns"), root, sp, spawn_name)


func add_exit(root: Node, exit_name: String, rect: Rect2i, target_map: String, target_spawn: String, lines: Array[String] = []) -> void:
	var ex := Node2D.new()
	ex.set_script(load("res://scripts/map_exit.gd"))
	ex.position = Vector2(rect.position * TILE)
	ex.size_tiles = rect.size
	ex.target_map = target_map
	ex.target_spawn = target_spawn
	ex.lines = lines
	add_node(root.get_node("Exits"), root, ex, exit_name)


## Standaard-opbouw: Ground (+ evt. Gebouwen), Objects (y-sort), Spawns, Exits.
func add_layers(root: Node2D, tileset: TileSet, with_buildings: bool) -> void:
	var ground := TileMapLayer.new()
	ground.tile_set = tileset
	add_node(root, root, ground, "Ground")
	if with_buildings:
		var gebouwen := TileMapLayer.new()
		gebouwen.tile_set = tileset
		add_node(root, root, gebouwen, "Gebouwen")
	var objects := Node2D.new()
	objects.y_sort_enabled = true
	add_node(root, root, objects, "Objects")
	add_node(root, root, Node2D.new(), "Spawns")
	add_node(root, root, Node2D.new(), "Exits")


func add_touch_controls(root: Node) -> void:
	var touch: Node = load("res://scenes/ui/touch_controls.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	root.add_child(touch)
	touch.owner = root


# ---------------------------------------------------------------- dorp Wilgendal
func build_town(tileset: TileSet) -> Node2D:
	var root := new_map_root("Wilgendal", "House at the Wood's Edge", false)   # GEEN monsters hier
	add_layers(root, tileset, true)
	var ground: TileMapLayer = root.get_node("Ground")
	var gebouwen: TileMapLayer = root.get_node("Gebouwen")
	var objects: Node = root.get_node("Objects")
	var house_pos := Vector2i(-1, -1)

	for y in TOWN_MAP.size():
		var row: String = TOWN_MAP[y]
		for x in row.length():
			var ch := row[x]
			ground.set_cell(Vector2i(x, y), 0, Vector2i(pick_town_tile(x, y), 0))
			if ch == "h" and house_pos.x < 0:
				house_pos = Vector2i(x, y)
			match ch:
				"O":
					var npc := add_instance(objects, root, "res://scenes/npc.tscn", "OudeMan", tile_center(Vector2i(x, y)))
					npc.npc_name = "Old Man"
					npc.sheet = load(WACHTER_SHEET)   # v0.13: RPG ART's Wachter
					npc.facing = Vector2i.UP     # staart naar de ruïnes
					npc.event = "opa"
					npc.show_if = {"step_lt": StoryData.AVOND}
				"W":
					# v0.13: stenen waterput van RPG ART, 32x32 = 2x2 tiles ('j' = de rest)
					var well := story_obj(objects, root, "Put", Vector2i(x, y), BUITEN + "put.png", 1, "put")
					well.tiles = Vector2i(2, 2)
				"U":
					var piece := story_obj(objects, root, "Ruine_%d_%d" % [x, y], Vector2i(x, y), BUITEN + "ruine.png",
							10, "ruine", "", [[{}, int(RUIN_PIECES.get(Vector2i(x, y), 8))]])
					piece.z_index = 0
				"K":
					story_obj(objects, root, "Kist", Vector2i(x, y), BUITEN + "kist.png", 2, "kist",
							"", [[{"flags": ["kist_open"]}, 1]])
				# v0.16: de 3 zegelstenen ('Z', runen aanraken) zijn uit de tutorial gehaald (wens Dennis)
				"R":
					add_book(objects, root, "BoekHP", Vector2i(x, y), "hp")
				"M":
					add_book(objects, root, "BoekMP", Vector2i(x, y), "mp")
				"A":
					# v0.13: ingang van RPG ART: 48x32 = 3x2 tiles, frame 0 dicht / 1 open (vanaf NACHT,
					# na scène 2 is het zegel verbroken); open = flakkerende gloed (2 frames)
					var arch := story_obj(objects, root, "Archief", Vector2i(x, y), BUITEN + "archief_ingang.png", 2,
							"archief_ingang", "", [[{"step_ge": StoryData.NACHT}, 1]])
					arch.tiles = Vector2i(3, 2)
					arch.loop_if = {"step_ge": StoryData.NACHT}
					arch.loop_texture = load(BUITEN + "archief_ingang_open_flikker.png")
					arch.loop_frames = 2
					arch.loop_time = 0.35
					arch.bump_event = true
					arch.glow_if = {"step_ge": StoryData.NACHT}
					arch.glow_color = Color("ff3ad0")
					arch.glow_radius = 40.0

	# Het huis (5x5 tiles uit huis.png) op de laag Gebouwen + een deur-object.
	for hy in HOUSE_SIZE.y:
		for hx in HOUSE_SIZE.x:
			gebouwen.set_cell(house_pos + Vector2i(hx, hy), 1, Vector2i(hx, hy))
	var door := add_instance(objects, root, "res://scenes/door.tscn", "Door", tile_center(house_pos + HOUSE_DOOR))
	door.target_map = HOUSE_PATH   # v0.10: het huis is open
	door.target_spawn = "binnen"
	add_spawn(root, "voor_huis", house_pos + HOUSE_DOOR + Vector2i(0, 1), Vector2i.DOWN)

	# Spawnpunten en uitgang
	var start := house_pos + HOUSE_DOOR + Vector2i(0, 2)   # 2 tiles voor de deur
	add_spawn(root, "start", start, Vector2i.DOWN)
	add_spawn(root, "zuid_ingang", Vector2i(15, TOWN_MAP.size() - 3), Vector2i.UP)
	add_exit(root, "NaarWereld", Rect2i(14, TOWN_MAP.size() - 1, 3, 1), WORLD_PATH, "van_dorp")
	root.get_node("Exits/NaarWereld").event = "pad_wereld"   # v0.11: dicht tijdens de proloog
	add_instance(objects, root, "res://scenes/player.tscn", "Player", tile_center(start))
	add_touch_controls(root)
	return root


## Kies de tile voor (x, y) in het dorp: de basis uit TOWN_LEGEND of een rand-variant.
func pick_town_tile(x: int, y: int) -> int:
	var ch := town_cell(x, y)
	var base: int = TOWN_LEGEND[ch]
	if base == 0:   # gras: schaduw van boom/heg/muur/huis erboven of links
		var m := 0
		if town_cell(x, y - 1) in ["T", "r", "o", "w", "h"]:
			m |= 1
		if town_cell(x - 1, y) in ["T", "r", "o", "w", "h"]:
			m |= 2
		if ch == "h":
			return base
		return GRASS_SHADOW_BASE + m if m > 0 else base
	if ch == "=" or ch == "#" or ch == "N":
		var m := 0
		if town_is_green(town_cell(x, y - 1)): m |= 1
		if town_is_green(town_cell(x + 1, y)): m |= 2
		if town_is_green(town_cell(x, y + 1)): m |= 4
		if town_is_green(town_cell(x - 1, y)): m |= 8
		if m == 0:
			return base
		return (PATH_EDGE_BASE if ch == "=" else COBBLE_EDGE_BASE) + m
	if ch == "~":
		var m := 0
		if not (town_cell(x, y - 1) in ["~", ""]): m |= 1
		if not (town_cell(x + 1, y) in ["~", ""]): m |= 2
		if not (town_cell(x - 1, y) in ["~", ""]): m |= 4
		return WATER_BANK_BASE + m if m > 0 else base
	return base


## v0.11: verhaal-object (scenes/story_object.tscn) met plaatje uit assets/sprites/story/.
func story_obj(objects: Node, root: Node, node_name: String, t: Vector2i, png: String, frames: int,
		event: String, arg := "", frame_rules: Array = []) -> Node2D:
	var o := add_instance(objects, root, "res://scenes/story_object.tscn", node_name, tile_center(t))
	o.texture = load(png if png.begins_with("res://") else "res://assets/sprites/story/" + png)
	o.hframes = frames
	o.event = event
	o.event_arg = arg
	o.frame_rules = frame_rules
	return o


func town_cell(x: int, y: int) -> String:
	if y < 0 or y >= TOWN_MAP.size() or x < 0 or x >= TOWN_MAP[y].length():
		return ""
	return TOWN_MAP[y][x]


## Begroeid (gras-achtig): daar krijgt een pad/kassei een grasrandje naartoe.
func town_is_green(ch: String) -> bool:
	return ch in [".", ",", "*", "S", "T", "o", "-", "W", "j", "Z", "K", "O", "A", "a", "U"]


# ---------------------------------------------------------------- wereldkaart
func build_world(tileset: TileSet) -> Node2D:
	var root := new_map_root("Wereldkaart", "World Map", true)   # overal monsters
	add_layers(root, tileset, false)
	var ground: TileMapLayer = root.get_node("Ground")
	var sea := sea_masks()
	var town_rect := Rect2i(-1, -1, 0, 0)
	var village_rect := Rect2i()
	var esdoorn_rect := Rect2i()
	var woud_tile := Vector2i(-1, -1)
	var spawn := Vector2i.ZERO
	for y in WORLD_MAP.size():
		var row: String = WORLD_MAP[y]
		for x in row.length():
			var ch := row[x]
			var i := pick_world_tile(x, y, sea)
			ground.set_cell(Vector2i(x, y), 0, Vector2i(i % W_COLS, i / W_COLS))
			if ch == "H":
				if town_rect.position.x < 0:
					town_rect = Rect2i(x, y, 1, 1)
				else:
					town_rect = town_rect.expand(Vector2i(x, y))
					town_rect.size = Vector2i(x - town_rect.position.x + 1, 1)
			elif ch == "V":
				village_rect = Rect2i(Vector2i(x, y), Vector2i.ONE) if village_rect.size == Vector2i.ZERO \
						else village_rect.merge(Rect2i(Vector2i(x, y), Vector2i.ONE))
			elif ch == "E":
				# v0.17 Esdoorn (2x2): tegel 0 lb, 1 rb, 2 lo, 3 ro uit wereld_v17_iconen.png
				var ei := (1 if world_cell(x - 1, y) == "E" else 0) + (2 if world_cell(x, y - 1) == "E" else 0)
				ground.set_cell(Vector2i(x, y), 1, Vector2i(ei, 0))
				esdoorn_rect = Rect2i(Vector2i(x, y), Vector2i.ONE) if esdoorn_rect.size == Vector2i.ZERO \
						else esdoorn_rect.merge(Rect2i(Vector2i(x, y), Vector2i.ONE))
			elif ch == "W":
				ground.set_cell(Vector2i(x, y), 1, Vector2i(4, 0))
				woud_tile = Vector2i(x, y)
			elif ch == "p":
				spawn = Vector2i(x, y)
			elif ch == "D":
				# v0.13: de trap = de ingang van De Vergeten Archieven (eerste dungeonkamer);
				# terug uit de dungeon kom je er net boven uit (spawn 'van_archief').
				add_exit(root, "Trap", Rect2i(x, y, 1, 1), ARCHIEF_PATH, "ingang")
				add_spawn(root, "van_archief", Vector2i(x, y - 1), Vector2i.UP)
	# v0.13: het oude stadsicoon is nu het Wachtershuis (scène wilgendal.tscn = 'Huis aan de
	# bosrand'); het nieuwe dorp Wilgendal heeft een eigen uitgang + spawn.
	add_exit(root, "NaarWachtershuis", town_rect, TOWN_PATH, "zuid_ingang")
	add_spawn(root, "van_dorp", spawn, Vector2i.DOWN)
	var lines_later: Array[String] = []
	add_exit(root, "NaarWilgendal", village_rect, VILLAGE_PATH, "zuid_ingang", lines_later)
	add_spawn(root, "van_wilgendal", village_rect.position + Vector2i(0, village_rect.size.y), Vector2i.DOWN)
	# v0.17 Esdoorn (pas open na de Golem: event naar_esdoorn) en het Donker Woud (pas met de opdracht)
	add_exit(root, "NaarEsdoorn", esdoorn_rect, ESDOORN_PATH, "zuid_ingang")
	root.get_node("Exits/NaarEsdoorn").event = "naar_esdoorn"
	add_spawn(root, "van_esdoorn", esdoorn_rect.position + Vector2i(0, esdoorn_rect.size.y), Vector2i.DOWN)
	add_exit(root, "NaarWoud", Rect2i(woud_tile, Vector2i.ONE), WOUD_PATH, "ingang")
	root.get_node("Exits/NaarWoud").event = "woud_ingang"
	add_spawn(root, "van_woud", woud_tile + Vector2i.RIGHT, Vector2i.RIGHT)
	add_instance(root.get_node("Objects"), root, "res://scenes/player.tscn", "Player", tile_center(spawn))
	add_touch_controls(root)
	return root


func world_cell(x: int, y: int) -> String:
	if y < 0 or y >= WORLD_MAP.size() or x < 0 or x >= WORLD_MAP[y].length():
		return "~"   # buiten de kaart = zee
	return WORLD_MAP[y][x]


## Masker: welke buren (N1 E2 S4 W8) een van de tekens in group zijn.
func mask4(x: int, y: int, group: String) -> int:
	var m := 0
	if world_cell(x, y - 1) in group: m |= 1
	if world_cell(x + 1, y) in group: m |= 2
	if world_cell(x, y + 1) in group: m |= 4
	if world_cell(x - 1, y) in group: m |= 8
	return m


func pick_world_tile(x: int, y: int, sea: Array) -> int:
	var ch := world_cell(x, y)
	match ch:
		"~":
			var m := 0
			var dirs := [[1, 0, -1], [2, 1, 0], [4, 0, 1], [8, -1, 0], [16, 1, -1], [32, 1, 1], [64, -1, 1], [128, -1, -1]]
			for d in dirs:
				if world_cell(x + d[1], y + d[2]) != "~":
					m |= d[0]
			for c in [[16, 1, 2], [32, 2, 4], [64, 4, 8], [128, 8, 1]]:
				if m & c[1] or m & c[2]:
					m &= ~c[0]
			return W_SEA + sea.find(m)
		",":
			return W_LIGHT + mask4(x, y, ",")
		":":
			return W_SAND + mask4(x, y, ":")
		"T":
			return W_FOREST + mask4(x, y, "T")
		"^":
			return (W_MOUNT if (x + y) % 2 == 0 else W_MOUNT_B) + mask4(x, y, "^")
		"H":
			return W_HOUSE + (1 if world_cell(x - 1, y) == "H" else 0)
		"V":
			return W_VILLAGE + (1 if world_cell(x - 1, y) == "V" else 0) + (2 if world_cell(x, y - 1) == "V" else 0)
		"D":
			return W_STAIRS
	return W_GRASS + (1 if (x * 7 + y * 13) % 5 == 0 else 0)


## De 47 kust-maskers, in dezelfde volgorde als in tools/art_maps.py sea_masks():
## bits N1 E2 S4 W8 = land aan die kant, NE16 SE32 SW64 NW128 = land op die hoek
## (een hoek telt alleen als de twee zijkanten ernaast water zijn).
func sea_masks() -> Array:
	var out := []
	for m in 256:
		var r := m
		for c in [[16, 1, 2], [32, 2, 4], [64, 4, 8], [128, 8, 1]]:
			if m & c[1] or m & c[2]:
				r &= ~c[0]
		if r == m:
			out.append(m)
	return out


# ---------------------------------------------------------------- binnen (v0.10)
func build_inside_tileset() -> TileSet:
	var ts := new_tileset()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/binnen.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var solid := {}
	for k in INSIDE_LEGEND:
		solid[INSIDE_LEGEND[k][0]] = solid.get(INSIDE_LEGEND[k][0], false) or INSIDE_LEGEND[k][1]
	var skip := {}
	for first in INSIDE_ANIM:
		for f in range(1, INSIDE_ANIM[first]):
			skip[first + f] = true
	@warning_ignore("integer_division")
	var count := src.texture.get_width() / TILE
	for i in count:
		if skip.has(i):
			continue
		add_tile(src, Vector2i(i, 0), solid.get(i, false), "binnen")
		if INSIDE_ANIM.has(i):
			src.set_tile_animation_frames_count(Vector2i(i, 0), INSIDE_ANIM[i])
			for f in INSIDE_ANIM[i]:
				src.set_tile_animation_frame_duration(Vector2i(i, 0), f, INSIDE_ANIM_FRAME_TIME)
	return ts


func build_inside(tileset: TileSet) -> Node2D:
	var root := new_map_root("Huis", "The House", false)   # binnen: geen monsters
	# zwart rondom de kamer (de kamer is kleiner dan het scherm)
	var void_rect := ColorRect.new()
	void_rect.color = Color(0.02, 0.02, 0.025)
	void_rect.position = Vector2(-640, -480)
	void_rect.size = Vector2(1472, 1104)
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_node(root, root, void_rect, "Void")
	add_layers(root, tileset, false)
	var ground: TileMapLayer = root.get_node("Ground")
	var objects: Node = root.get_node("Objects")
	var spawn := Vector2i(1, 1)
	for y in INSIDE_MAP.size():
		var row: String = INSIDE_MAP[y]
		for x in row.length():
			var ch := row[x]
			ground.set_cell(Vector2i(x, y), 0, Vector2i(int(INSIDE_LEGEND[ch][0]), 0))
			match ch:
				"X":
					add_book(objects, root, "SaveBook", Vector2i(x, y), "save")
				"P":
					spawn = Vector2i(x, y)
				"O":
					var npc := add_instance(objects, root, "res://scenes/npc.tscn", "OudeMan", tile_center(Vector2i(x, y)))
					npc.npc_name = "Old Man"
					npc.sheet = load(WACHTER_SHEET)   # v0.13: RPG ART's Wachter
					npc.facing = Vector2i.DOWN
					npc.show_if = {"step_ge": StoryData.AVOND, "step_lt": StoryData.OPGESLOTEN}
					var lines: Array[String] = ["..."]
					npc.lines = lines
				"G":
					story_obj(objects, root, "Schilderij", Vector2i(x, y), "schilderij.png", 2, "schilderij",
							"", [[{"flags": ["schilderij_weg"]}, 1]])
				"Z":
					add_spawn(root, "lezen", Vector2i(x, y), Vector2i.LEFT)
				"B":
					# Update 5: niet óp het bedmeubel (blokkeert), maar één tile rechts.
					add_spawn(root, "bed", Vector2i(x + 1, y), Vector2i.DOWN)
				"D":
					add_exit(root, "NaarDorp", Rect2i(x, y, 1, 1), TOWN_PATH, "voor_huis")
					root.get_node("Exits/NaarDorp").event = "huis_uit"   # v0.11: kan op slot zitten
	add_spawn(root, "binnen", spawn, Vector2i.UP)
	add_instance(objects, root, "res://scenes/player.tscn", "Player", tile_center(spawn))
	add_touch_controls(root)
	return root


# ---------------------------------------------------------------- v0.17 Esdoorn
func esdoorn_cell(x: int, y: int) -> String:
	if y < 0 or y >= ESDOORN_MAP.size() or x < 0 or x >= ESDOORN_MAP[y].length():
		return ""
	return ESDOORN_MAP[y][x]


func build_esdoorn(tileset: TileSet) -> Node2D:
	var root := new_map_root("Esdoorn", "Mapleton", false)   # dorp: geen monsters
	add_layers(root, tileset, true)
	var ground: TileMapLayer = root.get_node("Ground")
	var gebouwen: TileMapLayer = root.get_node("Gebouwen")
	var objects: Node = root.get_node("Objects")
	# pick_town_tile() leest TOWN_MAP: even ESDOORN_MAP gebruiken via een eigen kopie van de logica
	for y in ESDOORN_MAP.size():
		var row: String = ESDOORN_MAP[y]
		for x in row.length():
			ground.set_cell(Vector2i(x, y), 0, Vector2i(pick_esdoorn_tile(x, y), 0))
			if row[x] == "W":
				var well := story_obj(objects, root, "Put", Vector2i(x, y), BUITEN + "put.png", 1, "esdoorn_put")
				well.tiles = Vector2i(2, 2)
	for hd in ESDOORN_HOUSES:
		var hp: Vector2i = hd[0]
		for hy in HOUSE_SIZE.y:
			for hx in HOUSE_SIZE.x:
				gebouwen.set_cell(hp + Vector2i(hx, hy), 1, Vector2i(hx, hy))
		var door := add_instance(objects, root, "res://scenes/door.tscn", "Deur_" + str(hd[3]), tile_center(hp + HOUSE_DOOR))
		door.target_map = str(hd[1])
		door.target_spawn = str(hd[2])
		if str(hd[1]) == "":
			door.lines = ESDOORN_LOCKED_LINES
		add_spawn(root, str(hd[3]), hp + HOUSE_DOOR + Vector2i(0, 1), Vector2i.DOWN)
	for d in ESDOORN_NPCS:
		add_villager(objects, root, d)
	# Noor (loopsprite van RPG ART), alleen tot de ontmoeting
	var noor := add_instance(objects, root, "res://scenes/npc.tscn", "Vesper", tile_center(ESDOORN_NOOR))
	noor.npc_name = "Vesper"
	noor.sheet = load(NOOR_SHEET)
	noor.facing = Vector2i.DOWN
	noor.show_if = {"not_flags": ["noor_ontmoet"]}
	var nl: Array[String] = ["..."]
	noor.lines = nl
	# de wortelgreep (Noor in de wortelcocon, RPG ART): verborgen, alleen 'show' in de cutscene
	var greep := story_obj(objects, root, "WortelGreep", ESDOORN_GREEP, "res://assets/sprites/woud/noor_cocon_puls.png", 2, "")
	greep.show_if = {"flags": ["__cutscene_wortelgreep"]}
	greep.loop_if = {"not_flags": ["__nooit"]}
	greep.loop_texture = load("res://assets/sprites/woud/noor_cocon_puls.png")
	greep.loop_frames = 2
	greep.loop_time = 0.25
	greep.glow_if = {"not_flags": ["__nooit"]}
	greep.glow_color = Color("ff3ad0")
	greep.z_index = 1
	var sign := add_instance(objects, root, "res://scenes/sign.tscn", "BordWoud", tile_center(ESDOORN_SIGN))
	sign.lines = ESDOORN_SIGN_LINES
	var start := Vector2i(16, ESDOORN_MAP.size() - 3)
	add_spawn(root, "zuid_ingang", start, Vector2i.UP)
	add_exit(root, "NaarWereld", Rect2i(15, ESDOORN_MAP.size() - 1, 3, 1), WORLD_PATH, "van_esdoorn")
	add_instance(objects, root, "res://scenes/player.tscn", "Player", tile_center(start))
	add_touch_controls(root)
	return root


## Dorpeling: [node, naam, tile, richting, event, kleur].
func add_villager(objects: Node, root: Node, d: Array) -> void:
	var npc := add_instance(objects, root, "res://scenes/npc.tscn", str(d[0]), tile_center(d[2]))
	npc.npc_name = str(d[1])
	npc.facing = d[3]
	npc.event = str(d[4])
	npc.modulate = d[5]
	var l: Array[String] = ["..."]
	npc.lines = l


## Zelfde regels als pick_town_tile(), maar voor ESDOORN_MAP.
func pick_esdoorn_tile(x: int, y: int) -> int:
	var ch := esdoorn_cell(x, y)
	var base: int = TOWN_LEGEND[ch]
	if base == 0:
		if ch == "h":
			return base
		var m := 0
		if esdoorn_cell(x, y - 1) in ["T", "r", "o", "w", "h"]:
			m |= 1
		if esdoorn_cell(x - 1, y) in ["T", "r", "o", "w", "h"]:
			m |= 2
		return GRASS_SHADOW_BASE + m if m > 0 else base
	if ch == "=" or ch == "#" or ch == "N":
		var m := 0
		if town_is_green(esdoorn_cell(x, y - 1)): m |= 1
		if town_is_green(esdoorn_cell(x + 1, y)): m |= 2
		if town_is_green(esdoorn_cell(x, y + 1)): m |= 4
		if town_is_green(esdoorn_cell(x - 1, y)): m |= 8
		if m == 0:
			return base
		return (PATH_EDGE_BASE if ch == "=" else COBBLE_EDGE_BASE) + m
	if ch == "~":
		var m := 0
		if not (esdoorn_cell(x, y - 1) in ["~", ""]): m |= 1
		if not (esdoorn_cell(x + 1, y) in ["~", ""]): m |= 2
		if not (esdoorn_cell(x - 1, y) in ["~", ""]): m |= 4
		return WATER_BANK_BASE + m if m > 0 else base
	return base


## Interieur uit binnen.png (INSIDE_LEGEND). npcs = [[node, naam, tile, richting, event, kleur]].
func build_interior(root_name: String, map_name: String, rows: Array, npcs: Array, out_spawn: String) -> Node2D:
	var root := new_map_root(root_name, map_name, false)
	var void_rect := ColorRect.new()
	void_rect.color = Color(0.02, 0.02, 0.025)
	void_rect.position = Vector2(-640, -480)
	void_rect.size = Vector2(1472, 1104)
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_node(root, root, void_rect, "Void")
	add_layers(root, load("res://assets/tiles/binnen.tres"), false)
	var ground: TileMapLayer = root.get_node("Ground")
	var objects: Node = root.get_node("Objects")
	var spawn := Vector2i(1, 1)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			ground.set_cell(Vector2i(x, y), 0, Vector2i(int(INSIDE_LEGEND[ch][0]), 0))
			match ch:
				"X":
					add_book(objects, root, "SaveBook", Vector2i(x, y), "save")
				"P":
					spawn = Vector2i(x, y)
				"D":
					add_exit(root, "NaarBuiten", Rect2i(x, y, 1, 1), ESDOORN_PATH, out_spawn)
	for d in npcs:
		add_villager(objects, root, d)
	add_spawn(root, "binnen", spawn, Vector2i.UP)
	add_instance(objects, root, "res://scenes/player.tscn", "Player", tile_center(spawn))
	add_touch_controls(root)
	return root
