extends Node
## ALLEEN VOOR TESTEN - UX-polish WM1 (fase 6). EXPLORATIEF (audit): schrijft INFO-regels.
const UiTouch := preload("res://scripts/ui/ui_touch.gd")
var failures := 0
var passes := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()

func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok: passes += 1
	else: failures += 1

var shots := ""
func shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots, name])

func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()

func report(name: String, root: Node) -> void:
	var small := UiTouch.small_targets(root)
	print("AUDIT %s: %d te klein" % [name, small.size()])
	for s in small:
		print("   %s  %s  '%s'" % [s["path"].get_slice("/", s["path"].get_slice_count("/") - 1) if false else s["path"], s["size"], s["text"]])

func offscreen(root: Node) -> Array:
	var vs := get_viewport().get_visible_rect()
	var out: Array = []
	_off(root, vs, out)
	return out

func _off(n: Node, vs: Rect2, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is ScrollContainer:
		return
	if n is BaseButton and (n as Control).size.y > 0:
		var r := (n as Control).get_global_rect()
		if r.position.x < vs.position.x - 0.5 or r.position.y < vs.position.y - 0.5 or r.end.x > vs.end.x + 0.5 or r.end.y > vs.end.y + 0.5:
			out.append("%s %s '%s'" % [n.get_path(), r, str((n as BaseButton).get("text"))])
	for c in n.get_children():
		_off(c, vs, out)

func report_all(name: String, root: Node) -> void:
	report(name, root)
	if "hint" in root and root.hint != null:
		var hr: Rect2 = root.hint.get_global_rect()
		var cr: Rect2 = root.content.get_global_rect()
		print("HINT %s: hint %s content %s" % [name, hr, cr])
	var o := offscreen(root)
	if not o.is_empty():
		print("OFFSCREEN %s: %d" % [name, o.size()])
		for x in o: print("   ", x)

func _run() -> void:
	await wait_until(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	GameState.new_game("Dax")
	GameState.story_step = 99
	GameState.change_map("res://scenes/maps/wilgendal.tscn", "")
	await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.name == "Wilgendal" and get_tree().current_scene.is_node_ready() and not GameState.changing_map, 10.0)
	await pframes(30)
	var map := get_tree().current_scene
	report_all("touch HUD", map.get_node("TouchControls"))
	Input.action_press("menu")
	await pframes(3)
	Input.action_release("menu")
	await pframes(10)
	var fm := map.get_node_or_null("FieldMenu")
	print("fieldmenu ", fm)
	if fm != null:
		report_all("field menu", fm)
		await shot("field_menu")
		for id in ["equip","codex","items","magic","bestiary","warp","party","quests","scenes","options","load"]:
			fm.choose(id)
			await pframes(12)
			if fm.sub != null:
				report_all("sub " + id, fm.sub)
				await shot("sub_" + id)
				fm.sub.close()
				await pframes(6)
			else:
				print("geen sub voor ", id)
		fm.open_save()
		await pframes(12)
		if fm.sub != null:
			report_all("save screen", fm.sub)
			await shot("save_screen")
			fm.sub.close()
			await pframes(6)
		var SP := preload("res://scripts/ui/save_prompt.gd")
		var sp := SP.new()
		fm.add_child(sp)
		await pframes(8)
		report_all("save prompt", sp)
		sp.queue_free()
		fm.close()
	await pframes(5)
	if false:
		pass
	await wait_until(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
	await pframes(10)

	await pframes(10)
	report("title", get_tree().current_scene)
	await shot("title")
	print("RESULT OK (audit)")
	get_tree().quit(0)
