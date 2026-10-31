extends CanvasLayer
## Veldmenu: vier losse knoppen. Elke knop opent meteen een scherm. Geen tussenmenu.
## Het bord "MENU" is alleen een label.
## TODO(design): voorlopige indeling. Dennis liet de plek per functie open.
##   links, gestapeld: Uitrusting, Codex, Items
##   rechts: een groter vlak Warpen, met het label MENU erboven
##   v0.22: links onder Items de knop Magic (genezen buiten gevechten, meteen het Magie-scherm)
##   v0.22: rechts onder Warpen de knop Party (wie vecht mee, wie zit in de reserve)
##   v0.22: rechts daaronder Settings (het Opties-scherm) en Load (slotlijst + bevestiging)
## Openen: MENU-knop, of Esc / M / Tab (map.gd). B of MENU of een tik ernaast sluit.
## Status, Bestiarium en Opslaan hebben geen knop meer; choose()
## opent die schermen nog wel (tests en bestaand gedrag van die schermen).

signal closed

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")
const BestiaryScreen := preload("res://scripts/ui/bestiary_screen.gd")
const ItemsScreen := preload("res://scripts/ui/items_screen.gd")
const MagicScreen := preload("res://scripts/ui/magic_screen.gd")
const StatusScreen := preload("res://scripts/ui/status_screen.gd")
const OptionsScreen := preload("res://scripts/ui/options_screen.gd")
const EquipmentScreen := preload("res://scripts/ui/equipment_screen.gd")
const SaveScreen := preload("res://scripts/ui/save_screen.gd")
const CodexScreen := preload("res://scripts/ui/codex_screen.gd")
const PartyScreen := preload("res://scripts/ui/party_screen.gd")
const ScenesScreen := preload("res://scripts/ui/scenes_screen.gd")
const QuestlogScreen := preload("res://scripts/ui/questlog_screen.gd")   # v0.24 Quest Log (zelfde data als ECHO)
const QD := preload("res://scripts/data/quest_data.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const LoadScreen := preload("res://scripts/ui/load_screen.gd")   # v0.22 Load vanuit het veldmenu   # v0.22 partylimiet

const LAYER := 20
const MARGIN := 8
const GAP := 6
const LEFT_W := 156
const BUTTON_H := 30
const MENU_H := 15
## v0.22 compacte Warpen-/Party-knop (rechterkolom)
const WARP_W := 112   # 21 okt 2026: ruimte voor "Scenes & Music"
const WARP_H := 25   # tikmaat (UiTouch.TOUCH_MIN, ~48 dp); 6 knoppen rechts met RIGHT_GAP past boven de opdrachtregel
const RIGHT_GAP := 2   # tussenruimte in de rechterkolom (de grote linkerknoppen houden GAP)
## v0.22 rechterkolom (compact, onder het MENU-bord), van boven naar beneden
const RIGHT_COL := ["warp", "party", "quests", "scenes", "options", "load"]
## v0.22 linkerkolom (grote knoppen); 5 x 30 + tussenruimte eindigt op y=182, past op 216 hoog (telefoon)
const LEFT_COL := ["equip", "codex", "items", "magic", "bestiary"]
## Minimale tikhoogte (de knoppen zelf zijn hoger). Tests leunen op deze naam.
const ROW_H := 16
const MESSAGE_TIME := 2.5
## Spelertekst. TODO(design): deze zin tot er een hub-scène én een vlag is.
const WARP_UNAVAILABLE := "The warp hub cannot be reached yet."
const WARP_IN_RUN := "You cannot warp out of the Deep Cave."
const HUB_ENTER := "res://world_warper/flow/enter.gd"

## [id, tekst] in de volgorde van de indeling (links van boven naar beneden, dan Warpen).
const COMMANDS := [
	["equip", "Equipment"],
	["codex", "Codex"],
	["items", "Items"],
	["magic", "Magic"],
	["bestiary", "Bestiary"],
	["warp", "Warp"],
	["party", "Party"],
	["quests", QD.MENU_KNOP],
	["scenes", "Scenes & Music"],
	["options", "Settings"],
	["load", "Load"],
]

## De speler op de map (voor Opslaan: tile + kijkrichting). map.gd zet dit.
var player: Node2D = null
var root: Control
var menu_board: PanelContainer
var menu_label: Label
var buttons := {}
var party_cards: Array = []
var message_label: Label
## Lopende opdracht (story_data.gd QUESTS), alleen als er een is.
var quest_label: Label = null
var bestiary: CanvasLayer = null
## Open sub-scherm of null.
var sub: CanvasLayer = null
## Laatste uitkomst van Opslaan (voor de autotest): "", "saved", "declined" of "failed".
var last_save_result := ""
var _message_left := 0.0
var _last_focus: Button = null
## Laatste knop in de linkerkolom, zodat links vanaf Warpen daar terugkomt.
var _column_focus: Button = null
## Frame waarin dit scherm (of een sub-scherm) open/dicht ging: in dat frame geen knoppen
## verwerken (anders sluit dezelfde druk op MENU/B hem meteen weer).
var _quiet_frame := -1


func _ready() -> void:
	_quiet_frame = Engine.get_process_frames()
	layer = LAYER
	UiSfx.play(UiSfx.OPEN)
	root = Control.new()
	root.theme = load(UiMenu.THEME_PATH)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = MenuColors.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and sub == null:
			UiSfx.play(UiSfx.CLOSE)
			close())
	root.add_child(dim)
	_build_buttons()
	_build_message()
	_layout()
	_layout.call_deferred()
	root.resized.connect(_layout)
	buttons["equip"].grab_focus()


