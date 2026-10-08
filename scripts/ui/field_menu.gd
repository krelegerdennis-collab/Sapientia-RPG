extends CanvasLayer
## Veldmenu (overworld), zoals het START-menu van een SNES-JRPG.
## Openen: MENU-knop rechtsboven, of Esc / M / Tab (map.gd; niet tijdens tekstvak,
## gevecht of mapwissel). De speler staat zolang op slot en de touch-D-pad/A/B is
## verborgen (je tikt direct op het menu); map.gd regelt dat en geeft 'player' mee.
##   links : de groep (kaartje per held met Lv en HP/MP; tik = Status van die held)
##   rechts: de commando's  Items, Magie, Uitrusting, Status, Bestiarium, Opties, Opslaan,
##           Sluiten (v0.14: Uitrusting erbij, volgorde zoals Lufia 2)
##           en daaronder goud, speeltijd en waar je bent
## Elk scherm is een eigen script (items_screen.gd, magic_screen.gd, status_screen.gd,
## options_screen.gd, bestiary_screen.gd; v0.14: equipment_screen.gd, save_screen.gd).
## B / MENU / 'Sluiten' / tik naast het menu = dicht.
## Kleuren: menu_colors.gd (één bestand, makkelijk om te zetten naar het palet van Forge).

signal closed

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
## v0.14: menukleuren uit één bestand (menu_colors.gd), niet meer de neon van ui_style.gd
const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const PartyCard := preload("res://scripts/ui/party_card.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")
const BestiaryScreen := preload("res://scripts/ui/bestiary_screen.gd")
const ItemsScreen := preload("res://scripts/ui/items_screen.gd")
const MagicScreen := preload("res://scripts/ui/magic_screen.gd")
const StatusScreen := preload("res://scripts/ui/status_screen.gd")
const OptionsScreen := preload("res://scripts/ui/options_screen.gd")
const SavePrompt := preload("res://scripts/ui/save_prompt.gd")
const EquipmentScreen := preload("res://scripts/ui/equipment_screen.gd")
const SaveScreen := preload("res://scripts/ui/save_screen.gd")
const CodexScreen := preload("res://scripts/ui/codex_screen.gd")   # Codex (Kernfragment stap 2)

const LAYER := 20
const MARGIN := 8              # afstand tot de schermrand
const GAP := 4                 # ruimte tussen de vensters
const CMD_W := 100             # breedte van de commandolijst
const ROW_H := 16              # hoogte van een commando (tikvlak)
const CARD_BUTTON_H := 34      # kaartje van een held (PartyCard + rand)
const CARD_INDENT := 4
const PARTY_W_MAX := 200       # het groepsvenster wordt niet breder dan dit
const DIM_ALPHA := 0.45
const MESSAGE_TIME := 2.5

## [id, tekst] - volgorde in het menu.
const COMMANDS := [
	["items", "Items"],
	["magic", "Magie"],
	["equip", "Uitrusting"],
	["status", "Status"],
	["bestiary", "Bestiarium"],
	["options", "Opties"],
	["save", "Opslaan"],
	["close", "Sluiten"],
]
## Codex: staat na 'Status' in het menu zodra de Codex minstens één pagina heeft (zoals het
## capsule-menu in Lufia 2 pas verschijnt als je een capsule-monster hebt).
const CODEX_COMMAND := ["codex", "Codex"]

## De speler op de map (voor Opslaan: tile + kijkrichting). map.gd zet dit.
var player: Node2D = null
var root: Control
var command_box: PanelContainer
var info_box: PanelContainer
var party_box: PanelContainer
var buttons := {}              # id -> Button
var bestiary_button: Button    # (ook gebruikt door de autotest)
var back_button: Button        # 'Sluiten'
var party_cards: Array = []
var party_buttons: Array[Button] = []
var gold_label: Label
var time_label: Label
var place_label: Label
var message_label: Label
## v0.17 regel met de lopende opdracht (null = geen opdracht)
var quest_label: Label = null
var bestiary: CanvasLayer = null
## Open sub-scherm (Items/Magie/Status/Opties/Bestiarium/vraag) of null.
var sub: CanvasLayer = null
## Laatste uitkomst van Opslaan (voor de autotest): "", "saved", "declined" of "failed".
var last_save_result := ""
var _message_left := 0.0
var _last_focus: Button = null

