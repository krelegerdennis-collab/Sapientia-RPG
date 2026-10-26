extends Node
## TelegraphShape (Combat T1, scripts/som/telegraph_shape.gd): pure vormen + contains().
## Bewijst per vorm (melee_arc, line, circle, cone, ground_ring): binnen, buiten, rand, rotatie/richting,
## zero-size-guards, plus: vast na creatie, deterministisch, geen RNG, niet-eindige invoer.
## Geen scène en geen gameplay: alleen de pure klasse.
## Start: godot --headless --path . -- --telegraphtest

const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphStateTests := preload("res://scripts/tests/telegraph_state_tests.gd")
const TelegraphInktspuwTests := preload("res://scripts/tests/telegraph_inktspuw_tests.gd")
const TelegraphLayerTests := preload("res://scripts/tests/telegraph_layer_tests.gd")

const O := Vector2i(100, 100)

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_table_tests()
	_direction_tests()
	_circle_tests()
	_ring_tests()
	_line_tests()
	_line_rotation_tests()
	_cone_tests()
	_cone_rotation_tests()
	_arc_tests()
	_guard_tests()
	_input_tests()
	_lock_and_determinism_tests()
	_from_data_tests()
	TelegraphStateTests.new().run_all(self)
	TelegraphInktspuwTests.new().run_all(self)
	TelegraphLayerTests.new().run_all(self)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


## Punt relatief aan de origin van de vorm.
func _in(s: TelegraphShape, rel: Vector2i) -> bool:
	return s.contains_i(s.origin + rel)


func _rot90(v: Vector2i, quarter_turns: int) -> Vector2i:
	var r := v
	for i in posmod(quarter_turns, 4):
		r = Vector2i(-r.y, r.x)
	return r


## Aantal punten (relatief, raster -range..range) waar de vorm raakt.
func _count(s: TelegraphShape, range_px: int) -> int:
	var n := 0
	for y in range(-range_px, range_px + 1):
		for x in range(-range_px, range_px + 1):
			if _in(s, Vector2i(x, y)):
				n += 1
	return n


# --- tabel en richting ---------------------------------------------------------------------------

func _table_tests() -> void:
	var t: PackedInt32Array = TelegraphShape._COS_Q16
	check("cos-tabel: 91 waarden, cos(0)=65536, cos(90)=0", t.size() == 91 and t[0] == 65536 and t[90] == 0)
	var mono := true
	var pyth := true
	for d in 90:
		if t[d] <= t[d + 1]:
			mono = false
	for d in 91:
		var sq: int = t[d] * t[d] + t[90 - d] * t[90 - d]
		if absi(sq - 65536 * 65536) > 70000:
			pyth = false
	check("cos-tabel: strikt dalend", mono)
	check("cos-tabel: cos^2 + sin^2 = 1 (binnen afronding)", pyth)
	var exact := true
	for d in 91:
		if t[d] != roundi(cos(deg_to_rad(d)) * 65536.0):
			exact = false
	check("cos-tabel: gelijk aan afgeronde cos(d) x 65536", exact)
	check("cos 45 = 46341", t[45] == 46341)


func _direction_tests() -> void:
	check("dir_from_degrees(0) = +x", TelegraphShape.dir_from_degrees(0) == Vector2i(256, 0))
	check("dir_from_degrees(90) = +y (omlaag)", TelegraphShape.dir_from_degrees(90) == Vector2i(0, 256))
	check("dir_from_degrees(180) = -x", TelegraphShape.dir_from_degrees(180) == Vector2i(-256, 0))
	check("dir_from_degrees(270) = -y", TelegraphShape.dir_from_degrees(270) == Vector2i(0, -256))
	check("dir_from_degrees(45) = (181,181)", TelegraphShape.dir_from_degrees(45) == Vector2i(181, 181))
	check("dir_from_degrees(135) = (-181,181)", TelegraphShape.dir_from_degrees(135) == Vector2i(-181, 181))
	check("dir_from_degrees wikkelt (360, -90, 450)", TelegraphShape.dir_from_degrees(360) == Vector2i(256, 0)
			and TelegraphShape.dir_from_degrees(-90) == Vector2i(0, -256)
			and TelegraphShape.dir_from_degrees(450) == Vector2i(0, 256))
	var lens_ok := true
	for d in 360:
		var v := TelegraphShape.dir_from_degrees(d)
		var l := sqrt(float(v.x * v.x + v.y * v.y))
		if absf(l - 256.0) > 1.0:
			lens_ok = false
	check("dir_from_degrees: lengte ~256 voor alle 360 graden", lens_ok)
	check("dir_from_vector((10,0)) = (256,0)", TelegraphShape.dir_from_vector(Vector2(10, 0)) == Vector2i(256, 0))
	check("dir_from_vector((0,-3)) = (0,-256)", TelegraphShape.dir_from_vector(Vector2(0, -3)) == Vector2i(0, -256))
	check("dir_from_vector((7,7)) = (181,181)", TelegraphShape.dir_from_vector(Vector2(7, 7)) == Vector2i(181, 181))
	check("dir_from_vector(nul) = ZERO", TelegraphShape.dir_from_vector(Vector2.ZERO) == Vector2i.ZERO)
	check("dir_from_vector(NaN/INF) = ZERO", TelegraphShape.dir_from_vector(Vector2(NAN, 1)) == Vector2i.ZERO
			and TelegraphShape.dir_from_vector(Vector2(INF, 0)) == Vector2i.ZERO)
	check("dir_from_vector is nooit nul voor een niet-nul invoer", TelegraphShape.dir_from_vector(Vector2(0.0001, 0.0)) != Vector2i.ZERO)
	check("to_px rondt .5 naar buiten", TelegraphShape.to_px(Vector2(2.5, -2.5)) == Vector2i(3, -3)
			and TelegraphShape.to_px(Vector2(2.4, -2.4)) == Vector2i(2, -2))
	check("to_px(NaN) = ZERO", TelegraphShape.to_px(Vector2(NAN, 0)) == Vector2i.ZERO)


