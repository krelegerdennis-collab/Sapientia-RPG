extends RefCounted
## Verdieping 1 van Het Levende Archief (kas). Zelfde velden als dungeon_rooms.gd ROOMS.
## Aparte lijst, zodat de tellingen van het Eerste Archief (ORDER, gevechten, thema
## archief_grijs) blijven staan. DungeonRooms.room() zoekt hier ná de Archieven.
##
## Wereldkaart-ingang: event naar_leven (Golem verslagen + Vesper in de groep). Verdieping 2-4 in rooms().

const THEME := "kas"
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const M := "res://scenes/maps/"

const ROOMS := {
	# 1 KAS (22x15, was 16x11): entree vanaf de wereldkaart, zichtbare monsters, bord, opslag.
	"leven_ingang": {
		"name": "The Living Archive",
		"floor": 1,
		"tier": 5,
		"archief": "2",
		"theme": THEME,
		"layout": [
			"a--------------------b",
			"<LFFFFMFFFFFGFFFFFFFR>",
			"<lffffmfffffnfffffffr>",
			"<Zsssssssssssssssssss>",
			"<S...................>",
			"<S...................>",
			"<S...................>",
			"<S.......x...........>",
			"<S...................>",
			"<S...................>",
			"<S...................>",
			"<S..@................>",
			"<S...................>",
			"<S...................>",
			"c________(EE)________d",
		],
		"save": [4, 11],
		"spawns": {"ingang": [10, 13, "up"], "boog": [12, 3, "down"]},
		"exits": {
			"E": {"map": WORLD, "spawn": "van_kas"},
			"n": {"map": M + "leven_v1_plaat.tscn", "spawn": "ingang"},
		},
		"signs": [{
			"tile": [16, 6],
			"lines": [
				"A greenhouse. The vines grow across the floor.",
				"Pull the lever. Then the plate grows into a path.",
				"The Old Humanity made the six Archives as a chain.",
				"Each core activates the next. Not an invitation: a distress signal.",
				"Archive 1 sent: Someone is inside. Archive 2 answered first.",
				"Sapientia manipulated that signal. You think you are following. Sapientia is leading you.",
			],
		}],
		# Kaart: bestaande soorten; v0.21: Archief 2-vijanden (CANON besluit 13) vechten mee in de groep.
		"monsters": [
			{"id": "m1", "enemy": "mosslijm", "group": ["mosslijm", "rankje"], "tile": [6, 7], "moves": true},
			{"id": "m2", "enemy": "moskonijn", "group": ["moskonijn", "sporekop"], "tile": [16, 9], "moves": true},
		],
	},
}

const ORDER := [
	["leven_ingang", M + "leven_ingang.tscn"],
]

## Verdieping 2-4: kamers via rooms(). De wereldkaart en de groei-plaat van
## verdieping 1 blijven leven_ingang / leven_v1_plaat.
const SCENES := {
	"archief_2_v1_entree": "res://scenes/maps/archief_2_v1_entree.tscn",
	"archief_2_v1_plaat": "res://scenes/maps/archief_2_v1_plaat.tscn",
	"archief_2_v2_gang": "res://scenes/maps/archief_2_v2_gang.tscn",
	"archief_2_v2_lotte": "res://scenes/maps/archief_2_v2_lotte.tscn",
	"archief_2_v3_ketting": "res://scenes/maps/archief_2_v3_ketting.tscn",
	"archief_2_v3_tegen": "res://scenes/maps/archief_2_v3_tegen.tscn",
	"archief_2_v3_licht": "res://scenes/maps/archief_2_v3_licht.tscn",
	"archief_2_v3_wurger": "res://scenes/maps/archief_2_v3_wurger.tscn",
	"archief_2_v4_hal": "res://scenes/maps/archief_2_v4_hal.tscn",
	"archief_2_v4_genezer": "res://scenes/maps/archief_2_v4_genezer.tscn",
	"archief_2_warper": "res://scenes/maps/archief_2_warper.tscn",
}

const _F := "<S........................>"
const _G := "<S########################>"
const _B := "<S###########..###########>"
const _T := "<S...#####################>"
const _TOP := "a-------------------------b"
const _WU := "<LFFFFMFFGFFFAFFFFFFFFFFFR>"
const _WL := "<lffffmffgfffnfffffffffffr>"
const _BOT := "c___________(EE)__________d"
const _SH := "<Zssssssssssssssssssssssss>"


