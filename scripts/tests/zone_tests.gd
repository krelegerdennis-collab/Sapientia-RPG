extends Node
## Zones / Inktplas (Combat T4b). Start: godot --headless --path . -- --zonetest

const CombatZones := preload("res://scripts/som/combat_zones.gd")
const CombatSim := preload("res://scripts/som/combat_sim.gd")
const EnemyAttacks := preload("res://scripts/som/enemy_attacks.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const SomActionAttacks := preload("res://scripts/data/som_action_attacks.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const TelegraphSnapshot := preload("res://scripts/net/telegraph_snapshot.gd")

const PIN_COOLDOWN_MS := 1200

var failures := 0
var passes := 0
var _iframes: Dictionary = {}
var _dot_hits := 0
var _iframes_after_dot := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_inktplas_data_tests()
	_limit_tests()
	_dot_schedule_tests()
	_iframe_dot_tests()
	_cancel_windup_no_zone_tests()
	_owner_ko_clear_tests()
	_party_down_clear_tests()
	_determinism_frame_times_tests()
	_coop_zone_wire_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _inktplas_data_tests() -> void:
	var def: Dictionary = EnemyAttacks.attack("inktplas")
	check("inktplas: circle r 24 (1.5 tegel)", int(def.get("reach", 0)) == EnemyAttacks.INKPLAS_RADIUS_PX)
	check("inktplas windup 42 ticks", TelegraphState.ms_to_ticks(int(def.get("windup_ms", 0))) == 42)
	check("inktplas zone 120 ticks", int(def.get("zone_ticks", 0)) == 120)
	check("inktplas power 0.8 / dot 0.3", is_equal_approx(float(def.get("power", 0)), 0.8) and is_equal_approx(float(def.get("zone_dot_power", 0)), 0.3))
	check("snapshot atk_id inktplas", TelegraphSnapshot.attack_index("inktplas") == 2)


func _limit_tests() -> void:
	var z := CombatZones.new()
	var origin := Vector2i(50, 50)
	for i in CombatZones.MAX_ARENA:
		check("spawn zone %d" % i, z.try_spawn(i, origin + Vector2i(i, 0), 24, 120, 44, 0.3, 0.6))
	check("arena max 6: 7e geweigerd", not z.try_spawn(0, origin, 24, 120, 44, 0.3, 0.6))
	z.clear_all()
	for i in CombatZones.MAX_PER_OWNER:
		check("owner spawn %d" % i, z.try_spawn(3, origin + Vector2i(i, 0), 24, 120, 44, 0.3, 0.6))
	check("max 2 per owner: 3e geweigerd", not z.try_spawn(3, origin, 24, 120, 44, 0.3, 0.6))
	check("ticks clamp 120", z.try_spawn(1, origin, 24, 999, 44, 0.3, 0.6) and z.zones_for_draw()[0]["ticks_left"] == 120)


func _dot_schedule_tests() -> void:
	var z := CombatZones.new()
	z.try_spawn(0, Vector2i(0, 0), 24, 120, 44, 0.3, 0.6)
	var dot_ticks: Array = []
	for _t in 120:
		var dots: Array = z.tick()
		if dots.size() > 0:
			dot_ticks.append(_t + 1)
	check("DoT op tick 30/60/90", dot_ticks == [30, 60, 90])
	check("zone weg na 120 ticks", z.count() == 0)


func _iframe_dot_tests() -> void:
	_iframes = {"hero": 0.5}
	_dot_hits = 0
	var z := CombatZones.new()
	z.try_spawn(0, Vector2i(0, 0), 24, 60, 44, 0.3, 0.6)
	for _t in 30:
		_consume_dots(z, "hero")
	check("iframes: geen DoT-schade", _dot_hits == 0)
	z.clear_all()
	z.try_spawn(0, Vector2i(0, 0), 24, 60, 44, 0.3, 0.6)
	_iframes = {"hero": 0.0}
	for _t in 30:
		_consume_dots(z, "hero")
	check("zonder iframes: DoT telt", _dot_hits == 1)
	_iframes_after_dot = float(_iframes.get("hero", 0.0))
	check("DoT zet geen hit-invuln", _iframes_after_dot == 0.0)


func _consume_dots(z: CombatZones, hid: String) -> void:
	var px := Vector2i(0, 0)
	var dots: Array = z.tick()
	for row in dots:
		if z.contains_point(px, row) and float(_iframes.get(hid, 0.0)) <= 0.0:
			_dot_hits += 1


func _cancel_windup_no_zone_tests() -> void:
	var def: Dictionary = SomActionAttacks.attack("inktplas")
	var tg := TelegraphAttack.new()
	tg.configure(def, PIN_COOLDOWN_MS)
	var zones := CombatZones.new()
	tg.start(Vector2i(10, 10), Vector2i(256, 0), "circle")
	for _i in 10:
		tg.tick()
	check("windup niet klaar", tg.in_windup())
	tg.cancel()
	check("cancel in windup", not tg.is_busy())
	for _i in 40:
		tg.tick()
	check("cancel: geen ACTIVE, dus geen zone", zones.count() == 0)


func _owner_ko_clear_tests() -> void:
	var z := CombatZones.new()
	z.try_spawn(2, Vector2i(1, 1), 24, 120, 44, 0.3, 0.6)
	z.try_spawn(2, Vector2i(2, 2), 24, 120, 44, 0.3, 0.6)
	z.try_spawn(4, Vector2i(3, 3), 24, 120, 44, 0.3, 0.6)
	z.clear_owner(2)
	check("owner KO: zones van eigenaar weg", z.count() == 1 and z.count_for_owner(2) == 0)


func _party_down_clear_tests() -> void:
	var z := CombatZones.new()
	z.try_spawn(0, Vector2i(0, 0), 24, 120, 44, 0.3, 0.6)
	z.clear_all()
	check("party down / arena clear", z.count() == 0)


func _determinism_frame_times_tests() -> void:
	var patterns: Array = [
		[1.0 / 60.0],
		[1.0 / 30.0],
		[1.0 / 144.0],
		[0.25, 0.02, 0.11],
		[0.008, 0.02, 0.11, 1.0 / 60.0],
	]
	var ref := _zone_event_log(patterns[0])
	for p in patterns:
		check("determinisme patroon %s" % str(p), _zone_event_log(p) == ref)


func _zone_event_log(chunk_deltas: Array) -> Array:
	var z := CombatZones.new()
	z.try_spawn(0, Vector2i(100, 100), 24, 90, 44, 0.3, 0.6)
	var clock := CombatSim.new()
	var log: Array = []
	var target_ticks := 95
	var produced := 0
	var ci := 0
	while produced < target_ticks:
		var d: float = chunk_deltas[ci % chunk_deltas.size()]
		ci += 1
		var n := clock.frames_to_ticks(d)
		for _i in n:
			if produced >= target_ticks:
				break
			produced += 1
			clock.tick += 1
			var dots: Array = z.tick()
			log.append("t%d" % clock.tick)
			if dots.size() > 0:
				log.append("DOT")
	return log


func _coop_zone_wire_tests() -> void:
	var z := CombatZones.new()
	z.try_spawn(1, Vector2i(40, 50), 24, 88, 44, 0.3, 0.6)
	var wire := Codec.pack_snapshot(9, [], [], z.wire_rows())
	var snap := Codec.unpack_snapshot(wire)
	check("co-op zones roundtrip count", int((snap.get("zones", []) as Array).size()) == 1)
	var row: Dictionary = (snap.get("zones", []) as Array)[0]
	check("co-op zone velden", int(row.get("ox", 0)) == 40 and int(row.get("oy", 0)) == 50 and int(row.get("r", 0)) == 24
			and int(row.get("ticks_left", 0)) == 88 and int(row.get("owner_idx", 0)) == 1)
	var guest := CombatZones.new()
	guest.apply_wire_rows(snap.get("zones", []))
	check("gast spiegelt host zones", guest.count() == 1 and guest.zones_for_draw()[0]["origin"] == Vector2i(40, 50))
