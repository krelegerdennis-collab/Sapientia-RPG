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
	["wereldkaart", "res://scenes/maps/wereldkaart.tscn", "van_archief"],
]
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const CodexScreen := preload("res://scripts/ui/codex_screen.gd")
const Cutscene := preload("res://scripts/worldmap_cutscene.gd")

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
	print("=== Deel E: leider-behoud (Action SWAP) ===")
	await _leider_tests()
	print("=== Deel F: modus-direct (Classic<->Action meteen) ===")
	await _modus_direct_tests()
	print("=== Deel G: Codex vangen in Action ===")
	await _codex_tests()
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
	check("B: RUN zelfde hoogte als MENU (%.0f = %.0f) en zelfde stijl (top_style, uit en ingedrukt)" % [r.size.y, m.size.y],
			is_equal_approx(r.size.y, m.size.y) and TC.top_style(false)["text"] == TC.top_style(false)["text"]
			and FileAccess.get_file_as_string("res://scripts/touch_controls.gd").count("top_style(_press_count.has(") == 2)
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
	# echte invoer via de wachtrij (vensterschaal erbij, zoals debug_autotest): komt vóór _process binnen
	ev.position = get_tree().root.get_final_transform() * (t.get_global_transform_with_canvas() * local)
	Input.parse_input_event(ev)
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
			await _keuzes(t)
			await _scherm(t, "winkel", _maak_winkel)
			await _scherm(t, "codex", func(): return CodexScreen.new())
			await _cutscene(t)
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


## Dialoogkeuzes: joystick + A/B blijven, flick = één stap, vasthouden herhaalt (lange lijst).
func _keuzes(t: Control) -> void:
	var opties: Array = []
	for i in 8:
		opties.append("Keuze %d" % (i + 1))
	Dialog.ask("Welke?", opties)
	var open := await wait_until(func(): return Dialog.has_choices() and not Dialog._is_typing(), 5.0)
	await pframes(10)
	check("D keuzes: dialoogkeuze open met joystick zichtbaar", open and t.is_visible_in_tree() and t.joystick_mode)
	var i0: int = Dialog.choice_index
	await _stick(t, t.stick_center() + Vector2(0, t.joy_radius()), true, 2)
	await pframes(3)
	await _stick(t, t.stick_center(), false, 2)
	check("D keuzes: één flick omlaag = één stap (%d -> %d)" % [i0, Dialog.choice_index], Dialog.choice_index == (i0 + 1) % 8)
	await _screenshot("dialoogkeuze")
	var i1: int = Dialog.choice_index
	var r0: int = t.repeat_count
	await _stick(t, t.stick_center() + Vector2(0, t.joy_radius()), true, 2)
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(0.3).timeout
	var na_kort: int = Dialog.choice_index
	await get_tree().create_timer(0.45).timeout
	var stappen: int = (Dialog.choice_index - i1 + 8) % 8
	var ms := Time.get_ticks_msec() - t0
	await _stick(t, t.stick_center(), false, 2)
	var na_los: int = Dialog.choice_index
	await get_tree().create_timer(0.3).timeout
	check("D keuzes: vasthouden: eerst 1 stap, pas na %.2f s herhalen (na 0.3 s: %d stap)" % [t.STICK_REPEAT_DELAY, (na_kort - i1 + 8) % 8], (na_kort - i1 + 8) % 8 == 1)
	check("D keuzes: vasthouden %d ms herhaalt (%d stappen, %d herhalingen, tempo %.2f s)" % [ms, stappen, t.repeat_count - r0, t.STICK_REPEAT_RATE],
			stappen >= 3 and t.repeat_count - r0 >= 2)
	check("D keuzes: loslaten stopt het herhalen", Dialog.choice_index == na_los)
	Dialog.choose(0)
	await pframes(5)


func _maak_winkel() -> Node:
	var w := ShopScreen.new()
	w.name = "ShopScreen"
	w.shop_id = "wilgendal_wapen"
	return w