# --- circle --------------------------------------------------------------------------------------

func _circle_tests() -> void:
	var s := TelegraphShape.make_circle(O, 16)
	check("circle: geldig, kind en maten", s.valid and s.kind == TelegraphShape.Kind.CIRCLE and s.reach == 16 and s.origin == O)
	check("circle: middelpunt binnen", s.contains_i(O))
	check("circle: rand (r, 0) binnen", _in(s, Vector2i(16, 0)))
	check("circle: net buiten (r+1, 0)", not _in(s, Vector2i(17, 0)))
	check("circle: rand links/boven/onder binnen", _in(s, Vector2i(-16, 0)) and _in(s, Vector2i(0, -16)) and _in(s, Vector2i(0, 16)))
	check("circle: net buiten links/boven/onder", not _in(s, Vector2i(-17, 0)) and not _in(s, Vector2i(0, -17)) and not _in(s, Vector2i(0, 17)))
	check("circle: diagonaal (11,11) binnen (242 <= 256)", _in(s, Vector2i(11, 11)))
	check("circle: diagonaal (12,12) buiten (288 > 256)", not _in(s, Vector2i(12, 12)))
	var s15 := TelegraphShape.make_circle(O, 15)
	check("circle: 3-4-5 rand (9,12) binnen, (10,12) buiten", _in(s15, Vector2i(9, 12)) and not _in(s15, Vector2i(10, 12)))
	check("circle: ver weg buiten", not _in(s, Vector2i(500, 500)) and not s.contains_i(Vector2i(100000, 100)))
	check("circle: richting telt niet", TelegraphShape.make_circle(O, 16).contains_i(O + Vector2i(0, 16))
			and _count(TelegraphShape.make_circle(O, 5), 8) == 81)
	var big := TelegraphShape.make_circle(O, TelegraphShape.MAX_EXTENT)
	check("circle: maximale straal werkt, rand binnen", big.valid and _in(big, Vector2i(TelegraphShape.MAX_EXTENT, 0))
			and not _in(big, Vector2i(TelegraphShape.MAX_EXTENT, 1)))
	var one := TelegraphShape.make_circle(O, 1)
	check("circle: straal 1 = plus-vorm (5 punten)", _count(one, 3) == 5)


# --- ground_ring ---------------------------------------------------------------------------------

func _ring_tests() -> void:
	var s := TelegraphShape.make_ring(O, 8, 24)
	check("ring: geldig, kind en maten", s.valid and s.kind == TelegraphShape.Kind.GROUND_RING and s.inner == 8 and s.reach == 24)
	check("ring: middelpunt (het gat) veilig", not s.contains_i(O))
	check("ring: in het gat veilig (7,0)", not _in(s, Vector2i(7, 0)))
	check("ring: binnenrand (8,0) raakt", _in(s, Vector2i(8, 0)))
	check("ring: in de band (16,0) raakt", _in(s, Vector2i(16, 0)))
	check("ring: buitenrand (24,0) raakt", _in(s, Vector2i(24, 0)))
	check("ring: net buiten (25,0) veilig", not _in(s, Vector2i(25, 0)))
	check("ring: binnenrand alle kanten", _in(s, Vector2i(-8, 0)) and _in(s, Vector2i(0, 8)) and _in(s, Vector2i(0, -8)))
	check("ring: gat alle kanten", not _in(s, Vector2i(-7, 0)) and not _in(s, Vector2i(0, 7)) and not _in(s, Vector2i(0, -7)))
	check("ring: diagonaal gat (5,5) veilig (50 < 64), (6,6) raakt (72 >= 64)", not _in(s, Vector2i(5, 5)) and _in(s, Vector2i(6, 6)))
	check("ring: diagonaal buitenrand (17,17) buiten (578 > 576), (16,16) raakt", not _in(s, Vector2i(17, 17)) and _in(s, Vector2i(16, 16)))
	var disc := TelegraphShape.make_ring(O, 0, 10)
	check("ring: inner 0 = schijf, middelpunt raakt", disc.valid and disc.contains_i(O) and _in(disc, Vector2i(10, 0)) and not _in(disc, Vector2i(11, 0)))
	var thin := TelegraphShape.make_ring(O, 9, 10)
	check("ring: dunne ring raakt alleen 9..10", not _in(thin, Vector2i(8, 0)) and _in(thin, Vector2i(9, 0)) and _in(thin, Vector2i(10, 0)) and not _in(thin, Vector2i(11, 0)))
	var consistent := true
	for y in range(-30, 31):
		for x in range(-30, 31):
			var d2 := x * x + y * y
			if _in(s, Vector2i(x, y)) != (d2 >= 64 and d2 <= 576):
				consistent = false
	check("ring == {64 <= x^2 + y^2 <= 576} op het hele raster (onafhankelijk orakel)", consistent)


