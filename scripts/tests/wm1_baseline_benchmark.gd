extends Node
## WM1 F4 perf-baseline (headless, geen CI): alle WM1-kamers (warp via wm1_frametime.gd) plus enkele gevechten.
## Meet wandklok-frametijd (gem/p95), draw calls, nodes en static memory; schrijft docs/perf/wm1_baseline.md
## en markeert S25-risico t.o.v. 60 fps (16,667 ms/frame).
## Start:  xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --wm1baselinebenchtest
## Opties:  [--only=id,id]  [--warmup=N]  [--frames=N]  [--walk=N]  [--md=res://docs/perf/wm1_baseline.md]
## Niet in .github/workflows/tests.yml (bewust meting, geen regressiegate).

const Wm1FrametimeScript := preload("res://scripts/perf/wm1_frametime.gd")

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const BATTLES := [
	["battle_gras", ["mosslijm", "mosslijm"], "gras", false, 0, false],
	["battle_woud", ["wortelgeest", "rankje", "sporekop"], "woud", false, 2, true],
	["battle_archief", ["papiergeest", "glitchmot", "papiergeest"], "archief", false, 2, true],
	["battle_baas_golem", ["kennis_beest"], "archief", true, 0, false],
	["battle_kas", ["papiergeest", "glitchmot"], "kas", false, 3, true],
]

const S25_BUDGET_MS := 16.667
## Conservatieve schatting S25-GPU + CPU t.o.v. xvfb/llvmpipe (zie docs/perf/s25_check.md).
const EST_DRAW_MS := 0.06
const EST_NODE_MS := 0.002

const DEFAULT_WARMUP := 25
const DEFAULT_FRAMES := 120
const DEFAULT_WALK := 90
const DEFAULT_MD := "res://docs/perf/wm1_baseline.md"

