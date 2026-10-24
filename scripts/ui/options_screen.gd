extends "res://scripts/ui/menu_screen.gd"
## v0.11 Veldmenu > Opties. Tab General: elke regel naam, '<', waarde, '>'.
## Tab Music: schuifregelaars (zelfde Settings-keys), mute en preview van gehoord BGM.
##   omhoog/omlaag = regel kiezen, links/rechts (of tik op '<' '>') = waarde veranderen,
##   A = volgende waarde (aan/uit wisselen), onderste regel 'Default' = alles terug.
## De waarden staan in de autoload Settings (scripts/settings.gd) en worden na elke
## wijziging meteen in user://settings.cfg geschreven (los van de save).

const TargetList := preload("res://scripts/ui/target_list.gd")
const MusicTracks := preload("res://scripts/data/music_tracks.gd")

const OPTION_ROW_H := 19       # 13 regels in twee kolommen (7 + 6) passen met tabbalk en hulpregel op 216 hoog
const TAB_BAR_H := 24          # zelfde tikminimum als questlog-tab (ROW_H / RIJ_H-traditie: 24 logic px)
const TOUCH_MIN_H := 48        # Music-tab schuiven/tracks: mobiel tikdoel (logic pixels)
const VALUE_W := 50            # breedte van de waarde tussen '<' en '>' (twee kolommen: elke kolom is ~178 breed)
const RESET_KEY := "_reset"
const EXPORT_KEY := "_export"      # playtest: logboek aanbieden (SessieLog)
const TABS := ["general", "music"]
const TAB_NAMES := {"general": "General", "music": "Music"}
const MUSIC_HINT := "A: play/stop   Tap Music tab   B: back"
const MUSIC_LOCKED_MSG := "You haven't heard this track yet."
const MUSIC_PLAYING := "Now playing: %s"
const MUSIC_STOPPED := "Music stopped."

## [sleutel in Settings, naam in het menu, uitleg onderin]
const ROWS := [
	["music_volume", "Music", "Music volume."],
	["sfx_volume", "Effects", "Sound effect volume."],
	["text_speed", "Text Speed", "How fast text appears in the text box."],
	["battle_speed", "Battle Speed", "How long battle messages stay up."],
	["touch_opacity", "Button Fade", "How clearly you see the joystick and A/B."],
	["touch_size", "Button Size", "Size of the joystick and A/B on screen."],
	["crt", "Scanlines", "Picture filter with lines, vignette, and glitches."],
	["screen_shake", "Screen Shake", "Shake the screen when a hit lands."],
	["autosave", "Autosave", "Save when you enter or leave a dungeon."],
	[RESET_KEY, "Default", "Set every option back to the default (A)."],
	["sessie_log", "Session Log", "Notes where you walk and fight so the game can be improved. No personal data."],
	[EXPORT_KEY, "Export Log", "Save or share the session log (A) so you can send it."],
	["battle_style", "Battle Style", "Classic: turn-based. Action: real time (bosses stay turn-based)."],
]

var settings: Node
var rows: Array[Button] = []
var keys: Array[String] = []
var value_labels := {}         # sleutel -> Label
var tab := "general"
var tab_buttons := {}
var general_box: HBoxContainer   # twee kolommen met regels (links 7, rechts 6)
var _col_a: VBoxContainer
var _col_b: VBoxContainer
var music_root: Control
var music_sliders := {}        # music_volume / sfx_volume -> HSlider
var music_value_labels := {}   # sleutel -> Label (percentage)
var mute_button: Button
var track_buttons: Array[Button] = []
var track_list: VBoxContainer
var preview := ""


func _build() -> void:
	header.text = "Options"
	settings = get_node_or_null("/root/Settings")
	var outer := VBoxContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 2)
	content.add_child(outer)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	outer.add_child(bar)
	for t in TABS:
		var tb := UiMenu.button(TAB_NAMES[t])
		tb.name = "Tab_" + t
		tb.custom_minimum_size = Vector2(64, TAB_BAR_H)
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(kies_tab.bind(t))
		bar.add_child(tb)
		tab_buttons[t] = tb
	general_box = HBoxContainer.new()
	general_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	general_box.add_theme_constant_override("separation", 8)
	outer.add_child(general_box)
	_col_a = VBoxContainer.new()
	_col_b = VBoxContainer.new()
	for col in [_col_a, _col_b]:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		col.add_theme_constant_override("separation", 0)
		general_box.add_child(col)
	if settings == null:
		general_box.add_child(UiMenu.label("Options are unavailable (Settings autoload is missing).", MenuColors.TEXT_DIM))
		back_button.grab_focus()
		return
	music_root = _build_music_tab()
	music_root.visible = false
	outer.add_child(music_root)
	_build_general_rows()
	_refresh_tabs()
	general_box.visible = true
	rows[0].grab_focus()


