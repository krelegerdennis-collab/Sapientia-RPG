extends RefCounted
## v0.17 HET DONKER WOUD als DATA (zelfde formaat als scripts/data/dungeon_rooms.gd ROOMS; daar staat
## de uitleg van alle velden). scripts/dungeon/dungeon_room.gd bouwt de kamers; DungeonRooms.room(id)
## zoekt eerst in de Archieven, dan hier. Aparte lijst, zodat de tests/regels van het Eerste Archief
## (verdiepingen, EXP-totaal tot de Golem, thema archief_grijs) ongemoeid blijven.
##
## Thema "donker_woud" (dungeon_rooms.gd THEMES): zelfde TEGELNUMMERS, ander beeld: bladerdak als
## muurtop, boomstammen als muurvoorkant, wortels/varens/paddenstoelen als decor, mist, iets donkerder.
## Tegels van RPG ART (art_woud_v17): assets/tiles/dungeon/woud_tiles.png (256x112; 0-64 = nummering van
## docs/DUNGEON_TILES.txt, 65-111 bostegels, docs/WOUD_TILES.txt). Boomkruinen en mist staan op een
## overlay-laag boven de speler ("trees", "mist", "overlay", zie dungeon_room.gd _build_overlay).
##
## Route: wereldkaart -> 1 Woudrand -> 2 Wortelpad -> 3 Mistpoel -> 4 Sporenkring (opslagstronk)
##        -> 5 Open plek (baas: De Wortelkoning, met Noor in een wortelcocon).
## Monsterniveau: 3 in de eerste twee kamers, 4 daarna (game_data.gd TIERS), voor Dennis ~Lv 10-13.
## Extra velden (v0.17, ook bruikbaar in andere dungeons):
##   "objects" [{"name", "tile", "texture", "tiles": [w, h], "hframes", "event", "show_if", "frame_rules",
##              "glow_if", "glow_color"}]          verhaal-objecten (scenes/story_object.tscn)
##   "npcs"    [{"name", "npc_name", "tile", "sheet", "facing", "event", "show_if", "lines"}]  (scenes/npc.tscn)

const THEME := "donker_woud"
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const M := "res://scenes/maps/"
## v0.17 extra tekens voor ALLE woudkamers (tegels van RPG ART, docs/WOUD_TILES.txt):
##   P gloeiende paddenstoelen (85)  j wortels over de vloer (86)  J wortels verticaal (103)
##   D donkere bladeren B (107)      C glitch-vloer B (102)        i losse gloeiende paddenstoel (111)
##   I wortelwand (87, massief)      Y kuilrand (14)               V donkere kuil (13)
const WOUD_LEGEND := {"P": 85, "j": 86, "J": 103, "D": 107, "C": 102, "i": 111, "I": 87, "Y": 14, "V": 13}

