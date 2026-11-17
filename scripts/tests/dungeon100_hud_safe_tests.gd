extends SceneTree
## Diepe Grot-HUD volgt UiTouch.insets (zelfde afspraak als de MENU-knop).
## Profielen zoals f6_ux2/f6_5_warper_safe.gd: 16:9 en 19,5:9 met insets 30/0/30/0,
## en 19,5:9 met notch 22/4/10/6 via insets_override.
##
## Niet geregistreerd. Een vlag in scripts/game_state.gd of een regel in
## .github/workflows/tests.yml zou die bestaande bestanden wijzigen.
## Start (na --import, met een echt venster, zoals de andere suites):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://scripts/tests/dungeon100_hud_safe_tests.gd
## Optioneel: -- --shots=/pad/map
## Registratie later (RPG Forge): dispatch-regel in scripts/game_state.gd en de suite
## in de matrix van .github/workflows/tests.yml, zelfde patroon als --dungeon100regelstest.
## Zit niet in de export (scripts/tests/*).

const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const TOUCH_SCENE := "res://scenes/ui/touch_controls.tscn"
## Zelfde basis als dungeon100_hud.gd POS. Insets 0 moet hier exact op blijven.
const BASE := Vector2(8, 6)
## [profiel, insets (links, boven, rechts, onder)] — zelfde set als f6_5_warper_safe.gd.
const CASES := [
	["16x9", Vector4(30, 0, 30, 0)],
	["19_5x9", Vector4(30, 0, 30, 0)],
	["19_5x9_notch", Vector4(22, 4, 10, 6)],
]
const FLOORS: Array[int] = [12, 10, 100]

var failures := 0
var passes := 0
var _shots := ""
var _gestart := false


func _process(_delta: float) -> bool:
	if _gestart:
		return false
	_gestart = true
	_run()
	return false


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _lees_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.get_slice("=", 1)
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)


func _within(r: Rect2, bounds: Rect2) -> bool:
	return r.position.x >= bounds.position.x - 0.5 and r.position.y >= bounds.position.y - 0.5 \
			and r.end.x <= bounds.end.x + 0.5 and r.end.y <= bounds.end.y + 0.5


func _shot(name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_shots, name]
	var err := img.save_png(path)
	print("INFO  screenshot: %s %s err=%s" % [path, img.get_size(), err])


func _wacht_hud() -> Node:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		var gs := root.get_node_or_null("GameState")
		if gs != null:
			var hud := gs.get_node_or_null("Dungeon100Hud")
			if hud != null and hud.get("view") != null and (hud.get("view") as Control).is_inside_tree():
				return hud
		await process_frame
	return null


func _zet_verdieping(gs: Node, hud: Node, floor_nr: int) -> Rect2:
	gs.set("dungeon100_floor", floor_nr)
	gs.set("in_battle", false)
	hud.call("refresh")
	return hud.call("pill_rect")


