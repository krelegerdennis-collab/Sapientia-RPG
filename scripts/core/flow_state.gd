class_name FlowState
extends RefCounted
## Veldflow (docs/STATE_MACHINES.md §1): de ene toestand die vroeger impliciet uit vier losse vlaggen
## werd afgeleid (GameState.in_battle, GameState.changing_map, Story.running, Dialog.is_open) en in
## ~20 guards met de hand werd herhaald. Pure klasse: geen nodes, geen RNG.
##
## Prioriteit bij meerdere vlaggen tegelijk (van hard naar zacht):
##   BATTLE > MAP_CHANGE > CUTSCENE > DIALOG > FIELD
## Een gevecht wint van alles (de kaart is weg); een mapwissel wint van een cutscene (de scène
## verdwijnt onder het verhaal); een cutscene wint van tekst (Story opent zelf tekstvakken).
##
## De vlaggen zelf blijven bestaan en blijven leidend; dit is een afgeleide weergave. Toestanden zijn
## strings (zoals battle.gd/state en som_ally.gd/state), zodat tests en de sessielog ze direct kunnen
## printen. Spelers zien deze tekst nooit.

const FIELD := "field"              ## vrij lopen op de kaart
const DIALOG := "dialog"            ## tekstvak open (Dialog.is_open)
const CUTSCENE := "cutscene"        ## verhaal-event loopt (Story.running)
const MAP_CHANGE := "map_change"    ## fade + scènewissel (GameState.changing_map)
const BATTLE := "battle"            ## gevechtsscène (GameState.in_battle)

const STATES: Array[String] = [FIELD, DIALOG, CUTSCENE, MAP_CHANGE, BATTLE]

## Toestanden waarin de kaart "bezet" is: geen nieuwe mapwissel, gevecht of cutscene starten.
const SCENE_BUSY: Array[String] = [MAP_CHANGE, BATTLE]


## De flow-toestand uit de vier vlaggen.
static func of(in_battle: bool, changing_map: bool, story_running: bool, dialog_open: bool) -> String:
	if in_battle:
		return BATTLE
	if changing_map:
		return MAP_CHANGE
	if story_running:
		return CUTSCENE
	if dialog_open:
		return DIALOG
	return FIELD


## true = de scène wisselt of er loopt een gevecht (de oude guard `changing_map or in_battle`).
static func scene_busy(state: String) -> bool:
	return state in SCENE_BUSY


## true = de speler mag vrij handelen op de kaart (geen gevecht, wissel, cutscene of tekst).
static func field_free(state: String) -> bool:
	return state == FIELD


static func is_known(state: String) -> bool:
	return state in STATES
