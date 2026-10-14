class_name EchoGrot
extends RefCounted
## De Diepe Grot is een simulatie. ECHO beheert hem en is de enige start.
## De onthulling dat ECHO een digitale echo van een onderzoeker is, hoort hier niet.

const DUNGEON := "res://scenes/maps/dungeon100.tscn"
const DUNGEON_SPAWN := "omhoog"
const KAMER := "res://world_warper/kamers/echo_kamer.tscn"
const KAMER_SPAWN := "ingang"
const WERELD := "res://scenes/maps/wereldkaart.tscn"

const FLAG_EERSTE := "echo_grot_gezien"
const FLAG_RESULTAAT := "echo_grot_resultaat"
const FLAG_H6_GEZEGD := "echo_grot_h6_gezegd"
## De Spiegel zet deze vlag nog niet. Zolang ze uit staat, zegt ECHO de zin niet.
const FLAG_H6 := "h6_onthuld"

const NAAM := "ECHO"
const OPTIE_SIMULATIE := "Deep Learning Simulation"
const OPTIE_TWIJFEL := "Why do you do it?"
const OPTIE_DATA := "And the data?"
const KEUZE_START := "Start new run"
const KEUZE_TERUG := "Go back"
const VRAAG_MENU := "What do you want?"
const VRAAG_START := "Deep Learning Simulation"

const ZIN_EERSTE := "The Deep Learning Simulation. An AI training program — a hundred floors, different every time. I run it. Sapientia... Sapientia helps with the data. That's just how it works."
const ZIN_TWIJFEL := "Why I do it? Because it is my task. The Old Humanity built me to measure, to count, to preserve."
const ZIN_H6 := "I have let hundreds of candidates through. You are the sixth who stayed standing. The others... I don't know what happened to them."
const ZIN_DATA := "I don't know. I deliver, she takes. It has always been that way."
const ZIN_RESULTAAT := "Result: floor 100. A new run can start."
const ZIN_WERELD := "The Deep Learning Simulation starts with ECHO, in ECHO's Room."
const ZIN_LOOPT := "The simulation is already running."


static func blokkeert_wereldkaart(huidige: String, doel: String) -> bool:
	return huidige == WERELD and doel == DUNGEON


static func na_h6(flags: Dictionary) -> bool:
	return _aan(flags, FLAG_H6)


static func regels_vooraf(flags: Dictionary) -> Array[String]:
	var uit: Array[String] = []
	if not _aan(flags, FLAG_EERSTE):
		uit.append(ZIN_EERSTE)
	if _aan(flags, FLAG_RESULTAAT):
		uit.append(ZIN_RESULTAAT)
	if na_h6(flags) and not _aan(flags, FLAG_H6_GEZEGD):
		uit.append(ZIN_H6)
	return uit


static func markeer(flags: Dictionary, regels: Array) -> void:
	if regels.has(ZIN_EERSTE):
		flags[FLAG_EERSTE] = true
	if regels.has(ZIN_RESULTAAT):
		flags.erase(FLAG_RESULTAAT)
	if regels.has(ZIN_H6):
		flags[FLAG_H6_GEZEGD] = true


static func menu_opties() -> Array[String]:
	return [OPTIE_SIMULATIE, OPTIE_TWIJFEL, OPTIE_DATA, KEUZE_TERUG]


static func start_opties() -> Array[String]:
	return [KEUZE_START, KEUZE_TERUG]


static func speler_teksten() -> Array[String]:
	return [ZIN_EERSTE, ZIN_TWIJFEL, ZIN_H6, ZIN_DATA, ZIN_RESULTAAT, ZIN_WERELD, ZIN_LOOPT,
			OPTIE_SIMULATIE, OPTIE_TWIJFEL, OPTIE_DATA, KEUZE_START, KEUZE_TERUG, VRAAG_MENU, NAAM]


static func _aan(flags: Dictionary, sleutel: String) -> bool:
	var waarde: Variant = flags.get(sleutel, false)
	return waarde is bool and (waarde as bool)
