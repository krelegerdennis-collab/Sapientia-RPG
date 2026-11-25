extends "res://scripts/ui/menu_screen.gd"
## v0.11 Veldmenu > Items: alles uit GameState.inventory met aantal en uitleg.
##   links : lijst 'Drankje     x3' (grijs = kan hier niet gebruikt worden)
##   rechts: naam, beschrijving, effect; na A op een bruikbaar item: 'Op wie?' + de helden
## Gebruiken buiten het gevecht: party_actions.gd (HP/MP geclampt, aantal -1, op 0 weg).
## B in de doelkeuze = terug naar de lijst; B in de lijst = terug naar het hoofdmenu.

const PartyActions := preload("res://scripts/party_actions.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Dungeon100Reward := preload("res://scripts/data/dungeon100_reward.gd")
const ItemIcons := preload("res://scripts/data/item_icons.gd")

const LIST_W := 132            # breedte van de itemlijst (minimum)
const LIST_W_MAX := 176        # post-RC: lijst groeit tot hier mee met de langste naam (detail houdt >= 176 op 384 breed)
const NAME_COLS := PartyActions.LIST_NAME_COLS   # tekens voor de naam, daarna 'x3' (minimum)
const HINT_LIST := "A: use   B: back"
const HINT_TARGET := "On whom?   A: use   B: other choice"
const PERMANENT_NOTE := "Blue databank: this stays."

var scroll: ScrollContainer
var list: VBoxContainer
var entries: Array[Button] = []
var ids: Array = []
var name_label: Label
var desc_label: Label
var effect_label: Label
var detail_icon: TextureRect
var targets: TargetList
var empty_label: Label
var selected_id := ""
var targeting := false
var name_cols := NAME_COLS     # post-RC: naamkolom = langste naam in de lijst (minstens NAME_COLS)


func _build() -> void:
	header.text = "Items"
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
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
	empty_label = UiMenu.label("Your bag is empty.", MenuColors.TEXT_DIM)
	list.add_child(empty_label)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 2)
	body.add_child(detail)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	detail.add_child(title_row)
	detail_icon = ItemIcons.make_rect(ItemIcons.SIZE32)
	detail_icon.name = "DetailIcon"
	title_row.add_child(detail_icon)
	name_label = UiMenu.label("", MenuColors.TITLE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(name_label)
	desc_label = UiMenu.label("", MenuColors.TEXT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(100, 0)
	detail.add_child(desc_label)
	effect_label = UiMenu.label("", MenuColors.INFO)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.custom_minimum_size = Vector2(100, 0)
	detail.add_child(effect_label)
	targets = TargetList.new()
	targets.visible = false
	targets.chosen.connect(_on_target_chosen)
	detail.add_child(targets)
	set_hint(HINT_LIST)
	rebuild()


## Lijst opnieuw opbouwen uit de inventaris (na gebruik kan een item verdwijnen).
func rebuild(keep_id := "") -> void:
	for b in entries:
		b.queue_free()
	entries.clear()
	ids = []
	for id in GameState.inventory:
		if GameState.item_count(str(id)) > 0:
			ids.append(id)
	# vaste volgorde: zoals in game_data.gd ITEMS, dan de uitrusting (v0.14, EQUIPMENT),
	# onbekende id's achteraan
	var order: Array = GameData.ITEMS.keys() + GameData.EQUIPMENT.keys()
	ids.sort_custom(func(a, b):
		var ia := order.find(a)
		var ib := order.find(b)
		ia = ia if ia >= 0 else order.size()
		ib = ib if ib >= 0 else order.size()
		return ia < ib if ia != ib else str(a) < str(b))
	# post-RC: volle namen (geen harde knip na 13 tekens); 'x3' blijft in één kolom
	name_cols = NAME_COLS
	for id in ids:
		name_cols = maxi(name_cols, list_name(str(id)).length())
	var need := 0.0
	for id in ids:
		var b := touch_row(UiMenu.button(entry_label(id)))
		b.custom_minimum_size = Vector2(LIST_W - 4, ROW_H)
		ItemIcons.apply16(b, str(id))
		b.focus_entered.connect(show_item.bind(id))
		b.pressed.connect(choose_item.bind(id))
		if not PartyActions.item_usable_in_field(id):
			_grey(b)
		if GameState.is_permanent_item(id):
			tint_permanent(b)
		list.add_child(b)
		entries.append(b)
		# breedte met volle tekst meten, daarna knippen met '…' (alleen als het echt niet past)
		need = maxf(need, b.get_combined_minimum_size().x)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fit_list_width(need)
	TargetList.link_ring(entries)
	empty_label.visible = entries.is_empty()
	if entries.is_empty():
		selected_id = ""
		name_label.text = ""
		desc_label.text = ""
		effect_label.text = ""
		ItemIcons.show32(detail_icon, "")
		back_button.grab_focus()
		return
	var i := maxi(0, ids.find(keep_id))
	entries[i].grab_focus()
	show_item(ids[i])


## Naam in de lijst: met 'short' (game_data.gd) de korte naam als de volle te lang is, anders de volle naam.
func list_name(id: String) -> String:
	if PartyActions.item_data(id).has("short"):
		return PartyActions.item_list_name(id, NAME_COLS)
	return PartyActions.item_name(id)


func entry_label(id: String) -> String:
	return "%s x%d" % [list_name(id).rpad(name_cols), GameState.item_count(id)]


## Lijst zo breed als de langste regel (+ schuifbalk), tussen LIST_W en LIST_W_MAX.
func _fit_list_width(need: float) -> void:
	if need <= LIST_W - 4:
		# past al: precies de oude maat (LIST_W, knoppen LIST_W - 4)
		scroll.custom_minimum_size.x = LIST_W
		for b in entries:
			b.custom_minimum_size.x = LIST_W - 4
		return
	var bar := scroll.get_v_scroll_bar()
	var bar_w := bar.get_combined_minimum_size().x if bar != null else 0.0
	var w := clampf(ceilf(need + bar_w + 4.0), LIST_W, LIST_W_MAX)
	scroll.custom_minimum_size.x = w
	for b in entries:
		b.custom_minimum_size.x = w - 4.0 - bar_w


func entry_text(i: int) -> String:
	return str(entries[i].get_meta("label", ""))


func is_greyed(i: int) -> bool:
	return is_button_greyed(entries[i])


func show_item(id: String) -> void:
	if targeting:
		return
	selected_id = id
	var it := PartyActions.item_data(id)
	ItemIcons.show32(detail_icon, id)
	name_label.text = PartyActions.item_name(id)
	desc_label.text = str(it.get("desc", ""))
	var reason := PartyActions.item_block_reason(id)
	if reason == "" or bool(it.get("equip", false)):
		# v0.14: bij uitrusting staat hier het vak en de bonus ('Wapen: ATK +3.')
		effect_label.text = PartyActions.item_effect_text(id)
		effect_label.add_theme_color_override("font_color", MenuColors.INFO)
	else:
		effect_label.text = reason
		effect_label.add_theme_color_override("font_color", MenuColors.TEXT_DIM)
	if GameState.is_permanent_item(id):
		effect_label.text = (effect_label.text + "\n" if effect_label.text != "" else "") + PERMANENT_NOTE
		effect_label.add_theme_color_override("font_color", MenuColors.PERMANENT)


## A / tik op een item: bruikbaar = doel kiezen, anders een melding.
func choose_item(id: String) -> void:
	if targeting:
		return
	show_item(id)
	var reason := PartyActions.item_block_reason(id)
	if reason != "":
		show_message(reason, MenuColors.TEXT_DIM)
		return
	if bool(PartyActions.item_data(id).get("warp", false)):
		show_message(PartyActions.MSG_WARP_USED, MenuColors.INFO)
		var keuze: int = await Dialog.ask(Dungeon100Reward.VRAAG, Dungeon100Reward.KEUZES)
		if keuze < 0 or keuze >= Dungeon100Reward.IDS.size():
			return
		GameState.dungeon100_warp(Dungeon100Reward.IDS[keuze])
		return
	_start_targeting()


func _start_targeting() -> void:
	targeting = true
	quiet()
	desc_label.visible = false
	effect_label.visible = false
	name_label.text = "%s x%d - on whom?" % [PartyActions.item_name(selected_id), GameState.item_count(selected_id)]
	targets.build(GameState.party)
	targets.visible = true
	for b in entries:
		b.focus_mode = Control.FOCUS_NONE
	mark_chosen(entries[ids.find(selected_id)] if ids.has(selected_id) else null)
	targets.focus_first()
	set_hint(HINT_TARGET)


func _stop_targeting() -> void:
	targeting = false
	quiet()
	targets.visible = false
	desc_label.visible = true
	effect_label.visible = true
	for b in entries:
		b.focus_mode = Control.FOCUS_ALL
	set_hint(HINT_LIST)
	rebuild(selected_id)


func _on_target_chosen(index: int) -> void:
	if not targeting or index < 0 or index >= GameState.party.size():
		return
	var r := PartyActions.use_item(GameState.inventory, selected_id, GameState.party[index])
	show_message(str(r["text"]), MenuColors.INFO if r["ok"] else MenuColors.TEXT_DIM)
	UiSfx.play(UiSfx.USE_ITEM if r["ok"] else UiSfx.ERROR)
	targets.refresh()
	if GameState.item_count(selected_id) <= 0:
		_stop_targeting()
		show_message(str(r["text"]), MenuColors.INFO if r["ok"] else MenuColors.TEXT_DIM)
	else:
		name_label.text = "%s x%d - on whom?" % [PartyActions.item_name(selected_id), GameState.item_count(selected_id)]


func back() -> void:
	if targeting:
		_stop_targeting()
	else:
		close()