## Schermvullende schermen (winkel, codex): je tikt direct op het scherm; joystick/A/B/rij gaan weg
## (anders eet de onzichtbare joystick onder het venster tikken op de linkerkolom) en komen terug bij sluiten.
func _scherm(t: Control, naam: String, maak: Callable) -> void:
	var w: Node = maak.call()
	scene().add_child(w)
	await pframes(10)
	check("D %s: open, knoppenlaag weg (geen verborgen joystick onder het venster)" % naam, is_instance_valid(w) and not t.visible)
	var held := false
	for a in ["move_left", "move_right", "move_up", "move_down", "interact", "cancel", "ui_down", "ui_up"]:
		held = held or Input.is_action_pressed(a)
	check("D %s: geen knop blijft ingedrukt hangen" % naam, not held)
	await _screenshot(naam)
	if w.has_method("back"):
		w.back()
	if is_instance_valid(w):
		w.queue_free()
	var terug := await wait_until(func(): return t.visible, 3.0)
	check("D %s: dicht -> joystick + rij terug" % naam, terug and t.show_menu)


## Filmpje (wereldkaart): knoppen weg, tik slaat over, daarna joystick + rij terug.
func _cutscene(t: Control) -> void:
	var c: Node = Cutscene.start_on(scene())
	await pframes(10)
	check("D cutscene: filmpje speelt, knoppenlaag weg", is_instance_valid(c) and not c.is_done() and not t.visible)
	await get_tree().create_timer(float(c.SKIP_GRACE) + 0.1).timeout
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(100, 100)
	c._input(ev)
	var klaar := await wait_until(func(): return not is_instance_valid(c) or c.is_done(), 3.0)
	await pframes(10)
	var terug := await wait_until(func(): return t.visible, 3.0)
	check("D cutscene: tik slaat over, joystick terug", klaar and terug)
	var p: Node = scene().get_node_or_null("Objects/Player")
	if p and "input_locked" in p:
		await wait_until(func(): return not p.input_locked, 3.0)


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
	for i in 10:
		if not scene().menu_open():
			break
		Input.action_press("cancel")
		await pframes(3)
		Input.action_release("cancel")
		await pframes(10)
	await pframes(5)
	check("D menu: dicht -> joystick + rij terug", not scene().menu_open() and t.is_visible_in_tree() and t.show_menu)


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
	var r0: int = t.repeat_count
	await _stick(t, t.stick_center() + Vector2(0, t.joy_radius()), true, 1)
	await get_tree().create_timer(0.7).timeout
	await _stick(t, t.stick_center(), false, 1)
	check("D classic: vasthouden in het gevechtsmenu herhaalt (%d)" % (t.repeat_count - r0), t.repeat_count - r0 >= 2)
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


## Naar een kamer en wachten tot hij klaar is; geeft de Action-arena (of null in Classic).
func _naar(pad: String, spawn: String) -> Node:
	GameState.in_battle = false
	GameState.change_map(pad, spawn)
	await wait_until(func(): return scene() != null and scene().scene_file_path == pad and not GameState.changing_map, 15.0)
	await pframes(20)
	await _close_dialogs()
	return scene().get("som") if scene() and "som" in scene() else null


