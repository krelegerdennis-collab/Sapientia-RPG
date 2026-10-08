extends "res://scripts/ui/menu_screen.gd"
## v0.14 (RPG CODE, menu L2) Veldmenu > Uitrusting, in de stijl van Lufia 2:
##   links : portret (hero_portrait.gd), naam, Lv, HP, MP en de stats ATK, DEF, MAG, MDEF,
##           SPD. Bij het kiezen van een stuk: 'oud > nieuw' met een pijl (groen omhoog =
##           beter, rood omlaag = slechter, grijs = gelijk).
##   rechts: de vakken Wapen, Schild, Helm, Harnas, Accessoire, en daaronder het submenu
##           Uitrusten, Sterkste, Afdoen, Alles afdoen, Weggooien
##           (bij Uitrusten staat daar de lijst met stukken uit de tas die passen).
## Besturing: omhoog/omlaag + A, B = een stap terug, links/rechts of '<' '>' = andere held
## (niet in de lijst). Tikken kan overal; tik op een vak = meteen Uitrusten in dat vak.
## Alle regels (tas <-> vakken, niets dubbel of kwijt) staan in scripts/equipment.gd.

const Equipment := preload("res://scripts/equipment.gd")
const HeroPortrait := preload("res://scripts/ui/hero_portrait.gd")
const StatArrow := preload("res://scripts/ui/stat_arrow.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")
const SavePrompt := preload("res://scripts/ui/save_prompt.gd")

const LEFT_W := 150            # linkerkolom (portret + stats)
const PORTRAIT_BOX := Vector2(64, 80)
const SLOT_COLS := 11          # tekens voor de vaknaam ('Accessoire' + spatie)
const STAT_KEY_W := 30         # 'MDEF'
const STAT_NUM_W := 20         # '999'
const CMD_W := 92              # breedte van een submenu-knop (2 kolommen)
const LIST_ROWS := 3           # zichtbare regels van de lijst (scrollt)
const NAME_COLS := 19          # 'Zilveren Bladwijzer'

## [id, tekst] van het submenu; kolom voor kolom (omlaag loopt door naar de 2e kolom).
const COMMANDS := [
	["equip", "Uitrusten"],
	["strongest", "Sterkste"],
	["unequip", "Afdoen"],
	["unequip_all", "Alles afdoen"],
	["drop", "Weggooien"],
]
const HINT_CMD := "A: kiezen   <  >: held   B: terug"
const HINT_SLOT := {"equip": "Welk vak?   A: kiezen   B: terug",
	"unequip": "Wat afdoen?   A: afdoen   B: terug",
	"drop": "Wat weggooien?   A: kiezen   B: terug"}
const MSG_NOTHING_FITS := "Niets in de tas dat hier past."

var index := 0
## "command" (submenu), "slot" (vak kiezen), "item" (stuk kiezen), "confirm" (weggooien?)
var mode := "command"
## Wat er met een gekozen vak gebeurt: "equip", "unequip" of "drop".
var action := "equip"
var current_slot := ""
var prev_button: Button
var next_button: Button
var page_label: Label
var portrait_view: CenterContainer
var name_label: Label
var level_label: Label
var hp_label: Label
var mp_label: Label
## stat -> {"old": Label, "arrow": StatArrow, "new": Label}
var stat_rows := {}
var slot_buttons := {}         # vak -> Button
var cmd_buttons := {}          # id -> Button
var cmd_panel: PanelContainer
var list_panel: PanelContainer
var list_scroll: ScrollContainer
var list_box: VBoxContainer
var list_buttons: Array[Button] = []
var list_ids: Array = []
var confirm: CanvasLayer = null
var _last_cmd := "equip"


func hero() -> Dictionary:
	return GameState.party[index] if index < GameState.party.size() else {}


func _build() -> void:
	header.text = "Uitrusting"
	prev_button = arrow_button("<")
	prev_button.pressed.connect(switch.bind(-1))
	page_label = UiMenu.label("", MenuColors.TEXT_DIM)
	next_button = arrow_button(">")
	next_button.pressed.connect(switch.bind(1))
	for c in [prev_button, page_label, next_button]:
		header_row.add_child(c)
		header_row.move_child(c, header_row.get_child_count() - 2)   # vóór 'Terug'
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	content.add_child(body)
	_build_left(body)
	_build_right(body)
	var multi := GameState.party.size() > 1
	prev_button.visible = multi
	next_button.visible = multi
	page_label.visible = multi
	show_member(index)
	to_command_mode("equip")


