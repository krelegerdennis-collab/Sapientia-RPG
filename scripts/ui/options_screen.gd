extends "res://scripts/ui/menu_screen.gd"
## v0.11 Veldmenu > Opties. Elke regel: naam, '<', waarde, '>'.
##   omhoog/omlaag = regel kiezen, links/rechts (of tik op '<' '>') = waarde veranderen,
##   A = volgende waarde (aan/uit wisselen), onderste regel 'Standaard' = alles terug.
## De waarden staan in de autoload Settings (scripts/settings.gd) en worden na elke
## wijziging meteen in user://settings.cfg geschreven (los van de save).
## De onderste regel van het scherm legt de gekozen instelling uit.

const TargetList := preload("res://scripts/ui/target_list.gd")

const OPTION_ROW_H := 15       # iets lager dan ROW_H: 10 regels moeten op 216 px passen
const VALUE_W := 66            # breedte van de waarde tussen '<' en '>'
const RESET_KEY := "_reset"

## [sleutel in Settings, naam in het menu, uitleg onderin]
const ROWS := [
	["music_volume", "Music", "Music volume."],
	["sfx_volume", "Effects", "Sound effect volume."],
	["text_speed", "Text Speed", "How fast text appears in the text box."],
	["battle_speed", "Battle Speed", "How long battle messages stay up."],
	["touch_opacity", "Button Fade", "How clearly you see the D-pad and A/B."],
	["touch_size", "Button Size", "Size of the D-pad and A/B on screen."],
	["crt", "Scanlines", "Picture filter with lines, vignette, and glitches."],
	["screen_shake", "Screen Shake", "Shake the screen when a hit lands."],
	["autosave", "Autosave", "Save when you enter or leave a dungeon."],
	[RESET_KEY, "Default", "Set every option back to the default (A)."],
]

var settings: Node
var rows: Array[Button] = []
var keys: Array[String] = []
var value_labels := {}         # sleutel -> Label


func _build() -> void:
	header.text = "Options"
	settings = get_node_or_null("/root/Settings")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	content.add_child(box)
	if settings == null:
		box.add_child(UiMenu.label("Options are unavailable (Settings autoload is missing).", MenuColors.TEXT_DIM))
		back_button.grab_focus()
		return
	for r in ROWS:
		var key: String = r[0]
		if key == "crt" and get_node_or_null("/root/Crt") == null:
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 2)
		box.add_child(line)
		var b := UiMenu.button(str(r[1]))
		b.custom_minimum_size = Vector2(0, OPTION_ROW_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("key", key)
		b.focus_entered.connect(_on_row_focus.bind(key, str(r[2])))
		b.pressed.connect(activate.bind(key))
		line.add_child(b)
		rows.append(b)
		keys.append(key)
		if key == RESET_KEY:
			continue
		var minus := arrow_button("<")
		minus.custom_minimum_size.y = OPTION_ROW_H
		minus.pressed.connect(change.bind(key, -1))
		line.add_child(minus)
		var v := UiMenu.label("", MenuColors.TEXT)
		v.custom_minimum_size = Vector2(VALUE_W, OPTION_ROW_H)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(v)
		value_labels[key] = v
		var plus := arrow_button(">")
		plus.custom_minimum_size.y = OPTION_ROW_H
		plus.pressed.connect(change.bind(key, 1))
		line.add_child(plus)
	TargetList.link_ring(rows)
	refresh_values()
	rows[0].grab_focus()


## Tekst van een waarde ('80%', 'Normaal', 'Aan', ...).
func value_text(key: String) -> String:
	var v = settings.get_value(key)
	match key:
		"music_volume", "sfx_volume":
			return "Off" if int(v) <= 0 else "%d%%" % (int(v) * 100 / settings.VOLUME_STEPS)
		"text_speed":
			return settings.TEXT_SPEED_NAMES[int(v)]
		"battle_speed":
			return settings.BATTLE_SPEED_NAMES[int(v)]
		"touch_opacity":
			return "%d%%" % int(v)
		"touch_size":
			return settings.TOUCH_SIZE_NAMES[int(v)]
	if v is bool:
		return "On" if v else "Off"
	return str(v)


func refresh_values() -> void:
	for key in value_labels:
		var l: Label = value_labels[key]
		l.text = value_text(key)
		var v = settings.get_value(key)
		var off: bool = (v is bool and not v) or (key.ends_with("_volume") and int(v) <= 0)
		l.add_theme_color_override("font_color", MenuColors.TEXT_DIM if off else MenuColors.INFO)


func _on_row_focus(_key: String, help: String) -> void:
	set_hint(help)


func focused_key() -> String:
	for b in rows:
		if b.has_focus():
			return str(b.get_meta("key"))
	return ""


## Links/rechts: één stap (met grenzen; aan/uit wisselt).
func change(key: String, dir: int) -> void:
	if settings == null or key == RESET_KEY:
		return
	settings.step(key, dir)
	refresh_values()


## A / tik op de naam: volgende waarde (rondlopend), of alles terug naar standaard.
func activate(key: String) -> void:
	if settings == null:
		return
	if key == RESET_KEY:
		settings.reset_to_defaults()
		refresh_values()
		show_message("All options are back to the default.")
		return
	var before = settings.get_value(key)
	settings.step(key, 1)
	if settings.get_value(key) == before and not (before is bool):
		# al op het maximum: terug naar het begin
		var lowest = -999999
		settings.set_value(key, lowest)
	refresh_values()


func _handle_input() -> void:
	var d := horizontal_pressed()
	if d != 0:
		change(focused_key(), d)
