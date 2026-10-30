class_name TelegraphLayer
extends Node2D
## Grond-telegraaf (Combat T3): één `_draw()` voor alle actieve vormen uit de sim.
## PLACEHOLDER-kleuren en polygonen; geen art, geen shaders. Leest alleen TelegraphAttack/TelegraphShape
## en TelegraphState — verandert geen timings, schade of RNG.

const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const CombatZones := preload("res://scripts/som/combat_zones.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")

const BORDER_PX := 3
const FILL_STEPS := 4
const CIRCLE_SEGMENTS := 16

## PLACEHOLDER (COMBAT_DESIGN §11): rood = ontwijken, geel = onderbreekbaar (arcering).
const PLACEHOLDER_RED_FILL := Color(0.92, 0.18, 0.18, 0.42)
const PLACEHOLDER_RED_EDGE := Color(0.95, 0.12, 0.12, 0.92)
const PLACEHOLDER_YELLOW_FILL := Color(0.95, 0.82, 0.12, 0.38)
const PLACEHOLDER_YELLOW_EDGE := Color(0.9, 0.75, 0.08, 0.9)
## Inktplas-loop (T4b placeholder).
const PLACEHOLDER_INK_FILL := Color(0.18, 0.1, 0.42, 0.48)
const PLACEHOLDER_INK_EDGE := Color(0.28, 0.14, 0.62, 0.92)
## Wortelgreep-icoon om de voeten (T6 placeholder).
const PLACEHOLDER_ROOT_FILL := Color(0.45, 0.28, 0.08, 0.55)
const PLACEHOLDER_ROOT_EDGE := Color(0.35, 0.2, 0.05, 0.95)

enum Style { RED_DODGE, YELLOW_INTERRUPT }

class DrawEntry:
	var shape: TelegraphShape
	var fill_steps: int = 0
	var style: int = Style.RED_DODGE


var _entries: Array[DrawEntry] = []
var _zone_shapes: Array[TelegraphShape] = []
var _root_icons: Array[Vector2] = []


func entry_count() -> int:
	return _entries.size()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 4
	y_sort_enabled = false
	name = "TelegraphLayer"


## Bouwt de tekenlijst uit arena-vijanden (`SomArena.enemies`); roept `queue_redraw()` bij wijziging.
func sync_from_enemies(enemies: Dictionary, interruptible_for_attack: Callable = Callable()) -> void:
	var next: Array[DrawEntry] = []
	for m in enemies.keys():
		if not is_instance_valid(m):
			continue
		var e: Dictionary = enemies[m]
		if not e.has("tg"):
			continue
		var tg: TelegraphAttack = e["tg"]
		var ent := entry_from_attack(tg, interruptible_for_attack)
		if ent != null:
			next.append(ent)
	if _entries_changed(next):
		_entries = next
		queue_redraw()


## Actieve grondzones (Combat T4b); alleen tekenen.
## Rooted helden: kleine cirkels op voetpositie (alleen tekenen).
func sync_from_roots(roots: CombatRoots, positions: Dictionary) -> void:
	var next: Array[Vector2] = []
	if roots != null:
		for hid in roots.rooted_ids():
			if positions.has(hid):
				next.append(Vector2(positions[hid]))
	if _root_icons_changed(next):
		_root_icons = next
		queue_redraw()


func _root_icons_changed(next: Array[Vector2]) -> bool:
	if next.size() != _root_icons.size():
		return true
	for i in next.size():
		if next[i] != _root_icons[i]:
			return true
	return false


func sync_from_zones(zones: CombatZones) -> void:
	var next: Array[TelegraphShape] = []
	if zones != null:
		for z in zones.zones_for_draw():
			var sh := TelegraphShape.make_circle(z.get("origin", Vector2i.ZERO), int(z.get("r", 0)))
			if sh.valid:
				next.append(sh)
	if _zone_shapes_changed(next):
		_zone_shapes = next
		queue_redraw()