# --- line ----------------------------------------------------------------------------------------

func _line_tests() -> void:
	var s := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(0), 64, 16)
	check("line: geldig, kind en maten", s.valid and s.kind == TelegraphShape.Kind.LINE and s.reach == 64 and s.width == 16 and s.dir == Vector2i(256, 0))
	check("line: startpunt (origin) binnen", s.contains_i(O))
	check("line: midden (32,0) binnen", _in(s, Vector2i(32, 0)))
	check("line: einde (64,0) binnen (rand)", _in(s, Vector2i(64, 0)))
	check("line: voorbij het einde (65,0) buiten", not _in(s, Vector2i(65, 0)))
	check("line: achter de start (-1,0) buiten", not _in(s, Vector2i(-1, 0)))
	check("line: zijrand (30,8) binnen", _in(s, Vector2i(30, 8)) and _in(s, Vector2i(30, -8)))
	check("line: net naast de rand (30,9) buiten", not _in(s, Vector2i(30, 9)) and not _in(s, Vector2i(30, -9)))
	check("line: hoek (64,8) binnen, (65,8) en (64,9) buiten", _in(s, Vector2i(64, 8)) and not _in(s, Vector2i(65, 8)) and not _in(s, Vector2i(64, 9)))
	check("line: hoek bij de start (0,8) binnen, (-1,8) buiten", _in(s, Vector2i(0, 8)) and not _in(s, Vector2i(-1, 8)))
	check("line: oppervlak = 65 x 17 punten", _count(s, 80) == 65 * 17)
	var odd := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(0), 40, 15)
	check("line: oneven breedte 15: |y| <= 7 binnen, 8 buiten", _in(odd, Vector2i(10, 7)) and _in(odd, Vector2i(10, -7))
			and not _in(odd, Vector2i(10, 8)) and not _in(odd, Vector2i(10, -8)))
	var thin := TelegraphShape.make_line(O, Vector2i(1, 0), 10, 1)
	check("line: breedte 1: alleen de as (|y| <= 0)", _in(thin, Vector2i(5, 0)) and not _in(thin, Vector2i(5, 1)) and not _in(thin, Vector2i(5, -1)))
	var unit := TelegraphShape.make_line(O, Vector2i(1, 0), 10, 4)
	var long_dir := TelegraphShape.make_line(O, Vector2i(4000, 0), 10, 4)
	check("line: lengte van de richtingsvector maakt niet uit (1 vs 4000)", _count(unit, 20) == _count(long_dir, 20) and _count(unit, 20) > 0)


func _line_rotation_tests() -> void:
	var base := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(0), 64, 16)
	for q in 4:
		var rotated := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(90 * q), 64, 16)
		var same := true
		for y in range(-80, 81):
			for x in range(-80, 81):
				var p := Vector2i(x, y)
				if _in(base, p) != _in(rotated, _rot90(p, q)):
					same = false
		check("line: %d graden = exact gedraaid raster (alle punten)" % (90 * q), same and rotated.valid)
	var south := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(90), 64, 16)
	check("line zuid: (0,64) binnen, (0,65) buiten, (8,30) binnen, (9,30) buiten, (0,-1) buiten",
			_in(south, Vector2i(0, 64)) and not _in(south, Vector2i(0, 65)) and _in(south, Vector2i(8, 30))
			and not _in(south, Vector2i(9, 30)) and not _in(south, Vector2i(0, -1)))
	var west := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(180), 64, 16)
	check("line west: (-64,0) binnen, (-65,0) buiten, (1,0) buiten", _in(west, Vector2i(-64, 0)) and not _in(west, Vector2i(-65, 0)) and not _in(west, Vector2i(1, 0)))
	var north := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(270), 64, 16)
	check("line noord: (0,-64) binnen, (0,-65) buiten, (0,1) buiten", _in(north, Vector2i(0, -64)) and not _in(north, Vector2i(0, -65)) and not _in(north, Vector2i(0, 1)))
	var diag := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(45), 64, 16)
	check("line 45: as-punt (40,40) binnen (56.6 px)", _in(diag, Vector2i(40, 40)))
	check("line 45: voorbij het einde (46,46) buiten (65.1 px)", not _in(diag, Vector2i(46, 46)))
	check("line 45: zijpunt (-5,5) binnen (afstand 7.1 <= 8)", _in(diag, Vector2i(20, 20) + Vector2i(-5, 5)))
	check("line 45: zijpunt (-7,7) buiten (afstand 9.9 > 8)", not _in(diag, Vector2i(20, 20) + Vector2i(-7, 7)))
	check("line 45: loodrecht (30,0) buiten", not _in(diag, Vector2i(30, 0)))
	var from_vec := TelegraphShape.make_line(O, TelegraphShape.dir_from_vector(Vector2(3, 4)), 50, 10)
	check("line uit dir_from_vector((3,4)): (30,40) binnen (50 px), (33,44) buiten", _in(from_vec, Vector2i(30, 40)) and not _in(from_vec, Vector2i(33, 44)))
	var mirror_ok := true
	var a := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(30), 60, 12)
	var b := TelegraphShape.make_line(O, TelegraphShape.dir_from_degrees(-30), 60, 12)
	for y in range(-70, 71):
		for x in range(-70, 71):
			if _in(a, Vector2i(x, y)) != _in(b, Vector2i(x, -y)):
				mirror_ok = false
	check("line: +30 en -30 graden zijn elkaars spiegelbeeld (y)", mirror_ok)


