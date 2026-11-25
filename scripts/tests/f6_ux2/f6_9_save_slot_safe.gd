extends RefCounted
## Save-slotlijst en laadscherm: het venster staat in het midden van UiTouch.safe_rect.
## Profielen 16:9, 19,5:9 en een notch via insets_override. Bij insets 0 (null én Vector4.ZERO)
## blijft de plek pixelgelijk aan centreren op de volle ouder.
## Wordt geladen door scripts/tests/f6_ux2_tests.gd (map-scan); geen aparte suite-registratie.

const SaveSlotListS := preload("res://scripts/ui/save_slot_list.gd")
const LoadScreenS := preload("res://scripts/ui/load_screen.gd")
const UiMenuS := preload("res://scripts/ui/ui_menu.gd")

## [profiel, insets (links, boven, rechts, onder)]
const CASES := [
	["16x9", Vector4(30, 0, 30, 0)],
	["19_5x9", Vector4(30, 0, 30, 0)],
	["19_5x9_notch", Vector4(22, 4, 10, 6)],
]
const ZERO_PROFILES: Array[String] = ["16x9", "19_5x9"]


func needs_game() -> bool:
	return false


static func _same(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= 0.01 and absf(a.y - b.y) <= 0.01


## Midden van safe, daarna dezelfde klem als save_slot_list (past het niet, dan tegen de rand).
static func _safe_pos(safe: Rect2, venster_size: Vector2) -> Vector2:
	var pos := (safe.position + (safe.size - venster_size) / 2.0).floor()
	pos.x = clampf(pos.x, safe.position.x, maxf(safe.position.x, safe.end.x - venster_size.x))
	pos.y = clampf(pos.y, safe.position.y, maxf(safe.position.y, safe.end.y - venster_size.y))
	return pos


static func _sized(n: Node, skip: Array, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control and not skip.has(n):
		var c := n as Control
		if c.size.x > 1.0 and c.size.y > 1.0:
			out.append(c)
	for ch in n.get_children():
		_sized(ch, skip, out)


func _open_list(t: Node) -> Array:
	var layer := CanvasLayer.new()
	layer.layer = 80
	t.get_tree().root.add_child(layer)
	var host := Control.new()
	host.name = "SlotHost"
	host.theme = load(UiMenuS.THEME_PATH)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	var list = SaveSlotListS.new()
	host.add_child(list)
	return [layer, list]


func _assert_placed(t: Node, list: Node, tag: String, zero: bool) -> void:
	var venster := list.get("venster") as Control
	var dim := list.get("dim") as Control
	var lijst := list as Control
	var vp: Vector2 = t.get_viewport().get_visible_rect().size
	var safe: Rect2 = UiTouch.safe_rect(vp, t.get_viewport())
	t.check("%s: venster en dim bestaan, vier slots + autosave" % tag,
			venster != null and dim != null and (list.get("slot_buttons") as Array).size() == 4
			and list.get("autosave_button") != null)
	if venster == null or dim == null:
		return
	t.check("%s: lijst vult de viewport %s (is %s)" % [tag, vp, lijst.size], lijst.size.distance_to(vp) < 1.0)
	var dim_r := dim.get_global_rect()
	t.check("%s: dim bedekt het scherm %s (venster blijft in safe)" % [tag, dim_r],
			dim_r.position.length() < 1.0 and dim_r.size.distance_to(vp) < 1.0)
	if zero:
		var legacy := ((lijst.size - venster.size) / 2.0).floor()
		t.check("%s: insets 0, venster %s == midden van de ouder %s" % [tag, venster.position, legacy],
				_same(venster.position, legacy))
		t.check("%s: insets 0, globaal %s == lokaal + oorsprong %s" % [tag, venster.global_position, legacy + lijst.global_position],
				_same(venster.global_position, legacy + lijst.global_position))
	else:
		var want := _safe_pos(safe, venster.size)
		t.check("%s: venster globaal %s == midden van safe_rect %s" % [tag, venster.global_position, want],
				_same(venster.global_position, want))
		var full := ((vp - venster.size) / 2.0).floor()
		var ins := UiTouch.insets(t.get_viewport())
		if absf(ins.x - ins.z) > 0.5 or absf(ins.y - ins.w) > 0.5:
			t.check("%s: asymmetrische insets schuiven weg van het volle midden %s" % [tag, full],
					not _same(venster.global_position, full))
	var ctl: Array = []
	_sized(list, [list, dim], ctl)
	var buiten: Array = []
	for c in ctl:
		var r: Rect2 = (c as Control).get_global_rect()
		if not t.within(r, safe):
			buiten.append("%s %s" % [(c as Control).name, r])
	t.check("%s: %d controls binnen safe %s (buiten: %s)" % [tag, ctl.size(), safe, buiten.slice(0, 4)],
			ctl.size() >= 6 and buiten.is_empty())


func _check_list(t: Node, tag: String, zero: bool, shot: String) -> void:
	var opened: Array = _open_list(t)
	await t.pframes(6)
	_assert_placed(t, opened[1], tag + " slotlijst", zero)
	if shot != "":
		await t.shot(shot)
	(opened[0] as Node).queue_free()
	await t.pframes(2)


func _check_load(t: Node, tag: String, zero: bool, shot: String) -> void:
	var ls = LoadScreenS.new()
	t.get_tree().root.add_child(ls)
	await t.pframes(6)
	var inner: Node = ls.get("list")
	t.check("%s: laadscherm heeft een slotlijst" % tag, inner != null)
	if inner != null:
		_assert_placed(t, inner, tag + " laadscherm", zero)
	if shot != "":
		await t.shot(shot)
	ls.queue_free()
	await t.pframes(2)


func run(t: Node) -> void:
	UiTouch.insets_override = null
	for prof in ZERO_PROFILES:
		await t.sc.set_profile(prof)
		UiTouch.insets_override = null
		await t.pframes(2)
		var tag := "F6-9 [%s insets 0]" % prof
		var shot := "f6_9_list_16x9_zero" if prof == "16x9" else ""
		await _check_list(t, tag, true, shot)
		await _check_load(t, tag, true, "")
	await t.sc.set_profile("16x9")
	UiTouch.insets_override = Vector4.ZERO
	await t.pframes(2)
	await _check_list(t, "F6-9 [16x9 Vector4.ZERO]", true, "")
	for cs in CASES:
		await t.sc.set_profile(cs[0])
		UiTouch.insets_override = cs[1]
		await t.pframes(2)
		var tag2 := "F6-9 [%s insets %s]" % [cs[0], cs[1]]
		var shot2 := "f6_9_list_%s" % str(cs[0])
		var shot_load := "f6_9_load_19_5x9_notch" if str(cs[0]) == "19_5x9_notch" else ""
		await _check_list(t, tag2, false, shot2)
		await _check_load(t, tag2, false, shot_load)
	# Zelfde viewport (19,5:9), alleen de insets wisselen: het venster moet opnieuw centreren.
	await t.sc.set_profile("19_5x9")
	UiTouch.insets_override = Vector4(30, 0, 30, 0)
	await t.pframes(2)
	var live: Array = _open_list(t)
	await t.pframes(6)
	_assert_placed(t, live[1], "F6-9 [live 19_5x9 insets 30]", false)
	var before: Vector2 = (live[1].get("venster") as Control).global_position
	UiTouch.insets_override = Vector4(22, 4, 10, 6)
	await t.pframes(4)
	_assert_placed(t, live[1], "F6-9 [live notch zonder resize]", false)
	var after: Vector2 = (live[1].get("venster") as Control).global_position
	t.check("F6-9: insets wisselen zonder viewport-resize verplaatst het venster (%s -> %s)" % [before, after],
			not _same(before, after))
	await t.shot("f6_9_list_live_notch")
	(live[0] as Node).queue_free()
	await t.pframes(2)
	UiTouch.insets_override = null
