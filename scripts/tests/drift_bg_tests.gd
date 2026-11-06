extends Node
## Drift-achtergrond op een breed landschap (2400×1080, stretch expand).
## De achtergrond moet het viewport dekken; tekst en schip blijven in het midden.
## Start: godot --path . -- --driftbgtest [--shots=/pad/map]
## Niet in tests.yml / CI (bewust los van de matrix).

const Drift := preload("res://world_warper/opening/drift.gd")
const Art := preload("res://world_warper/opening/art.gd")

const WINDOW := Vector2i(2400, 1080)

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shots="):
			shots = str(arg).get_slice("=", 1)
	call_deferred("_run")


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	if has_node("/root/Crt") and Crt.has_method("set_enabled"):
		Crt.set_enabled(false)
	var scene := get_tree().current_scene
	if scene != null:
		scene.visible = false
	await _zet_breed_venster()
	var drift := Drift.new()
	drift.name = "OpeningDrift"
	add_child(drift)
	for _i in 8:
		await get_tree().process_frame
	var view := get_viewport().get_visible_rect()
	check("venster 2400x1080 (%s)" % get_window().size, get_window().size == WINDOW)
	check("viewport breder dan 384 (%s)" % view.size, view.size.x > float(Art.VIEW_W) + 32.0 and view.size.y >= float(Art.VIEW_H) - 1.0)
	var root := drift.get_node_or_null("Root") as Control
	var backfill := drift.get_node_or_null("Root/Backfill") as Control
	var stage := drift.get_node_or_null("Root/Stage") as Control
	check("drift-nodes aanwezig", root != null and backfill != null and stage != null)
	if root == null or backfill == null or stage == null:
		_finish()
		return
	var bg := backfill.get_global_rect()
	check("achtergrond dekt viewport bg=%s view=%s" % [bg, view], _dekt(bg, view))
	var ver := root.get_global_rect()
	check("root dekt viewport root=%s" % ver, _dekt(ver, view))
	var midden := stage.position + stage.size * 0.5
	var doel := view.size * 0.5
	check("stage (tekst en schip) gecentreerd midden=%s doel=%s" % [midden, doel],
			absf(midden.x - doel.x) <= 1.0 and absf(midden.y - doel.y) <= 1.0)
	check("stage niet tegen de linkerrand", stage.position.x > 8.0)
	var far := stage.get_node_or_null("Parallax/drift_bg_far") as Node2D
	check("far-laag aanwezig", far != null)
	if far != null:
		var tegels := _sprite_bounds(far)
		check("far-tegels dekken viewport %s" % tegels, _dekt(tegels, view))
	var schip := _schip(stage)
	if schip != null:
		var hart := schip.global_position + Vector2(Art.WARPER_FRAME) * 0.5
		check("schip in het midden hart=%s" % hart, absf(hart.x - doel.x) <= 1.0 and absf(hart.y - doel.y) <= 1.0)
	else:
		check("schip aanwezig", false)
	await _pixels(view)
	await _screenshot("drift_wide")
	_finish()


func _dekt(r: Rect2, view: Rect2) -> bool:
	return r.position.x <= view.position.x + 1.0 and r.position.y <= view.position.y + 1.0 \
			and r.end.x >= view.end.x - 1.0 and r.end.y >= view.end.y - 1.0


func _sprite_bounds(node: Node2D) -> Rect2:
	var rect := Rect2()
	var any := false
	for c in node.get_children():
		var s := c as Sprite2D
		if s == null or s.texture == null:
			continue
		var stuk := Rect2(s.global_position, s.texture.get_size())
		rect = stuk if not any else rect.merge(stuk)
		any = true
	return rect


func _schip(stage: Node) -> Sprite2D:
	var par := stage.get_node_or_null("Parallax")
	if par == null:
		return null
	for c in par.get_children():
		var s := c as Sprite2D
		if s != null and s.texture != null and s.hframes == Art.WARPER_FRAMES:
			return s
	return null


func _zet_breed_venster() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(Art.VIEW_W, Art.VIEW_H)
	win.size = WINDOW
	DisplayServer.window_set_size(WINDOW)
	for _i in 6:
		await get_tree().process_frame


func _pixels(view: Rect2) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		check("viewport-beeld beschikbaar", false)
		return
	var leeg := 0
	var n := 0
	var x := img.get_width() - 2
	for y in range(2, img.get_height() - 2, 4):
		n += 1
		if _lijkt_leeg(img.get_pixel(x, y)):
			leeg += 1
	check("rechterkolom gevuld %d/%d leeg (beeld %s, view %s)" % [leeg, n, img.get_size(), view.size],
			n > 0 and float(leeg) / float(n) < 0.15)
	if shots != "":
		print("INFO  beeld %s" % img.get_size())


func _lijkt_leeg(c: Color) -> bool:
	if c.a < 0.5:
		return true
	if c.r < 0.04 and c.g < 0.04 and c.b < 0.04:
		return true
	var grijs := absf(c.r - c.g) < 0.05 and absf(c.g - c.b) < 0.05
	return grijs and absf(c.r - 0.3) < 0.08


func _screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	var pad := shots.path_join(name + ".png")
	img.save_png(pad)
	print("INFO  screenshot: ", pad, " ", img.get_size())


func _finish() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
