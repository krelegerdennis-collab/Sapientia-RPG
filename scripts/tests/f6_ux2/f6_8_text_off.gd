extends RefCounted
## F6-8: grijze UI-tekst (UiStyle.TEXT_OFF) haalt >= 4,5:1 contrast op de vensterinkt (INK).
## Plus: de Save-regel in het veldmenu ('Save: Find a glowing book') gebruikt die kleur en is
## op 19,5:9 met notch volledig leesbaar (niet afgekapt, binnen het veilige gebied).

const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const MIN_CONTRAST := 4.5


func run(t: Node) -> void:
	var c: float = t.contrast(UiStyle.TEXT_OFF, UiStyle.INK)
	t.check("F6-8 contrast TEXT_OFF #%s op INK #%s = %.2f (>= %.1f)" % [UiStyle.TEXT_OFF.to_html(false),
			UiStyle.INK.to_html(false), c, MIN_CONTRAST], c >= MIN_CONTRAST)
	t.check("F6-8 MenuColors.TEXT_OFF blijft alias van UiStyle.TEXT_OFF", MenuColors.TEXT_OFF == UiStyle.TEXT_OFF)
	t.check("F6-8 TEXT_OFF blijft donkerder dan TEXT_DIM (uitgeschakeld blijft herkenbaar)",
			t._lum(UiStyle.TEXT_OFF) < t._lum(UiStyle.TEXT_DIM))
	for p in ["16x9", "19_5x9_notch"]:
		await t.sc.set_profile(p)
		await t.sc.open("menu_main")
		var m: Node = t.sc.field_menu()
		t.check("F6-8 [%s] veldmenu open" % p, m != null)
		if m == null:
			continue
		var b: Button = m.buttons.get("save")
		t.check("F6-8 [%s] Save-regel bestaat" % p, b != null)
		if b == null:
			await t.sc.close_all()
			continue
		t.check("F6-8 [%s] Save-regel toont de reden" % p, b.text.contains("Find a glowing book"))
		if not b.has_focus():
			t.check("F6-8 [%s] Save-regel in TEXT_OFF" % p, b.get_theme_color("font_color") == UiStyle.TEXT_OFF)
		t.check("F6-8 [%s] Save-regel niet afgekapt (%.0f breed)" % [p, b.size.x], t.text_fits(b))
		t.check("F6-8 [%s] Save-regel binnen het veilige gebied" % p, t.within(b.get_global_rect(), t.safe()))
		await t.sc.close_all()