var failures := 0
var passes := 0
var sampler := Wm1FrametimeScript.new()
var only: PackedStringArray = []
var warmup := DEFAULT_WARMUP
var frames := DEFAULT_FRAMES
var walk_frames := DEFAULT_WALK
var md_path := DEFAULT_MD
var rows: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--warmup="):
			warmup = maxi(int(arg.get_slice("=", 1)), 5)
		elif arg.begins_with("--frames="):
			frames = maxi(int(arg.get_slice("=", 1)), 20)
		elif arg.begins_with("--walk="):
			walk_frames = maxi(int(arg.get_slice("=", 1)), 0)
		elif arg.begins_with("--md="):
			md_path = arg.get_slice("=", 1)
	get_tree().create_timer(5400.0, true, false, true).timeout.connect(func():
		check("waakhond: baseline klaar binnen 5400 s", false)
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
	var cap := Engine.max_fps
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("WM1BASELINE rooms=%d battles=%d warmup=%d idle=%d walk=%d budget=%.3fms"
			% [Wm1FrametimeScript.rooms().size(), BATTLES.size(), warmup, frames, walk_frames, S25_BUDGET_MS])
	for room in Wm1FrametimeScript.rooms():
		var rid: String = room["id"]
		if not _wanted(rid):
			continue
		var ok := await sampler.enter_room(get_tree(), room)
		check("%s: scène geladen" % rid, ok)
		if not ok:
			continue
		var m := await _sample_room(room, walk_frames > 0)
		rows.append(m)
		print("WM1BASELINE %s" % JSON.stringify(m))
	for b in BATTLES:
		if not _wanted(b[0]):
			continue
		var bm := await _sample_battle(b)
		rows.append(bm)
		check("%s: gevecht gemeten" % b[0], bool(bm.get("ok", false)))
		print("WM1BASELINE %s" % JSON.stringify(bm))
	Engine.max_fps = cap
	_write_markdown()
	check("baseline markdown geschreven", FileAccess.file_exists(md_path))
	print("WM1BASELINEBENCH %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _estimate_s25_ms(m: Dictionary) -> float:
	return float(m["frame_p95_ms"]) + float(m["draw_avg"]) * EST_DRAW_MS + float(m["scene_nodes"]) * EST_NODE_MS


func _s25_risk(m: Dictionary) -> String:
	var est := _estimate_s25_ms(m)
	if est >= S25_BUDGET_MS:
		return "RISK"
	if est >= S25_BUDGET_MS * 0.85 or float(m["draw_avg"]) >= 120.0 or int(m["scene_nodes"]) >= 900:
		return "WATCH"
	return "OK"


func _player() -> CharacterBody2D:
	var cs := get_tree().current_scene
	if cs == null or not cs.has_method("terrain_at"):
		return null
	return cs.get_node_or_null("Objects/Player") as CharacterBody2D


func _sample_room(room: Dictionary, do_walk: bool) -> Dictionary:
	var rid: String = room["id"]
	var r := {
		"id": rid,
		"path": room["path"],
		"group": room.get("group", ""),
		"kind": "map",
		"ok": true,
	}
	for i in warmup:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var cs := get_tree().current_scene
	r["scene_nodes"] = sampler.count_nodes(cs) if cs != null else 0
	var idle := await _measure_frames(frames, "")
	r.merge(idle)
	var walk := {"frame_avg_ms": 0.0, "frame_p95_ms": 0.0, "draw_avg": 0.0, "draw_max": 0}
	if do_walk and _player() != null and walk_frames > 0:
		walk = await _measure_frames(walk_frames, "move_right")
		for k in ["frame_avg_ms", "frame_p95_ms", "draw_avg", "draw_max"]:
			r[k] = maxf(float(r.get(k, 0.0)), float(walk.get(k, 0.0)))
	r["mode"] = "idle+walk" if do_walk and _player() != null else "idle"
	r["static_mem_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	r["nodes_engine"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	r["s25_est_ms"] = _estimate_s25_ms(r)
	r["s25_flag"] = _s25_risk(r)
	return r


func _measure_frames(n: int, move_action: String) -> Dictionary:
	if move_action != "":
		Input.action_press(move_action)
	var dt: Array[float] = []
	var draw_sum := 0.0
	var draw_max := 0
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		dt.append((now - last) / 1000.0)
		last = now
		var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_sum += dc
		draw_max = maxi(draw_max, dc)
	if move_action != "":
		Input.action_release(move_action)
	var sorted := dt.duplicate()
	sorted.sort()
	var avg := 0.0
	for v in dt:
		avg += v
	avg /= maxf(1.0, float(dt.size()))
	var p95: float = sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)] if not sorted.is_empty() else 0.0
	return {
		"frame_avg_ms": avg,
		"frame_p95_ms": p95,
		"draw_avg": draw_sum / maxf(1.0, float(n)),
		"draw_max": draw_max,
	}


func _sample_battle(b: Array) -> Dictionary:
	await sampler.clear_scene(get_tree())
	var r := {"id": b[0], "path": BATTLE_SCENE, "group": "battle", "kind": "battle", "ok": false, "mode": "battle"}
	GameState.prepare_battle(b[1], b[2], b[3], b[4], b[5], false)
	GameState.in_battle = true
	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		return r
	get_tree().change_scene_to_packed(packed)
	for _i in 400:
		await get_tree().process_frame
		if get_tree().current_scene != null and str(get_tree().current_scene.scene_file_path) == BATTLE_SCENE:
			break
	await RenderingServer.frame_post_draw
	for i in warmup:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var cs := get_tree().current_scene
	r["scene_nodes"] = sampler.count_nodes(cs) if cs != null else 0
	var m := await _measure_frames(frames, "")
	r.merge(m)
	r["static_mem_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	r["nodes_engine"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	r["s25_est_ms"] = _estimate_s25_ms(r)
	r["s25_flag"] = _s25_risk(r)
	var bd: TextureRect = get_tree().current_scene.get_node_or_null("Backdrop") as TextureRect if cs != null else null
	r["ok"] = bd != null and bd.texture != null
	return r


func _write_markdown() -> void:
	var risky: Array[String] = []
	var watch: Array[String] = []
	for row in rows:
		match str(row.get("s25_flag", "")):
			"RISK":
				risky.append(str(row["id"]))
			"WATCH":
				watch.append(str(row["id"]))
	var s := "# WM1 performance-baseline (headless)\n\n"
	s += "Automatisch gegenereerd door `--wm1baselinebenchtest` (`scripts/tests/wm1_baseline_benchmark.gd`). "
	s += "Niet de CI-matrix; opnieuw draaien na grote WM1-wijzigingen.\n\n"
	s += "## Omgeving\n\n"
	s += "- Godot **4.3-stable**, `gl_compatibility`, viewport **384×216**, `xvfb-run` + `--rendering-driver opengl3`.\n"
	s += "- Warmup **%d** frames, idle **%d** frames, lopen **%d** frames (rechts) waar een speler bestaat.\n" % [warmup, frames, walk_frames]
	s += "- **Frametijd** = wandklok tussen opeenvolgende frames (`max_fps=0`, vsync uit). Op llvmpipe **niet** gelijk aan een Galaxy S25.\n"
	s += "- **S25-schatting** = `p95_ms + draw_avg×%.2f + scene_nodes×%.3f`; **RISK** als ≥ **%.3f ms** (60 fps).\n\n" % [
			EST_DRAW_MS, EST_NODE_MS, S25_BUDGET_MS]
	s += "| id | kind | mode | frame avg ms | frame p95 ms | draw avg | draw max | scene nodes | engine nodes | static MB | S25 est ms | flag |\n"
	s += "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|\n"
	for row in rows:
		s += "| `%s` | %s | %s | %.2f | %.2f | %.1f | %d | %d | %d | %.2f | %.2f | **%s** |\n" % [
				row["id"], row.get("kind", ""), row.get("mode", ""), float(row.get("frame_avg_ms", 0.0)),
				float(row.get("frame_p95_ms", 0.0)), float(row.get("draw_avg", 0.0)), int(row.get("draw_max", 0)),
				int(row.get("scene_nodes", 0)), int(row.get("nodes_engine", 0)), float(row.get("static_mem_mb", 0.0)),
				float(row.get("s25_est_ms", 0.0)), row.get("s25_flag", "")]
	s += "\n## S25 60 fps (16,667 ms) — headless signalen\n\n"
	s += "Bevestig op het toestel met `docs/perf/s25_check.md`. Headless **RISK** betekent: extra aandacht op de S25, geen garantie.\n\n"
	if risky.is_empty():
		s += "- **RISK:** geen\n"
	else:
		s += "- **RISK:** `" + "`, `".join(risky) + "`\n"
	if watch.is_empty():
		s += "- **WATCH:** geen\n"
	else:
		s += "- **WATCH:** `" + "`, `".join(watch) + "`\n"
	s += "\n## Kamers zonder speler (alleen idle)\n\n"
	s += "Hub-kamers via `change_map`, warper-veldkaarten en gevechten meten geen loop-samples.\n"
	var f := FileAccess.open(md_path, FileAccess.WRITE)
	if f != null:
		f.store_string(s)
		f.close()
		print("WM1BASELINE md: %s" % ProjectSettings.globalize_path(md_path))
