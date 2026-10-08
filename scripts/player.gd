extends CharacterBody2D
## Speler met Lufia-achtige grid-beweging:
## - beweegt altijd precies 1 tile (16 px) per stap, vloeiend tussen tiles
## - kijkt in de richting van de laatst ingedrukte pijl
## - wordt geblokkeerd door collision (muren, water, bomen, NPC's)
## - 'interact' praat met / leest wat er vóór de speler staat

## Wordt uitgezonden telkens als de speler een nieuwe tile bereikt.
## Handig voor later: random encounters, vijanden die meebewegen (Lufia 2!), deuren...
signal stepped(tile: Vector2i)
## Wordt uitgezonden als de speler tegen iets aan loopt (één keer per poging).
signal bumped(tile: Vector2i)

const TILE_SIZE := 16

## Loopsnelheid in pixels per seconde (64 = 4 tiles per seconde).
@export var walk_speed := 64.0

## Rij in de sprite sheet per kijkrichting (sheet = 3 kolommen x 4 rijen).
const DIR_ROW := {
	Vector2i.DOWN: 0,
	Vector2i.LEFT: 1,
	Vector2i.RIGHT: 2,
	Vector2i.UP: 3,
}
## Kolommen tijdens het lopen: stap A, stil, stap B, stil, ...
const WALK_CYCLE := [1, 0, 2, 0]

var facing := Vector2i.DOWN
var is_moving := false
## true = speler reageert niet op input (bv. tijdens de overgang naar een gevecht).
var input_locked := false
var _target := Vector2.ZERO
var _walk_distance := 0.0
var _bump_tile := Vector2i(-9999, -9999)
## v0.11: true zolang een cutscene de speler laat lopen
var _scripted := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# Zet de speler precies in het midden van de tile waar hij staat.
	position = (position / TILE_SIZE).floor() * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)
	_target = position
	_update_sprite()


## v7 (prestaties): lopen gebeurt in _process (per beeld) i.p.v. _physics_process (vast
## 60x per seconde). Op telefoons met 90/120 Hz-schermen (Samsung) liep de speler en de
## camera anders schokkerig: soms 1, soms 2 beelden per physics-stap.
func _process(delta: float) -> void:
	if _scripted:
		return   # cutscene laat de speler lopen (script_walk)
	# --- Praten / tekstvak doorklikken ---
	if Dialog.is_open and Input.is_action_just_pressed("cancel"):
		Dialog.cancel()    # B werkt ook om tekst door te klikken (bij een vraag: "Nee")
		return
	# v0.11: tekst doorklikken mag ook tijdens een cutscene (input_locked)
	if Input.is_action_just_pressed("interact") and not is_moving and (Dialog.is_open or not input_locked):
		if Dialog.is_open:
			Dialog.advance()
		else:
			_try_interact()
		return

	if Dialog.is_open:
		return  # niet lopen terwijl er een tekstvak open staat

	# --- Lopen ---
	var budget := walk_speed * delta  # hoeveel pixels we deze frame mogen bewegen
	if is_moving:
		budget = _step_towards_target(budget)

	if not is_moving:
		var dir := _read_direction()
		if dir == Vector2i.ZERO:
			_walk_distance = 0.0
			_bump_tile = Vector2i(-9999, -9999)
		else:
			facing = dir
			if _can_move(dir):
				_target = position + Vector2(dir) * TILE_SIZE
				is_moving = true
				_bump_tile = Vector2i(-9999, -9999)
				# Gebruik de overgebleven beweging meteen: zo loop je zonder haperen door.
				_step_towards_target(budget)
			else:
				_walk_distance = 0.0
				if get_tile() + dir != _bump_tile:
					_bump_tile = get_tile() + dir
					_try_bump()

	_update_sprite()


