extends RefCounted
## v0.13/v0.14 DUNGEONKAMERS als DATA (De Vergeten Archieven). scripts/dungeon/dungeon_room.gd bouwt
## er de kamer mee (vloer/muren, savepunt, uitgangen, spawnpunten, kisten, HP-boeken, losse
## meubels en de zichtbare map-monsters).
##
## v0.14 EERSTE ARCHIEF = 4 verdiepingen (plan: story/ARCHIEF1_PLATTEGROND.md). De layouts van de
## gewone kamers komen uit tools/gen_archief1_rooms.py (zet de ontwerp-kaarten om naar deze tekens);
## de bibliotheek en de Golemhal zijn met de hand gemaakt. De puzzelkamer (3B) is een PuzzleRoom
## (scripts/data/puzzle_rooms.gd, "archief_puzzel") en staat dus niet hier.
##
## v0.15: het BEELD komt uit het thema van de kamer (THEMES hieronder, standaard "archief_grijs" =
## de grijze vervallen bibliotheek); de nummers hieronder blijven gelijk.
## Tegels: assets/tiles/dungeon/dungeon_tiles_v14.png van RPG ART (16x16, 16 kolommen; 0-63 zijn
## precies dungeon_tiles.png, lijst in docs/DUNGEON_TILES.txt; 64 = donkere onderrand-doorgang).
## Tegelnummers vanaf 100 = assets/tiles/dungeon/bibliotheek_tiles.png (nummer - 100, lijst in
## docs/BIBLIOTHEEK_TILES.txt). In "layout" staat 1 teken per tile; LEGEND (+ optioneel een eigen
## "legend" per kamer) zegt welk tegelnummer dat is. '.' = gewone vloer (de bouwer kiest zelf
## vloer A/B/C, of de nummers in "floor" van de kamer).
##
## Per kamer (v0.14):
##   "name", "floor" (verdieping 1-4), "tier" (monsterniveau 1-4, zie game_data.gd TIERS; alleen
##           voor map-monsters in deze kamer, NIET voor een baas en niet op de wereldkaart)
##   "spawns" {naam: [x, y, richting]}       waar je binnenkomt (richting "up"/"down"/"left"/"right")
##   "exits"  {teken: {"map", "spawn"}}      alle tiles met dat teken = één uitgang (zie EXIT_CHARS):
##            'E' naar buiten (30), 'U' onderrand-doorgang (64), 'n' boog/deur (43, onderste rij),
##            'v' trap omlaag (58), 'h' ladder omhoog (44/45, beide tiles)
##   "save"   [x, y] opslagboek (+ "save_type" uit book_data.gd, "save_offset" [x, y] in pixels)
##   "books"  [{"type": "hp"/"mp", "tile": [x, y]}]   boekpunten (rood/groen)
##   "chests" [{"id", "tile", "item", "n"}]  kist (assets/sprites/buiten/kist.png); eenmalig: de vlag
##            "kist:<id>" in GameState.story_flags (gaat mee in de save)
##   "props"  [{"type", "tile", ...}]        losse meubels (zie PROPS): staande kast, kandelaar, golemdeur
##   "monsters" (zie hieronder)
##
## MAP-MONSTERS (Lufia 2-stijl, GEEN random encounters in dungeons): lijst "monsters", per monster
##   "id"     uniek binnen de kamer (onthoudt of hij verslagen is)
##   "enemy"  vijand-id uit game_data.gd ENEMIES (plaatje: assets/map_monsters/<enemy>.png;
##            ontbreekt dat, dan een gemarkeerde placeholder)
##   "tile"   [x, y] starttile
##   "moves"  true = loopt willekeurig rond (tile voor tile, korte pauzes), false = staat stil
##   optioneel: "group" = vijandgroep van het gevecht (standaard [enemy]),
##              "guard" = true -> BEWAKER: staat stil en blijft na winst VOOR ALTIJD weg
##                        (vlag "bewaker:<kamer>/<id>" in GameState.story_flags, gaat mee in de save),
##              "boss" = true -> baasgevecht (achtergrond 'boss', baas-stats; geen tier),
##              "sprite" = ander bestand in assets/map_monsters/ (zonder .png), bv. "golem",
##              "size" = [w, h] in tiles (standaard [1, 1]; de Golem is 2x2),
##              "frame" = [w, h] framegrootte in pixels (standaard 16x16; de Golem 32x32),
##              "fps" = animatiesnelheid (lopen 4, stilstaand plaatje: langzaam)
## Aanraken (jij loopt ertegen, of hij loopt tegen jou) = gevecht met zijn groep. Na winst is hij
## weg (tot je de kamer opnieuw binnenkomt, behalve bewakers); na vluchten blijft hij staan en
## knipper je 1,5 s (onkwetsbaar). Stilstaande monsters starten het gevecht ook met A.

const TILES := "res://assets/tiles/dungeon/dungeon_tiles_v14.png"
## v0.14: tweede atlas (tegelnummers vanaf LIB_BASE).
const LIB_TILES := "res://assets/tiles/dungeon/bibliotheek_tiles.png"

