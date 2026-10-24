extends Node
## Perf-harnas WM1 (laad- en scène-wisseltijden + script-tijd per frame). Geen test en geen gameplay:
## meet alleen. Start (zie tools/perf/run_perf_wm1.sh):
##   XDG_DATA_HOME=/tmp/xdg xvfb-run -a godot --rendering-driver opengl3 --path . \
##       res://tools/perf/perf_wm1.tscn -- --perfwm1 [--runs=5] [--frames=300] [--out=/tmp/perf.json]
## Eerst de scène (tools/perf/perf_wm1.tscn) i.p.v. een dispatch in game_state.gd, zodat dit
## bestand ook op oudere commits draait (voor/na-vergelijking) en game_state.gd niet raakt.
##
## Hoe er gemeten wordt:
## - Engine.time_scale = 1000 tijdens de overgangen: de vaste fades/timers (0,3 s, 0,06 s, 0,35 s autosave)
##   kosten dan ~1 frame en de gemeten tijd is het echte werk (laden, instantiëren, _ready, save lezen/schrijven).
## - max_fps = 0 en vsync uit: geen framebegrenzing in de meting.
## - Elke stap wordt `runs` keer gemeten (mediaan + min/max). Cold = eerste keer na de start, warm = herhaling.
## - 'ready_ms' = van de aanroep tot de nieuwe scène in de boom staat en klaar is (frame dat de swap doet);
##   'settled_ms' = ook 4 frames later (autosave, call_deferred-werk, eerste _process).
## - 'hitch_ms' = langste enkele frame tijdens de stap (voelbare stotter op een telefoon).
## - Script-tijd per frame: Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS (zonder renderen) op de wereldkaart,
##   stilstaand en lopend, plus de kosten per _process-aanroep per node ('probe').
## Xvfb-renderer is software (llvmpipe): absolute getallen zijn NIET die van een Samsung S25 Ultra;
## vergelijk alleen voor/na op dezelfde machine.

const WORLD := "res://scenes/maps/wereldkaart.tscn"
const TITLE := "res://scenes/ui/title.tscn"
const TIME_SCALE := 1000.0

## Route langs WM1-kaarten: [map, spawn]. Eerste doorloop = cold, tweede = warm.
const ROUTE: Array = [
	["res://scenes/maps/wilgendal.tscn", "start"],
	["res://scenes/maps/wereldkaart.tscn", "van_wilgendal"],
	["res://scenes/maps/dorp_wilgendal.tscn", "zuid_ingang"],
	["res://scenes/maps/esdoorn.tscn", "zuid_ingang"],
	["res://scenes/maps/wereldkaart.tscn", "van_esdoorn"],
	["res://scenes/maps/woud_rand.tscn", "ingang"],
	["res://scenes/maps/woud_pad.tscn", "zuid"],
	["res://scenes/maps/wereldkaart.tscn", "van_woud"],
	["res://scenes/maps/archief_ingang.tscn", "ingang"],
	["res://scenes/maps/archief_v1_gang.tscn", "zuid"],
	["res://scenes/maps/wereldkaart.tscn", "van_archief"],
	["res://scenes/maps/berggrot_bouwplaats.tscn", "zuid"],
	["res://scenes/maps/wereldkaart.tscn", "van_berggrot"],
]

var runs := 5
var frames := 300
## Echte tijd (ms) die de speler op het titelscherm doorbrengt voordat hij Doorgaan kiest; lege-tijd-werk
## (prewarm) mag dan afronden. Voor/na gebruiken dezelfde waarde.
var dwell_ms := 4000
var out_path := ""
var probe_on := true
var result := {}
var _frame_max_us := 0
var _last_us := 0


