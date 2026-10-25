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
const SomMove := preload("res://scripts/som/som_move.gd")
const SomSlide := preload("res://scripts/som/som_slide.gd")

## TODO.md "run feature" (CANON): RUN aan = 2 tegels per zet, sprite 2x zo snel. Toggle via de
## RUN-knop (touch, boven CORE) of toets R (actie "run"); de stand staat in Settings ("run").
const RUN_ACTION := "run"
const RUN_KEY := KEY_R
const RUN_TILES := 2
const RUN_SPEED_MULT := 2.0

## SoM-stijl: framemaat van de kaartsprite (16x24 oud, 24x32 nieuw). ZERO = uit de sheet afleiden.
@export var frame_maat := Vector2i.ZERO

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
## Hoeveel tegels deze RUN-zet nog extra mag (0 = gewone stap).
var _run_left := 0
## SoM-proef (Action): analoge beweging. Geldig = vrije pixelbeweging met move_and_slide (glijdt langs
## muren); geeft per frame een richting x kracht (lengte 0..1). Leeg = de gewone tegelbeweging.
var analog_input: Callable
## Topsnelheid in analoge modus (px/s).
var analog_speed := 80.0
## Action doel-lock: als deze Callable een richting geeft, kijkt de held naar het doel (strafen).
var facing_provider: Callable
## Na een duw (TODO.md push): niet doorlopen naar de vrijgekomen tegel tot de richting is losgelaten.
var hold_until_release := false
## Sessielog-review 21 okt 2026: na binnenkomen via een uitgang met de richting nog ingedrukt: niet lopen
## tot alle richtingen zijn losgelaten (geen warp-pingpong tussen twee kaarten).
var spawn_hold := false


func richting_ingedrukt() -> bool:
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false


## true = deze frame niet lopen (spawn_hold actief); laat los zodra er geen richting meer is.
func _spawn_hold_actief() -> bool:
	if spawn_hold and not richting_ingedrukt():
		spawn_hold = false
	return spawn_hold

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# Zet de speler precies in het midden van de tile waar hij staat.
	position = (position / TILE_SIZE).floor() * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)
	_target = position
	MapSprite.pas_toe(sprite, frame_maat)
	_update_sprite()
	ensure_run_action()


