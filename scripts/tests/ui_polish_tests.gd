extends Node
## UI-polijst WM1 (touch + veilig gebied + leesbaarheid). Draait de echte schermen (veldmenu, Items, Codex,
## winkel, tekstvak, touch-HUD, commandokruis, co-op lobby) in vijf viewportprofielen:
## 16:9 (384x216), 19,5:9 (468x216), 19,5:9 met gesimuleerde punch-hole, 21:9 en 4:3 'hoog' (384x288).
## Per profiel: tikvlakken >= 25 eenheden (~48 dp op een telefoon in landschap), niets buiten het veilige
## gebied of het beeld, geen afgekapte knoptekst, geen ontbrekende lettertekens, B/Cancel sluit of gaat terug.
## Start: godot --path . -- --uipolishtest [--shots=/pad/map]
## Hulp: tools/ui_polish/ui_scenarios.gd (zelfde scenario's als de screenshot-tool --uishots).

const Scenarios := preload("res://tools/ui_polish/ui_scenarios.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const CoopLobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")

const SUB_SCREENS: Array[String] = ["menu_items", "menu_equipment", "menu_magic", "menu_status", "menu_codex",
		"menu_bestiary", "menu_party", "menu_quests", "menu_options", "menu_save"]
const MIN_FONT := 10