## v0.15 THEMA'S (stijl van een dungeon): welke tegelsets en welke losse sprites. De TEGELNUMMERS,
## botsing (SOLID) en indeling blijven per thema gelijk; alleen het beeld verandert.
##   "tiles"     atlas voor tegels 0-79 (zelfde nummering als dungeon_tiles_v14.png)
##   "lib_tiles" atlas voor tegels vanaf LIB_BASE (zelfde nummering als bibliotheek_tiles.png)
##   "sprites"   origineel pad -> pad in dit thema (kisten, meubels, puzzelobjecten); ontbreekt
##               een pad, dan het origineel
## Kiezen: per kamer "theme" (dungeon_rooms.gd ROOMS of puzzle_rooms.gd met "style": "dungeon");
## zonder "theme" -> DEFAULT_THEME. Zo krijgen ALLE archieven (ook toekomstige) standaard de grijze
## vervallen bibliotheek van de gevechtsachtergrond (assets/battle/bibliotheek.png).
## "archief_grijs" = gegenereerd door tools/art_archief_grijs.py (geen handwerk);
## "archief_v14" = de oorspronkelijke bruine archief-art van RPG ART (v0.14).
const DEFAULT_THEME := "archief_grijs"
const SPRITES_GRIJS := "res://assets/sprites/dungeon/grijs/"
const THEMES := {
	"archief_grijs": {
		"tiles": "res://assets/tiles/dungeon/archief_grijs_tiles.png",
		"lib_tiles": "res://assets/tiles/dungeon/archief_grijs_bibliotheek.png",
		"sprites": {
			"res://assets/sprites/dungeon/staande_kast.png": SPRITES_GRIJS + "staande_kast.png",
			"res://assets/sprites/dungeon/kandelaar.png": SPRITES_GRIJS + "kandelaar.png",
			"res://assets/sprites/dungeon/golemdeur.png": SPRITES_GRIJS + "golemdeur.png",
			"res://assets/sprites/dungeon/leestafel.png": SPRITES_GRIJS + "leestafel.png",
			"res://assets/sprites/dungeon/schatkist.png": SPRITES_GRIJS + "schatkist.png",
			"res://assets/sprites/buiten/kist.png": SPRITES_GRIJS + "kist.png",
			"res://assets/puzzle/geheime_deur_archief.png": SPRITES_GRIJS + "geheime_deur_archief.png",
			"res://assets/puzzle/drukplaat.png": SPRITES_GRIJS + "drukplaat.png",
			"res://assets/puzzle/drukplaat_rune.png": SPRITES_GRIJS + "drukplaat_rune.png",
			"res://assets/puzzle/kast_vast.png": SPRITES_GRIJS + "kast_vast.png",
			"res://assets/puzzle/kast_duwbaar.png": SPRITES_GRIJS + "kast_duwbaar.png",
			"res://assets/puzzle/kast_zwaar.png": SPRITES_GRIJS + "kast_zwaar.png",
			"res://assets/puzzle/poort.png": SPRITES_GRIJS + "poort.png",
			"res://assets/puzzle/hendel.png": SPRITES_GRIJS + "hendel.png",
			"res://assets/puzzle/herstelsteen.png": SPRITES_GRIJS + "herstelsteen.png",
		},
	},
	"archief_v14": {"tiles": TILES, "lib_tiles": LIB_TILES, "sprites": {}},
	# v0.17 HET DONKER WOUD (scripts/data/woud_rooms.gd), tegels van RPG ART (art_woud_v17,
	# docs/WOUD_TILES.txt): woud_tiles.png 256x112. 0-64 = zelfde nummering/botsing als
	# dungeon_tiles_v14 (bladerdak = muurtop, stammen = voorkant, wortels/paddenstoelen = decor),
	# 65-111 = bostegels (pad, wortels, mist, bomen 2x3, wortelpoorten). Extra velden (optioneel, elk thema):
	#   "terrain"     = terrein van de tegels (gevechtsachtergrond + encounters), standaard TERRAIN
	#   "tint"        = kleur over de hele kamer (CanvasModulate), "mist" = drijvende mistvlekken
	#   "single_atlas" = true: ALLE nummers (ook 100-111) uit "tiles"; geen bibliotheek-atlas (LIB_BASE)
	#   "solid_extra" / "no_monster_extra" = extra massieve / monstervrije tegels van dit thema
	#   "trees"       = boomsoort -> {"feet": [l, r] (grondlaag, massief), "crown": [[boven l, r], [onder l, r]]
	#                   (overlay-laag boven de speler)}; kamers zetten bomen met "trees": [[x, y, soort]]
	#   "mist_band"   = [begin, midden..., eind] overlay-tegels voor "mist": [[x, y, lengte]] in een kamer
	"donker_woud": {
		"tiles": "res://assets/tiles/dungeon/woud_tiles.png",
		"lib_tiles": "res://assets/tiles/dungeon/archief_grijs_bibliotheek.png",
		"single_atlas": true,
		"terrain": "woud",
		"tint": Color(0.86, 0.92, 0.90),
		"mist": true,
		"solid_extra": [87, 88, 89, 90, 96, 97, 98, 99, 100, 101, 104],
		"no_monster_extra": [91],
		"trees": {
			"A": {"feet": [96, 97], "crown": [[76, 77], [92, 93]]},     # dode boom met glitch-litteken
			"B": {"feet": [98, 99], "crown": [[78, 79], [94, 95]]},     # treurboom met mosgordijn
		},
		"mist_band": [109, 82, 83, 110],
		"sprites": {},
	},
}
## Thema van de kamer die nu gebouwd wordt (DungeonRoom / PuzzleRoom zetten dit in _build; "" =
## geen dungeonthema, bv. een puzzelkamer met binnen.png). Losse objecten (kist, kast, hendel...)
## laden hun plaatje via themed() zodat ze in de stijl van de kamer verschijnen.
static var current_theme := ""
const LIB_BASE := 100
## Kolommen in de atlassen (256 / 16).
const COLS := 16
## Massieve tegels (botsing). Zie docs/DUNGEON_TILES.txt en docs/BIBLIOTHEEK_TILES.txt ('solid ja').
const SOLID := [12, 13, 14, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 31,
	32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 46, 47, 54, 55, 56, 59, 60, 61,
	100, 101, 102, 103, 104, 105, 106, 107, 108, 116, 117, 118, 119, 120, 121, 122, 123, 124,
	138, 139, 140, 141, 142]