func _build_general_rows() -> void:
	var shown: Array = ROWS.filter(func(r): return not (str(r[0]) == "crt" and get_node_or_null("/root/Crt") == null))
	var split := (shown.size() + 1) / 2
	for n in shown.size():
		var r: Array = shown[n]
		var key: String = r[0]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 2)
		(_col_a if n < split else _col_b).add_child(line)
		var b := UiMenu.button(str(r[1]))
		b.custom_minimum_size = Vector2(0, OPTION_ROW_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("key", key)
		b.focus_entered.connect(_on_row_focus.bind(key, str(r[2])))
		b.pressed.connect(activate.bind(key))
		line.add_child(b)
		rows.append(b)
		keys.append(key)
		if key == RESET_KEY or key == EXPORT_KEY:
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


func _build_music_tab() -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 2)
	_add_volume_slider(wrap, "music_volume", "Music")
	_add_volume_slider(wrap, "sfx_volume", "SFX")
	var mute_row := HBoxContainer.new()
	mute_row.custom_minimum_size.y = TOUCH_MIN_H
	wrap.add_child(mute_row)
	mute_button = UiMenu.button("Mute all audio")
	mute_button.custom_minimum_size = Vector2(0, TOUCH_MIN_H)
	mute_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_button.pressed.connect(_toggle_mute)
	mute_row.add_child(mute_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrap.add_child(scroll)
	track_list = VBoxContainer.new()
	track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_list.add_theme_constant_override("separation", 0)
	scroll.add_child(track_list)
	return wrap


func _add_volume_slider(parent: VBoxContainer, key: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = TOUCH_MIN_H
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var lab := UiMenu.label(title)
	lab.custom_minimum_size = Vector2(44, TOUCH_MIN_H)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lab)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = settings.VOLUME_STEPS
	slider.step = 1
	slider.tick_count = 0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(80, TOUCH_MIN_H)
	slider.value = int(settings.get_value(key))
	lock_horizontal_focus(slider)
	slider.value_changed.connect(func(v: float) -> void: _on_slider(key, v))
	row.add_child(slider)
	music_sliders[key] = slider
	var val := UiMenu.label(_volume_pct(key), MenuColors.INFO)
	val.custom_minimum_size = Vector2(36, TOUCH_MIN_H)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)
	music_value_labels[key] = val


func _on_slider(key: String, v: float) -> void:
	if settings == null:
		return
	settings.set_value(key, int(v))
	_volume_label_refresh(key)


func _volume_pct(key: String) -> String:
	var steps := int(settings.get_value(key))
	return "Off" if steps <= 0 else "%d%%" % (steps * 100 / settings.VOLUME_STEPS)


func _volume_label_refresh(key: String) -> void:
	if music_value_labels.has(key):
		music_value_labels[key].text = _volume_pct(key)
	if music_sliders.has(key):
		music_sliders[key].value = int(settings.get_value(key))


func _toggle_mute() -> void:
	if settings == null:
		return
	settings.set_value("audio_mute", not bool(settings.get_value("audio_mute")))
	_refresh_mute_button()


func _refresh_mute_button() -> void:
	if mute_button == null or settings == null:
		return
	var on: bool = bool(settings.get_value("audio_mute"))
	UiMenu.set_label(mute_button, ("[On] " if on else "") + "Mute all audio")
	var c := MenuColors.TEXT_DIM if on else MenuColors.TEXT
	mute_button.add_theme_color_override("font_color", c)