# --- cone ----------------------------------------------------------------------------------------

func _cone_tests() -> void:
	var s := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 32, 90)
	check("cone: geldig, kind en maten", s.valid and s.kind == TelegraphShape.Kind.CONE and s.reach == 32 and s.angle_deg == 90)
	check("cone: de top (origin) binnen", s.contains_i(O))
	check("cone: op de as (32,0) binnen (reach-rand)", _in(s, Vector2i(32, 0)))
	check("cone: voorbij de reach (33,0) buiten", not _in(s, Vector2i(33, 0)))
	check("cone: achter de top (-1,0) buiten", not _in(s, Vector2i(-1, 0)))
	check("cone: 45-gradenrand (10,10) binnen (rand telt)", _in(s, Vector2i(10, 10)) and _in(s, Vector2i(10, -10)))
	check("cone: net buiten de rand (10,11) buiten", not _in(s, Vector2i(10, 11)) and not _in(s, Vector2i(10, -11)))
	check("cone: net binnen de rand (11,10) binnen", _in(s, Vector2i(11, 10)))
	check("cone: (22,22) op de 45-gradenrand en binnen de reach (968 <= 1024)", _in(s, Vector2i(22, 22)))
	check("cone: (23,23) buiten de reach (1058 > 1024)", not _in(s, Vector2i(23, 23)))
	var c70 := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 32, 70)
	check("cone 70: (20,14) binnen (tan 0.700 < tan 35 = 0.7002)", _in(c70, Vector2i(20, 14)))
	check("cone 70: (20,15) buiten (tan 0.75)", not _in(c70, Vector2i(20, 15)))
	check("cone 70: (24,16) binnen, (28,16) buiten reach (1040 > 1024)", _in(c70, Vector2i(24, 16)) and not _in(c70, Vector2i(28, 16)))
	check("cone 70: symmetrisch in y", _in(c70, Vector2i(20, -14)) and not _in(c70, Vector2i(20, -15)))
	var narrow := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 100, 1)
	check("cone 1 graad: as binnen, (100,1) buiten (tan 0.01 > tan 0.5 graad = 0.0087)", _in(narrow, Vector2i(100, 0)) and not _in(narrow, Vector2i(100, 1)))
	check("cone 1 graad: (50,1) buiten (tan 0.02)", not _in(narrow, Vector2i(50, 1)))
	var half := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 32, 180)
	check("cone 180 = halfvlak: (0,10) rand binnen, (-1,10) buiten, (0,-10) rand binnen, (10,31) binnen", _in(half, Vector2i(0, 10))
			and not _in(half, Vector2i(-1, 10)) and _in(half, Vector2i(0, -10)) and _in(half, Vector2i(10, 30)))
	check("cone 180: (0,32) rand binnen, (0,33) buiten (reach)", _in(half, Vector2i(0, 32)) and not _in(half, Vector2i(0, 33)))
	var odd := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 200, 71)
	check("cone 71 (halve hoek 35,5; tan 0.7133): (100,71) binnen, (100,72) buiten", _in(odd, Vector2i(100, 71)) and not _in(odd, Vector2i(100, 72)))
	var even := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 200, 70)
	var wide := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 200, 72)
	check("cone: oppervlak groeit monotoon met de hoek (70 < 71 < 72)", _count(even, 40) < _count(odd, 40) and _count(odd, 40) < _count(wide, 40))
	var mono := true
	var last := 0
	for ang in range(1, 181):
		var n := _count(TelegraphShape.make_cone(O, Vector2i(256, 0), 20, ang), 20)
		if n < last:
			mono = false
		last = n
	check("cone: oppervlak is voor 1..180 graden nooit kleiner bij een grotere hoek", mono)