## Hier lopen map-monsters NIET heen (wel de speler): uitgangen, ladder, boog, platform, trap, rune.
const NO_MONSTER := [30, 43, 44, 45, 48, 49, 50, 51, 52, 53, 57, 58, 62, 63, 64]
## Vloervarianten voor '.' (vloer A, B, C).
const FLOOR := [0, 1, 2]
## Terrein van alle tegels (custom data "terrain"): bepaalt de gevechtsachtergrond
## (game_data.gd TERRAIN_BACKDROP: "archief" -> de bibliotheek). Geen random encounters:
## "archief" staat niet in ENCOUNTER_RATES en de kamer heeft encounters = false.
const TERRAIN := "archief"
## v0.14 Uitgang-tekens: teken in de layout -> sleutel in "exits" (de ladder heeft 2 tekens).
const EXIT_CHARS := {"E": "E", "U": "U", "n": "n", "v": "v", "H": "h", "h": "h"}
## v0.14 Losse meubels/objecten ("props"): plaatje, frames, hoogte (16x32 = voet op de tile,
## steekt 1 tile omhoog), botsing. "solid_h" = hoeveel tiles (vanaf de voet omhoog) massief zijn.
const PROPS := {
	"staande_kast": {"texture": "res://assets/sprites/dungeon/staande_kast.png", "hframes": 2, "h": 32, "solid": true},
	"kandelaar": {"texture": "res://assets/sprites/dungeon/kandelaar.png", "hframes": 2, "h": 32, "solid": true, "fps": 3.0},
	# grote deur naar de Golemhal (2x2 tiles over de muurvoorkant); de botsing komt van de tegels
	# eronder: bovenste rij muur, onderste rij = boog-doorgang 'n' (uitgang)
	"golemdeur": {"texture": "res://assets/sprites/dungeon/golemdeur.png", "hframes": 2, "w": 32, "h": 32, "solid": false},
}

## teken -> tegelnummer
const LEGEND := {
	# muurtoppen (rand van de kamer)
	"a": 28, "-": 23, "b": 27, "<": 21, ">": 19, "c": 26, "_": 17, "d": 25,
	# v0.14 muurtoppen van pilaren/muurblokken (16..24 = NW N NO W midden O ZW Z ZO)
	"1": 16, "2": 17, "3": 18, "4": 19, "5": 20, "6": 21, "7": 22, "8": 23, "9": 24,
	# muurvoorkant (2 hoog: hoofdletter = boven, kleine letter = onder)
	"F": 32, "f": 33, "L": 34, "l": 35, "R": 36, "r": 37, "G": 38, "g": 39,
	"K": 40, "k": 41, "M": 46, "m": 47, "H": 44, "h": 45,
	# v0.14 boogdoorgang (boven muur, onder = doorgang/uitgang 'n')
	"A": 42, "n": 43,
	# vloer
	".": 0, "s": 8, "S": 9, "Z": 10, "u": 11,
	"w": 3, "x": 4, "p": 5, ",": 6, "X": 7, "*": 15,
	# massief decor
	"#": 59, "B": 60, "N": 61,
	# savepunt-sokkel (het opslagboek komt erop) en de uitgang naar buiten
	"@": 12, "(": 29, "E": 30, ")": 31,
	# v0.14 trap omlaag en de donkere onderrand-doorgang (RPG ART, tegel 64)
	"v": 58, "U": 64,
	# platform voor de Golem
	"[": 51, "=": 52, "]": 53, "{": 54, "~": 55, "}": 56, "^": 57, "o": 62, "O": 63,
}

## v0.14 Eigen tekens van de bibliotheek (4C), bovenop LEGEND (bibliotheek_tiles = 100 + n).
const LIBRARY_LEGEND := {
	# boekenkastmuur boven / onder: linkereinde, midden A, midden B, rechtereinde, glitch-boek
	"1": 100, "2": 101, "3": 102, "4": 103, "5": 105,
	"6": 116, "7": 117, "8": 118, "9": 119, "0": 121,
	# houten vloer: schaduw onder de voorkant / naast de linkermuur / hoek, runenring (boekpunt)
	"s": 134, "S": 135, "Z": 136, "R": 157,
	# loper (kleed 2 breed): boven-eind, midden, onder-eind
	"[": 148, "]": 150, "{": 151, "}": 153, "q": 154, "Q": 156,
	# leestafel (2 tegels, massief)
	"t": 138, "T": 139,
}