## Actie "run" (toets R) als project.godot hem niet kent; de touch-knop drukt dezelfde actie in.
static func ensure_run_action() -> void:
	if InputMap.has_action(RUN_ACTION):
		return
	InputMap.add_action(RUN_ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = RUN_KEY
	InputMap.action_add_event(RUN_ACTION, ev)


## Staat RUN aan? (nooit tijdens een gevecht)
func run_on() -> bool:
	var st := get_node_or_null("/root/Settings")
	return st != null and bool(st.get_value("run")) and not GameState.in_battle


func toggle_run() -> void:
	var st := get_node_or_null("/root/Settings")
	if st != null and not GameState.in_battle:
		st.set_value("run", not bool(st.get_value("run")))


## Loopsnelheid nu (RUN = 2x).
func current_speed() -> float:
	return walk_speed * (RUN_SPEED_MULT if run_on() else 1.0)


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

	# --- RUN aan/uit (toets R of de RUN-knop) ---
	if Input.is_action_just_pressed(RUN_ACTION) and not input_locked:
		toggle_run()

	if analog_input.is_valid():
		_process_analog(delta)
		return

	# --- Lopen ---
	var budget := current_speed() * delta  # hoeveel pixels we deze frame mogen bewegen
	if is_moving:
		budget = _step_towards_target(budget)

	if not is_moving:
		var dir := _read_direction()
		if _spawn_hold_actief():
			dir = Vector2i.ZERO
		if hold_until_release and dir != facing:
			hold_until_release = false
		if dir == Vector2i.ZERO:
			_walk_distance = 0.0
			_bump_tile = Vector2i(-9999, -9999)
		else:
			facing = dir
			if hold_until_release:
				pass   # duw: speler blijft staan
			elif _can_move(dir):
				_target = position + Vector2(dir) * TILE_SIZE
				is_moving = true
				_run_left = RUN_TILES - 1 if run_on() else 0
				_bump_tile = Vector2i(-9999, -9999)
				# Gebruik de overgebleven beweging meteen: zo loop je zonder haperen door.
				_step_towards_target(budget)
			else:
				_walk_distance = 0.0
				if get_tile() + dir != _bump_tile:
					_bump_tile = get_tile() + dir
					_try_bump()

	_update_sprite()


## SoM-proef: analoge modus aan (provider = Callable -> Vector2) of uit (Callable()).
## Kleinere botsing aan de voeten (10x8) zodat je soepel door 1-tegel-gangen glijdt.
func set_analog(provider: Callable, speed := 80.0) -> void:
	analog_input = provider
	analog_speed = speed
	is_moving = false
	_target = position
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if provider.is_valid() else CharacterBody2D.MOTION_MODE_GROUNDED
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and provider.is_valid():
		var r := RectangleShape2D.new()
		r.size = SomSlide.HIT_SIZE
		cs.shape = r
		cs.position = SomSlide.HIT_OFF


func _action_pose_active() -> bool:
	return get_node_or_null("SomCastAnim") != null or get_node_or_null("SomAttackAnim") != null


func _process_analog(delta: float) -> void:
	var v := Vector2.ZERO
	if not input_locked and not GameState.changing_map and not GameState.in_battle:
		v = analog_input.call()
	if _spawn_hold_actief():
		v = Vector2.ZERO
	var lock_face := Vector2i.ZERO
	if facing_provider.is_valid():
		lock_face = facing_provider.call()
	if v != Vector2.ZERO:
		if lock_face != Vector2i.ZERO and not _action_pose_active():
			facing = lock_face
		else:
			facing = SomMove.facing_for(v, facing)
	var before := position
	var old_tile := get_tile()
	velocity = v * analog_speed
	if velocity != Vector2.ZERO:
		# Logische tegels (is_wall) gaan voor op TileSet-physics: die cache deelt
		# kamers en kan na AtlasZuinig/grote frames 1–2 px in een muur tunnelllen.
		var wall := Callable(self, "_tegel_is_muur")
		var left := delta
		var speed := velocity.length()
		while left > 0.0001:
			var dt := left
			if speed > 0.0 and speed * dt > SomSlide.MAX_STAP_PX:
				dt = SomSlide.MAX_STAP_PX / speed
			var voor := position
			var want := SomSlide.corrigeer(voor, voor + velocity * dt, wall)
			var motion := want - position
			if motion != Vector2.ZERO:
				move_and_collide(motion)
			position = SomSlide.corrigeer(voor, position, wall)
			left -= dt
	var moved := position.distance_to(before)
	if moved > 0.001:
		_walk_distance += moved
	else:
		_walk_distance = 0.0
	_target = position
	if get_tile() != old_tile:
		_bump_tile = Vector2i(-9999, -9999)
		stepped.emit(get_tile())
	elif v != Vector2.ZERO and moved < analog_speed * delta * 0.2:
		if get_tile() + facing != _bump_tile:
			_bump_tile = get_tile() + facing
			_try_bump()
	_update_sprite()


## Kamer-`is_wall` (data), niet de TileSet-physics. Geen node-cache: bij een
## kaartwissel zou een vastgehouden kamer-ref anders stale botsing geven.
func _tegel_is_muur(t: Vector2i) -> bool:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("is_wall"):
			return n.is_wall(t)
		n = n.get_parent()
	return false


## Beweeg richting het doel; geeft terug hoeveel beweging er "over" is.
func _step_towards_target(amount: float) -> float:
	var dist := position.distance_to(_target)
	if amount >= dist:
		position = _target
		_walk_distance += dist
		is_moving = false
		stepped.emit(get_tile())
		# RUN: dezelfde zet loopt nog een tegel door (als dat kan en er niets gebeurde bij de stap)
		if _run_left > 0:
			_run_left -= 1
			if not input_locked and not _scripted and not Dialog.is_open and not GameState.changing_map \
					and not GameState.in_battle and is_inside_tree() and _can_move(facing):
				_target = position + Vector2(facing) * TILE_SIZE
				is_moving = true
				return _step_towards_target(amount - dist)
			_run_left = 0
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
	MapSprite.zet_frame(sprite, DIR_ROW[facing], col)


## Andere kaartsprite (bv. 24x32 SoM-stijl); botsing blijft 14x14 aan de voeten.
func zet_sheet(tex: Texture2D, maat := Vector2i.ZERO) -> void:
	sprite.texture = tex
	frame_maat = maat
	MapSprite.pas_toe(sprite, maat)
	_update_sprite()


## Zet de speler direct op een tile (bv. terug na een gevecht).
func place_at(tile: Vector2i, new_facing: Vector2i) -> void:
	position = Vector2(tile) * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)
	_target = position
	is_moving = false
	_run_left = 0
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
