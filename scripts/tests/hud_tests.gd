extends Node
## ALLEEN VOOR TESTEN - Action-HUD overal (rpgcode/action-hud-overal).
## Start:  godot --path . -- --hudtest [--shots=/pad/map]
##   Deel A: geen D-pad meer: elke scène met knoppen gebruikt de gedeelde touch_controls.tscn,
##           de joystick staat altijd aan en het script tekent/kent geen kruis meer.
##   Deel B: indeling: joystick klein/hoog midden-links, rij rechtsboven [RUN][MENU], KERN boven A,
##           A/B rechtsonder, niets overlapt.
##   Deel C: joystick -> rasteracties (dode zone, 4 richtingen, ui_* voor menu's).
##   Deel D: echt in veld, dorp, World Warper en Classic-gevecht: joystick + rij zichtbaar;
##           rasterlopen met de joystick (precies hele tegels), menu-flick (ui_down).
## Met --shots=map: veld, dorp, world_warper, menu, classic_gevecht (+ _3x).
## Zit niet in de export (scripts/tests/*).

const TOUCH_SCENE := "res://scenes/ui/touch_controls.tscn"
const TC := preload("res://scripts/touch_controls.gd")
const SCENES := [
	["veld", "res://scenes/maps/wilgendal.tscn", "start"],
	["dorp", "res://scenes/maps/esdoorn.tscn", "voor_herberg"],
	["world_warper", "res://world_warper/maps/hal.tscn", "ingang"],
]

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
	print("=== Deel A: geen D-pad ===")
	_no_dpad_tests()
	print("=== Deel B: indeling ===")
	await _layout_tests()
	print("=== Deel C: joystick -> raster ===")
	_stick_tests()
	print("=== Deel D: in het spel ===")
	await _game_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scan(dir.path_join(sub), out)


func _no_dpad_tests() -> void:
	var files: Array = []
	_scan("res://scenes", files)
	_scan("res://world_warper", files)
	var with_touch := 0
	var bad: Array = []
	for f in files:
		var txt := FileAccess.get_file_as_string(f)
		if not "TouchControls" in txt or f == TOUCH_SCENE:
			continue
		with_touch += 1
		if not TOUCH_SCENE in txt:
			bad.append(f)
	check("A: %d scènes met knoppen, allemaal via de gedeelde touch_controls.tscn %s" % [with_touch, bad], with_touch >= 40 and bad.is_empty())
	var src := FileAccess.get_file_as_string("res://scripts/touch_controls.gd")
	check("A: touch_controls.gd tekent geen D-pad-kruis meer (geen CIRCUIT/_draw_dpad)", not "CIRCUIT" in src and not "_draw_dpad" in src)
	var t: Control = load(TOUCH_SCENE).instantiate().get_node("Control")
	check("A: joystick staat standaard aan", t.joystick_mode)
	t.get_parent().free()


func _layout_tests() -> void:
	var layer: Node = load(TOUCH_SCENE).instantiate()
	add_child(layer)
	await get_tree().process_frame
	var t: Control = layer.get_node("Control")
	t.show_menu = true
	t.show_run = true
	t.show_kern = true
	var vs: Vector2 = t.size
	var c: Vector2 = t.stick_center()
	check("B: joystick midden-links en hoog (%s in %s)" % [c, vs], c.x < vs.x * 0.25 and c.y > vs.y * 0.35 and c.y < vs.y * 0.75)
	check("B: joystick kleiner dan de oude D-pad (%.0f < %.0f)" % [t.joy_radius(), t.dpad_radius], t.joy_radius() < t.dpad_radius)
	var m: Rect2 = t.menu_rect()
	var r: Rect2 = t.run_rect()
	check("B: rij rechtsboven: RUN direct links van MENU, op één hoogte", r.end.x <= m.position.x and absf(r.get_center().y - m.get_center().y) < 1.0
			and m.position.y < vs.y * 0.15 and m.end.x > vs.x * 0.85)
	var k: Rect2 = t.kern_rect()
	check("B: KERN boven A, rechts uitgelijnd", k.end.y < t.a_center().y - t.button_radius and absf(k.end.x - (t.a_center().x + t.button_radius)) < 1.0)
	check("B: A/B rechtsonder", t.a_center().x > vs.x * 0.75 and t.a_center().y > vs.y * 0.6 and t.b_center().x < t.a_center().x)
	var rects: Array = t.button_rects()
	var overlap := false
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				overlap = true
	check("B: %d knoppen, geen overlap" % rects.size(), rects.size() == 6 and not overlap)
	t.analog_only = true
	check("B: Action-arena: RUN schuift naar slot 2 (links van Swap/Ring)", t.run_rect().end.x <= t.som_row_slot(1).position.x)
	layer.queue_free()
	await get_tree().process_frame


func _stick_tests() -> void:
	check("C: dode zone: kleine uitslag doet niets", TC.stick_actions(Vector2(0.1, 0.05)) == ["", ""])
	check("C: rechts -> move_right + ui_right", TC.stick_actions(Vector2(0.9, 0.2)) == ["move_right", "ui_right"])
	check("C: links -> move_left + ui_left", TC.stick_actions(Vector2(-0.5, 0.1)) == ["move_left", "ui_left"])
	check("C: omhoog -> move_up + ui_up", TC.stick_actions(Vector2(0.2, -0.6)) == ["move_up", "ui_up"])
	check("C: schuin omlaag (y overheerst) -> move_down", TC.stick_actions(Vector2(0.6, 0.7)) == ["move_down", "ui_down"])