func _cone_rotation_tests() -> void:
	var base := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 48, 70)
	for q in 4:
		var rotated := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(90 * q), 48, 70)
		var same := true
		for y in range(-60, 61):
			for x in range(-60, 61):
				var p := Vector2i(x, y)
				if _in(base, p) != _in(rotated, _rot90(p, q)):
					same = false
		check("cone: %d graden = exact gedraaid raster (alle punten)" % (90 * q), same and rotated.valid)
	var south := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(90), 32, 90)
	check("cone zuid: (0,30) binnen, (0,-1) buiten, (10,10) rand binnen, (11,10) buiten", _in(south, Vector2i(0, 30)) and not _in(south, Vector2i(0, -1))
			and _in(south, Vector2i(10, 10)) and not _in(south, Vector2i(11, 10)))
	var west := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(180), 32, 90)
	check("cone west: (-30,0) binnen, (1,0) buiten", _in(west, Vector2i(-30, 0)) and not _in(west, Vector2i(1, 0)))
	var diag := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(45), 40, 40)
	check("cone 45 graden richting, 40 graden hoek: (20,20) binnen, (28,0) buiten, (0,28) buiten", _in(diag, Vector2i(20, 20))
			and not _in(diag, Vector2i(28, 0)) and not _in(diag, Vector2i(0, 28)))
	check("cone 45/40: (24,12) binnen (18.4 graden van de as, halve hoek 20), (30,5) buiten (35.5 graden van de as)",
			_in(diag, Vector2i(24, 12)) and not _in(diag, Vector2i(30, 5)))
	var from_vec := TelegraphShape.make_cone(O, TelegraphShape.dir_from_vector(Vector2(-1, -1)), 40, 90)
	check("cone uit dir_from_vector((-1,-1)): (-20,-20) binnen, (20,20) buiten, (-31,0) rand binnen, (-31,1) buiten",
			_in(from_vec, Vector2i(-20, -20)) and not _in(from_vec, Vector2i(20, 20)) and _in(from_vec, Vector2i(-31, 0)) and not _in(from_vec, Vector2i(-31, 1)))
	var mirror_ok := true
	var a := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(20), 60, 50)
	var b := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(-20), 60, 50)
	for y in range(-70, 71):
		for x in range(-70, 71):
			if _in(a, Vector2i(x, y)) != _in(b, Vector2i(x, -y)):
				mirror_ok = false
	check("cone: +20 en -20 graden zijn elkaars spiegelbeeld (y)", mirror_ok)


# --- melee_arc -----------------------------------------------------------------------------------

func _arc_tests() -> void:
	var s := TelegraphShape.make_melee_arc(O, TelegraphShape.dir_from_degrees(0), 32, 120)
	check("arc: geldig, kind en maten", s.valid and s.kind == TelegraphShape.Kind.MELEE_ARC and s.reach == 32 and s.angle_deg == 120)
	check("arc 120: voor de aanvaller (20,0) binnen, achter (-1,0) buiten", _in(s, Vector2i(20, 0)) and not _in(s, Vector2i(-1, 0)))
	check("arc 120: (10,17) binnen (tan 1.7 < 1.732), (10,18) buiten", _in(s, Vector2i(10, 17)) and not _in(s, Vector2i(10, 18)))
	check("arc 120: reach-rand (32,0) binnen, (33,0) buiten", _in(s, Vector2i(32, 0)) and not _in(s, Vector2i(33, 0)))
	check("arc 120: de aanvaller zelf (origin) binnen", s.contains_i(O))
	var wide := TelegraphShape.make_melee_arc(O, TelegraphShape.dir_from_degrees(0), 32, 270)
	check("arc 270 (halve hoek 135): (-10,10) rand binnen, (-10,11) binnen, (-10,9) buiten, (-10,0) recht achter buiten",
			_in(wide, Vector2i(-10, 10)) and _in(wide, Vector2i(-10, 11)) and not _in(wide, Vector2i(-10, 9)) and not _in(wide, Vector2i(-10, 0)))
	check("arc 270: voor en zijkant binnen ((10,0), (0,10), (0,-10))", _in(wide, Vector2i(10, 0)) and _in(wide, Vector2i(0, 10)) and _in(wide, Vector2i(0, -10)))
	var wide_s := TelegraphShape.make_melee_arc(O, TelegraphShape.dir_from_degrees(90), 32, 270)
	check("arc 270 zuid: (0,-10) recht achter buiten, (10,-10) rand binnen, (0,10) binnen",
			not _in(wide_s, Vector2i(0, -10)) and _in(wide_s, Vector2i(10, -10)) and _in(wide_s, Vector2i(0, 10)))
	var full := TelegraphShape.make_melee_arc(O, TelegraphShape.dir_from_degrees(0), 32, 360)
	var disc := TelegraphShape.make_circle(O, 32)
	var same := true
	for y in range(-40, 41):
		for x in range(-40, 41):
			if _in(full, Vector2i(x, y)) != _in(disc, Vector2i(x, y)):
				same = false
	check("arc 360 == circle(reach) overal (oude melee-check blijft uitdrukbaar)", same)
	var full_rot := TelegraphShape.make_melee_arc(O, TelegraphShape.dir_from_degrees(137), 32, 360)
	check("arc 360: richting maakt niet uit", _count(full_rot, 40) == _count(disc, 40))
	var same180 := true
	var arc180 := TelegraphShape.make_melee_arc(O, TelegraphShape.dir_from_degrees(0), 32, 180)
	var cone180 := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(0), 32, 180)
	for y in range(-40, 41):
		for x in range(-40, 41):
			if _in(arc180, Vector2i(x, y)) != _in(cone180, Vector2i(x, y)):
				same180 = false
	check("arc 180 == cone 180 (zelfde geometrie, ander id)", same180)
	var mono := true
	var last := 0
	for ang in range(1, 361):
		var n := _count(TelegraphShape.make_melee_arc(O, Vector2i(256, 0), 16, ang), 16)
		if n < last:
			mono = false
		last = n
	check("arc: oppervlak is voor 1..360 graden nooit kleiner bij een grotere hoek", mono)
	var rot_ok := true
	for q in 4:
		var r := TelegraphShape.make_melee_arc(O, TelegraphShape.dir_from_degrees(90 * q), 32, 270)
		for y in range(-40, 41):
			for x in range(-40, 41):
				var p := Vector2i(x, y)
				if _in(wide, p) != _in(r, _rot90(p, q)):
					rot_ok = false
	check("arc 270: 0/90/180/270 graden = exact gedraaid raster", rot_ok)