const ROOMS := {
	# 1A Ingang (bestaand, met savepunt) (20x12), verdieping 1
	"archief_ingang": {
		"name": "Vergeten Archieven", "floor": 1, "tier": 1,
		"layout": [
			"a------------------b",
			"<LFFMFGFFAFFFFFFFFR>",
			"<lffmfgffnffffffffr>",
			"<Zsssssssssssssssss>",
			"<S#...x.........#..>",
			"<S.................>",
			"<S.........#.......>",
			"<S.................>",
			"<S.@...............>",
			"<S..p.........N....>",
			"<S.................>",
			"c_______(EE)_______d",
		],
		"save": [3, 8],
		"spawns": {"ingang": [9, 10, "up"], "boog": [9, 3, "down"]},
		"exits": {
			"E": {"map": "res://scenes/maps/wereldkaart.tscn", "spawn": "van_archief"},
			"n": {"map": "res://scenes/maps/archief_v1_gang.tscn", "spawn": "zuid"},
		},
		"monsters": [
			{"id": "m1", "enemy": "mosslijm", "group": ["mosslijm"], "tile": [13, 4], "moves": true},
			{"id": "m2", "enemy": "moskonijn", "group": ["moskonijn"], "tile": [6, 5], "moves": true},
			{"id": "m3", "enemy": "papiergeest", "group": ["papiergeest"], "tile": [14, 7], "moves": true},
		],
	},
	# 1B Stoffige Gang (scrolt horizontaal) (32x12), verdieping 1
	"archief_v1_gang": {
		"name": "Vergeten Archieven - Stoffige Gang", "floor": 1, "tier": 1,
		"layout": [
			"a------------------------------b",
			"<LFFFFFFFFFFFFMFFFFFFFFFFFFMFMR>",
			"<lffffffffffffmffffffffffffmfmr>",
			"<Zsssss1223ssssssssswssss13svss>",
			"<S.....LFFR..............LR....>",
			"<S......#...........123........>",
			"<S...........123....LFR........>",
			"<S.p.........LFR...........N...>",
			"<S.......N.....................>",
			"<S..............*.........13...>",
			"<S........................LR...>",
			"c_(UU)_________________________d",
		],
		"spawns": {"zuid": [3, 10, "up"], "trap": [27, 3, "down"]},
		"exits": {
			"U": {"map": "res://scenes/maps/archief_ingang.tscn", "spawn": "boog"},
			"v": {"map": "res://scenes/maps/archief_v2_kastenzaal.tscn", "spawn": "ladder"},
		},
		"chests": [{"id": "kist_1b", "tile": [23, 8], "item": "drankje", "n": 2}],
		"monsters": [
			{"id": "m1", "enemy": "mosslijm", "group": ["mosslijm", "mosslijm"], "tile": [3, 4], "moves": true},
			{"id": "m2", "enemy": "papiergeest", "group": ["papiergeest"], "tile": [7, 7], "moves": true},
			{"id": "m3", "enemy": "moskonijn", "group": ["moskonijn", "mosslijm"], "tile": [8, 9], "moves": true},
			{"id": "m4", "enemy": "glitchmot", "group": ["glitchmot"], "tile": [15, 4], "moves": true},
			{"id": "m5", "enemy": "papiergeest", "group": ["papiergeest", "papiergeest"], "tile": [17, 8], "moves": true},
			{"id": "m6", "enemy": "papiergeest", "group": ["papiergeest", "glitchmot"], "tile": [26, 6], "moves": true},
		],
	},
	# 2A Kastenzaal (1 scherm) (24x13), verdieping 2
	"archief_v2_kastenzaal": {
		"name": "Vergeten Archieven - Kastenzaal", "floor": 2, "tier": 2,
		"layout": [
			"a----------------------b",
			"<LFHFFFFFFFFFFMFFFFFAFR>",
			"<lfhffffffffffmfffffnfr>",
			"<Zsssssssssssssssssssss>",
			"<S.BBNB....NBBB....,...>",
			"<S.....................>",
			"<S.BBBB....BBBN..BNBB..>",
			"<S.....................>",
			"<S.BBBB....NBBB..BBBB..>",
			"<S.....................>",
			"<S..x..................>",
			"<S.....................>",
			"c______________________d",
		],
		"spawns": {"ladder": [3, 3, "down"], "boog": [20, 3, "down"]},
		"exits": {
			"h": {"map": "res://scenes/maps/archief_v1_gang.tscn", "spawn": "trap"},
			"n": {"map": "res://scenes/maps/archief_v2_leeszaal.tscn", "spawn": "zuid"},
		},
		"monsters": [
			{"id": "m1", "enemy": "papiergeest", "group": ["papiergeest", "papiergeest"], "tile": [15, 5], "moves": true},
			{"id": "m2", "enemy": "glitchmot", "group": ["glitchmot"], "tile": [7, 7], "moves": true},
			{"id": "m3", "enemy": "mech_wachter", "group": ["mech_wachter"], "tile": [16, 9], "moves": true},
		],
	},
	# 2B Leeszaal (scrolt verticaal) (20x24), verdieping 2
	"archief_v2_leeszaal": {
		"name": "Vergeten Archieven - Leeszaal", "floor": 2, "tier": 2,
		"layout": [
			"a------------------b",
			"<LFFFFFFFFAMFFFGFFR>",
			"<lffffffffnmfffgffr>",
			"<Zsssssssssssssssss>",
			"<S.BNBB......BBNN..>",
			"<S.................>",
			"<S.BBBB......BBBB..>",
			"<S.................>",
			"<S....13....13.....>",
			"<S....LR....LR.....>",
			"<S.................>",
			"<S.NBBB......BBBB..>",
			"<S.................>",
			"<S.BNBB......BBBB..>",
			"<S.................>",
			"<S....13....13.....>",
			"<S....LR....LR.....>",
			"<S.................>",
			"<S.BBBB......BBBB..>",
			"<S.................>",
			"<S.*...........w...>",
			"<S.................>",
			"<S.................>",
			"c_______(UU)_______d",
		],
		"spawns": {"zuid": [9, 22, "up"], "boog": [10, 3, "down"]},
		"exits": {
			"U": {"map": "res://scenes/maps/archief_v2_kastenzaal.tscn", "spawn": "boog"},
			"n": {"map": "res://scenes/maps/archief_v2_trapzaal.tscn", "spawn": "zuid"},
		},
		"chests": [{"id": "kist_2b", "tile": [2, 12], "item": "leren_kap", "n": 1}],
		"monsters": [
			{"id": "m1", "enemy": "glitchmot", "group": ["glitchmot", "papiergeest"], "tile": [9, 16], "moves": true},
			{"id": "m2", "enemy": "mech_wachter", "group": ["mech_wachter"], "tile": [9, 12], "moves": true},
			{"id": "m3", "enemy": "papiergeest", "group": ["papiergeest", "papiergeest", "glitchmot"], "tile": [9, 9], "moves": true},
			{"id": "m4", "enemy": "glitchmot", "group": ["glitchmot", "glitchmot"], "tile": [10, 5], "moves": true},
		],
	},
	# 2C Trapzaal + poortwachter (20x12), verdieping 2
	"archief_v2_trapzaal": {
		"name": "Vergeten Archieven - Trapzaal", "floor": 2, "tier": 2,
		"layout": [
			"a------------------b",
			"<LFFFFFFFKFFFFFFFFR>",
			"<lfffffffkffffffffr>",
			"<Zssssssssssss5v5ss>",
			"<S............F.F..>",
			"<S............f.f..>",
			"<S.................>",
			"<S.N.........#.....>",
			"<S.................>",
			"<S.x...............>",
			"<S.................>",
			"c_______(UU)_______d",
		],
		"spawns": {"zuid": [9, 10, "up"], "trap": [15, 4, "down"]},
		"exits": {
			"U": {"map": "res://scenes/maps/archief_v2_leeszaal.tscn", "spawn": "boog"},
			"v": {"map": "res://scenes/maps/archief_v3_zuilenhal.tscn", "spawn": "ladder"},
		},
		"books": [{"type": "hp", "tile": [2, 3]}],
		"chests": [{"id": "kist_2c", "tile": [15, 8], "item": "drankje", "n": 3}],
		"monsters": [
			{"id": "m1", "enemy": "mech_wachter", "group": ["mech_wachter", "papiergeest"], "tile": [5, 6], "moves": true},
			{"id": "m2", "enemy": "kennis_beest", "group": ["kennis_beest"], "tile": [15, 5], "moves": false, "guard": true},
		],
	},
	# 3A Zuilenhal (scrolt horizontaal) (32x13), verdieping 3
	"archief_v3_zuilenhal": {
		"name": "Vergeten Archieven - Zuilenhal", "floor": 3, "tier": 3,
		"layout": [
			"a------------------------------b",
			"<LHFFFFFFFFMFFFGFFMFFFFFFKKFAFR>",
			"<lhffffffffmfffgffmffffffkkfnfr>",
			"<Zsssssssssssssssssssssssssssss>",
			"<S..13.....13.....13.....13....>",
			"<S..LR.....LR.....LR.....LR....>",
			"<S..................,..........>",
			"<S.............................>",
			"<S..13.....13.....13.....13....>",
			"<S..LR.....LR.....LR.....LR....>",
			"<S.............................>",
			"<S.............................>",
			"c______________________________d",
		],
		"spawns": {"ladder": [2, 3, "down"], "boog": [28, 3, "down"]},
		"exits": {
			"h": {"map": "res://scenes/maps/archief_v2_trapzaal.tscn", "spawn": "trap"},
			"n": {"map": "res://scenes/maps/archief_puzzel.tscn", "spawn": "ingang"},
		},
		"books": [{"type": "hp", "tile": [27, 3]}],
		"chests": [{"id": "kist_3a", "tile": [2, 10], "item": "kaftschild", "n": 1}],
		"monsters": [
			{"id": "m1", "enemy": "glitchmot", "group": ["glitchmot", "glitchmot"], "tile": [8, 5], "moves": true},
			{"id": "m2", "enemy": "mech_wachter", "group": ["mech_wachter"], "tile": [6, 7], "moves": true},
			{"id": "m3", "enemy": "mech_wachter", "group": ["mech_wachter", "glitchmot"], "tile": [15, 5], "moves": true},
			{"id": "m4", "enemy": "kennis_beest", "group": ["kennis_beest"], "tile": [16, 7], "moves": true},
			{"id": "m5", "enemy": "papiergeest", "group": ["papiergeest", "papiergeest", "glitchmot"], "tile": [26, 7], "moves": true},
		],
	},
	# 3C Gang na de puzzel (20x12), verdieping 3
	"archief_v3_gang": {
		"name": "Vergeten Archieven - Gang", "floor": 3, "tier": 3,
		"layout": [
			"a------------------b",
			"<LFFGFFMFFFFFFFFFFR>",
			"<lffgffmffffffffffr>",
			"<Zssssssssss13sssvs>",
			"<S..........LR.....>",
			"<S.......#.........>",
			"<S.13..............>",
			"<S.LR....p.........>",
			"<S.................>",
			"<S.N...........N...>",
			"<S.................>",
			"c______(UU)________d",
		],
		"spawns": {"zuid": [8, 10, "up"], "trap": [16, 3, "down"]},
		"exits": {
			"U": {"map": "res://scenes/maps/archief_puzzel.tscn", "spawn": "uit_x"},
			"v": {"map": "res://scenes/maps/archief_v4_wachtersgang.tscn", "spawn": "ladder"},
		},
		"monsters": [
			{"id": "m1", "enemy": "mech_wachter", "group": ["mech_wachter"], "tile": [4, 4], "moves": true},
			{"id": "m2", "enemy": "mech_wachter", "group": ["mech_wachter", "mech_wachter"], "tile": [15, 6], "moves": true},
			{"id": "m3", "enemy": "kennis_beest", "group": ["kennis_beest", "papiergeest"], "tile": [10, 8], "moves": true},
		],
	},
	# 4A Wachtersgang (scrolt horizontaal) (32x12), verdieping 4
	"archief_v4_wachtersgang": {
		"name": "Vergeten Archieven - Wachtersgang", "floor": 4, "tier": 4,
		"layout": [
			"a------------------------------b",
			"<LHFFFFFFKFFFFFFFFMFFFFMFFFFFAR>",
			"<lhffffffkffffffffmffffmfffffnr>",
			"<Zsssssssssssssssssssssssssssss>",
			"<S......13.......13.......13...>",
			"<S......LR.......LR.......LR...>",
			"<S.............................>",
			"<S...................p.........>",
			"<S......13.......13.......13...>",
			"<S......LR.......LR.......LR...>",
			"<S.............................>",
			"c______________________________d",
		],
		"spawns": {"ladder": [2, 3, "down"], "boog": [29, 3, "down"]},
		"exits": {
			"h": {"map": "res://scenes/maps/archief_v3_gang.tscn", "spawn": "trap"},
			"n": {"map": "res://scenes/maps/archief_v4_voorhal.tscn", "spawn": "zuid"},
		},
		"books": [{"type": "hp", "tile": [4, 3]}],
		"monsters": [
			{"id": "m1", "enemy": "mech_wachter", "group": ["mech_wachter"], "tile": [4, 5], "moves": true},
			{"id": "m2", "enemy": "glitchmot", "group": ["glitchmot", "glitchmot", "glitchmot"], "tile": [13, 5], "moves": true},
			{"id": "m3", "enemy": "mech_wachter", "group": ["mech_wachter", "glitchmot"], "tile": [11, 7], "moves": true},
			{"id": "m4", "enemy": "kennis_beest", "group": ["kennis_beest"], "tile": [22, 5], "moves": true},
			{"id": "m5", "enemy": "mech_wachter", "group": ["mech_wachter", "mech_wachter"], "tile": [26, 7], "moves": true},
		],
	},
	# 4B Voorhal (20x12), verdieping 4
	"archief_v4_voorhal": {
		"name": "Vergeten Archieven - Voorhal", "floor": 4, "tier": 4,
		"layout": [
			"a------------------b",
			"<LFFGFFMFFAFFFFFFFR>",
			"<lffgffmffnfffffffr>",
			"<Zsssssssssssssssss>",
			"<S.13..........13..>",
			"<S.LR..........LR..>",
			"<S.................>",
			"<S.N............#..>",
			"<S.13..........13..>",
			"<S.LR..........LR..>",
			"<S.................>",
			"c_______(UU)_______d",
		],
		"spawns": {"zuid": [9, 10, "up"], "boog": [10, 3, "down"]},
		"exits": {
			"U": {"map": "res://scenes/maps/archief_v4_wachtersgang.tscn", "spawn": "boog"},
			"n": {"map": "res://scenes/maps/archief_bibliotheek.tscn", "spawn": "zuid"},
		},
		"chests": [{"id": "kist_4b", "tile": [17, 9], "item": "drankje", "n": 2}],
		"monsters": [
			{"id": "m1", "enemy": "kennis_beest", "group": ["kennis_beest", "mech_wachter"], "tile": [8, 5], "moves": true},
			{"id": "m2", "enemy": "mech_wachter", "group": ["mech_wachter", "papiergeest", "glitchmot"], "tile": [13, 7], "moves": true},
			{"id": "m3", "enemy": "kennis_beest", "group": ["kennis_beest"], "tile": [10, 4], "moves": false, "guard": true},
		],
	},
	# 4C BIBLIOTHEEK = savekamer vlak voor de baas (12x9). Kastmuur, staande kasten, kandelaars,
	# loper naar de grote deur van de Golemhal, opslagboek op de runenring. Geen monsters.
	"archief_bibliotheek": {
		"name": "Vergeten Archieven - Bibliotheek", "floor": 4, "tier": 4,
		"legend": LIBRARY_LEGEND, "floor_tiles": [132, 133],
		"layout": [
			"a----------b",
			"<1254FF1324>",
			"<6709nn6879>",
			"<Zsss[]ssss>",
			"<S...{}....>",
			"<S.R.{}..tT>",
			"<S...{}....>",
			"<S...qQ....>",
			"c___(UU)___d",
		],
		# opslagboek van de bibliotheek (savepunt_bibliotheek.png) op de runenring, zonder verschuiving
		"save": [3, 5], "save_type": "save_bibliotheek", "save_offset": [0, 0],
		"spawns": {"zuid": [5, 7, "up"], "deur": [5, 3, "down"]},
		"exits": {
			"U": {"map": "res://scenes/maps/archief_v4_voorhal.tscn", "spawn": "boog"},
			# de open golemdeur: alleen de onderste rij is beloopbaar (zoals boog 43) = overgang
			"n": {"map": "res://scenes/maps/archief_golemhal.tscn", "spawn": "zuid"},
		},
		"props": [
			{"type": "golemdeur", "tile": [5, 1], "frame": 1},
			{"type": "staande_kast", "tile": [1, 3], "frame": 0},
			{"type": "staande_kast", "tile": [1, 5], "frame": 1, "solid_h": 2},
			{"type": "staande_kast", "tile": [10, 3], "frame": 1},
			{"type": "staande_kast", "tile": [10, 5], "frame": 0, "solid_h": 2},
			{"type": "kandelaar", "tile": [1, 7]},
			{"type": "kandelaar", "tile": [10, 7]},
		],
		# leesbaar boek op de leestafel (A ervoor)
		"signs": [{"tile": [8, 5], "lines": ["Een open boek. Het handschrift is oud maar netjes:",
				"'Sapientia bewaart wat de wereld vergat. Dit is het Eerste Archief.'",
				"'Achter de grote deur slaapt de Wachter van steen. Lees, rust, en ga dan pas verder.'"]},
				{"tile": [5, 2], "lines": ["Achter deze deur bromt iets zwaars. Ben je er klaar voor?"]},
				{"tile": [6, 2], "lines": ["Achter deze deur bromt iets zwaars. Ben je er klaar voor?"]}],
		"monsters": [],
	},
	# 4D GOLEMHAL = de bestaande baaskamer (v0.13 testkamer-platform), zonder opslagboek en zonder
	# andere monsters. De opening onderaan leidt naar de bibliotheek. Baas-stats: game_data.gd
	# (kennis_beest.boss, RPG CODE). Een verslagen Golem blijft weg (bewaker).
	"archief_golemhal": {
		"name": "Vergeten Archieven - Golemhal", "floor": 4, "tier": 4,
		"layout": [
			"a------------------b",
			"<LFKMFFFFFFFFFGFFFR>",
			"<lfkmfffffffffgfffr>",
			"<Zsssss[====]ssssss>",
			"<S.#...[====]...#..>",
			"<S.....[=oO=]......>",
			"<S.....{~^^~}......>",
			"<S.................>",
			"<S.w...........*...>",
			"<S.................>",
			"<S.................>",
			"c_______(UU)_______d",
		],
		"spawns": {"zuid": [9, 10, "up"]},
		"exits": {
			"U": {"map": "res://scenes/maps/archief_bibliotheek.tscn", "spawn": "deur"},
		},
		"monsters": [
			# De Golem: baas, staat stil op het platform (2x2 tiles), kern pulseert langzaam.
			{"id": "golem", "enemy": "kennis_beest", "tile": [9, 3], "moves": false, "boss": true, "guard": true,
				"sprite": "golem", "size": [2, 2], "frame": [32, 32], "fps": 1.2},
		],
	},
}