func _ready() -> void:
	# De hoofdscène is alleen een steiger: het eigenlijke harnas hangt aan de root, zodat het
	# scènewissels (die current_scene vrijgeven) overleeft.
	if get_tree().current_scene == self:
		var h: Node = get_script().new()
		h.name = "PerfWm1Run"
		get_tree().root.add_child.call_deferred(h)
		return
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--runs="):
			runs = maxi(1, int(a.get_slice("=", 1)))
		elif a.begins_with("--frames="):
			frames = maxi(30, int(a.get_slice("=", 1)))
		elif a.begins_with("--out="):
			out_path = a.get_slice("=", 1)
		elif a.begins_with("--dwell="):
			dwell_ms = maxi(0, int(a.get_slice("=", 1)))
		elif a == "--noprobe":
			probe_on = false
	result["engine_start_to_harness_ms"] = Time.get_ticks_msec()
	result["godot"] = Engine.get_version_info().get("string", "")
	result["runs"] = runs
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameState.encounter_multiplier = 0.0
	_run.call_deferred()


# ---------------------------------------------------------------- hulpjes
func _now_us() -> int:
	return Time.get_ticks_usec()


func _frame() -> void:
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	var n := b.size()
	return float(b[n / 2]) if n % 2 == 1 else (float(b[n / 2 - 1]) + float(b[n / 2])) / 2.0


func _stat(name: String, samples: Array) -> void:
	var ms: Array = samples.map(func(us): return snappedf(float(us) / 1000.0, 0.01))
	result[name] = {"median": snappedf(_median(ms), 0.01), "min": snappedf(float(ms.min()), 0.01),
			"max": snappedf(float(ms.max()), 0.01), "n": ms.size()}
	print("PERF %-34s median=%8.2f ms  min=%8.2f  max=%8.2f  (n=%d)" % [name, result[name]["median"],
			result[name]["min"], result[name]["max"], ms.size()])


func _scene_path() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s != null else ""


## Wacht tot de huidige scène 'path' is; geeft de tijdstempel (µs) van het frame waarin hij klaar stond.
func _wait_scene(path: String, timeout_frames := 600) -> int:
	for i in timeout_frames:
		await get_tree().process_frame
		if _scene_path() == path and get_tree().current_scene.is_node_ready():
			return _now_us()
	push_error("PERF: timeout, scène %s niet bereikt (nu %s)" % [path, _scene_path()])
	return -1


## Houdt het langste frame bij (µs) tussen start_hitch() en stop_hitch().
func _on_frame_tick() -> void:
	var t := _now_us()
	_frame_max_us = maxi(_frame_max_us, t - _last_us)
	_last_us = t


func _start_hitch() -> void:
	_frame_max_us = 0
	_last_us = _now_us()
	if not get_tree().process_frame.is_connected(_on_frame_tick):
		get_tree().process_frame.connect(_on_frame_tick)


func _stop_hitch() -> int:
	if get_tree().process_frame.is_connected(_on_frame_tick):
		get_tree().process_frame.disconnect(_on_frame_tick)
	return _frame_max_us


## Realistische save: hele party, bestiarium, tas, verhaalvlaggen (zodat JSON-parse/serialisatie meetelt).
func _fill_state() -> void:
	GameState.new_game()
	for id in ["lotte", "noor"]:
		GameState.add_member(id)
	for id in GameData.ENEMIES:
		GameState.bestiary[id] = {"seen": true, "defeated": 12}
	for id in GameData.ITEMS:
		GameState.inventory[id] = 9
	GameState.gold = 12345
	GameState.story_step = StoryData.KLAAR
	for k in StoryData.UNIQUE_SEEN_FLAGS.values():
		GameState.story_flags[str(k)] = true
	for i in 20:
		GameState.story_flags["perf_flag_%d" % i] = true
	GameState.bezochte_kaarten = []
	for r in ROUTE:
		GameState.bezochte_kaarten.append(str(r[0]))


const GameData := preload("res://scripts/data/game_data.gd")
const StoryData := preload("res://scripts/data/story_data.gd")