## Bug Dennis: met SWAP een andere held kiezen en door een warp lopen = weer Dax. De gekozen leider moet blijven
## over warps, opslaan/laden en Classic<->Action; terugval naar Dax bij KO of niet (meer) in de party.
func _leider_tests() -> void:
	const V1 := "res://scenes/maps/archief_v1_gang.tscn"
	const V2 := "res://scenes/maps/archief_v2_kastenzaal.tscn"
	var stijl: int = int(Settings.get_value("battle_style"))
	GameState.new_game("Dax")
	GameState.add_member("noor")
	GameState.add_member("lotte")
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	check("E: nieuw spel: leider = Dax", GameState.leader_id == GameState.MAIN_HERO)
	var a: Node = await _naar(V1, "zuid")
	check("E: Action-arena in archief_v1_gang, Dax bestuurd", a != null and a.active_id == "dennis")
	if a == null:
		Settings.set_value("battle_style", stijl)
		return
	var nu: String = a.switch_hero("noor")
	check("E: SWAP naar Vesper (noor) zet de leider", nu == "noor" and a.active_id == "noor" and GameState.leader_id == "noor")
	# warp naar de volgende kamer
	a = await _naar(V2, "ladder")
	check("E: na warp naar archief_v2_kastenzaal nog steeds Vesper bestuurd (%s)" % (a.active_id if a else "-"), a != null and a.active_id == "noor")
	check("E: na de warp loopt Dax mee als bondgenoot", a != null and a.ally_of("dennis") != null and a.ally_of("noor") == null)
	# en weer terug (kamerwissel de andere kant op)
	a = await _naar(V1, "zuid")
	check("E: terug naar archief_v1_gang: nog steeds Vesper", a != null and a.active_id == "noor")
	# opslaan / laden
	var d: Dictionary = GameState.state_data(Vector2i(5, 5), Vector2i.DOWN, V1)
	check("E: save bevat leader = noor", str(d.get("leader", "")) == "noor")
	GameState.set_leader(GameState.MAIN_HERO)
	check("E: laden zet de leider terug (noor)", GameState.apply_state(d.duplicate(true)) and GameState.leader_id == "noor")
	var oud := d.duplicate(true)
	oud.erase("leader")
	check("E: oude save zonder 'leader' = Dax", GameState.apply_state(oud) and GameState.leader_id == GameState.MAIN_HERO)
	GameState.apply_state(d.duplicate(true))
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	a = await _naar(V1, "zuid")
	check("E: na laden + kamer: Vesper bestuurd", a != null and a.active_id == "noor")
	# Classic <-> Action
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	a = await _naar(V2, "ladder")
	check("E: Classic: geen arena, leider blijft bewaard (noor)", a == null and GameState.leader_id == "noor")
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	a = await _naar(V1, "zuid")
	check("E: terug naar Action: Vesper bestuurd", a != null and a.active_id == "noor")
	# terugval: KO
	GameState.member("noor")["hp"] = 0
	check("E: KO-leider -> active_leader() = Dax", GameState.active_leader() == GameState.MAIN_HERO)
	a = await _naar(V2, "ladder")
	check("E: KO-leider: na warp Dax bestuurd", a != null and a.active_id == "dennis")
	GameState.member("noor")["hp"] = int(GameState.member("noor").get("max_hp", 10))
	# terugval: niet (meer) in de party
	GameState.set_leader("seren")
	check("E: leider niet in de party -> Dax", not GameState.has_member("seren") and GameState.active_leader() == GameState.MAIN_HERO)
	GameState.set_leader("noor")
	var noor: Dictionary = GameState.member("noor")
	GameState.party.erase(noor)
	a = await _naar(V1, "zuid")
	check("E: leider uit de party gehaald: na warp Dax bestuurd", a != null and a.active_id == "dennis")
	Settings.set_value("battle_style", stijl)


## Wacht op een herbouwde kamer (zelfde pad) na reload_room; geeft de nieuwe scène.
func _wacht_reload(oud: Node) -> Node:
	await wait_until(func(): return scene() != null and scene() != oud and not GameState.changing_map and scene().is_node_ready(), 8.0)
	await pframes(10)
	return scene()