func _build_buttons() -> void:
	menu_board = PanelContainer.new()
	menu_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_board.add_theme_stylebox_override("panel", _board_style())
	root.add_child(menu_board)
	menu_label = UiMenu.label("MENU", MenuColors.TITLE)
	menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_board.add_child(menu_label)
	var ring: Array = []
	for c in COMMANDS:
		var id := str(c[0])
		var b := UiMenu.button(str(c[1]))
		b.custom_minimum_size = Vector2(LEFT_W, ROW_H)
		_style_button(b, id == "warp")
		if id in RIGHT_COL:
			b.custom_minimum_size = Vector2(WARP_W, ROW_H)   # v0.22 compact
		# v0.22 (Dennis): alle teksten gecentreerd (horizontaal; Button centreert verticaal zelf), zodat ze gelijk staan
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiMenu.set_label(b, str(c[1]))
		b.pressed.connect(choose.bind(id))
		b.focus_entered.connect(_remember_focus.bind(b))
		root.add_child(b)
		buttons[id] = b
		ring.append(b)
	TargetList.link_ring(ring)
	var q: String = Story.active_quest()
	if q != "":
		quest_label = UiMenu.label(q, MenuColors.INFO)
		quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(quest_label)
	_link_focus()


func _build_message() -> void:
	message_label = UiMenu.label("", MenuColors.INFO)
	message_label.visible = false
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(message_label)


func _board_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = UiStyle.panel("tab", UiStyle.HILITE)
	sb.border_color = UiStyle.BORDER
	return sb


func _style_button(b: Button, gold: bool) -> void:
	var normal: StyleBoxFlat = UiStyle.panel("button", UiStyle.BORDER if gold else UiStyle.BORDER_DIM)
	var focus: StyleBoxFlat = UiStyle.panel("button", UiStyle.BORDER)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", focus)
	b.add_theme_stylebox_override("focus", focus)


func _link_focus() -> void:
	# v0.22: linkerkolom LEFT_COL (ring), rechterkolom RIGHT_COL
	var col: Array = LEFT_COL.map(func(id): return buttons[id])
	var wp: Button = buttons["warp"]
	var pt: Button = buttons["party"]
	for i in col.size():
		var b: Button = col[i]
		var nxt: Button = col[(i + 1) % col.size()]
		var prv: Button = col[(i - 1 + col.size()) % col.size()]
		b.focus_next = b.get_path_to(nxt)
		b.focus_previous = b.get_path_to(prv)
		b.focus_neighbor_bottom = b.focus_next
		b.focus_neighbor_top = b.focus_previous
		b.focus_neighbor_right = b.get_path_to(wp)
	var eq: Button = col[0]
	# rechterkolom: Warp > Party > Quest Log > Scenes > Settings > Load, daarna weer de linkerkolom
	var rc: Array = RIGHT_COL.map(func(id): return buttons[id])
	for i in rc.size():
		var b: Button = rc[i]
		var nxt: Button = rc[i + 1] if i + 1 < rc.size() else eq
		var prv: Button = rc[i - 1] if i > 0 else col[col.size() - 1]
		b.focus_next = b.get_path_to(nxt)
		b.focus_previous = b.get_path_to(prv)
		b.focus_neighbor_bottom = b.focus_next
		b.focus_neighbor_top = b.focus_previous
		b.focus_neighbor_left = b.get_path_to(eq)