const ROOMS := {
	# 1 WOUDRAND (20x12): ingang vanaf de wereldkaart
	"woud_rand": {
		"name": "Dark Wood - Wood's Edge", "floor": 1, "tier": 3, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a------------------b",
			"<LFFMFFFFFAFFFGFFFR>",
			"<lffmfffffnfffgfffr>",
			"<Zsssssssssssssssss>",
			"<S..x....#.....P...>",
			"<S.....,.......B...>",
			"<S..N.......w......>",
			"<S...D.....,....N..>",
			"<S.p.....*.........>",
			"<S......B..jjj.x...>",
			"<S.................>",
			"c_______(EE)_______d",
		],
		"spawns": {"ingang": [9, 10, "up"], "boog": [10, 3, "down"]},
		"exits": {
			"E": {"map": WORLD, "spawn": "van_woud"},
			"n": {"map": M + "woud_pad.tscn", "spawn": "zuid"},
		},
		"books": [{"type": "hp", "tile": [2, 3]}],
		"chests": [{"id": "kist_w1", "tile": [17, 9], "item": "drankje", "n": 2}],
		"trees": [[5, 5, "A"], [13, 8, "B"]],
		"mist": [[10, 6, 5]],
		"overlay": [[16, 4, 108]],
		"monsters": [
			{"id": "m1", "enemy": "wortelkruiper", "group": ["wortelkruiper"], "tile": [13, 5], "moves": true},
			{"id": "m2", "enemy": "mistuil", "group": ["mistuil"], "tile": [5, 7], "moves": true},
			{"id": "m3", "enemy": "sporenzwam", "group": ["sporenzwam"], "tile": [11, 9], "moves": true},
		],
	},
	# 2 WORTELPAD (32x12, scrolt horizontaal)
	"woud_pad": {
		"name": "Dark Wood - Root Path", "floor": 1, "tier": 3, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a------------------------------b",
			"<LFFFFFFMFFFFFKFFFFFFFGFFFFFFAR>",
			"<lffffffmfffffkfffffffgffffffnr>",
			"<Zsssssss13ssssssssss13ssssssss>",
			"<S.......LR..,.......LR...x....>",
			"<S..w..........B.....P.....N...>",
			"<S.....13.........,..13........>",
			"<S.p...LR....N.......LR....,...>",
			"<S..jjjj......x.......DD.......>",
			"<S..N.....13.........*.....13..>",
			"<S........LR...............LR..>",
			"c_(UU)_________________________d",
		],
		"spawns": {"zuid": [3, 10, "up"], "boog": [29, 3, "down"]},
		"exits": {
			"U": {"map": M + "woud_rand.tscn", "spawn": "boog"},
			"n": {"map": M + "woud_mistpoel.tscn", "spawn": "zuid"},
		},
		"chests": [{"id": "kist_w2", "tile": [30, 8], "item": "toverwater", "n": 2},
			{"id": "kist_w4", "tile": [30, 4], "item": "leeg_boek", "n": 1}],   # v0.17 Codex
		"trees": [[16, 8, "B"], [25, 9, "A"]],
		"mist": [[3, 5, 6], [19, 4, 5]],
		"overlay": [[12, 9, 108], [28, 6, 108], [8, 3, 84]],
		"monsters": [
			{"id": "m1", "enemy": "wortelkruiper", "group": ["wortelkruiper", "wortelkruiper"], "tile": [5, 4], "moves": true},
			{"id": "m2", "enemy": "mistuil", "group": ["mistuil", "wortelkruiper"], "tile": [12, 6], "moves": true},
			{"id": "m3", "enemy": "sporenzwam", "group": ["sporenzwam", "mistuil"], "tile": [18, 9], "moves": true},
			{"id": "m4", "enemy": "wortelkruiper", "group": ["wortelkruiper", "sporenzwam"], "tile": [24, 6], "moves": true},
			{"id": "m5", "enemy": "mistuil", "group": ["mistuil", "mistuil"], "tile": [27, 4], "moves": true},
		],
	},
	# 3 MISTPOEL (20x16, scrolt verticaal): donkere poel in het midden
	"woud_mistpoel": {
		"name": "Dark Wood - Mist Pool", "floor": 2, "tier": 4, "theme": THEME, "legend": WOUD_LEGEND,
				"layout": [
			"a------------------b",
			"<LFFFFFFFFAMFFFKFFR>",
			"<lffffffffnmfffkffr>",
			"<Zsssssssssssssssss>",
			"<S..13........,....>",
			"<S..LR....w.....N..>",
			"<S.................>",
			"<S...YYYYYY....x.i.>",
			"<S...VVVVVV........>",
			"<S.,.VVVVVV..13....>",
			"<S...VVVVVV..LR....>",
			"<S.................>",
			"<S..N.....p....B.P.>",
			"<S.................>",
			"<S...jjjx.....,..C.>",
			"c_______(UU)_______d",
		],
		"spawns": {"zuid": [9, 14, "up"], "boog": [10, 3, "down"]},
		"exits": {
			"U": {"map": M + "woud_pad.tscn", "spawn": "boog"},
			"n": {"map": M + "woud_sporenkring.tscn", "spawn": "zuid"},
		},
		"chests": [{"id": "kist_w3", "tile": [17, 13], "item": "ijzeren_helm", "n": 1}],
		"signs": [{"tile": [7, 6], "lines": ["The water is black and still. A soft hum hangs in the mist,", "as if the woods themselves are breathing... in zeros and ones."]}],
		"trees": [[2, 8, "A"], [15, 11, "B"]],
		"mist": [[4, 7, 8], [2, 11, 7], [10, 13, 6], [11, 4, 5]],
		"overlay": [[16, 6, 84], [6, 9, 108], [12, 12, 108], [3, 5, 108]],
		"monsters": [
			{"id": "m1", "enemy": "mistuil", "group": ["mistuil", "mistuil"], "tile": [9, 4], "moves": true},
			{"id": "m2", "enemy": "sporenzwam", "group": ["sporenzwam", "sporenzwam"], "tile": [15, 8], "moves": true},
			{"id": "m3", "enemy": "wortelkruiper", "group": ["wortelkruiper", "mistuil", "wortelkruiper"], "tile": [8, 12], "moves": true},
			{"id": "m4", "enemy": "wortelkruiper", "group": ["wortelkruiper", "sporenzwam"], "tile": [3, 13], "moves": true},
		],
	},
	# 4 SPORENKRING (20x12): opslagstronk vlak voor de baas, een bewaker voor de doorgang
	"woud_sporenkring": {
		"name": "Dark Wood - Spore Ring", "floor": 2, "tier": 4, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a------------------b",
			"<LFFGFFMFFAFFFFFFFR>",
			"<lffgffmffnfffffffr>",
			"<Zsssssssssssssssss>",
			"<S.P...........N...>",
			"<S.@.....X.........>",
			"<S.....,.....,.....>",
			"<S.N.......X.....,.>",
			"<S...C.....,.....i.>",
			"<S.,..B..jjj....N..>",
			"<S.................>",
			"c_______(UU)_______d",
		],
		"save": [3, 5],
		"spawns": {"zuid": [9, 10, "up"], "boog": [10, 3, "down"]},
		"exits": {
			"U": {"map": M + "woud_mistpoel.tscn", "spawn": "boog"},
			"n": {"map": M + "woud_open_plek.tscn", "spawn": "zuid"},
		},
		"chests": [{"id": "kist_w5", "tile": [17, 4], "item": "leeg_boek", "n": 1}],   # v0.17 Codex
		"signs": [{"tile": [15, 4], "lines": ["Something whispers between the trunks. 'Noor...' It sounds like her own voice."]}],
		"trees": [[13, 8, "A"], [5, 7, "B"]],
		"mist": [[7, 9, 6]],
		"overlay": [[8, 4, 108], [16, 6, 108], [3, 9, 108], [11, 6, 108], [15, 3, 84]],
		"monsters": [
			{"id": "m1", "enemy": "sporenzwam", "group": ["sporenzwam", "sporenzwam", "mistuil"], "tile": [9, 7], "moves": true},
			{"id": "m2", "enemy": "wortelkruiper", "group": ["wortelkruiper", "wortelkruiper", "sporenzwam"], "tile": [10, 4], "moves": false, "guard": true},
			{"id": "m3", "enemy": "mistuil", "group": ["mistuil", "wortelkruiper"], "tile": [15, 8], "moves": true},
		],
	},
	# 5 OPEN PLEK (20x12): de Wortelkoning op de wortelheuvel; Noor hangt in een cocon tussen de stammen
	"woud_open_plek": {
		"name": "Dark Wood - Clearing", "floor": 3, "tier": 4, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a------------------b",
			"<LFKMFFFFFFFFFGFFFR>",
			"<lfkmfffffffffgfffr>",
			"<Zsssss[====]ssssss>",
			"<S.N...[====]...N..>",
			"<S.....[=oO=]......>",
			"<S.....{~^^~}......>",
			"<S.................>",
			"<S.P....C.....C*...>",
			"<S..x..jjj....P....>",
			"<S.................>",
			"c_______(UU)_______d",
		],
		"checkpoint": false,      # v0.19 baaskamer: game over = terug in de Sporenkring
		"spawns": {"zuid": [9, 10, "up"]},
		"exits": {
			"U": {"map": M + "woud_sporenkring.tscn", "spawn": "boog"},
		},
		"trees": [[2, 8, "B"], [16, 9, "A"]],
		"mist": [[3, 10, 5], [12, 10, 5]],
		"overlay": [[4, 4, 108], [14, 4, 108], [6, 7, 108], [13, 8, 108], [8, 9, 108], [11, 2, 108], [3, 6, 84]],
		"objects": [
			# Noor in de wortelcocon (RPG ART, 32x48, anker midden-onder): staat op de wortelheuvel achter
			# de baas, ademt (puls 2 frames) tot ze vrij is; daarna de lege, verdorde cocon
			{"name": "Cocon", "tile": [9, 3], "tiles": [2, 1], "texture": "res://assets/sprites/woud/noor_cocon.png",
				"loop_texture": "res://assets/sprites/woud/noor_cocon_puls.png", "loop_frames": 2, "loop_time": 0.5,
				"loop_if": {"not_flags": ["noor_gered"]},
				"event": "cocon", "show_if": {"not_flags": ["noor_gered"]},
				"glow_if": {"not_flags": ["noor_gered"]}, "glow_color": "ff3ad0"},
			{"name": "CoconOpen", "tile": [9, 3], "tiles": [2, 1], "texture": "res://assets/sprites/woud/noor_cocon_open.png",
				"event": "cocon", "show_if": {"flags": ["noor_gered"]}},
		],
		"npcs": [
			{"name": "Noor", "npc_name": "Noor", "tile": [9, 4], "sheet": "res://assets/sprites/noor_dorp.png",
				"facing": "down", "event": "noor_woud", "show_if": {"flags": ["noor_gered"], "not_flags": ["noor_lid"]}},
		],
		"monsters": [
			{"id": "baas", "enemy": "wortelkoning", "tile": [9, 4], "moves": false, "boss": true, "guard": true,
				"sprite": "wortelkoning", "size": [2, 2], "frame": [32, 32], "fps": 1.5},
		],
	},
}

## Volgorde (ingang -> baas) met scènes, voor tests/overzicht.
const ORDER := [
	["woud_rand", M + "woud_rand.tscn"],
	["woud_pad", M + "woud_pad.tscn"],
	["woud_mistpoel", M + "woud_mistpoel.tscn"],
	["woud_sporenkring", M + "woud_sporenkring.tscn"],
	["woud_open_plek", M + "woud_open_plek.tscn"],
]
const BOSS_ROOM := "woud_open_plek"
