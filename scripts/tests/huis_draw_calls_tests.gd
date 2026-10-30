extends Node
## Draw-call budget voor huis_wilgendal (WM1). Start: godot --path . -- --huisdrawtest

const HUIS := "res://scenes/maps/huis_wilgendal.tscn"
const MAX_DRAW := 60
const WARMUP := 30
const FRAMES := 90

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	GameState.new_game("Dax")
	GameState.pending_spawn = "binnen"
	var packed := load(HUIS) as PackedScene
	_check("huis_wilgendal laadt", packed != null)
	if packed == null:
		return
	get_tree().change_scene_to_packed(packed)
	for _i in 120:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and str(cs.scene_file_path) == HUIS and cs.is_node_ready():
			break
	var cap := Engine.max_fps
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for _i in WARMUP:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var draw_sum := 0.0
	var draw_max := 0
	for _i in FRAMES:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_sum += dc
		draw_max = maxi(draw_max, dc)
	Engine.max_fps = cap
	var draw_avg: float = draw_sum / float(FRAMES)
	_check("huis_wilgendal draw_avg <= %d (was ~528)" % MAX_DRAW, draw_avg <= float(MAX_DRAW))
	_check("huis_wilgendal draw_max <= %d" % MAX_DRAW, draw_max <= MAX_DRAW)
	print("HUISDRAW avg=%.1f max=%d" % [draw_avg, draw_max])
