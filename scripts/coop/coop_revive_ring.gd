class_name CoopReviveRing
extends CanvasLayer
## PLACEHOLDER voortgangsboog voor een revive-kanaal (M8a).
## Magenta boog + de letters PH. Geen definitieve art.
## Eigen CanvasLayer, dus niet meegekleurd door een CanvasModulate op de kaart.
## Echte art later: assets/sprites/coop/revive_ring.png  32x32.

const PLACEHOLDER := true
const PLACEHOLDER_MARK := "PH"
const COLOR := Color(1.0, 0.0, 1.0, 0.95)

var progress: int = 0
var world_pos := Vector2.ZERO
var shown := false
var _arc: Control
var _mark: Label


func _ready() -> void:
	layer = 20
	name = "CoopReviveRing"
	_arc = _Arc.new()
	_arc.name = "Arc"
	_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_arc as _Arc).ring = self
	add_child(_arc)
	_mark = Label.new()
	_mark.name = "PlaceholderMark"
	_mark.text = PLACEHOLDER_MARK
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_theme_color_override("font_color", COLOR)
	_mark.add_theme_font_size_override("font_size", 8)
	_mark.visible = false
	add_child(_mark)
	_fit()


## Control onder een CanvasLayer krijgt anders hoogte 0 en tekent _draw niet.
func _fit() -> void:
	var sz := Vector2(384, 216)
	var vp := get_viewport()
	if vp != null:
		var vis := vp.get_visible_rect().size
		if vis.x > 1.0 and vis.y > 1.0:
			sz = vis
	if _arc != null:
		_arc.position = Vector2.ZERO
		_arc.size = sz


func show_channel(pos: Vector2, pct: int) -> void:
	var next := clampi(pct, 0, 100)
	var on := next > 0
	if on == shown and next == progress and pos == world_pos:
		return
	shown = on
	progress = next
	world_pos = pos
	_fit()
	if _mark != null:
		_mark.visible = on
		_mark.position = pos + Vector2(-6, -18)
	if _arc != null:
		_arc.queue_redraw()


func paint(canvas: CanvasItem) -> void:
	if not shown or progress <= 0:
		return
	var start := -PI * 0.5
	var end := start + TAU * (float(progress) / 100.0)
	canvas.draw_arc(world_pos, 11.0, start, end, 20, COLOR, 2.0, true)
	canvas.draw_arc(world_pos, 11.0, 0.0, TAU, 24, Color(1, 0, 1, 0.35), 1.0, true)


class _Arc extends Control:
	var ring: Node

	func _draw() -> void:
		if ring != null and ring.has_method("paint"):
			ring.paint(self)