func _write_saves() -> void:
	GameState.use_story_saves()
	_fill_state()
	GameState.current_map = WORLD
	for slot in range(1, GameState.SLOT_COUNT + 1):
		GameState.active_slot = slot
		GameState.save_game(Vector2i(10, 10), Vector2i.DOWN)
	GameState.save_game(Vector2i(10, 10), Vector2i.DOWN, GameState.autosave_path)
	GameState.active_slot = 1
	var f := FileAccess.open(GameState.slot_path(1), FileAccess.READ)
	result["save_bytes"] = f.get_length() if f != null else 0


# ---------------------------------------------------------------- hoofdlus
func _run() -> void:
	await _frames(3)
	GameState.save_path = "user://perfwm1_save_1.json"
	GameState.autosave_path = "user://perfwm1_autosave.json"
	GameState._story_save_path = GameState.save_path
	GameState._story_autosave_path = GameState.autosave_path
	for s in range(1, GameState.SLOT_COUNT + 1):
		var p := GameState.slot_path(s)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if FileAccess.file_exists(GameState.autosave_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.autosave_path))

	await _bench_startup()
	_write_saves()
	await _bench_title_to_wm1()
	await _bench_route()
	await _bench_battle()
	await _bench_save_load()
	await _bench_frames()

	var txt := JSON.stringify(result, "  ")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(txt)
			f.close()
	print("PERFJSON ", JSON.stringify(result))
	print("RESULT OK (perfwm1)")
	get_tree().quit(0)


# ---------------------------------------------------------------- stappen
func _bench_startup() -> void:
	# Eerste titelscherm na de start (cold), daarna 'dwell_ms' echte tijd (speler leest het scherm).
	# De autoloads zijn dan al klaar; 'engine_start_to_harness_ms' is de tijd tot daar.
	Engine.time_scale = TIME_SCALE
	_start_hitch()
	var t0 := _now_us()
	GameState._go_to_scene(TITLE)
	var t1 := await _wait_scene(TITLE)
	await _frames(2)
	result["startup_title_first_ready_ms"] = snappedf(float(t1 - t0) / 1000.0, 0.01)
	result["startup_title_first_hitch_ms"] = snappedf(float(_stop_hitch()) / 1000.0, 0.01)
	Engine.time_scale = 1.0
	print("PERF startup_title_first_ready_ms           %8.2f ms (hitch %.2f)" % [result["startup_title_first_ready_ms"],
			result["startup_title_first_hitch_ms"]])
	# Langste frame tijdens het wachten op het titelscherm: zichtbaar maakt dit de stalls van achtergrondwerk
	# (voorladen/prewarm) die het titelscherm kort laten haperen.
	var d0 := Time.get_ticks_msec()
	var dwell_worst_us := 0
	var prev_us := _now_us()
	while Time.get_ticks_msec() - d0 < dwell_ms:
		await get_tree().process_frame
		var nu := _now_us()
		dwell_worst_us = maxi(dwell_worst_us, nu - prev_us)
		prev_us = nu
	result["title_dwell_worst_frame_ms"] = snappedf(float(dwell_worst_us) / 1000.0, 0.01)
	print("PERF title_dwell_worst_frame_ms             %8.2f ms (dwell %d ms)" % [result["title_dwell_worst_frame_ms"], dwell_ms])
	var t: Array = []
	var hitch: Array = []
	for i in runs:
		if get_tree().current_scene != null:
			get_tree().current_scene.queue_free()
		await _frames(2)
		Engine.time_scale = TIME_SCALE
		_start_hitch()
		t0 = _now_us()
		GameState._go_to_scene(TITLE)
		t1 = await _wait_scene(TITLE)
		await _frames(2)
		t.append(t1 - t0)
		hitch.append(_stop_hitch())
		Engine.time_scale = 1.0
	_stat("startup_title_warm_ready_ms", t)
	_stat("startup_title_warm_hitch_ms", hitch)
	Engine.time_scale = 1.0


