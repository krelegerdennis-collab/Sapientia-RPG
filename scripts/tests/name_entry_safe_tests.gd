extends SceneTree
## Naamscherm blijft bovenin het veilige gebied (notch / gebarenbalk).
## y = 22 + inset boven, zodat het schermtoetsenbord (onderste helft) niets bedekt.
## x blijft het midden en schuift alleen de safe rect in. Insets 0 = dezelfde pixel als eerst.
##
## Patroon als scripts/tests/f6_ux2/f6_5_warper_safe.gd (16:9, 19,5:9, notch via insets_override),
## maar losstaand: niet in scripts/tests/f6_ux2/ (die map hangt aan --f6uxtest2) en niet
## geregistreerd in scripts/game_state.gd of .github/workflows/tests.yml.
##
## Start:
##   godot --headless --rendering-driver opengl3 --path . --script res://scripts/tests/name_entry_safe_tests.gd [--shots=/pad]
##
## Registratie (later, door RPG Forge — niet in deze PR): één dispatch-regel in
## scripts/game_state.gd _ready() zoals --androidbacktest, plus de suite in de matrix van
## .github/workflows/tests.yml. Voorbeeldvlag: --nameentrysafetest.

var _gestart := false


func _process(_delta: float) -> bool:
	if _gestart:
		return false
	_gestart = true
	root.add_child(Runner.new())
	return false


