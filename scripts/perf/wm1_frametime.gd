class_name Wm1Frametime
extends RefCounted
## Gedeelde WM1-frametijdmeting (headless, gl_compatibility): script-tijd per frame (process_frame →
## frame_pre_draw), gemiddelde draw calls en node-tellers. Zie docs/perf_wm1.md.
## Gebruikt door --wm1frametest (loggen); budget-regressie volgt in een aparte PR (#246).

const Kamers := preload("res://world_warper/kamers/kamers.gd")

const MAPS_DIR := "res://scenes/maps/"
const WARPER_MAPS_DIR := "res://world_warper/maps/"
const MAP_EXCLUDE := ["dungeon100.tscn", "archief_test.tscn", "kern_demo.tscn"]
const WARPER_MAP_EXCLUDE := ["codex_nis.tscn", "sapientia_schot.tscn"]

const DEFAULT_WARMUP := 30
const DEFAULT_FRAMES := 180

var _pd_start_us := 0
var _pd_acc_us := 0


## [{id, path, group, kind}] — kind: map | warper_map | warper_kamer
static func rooms() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in DirAccess.get_files_at(MAPS_DIR):
		if not f.ends_with(".tscn") or f in MAP_EXCLUDE:
			continue
		var id := f.get_basename()
		out.append({"id": id, "path": MAPS_DIR + f, "group": "maps", "kind": "map"})
	for f in DirAccess.get_files_at(WARPER_MAPS_DIR):
		if not f.ends_with(".tscn") or f in WARPER_MAP_EXCLUDE:
			continue
		var id := "warper_" + f.get_basename()
		out.append({"id": id, "path": WARPER_MAPS_DIR + f, "group": "warper_maps", "kind": "warper_map"})
	for kid in Kamers.ROOMS.keys():
		out.append({
			"id": "kamer_" + str(kid),
			"path": Kamers.scene_path(str(kid)),
			"group": "warper_kamers",
			"kind": "warper_kamer",
			"room_id": str(kid),
		})
	out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return out


static func log_line(room_id: String, path: String, m: Dictionary) -> String:
	return ("WM1FRAME id=%s path=%s proc_ms=%.3f draw=%.1f draw_max=%d nodes=%d scene_nodes=%d frames=%d"
			% [room_id, path, m["proc_ms"], m["draw_avg"], m["draw_max"], m["nodes"], m["scene_nodes"], m["frames"]])


func clear_scene(tree: SceneTree) -> void:
	var cs := tree.current_scene
	if cs != null:
		tree.current_scene = null
		cs.queue_free()
	for _i in 4:
		await tree.process_frame
	GameState.changing_map = false
	GameState.in_battle = false
	GameState.pending_spawn = ""
	GameState.has_return_point = false


func enter_room(tree: SceneTree, room: Dictionary) -> bool:
	await clear_scene(tree)
	var path: String = room["path"]
	var kind: String = room["kind"]
	if kind == "warper_kamer":
		GameState.story_flags[Kamers.FLAG_HUB] = true
		GameState.change_map(path, "ingang")
		for _i in 600:
			await tree.process_frame
			var nu := tree.current_scene
			if nu != null and nu.scene_file_path == path and not GameState.changing_map:
				return true
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	tree.change_scene_to_packed(packed)
	for _i in 600:
		await tree.process_frame
		var nu := tree.current_scene
		if nu != null and str(nu.scene_file_path) == path:
			await RenderingServer.frame_post_draw
			return true
	return false


func count_nodes(root: Node) -> int:
	var n := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		n += 1
		for c in node.get_children():
			stack.append(c)
	return n


## Meet na warmup: proc_ms (gemiddelde), draw_avg, draw_max, nodes (engine), scene_nodes (huidige scène).
func sample_idle(tree: SceneTree, warmup: int = DEFAULT_WARMUP, frames: int = DEFAULT_FRAMES) -> Dictionary:
	var cap := Engine.max_fps
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for _i in warmup:
		await tree.process_frame
		await RenderingServer.frame_post_draw
	var cs := tree.current_scene
	var scene_nodes := count_nodes(cs) if cs != null else 0
	var proc: Array[float] = []
	var draw_sum := 0.0
	var draw_max := 0
	_pd_start_us = 0
	_pd_acc_us = 0
	var on_start := func() -> void:
		_pd_start_us = Time.get_ticks_usec()
	var on_pre := func() -> void:
		if _pd_start_us > 0:
			_pd_acc_us = Time.get_ticks_usec() - _pd_start_us
	tree.process_frame.connect(on_start)
	RenderingServer.frame_pre_draw.connect(on_pre)
	for _i in frames:
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var script_ms := float(_pd_acc_us) / 1000.0
		if script_ms <= 0.0:
			script_ms = (Performance.get_monitor(Performance.TIME_PROCESS)
					+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		proc.append(script_ms)
		var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_sum += dc
		draw_max = maxi(draw_max, dc)
	tree.process_frame.disconnect(on_start)
	RenderingServer.frame_pre_draw.disconnect(on_pre)
	Engine.max_fps = cap
	var proc_sum := 0.0
	for v in proc:
		proc_sum += v
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	return {
		"proc_ms": proc_sum / maxf(1.0, proc.size()),
		"draw_avg": draw_sum / maxf(1.0, float(frames)),
		"draw_max": draw_max,
		"nodes": nodes,
		"scene_nodes": scene_nodes,
		"frames": frames,
	}
