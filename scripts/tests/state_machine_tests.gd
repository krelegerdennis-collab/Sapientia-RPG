extends Node
## ALLEEN VOOR TESTEN - toestandsmachines (docs/STATE_MACHINES.md).
## Start:  godot --path . -- --statemachinetest
##   A: FlowState (pure klasse): prioriteit, scene_busy/field_free, bekende toestanden
##   B: GameState.flow_state()/scene_busy()/field_free() + het signaal flow_changed (setters op de vlaggen)
##   C: battle.gd: STATES, CHOOSING_STATES, choosing(), _set_state(), prev_state, state_changed
##   D: constanten-sets (uniek, compleet) van som_ally, kern_absorption, shop/equipment/save_slot_list/codex,
##      player (MOVE_*), dialog_box (PHASE_*)
##   E: broncontrole: geen letterlijke toestand-strings meer in die bestanden; elke ST_/MODE_/PHASE_-naam
##      die ze gebruiken bestaat en zit in de set (de AX-vangrail: een nieuwe toestand zonder constante faalt hier)
##   F: Dialog.phase() op de echte autoload: closed -> typing -> waiting -> closed
##   G: Player.movement_state() (instantie zonder boom; alleen de vlaggen)
## Geen kaart, geen gevecht: alle onderdelen zijn puur of op een losse instantie. Zit niet in de export.

const BattleScript := preload("res://scripts/battle/battle.gd")
const SomAlly := preload("res://scripts/som/som_ally.gd")
const KernAbsorption := preload("res://scripts/kern/kern_absorption.gd")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const EquipmentScreen := preload("res://scripts/ui/equipment_screen.gd")
const SaveSlotList := preload("res://scripts/ui/save_slot_list.gd")
const CodexScreen := preload("res://scripts/ui/codex_screen.gd")
const PlayerScript := preload("res://scripts/player.gd")
const DialogScript := preload("res://scripts/dialog_box.gd")

