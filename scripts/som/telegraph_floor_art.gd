class_name TelegraphFloorArt
extends RefCounted
## WM1 vloer-telegraph sprites (docs/art/telegraph_floor_README.md). Alleen teken-hulp; geen gameplay.

const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")

const TEX_CIRCLE_48 := preload("res://assets/sprites/telegraph/telegraph_circle_48.png")
const TEX_CIRCLE_96 := preload("res://assets/sprites/telegraph/telegraph_circle_96.png")
const TEX_ARC120 := preload("res://assets/sprites/telegraph/telegraph_arc120_64.png")
const TEX_ARC120_DIAG := preload("res://assets/sprites/telegraph/telegraph_arc120_diag_64.png")
const TEX_LINE := preload("res://assets/sprites/telegraph/telegraph_line_16.png")
const TEX_LINE_START := preload("res://assets/sprites/telegraph/telegraph_line_start_16.png")
const TEX_LINE_DIAG := preload("res://assets/sprites/telegraph/telegraph_line_diag_16.png")
const TEX_INKSPIT := preload("res://assets/sprites/telegraph/telegraph_inkspit_22x44.png")
const TEX_INKSPIT_DIAG := preload("res://assets/sprites/telegraph/telegraph_inkspit_diag_22x44.png")
const TEX_INK_ZONE := preload("res://assets/sprites/telegraph/telegraph_ink_zone_48.png")

const COLS := 5
const FILL_STEPS := 4
const INK_ZONE_FRAMES := 4
const INK_ZONE_MS := 100
const FLASH_MS := 100
const LINE_TILE_ALONG := 16
const DIAG_ALONG := 11.31
const DIAG_STEP := Vector2(8.0, 8.0)
const DIAG_CELL := 24.0

const INKPLAS_RADIUS := 24
const INKSPIW_REACH := 22
const INKSPIW_WIDTH := 44

enum Dir8 { RIGHT, DOWN, LEFT, UP, DR, UL, UR, DL }

class SheetXform:
	var rot: float = 0.0
	var flip_h: bool = false
	var flip_v: bool = false
	var use_diag: bool = false


static var _reusable_sheet_xform := SheetXform.new()


static func is_inkspit_line(shape: TelegraphShape) -> bool:
	return shape.kind == TelegraphShape.Kind.LINE and shape.reach == INKSPIW_REACH and shape.width == INKSPIW_WIDTH


static func sheet_column(fill_steps: int, phase: int, ticks_left: int, active_ticks: int) -> int:
	if fill_steps <= 0:
		return -1
	if fill_steps < FILL_STEPS:
		return fill_steps - 1
	if phase == TelegraphState.State.ACTIVE and active_ticks > 0:
		var elapsed: int = active_ticks - ticks_left
		var flash_ticks: int = maxi(1, TelegraphState.ms_to_ticks(FLASH_MS))
		if elapsed < flash_ticks:
			return 4
	return 3


static func frame_index(row: int, col: int) -> int:
	return row * COLS + col


static func dir8_from_shape(shape: TelegraphShape) -> int:
	var dx: int = shape.dir.x
	var dy: int = shape.dir.y
	if dx == 0 and dy == 0:
		return Dir8.RIGHT
	var adx: int = absi(dx)
	var ady: int = absi(dy)
	if ady * 2 < adx:
		return Dir8.RIGHT if dx > 0 else Dir8.LEFT
	if adx * 2 < ady:
		return Dir8.DOWN if dy > 0 else Dir8.UP
	if dx > 0 and dy > 0:
		return Dir8.DR
	if dx < 0 and dy < 0:
		return Dir8.UL
	if dx > 0 and dy < 0:
		return Dir8.UR
	return Dir8.DL


static func sheet_xform(d8: int) -> SheetXform:
	var x: SheetXform = _reusable_sheet_xform
	x.rot = 0.0
	x.flip_h = false
	x.flip_v = false
	x.use_diag = false
	match d8:
		Dir8.RIGHT:
			pass
		Dir8.DOWN:
			x.rot = PI * 0.5
			x.flip_v = true
		Dir8.LEFT:
			x.rot = PI
		Dir8.UP:
			x.rot = PI * 0.5
			x.flip_h = true
		Dir8.DR:
			x.use_diag = true
		Dir8.UL:
			x.use_diag = true
			x.rot = PI
		Dir8.UR:
			x.use_diag = true
			x.rot = -PI * 0.5
		Dir8.DL:
			x.use_diag = true
			x.rot = PI * 0.5
	return x


