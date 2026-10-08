extends Control
## v0.11 Kaartje van één held in het veldmenu (hoofdmenu, doelkeuze bij items/magie):
##   Naam                 Lv 3
##   HP [========    ]  30/42
##   MP [====        ]  10/18
## Zelfde kleuren als het statusvak in het gevecht (UiStyle), maar op het gewone
## 384x216-raster (lijnen van 1 pixel). Tekent zichzelf; vangt geen tikken af
## (mouse_filter IGNORE), zodat hij in een knop kan staan.

## v0.14: menukleuren uit één bestand (menu_colors.gd), niet meer de neon van ui_style.gd
const MenuColors := preload("res://scripts/ui/menu_colors.gd")

const HEIGHT := 32
const PAD := 4
const FONT_SIZE := 10
const CHAR_W := 6             # Dauwpixel is monospace: 6 px per teken
const NAME_BASE := 9          # baseline van de naamregel
const HP_TOP := 12
const MP_TOP := 22
const BAR_H := 7
const LABEL_W := 14           # ruimte voor 'HP' / 'MP' voor de balk
const NUM_COLS := 7           # ruimte voor de getallen achter de balk ('999/999')
const NUM_GAP := 3
const CLASS_MIN_W := 150      # pas vanaf deze breedte staat de klasse achter de naam
const CLASS_COLOR := Color("6c6c74")   # tussen TEXT_OFF en TEXT_DIM in
const LOW_HP := 0.25          # onder 25% wordt de HP-balk rood

var hero: Dictionary = {}
## Klasse ('Krijger') achter de naam tonen (het statusscherm heeft hem al onder het portret).
var show_class := true


func setup(hero_data: Dictionary) -> void:
	hero = hero_data
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = HEIGHT
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if hero.is_empty():
		return
	var font := get_theme_default_font()
	var w := size.x
	var ko := int(hero["hp"]) <= 0
	var name_col: Color = MenuColors.KO if ko else MenuColors.hero_color(str(hero.get("accent", "")))
	var hero_name := str(hero["name"])
	_text(font, Vector2(PAD, NAME_BASE), hero_name, name_col)
	if show_class and w >= CLASS_MIN_W and str(hero.get("class", "")) != "":
		_text(font, Vector2(PAD + CHAR_W * (hero_name.length() + 1), NAME_BASE), str(hero["class"]), CLASS_COLOR)
	var lv := "Lv %d" % int(hero["level"])
	_text(font, Vector2(w - PAD - CHAR_W * lv.length(), NAME_BASE), lv, MenuColors.TEXT_DIM)
	var max_hp := float(hero["max_hp"])
	var hp_cols: Array = MenuColors.BAR_LOW if float(hero["hp"]) < max_hp * LOW_HP else MenuColors.BAR_HP
	_stat_row(font, HP_TOP, "HP", float(hero["hp"]), max_hp, hp_cols, true)
	_stat_row(font, MP_TOP, "MP", float(hero["mp"]), float(hero["max_mp"]), MenuColors.BAR_MP, int(hero["max_mp"]) > 0)


func _stat_row(font: Font, top: float, label: String, value: float, max_value: float,
		cols: Array, enabled: bool) -> void:
	var w := size.x
	_text(font, Vector2(PAD, top + BAR_H), label, MenuColors.TEXT_DIM if enabled else MenuColors.TEXT_OFF)
	var num_w := CHAR_W * NUM_COLS
	var r := Rect2(PAD + LABEL_W, top, w - PAD * 2 - LABEL_W - num_w - NUM_GAP, BAR_H)
	draw_rect(r, MenuColors.BAR_EDGE)
	var inner := r.grow(-1)
	draw_rect(inner, MenuColors.BAR_EMPTY)
	if enabled and max_value > 0.0 and value > 0.0:
		var fw := maxf(1.0, roundf(inner.size.x * clampf(value / max_value, 0.0, 1.0)))
		draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), cols[1])
		draw_rect(Rect2(inner.position, Vector2(fw, 1)), cols[0])
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(fw, 1)), cols[2])
	var txt := "%d/%d" % [roundi(value), int(max_value)] if enabled else "--"
	# getallen rechts naast de balk, rechts uitgelijnd
	var tw := CHAR_W * txt.length()
	var base := Vector2(w - PAD - tw, top + BAR_H)
	_text(font, base, txt, MenuColors.TEXT if enabled else MenuColors.TEXT_OFF)


## Tekst met 1 px schaduw (zoals de labels in het thema).
func _text(font: Font, baseline: Vector2, text: String, color: Color) -> void:
	draw_string(font, baseline + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, MenuColors.SHADOW)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
