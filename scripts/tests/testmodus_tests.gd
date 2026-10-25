extends Node
## Testmodus (--testmodustest): de stabiliteitshaken uit O-4 (flaky berggrottest onder load).
## Start: godot --path . -- --testmodustest
##   Deel A: GameState.test_modus staat aan; de physics-gelijk-lijst (berggrottest) loopt nooit sneller dan beelden.
##   Deel B: World Warper-flyover gebruikt in een test een vaste seed (niet de klok).
## Zit niet in de export (scripts/tests/*).

const Flyover := preload("res://world_warper/art/flyover.gd")
const FRAMES := 90

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: test klaar binnen 120 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: testmodus ===")
	await _modus_tests()
	print("=== Deel B: vaste warper-seed ===")
	_warper_seed_tests()
	print("TESTMODUSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)


func _modus_tests() -> void:
	check("GameState.test_modus staat aan in een --...test-suite", GameState.test_modus)
	check("berggrottest staat op de physics-gelijk-lijst", "berggrottest" in GameState.PHYSICS_GELIJK_SUITES)
	check("menutest en woudtest niet (die hangen af van physics op wandkloktijd)",
			not ("menutest" in GameState.PHYSICS_GELIJK_SUITES) and not ("woudtest" in GameState.PHYSICS_GELIJK_SUITES))
	var standaard := Engine.max_physics_steps_per_frame
	GameState._zet_testmodus("woudtest")
	check("suite buiten de lijst: physics-limiet ongewijzigd", Engine.max_physics_steps_per_frame == standaard)
	GameState._zet_testmodus("berggrottest")
	check("suite op de lijst: max 1 physics-stap per beeld", Engine.max_physics_steps_per_frame == 1)
	for _i in 10:   # eerst de achterstand van vóór de limiet laten weglopen
		await get_tree().process_frame
	var p0 := Engine.get_physics_frames()
	var f0 := Engine.get_process_frames()
	for _i in FRAMES:
		await get_tree().process_frame
	var dp := Engine.get_physics_frames() - p0
	var df := Engine.get_process_frames() - f0
	print("INFO  %d beelden, %d physics-frames" % [df, dp])
	check("physics-frames lopen niet voor op beelden (%d <= %d)" % [dp, df], dp <= df)
	Engine.max_physics_steps_per_frame = standaard


func _maak_flyover(seed_override: int) -> Node2D:
	var ouder := Node2D.new()
	var fly := Flyover.new() as Node2D
	fly.seed_override = seed_override
	ouder.add_child(fly)
	add_child(ouder)
	return fly


func _warper_seed_tests() -> void:
	var a := _maak_flyover(-1)
	var b := _maak_flyover(-1)
	var c := _maak_flyover(7)
	check("flyover zonder seed_override: vaste test-seed", a.brain.rng.seed == Flyover.TEST_SEED)
	check("twee flyovers: zelfde eerste waypoint", a.brain.target == b.brain.target)
	check("seed_override wint nog van de test-seed", c.brain.rng.seed == 7)
	for fly in [a, b, c]:
		(fly.get_parent() as Node).queue_free()