## v0.14 Volgorde van de kamers (verdieping voor verdieping) met hun scène, voor tests/overzicht.
## De puzzelkamer (3B) staat erbij met room = "" (PuzzleRoom, puzzle_rooms.gd "archief_puzzel").
const ORDER := [
	["archief_ingang", "res://scenes/maps/archief_ingang.tscn"],
	["archief_v1_gang", "res://scenes/maps/archief_v1_gang.tscn"],
	["archief_v2_kastenzaal", "res://scenes/maps/archief_v2_kastenzaal.tscn"],
	["archief_v2_leeszaal", "res://scenes/maps/archief_v2_leeszaal.tscn"],
	["archief_v2_trapzaal", "res://scenes/maps/archief_v2_trapzaal.tscn"],
	["archief_v3_zuilenhal", "res://scenes/maps/archief_v3_zuilenhal.tscn"],
	["", "res://scenes/maps/archief_puzzel.tscn"],
	["archief_v3_gang", "res://scenes/maps/archief_v3_gang.tscn"],
	["archief_v4_wachtersgang", "res://scenes/maps/archief_v4_wachtersgang.tscn"],
	["archief_v4_voorhal", "res://scenes/maps/archief_v4_voorhal.tscn"],
	["archief_bibliotheek", "res://scenes/maps/archief_bibliotheek.tscn"],
	["archief_golemhal", "res://scenes/maps/archief_golemhal.tscn"],
]


