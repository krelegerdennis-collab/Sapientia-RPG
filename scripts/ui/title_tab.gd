class_name TitleTab
extends PanelContainer
## Klein titel-tabje boven een venster (zoals 'De Vergeten Bibliotheek' in de mockup).
## v0.13: stijl "tab" uit het palet (scripts/ui/ui_style.gd). Het eerste Label-kind
## is de tekst; het tabje wordt vanzelf zo breed als de tekst.
## hd = true: 2x zo fijne rand voor het gevechtsscherm (768x432, zie hd_ui.gd).

## (preload i.p.v. class_name: dit script wordt al door een autoload geladen)
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const HdUiC := preload("res://scripts/battle/hd_ui.gd")

@export var hd := false
@export var text_color := UiStyleC.TEXT_DIM


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiStyleC.panel("tab")   # v0.13: palet (ui_style.gd)
	add_theme_stylebox_override("panel", sb)
	var lbl := label()
	if lbl:
		lbl.add_theme_color_override("font_color", text_color)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func label() -> Label:
	for c in get_children():
		if c is Label:
			return c
	return null


func set_text(t: String) -> void:
	var lbl := label()
	if lbl:
		lbl.text = t
	size = Vector2.ZERO
	reset_size()


func set_color(c: Color) -> void:
	var lbl := label()
	if lbl:
		lbl.add_theme_color_override("font_color", c)
