extends "res://scripts/ui/menu_screen.gd"
## Veldmenu > Quest Log. Zelfde data als ECHO's questlog (world_warper/data/echo_questlog.gd).
## Twee tabs: Main (de acts, zoals bij ECHO) en Side (zijopdrachten per NPC).
## Links/rechts of tikken wisselt de tab. Main: A op een act toont ECHO's zin en de opdrachten.

const QL := preload("res://world_warper/data/echo_questlog.gd")
const HINT := "Left/Right: tab   A: open   B: back"
const TABS := ["hoofd", "zij"]

var tab := "hoofd"
var tab_buttons := {}
var list: VBoxContainer
var detail: Label
var rows: Array[Button] = []
## Testhaak: andere zijopdrachten-lijst (leeg = QL.ZIJ)
var zij_lijst: Array = []


func _build() -> void:
	header.text = QL.OPTIE
	set_hint(HINT)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	content.add_child(bar)
	for t in TABS:
		var b := UiMenu.button(QL.TAB_HOOFD if t == "hoofd" else QL.TAB_ZIJ)
		b.name = "Tab_" + t
		b.custom_minimum_size = Vector2(56, ROW_H)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(kies_tab.bind(t))
		bar.add_child(b)
		tab_buttons[t] = b
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	content.add_child(list)
	detail = UiMenu.label("", MenuColors.TEXT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(detail)
	_fill()


func _handle_input() -> void:
	var d := horizontal_pressed()
	if d != 0 and open_akte == "":
		kies_tab(TABS[(TABS.find(tab) + d + TABS.size()) % TABS.size()])


func kies_tab(t: String) -> void:
	if t == tab or not t in TABS:
		return
	tab = t
	quiet()
	_fill()


func _zij() -> Array:
	return zij_lijst if not zij_lijst.is_empty() else QL.ZIJ


## De teksten in de lijst (voor de tests).
func regel_teksten() -> Array[String]:
	var uit: Array[String] = []
	for b in rows:
		uit.append(str(b.get_meta("label", b.text)))
	return uit


func _fill() -> void:
	for t in tab_buttons:
		var b: Button = tab_buttons[t]
		b.add_theme_color_override("font_color", MenuColors.TITLE if t == tab else MenuColors.TEXT_DIM)
		UiMenu.set_label(b, ("[%s]" if t == tab else "%s") % (QL.TAB_HOOFD if t == "hoofd" else QL.TAB_ZIJ))
	for b in rows:
		b.queue_free()
	rows.clear()
	detail.text = ""
	open_akte = ""
	list.visible = true
	var flags: Dictionary = GameState.story_flags
	if tab == "hoofd":
		for id in QL.ids():
			var b := _rij(QL.keuze(str(id), flags, GameState.story_step))
			b.name = "Act_" + str(id)
			b.pressed.connect(toon_akte.bind(str(id)))
	else:
		var lijst := _zij()
		if lijst.is_empty():
			detail.text = QL.ZIJ_LEEG
		for z in lijst:
			var b := _rij(QL.zij_regel(z, flags))
			b.name = "Zij_" + str(z["id"])
			if not QL.zij_gesproken(z, flags):
				_grey(b)
	if not rows.is_empty():
		rows[0].grab_focus.call_deferred()
	else:
		back_button.grab_focus.call_deferred()


func _rij(tekst: String) -> Button:
	var b := UiMenu.button(tekst)
	UiMenu.set_label(b, tekst)
	b.custom_minimum_size = Vector2(0, ROW_H)
	list.add_child(b)
	rows.append(b)
	return b


## Main-tab: ECHO's zin + (bij inhoud) de opdrachten onder de lijst.
## De lijst gaat zolang weg (anders past het niet); B gaat terug naar de lijst.
var open_akte := ""


func toon_akte(id: String) -> void:
	open_akte = id
	list.visible = false
	detail.text = "\n".join(QL.regels(id, GameState.story_flags, GameState.story_step))
	back_button.grab_focus.call_deferred()


func back() -> void:
	if open_akte != "":
		var id := open_akte
		open_akte = ""
		list.visible = true
		detail.text = ""
		quiet()
		var i := QL.ids().find(id)
		if i >= 0 and i < rows.size():
			rows[i].grab_focus.call_deferred()
		return
	close()
