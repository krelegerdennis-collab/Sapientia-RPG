extends "res://scripts/ui/menu_screen.gd"
## Codex (Kernfragment stap 2): veldmenu > Codex, zoals het capsule-menu van Lufia 2.
##   links : de pagina's ('Mosslijm   Lv 3'; '*' = actieve bondgenoot), onderaan 'Geen bondgenoot'
##   rechts: naam, plaatje, level, HP/MP, ATK/DEF/SPD, EXP, vaardigheden, element
## A / tik op een pagina = die wordt de bondgenoot (vecht mee); A op 'Geen' = niemand.
## B / MENU / 'Terug' = terug naar het hoofdmenu. Alles is tikbaar (regels van 16 hoog).

const CodexData := preload("res://scripts/data/codex_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")

const LIST_W := 120
const NONE_ID := ""
const HINT := "A: bondgenoot kiezen   B: terug"

var scroll: ScrollContainer
var list: VBoxContainer
var entries: Array[Button] = []
var uids: Array = []            # per regel: page-uid of NONE_ID ('Geen bondgenoot')
var name_label: Label
var picture: TextureRect
var stats_label: Label
var skills_label: Label
var state_label: Label
var empty_label: Label
var shown_uid := "-"


func _build() -> void:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	content.add_child(body)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_W, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 6
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	empty_label = UiMenu.label("Nog geen pagina's.", MenuColors.TEXT_DIM)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(empty_label)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 2)
	body.add_child(detail)
	name_label = UiMenu.label("", MenuColors.TITLE)
	detail.add_child(name_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	detail.add_child(row)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(52, 52)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(picture)
	stats_label = UiMenu.label("", MenuColors.TEXT)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stats_label)
	skills_label = UiMenu.label("", MenuColors.TEXT_DIM)
	skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_label.custom_minimum_size = Vector2(100, 0)
	detail.add_child(skills_label)
	state_label = UiMenu.label("", MenuColors.INFO)
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.custom_minimum_size = Vector2(100, 0)
	detail.add_child(state_label)
	set_hint(HINT)
	rebuild()


func rebuild(keep_uid := "-") -> void:
	for b in entries:
		b.queue_free()
	entries.clear()
	uids = []
	header.text = "Codex   %d/%d pagina's" % [GameState.codex_pages.size(), CodexData.MAX_PAGES]
	for p in GameState.codex_pages:
		uids.append(str(p["uid"]))
	if not uids.is_empty():
		uids.append(NONE_ID)
	for uid in uids:
		var b := UiMenu.button(entry_label(uid))
		b.custom_minimum_size = Vector2(LIST_W - 4, ROW_H)
		b.focus_entered.connect(show_page.bind(uid))
		b.pressed.connect(choose.bind(uid))
		list.add_child(b)
		entries.append(b)
	TargetList.link_ring(entries)
	empty_label.visible = entries.is_empty()
	if entries.is_empty():
		name_label.text = ""
		stats_label.text = ""
		skills_label.text = "Gebruik een Leeg Boek in een gevecht op een verzwakt monster."
		state_label.text = ""
		back_button.grab_focus()
		return
	var i := uids.find(keep_uid)
	if i < 0:
		i = maxi(0, uids.find(GameState.codex_active))
	entries[i].grab_focus()
	show_page(uids[i])


## Tekst van een regel ('* Mosslijm  Lv 3'); '*' = actieve bondgenoot.
func entry_label(uid: String) -> String:
	if uid == NONE_ID:
		return ("* " if GameState.codex_active == "" else "  ") + "Geen bondgenoot"
	var p := GameState.codex_page(uid)
	var mark := "* " if GameState.codex_active == uid else "  "
	var n := str(p["name"])
	if n.length() > 12:
		n = n.substr(0, 12)
	return "%s%s Lv%d" % [mark, n.rpad(12), int(p["level"])]


func entry_text(i: int) -> String:
	return str(entries[i].get_meta("label", ""))


func show_page(uid: String) -> void:
	shown_uid = uid
	if uid == NONE_ID:
		name_label.text = "Geen bondgenoot"
		picture.texture = null
		stats_label.text = ""
		skills_label.text = "Dennis vecht zonder Codex-monster."
		state_label.text = "Gekozen." if GameState.codex_active == "" else "A: niemand laten meevechten."
		return
	var p := GameState.codex_page(uid)
	if p.is_empty():
		return
	var sp := CodexData.species(str(p["species"]))
	name_label.text = "%s  Lv %d" % [p["name"], int(p["level"])]
	var front := str(sp.get("front", ""))
	picture.texture = GameState.get_resource(front) if ResourceLoader.exists(front) else null
	picture.modulate = Color(0.62, 0.62, 0.72) if int(p["hp"]) <= 0 else Color.WHITE
	var need: int = maxi(0, GameData.exp_for_level(int(p["level"]) + 1) - int(p["exp"]))
	stats_label.text = "HP %d/%d  MP %d/%d\nATK %d  DEF %d  SPD %d\nEXP %d  volg. %d\nElement: %s" % [
			int(p["hp"]), int(p["max_hp"]), int(p["mp"]), int(p["max_mp"]),
			int(p["atk"]), int(p["def"]), int(p["agi"]), int(p["exp"]), need, str(p.get("element", "-"))]
	var names: Array = (p["skills"] as Array).map(func(x): return str(CodexData.skill(str(x)).get("name", x)))
	skills_label.text = "Vaardigheden: " + (", ".join(names) if not names.is_empty() else "-")
	if GameState.codex_active == uid:
		state_label.text = "Vecht mee naast %s." % GameState.party[0]["name"]
	else:
		state_label.text = "A: laat dit monster meevechten."


## A / tik: deze pagina wordt de bondgenoot ('Geen' = niemand).
func choose(uid: String) -> void:
	GameState.codex_set_active(uid)
	for i in entries.size():
		UiMenu.set_label(entries[i], entry_label(uids[i]))
	show_page(uid)
	if uid == NONE_ID:
		show_message("Geen bondgenoot.")
	else:
		show_message("%s vecht mee!" % GameState.codex_page(uid)["name"])
