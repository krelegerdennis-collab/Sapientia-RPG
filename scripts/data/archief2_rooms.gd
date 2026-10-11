extends RefCounted
## Kamers van Het Levende Archief. Niet in DungeonRooms.ROOMS: DungeonRooms.room zoekt
## ze hier, zodat de glitch-grafiek en de tests van Archief 1 gelijk blijven.
## Thema levend_kas = placeholder-tegels (groen, vochtig). BGM blijft vergeten_archieven
## tot er kas-muziek is.

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

const _F := "<S.................>"
const _G := "<S#################>"
const _B := "<S#######.#########>"
const _T := "<S...##############>"
const _TOP := "a------------------b"
const _WU := "<LFFMFGFFAFFFFFFFFR>"
const _WL := "<lffmfgffnffffffffr>"
const _BOT := "c_______(EE)_______d"
const _SH := "<Zsssssssssssssssss>"


static func _basis(naam: String, verdieping: int, tier: int) -> Dictionary:
	return {
		"name": naam, "floor": verdieping, "tier": tier, "archief": "2", "theme": "levend_kas",
		"layout": [_TOP, _WU, _WL, _SH, _F, _F, _F, _F, _F, _F, _F, _BOT],
		"spawns": {"zuid": [9, 10, "up"], "noord": [9, 3, "down"], "ingang": [9, 10, "up"]},
	}


static func _met(basis: Dictionary, extra: Dictionary) -> Dictionary:
	var out := basis.duplicate(true)
	for k in extra:
		out[k] = extra[k]
	return out