# --- zero-size guards en ongeldige invoer ----------------------------------------------------------

func _all_miss(s: TelegraphShape) -> bool:
	if s.contains_i(s.origin) or s.contains(Vector2(s.origin)):
		return false
	return _count(s, 12) == 0


func _guard_tests() -> void:
	var cases := {
		"circle radius 0": TelegraphShape.make_circle(O, 0),
		"circle radius -5": TelegraphShape.make_circle(O, -5),
		"circle radius > MAX": TelegraphShape.make_circle(O, TelegraphShape.MAX_EXTENT + 1),
		"ring outer 0": TelegraphShape.make_ring(O, 0, 0),
		"ring outer == inner": TelegraphShape.make_ring(O, 8, 8),
		"ring inner > outer": TelegraphShape.make_ring(O, 10, 5),
		"ring inner < 0": TelegraphShape.make_ring(O, -1, 5),
		"ring outer > MAX": TelegraphShape.make_ring(O, 0, TelegraphShape.MAX_EXTENT + 1),
		"line length 0": TelegraphShape.make_line(O, Vector2i(256, 0), 0, 8),
		"line length -1": TelegraphShape.make_line(O, Vector2i(256, 0), -1, 8),
		"line width 0": TelegraphShape.make_line(O, Vector2i(256, 0), 32, 0),
		"line width -3": TelegraphShape.make_line(O, Vector2i(256, 0), 32, -3),
		"line zero direction": TelegraphShape.make_line(O, Vector2i.ZERO, 32, 8),
		"line direction too large": TelegraphShape.make_line(O, Vector2i(TelegraphShape.MAX_DIR_COMPONENT + 1, 0), 32, 8),
		"line length > MAX": TelegraphShape.make_line(O, Vector2i(256, 0), TelegraphShape.MAX_EXTENT + 1, 8),
		"line width > MAX": TelegraphShape.make_line(O, Vector2i(256, 0), 32, TelegraphShape.MAX_EXTENT + 1),
		"cone reach 0": TelegraphShape.make_cone(O, Vector2i(256, 0), 0, 60),
		"cone reach -4": TelegraphShape.make_cone(O, Vector2i(256, 0), -4, 60),
		"cone angle 0": TelegraphShape.make_cone(O, Vector2i(256, 0), 32, 0),
		"cone angle -10": TelegraphShape.make_cone(O, Vector2i(256, 0), 32, -10),
		"cone angle 181": TelegraphShape.make_cone(O, Vector2i(256, 0), 32, 181),
		"cone zero direction": TelegraphShape.make_cone(O, Vector2i.ZERO, 32, 60),
		"cone reach > MAX": TelegraphShape.make_cone(O, Vector2i(256, 0), TelegraphShape.MAX_EXTENT + 1, 60),
		"arc reach 0": TelegraphShape.make_melee_arc(O, Vector2i(256, 0), 0, 90),
		"arc angle 0": TelegraphShape.make_melee_arc(O, Vector2i(256, 0), 32, 0),
		"arc angle 361": TelegraphShape.make_melee_arc(O, Vector2i(256, 0), 32, 361),
		"arc zero direction": TelegraphShape.make_melee_arc(O, Vector2i.ZERO, 32, 90),
	}
	for label in cases:
		var s: TelegraphShape = cases[label]
		check("guard: %s => ongeldig, raakt nergens, met reden" % label, not s.valid and s.invalid_reason != "" and _all_miss(s))
	var ok_cases := [
		TelegraphShape.make_circle(O, 1),
		TelegraphShape.make_ring(O, 0, 1),
		TelegraphShape.make_line(O, Vector2i(1, 0), 1, 1),
		TelegraphShape.make_cone(O, Vector2i(0, -1), 1, 1),
		TelegraphShape.make_cone(O, Vector2i(256, 0), 32, 180),
		TelegraphShape.make_melee_arc(O, Vector2i(256, 0), 1, 360),
		TelegraphShape.make_circle(O, TelegraphShape.MAX_EXTENT),
		TelegraphShape.make_line(O, Vector2i(TelegraphShape.MAX_DIR_COMPONENT, -TelegraphShape.MAX_DIR_COMPONENT), TelegraphShape.MAX_EXTENT, TelegraphShape.MAX_EXTENT),
	]
	var all_valid := true
	for s in ok_cases:
		if not s.valid or s.invalid_reason != "":
			all_valid = false
	check("guard: kleinste/grootste toegestane maten zijn geldig", all_valid)
	check("guard: kleinste circle (r=1) raakt het middelpunt", ok_cases[0].contains_i(O))
	check("guard: kleinste line (1x1) raakt het startpunt", ok_cases[2].contains_i(O))
	var worst: TelegraphShape = ok_cases[7]
	check("guard: grootste line + grootste richting rekent zonder overflow",
			worst.contains_i(O) and worst.contains_i(O + Vector2i(700, -700)) and not worst.contains_i(O + Vector2i(-1, 1000)))
	var reasons := {}
	for label in cases:
		reasons[(cases[label] as TelegraphShape).invalid_reason] = true
	check("guard: redenen zijn onderscheidend (>= 8 verschillende)", reasons.size() >= 8)


