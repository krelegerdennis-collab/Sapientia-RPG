extends RefCounted
## WM1 T2: Donker Woud - de Beek (woud_beek). Optionele zijkamer van het Wortelpad (woud_pad), gebouwd uit
## data/woud_tegels.json (16x16 via `"file"`, scripts/data/woud_tegels.gd). Geen monsters, geen kist.
## TEMPORARY ASSUMPTION: er is geen spec voor een extra woudkamer; dit is een rustige zijkamer die alle
## tegelgroepen laat zien (grond, pad, bosrand, bomen, water, brug, props, uitgang) voor RPG ART.
##
## Tekens: zie LEGEND. 'p' = pad en '~' = water zijn gebieden: de bouwer kiest zelf het rand-/hoekstuk.
## '=' = brug (links/midden/rechts uit de buren), 'o' = stapsteen. '.' en ',' kiezen een vaste variant.

const SCENE := "res://scenes/maps/woud_beek.tscn"
const PAD := "res://scenes/maps/woud_pad.tscn"
const NAAM := "Dark Wood - Brook"

const LAYOUT := [
	"12222222222222222222222223",
	"4[SSSSSSSSSSSSSSSSSSSSSS]6",
	"4{ssssssssssssssssssssss}6",
	"4hnnnnnnnnnn~~~nnnnnnnnnn6",
	"4w..pp....,.~~~..v.......6",
	"4w..pp..R...~~~.....gG...6",
	"4wb.pp......~~~..........6",
	"4w..pp......~~~........Y.6",
	"4w..ppppppp=====ppppppp..6",
	"4w..ppppppp.~~~.ppppppp..6",
	"4w..pp......~~~..........6",
	"4w.,pp......~~~........M.6",
	"4w..pp.v....ooo...K......6",
	"4w..pp...m..~~~....,.....6",
	"4w..pp......~~~..........6",
	"788(UU)8888888888888888889",
]

const LEGEND := {
	"1": "rand_top_nw", "2": "rand_top_n", "3": "rand_top_no", "4": "rand_top_w", "5": "rand_top_m",
	"6": "rand_top_o", "7": "rand_top_zw", "8": "rand_top_z", "9": "rand_top_zo",
	"[": "rand_stam_boven_links", "S": "rand_stam_boven_midden", "]": "rand_stam_boven_rechts",
	"{": "rand_stam_onder_links", "s": "rand_stam_onder_midden", "}": "rand_stam_onder_rechts",
	"n": "grond_schaduw_n", "w": "grond_schaduw_w", "h": "grond_schaduw_nw",
	"R": "steen", "K": "stronk", "g": "stam_liggend_l", "G": "stam_liggend_r", "v": "varen",
	"m": "paddenstoel", "M": "paddenstoel_gloed", "Y": "wegwijzer", "b": "struik", "o": "stapsteen",
	"(": "uitgang_rand_l", "U": "uitgang_pad", ")": "uitgang_rand_r",
}
const STAM_VAR := ["", "_b", "_c"]
const GROND := ["grond_a", "grond_b", "grond_c", "grond_d"]
const BLAD := ["grond_blad_a", "grond_blad_b"]

## Bomen 2x3: [x, y van de linker stamvoet, soort]; kruin (2 rijen erboven) op de overlay-laag.
const BOMEN := [[7, 6, "eik"], [19, 14, "den"], [2, 13, "eik"]]
## Mist op de overlay: [x, y, lengte].
const MIST := [[15, 4, 4], [2, 10, 3]]
const SPAWNS := {"pad": [4, 14, "up"]}
## Uitgang: alle 'U' -> terug naar het Wortelpad bij de kast-opening.
const EXIT := {"map": PAD, "spawn": "beek"}
const BORD := {"tile": [23, 7], "lines": ["West: the Root Path.", "The brook runs on into the dark."]}


static func teken(t: Vector2i) -> String:
	if t.y < 0 or t.y >= LAYOUT.size() or t.x < 0 or t.x >= str(LAYOUT[0]).length():
		return ""
	return str(LAYOUT[t.y])[t.x]


## Tegelnaam van de grondlaag op t (zonder bomen).
static func grond_naam(t: Vector2i) -> String:
	var c := teken(t)
	var h := absi((t.x * 73856093) ^ (t.y * 19349663))
	match c:
		".":
			return GROND[h % GROND.size()]
		",":
			return BLAD[h % BLAD.size()]
		"p":
			var s := WoudTegelsData.stuk(func(q): return teken(q) == "p", t)
			if s == "m" and h % 3 == 0:
				return "pad_m_b"
			return "pad_" + s
		"~":
			var s := WoudTegelsData.stuk(func(q): return teken(q) in ["~", "o"] or _brug_water(q), t)
			return "water_m" if s == "m" else "water_oever_" + s
		"=":
			var l := teken(t + Vector2i.LEFT) == "="
			var r := teken(t + Vector2i.RIGHT) == "="
			return "brug_midden" if l and r else ("brug_links" if r else "brug_rechts")
	var naam := str(LEGEND.get(c, ""))
	if naam.begins_with("rand_stam_"):
		# variant per column (x only), so the top and bottom rows stay aligned
		var hv := absi(((t.x * 73856093) ^ 19349663) * 83492791)
		naam += STAM_VAR[hv % STAM_VAR.size()]
	return naam


## Brugdelen die boven water liggen tellen voor het oever-stuk mee als water.
static func _brug_water(t: Vector2i) -> bool:
	return teken(t) == "=" and teken(t + Vector2i.UP) == "~"


## Alle tegels: {Vector2i: naam} voor grond en overlay, met de bomen.
static func lagen() -> Dictionary:
	var grond := {}
	var overlay := {}
	for y in LAYOUT.size():
		for x in str(LAYOUT[y]).length():
			grond[Vector2i(x, y)] = grond_naam(Vector2i(x, y))
	for b in BOMEN:
		var x := int(b[0])
		var y := int(b[1])
		var s := str(b[2])
		grond[Vector2i(x, y)] = "boom_%s_voet_l" % s
		grond[Vector2i(x + 1, y)] = "boom_%s_voet_r" % s
		overlay[Vector2i(x, y - 2)] = "boom_%s_kruin_boven_l" % s
		overlay[Vector2i(x + 1, y - 2)] = "boom_%s_kruin_boven_r" % s
		overlay[Vector2i(x, y - 1)] = "boom_%s_kruin_midden_l" % s
		overlay[Vector2i(x + 1, y - 1)] = "boom_%s_kruin_midden_r" % s
	for m in MIST:
		for i in int(m[2]):
			overlay[Vector2i(int(m[0]) + i, int(m[1]))] = "mist"
	return {"grond": grond, "overlay": overlay}


static func beloopbaar(t: Vector2i) -> bool:
	var naam: String = lagen()["grond"].get(t, "")
	if naam == "":
		return false
	return not bool(WoudTegelsData.tegel(naam).get("solid", true))


static func uitgangen() -> Array[Vector2i]:
	var uit: Array[Vector2i] = []
	for y in LAYOUT.size():
		for x in str(LAYOUT[y]).length():
			if str(LAYOUT[y])[x] == "U":
				uit.append(Vector2i(x, y))
	return uit
