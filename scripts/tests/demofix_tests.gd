extends "res://scripts/tests/golem_tests.gd"
## ALLEEN VOOR TESTEN - browserdemo-fixes (31 okt 2026) in het Golem-gevecht:
##   1) kruis start op Aanval; Magie zonder bruikbare spreuk -> 'No spells yet', kruis blijft bedienbaar.
##   2) tikvlakken van het kruis: claims_touch + 1e tik kiest / 2e tik bevestigt.
##   3) baas-HP-balk zichtbaar (font 10) en volgt de HP.
##   4) touch_mode: toetsenbord verbergt joystick/A/B, echte ScreenTouch toont ze.
## Start: xvfb-run -a godot --rendering-driver opengl3 --path . -- --demofixtest

const TC := preload("res://scripts/touch_controls.gd")


func _run() -> void:
	Engine.time_scale = 2.0
	var b := await _start_boss(10)
	check("baasgevecht gestart", b != null)
	if b == null:
		return _finish()
	check("ronde 1: wacht op het commando", await wait_battle_state(["command"]) == "command")
	await pframes(4)
	var cross = b.cross
	check("fix 1: kruis start op Aanval (selected %d)" % cross.selected, cross.selected == 0)
	# --- fix 3
	var bar = b.boss_bar
	check("fix 3: baas-HP-balk bestaat en is zichtbaar", bar != null and bar.is_visible_in_tree())
	if bar:
		check("fix 3: font_size >= 10", bar.name_label.get_theme_font_size("font_size") >= 10)
		check("fix 3: balk vol bij de start (%.2f)" % bar.ratio(), is_equal_approx(bar.ratio(), 1.0))
		var g: Dictionary = b.enemies[0]
		var hp0 := int(g["s"]["hp"])
		g["s"]["hp"] = hp0 / 2
		check("fix 3: balk volgt de HP (%.2f)" % bar.ratio(), absf(bar.ratio() - 0.5) < 0.02)
		g["s"]["hp"] = hp0
	# --- fix 1: Magie zonder MP
	var hero: Dictionary = b.heroes[0]
	var mp0 := int(hero["s"]["mp"])
	hero["s"]["mp"] = 0
	check("fix 1: geen bruikbare magie (MP 0)", not b.has_usable_magic(hero))
	cross.select(1)
	await tap("interact")
	await pframes(6)
	check("fix 1: na Magie weer in 'command' (state %s)" % b.state, b.state == "command")
	check("fix 1: kruis weer actief", cross.active)
	# Magie grijs (geen spreuken) -> denied, cursor blijft staan; Magie aan maar geen MP -> terug op Aanval
	check("fix 1: cursor op Aanval of Magie (%d), kruis bedienbaar" % cross.selected, cross.selected in [0, 1])
	check("fix 1: bericht 'No spells yet' zichtbaar", b.message_label.text == "No spells yet" and b.caption.visible)
	hero["s"]["mp"] = mp0
	# --- r3 (b): touch-joystick en A in het gevecht
	var tc: Control = b.touch
	cross.select(0)
	await pframes(2)
	var up_local: Vector2 = tc.stick_center() + Vector2(0, -tc.joy_radius() * 0.8)
	await touch_at(tc.get_global_transform_with_canvas() * up_local, 7)
	check("r3: touch-joystick omhoog kiest Magie in het kruis (selected %d)" % cross.selected, cross.selected == 1)
	var right_local: Vector2 = tc.stick_center() + Vector2(tc.joy_radius() * 0.8, 0)
	cross.select(0)
	await touch_at(tc.get_global_transform_with_canvas() * right_local, 7)
	check("r3: touch-joystick rechts kiest Verdedig (selected %d)" % cross.selected, cross.selected == 3)
	cross.select(0)
	await pframes(2)
	await touch_at(tc.get_global_transform_with_canvas() * tc.a_center(), 8)
	check("r3: touch op A bevestigt Aanval -> doelkeuze (state %s)" % b.state,
			await wait_battle_state(["target_enemy"], 3) == "target_enemy")
	await touch_at(tc.get_global_transform_with_canvas() * tc.b_center(), 9)
	check("r3: touch op B -> terug naar het kruis", await wait_battle_state(["command"], 3) == "command")
	await pframes(4)
	# --- fix 2: tikken
	var c1: Vector2 = cross.get_global_transform_with_canvas() * cross.button_rect(3).get_center()
	check("fix 2: tik op Verdedig wordt door het kruis geclaimd", cross.claims_touch(c1))
	check("fix 2: tikvlak >= 25 eenheden", cross.hit_rect(3).size.x >= 25.0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	cross._on_button_input(ev, 3)
	check("fix 2: 1e tik kiest Verdedig, bevestigt nog niet", cross.selected == 3 and cross.active)
	await pframes(2)
	# --- fix 4 (voor de 2e tik: daarna loopt de ronde door)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	TC.note_input(key)
	check("fix 4: toetsenbord -> touch_mode uit", not TC.touch_mode)
	var emu := InputEventScreenTouch.new()
	emu.pressed = true
	emu.device = InputEvent.DEVICE_ID_EMULATION
	TC.note_input(emu)
	check("fix 4: geëmuleerde touch (muis) laat het uit", not TC.touch_mode)
	var st := InputEventScreenTouch.new()
	st.pressed = true
	st.device = 0
	TC.note_input(st)
	check("fix 4: echte touch -> touch_mode aan", TC.touch_mode)
	cross._on_button_input(ev, 3)
	check("fix 2: 2e tik op de gekozen knop bevestigt (last_result %d)" % cross.last_result, cross.last_result == 3)
	_finish()


func touch_at(pos: Vector2, index: int) -> void:
	await get_tree().physics_frame
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.device = 0
	ev.position = get_tree().root.get_final_transform() * pos   # viewport -> venster
	ev.pressed = true
	Input.parse_input_event(ev)
	await pframes(3)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await pframes(3)


func _finish() -> void:
	print("DEMOFIXTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(10)
	get_tree().quit(1 if failures else 0)
