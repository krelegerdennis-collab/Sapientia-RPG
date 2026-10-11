extends RefCounted
## Verdieping 1 van Het Levende Archief (kas). Zelfde velden als dungeon_rooms.gd ROOMS.
## Aparte lijst, zodat de tellingen van het Eerste Archief (ORDER, gevechten, thema
## archief_grijs) blijven staan. DungeonRooms.room() zoekt hier ná de Archieven.
##
## TODO(verhaal): de ingang op de wereldkaart gebruikt de bestaande golem-vlag.
## Waarom de kern van Archief 1 op een tweede signaal reageert, staat nog open.
## TODO(design): verdieping 2-4, Lotte, De Genezer en de World Warper horen hier niet.

const THEME := "kas"
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const M := "res://scenes/maps/"

const ROOMS := {
	# 1 KAS (16x11): entree vanaf de wereldkaart, zichtbare monsters, bord, opslag.
	"leven_ingang": {
		"name": "Het Levende Archief",
		"floor": 1,
		"tier": 2,
		"theme": THEME,
		"layout": [
			"a--------------b",
			"<LFFMFFFFGFFFFR>",
			"<lffmffffnffffr>",
			"<Zsssssssssssss>",
			"<S.............>",
			"<S.............>",
			"<S....x........>",
			"<S.............>",
			"<S.@...........>",
			"<S.............>",
			"c_____(EE)_____d",
		],
		"save": [3, 8],
		"spawns": {"ingang": [7, 9, "up"], "boog": [9, 3, "down"]},
		"exits": {
			"E": {"map": WORLD, "spawn": "van_kas"},
			"n": {"map": M + "leven_v1_plaat.tscn", "spawn": "ingang"},
		},
		"signs": [{
			"tile": [12, 5],
			"lines": [
				"Een kas. De ranken groeien over de vloer.",
				"Zet de hendel om. Daarna groeit de plaat tot een pad.",
			],
		}],
		# Bestaande soorten. Geen nieuwe species.
		"monsters": [
			{"id": "m1", "enemy": "mosslijm", "group": ["mosslijm"], "tile": [4, 6], "moves": true},
			{"id": "m2", "enemy": "moskonijn", "group": ["moskonijn"], "tile": [12, 7], "moves": true},
		],
	},
}

const ORDER := [
	["leven_ingang", M + "leven_ingang.tscn"],
]
