class_name WarperBrain
extends RefCounted
## Vlieg-AI van de World Warper op de wereldkaart (puur beeld, geen botsing).
## Kleine toestandsmachine: CRUISE -> (BURST | HOVER | DESCEND) ; DESCEND -> LANDED -> ASCEND -> CRUISE.
## Los van de Node, zodat tests hem met een vaste seed sneller dan realtime kunnen draaien.

enum State { CRUISE, BURST, HOVER, DESCEND, LANDED, ASCEND }

# --- Tunables ---
const CRUISE_SPEED := 96.0        ## px/s (speler loopt 64, rent 128)
const CRUISE_VARIANCE := Vector2(0.8, 1.2)  ## per waypoint iets sneller/trager
const BURST_SPEED := 260.0        ## topsnelheid tijdens een burst
const HOVER_SPEED := 14.0
const STEER_ACCEL := 150.0        ## px/s^2 bijsturen in cruise (bepaalt de draaicirkel)
const BURST_ACCEL := 420.0
const BURST_BRAKE := 1.1          ## px/s extra snelheid per px afstand tot het doel
const BURST_CONE := 0.8           ## burst schiet ongeveer vooruit (radialen)
const BURST_TIME := Vector2(1.4, 2.4)      ## min/max seconden
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
const VIEW_PAD := -16.0           ## waypoints liefst zoveel binnen de beeldrand (negatief = inset)
const LAND_COOLDOWN := 12.0       ## minimaal tussen twee landingen
const LAND_FORCE_AFTER := 25.0    ## na zolang zonder landing: zeker landen
const LAND_PLAYER_MIN := 56.0     ## nooit vlak bij de speler landen
const LAND_SPOOK_DIST := 22.0     ## speler loopt erheen -> eerder opstijgen
const LAND_TRIES := 32
const HULL_HALF := Vector2(32.0, 16.0)  ## halve romp (128x64 op schaal 0.5)
const AVOID_MARGIN := 6.0         ## extra ruimte rond touch-knoppen
const AVOID_LOOKAHEAD := 28.0     ## vanaf deze afstand zacht wegsturen
const AVOID_SPEED_LOOK := 0.18   ## extra kijkafstand per px/s snelheid
const AVOID_DAMP := 8.0           ## 1/s: hoe snel snelheid naar de knop wegvalt
const AVOID_PUSH := 360.0         ## px/s^2 wegduwen in de zachte zone
const HULL_LIFT := 12.0           ## romp-midden boven het grondpunt (zelfde als flyover.GROUND_OFFSET)
const LAND_CONE := 0.9            ## radialen links/rechts van de vliegrichting
const LAND_DIST := Vector2(50.0, 150.0)
const LAND_VIEW_INSET := 36.0    ## landen liefst goed in beeld
## Kansen na het bereiken van een waypoint (rest = gewoon doorcruisen).
const P_BURST := 0.3
const P_HOVER := 0.12
const P_LAND := 0.25
const MAX_PLAIN_LEGS := 3         ## hoogstens zoveel gewone cruise-stukken achter elkaar

var rng := RandomNumberGenerator.new()
var state: State = State.CRUISE
var pos := Vector2.ZERO            ## grondpositie (de schaduw)
var vel := Vector2.ZERO
var alt := CRUISE_ALT
var bounds := Rect2(0, 0, 1024, 1024)
var view := Rect2()                ## leeg = geen camera-voorkeur
## true = zwerft over de hele wereldkaart en mag gerust buiten beeld vliegen (geen camera-klem).
var global_roam := true
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
var _approach_t := 0.0
var _cruise_v := CRUISE_SPEED
var _plain_legs := 0
## Wereld-rechthoeken van de touch-knoppen (al vergroot met romp + marge), per frame gezet.
var avoid: Array[Rect2] = []
var hard_pushes := 0  ## telt noodduwen (tests: moet zeldzaam zijn, anders schokt het)


