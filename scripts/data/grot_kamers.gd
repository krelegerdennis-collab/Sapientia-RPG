extends RefCounted
## Kamersoorten van de Diepe Grot (Dungeon100) bovenop de gegenereerde verdieping: VALKAMER,
## RUSTKAMER (= de bestaande rustpunt-verdiepingen, elke 10e) en KOOPMANKAMER (H-5, CANON §12).
## Puur en deterministisch per (run-seed, verdieping); raakt de generator niet aan, zodat de
## bestaande kaarten (en hun tests) gelijk blijven. De kamerbouwer (dungeon100_room.gd) leest dit.
##
## Atlas: assets/tiles/dungeon/grot_kamers.png (RPG ART batch 10, 128x48, 16x16-tegels, 8 kol x 3 rijen):
##   rij 0 vallen  (0 spijker verborgen, 1 zichtbaar, 2-3 geactiveerd; 4 rune verborgen, 5 zichtbaar, 6<->7 geactiveerd)
##   rij 1 rustpunt (0-3 kampvuur-lus, 4 gedoofd, 5 boomstam, 6-7 slaaprol)
##   rij 2 koopman (0-3 kraam van 4 breed, 4 krat, 5 zakken, 6 lantaarnpaal, 7 kleed)
##
## TIJDELIJKE AANNAMES (zie HANDOFF_KOOPMAN.md):
##   - Koopman: precies 1x per blok van 10 verdiepingen (TODO: "max 1x per 10"), op een vaste
##     (zaad-)verdieping in dat blok die geen rust-, baas- of eindverdieping is. De 1% uit TODO.md
##     zou de 8+ bezoeken van CANON §12 praktisch onhaalbaar maken.
##   - Valkamer: 7% per verdieping, niet op 1-3 (TODO canon), niet op rust/baas/koopman/100.
##     60% zichtbaar / 40% verborgen (TODO canon). Alleen spijkerplaat (5-10% HP) en drukplaat-rune (10% HP).

const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")
const Layouts := preload("res://scripts/data/grot_layouts.gd")

const ATLAS := preload("res://assets/tiles/dungeon/grot_kamers.png")
const TEGEL := 16

const SOORT_GEWOON := ""
const SOORT_VAL := "val"
const SOORT_RUST := "rust"
const SOORT_KOOPMAN := "koopman"

const VAL_KANS := 0.07
const VAL_VANAF := 4
const VAL_ZICHTBAAR_KANS := 0.6
const VAL_MIN := 3
const VAL_MAX := 5

## Valsoorten: kolommen in rij 0 + schade (fractie van max HP, min/max).
const VALLEN := {
	"spijker": {"verborgen": 0, "zichtbaar": 1, "actief": [2, 3], "schade": [0.05, 0.10]},
	"rune": {"verborgen": 4, "zichtbaar": 5, "actief": [6, 7], "schade": [0.10, 0.10]},
}
const VUUR_FRAMES: Array[int] = [0, 1, 2, 3]   # rij 1
const VUUR_FPS := 6.7                          # ~0,15 s per frame (LEESMIJ)
const KRAAM_KOLOMMEN: Array[int] = [0, 1, 2, 3]  # rij 2
const KLEED_KOLOM := 7


## Kaartje uit de atlas: kolom, rij.
static func tegel(kolom: int, rij: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = ATLAS
	t.region = Rect2(kolom * TEGEL, rij * TEGEL, TEGEL, TEGEL)
	return t


static func _hash(run_seed: int, floor_no: int, zout: int) -> int:
	var h: int = (run_seed * 31 + floor_no * 0x9E3779B1 + zout * 0x85EBCA6B) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 0x5BD1E995) & 0x7FFFFFFF
	return (h ^ (h >> 15)) & 0x7FFFFFFF


static func _speciaal(floor_no: int) -> bool:
	return floor_no >= 100 or Rules.is_rest_floor(floor_no) or Scaling.is_boss_floor(floor_no)


## De koopmanverdieping in het blok van 10 waar floor_no in valt (1-10 -> blok 0, 11-20 -> blok 1, ...).
static func koopman_verdieping(run_seed: int, floor_no: int) -> int:
	var blok := (maxi(1, floor_no) - 1) / 10
	var kandidaten: Array[int] = []
	for f in range(blok * 10 + 1, blok * 10 + 11):
		if f > 1 and not _speciaal(f):
			kandidaten.append(f)
	if kandidaten.is_empty():
		return -1
	return kandidaten[_hash(run_seed, blok, 7) % kandidaten.size()]


## Layout-type (grot_layouts.gd) met de koopmanregel van deze file.
static func layout_soort(run_seed: int, floor_no: int) -> String:
	return Layouts.soort(run_seed, floor_no, func(f: int) -> bool:
		return f >= 1 and f < 100 and not _speciaal(f) and koopman_verdieping(run_seed, f) == f)


