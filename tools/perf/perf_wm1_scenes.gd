extends Node
## Perf-meting zwaarste WM1-scènes: frametijd/FPS (gemiddelde, p95, max over N frames) en geheugen
## (static memory, object count, node count) per scène, als tabel op stdout. Geen test, geen gameplay.
## Start (headless, Windows of Linux):
##   godot --headless --path . res://tools/perf/perf_wm1_scenes.tscn -- --perfscenes \
##       [--warmup=60] [--frames=600] [--only=dorp_wilgendal,battle] [--out=pad.md]
## Eigen steiger-scène (zoals tools/perf/perf_wm1.tscn): geen dispatch in game_state.gd nodig.
## Uitleg methode, keuze scènes en beperkingen: docs/perf/PERF_WM1.md.

const Wm1FrametimeScript := preload("res://scripts/perf/wm1_frametime.gd")
const WORLD := "res://scenes/maps/wereldkaart.tscn"

## Zwaarste WM1-scènes (keuze: zie PERF_WM1.md; afgeleid uit de wm1frametest-baseline in docs/perf_wm1.md).
## [id, reden]; id = id uit Wm1Frametime.rooms(), of "battle" (gevecht vanaf de wereldkaart).
const SCENES: Array = [
	["dorp_wilgendal", "meeste nodes (~1680) en draw calls (~206) van WM1"],
	["archief_puzzel", "meeste nodes buiten het dorp (puzzel-elementen)"],
	["warper_hal", "hub-veldkaart, meeste draw calls na het dorp"],
	["battle", "gevecht met 3 vijanden (sprites, HUD, menu, shaders) vanaf de wereldkaart"],
]
const BATTLE_ENEMIES := ["mosslijm", "moskonijn", "mosslijm"]

var warmup := 60
var frames := 600
var only: PackedStringArray = []
var out_path := ""
var sampler := Wm1FrametimeScript.new()
var _rows: Array[Dictionary] = []
var _frame_us: Array[int] = []
## Minimale meetduur per scène (wandklok): zonder vsync/slaap is een frame headless ~0,1 ms, dus
## N frames alleen zou maar enkele ms speeltijd (timers, tweens, physics-ticks) dekken.
var seconds := 5.0
var _last_us := 0


func _ready() -> void:
	# De hoofdscène is alleen een steiger: het harnas hangt aan de root en overleeft scènewissels.
	if get_tree().current_scene == self:
		var h: Node = get_script().new()
		h.name = "PerfWm1ScenesRun"
		get_tree().root.add_child.call_deferred(h)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--warmup="):
			warmup = maxi(5, int(a.get_slice("=", 1)))
		elif a.begins_with("--frames="):
			frames = maxi(30, int(a.get_slice("=", 1)))
		elif a.begins_with("--seconds="):
			seconds = maxf(0.0, float(a.get_slice("=", 1)))
		elif a.begins_with("--only="):
			only = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("--out="):
			out_path = a.get_slice("=", 1)
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func():
		print("RESULT FOUT (waakhond: niet klaar binnen 900 s)")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	for _i in 3:
		await get_tree().process_frame
	# eigen save-paden: een perf-run raakt de echte save/autosave niet
	GameState.save_path = "user://perfscenes_save_1.json"
	GameState.autosave_path = "user://perfscenes_autosave.json"
	GameState._story_save_path = GameState.save_path
	GameState._story_autosave_path = GameState.autosave_path
	GameState._finish_preload()   # achtergrond-laden eerst afmaken: geen ruis in de meting
	GameState.new_game()
	GameState.encounter_multiplier = 0.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# AppLifecycle zet low_processor_usage_mode aan bij menu's (o.a. HUD/gevechtsmenu); dat slaapt
	# ~6,9 ms per frame en maakt elke scène "144 FPS". Voor de meting uit.
	AppLifecycle.set_low_processor_enabled(false)
	OS.low_processor_usage_mode = false
	# Headless kan geen venster tekenen; de main loop slaapt dan elke iteratie deze tijd (default
	# 6900 µs), los van low_processor_usage_mode. Op 0: frametijd = echte CPU-tijd per iteratie.
	OS.low_processor_usage_mode_sleep_usec = 0
	await sampler.clear_scene(get_tree())
	var base := _memory()
	print("PERFSCENES godot=%s headless=%s renderer=%s warmup=%d frames>=%d seconds>=%.1f static_base=%.1f MB" % [
			Engine.get_version_info().get("string", ""), DisplayServer.get_name() == "headless",
			RenderingServer.get_video_adapter_name(), warmup, frames, seconds, base["static_mb"]])
	var rooms := {}
	for r in Wm1FrametimeScript.rooms():
		rooms[str(r["id"])] = r
	var fouten := 0
	for s in SCENES:
		var id: String = s[0]
		if not only.is_empty() and not (id in only):
			continue
		var ok := false
		if id == "battle":
			ok = await _enter_battle()
		elif rooms.has(id):
			ok = await sampler.enter_room(get_tree(), rooms[id])
		if not ok:
			print("PERFSCENE id=%s FOUT: scène niet geladen" % id)
			fouten += 1
			continue
		var m := await _measure()
		m["id"] = id
		m["reason"] = s[1]
		m["static_delta_mb"] = m["static_mb"] - base["static_mb"]
		_rows.append(m)
		print("PERFSCENE id=%s avg_ms=%.3f p95_ms=%.3f max_ms=%.3f n=%d static_mb=%.1f objects=%d nodes=%d scene_nodes=%d resources=%d orphans=%d"
				% [id, m["avg_ms"], m["p95_ms"], m["max_ms"], m["n"], m["static_mb"],
				m["objects"], m["nodes"], m["scene_nodes"], m["resources"], m["orphans"]])
		if id == "battle":
			GameState.in_battle = false
	await sampler.clear_scene(get_tree())
	var table := _table()
	print("")
	print(table)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(table + "\n")
	print("RESULT %s (%d scènes, %d fouten)" % ["OK" if fouten == 0 else "FOUT", _rows.size(), fouten])
	get_tree().quit(1 if fouten else 0)


