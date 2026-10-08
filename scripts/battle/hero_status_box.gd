extends Control
## Statusvak van één held onderaan het gevechtsscherm ('De Vergeten Bibliotheek', v7).
## Zoals de mockup: donker vak met dunne lichtgrijze rand, de naam, en twee regels
##   HP [=========  42/42 ]
##   MP [=====      18/18 ]
## met de getallen OP de balk. Kleuren:
##   - naam lichtgrijs; magenta + gloed = deze held kiest nu een commando; rood-grijs = KO
##   - HP-balk grijs; magenta (met gloed) voor de held die aan de beurt is; rood bij < 25%
##   - MP-balk cyaan; helden zonder MP (max_mp = 0, zoals Dennis) krijgen een lege balk met '--'
##   - rand: magenta neon = aan de beurt, cyaan (pulserend) = wordt gekozen als doelwit
## v0.13: kleuren uit het gedeelde palet (scripts/ui/ui_style.gd, 'Inkt & Perkament'):
##   vak = inkt met rustige gouden rand; aan de beurt = goud (HILITE) + zachte gloed;
##   doelwit = teal (pulserend); HP-balk warm rood (oranje bij < 25%), MP-balk teal.
## De balken lopen rustig naar de nieuwe waarde (animatie).
## Tik op het vak -> signaal 'tapped' (bij het kiezen van een held als doelwit).

signal tapped

const HEIGHT := 37
const PAD := 5

var hero: Dictionary = {}      # verwijst naar GameState.party[i]
var active := false            # kiest nu een commando
var targeted := false          # wordt gekozen als doelwit
var shown_hp := 0.0            # getoonde waarde (loopt naar de echte waarde)
var shown_mp := 0.0
var _flash_color := Color(0, 0, 0, 0)
var _flash_t := 0.0
var _style: StyleBox


func setup(hero_data: Dictionary) -> void:
	hero = hero_data
	shown_hp = float(hero["hp"])
	shown_mp = float(hero["mp"])
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = UiStyle.panel("status")      # v0.13: palet i.p.v. de oude panel_status-textuur


func has_mp() -> bool:
	return int(hero.get("max_mp", 0)) > 0


## Zijn de balken klaar met bewegen? (handig voor de autotest)
func is_settled() -> bool:
	return is_equal_approx(shown_hp, float(hero["hp"])) and is_equal_approx(shown_mp, float(hero["mp"]))


## Welke kleur heeft de HP-balk nu? ("hp" of "laag" bij < 25%; voor de autotest)
func hp_bar_kind() -> String:
	if shown_hp < float(hero["max_hp"]) * 0.25:
		return "laag"
	return "hp"


## Kleur van de naam: magenta als de held aan de beurt is (zoals de mockup).
func name_color() -> Color:
	if int(hero["hp"]) <= 0:
		return UiStyle.KO
	return UiStyle.HILITE if active else UiStyle.TEXT


func flash(color: Color) -> void:
	_flash_color = color
	_flash_t = 0.35


func _process(delta: float) -> void:
	var changed := false
	shown_hp = _approach(shown_hp, float(hero["hp"]), float(hero["max_hp"]), delta)
	shown_mp = _approach(shown_mp, float(hero["mp"]), float(hero["max_mp"]), delta)
	if not is_settled():
		changed = true
	if _flash_t > 0.0:
		_flash_t -= delta
		changed = true
	if targeted or active:
		changed = true             # pulserende rand / gloed
	if changed:
		queue_redraw()


func _approach(current: float, target: float, max_value: float, delta: float) -> float:
	var speed := maxf(max_value, 10.0) * 1.4 * delta     # volle balk in ~0,7 sec
	if absf(target - current) <= speed:
		return target
	return current + signf(target - current) * speed


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
		accept_event()