## TODO(design): zelfde voorlopige indeling als hierboven. Rechts groeit mee op bredere telefoons.
func _layout() -> void:
	var w := root.size.x if root.size.x > 0.0 else 384.0
	var h := root.size.y if root.size.y > 0.0 else 216.0
	var ins := UiTouchC.insets(root.get_viewport())
	var left_x := float(MARGIN) + ins.x
	var top := float(MARGIN) + ins.y
	var right_x := left_x + LEFT_W + GAP
	var right_w := maxf(80.0, w - right_x - MARGIN - ins.z)
	var y := top
	for id in LEFT_COL:
		var b: Button = buttons[id]
		b.position = Vector2(left_x, y)
		b.size = Vector2(LEFT_W, BUTTON_H)
		y += BUTTON_H + GAP
	var stack_bottom := y - GAP
	menu_board.position = Vector2(right_x, top)
	menu_board.size = Vector2(minf(right_w, float(WARP_W)), MENU_H)
	var warp_y := top + MENU_H + RIGHT_GAP
	# v0.22 (Dennis): Warpen compact (was een groot vlak): vaste maat WARP_W x WARP_H, nu op tikmaat
	# (25 eenheden = ~48 dp); Party eronder met dezelfde breedte.
	var col_w := minf(right_w, float(WARP_W))
	var ry := warp_y
	for id in RIGHT_COL:
		var rb: Button = buttons[id]
		rb.position = Vector2(right_x, ry)
		rb.size = Vector2(col_w, float(WARP_H))
		ry += WARP_H + RIGHT_GAP
	stack_bottom = maxf(stack_bottom, ry - RIGHT_GAP)
	message_label.position = Vector2(left_x, stack_bottom + GAP)
	message_label.size = Vector2(maxf(40.0, w - left_x - MARGIN - ins.z), 32)
	if quest_label != null:
		quest_label.position = Vector2(left_x, maxf(h - MARGIN - ins.w - 16.0, stack_bottom + 1.0))
		quest_label.size = Vector2(maxf(40.0, w - left_x - MARGIN - ins.z), 16)


func _place_name() -> String:
	var s := get_tree().current_scene if is_inside_tree() else null
	if s != null and "map_name" in s and str(s.map_name) != "":
		return str(s.map_name)
	return ""


func refresh_party() -> void:
	for c in party_cards:
		c.refresh()


func show_message(text: String, sticky := false) -> void:
	message_label.text = text
	message_label.visible = true
	_message_left = -1.0 if sticky else MESSAGE_TIME
	_layout.call_deferred()


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			message_label.visible = false
	if sub != null or Engine.get_process_frames() <= _quiet_frame:
		return
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
		UiSfx.play(UiSfx.CLOSE)
		close()
		return
	_horizontal_nav()
	UiMenu.pad_nav(root.get_viewport())


func _horizontal_nav() -> void:
	var f := root.get_viewport().gui_get_focus_owner()
	if f == null:
		return
	var right := Input.is_action_just_pressed("move_right") and not Input.is_action_just_pressed("ui_right")
	var left := Input.is_action_just_pressed("move_left") and not Input.is_action_just_pressed("ui_left")
	if right and not RIGHT_COL.any(func(id): return buttons[id] == f):
		buttons["warp"].grab_focus()
	elif left and RIGHT_COL.any(func(id): return buttons[id] == f):
		var back: Button = _column_focus if _column_focus != null else buttons["equip"]
		back.grab_focus()


## De vier knoppen, in indelingsvolgorde.
func commands() -> Array:
	return COMMANDS.duplicate()


## Een knop kiezen (tik, A of Enter).
func choose(id: String) -> void:
	if sub != null or is_queued_for_deletion():
		return
	if buttons.has(id):
		_last_focus = buttons[id]
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
		"warp":
			open_warp()
		"load":
			open_load()
		"scenes":
			open_scenes()
		"quests":
			open_quests()
		"party":
			open_party()
		"close":
			close()


func _open_sub(screen: CanvasLayer, node_name: String) -> CanvasLayer:
	sub = screen
	screen.name = node_name
	SessieLog.menu(node_name)
	GameState.menu_opened.emit(node_name)
	var back_to: Button = _last_focus if _last_focus != null else buttons["equip"]
	message_label.visible = false
	_message_left = 0.0
	var full_screen := screen.has_signal("closed")
	root.visible = not full_screen
	var on_closed := func() -> void:
		sub = null
		root.visible = true
		if node_name == "Bestiary":
			bestiary = null
		_quiet_frame = Engine.get_process_frames()
		refresh_party()
		if is_instance_valid(back_to):
			back_to.grab_focus()
	if full_screen:
		screen.closed.connect(on_closed)
	else:
		screen.answered.connect(func(_yes: bool) -> void: on_closed.call())
	add_child(screen)
	return screen


func open_status(index := 0) -> void:
	if sub != null:
		return
	var s := StatusScreen.new()
	s.index = clampi(index, 0, maxi(0, GameState.party.size() - 1))
	_open_sub(s, "Status")


