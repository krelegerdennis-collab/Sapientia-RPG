extends RefCounted
## F6-T10: tekstvak met 4+ keuzes. Regels zijn 25 hoog (~48 dp, UiTouch.TOUCH_MIN) zolang het vak dan nog
## in het veilige gebied past; een lange namenlijst (8 keuzes) valt terug op CHOICE_ROW_MANY (20) en past nog.
## Profielen 16:9, 19,5:9 en notch via insets_override. Wordt geladen door scripts/tests/f6_ux2_tests.gd (map-scan).

const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const NAME_TAB_H := 11.0
## [profiel, insets (links, boven, rechts, onder)]
const CASES := [
	["16x9", Vector4.ZERO],
	["19_5x9", Vector4(30, 0, 30, 0)],
	["19_5x9_notch", Vector4(22, 4, 10, 6)],
]
const FOUR := ["Wilgendal", "Archief", "Molen", "Back"]
## Zoals book_point.ask_slot(): vier slots + Back.
const SLOTS := ["*Slot 1: Dax Lv 4  Wilgendal  0:42", "Slot 2: empty", "Slot 3: Seren Lv 2  Molen  0:10",
		"Slot 4: empty", "Back"]
const NAMES := ["Dax", "Seren", "Vesper", "Kael Voss", "Orion", "Mira", "Tobias", "Back"]


func needs_game() -> bool:
	return false


func _ask(t: Node, q: String, opts: Array) -> void:
	await t.sc.close_all()
	Dialog.chars_per_second = 1000.0
	Dialog.ask(q, opts)
	await t.pframes(8)


func _box_ok(t: Node) -> bool:
	var safe: Rect2 = t.safe()
	var box: Rect2 = Dialog.box_rect()
	return t.within(box, safe) and box.position.y >= NAME_TAB_H + safe.position.y - 0.5


func _rows(opts: Array) -> Dictionary:
	var rects: Array[Rect2] = Dialog.choice_rects()
	var min_h := INF
	var inside := rects.size() == opts.size()
	var stacked := inside
	for i in rects.size():
		min_h = minf(min_h, rects[i].size.y)
		inside = inside and Dialog.box_rect().grow(0.5).encloses(rects[i])
		if i > 0:
			stacked = stacked and rects[i].position.y >= rects[i - 1].end.y - 0.01
	return {"n": rects.size(), "min_h": min_h, "inside": inside, "stacked": stacked}


func run(t: Node) -> void:
	for cs in CASES:
		await t.sc.set_profile(cs[0])
		UiTouchC.insets_override = cs[1]
		await t.pframes(2)
		var tag := "F6-T10 [%s insets %s]" % [cs[0], cs[1]]
		for opts in [FOUR, SLOTS]:
			await _ask(t, "Save to which slot?" if opts == SLOTS else "Where to?", opts)
			var r := _rows(opts)
			t.check("%s %d keuzes: onder elkaar, binnen het vak (%d regels)" % [tag, opts.size(), r["n"]],
					bool(r["stacked"]) and bool(r["inside"]))
			t.check("%s %d keuzes: elke regel >= %d hoog (kleinste %.1f)" % [tag, opts.size(), int(UiTouchC.TOUCH_MIN), r["min_h"]],
					float(r["min_h"]) >= UiTouchC.TOUCH_MIN - 0.01)
			t.check("%s %d keuzes: vak %s (+ naamtabje) binnen safe %s" % [tag, opts.size(), Dialog.box_rect(), t.safe()], _box_ok(t))
			await t.shot("f6_19_%d_%s" % [opts.size(), cs[0]])
		# lange namenlijst: past niet met 25, dus 20 (zoals voor F6-T10), en het vak past nog
		await _ask(t, "Who?", NAMES)
		var rn := _rows(NAMES)
		t.check("%s 8 keuzes: terug naar CHOICE_ROW_MANY (kleinste %.1f, choice_row_h %.0f)" % [tag, rn["min_h"], Dialog.choice_row_h(Dialog.box_rect().size.x)],
				bool(rn["stacked"]) and bool(rn["inside"]) and float(rn["min_h"]) >= Dialog.CHOICE_ROW_MANY - 0.01
				and is_equal_approx(Dialog.choice_row_h(Dialog.box_rect().size.x), Dialog.CHOICE_ROW_MANY))
		t.check("%s 8 keuzes: vak %s binnen safe %s" % [tag, Dialog.box_rect(), t.safe()], _box_ok(t))
		# tik op de vierde keuze kiest die keuze (tikvlak = de regel)
		await _ask(t, "Where to?", FOUR)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		Dialog._choice_labels[3].gui_input.emit(ev)
		t.check("%s 4 keuzes: tik op de vierde kiest die" % tag, Dialog.choice_result == 3)
		await t.sc.close_all()
	# 3 keuzes of minder: ongewijzigd 25 (CHOICE_ROW_TOUCH), los van de breedte
	await t.sc.set_profile("16x9")
	UiTouchC.insets_override = null
	await _ask(t, "Save your progress?", ["Yes", "No"])
	t.check("F6-T10 2 keuzes: choice_row_h blijft CHOICE_ROW_TOUCH",
			is_equal_approx(Dialog.choice_row_h(), Dialog.CHOICE_ROW_TOUCH) and is_equal_approx(Dialog.choice_row_h(100.0), Dialog.CHOICE_ROW_TOUCH))
	await t.sc.close_all()
