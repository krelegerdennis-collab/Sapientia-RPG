extends Node
## WM1 F6 UX-polish: plaatsing van ballon, schat-vak en tutorial-tip is onafhankelijk van
## venstergrootte/DPI/Windows-taakbalk.
## Start: godot --path . -- --uxpolishtest [--shots=/pad/map]
## Zit niet in de export (scripts/tests/*).

const SD := preload("res://scripts/data/story_data.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const WILGENDAL := "res://scenes/maps/wilgendal.tscn"
const TASKBAR := Vector4(0, 0, 0, 16)

## Vensters die de Windows-laptop (1536x864 @ 125%) en de polish-ratio's nabootsen.
const SIZES := [
	["1536x864", Vector2i(1536, 864)],
	["1170x540", Vector2i(1170, 540)],
	["1260x540", Vector2i(1260, 540)],
	["1024x768", Vector2i(1024, 768)],
	["768x432", Vector2i(768, 432)],
]

var failures := 0
var passes := 0
var shots := ""
var _win0 := Vector2i.ZERO
var _cps0 := 40.0


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


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func player() -> Node2D:
	var s := get_tree().current_scene
	if s == null:
		return null
	return s.get_node_or_null("Objects/Player")


func _rect_hits_circle(r: Rect2, c: Vector2, radius: float) -> bool:
	var p := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return p.distance_to(c) < radius


func _run() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	var oude_mult: float = GameState.encounter_multiplier
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	GameState.encounter_multiplier = 0.0
	_win0 = get_window().size
	_cps0 = Dialog.chars_per_second
	Dialog.chars_per_second = 1000.0
	UiTouchC.insets_override = null
	UiTouchC.test_display_insets = null
	print("=== F6 UX-polish: desktop-insets + plaatsing ===")
	_inset_unit()
	await _placement_windows()
	await _battle_tip()
	_restore()
	Settings.set_value("battle_style", oude_stijl)
	GameState.encounter_multiplier = oude_mult
	print("UXPOLISHTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _restore() -> void:
	UiTouchC.insets_override = null
	UiTouchC.test_display_insets = null
	Dialog.chars_per_second = _cps0
	if Dialog.is_open:
		Dialog.close()
	if _win0 != Vector2i.ZERO:
		get_window().size = _win0


# ---------------------------------------------------------------- insets
func _inset_unit() -> void:
	check("F6: desktop/CI is geen mobile-feature", not OS.has_feature("mobile"))
	check("F6: zonder override is insets nul (geen taakbalk)", UiTouchC.insets(get_viewport()) == Vector4.ZERO)
	UiTouchC.test_display_insets = TASKBAR
	check("F6: gesimuleerde desktop-inset 16 px onder wordt genegeerd",
			UiTouchC.insets(get_viewport()) == Vector4.ZERO)
	UiTouchC.test_display_insets = null
	UiTouchC.insets_override = TASKBAR
	check("F6: insets_override (notch-test) blijft wél gelden", UiTouchC.insets(get_viewport()) == TASKBAR)
	UiTouchC.insets_override = null


# ---------------------------------------------------------------- ballon + schat op meerdere vensters
func _placement_windows() -> void:
	GameState.new_game("Kees")
	GameState.story_step = SD.KLAAR
	GameState.pending_spawn = ""
	var map: Node = await _laad(WILGENDAL)
	check("F6: Wilgendal laadt voor plaatsingstests", map != null)
	if map == null:
		return
	var p: Node2D = player()
	check("F6: speler op de kaart", p != null)
	if p == null:
		return
	if p.has_method("place_at"):
		# Omhoog kijken: de tegel vóór de speler ligt boven het midden, zodat 'onder'/'onder_smal'
		# vrij blijft. Omlaag kijken overlapte het smalle vak (y 118) op 16:9.
		p.place_at(Vector2i(20, 10), Vector2i.UP)
	await frames(6)
	var touch: Control = map.get_node_or_null("TouchControls/Control")
	for pair in SIZES:
		var label: String = pair[0]
		var sz: Vector2i = pair[1]
		get_window().size = sz
		await frames(8)
		if touch != null and touch.has_method("refit"):
			touch.refit()
		await pframes(2)
		UiTouchC.test_display_insets = TASKBAR
		check("F6: %s insets blijven nul met taakbalk-simulatie" % label,
				UiTouchC.insets(get_viewport()) == Vector4.ZERO)
		await _check_vak(label)
		await _check_ballon(label, p, label == "1536x864")
		UiTouchC.test_display_insets = null
	get_window().size = _win0
	await frames(4)


func _check_vak(tag: String) -> void:
	Dialog.show_lines(["Kees receives 3x Healing Herb!"], "")
	await pframes(4)
	var r: Rect2 = Dialog.box_rect()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	check("F6: schat (%s) in het blauwe vak, laag en niet bovenin (%s, plek %s)" % [tag, r, Dialog.placement],
			Dialog.is_open and Dialog.style_kind == "vak" and UiStyleC.is_blue_box(Dialog.box_style(), "vak")
			and not Dialog.tail.visible and Dialog.at_bottom and Dialog.placement != "boven"
			and r.position.y > vs.y * 0.4)
	Dialog.close()
	await pframes(2)


func _check_ballon(tag: String, speaker: Node2D, shot := false) -> void:
	Dialog.show_lines(["The Archives wait."], "Old Man", speaker)
	await pframes(4)
	var r: Rect2 = Dialog.box_rect()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	check("F6: ballon (%s) niet bovenin maar laag, boven de knoppen (plek '%s', y %.0f)" % [tag, Dialog.placement, r.position.y],
			Dialog.is_open and Dialog.style_kind == "ballon" and Dialog.at_bottom
			and Dialog.placement != "boven" and r.position.y > vs.y * 0.4)
	if shot:
		await _shot("f6_dialog_1536x864")
	Dialog.close()
	await pframes(2)


# ---------------------------------------------------------------- tutorial-tip
func _battle_tip() -> void:
	GameState.in_battle = true
	GameState.pending_tutorial = {"tutorial": true}
	GameState.pending_enemies = ["mosslijm"]
	GameState.pending_boss = false
	GameState.pending_tier = 0
	GameState.pending_backdrop = ""
	var b: Node = load(GameState.BATTLE_SCENE).instantiate()
	get_tree().root.add_child(b)
	var ready := false
	for i in 240:
		if is_instance_valid(b) and str(b.state) == "command" and b.tip_panel != null and b.tip_panel.visible:
			ready = true
			break
		await pframes(1)
	check("F6: oefengevecht toont het tip-venster", ready)
	if ready:
		var want: Vector2 = b.tip_origin()
		check("F6: tip-oorsprong op desktop is (6, 22)", want.is_equal_approx(Vector2(6, 22)))
		check("F6: tip-venster staat op de oorsprong %s" % b.tip_panel.position,
				b.tip_panel.position.is_equal_approx(want))
		var tip_r: Rect2 = _lrect(b, b.tip_panel)
		var ok_tip := _tip_clear(b, tip_r)
		check("F6: tip-venster valt nergens over (vijand, kruis, held, vak, strook, D-pad, A/B) %s" % tip_r, ok_tip)
		await _shot("f6_tip_desktop")
		# notch-simulatie: top-inset schuift de tip mee (gevecht is 2x, dus /2)
		UiTouchC.insets_override = Vector4(0, 10, 0, 0)
		if b.touch != null and b.touch.has_method("refit"):
			b.touch.refit()
		b._show_tip(b.heroes[0])
		await pframes(2)
		var shifted: Vector2 = b.tip_origin()
		check("F6: tip is inset-aware (y %.1f >= 26 bij boven-inset 10)" % shifted.y,
				shifted.y >= 26.0 - 0.05 and b.tip_panel.position.is_equal_approx(shifted))
		UiTouchC.insets_override = null
	if is_instance_valid(b):
		b.queue_free()
	await pframes(4)
	GameState.in_battle = false
	GameState.pending_tutorial = {}
	GameState.pending_enemies = []
	GameState.practice_battle = false


func _tip_clear(b: Node, tip_r: Rect2) -> bool:
	for c in b.enemies:
		if tip_r.intersects(_lrect(b, c["node"])):
			return false
	if b.cross != null and (tip_r.intersects(b.cross.cross_rect()) or tip_r.intersects(_lrect(b, b.cross.name_tab))):
		return false
	if b.caption.visible and tip_r.intersects(_lrect(b, b.caption)):
		return false
	for box in b.status_boxes:
		if tip_r.intersects(_lrect(b, box)):
			return false
	for node in b.hero_nodes:
		if tip_r.intersects(_lrect(b, node)):
			return false
	var tc: Control = b.touch
	if tc != null and tc.has_method("dpad_center"):
		for c in [[tc.dpad_center(), tc.joy_radius() * 1.2], [tc.a_center(), tc.button_radius * 1.25],
				[tc.b_center(), tc.button_radius * 1.25]]:
			if _rect_hits_circle(tip_r, c[0], c[1]):
				return false
	return true


func _lrect(b: Node, c: Control) -> Rect2:
	return b.get_global_transform().affine_inverse() * c.get_global_rect()


func _shot(name: String) -> void:
	if shots == "":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [shots, name])


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.has_return_point = false
	get_tree().change_scene_to_file(pad)
	for i in 180:
		await get_tree().process_frame
		var s: Node = get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4 \
				and s.get_node_or_null("Objects/Player") != null:
			return s
	return null