## v0.10: de speler kiest zelf een naam (max. 10 tekens). Past die niet in het vak (bv. met
## 4 helden), dan wordt hij ingekort met een puntje.
func fitted_name(font: Font = null) -> String:
	if font == null:
		font = get_theme_default_font()
	var n := str(hero.get("name", ""))
	var avail := size.x - PAD * 2.0
	if font == null or avail <= 0.0 or font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= avail:
		return n
	while n.length() > 1 and font.get_string_size(n + ".", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > avail:
		n = n.left(n.length() - 1)
	return n + "."


# ---------------------------------------------------------------- tekenen
func _draw() -> void:
	if hero.is_empty():
		return
	var w := size.x
	var ko: bool = int(hero["hp"]) <= 0
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
	# neon-gloed rond het vak (achter de rand)
	if active or targeted:
		var c := UiStyle.HILITE if active and not targeted else UiStyle.TEAL
		draw_rect(Rect2(-1, -1, w + 2, HEIGHT + 2), Color(c.r, c.g, c.b, 0.22 * pulse), false, 1.0)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	if ko:
		draw_rect(Rect2(3, 3, w - 6, HEIGHT - 6), Color(0, 0, 0, 0.3))
	# rand: magenta = aan de beurt, cyaan (pulserend) = gekozen als doelwit.
	# Lijnen van een halve eenheid = 1 echte pixel op het 2x-raster van het gevecht.
	if targeted:
		var cy := UiStyle.TEAL
		draw_rect(Rect2(1.25, 1.25, w - 2.5, HEIGHT - 2.5), Color(cy.r, cy.g, cy.b, pulse), false, 0.5)
		draw_rect(Rect2(1.75, 1.75, w - 3.5, HEIGHT - 3.5), Color(cy.r, cy.g, cy.b, 0.35 * pulse), false, 0.5)
	elif active:
		var hl := UiStyle.HILITE
		draw_rect(Rect2(1.25, 1.25, w - 2.5, HEIGHT - 2.5), hl, false, 0.5)
		draw_rect(Rect2(1.75, 1.75, w - 3.5, HEIGHT - 3.5), Color(hl.r, hl.g, hl.b, 0.35), false, 0.5)
	var font := get_theme_default_font()
	var name_col := name_color()
	var shown_name := fitted_name(font)
	if active and not ko:
		# zachte gloed achter de naam
		draw_string_outline(font, Vector2(PAD, 11), shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 2,
				Color(UiStyle.HILITE.r, UiStyle.HILITE.g, UiStyle.HILITE.b, 0.3 * pulse))
	_text(font, Vector2(PAD, 11), shown_name, name_col)
	# HP- en MP-regel
	var hp_cols: Array = UiStyle.BAR_HP_LOW if hp_bar_kind() == "laag" else UiStyle.BAR_HP
	_stat_row(font, 14, "HP", shown_hp, float(hero["max_hp"]), hp_cols, true, active and not ko)
	_stat_row(font, 24.5, "MP", shown_mp, float(hero["max_mp"]), UiStyle.BAR_MP, has_mp(), false)
	if _flash_t > 0.0:
		var c := _flash_color
		c.a = 0.45 * (_flash_t / 0.35)
		draw_rect(Rect2(2, 2, w - 4, HEIGHT - 4), c)


func _stat_row(font: Font, top: float, label: String, value: float, max_value: float,
		bar_colors: Array, enabled: bool, glow: bool) -> void:
	var w := size.x
	_text(font, Vector2(PAD, top + 7), label, UiStyle.TEXT_DIM if enabled else UiStyle.TEXT_OFF)
	var bar_x := PAD + 13.0
	var r := Rect2(bar_x, top + 0.5, w - PAD - bar_x + 1.0, 6.5)
	if glow:
		var g: Color = bar_colors[1]
		draw_rect(r.grow(1.0), Color(g.r, g.g, g.b, 0.25))
	draw_rect(r, UiStyle.BAR_EDGE)
	var inner := Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1, 1))
	draw_rect(inner, UiStyle.BAR_EMPTY if enabled else UiStyle.BAR_EMPTY.darkened(0.2))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 0.5)), UiStyle.BAR_EDGE)
	if enabled and max_value > 0.0 and value > 0.0:
		# vulling in halve eenheden: glans, vulling, schaduwrand (1 fijne pixel per laag)
		var fw := maxf(0.5, roundf(inner.size.x * 2.0 * clampf(value / max_value, 0.0, 1.0)) / 2.0)
		var p := inner.position
		draw_rect(Rect2(p, Vector2(fw, inner.size.y)), bar_colors[1])
		draw_rect(Rect2(p, Vector2(fw, 0.5)), bar_colors[0])
		draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(fw, 0.5)), bar_colors[0].lerp(bar_colors[1], 0.5))
		draw_rect(Rect2(p + Vector2(0, inner.size.y - 1.0), Vector2(fw, 0.5)), bar_colors[1].lerp(bar_colors[2], 0.5))
		draw_rect(Rect2(p + Vector2(0, inner.size.y - 0.5), Vector2(fw, 0.5)), bar_colors[2])
	# getallen OP de balk, rechts uitgelijnd: 'HP 42/42' zoals de mockup
	var txt := "%d/%d" % [roundi(value), int(max_value)] if enabled else "--"
	var tw := 6.0 * txt.length()
	var base := Vector2(r.end.x - 2.0 - tw, top + 7.0)
	# donker 'plaatje' achter de getallen, zodat ze op een felle balk leesbaar blijven
	draw_rect(Rect2(base.x - 1.5, r.position.y + 1.0, tw + 2.5, r.size.y - 2.0), Color(0, 0, 0, 0.45))
	draw_string_outline(font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 1, UiStyle.SHADOW)
	draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.TEXT if enabled else UiStyle.TEXT_OFF)


## Tekst met 1 px schaduw (zoals de labels in het thema).
func _text(font: Font, baseline: Vector2, text: String, color: Color) -> void:
	draw_string(font, baseline + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.SHADOW)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
