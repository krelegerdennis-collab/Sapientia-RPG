extends RefCounted
## SoM-proef: analoge beweging (Action). Pure functies (getest in som_autotest.gd).
## joystick: dode zone, 8 richtingen, snelheid evenredig met hoe ver je duwt.
## toetsenbord: pijltjes/WASD (move_*), 8 richtingen, volle snelheid.

const SomData := preload("res://scripts/data/som_data.gd")


## Ruwe joystick (lengte 0..1) -> richting (8 stappen, genormaliseerd) x kracht (0..1, na de dode zone).
static func joy_to_dir(raw: Vector2, dead := SomData.JOY_DEADZONE) -> Vector2:
	var l := raw.length()
	if l <= dead:
		return Vector2.ZERO
	var strength := clampf((l - dead) / (1.0 - dead), 0.0, 1.0)
	var a := snappedf(raw.angle(), PI / 4.0)
	return Vector2.from_angle(a) * strength


## Richting x kracht -> snelheid in px/s.
static func joy_to_velocity(raw: Vector2, max_speed := SomData.MOVE_SPEED) -> Vector2:
	return joy_to_dir(raw) * max_speed


## Toetsenbord (move_*-acties) -> richting (8 stappen, lengte 1 of 0).
static func keys_to_dir() -> Vector2:
	var v := Vector2(
			float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
			float(Input.is_action_pressed("move_down")) - float(Input.is_action_pressed("move_up")))
	return v.normalized()


## Kijkrichting (4 rijen in de sheet) bij een bewegingsrichting; ZERO = houd de oude.
static func facing_for(dir: Vector2, old: Vector2i) -> Vector2i:
	if dir.length() < 0.01:
		return old
	if absf(dir.x) > absf(dir.y) + 0.01:
		return Vector2i.RIGHT if dir.x > 0.0 else Vector2i.LEFT
	if absf(dir.y) > absf(dir.x) + 0.01:
		return Vector2i.DOWN if dir.y > 0.0 else Vector2i.UP
	# diagonaal: horizontale kijkrichting houden als die al klopte, anders verticaal
	if old.x != 0 and signf(dir.x) == float(old.x):
		return old
	return Vector2i.DOWN if dir.y > 0.0 else Vector2i.UP