func _build_left(body: HBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LEFT_W
	left.add_theme_constant_override("separation", 3)
	body.add_child(left)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	left.add_child(top)
	var frame := PanelContainer.new()
	var fs := UiMenu.inner_style()
	fs.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", fs)
	top.add_child(frame)
	portrait_view = HeroPortrait.make_view(PORTRAIT_BOX)
	frame.add_child(portrait_view)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	top.add_child(info)
	name_label = UiMenu.label("")
	level_label = UiMenu.label("", MenuColors.TEXT_DIM)
	hp_label = UiMenu.label("")
	mp_label = UiMenu.label("")
	for l in [name_label, level_label, hp_label, mp_label]:
		l.clip_text = true
		l.custom_minimum_size.x = LEFT_W - PORTRAIT_BOX.x - 8
		info.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 0)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 3)
	pad.add_child(grid)
	left.add_child(pad)
	for s in Equipment.stats():
		var k := UiMenu.label(Equipment.stat_label(s), MenuColors.TEXT_DIM)
		k.custom_minimum_size.x = STAT_KEY_W
		grid.add_child(k)
		var old := UiMenu.label("")
		old.custom_minimum_size.x = STAT_NUM_W
		old.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(old)
		var arrow := StatArrow.new()
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(arrow)
		var nw := UiMenu.label("")
		nw.custom_minimum_size.x = STAT_NUM_W
		nw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(nw)
		stat_rows[s] = {"old": old, "arrow": arrow, "new": nw}