static func _draw_push(canvas: CanvasItem, origin: Vector2, xform: SheetXform) -> void:
	var scale := Vector2(-1.0 if xform.flip_h else 1.0, -1.0 if xform.flip_v else 1.0)
	canvas.draw_set_transform(origin, xform.rot, scale)


static func _draw_pop(canvas: CanvasItem) -> void:
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func row_for_style(yellow_interrupt: bool) -> int:
	return 1 if yellow_interrupt else 0


static func ink_zone_frame(age_ticks: int) -> int:
	var step: int = maxi(0, age_ticks * 1000 / (TelegraphState.TICK_HZ * INK_ZONE_MS))
	return step % INK_ZONE_FRAMES


static func draw_circle(canvas: CanvasItem, shape: TelegraphShape, row: int, col: int, alpha: float) -> void:
	if col < 0:
		return
	var tex: Texture2D = TEX_CIRCLE_96 if shape.reach > INKPLAS_RADIUS else TEX_CIRCLE_48
	var cw: float = 48.0 if tex == TEX_CIRCLE_48 else 96.0
	var ch: float = cw
	var fi: int = frame_index(row, col)
	var src := Rect2(float(fi % COLS) * cw, float(fi / COLS) * ch, cw, ch)
	var o := Vector2(shape.origin)
	var dest := Rect2(o.x - cw * 0.5, o.y - ch * 0.5, cw, ch)
	canvas.draw_texture_rect_region(tex, dest, src, Color(1, 1, 1, alpha))


static func draw_arc(canvas: CanvasItem, shape: TelegraphShape, row: int, col: int, alpha: float) -> void:
	if col < 0 or shape.angle_deg <= 0:
		return
	var d8: int = dir8_from_shape(shape)
	var xf: SheetXform = sheet_xform(d8)
	var tex: Texture2D = TEX_ARC120_DIAG if xf.use_diag else TEX_ARC120
	var cw := 64.0
	var ch := 64.0
	var fi: int = frame_index(row, col)
	var src := Rect2(float(fi % COLS) * cw, float(fi / COLS) * ch, cw, ch)
	_draw_push(canvas, Vector2(shape.origin), xf)
	canvas.draw_texture_rect_region(tex, Rect2(-cw * 0.5, -ch * 0.5, cw, ch), src, Color(1, 1, 1, alpha))
	_draw_pop(canvas)


static func draw_inkspit(canvas: CanvasItem, shape: TelegraphShape, row: int, col: int, alpha: float) -> void:
	if col < 0:
		return
	var d8: int = dir8_from_shape(shape)
	var xf: SheetXform = sheet_xform(d8)
	var tex: Texture2D = TEX_INKSPIT_DIAG if xf.use_diag else TEX_INKSPIT
	var cw := 22.0 if tex == TEX_INKSPIT else 48.0
	var ch := 44.0 if tex == TEX_INKSPIT else 48.0
	var fi: int = frame_index(row, col)
	var src := Rect2(float(fi % COLS) * cw, float(fi / COLS) * ch, cw, ch)
	_draw_push(canvas, Vector2(shape.origin), xf)
	if tex == TEX_INKSPIT:
		canvas.draw_texture_rect_region(tex, Rect2(0.0, -22.0, cw, ch), src, Color(1, 1, 1, alpha))
	else:
		canvas.draw_texture_rect_region(tex, Rect2(-16.0, -16.0, cw, ch), src, Color(1, 1, 1, alpha))
	_draw_pop(canvas)


static func draw_line_cardinal(
	canvas: CanvasItem,
	shape: TelegraphShape,
	row: int,
	col: int,
	alpha: float,
	xf: SheetXform,
) -> void:
	if col < 0:
		return
	_draw_push(canvas, Vector2(shape.origin), xf)
	var sy: float = float(row) * 16.0
	var frame_x: float = float(col) * 32.0
	var reach: int = shape.reach
	var total_tiles: int = maxi(1, int(ceil(float(reach) / float(LINE_TILE_ALONG))))
	var mids: int = maxi(0, total_tiles - 2)
	var pos := Vector2.ZERO
	var start_src := Rect2(float(col) * 16.0, sy, 16.0, 16.0)
	canvas.draw_texture_rect_region(TEX_LINE_START, Rect2(pos.x, pos.y - 8.0, 16.0, 16.0), start_src, Color(1, 1, 1, alpha))
	pos.x += float(LINE_TILE_ALONG)
	for _i in mids:
		var mid_src := Rect2(frame_x, sy, 16.0, 16.0)
		canvas.draw_texture_rect_region(TEX_LINE, Rect2(pos.x, pos.y - 8.0, 16.0, 16.0), mid_src, Color(1, 1, 1, alpha))
		pos.x += float(LINE_TILE_ALONG)
	var end_src := Rect2(frame_x + 16.0, sy, 16.0, 16.0)
	canvas.draw_texture_rect_region(TEX_LINE, Rect2(pos.x, pos.y - 8.0, 16.0, 16.0), end_src, Color(1, 1, 1, alpha))
	_draw_pop(canvas)


