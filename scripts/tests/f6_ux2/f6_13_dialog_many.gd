extends RefCounted
## F6-T10: bij 4+ keuzes minstens CHOICE_ROW_TOUCH (25) als het vak in safe_rect past, anders CHOICE_ROW_MANY (20).
## <=3-keuzes en tekst zonder keuzes blijven pixelgelijk aan finish/wm1 (ballon/staartje/naamtabje onaangetast).

const Scenarios := preload("res://tools/ui_polish/ui_scenarios.gd")

## [profiel, insets (links, boven, rechts, onder)]
const CASES := [
	["16x9", Vector4(30, 0, 30, 0)],
	["19_5x9", Vector4(30, 0, 30, 0)],
	["19_5x9_notch", Vector4(22, 4, 10, 6)],
]

## Gemeten op finish/wm1 (vóór F6-T10): 16:9, geen insets_override, na start_game.
const BASELINE_NARRATOR := {
	"panel_pos": Vector2(8, 15),
	"panel_size": Vector2(368, 44),
	"name_tab_pos": Vector2(6, -11),
	"tail_pos": Vector2(0, 0),
	"tail_visible": false,
	"placement": "boven",
}
const BASELINE_CHOICES3 := {
	"panel_pos": Vector2(8, 15),
	"panel_size": Vector2(368, 46),
	"name_tab_pos": Vector2(6, -11),
	"tail_pos": Vector2(0, 0),
	"tail_visible": false,
	"placement": "boven",
}

## Lijst zoals save-slots (8 regels): forceert 20px-rijen, past binnen smalle safe met insets 30.
const LONG_SLOT_NAMES: Array[String] = [
	"*Slot 1: Dennis Lv 9",
	"Slot 2: Noor Lv 8",
	"Slot 3: Lotte Lv 7",
	"Slot 4: Empty",
	"Slot 5: Dennis Lv 12",
	"Slot 6: Noor Lv 11",
	"Slot 7: Lotte Lv 10",
	"Back",
]


func needs_game() -> bool:
	return true


static func _snap() -> Dictionary:
	return {
		"panel_pos": Dialog.panel.position,
		"panel_size": Dialog.panel.size,
		"name_tab_pos": Dialog.name_tab.position,
		"tail_pos": Dialog.tail.position,
		"tail_visible": Dialog.tail.visible,
		"placement": Dialog.placement,
	}


static func _snap_ok(got: Dictionary, want: Dictionary) -> bool:
	for k in want:
		if not got.has(k):
			return false
		var v = got[k]
		var w = want[k]
		if v is Vector2 and w is Vector2:
			if not is_equal_approx((v as Vector2).x, (w as Vector2).x) or not is_equal_approx((v as Vector2).y, (w as Vector2).y):
				return false
		elif str(v) != str(w):
			return false
	return true


static func _rows_ok(rects: Array, min_h: float) -> bool:
	for r in rects:
		if r.size.y < min_h - 0.01:
			return false
	return not rects.is_empty()


static func _all_within(rects: Array[Rect2], outer: Rect2) -> bool:
	for r in rects:
		if not outer.grow(0.5).encloses(r):
			return false
	return true


func _check_many(t: Node, tag: String, opts: Array, want_touch: bool) -> void:
	Dialog.chars_per_second = 1000.0
	Dialog.ask("Choose.", opts)
	await t.pframes(8)
	var rects: Array[Rect2] = Dialog.choice_rects()
	var min_h := Dialog.CHOICE_ROW_TOUCH if want_touch else Dialog.CHOICE_ROW_MANY
	t.check("%s %d keuzes: elke rij >= %.0f (%s)" % [tag, opts.size(), min_h, rects.map(func(r): return r.size.y)],
			_rows_ok(rects, min_h))
	var safe: Rect2 = t.safe()
	t.check("%s %d keuzes: vak binnen safe %s (vak %s)" % [tag, opts.size(), safe, Dialog.box_rect()],
			t.within(Dialog.box_rect(), safe))
	if not rects.is_empty():
		t.check("%s %d keuzes: rijen binnen het vak" % [tag, opts.size()],
				_all_within(rects, Dialog.box_rect()))
	await t.sc.close_all()


func _check_baselines(t: Node) -> void:
	await t.sc.set_profile("16x9")
	UiTouch.insets_override = null
	await t.sc.open("dialog_narrator")
	await t.pframes(6)
	var nar := _snap()
	print("INFO  F6-T10 baseline narrator %s" % nar)
	t.check("F6-T10 baseline: tekst zonder keuzes ongewijzigd (16:9) %s" % nar, _snap_ok(nar, BASELINE_NARRATOR))
	await t.sc.close_all()
	await t.sc.open("dialog_choices")
	for _i in 30:
		await t.pframes(1)
		if Dialog.phase() == Dialog.PHASE_CHOOSING and Dialog.choice_rects().size() == 3:
			break
	var ch3 := _snap()
	print("INFO  F6-T10 baseline choices3 %s" % ch3)
	t.check("F6-T10 baseline: <=3 keuzes (ballon) ongewijzigd (16:9) %s" % ch3, _snap_ok(ch3, BASELINE_CHOICES3))
	await t.sc.close_all()


func run(t: Node) -> void:
	await _check_baselines(t)
	var four := ["Alpha", "Beta", "Gamma", "Delta"]
	var five := ["One", "Two", "Three", "Four", "Five"]
	for case in CASES:
		var prof: String = case[0]
		var ins: Vector4 = case[1]
		await t.sc.set_profile(prof)
		UiTouch.insets_override = ins
		await t.pframes(2)
		var tag := "[%s]" % prof
		await _check_many(t, tag, four, true)
		await _check_many(t, tag, five, true)
	await t.sc.set_profile("16x9")
	UiTouch.insets_override = Vector4(30, 0, 30, 0)
	await t.pframes(2)
	await _check_many(t, "[16x9 long]", LONG_SLOT_NAMES, false)
	await t.sc.close_all()