static func rooms() -> Dictionary:
	var entree := _met(_basis("Het Levende Archief", 1, 2), {
		"save": [3, 8],
		"exits": {
			"E": {"map": "res://scenes/maps/wereldkaart.tscn", "spawn": "van_archief2"},
			"n": {"map": SCENES["archief_2_v1_plaat"], "spawn": "zuid"},
		},
		"signs": [{"tile": [4, 5], "lines": [
			"De kas ademt. Alles hier groeit door, ook als je stilstaat.",
		]}],
		"monsters": [
			{"id": "m1", "enemy": "mosslijm", "group": ["mosslijm"], "tile": [5, 6], "moves": true},
			{"id": "m2", "enemy": "wortelkruiper", "group": ["wortelkruiper"], "tile": [14, 7], "moves": true},
		],
	})
	var plaat := _met(_basis("Groei-plaat", 1, 2), {
		"layout": [_TOP, _WU, _WL, _F, _G, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v1_entree"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v2_gang"], "spawn": "zuid"},
		},
		"signs": [{"tile": [4, 6], "lines": [
			"Een groei-plaat. Stap erop.",
			"Hij groeit tot een pad.",
		]}],
		"platen": [{"id": "p1", "soort": "groei", "tile": [9, 6], "start": 0}],
		"bruggen": [{"plaat": "p1", "tiles": [[8, 4], [9, 4], [10, 4]]}],
	})
	var gang := _met(_basis("Kasgang", 2, 2), {
		"exits": {
			"E": {"map": SCENES["archief_2_v1_plaat"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v2_lotte"], "spawn": "zuid"},
		},
		"monsters": [
			{"id": "m1", "enemy": "wortelkruiper", "group": ["wortelkruiper"], "tile": [6, 6], "moves": true},
			{"id": "m2", "enemy": "sporenzwam", "group": ["sporenzwam"], "tile": [13, 7], "moves": true},
		],
	})
	var lotte := _met(_basis("Lotte", 2, 2), {
		"layout": [_TOP, _WU, _WL, _F, _F, _B, _F, _F, _F, _F, _F, _BOT],
		"checkpoint": false,
		"exits": {
			"E": {"map": SCENES["archief_2_v2_gang"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v3_ketting"], "spawn": "zuid"},
		},
		"monsters": [{
			"id": "lotte", "enemy": "lotte_glitch", "group": ["lotte_glitch"],
			"tile": [9, 5], "moves": false, "boss": true, "guard": true,
		}],
	})
	var ketting := _met(_basis("Ketting-platen", 3, 3), {
		"layout": [_TOP, _WU, _WL, _F, _G, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v2_lotte"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v3_tegen"], "spawn": "zuid"},
		},
		"signs": [{"tile": [3, 7], "lines": [
			"Ketting-platen. Eén activeert de volgende.",
			"De laatste groeit alleen als de vorige hem wekt.",
		]}],
		"platen": [
			{"id": "k0", "soort": "ketting", "index": 0, "tile": [4, 6], "start": 0},
			{"id": "k1", "soort": "ketting", "index": 1, "tile": [8, 6], "start": 0},
			{"id": "k2", "soort": "ketting", "index": 2, "tile": [12, 6], "start": 0},
		],
		"bruggen": [{"plaat": "k2", "tiles": [[8, 4], [9, 4], [10, 4]]}],
		"monsters": [
			{"id": "m1", "enemy": "sporenzwam", "group": ["sporenzwam"], "tile": [15, 8], "moves": true},
		],
	})
	var tegen := _met(_basis("Tegen-platen", 3, 3), {
		"layout": [_TOP, _WU, _WL, _F, _T, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v3_ketting"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v3_licht"], "spawn": "zuid"},
		},
		"signs": [{"tile": [3, 7], "lines": [
			"Tegen-platen krimpen als je ze aanraakt.",
			"Mijd ze, of neem de lange weg links.",
		]}],
		"platen": [{"id": "t1", "soort": "tegen", "tile": [14, 6], "start": 2}],
		"bruggen": [{"plaat": "t1", "tiles": [[12, 4], [13, 4], [14, 4]]}],
	})
	var licht := _met(_basis("Licht-platen", 3, 3), {
		"layout": [_TOP, _WU, _WL, _F, _G, _F, _F, _F, _F, _F, _F, _BOT],
		"exits": {
			"E": {"map": SCENES["archief_2_v3_tegen"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v3_wurger"], "spawn": "zuid"},
		},
		"signs": [{"tile": [4, 7], "lines": [
			"Deze plaat groeit alleen in Lotte's licht.",
			"Ga ervoor staan en druk op A.",
		]}],
		"platen": [{"id": "l1", "soort": "licht", "tile": [9, 6], "start": 0}],
		"bruggen": [{"plaat": "l1", "tiles": [[8, 4], [9, 4], [10, 4]]}],
	})
	var wurger := _met(_basis("De Wurger", 3, 3), {
		"layout": [_TOP, _WU, _WL, _F, _F, _B, _F, _F, _F, _F, _F, _BOT],
		"checkpoint": false,
		"exits": {
			"E": {"map": SCENES["archief_2_v3_licht"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v4_hal"], "spawn": "zuid"},
		},
		"signs": [{"tile": [4, 8], "lines": [
			"Ranken versperren de kas. IJs en een zwaard snijden ze door.",
		]}],
		"monsters": [{
			"id": "wurger", "enemy": "wurger", "group": ["wurger"],
			"tile": [9, 5], "moves": false, "boss": true, "guard": true,
		}],
	})
	var hal := _met(_basis("Hal van de Genezer", 4, 3), {
		"exits": {
			"E": {"map": SCENES["archief_2_v3_wurger"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_v4_genezer"], "spawn": "zuid"},
		},
		"signs": [{"tile": [4, 6], "lines": [
			"Verderop staat iets dat geneest door te nemen.",
		]}],
		"monsters": [
			{"id": "m1", "enemy": "sporenzwam", "group": ["sporenzwam"], "tile": [13, 7], "moves": true},
		],
	})
	var genezer := _met(_basis("De Genezer", 4, 3), {
		"layout": [_TOP, _WU, _WL, _F, _F, _B, _F, _F, _F, _F, _F, _BOT],
		"checkpoint": false,
		"exits": {
			"E": {"map": SCENES["archief_2_v4_hal"], "spawn": "noord"},
			"n": {"map": SCENES["archief_2_warper"], "spawn": "ingang"},
		},
		"monsters": [{
			"id": "genezer", "enemy": "genezer", "group": ["genezer"],
			"tile": [9, 5], "moves": false, "boss": true, "guard": true,
		}],
	})
	var warper := _met(_basis("World Warper", 4, 0), {
		"theme": "warper_paars",
		"save": [3, 8],
		"exits": {
			"E": {"map": SCENES["archief_2_v4_genezer"], "spawn": "noord"},
		},
		"warp": [9, 6],
		"signs": [{"tile": [5, 5], "lines": [
			"ECHO bedient de hub. Stap op het pad en kies.",
		]}],
		"sfeer": [
			{"name": "Echo", "texture": "res://assets/sprites/archief2/echo.png", "tile": [4, 6], "scale": 1.0},
			{"name": "Warper", "texture": "res://assets/sprites/archief2/world_warper.png", "tile": [14, 4], "scale": 0.25},
			{"name": "Sapientia", "texture": "res://assets/sprites/archief2/sapientia_glitch.png", "tile": [15, 7], "scale": 0.5},
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