class Runner extends Node:
	const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
	const TOP_Y := 22.0
	## [label, viewport, insets (links, boven, rechts, onder)]
	const CASES: Array = [
		["16x9", Vector2i(384, 216), Vector4(0, 0, 0, 0)],
		["19_5x9", Vector2i(468, 216), Vector4(0, 0, 0, 0)],
		["16x9_zij", Vector2i(384, 216), Vector4(30, 0, 30, 0)],
		["19_5x9_zij", Vector2i(468, 216), Vector4(30, 0, 30, 0)],
		["19_5x9_notch", Vector2i(468, 216), Vector4(22, 4, 10, 6)],
	]

	var failures := 0
	var passes := 0
	var shots := ""


	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		for arg in OS.get_cmdline_user_args():
			if str(arg).begins_with("--shots="):
				shots = str(arg).get_slice("=", 1)
		if shots != "":
			DirAccess.make_dir_recursive_absolute(shots)
		get_tree().create_timer(90.0, true, false, true).timeout.connect(func() -> void:
			print("RESULT FOUT (waakhond: niet klaar binnen 90 s)")
			get_tree().quit(1))
		_run.call_deferred()


	func check(label: String, ok: bool) -> void:
		print(("PASS  " if ok else "FAIL  ") + label)
		if ok:
			passes += 1
		else:
			failures += 1


	func _frames(n: int) -> void:
		for _i in n:
			await get_tree().process_frame


	func _set_view(sz: Vector2i) -> void:
		var win := get_window()
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_size = sz
		win.size = sz * 3
		await _frames(4)


	func _panel(s: Node) -> Control:
		for c in s.get_children():
			if c is PanelContainer:
				return c
		return null


	func _shot(name: String) -> void:
		if shots == "":
			return
		var tr := get_node_or_null("/root/Transition")
		if tr != null and tr.has_method("clear_overlay"):
			tr.call("clear_overlay")
		await _frames(2)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var pad := shots
		img.save_png("%s/%s.png" % [pad, name])
		print("INFO  screenshot: %s/%s.png %s" % [pad, name, img.get_size()])


	func _open() -> Control:
		get_tree().change_scene_to_file("res://scenes/ui/name_entry.tscn")
		var t := 0.0
		while t < 8.0:
			var s := get_tree().current_scene
			if s != null and s.name == "NameEntry" and s.is_node_ready() and _panel(s) != null:
				var box := _panel(s)
				if box.size.x > 1.0 and box.size.y > 1.0 and box.position.y >= TOP_Y - 0.01:
					return s
			await get_tree().process_frame
			t += get_process_delta_time()
		var now := get_tree().current_scene
		return now if now != null and now.name == "NameEntry" else null


	## x = afgerond midden, daarna in de safe rect geklemd. y = 22 + inset boven.
	func _check_box(tag: String, s: Control, ins: Vector4) -> void:
		var box := _panel(s)
		check("%s: paneel staat" % tag, box != null and box.size.x > 1.0)
		if box == null:
			return
		var vp := s.size
		var safe := UiTouchC.safe_rect(vp, get_viewport())
		var center := roundf((vp.x - box.size.x) / 2.0)
		var max_x := maxf(safe.position.x, safe.end.x - box.size.x)
		var expect_x := clampf(center, safe.position.x, max_x)
		var expect_y := TOP_Y + ins.y
		print("INFO  %s paneel pos %s size %s safe %s" % [tag, box.position, box.size, safe])
		check("%s: y = 22 + inset boven (%.1f, verwacht %.1f)" % [tag, box.position.y, expect_y],
				absf(box.position.y - expect_y) < 0.01)
		check("%s: x = midden binnen safe (%.1f, verwacht %.1f, midden %.1f)" % [tag, box.position.x, expect_x, center],
				absf(box.position.x - expect_x) < 0.01)
		var r := box.get_global_rect()
		var top_ok := r.position.y >= safe.position.y - 0.5
		var left_ok := r.position.x >= safe.position.x - 0.5
		var fits := box.size.x <= safe.size.x + 0.5 and box.size.y <= safe.size.y + 0.5
		var inside := left_ok and top_ok and (not fits or (r.end.x <= safe.end.x + 0.5 and r.end.y <= safe.end.y + 0.5))
		check("%s: paneel binnen safe %s (rect %s, past %s)" % [tag, safe, r, fits], inside)
		if fits:
			for node_name in ["edit", "ok", "back"]:
				var ctl: Control = s.get(node_name + ("_button" if node_name != "edit" else ""))
				if ctl == null:
					check("%s: %s aanwezig" % [tag, node_name], false)
					continue
				var cr := ctl.get_global_rect()
				check("%s: %s binnen safe %s" % [tag, node_name, cr],
						cr.position.x >= safe.position.x - 0.5 and cr.position.y >= safe.position.y - 0.5
						and cr.end.x <= safe.end.x + 0.5 and cr.end.y <= safe.end.y + 0.5)
		if ins == Vector4.ZERO:
			check("%s: insets 0, y exact 22 en x het oude midden" % tag,
					absf(box.position.y - TOP_Y) < 0.01 and absf(box.position.x - center) < 0.01)
		var back: Button = s.get("back_button")
		check("%s: Back-knop nog op tikmaat" % tag, back != null and back.size.y >= UiTouchC.TOUCH_MIN - 0.01)


	func _run() -> void:
		await _set_view(Vector2i(384, 216))
		UiTouchC.insets_override = Vector4.ZERO
		var s := await _open()
		check("naamscherm geladen", s != null)
		if s == null:
			_einde()
			return
		for cs in CASES:
			var label: String = cs[0]
			var sz: Vector2i = cs[1]
			var ins: Vector4 = cs[2]
			await _set_view(sz)
			UiTouchC.insets_override = ins
			await _frames(4)
			var now := get_tree().current_scene as Control
			var vis := get_viewport().get_visible_rect().size
			check("%s: viewport %s" % [label, vis], now != null and vis.is_equal_approx(Vector2(sz)) and now.size.is_equal_approx(Vector2(sz)))
			if now == null:
				continue
			_check_box(label, now, ins)
			if label in ["16x9", "19_5x9", "19_5x9_notch"]:
				await _shot("name_entry_%s" % label)
		# Zelfde viewport: alleen de insets wisselen (geen resize). Dat loopt via _process.
		await _set_view(Vector2i(384, 216))
		UiTouchC.insets_override = Vector4.ZERO
		await _frames(4)
		var live := get_tree().current_scene as Control
		var before := _panel(live)
		var y0 := before.position.y if before != null else -1.0
		var x0 := before.position.x if before != null else -1.0
		check("live: insets 0 terug op y = 22", absf(y0 - TOP_Y) < 0.01)
		UiTouchC.insets_override = Vector4(22, 4, 10, 6)
		await _frames(4)
		var after := _panel(live)
		var safe_n := UiTouchC.safe_rect(live.size, get_viewport())
		check("live: notch zonder resize zet y op 26 (was %.1f, nu %.1f)" % [y0, after.position.y if after != null else -1.0],
				after != null and absf(after.position.y - (TOP_Y + 4.0)) < 0.01)
		check("live: notch-x binnen safe %s (x %.1f)" % [safe_n, after.position.x if after != null else -1.0],
				after != null and after.position.x >= safe_n.position.x - 0.5
				and after.position.x <= maxf(safe_n.position.x, safe_n.end.x - after.size.x) + 0.5)
		UiTouchC.insets_override = null
		await _frames(4)
		var back := _panel(live)
		check("live: override weg, weer de pixel van insets 0 (x %.1f -> %.1f, y %.1f)" % [x0, back.position.x if back != null else -1.0, back.position.y if back != null else -1.0],
				back != null and absf(back.position.y - TOP_Y) < 0.01 and absf(back.position.x - x0) < 0.01)
		await _check_wide(live)
		UiTouchC.insets_override = null
		_einde()


	## Paneel breder dan het midden toelaat: x moet de safe rect in schuiven.
	func _check_wide(s: Control) -> void:
		await _set_view(Vector2i(384, 216))
		var box := _panel(s)
		if box == null:
			check("breed: paneel staat", false)
			return
		box.custom_minimum_size = Vector2(s.size.x - 64.0, box.size.y)
		UiTouchC.insets_override = Vector4(48, 10, 48, 0)
		await _frames(4)
		box = _panel(s)
		var vp := s.size
		var safe := UiTouchC.safe_rect(vp, get_viewport())
		var center := roundf((vp.x - box.size.x) / 2.0)
		var max_x := maxf(safe.position.x, safe.end.x - box.size.x)
		print("INFO  breed paneel pos %s size %s safe %s midden %.1f" % [box.position, box.size, safe, center])
		check("breed: paneel is echt breder dan het ongeklemd midden toelaat (midden %.1f < safe %.1f, breedte %.0f)" % [center, safe.position.x, box.size.x],
				center < safe.position.x - 0.5 and box.size.x > 300.0)
		check("breed: x geschoven tot in de safe rect (%.1f, verwacht %.1f)" % [box.position.x, clampf(center, safe.position.x, max_x)],
				absf(box.position.x - clampf(center, safe.position.x, max_x)) < 0.01)
		check("breed: y blijft 22 + inset boven", absf(box.position.y - (TOP_Y + 10.0)) < 0.01)
		box.custom_minimum_size = Vector2.ZERO


	func _einde() -> void:
		UiTouchC.insets_override = null
		print("NAMEENTRYSAFE %d PASS, %d FAIL" % [passes, failures])
		print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
		await _frames(2)
		get_tree().quit(1 if failures else 0)