func _run() -> void:
	_lees_args()
	var gs: Node = root.get_node_or_null("GameState")
	var hud := await _wacht_hud()
	check("HUD hangt onder GameState", gs != null and hud != null and hud.get_parent() == gs)
	if hud == null or gs == null:
		_einde()
		return
	var view := hud.get("view") as Control
	check("HUD heeft een themafont", view != null and view.get_theme_default_font() != null)
	var pos_const: Vector2 = hud.get_script().get_script_constant_map().get("POS", Vector2.ZERO)
	check("POS-const blijft (8, 6)", pos_const == BASE)

	var floor0: int = int(gs.get("dungeon100_floor"))
	var best0: int = int(gs.get("dungeon100_best"))
	var battle0: bool = bool(gs.get("in_battle"))

	var scenarios_script: GDScript = load("res://tools/ui_polish/ui_scenarios.gd")
	# Ongetypt: set_profile/refit zitten op het script, niet op Node/Control.
	var sc = scenarios_script.new()
	root.add_child(sc)
	var profiles: Dictionary = scenarios_script.get_script_constant_map()["PROFILES"]
	var touch_layer: Node = load(TOUCH_SCENE).instantiate()
	root.add_child(touch_layer)
	var touch = touch_layer.get_node("Control")
	touch.show_menu = true
	await _frames(2)

	# --- insets 0: pixel-identiek aan de vaste plek, ook de losse grenzen van dungeon100_tests
	await sc.set_profile("16x9")
	UiTouchC.insets_override = null
	touch.refit()
	await _frames(2)
	check("zonder override zijn de insets 0", UiTouchC.insets(root) == Vector4.ZERO)
	var zero_size := {}
	for floor_nr in FLOORS:
		var z: Rect2 = _zet_verdieping(gs, hud, floor_nr)
		zero_size[floor_nr] = z.size
		var oud := z.position.x >= 4.0 and z.position.y >= 2.0 and z.end.x < 200.0 and z.end.y < 30.0
		check("insets 0, verdieping %d: pil %s op (8, 6), hoogte 14, binnen x>=4 y>=2 end.x<200 end.y<30" % [floor_nr, z],
				z.position == BASE and is_equal_approx(z.size.y, 14.0) and oud)
	check("insets 0: rustverdieping 10 is breder dan 12 (puntje)", (zero_size[10] as Vector2).x > (zero_size[12] as Vector2).x)
	check("insets 0: verdieping 100 is de breedste", (zero_size[100] as Vector2).x > (zero_size[10] as Vector2).x)
	var zero_rect: Rect2 = _zet_verdieping(gs, hud, 12)
	UiTouchC.insets_override = Vector4.ZERO
	touch.refit()
	await _frames(2)
	var zero_explicit: Rect2 = hud.call("pill_rect")
	check("insets_override 0 is dezelfde rechthoek als geen override (%s)" % zero_explicit,
			zero_explicit == zero_rect)
	await _shot("d100_hud_safe_16x9_zero")

	# --- 16:9, 19,5:9 en notch. Alleen de plek schuift; de maat blijft die van insets 0.
	for cs in CASES:
		var profiel: String = cs[0]
		var ins: Vector4 = cs[1]
		await sc.set_profile(profiel)
		UiTouchC.insets_override = ins
		await _frames(3)
		touch.refit()
		var vp: Vector2 = root.get_visible_rect().size
		var verwacht: Vector2i = profiles[profiel]
		check("%s: viewport %s (verwacht %s)" % [profiel, vp, verwacht],
				is_equal_approx(vp.x, float(verwacht.x)) and is_equal_approx(vp.y, float(verwacht.y)))
		check("%s: insets gelezen als %s" % [profiel, ins], UiTouchC.insets(root) == ins)
		var want := BASE + Vector2(ins.x, ins.y)
		var safe := UiTouchC.safe_rect(vp, root)
		var menu: Rect2 = touch.menu_rect()
		# Zonder refresh: _process moet de insets zelf zien (tekenen volgt).
		var gezien: Vector4 = hud.get("_last_insets")
		check("%s: HUD-proces volgt de insets (%s)" % [profiel, gezien], gezien == ins)
		for floor_nr in FLOORS:
			var r: Rect2 = _zet_verdieping(gs, hud, floor_nr)
			var maat: Vector2 = zero_size[floor_nr]
			check("%s vloer %d: pil %s = %s + insets, maat %s ongewijzigd" % [profiel, floor_nr, r, BASE, maat],
					r.position == want and r.size == maat)
			check("%s vloer %d: pil binnen safe %s, links van MENU %s, zelfde bovenrand" % [profiel, floor_nr, safe, menu],
					_within(r, safe) and r.end.x < menu.position.x and not r.intersects(menu)
					and is_equal_approx(r.position.y, menu.position.y))
		_zet_verdieping(gs, hud, 12)
		await _shot("d100_hud_safe_%s" % profiel)

	# --- terug naar 0: weer exact de basisrechthoek
	await sc.set_profile("16x9")
	UiTouchC.insets_override = null
	touch.refit()
	await _frames(2)
	var terug: Rect2 = _zet_verdieping(gs, hud, 12)
	check("na de profielen weer (8, 6) en dezelfde maat (%s)" % terug,
			terug.position == BASE and terug.size == zero_size[12])

	gs.set("dungeon100_floor", floor0)
	gs.set("dungeon100_best", best0)
	gs.set("in_battle", battle0)
	hud.call("refresh")
	UiTouchC.insets_override = null
	touch_layer.queue_free()
	sc.queue_free()
	_einde()


func _einde() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	quit(1 if failures else 0)