func scene() -> Node:
	return get_tree().current_scene


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 8.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _close_dialogs() -> void:
	var t0 := Time.get_ticks_msec()
	while Dialog.is_open and Time.get_ticks_msec() - t0 < 8000:
		Input.action_press("interact")
		await pframes(2)
		Input.action_release("interact")
		await pframes(4)


func _touch() -> Control:
	return scene().get_node_or_null("TouchControls/Control") as Control if scene() else null


## Echte aanraking op de joystick (schermcoördinaten), vinger 'idx'.
func _stick(t: Control, local: Vector2, pressed: bool, idx := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.pressed = pressed
	ev.position = t.get_global_transform_with_canvas() * local
	t._input(ev)      # viewport-coördinaten, zoals _input ze krijgt (parse_input_event zou nog door de vensterschaal gaan)
	await pframes(2)


func _game_tests() -> void:
	for s in SCENES:
		GameState.change_map(s[1], s[2])
		var ok := await wait_until(func(): return scene() != null and scene().scene_file_path == s[1] and not GameState.changing_map, 15.0)
		await pframes(20)
		await _close_dialogs()
		await pframes(10)
		var t := _touch()
		check("D %s: geladen met knoppen" % s[0], ok and t != null)
		if t == null:
			continue
		check("D %s: joystick + rij [RUN][MENU] zichtbaar, geen D-pad" % s[0],
				t.is_visible_in_tree() and t.joystick_mode and t.show_menu and t.show_run)
		await _screenshot(s[0])
		if s[0] == "veld":
			await _grid_walk(t)
			await _menu(t)
	await _classic_battle()


func _grid_walk(t: Control) -> void:
	var p: Node2D = scene().get_node_or_null("Objects/Player")
	if p == null:
		check("D veld: speler gevonden", false)
		return
	var start := p.position
	# dode zone: een tikje naast het midden laat de speler staan
	await _stick(t, t.stick_center() + Vector2(t.joy_radius() * 0.1, 0), true)
	await pframes(20)
	await _stick(t, t.stick_center(), false)
	check("D veld: tik binnen de dode zone = blijft staan", p.position == start)
	var best := Vector2.ZERO
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var from := p.position
		await _stick(t, t.stick_center() + dir * t.joy_radius(), true)
		await pframes(25)
		await _stick(t, t.stick_center(), false)
		await wait_until(func(): return not p.is_moving, 3.0)
		await pframes(4)
		var moved := p.position - from
		if moved.length() > best.length():
			best = moved
		if moved != Vector2.ZERO:
			check("D veld: joystick %s -> %s, hele tegels in die richting" % [dir, moved],
					is_equal_approx(fmod(absf(moved.x) + absf(moved.y), 16.0), 0.0) and moved.normalized().is_equal_approx(dir))
	check("D veld: rasterlopen met de joystick verplaatst de speler", best.length() >= 16.0)
	check("D veld: losgelaten = geen move_* meer ingedrukt", not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left")
			and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"))


func _menu(t: Control) -> void:
	# MENU-knop in de rij (echte tik)
	var ev := InputEventScreenTouch.new()
	ev.index = 3
	ev.pressed = true
	ev.position = t.get_global_transform_with_canvas() * t.menu_rect().get_center()
	t._input(ev)
	await pframes(3)
	ev = ev.duplicate()
	ev.pressed = false
	t._input(ev)
	var open := await wait_until(func(): return scene().has_method("menu_open") and scene().menu_open(), 3.0)
	check("D menu: MENU-knop in de rij opent het veldmenu", open)
	await pframes(15)
	await _screenshot("menu")
	Input.action_press("cancel")
	await pframes(3)
	Input.action_release("cancel")
	await wait_until(func(): return not scene().menu_open(), 3.0)
	await pframes(5)


func _classic_battle() -> void:
	var p: Node = scene().get_node_or_null("Objects/Player")
	if p == null:
		check("D classic: speler voor gevecht", false)
		return
	GameState.start_battle(["mosslijm"], p.get_tile(), p.facing, "gras")
	var ok := await wait_until(func(): return scene() != null and scene().name == "Battle", 10.0)
	await pframes(60)
	var t := _touch()
	check("D classic: gevecht met joystick (geen D-pad)", ok and t != null and t.joystick_mode)
	if t == null:
		return
	# flick omlaag: joystick zet ui_down aan (menu-cursor), loslaten zet het uit
	await _stick(t, t.stick_center() + Vector2(0, t.joy_radius()), true, 1)
	var down := Input.is_action_pressed("ui_down") and Input.is_action_pressed("move_down")
	await _stick(t, t.stick_center(), false, 1)
	check("D classic: joystick-flick omlaag = ui_down/move_down (menu-cursor), los = uit", down and not Input.is_action_pressed("ui_down"))
	await _screenshot("classic_gevecht")


func _screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	var big := img.duplicate()
	big.resize(1152, 648, Image.INTERPOLATE_NEAREST)
	big.save_png(shots.path_join(name + "_3x.png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"))
