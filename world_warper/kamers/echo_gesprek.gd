class_name EchoGesprek
extends Node
## Gesprek met ECHO in ECHO's Kamer. De grot start alleen via het signaal hier.

signal gestart
signal klaar

const Data := preload("res://scripts/data/echo_grot.gd")
const Questlog := preload("res://world_warper/data/echo_questlog.gd")

var bezig := false


func praat() -> void:
	if bezig or Dialog.is_open or GameState.changing_map or GameState.in_battle:
		klaar.emit()
		return
	bezig = true
	await _openingsregels()
	if is_inside_tree() and not GameState.changing_map:
		await _menu()
	bezig = false
	if is_inside_tree():
		klaar.emit()


func _openingsregels() -> void:
	var regels := Data.regels_vooraf(GameState.story_flags)
	if regels.is_empty():
		return
	Dialog.show_lines(regels, Data.NAAM)
	await Dialog.finished
	if is_inside_tree():
		Data.markeer(GameState.story_flags, regels)


func _menu() -> void:
	while is_inside_tree() and not GameState.changing_map and not GameState.in_battle:
		var opties := Data.menu_opties()
		var keuze := await Dialog.ask(Data.VRAAG_MENU, opties, Data.NAAM)
		if not is_inside_tree() or GameState.changing_map:
			return
		var gekozen := _gekozen(opties, keuze)
		if gekozen == Data.OPTIE_SIMULATIE:
			if not await _startkeuze():
				return
		elif gekozen == Data.OPTIE_QUESTLOG:
			await _questlog()
		elif gekozen == Data.OPTIE_TWIJFEL:
			await _een_zin(Data.ZIN_TWIJFEL)
		elif gekozen == Data.OPTIE_DATA:
			await _een_zin(Data.ZIN_DATA)
		else:
			return


## true = terug naar het menu. false = het gesprek is klaar (gestart of weg).
func _startkeuze() -> bool:
	var opties := Data.start_opties()
	var keuze := await Dialog.ask(Data.VRAAG_START, opties, Data.NAAM)
	if not is_inside_tree() or GameState.changing_map:
		return false
	if _gekozen(opties, keuze) != Data.KEUZE_START:
		return true
	if GameState.dungeon100_echo_start():
		gestart.emit()
		return false
	await _een_zin(Data.ZIN_LOOPT)
	return true


## v0.24 Questlog: lijst met acts (status), per act ECHO's zin + de opdrachten. 'Go back' = terug naar het menu.
func _questlog() -> void:
	while is_inside_tree() and not GameState.changing_map and not GameState.in_battle:
		var opties := Questlog.keuzes(GameState.story_flags, GameState.story_step)
		var keuze := await Dialog.ask(Questlog.VRAAG, opties, Data.NAAM)
		if not is_inside_tree() or GameState.changing_map:
			return
		if keuze < 0 or keuze >= Questlog.AKTES.size():
			return
		Dialog.show_lines(Questlog.regels(str(Questlog.AKTES[keuze]["id"]), GameState.story_flags,
				GameState.story_step), Data.NAAM)
		await Dialog.finished


func _een_zin(zin: String) -> void:
	Dialog.show_lines([zin], Data.NAAM)
	await Dialog.finished


func _gekozen(opties: Array[String], keuze: int) -> String:
	if keuze < 0 or keuze >= opties.size():
		return ""
	return opties[keuze]
