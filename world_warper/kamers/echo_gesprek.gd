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


## Eerst de vaste zinnen (eerste bezoek, resultaat, H-6), daarna één keer per act ECHO's zinnen van die act.
func _openingsregels() -> void:
	GameState.quest_sync()
	var regels := Data.regels_vooraf(GameState.story_flags)
	var akte := _akte()
	var vlag := Data.FLAG_AKTE + akte
	var akte_nieuw := akte != "" and not GameState.story_flags.has(vlag)
	if akte_nieuw:
		regels.append_array(Questlog.echo_dialoog(akte))
	if regels.is_empty():
		return
	Dialog.show_lines(regels, Data.NAAM)
	await Dialog.finished
	if is_inside_tree():
		Data.markeer(GameState.story_flags, regels)
		if akte_nieuw:
			GameState.story_flags[vlag] = true


func _akte() -> String:
	return Questlog.huidige_akte(GameState.story_flags, GameState.story_step, GameState.quest_progress)


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
		elif gekozen == Data.OPTIE_AKTE:
			await _zinnen(Questlog.echo_dialoog(_akte()))
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
		var opties := Questlog.keuzes(GameState.story_flags, GameState.story_step, GameState.quest_progress)
		var keuze := await Dialog.ask(Questlog.VRAAG, opties, Data.NAAM)
		if not is_inside_tree() or GameState.changing_map:
			return
		if keuze < 0 or keuze >= Questlog.AKTES.size():
			return
		Dialog.show_lines(Questlog.regels(str(Questlog.AKTES[keuze]["id"]), GameState.story_flags,
				GameState.story_step, GameState.quest_progress), Data.NAAM)
		await Dialog.finished


func _een_zin(zin: String) -> void:
	await _zinnen([zin])


func _zinnen(regels: Array[String]) -> void:
	if regels.is_empty():
		return
	Dialog.show_lines(regels, Data.NAAM)
	await Dialog.finished


func _gekozen(opties: Array[String], keuze: int) -> String:
	if keuze < 0 or keuze >= opties.size():
		return ""
	return opties[keuze]