func _bench_title_to_wm1() -> void:
	var title_t: Array = []
	var list_t: Array = []
	var cont_t: Array = []
	var settled_t: Array = []
	var hitch: Array = []
	for i in runs:
		Engine.time_scale = TIME_SCALE
		GameState.use_story_saves()
		GameState.changing_map = false
		GameState.in_battle = false
		var t0 := _now_us()
		GameState._go_to_scene(TITLE)
		var t1 := await _wait_scene(TITLE)
		await _frames(2)
		title_t.append(t1 - t0)
		var title := get_tree().current_scene
		# slotlijst openen (leest alle saves)
		var l0 := _now_us()
		title._open_slot_list()
		await _frame()
		list_t.append(_now_us() - l0)
		# Continue -> wereldkaart
		_start_hitch()
		var c0 := _now_us()
		title._on_slot_picked(1)
		var c1 := await _wait_scene(WORLD)
		cont_t.append(c1 - c0)
		await _frames(4)
		settled_t.append(_now_us() - c0)
		hitch.append(_stop_hitch())
		Engine.time_scale = 1.0
	_stat("title_ready_with_saves_ms", title_t)
	_stat("title_slotlist_open_ms", list_t)
	_stat("title_to_wm1_ready_ms", cont_t)
	_stat("title_to_wm1_settled_ms", settled_t)
	_stat("title_to_wm1_hitch_ms", hitch)


func _bench_route() -> void:
	var cold: Array = []
	var warm: Array = []
	var cold_h: Array = []
	var warm_h: Array = []
	for pass_i in 2:
		for step in ROUTE:
			var path: String = step[0]
			var spawn: String = step[1]
			GameState.changing_map = false
			Engine.time_scale = TIME_SCALE
			_start_hitch()
			var t0 := _now_us()
			GameState.change_map(path, spawn)
			var t1 := await _wait_scene(path)
			await _frames(4)
			var settled := _now_us() - t0
			var hitch := _stop_hitch()
			Engine.time_scale = 1.0
			var rec := {"map": path.get_file().get_basename(), "ready_us": t1 - t0, "settled_us": settled, "hitch_us": hitch}
			if pass_i == 0:
				cold.append(rec)
			else:
				warm.append(rec)
			await _frames(2)
	_stat("map_transition_cold_ready_ms", cold.map(func(r): return r["ready_us"]))
	_stat("map_transition_cold_settled_ms", cold.map(func(r): return r["settled_us"]))
	_stat("map_transition_cold_hitch_ms", cold.map(func(r): return r["hitch_us"]))
	_stat("map_transition_warm_ready_ms", warm.map(func(r): return r["ready_us"]))
	_stat("map_transition_warm_settled_ms", warm.map(func(r): return r["settled_us"]))
	_stat("map_transition_warm_hitch_ms", warm.map(func(r): return r["hitch_us"]))
	var per := {}
	for r in cold:
		per[r["map"] + "#cold"] = snappedf(float(r["ready_us"]) / 1000.0, 0.01)
	for r in warm:
		per[r["map"] + "#warm"] = snappedf(float(r["ready_us"]) / 1000.0, 0.01)
	result["map_transition_per_map_ms"] = per
	for k in per:
		print("PERF   map %-34s %8.2f ms" % [k, per[k]])


func _bench_battle() -> void:
	var enter: Array = []
	var enter_h: Array = []
	var leave: Array = []
	var leave_h: Array = []
	GameState.changing_map = false
	GameState.in_battle = false
	GameState.change_map(WORLD, "van_wilgendal")
	Engine.time_scale = TIME_SCALE
	await _wait_scene(WORLD)
	await _frames(4)
	Engine.time_scale = 1.0
	for i in runs + 1:
		var m := get_tree().current_scene
		Engine.time_scale = TIME_SCALE
		_start_hitch()
		var t0 := _now_us()
		m.start_battle(["mosslijm", "moskonijn"])
		var t1 := await _wait_scene(GameState.BATTLE_SCENE)
		await _frames(4)
		var h1 := _stop_hitch()
		if i > 0:   # eerste ronde = cold, wordt als eerste sample meegerekend maar apart gerapporteerd
			enter.append(t1 - t0)
			enter_h.append(h1)
		else:
			result["battle_enter_cold_ms"] = snappedf(float(t1 - t0) / 1000.0, 0.01)
		# gevecht uit: end_battle("run")
		_start_hitch()
		var u0 := _now_us()
		GameState.end_battle("run")
		var u1 := await _wait_scene(WORLD)
		await _frames(4)
		var h2 := _stop_hitch()
		Engine.time_scale = 1.0
		if i > 0:
			leave.append(u1 - u0)
			leave_h.append(h2)
		else:
			result["battle_exit_cold_ms"] = snappedf(float(u1 - u0) / 1000.0, 0.01)
		await _frames(2)
	_stat("battle_enter_warm_ms", enter)
	_stat("battle_enter_hitch_ms", enter_h)
	_stat("battle_exit_warm_ms", leave)
	_stat("battle_exit_hitch_ms", leave_h)
	print("PERF battle cold enter=%s exit=%s ms" % [result.get("battle_enter_cold_ms"), result.get("battle_exit_cold_ms")])


