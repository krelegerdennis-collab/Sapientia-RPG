extends "res://scripts/ui/menu_screen.gd"
## v0.14 (RPG CODE, menu L2) Veldmenu > Opslaan, in de stijl van Lufia 2:
##   boven : de groep - per held een klein plaatje (hoofd uit het portret 44x44, anders het
##           loopframe; hero_portrait.gd, scherp),
##           naam, Lv, HP en MP
##   midden: de plek (naam van de map)
##   onder : links Tijd en Goud, rechts de vraag:
##             'Overschrijven?'  Ja / Nee   als het slot al een save heeft
##             'Hier opslaan?'   Ja / Nee   als het slot leeg is
## Ja = signaal answered(true); het veldmenu schrijft dan de save (field_menu.save_now,
## zelfde handmatige slot als het opslagboek). Nee / B / 'Terug' = answered(false).
## Opslaan via het menu geneest niet (v0.13, Dennis). De autosave-regels veranderen niet.

signal answered(yes: bool)

const HeroPortrait := preload("res://scripts/ui/hero_portrait.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")

const MINI_BOX := Vector2(44, 44)      # vak voor het kleine plaatje (loopframe 16x24 of hoofd 44x44)
const HERO_W := 110                    # breedte van één held in de groepsrij
const ASK_W := 120                     # breedte van het vraagvak
const BUTTON_W := 56
const Q_OVERWRITE := "Overwrite?"
const Q_NEW := "Save here?"

## Naam van de plek (field_menu.gd zet dit: map_name van de huidige map).
var place := ""
var overwrite := false
var question_label: Label
var slot_label: Label
var place_label: Label
var time_label: Label
var gold_label: Label
var yes_button: Button
var no_button: Button
var chosen_slot := 1
var hero_views: Array = []
var _answered := false


func _build() -> void:
	header.text = "Save"
	var slots := HBoxContainer.new()
	slots.name = "Slots"
	slots.add_theme_constant_override("separation", 2)
	content.add_child(slots)
	for i in range(1, GameState.SLOT_COUNT + 1):
		var b := UiMenu.button("S%d" % i)
		b.name = "Slot%d" % i
		b.custom_minimum_size = Vector2(36, TOUCH_H)
		var slot := i
		b.pressed.connect(_select_slot.bind(slot))
		slots.add_child(b)
	_select_slot(GameState.active_slot)
	var party_panel := PanelContainer.new()
	party_panel.add_theme_stylebox_override("panel", UiMenu.inner_style())
	content.add_child(party_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	party_panel.add_child(row)
	for h in GameState.party:
		row.add_child(_hero_block(h))
	# plek
	var place_panel := PanelContainer.new()
	place_panel.add_theme_stylebox_override("panel", UiMenu.inner_style())
	content.add_child(place_panel)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 0)
	place_panel.add_child(pcol)
	place_label = UiMenu.label(place if place != "" else "-")
	place_label.clip_text = true
	pcol.add_child(place_label)
	# wat er nu in het slot staat (alleen als er al een save is)
	slot_label = UiMenu.label("", MenuColors.TEXT_DIM)
	slot_label.clip_text = true
	pcol.add_child(slot_label)
	_refresh_question()
	# tijd/goud + vraag
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	content.add_child(bottom)
	var tg := PanelContainer.new()
	tg.add_theme_stylebox_override("panel", UiMenu.inner_style())
	tg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(tg)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	tg.add_child(grid)
	grid.add_child(UiMenu.label("Time", MenuColors.TEXT_DIM))
	time_label = UiMenu.label(UiMenu.format_time(GameState.play_time()))
	grid.add_child(time_label)
	grid.add_child(UiMenu.label("Gold", MenuColors.TEXT_DIM))
	gold_label = UiMenu.label(str(GameState.gold))
	grid.add_child(gold_label)
	var ask := PanelContainer.new()
	ask.add_theme_stylebox_override("panel", UiMenu.inner_style(MenuColors.BORDER))
	ask.custom_minimum_size.x = ASK_W
	bottom.add_child(ask)
	var acol := VBoxContainer.new()
	acol.add_theme_constant_override("separation", 0)
	ask.add_child(acol)
	question_label = UiMenu.label("")
	acol.add_child(question_label)
	# Yes/No naast elkaar (elk 48dp hoog): zo past het hele scherm op 216 hoog
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 2)
	acol.add_child(answers)
	yes_button = UiMenu.button("Yes")
	yes_button.custom_minimum_size = Vector2(BUTTON_W, TOUCH_H)
	yes_button.pressed.connect(answer.bind(true))
	answers.add_child(yes_button)
	no_button = UiMenu.button("No")
	no_button.custom_minimum_size = Vector2(BUTTON_W, TOUCH_H)
	no_button.pressed.connect(answer.bind(false))
	answers.add_child(no_button)
	TargetList.link_ring([yes_button, no_button])
	yes_button.focus_neighbor_right = yes_button.get_path_to(no_button)
	no_button.focus_neighbor_left = no_button.get_path_to(yes_button)
	set_hint("A: choose   B: back")
	_refresh_question()
	yes_button.grab_focus()


func _select_slot(slot: int) -> void:
	chosen_slot = slot
	if question_label != null:
		_refresh_question()


func _refresh_question() -> void:
	var rec := GameState.slot_record(chosen_slot)
	overwrite = not rec.is_empty()
	if question_label != null:
		question_label.text = Q_OVERWRITE if overwrite else Q_NEW
	if slot_label != null:
		slot_label.visible = overwrite
		slot_label.text = _summary_of(rec.get("data", {})) if overwrite else ""


func _hero_block(h: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size.x = HERO_W
	box.add_theme_constant_override("separation", 3)
	var view := HeroPortrait.make_view(MINI_BOX)
	HeroPortrait.show_mini(view, h)
	box.add_child(view)
	hero_views.append(view)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -1)
	box.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	col.add_child(top)
	var nm := UiMenu.label(str(h.get("name", "")), MenuColors.hero_color(str(h.get("accent", ""))))
	top.add_child(nm)
	top.add_child(UiMenu.label("Lv %d" % int(h.get("level", 1)), MenuColors.TEXT_DIM))
	col.add_child(UiMenu.label("HP %d/%d" % [int(h["hp"]), int(h["max_hp"])]))
	var has_mp := int(h["max_mp"]) > 0
	col.add_child(UiMenu.label("MP %d/%d" % [int(h["mp"]), int(h["max_mp"])] if has_mp else "MP --",
			MenuColors.TEXT if has_mp else MenuColors.TEXT_OFF))
	return box


func _summary_of(d: Dictionary) -> String:
	if d.is_empty():
		return ""
	var who := ""
	var p = d.get("party", [])
	if p is Array and not p.is_empty() and p[0] is Dictionary:
		var lv = p[0].get("level", 1)
		who = "%s Lv %d, " % [str(p[0].get("name", "")), int(lv) if (lv is int or lv is float) else 1]
	var t = d.get("play_time", 0.0)
	return "In the slot: %sTime %s" % [who, UiMenu.format_time(float(t) if (t is int or t is float) else 0.0)]


func answer(yes: bool) -> void:
	if _answered:
		return
	_answered = true
	if yes:
		GameState.active_slot = chosen_slot
	answered.emit(yes)
	close()


func back() -> void:
	answer(false)


func _handle_input() -> void:
	time_label.text = UiMenu.format_time(GameState.play_time())
