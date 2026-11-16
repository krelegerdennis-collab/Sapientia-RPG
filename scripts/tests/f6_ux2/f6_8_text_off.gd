extends RefCounted
## F6-8: grijze UI-tekst (UiStyle.TEXT_OFF) haalt minstens 4,5:1 contrast op INK én op het
## effectieve knopvlak (WCAG AA, sRGB-luminantie). ACCENT_GREY idem; onderscheid >= 1,15 luminantie.
## Plus: de Save-uitleg in het veldmenu ("Save: Find a glowing book") past op smalle/hoge profielen.

const FieldMenuS := preload("res://scripts/ui/field_menu.gd")
const MenuColorsS := preload("res://scripts/ui/menu_colors.gd")

const _BUTTON_PANEL_ALPHA := 0.9


func needs_game() -> bool:
	return true


static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## INK_LIGHT @ panel("button")-alpha over INK-venster (opaque stapeling).
static func effective_button_bg() -> Color:
	var ink_light := UiStyle.INK_LIGHT
	var a := _BUTTON_PANEL_ALPHA
	var inv := 1.0 - a
	return Color(
			ink_light.r * a + UiStyle.INK.r * inv,
			ink_light.g * a + UiStyle.INK.g * inv,
			ink_light.b * a + UiStyle.INK.b * inv,
			1.0)


static func _wcag_pair(t: Node, label: String, fg: Color, bg: Color, bg_name: String) -> void:
	var cr := contrast(fg, bg)
	t.check("F6-8 %s #%s op %s #%s: %.2f:1 >= 4,5:1" % [
			label, fg.to_html(false), bg_name, bg.to_html(false), cr], cr >= 4.5)


func run(t: Node) -> void:
	var btn_bg := effective_button_bg()
	# ijkpunten uit de WCAG-definitie: wit/zwart = 21, gelijk = 1, en de oude waarde ~3,24
	t.check("F6-8 contrastformule: wit op zwart = 21:1", absf(contrast(Color.WHITE, Color.BLACK) - 21.0) < 0.01)
	t.check("F6-8 contrastformule: oude TEXT_OFF 6c6455 op INK ~3,24:1 (%.2f)" % contrast(Color("6c6455"), UiStyle.INK),
			absf(contrast(Color("6c6455"), UiStyle.INK) - 3.24) < 0.02)
	t.check("F6-8 effectief knopvlak = INK_LIGHT 0,9 over INK (#%s)" % btn_bg.to_html(false),
			btn_bg.is_equal_approx(effective_button_bg()))
	_wcag_pair(t, "TEXT_OFF", UiStyle.TEXT_OFF, UiStyle.INK, "INK")
	_wcag_pair(t, "TEXT_OFF", UiStyle.TEXT_OFF, btn_bg, "button")
	_wcag_pair(t, "ACCENT_GREY", MenuColorsS.ACCENT_GREY, UiStyle.INK, "INK")
	_wcag_pair(t, "ACCENT_GREY", MenuColorsS.ACCENT_GREY, btn_bg, "button")
	t.check("F6-8 MenuColors.TEXT_OFF blijft alias van UiStyle.TEXT_OFF", MenuColorsS.TEXT_OFF == UiStyle.TEXT_OFF)
	t.check("F6-8 MenuColors.ACCENT_GREY blijft alias van UiStyle.ACCENT_GREY",
			MenuColorsS.ACCENT_GREY == UiStyle.ACCENT_GREY)
	t.check("F6-8 TEXT_OFF blijft grijzer dan gewone tekst (TEXT)", luminance(UiStyle.TEXT_OFF) < luminance(UiStyle.TEXT))
	var grey_split := luminance(MenuColorsS.ACCENT_GREY) / maxf(luminance(UiStyle.TEXT_OFF), 0.0001)
	t.check("F6-8 ACCENT_GREY helderder dan TEXT_OFF (luminantieverhouding %.2f >= 1,15)" % grey_split, grey_split >= 1.15)
	# Save-uitleg in het veldmenu op smalle/hoge profielen
	for p in ["16x9", "19_5x9_notch", "21x9", "4x3_hoog"]:
		await t.sc.set_profile(p)
		var fm: Node = await t.sc.open_field_menu()
		if fm == null:
			t.check("F6-8 [%s] veldmenu open" % p, false)
			continue
		await t.pframes(4)
		var b: Button = fm.buttons.get("save")
		if b == null:
			t.check("F6-8 [%s] Save-knop in het veldmenu" % p, false)
		else:
			var font: Font = b.get_theme_font("font")
			var fs: int = b.get_theme_font_size("font_size")
			var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var r := b.get_global_rect()
			t.check("F6-8 [%s] Save-uitleg '%s' past in de knop (tekst %.0f <= %.0f) en ligt binnen het veilige gebied %s (%s)"
					% [p, FieldMenuS.SAVE_MENU_REASON, w, b.size.x, t.safe(), r],
					b.text.contains(FieldMenuS.SAVE_MENU_REASON) and w <= b.size.x + 0.5 and t.within(r, t.safe()))
		await t.shot("f6_8_menu_" + p)
		await t.sc.close_field_menu()