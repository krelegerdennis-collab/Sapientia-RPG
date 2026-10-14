extends RefCounted
## LAYOUT-TYPES van de Diepe Grot (Dungeon100): per verdieping één layout uit de CANON-tabel in
## TODO.md ("Diepe Grot – map generatie (uitgebreid)"). Puur en deterministisch per (run-seed, verdieping):
## dezelfde save (seed + verdieping) geeft altijd hetzelfde type, dus "onthouden voor save/load" gaat via de seed.
##
## Vast (geen worp):
##   - verdieping 100            -> VLOER100 (warp-kristal, geen monsters, geen kisten)
##   - baasverdieping (BOSSES)   -> BAAS (baas + wat monsters). Dat zijn 10, 20, 25 ... 90 en 99; de
##     tien-tallen zijn ook rustpunt-verdiepingen (checkpoint), dat blijft zo.
##   - koopmanverdieping (GrotKamers.koopman_verdieping, 1x per 10) -> KOOPMAN
## Anders een worp uit KANSEN. AANNAMES (zie de PR):
##   - De CANON-tabel telt op tot 91%; de worp normaliseert over de actieve types.
##   - De Koopman (1%) blijft de vaste 1x-per-10-regel van GrotKamers (H-5, CANON 12); hij zit niet in de worp.
##   - PUZZEL staat uit (PUZZEL_ACTIEF) tot Dennis kiest welke puzzels (TODO(design)); zijn 5% valt weg.
##   - Kamerafmeting = speelveld incl. buitenmuur: CHEST ROOM 12x12 (vloer 8x7), MEDIUM 25x25, LARGE 50x50.
##     Val, schat, leeg, rust, baas en vloer 100 gebruiken de MEDIUM-maat.
## Balans-regels: PUZZEL niet op 1-5, VAL niet op 1-3, SCHAT nooit direct naast een RUST-verdieping
## (gerold of vast), KOOPMAN max 1x per 10 (GrotKamers).

const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")

const MEDIUM := "medium"
const GROOT := "groot"
const KIST := "kist"
const VAL := "val"
const PUZZEL := "puzzel"
const SCHAT := "schat"
const LEEG := "leeg"
const RUST := "rust"
const KOOPMAN := "koopman"
const BAAS := "baas"
const VLOER100 := "vloer100"

## CANON-kansen in procenten (TODO.md). Koopman staat er voor de volledigheid in maar wordt niet gerold.
const KANSEN := {MEDIUM: 35, GROOT: 20, KIST: 10, VAL: 7, PUZZEL: 5, SCHAT: 5, LEEG: 5, RUST: 3, KOOPMAN: 1}
## Vaste volgorde van de worp (zelfde seed = zelfde type).
const VOLGORDE := [MEDIUM, GROOT, KIST, VAL, PUZZEL, SCHAT, LEEG, RUST]
const PUZZEL_ACTIEF := false
const PUZZEL_VANAF := 6
const VAL_VANAF := 4

## Kaartmaat per type (incl. buitenmuur). Standaard MEDIUM.
const MAAT := {GROOT: Vector2i(50, 50), KIST: Vector2i(12, 12)}
const MAAT_STANDAARD := Vector2i(25, 25)

## Monsters per floor-bracket [tot en met verdieping, min, max].
const MONSTERS_MEDIUM := [[20, 8, 10], [50, 10, 12], [80, 12, 14], [99, 14, 16]]
const MONSTERS_GROOT := [[20, 15, 18], [50, 18, 22], [80, 22, 26], [99, 26, 30]]
## Vaste aantallen [min, max] per type (monsters, gewone kisten).
const MONSTERS_VAST := {KIST: [8, 10], VAL: [3, 5], PUZZEL: [0, 2], SCHAT: [0, 0], LEEG: [0, 0], RUST: [0, 0],
		KOOPMAN: [3, 5], BAAS: [4, 6], VLOER100: [0, 0]}
const KISTEN := {MEDIUM: [2, 4], GROOT: [6, 10], KIST: [3, 3], VAL: [0, 1], PUZZEL: [0, 0], SCHAT: [2, 3],
		LEEG: [0, 0], RUST: [0, 0], KOOPMAN: [0, 1], BAAS: [0, 1], VLOER100: [0, 0]}
