extends Node
## WM1 studio-URL op het titelscherm (--studiourltest). Niet in tests.yml / CI.
## Start: godot --path . -- --studiourltest [--shots=/pad/map]

const Wm1Config := preload("res://scripts/data/wm1_config.gd")

const VIEW_WIDTHS := [384, 432, 468]
const VIEW_H := 216

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	GameState.go_to_title()
	await _wacht(func() -> bool: return _title() != null and not GameState.changing_map, 10.0)
	await _pframes(10)
	var t := _title()
	check("titelscherm geladen", t != null)
	if t == null:
		_finish()
		return
	check("studio-label tekst", t.studio_label.text == Wm1Config.STUDIO_URL)
	check("studio-label 10px grid", t.studio_label.get_theme_font_size("font_size") == 10)
	var ver: Rect2 = t.version_label.get_global_rect()
	var st: Rect2 = t.studio_label.get_global_rect()
	check("studio links van versie (x)", st.end.x <= ver.position.x - 3.0)
	check("studio op dezelfde regel als versie (y)", absf(st.position.y - ver.position.y) <= 0.5)
	check("footer binnen beeld", st.position.x >= 0.0 and ver.end.x <= t.size.x and ver.end.y <= t.size.y)
	for w in VIEW_WIDTHS:
		await _set_viewport(w)
		await _pframes(6)
		var tag := "%dx%d" % [w, VIEW_H]
		check("%s: geen overlap studio vs menukaart" % tag, _studio_clear_of(t, t.card.get_global_rect()))
		check("%s: geen overlap studio vs save-info" % tag, _studio_clear_of(t, t.save_info.get_global_rect()) if t.save_info.visible else true)
		for btn_name in ["CoopButton", "PvpButton", "SomButton"]:
			var btn: Control = t.get_node_or_null(btn_name) as Control
			if btn != null and btn.visible:
				check("%s: geen overlap studio vs %s" % [tag, btn_name], _studio_clear_of(t, btn.get_global_rect()))
		check("%s: geen overlap studio vs betakaart" % tag, _studio_clear_of(t, t.beta_card.get_global_rect()))
		check("%s: geen overlap studio vs beta-info" % tag, _studio_clear_of(t, t.beta_info.get_global_rect()) if t.beta_info.visible else true)
	await _screenshot("title_studio_url")
	_finish()


func _studio_clear_of(t: Node, other: Rect2) -> bool:
	if not other.has_area():
		return true
	return not t.studio_label.get_global_rect().intersects(other)


func _set_viewport(w: int) -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.size = Vector2i(w, VIEW_H)
	await get_tree().process_frame


func _finish() -> void:
	print("STUDIOURLTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _title() -> Node:
	var nu := get_tree().current_scene
	return nu if nu != null and nu.get("studio_label") != null else null


func _wacht(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"), " ", img.get_size())
