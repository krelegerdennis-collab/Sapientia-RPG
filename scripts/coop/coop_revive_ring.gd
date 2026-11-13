extends CanvasLayer
## Voortgangsring om een liggende co-op-stoel (M8a).
## Art van RPG ART, 32x32: revive_ring_under onder, revive_ring als vulling.
## Eigen CanvasLayer (laag 20), dus niet meegekleurd door een CanvasModulate.
## Geen class_name: een globale klasse plus preload vanuit som_arena laat het
## script headless half-gecompileerd, en dan bestaat new() niet.

const TEX_UNDER := preload("res://assets/sprites/coop/revive_ring_under.png")
const TEX_RING := preload("res://assets/sprites/coop/revive_ring.png")
const RING_PX := 32
const OFFSET := Vector2(16, 16)

var progress: int = 0
var world_pos := Vector2.ZERO
var shown := false
var bar: TextureProgressBar


func _ready() -> void:
	layer = 20
	name = "CoopReviveRing"
	bar = TextureProgressBar.new()
	bar.name = "Ring"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.texture_under = TEX_UNDER
	bar.texture_progress = TEX_RING
	bar.fill_mode = 4
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	bar.visible = false
	bar.size = Vector2(RING_PX, RING_PX)
	add_child(bar)


## pos is de wereldpositie in schermruimte. De 32x32-ring staat daar gecentreerd.
func show_channel(pos: Vector2, pct: int) -> void:
	var next := clampi(pct, 0, 100)
	shown = next > 0
	progress = next
	world_pos = pos
	if bar == null:
		return
	bar.value = next
	bar.position = pos - OFFSET
	bar.visible = shown
