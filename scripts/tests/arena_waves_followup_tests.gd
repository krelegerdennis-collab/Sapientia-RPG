extends Node
## Vervolgpunten review #487 (--arenawavesfollowuptest). Klus 14.
## A: geen magisch getal 7919 in arena_room.add_monster (determinisme gelijk).
## B: golf met 0 spawns blijft niet hangen in PHASE_WAVE.
## C: overgeslagen golf (hal-timeout / 0 spawns) geeft geen beloning.
## D: arena start niet in een co-op-sessie (LAN of online), geen netwerksync.
## CI-regel voegt Forge later toe (akkoord Dennis).

const WavesScript := preload("res://scripts/arena/som_arena_waves.gd")
const WavesData := preload("res://scripts/data/arena_waves_data.gd")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const FakeHallScript := preload("res://scripts/tests/arena_followup_fake_hall.gd")
const HALL := "res://scenes/arena/arena_hall.tscn"
const ROOM_SRC := "res://scripts/arena/arena_room.gd"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_all.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run_all() -> void:
	ReleaseFlags.arena_enabled_override = 1
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	_punt_a_bron()
	await _punt_a_determinisme()
	await _punt_b_nul_spawns()
	await _punt_c_timeout_geen_beloning()
	await _punt_c_echte_golf_wel_beloning()
	await _punt_d_coop_guard()
	ReleaseFlags.arena_enabled_override = -1
	check("ARENA_ENABLED blijft false", ReleaseFlags.ARENA_ENABLED == false)
	print("ARENAWAVESFOLLOWUPTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _await_frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _new_run(seed_value: int) -> Node:
	var run := RunScript.new()
	run.run_seed = seed_value
	add_child(run)
	return run


func _total_exp() -> int:
	var total := 0
	for raw in GameState.party:
		if typeof(raw) == TYPE_DICTIONARY:
			total += int((raw as Dictionary).get("exp", 0))
	return total


# --- Punt A ---------------------------------------------------------------

func _punt_a_bron() -> void:
	var f := FileAccess.open(ROOM_SRC, FileAccess.READ)
	var src := f.get_as_text() if f != null else ""
	check("A: arena_room.gd leesbaar", src != "")
	check("A: geen letterlijke 7919 in arena_room.gd", not src.contains("7919"))
	check("A: arena_room gebruikt MONSTER_RNG_STRIDE", src.contains("MONSTER_RNG_STRIDE"))
	check("A: stride-waarde ongewijzigd (7919)", WavesData.MONSTER_RNG_STRIDE == 7919)


## Zonder expliciete seed: seed = hash(room_id) + index * 7919, net als vóór de wijziging.
func _punt_a_determinisme() -> void:
	GameState.new_game("Dax")
	var hall: Node = (load(HALL) as PackedScene).instantiate()
	hall.name = "FollowupHallA"
	add_child(hall)
	await _await_frames(3)
	for m in hall.monsters:
		m.queue_free()
	hall.monsters.clear()
	var d := {"id": "a_test", "enemy": "mosslijm", "group": ["mosslijm"], "tile": [10, 8], "moves": false}
	var m0: Node = hall.add_monster(d.duplicate(), 0)
	var m1: Node = hall.add_monster(d.duplicate(), 0)
	var rid: String = str(hall.room_id)
	check("A: seed monster 0 = hash(room_id)", int(m0.rng.seed) == hash(rid) + 0 * 7919)
	check("A: seed monster 1 = hash(room_id) + 7919", int(m1.rng.seed) == hash(rid) + 1 * 7919)
	var m2: Node = hall.add_monster(d.duplicate(), 555)
	check("A: expliciete seed blijft leidend", int(m2.rng.seed) == 555)
	hall.queue_free()
	await _await_frames(3)


# --- Punt B ---------------------------------------------------------------

func _punt_b_nul_spawns() -> void:
	GameState.new_game("Dax")
	var fake: Node = FakeHallScript.new()
	fake.name = "FakeHallB"
	add_child(fake)
	var run := _new_run(1234)
	var waves: Node = run.get_node("Waves")
	var cleared: Array[int] = []
	waves.wave_cleared.connect(func(n: int) -> void: cleared.append(n))
	var exp_before := _total_exp()
	var tok_before := GameState.arena_tokens
	run.begin()
	await _await_frames(10)
	check("B: hal gevonden (fake, alles muur)", fake.wall_calls > 0)
	check("B: 0 monsters gespawnd", fake.monsters.is_empty())
	check("B: wave_cleared 1x voor wave 1", cleared.size() == 1 and cleared[0] == 1)
	check("B: run hangt niet in PHASE_WAVE", str(run.phase) != RunScript.PHASE_WAVE)
	check("B: run gaat naar keuze", str(run.phase) == RunScript.PHASE_CHOICE)
	check("B: golf gemarkeerd als overgeslagen", waves.has_method("wave_was_skipped") and waves.wave_was_skipped(1))
	check("B: geen XP voor lege golf", _total_exp() == exp_before and int(run.earned_xp) == 0)
	check("B: geen tokens voor lege golf", GameState.arena_tokens == tok_before and int(run.earned_tokens) == 0)
	check("B: waves_cleared telt lege golf niet", int(run.waves_cleared) == 0)
	run.queue_free()
	fake.queue_free()
	await _await_frames(3)


# --- Punt C ---------------------------------------------------------------

func _punt_c_timeout_geen_beloning() -> void:
	GameState.new_game("Dax")
	await _await_frames(2)
	check("C: geen arena_hall in de boom", get_tree().get_nodes_in_group("arena_hall").is_empty())
	var run := _new_run(5151)
	var waves: Node = run.get_node("Waves")
	var cleared: Array[int] = []
	waves.wave_cleared.connect(func(n: int) -> void: cleared.append(n))
	var exp_before := _total_exp()
	var tok_before := GameState.arena_tokens
	run.begin()
	await _await_frames(WavesData.HALL_FIND_MAX_FRAMES + 8)
	check("C: timeout geeft nog steeds 1x wave_cleared", cleared.size() == 1 and cleared[0] == 1)
	check("C: run gaat door naar keuze", str(run.phase) == RunScript.PHASE_CHOICE)
	check("C: golf gemarkeerd als overgeslagen", waves.has_method("wave_was_skipped") and waves.wave_was_skipped(1))
	check("C: geen XP bij timeout", _total_exp() == exp_before and int(run.earned_xp) == 0)
	check("C: geen tokens bij timeout", GameState.arena_tokens == tok_before and int(run.earned_tokens) == 0)
	check("C: waves_cleared 0 na timeout", int(run.waves_cleared) == 0)
	run.queue_free()
	await _await_frames(3)


## Controle: een echt verslagen golf levert nog de normale beloning.
func _punt_c_echte_golf_wel_beloning() -> void:
	GameState.new_game("Dax")
	var hall: Node = (load(HALL) as PackedScene).instantiate()
	hall.name = "FollowupHallC"
	add_child(hall)
	await _await_frames(3)
	var run := _new_run(77)
	var waves: Node = run.get_node("Waves")
	run.begin()
	await _await_frames(10)
	check("C: echte golf spawnt", hall.monsters.size() > 0)
	var ms: Array = hall.monsters.duplicate()
	if hall.som != null:
		for m in ms:
			hall.som.enemy_defeated.emit(m, 0, 0, [])
	await _await_frames(2)
	check("C: echte golf niet overgeslagen", waves.has_method("wave_was_skipped") and not waves.wave_was_skipped(1))
	check("C: echte golf geeft XP", int(run.earned_xp) > 0)
	check("C: echte golf telt mee", int(run.waves_cleared) == 1)
	run.queue_free()
	hall.queue_free()
	await _await_frames(3)


# --- Punt D ---------------------------------------------------------------

func _punt_d_coop_guard() -> void:
	GameState.new_game("Dax")
	var old_role: String = GameState.coop_role
	for role in ["guest", "host"]:
		GameState.coop_role = role
		var run := _new_run(99)
		run.begin()
		await _await_frames(2)
		check("D: %s: arena start niet" % role, str(run.phase) == RunScript.PHASE_LOBBY and int(run.wave) == 0)
		check("D: %s: geen actieve golf" % role, int(run.waves.active_wave) == 0)
		check("D: %s: coop_blocked() true" % role, run.has_method("coop_blocked") and run.coop_blocked())
		run.queue_free()
		await _await_frames(2)
	GameState.coop_role = ""
	var solo := _new_run(100)
	check("D: solo: coop_blocked() false", solo.has_method("coop_blocked") and not solo.coop_blocked())
	solo.begin()
	check("D: solo: arena start wel", str(solo.phase) == RunScript.PHASE_WAVE and int(solo.wave) == 1)
	solo.queue_free()
	GameState.coop_role = old_role
	await _await_frames(3)