## Beweeg richting het doel; geeft terug hoeveel beweging er "over" is.
func _step_towards_target(amount: float) -> float:
	var dist := position.distance_to(_target)
	if amount >= dist:
		position = _target
		_walk_distance += dist
		is_moving = false
		stepped.emit(get_tile())
		return amount - dist
	position = position.move_toward(_target, amount)
	_walk_distance += amount
	return 0.0


## Lees de pijltjes / WASD / touch D-pad. Alleen 4 richtingen (geen diagonaal).
func _read_direction() -> Vector2i:
	if input_locked:
		return Vector2i.ZERO
	var pressed: Array[Vector2i] = []
	if Input.is_action_pressed("move_up"):
		pressed.append(Vector2i.UP)
	if Input.is_action_pressed("move_down"):
		pressed.append(Vector2i.DOWN)
	if Input.is_action_pressed("move_left"):
		pressed.append(Vector2i.LEFT)
	if Input.is_action_pressed("move_right"):
		pressed.append(Vector2i.RIGHT)
	if pressed.is_empty():
		return Vector2i.ZERO
	# Houd je twee richtingen vast? Blijf dan de huidige richting op lopen.
	if facing in pressed:
		return facing
	return pressed[0]


## test_move kijkt of onze collision shape iets zou raken als we 1 tile verschuiven.
func _can_move(dir: Vector2i) -> bool:
	return not test_move(global_transform, Vector2(dir) * TILE_SIZE)


## Zoek een object op de tile vóór de speler en roep daar interact() op aan.
func _try_interact() -> void:
	for obj in _objects_in_front():
		if obj.has_method("interact"):
			obj.interact(self)
			return


## Tegen iets aan gelopen: objecten met een bump()-functie reageren (bv. een deur).
func _try_bump() -> void:
	bumped.emit(_bump_tile)
	for obj in _objects_in_front():
		if obj.has_method("bump"):
			obj.bump(self)
			return


func _objects_in_front() -> Array:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(facing) * TILE_SIZE
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var out := []
	for hit in get_world_2d().direct_space_state.intersect_point(query):
		if hit["collider"]:
			out.append(hit["collider"])
	return out


func _update_sprite() -> void:
	var col := 0
	if is_moving or _walk_distance > 0.0:
		col = WALK_CYCLE[int(_walk_distance / (TILE_SIZE / 2.0)) % WALK_CYCLE.size()]
	sprite.frame = DIR_ROW[facing] * sprite.hframes + col


## Zet de speler direct op een tile (bv. terug na een gevecht).
func place_at(tile: Vector2i, new_facing: Vector2i) -> void:
	position = Vector2(tile) * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)
	_target = position
	is_moving = false
	_walk_distance = 0.0
	facing = new_facing
	_update_sprite()


## Tile-coördinaat waar de speler nu staat.
func get_tile() -> Vector2i:
	return Vector2i((position / TILE_SIZE).floor())


## Stel de camera-grenzen in (wordt aangeroepen door map.gd).
func set_camera_limits(rect: Rect2i) -> void:
	camera.limit_left = rect.position.x
	camera.limit_top = rect.position.y
	camera.limit_right = rect.end.x
	camera.limit_bottom = rect.end.y


## v0.11 cutscene: kijkrichting zetten.
func face(dir: Vector2i) -> void:
	facing = dir
	_walk_distance = 0.0
	_update_sprite()


## v0.11 cutscene: n tiles lopen zonder input en zonder 'stepped' (dus geen uitgangen of
## gevechten); botsing telt niet, het script kiest de route.
func script_walk(dir: Vector2i, n: int, speed := 56.0) -> void:
	_scripted = true
	is_moving = true
	facing = dir
	for i in n:
		var from := position
		var to := from + Vector2(dir) * TILE_SIZE
		var t := 0.0
		var dur := TILE_SIZE / speed
		while t < dur:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			_walk_distance += speed * dt
			position = from.lerp(to, minf(t / dur, 1.0))
			_update_sprite()
		position = to
	_target = position
	is_moving = false
	_walk_distance = 0.0
	_scripted = false
	_update_sprite()