static func _diag_mid_count(reach_px: int) -> int:
	return maxi(0, int(roundf(float(reach_px) / DIAG_ALONG)) - 2)


static func draw_line_diag(
	canvas: CanvasItem,
	shape: TelegraphShape,
	row: int,
	col: int,
	alpha: float,
	xf: SheetXform,
) -> void:
	if col < 0:
		return
	_draw_push(canvas, Vector2(shape.origin), xf)
	var sy: float = float(row) * DIAG_CELL
	var frame_x: float = float(col) * 72.0
	var n_mid: int = _diag_mid_count(shape.reach)
	var pieces: int = n_mid + 2
	for k in pieces:
		var cell := Vector2(float(k) * DIAG_STEP.x - 6.0, float(k) * DIAG_STEP.y - 6.0)
		var part_src: Rect2
		if k == 0:
			part_src = Rect2(frame_x, sy, DIAG_CELL, DIAG_CELL)
		elif k == pieces - 1:
			part_src = Rect2(frame_x + DIAG_CELL * 2.0, sy, DIAG_CELL, DIAG_CELL)
		else:
			part_src = Rect2(frame_x + DIAG_CELL, sy, DIAG_CELL, DIAG_CELL)
		canvas.draw_texture_rect_region(TEX_LINE_DIAG, Rect2(cell.x, cell.y, DIAG_CELL, DIAG_CELL), part_src, Color(1, 1, 1, alpha))
	_draw_pop(canvas)


static func draw_line(canvas: CanvasItem, shape: TelegraphShape, row: int, col: int, alpha: float) -> void:
	var d8: int = dir8_from_shape(shape)
	var xf: SheetXform = sheet_xform(d8)
	if xf.use_diag:
		draw_line_diag(canvas, shape, row, col, alpha, xf)
	else:
		draw_line_cardinal(canvas, shape, row, col, alpha, xf)


static func draw_ink_zone(canvas: CanvasItem, shape: TelegraphShape, age_ticks: int, alpha: float) -> void:
	var frame: int = ink_zone_frame(age_ticks)
	var cw := 48.0
	var src := Rect2(float(frame) * cw, 0.0, cw, cw)
	var o := Vector2(shape.origin)
	var dest := Rect2(o.x - cw * 0.5, o.y - cw * 0.5, cw, cw)
	canvas.draw_texture_rect_region(TEX_INK_ZONE, dest, src, Color(1, 1, 1, alpha))


## Windup-kolommen 0..2; ACTIVE flits-kolom 4 alleen tijdens eerste FLASH_MS, daarna 3.
static func verify_sheet_column_transitions() -> bool:
	var flash_ticks: int = maxi(1, TelegraphState.ms_to_ticks(FLASH_MS))
	var active_len: int = flash_ticks + 4
	if sheet_column(1, TelegraphState.State.WINDUP, 10, 0) != 0:
		return false
	if sheet_column(4, TelegraphState.State.ACTIVE, active_len, active_len) != 4:
		return false
	if sheet_column(4, TelegraphState.State.ACTIVE, active_len - 1, active_len) != 4:
		return false
	if sheet_column(4, TelegraphState.State.ACTIVE, active_len - flash_ticks, active_len) != 3:
		return false
	if sheet_column(4, TelegraphState.State.ACTIVE, 1, active_len) != 3:
		return false
	return true


static func draw_entry(
	canvas: CanvasItem,
	shape: TelegraphShape,
	yellow_interrupt: bool,
	fill_steps: int,
	phase: int,
	ticks_left: int,
	active_ticks: int,
	alpha: float,
) -> void:
	if shape == null or not shape.valid or fill_steps <= 0:
		return
	var row: int = row_for_style(yellow_interrupt)
	var col: int = sheet_column(fill_steps, phase, ticks_left, active_ticks)
	match shape.kind:
		TelegraphShape.Kind.CIRCLE:
			draw_circle(canvas, shape, row, col, alpha)
		TelegraphShape.Kind.MELEE_ARC:
			if shape.angle_deg == 120:
				draw_arc(canvas, shape, row, col, alpha)
		TelegraphShape.Kind.LINE:
			if is_inkspit_line(shape):
				draw_inkspit(canvas, shape, row, col, alpha)
			else:
				draw_line(canvas, shape, row, col, alpha)