func _zone_shapes_changed(next: Array[TelegraphShape]) -> bool:
	if next.size() != _zone_shapes.size():
		return true
	for i in next.size():
		if next[i].origin != _zone_shapes[i].origin or next[i].reach != _zone_shapes[i].reach:
			return true
	return false


func _entries_changed(next: Array[DrawEntry]) -> bool:
	if next.size() != _entries.size():
		return true
	for i in next.size():
		var a: DrawEntry = next[i]
		var b: DrawEntry = _entries[i]
		if a.fill_steps != b.fill_steps or a.style != b.style or a.shape != b.shape:
			return true
	return false


## Zichtbaar alleen in WINDUP/ACTIVE; leeg bij IDLE/RECOVERY/COOLDOWN.
static func entry_from_attack(tg: TelegraphAttack, interruptible_for_attack: Callable = Callable()) -> DrawEntry:
	if tg == null or not tg.is_busy():
		return null
	var st: int = tg.state()
	if st != TelegraphState.State.WINDUP and st != TelegraphState.State.ACTIVE:
		return null
	var sh: TelegraphShape = tg.shape()
	if sh == null or not sh.valid:
		return null
	var ent := DrawEntry.new()
	ent.shape = sh
	ent.fill_steps = fill_steps_for_phase(st, tg.ticks_left_in_phase(), tg.windup_duration_ticks())
	var intr := false
	if interruptible_for_attack.is_valid():
		intr = bool(interruptible_for_attack.call(tg.attack_id()))
	ent.style = Style.YELLOW_INTERRUPT if intr else Style.RED_DODGE
	return ent


static func fill_steps_for_phase(state: int, ticks_left: int, windup_total: int) -> int:
	if state == TelegraphState.State.ACTIVE:
		return FILL_STEPS
	if state != TelegraphState.State.WINDUP or windup_total <= 0:
		return 0
	var elapsed: int = windup_total - ticks_left
	if elapsed <= 0:
		return 0
	return clampi((elapsed * FILL_STEPS + windup_total - 1) / windup_total, 1, FILL_STEPS - 1)


static func is_visible_phase(state: int) -> bool:
	return state == TelegraphState.State.WINDUP or state == TelegraphState.State.ACTIVE


## Buitenomtrek van de vorm (voor rand + tests). `scale` 1.0 = volle maat, kleiner = naar binnen.
static func outline_polygon(shape: TelegraphShape, scale: float = 1.0) -> PackedVector2Array:
	if shape == null or not shape.valid:
		return PackedVector2Array()
	var o := Vector2(shape.origin)
	match shape.kind:
		TelegraphShape.Kind.CIRCLE:
			return _circle_poly(o, maxf(1.0, float(shape.reach) * scale))
		TelegraphShape.Kind.GROUND_RING:
			return _ring_outer_poly(o, shape.inner, shape.reach, scale)
		TelegraphShape.Kind.LINE:
			return _line_poly(shape, scale)
		TelegraphShape.Kind.CONE, TelegraphShape.Kind.MELEE_ARC:
			return _wedge_poly(shape, scale)
	return PackedVector2Array()


## Binnenrand voor opvul-band (stap n gebruikt band tussen inner(n) en outer).
static func inner_outline_polygon(shape: TelegraphShape, fill_steps: int) -> PackedVector2Array:
	var t: float = 1.0 - float(fill_steps) / float(FILL_STEPS)
	return outline_polygon(shape, t)


static func _dir_unit(shape: TelegraphShape) -> Vector2:
	var d := Vector2(shape.dir.x, shape.dir.y)
	if d.length_squared() < 0.001:
		return Vector2.RIGHT
	return d / float(TelegraphShape.DIR_SCALE)