func _bench_save_load() -> void:
	GameState.use_story_saves()
	var n := maxi(runs * 4, 20)
	var rd: Array = []
	var ap: Array = []
	var sd: Array = []
	var sv: Array = []
	var sl: Array = []
	var nw: Array = []
	var cp: Array = []
	for i in n:
		var t0 := _now_us()
		var d := GameState.read_save(GameState.slot_path(1))
		rd.append(_now_us() - t0)
		t0 = _now_us()
		GameState.apply_state(d)
		ap.append(_now_us() - t0)
		t0 = _now_us()
		GameState.state_data(Vector2i(10, 10), Vector2i.DOWN)
		sd.append(_now_us() - t0)
		t0 = _now_us()
		GameState.save_game(Vector2i(10, 10), Vector2i.DOWN, GameState.slot_path(1))
		sv.append(_now_us() - t0)
		t0 = _now_us()
		for s in [1, 2, 3, 4, 0]:
			GameState.slot_record(s)
		sl.append(_now_us() - t0)
		t0 = _now_us()
		GameState.newest_slot_record()
		nw.append(_now_us() - t0)
		t0 = _now_us()
		GameState.set_checkpoint(WORLD, Vector2i(10, 10), Vector2i.DOWN)
		cp.append(_now_us() - t0)
	_stat("save_read_one_ms", rd)
	_stat("save_apply_state_ms", ap)
	_stat("save_state_data_ms", sd)
	_stat("save_write_ms", sv)
	_stat("save_slot_records_5_ms", sl)
	_stat("save_newest_slot_record_ms", nw)
	_stat("save_set_checkpoint_ms", cp)


## Kaarten voor de script-tijd per frame: [map, spawn, tag]. Wereldkaart ook lopend.
const FRAME_MAPS: Array = [
	["res://scenes/maps/wereldkaart.tscn", "van_wilgendal", "wereldkaart"],
	["res://scenes/maps/wilgendal.tscn", "start", "wilgendal"],
	["res://scenes/maps/dorp_wilgendal.tscn", "zuid_ingang", "dorp"],
	["res://scenes/maps/esdoorn.tscn", "zuid_ingang", "esdoorn"],
	["res://scenes/maps/woud_pad.tscn", "zuid", "woud_pad"],
	["res://scenes/maps/archief_v1_gang.tscn", "zuid", "archief_gang"],
]


func _bench_frames() -> void:
	GameState.encounter_multiplier = 0.0
	var probes := {}
	for entry in FRAME_MAPS:
		GameState.changing_map = false
		GameState.in_battle = false
		GameState.change_map(entry[0], entry[1])
		Engine.time_scale = TIME_SCALE
		await _wait_scene(entry[0])
		await _frames(4)
		Engine.time_scale = 1.0
		await _frames(30)
		var tag: String = entry[2]
		var idle := await _sample_frames(frames, "")
		_report_frames("idle_" + tag, idle)
		if probe_on:
			probes[tag] = _probe(get_tree().current_scene)
		if tag == "wereldkaart":
			var walk := await _sample_frames(frames, "walk")
			_report_frames("walk_" + tag, walk)
	result["probe"] = probes


