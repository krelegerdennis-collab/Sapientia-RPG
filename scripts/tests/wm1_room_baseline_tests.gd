extends Node
## F-5 nulmeting: budget per WM1-kamer, geïsoleerd (verse load, staat tussen kamers gewist).
## Hergebruikt de kamerlijst en de probe van scripts/perf/wm1_frametime.gd en de drempels van
## scripts/data/wm1_perf_budget.gd. Overschrijding is een waarschuwing, geen FAIL.
## Start: godot --path . -- --wm1roombaselinetest [--only=id,id]
## Of:    GODOT=... .github/scripts/run_suite.sh wm1roombaselinetest
## Schrijft (alleen bij een volledige run): docs/perf/wm1_room_baseline.json en
## docs/perf/WM1_ROOM_BASELINE.md. Niet in de CI-matrix.

const Wm1FrametimeScript := preload("res://scripts/perf/wm1_frametime.gd")
const Budget := preload("res://scripts/data/wm1_perf_budget.gd")

const JSON_PATH := "res://docs/perf/wm1_room_baseline.json"
const MD_PATH := "res://docs/perf/WM1_ROOM_BASELINE.md"
## Kort vast venster ná de probe, voor wandklok-frametijd (gemiddelde en p95).
const FRAME_WINDOW := 60
## Kamer die twee keer gemeten wordt (node-count moet identiek zijn). Valt hij buiten --only, dan de eerste.
const REPEAT_ID := "dorp_wilgendal"
const AUTOLOADS := [
	"GameState", "Transition", "Dialog", "Story", "Crt", "Settings",
	"AudioManager", "SessieLog", "AppLifecycle",
]

