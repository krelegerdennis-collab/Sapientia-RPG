extends "res://scripts/ui/menu_screen.gd"
## v0.11 Veldmenu > Magie: de spreuken van één held (links/rechts = andere held).
##   links : spreuken met MP-kosten (grijs = kan hier niet, bv. Vuur, of te weinig MP)
##   rechts: uitleg + effect; A op een genees-spreuk = 'Op wie?' + de helden
## Genezen buiten het gevecht: party_actions.gd (zelfde formule als in het gevecht,
## MP eraf, HP geclampt op max_hp).

const PartyActions := preload("res://scripts/party_actions.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")

const LIST_W := 132
const NAME_COLS := 9
const HINT_LIST := "A: use   <  >: other hero   B: back"
const HINT_LIST_SOLO := "A: use   B: back"
const HINT_TARGET := "On whom?   A: use   B: other choice"

var caster_index := 0
var prev_button: Button
var next_button: Button
var caster_label: Label
var list: VBoxContainer
var entries: Array[Button] = []
var spell_ids: Array = []
var name_label: Label
var desc_label: Label
var targets: TargetList
var selected_id := ""
var targeting := false


func _build() -> void:
	header.text = "Magic"
	prev_button = arrow_button("<")
	prev_button.pressed.connect(switch.bind(-1))
	caster_label = UiMenu.label("", MenuColors.TEXT)
	next_button = arrow_button(">")
	next_button.pressed.connect(switch.bind(1))
	for c in [prev_button, caster_label, next_button]:
		header_row.add_child(c)
		header_row.move_child(c, header_row.get_child_count() - 2)   # vóór 'Terug'
	var multi := GameState.party.size() > 1
	prev_button.visible = multi
	next_button.visible = multi
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	content.add_child(body)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(LIST_W, 0)
	list.add_theme_constant_override("separation", 0)
	body.add_child(list)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 2)
	body.add_child(detail)
	name_label = UiMenu.label("", MenuColors.ACCENT)
	detail.add_child(name_label)
	desc_label = UiMenu.label("", MenuColors.TEXT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(100, 0)
	detail.add_child(desc_label)
	targets = TargetList.new()
	targets.visible = false
	targets.chosen.connect(_on_target_chosen)
	detail.add_child(targets)
	# begin bij de eerste held die magie kent
	for i in GameState.party.size():
		if not GameState.party[i].get("spells", []).is_empty():
			caster_index = i
			break
	show_caster(caster_index)


func caster() -> Dictionary:
	return GameState.party[caster_index] if not GameState.party.is_empty() else {}


func show_caster(i: int, keep_id := "") -> void:
	if GameState.party.is_empty():
		return
	caster_index = posmod(i, GameState.party.size())
	var c := caster()
	caster_label.text = "%s  MP %d/%d" % [c["name"], int(c["mp"]), int(c["max_mp"])]
	for b in entries:
		b.queue_free()
	entries.clear()
	spell_ids = c.get("spells", []).duplicate()
	for sid in spell_ids:
		var sp := PartyActions.spell_data(str(sid))
		var b := UiMenu.button("%s %2d MP" % [str(sp.get("name", sid)).rpad(NAME_COLS), int(sp.get("mp", 0))])
		b.custom_minimum_size = Vector2(LIST_W - 4, TOUCH_H)
		b.focus_entered.connect(show_spell.bind(str(sid)))
		b.pressed.connect(choose_spell.bind(str(sid)))
		if PartyActions.spell_block_reason(c, str(sid)) != "":
			_grey(b)
		list.add_child(b)
		entries.append(b)
	TargetList.link_ring(entries)
	set_hint(HINT_LIST if GameState.party.size() > 1 else HINT_LIST_SOLO)
	if entries.is_empty():
		selected_id = ""
		var anyone := GameState.party.any(func(h): return not h.get("spells", []).is_empty())
		name_label.text = "%s knows no magic." % c["name"]
		desc_label.text = "" if anyone else "Nobody in the party knows magic yet."
		back_button.grab_focus()
		return
	var k := maxi(0, spell_ids.find(keep_id))
	entries[k].grab_focus()
	show_spell(str(spell_ids[k]))


func entry_text(i: int) -> String:
	return str(entries[i].get_meta("label", ""))


func is_greyed(i: int) -> bool:
	return is_button_greyed(entries[i])


func show_spell(id: String) -> void:
	if targeting:
		return
	selected_id = id
	var sp := PartyActions.spell_data(id)
	name_label.text = str(sp.get("name", id))
	var lines := [PartyActions.spell_effect_text(caster(), id)]
	var reason := PartyActions.spell_block_reason(caster(), id)
	if reason != "":
		lines.append(reason)
	desc_label.text = "\n".join(lines)


func choose_spell(id: String) -> void:
	if targeting:
		return
	show_spell(id)
	var reason := PartyActions.spell_block_reason(caster(), id)
	if reason != "":
		show_message(reason, MenuColors.TEXT_DIM)
		return
	targeting = true
	quiet()
	desc_label.visible = false
	name_label.text = "%s - on whom?" % str(PartyActions.spell_data(id).get("name", id))
	targets.build(GameState.party)
	targets.visible = true
	for b in entries:
		b.focus_mode = Control.FOCUS_NONE
	if spell_ids.has(id):
		mark_chosen(entries[spell_ids.find(id)])
	targets.focus_first()
	set_hint(HINT_TARGET)


func _stop_targeting() -> void:
	targeting = false
	quiet()
	targets.visible = false
	desc_label.visible = true
	for b in entries:
		b.focus_mode = Control.FOCUS_ALL
	show_caster(caster_index, selected_id)


func _on_target_chosen(index: int) -> void:
	if not targeting or index < 0 or index >= GameState.party.size():
		return
	var r := PartyActions.cast_spell(caster(), selected_id, GameState.party[index])
	show_message(str(r["text"]), MenuColors.INFO if r["ok"] else MenuColors.TEXT_DIM)
	targets.refresh()
	var c := caster()
	caster_label.text = "%s  MP %d/%d" % [c["name"], int(c["mp"]), int(c["max_mp"])]
	if PartyActions.spell_block_reason(c, selected_id) != "":
		_stop_targeting()      # te weinig MP voor nog een keer
		show_message(str(r["text"]), MenuColors.INFO if r["ok"] else MenuColors.TEXT_DIM)


func switch(dir: int) -> void:
	if targeting or GameState.party.size() <= 1:
		return
	clear_message()
	show_caster(caster_index + dir)


func _handle_input() -> void:
	var d := horizontal_pressed()
	if d != 0:
		switch(d)


func back() -> void:
	if targeting:
		_stop_targeting()
	else:
		close()
