extends RefCounted
## Tip-venster links (boven de D-pad); uit battle.gd gehaald, gedrag ongewijzigd.
## battle.gd roept dit aan via dunne wrappers met de oude namen (sim en tests roepen die).

const UiTouchC := preload("res://scripts/ui/ui_touch.gd")

var battle  # scripts/battle/battle.gd root (geen class_name)


func _init(b) -> void:
	battle = b


func make_tip() -> void:
	battle.tip_panel = Panel.new()
	battle.tip_panel.name = "TipPanel"
	# v0.16: tutorialtekst in hetzelfde blauwe vak als de verteller (Lufia 2-stijl)
	battle.tip_panel.add_theme_stylebox_override("panel", UiStyle.blue_box("vak", Vector4.ZERO))
	battle.tip_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	battle.tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.add_child(battle.tip_panel)
	battle.tip_label = Label.new()
	battle.tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle.tip_label.add_theme_color_override("font_color", UiStyle.BOX_TEXT)
	battle.tip_label.add_theme_color_override("font_shadow_color", UiStyle.BOX_SHADOW)
	battle.tip_panel.add_child(battle.tip_label)
	battle.tip_panel.hide()


func tip_text(hero: Dictionary) -> String:
	var hurt := int(hero["s"]["hp"]) < int(hero["s"]["max_hp"])
	if battle.round_no <= 1 or not hurt or battle._available_items().is_empty():
		battle.tips_shown["aanval"] = true
		return "TIP: Attack, then the Moss Slime."
	battle.tips_shown["item"] = true
	return "TIP: hurt? Item > Herb gives HP back."


func show_tip(hero: Dictionary) -> void:
	if battle.tip_panel == null:
		return
	battle.tip_label.text = tip_text(hero)
	var w := 132.0
	battle.tip_label.position = Vector2(7, 5)
	battle.tip_label.custom_minimum_size = Vector2(w - 14, 0)
	battle.tip_label.size = Vector2(w - 14, 0)
	# Hoogte uit het lettertype zelf (een Label met autowrap meldt bij breedte 0 per letter een regel).
	var font: Font = battle.tip_label.get_theme_font("font")
	var fs: int = battle.tip_label.get_theme_font_size("font_size")
	var th: float = font.get_multiline_string_size(battle.tip_label.text, HORIZONTAL_ALIGNMENT_LEFT, w - 14, fs,
			-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
	battle.tip_label.size = Vector2(w - 14, th)
	var h := ceilf(th) + 10.0
	battle.tip_panel.size = Vector2(w, h)
	battle.tip_panel.position = tip_origin()   # linksboven, onder de strook; notch schuift mee
	battle.tip_panel.show()


## Plek van het tip-venster in gevechtseenheden (384x216). Desktop: (6, 22).
## Op mobiel telt de veilige zone (notch); het gevecht is 2x geschaald, insets staan in viewport-px.
func tip_origin() -> Vector2:
	var ins := UiTouchC.insets(battle.get_viewport())
	var s := maxf(battle.get_global_transform().get_scale().x, 0.001)
	return Vector2(6.0 + ins.x / s, 22.0 + ins.y / s)


func hide_tip() -> void:
	if battle.tip_panel:
		battle.tip_panel.hide()