func _input_tests() -> void:
	var s := TelegraphShape.make_circle(O, 16)
	check("input: NaN/INF is nooit binnen", not s.contains(Vector2(NAN, 100)) and not s.contains(Vector2(100, NAN))
			and not s.contains(Vector2(INF, 100)) and not s.contains(Vector2(-INF, 100)))
	check("input: enorme float is buiten (geen overflow)", not s.contains(Vector2(1.0e12, 1.0e12)) and not s.contains(Vector2(-1.0e18, 0)))
	check("input: grote integer is buiten", not s.contains_i(Vector2i(2000000000, 100)) and not s.contains_i(Vector2i(-2000000000, -2000000000)))
	check("input: float wordt afgerond (116.4 binnen, 116.5 -> 117 buiten)", s.contains(Vector2(116.4, 100.0)) and not s.contains(Vector2(116.5, 100.0)))
	check("input: links van de origin (83.6 en 83.5 ronden af naar 84, binnen)", s.contains(Vector2(83.6, 100.0)) and s.contains(Vector2(83.5, 100.0)))
	check("input: contains(Vector2) == contains_i(afgerond)", s.contains(Vector2(110.2, 108.7)) == s.contains_i(Vector2i(110, 109)))
	var line := TelegraphShape.make_line(O, Vector2i(256, 0), 64, 16)
	check("input: line met NaN is niet binnen", not line.contains(Vector2(NAN, NAN)))
	var cone := TelegraphShape.make_cone(O, Vector2i(256, 0), 64, 60)
	check("input: cone met INF is niet binnen", not cone.contains(Vector2(INF, INF)))
	var neg := TelegraphShape.make_circle(Vector2i(-50, -70), 10)
	check("negatieve origin: werkt (middelpunt, rand, net buiten)", neg.contains_i(Vector2i(-50, -70)) and neg.contains_i(Vector2i(-40, -70)) and not neg.contains_i(Vector2i(-39, -70)))
	var zero := TelegraphShape.make_line(Vector2i.ZERO, Vector2i(0, 256), 32, 8)
	check("origin (0,0): line omlaag werkt", zero.contains_i(Vector2i(0, 32)) and not zero.contains_i(Vector2i(0, 33)) and zero.contains_i(Vector2i(4, 10)) and not zero.contains_i(Vector2i(5, 10)))


# --- vast na creatie, deterministisch -------------------------------------------------------------

func _lock_and_determinism_tests() -> void:
	var o := Vector2i(40, 50)
	var d := Vector2i(256, 0)
	var s := TelegraphShape.make_line(o, d, 64, 16)
	var before := _count(s, 100)
	o = Vector2i(900, 900)
	d = Vector2i(0, 256)
	check("vast: origin en richting zijn bij het maken gekopieerd (latere wijziging van de invoer raakt de vorm niet)",
			s.origin == Vector2i(40, 50) and s.dir == Vector2i(256, 0) and _count(s, 100) == before)
	var data := {"reach": 40, "width": 10}
	var from_data := TelegraphShape.from_data("line", Vector2i(10, 10), Vector2i(256, 0), data)
	data["reach"] = 5
	data["width"] = 99
	check("vast: from_data kopieert de maten (latere wijziging van de dictionary raakt de vorm niet)",
			from_data.reach == 40 and from_data.width == 10 and from_data.contains_i(Vector2i(50, 10)))
	var a := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(33), 60, 77)
	var b := TelegraphShape.make_cone(O, TelegraphShape.dir_from_degrees(33), 60, 77)
	var same := true
	for y in range(-70, 71):
		for x in range(-70, 71):
			if _in(a, Vector2i(x, y)) != _in(b, Vector2i(x, y)):
				same = false
	check("deterministisch: twee gelijke vormen geven op het hele raster dezelfde uitkomst", same)
	var first := _count(a, 70)
	var repeat_ok := true
	for i in 5:
		if _count(a, 70) != first:
			repeat_ok = false
	check("deterministisch: herhaald aanroepen verandert niets (pure functie)", repeat_ok)
	var float_pts_ok := true
	for i in 200:
		var p := Vector2(float((i * 37) % 160) - 80.0 + 0.31, float((i * 91) % 160) - 80.0 - 0.27) + Vector2(O)
		if a.contains(p) != a.contains_i(TelegraphShape.to_px(p)):
			float_pts_ok = false
	check("deterministisch: contains(float) == contains_i(to_px(float)) voor 200 punten", float_pts_ok)
	var src := FileAccess.get_file_as_string("res://scripts/som/telegraph_shape.gd")
	var code := ""
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	check("geen RNG, tijd, scène of node in de klasse", not (code.contains("randi") or code.contains("randf") or code.contains("RandomNumberGenerator")
			or code.contains("shuffle") or code.contains("Time.") or code.contains("get_node") or code.contains("get_tree")
			or code.contains("extends Node") or code.contains("preload(") or code.contains("load(")))
	check("geen float-trig in de raak-check (sin/cos/atan/acos alleen in de commentaar)",
			not (code.contains("sin(") or code.contains("cos(") or code.contains("atan") or code.contains("acos") or code.contains("asin") or code.contains("deg_to_rad")))
	var as_object: Object = s
	check("klasse is een RefCounted zonder scène (pure klasse)", as_object is RefCounted and not (as_object is Node))