var failures := 0
var passes := 0
var _flow_log: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.encounter_multiplier = 0.0
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_flow_state_tests()
	_game_state_flow_tests()
	_battle_state_tests()
	_constant_set_tests()
	_source_tests()
	await _dialog_phase_tests()
	_player_movement_tests()
	print("STATEMACHINETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


# ================================================================ A: FlowState (puur)
func _flow_state_tests() -> void:
	check("FlowState: 5 bekende toestanden", FlowState.STATES.size() == 5)
	check("FlowState: alles uit = FIELD", FlowState.of(false, false, false, false) == FlowState.FIELD)
	check("FlowState: alleen tekst = DIALOG", FlowState.of(false, false, false, true) == FlowState.DIALOG)
	check("FlowState: alleen cutscene = CUTSCENE", FlowState.of(false, false, true, false) == FlowState.CUTSCENE)
	check("FlowState: alleen wissel = MAP_CHANGE", FlowState.of(false, true, false, false) == FlowState.MAP_CHANGE)
	check("FlowState: alleen gevecht = BATTLE", FlowState.of(true, false, false, false) == FlowState.BATTLE)
	# prioriteit: BATTLE > MAP_CHANGE > CUTSCENE > DIALOG
	check("prioriteit: gevecht wint van alles", FlowState.of(true, true, true, true) == FlowState.BATTLE)
	check("prioriteit: wissel wint van cutscene + tekst", FlowState.of(false, true, true, true) == FlowState.MAP_CHANGE)
	check("prioriteit: cutscene wint van tekst", FlowState.of(false, false, true, true) == FlowState.CUTSCENE)
	# alle 16 combinaties geven een bekende toestand en zijn consistent met scene_busy/field_free
	var alle_bekend := true
	var busy_klopt := true
	var free_klopt := true
	for m in 16:
		var b := bool(m & 1)
		var c := bool(m & 2)
		var s := bool(m & 4)
		var d := bool(m & 8)
		var st := FlowState.of(b, c, s, d)
		alle_bekend = alle_bekend and FlowState.is_known(st)
		busy_klopt = busy_klopt and FlowState.scene_busy(st) == (b or c)
		free_klopt = free_klopt and FlowState.field_free(st) == (not b and not c and not s and not d)
	check("alle 16 vlag-combinaties: bekende toestand", alle_bekend)
	check("alle 16: scene_busy == (in_battle or changing_map)", busy_klopt)
	check("alle 16: field_free == geen enkele vlag", free_klopt)
	check("is_known: onbekende string = false", not FlowState.is_known("menu"))


# ================================================================ B: GameState
func _on_flow(from_state: String, to_state: String) -> void:
	_flow_log.append([from_state, to_state])


func _game_state_flow_tests() -> void:
	# uitgangssituatie: titelscherm, geen gevecht, geen wissel
	GameState.in_battle = false
	GameState.changing_map = false
	var story_loopt: bool = Story.running
	var tekst_open: bool = Dialog.is_open
	check("GameState: start zonder vlaggen (story %s, dialog %s)" % [story_loopt, tekst_open],
			not GameState.scene_busy() and GameState.flow_state() == FlowState.of(false, false, story_loopt, tekst_open))
	check("GameState: field_free == (flow_state == FIELD)", GameState.field_free() == (GameState.flow_state() == FlowState.FIELD))
	check("GameState: can_autosave gebruikt scene_busy (geen gevecht/wissel -> niet geblokkeerd daardoor)",
			GameState.can_autosave(true) == (not Dialog.is_open and not Story.running and not GameState.coop_is_guest()))
	GameState.flow_changed.connect(_on_flow)
	_flow_log.clear()
	GameState.in_battle = true
	check("in_battle=true: flow_state BATTLE", GameState.flow_state() == FlowState.BATTLE and GameState.scene_busy())
	check("in_battle=true: flow_changed(.., battle) 1x", _flow_log.size() == 1 and _flow_log[0][1] == FlowState.BATTLE)
	GameState.in_battle = true
	check("in_battle nog eens true: geen extra signaal", _flow_log.size() == 1)
	GameState.changing_map = true
	check("changing_map erbij tijdens gevecht: toestand blijft BATTLE, geen signaal", GameState.flow_state() == FlowState.BATTLE and _flow_log.size() == 1)
	GameState.in_battle = false
	check("in_battle=false met wissel: BATTLE -> MAP_CHANGE", GameState.flow_state() == FlowState.MAP_CHANGE
			and _flow_log.size() == 2 and _flow_log[1][0] == FlowState.BATTLE and _flow_log[1][1] == FlowState.MAP_CHANGE)
	GameState.changing_map = false
	check("changing_map=false: terug naar start, signaal 3x", _flow_log.size() == 3 and _flow_log[2][0] == FlowState.MAP_CHANGE
			and not GameState.scene_busy())
	check("vlaggen lezen zoals vroeger (in_battle/changing_map zijn gewone bools)",
			GameState.in_battle == false and GameState.changing_map == false)
	GameState.flow_changed.disconnect(_on_flow)
	# guards die scene_busy gebruiken, weigeren nog steeds tijdens een wissel
	GameState.changing_map = true
	var voor := GameState.current_map
	GameState.change_map("res://scenes/maps/wilgendal.tscn", "start")
	check("change_map tijdens changing_map doet niets (guard via scene_busy)", GameState.current_map == voor and GameState.changing_map)
	GameState.changing_map = false
	GameState.in_battle = true
	check("on_player_step tijdens gevecht geeft false", GameState.on_player_step("grass") == false)
	GameState.in_battle = false


# ================================================================ C: battle.gd
func _battle_state_tests() -> void:
	var b: Control = BattleScript.new()
	check("battle: 6 toestanden, uniek", BattleScript.STATES.size() == 6 and _uniek(BattleScript.STATES))
	check("battle: CHOOSING_STATES is deelverzameling", _subset(BattleScript.CHOOSING_STATES, BattleScript.STATES)
			and BattleScript.CHOOSING_STATES.size() == 3)
	check("battle: begint in intro (zelfde string als vroeger)", b.state == BattleScript.ST_INTRO and b.state == "intro")
	check("battle: oude strings ongewijzigd", BattleScript.ST_COMMAND == "command" and BattleScript.ST_TARGET_ENEMY == "target_enemy"
			and BattleScript.ST_TARGET_ALLY == "target_ally" and BattleScript.ST_BUSY == "busy" and BattleScript.ST_MESSAGE_WAIT == "message_wait")
	var gezien: Array = []
	b.state_changed.connect(func(s: String) -> void: gezien.append(s))
	b._set_state(BattleScript.ST_COMMAND)
	check("battle: _set_state zet state + prev_state", b.state == "command" and b.prev_state == "intro")
	check("battle: state_changed komt met de nieuwe toestand", gezien == ["command"])
	var kiest := {}
	for st in BattleScript.STATES:
		b._set_state(st)
		kiest[st] = b.choosing()
	check("battle: choosing() alleen in command/target_enemy/target_ally",
			kiest["command"] and kiest["target_enemy"] and kiest["target_ally"]
			and not kiest["intro"] and not kiest["busy"] and not kiest["message_wait"])
	check("battle: prev_state volgt (laatste = busy -> message_wait)", b.prev_state == "busy" and b.state == "message_wait")
	b.free()


# ================================================================ D: constanten-sets
func _constant_set_tests() -> void:
	check("som_ally: STATES = follow/engage/flee/ko", _gelijk(SomAlly.STATES, ["follow", "engage", "flee", "ko"]))
	check("kern_absorption: PHASES = ''/effect/bericht/klaar", _gelijk(KernAbsorption.PHASES, ["", "effect", "bericht", "klaar"]))
	check("shop_screen: MODES = koop/verkoop/held", _gelijk(ShopScreen.MODES, ["koop", "verkoop", "held"]))
	check("equipment_screen: MODES = command/slot/item/confirm", _gelijk(EquipmentScreen.MODES, ["command", "slot", "item", "confirm"]))
	check("save_slot_list: MODES = load/new", _gelijk(SaveSlotList.MODES, ["load", "new"]))
	check("codex_screen: MODES = ''/kies_a/kies_b/voorbeeld", _gelijk(CodexScreen.MODES, ["", "kies_a", "kies_b", "voorbeeld"])
			and CodexScreen.MODE_BROWSE == "")
	check("player: MOVE_STATES 5 uniek", PlayerScript.MOVE_STATES.size() == 5 and _uniek(PlayerScript.MOVE_STATES))
	check("dialog_box: PHASES 4 uniek", DialogScript.PHASES.size() == 4 and _uniek(DialogScript.PHASES))
	check("FlowState: STATES uniek", _uniek(FlowState.STATES))


# ================================================================ E: broncontrole
## Per bestand: de variabele, het voorvoegsel van zijn constanten en het script (voor de constantenmap).
const BRONNEN := [
	["res://scripts/battle/battle.gd", "state", "ST_", "STATES"],
	["res://scripts/som/som_ally.gd", "state", "ST_", "STATES"],
	["res://scripts/kern/kern_absorption.gd", "phase", "PHASE_", "PHASES"],
	["res://scripts/ui/shop_screen.gd", "mode", "MODE_", "MODES"],
	["res://scripts/ui/equipment_screen.gd", "mode", "MODE_", "MODES"],
	["res://scripts/ui/save_slot_list.gd", "mode", "MODE_", "MODES"],
	["res://scripts/ui/codex_screen.gd", "mode", "MODE_", "MODES"],
]


func _source_tests() -> void:
	for bron in BRONNEN:
		var pad: String = bron[0]
		var naam: String = bron[1]
		var prefix: String = bron[2]
		var setnaam: String = bron[3]
		var f := FileAccess.open(pad, FileAccess.READ)
		if f == null:
			check("bron leesbaar: " + pad, false)
			continue
		var tekst := f.get_as_text()
		var script: Script = load(pad)
		var consts: Dictionary = script.get_script_constant_map()
		var set: Array = consts.get(setnaam, [])
		# 1) letterlijke strings rechts van  state = / == / !=  (of _set_state("..."))
		var rx := RegEx.new()
		rx.compile("(?m)^[^#\\n]*?(?:\\b%s\\s*(?:=|==|!=)\\s*|_set_%s\\()(\"[^\"]*\"|[A-Za-z_][A-Za-z0-9_]*)" % [naam, naam])
		var letterlijk: Array = []
		var onbekend: Array = []
		for m in rx.search_all(tekst):
			var rhs := m.get_string(1)
			if rhs.begins_with("\""):
				letterlijk.append(rhs)
			elif rhs.begins_with(prefix):
				if not consts.has(rhs) or not (consts[rhs] in set):
					onbekend.append(rhs)
		check("%s: geen letterlijke %s-strings meer %s" % [pad.get_file(), naam, letterlijk], letterlijk.is_empty())
		check("%s: elke %s*-naam bestaat en zit in %s %s" % [pad.get_file(), prefix, setnaam, onbekend], onbekend.is_empty())
		# 2) elke constante met het voorvoegsel zit in de set (geen vergeten toestand)
		var vergeten: Array = []
		for k in consts:
			if str(k).begins_with(prefix) and consts[k] is String and not (consts[k] in set):
				vergeten.append(k)
		check("%s: alle %s*-constanten staan in %s %s" % [pad.get_file(), prefix, setnaam, vergeten], vergeten.is_empty())
	# game_state.gd: de oude dubbele guard komt niet meer voor (alleen nog in scene_busy() zelf + commentaar)
	var gs := FileAccess.open("res://scripts/game_state.gd", FileAccess.READ).get_as_text()
	var rx2 := RegEx.new()
	rx2.compile("(?m)^[^#\\n]*\\b(?:changing_map or in_battle|in_battle or changing_map)\\b")
	var hits := rx2.search_all(gs).size()
	check("game_state.gd: 'changing_map or in_battle' alleen nog in scene_busy() (%d)" % hits, hits == 1)


# ================================================================ F: Dialog.phase()
func _dialog_phase_tests() -> void:
	if Dialog.is_open:
		Dialog.close()
	check("Dialog: dicht = PHASE_CLOSED", Dialog.phase() == Dialog.PHASE_CLOSED)
	Dialog.show_lines(["State machine test."])
	check("Dialog: na show_lines = TYPING", Dialog.is_open and Dialog.phase() == Dialog.PHASE_TYPING)
	Dialog.advance()      # alles tonen
	check("Dialog: na A tijdens typen = WAITING", Dialog.is_open and Dialog.phase() == Dialog.PHASE_WAITING)
	check("Dialog: flow_state is DIALOG zolang de tekst open staat", GameState.flow_state() == FlowState.DIALOG and not GameState.field_free())
	Dialog.advance()      # laatste regel -> dicht
	check("Dialog: na A op de laatste regel = CLOSED", not Dialog.is_open and Dialog.phase() == Dialog.PHASE_CLOSED)
	await get_tree().process_frame


# ================================================================ G: Player.movement_state()
func _analog_dummy() -> Vector2:
	return Vector2.ZERO


func _player_movement_tests() -> void:
	var p: CharacterBody2D = PlayerScript.new()
	check("player: stil = idle", p.movement_state() == PlayerScript.MOVE_IDLE)
	p.is_moving = true
	check("player: is_moving = stepping", p.movement_state() == PlayerScript.MOVE_STEPPING)
	p.analog_input = Callable(self, "_analog_dummy")
	check("player: analog_input wint van stepping", p.movement_state() == PlayerScript.MOVE_ANALOG)
	p.input_locked = true
	check("player: input_locked wint van analog", p.movement_state() == PlayerScript.MOVE_LOCKED)
	p._scripted = true
	check("player: _scripted wint van alles", p.movement_state() == PlayerScript.MOVE_SCRIPTED)
	p._scripted = false
	p.input_locked = false
	p.analog_input = Callable()
	p.is_moving = false
	check("player: alles los = idle, waarde in MOVE_STATES", p.movement_state() == "idle" and p.movement_state() in PlayerScript.MOVE_STATES)
	p.free()


# ================================================================ hulp
func _uniek(a: Array) -> bool:
	var d := {}
	for x in a:
		d[x] = true
	return d.size() == a.size()


## Elementsgewijs gelijk (zonder typed-array cast; `a == [..] as Array[String]` bindt verkeerd).
func _gelijk(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _subset(a: Array, b: Array) -> bool:
	for x in a:
		if not (x in b):
			return false
	return true