func setup(seed_value: int, area: Rect2, start: Vector2) -> void:
	rng.seed = seed_value
	bounds = area
	pos = _clamp_in(start)
	alt = CRUISE_ALT
	since_land = LAND_COOLDOWN * 0.75
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
			_steer(_cruise_v, STEER_ACCEL, delta)
			if pos.distance_to(target) < ARRIVE_RADIUS * 3.0 or t_state > 9.0:
				_pick_next()
		State.BURST:
			# ease-in-out: snelheid volgt een sinusboog over de burst
			var f := clampf(t_state / dur_state, 0.0, 1.0)
			var top := lerpf(CRUISE_SPEED, BURST_SPEED, sin(f * PI))
			# op tijd afremmen: geen grote bocht ver buiten beeld
			top = minf(top, CRUISE_SPEED + pos.distance_to(target) * BURST_BRAKE)
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
				_approach_t += delta
				if _approach_t > 10.0:  # veiligheidsnet: plek onbereikbaar
					_enter(State.CRUISE)
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
	_avoid_buttons(delta)
	if state == State.LANDED and blocked(pos, 0.0):
		_enter(State.ASCEND)  # camera schoof een knop over het schip: opstijgen
	# veiligheidsnet: nooit buiten de kaart; rand = terugsturen
	var inner := bounds.grow(-EDGE_MARGIN * 0.5)
	if not inner.has_point(pos):
		pos = _clamp_in(pos)
		vel *= 0.5
		if state == State.CRUISE or state == State.BURST:
			target = _random_waypoint()


## Midden van de romp op het scherm voor grondpunt p op hoogte h.
func hull_center(p: Vector2, h: float) -> Vector2:
	return p - Vector2(0.0, HULL_LIFT + h)


## Knoppen in wereldcoördinaten -> rechthoeken waar het rompmidden niet mag komen.
func set_avoid_from_buttons(world_rects: Array[Rect2]) -> void:
	avoid.clear()
	for r in world_rects:
		avoid.append(r.grow_individual(HULL_HALF.x + AVOID_MARGIN, HULL_HALF.y + AVOID_MARGIN,
				HULL_HALF.x + AVOID_MARGIN, HULL_HALF.y + AVOID_MARGIN))


func blocked(p: Vector2, h: float) -> bool:
	var c := hull_center(p, h)
	for r in avoid:
		if r.has_point(c):
			return true
	return false


## Zacht om knoppen heen sturen, en hard eruit duwen als hij er toch in zou komen.
func _avoid_buttons(delta: float) -> void:
	if avoid.is_empty():
		return
	var h := visual_alt()
	for r in avoid:
		var c := hull_center(pos, h)
		var vooruit := AVOID_LOOKAHEAD + vel.length() * AVOID_SPEED_LOOK
		var zacht := r.grow(vooruit)
		if not zacht.has_point(c):
			continue
		var weg := _out_vector(r, c)
		if r.has_point(c):
			hard_pushes += 1
			pos += weg  # hard: naar de dichtstbijzijnde rand
			var n := weg.normalized()
			if vel.dot(n) < 0.0:
				vel -= n * vel.dot(n)
		else:
			var dichtbij := 1.0 - clampf(_dist_out(r, c) / vooruit, 0.0, 1.0)
			var n := _away_dir(r, c)
			vel += n * AVOID_PUSH * dichtbij * delta
			var naar := -vel.dot(n)
			if naar > 0.0:  # snelheid richting de knop wegnemen (afremmen + langs glijden)
				vel += n * naar * minf(1.0, AVOID_DAMP * dichtbij * delta)


## Kortste verschuiving die punt c buiten r zet.
static func _out_vector(r: Rect2, c: Vector2) -> Vector2:
	var l := c.x - r.position.x
	var rr := r.end.x - c.x
	var t := c.y - r.position.y
	var b := r.end.y - c.y
	var m := minf(minf(l, rr), minf(t, b))
	if m == l:
		return Vector2(-l - 0.5, 0)
	if m == rr:
		return Vector2(rr + 0.5, 0)
	if m == t:
		return Vector2(0, -t - 0.5)
	return Vector2(0, b + 0.5)


static func _dist_out(r: Rect2, c: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - c.x, c.x - r.end.x), 0.0)
	var dy := maxf(maxf(r.position.y - c.y, c.y - r.end.y), 0.0)
	return Vector2(dx, dy).length()


static func _away_dir(r: Rect2, c: Vector2) -> Vector2:
	var q := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	var d := c - q
	return d.normalized() if d.length() > 0.01 else (c - r.get_center()).normalized()


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
	if _plain_legs >= MAX_PLAIN_LEGS:
		r *= P_BURST + P_HOVER  # na een paar gewone stukken altijd iets bijzonders
	if r < P_BURST:
		_enter(State.BURST)
	elif r < P_BURST + P_HOVER:
		_enter(State.HOVER)
	else:
		_enter(State.CRUISE)