static func _basis(naam: String, verdieping: int, tier: int) -> Dictionary:
	return {
		"name": naam, "floor": verdieping, "tier": tier, "archief": "2", "theme": "kas",
		"layout": [_TOP, _WU, _WL, _SH, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"spawns": {"zuid": [13, 15, "up"], "noord": [13, 3, "down"], "ingang": [13, 15, "up"]},
	}


static func _met(basis: Dictionary, extra: Dictionary) -> Dictionary:
	var out := basis.duplicate(true)
	for k in extra:
		out[k] = extra[k]
	return out


static func rooms() -> Dictionary:
	var entree := _met(_basis("The Living Archive", 1, 5), {
		"layout": [_TOP, _WU, _WL, _SH, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"save": [4, 11],
		"exits": {
			"E": {"map": "res://scenes/maps/berggrot_uitmond.tscn", "spawn": "boog"},
			"n": {"map": SCENES["archief_2_v1_plaat"], "spawn": "zuid"},
		},
		"signs": [{"tile": [6, 6], "lines": [
			"The greenhouse breathes. Everything here keeps growing, even when you stand still.",
		]}],
		"monsters": [
			{"id": "m1", "enemy": "rankje", "group": ["rankje", "rankje"], "tile": [8, 7], "moves": true},
			{"id": "m2", "enemy": "doornige_loper", "group": ["doornige_loper", "wortelkruiper"], "tile": [18, 9], "moves": true},
		],
	})
	var plaat := _met(_basis("Growth Plate", 1, 5), {
		"layout": [_TOP, _WU, _WL, _F, _G, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v1_entree"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v2_gang"], "spawn": "zuid"},
		},
		"signs": [{"tile": [6, 7], "lines": [
			"A growth plate. Step on it.",
			"It grows into a path.",
		]}],
		"platen": [{"id": "p1", "soort": "groei", "tile": [13, 7], "start": 0}],
		"bruggen": [{"plaat": "p1", "tiles": [[12, 4], [13, 4], [14, 4]]}],
	})
	var gang := _met(_basis("Greenhouse Passage", 2, 5), {
		"layout": [_TOP, _WU, _WL, _SH, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": "res://scenes/maps/leven_v1_plaat.tscn", "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v2_lotte"], "spawn": "zuid"},
		},
		"monsters": [
			{"id": "m1", "enemy": "doornige_loper", "group": ["doornige_loper", "rankje"], "tile": [9, 7], "moves": true},
			{"id": "m2", "enemy": "sporekop", "group": ["sporekop", "sporenzwam"], "tile": [17, 9], "moves": true},
		],
	})
	var lotte := _met(_basis("Seren's Room", 2, 5), {
		"layout": [_TOP, _WU, _WL, _F, _F, _F, _B, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"checkpoint": false,
		"exits": {
			"E": {"map": SCENES["archief_2_v2_gang"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v3_ketting"], "spawn": "zuid"},
		},
		# poort 2 breed: (14,6) dicht tot de bewaker verslagen is (was poort (9,5) 1 breed)
		"blokkades": {"tot_vlag": "bewaker:archief_2_v2_lotte/lotte", "tiles": [[14, 6]]},
		"monsters": [{
			"id": "lotte", "enemy": "lotte_glitch", "group": ["lotte_glitch"],
			"tile": [13, 6], "moves": false, "boss": true, "guard": true,
		}],
	})
	var ketting := _met(_basis("Chain Plates", 3, 6), {
		"layout": [_TOP, _WU, _WL, _F, _G, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v2_lotte"], "spawn": "noord"},
			"n": {"map": "res://scenes/maps/leven_v3_combi.tscn", "spawn": "ingang"},
		},
		"signs": [{"tile": [4, 9], "lines": [
			"Chain plates. One activates the next.",
			"The last one only grows when the one before wakes it.",
		]}],
		"platen": [
			{"id": "k0", "soort": "ketting", "index": 0, "tile": [6, 7], "start": 0},
			{"id": "k1", "soort": "ketting", "index": 1, "tile": [12, 7], "start": 0},
			{"id": "k2", "soort": "ketting", "index": 2, "tile": [16, 7], "start": 0},
		],
		"bruggen": [{"plaat": "k2", "tiles": [[12, 4], [13, 4], [14, 4]]}],
		"monsters": [
			{"id": "m1", "enemy": "bloeiende_schrik", "group": ["bloeiende_schrik", "sporekop"], "tile": [19, 10], "moves": true},
		],
	})
	var tegen := _met(_basis("Counter Plates", 3, 6), {
		"layout": [_TOP, _WU, _WL, _F, _T, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v3_ketting"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v3_licht"], "spawn": "zuid"},
		},
		"signs": [{"tile": [4, 9], "lines": [
			"Counter plates shrink when you touch them.",
			"Avoid them, or take the long way on the left.",
		]}],
		"platen": [{"id": "t1", "soort": "tegen", "tile": [18, 7], "start": 2}],
		"bruggen": [{"plaat": "t1", "tiles": [[16, 4], [17, 4], [18, 4]]}],
	})
	var licht := _met(_basis("Light Plates", 3, 6), {
		"layout": [_TOP, _WU, _WL, _F, _G, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v3_tegen"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v3_wurger"], "spawn": "zuid"},
		},
		"signs": [{"tile": [6, 9], "lines": [
			"This plate only grows in Seren's light.",
			"Stand in front of it and press A.",
		]}],
		"platen": [{"id": "l1", "soort": "licht", "tile": [13, 7], "start": 0}],
		"bruggen": [{"plaat": "l1", "tiles": [[12, 4], [13, 4], [14, 4]]}],
	})
	var wurger := _met(_basis("The Strangler", 3, 6), {
		"layout": [_TOP, _WU, _WL, _F, _F, _F, _B, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"checkpoint": false,
		"exits": {
			"E": {"map": SCENES["archief_2_v3_licht"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v4_hal"], "spawn": "zuid"},
		},
		"signs": [{"tile": [6, 10], "lines": [
			"Vines block the greenhouse. Ice and a sword cut through them.",
		]}],
		# poort 2 breed: (14,6) dicht tot de bewaker verslagen is (was poort (9,5) 1 breed)
		"blokkades": {"tot_vlag": "bewaker:archief_2_v3_wurger/wurger", "tiles": [[14, 6]]},
		"monsters": [{
			"id": "wurger", "enemy": "wurger", "group": ["wurger"],
			"tile": [13, 6], "moves": false, "boss": true, "mini": true, "guard": true,
		}],
	})
	var hal := _met(_basis("Hall of the Mender", 4, 6), {
		"layout": [_TOP, _WU, _WL, _SH, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v3_wurger"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v4_genezer"], "spawn": "zuid"},
		},
		"signs": [{"tile": [6, 7], "lines": [
			"Further on stands something that heals by taking.",
		]}],
		"monsters": [
			{"id": "m1", "enemy": "wortelgeest", "group": ["wortelgeest", "bloeiende_schrik"], "tile": [17, 9], "moves": true},
		],
	})
	var genezer := _met(_basis("The Mender", 4, 6), {
		"layout": [_TOP, _WU, _WL, _F, _F, _B, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"spawns": {"zuid": [13, 13, "up"], "noord": [13, 3, "down"], "ingang": [13, 13, "up"]},
		"checkpoint": false,
		"exits": {
			"E": {"map": SCENES["archief_2_v4_hal"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_warper"], "spawn": "ingang"},
		},
		"monsters": [{
			"id": "genezer", "enemy": "genezer", "group": ["genezer"],
			"tile": [13, 5], "moves": false, "boss": true, "guard": true,
			# v0.23 originele Genezer, grote kaartversie (RPG ART, 2 frames van 32x32) op het zegel 62/63
			"sprite": "genezer_groot", "size": [2, 1], "frame": [32, 32], "fps": 1.2,
		}],
		# v0.23 (Dennis): het podium heeft geen hekje meer; rij 5 blijft dicht tot De Genezer verslagen is
		"blokkades": {"tot_vlag": "bewaker:archief_2_v4_genezer/genezer",
			"tiles": [[1, 5], [2, 5], [3, 5], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [9, 5], [10, 5], [11, 5], [12, 5], [15, 5], [16, 5], [17, 5], [18, 5], [19, 5], [20, 5], [21, 5], [22, 5], [23, 5], [24, 5], [25, 5]]},
	})
	var warper := _met(_basis("World Warper", 4, 0), {
		"layout": [_TOP, _WU, _WL, _SH, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"theme": "warper_paars",
		"save": [4, 11],
		"exits": {
			"E": {"map": SCENES["archief_2_v4_genezer"], "spawn": "noord"},
		},
		# de boog (n) in de noordmuur is hier alleen beeld: geen uitgang, dus geen doel nodig
		"decor_uitgangen": ["n"],
		"warp": [13, 7],
		"signs": [{"tile": [8, 6], "lines": [
			"ECHO operates the hub. Step onto the path and choose.",
		]}],
		"sfeer": [
			{"name": "Echo", "texture": "res://assets/sprites/archief2/echo_groen.png", "tile": [6, 7], "scale": 1.0},
			{"name": "Warper", "texture": "res://assets/sprites/archief2/world_warper_groen.png", "tile": [18, 4], "scale": 0.25},
			{"name": "Sapientia", "texture": "res://assets/sprites/archief2/sapientia_glitch.png", "tile": [19, 9], "scale": 0.5},
		],
	})
	return {
		"archief_2_v1_entree": entree,
		"archief_2_v1_plaat": plaat,
		"archief_2_v2_gang": gang,
		"archief_2_v2_lotte": lotte,
		"archief_2_v3_ketting": ketting,
		"archief_2_v3_tegen": tegen,
		"archief_2_v3_licht": licht,
		"archief_2_v3_wurger": wurger,
		"archief_2_v4_hal": hal,
		"archief_2_v4_genezer": genezer,
		"archief_2_warper": warper,
	}
