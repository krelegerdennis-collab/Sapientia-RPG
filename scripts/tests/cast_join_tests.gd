extends Node
## WM1-bugfix: kaart-cast na late party join (scripts/tests/cast_join_autotest.gd).
## Start: godot --path . -- --castjointest

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 300 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func scene() -> Node:
	return get_tree().current_scene


func map_name() -> String:
	var s := scene()
	return String(s.name) if s != null else ""


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	for i in 2:
		await get_tree().process_frame
	Input.action_release(action)
	for i in 2:
		await get_tree().process_frame


func _run() -> void:
	GameState._finish_preload()
	GameState.encounter_multiplier = 0.0
	await preload("res://scripts/tests/cast_join_autotest.gd").new(self).run()
	print("CASTJOINTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
