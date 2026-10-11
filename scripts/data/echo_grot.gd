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
const OPTIE_SIMULATIE := "Diepe Grot Simulatie"
const OPTIE_TWIJFEL := "Waarom doe je het?"
const OPTIE_DATA := "En de data?"
const KEUZE_START := "Start nieuwe run"
const KEUZE_TERUG := "Ga terug"
const VRAAG_MENU := "Wat wil je?"
const VRAAG_START := "Diepe Grot Simulatie"

const ZIN_EERSTE := "De Diepe Grot. Een simulatie — honderd verdiepingen, telkens anders. Ik beheer hem. Sapientia... Sapientia helpt met de data. Zo werkt het nu eenmaal."
const ZIN_TWIJFEL := "Waarom ik het doe? Omdat het mijn taak is. De Oude Mensheid bouwde me om te meten, te tellen, te bewaren."
const ZIN_H6 := "Ik heb honderden kandidaten doorgelaten. Jij bent de zesde die bleef staan. De anderen... ik weet niet wat er met ze is gebeurd."
const ZIN_DATA := "Dat weet ik niet. Ik lever, zij neemt. Zo is het altijd geweest."
const ZIN_RESULTAAT := "Resultaat: verdieping 100. Een nieuwe run kan starten."
const ZIN_WERELD := "De Diepe Grot start bij ECHO, in ECHO's Kamer."
const ZIN_LOOPT := "De simulatie loopt al."


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
