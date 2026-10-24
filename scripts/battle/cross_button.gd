extends TextureRect
## Knop van het commando-kruis (command_cross.gd). Het plaatje blijft 24x24 (art van RPG ART, tests
## leunen op die maat en op de afstand 25); het tikvlak is SLOP eenheden ruimer rondom: 26x26 >=
## UiTouch.TOUCH_MIN (25, ~48dp). Buren overlappen daardoor 1 eenheid; de later getekende knop wint.

const SLOP := 1.0


func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2(-SLOP, -SLOP), size + Vector2(SLOP, SLOP) * 2.0).has_point(point)
