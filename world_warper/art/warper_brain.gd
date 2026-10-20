class_name WarperBrain
extends RefCounted
## Vlieg-AI van de World Warper op de wereldkaart (puur beeld, geen botsing).
## Kleine toestandsmachine: CRUISE -> (BURST | HOVER | DESCEND) ; DESCEND -> LANDED -> ASCEND -> CRUISE.
## Los van de Node, zodat tests hem met een vaste seed sneller dan realtime kunnen draaien.

enum State { CRUISE, BURST, HOVER, DESCEND, LANDED, ASCEND }

# --- Tunables ---
const CRUISE_SPEED := 96.0        ## px/s (speler loopt 64, rent 128)
const BURST_SPEED := 260.0        ## topsnelheid tijdens een burst
const HOVER_SPEED := 14.0
const STEER_ACCEL := 150.0        ## px/s^2 bijsturen in cruise (bepaalt de draaicirkel)
const BURST_ACCEL := 420.0
const BURST_TIME := Vector2(1.2, 2.0)      ## min/max seconden
const HOVER_TIME := Vector2(1.5, 3.5)
const LANDED_TIME := Vector2(2.5, 5.0)
const CRUISE_ALT := 34.0          ## px boven de grond
const BOB_AMP := 2.5
const BOB_FREQ := 2.2
const DESCEND_TIME := 1.6
const ASCEND_TIME := 1.1
const WAYPOINT_DIST := Vector2(110.0, 320.0)
const ARRIVE_RADIUS := 14.0
const EDGE_MARGIN := 24.0
const VIEW_PAD := 140.0           ## waypoints liefst binnen beeld + deze rand
const LAND_COOLDOWN := 12.0       ## minimaal tussen twee landingen
const LAND_FORCE_AFTER := 35.0    ## na zolang zonder landing: zeker landen
const LAND_PLAYER_MIN := 56.0     ## nooit vlak bij de speler landen
const LAND_SPOOK_DIST := 22.0     ## speler loopt erheen -> eerder opstijgen
const LAND_TRIES := 24
## Kansen na het bereiken van een waypoint (rest = gewoon doorcruisen).
const P_BURST := 0.24
const P_HOVER := 0.16
const P_LAND := 0.16

var rng := RandomNumberGenerator.new()
var state: State = State.CRUISE
var pos := Vector2.ZERO            ## grondpositie (de schaduw)
var vel := Vector2.ZERO
var alt := CRUISE_ALT
var bounds := Rect2(0, 0, 1024, 1024)
var view := Rect2()                ## leeg = geen camera-voorkeur
var player_pos := Vector2(INF, INF)
## Callable(Vector2) -> bool: mag hier geland worden? Leeg = overal.
var landable: Callable
var target := Vector2.ZERO
var t_state := 0.0
var dur_state := 0.0
var t_total := 0.0
var since_land := 0.0
var bursts := 0
var landings := 0
var _from_alt := 0.0


func setup(seed_value: int, area: Rect2, start: Vector2) -> void:
	rng.seed = seed_value
	bounds = area
	pos = _clamp_in(start)
	alt = CRUISE_ALT
	since_land = LAND_COOLDOWN * 0.5
	_enter(State.CRUISE)


func airborne() -> bool:
	return state != State.LANDED


## Hoogte inclusief deining (voor de sprite).
func visual_alt() -> float:
	if state == State.CRUISE or state == State.BURST or state == State.HOVER:
		return alt + sin(t_total * BOB_FREQ * TAU / 2.0) * BOB_AMP
	return alt