## Battle Style in de Opties geldt meteen in de huidige kamer (niet pas na een kamerwissel); de leider blijft (#161),
## de speler blijft op zijn tile en verslagen monsters blijven weg.
func _modus_direct_tests() -> void:
	const V1 := "res://scenes/maps/archief_v1_gang.tscn"
	var stijl: int = int(Settings.get_value("battle_style"))
	GameState.new_game("Dax")
	GameState.add_member("noor")
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var a: Node = await _naar(V1, "zuid")
	if a == null:
		check("F: Action-arena", false)
		Settings.set_value("battle_style", stijl)
		return
	a.switch_hero("noor")
	var s0 := scene()
	var tile0: Vector2i = s0.player.get_tile()
	var weg := ""
	for m in s0.monsters:
		if is_instance_valid(m) and not m.boss:
			weg = str(m.monster_id)
			a.damage_enemy(m, 9999, Vector2i.DOWN)
			break
	await pframes(30)
	check("F: monster %s verslagen in Action" % weg, weg != "" and GameState.defeated_map_monsters.get(s0.room_id, {}).has(weg))
	# Action -> Classic, rechtstreeks (zoals de Opties doen: Settings.set_value)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	var s1 := await _wacht_reload(s0)
	check("F: Classic meteen: kamer herbouwd zonder arena", s1 != s0 and s1.scene_file_path == V1 and s1.get("som") == null)
	check("F: zelfde tile (%s -> %s)" % [tile0, s1.player.get_tile() if s1 else Vector2i(-1, -1)], s1 != null and s1.player.get_tile() == tile0)
	var nog := false
	for m in s1.monsters:
		nog = nog or str(m.monster_id) == weg
	check("F: verslagen monster blijft weg", not nog)
	check("F: leider blijft Vesper (noor) in Classic", GameState.leader_id == "noor")
	var touch := s1.get_node_or_null("TouchControls/Control")
	check("F: Classic: joystick zonder analog_only (rasterlopen)", touch != null and not touch.analog_only)
	# Classic -> Action via het veldmenu: pas bij sluiten
	s1.open_field_menu()
	await pframes(10)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	await pframes(10)
	check("F: met open menu nog niet herbouwd", scene() == s1 and s1.menu_open())
	var fm := s1.get_node_or_null("FieldMenu")
	if fm:
		fm.close()
	var s2 := await _wacht_reload(s1)
	var a2: Node = s2.get("som") if s2 else null
	check("F: menu dicht -> Action meteen, Vesper bestuurd", s2 != s1 and a2 != null and a2.active_id == "noor")
	check("F: zelfde tile na terug naar Action", s2 != null and s2.player.get_tile() == tile0)
	# zelfde stijl opnieuw zetten = niets herbouwen
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	await pframes(30)
	check("F: zelfde stijl = geen herbouw", scene() == s2 and not GameState.changing_map)
	Settings.set_value("battle_style", stijl)
	await pframes(30)
	await wait_until(func(): return not GameState.changing_map, 8.0)

# ---------------------------------------------------------------- Deel G: Codex vangen in Action
const CodexDataT := preload("res://scripts/data/codex_data.gd")


## Echte tik (muis = touch-emulatie) midden op een HUD-knop.
func _tik(b: Control) -> void:
	var c: Vector2 = b.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = c
		ev.global_position = c
		get_viewport().push_input(ev, true)
		await pframes(2)


## Een geregistreerde arena-vijand als Mosslijm (vangbare Codex-soort) vlak naast de speler.
func _vangbaar(a: Node) -> Node:
	for m in a.enemies.keys():
		if is_instance_valid(m):
			m.enemy_id = "mosslijm"
			var p: Node = a.player
			m.place_at(p.get_tile() + Vector2i(1, 0), Vector2i.LEFT)
			a.enemies[m]["data"]["name"] = "Moss Slime"
			return m
	return null