## Alle vijand-id's waar een kamer een map-monster voor heeft (voor tests/overzicht).
static func enemy_ids(room_id: String) -> Array:
	var out := []
	for m in room(room_id).get("monsters", []):
		if not out.has(m["enemy"]):
			out.append(m["enemy"])
	return out


## v0.15 Thema-sleutel van een kamer ("theme", anders DEFAULT_THEME; onbekend -> DEFAULT_THEME).
static func theme_of(room: Dictionary) -> String:
	var t := str(room.get("theme", DEFAULT_THEME))
	return t if THEMES.has(t) else DEFAULT_THEME


## v0.15 Gegevens van een thema (tiles, lib_tiles, sprites).
static func theme_data(theme: String) -> Dictionary:
	return THEMES.get(theme, THEMES[DEFAULT_THEME])


## v0.15 Plaatje in het thema (standaard: current_theme). Geen thema / geen vervanging /
## bestand ontbreekt -> het originele pad.
static func themed(path: String, theme := "") -> String:
	var t := theme if theme != "" else current_theme
	if t == "" or not THEMES.has(t):
		return path
	var alt := str(THEMES[t].get("sprites", {}).get(path, ""))
	if alt != "" and ResourceLoader.exists(alt):
		return alt
	return path


## Legenda van een kamer (LEGEND + de eigen "legend" van de kamer).
static func legend_of(room: Dictionary) -> Dictionary:
	var l := LEGEND.duplicate()
	l.merge(room.get("legend", {}), true)
	return l


