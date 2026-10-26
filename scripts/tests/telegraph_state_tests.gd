extends RefCounted
## TelegraphState (Combat T2). Draait via `telegraph_tests.gd` (--telegraphtest).
## Geen scène, geen gameplay.

const TelegraphState := preload("res://scripts/som/telegraph_state.gd")

## Vastgepind: SomData.TELEGRAPH 450 ms en ATTACK_COOLDOWN 1200 ms bij 60 Hz (mutatiecontrole op ms_to_ticks + cooldown-fase).
const PIN_WINDUP_MS := 450
const PIN_COOLDOWN_MS := 1200
const PIN_WINDUP_TICKS := 27
const PIN_COOLDOWN_TICKS := 72


func run_all(host: Node) -> void:
	_host = host
	_run()


var _host: Node


func _check(label: String, ok: bool) -> void:
	_host.call("check", label, ok)


func _run() -> void:
	_ms_to_ticks_tests()
	_invalid_input_tests()
	_zero_length_tests()
	_full_cycle_sequence_tests()
	_pinned_cooldown_tests()
	_start_while_busy_tests()
	_cancel_interrupt_tests()
	_determinism_tests()
	_long_run_no_drift_tests()
	_pure_class_tests()


func _ms_to_ticks_tests() -> void:
	_check("ms_to_ticks: 0 ms => 0", TelegraphState.ms_to_ticks(0) == 0)
	_check("ms_to_ticks: 1 ms => 1 tick (ceil)", TelegraphState.ms_to_ticks(1) == 1)
	_check("ms_to_ticks: 16 ms => 1 tick", TelegraphState.ms_to_ticks(16) == 1)
	_check("ms_to_ticks: 17 ms => 2 ticks", TelegraphState.ms_to_ticks(17) == 2)
	_check("ms_to_ticks: 450 ms => 27 ticks", TelegraphState.ms_to_ticks(PIN_WINDUP_MS) == PIN_WINDUP_TICKS)
	_check("ms_to_ticks: 1200 ms => 72 ticks", TelegraphState.ms_to_ticks(PIN_COOLDOWN_MS) == PIN_COOLDOWN_TICKS)
	_check("ms_to_ticks: 1000 ms => 60 ticks", TelegraphState.ms_to_ticks(1000) == 60)


func _invalid_input_tests() -> void:
	var s := TelegraphState.new()
	s.set_phase_ticks(2, 1, 1, 3)
	_check("geldige duur: valid", s.valid and s.invalid_reason == "")
	s.set_phase_ticks(-1, 1, 1, 1)
	_check("windup < 0 => ongeldig", not s.valid and s.invalid_reason.contains("windup"))
	_check("ongeldig: start() weigert", not s.start())
	_check("ongeldig: tick() blijft IDLE", s.state == TelegraphState.State.IDLE)
	s.set_phase_ticks(1, -2, 1, 1)
	_check("active < 0 => ongeldig", not s.valid)
	s.set_phase_ticks(1, 1, -1, 1)
	_check("recovery < 0 => ongeldig", not s.valid)
	s.set_phase_ticks(1, 1, 1, -5)
	_check("cooldown < 0 => ongeldig", not s.valid)


func _zero_length_tests() -> void:
	var s := TelegraphState.new()
	s.set_phase_ticks(0, 2, 0, 0)
	_check("start met windup 0: direct ACTIVE", s.start() and s.state == TelegraphState.State.ACTIVE and s.ticks_left == 2)
	s.tick()
	s.tick()
	_check("na active: recovery 0 => COOLDOWN overgeslagen => IDLE", s.state == TelegraphState.State.IDLE)
	var chain := TelegraphState.new()
	chain.set_phase_ticks(0, 0, 1, 0)
	_check("windup+active 0: land op RECOVERY", chain.start() and chain.state == TelegraphState.State.RECOVERY and chain.ticks_left == 1)
	var all0 := TelegraphState.new()
	all0.set_phase_ticks(0, 0, 0, 0)
	_check("alle fasen 0: start blijft IDLE", all0.start() and all0.state == TelegraphState.State.IDLE)


func _full_cycle_sequence_tests() -> void:
	var s := TelegraphState.new()
	s.set_phase_ticks(2, 1, 1, 3)
	var log: Array[String] = []
	log.append(_snap(s, "init"))
	_check("init IDLE", s.state == TelegraphState.State.IDLE and s.can_start)
	s.start()
	log.append(_snap(s, "start"))
	var expect: Array[String] = [
		"init:IDLE:0",
		"start:WINDUP:2",
		"t1:WINDUP:1",
		"t2:ACTIVE:1->ACTIVE",
		"t3:RECOVERY:1->RECOVERY",
		"t4:COOLDOWN:3->COOLDOWN",
		"t5:COOLDOWN:2",
		"t6:COOLDOWN:1",
		"t7:IDLE:0->IDLE",
		"t8:IDLE:0",
	]
	var step := 0
	for label in ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8"]:
		s.tick()
		step += 1
		var extra := ""
		if s.phase_changed:
			extra = "->%s" % _st(s.entered_state)
		log.append("%s:%s:%d%s" % [label, _st(s.state), s.ticks_left, extra])
	_check("volledige cyclus: per-tick log", log == expect)
	_check("na cyclus can_start", s.can_start)


