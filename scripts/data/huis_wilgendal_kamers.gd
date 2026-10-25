extends RefCounted
## Vleugels van het Wachtershuis (huis_wilgendal.tscn).
## De woonkamer op Ground blijft 12x9 op (0,0) — bestaande tests en de proloog
## (bed, lezen, binnen, schilderij, opslagboek, Opa-loop) hangen daaraan.
## Annex vult de camerapadding voor 16:9 (384x216) én 19,5:9 (468x216):
## links slaapkamer Dax, rechts slaapkamer Opa, buitenste kolommen = muur.

const LEGEND := {
	".": 0, ",": 1, "C": 2, "U": 3, "W": 4, "D": 5, "S": 6, "s": 7,
	"t": 8, "h": 9, "b": 10, "d": 11, "q": 12, "w": 13, "e": 14,
	"a": 15, "m": 16, "f": 17, "z": 18, "P": 19, "c": 20, "k": 21, "L": 23, "R": 24,
}

## Wereldtegel van string-index 0. 30 kolommen: x=-9..20 dekt 19,5:9-padding.
const X0 := -9
const Y0 := -3
## Midden 12 kolommen op y=0..8 blijven Ground (spatie = niet schilderen).
const ANNEX_MAP := [
	"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCC            CCCCCCCCC",
	"CUUSSWWUU            UUWWSSUUC",
	"LssqweamU            UmaewqssR",
	"LaabamfhU            UhfmabaaR",
	"LzzdzPctU            UtcPzdzzR",
	"LqweamfcU            UcfmaewqR",
	"LkqweamfD            DfmaewqkR",
	"LssSthqwU            UwqhtSssR",
	"CCCCCCCCC            CCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
	"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
]

## Deuropeningen in de bestaande woonkamer-muur (Ground). Niet op de autotest-loop.
const WOON_DEUREN: Array[Vector2i] = [Vector2i(0, 6), Vector2i(11, 6)]
const STOEL_2 := Vector2i(7, 5)
const KEUKEN_AANRECHT := Vector2i(10, 4)
const KEUKEN_FORNUIS := Vector2i(10, 5)
const KEUKEN_KLEED := Vector2i(10, 6)
const KEUKEN_KAST := Vector2i(10, 4)
const KEUKEN_TAFEL_RUG := Vector2i(8, 6)
const KEUKEN_STOEL_RUG := Vector2i(7, 6)
const KEUKEN_RUGS: Array[Vector2i] = [
	Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4),
	Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6),
]

const BED_DAX := Vector2i(-6, 3)
const BED_OPA := Vector2i(17, 3)
const DEUR_DAX := Vector2i(0, 6)
const DEUR_OPA := Vector2i(11, 6)
const KOZIJN_DAX := Vector2i(0, 5)
const KOZIJN_OPA := Vector2i(11, 5)
const KAST_DAX := Vector2i(-6, 7)
const KAST_OPA := Vector2i(17, 7)
const SLAAP_DAX := Rect2i(Vector2i(-8, 2), Vector2i(7, 6))
const SLAAP_OPA := Rect2i(Vector2i(13, 2), Vector2i(7, 6))
const KEUKEN_ZONE := Rect2i(Vector2i(7, 4), Vector2i(4, 3))
const KOZIJN_MAAT := Vector2i(24, 32)
## Voordeur naar buiten: minstens 2 tegels, originele (4,8) blijft staan.
const VOORDEUR: Array[Vector2i] = [Vector2i(4, 8), Vector2i(5, 8)]
const VOORDEUR_MAT: Array[Vector2i] = [Vector2i(4, 7), Vector2i(5, 7)]
const KOZIJN_VOOR_L := Vector2i(3, 8)
const KOZIJN_VOOR_R := Vector2i(6, 8)

const VP_16_9 := Vector2i(384, 216)
const VP_195_9 := Vector2i(468, 216)


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
	# Scheidingswanden: paneel i.p.v. dunne L/R-rand, deuropening blijft D.
	for y in [2, 3, 4, 5, 7]:
		ground.set_cell(Vector2i(0, y), 0, Vector2i(atlas("U"), 0))
		ground.set_cell(Vector2i(11, y), 0, Vector2i(atlas("U"), 0))
	ground.set_cell(STOEL_2, 0, Vector2i(atlas("h"), 0))
	ground.set_cell(KEUKEN_AANRECHT, 0, Vector2i(atlas("t"), 0))
	ground.set_cell(KEUKEN_FORNUIS, 0, Vector2i(atlas("t"), 0))
	ground.set_cell(KEUKEN_KLEED, 0, Vector2i(atlas("m"), 0))
	ground.set_cell(KEUKEN_TAFEL_RUG, 0, Vector2i(atlas("w"), 0))
	ground.set_cell(KEUKEN_STOEL_RUG, 0, Vector2i(atlas("a"), 0))
	ground.set_cell(Vector2i(7, 4), 0, Vector2i(atlas("z"), 0))
	ground.set_cell(Vector2i(8, 4), 0, Vector2i(atlas("P"), 0))
	ground.set_cell(Vector2i(9, 4), 0, Vector2i(atlas("c"), 0))
	ground.set_cell(Vector2i(9, 6), 0, Vector2i(atlas("f"), 0))
	for tegel in VOORDEUR:
		ground.set_cell(tegel, 0, Vector2i(atlas("D"), 0))
	# Mat/drempel direct voor de 2-tegel-deur; (4,7) blijft het spawnpunt.
	ground.set_cell(VOORDEUR_MAT[0], 0, Vector2i(atlas("z"), 0))
	ground.set_cell(VOORDEUR_MAT[1], 0, Vector2i(atlas("c"), 0))


static func laag_blokkeert(laag: TileMapLayer, tegel: Vector2i) -> bool:
	if laag == null:
		return false
	var data: TileData = laag.get_cell_tile_data(tegel)
	if data == null:
		return false
	return data.get_collision_polygons_count(0) > 0


static func camera_rect(used: Rect2i, vp: Vector2i) -> Rect2i:
	var r := Rect2i(used.position * 16, used.size * 16)
	if r.size.x < vp.x:
		r.position.x -= (vp.x - r.size.x) / 2
		r.size.x = vp.x
	if r.size.y < vp.y:
		r.position.y -= (vp.y - r.size.y) / 2
		r.size.y = vp.y
	return r