var failures := 0
var passes := 0
var sampler := Wm1FrametimeScript.new()
var only: PackedStringArray = []
var rows: Array[Dictionary] = []
var repeat_row: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",", false)
	get_tree().create_timer(2400.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: room-baseline klaar binnen 2400 s", false)
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


func _wm1_path(path: String) -> bool:
	return not path.contains("/wm2/") and not path.contains("/wacht/")


func _run() -> void:
	_prepare_host()
	var rooms: Array[Dictionary] = []
	for room in Wm1FrametimeScript.rooms():
		if _wm1_path(str(room["path"])):
			rooms.append(room)
	check("kamerlijst niet leeg", not rooms.is_empty())
	print("WM1ROOMBASELINE rooms=%d warmup=%d probe_frames=%d frame_window=%d only=%s" % [
			rooms.size(), Budget.WARMUP_FRAMES, Budget.SAMPLE_FRAMES, FRAME_WINDOW,
			"alle" if only.is_empty() else ",".join(only)])
	var measured := 0
	for room in rooms:
		var rid: String = room["id"]
		if not _wanted(rid):
			continue
		var row := await _measure(room)
		rows.append(row)
		measured += 1
		_print_row(row)
		check("%s: scène geladen" % rid, bool(row["ok"]))
		if row["ok"]:
			var miss := _missing_metrics(row)
			check("%s: metrieken gevuld%s" % [rid, "" if miss.is_empty() else " (ontbreekt " + miss + ")"],
					miss.is_empty())
			_warn_budget(row)
	var repeat_id := REPEAT_ID if _has_row(REPEAT_ID) else (str(rows[0]["id"]) if not rows.is_empty() else "")
	if repeat_id != "":
		var room := _room_by_id(rooms, repeat_id)
		var again := await _measure(room)
		repeat_row = again
		_print_row(again, true)
		var eerste := _row_by_id(repeat_id)
		var zelfde := bool(again["ok"]) and not eerste.is_empty() and int(again["scene_nodes"]) == int(eerste["scene_nodes"])
		check("herhaling %s: scene_nodes %d == %d" % [repeat_id, int(again.get("scene_nodes", -1)), int(eerste.get("scene_nodes", -2))],
				zelfde)
	else:
		check("herhaling: kamer om te herhalen", false)
	var vol := only.is_empty() and failures == 0 and measured == rooms.size()
	if vol:
		var geschreven := _write(rooms.size())
		check("json geschreven", geschreven and FileAccess.file_exists(JSON_PATH))
		check("markdown geschreven", FileAccess.file_exists(MD_PATH))
		check("json leest terug met alle kamers", _json_roundtrip(rooms.size()))
	elif only.is_empty():
		check("baseline niet geschreven: meting incompleet", false)
	print("WM1ROOMBASELINE %d PASS, %d FAIL, %d kamers" % [passes, failures, rows.size()])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _prepare_host() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	var life := get_tree().root.get_node_or_null("AppLifecycle")
	if life != null and life.has_method("set_low_processor_enabled"):
		life.set_low_processor_enabled(false)


## Vorige scène weg, spelstaat terug naar een vers spel, stijl- en resourcecache leeg.
## Zonder dit blijft scene_nodes van een kamer afhangen van wat er eerder in het proces zat
## (bekend: dorp_wilgendal 838 in een volle run, 1679 bij een losse load).
func _isolate(tree: SceneTree) -> void:
	await sampler.clear_scene(tree)
	var extra := false
	for c in tree.root.get_children():
		if c == self or str(c.name) in AUTOLOADS:
			continue
		if tree.current_scene == c:
			tree.current_scene = null
		c.queue_free()
		extra = true
	if extra:
		for _i in 4:
			await tree.process_frame
	var dialog := tree.root.get_node_or_null("Dialog")
	if dialog != null and dialog.get("is_open") == true and dialog.has_method("close"):
		dialog.close()
	GameState.new_game()
	GameState.encounter_multiplier = 0.0
	GameState.changing_map = false
	GameState.in_battle = false
	GameState.pending_spawn = ""
	GameState.has_return_point = false
	GameState._autosave_request = ""
	# Eenmalige binnenkomst-dialogen niet tijdens het meetvenster (alleen tekst, geen extra props).
	GameState.story_flags["archief2_keten"] = true
	GameState.story_flags["archief2_echo"] = true
	KaartStijl.zet_config({})
	GameState._finish_preload()
	for actie in ["move_left", "move_right", "move_up", "move_down"]:
		if InputMap.has_action(actie):
			Input.action_release(actie)
	_prepare_host()


func _verse_resource(path: String) -> void:
	if GameState._loaded.has(path):
		GameState._loaded.erase(path)
	# enter_room / get_resource doen daarna load(); REPLACE zodat geen oude PackedScene blijft hangen.
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


func _measure(room: Dictionary) -> Dictionary:
	var tree := get_tree()
	var rid: String = room["id"]
	var path: String = room["path"]
	await _isolate(tree)
	_verse_resource(path)
	var t0 := Time.get_ticks_usec()
	var ok := await sampler.enter_room(tree, room)
	var load_us := Time.get_ticks_usec() - t0
	var row := {
		"id": rid,
		"path": path,
		"group": str(room.get("group", "")),
		"kind": str(room.get("kind", "")),
		"ok": false,
		"load_ms": _round(float(load_us) / 1000.0, 3),
		"scene_nodes": 0,
		"nodes": 0,
		"objects": 0,
		"orphans": 0,
		"draw_avg": 0.0,
		"draw_max": 0,
		"proc_ms": 0.0,
		"static_mb": 0.0,
		"frame_avg_ms": 0.0,
		"frame_p95_ms": 0.0,
		"frames": 0,
		"frame_samples": 0,
		"has_budget": Budget.has_room(rid),
		"over_budget": [] as Array[String],
	}
	if not ok:
		return row
	var cs := tree.current_scene
	if cs == null or str(cs.scene_file_path) != path:
		return row
	# Zelfde probe als --wm1budgettest (warmup + meetframes, draw, nodes, proc_ms).
	var m := await sampler.sample_idle(tree, Budget.WARMUP_FRAMES, Budget.SAMPLE_FRAMES)
	var ft := await _frame_window(tree)
	row["ok"] = true
	row["scene_nodes"] = int(m["scene_nodes"])
	row["nodes"] = int(m["nodes"])
	row["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	row["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	row["draw_avg"] = _round(float(m["draw_avg"]), 3)
	row["draw_max"] = int(m["draw_max"])
	row["proc_ms"] = _round(float(m["proc_ms"]), 3)
	row["static_mb"] = _round(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 3)
	row["frame_avg_ms"] = _round(float(ft["avg"]), 3)
	row["frame_p95_ms"] = _round(float(ft["p95"]), 3)
	row["frames"] = int(m["frames"])
	row["frame_samples"] = int(ft["n"])
	row["over_budget"] = _over_budget(row)
	return row


func _frame_window(tree: SceneTree) -> Dictionary:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var dt: Array[float] = []
	var last := Time.get_ticks_usec()
	for _i in FRAME_WINDOW:
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		dt.append(float(now - last) / 1000.0)
		last = now
	return {"avg": _avg(dt), "p95": _percentile(dt, 0.95), "n": dt.size()}


func _over_budget(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not Budget.has_room(str(row["id"])):
		return out
	var lim: Dictionary = Budget.limit(str(row["id"]))
	if float(row["proc_ms"]) > float(lim["max_proc_ms"]):
		out.append("proc_ms")
	if float(row["draw_avg"]) > float(lim["max_draw_avg"]):
		out.append("draw_avg")
	if int(row["draw_max"]) > int(lim["max_draw_max"]):
		out.append("draw_max")
	if int(row["scene_nodes"]) > int(lim["max_scene_nodes"]):
		out.append("scene_nodes")
	if int(row["nodes"]) > int(lim["max_nodes"]):
		out.append("nodes")
	return out


func _warn_budget(row: Dictionary) -> void:
	var over: Array[String] = row["over_budget"]
	if over.is_empty():
		return
	var lim: Dictionary = Budget.limit(str(row["id"]))
	for key in over:
		var gemeten: String = str(row[key])
		var grens: String = str(lim["max_" + key] if lim.has("max_" + key) else lim.get("max_nodes", ""))
		if key == "scene_nodes":
			grens = str(lim["max_scene_nodes"])
			gemeten = str(row["scene_nodes"])
		elif key == "nodes":
			grens = str(lim["max_nodes"])
			gemeten = str(row["nodes"])
		elif key == "proc_ms":
			grens = "%.3f" % float(lim["max_proc_ms"])
			gemeten = "%.3f" % float(row["proc_ms"])
		elif key == "draw_avg":
			grens = "%.1f" % float(lim["max_draw_avg"])
			gemeten = "%.1f" % float(row["draw_avg"])
		elif key == "draw_max":
			grens = str(lim["max_draw_max"])
			gemeten = str(row["draw_max"])
		print("WARN  %s: %s %s > %s (budget, geen fout)" % [row["id"], key, gemeten, grens])


func _missing_metrics(row: Dictionary) -> String:
	var miss: PackedStringArray = []
	if int(row["scene_nodes"]) <= 0:
		miss.append("scene_nodes")
	if int(row["nodes"]) <= 0:
		miss.append("nodes")
	if int(row["objects"]) <= 0:
		miss.append("objects")
	if int(row["draw_max"]) < 0 or float(row["draw_avg"]) < 0.0:
		miss.append("draw")
	if float(row["static_mb"]) <= 0.0:
		miss.append("static_mb")
	if float(row["load_ms"]) < 0.0:
		miss.append("load_ms")
	if float(row["frame_avg_ms"]) <= 0.0 or float(row["frame_p95_ms"]) <= 0.0:
		miss.append("frame_ms")
	if int(row["frame_samples"]) != FRAME_WINDOW:
		miss.append("frame_samples")
	if int(row["frames"]) != Budget.SAMPLE_FRAMES:
		miss.append("frames")
	if float(row["proc_ms"]) < 0.0:
		miss.append("proc_ms")
	# Draw-calls horen headless (opengl3) beschikbaar te zijn; 0 op een WM1-kaart is leeg.
	if int(row["draw_max"]) == 0:
		miss.append("draw_max")
	return ", ".join(miss)


func _print_row(row: Dictionary, herhaling := false) -> void:
	print("WM1ROOM%s id=%s load_ms=%.3f scene_nodes=%d nodes=%d objects=%d draw=%.1f draw_max=%d proc_ms=%.3f static_mb=%.3f frame_avg=%.3f frame_p95=%.3f ok=%s" % [
			" REPEAT" if herhaling else "", row["id"], float(row["load_ms"]), int(row["scene_nodes"]),
			int(row["nodes"]), int(row["objects"]), float(row["draw_avg"]), int(row["draw_max"]),
			float(row["proc_ms"]), float(row["static_mb"]), float(row["frame_avg_ms"]),
			float(row["frame_p95_ms"]), str(row["ok"])])


func _write(room_count: int) -> bool:
	var payload := _payload(room_count)
	var json_text := JSON.stringify(payload, "\t", true)
	if not _store(JSON_PATH, json_text):
		return false
	if not _store(MD_PATH, _markdown()):
		return false
	print("WM1ROOMBASELINE json=%s md=%s" % [ProjectSettings.globalize_path(JSON_PATH), ProjectSettings.globalize_path(MD_PATH)])
	return true


func _payload(room_count: int) -> Dictionary:
	var ver := Engine.get_version_info()
	var kamer_rijen: Array = []
	for row in rows:
		kamer_rijen.append(_json_row(row))
	return {
		"suite": "--wm1roombaselinetest",
		"source": "scripts/tests/wm1_room_baseline_tests.gd",
		"probe": "scripts/perf/wm1_frametime.gd",
		"budget": "scripts/data/wm1_perf_budget.gd",
		"godot": str(ver.get("string", "")),
		"renderer": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"warmup_frames": Budget.WARMUP_FRAMES,
		"probe_frames": Budget.SAMPLE_FRAMES,
		"frame_window": FRAME_WINDOW,
		"isolation": "clear_scene + losse root-nodes weg + new_game + KaartStijl.zet_config({}) + PackedScene CACHE_MODE_REPLACE, per kamer",
		"room_count": room_count,
		"repeat": _json_row(repeat_row) if not repeat_row.is_empty() else {},
		"warnings": _warning_rows(),
		"rooms": kamer_rijen,
	}


func _json_row(row: Dictionary) -> Dictionary:
	var over: Array[String] = row.get("over_budget", [])
	return {
		"id": str(row.get("id", "")),
		"path": str(row.get("path", "")),
		"group": str(row.get("group", "")),
		"kind": str(row.get("kind", "")),
		"ok": bool(row.get("ok", false)),
		"load_ms": float(row.get("load_ms", 0.0)),
		"scene_nodes": int(row.get("scene_nodes", 0)),
		"nodes": int(row.get("nodes", 0)),
		"objects": int(row.get("objects", 0)),
		"orphans": int(row.get("orphans", 0)),
		"draw_avg": float(row.get("draw_avg", 0.0)),
		"draw_max": int(row.get("draw_max", 0)),
		"proc_ms": float(row.get("proc_ms", 0.0)),
		"static_mb": float(row.get("static_mb", 0.0)),
		"frame_avg_ms": float(row.get("frame_avg_ms", 0.0)),
		"frame_p95_ms": float(row.get("frame_p95_ms", 0.0)),
		"frames": int(row.get("frames", 0)),
		"frame_samples": int(row.get("frame_samples", 0)),
		"has_budget": bool(row.get("has_budget", false)),
		"over_budget": over,
	}


func _warning_rows() -> Array:
	var uit: Array = []
	for row in rows:
		var over: Array[String] = row["over_budget"]
		if over.is_empty():
			continue
		var lim: Dictionary = Budget.limit(str(row["id"]))
		for key in over:
			uit.append({
				"id": str(row["id"]),
				"metric": str(key),
				"value": row[str(key)],
				"limit": _limit_value(lim, str(key)),
			})
	return uit


func _limit_value(lim: Dictionary, key: String) -> Variant:
	match key:
		"proc_ms":
			return float(lim["max_proc_ms"])
		"draw_avg":
			return float(lim["max_draw_avg"])
		"draw_max":
			return int(lim["max_draw_max"])
		"scene_nodes":
			return int(lim["max_scene_nodes"])
		"nodes":
			return int(lim["max_nodes"])
	return null


func _markdown() -> String:
	var s := "# WM1 nulmeting per kamer\n\n"
	s += "Automatisch gegenereerd door `--wm1roombaselinetest` (`scripts/tests/wm1_room_baseline_tests.gd`). "
	s += "Elke kamer is apart geladen: vorige scène vrijgegeven, `GameState.new_game()`, stijlcache leeg "
	s += "(`KaartStijl.zet_config({})`) en de PackedScene opnieuw van schijf. "
	s += "Niet de CI-matrix. Een overschrijding van `scripts/data/wm1_perf_budget.gd` is een waarschuwing, geen fout.\n\n"
	s += "## Omgeving\n\n"
	s += "- Godot **%s**, renderer `%s`, display `%s`.\n" % [
			str(Engine.get_version_info().get("string", "")), RenderingServer.get_video_adapter_name(), DisplayServer.get_name()]
	s += "- Probe: warmup **%d** + **%d** meetframes (`Wm1Frametime.sample_idle`, zelfde als `--wm1budgettest`).\n" % [
			Budget.WARMUP_FRAMES, Budget.SAMPLE_FRAMES]
	s += "- Frametijd: wandklok over **%d** frames ná de probe (`max_fps=0`, vsync uit). Op llvmpipe niet gelijk aan een telefoon.\n" % FRAME_WINDOW
	s += "- `scene_nodes` telt de huidige scène. `nodes` is `OBJECT_NODE_COUNT`. `objects` is `OBJECT_COUNT`. `static_mb` is `MEMORY_STATIC`.\n"
	s += "- `load_ms` is de scènewissel. Hub-kamers gaan via `change_map` en tellen de fade (~0,3 s) mee.\n\n"
	s += _top_section("scene_nodes", "scene nodes")
	s += _top_section("frame_p95_ms", "frame p95 ms")
	s += "## Kamers\n\n"
	s += "| id | groep | load ms | scene nodes | nodes | objects | draw avg | draw max | proc ms | static MB | frame avg | frame p95 | budget |\n"
	s += "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n"
	for row in rows:
		var budget := "—"
		if row["has_budget"]:
			var over: Array[String] = row["over_budget"]
			budget = "ok" if over.is_empty() else "WARN " + ", ".join(over)
		s += "| `%s` | %s | %.1f | %d | %d | %d | %.1f | %d | %.3f | %.2f | %.2f | %.2f | %s |\n" % [
				row["id"], row["group"], float(row["load_ms"]), int(row["scene_nodes"]), int(row["nodes"]),
				int(row["objects"]), float(row["draw_avg"]), int(row["draw_max"]), float(row["proc_ms"]),
				float(row["static_mb"]), float(row["frame_avg_ms"]), float(row["frame_p95_ms"]), budget]
	s += "\n## Boven het bestaande budget (waarschuwing)\n\n"
	var warns := _warning_rows()
	if warns.is_empty():
		s += "Geen kamer boven `wm1_perf_budget.gd`.\n"
	else:
		s += "Drempels zijn de sequentiële meting in `scripts/data/wm1_perf_budget.gd`. "
		s += "Deze nulmeting laadt elke kamer geïsoleerd; daardoor kan een kamer hoger uitkomen dan die drempel. "
		s += "De test faalt daar niet op.\n\n"
		s += "| id | metriek | gemeten | drempel |\n|---|---|---:|---:|\n"
		for w in warns:
			s += "| `%s` | %s | %s | %s |\n" % [w["id"], w["metric"], w["value"], w["limit"]]
	if not repeat_row.is_empty():
		var eerste := _row_by_id(str(repeat_row["id"]))
		s += "\n## Herhaling\n\n"
		s += "`%s` nog een keer na de andere kamers: scene_nodes **%d** en **%d**.\n" % [
				repeat_row["id"], int(eerste.get("scene_nodes", -1)), int(repeat_row["scene_nodes"])]
	s += "\n## Kamers zonder drempel\n\n"
	var zonder: PackedStringArray = []
	for row in rows:
		if not row["has_budget"]:
			zonder.append(str(row["id"]))
	s += ("Geen.\n" if zonder.is_empty() else "`" + "`, `".join(zonder) + "`\n")
	return s


func _top_section(key: String, label: String) -> String:
	var copy: Array[Dictionary] = []
	for row in rows:
		if row["ok"]:
			copy.append(row)
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a[key]) > float(b[key]))
	var s := "## Zwaarste 5 op %s\n\n" % label
	if key == "scene_nodes":
		s += "| id | scene nodes | frame p95 ms |\n|---|---:|---:|\n"
	else:
		s += "| id | frame p95 ms | scene nodes |\n|---|---:|---:|\n"
	for i in mini(5, copy.size()):
		var row: Dictionary = copy[i]
		if key == "scene_nodes":
			s += "| `%s` | %d | %.2f |\n" % [row["id"], int(row["scene_nodes"]), float(row["frame_p95_ms"])]
		else:
			s += "| `%s` | %.2f | %d |\n" % [row["id"], float(row[key]), int(row["scene_nodes"])]
	return s + "\n"


func _json_roundtrip(room_count: int) -> bool:
	var text := FileAccess.get_file_as_string(JSON_PATH)
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		return false
	var rooms = data.get("rooms", [])
	return rooms is Array and rooms.size() == room_count and int(data.get("room_count", -1)) == room_count


func _store(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("WM1ROOMBASELINE kon %s niet schrijven" % path)
		return false
	f.store_string(text)
	f.close()
	return true


func _has_row(id: String) -> bool:
	return not _row_by_id(id).is_empty()


func _row_by_id(id: String) -> Dictionary:
	for row in rows:
		if str(row["id"]) == id:
			return row
	return {}


func _room_by_id(rooms: Array[Dictionary], id: String) -> Dictionary:
	for room in rooms:
		if str(room["id"]) == id:
			return room
	return {}


static func _round(v: float, digits: int) -> float:
	var p := pow(10.0, digits)
	return round(v * p) / p


static func _avg(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var som := 0.0
	for v in samples:
		som += v
	return som / float(samples.size())


static func _percentile(samples: Array[float], p: float) -> float:
	if samples.is_empty():
		return 0.0
	var b := samples.duplicate()
	b.sort()
	var idx := clampi(int(ceil(p * float(b.size()))) - 1, 0, b.size() - 1)
	return float(b[idx])
