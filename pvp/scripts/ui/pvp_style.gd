extends RefCounted
class_name PvpStyle
## Code-drawn UI op 384x216. Geen art, geen shaders.


const BG := Color(0.07, 0.06, 0.11)
const INK := Color(0.93, 0.91, 0.86)
const DIM := Color(0.68, 0.64, 0.74)


static func fill(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg


static func column(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8.0
	box.offset_top = 6.0
	box.offset_right = -8.0
	box.offset_bottom = -6.0
	box.add_theme_constant_override("separation", 3)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(box)
	return box


static func label(text: String, size: int = 8) -> Label:
	var row := Label.new()
	row.text = text
	row.add_theme_font_size_override("font_size", size)
	row.add_theme_color_override("font_color", INK)
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return row


static func button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 18)
	btn.add_theme_font_size_override("font_size", 8)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return btn


static func portrait(character_id: String) -> ColorRect:
	var box := ColorRect.new()
	box.custom_minimum_size = Vector2(32, 32)
	box.color = PvpCharacters.color_of(character_id)
	var tag := Label.new()
	tag.text = "PLACEHOLDER"
	tag.add_theme_font_size_override("font_size", 6)
	tag.add_theme_color_override("font_color", Color(0.08, 0.06, 0.1))
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(tag)
	return box