func step(delta: float) -> void:
	t_total += delta
	t_state += delta
	since_land += delta
	match state:
		State.CRUISE:
			_steer(CRUISE_SPEED, STEER_ACCEL, delta)
			if pos.distance_to(target) < ARRIVE_RADIUS * 3.0 or t_state > 9.0:
				_pick_next()
		State.BURST:
			# ease-in-out: snelheid volgt een sinusboog over de burst
			var f := clampf(t_state / dur_state, 0.0, 1.0)
			var top := lerpf(CRUISE_SPEED, BURST_SPEED, sin(f * PI))
			_steer(top, BURST_ACCEL, delta)
			if f >= 1.0 or pos.distance_to(target) < ARRIVE_RADIUS * 2.0:
				_enter(State.CRUISE)
		State.HOVER:
			_steer(HOVER_SPEED, STEER_ACCEL * 0.5, delta)
			if t_state >= dur_state:
				_enter(State.CRUISE)
		State.DESCEND:
			var d := pos.distance_to(target)
			if d > ARRIVE_RADIUS:
				# aanvliegen, afremmen in de laatste 60 px
				_steer(clampf(d * 1.6, 18.0, CRUISE_SPEED), STEER_ACCEL * 1.4, delta)
				t_state = 0.0
			else:
				vel = vel.move_toward(Vector2.ZERO, 200.0 * delta)
				pos = pos.move_toward(target, 20.0 * delta)
				var f := clampf(t_state / DESCEND_TIME, 0.0, 1.0)
				alt = lerpf(_from_alt, 0.0, _smooth(f))
				if f >= 1.0:
					alt = 0.0
					vel = Vector2.ZERO
					landings += 1
					since_land = 0.0
					_enter(State.LANDED)
		State.LANDED:
			vel = Vector2.ZERO
			if t_state >= dur_state or pos.distance_to(player_pos) < LAND_SPOOK_DIST:
				_enter(State.ASCEND)
		State.ASCEND:
			var f := clampf(t_state / ASCEND_TIME, 0.0, 1.0)
			alt = lerpf(0.0, CRUISE_ALT, _smooth(f))
			if f > 0.5:
				_steer(CRUISE_SPEED * 0.6, STEER_ACCEL, delta)
			if f >= 1.0:
				_enter(State.CRUISE)
	if state != State.LANDED and state != State.ASCEND:
		if state != State.DESCEND:
			alt = move_toward(alt, CRUISE_ALT, 30.0 * delta)
	pos += vel * delta
	# veiligheidsnet: nooit buiten de kaart; rand = terugsturen
	var inner := bounds.grow(-EDGE_MARGIN * 0.5)
	if not inner.has_point(pos):
		pos = _clamp_in(pos)
		vel *= 0.5
		if state == State.CRUISE or state == State.BURST:
			target = _random_waypoint()


func _steer(speed: float, accel: float, delta: float) -> void:
	var to := target - pos
	var desired := Vector2.ZERO if to.length() < 0.5 else to.normalized() * speed
	vel = vel.move_toward(desired, accel * delta)


func _pick_next() -> void:
	var r := rng.randf()
	var mag_landen := since_land >= LAND_COOLDOWN
	if since_land >= LAND_FORCE_AFTER or (mag_landen and r < P_LAND):
		if _try_land():
			return
	r = rng.randf()
	if r < P_BURST:
		_enter(State.BURST)
	elif r < P_BURST + P_HOVER:
		_enter(State.HOVER)
	else:
		_enter(State.CRUISE)


func _try_land() -> bool:
	for i in LAND_TRIES:
		var p := _random_waypoint(0.6)
		if player_pos.distance_to(p) < LAND_PLAYER_MIN:
			continue
		if landable.is_valid() and not bool(landable.call(p)):
			continue
		target = p
		_enter(State.DESCEND)
		return true
	return false


func _enter(s: State) -> void:
	state = s
	t_state = 0.0
	match s:
		State.CRUISE:
			target = _random_waypoint()
		State.BURST:
			bursts += 1
			dur_state = rng.randf_range(BURST_TIME.x, BURST_TIME.y)
			target = _random_waypoint(1.6)
		State.HOVER:
			dur_state = rng.randf_range(HOVER_TIME.x, HOVER_TIME.y)
			target = pos + Vector2.from_angle(rng.randf() * TAU) * 20.0
		State.DESCEND:
			_from_alt = alt
		State.LANDED:
			dur_state = rng.randf_range(LANDED_TIME.x, LANDED_TIME.y)
		State.ASCEND:
			target = _random_waypoint()


## Willekeurig punt in een willekeurige richting, binnen kaart (en liefst rond het beeld).
func _random_waypoint(dist_mult := 1.0) -> Vector2:
	var area := bounds.grow(-EDGE_MARGIN)
	if view.has_area():
		var v := view.grow(VIEW_PAD).intersection(area)
		if v.has_area():
			area = v
	var best := pos
	for i in 8:
		var hoek := rng.randf() * TAU
		var p := pos + Vector2.from_angle(hoek) * rng.randf_range(WAYPOINT_DIST.x, WAYPOINT_DIST.y) * dist_mult
		if area.has_point(p):
			return p
		best = p
	# geen punt in de buurt past: ergens binnen het gebied
	return Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)) \
			if not area.has_point(best) else best


func _clamp_in(p: Vector2) -> Vector2:
	var a := bounds.grow(-EDGE_MARGIN * 0.5)
	return Vector2(clampf(p.x, a.position.x, a.end.x), clampf(p.y, a.position.y, a.end.y))


static func _smooth(f: float) -> float:
	return f * f * (3.0 - 2.0 * f)