func _try_land() -> bool:
	for i in LAND_TRIES:
		var kegel := LAND_CONE if i < LAND_TRIES / 2 else LAND_CONE * 2.0
		var p := _land_candidate(kegel if i < LAND_TRIES - 4 else PI)
		if not global_roam and view.has_area() and not view.grow_individual(-LAND_VIEW_INSET, -LAND_VIEW_INSET - HULL_LIFT * 2.0,
				-LAND_VIEW_INSET, -LAND_VIEW_INSET * 0.5).has_point(p):
			continue
		if not bounds.grow(-EDGE_MARGIN).has_point(p) or player_pos.distance_to(p) < LAND_PLAYER_MIN:
			continue
		if blocked(p, 0.0) or blocked(p, CRUISE_ALT * 0.5) or blocked(p, CRUISE_ALT):
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
			_plain_legs += 1
			target = _random_waypoint()
			_cruise_v = CRUISE_SPEED * rng.randf_range(CRUISE_VARIANCE.x, CRUISE_VARIANCE.y)
		State.BURST:
			_plain_legs = 0
			bursts += 1
			dur_state = rng.randf_range(BURST_TIME.x, BURST_TIME.y)
			target = _burst_target()
		State.HOVER:
			_plain_legs = 0
			dur_state = rng.randf_range(HOVER_TIME.x, HOVER_TIME.y)
			target = pos + Vector2.from_angle(rng.randf() * TAU) * 20.0
		State.DESCEND:
			_plain_legs = 0
			_from_alt = alt
			_approach_t = 0.0
		State.LANDED:
			dur_state = rng.randf_range(LANDED_TIME.x, LANDED_TIME.y)
		State.ASCEND:
			target = _random_waypoint()


## Willekeurig punt in een willekeurige richting, binnen de kaart (global_roam: hele kaart, ook buiten beeld).
func _waypoint_area() -> Rect2:
	var area := bounds.grow(-EDGE_MARGIN)
	if not global_roam and view.has_area():
		# het schip hangt CRUISE_ALT + romp boven zijn grondpunt: beeld voor het grondpunt zakt mee
		var v := view.grow_individual(VIEW_PAD, -8.0, VIEW_PAD, -8.0)
		v.position.y += CRUISE_ALT + HULL_LIFT
		v = v.intersection(area)
		if v.has_area():
			area = v
	return area


func _random_waypoint(dist_mult := 1.0, kegel := PI) -> Vector2:
	var area := _waypoint_area()
	var best := pos
	for i in 12:
		var hoek := rng.randf() * TAU
		if kegel < PI and i < 8 and vel.length() > 5.0:
			hoek = vel.angle() + rng.randf_range(-kegel, kegel)
		var p := pos + Vector2.from_angle(hoek) * rng.randf_range(WAYPOINT_DIST.x, WAYPOINT_DIST.y) * dist_mult
		if area.has_point(p) and not blocked(p, CRUISE_ALT):
			return p
		best = p
	# geen punt in de buurt past: ergens binnen het gebied, liefst niet achter een knop
	for i in 8:
		var q := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if not blocked(q, CRUISE_ALT):
			return q
	return best if area.has_point(best) else area.get_center()


## Burst-doel: zo ver mogelijk weg binnen het gebied, liefst ongeveer vooruit (lange, snelle streep).
func _burst_target() -> Vector2:
	var area := _waypoint_area()
	var best := Vector2.INF
	var best_d := -1.0
	for i in 16:
		var hoek := rng.randf() * TAU
		if i < 10 and vel.length() > 5.0:
			hoek = vel.angle() + rng.randf_range(-BURST_CONE, BURST_CONE)
		var p := pos + Vector2.from_angle(hoek) * rng.randf_range(WAYPOINT_DIST.y * 0.6, WAYPOINT_DIST.y * 1.3)
		p = Vector2(clampf(p.x, area.position.x, area.end.x), clampf(p.y, area.position.y, area.end.y))
		var d := pos.distance_to(p)
		if d > best_d and not blocked(p, CRUISE_ALT):
			best = p
			best_d = d
	return best if best_d > 0.0 else _random_waypoint()


## Landplek: liefst vóór de neus (kegel), zodat hij er in één boog heen glijdt.
func _land_candidate(kegel: float) -> Vector2:
	var hoek := rng.randf() * TAU
	if vel.length() > 5.0:
		hoek = vel.angle() + rng.randf_range(-kegel, kegel)
	return pos + Vector2.from_angle(hoek) * rng.randf_range(LAND_DIST.x, LAND_DIST.y)


func _clamp_in(p: Vector2) -> Vector2:
	var a := bounds.grow(-EDGE_MARGIN * 0.5)
	return Vector2(clampf(p.x, a.position.x, a.end.x), clampf(p.y, a.position.y, a.end.y))


static func _smooth(f: float) -> float:
	return f * f * (3.0 - 2.0 * f)
