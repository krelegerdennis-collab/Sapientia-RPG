class_name TelegraphShape
extends RefCounted
## Pure telegraafvorm (Combat T1, voorstel telegraaf-systeem sectie B). Geen nodes, geen scène, geen RNG,
## geen gedrag: alleen "ligt dit punt in de vorm?". Origin en richting liggen vast vanaf het maken
## (alleen getters), zodat T2/T4a de vorm bij de start van de windup kunnen vastzetten en de actieve
## ticks er alleen nog `contains()` op aanroepen.
##
## Vijf vormen (ids uit COMBAT_DESIGN.md §11):
##   melee_arc   - cirkelsector vanaf origin: reach + boek in graden (1..360; 360 = rondom, als de oude melee-check)
##   line        - rechthoek vanaf origin langs de richting: lengte x breedte (breedte om de as gecentreerd)
##   circle      - schijf om origin (richting telt niet)
##   cone        - cirkelsector vanaf de top (origin): reach + hoek in graden (1..180)
##   ground_ring - ring om origin: binnen- en buitenstraal (het gat telt niet; richting telt niet)
##
## Determinisme: alles is integer-rekenwerk in pixels. Randen tellen als geraakt (gesloten vormen).
## Hoeken lopen via een vaste integer-tabel (Q16), niet via sin/cos/atan2 van de float-bibliotheek,
## zodat host en gast (ander platform) op de rand dezelfde uitkomst geven.
## Ongeldige parameters (grootte 0 of negatief, richting nul bij een gerichte vorm, te groot) geven een
## vorm met `valid == false` die nooit raakt; er komt nooit een error of null terug.
##
## Coördinaten: pixels, y omlaag (zoals de arena). Richting 0 graden = +x, 90 graden = +y (omlaag).

enum Kind { MELEE_ARC, LINE, CIRCLE, CONE, GROUND_RING }

const KIND_IDS := {
	"melee_arc": Kind.MELEE_ARC,
	"line": Kind.LINE,
	"circle": Kind.CIRCLE,
	"cone": Kind.CONE,
	"ground_ring": Kind.GROUND_RING,
}

## Elke maat (reach, breedte, stralen) en elke afstand tot origin is begrensd; zo kunnen de kwadraten
## en producten in 64-bit nooit overlopen en is "ver weg" altijd gewoon "buiten".
const MAX_EXTENT := 1024
## Richtingsvector (geheel getal) mag per component maximaal zo groot zijn; lengte maakt niet uit.
const MAX_DIR_COMPONENT := 4096
## Schaal van `dir_from_vector` / `dir_from_degrees` (lengte van de gegenereerde richting).
const DIR_SCALE := 256
const MAX_CONE_DEG := 180
const MAX_ARC_DEG := 360

## cos(0..90 graden) x 65536, afgerond. Vaste literal-tabel: geen float-trig in de raak-check.
const _COS_Q16: PackedInt32Array = [
	65536, 65526, 65496, 65446, 65376, 65287, 65177, 65048, 64898,
	64729, 64540, 64332, 64104, 63856, 63589, 63303, 62997, 62672,
	62328, 61966, 61584, 61183, 60764, 60326, 59870, 59396, 58903,
	58393, 57865, 57319, 56756, 56175, 55578, 54963, 54332, 53684,
	53020, 52339, 51643, 50931, 50203, 49461, 48703, 47930, 47143,
	46341, 45525, 44695, 43852, 42995, 42126, 41243, 40348, 39441,
	38521, 37590, 36647, 35693, 34729, 33754, 32768, 31772, 30767,
	29753, 28729, 27697, 26656, 25607, 24550, 23486, 22415, 21336,
	20252, 19161, 18064, 16962, 15855, 14742, 13626, 12505, 11380,
	10252, 9121, 7987, 6850, 5712, 4572, 3430, 2287, 1144,
	0,
]

