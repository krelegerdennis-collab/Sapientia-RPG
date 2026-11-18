extends TextureRect
## Knop van het commando-kruis (command_cross.gd). F6-T16: het plaatje is 26x26 (art van RPG ART,
## afstand 27 = BUTTON + GAP) en vult zelf al UiTouch.TOUCH_MIN (25, ~48dp); het tikvlak is SLOP
## eenheden ruimer rondom (28x28). Buren overlappen daardoor 1 eenheid; de later getekende knop wint.

const SLOP := 1.0


func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2(-SLOP, -SLOP), size + Vector2(SLOP, SLOP) * 2.0).has_point(point)