# --- from_data ----------------------------------------------------------------------------------

func _from_data_tests() -> void:
	check("KIND_IDS bevat de 5 id's uit COMBAT_DESIGN.md §11", TelegraphShape.KIND_IDS.size() == 5
			and TelegraphShape.KIND_IDS.has("melee_arc") and TelegraphShape.KIND_IDS.has("line") and TelegraphShape.KIND_IDS.has("circle")
			and TelegraphShape.KIND_IDS.has("cone") and TelegraphShape.KIND_IDS.has("ground_ring"))
	var east := Vector2i(256, 0)
	var c := TelegraphShape.from_data("circle", O, east, {"reach": 16})
	check("from_data circle == make_circle", c.valid and c.kind == TelegraphShape.Kind.CIRCLE and _count(c, 20) == _count(TelegraphShape.make_circle(O, 16), 20))
	var r := TelegraphShape.from_data("ground_ring", O, east, {"inner": 8, "reach": 24})
	check("from_data ground_ring == make_ring", r.valid and r.kind == TelegraphShape.Kind.GROUND_RING and _count(r, 30) == _count(TelegraphShape.make_ring(O, 8, 24), 30))
	var r0 := TelegraphShape.from_data("ground_ring", O, east, {"reach": 12})
	check("from_data ground_ring zonder inner = schijf", r0.valid and r0.contains_i(O))
	var l := TelegraphShape.from_data("line", O, east, {"reach": 64, "width": 16})
	check("from_data line == make_line", l.valid and l.kind == TelegraphShape.Kind.LINE and _count(l, 80) == 65 * 17)
	var k := TelegraphShape.from_data("cone", O, east, {"reach": 32, "angle": 90})
	check("from_data cone == make_cone", k.valid and k.kind == TelegraphShape.Kind.CONE and _in(k, Vector2i(10, 10)) and not _in(k, Vector2i(10, 11)))
	var m := TelegraphShape.from_data("melee_arc", O, east, {"reach": 32, "angle": 120})
	check("from_data melee_arc == make_melee_arc", m.valid and m.kind == TelegraphShape.Kind.MELEE_ARC and _in(m, Vector2i(10, 17)) and not _in(m, Vector2i(10, 18)))
	var unknown := TelegraphShape.from_data("spiral", O, east, {"reach": 16})
	check("from_data: onbekende vorm => ongeldig, geen null, raakt nergens", unknown != null and not unknown.valid and unknown.invalid_reason.contains("spiral") and _all_miss(unknown))
	check("from_data: ontbrekende reach => ongeldig", not TelegraphShape.from_data("circle", O, east, {}).valid)
	check("from_data: ontbrekende width => ongeldige line", not TelegraphShape.from_data("line", O, east, {"reach": 10}).valid)
	check("from_data: ontbrekende angle => ongeldige cone/arc", not TelegraphShape.from_data("cone", O, east, {"reach": 10}).valid
			and not TelegraphShape.from_data("melee_arc", O, east, {"reach": 10}).valid)
	check("from_data: float/string-waarden worden genegeerd (ongeldig, geen error)", not TelegraphShape.from_data("circle", O, east, {"reach": 16.5}).valid
			and not TelegraphShape.from_data("circle", O, east, {"reach": "16"}).valid)
	check("from_data: nulrichting bij een gerichte vorm => ongeldig; circle/ring hebben geen richting nodig",
			not TelegraphShape.from_data("cone", O, Vector2i.ZERO, {"reach": 10, "angle": 60}).valid
			and TelegraphShape.from_data("circle", O, Vector2i.ZERO, {"reach": 10}).valid
			and TelegraphShape.from_data("ground_ring", O, Vector2i.ZERO, {"inner": 2, "reach": 10}).valid)
	var windup_ok := true
	for id in TelegraphShape.KIND_IDS:
		var s := TelegraphShape.from_data(id, O, east, {"reach": 32, "width": 8, "angle": 90, "inner": 4})
		if not s.valid or s.kind != TelegraphShape.KIND_IDS[id]:
			windup_ok = false
	check("from_data: alle 5 id's geven een geldige vorm met de juiste kind", windup_ok)