var failures := 0
var passes := 0
var shots := ""
var sc: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	sc = Scenarios.new()
	add_child(sc)
	sc.shots_dir = shots
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await sc.wait_scene("Title")
	await sc.pframes(10)
	_unit_tests()
	check("spel start in Wilgendal", await sc.start_game())
	for p in Scenarios.PROFILES.keys():
		await sc.set_profile(p)
		var tag := "[%s] " % p
		await _hud_tests(tag)
		await _dialog_tests(tag)
		await _field_menu_tests(tag)
		await _sub_screen_tests(tag)
		await _shop_tests(tag)
		await _codex_tests(tag)
		await _lobby_tests(tag)
		await _battle_tests(tag)
	print("UIPOLISHTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- hulpjes
func _vp() -> Vector2:
	return sc.viewport_size()


func _safe(scale := 1.0) -> Rect2:
	var vp := _vp() / scale
	var i := UiTouchC.insets(get_viewport()) / scale
	return Rect2(Vector2(i.x, i.y), vp - Vector2(i.x + i.z, i.y + i.w))


func _within(r: Rect2, bounds: Rect2) -> bool:
	return r.position.x >= bounds.position.x - 0.5 and r.position.y >= bounds.position.y - 0.5 \
			and r.end.x <= bounds.end.x + 0.5 and r.end.y <= bounds.end.y + 0.5


## Zichtbare Label/Button-nodes met tekst (niet in een ScrollContainer: die knipt bewust).
func _text_nodes(root: Node, out: Array[Control] = []) -> Array[Control]:
	for c in root.get_children():
		if c is ScrollContainer:
			continue
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if (c is Label or c is Button) and str(c.get("text")).strip_edges() != "":
			out.append(c)
		_text_nodes(c, out)
	return out


func _offscreen(root: Node, bounds: Rect2) -> Array[String]:
	var bad: Array[String] = []
	for c in _text_nodes(root):
		if not _within(c.get_global_rect(), bounds):
			bad.append("%s '%s' %s" % [c.name, str(c.get("text")).strip_edges(), c.get_global_rect()])
	return bad


## Tekens waarvoor het pixelfont geen glyph heeft (die zie je als gat of dubbele punt).
func _missing_glyphs(root: Node) -> Array[String]:
	var bad: Array[String] = []
	for c in _text_nodes(root):
		var font: Font = c.get_theme_font("font")
		for ch in str(c.get("text")):
			var code := ch.unicode_at(0)
			if code <= 32 or font.has_char(code):
				continue
			bad.append("U+%04X in '%s'" % [code, str(c.get("text")).strip_edges()])
			break
	return bad


## Past de tekst van een knop in zijn eigen vak (niet afgekapt)?
func _button_clipped(b: Button) -> bool:
	var font: Font = b.get_theme_font("font")
	var fs := b.get_theme_font_size("font_size")
	var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w > b.size.x + 0.5


func _event_action(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await sc.pframes(2)


func _mouse(pos := Vector2.ZERO) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	return ev


# ---------------------------------------------------------------- unit
func _unit_tests() -> void:
	check("tikmaat: 25 eenheden = >= 47 dp op een telefoon van 411 dp hoog", UiTouchC.TOUCH_MIN * 411.0 / 216.0 >= 47.0)
	var r := UiTouchC.hit_rect(Rect2(10, 10, 38, 14), 4.0)
	check("hit_rect: klein vlak groeit naar >= 25 hoog met hetzelfde midden",
			r.size.y >= 25.0 and r.size.x >= 38.0 and r.get_center().is_equal_approx(Vector2(29, 17)))
	check("hit_rect: groot vlak blijft (alleen extra marge)", UiTouchC.hit_rect(Rect2(0, 0, 60, 30), 2.0).size == Vector2(64, 34))
	check("big_enough herkent te kleine vlakken", UiTouchC.big_enough(Rect2(0, 0, 25, 25)) and not UiTouchC.big_enough(Rect2(0, 0, 40, 16)))
	UiTouchC.insets_override = Vector4(500, -3, 12, 4)
	var i := UiTouchC.insets(get_viewport())
	check("insets: override wordt begrensd (0..%d)" % int(UiTouchC.INSET_MAX), i == Vector4(UiTouchC.INSET_MAX, 0, 12, 4))
	UiTouchC.insets_override = null
	check("insets: zonder override op desktop/headless nul of klein",
			UiTouchC.insets(get_viewport()).length() <= UiTouchC.INSET_MAX * 2.0)
	var lobby_h := CoopLobbyScreen.touch_min_height_px()
	check("lobby: touch_min_height_px = tikmaat (%d)" % lobby_h, lobby_h >= int(UiTouchC.TOUCH_MIN))


# ---------------------------------------------------------------- HUD (joystick, A/B, MENU/RUN)
func _hud_tests(tag: String) -> void:
	await sc.open("hud")
	var touch: Control = sc.scene().get_node("TouchControls/Control")
	touch.show_menu = true
	touch.show_run = true
	touch.refit()
	await sc.pframes(2)
	var safe := _safe()
	var stick := Rect2(touch.stick_center() - Vector2.ONE * touch.joy_radius(), Vector2.ONE * touch.joy_radius() * 2.0)
	var a := Rect2(touch.a_center() - Vector2.ONE * touch.button_radius, Vector2.ONE * touch.button_radius * 2.0)
	var b := Rect2(touch.b_center() - Vector2.ONE * touch.button_radius, Vector2.ONE * touch.button_radius * 2.0)
	check(tag + "HUD: joystick, A en B binnen het veilige gebied", _within(stick, safe) and _within(a, safe) and _within(b, safe))
	check(tag + "HUD: MENU en RUN binnen het veilige gebied", _within(touch.menu_rect(), safe) and _within(touch.run_rect(), safe))
	check(tag + "HUD: A en B zijn groot genoeg (>= 25)", UiTouchC.big_enough(a.grow(touch.button_radius * 0.25))
			and UiTouchC.big_enough(b.grow(touch.button_radius * 0.25)))
	var menu_hit := UiTouchC.hit_rect(touch.menu_rect(), 4.0)
	var run_hit := UiTouchC.hit_rect(touch.run_rect(), 2.0)
	check(tag + "HUD: tikvlak MENU (%s) en RUN (%s) >= 25 hoog" % [menu_hit.size, run_hit.size],
			UiTouchC.big_enough(menu_hit) and UiTouchC.big_enough(run_hit))
	check(tag + "HUD: tikvlakken van MENU en RUN overlappen de joystick, A of B niet",
			not menu_hit.intersects(stick) and not run_hit.intersects(stick) and not menu_hit.intersects(a) and not run_hit.intersects(b))
	# tik net onder het zichtbare MENU-vlak: telt toch als MENU
	var xf: Transform2D = touch.get_global_transform_with_canvas()
	var below: Vector2 = touch.menu_rect().get_center() + Vector2(0, touch.menu_rect().size.y / 2.0 + 4.0)
	var ev := InputEventScreenTouch.new()
	ev.index = 9
	ev.pressed = true
	ev.position = xf * below
	touch._input(ev)
	check(tag + "HUD: tik 4 eenheden onder het MENU-vlak telt als MENU", touch._touch_owner.get(9, "") == "menu")
	ev = ev.duplicate()
	ev.pressed = false
	touch._input(ev)
	touch.release_all()
	touch.show_menu = false
	touch.show_run = false


# ---------------------------------------------------------------- tekstvak
func _dialog_tests(tag: String) -> void:
	await sc.open("dialog_narrator")
	var safe := _safe()
	check(tag + "tekstvak: vak (%s) binnen het veilige gebied" % Dialog.box_rect(), _within(Dialog.box_rect(), safe))
	await sc.close_all()
	await sc.open("dialog_choices")
	var rects: Array[Rect2] = Dialog.choice_rects()
	check(tag + "tekstvak: 3 keuzeregels", rects.size() == 3)
	var tall := true
	for r in rects:
		tall = tall and r.size.y >= UiTouchC.TOUCH_MIN - 0.01 and r.size.x >= UiTouchC.TOUCH_MIN
	check(tag + "tekstvak: elke keuzeregel >= 25 hoog (%s)" % [rects.map(func(r): return r.size)], tall)
	var los := true
	for i in range(1, rects.size()):
		los = los and not rects[i].intersects(rects[i - 1].grow(-0.5))
	check(tag + "tekstvak: keuzeregels overlappen niet", los)
	check(tag + "tekstvak: vak met keuzes volledig in beeld (naamtabje 11 boven het vak ook)",
			_within(Dialog.box_rect(), _safe()) and Dialog.box_rect().position.y >= 11.0 + _safe().position.y - 0.5)
	var inside := true
	for r in rects:
		inside = inside and Dialog.box_rect().grow(0.5).encloses(r)
	check(tag + "tekstvak: keuzeregels binnen het vak", inside)
	check(tag + "tekstvak: geen ontbrekende lettertekens", _missing_glyphs(Dialog.panel).is_empty())
	var same_row := true
	for r in rects:
		same_row = same_row and is_equal_approx(r.position.y, rects[0].position.y)
	check(tag + "tekstvak: 3 korte keuzes staan op een rij (vak blijft laag)", same_row and Dialog.choices_horizontal(Dialog.box_rect().size.x))
	# tikken op de tweede keuze kiest hem
	Dialog._choice_labels[1].gui_input.emit(_mouse())
	check(tag + "tekstvak: tik op een keuze kiest die keuze", Dialog.choice_result == 1)
	await sc.close_all()
	Dialog.chars_per_second = 1000.0
	Dialog.ask("Pick one.", ["Alpha", "Beta", "Gamma", "Delta"])
	await sc.pframes(8)
	var many: Array[Rect2] = Dialog.choice_rects()
	var stacked := many.size() == 4 and many[1].position.y > many[0].position.y
	var many_ok := stacked
	for r in many:
		many_ok = many_ok and r.size.y >= Dialog.CHOICE_ROW_MANY - 0.01
	check(tag + "tekstvak: 4 keuzes staan onder elkaar, elk >= 20 hoog", many_ok)
	check(tag + "tekstvak: 4 keuzes: vak binnen het veilige gebied", _within(Dialog.box_rect(), _safe()))
	await sc.close_all()
	Dialog.ask("Save your progress?", ["Yes", "No"])
	await sc.pframes(8)
	var short: Array[Rect2] = Dialog.choice_rects()
	var short_ok := short.size() == 2 and short[1].position.y > short[0].position.y and not Dialog.choices_horizontal(Dialog.box_rect().size.x)
	for r in short:
		short_ok = short_ok and r.size.y >= UiTouchC.TOUCH_MIN - 0.01 and r.size.x >= UiTouchC.TOUCH_MIN
	check(tag + "tekstvak: Yes/No blijven rechtsonder onder elkaar, elk >= 25 hoog", short_ok)
	check(tag + "tekstvak: Yes/No: vak binnen het veilige gebied", _within(Dialog.box_rect(), _safe()))
	await sc.close_all()


# ---------------------------------------------------------------- veldmenu
func _field_menu_tests(tag: String) -> void:
	await sc.open("menu_main")
	var m: Node = sc.field_menu()
	var safe := _safe()
	var ok_size := true
	var inside := true
	for id in m.buttons:
		var btn: Button = m.buttons[id]
		inside = inside and _within(btn.get_global_rect(), safe)
		var need: float = UiTouchC.TOUCH_MIN if id in m.RIGHT_COL else float(m.ROW_H)
		ok_size = ok_size and btn.size.y >= need - 0.01
	check(tag + "veldmenu: alle knoppen binnen het veilige gebied", inside)
	check(tag + "veldmenu: rechterkolom >= 25 hoog, linkerkolom >= %d" % m.ROW_H, ok_size)
	var overlap := false
	var ids: Array = m.buttons.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if (m.buttons[ids[i]] as Button).get_global_rect().intersects((m.buttons[ids[j]] as Button).get_global_rect()):
				overlap = true
	check(tag + "veldmenu: knoppen overlappen elkaar niet", not overlap)
	var clipped: Array = m.buttons.values().filter(func(btn): return _button_clipped(btn))
	check(tag + "veldmenu: geen afgekapte knoppen (%s)" % [clipped.map(func(btn): return btn.text)], clipped.is_empty())
	if m.quest_label != null:
		var q: Rect2 = m.quest_label.get_global_rect()
		var hits: Array = m.buttons.values().filter(func(btn): return btn.get_global_rect().intersects(q))
		check(tag + "veldmenu: opdrachtregel overlapt geen knop", hits.is_empty())
	check(tag + "veldmenu: geen ontbrekende lettertekens", _missing_glyphs(m.root).is_empty())
	await sc.shot_if("menu_main")
	await _event_action("cancel")
	await sc.pframes(3)
	check(tag + "veldmenu: B sluit het menu", sc.field_menu() == null or sc.field_menu().is_queued_for_deletion())
	await sc.close_all()


# ---------------------------------------------------------------- sub-schermen van het veldmenu
func _sub_screen_tests(tag: String) -> void:
	for name in SUB_SCREENS:
		await sc.open(name)
		var m: Node = sc.field_menu()
		var s: Node = m.sub if m != null else null
		check(tag + "%s: scherm opent" % name, s != null and is_instance_valid(s))
		if s == null:
			await sc.close_all()
			continue
		var zone: Control = s.get("back_zone")
		var back: Button = s.get("back_button")
		check(tag + "%s: Back-tikvlak >= 25 x 25 en bevat de knop" % name, zone != null and back != null
				and UiTouchC.big_enough(zone.get_global_rect())
				and zone.get_global_rect().grow(0.5).encloses(back.get_global_rect()))
		var root: Control = s.get("root")
		var bad := _offscreen(root, _safe())
		check(tag + "%s: alle tekst binnen het veilige gebied %s" % [name, bad.slice(0, 2)], bad.is_empty())
		var gaps := _missing_glyphs(root)
		check(tag + "%s: geen ontbrekende lettertekens %s" % [name, gaps.slice(0, 2)], gaps.is_empty())
		if name == "menu_save":
			check(tag + "menu_save: Ja en Nee >= 25 hoog (%s, %s)" % [s.yes_button.size, s.no_button.size],
					s.yes_button.size.y >= UiTouchC.TOUCH_MIN - 0.01 and s.no_button.size.y >= UiTouchC.TOUCH_MIN - 0.01)
		if name in ["menu_codex", "menu_bestiary", "menu_status"]:
			await sc.shot_if(name)
		if zone != null:
			zone.gui_input.emit(_mouse(Vector2(zone.size.x - 2.0, zone.size.y - 2.0)))
			await sc.pframes(3)
			check(tag + "%s: tik in de hoek (ook buiten de zichtbare knop) = terug" % name, m.sub == null or not is_instance_valid(m.sub))
		await sc.close_all()
		await sc.open(name)
		m = sc.field_menu()
		await _event_action("cancel")
		await sc.pframes(3)
		check(tag + "%s: B sluit het scherm" % name, m != null and (m.sub == null or not is_instance_valid(m.sub)))
		await sc.close_all()


# ---------------------------------------------------------------- winkel
func _shop_tests(tag: String) -> void:
	for name in ["shop_buy", "shop_sell", "shop_merchant"]:
		await sc.open(name)
		var s: Node = sc.scene().get_node_or_null("ShopScreen")
		check(tag + "%s: winkel opent" % name, s != null)
		if s == null:
			continue
		var rows := 0
		var tall := true
		for c in s.content.get_children():
			if c is Button:
				rows += 1
				tall = tall and c.size.y >= UiTouchC.ROW_TOUCH - 0.01
		check(tag + "%s: %d regels, elke >= 25 hoog" % [name, rows], rows > 0 and tall)
		check(tag + "%s: Back-tikvlak >= 25 x 25" % name, UiTouchC.big_enough(s.back_zone.get_global_rect()))
		var bad := _offscreen(s.root, _safe())
		check(tag + "%s: alle tekst binnen het veilige gebied %s" % [name, bad.slice(0, 2)], bad.is_empty())
		check(tag + "%s: geen ontbrekende lettertekens" % name, _missing_glyphs(s.root).is_empty())
		await sc.shot_if(name)
		if name == "shop_sell":
			await _event_action("cancel")
			await sc.pframes(3)
			check(tag + "shop_sell: B gaat eerst terug naar Kopen (winkel blijft open)",
					sc.scene().get_node_or_null("ShopScreen") != null and s.mode == "koop")
		await _event_action("cancel")
		await sc.pframes(3)
		check(tag + "%s: B sluit de winkel" % name, sc.scene().get_node_or_null("ShopScreen") == null
				or sc.scene().get_node("ShopScreen").is_queued_for_deletion())
		await sc.close_all()


# ---------------------------------------------------------------- Codex
func _codex_tests(tag: String) -> void:
	await sc.open("menu_codex")
	var s: Node = sc.field_menu().sub
	var tall: bool = s.entries.size() > 0
	for e in s.entries:
		tall = tall and e.size.y >= UiTouchC.ROW_TOUCH - 0.01
	check(tag + "Codex: %d lijstregels, elke >= 25 hoog" % s.entries.size(), tall)
	check(tag + "Codex: Fusion-knop >= 25 hoog", s.fuse_button.size.y >= UiTouchC.TOUCH_MIN - 0.01)
	check(tag + "Codex: Fusion en Back overlappen niet", not s.fuse_button.get_global_rect().intersects(s.back_button.get_global_rect()))
	check(tag + "Codex: lijst volgt de focus (scrollen met joystick)", s.scroll.follow_focus)
	await sc.close_all()
	await sc.open("menu_bestiary")
	var b: Node = sc.field_menu().sub
	check(tag + "Bestiarium: lijst volgt de focus", b.scroll.follow_focus)
	await sc.close_all()


# ---------------------------------------------------------------- co-op lobby
func _lobby_tests(tag: String) -> void:
	for name in ["lobby_menu", "lobby_host", "lobby_join", "lobby_join_code", "lobby_menu_online"]:
		await sc.open(name)
		var lobby: Control = sc._lobby
		var buttons: Array[Button] = lobby.all_touch_buttons()
		var tall := not buttons.is_empty()
		for btn in buttons:
			tall = tall and btn.size.y >= UiTouchC.TOUCH_MIN - 0.01
		check(tag + "%s: %d knoppen, elk >= 25 hoog" % [name, buttons.size()], tall)
		var small: Array = []
		for c in _text_nodes(lobby):
			if c is Label and c.get_theme_font_size("font_size") < MIN_FONT:
				small.append(c.text)
		check(tag + "%s: geen tekst kleiner dan %d %s" % [name, MIN_FONT, small.slice(0, 2)], small.is_empty())
		var bad := _offscreen(lobby, _safe())
		check(tag + "%s: alle tekst binnen het veilige gebied %s" % [name, bad.slice(0, 2)], bad.is_empty())
		var gaps := _missing_glyphs(lobby)
		check(tag + "%s: geen ontbrekende lettertekens %s" % [name, gaps.slice(0, 2)], gaps.is_empty())
		var clipped: Array = buttons.filter(func(btn): return _button_clipped(btn))
		check(tag + "%s: geen afgekapte knoppen" % name, clipped.is_empty())
		await sc.shot_if(name)
		if name == "lobby_host":
			await _event_action("cancel")
			check(tag + "lobby_host: B gaat terug naar het lobbymenu", lobby._screen == CoopLobbyScreen.Screen.MENU)
		elif name == "lobby_join" or name == "lobby_join_code":
			await _event_action("cancel")
			check(tag + "%s: B gaat terug naar het lobbymenu" % name, lobby._screen == CoopLobbyScreen.Screen.MENU)
		await sc.close_all()


# ---------------------------------------------------------------- gevecht
func _battle_tests(tag: String) -> void:
	if not await sc.start_battle():
		check(tag + "gevecht start", false)
		return
	var b: Control = sc.scene()
	var safe2 := _safe(2.0)
	var cross: Control = b.cross
	var tall := true
	for i in cross.buttons.size():
		if cross.is_shown(i):
			tall = tall and cross.button_rect(i).size.x >= 24.0 and cross.button_rect(i).size.y >= 24.0
	check(tag + "gevecht: kruisknoppen >= 24 (art 24x24 = ~46 dp, RPG ART-maat)", tall)
	check(tag + "gevecht: kruis binnen het veilige gebied", _within(cross.cross_rect(), safe2))
	var ally: Control = null
	for bx in b.status_boxes:
		if bool(bx.get("monster")):
			ally = bx
	check(tag + "gevecht: Codex-bondgenoot heeft een zijlabel", ally != null)
	if ally != null:
		check(tag + "gevecht: bondgenootnaam niet afgekapt ('%s')" % ally.fitted_name(),
				ally.fitted_name() == str(ally.hero.get("name", "")) and _within(ally.get_rect(), _safe(2.0)))
	await sc.shot_if("battle_cross")
	check(tag + "gevecht: A/B-knoppen binnen het veilige gebied", _within(Rect2(b.touch.a_center() - Vector2.ONE * 15.0, Vector2.ONE * 30.0), safe2)
			and _within(Rect2(b.touch.b_center() - Vector2.ONE * 15.0, Vector2.ONE * 30.0), safe2))
	await sc.open_battle("battle_magic")
	var menu: Control = b.menu
	var rows_ok: bool = menu.visible and menu._buttons.size() > 0
	for i in menu._buttons.size():
		var rb: Button = menu.row_button(i)
		if rb.visible:
			rows_ok = rows_ok and rb.size.y >= UiTouchC.TOUCH_MIN - 0.01
	check(tag + "gevecht: Magie-lijst, elke regel >= 25 hoog", rows_ok)
	check(tag + "gevecht: Magie-lijst binnen het veilige gebied", _within(menu.get_global_rect(), _safe()))
	var rows_n := 0
	for i in menu._buttons.size():
		if menu.row_button(i).visible:
			rows_n += 1
	var h_free: float = b._hero_top_y - (b.SUBMENU_TOP + b._safe().y) - b.LIST_CHROME
	check(tag + "gevecht: lijstregel (%d) = tikmaat of zoveel als boven de helden past (vrij %.0f voor %d regels)" % [menu.row_height, h_free, rows_n],
			menu.row_height == b._list_row_h(rows_n) and menu.row_height >= b.LIST_ROW_MIN and menu.row_height <= b.LIST_ROW_H)
	check(tag + "gevecht: lijstje van 1 of 2 regels krijgt de volle tikmaat", b._list_row_h(2) == b.LIST_ROW_H or h_free < 2.0 * b.LIST_ROW_H)
	var over_heroes := false
	for node in b.hero_nodes:
		if menu.get_global_rect().intersects(Rect2((node.home + node.STEP - node.FEET).round() * 2.0, node.SIZE * 2.0)):
			over_heroes = true
	check(tag + "gevecht: Magie-lijst valt niet over de helden", not over_heroes)
	await sc.shot_if("battle_magic")
	await _event_action("cancel")
	await sc.pframes(6)
	check(tag + "gevecht: B in de Magie-lijst gaat terug naar het kruis", b.state == "command" and cross.active)
	await sc.end_battle()


