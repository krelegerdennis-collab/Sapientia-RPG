extends "res://scripts/ui/menu_screen.gd"
## Veldmenu > Quest Log (v0.25). Data: res://data/quests.json via scripts/data/quest_data.gd
## (zelfde bron als ECHO's questlog). Twee tabs: Active en Done. Links de lijst, gegroepeerd per act
## (kopje "Act 1: The First Archive"), rechts de gekozen opdracht: omschrijving en stappen [x]/[ ].
## Links/rechts of tikken wisselt de tab; focus of tikken op een opdracht toont hem rechts.
## Een zijopdracht waarvan je de NPC nog niet sprak, staat er grijs met alleen de naam van de NPC.

const QD := preload("res://scripts/data/quest_data.gd")
const HINT := "Left/Right: tab   B: back"
const TABS := ["actief", "klaar"]
const TAB_W := 84
const LIST_W := 172
const RIJ_H := 18               # iets hoger dan ROW_H: duimvriendelijk op de telefoon

var tab := "actief"
var tab_buttons := {}
var scroll: ScrollContainer
var list: VBoxContainer
var detail_titel: Label
var detail: Label
var leeg: Label
var rows: Array[Button] = []
## Id van de opdracht die rechts staat ("" = geen)
var gekozen := ""


func _build() -> void:
	header.text = QD.TITEL
	set_hint(HINT)
	GameState.quest_sync()
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	content.add_child(bar)
	for t in TABS:
		var b := UiMenu.button(_tab_naam(t))
		b.name = "Tab_" + t
		b.custom_minimum_size = Vector2(TAB_W, RIJ_H)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(kies_tab.bind(t))
		bar.add_child(b)
		tab_buttons[t] = b
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	content.add_child(body)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_W, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 6
	scroll.follow_focus = true
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	var rechts := PanelContainer.new()
	rechts.add_theme_stylebox_override("panel", UiMenu.inner_style())
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rechts)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override("separation", 2)
	rechts.add_child(kol)
	detail_titel = UiMenu.label("", MenuColors.TITLE)
	detail_titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kol.add_child(detail_titel)
	detail = UiMenu.label("", MenuColors.TEXT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kol.add_child(detail)
	_fill()


func _handle_input() -> void:
	var d := horizontal_pressed()
	if d != 0:
		kies_tab(TABS[(TABS.find(tab) + d + TABS.size()) % TABS.size()])


static func _tab_naam(t: String) -> String:
	return QD.TAB_ACTIEF if t == "actief" else QD.TAB_KLAAR


func kies_tab(t: String) -> void:
	if t == tab or not t in TABS:
		return
	tab = t
	quiet()
	_fill()


## De teksten van de opdrachtregels (voor de tests).
func regel_teksten() -> Array[String]:
	var uit: Array[String] = []
	for b in rows:
		uit.append(str(b.get_meta("label", b.text)))
	return uit


## De act-kopjes in de lijst, in volgorde (voor de tests).
func kop_teksten() -> Array[String]:
	var uit: Array[String] = []
	for c in list.get_children():
		if c is Label and c != leeg and not c.is_queued_for_deletion():
			uit.append(str(c.text))
	return uit


func _fill() -> void:
	for t in tab_buttons:
		var b: Button = tab_buttons[t]
		b.add_theme_color_override("font_color", MenuColors.TITLE if t == tab else MenuColors.TEXT_DIM)
		UiMenu.set_label(b, ("[%s]" if t == tab else "%s") % _tab_naam(t))
	for c in list.get_children():
		c.queue_free()
	rows.clear()
	leeg = null
	gekozen = ""
	detail_titel.text = ""
	detail.text = ""
	var flags: Dictionary = GameState.story_flags
	var stap: int = GameState.story_step
	var vg: Dictionary = GameState.quest_progress
	for id in QD.act_ids():
		var lijst := QD.voor_tab(str(id), tab, flags, stap, vg)
		if lijst.is_empty():
			continue
		var kop := UiMenu.label(QD.act_kop(str(id)), MenuColors.ACCENT_SOFT)
		kop.clip_text = true
		list.add_child(kop)
		for q in lijst:
			_rij(q, flags, stap, vg)
	if rows.is_empty():
		leeg = UiMenu.label(QD.LEEG_ACTIEF if tab == "actief" else QD.LEEG_KLAAR, MenuColors.TEXT_DIM)
		list.add_child(leeg)
		back_button.grab_focus.call_deferred()
	else:
		toon(str(rows[0].get_meta("quest")))
		rows[0].grab_focus.call_deferred()


func _rij(q: Dictionary, flags: Dictionary, stap: int, vg: Dictionary) -> void:
	var tekst := QD.regel(q, flags, stap, vg)
	var b := UiMenu.button(tekst)
	b.name = "Quest_" + str(q["id"])
	b.set_meta("quest", str(q["id"]))
	b.custom_minimum_size = Vector2(0, RIJ_H)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lock_horizontal_focus(b)
	b.focus_entered.connect(toon.bind(str(q["id"])))
	b.pressed.connect(toon.bind(str(q["id"])))
	list.add_child(b)
	rows.append(b)
	if QD.is_zij(q) and not QD.zij_gesproken(q, flags, stap, vg):
		_grey(b)


## Rechts: titel + omschrijving + stappen van deze opdracht.
func toon(id: String) -> void:
	var q := QD.quest(id)
	if q.is_empty():
		return
	gekozen = id
	var flags: Dictionary = GameState.story_flags
	var stap: int = GameState.story_step
	var vg: Dictionary = GameState.quest_progress
	detail_titel.text = QD.regel(q, flags, stap, vg)
	detail.text = "\n".join(QD.detail_regels(q, flags, stap, vg))
