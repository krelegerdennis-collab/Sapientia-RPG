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
	# 1 WOUDRAND (28x17, v1.4x; was 20x12): ingang vanaf de wereldkaart
	"woud_rand": {
		"name": "Dark Wood - Wood's Edge", "floor": 1, "tier": 3, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a--------------------------b",
			"<LFFFMFFFFFFFFAFFFFGFFFFFFR>",
			"<lfffmffffffffnffffgffffffr>",
			"<Zsssssssssssssssssssssssss>",
			"<S...x....#..........P.....>",
			"<S.........................>",
			"<S........,..........B.....>",
			"<S...N..........w..........>",
			"<S.........................>",
			"<S.....D.......,.......N...>",
			"<S.........................>",
			"<S..p........*.............>",
			"<S.........................>",
			"<S..........B..jjjj..x.....>",
			"<S.........................>",
			"<S.........................>",
			"c___________(EE)___________d",
		],
		"path": {"width": 2, "lines": [[[13, 15], [13, 3]]]},   # v0.24 bospad ingang -> uitgangen
		"spawns": {"ingang": [13, 15, "up"], "boog": [14, 3, "down"]},
		"exits": {
			"E": {"map": WORLD, "spawn": "van_woud"},
			"n": {"map": M + "woud_pad.tscn", "spawn": "zuid"},
		},
		"books": [{"type": "hp", "tile": [2, 3]}],
		"chests": [{"id": "kist_w1", "tile": [24, 13], "item": "drankje", "n": 2}],
		"trees": [[7, 6, "A"], [18, 11, "B"]],
		"mist": [[14, 7, 7]],
		"overlay": [[23, 4, 108]],
		"monsters": [
			{"id": "m1", "enemy": "wortelkruiper", "group": ["wortelkruiper"], "tile": [18, 6], "moves": true},
			{"id": "m2", "enemy": "mistuil", "group": ["mistuil"], "tile": [7, 9], "moves": true},
			{"id": "m3", "enemy": "sporenzwam", "group": ["sporenzwam"], "tile": [15, 13], "moves": true},
		],
	},
	# 2 WORTELPAD (45x17, was 32x12; scrolt horizontaal)
	"woud_pad": {
		"name": "Dark Wood - Root Path", "floor": 1, "tier": 3, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a-------------------------------------------b",
			"<LFFFFFFFMFFFFFFFFKFFFFFFFFFFFFGFFFFFFFFFFAR>",
			"<lfffffffmffffffffkffffffffffffgffffffffffnr>",
			"<Zssssssss13ssssssssssssssssss13ssssssssssss>",
			"<S........LR....,.............LR......x.....>",
			"<S..........................................>",
			"<S..w..............B..........P........N....>",
			"<S..........................................>",
			"<S......13...............,....13............>",
			"<S.p....LR......N.............LR.......,....>",
			"<S..........................................>",
			"<S................x.........................>",
			"<S..........................................>",
			"<S.....N...13.................*........13...>",
			"<S..........jjjjjj...............DD.........>",
			"<S.........LR..........................LR...>",
			"c_(UU)______________________________________d",
		],
		"path": {"width": 3, "lines": [[[4, 15], [4, 11], [41, 11], [41, 3]]]},   # v0.24 bospad ingang -> uitgangen
		"spawns": {"zuid": [3, 15, "up"], "boog": [42, 3, "down"]},
		"exits": {
			"U": {"map": M + "woud_rand.tscn", "spawn": "boog"},
			"n": {"map": M + "woud_mistpoel.tscn", "spawn": "zuid"},
		},
		"chests": [{"id": "kist_w2", "tile": [43, 11], "item": "toverwater", "n": 2},
			{"id": "kist_w4", "tile": [43, 4], "item": "leeg_boek", "n": 1}],   # v0.17 Codex
		"trees": [[21, 15, "B"], [36, 13, "A"]],
		"mist": [[3, 6, 7], [26, 4, 8]],
		"overlay": [[14, 13, 108], [40, 8, 108], [9, 3, 84]],
		"monsters": [
			{"id": "m1", "enemy": "wortelkruiper", "group": ["wortelkruiper", "wortelkruiper"], "tile": [5, 4], "moves": true},
			{"id": "m2", "enemy": "mistuil", "group": ["mistuil", "wortelkruiper"], "tile": [14, 8], "moves": true},
			{"id": "m3", "enemy": "sporenzwam", "group": ["sporenzwam", "mistuil"], "tile": [25, 13], "moves": true},
			{"id": "m4", "enemy": "wortelkruiper", "group": ["wortelkruiper", "sporenzwam"], "tile": [34, 8], "moves": true},
			{"id": "m5", "enemy": "mistuil", "group": ["mistuil", "mistuil"], "tile": [39, 4], "moves": true},
		],
	},
	# 3 MISTPOEL (28x22, was 20x16; scrolt verticaal): donkere poel in het midden
	"woud_mistpoel": {
		"name": "Dark Wood - Mist Pool", "floor": 2, "tier": 4, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a--------------------------b",
			"<LFFFFFFFFFFFFAMFFFFFKFFFFR>",
			"<lffffffffffffnmfffffkffffr>",
			"<Zsssssssssssssssssssssssss>",
			"<S....13...........,.......>",
			"<S....LR......w.......N....>",
			"<S.........................>",
			"<S.........................>",
			"<S.....YYYYYYYY......x..i..>",
			"<S.....VVVVVVVV............>",
			"<S.....VVVVVVVV............>",
			"<S..,..VVVVVVVV...13.......>",
			"<S.....VVVVVVVV...LR.......>",
			"<S.....VVVVVVVV............>",
			"<S.........................>",
			"<S.........................>",
			"<S....N.......p......B..P..>",
			"<S.........................>",
			"<S.........................>",
			"<S.........................>",
			"<S.....jjjjjx......,....C..>",
			"c___________(UU)___________d",
		],
		"path": {"width": 2, "lines": [[[13, 20], [13, 15], [16, 15], [16, 6], [13, 6], [13, 3]]]},   # v0.24 bospad ingang -> uitgangen
		"spawns": {"zuid": [13, 20, "up"], "boog": [14, 3, "down"]},
		"exits": {
			"U": {"map": M + "woud_pad.tscn", "spawn": "boog"},
			"n": {"map": M + "woud_sporenkring.tscn", "spawn": "zuid"},
		},
		"chests": [{"id": "kist_w3", "tile": [24, 17], "item": "ijzeren_helm", "n": 1}],
		"signs": [{"tile": [10, 7], "lines": ["The water is black and still. A soft hum hangs in the mist,", "as if the woods themselves are breathing... in zeros and ones."]}],
		"trees": [[2, 9, "A"], [21, 14, "B"]],
		"mist": [[6, 8, 10], [2, 14, 11], [14, 17, 8], [15, 4, 7]],
		"overlay": [[22, 7, 84], [8, 11, 108], [16, 16, 108], [4, 5, 108]],
		"monsters": [
			{"id": "m1", "enemy": "mistuil", "group": ["mistuil", "mistuil"], "tile": [13, 4], "moves": true},
			{"id": "m2", "enemy": "sporenzwam", "group": ["sporenzwam", "sporenzwam"], "tile": [21, 9], "moves": true},
			{"id": "m3", "enemy": "wortelkruiper", "group": ["wortelkruiper", "mistuil", "wortelkruiper"], "tile": [9, 17], "moves": true},
			{"id": "m4", "enemy": "wortelkruiper", "group": ["wortelkruiper", "sporenzwam"], "tile": [4, 17], "moves": true},
		],
	},
	# 4 SPORENKRING (28x17, was 20x12): opslagstronk vlak voor de baas, een bewaker voor de doorgang
	"woud_sporenkring": {
		"name": "Dark Wood - Spore Ring", "floor": 2, "tier": 4, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a--------------------------b",
			"<LFFFGFFFFMFFFAFFFFFFFFFFFR>",
			"<lfffgffffmfffnfffffffffffr>",
			"<Zsssssssssssssssssssssssss>",
			"<S..P................N.....>",
			"<S.........................>",
			"<S..@........X.............>",
			"<S........,......,.........>",
			"<S.........................>",
			"<S..N..........X........,..>",
			"<S....C........,........i..>",
			"<S.........................>",
			"<S..,...B........jjj...N...>",
			"<S.........................>",
			"<S.........................>",
			"<S.........................>",
			"c___________(UU)___________d",
		],
		"save": [4, 6],
		"path": {"width": 2, "lines": [[[13, 15], [13, 3]]]},   # v0.24 bospad ingang -> uitgangen
		"spawns": {"zuid": [13, 15, "up"], "boog": [14, 3, "down"]},
		"exits": {
			"U": {"map": M + "woud_mistpoel.tscn", "spawn": "boog"},
			"n": {"map": M + "woud_open_plek.tscn", "spawn": "zuid"},
		},
		"chests": [{"id": "kist_w5", "tile": [24, 4], "item": "leeg_boek", "n": 1}],   # v0.17 Codex
		"signs": [{"tile": [21, 4], "lines": ["Something whispers between the trunks. 'Vesper...' It sounds like her own voice."]}],
		"trees": [[17, 10, "A"], [6, 9, "B"]],
		"mist": [[10, 12, 7]],
		"overlay": [[12, 4, 108], [23, 7, 108], [4, 12, 108], [15, 7, 108], [21, 3, 84]],
		"monsters": [
			{"id": "m1", "enemy": "sporenzwam", "group": ["sporenzwam", "sporenzwam", "mistuil"], "tile": [9, 9], "moves": true},
			{"id": "m2", "enemy": "wortelkruiper", "group": ["wortelkruiper", "wortelkruiper", "sporenzwam"], "tile": [14, 4], "moves": false, "guard": true},
			{"id": "m3", "enemy": "mistuil", "group": ["mistuil", "wortelkruiper"], "tile": [21, 10], "moves": true},
		],
	},
	# 5 OPEN PLEK (28x17, was 20x12): de Wortelkoning op de wortelheuvel; Noor hangt in een cocon tussen de stammen
	"woud_open_plek": {
		"name": "Dark Wood - Clearing", "floor": 3, "tier": 4, "theme": THEME, "legend": WOUD_LEGEND,
		"layout": [
			"a--------------------------b",
			"<LFFKFMFFFFFFFFFFFFGFFFFFFR>",
			"<lffkfmffffffffffffgffffffr>",
			"<Zsssssssss[====]ssssssssss>",
			"<S..N......[====].....N....>",
			"<S.........[====]..........>",
			"<S.........[=oO=]..........>",
			"<S.........{~^^~}..........>",
			"<S.........................>",
			"<S.........................>",
			"<S..P.......C......C.*.....>",
			"<S.........................>",
			"<S....xjjj.........P.......>",
			"<S.........................>",
			"<S.........................>",
			"<S.........................>",
			"c___________(UU)___________d",
		],
		"checkpoint": false,      # v0.19 baaskamer: game over = terug in de Sporenkring
		"path": {"width": 2, "lines": [[[13, 15], [13, 8]]], "join": "^"},   # join: pad sluit naadloos aan op de heuveltrap (rij 7)   # v0.24 bospad ingang -> uitgangen
		"spawns": {"zuid": [13, 15, "up"]},
		"exits": {
			"U": {"map": M + "woud_sporenkring.tscn", "spawn": "boog"},
		},
		"trees": [[2, 10, "B"], [22, 12, "A"]],
		"mist": [[4, 15, 8], [16, 15, 8]],
		"overlay": [[6, 4, 108], [19, 4, 108], [9, 8, 108], [17, 10, 108], [12, 12, 108], [15, 2, 108], [4, 7, 84]],
		"objects": [
			# Noor in de wortelcocon (RPG ART, 32x48, anker midden-onder): staat op de wortelheuvel achter
			# de baas, ademt (puls 2 frames) tot ze vrij is; daarna de lege, verdorde cocon
			{"name": "Cocon", "tile": [13, 3], "tiles": [2, 1], "texture": "res://assets/sprites/woud/noor_cocon.png",
				"loop_texture": "res://assets/sprites/woud/noor_cocon_puls.png", "loop_frames": 2, "loop_time": 0.5,
				"loop_if": {"not_flags": ["noor_gered"]},
				"event": "cocon", "show_if": {"not_flags": ["noor_gered"]},
				"glow_if": {"not_flags": ["noor_gered"]}, "glow_color": "ff3ad0"},
			{"name": "CoconOpen", "tile": [13, 3], "tiles": [2, 1], "texture": "res://assets/sprites/woud/noor_cocon_open.png",
				"event": "cocon", "show_if": {"flags": ["noor_gered"]}},
		],
		"npcs": [
			{"name": "Vesper", "npc_name": "Vesper", "tile": [13, 4], "sheet": "res://assets/sprites/noor_dorp.png",
				"facing": "down", "event": "noor_woud", "show_if": {"flags": ["noor_gered"], "not_flags": ["noor_lid"]}},
			# Het Zingende Graan: vloer (6,14) direct boven de mistband op y=15 (1.4x; was (4,9)/y=10). Alleen tijdens de opdracht.
			{"name": "Woudgeesten", "npc_name": "Wood Wraith", "tile": [6, 14], "facing": "down",
				"event": "zingend_zaad", "lines": [],
				"show_if": {"flags": ["quest_zingend_graan"], "not_flags": ["zingend_zaad"]}},
		],
		"monsters": [
			{"id": "baas", "enemy": "wortelkoning", "tile": [13, 4], "moves": false, "boss": true, "guard": true,
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