func _build_right(body: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	body.add_child(right)
	var slot_panel := PanelContainer.new()
	slot_panel.add_theme_stylebox_override("panel", UiMenu.inner_style())
	right.add_child(slot_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	slot_panel.add_child(col)
	var list: Array = []
	for s in Equipment.slots():
		var b := UiMenu.button("")
		b.custom_minimum_size = Vector2(0, ROW_H)
		b.clip_text = true
		b.pressed.connect(choose_slot.bind(str(s)))
		lock_horizontal_focus(b)
		col.add_child(b)
		slot_buttons[s] = b
		list.append(b)
	TargetList.link_ring(list)
	# submenu (2 kolommen, kolom voor kolom)
	cmd_panel = PanelContainer.new()
	cmd_panel.add_theme_stylebox_override("panel", UiMenu.inner_style())
	cmd_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(cmd_panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 2)
	cmd_panel.add_child(cols)
	var c1 := VBoxContainer.new()
	var c2 := VBoxContainer.new()
	for c in [c1, c2]:
		c.add_theme_constant_override("separation", 0)
		cols.add_child(c)
	var order: Array = []
	for i in COMMANDS.size():
		var id := str(COMMANDS[i][0])
		var b := UiMenu.button(str(COMMANDS[i][1]))
		b.custom_minimum_size = Vector2(CMD_W, ROW_H)
		b.pressed.connect(do_command.bind(id))
		lock_horizontal_focus(b)
		(c1 if i < 3 else c2).add_child(b)
		cmd_buttons[id] = b
		order.append(b)
	TargetList.link_ring(order)
	# lijst met stukken (zelfde plek als het submenu)
	list_panel = PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", UiMenu.inner_style(MenuColors.BORDER_DARK))
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.visible = false
	right.add_child(list_panel)
	list_scroll = ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	list_scroll.scroll_deadzone = 6
	list_scroll.custom_minimum_size.y = ROW_H * LIST_ROWS
	list_panel.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 0)
	list_scroll.add_child(list_box)


# ---------------------------------------------------------------- tonen
func show_member(i: int) -> void:
	if GameState.party.is_empty():
		return
	index = posmod(i, GameState.party.size())
	var h := hero()
	page_label.text = "%d/%d" % [index + 1, GameState.party.size()]
	HeroPortrait.show_portrait(portrait_view, h)
	name_label.text = str(h.get("name", ""))
	name_label.add_theme_color_override("font_color", MenuColors.hero_color(str(h.get("accent", ""))))
	level_label.text = "%s Lv %d" % [str(h.get("class", "")), int(h.get("level", 1))]
	hp_label.text = "HP %d/%d" % [int(h["hp"]), int(h["max_hp"])]
	mp_label.text = "MP %d/%d" % [int(h["mp"]), int(h["max_mp"])] if int(h["max_mp"]) > 0 else "MP --"
	mp_label.add_theme_color_override("font_color", MenuColors.TEXT if int(h["max_mp"]) > 0 else MenuColors.TEXT_OFF)
	refresh_slots()
	show_stats()


func refresh_slots() -> void:
	var h := hero()
	for s in Equipment.slots():
		var id := Equipment.equipped(h, s)
		var nm := Equipment.item_name(id) if id != "" else "-"
		UiMenu.set_label(slot_buttons[s], "%s%s" % [Equipment.slot_name(s).rpad(SLOT_COLS), nm])


## Stats zonder vergelijking (alleen de huidige waarde).
func show_stats() -> void:
	var eff := Equipment.effective_stats(hero())
	for s in stat_rows:
		var r: Dictionary = stat_rows[s]
		r["old"].text = str(eff[s])
		r["arrow"].shown = false        # blijft in het raster (anders schuiven de kolommen)
		r["new"].text = ""


## Vergelijking 'oud > nieuw' met pijlen (voor een stuk in de lijst, of na Sterkste).
func show_compare(before: Dictionary, after: Dictionary) -> void:
	var cmp := Equipment.compare(before, after)
	for s in stat_rows:
		var r: Dictionary = stat_rows[s]
		r["old"].text = str(before[s])
		r["arrow"].shown = true
		r["arrow"].dir = int(cmp[s])
		r["new"].text = str(after[s])
		var c := MenuColors.TEXT
		if int(cmp[s]) > 0:
			c = MenuColors.BETTER
		elif int(cmp[s]) < 0:
			c = MenuColors.WORSE
		r["new"].add_theme_color_override("font_color", c)


## Voor de test: richting van de pijl bij een stat (1/-1/0), of null als er geen pijl is.
func arrow_dir(stat: String):
	var r: Dictionary = stat_rows[stat]
	return int(r["arrow"].dir) if r["arrow"].shown else null


func new_value_text(stat: String) -> String:
	return str(stat_rows[stat]["new"].text)


func old_value_text(stat: String) -> String:
	return str(stat_rows[stat]["old"].text)


func new_value_color(stat: String) -> Color:
	return stat_rows[stat]["new"].get_theme_color("font_color")


# ---------------------------------------------------------------- modi
## Knoppen weer gewoon tonen (geen '>' en gewone kleur, behalve wie focus heeft).
func _unmark(buttons: Array) -> void:
	for b in buttons:
		UiMenu.set_label(b, str(b.get_meta("label", "")))


func _set_focusable(buttons: Array, on: bool) -> void:
	for b in buttons:
		b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func to_command_mode(focus_id := "") -> void:
	mode = "command"
	quiet()
	current_slot = ""
	list_panel.visible = false
	cmd_panel.visible = true
	_set_focusable(slot_buttons.values(), false)
	_set_focusable(cmd_buttons.values(), true)
	_unmark(slot_buttons.values())
	_unmark(cmd_buttons.values())
	cmd_buttons[focus_id if focus_id != "" else _last_cmd].grab_focus()
	set_hint(HINT_CMD)


func to_slot_mode(act: String, focus_slot := "") -> void:
	mode = "slot"
	action = act
	quiet()
	list_panel.visible = false
	cmd_panel.visible = true
	_set_focusable(cmd_buttons.values(), false)
	_set_focusable(slot_buttons.values(), true)
	_unmark(slot_buttons.values())
	_unmark(cmd_buttons.values())
	mark_chosen(cmd_buttons[act])
	var s := focus_slot if focus_slot != "" else str(Equipment.slots()[0])
	slot_buttons[s].grab_focus()
	set_hint(str(HINT_SLOT.get(act, HINT_CMD)))
	show_stats()


## Submenu-keuze (A of tik).
func do_command(id: String) -> void:
	if mode == "confirm":
		return
	_last_cmd = id
	clear_message()
	var h := hero()
	match id:
		"equip", "unequip", "drop":
			to_slot_mode(id, current_slot)
		"strongest":
			var before := Equipment.effective_stats(h)
			var n := Equipment.strongest(h, GameState.inventory)
			refresh_slots()
			show_compare(before, Equipment.effective_stats(h))
			show_message(Equipment.MSG_STRONGEST if n > 0 else Equipment.MSG_STRONGEST_SAME, MenuColors.INFO)
		"unequip_all":
			var n2 := Equipment.unequip_all(h, GameState.inventory)
			refresh_slots()
			show_stats()
			show_message(Equipment.MSG_ALL_REMOVED if n2 > 0 else Equipment.MSG_NOTHING_ON % str(h.get("name", "")),
					MenuColors.INFO if n2 > 0 else MenuColors.TEXT_DIM)


## Vak gekozen (A of tik). Tik op een vak vanuit het submenu = Uitrusten in dat vak.
func choose_slot(slot: String) -> void:
	if mode == "confirm" or mode == "item":
		return
	if mode == "command":
		to_slot_mode("equip", slot)
	current_slot = slot
	var h := hero()
	match action:
		"equip":
			open_list(slot)
		"unequip":
			var r := Equipment.unequip(h, GameState.inventory, slot)
			refresh_slots()
			show_stats()
			show_message(str(r["text"]), MenuColors.INFO if r["ok"] else MenuColors.TEXT_DIM)
		"drop":
			var id := Equipment.equipped(h, slot)
			if id == "":
				show_message(Equipment.MSG_EMPTY_SLOT, MenuColors.TEXT_DIM)
				return
			ask_drop(slot, id)


func open_list(slot: String) -> void:
	var h := hero()
	var ids := Equipment.candidates(h, GameState.inventory, slot)
	if ids.is_empty():
		show_message(MSG_NOTHING_FITS, MenuColors.TEXT_DIM)
		return
	mode = "item"
	current_slot = slot
	quiet()
	for b in list_buttons:
		b.queue_free()
	list_buttons.clear()
	list_ids = ids
	for id in ids:
		var b := UiMenu.button("%s x%d" % [Equipment.item_name(id).rpad(NAME_COLS), GameState.item_count(id)])
		b.custom_minimum_size = Vector2(0, ROW_H)
		b.clip_text = true
		b.focus_entered.connect(preview_item.bind(str(id)))
		b.pressed.connect(choose_item.bind(str(id)))
		lock_horizontal_focus(b)
		list_box.add_child(b)
		list_buttons.append(b)
	TargetList.link_ring(list_buttons)
	cmd_panel.visible = false
	list_panel.visible = true
	_set_focusable(slot_buttons.values(), false)
	mark_chosen(slot_buttons[slot])
	clear_message()
	list_buttons[0].grab_focus()
	preview_item(str(ids[0]))


## Stuk in de lijst heeft focus: pijlen 'oud > nieuw' en de bonus in de hulpregel.
func preview_item(id: String) -> void:
	if mode != "item":
		return
	var h := hero()
	show_compare(Equipment.effective_stats(h), Equipment.preview(h, current_slot, id))
	set_hint("%s: %s" % [Equipment.item_name(id), Equipment.bonus_text(id)])


func choose_item(id: String) -> void:
	if mode != "item":
		return
	var slot := current_slot
	var r := Equipment.equip(hero(), GameState.inventory, slot, id)
	_close_list()
	to_slot_mode("equip", slot)
	refresh_slots()
	show_stats()
	show_message(str(r["text"]), MenuColors.INFO if r["ok"] else MenuColors.TEXT_DIM)


func _close_list() -> void:
	for b in list_buttons:
		b.queue_free()
	list_buttons.clear()
	list_ids = []
	list_panel.visible = false
	cmd_panel.visible = true


func ask_drop(slot: String, id: String) -> void:
	mode = "confirm"
	var p := SavePrompt.new()
	p.question = "%s weggooien?" % Equipment.item_name(id)
	p.detail = "Het is daarna echt weg."
	p.default_no = true
	p.answered.connect(_on_drop_answer.bind(slot))
	confirm = p
	add_child(p)


func _on_drop_answer(yes: bool, slot: String) -> void:
	confirm = null
	mode = "slot"
	quiet()
	var h := hero()
	if yes:
		var r := Equipment.drop(h, slot)
		refresh_slots()
		show_stats()
		show_message(str(r["text"]), MenuColors.INFO)
	slot_buttons[slot].grab_focus()


func switch(dir: int) -> void:
	if GameState.party.size() <= 1 or mode == "item" or mode == "confirm":
		return
	show_member(index + dir)
	if mode == "slot":
		to_slot_mode(action, current_slot)


func back() -> void:
	match mode:
		"confirm":
			return
		"item":
			var slot := current_slot
			_close_list()
			to_slot_mode("equip", slot)
		"slot":
			to_command_mode(action)
		_:
			close()


func _handle_input() -> void:
	if mode == "confirm":
		return
	var d := horizontal_pressed()
	if d != 0:
		switch(d)


func _process(delta: float) -> void:
	if mode == "confirm":
		# de vraag (save_prompt.gd) regelt zelf A/B; hier alleen de melding laten aflopen
		if _message_left > 0.0:
			_message_left -= delta
		return
	super._process(delta)