## Wereldkaart laden en daar een gevecht starten (zelfde pad als een encounter).
func _enter_battle() -> bool:
	var world := {"id": "wereldkaart", "path": WORLD, "kind": "map"}
	if not await sampler.enter_room(get_tree(), world):
		return false
	var m := get_tree().current_scene
	if m == null or not m.has_method("start_battle"):
		return false
	m.start_battle(BATTLE_ENEMIES)
	# wandklok i.p.v. frames: headless zonder slaap lopen frames ~0,1 ms, de overgang duurt seconden
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs.scene_file_path == GameState.BATTLE_SCENE and cs.is_node_ready():
			return true
	return false


func _memory() -> Dictionary:
	return {
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _on_process_frame() -> void:
	var t := Time.get_ticks_usec()
	if _last_us > 0:
		_frame_us.append(t - _last_us)
	_last_us = t


## Warmup (frames + 1 s), daarna minstens N frames en minstens `seconds` wandklok: frametijd = tijd
## tussen twee opeenvolgende process_frame-signalen (hele engine-iteratie, incl. physics-ticks).
## Headless zonder slaap is dat de CPU-tijd per iteratie (geen render). frame_pre_draw (zoals
## Wm1Frametime de script-tijd meet) komt headless nooit, dus die kolom is er hier niet.
func _measure() -> Dictionary:
	var warm_end := Time.get_ticks_msec() + 1000
	var w := 0
	while w < warmup or Time.get_ticks_msec() < warm_end:
		await get_tree().process_frame
		w += 1
	_frame_us.clear()
	_last_us = 0
	# geheugen vóór het verzamelen: de sample-array (tienduizenden frames) telt anders mee
	var m := _memory()
	get_tree().process_frame.connect(_on_process_frame)
	var end_ms := Time.get_ticks_msec() + int(seconds * 1000.0)
	while _frame_us.size() < frames or Time.get_ticks_msec() < end_ms:
		await get_tree().process_frame
	get_tree().process_frame.disconnect(_on_process_frame)
	var ft: Array[float] = []
	for us in _frame_us:
		ft.append(float(us) / 1000.0)
	var avg := _avg(ft)
	var cs := get_tree().current_scene
	m["scene_nodes"] = sampler.count_nodes(cs) if cs != null else 0
	m["avg_ms"] = avg
	m["p95_ms"] = _percentile(ft, 0.95)
	m["max_ms"] = ft.max() if not ft.is_empty() else 0.0
	m["fps"] = 1000.0 / avg if avg > 0.0 else 0.0
	m["n"] = ft.size()
	return m


static func _avg(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / float(a.size())


## Nearest-rank percentiel (p in 0..1).
static func _percentile(a: Array[float], p: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	var idx := clampi(int(ceil(p * float(b.size()))) - 1, 0, b.size() - 1)
	return b[idx]


func _table() -> String:
	var lines: PackedStringArray = [
		"| scène | frame avg ms | p95 ms | max ms | frames (N) | static MB | Δ static MB | objects | nodes | scene nodes | resources |",
		"|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
	]
	for m in _rows:
		lines.append("| `%s` | %.3f | %.3f | %.3f | %d | %.1f | %+.1f | %d | %d | %d | %d |" % [
				m["id"], m["avg_ms"], m["p95_ms"], m["max_ms"], m["n"],
				m["static_mb"], m["static_delta_mb"], m["objects"], m["nodes"], m["scene_nodes"], m["resources"]])
	return "\n".join(lines)