func open_codex() -> void:
	if sub != null:
		return
	if buttons.has("codex"):
		_last_focus = buttons["codex"]
	_open_sub(CodexScreen.new(), "Codex")


## v0.22 Load: slotlijst (zoals het titelscherm) met een bevestiging; niet tijdens een gevecht.
func open_load() -> void:
	if sub != null:
		return
	if buttons.has("load"):
		_last_focus = buttons["load"]
	_open_sub(LoadScreen.new(), "Load")


## v0.22 partylimiet: actieve groep (4 helden + 1 monster) en reserve wisselen. Niet in een gevecht.
func open_party() -> void:
	if sub != null:
		return
	if GameState.in_battle:
		show_message(PartyScreen.PartyLimiet.IN_GEVECHT)
		return
	if buttons.has("party"):
		_last_focus = buttons["party"]
	_open_sub(PartyScreen.new(), "Party")


## v0.22 Scenes: bekeken cutscenes opnieuw afspelen (scripts/ui/scenes_screen.gd).
func open_scenes() -> void:
	if sub != null:
		return
	if buttons.has("scenes"):
		_last_focus = buttons["scenes"]
	_open_sub(ScenesScreen.new(), "Scenes")


## Quest Log: tabs Active en Done, per act gegroepeerd (data/quests.json, scripts/data/quest_data.gd).
func open_quests() -> CanvasLayer:
	if sub != null:
		return null
	if buttons.has("quests"):
		_last_focus = buttons["quests"]
	return _open_sub(QuestlogScreen.new(), "QuestLog")


func open_bestiary() -> void:
	if sub != null:
		return
	bestiary = _open_sub(BestiaryScreen.new(), "Bestiary")


func open_equipment(index := 0) -> void:
	if sub != null:
		return
	var s := EquipmentScreen.new()
	s.index = clampi(index, 0, maxi(0, GameState.party.size() - 1))
	if buttons.has("equip"):
		_last_focus = buttons["equip"]
	_open_sub(s, "Equipment")


## Hub-scène uit de World Warper, of "" als die taak het bestand nog niet leverde.
func hub_scene_path() -> String:
	if not ResourceLoader.exists(HUB_ENTER):
		return ""
	var script: Script = load(HUB_ENTER)
	if script == null:
		return ""
	return str(script.get_script_constant_map().get("HUB_SCENE", ""))


## True als de hub-scène én de unlock-vlag (het vlaggensysteem) bestaan.
func hub_present() -> bool:
	var path := hub_scene_path()
	if path == "" or not ResourceLoader.exists(path):
		return false
	return GameState.has_method("world_warper_is_unlocked")


## Naar de warp-hub. Zonder scène of vlag, of nog niet ontgrendeld: melding.
## De kaart blijft, en er gaan geen save-slots open of dicht.
func open_warp() -> void:
	if sub != null or is_queued_for_deletion():
		return
	if buttons.has("warp"):
		_last_focus = buttons["warp"]
	# r7-3 #5: niet midden in een Diepe Grot-run; anders breekt enter_map de run stil af.
	if GameState.dungeon100_run_active() or GameState.dungeon100_floor > 0:
		show_message(WARP_IN_RUN, true)
		return
	if not hub_present():
		# TODO(design): deze zin tot de hub-scène en de vlag er zijn.
		show_message(WARP_UNAVAILABLE, true)
		return
	if GameState.has_method("try_unlock_world_warper"):
		GameState.try_unlock_world_warper()
	if not GameState.world_warper_is_unlocked():
		# TODO(design): deze zin tot de hub-scène en de vlag er zijn.
		show_message(WARP_UNAVAILABLE, true)
		return
	var spawn := "ingang"
	var script: Script = load(HUB_ENTER)
	if script != null:
		var named: String = str(script.get_script_constant_map().get("HUB_SPAWN", "ingang"))
		if named != "":
			spawn = named
	# Geen save-slots openen of sluiten.
	close()
	GameState.change_map(hub_scene_path(), spawn)


func _remember_focus(b: Button) -> void:
	_last_focus = b
	if not RIGHT_COL.any(func(id): return buttons.get(id) == b):
		_column_focus = b


## Opslagscherm. Geen knop meer in dit menu; choose("save") en tests gebruiken dit nog.
func open_save() -> void:
	if sub != null:
		return
	var p := SaveScreen.new()
	p.place = _place_name()
	p.answered.connect(_on_save_answer)
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
		show_message("You can't save here.")
		return false
	if GameState.save_game(player.get_tile(), player.facing):
		last_save_result = "saved"
		UiSfx.play(UiSfx.SAVE)
		show_message("Saved.")
		return true
	last_save_result = "failed"
	UiSfx.play(UiSfx.ERROR)
	show_message("Save failed.")
	return false


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
