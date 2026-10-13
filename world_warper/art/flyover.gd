class_name WorldWarperFlyover
extends Node2D
## World Warper op de wereldkaart: alleen een overvliegend plaatje (puur beeld).
## Geen ingang, geen botsing, geen uitgang. De enige weg naar binnen is Warp in het menu
## (scripts/ui/field_menu.gd open_warp). Pas zichtbaar na canon-scène 1 (ontgrendeld).

const TEX := preload("res://assets/sprites/archief2/world_warper.png")
## Seconden tussen twee overvluchten en de duur van één vlucht.
const PAUZE := 18.0
const VLUCHT := 14.0
const SCHAAL := 0.5

var sprite: Sprite2D
var _t := 0.0
var _kaart_breedte := 1024.0


func _ready() -> void:
	z_index = 50
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(SCHAAL, SCHAAL)
	sprite.modulate = Color(1, 1, 1, 0.85)
	add_child(sprite)
	var grond := get_parent().get_node_or_null("Ground") as TileMapLayer
	if grond != null:
		_kaart_breedte = float(grond.get_used_rect().end.x * 16)
	sprite.visible = false
	_t = PAUZE - 2.0


static func actief() -> bool:
	return GameState.world_warper_is_unlocked()


func _process(delta: float) -> void:
	if not actief():
		sprite.visible = false
		return
	_t += delta
	var cyclus := PAUZE + VLUCHT
	if _t >= cyclus:
		_t -= cyclus
	if _t < PAUZE:
		sprite.visible = false
		return
	var f := (_t - PAUZE) / VLUCHT
	sprite.visible = true
	sprite.position = Vector2(lerpf(-80.0, _kaart_breedte + 80.0, f), 120.0 + sin(f * TAU) * 24.0)
