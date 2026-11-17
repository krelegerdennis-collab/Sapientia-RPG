extends RefCounted
## F6-1: Settings > General past op 16:9, 19,5:9 en 19,5:9 met notch (UiTouch.insets_override 22/4/10/6).
## Per profiel: de laatste regel van kolom A en van kolom B (na erheen gaan met de focus, scrollen mag)
## en het hint-label liggen binnen UiTouch.safe_rect en binnen het zichtbare deel van de lijst;
## elke regel en elke '<'/'>' heeft een echt tikvlak >= TOUCH_MIN; geen nieuwe of verdwenen opties.

const OptionsS := preload("res://scripts/ui/options_screen.gd")
const PROFILES: Array[String] = ["16x9", "19_5x9", "19_5x9_notch"]


func needs_game() -> bool:
	return true


static func touch_rect(c: Control) -> Rect2:
	if c.has_method("touch_rect_global"):
		return c.touch_rect_global()
	return c.get_global_rect()


## Rechthoek waarbinnen een regel echt te zien is: de knippende ouder (ScrollContainer) of het hele scherm.
static func view_rect(c: Control, fallback: Rect2) -> Rect2:
	var n := c.get_parent()
	while n != null and n is Control:
		if (n as Control).clip_contents:
			return (n as Control).get_global_rect()
		n = n.get_parent()
	return fallback


func run(t: Node) -> void:
	for p in PROFILES:
		await t.sc.set_profile(p)
		var tag := "F6-1 [%s]" % p
		if not await t.sc.open("menu_options"):
			t.check(tag + " Settings open", false)
			continue
		var fm: Node = t.sc.field_menu()
		var o: Node = fm.sub if fm != null else null
		if o == null or o.get("rows") == null:
			t.check(tag + " Settings-scherm gevonden", false)
			await t.sc.close_all()
			continue
		await t.pframes(4)
		var safe: Rect2 = t.safe()
		# het zichtbare venster (rand van het menuscherm) binnen het veilige gebied
		var frame: Rect2 = (o._bg as Control).get_global_rect().intersection(safe)
		var screen := Rect2(Vector2.ZERO, t.get_viewport().get_visible_rect().size)
		var rows: Array = o.rows
		var shown: int = OptionsS.ROWS.filter(func(r): return not (str(r[0]) == "crt" and t.get_node_or_null("/root/Crt") == null)).size()
		t.check("%s General: %d regels (zelfde set opties als ROWS: %d)" % [tag, rows.size(), shown], rows.size() == shown)
		# hint-label
		var hint: Label = o.hint
		var hr := hint.get_global_rect()
		t.check("%s hint-label '%s' zichtbaar en binnen het venster/veilige gebied %s (%s)" % [tag, hint.text.left(24), frame, hr],
				hint.is_visible_in_tree() and hr.size.y > 0.0 and t.within(hr, frame))
		# laatste regel van kolom A en B: erheen met de focus (zoals de joystick), dan meten
		var col_a: Array = []
		var col_b: Array = []
		for b in rows:
			var line: Node = (b as Control).get_parent()
			(col_a if line.get_parent() == o._col_a else col_b).append(b)
		for pair in [["A", col_a], ["B", col_b]]:
			var col: Array = pair[1]
			if col.is_empty():
				t.check("%s kolom %s heeft regels" % [tag, pair[0]], false)
				continue
			var last: Button = col[-1]
			last.grab_focus()
			await t.pframes(4)
			var line_r := (last.get_parent() as Control).get_global_rect()
			var view := view_rect(last, screen)
			t.check("%s kolom %s laatste regel '%s' %s binnen het venster/veilige gebied en zichtbaar in de lijst %s"
					% [tag, pair[0], last.text.strip_edges(), line_r, view],
					t.within(line_r, frame) and t.within(line_r, view))
			await t.shot("f6_1_%s_col%s" % [p, pair[0]])
		# alle regels horizontaal binnen het venster; ook met de release-tekst "Debug only" bij Session Log
		for pass_name in ["", "Debug only"]:
			if pass_name != "" and o.value_labels.has("sessie_log"):
				(o.value_labels["sessie_log"] as Label).text = pass_name
				await t.pframes(3)
			var wide: Array = []
			for b in rows:
				var lr := ((b as Control).get_parent() as Control).get_global_rect()
				if lr.position.x < frame.position.x - 0.5 or lr.end.x > frame.end.x + 0.5:
					wide.append("%s %s" % [(b as Button).text.strip_edges(), lr])
			t.check("%s alle regels horizontaal binnen het venster %s%s (te breed: %s)"
					% [tag, frame, " (Session Log = '%s')" % pass_name if pass_name != "" else "", wide], wide.is_empty())
		o.refresh_values()
		await t.pframes(2)
		# hint nog steeds binnen beeld na het scrollen
		t.check("%s hint-label blijft binnen het venster na scrollen" % tag, t.within(hint.get_global_rect(), frame))
		# tikvlakken: regel + '<' + '>' (alleen die in beeld)
		var small: Array = []
		var n := 0
		for b in rows:
			for c in (b as Control).get_parent().get_children():
				if not (c is Button) or not (c as Control).is_visible_in_tree():
					continue
				var g := (c as Control).get_global_rect()
				if not view_rect(c, screen).grow(0.5).encloses(g):
					continue
				n += 1
				var r := touch_rect(c)
				if not UiTouch.big_enough(r):
					small.append("%s %s" % [(c as Button).text.strip_edges(), r.size])
		t.check("%s %d knoppen in beeld, allemaal tikvlak >= %d (te klein: %s)" % [tag, n, int(UiTouch.TOUCH_MIN), small],
				n > 0 and small.is_empty())
		await t.sc.close_all()
