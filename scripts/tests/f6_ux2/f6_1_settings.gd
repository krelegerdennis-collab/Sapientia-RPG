extends RefCounted
## F6-1: Instellingen > General. Alle regels (laatste van kolom A en B) en de hulpregel binnen
## UiTouch.safe_rect op 16:9, 19,5:9 en 19,5:9+notch (en 21:9 / 4:3 hoog als extra), zonder scrollen.
## Anders dan de menutest kijkt dit ook of de hulpregel zelf in beeld en binnen het venster staat.

const OptionsScreen := preload("res://scripts/ui/options_screen.gd")
const PROFILES: Array[String] = ["16x9", "19_5x9", "19_5x9_notch", "21x9", "4x3_hoog"]


func run(t: Node) -> void:
	t.check("F6-1 OPTION_ROW_H = %d (7 regels + tabbalk passen in 154 hoog)" % OptionsScreen.OPTION_ROW_H,
			OptionsScreen.TAB_BAR_H + 2 + 7 * OptionsScreen.OPTION_ROW_H <= 154)
	for p in PROFILES:
		await t.sc.set_profile(p)
		await t.sc.open("menu_options")
		var m: Node = t.sc.field_menu()
		var s: Node = m.sub if m != null else null
		var tag := "F6-1 [%s]" % p
		t.check(tag + " Settings opent", s != null and is_instance_valid(s))
		if s == null:
			await t.sc.close_all()
			continue
		var veilig: Rect2 = t.safe()
		var col_a: VBoxContainer = s.get("_col_a")
		var col_b: VBoxContainer = s.get("_col_b")
		var hint: Label = s.get("hint")
		t.check(tag + " 14 regels, verdeeld 7 + 7", s.rows.size() == 14 and col_a.get_child_count() == 7
				and col_b.get_child_count() == 7)
		t.check(tag + " General scrolt niet (geen ScrollContainer om de kolommen)",
				not _in_scroll(s.get("general_box") as Node))
		for col in [col_a, col_b]:
			var laatste: Control = (col as VBoxContainer).get_child((col as VBoxContainer).get_child_count() - 1) as Control
			var naam := _row_name(laatste)
			t.check(tag + " laatste regel '%s' %s binnen safe_rect %s" % [naam, laatste.get_global_rect(), veilig],
					t.within(laatste.get_global_rect(), veilig))
			t.check(tag + " laatste regel '%s' boven de hulpregel" % naam,
					laatste.get_global_rect().end.y <= hint.get_global_rect().position.y + 0.01)
		t.check(tag + " hulpregel %s binnen safe_rect" % [hint.get_global_rect()], t.within(hint.get_global_rect(), veilig))
		var bg: Control = s.get("_bg")
		t.check(tag + " hulpregel binnen het venster (niet over de rand)",
				bg == null or t.within(hint.get_global_rect(), bg.get_global_rect()))
		var bad: Array[String] = []
		for b in s.rows:
			var line := (b as Control).get_parent() as Control
			if not t.within(line.get_global_rect(), veilig):
				bad.append(_row_name(line))
		t.check(tag + " alle regels binnen safe_rect %s" % [bad], bad.is_empty())
		print("INFO  %s regelhoogte %.0f (TOUCH_MIN %.0f), hulpregel %s" % [tag, (s.rows[0] as Control).size.y,
				UiTouch.TOUCH_MIN, hint.get_global_rect()])
		await t.sc.close_all()


func _in_scroll(n: Node) -> bool:
	var p := n.get_parent() if n != null else null
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _row_name(line: Control) -> String:
	for k in line.get_children():
		if k is Button:
			return str((k as Button).get_meta("label", (k as Button).text))
	return str(line.name)
