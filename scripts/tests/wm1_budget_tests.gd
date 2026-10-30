extends Node
## WM1 performance-budget (headless): zelfde meting als wm1frametest, faalt bij regressie t.o.v.
## scripts/data/wm1_perf_budget.gd. Geen wijziging aan bestaande suites.
## Start: godot --path . -- --wm1budgettest [--only=id,id]
## Of: GODOT=... .github/scripts/run_suite.sh wm1budgettest

const Wm1FrametimeScript := preload("res://scripts/perf/wm1_frametime.gd")
const Budget := preload("res://scripts/data/wm1_perf_budget.gd")

var failures := 0
var passes := 0
var sampler := Wm1FrametimeScript.new()
var only: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",", false)
	get_tree().create_timer(2400.0, true, false, true).timeout.connect(func():
		check("waakhond: budgettest klaar binnen 2400 s", false)
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
	var verwacht := 0
	for room in Wm1FrametimeScript.rooms():
		if Budget.has_room(room["id"]):
			verwacht += 1
	check("budgetdata dekt minstens één kamer", verwacht > 0)
	for room in Wm1FrametimeScript.rooms():
		var rid: String = room["id"]
		if not _wanted(rid):
			continue
		if not Budget.has_room(rid):
			check("%s: geen budgetregel (overgeslagen)" % rid, true)
			continue
		var lim: Dictionary = Budget.limit(rid)
		var ok_load := await sampler.enter_room(get_tree(), room)
		if not ok_load:
			check("%s: scène geladen" % rid, false)
			continue
		var m := await sampler.sample_idle(get_tree(), Budget.WARMUP_FRAMES, Budget.SAMPLE_FRAMES)
		print(Wm1FrametimeScript.log_line(rid, room["path"], m))
		check("%s: proc_ms %.3f <= %.3f" % [rid, m["proc_ms"], lim["max_proc_ms"]],
				m["proc_ms"] <= float(lim["max_proc_ms"]))
		check("%s: draw_avg %.1f <= %.1f" % [rid, m["draw_avg"], lim["max_draw_avg"]],
				m["draw_avg"] <= float(lim["max_draw_avg"]))
		check("%s: draw_max %d <= %d" % [rid, m["draw_max"], lim["max_draw_max"]],
				m["draw_max"] <= int(lim["max_draw_max"]))
		check("%s: scene_nodes %d <= %d" % [rid, m["scene_nodes"], lim["max_scene_nodes"]],
				m["scene_nodes"] <= int(lim["max_scene_nodes"]))
		check("%s: nodes %d <= %d" % [rid, m["nodes"], lim["max_nodes"]],
				m["nodes"] <= int(lim["max_nodes"]))
	print("WM1BUDGETTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)