func _fill_tracks() -> void:
	for b in track_buttons:
		b.queue_free()
	track_buttons.clear()
	var first: Button = null
	for i in MusicTracks.TRACKS.size():
		var tr: Dictionary = MusicTracks.TRACKS[i]
		var tid := str(tr["id"])
		var heard: bool = GameState.heard_music.has(tid)
		var b := UiMenu.button(_music_label(i, tr, heard))
		b.name = "Track_" + tid
		b.custom_minimum_size = Vector2(0, TOUCH_MIN_H)
		b.pressed.connect(choose_track.bind(tid))
		if not heard:
			_grey(b)
		elif first == null:
			first = b
		track_list.add_child(b)
		track_buttons.append(b)
	(first if first != null else (track_buttons[0] if not track_buttons.is_empty() else back_button)).grab_focus.call_deferred()


func _music_label(i: int, tr: Dictionary, heard: bool) -> String:
	if not heard:
		return "%d. %s" % [i + 1, MusicTracks.LOCKED_NAME]
	var mark := "[Playing] " if str(tr["id"]) == preview else ""
	return "%d. %s%s  (%s)" % [i + 1, mark, str(tr["name"]), str(tr["where"])]


func _relabel_tracks() -> void:
	for i in mini(track_buttons.size(), MusicTracks.TRACKS.size()):
		var tr: Dictionary = MusicTracks.TRACKS[i]
		UiMenu.set_label(track_buttons[i], _music_label(i, tr, GameState.heard_music.has(str(tr["id"]))))


func choose_track(tid: String) -> void:
	if not GameState.heard_music.has(tid):
		show_message(MUSIC_LOCKED_MSG)
		return
	if tid == preview:
		stop_preview()
		show_message(MUSIC_STOPPED)
		_relabel_tracks()
		return
	var tr: Dictionary = MusicTracks.track(tid)
	var mid := str((tr["ids"] as Array)[0])
	if preview == "":
		AudioManager.push_music(mid, 0.3)
	else:
		AudioManager.play_music(mid, 0.3, true)
	preview = tid
	show_message(MUSIC_PLAYING % str(tr["name"]))
	_relabel_tracks()


func stop_preview() -> void:
	if preview == "":
		return
	preview = ""
	AudioManager.pop_music(0.3)


func kies_tab(t: String) -> void:
	if t == tab or not t in TABS:
		return
	if tab == "music":
		stop_preview()
	tab = t
	quiet()
	general_box.visible = tab == "general"
	music_root.visible = tab == "music"
	_refresh_tabs()
	if tab == "music":
		set_hint(MUSIC_HINT)
		for key in music_sliders:
			_volume_label_refresh(key)
		_refresh_mute_button()
		_fill_tracks()
	else:
		set_hint(DEFAULT_HINT)
		refresh_values()


func _refresh_tabs() -> void:
	for t in tab_buttons:
		var b: Button = tab_buttons[t]
		b.add_theme_color_override("font_color", MenuColors.TITLE if t == tab else MenuColors.TEXT_DIM)
		UiMenu.set_label(b, ("[%s]" if t == tab else "%s") % TAB_NAMES[t])


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
		"battle_style":
			return settings.BATTLE_STYLE_NAMES[int(v)]
		"sessie_log":
			return ["Auto", "Off", "On"][int(v) + 1]
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
	for key in music_sliders:
		_volume_label_refresh(key)
	_refresh_mute_button()


func _on_row_focus(_key: String, help: String) -> void:
	set_hint(help)


func focused_key() -> String:
	for b in rows:
		if b.has_focus():
			return str(b.get_meta("key"))
	return ""


## Links/rechts: één stap (met grenzen; aan/uit wisselt).
func change(key: String, dir: int) -> void:
	if settings == null or key == RESET_KEY or key == EXPORT_KEY:
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
	if key == EXPORT_KEY:
		var uit: Dictionary = SessieLog.exporteer()
		show_message(str(uit["bericht"]))
		return
	var before = settings.get_value(key)
	settings.step(key, 1)
	if settings.get_value(key) == before and not (before is bool):
		# al op het maximum: terug naar het begin
		var lowest = -999999
		settings.set_value(key, lowest)
	refresh_values()


func _handle_input() -> void:
	if tab == "music":
		var d := horizontal_pressed()
		if d != 0:
			kies_tab(TABS[(TABS.find(tab) + d + TABS.size()) % TABS.size()])
		return
	var d := horizontal_pressed()
	if d != 0:
		change(focused_key(), d)


func close() -> void:
	stop_preview()
	super.close()