## Script-tijd per frame = van het begin van 'process' (process_frame) tot vlak voor het tekenen
## (RenderingServer.frame_pre_draw): alle _process-callbacks, signalen, timers, tweens en de
## message queue. Renderen zelf (llvmpipe) zit er dus niet in. Performance.TIME_PROCESS is in
## headless/xvfb onbetrouwbaar (blijft op de eerste waarde staan) en wordt daarom niet gebruikt.
func _sample_frames(n: int, mode: String) -> Dictionary:
	var s := {"proc": [], "obj": [], "node": []}
	var dirs := ["move_right", "move_down", "move_left", "move_up"]
	var d := 0
	_pd_start = 0
	_pd_acc = 0
	var on_start := func() -> void: _pd_start = _now_us()
	var on_pre_draw := func() -> void:
		if _pd_start > 0:
			_pd_acc = _now_us() - _pd_start
	get_tree().process_frame.connect(on_start)
	RenderingServer.frame_pre_draw.connect(on_pre_draw)
	if mode == "walk":
		Input.action_press(dirs[0])
	for i in n:
		if mode == "walk" and i % 40 == 0 and i > 0:
			Input.action_release(dirs[d])
			d = (d + 1) % dirs.size()
			Input.action_press(dirs[d])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		s["proc"].append(float(_pd_acc) / 1000.0)
		s["obj"].append(Performance.get_monitor(Performance.OBJECT_COUNT))
		s["node"].append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if mode == "walk":
		Input.action_release(dirs[d])
	get_tree().process_frame.disconnect(on_start)
	RenderingServer.frame_pre_draw.disconnect(on_pre_draw)
	return s


var _pd_start := 0
var _pd_acc := 0


func _report_frames(tag: String, s: Dictionary) -> void:
	var proc_ms: Array = s["proc"]
	var sum := 0.0
	for v in proc_ms:
		sum += v
	var r := {
		"script_ms_mean": snappedf(sum / maxf(1.0, proc_ms.size()), 0.0001),
		"script_ms_median": snappedf(_median(proc_ms), 0.0001),
		"script_ms_p95": snappedf(_percentile(proc_ms, 0.95), 0.0001),
		"script_ms_max": snappedf(float(proc_ms.max()), 0.0001),
		"objects_start": s["obj"][0], "objects_end": s["obj"][s["obj"].size() - 1],
		"nodes": s["node"][s["node"].size() - 1],
	}
	result["frame_%s" % tag] = r
	print("PERF frame_%s script mean=%.4f ms median=%.4f p95=%.4f max=%.4f | objects %d -> %d nodes=%d" % [
			tag, r["script_ms_mean"], r["script_ms_median"], r["script_ms_p95"], r["script_ms_max"],
			r["objects_start"], r["objects_end"], r["nodes"]])


static func _percentile(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[clampi(int(ceil(p * b.size())) - 1, 0, b.size() - 1)])


## Kosten per _process-aanroep per node met een script (stilstaande speler). Geeft som + top 6.
func _probe(_root: Node) -> Dictionary:
	var rows: Array = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n == self or n.get_script() == null or not n.is_processing() or not n.has_method("_process"):
			continue
		var k := 200
		var t0 := _now_us()
		for i in k:
			n._process(0.016)
		var per := float(_now_us() - t0) / k
		rows.append([per, str(n.get_path()), str((n.get_script() as Script).resource_path.get_file())])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0.0
	for r in rows:
		total += r[0]
	var top: Array = []
	for i in mini(6, rows.size()):
		top.append({"node": rows[i][1], "script": rows[i][2], "us_per_call": snappedf(rows[i][0], 0.01)})
	print("PERF probe: %d processing nodes, sum of _process = %.2f us/frame" % [rows.size(), total])
	for r in top:
		print("PERF   %8.2f us  %-28s %s" % [r["us_per_call"], r["script"], r["node"]])
	return {"nodes": rows.size(), "us_total": snappedf(total, 0.01), "top": top}