## Kamersoort voor de kamerbouwer: "val", "rust", "koopman" of "". Volgt het layout-type; de vaste
## rustpunt-verdiepingen (elke 10e, behalve 100) blijven "rust".
static func kamer_soort(run_seed: int, floor_no: int) -> String:
	if floor_no < 1 or floor_no > 100:
		return SOORT_GEWOON
	if Rules.is_rest_floor(floor_no) and floor_no < 100:
		return SOORT_RUST
	match layout_soort(run_seed, floor_no):
		Layouts.KOOPMAN:
			return SOORT_KOOPMAN
		Layouts.VAL:
			return SOORT_VAL
		Layouts.RUST:
			return SOORT_RUST
	return SOORT_GEWOON


static func _vrij_teken(ch: String) -> bool:
	return ch == "." or ch in ["w", "x", "p", ",", "X"]


static func _bezet(room: Dictionary, d: Dictionary) -> Dictionary:
	var taken := {}
	for m in room.get("monsters", []):
		var sz: Array = m.get("size", [1, 1])
		for dx in int(sz[0]):
			for dy in int(sz[1]):
				taken[Vector2i(int(m["tile"][0]) + dx, int(m["tile"][1]) + dy)] = true
	for c in room.get("chests", []):
		taken[Vector2i(int(c["tile"][0]), int(c["tile"][1]))] = true
	for k in ["rustpunt", "warper"]:
		if room.has(k):
			taken[Vector2i(int(room[k][0]), int(room[k][1]))] = true
	for sp in room.get("spawns", {}).values():
		taken[Vector2i(int(sp[0]), int(sp[1]))] = true
	for k in ["spawn_up", "stairs_up", "stairs_down", "spawn_down", "warper_spawn"]:
		if d.has(k) and d[k] is Vector2i:
			taken[d[k]] = true
	return taken


static func _vrij(layout: Array, t: Vector2i) -> bool:
	if t.y < 0 or t.y >= layout.size():
		return false
	var row: String = layout[t.y]
	return t.x >= 0 and t.x < row.length() and _vrij_teken(row[t.x])


## Plek voor de kraam (4 breed, rij y) met de Koopman eronder (x+1, y+1): een vrij blok van 6x4
## (kraam + koopman + ring eromheen), zodat niets afgesloten wordt. Liefst in de ingangskamer.
## Geeft {"kraam": Vector2i (linkertegel), "koopman": Vector2i} of {}.
static func koopman_plek(room: Dictionary, d: Dictionary) -> Dictionary:
	var layout: Array = room.get("layout", [])
	var taken := _bezet(room, d)
	var kandidaten: Array[Vector2i] = []
	for y in range(1, layout.size() - 3):
		for x in range(1, str(layout[y]).length() - 5):
			var ok := true
			for dy in range(-1, 3):
				for dx in range(-1, 5):
					var t := Vector2i(x + dx, y + dy)
					if not _vrij(layout, t) or taken.has(t):
						ok = false
						break
				if not ok:
					break
			if ok:
				kandidaten.append(Vector2i(x, y))
	if kandidaten.is_empty():
		return {}
	var start: Vector2i = d.get("spawn_up", Vector2i.ZERO)
	kandidaten.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := absi(a.x + 1 - start.x) + absi(a.y + 1 - start.y)
		var db := absi(b.x + 1 - start.x) + absi(b.y + 1 - start.y)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	# niet pal naast de ladder: minstens 3 tegels afstand
	for k in kandidaten:
		if absi(k.x + 1 - start.x) + absi(k.y + 1 - start.y) >= 3:
			return {"kraam": k, "koopman": k + Vector2i(1, 1)}
	return {"kraam": kandidaten[0], "koopman": kandidaten[0] + Vector2i(1, 1)}


## Vallen voor een valkamer: [{tile: Vector2i, soort: "spijker"|"rune", verborgen: bool}].
## Nooit op bezette tegels of binnen 3 tegels van de ladder.
static func vallen(run_seed: int, room: Dictionary, d: Dictionary) -> Array:
	var floor_no := int(room.get("dungeon100_floor", room.get("floor", 0)))
	var layout: Array = room.get("layout", [])
	var taken := _bezet(room, d)
	var start: Vector2i = d.get("spawn_up", Vector2i.ZERO)
	var vrij: Array[Vector2i] = []
	for y in layout.size():
		for x in str(layout[y]).length():
			var t := Vector2i(x, y)
			if str(layout[y])[x] == "." and not taken.has(t) and absi(t.x - start.x) + absi(t.y - start.y) > 3:
				vrij.append(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(run_seed, floor_no, 11)
	var n := mini(vrij.size(), rng.randi_range(VAL_MIN, VAL_MAX))
	var uit: Array = []
	for i in n:
		var j := rng.randi_range(0, vrij.size() - 1)
		var t: Vector2i = vrij[j]
		vrij.remove_at(j)
		uit.append({"tile": t, "soort": "spijker" if rng.randf() < 0.5 else "rune",
				"verborgen": rng.randf() >= VAL_ZICHTBAAR_KANS})
	return uit


## Schade van een val voor één held (minstens 1, nooit dodelijk: blijft op minstens 1 HP).
static func val_schade(soort: String, max_hp: int, hp: int, rol: float) -> int:
	var s: Array = VALLEN.get(soort, VALLEN["spijker"])["schade"]
	var f := lerpf(float(s[0]), float(s[1]), clampf(rol, 0.0, 1.0))
	var dmg := maxi(1, roundi(float(max_hp) * f))
	return mini(dmg, maxi(0, hp - 1))