var _kind: int = Kind.CIRCLE
var _origin: Vector2i = Vector2i.ZERO
var _dir: Vector2i = Vector2i.ZERO
var _reach: int = 0
var _inner: int = 0
var _width: int = 0
var _angle_deg: int = 0
var _valid: bool = false
var _invalid_reason: String = ""
## Voorberekend voor sector-vormen: cos/sin van de halve hoek (Q16, niet-negatief) en of de halve hoek > 90 is.
var _wedge_c: int = 0
var _wedge_s: int = 0
var _wedge_wide: bool = false

var kind: int:
	get:
		return _kind
var origin: Vector2i:
	get:
		return _origin
var dir: Vector2i:
	get:
		return _dir
## Lijn: lengte; circle: straal; cone/melee_arc: reach; ground_ring: buitenstraal.
var reach: int:
	get:
		return _reach
## Alleen ground_ring (0 voor de andere vormen).
var inner: int:
	get:
		return _inner
## Alleen line: volle breedte.
var width: int:
	get:
		return _width
## Alleen cone/melee_arc: totale hoek in graden.
var angle_deg: int:
	get:
		return _angle_deg
var valid: bool:
	get:
		return _valid
var invalid_reason: String:
	get:
		return _invalid_reason


## Cirkel/schijf om `origin`.
static func make_circle(origin: Vector2i, radius: int) -> TelegraphShape:
	var s := TelegraphShape.new()
	s._kind = Kind.CIRCLE
	s._origin = origin
	s._reach = radius
	s._check_extent(radius, "radius")
	if s._invalid_reason == "" and radius <= 0:
		s._invalid_reason = "radius must be > 0"
	s._finish()
	return s


## Ring om `origin`: raakt waar inner <= afstand <= outer. `inner` mag 0 zijn (dan is het een schijf).
static func make_ring(origin: Vector2i, inner_radius: int, outer_radius: int) -> TelegraphShape:
	var s := TelegraphShape.new()
	s._kind = Kind.GROUND_RING
	s._origin = origin
	s._inner = inner_radius
	s._reach = outer_radius
	s._check_extent(outer_radius, "outer radius")
	if s._invalid_reason == "":
		if inner_radius < 0:
			s._invalid_reason = "inner radius must be >= 0"
		elif outer_radius <= inner_radius:
			s._invalid_reason = "outer radius must be > inner radius"
	s._finish()
	return s


## Rechthoek: begint op `origin`, loopt `length` px langs `direction`, volle `width` px breed om de as.
static func make_line(origin: Vector2i, direction: Vector2i, length: int, width: int) -> TelegraphShape:
	var s := TelegraphShape.new()
	s._kind = Kind.LINE
	s._origin = origin
	s._dir = direction
	s._reach = length
	s._width = width
	s._check_extent(length, "length")
	s._check_extent(width, "width")
	s._check_dir()
	if s._invalid_reason == "":
		if length <= 0:
			s._invalid_reason = "length must be > 0"
		elif width <= 0:
			s._invalid_reason = "width must be > 0"
	s._finish()
	return s


## Kegel: top op `origin`, opent in `direction`, totale hoek 1..180 graden, tot `reach` px.
static func make_cone(origin: Vector2i, direction: Vector2i, reach_px: int, angle_degrees: int) -> TelegraphShape:
	return _make_wedge(Kind.CONE, origin, direction, reach_px, angle_degrees, MAX_CONE_DEG)


## Melee-boog: zoals de kegel maar tot 360 graden (360 = rondom, gelijk aan de oude melee-afstandscheck).
static func make_melee_arc(origin: Vector2i, direction: Vector2i, reach_px: int, angle_degrees: int) -> TelegraphShape:
	return _make_wedge(Kind.MELEE_ARC, origin, direction, reach_px, angle_degrees, MAX_ARC_DEG)


