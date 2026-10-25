extends RefCounted
## Vleugels van het Wachtershuis (huis_wilgendal.tscn).
## De woonkamer op Ground blijft 12x9 op (0,0) — bestaande tests en de proloog
## (bed, lezen, binnen, schilderij, opslagboek, Opa-loop) hangen daaraan.
## Annex vult de camerapadding (384x216) zodat er geen zwart gat om de kamer zit:
## links slaapkamer Dax, rechts slaapkamer Opa, boven/onder muur.

const LEGEND := {
	".": 0, ",": 1, "C": 2, "U": 3, "W": 4, "D": 5, "S": 6, "s": 7,
	"t": 8, "h": 9, "b": 10, "d": 11, "q": 12, "w": 13, "e": 14,
	"a": 15, "m": 16, "f": 17, "z": 18, "P": 19, "c": 20, "k": 21, "L": 23, "R": 24,
}

## Wereldtegel van string-index 0.
const X0 := -6
const Y0 := -3
## Midden 12 kolommen op y=0..8 blijven Ground (spatie = niet schilderen).
const ANNEX_MAP := [
	"CCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCC            CCCCCC",
	"USSWWU            UWSSUU",
	"Lss..R            L..ssR",
	"Lb...R            L...bR",
	"Ld.h.R            L.h.dR",
	"L....R            L....R",
	"L....D            D....R",
	"Lk...R            L...kR",
	"CCCCCC            CCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCC",
]

## Deuropeningen in de bestaande woonkamer-muur (Ground). Niet op de autotest-loop.
const WOON_DEUREN: Array[Vector2i] = [Vector2i(0, 6), Vector2i(11, 6)]
## Tweede stoel naast de tafel; keukentegel (fornuis/aanrecht).
const STOEL_2 := Vector2i(7, 5)
const KEUKEN_AANRECHT := Vector2i(10, 4)
const KEUKEN_FORNUIS := Vector2i(10, 5)

const BED_DAX := Vector2i(-5, 3)
const BED_OPA := Vector2i(16, 3)
const DEUR_DAX := Vector2i(0, 6)
const DEUR_OPA := Vector2i(11, 6)


static func atlas(teken: String) -> int:
	return int(LEGEND.get(teken, 0))


static func verf(annex: TileMapLayer, ground: TileMapLayer) -> void:
	for y in ANNEX_MAP.size():
		var rij: String = ANNEX_MAP[y]
		for x in rij.length():
			var teken := rij[x]
			if teken == " ":
				continue
			var tegel := Vector2i(X0 + x, Y0 + y)
			if ground.get_cell_source_id(tegel) != -1:
				continue
			annex.set_cell(tegel, 0, Vector2i(atlas(teken), 0))
	for deur in WOON_DEUREN:
		ground.set_cell(deur, 0, Vector2i(atlas("D"), 0))
	ground.set_cell(STOEL_2, 0, Vector2i(atlas("h"), 0))
	ground.set_cell(KEUKEN_AANRECHT, 0, Vector2i(atlas("t"), 0))
	ground.set_cell(KEUKEN_FORNUIS, 0, Vector2i(atlas("t"), 0))


static func laag_blokkeert(laag: TileMapLayer, tegel: Vector2i) -> bool:
	if laag == null:
		return false
	var data: TileData = laag.get_cell_tile_data(tegel)
	if data == null:
		return false
	return data.get_collision_polygons_count(0) > 0
