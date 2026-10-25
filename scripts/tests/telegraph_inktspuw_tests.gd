extends RefCounted
## Inktspuw / TelegraphAttack (Combat T4a). Draait via telegraph_tests.gd (--telegraphtest).

const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const SomActionAttacks := preload("res://scripts/data/som_action_attacks.gd")
const SomData := preload("res://scripts/data/som_data.gd")

const PIN_COOLDOWN_MS := 1200
## 27 windup + 1 active + 72 cooldown (450 ms + 1 ms + 1200 ms @ 60 Hz).
const LEGACY_CYCLE_TICKS := 100


func run_all(host: Node) -> void:
	_host = host
	_run()


var _host: Node


func _check(label: String, ok: bool) -> void:
	_host.call("check", label, ok)


func _run() -> void:
	_data_mapping_tests()
	_hit_only_on_active_tick_tests()
	_dodge_before_active_tests()
	_locked_aim_tests()
	_cycle_length_tests()
	_determinism_two_runs_tests()


func _make_runner() -> TelegraphAttack:
	var def: Dictionary = SomActionAttacks.attack("inktspuw")
	var tg := TelegraphAttack.new()
	tg.configure(def, PIN_COOLDOWN_MS)
	return tg


func _data_mapping_tests() -> void:
	var def: Dictionary = SomActionAttacks.attack("inktspuw")
	_check("inktspuw data: line + reach/width", str(def.get("shape", "")) == "line" and int(def["reach"]) == 22 and int(def["width"]) == 44)
	_check("inktspuw windup_ms = TELEGRAPH 450 ms", int(def["windup_ms"]) == int(roundf(SomData.TELEGRAPH * 1000.0)))
	_check("fasen via ms_to_ticks: windup 27, cooldown 72", TelegraphState.ms_to_ticks(int(def["windup_ms"])) == 27
			and TelegraphState.ms_to_ticks(PIN_COOLDOWN_MS) == 72)


func _step_until_active(tg: TelegraphAttack) -> void:
	while tg.is_busy() and not tg.entered_active_this_tick():
		tg.tick()


func _hit_only_on_active_tick_tests() -> void:
	var tg := _make_runner()
	var origin := Vector2i(0, 0)
	var dir := Vector2i(256, 0)
	_check("start Inktspuw", tg.start(origin, dir, "line"))
	var target := Vector2i(20, 0)
	var active_hit_ticks := 0
	while tg.is_busy():
		if tg.entered_active_this_tick() and tg.hits_point_i(target):
			active_hit_ticks += 1
		tg.tick()
	_check("precies één ACTIVE-tick met treffer", active_hit_ticks == 1)


func _dodge_before_active_tests() -> void:
	var tg := _make_runner()
	var origin := Vector2i(100, 100)
	var dir := Vector2i(256, 0)
	tg.start(origin, dir, "line")
	var in_windup := Vector2i(120, 100)
	var out_before_active := Vector2i(100, 200)
	for _i in 26:
		tg.tick()
	_check("in de straal tijdens windup (locked shape)", tg.hits_point_i(in_windup))
	tg.tick()
	_check("ontwijken: buiten de vorm op ACTIVE => geen treffer", not tg.hits_point_i(out_before_active))


func _locked_aim_tests() -> void:
	var tg := _make_runner()
	var origin := Vector2i(50, 50)
	var dir := TelegraphShape.dir_from_degrees(0)
	tg.start(origin, dir, "line")
	var locked := tg.locked_dir()
	for _i in 10:
		tg.tick()
	_check("richting vast na windup-ticks", tg.locked_dir() == locked and tg.locked_origin() == origin)
	var south := Vector2i(50, 80)
	_check("doel zuidelijk tijdens windup telt niet (shape oost)", not tg.hits_point_i(south))
	tg.tick()
	_check("ACTIVE gebruikt nog steeds oostelijke richting", tg.hits_point_i(Vector2i(70, 50)) and not tg.hits_point_i(south))


func _cycle_length_tests() -> void:
	var def: Dictionary = SomActionAttacks.attack("inktspuw")
	var expected := SomActionAttacks.cycle_ticks(def, PIN_COOLDOWN_MS)
	_check("SomActionAttacks.cycle_ticks = 27+1+72", expected == LEGACY_CYCLE_TICKS)
	var tg := _make_runner()
	tg.start(Vector2i.ZERO, Vector2i(256, 0), "line")
	var n := 0
	while tg.is_busy():
		tg.tick()
		n += 1
	_check("volledige cyclus = oude TELEGRAPH+COOLDOWN ticks (100)", n == LEGACY_CYCLE_TICKS)
	_check("na cyclus weer IDLE/can_start", tg.can_start())


func _determinism_two_runs_tests() -> void:
	var log_a := _simulate_log()
	var log_b := _simulate_log()
	_check("twee runs: zelfde fase-log en treffer-tick", log_a == log_b and log_a.size() > 0)


func _simulate_log() -> Array:
	var tg := _make_runner()
	var log: Array = []
	tg.start(Vector2i(10, 10), Vector2i(0, 256), "line")
	var probe := Vector2i(10, 30)
	for _i in LEGACY_CYCLE_TICKS + 2:
		if tg.entered_active_this_tick():
			log.append("HIT" if tg.hits_point_i(probe) else "MISS")
		log.append(tg.state())
		if tg.is_busy():
			tg.tick()
	return log
