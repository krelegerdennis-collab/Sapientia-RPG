extends CanvasLayer
## v0.10 Bestiarium: alle monsters uit game_data.gd (ENEMIES, op nummer).
##   nog niet gezien   -> '???' en een zwart silhouet
##   gezien            -> plaatje, naam en beschrijving
##   >= 1x verslagen   -> ook de stats (HP, MP, ATK, DEF, EXP, goud, zwak/sterk, buit, leefgebied)
## Gezien/verslagen staat in GameState.bestiary en gaat mee in de save.
## Lijst links (scrollt met de vinger), details rechts. B / MENU = terug.

signal closed

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const EndgameBestiary := preload("res://scripts/data/endgame_bestiary.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
## v0.14: menukleuren uit één bestand (menu_colors.gd), niet meer de neon van ui_style.gd
const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const TERRAIN_NAMES := {
	"gras": "plains", "hoog_gras": "tall grass", "bos": "woods", "zand": "sand",
	"baas": "boss", "archief": "archive", "woud": "wood",
	"dungeon100": "Deep Learning Simulation", "berggrot": "Hollow Mountain",
}

var root: Control
var header: Label
var scroll: ScrollContainer
var list: VBoxContainer
var picture: TextureRect
var name_label: Label
var desc_label: Label
var stats_label: Label
var back_button: Button
## Onzichtbaar tikvlak rond 'Back' (>= 25 eenheden hoog, tot aan de schermrand).
var back_zone: Control
var _bg: Panel
var _outer: VBoxContainer
var entries: Array[Button] = []
var ids: Array = []
var shown_id := ""


## Frame waarin dit scherm (of een sub-scherm) open/dicht ging: in dat frame geen knoppen
## verwerken (anders sluit dezelfde druk op MENU/B hem meteen weer).
var _quiet_frame := -1


const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const BACK_W := 56


## Venster en inhoud binnen het veilige gebied + het tikvlak van 'Back' (zelfde maten als menu_screen.gd).
func _apply_safe_area() -> void:
	var ins := UiTouchC.insets(root.get_viewport())
	_bg.offset_left = 6 + ins.x
	_bg.offset_top = 6 + ins.y
	_bg.offset_right = -(6 + ins.z)
	_bg.offset_bottom = -(6 + ins.w)
	_outer.offset_left = 12 + ins.x
	_outer.offset_top = 9 + ins.y
	_outer.offset_right = -(12 + ins.z)
	_outer.offset_bottom = -(9 + ins.w)
	var w := root.size.x if root.size.x > 0.0 else 384.0
	back_zone.position = Vector2(w - ins.z - 12.0 - BACK_W, 0.0)
	back_zone.size = Vector2(BACK_W + 12.0 + ins.z, maxf(UiTouchC.TOUCH_MIN, 9.0 + ins.y + 18.0))


func _on_back_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		back_zone.accept_event()
		close()


func _ready() -> void:
	_quiet_frame = Engine.get_process_frames()
	layer = 21
	root = Control.new()
	root.theme = load(UiMenu.THEME_PATH)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiMenu.window_style(MenuColors.BORDER_DARK, 0.97))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_bg = bg
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 4)
	root.add_child(outer)
	_outer = outer
	var top := HBoxContainer.new()
	outer.add_child(top)
	header = UiMenu.label("", MenuColors.TEXT)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	back_button = UiMenu.button("Back")
	back_button.custom_minimum_size = Vector2(BACK_W, 16)
	UiSfx.tag(back_button, UiSfx.CANCEL)
	back_button.pressed.connect(close)
	top.add_child(back_button)
	back_zone = Control.new()
	back_zone.name = "BackZone"
	back_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	back_zone.gui_input.connect(_on_back_zone_input)
	root.add_child(back_zone)
	_apply_safe_area()
	root.resized.connect(_apply_safe_area)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	outer.add_child(body)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(112, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 6   # vinger-scrollen zonder per ongeluk te tikken
	scroll.follow_focus = true
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	# details: naam, dan plaatje + beschrijving, dan de stats over de hele breedte
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 3)
	body.add_child(detail)
	name_label = UiMenu.label("", MenuColors.ACCENT)
	detail.add_child(name_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	detail.add_child(row)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(64, 64)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(picture)
	desc_label = UiMenu.label("", MenuColors.TEXT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(desc_label)
	stats_label = UiMenu.label("", MenuColors.TEXT_DIM)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.custom_minimum_size = Vector2(160, 0)
	detail.add_child(stats_label)

	ids = GameData.bestiary_ids()
	ids.append_array(EndgameBestiary.ids())
	# Berggrot-monsters (043-045) komen in de lijst zodra je er een gezien hebt; de vaste lijst en teller
	# hierboven blijven daarmee gelijk voor een speler die ze nog niet kent.
	for bid in BerggrotData.bestiary_ids():
		if GameState.is_seen(str(bid)):
			ids.append(bid)
	var seen := 0
	var beaten := 0
	for id in ids:
		var e: Dictionary = _entry(str(id))
		if e.is_empty():
			continue
		var known := GameState.is_seen(id)
		seen += 1 if known else 0
		beaten += 1 if GameState.defeated_count(id) > 0 else 0
		var b := UiMenu.button("%03d %s" % [int(e.get("no", 0)), str(e["name"]) if known else "???"])
		b.custom_minimum_size = Vector2(106, 15)
		b.focus_entered.connect(show_entry.bind(id))
		b.pressed.connect(show_entry.bind(id))
		list.add_child(b)
		entries.append(b)
	header.text = "Bestiary   seen %d/%d   defeated %d/%d" % [seen, ids.size(), beaten, ids.size()]
	if not entries.is_empty():
		entries[0].grab_focus()
		show_entry(ids[0])


func entry_text(i: int) -> String:
	return str(entries[i].get_meta("label", ""))


func _entry(id: String) -> Dictionary:
	if GameData.ENEMIES.has(id):
		return GameData.ENEMIES[id]
	if BerggrotData.has_enemy(id):
		return BerggrotData.enemy(id)
	return EndgameBestiary.entry(id)


func show_entry(id: String) -> void:
	shown_id = id
	var e: Dictionary = _entry(id)
	if e.is_empty():
		return
	var known := GameState.is_seen(id)
	var kills := GameState.defeated_count(id)
	var sp := GameData.enemy_sprite(e)   # v0.19: plaatsvervanger als de art er nog niet is
	picture.texture = GameState.get_resource(sp) if ResourceLoader.exists(sp) else null
	picture.modulate = Color.WHITE if known else Color(0.02, 0.02, 0.03, 0.95)   # silhouet
	if not known:
		name_label.text = "%03d ???" % int(e.get("no", 0))
		desc_label.text = "Not seen yet."
		stats_label.text = ""
		return
	name_label.text = "%03d %s" % [int(e.get("no", 0)), str(e["name"])]
	desc_label.text = str(e.get("desc", ""))
	if kills <= 0:
		stats_label.text = "Defeat it to learn more."
		return
	var lines := [
		"HP %d  MP %d  ATK %d  DEF %d" % [int(e["max_hp"]), int(e.get("mp", 0)), int(e["atk"]), int(e["def"])],
		"EXP %d  Gold %d  Defeated: %dx" % [int(e["exp"]), int(e["gold"]), kills],
	]
	var ws := []
	if not e.get("weak", []).is_empty():
		ws.append("Weak: " + _element_list(e["weak"]))
	if not e.get("resist", []).is_empty():
		ws.append("Resists: " + _element_list(e["resist"]))
	if not ws.is_empty():
		lines.append("   ".join(ws))
	var drops: Array = []
	for d in e.get("drops", []):
		var item: Dictionary = GameData.ITEMS.get(str(d["item"]), {})
		drops.append("%s %d%%" % [str(item.get("name", d["item"])), roundi(float(d["chance"]) * 100.0)])
	if not drops.is_empty():
		lines.append("Drops: " + ", ".join(drops))
	var hab: Array = []
	for t in e.get("habitat", []):
		hab.append(str(TERRAIN_NAMES.get(t, t)))
	if not hab.is_empty():
		lines.append("Lives: " + ", ".join(hab))
	stats_label.text = "\n".join(lines)


func _element_list(ids: Array) -> String:
	var names: Array = []
	for id in ids:
		names.append(GameData.element_name(str(id)))
	return ", ".join(names)


func stats_visible() -> bool:
	return stats_label.text.begins_with("HP ")


func _process(_delta: float) -> void:
	if Engine.get_process_frames() <= _quiet_frame:
		return
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
		UiSfx.play(UiSfx.CANCEL)
		close()
		return
	UiMenu.pad_nav(root.get_viewport())


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