## Scènepad van een kamer-id ("" = onbekend). v0.17: ook de kamers van het Donker Woud.
static func scene_of(room_id: String) -> String:
	for e in ORDER + woud().ORDER:
		if e[0] == room_id:
			return e[1]
	return ""


## v0.17 De kamers van het Donker Woud (scripts/data/woud_rooms.gd; via load(), geen cyclus).
static func woud() -> Script:
	return load("res://scripts/data/woud_rooms.gd")


## v0.17 Kamerdata van ELKE dungeon: eerst de Archieven (ROOMS), dan het Donker Woud ({} = onbekend).
## Dungeon100 (de Diepe Grot): id "dungeon100_<seed>_<verdieping>" wordt gegenereerd (dungeon100_generator.gd).
static func room(room_id: String) -> Dictionary:
	if ROOMS.has(room_id):
		return ROOMS[room_id]
	if room_id.begins_with("dungeon100_"):
		return load("res://scripts/dungeon/dungeon100_generator.gd").room_for_id(room_id)
	return woud().ROOMS.get(room_id, {})


## v0.17 Massieve tegel in dit thema? (SOLID + "solid_extra" van het thema; "" = current_theme)
static func is_solid(n: int, theme := "") -> bool:
	if n in SOLID:
		return true
	var t := theme if theme != "" else current_theme
	return n in theme_data(t).get("solid_extra", []) if THEMES.has(t) else false


## v0.17 Mag een map-monster hier niet staan? (NO_MONSTER + "no_monster_extra" van het thema)
static func is_no_monster(n: int, theme := "") -> bool:
	if n in NO_MONSTER:
		return true
	var t := theme if theme != "" else current_theme
	return n in theme_data(t).get("no_monster_extra", []) if THEMES.has(t) else false


## v0.17 Eén atlas voor alle nummers (ook >= LIB_BASE)? Zie THEMES "single_atlas".
static func single_atlas(theme := "") -> bool:
	var t := theme if theme != "" else current_theme
	return THEMES.has(t) and bool(THEMES[t].get("single_atlas", false))