func _codex_tests() -> void:
	const V1 := "res://scenes/maps/archief_v1_gang.tscn"
	var stijl: int = int(Settings.get_value("battle_style"))
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	var boek: String = CodexDataT.BOOK_ITEM
	GameState.inventory[boek] = 5
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var a: Node = await _naar(V1, "zuid")
	check("G: Action-arena met Codex-module", a != null and a.codex != null)
	if a == null:
		Settings.set_value("battle_style", stijl)
		return
	var dax_pad: String = KaartStijl.speler_sheet("wilgendal")
	check("G: Action-arena gebruikt Dax' sheet via KaartStijl.speler_sheet() (%s), niet de oude dax_wm1_slim" % dax_pad.get_file(),
			dax_pad != "" and a.dax_sheet_path() == dax_pad and a.sheet_for("dennis") != null
			and a.sheet_for("dennis").resource_path == dax_pad and not dax_pad.ends_with("dax_wm1_slim.png"))
	var hud: Node = a.hud
	var cb: Button = hud.codex_button
	await pframes(3)
	check("G: CODEX-knop in de HUD-rij, zichtbaar, art btn_codex (38x14)", cb != null and cb.is_visible_in_tree()
			and str(cb.get_meta("som_skin", "")) == "codex" and cb.size == SomData_TOP())
	var rr: Rect2 = hud.ring_button.get_global_rect()
	var cr: Rect2 = cb.get_global_rect()
	var sr: Rect2 = hud.switch_button.get_global_rect()
	check("G: rij [RUN][Swap][Codex][Ring][MENU]: Codex direct naast Ring, één hoogte, geen overlap",
			cr.end.x <= rr.position.x and rr.position.x - cr.end.x < 6.0 and absf(cr.get_center().y - rr.get_center().y) < 1.0
			and sr.end.x <= cr.position.x and not cr.intersects(rr) and not cr.intersects(sr)
			and _touch().run_rect().end.x <= sr.position.x + 0.5)
	await _screenshot("hud_codex_knop")
	# --- tik: vangt de dichtstbijzijnde (geseed: gelukt)
	var m: Node = _vangbaar(a)
	check("G: testmonster in de arena", m != null)
	if m == null:
		Settings.set_value("battle_style", stijl)
		return
	await _close_dialogs()
	var actief := await wait_until(func(): return a.active(), 6.0)
	if not actief:
		var r: Node = scene()
		print("INFO  arena niet actief: grace=%s battle=%s dialog=%s menu=%s story=%s lock=%s" % [r.get("_grace_left"), GameState.in_battle,
				Dialog.is_open, r.menu_open(), Story.running, r.get("_touch_lock")])
	check("G: arena actief (monsters bewegen)", actief)
	var n0: int = GameState.codex_pages.size()
	a.codex.force_roll = 0.0
	await _tik(cb)
	print("INFO  na tik: active=%s result=%s" % [a.active(), a.codex.last_capture])
	check("G: tik op CODEX = vangpoging op het dichtstbijzijnde monster (%s)" % str(a.codex.last_capture.get("result", "")),
			str(a.codex.last_capture.get("result", "")) == "gelukt")
	check("G: gelukt: pagina in de Codex (Mosslijm), Leeg Boek -1, monster uit de arena",
			GameState.codex_pages.size() == n0 + 1 and str(GameState.codex_pages.back()["species"] if not GameState.codex_pages.is_empty() else "") == "mosslijm"
			and GameState.item_count(boek) == 4 and not a.enemies.has(m))
	check("G: Engelse melding als Classic", str(a.codex.last_capture.get("text", "")).begins_with("Moss Slime is written into the Codex!"))
	check("G: niveau/gegevens als Classic (capture_level, tier, play_time)", not GameState.codex_pages.is_empty() and int(GameState.codex_pages.back()["level"]) == CodexDataT.capture_level(int(scene().tier()), "mosslijm")
			and GameState.defeated_map_monsters.get(str(scene().room_id), {}).has(str(m.monster_id)))
	# effect speelt: 6 frames, midden op het monster
	var fx: Node = a.codex.fx_node
	check("G: codex_capture_fx speelt (6 frames van 48x48)", fx != null and fx is Sprite2D and (fx as Sprite2D).hframes == 6
			and (fx as Sprite2D).texture != null and (fx as Sprite2D).texture.get_size() == Vector2(288, 48))
	await pframes(4)
	await _screenshot("vang_effect")
	# --- geen dubbele vangst: tijdens het effect nog eens
	var b0: int = GameState.item_count(boek)
	var p0: int = GameState.codex_pages.size()
	a.codex.capture(m)
	check("G: geen dubbele vangst tijdens het effect (boek en pagina's gelijk)", str(a.codex.last_capture.get("result", "")) == "bezig"
			and GameState.item_count(boek) == b0 and GameState.codex_pages.size() == p0)
	await wait_until(func(): return not a.codex.busy, 3.0)
	await pframes(3)
	check("G: na het effect is het monster weg (vrijgegeven)", not is_instance_valid(m))
	# --- mislukt (geseed)
	var m2: Node = _vangbaar(a)
	if m2 == null:
		check("G: tweede testmonster", false)
	else:
		a.codex.force_roll = 0.999
		var hp: int = int(a.enemies[m2]["hp"])
		var txt: String = a.codex.capture(m2)
		check("G: mislukt (geseed): boek weg, geen pagina, monster blijft met zelfde HP",
				str(a.codex.last_capture.get("result", "")) == "mislukt" and GameState.item_count(boek) == b0 - 1
				and GameState.codex_pages.size() == p0 and a.enemies.has(m2) and int(a.enemies[m2]["hp"]) == hp)
		check("G: mislukt-melding als Classic", txt.begins_with("The book stays blank... Moss Slime slips out! (chance "))
		await wait_until(func(): return not a.codex.busy, 3.0)
		check("G: na mislukken weer zichtbaar", is_instance_valid(m2) and m2.modulate.a > 0.99)
		# --- ring: Codex-boek (icoon 8 van ring_icons_9), doelkeuze met hint, vangen
		a.codex.force_roll = 0.0
		a.open_ring()
		a.ring.set_tab("items")
		await pframes(2)
		var idx := -1
		for i in a.ring.entries.size():
			if str(a.ring.entries[i].get("kind", "")) == "codex":
				idx = i
		var ic: AtlasTexture = a.ring.icon_for({"kind": "codex", "id": "codex"}) as AtlasTexture
		check("G: ring: Codex-boek in Items, icoon index 8 van ring_icons_9 (x=128)", idx >= 0 and ic != null
				and ic.region == Rect2(128, 0, 16, 16) and ic.atlas.get_size() == Vector2(144, 16))
		a.ring.selected = maxi(idx, 0)
		a.ring._highlight()
		await _screenshot("ring_codex")
		a.ring.choose(idx)
		await pframes(2)
		var doel: Array = a.ring.entries
		check("G: ring: Codex vraagt een doel, met Classic-hint (%s)" % (str(doel[0].get("label", "")) if not doel.is_empty() else "-"),
				a.ring.tab == "target" and not doel.is_empty() and doel[0]["target"] == m2 and str(doel[0]["label"]).ends_with("%"))
		await _screenshot("ring_codex_doel")
		a.ring.choose(0)
		var klaar := await wait_until(func(): return str(a.codex.last_capture.get("result", "")) == "gelukt", 3.0)
		check("G: ring: gekozen doel gevangen", klaar and GameState.codex_pages.size() == p0 + 1 and not a.enemies.has(m2))
		await wait_until(func(): return not a.codex.busy, 3.0)
	# --- baas: nooit te vangen, boek blijft
	var bm: Node = null
	for x in a.enemies.keys():
		if is_instance_valid(x):
			bm = x
	if bm == null:
		check("G: baas-testmonster", false)
	else:
		bm.boss = true
		a.enemies.erase(bm)          # zoals register(): een baas zit niet in de arena-lijst
		a.codex.force_roll = 0.0
		var bb: int = GameState.item_count(boek)
		var pp: int = GameState.codex_pages.size()
		var bt: String = a.codex.capture(bm)
		check("G: baas: weigert ('too strong'), boek blijft, geen pagina", str(a.codex.last_capture.get("result", "")) == "baas"
				and bt.contains("is too strong! A boss won't be written in.") and GameState.item_count(boek) == bb and GameState.codex_pages.size() == pp)
		check("G: baas-hint = too strong", a.codex.hint(bm) == "too strong")
	# --- geen boek
	GameState.inventory[boek] = 0
	check("G: zonder Leeg Boek: melding, niets gevangen", a.codex.capture() == "No Blank Book left.")
	# --- opslaan en laden: de gevangen pagina's
	var pages_voor: Array = GameState.codex_pages.map(func(p): return [str(p["uid"]), str(p["species"]), int(p["level"])])
	var d: Dictionary = GameState.state_data(Vector2i(5, 5), Vector2i.DOWN, V1)
	GameState.codex_pages = []
	var geladen := GameState.apply_state(JSON.parse_string(JSON.stringify(d)))
	var pages_na: Array = GameState.codex_pages.map(func(p): return [str(p["uid"]), str(p["species"]), int(p["level"])])
	check("G: opslaan/laden: Codex-pagina's uit Action blijven (%d)" % pages_na.size(), geladen and pages_na == pages_voor and pages_na.size() >= 2)
	a.codex.force_roll = -1.0
	Settings.set_value("battle_style", stijl)


func SomData_TOP() -> Vector2:
	return preload("res://scripts/data/som_data.gd").TOP_BUTTON_SIZE