## Frame waarin dit scherm (of een sub-scherm) open/dicht ging: in dat frame geen knoppen
## verwerken (anders sluit dezelfde druk op MENU/B hem meteen weer).
var _quiet_frame := -1


func _ready() -> void:
	_quiet_frame = Engine.get_process_frames()
	layer = LAYER
	root = Control.new()
	root.theme = load(UiMenu.THEME_PATH)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = MenuColors.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and sub == null:
			close())
	root.add_child(dim)
	_build_commands()
	_build_info()
	_build_party()
	_update_info()
	_layout()
	_layout.call_deferred()
	root.resized.connect(_layout)
	buttons["items"].grab_focus()


func _build_commands() -> void:
	command_box = UiMenu.panel(MenuColors.BORDER_DARK)
	root.add_child(command_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	command_box.add_child(col)
	var list: Array = []
	for c in commands():
		var b := UiMenu.button(str(c[1]))
		b.custom_minimum_size = Vector2(CMD_W - 12, ROW_H)
		b.pressed.connect(choose.bind(str(c[0])))
		b.focus_entered.connect(func(): _last_focus = b)
		col.add_child(b)
		buttons[str(c[0])] = b
		list.append(b)
	TargetList.link_ring(list)
	bestiary_button = buttons["bestiary"]
	back_button = buttons["close"]
	if get_node_or_null("/root/Settings") == null:
		buttons["options"].disabled = true


func _build_info() -> void:
	info_box = UiMenu.panel(MenuColors.BORDER_DARK)
	root.add_child(info_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	info_box.add_child(col)
	gold_label = UiMenu.label("")
	time_label = UiMenu.label("")
	place_label = UiMenu.label("", MenuColors.TEXT_DIM)
	# lange plaatsnamen (v0.11: 'Huis aan de bosrand') op 2 regels i.p.v. afgekapt
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_label.max_lines_visible = 2
	place_label.custom_minimum_size.x = CMD_W - 12
	for l in [gold_label, time_label, place_label]:
		col.add_child(l)
	message_label = UiMenu.label("", MenuColors.INFO)
	message_label.visible = false
	col.add_child(message_label)


func _build_party() -> void:
	party_box = UiMenu.panel(MenuColors.BORDER_DARK)
	root.add_child(party_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	party_box.add_child(col)
	col.add_child(UiMenu.label("Groep", MenuColors.TEXT_DIM))
	for i in GameState.party.size():
		# tikbaar kaartje (geen focus: de D-pad blijft in de commandolijst)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, CARD_BUTTON_H)
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.pressed.connect(open_status.bind(i))
		var card := PartyCard.new()
		card.setup(GameState.party[i])
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.offset_left = CARD_INDENT
		card.offset_right = -CARD_INDENT
		card.offset_top = 1
		b.add_child(card)
		col.add_child(b)
		party_buttons.append(b)
		party_cards.append(card)
	# v0.17 lopende opdracht (story_data.gd QUESTS), bv. 'Red Noor uit het Donker Woud'
	var q: String = Story.active_quest()
	if q != "":
		col.add_child(UiMenu.label("Opdracht", MenuColors.TEXT_DIM))
		quest_label = UiMenu.label(q, MenuColors.INFO)
		quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(quest_label)


## Vensters plaatsen: commando's rechtsboven, info eronder, groep links (schermbreedte
## kan op brede telefoons groter zijn dan 384: stretch aspect 'expand').
func _layout() -> void:
	var w := root.size.x if root.size.x > 0 else 384.0
	command_box.reset_size()
	command_box.size.x = CMD_W
	command_box.position = Vector2(w - MARGIN - CMD_W, MARGIN).round()
	info_box.reset_size()
	info_box.size.x = CMD_W
	info_box.position = Vector2(command_box.position.x, command_box.position.y + command_box.size.y + GAP).round()
	party_box.reset_size()
	var pw := minf(PARTY_W_MAX, command_box.position.x - GAP - MARGIN)
	party_box.size.x = pw
	party_box.position = Vector2(MARGIN, MARGIN)


func _update_info() -> void:
	gold_label.text = "Goud %d" % GameState.gold
	time_label.text = "Tijd %s" % UiMenu.format_time(GameState.play_time())
	place_label.text = _place_name()


func _place_name() -> String:
	var s := get_tree().current_scene if is_inside_tree() else null
	if s != null and "map_name" in s and str(s.map_name) != "":
		return str(s.map_name)
	return ""


func refresh_party() -> void:
	for c in party_cards:
		c.refresh()


func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	_message_left = MESSAGE_TIME
	_layout.call_deferred()


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			message_label.visible = false
			_layout.call_deferred()
	if sub != null or Engine.get_process_frames() <= _quiet_frame:
		return
	_update_info()
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
		close()
		return
	UiMenu.pad_nav(root.get_viewport())


## Commando's in menu-volgorde (COMMANDS, plus 'Codex' als er pagina's zijn).
func commands() -> Array:
	var out: Array = COMMANDS.duplicate()
	if not GameState.codex_pages.is_empty():
		var at := out.size() - 1
		for i in out.size():
			if str(out[i][0]) == "status":
				at = i + 1
		out.insert(at, CODEX_COMMAND)
	return out


## Een commando kiezen (tik, A of Enter).
func choose(id: String) -> void:
	if sub != null or is_queued_for_deletion():
		return
	match id:
		"items":
			_open_sub(ItemsScreen.new(), "Items")
		"magic":
			_open_sub(MagicScreen.new(), "Magic")
		"equip":
			open_equipment(0)
		"status":
			open_status(0)
		"bestiary":
			open_bestiary()
		"codex":
			open_codex()
		"options":
			_open_sub(OptionsScreen.new(), "Options")
		"save":
			open_save()
		"close":
			close()


func _open_sub(screen: CanvasLayer, node_name: String) -> CanvasLayer:
	sub = screen
	screen.name = node_name
	var back_to: Button = _last_focus if _last_focus else buttons["items"]
	# schermen over het hele scherm: het hoofdmenu zolang verbergen (anders schemert het
	# door het venster heen); de vraag bij Opslaan is klein, daar blijft het menu zichtbaar
	var full_screen := screen.has_signal("closed")
	root.visible = not full_screen
	var on_closed := func():
		sub = null
		root.visible = true
		if node_name == "Bestiary":
			bestiary = null
		_quiet_frame = Engine.get_process_frames()
		refresh_party()
		_update_info()
		if is_instance_valid(back_to):
			back_to.grab_focus()
	if full_screen:
		screen.closed.connect(on_closed)
	else:
		screen.answered.connect(func(_yes): on_closed.call())
	add_child(screen)
	return screen


func open_status(index := 0) -> void:
	if sub != null:
		return
	var s := StatusScreen.new()
	s.index = clampi(index, 0, maxi(0, GameState.party.size() - 1))
	_last_focus = buttons["status"]
	_open_sub(s, "Status")


func open_codex() -> void:
	if sub != null:
		return
	_last_focus = buttons.get("codex", buttons["items"])
	_open_sub(CodexScreen.new(), "Codex")


func open_bestiary() -> void:
	if sub != null:
		return
	bestiary = _open_sub(BestiaryScreen.new(), "Bestiary")


func open_equipment(index := 0) -> void:
	if sub != null:
		return
	var s := EquipmentScreen.new()
	s.index = clampi(index, 0, maxi(0, GameState.party.size() - 1))
	_last_focus = buttons["equip"]
	_open_sub(s, "Equipment")


## v0.14: Lufia 2-achtig opslagscherm (groep, plek, tijd, goud) met 'Overschrijven? Ja/Nee'
## als het slot al een save heeft. Het scherm vraagt; save_now() schrijft.
func open_save() -> void:
	if sub != null:
		return
	var p := SaveScreen.new()
	p.place = _place_name()
	p.answered.connect(_on_save_answer)
	_last_focus = buttons["save"]
	_open_sub(p, "SaveScreen")


func _on_save_answer(yes: bool) -> void:
	if not yes:
		last_save_result = "declined"
		return
	save_now()


## Opslaan in het (handmatige) slot, met de plek en kijkrichting van de speler.
func save_now() -> bool:
	if player == null or not is_instance_valid(player):
		last_save_result = "failed"
		show_message("Hier kun je niet opslaan.")
		return false
	if GameState.save_game(player.get_tile(), player.facing):
		last_save_result = "saved"
		show_message("Opgeslagen.")
		return true
	last_save_result = "failed"
	show_message("Opslaan mislukt.")
	return false


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