func _pinned_cooldown_tests() -> void:
	_check("PIN windup ticks", TelegraphState.ms_to_ticks(PIN_WINDUP_MS) == PIN_WINDUP_TICKS)
	_check("PIN cooldown ticks", TelegraphState.ms_to_ticks(PIN_COOLDOWN_MS) == PIN_COOLDOWN_TICKS)
	var s := TelegraphState.new()
	s.set_phase_ms(PIN_WINDUP_MS, 0, 0, PIN_COOLDOWN_MS)
	_check("set_phase_ms windup 27", s.start() and s.ticks_left == PIN_WINDUP_TICKS)
	for i in PIN_WINDUP_TICKS:
		s.tick()
	_check("na windup (active/recovery 0) => COOLDOWN 72", s.state == TelegraphState.State.COOLDOWN and s.ticks_left == PIN_COOLDOWN_TICKS)
	var cd_left := PIN_COOLDOWN_TICKS
	while s.state == TelegraphState.State.COOLDOWN:
		s.tick()
		cd_left -= 1
	_check("cooldown verbruikt precies 72 ticks", cd_left == 0 and s.state == TelegraphState.State.IDLE)


func _start_while_busy_tests() -> void:
	var s := TelegraphState.new()
	s.set_phase_ticks(3, 1, 1, 2)
	_check("start ok", s.start())
	_check("busy: can_start false", not s.can_start)
	_check("start tijdens WINDUP geweigerd", not s.start())
	s.tick()
	_check("nog steeds geweigerd", not s.start())


func _cancel_interrupt_tests() -> void:
	var s := TelegraphState.new()
	s.set_phase_ticks(4, 2, 1, 5)
	s.start()
	_check("interrupt in WINDUP ok", s.interrupt() and s.state == TelegraphState.State.IDLE and s.phase_changed)
	s.start()
	s.tick()
	_check("cancel in WINDUP ok", s.cancel() and s.state == TelegraphState.State.IDLE)
	s.start()
	for i in 4:
		s.tick()
	_check("in ACTIVE", s.state == TelegraphState.State.ACTIVE)
	_check("cancel in ACTIVE ok", s.cancel() and s.state == TelegraphState.State.IDLE)
	s.start()
	for i in 4:
		s.tick()
	s.tick()
	s.tick()
	_check("interrupt in ACTIVE geweigerd", not s.interrupt() and s.state == TelegraphState.State.RECOVERY)
	var cd := TelegraphState.new()
	cd.set_phase_ticks(1, 1, 1, 3)
	cd.start()
	for i in 3:
		cd.tick()
	_check("in COOLDOWN", cd.state == TelegraphState.State.COOLDOWN and cd.ticks_left == 3)
	_check("cancel in COOLDOWN geweigerd", not cd.cancel())


func _determinism_tests() -> void:
	var a := TelegraphState.new()
	var b := TelegraphState.new()
	a.set_phase_ticks(2, 2, 1, 4)
	b.set_phase_ticks(2, 2, 1, 4)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	a.start()
	b.start()
	for t in 12:
		seq_a.append(a.state)
		seq_b.append(b.state)
		a.tick()
		b.tick()
	_check("twee instanties:zelfde state-reeks", seq_a == seq_b)


func _long_run_no_drift_tests() -> void:
	var s := TelegraphState.new()
	var w := 3
	var ac := 2
	var r := 1
	var c := 5
	s.set_phase_ticks(w, ac, r, c)
	var per_cycle := w + ac + r + c
	var cycles := 200
	var ticks := 0
	var ok_cycles := true
	for cycle in cycles:
		if not s.start():
			ok_cycles = false
			break
		var guard := 0
		while s.state != TelegraphState.State.IDLE:
			s.tick()
			ticks += 1
			guard += 1
			if guard > per_cycle + 2:
				ok_cycles = false
				break
	_check("200 cycli zonder hangen of drift", ok_cycles and s.can_start)
	_check("totaal ticks = cycli * som fasen (%d)" % (cycles * per_cycle), ticks == cycles * per_cycle)


func _pure_class_tests() -> void:
	var s := TelegraphState.new()
	var o: Object = s
	_check("RefCounted, geen Node", o is RefCounted and not (o is Node))
	var src := FileAccess.get_file_as_string("res://scripts/som/telegraph_state.gd")
	var code := ""
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	_check("geen RNG/tijd/node in bron", not (code.contains("randi") or code.contains("randf") or code.contains("RandomNumberGenerator")
			or code.contains("Time.") or code.contains("get_node") or code.contains("get_tree")
			or code.contains("extends Node")))


func _st(st: int) -> String:
	match st:
		TelegraphState.State.IDLE:
			return "IDLE"
		TelegraphState.State.WINDUP:
			return "WINDUP"
		TelegraphState.State.ACTIVE:
			return "ACTIVE"
		TelegraphState.State.RECOVERY:
			return "RECOVERY"
		TelegraphState.State.COOLDOWN:
			return "COOLDOWN"
	return "?"


func _snap(s: TelegraphState, _label: String) -> String:
	return "%s:%s:%d" % [_label, _st(s.state), s.ticks_left]
