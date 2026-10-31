extends Node
## D3 PR A: BossScript + BossPhaseMachine + register()-gate. Start: godot --path . -- --bossphasetest

const BossScript := preload("res://scripts/som/boss_script.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")
const BossCore := preload("res://scripts/battle/boss_core.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")

const DUMMY_ID := "_boss_phase_test_dummy"
const DUMMY_SCRIPT := {
	"phases": [
		{"hp_until": 0.5, "attacks": [{"id": "a1", "weight": 1.0}], "adds": [], "on_enter": "phase1"},
		{"hp_until": 0.0, "attacks": [{"id": "b1", "weight": 1.0}], "adds": ["add_x", "add_y"], "on_enter": "phase2"},
	],
}

var failures := 0
var passes := 0


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
	_boss_script_tests()
	_phase_threshold_tests()
	_invuln_tests()
	_overkill_tests()
	_determinism_tests()
	_action_boss_stats_tests()
	_register_tests()
	BossScript.unregister(DUMMY_ID)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _machine(max_hp: int = 100, seed: int = 42) -> BossPhaseMachine:
	return BossPhaseMachine.new(DUMMY_SCRIPT, max_hp, seed)


func _boss_script_tests() -> void:
	BossScript.register(DUMMY_ID, DUMMY_SCRIPT)
	check("BossScript.has_script dummy", BossScript.has_script(DUMMY_ID))
	check("geen script voor kennis_beest (PR B)", not BossScript.has_script("kennis_beest"))
	var phases: Array = BossScript.script_for(DUMMY_ID).get("phases", [])
	check("parse_phases: 2 fases", phases.size() == 2)
	check("fase0 hp_until 0.5", is_equal_approx(float(phases[0]["hp_until"]), 0.5))


func _phase_threshold_tests() -> void:
	var m := _machine(100)
	check("start fase 0", m.phase_index() == 0)
	check("drempel fase0 = 50 hp", m.threshold_hp(0) == 50)
	m.on_damage(49)
	check("49 schade: nog fase 0", m.phase_index() == 0)
	m.on_damage(1)
	check("50 hp: fase 1", m.phase_index() == 1)


func _invuln_tests() -> void:
	var m := _machine(100)
	m.on_damage(50)
	check("na fase-wissel invuln", m.is_invulnerable())
	check("invuln 90 ticks", BossPhaseMachine.INVULN_TICKS == 90)
	var hp := m.current_hp()
	for _i in BossPhaseMachine.INVULN_TICKS - 1:
		m.tick()
	check("schade geblokkeerd tijdens invuln", m.on_damage(99) == 0 and m.current_hp() == hp)
	m.tick()
	check("invuln voorbij", not m.is_invulnerable())
	check("schade daarna wel", m.on_damage(1) == 1)


func _overkill_tests() -> void:
	var script := {
		"phases": [
			{"hp_until": 0.5, "attacks": [], "adds": [], "on_enter": ""},
			{"hp_until": 0.25, "attacks": [], "adds": [], "on_enter": ""},
			{"hp_until": 0.0, "attacks": [], "adds": [], "on_enter": ""},
		],
	}
	var m := BossPhaseMachine.new(script, 100, 1)
	m.on_damage(80)
	check("overkill: max 1 fase per schade", m.phase_index() == 1)
	var transitions := 0
	for ev in m.event_log():
		if str(ev.get("type", "")) == "phase_transition":
			transitions += 1
	check("overkill: precies 1 transition-event", transitions == 1)


func _event_types(log: Array) -> Array:
	var out: Array = []
	for ev in log:
		out.append(str(ev.get("type", "")))
	return out


func _determinism_tests() -> void:
	var a := BossPhaseMachine.new(DUMMY_SCRIPT, 100, 777)
	var b := BossPhaseMachine.new(DUMMY_SCRIPT, 100, 777)
	for _i in 120:
		a.tick()
		b.tick()
	a.on_damage(10)
	b.on_damage(10)
	a.pick_attack()
	b.pick_attack()
	check("zelfde seed -> zelfde event-log", _event_types(a.event_log()) == _event_types(b.event_log()))
	check("zelfde pick_attack", a.pick_attack() == b.pick_attack())


func _action_boss_stats_tests() -> void:
	var base := GameData.ENEMIES["kennis_beest"].duplicate(true)
	var applied := SomData.action_boss_stats(base, 2)
	var expected := BossCore.apply_boss(base)
	check("action_boss_stats = apply_boss (scale 1.0)", applied["max_hp"] == expected["max_hp"] and applied["atk"] == expected["atk"])
	check("boss_party_scale(4) = 1.0", is_equal_approx(SomData.boss_party_scale(4), 1.0))
	var mult := SomData.action_boss(expected.duplicate(true), true, SomData.START_LEVEL)
	check("legacy action_boss mult actief", int(mult["max_hp"]) > int(expected["max_hp"]))


func _register_tests() -> void:
	check("kennis_beest register geweigerd zonder BossScript", not BossScript.has_script("kennis_beest"))
	var arena := SomArena.new()
	arena.down = false
	var room_stub := _RoomStub.new()
	arena.room = room_stub
	var no_script := _BossMonster.new()
	no_script.enemy_id = "kennis_beest"
	arena.register(no_script)
	check("register: baas zonder script niet in enemies", not arena.enemies.has(no_script))
	BossScript.register("kennis_beest", DUMMY_SCRIPT)
	var with_script := _BossMonster.new()
	with_script.enemy_id = "kennis_beest"
	arena.register(with_script)
	check("register: baas met BossScript mag wel", arena.enemies.has(with_script))
	BossScript.unregister("kennis_beest")


class _BossMonster extends Node:
	var boss := true
	var enemy_id := ""
	var moves := true


class _RoomStub extends Node:
	var room_id := "archief_v1_gang"

	func tier() -> int:
		return 0
