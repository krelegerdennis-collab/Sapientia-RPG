extends Node
## WM1 frametime-log (headless): elke WM1-kamer, één regel WM1FRAME met proc_ms, draw calls en nodes.
## Start: godot --path . -- --wm1frametest [--only=id,id] [--warmup=N] [--frames=N]
## Of: GODOT=... .github/scripts/run_suite.sh wm1frametest

const Wm1FrametimeScript := preload("res://scripts/perf/wm1_frametime.gd")

var failures := 0
var passes := 0
var sampler := Wm1FrametimeScript.new()
var only: PackedStringArray = []
var warmup := Wm1FrametimeScript.DEFAULT_WARMUP
var frames := Wm1FrametimeScript.DEFAULT_FRAMES


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--warmup="):
			warmup = maxi(int(arg.get_slice("=", 1)), 5)
		elif arg.begins_with("--frames="):
			frames = maxi(int(arg.get_slice("=", 1)), 10)
	get_tree().create_timer(2400.0, true, false, true).timeout.connect(func():
		check("waakhond: frametime-log klaar binnen 2400 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _wanted(id: String) -> bool:
	return only.is_empty() or id in only


func _run() -> void:
	print("WM1FRAMETEST rooms=%d warmup=%d frames=%d" % [Wm1FrametimeScript.rooms().size(), warmup, frames])
	for room in Wm1FrametimeScript.rooms():
		var rid: String = room["id"]
		if not _wanted(rid):
			continue
		var ok := await sampler.enter_room(get_tree(), room)
		check("%s: scène geladen (%s)" % [rid, room["path"]], ok)
		if not ok:
			continue
		var m := await sampler.sample_idle(get_tree(), warmup, frames)
		print(Wm1FrametimeScript.log_line(rid, room["path"], m))
	print("WM1FRAMETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)
