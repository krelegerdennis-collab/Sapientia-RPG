extends RefCounted
## F6-T02: hub Warp/Party schermen claimen tikken boven TouchControls (joystick/A/B).
## Registratie: map-scan in scripts/tests/f6_ux2_tests.gd (--f6uxtest2).

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const HAL := "res://world_warper/maps/hal.tscn"
const TC := preload("res://scripts/touch_controls.gd")
const STEP_PLACES := 1

const CANON_FLAGS: Array[String] = [
	"ww_canon_genezer_gezien",
	"ww_canon_hanger_gezien",
	"ww_canon_dreiging_gezien",
]


func needs_game() -> bool:
	return true


## Tikpunt op de knop dat in de joystick-zone ligt (zoals in de hal: links onder op het scherm).
static func _overlap_tik(tc: Control, knop: BaseButton) -> Dictionary:
	var r: Rect2 = knop.get_global_rect()
	var stick_vp: Vector2 = tc.get_global_transform_with_canvas() * tc.stick_center()
	var reach: float = tc.stick_reach()
	var p: Vector2 = Vector2(
			clampf(stick_vp.x, r.position.x, r.end.x),
			clampf(stick_vp.y, r.position.y, r.end.y))
	var local: Vector2 = tc.get_global_transform_with_canvas().affine_inverse() * p
	var joy_overlap: bool = r.has_point(p) and local.distance_to(tc.stick_center()) <= reach
	return {"pos": p, "joy_overlap": joy_overlap}


func _touch_tree(t: Node, viewport_pos: Vector2, index: int, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.device = 0
	ev.pressed = pressed
	ev.position = t.get_tree().root.get_final_transform() * viewport_pos
	Input.parse_input_event(ev)


func _tap_at(t: Node, viewport_pos: Vector2, index: int) -> void:
	_touch_tree(t, viewport_pos, index, true)
	await t.pframes(3)
	_touch_tree(t, viewport_pos, index, false)
	await t.pframes(4)


func _laad_hal(t: Node) -> Node2D:
	GameState.story_flags[Kamers.FLAG_HUB] = true
	for f in CANON_FLAGS:
		GameState.story_flags[f] = true
	GameState.change_map(HAL, "ingang")
	var hal: Node2D = null
	for _i in 420:
		await t.pframes(1)
		var nu := t.get_tree().current_scene
		if nu != null and nu.scene_file_path == HAL and not GameState.changing_map and nu.is_node_ready():
			hal = nu as Node2D
			break
	t.check("F6-T02: hub-hal geladen", hal != null)
	if hal == null:
		return null
	await t.pframes(6)
	return hal


func _prep_touch(t: Node, hal: Node2D) -> Control:
	var tc := hal.get_node_or_null("TouchControls/Control") as Control
	t.check("F6-T02: TouchControls aanwezig", tc != null)
	if tc == null:
		return null
	TC.touch_mode = true
	await t.pframes(2)
	return tc


func _touch_knop(t: Node, hal: Node2D, tc: Control, knop: BaseButton, tag: String, ok_if: Callable) -> void:
	var pick: Dictionary = _overlap_tik(tc, knop)
	var gp: Vector2 = pick["pos"]
	var joy_overlap: bool = pick["joy_overlap"]
	if not joy_overlap:
		t.check("%s: knop '%s' overlapt joystick niet (overgeslagen)" % [tag, knop.name], true)
		return
	t.check("%s: knop '%s' deelt tikgebied met joystick (repro)" % [tag, knop.name], true)
	var speler: Node2D = hal.get_node_or_null("Objects/Player")
	var pos0: Vector2 = speler.global_position if speler != null else Vector2.ZERO
	tc._touch_owner.clear()
	tc.joy_raw = Vector2.ZERO
	var presses: Array[int] = [0]
	var cb := func() -> void:
		presses[0] += 1
	if not knop.pressed.is_connected(cb):
		knop.pressed.connect(cb)
	await _tap_at(t, gp, 11)
	var owner: String = str(tc._touch_owner.get(11, ""))
	var beweging: bool = speler != null and speler.global_position.distance_to(pos0) > 0.5
	var actie_ok: bool = presses[0] > 0 or ok_if.call()
	if knop.pressed.is_connected(cb):
		knop.pressed.disconnect(cb)
	t.check("%s: tik op '%s' -> actie ok, touch_owner leeg, speler stil" % [tag, knop.name],
			actie_ok and owner == "" and not beweging)


func _test_warp(t: Node, hal: Node2D, tc: Control) -> void:
	var warp := hal.get_node_or_null("HubBoot/Scherm/WarpView")
	t.check("F6-T02: WarpView in hub", warp != null)
	if warp == null or tc == null:
		return
	warp.call("open")
	await t.pframes(8)
	var wm1 := warp.find_child("Rij_WM1", true, false) as BaseButton
	var terug := warp.find_child("Terug", true, false) as BaseButton
	t.check("F6-T02: WM1-rij en Terug aanwezig", wm1 != null and terug != null and not wm1.disabled)
	if wm1 == null:
		return
	await _touch_knop(t, hal, tc, wm1, "warp", func() -> bool:
			return int(warp.get("_step")) == STEP_PLACES and str(warp.get("_wm_id")) == "WM1")
	if terug != null and not terug.disabled and bool(warp.visible):
		await _touch_knop(t, hal, tc, terug, "warp", func() -> bool:
				return not bool(warp.visible))


func _test_party(t: Node, hal: Node2D, tc: Control) -> void:
	var warp := hal.get_node_or_null("HubBoot/Scherm/WarpView")
	if warp != null and bool(warp.visible):
		warp.call("close")
		await t.pframes(4)
	var party := hal.get_node_or_null("HubBoot/Scherm/PartySelect")
	t.check("F6-T02: PartySelect in hub", party != null)
	if party == null or tc == null:
		return
	party.call("open")
	await t.pframes(8)
	var sluit := party.find_child("Sluiten", true, false) as BaseButton
	t.check("F6-T02: Party Close-knop", sluit != null and not sluit.disabled)
	if sluit == null:
		return
	await _touch_knop(t, hal, tc, sluit, "party", func() -> bool:
			return not bool(party.call("is_open")))


func run(t: Node) -> void:
	var hal := await _laad_hal(t)
	if hal == null:
		return
	var tc: Control = await _prep_touch(t, hal)
	if tc == null:
		return
	await _test_warp(t, hal, tc)
	await _test_party(t, hal, tc)