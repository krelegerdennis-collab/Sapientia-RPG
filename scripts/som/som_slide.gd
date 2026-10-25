extends RefCounted
## Analoge muur-glijding op logische tegels (`is_wall`), los van TileSet-physics en
## de gedeelde `_tilesets`-cache in dungeon_room.gd.
##
## `move_and_slide` in `_process` gebruikt de frametijd: bij een hapering (CI-jobs parallel,
## xvfb) kan de physics-sweep 1–2 px in een plafond tunnelllen. De autotest meet
## `is_wall` (data), niet de physics-cache — die twee lopen uit elkaar.
## Zelfde voeten-hitbox als `player.set_analog`: 10×8 op (0, 3).

const TILE := 16.0
const HIT_SIZE := Vector2(10, 8)
const HIT_OFF := Vector2(0, 3)
## Nooit meer dan een halve tegel per substap, zodat één lange frame geen muur overslaat.
const MAX_STAP_PX := 4.0


static func hitbox(pos: Vector2) -> Rect2:
	var c := pos + HIT_OFF
	return Rect2(c - HIT_SIZE * 0.5, HIT_SIZE)


## Raakt de analoge hitbox op `pos` een tegel waar `is_wall(Vector2i)` true is?
static func in_muur(pos: Vector2, is_wall: Callable) -> bool:
	var r := hitbox(pos)
	var x0 := int(floor(r.position.x / TILE))
	var y0 := int(floor(r.position.y / TILE))
	var x1 := int(floor((r.end.x - 0.001) / TILE))
	var y1 := int(floor((r.end.y - 0.001) / TILE))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if bool(is_wall.call(Vector2i(x, y))):
				return true
	return false


## As-gescheiden correctie: schuif langs de muur i.p.v. erin. `voor` = positie vóór de stap.
static func corrigeer(voor: Vector2, na: Vector2, is_wall: Callable) -> Vector2:
	if not in_muur(na, is_wall):
		return na
	var alleen_x := Vector2(na.x, voor.y)
	if not in_muur(alleen_x, is_wall):
		return alleen_x
	var alleen_y := Vector2(voor.x, na.y)
	if not in_muur(alleen_y, is_wall):
		return alleen_y
	if not in_muur(voor, is_wall):
		return voor
	return voor


## Beweeg `vel` (px/s) gedurende `delta`, in substappen, glijdend langs logische muren.
static func glijd(pos: Vector2, vel: Vector2, delta: float, is_wall: Callable) -> Vector2:
	if vel == Vector2.ZERO or delta <= 0.0:
		return pos
	var left := delta
	var speed := vel.length()
	while left > 0.0001:
		var dt := left
		if speed > 0.0 and speed * dt > MAX_STAP_PX:
			dt = MAX_STAP_PX / speed
		var voor := pos
		pos = corrigeer(voor, voor + vel * dt, is_wall)
		left -= dt
	return pos
