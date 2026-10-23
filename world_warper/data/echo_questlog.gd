class_name EchoQuestlog
extends RefCounted
## ECHO's questlog (ECHO's Kamer > ECHO > "Quest Log"). Geen eigen data meer: alles komt uit
## res://data/quests.json via scripts/data/quest_data.gd (zelfde bron als Veldmenu > Quest Log).
## Geen scène en geen GameState: alles werkt op een vlaggen-dictionary + verhaalstap (+ optioneel
## de opgeslagen voortgang), zodat de headless suite het kan naspelen.
##
## Act-indeling (niet verzonnen):
##   - Act N hoort bij Archief N (Lore_basis.md: Act 1 = het Eerste Archief; Verhaal_Act2_tot_6.md:
##     Act 2 t/m 6 = Archief 2 t/m 6). Thema per Archief uit CANON punt 14
##     (Kennis, Leven, Industrie, Magie, Kosmos, Hart).
##   - Alleen Act 1 en Act 2 staan in de game. Hun opdrachten zijn bestaande verhaalvlaggen.
##   - Act 3 t/m 6 hebben nog geen inhoud: status 'later' (upcoming), zonder opdrachten.
## ECHO zegt per act één zin. De Act 2-zin komt letterlijk uit canon-scène 1.
## Ids zijn Nederlands; alle tekst voor de speler is Engels.

const QD := preload("res://scripts/data/quest_data.gd")

## Status van een act (ids)
const KLAAR := QD.KLAAR
const OPEN := QD.OPEN
const DICHT := QD.DICHT
const LATER := QD.LATER

const NAAM := "ECHO"
const OPTIE := "Quest Log"
const VRAAG := "Which act?"
const TERUG := "Go back"
const KOP_OPDRACHTEN := "Quests:"
const VINK_KLAAR := QD.VINK_KLAAR
const VINK_OPEN := QD.VINK_OPEN
const STATUS_TEKST := {KLAAR: "Done", OPEN: "Active", DICHT: "Locked", LATER: "Upcoming"}
const ZIN_DICHT := "That record is locked. Finish the act before it first."
const ZIN_LATER := "That record is still empty. A story for later."

## Acts in de oude vorm (id, nummer, archief, thema, echo_klaar/echo_open, opdrachten = hoofdopdrachten).
static var AKTES: Array = _aktes()
## Zijopdrachten in de oude vorm (id, npc, titel, gesproken, start, klaar). Zolang je die NPC niet
## gesproken hebt (vlag "gesproken"), toont de lijst alleen de Engelse naam van de NPC.
## Een oude save met de startvlag telt ook als gesproken.
static var ZIJ: Array = _zij()


static func _aktes() -> Array:
	var uit: Array = []
	for a in QD.acts():
		var id := str(a["id"])
		var e := {"id": id, "nummer": int(a["number"]), "archief": str(a["archive"]), "thema": str(a["theme"]),
				"opdrachten": QD.in_act(id, QD.HOOFD).map(func(q): return {"id": str(q["id"]), "titel": str(q["title"])})}
		if a.has("echo_done"):
			e["echo_klaar"] = str(a["echo_done"])
		if a.has("echo_open"):
			e["echo_open"] = str(a["echo_open"])
		uit.append(e)
	return uit


static func _zij() -> Array:
	var uit: Array = []
	for q in QD.quests():
		if QD.is_zij(q):
			uit.append({"id": str(q["id"]), "npc": str(q.get("npc", "")), "titel": str(q["title"]),
					"gesproken": str(q.get("spoken_flag", "")), "start": str(q.get("start_flag", "")),
					"klaar": str(q.get("done_flag", ""))})
	return uit


static func zij_gesproken(z: Dictionary, flags: Dictionary) -> bool:
	return flags.has(str(z["gesproken"])) or flags.has(str(z.get("start", "")))


static func zij_klaar(z: Dictionary, flags: Dictionary) -> bool:
	return z.has("klaar") and flags.has(str(z["klaar"]))


## Regel in de Side-lijst: "Garrett the Miller" (nog niet gesproken) of "[ ] The Singing Grain".
static func zij_regel(z: Dictionary, flags: Dictionary) -> String:
	if not zij_gesproken(z, flags):
		return str(z["npc"])
	return (VINK_KLAAR if zij_klaar(z, flags) else VINK_OPEN) + str(z["titel"])


static func zij_regels(flags: Dictionary, lijst: Array = ZIJ) -> Array[String]:
	var uit: Array[String] = []
	for z in lijst:
		uit.append(zij_regel(z, flags))
	return uit


static func ids() -> Array:
	return QD.act_ids()


static func akte(id: String) -> Dictionary:
	for a in AKTES:
		if str(a["id"]) == id:
			return a
	return {}


static func status(id: String, flags: Dictionary, stap: int, voortgang := {}) -> String:
	return QD.akte_status(id, flags, stap, voortgang)


## De act waar de speler nu is (ECHO's gesprek per act).
static func huidige_akte(flags: Dictionary, stap: int, voortgang := {}) -> String:
	return QD.huidige_akte(flags, stap, voortgang)


static func echo_dialoog(id: String) -> Array[String]:
	return QD.echo_dialoog(id)


## "Act 1: The First Archive (Knowledge)"
static func titel(id: String) -> String:
	var a := akte(id)
	return "Act %d: %s (%s)" % [int(a["nummer"]), str(a["archief"]), str(a["thema"])]


## Keuzeregel in de lijst: "Act 1 - Done"
static func keuze(id: String, flags: Dictionary, stap: int, voortgang := {}) -> String:
	return "Act %d - %s" % [int(akte(id)["nummer"]), STATUS_TEKST[status(id, flags, stap, voortgang)]]


static func keuzes(flags: Dictionary, stap: int, voortgang := {}) -> Array[String]:
	var uit: Array[String] = []
	for id in ids():
		uit.append(keuze(str(id), flags, stap, voortgang))
	uit.append(TERUG)
	return uit


## Wat ECHO over een act zegt: zijn zin, daarna de titel met de opdrachten (alleen als er inhoud is).
static func regels(id: String, flags: Dictionary, stap: int, voortgang := {}) -> Array[String]:
	var a := akte(id)
	var st := status(id, flags, stap, voortgang)
	var uit: Array[String] = []
	match st:
		KLAAR:
			uit.append(str(a["echo_klaar"]))
		OPEN:
			uit.append(str(a["echo_open"]))
		DICHT:
			uit.append(ZIN_DICHT)
			return uit
		_:
			uit.append(ZIN_LATER)
			return uit
	var blok := "%s\n%s" % [titel(id), KOP_OPDRACHTEN]
	for q in QD.in_act(id, QD.HOOFD):
		blok += "\n" + (VINK_KLAAR if QD.quest_klaar(q, flags, stap, voortgang) else VINK_OPEN) + str(q["title"])
	uit.append(blok)
	return uit


static func speler_teksten() -> Array[String]:
	var uit: Array[String] = [NAAM, OPTIE, VRAAG, TERUG, KOP_OPDRACHTEN, ZIN_DICHT, ZIN_LATER]
	for z in ZIJ:
		uit.append(str(z["npc"]))
		uit.append(str(z["titel"]))
	for s in STATUS_TEKST.values():
		uit.append(str(s))
	for a in AKTES:
		uit.append(titel(str(a["id"])))
	uit.append_array(QD.speler_teksten())
	return uit