## v0.17 Terrein van de tegels van een thema ("archief" = bibliotheek-achtergrond, "woud" = bos).
static func terrain_of(theme: String) -> String:
	return str(theme_data(theme).get("terrain", TERRAIN))


# ---------------------------------------------------------------- v0.16 glitch per kamer
## v0.16 (wens Dennis) GLITCH-EFFECTEN alleen in de Archieven, en sterker naarmate je dichter bij
## de baas komt. Afstand = aantal kamerstappen (via de "exits" hierboven en de entrance/exit van
## de puzzelkamers met "style": "dungeon" in puzzle_rooms.gd) vanaf de baaskamer GLITCH_BOSS_ROOM.
## Sterkte 0..1: kamers tot en met GLITCH_FULL_STEPS stappen van de baas (Golemhal, Bibliotheek,
## Voorhal) = 1.0 (max); daarna lineair omlaag tot GLITCH_MIN in de verste kamer (de ingang).
## Niet in de Archieven (huis, buiten, wereldkaart, tutorial, gevecht, titel) = 0 = geen glitch.
## crt_overlay.gd (autoload Crt) leest dit bij elke scènewissel (goedkoop: één opzoeking).
const GLITCH_BOSS_ROOM := "archief_golemhal"
const GLITCH_FULL_STEPS := 2
## v0.17 ELKE dungeon met een baas krijgt zijn eigen glitch-schaal (per dungeon genormaliseerd, zodat
## de Archieven precies blijven zoals in v0.16): "set" = welke kamers ("archief" = ROOMS + puzzelkamers
## met "style": "dungeon", "woud" = woud_rooms.gd), "boss" = baaskamer, "full" = tot zoveel stappen
## van de baas maximaal. Donker Woud: Woudrand 0.15 -> Wortelpad -> Mistpoel -> Sporenkring/Open plek 1.0.
const GLITCH_DUNGEONS := [
	{"set": "archief", "boss": GLITCH_BOSS_ROOM, "full": GLITCH_FULL_STEPS},
	{"set": "woud", "boss": "woud_open_plek", "full": 1},
]
const GLITCH_MIN := 0.15
const MAPS_DIR := "res://scenes/maps/"
static var _glitch_cache := {}
static var _glitch_scale := {}     # scènepad -> [full, verste afstand] van zijn dungeon


## Scènepad van een kamer of puzzelkamer-id.
static func room_scene(room_id: String) -> String:
	var s := scene_of(room_id)
	return s if s != "" else MAPS_DIR + room_id + ".tscn"


## Kamergraaf: scènepad -> Array van buur-scènepaden (beide kanten op; alleen kamers van één
## dungeon: dungeon_set "archief" (standaard) of "woud").
static func room_graph(dungeon_set := "archief") -> Dictionary:
	var g := {}
	var archive := {}
	var rooms: Dictionary = ROOMS if dungeon_set == "archief" else woud().ROOMS
	for id in rooms:
		archive[room_scene(id)] = true
	var PR = load("res://scripts/data/puzzle_rooms.gd")
	for id in PR.ROOMS:
		if dungeon_set == "archief" and str(PR.ROOMS[id].get("style", "")) == "dungeon":
			archive[room_scene(id)] = true
	var link := func(a: String, b: String):
		if not archive.has(a) or not archive.has(b) or a == b:
			return
		if not g.has(a):
			g[a] = []
		if not g.has(b):
			g[b] = []
		if not g[a].has(b):
			g[a].append(b)
		if not g[b].has(a):
			g[b].append(a)
	for id in rooms:
		for k in rooms[id].get("exits", {}):
			link.call(room_scene(id), str(rooms[id]["exits"][k].get("map", "")))
	for id in PR.ROOMS:
		var r: Dictionary = PR.ROOMS[id]
		if dungeon_set != "archief" or str(r.get("style", "")) != "dungeon":
			continue
		for k in ["entrance", "exit"]:
			if r.get(k) is Dictionary:
				link.call(room_scene(id), str(r[k].get("map", "")))
	return g


## Afstand (kamerstappen) van elke dungeonkamer tot de baaskamer van zijn dungeon: scènepad -> int.
static func boss_distances() -> Dictionary:
	if not _glitch_cache.is_empty():
		return _glitch_cache
	var all := {}
	for gd in GLITCH_DUNGEONS:
		var g := room_graph(str(gd["set"]))
		var start := room_scene(str(gd["boss"]))
		var dist := {start: 0}
		var queue := [start]
		while not queue.is_empty():
			var cur: String = queue.pop_front()
			for nb in g.get(cur, []):
				if not dist.has(nb):
					dist[nb] = int(dist[cur]) + 1
					queue.append(nb)
		var far := 0
		for v in dist.values():
			far = maxi(far, int(v))
		for p in dist:
			all[p] = dist[p]
			_glitch_scale[p] = [int(gd["full"]), far]
	_glitch_cache = all
	return all


## Kamerstappen tot de baas (-1 = geen dungeonkamer / niet verbonden).
static func boss_distance(scene_path: String) -> int:
	return int(boss_distances().get(scene_path, -1))


## Glitch-sterkte 0..1 van een scène (0 = buiten de dungeons).
static func glitch_intensity(scene_path: String) -> float:
	var d := boss_distance(scene_path)
	if d < 0:
		return 0.0
	var sc: Array = _glitch_scale.get(scene_path, [GLITCH_FULL_STEPS, GLITCH_FULL_STEPS])
	var full := int(sc[0])
	var far := int(sc[1])
	if d <= full or far <= full:
		return 1.0
	var t := float(d - full) / float(far - full)   # 0 dichtbij .. 1 verst
	return lerpf(1.0, GLITCH_MIN, t)