## Data-gedreven (T4a: `attacks`-data). `shape` is een id uit KIND_IDS. Sleutels in `data` (alles int):
## reach (lijn: lengte, circle: straal, cone/melee_arc: reach, ground_ring: buitenstraal),
## width (lijn), angle (cone/melee_arc, graden), inner (ground_ring, standaard 0).
## Onbekende vorm of ontbrekende sleutel => ongeldige vorm (raakt nooit), geen error.
static func from_data(shape: String, origin: Vector2i, direction: Vector2i, data: Dictionary) -> TelegraphShape:
	var r: int = _int_or(data, "reach", 0)
	var k: int = KIND_IDS.get(shape, -1)
	match k:
		Kind.CIRCLE:
			return make_circle(origin, r)
		Kind.GROUND_RING:
			return make_ring(origin, _int_or(data, "inner", 0), r)
		Kind.LINE:
			return make_line(origin, direction, r, _int_or(data, "width", 0))
		Kind.CONE:
			return make_cone(origin, direction, r, _int_or(data, "angle", 0))
		Kind.MELEE_ARC:
			return make_melee_arc(origin, direction, r, _int_or(data, "angle", 0))
	var bad := TelegraphShape.new()
	bad._origin = origin
	bad._invalid_reason = "unknown shape '%s'" % shape
	bad._finish()
	return bad


## Float-positie -> pixel (afronden, .5 naar buiten). Niet-eindige waarden geven Vector2i.ZERO;
## `contains()` vangt die zelf al af.
static func to_px(v: Vector2) -> Vector2i:
	if not (is_finite(v.x) and is_finite(v.y)):
		return Vector2i.ZERO
	return Vector2i(roundi(v.x), roundi(v.y))


## Float-richting -> integer-richting met lengte ~DIR_SCALE. Nulvector of niet-eindig => Vector2i.ZERO
## (gerichte vormen zijn dan ongeldig). Alleen sqrt en delen: IEEE-exact, dus op elk platform gelijk.
static func dir_from_vector(v: Vector2) -> Vector2i:
	if not (is_finite(v.x) and is_finite(v.y)) or (v.x == 0.0 and v.y == 0.0):
		return Vector2i.ZERO
	var n := v.normalized()
	return Vector2i(roundi(n.x * DIR_SCALE), roundi(n.y * DIR_SCALE))


## Integer-richting uit hele graden via de vaste tabel (0 = +x, 90 = +y/omlaag). Lengte ~DIR_SCALE.
static func dir_from_degrees(degrees: int) -> Vector2i:
	return Vector2i((_cos_deg_q16(degrees) + 128) >> 8, (_cos_deg_q16(degrees - 90) + 128) >> 8)


## Ligt `point` (pixels, float) in de vorm? Rondt af op hele pixels (zie `to_px`); NaN/INF => false.
func contains(point: Vector2) -> bool:
	if not (is_finite(point.x) and is_finite(point.y)):
		return false
	if absf(point.x) > 1.0e9 or absf(point.y) > 1.0e9:
		return false
	return contains_i(Vector2i(roundi(point.x), roundi(point.y)))


## Zelfde als `contains`, maar al in hele pixels (tick-/integerpad, geen afronding nodig).
func contains_i(point: Vector2i) -> bool:
	if not _valid:
		return false
	var dx: int = point.x - _origin.x
	var dy: int = point.y - _origin.y
	if absi(dx) > MAX_EXTENT or absi(dy) > MAX_EXTENT:
		return false
	match _kind:
		Kind.CIRCLE:
			return dx * dx + dy * dy <= _reach * _reach
		Kind.GROUND_RING:
			var d2: int = dx * dx + dy * dy
			return d2 >= _inner * _inner and d2 <= _reach * _reach
		Kind.LINE:
			return _line_contains(dx, dy)
		Kind.CONE, Kind.MELEE_ARC:
			if dx * dx + dy * dy > _reach * _reach:
				return false
			return _wedge_contains(dx, dy)
	return false