## Blauwe kisten per type (CANON-overrides) zitten hier NIET: dat is de loot-taak (RPG CODE).

static func _hash(run_seed: int, floor_no: int, zout: int) -> int:
	var h: int = (run_seed * 31 + floor_no * 0x9E3779B1 + zout * 0x85EBCA6B) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 0x5BD1E995) & 0x7FFFFFFF
	return (h ^ (h >> 15)) & 0x7FFFFFFF


static func _rng(run_seed: int, floor_no: int, zout: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%d|layout|%s" % [run_seed, floor_no, zout])
	return rng


static func is_vast(floor_no: int) -> bool:
	return floor_no >= 100 or Scaling.is_boss_floor(floor_no)


## Mag dit type op deze verdieping gerold worden?
static func toegestaan(soort: String, floor_no: int) -> bool:
	match soort:
		PUZZEL:
			return PUZZEL_ACTIEF and floor_no >= PUZZEL_VANAF
		VAL:
			return floor_no >= VAL_VANAF
	return true


## De worp zonder buur-regels (ook gebruikt om de buren te bekijken).
static func gerold(run_seed: int, floor_no: int) -> String:
	var totaal := 0
	for s in VOLGORDE:
		if toegestaan(s, floor_no):
			totaal += int(KANSEN[s])
	var r := _hash(run_seed, floor_no, 11) % totaal
	for s in VOLGORDE:
		if not toegestaan(s, floor_no):
			continue
		r -= int(KANSEN[s])
		if r < 0:
			return s
	return MEDIUM


static func _is_rust(run_seed: int, floor_no: int, koopman_floor: Callable) -> bool:
	if floor_no < 1 or floor_no >= 100:
		return false
	if Rules.is_rest_floor(floor_no):
		return true
	if is_vast(floor_no) or koopman_floor.call(floor_no):
		return false
	return gerold(run_seed, floor_no) == RUST


## Het layout-type van een verdieping. 'koopman_floor' = Callable(floor_no) -> bool (GrotKamers geeft
## die mee, zodat er geen kringverwijzing is); zonder: geen koopmanverdiepingen.
static func soort(run_seed: int, floor_no: int, koopman_floor := Callable()) -> String:
	var kf := koopman_floor if koopman_floor.is_valid() else func(_f: int) -> bool: return false
	if floor_no >= 100:
		return VLOER100
	if Scaling.is_boss_floor(floor_no):
		return BAAS
	if kf.call(floor_no):
		return KOOPMAN
	var s := gerold(run_seed, floor_no)
	if s == SCHAT and (_is_rust(run_seed, floor_no - 1, kf) or _is_rust(run_seed, floor_no + 1, kf)):
		return MEDIUM
	return s


static func maat(soort_: String) -> Vector2i:
	return MAAT.get(soort_, MAAT_STANDAARD)


static func _bracket(tabel: Array, floor_no: int) -> Array:
	for b in tabel:
		if floor_no <= int(b[0]):
			return [int(b[1]), int(b[2])]
	var last: Array = tabel[tabel.size() - 1]
	return [int(last[1]), int(last[2])]


## [min, max] aantal monster-groepen voor dit type op deze verdieping.
static func monster_bereik(soort_: String, floor_no: int) -> Array:
	match soort_:
		MEDIUM:
			return _bracket(MONSTERS_MEDIUM, floor_no)
		GROOT:
			return _bracket(MONSTERS_GROOT, floor_no)
	return MONSTERS_VAST.get(soort_, [0, 0])


static func monsters(run_seed: int, floor_no: int, soort_: String) -> int:
	var b := monster_bereik(soort_, floor_no)
	return _rng(run_seed, floor_no, "monsters").randi_range(int(b[0]), int(b[1]))


static func kisten(run_seed: int, floor_no: int, soort_: String) -> int:
	var b: Array = KISTEN.get(soort_, [0, 0])
	return _rng(run_seed, floor_no, "kisten").randi_range(int(b[0]), int(b[1]))


## Minimale afstand (Manhattan) van monsters tot de ingang: kleiner in het kistkamertje.
static func min_afstand(soort_: String) -> int:
	return 3 if soort_ == KIST else 6