static func _circle_poly(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(CIRCLE_SEGMENTS)
	for i in CIRCLE_SEGMENTS:
		var a := TAU * float(i) / float(CIRCLE_SEGMENTS)
		pts[i] = center + Vector2(cos(a), sin(a)) * radius
	return pts


static func _ring_outer_poly(center: Vector2, inner_r: int, outer_r: int, scale: float) -> PackedVector2Array:
	var orad: float = maxf(float(inner_r) + 1.0, float(outer_r) * scale)
	return _circle_poly(center, orad)


static func _line_poly(shape: TelegraphShape, scale: float) -> PackedVector2Array:
	var fwd := _dir_unit(shape) * float(shape.reach) * scale
	var half_w: float = maxf(1.0, float(shape.width) * 0.5 * scale)
	var perp := Vector2(-fwd.y, fwd.x)
	if perp.length_squared() > 0.001:
		perp = perp.normalized() * half_w
	var o := Vector2(shape.origin)
	var a := o - perp
	var b := o + perp
	var c := o + fwd + perp
	var d := o + fwd - perp
	return PackedVector2Array([a, b, c, d])


static func _wedge_poly(shape: TelegraphShape, scale: float) -> PackedVector2Array:
	var reach: float = maxf(1.0, float(shape.reach) * scale)
	var half: float = clampf(float(shape.angle_deg) * 0.5, 1.0, 180.0)
	var base := _dir_unit(shape)
	var segs: int = maxi(3, int(ceil(half / 15.0)))
	var pts := PackedVector2Array()
	pts.append(Vector2(shape.origin))
	var center_angle := base.angle()
	for i in segs + 1:
		var t := float(i) / float(segs)
		var ang := center_angle - deg_to_rad(half) + deg_to_rad(half * 2.0) * t
		pts.append(Vector2(shape.origin) + Vector2(cos(ang), sin(ang)) * reach)
	return pts


func _draw() -> void:
	for ent in _entries:
		_draw_entry(ent)
	for sh in _zone_shapes:
		_draw_zone(sh)
	for p in _root_icons:
		_draw_root_icon(p)


func _draw_root_icon(center: Vector2) -> void:
	var r := 7.0
	var pts := PackedVector2Array()
	pts.resize(12)
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts[i] = center + Vector2(cos(a), sin(a)) * r
	draw_colored_polygon(pts, PLACEHOLDER_ROOT_FILL)
	draw_polyline(pts, PLACEHOLDER_ROOT_EDGE, 2.0, true)


func _draw_zone(shape: TelegraphShape) -> void:
	var outer := outline_polygon(shape, 1.0)
	if outer.is_empty():
		return
	draw_colored_polygon(outer, PLACEHOLDER_INK_FILL)
	draw_polyline(outer, PLACEHOLDER_INK_EDGE, float(BORDER_PX), true)


func _draw_entry(ent: DrawEntry) -> void:
	var outer := outline_polygon(ent.shape, 1.0)
	if outer.is_empty():
		return
	var edge := PLACEHOLDER_YELLOW_EDGE if ent.style == Style.YELLOW_INTERRUPT else PLACEHOLDER_RED_EDGE
	var fill := PLACEHOLDER_YELLOW_FILL if ent.style == Style.YELLOW_INTERRUPT else PLACEHOLDER_RED_FILL
	if ent.fill_steps > 0:
		# PLACEHOLDER: FILL_STEPS discrete opvulstappen (buiten → binnen), cumulatief via alpha.
		var fc := fill
		fc.a = fill.a * float(ent.fill_steps) / float(FILL_STEPS)
		draw_colored_polygon(outer, fc)
		if ent.style == Style.YELLOW_INTERRUPT:
			_draw_hatch(outer)
	draw_polyline(outer, edge, float(BORDER_PX), true)


func _draw_hatch(poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	var mn := poly[0]
	var mx := poly[0]
	for p in poly:
		mn = mn.min(p)
		mx = mx.max(p)
	var col := Color(0.15, 0.1, 0.02, 0.55)
	var step := 5.0
	var y := mn.y
	while y <= mx.y + (mx.x - mn.x):
		draw_line(Vector2(mn.x, y), Vector2(mx.x, y - (mx.x - mn.x)), col, 1.0)
		y += step