static func _make_wedge(k: int, origin: Vector2i, direction: Vector2i, reach_px: int, angle_degrees: int, max_deg: int) -> TelegraphShape:
	var s := TelegraphShape.new()
	s._kind = k
	s._origin = origin
	s._dir = direction
	s._reach = reach_px
	s._angle_deg = angle_degrees
	s._check_extent(reach_px, "reach")
	s._check_dir()
	if s._invalid_reason == "":
		if reach_px <= 0:
			s._invalid_reason = "reach must be > 0"
		elif angle_degrees < 1 or angle_degrees > max_deg:
			s._invalid_reason = "angle must be 1..%d degrees" % max_deg
	s._finish()
	return s


static func _int_or(data: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = data.get(key, fallback)
	if typeof(v) == TYPE_INT:
		return v
	return fallback


func _check_extent(value: int, label: String) -> void:
	if _invalid_reason == "" and value > MAX_EXTENT:
		_invalid_reason = "%s exceeds %d" % [label, MAX_EXTENT]


func _check_dir() -> void:
	if _invalid_reason != "":
		return
	if _dir == Vector2i.ZERO:
		_invalid_reason = "direction must not be zero"
	elif absi(_dir.x) > MAX_DIR_COMPONENT or absi(_dir.y) > MAX_DIR_COMPONENT:
		_invalid_reason = "direction component exceeds %d" % MAX_DIR_COMPONENT


func _finish() -> void:
	_valid = _invalid_reason == ""
	if not _valid:
		return
	if _kind == Kind.CONE or _kind == Kind.MELEE_ARC:
		_prepare_wedge()


## Halve hoek in halve graden = totale hoek `k`. Tot 90 graden halve hoek: (cos, sin) uit de tabel; daarboven
## via de supplementhoek. Oneven totale hoeken middelen twee tabelwaarden (integer, vast).
func _prepare_wedge() -> void:
	var k: int = _angle_deg
	if k <= 180:
		_wedge_c = _cos_half_deg_q16(k)
		_wedge_s = _cos_half_deg_q16(180 - k)
		_wedge_wide = false
	else:
		_wedge_c = _cos_half_deg_q16(360 - k)
		_wedge_s = _cos_half_deg_q16(k - 180)
		_wedge_wide = true


## cos van `half_deg` halve graden (0..180 => 0..90 graden), Q16.
static func _cos_half_deg_q16(half_deg: int) -> int:
	var i: int = half_deg >> 1
	if half_deg & 1 == 0:
		return _COS_Q16[i]
	return (_COS_Q16[i] + _COS_Q16[i + 1]) >> 1


## cos van een willekeurig geheel aantal graden, Q16 (kan negatief zijn).
static func _cos_deg_q16(degrees: int) -> int:
	var d: int = posmod(degrees, 360)
	if d <= 90:
		return _COS_Q16[d]
	if d <= 180:
		return -_COS_Q16[180 - d]
	if d <= 270:
		return -_COS_Q16[d - 180]
	return _COS_Q16[360 - d]


func _line_contains(dx: int, dy: int) -> bool:
	var along: int = dx * _dir.x + dy * _dir.y
	if along < 0:
		return false
	var len2: int = _dir.x * _dir.x + _dir.y * _dir.y
	if along * along > _reach * _reach * len2:
		return false
	var across: int = _dir.x * dy - _dir.y * dx
	return 4 * across * across <= _width * _width * len2


## Hoek tussen (dx,dy) en de richting <= halve hoek, zonder wortels of atan2: vergelijk |cross|*cos met dot*sin.
## Het punt op de top zelf (0,0) telt als binnen.
func _wedge_contains(dx: int, dy: int) -> bool:
	var dot: int = dx * _dir.x + dy * _dir.y
	var cross: int = absi(_dir.x * dy - _dir.y * dx)
	if not _wedge_wide:
		return dot >= 0 and cross * _wedge_c <= dot * _wedge_s
	if dot >= 0:
		return true
	return cross * _wedge_c >= (-dot) * _wedge_s
