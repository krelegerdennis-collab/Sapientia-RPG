class_name EchoQuestlog
extends RefCounted
## ECHO's questlog (ECHO's Kamer > ECHO > "Quest Log"). Data only: één regel per act.
## Geen scène en geen GameState: alles werkt op een vlaggen-dictionary + verhaalstap, zodat
## de headless suite het kan naspelen.
##
## Act-indeling (niet verzonnen):
##   - Act N hoort bij Archief N (Lore_basis.md: Act 1 = het Eerste Archief; Verhaal_Act2_tot_6.md:
##     Act 2 t/m 6 = Archief 2 t/m 6). Thema per Archief uit CANON punt 14
##     (Kennis, Leven, Industrie, Magie, Kosmos, Hart).
##   - Alleen Act 1 en Act 2 staan in de game. Hun opdrachten zijn bestaande verhaalvlaggen.
##   - Act 3 t/m 6 hebben nog geen inhoud: status 'later' (upcoming), zonder opdrachten.
## ECHO zegt per act één zin. De Act 2-zin komt letterlijk uit canon-scène 1.
## Ids zijn Nederlands; alle tekst voor de speler is Engels.

const StoryData := preload("res://scripts/data/story_data.gd")
const Unlock := preload("res://world_warper/flow/unlock.gd")

## Status van een act (ids)
const KLAAR := "klaar"      # alle opdrachten gedaan
const OPEN := "open"        # speelbaar, nog niet klaar
const DICHT := "dicht"      # er is inhoud, maar de vorige act is nog niet klaar
const LATER := "later"      # nog geen inhoud in de game

const NAAM := "ECHO"
const OPTIE := "Quest Log"
const VRAAG := "Which act?"
const TERUG := "Go back"
const KOP_OPDRACHTEN := "Quests:"
const VINK_KLAAR := "[x] "
const VINK_OPEN := "[ ] "
const STATUS_TEKST := {KLAAR: "Done", OPEN: "Active", DICHT: "Locked", LATER: "Upcoming"}
const ZIN_DICHT := "That record is locked. Finish the act before it first."
const ZIN_LATER := "That record is still empty. A story for later."

## Opdracht klaar via:  "vlag" (sleutel in story_flags)  of  "stap" (GameState.story_step >= stap)
const AKTES := [
	{
		"id": "akte_1", "nummer": 1, "archief": "The First Archive", "thema": "Knowledge",
		"opdrachten": [
			{"id": "archieven_in", "titel": "The Archives of Sapientia", "stap": StoryData.NACHT},
			{"id": "golem", "titel": "Defeat the Golem", "vlag": StoryData.GOLEM_FLAG},
		],
		"echo_klaar": "The first Archive. The Golem has fallen and its core is yours.",
		"echo_open": "The first Archive. Its guardian still stands.",
	},
	{
		"id": "akte_2", "nummer": 2, "archief": "The Second Archive", "thema": "Life",
		"opdrachten": [
			{"id": "vesper", "titel": "Save Vesper from the Dark Wood", "vlag": "noor_gered"},
			{"id": "seren", "titel": "Seren joins the party", "vlag": "archief2_lotte_lid"},
			{"id": "genezer", "titel": "Defeat the guardian of the second Archive", "vlag": Unlock.BEWAKER_VLAG},
			{"id": "warper", "titel": "Reach the World Warper", "vlag": Unlock.UNLOCK_VLAG},
		],
		"echo_klaar": "Two Archives active. World Warper online.",
		"echo_open": "The second Archive. Its core is not free yet.",
	},
	{"id": "akte_3", "nummer": 3, "archief": "The Third Archive", "thema": "Industry", "opdrachten": []},
	{"id": "akte_4", "nummer": 4, "archief": "The Fourth Archive", "thema": "Magic", "opdrachten": []},
	{"id": "akte_5", "nummer": 5, "archief": "The Fifth Archive", "thema": "Cosmos", "opdrachten": []},
	{"id": "akte_6", "nummer": 6, "archief": "The Sixth Archive", "thema": "Heart", "opdrachten": []},
]


## Zijopdrachten (tab 'Side' in de Quest Log). Elke regel hoort bij een NPC. Zolang je die NPC niet
## gesproken hebt (vlag "gesproken"), toont de lijst alleen de Engelse naam van de NPC; daarna de
## titel van de opdracht met [ ] of [x]. Alleen bestaande opdrachten: Het Zingende Graan (Gerrit).
## Een oude save met de startvlag telt ook als gesproken.
const ZIJ := [
	{"id": "zingend_graan", "npc": StoryData.GERRIT, "titel": "The Singing Grain",
		"gesproken": "gesproken_gerrit", "start": StoryData.FLAG_GRAAN, "klaar": StoryData.FLAG_GRAAN_KLAAR},
]
const TAB_HOOFD := "Main"
const TAB_ZIJ := "Side"
const ZIJ_LEEG := "No side quests yet."


static func zij_gesproken(z: Dictionary, flags: Dictionary) -> bool:
	return flags.has(str(z["gesproken"])) or flags.has(str(z.get("start", "")))


static func zij_klaar(z: Dictionary, flags: Dictionary) -> bool:
	return z.has("klaar") and flags.has(str(z["klaar"]))


## Regel in de Side-tab: "Gerrit the Miller" (nog niet gesproken) of "[ ] The Singing Grain".
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
	return AKTES.map(func(a): return str(a["id"]))


static func akte(id: String) -> Dictionary:
	for a in AKTES:
		if str(a["id"]) == id:
			return a
	return {}


static func opdracht_klaar(o: Dictionary, flags: Dictionary, stap: int) -> bool:
	if o.has("vlag"):
		return flags.has(str(o["vlag"]))
	if o.has("stap"):
		return stap >= int(o["stap"])
	return false


static func status(id: String, flags: Dictionary, stap: int) -> String:
	var a := akte(id)
	if a.is_empty():
		return LATER
	var lijst: Array = a.get("opdrachten", [])
	if lijst.is_empty():
		return LATER
	if lijst.all(func(o): return opdracht_klaar(o, flags, stap)):
		return KLAAR
	var i := ids().find(id)
	if i > 0 and status(str(AKTES[i - 1]["id"]), flags, stap) != KLAAR:
		return DICHT
	return OPEN


## "Act 1: The First Archive (Knowledge)"
static func titel(id: String) -> String:
	var a := akte(id)
	return "Act %d: %s (%s)" % [int(a["nummer"]), str(a["archief"]), str(a["thema"])]


## Keuzeregel in de lijst: "Act 1 - Done"
static func keuze(id: String, flags: Dictionary, stap: int) -> String:
	return "Act %d - %s" % [int(akte(id)["nummer"]), STATUS_TEKST[status(id, flags, stap)]]


static func keuzes(flags: Dictionary, stap: int) -> Array[String]:
	var uit: Array[String] = []
	for id in ids():
		uit.append(keuze(str(id), flags, stap))
	uit.append(TERUG)
	return uit


## Wat ECHO over een act zegt: zijn zin, daarna de titel met de opdrachten (alleen als er inhoud is).
static func regels(id: String, flags: Dictionary, stap: int) -> Array[String]:
	var a := akte(id)
	var st := status(id, flags, stap)
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
	for o in a["opdrachten"]:
		blok += "\n" + (VINK_KLAAR if opdracht_klaar(o, flags, stap) else VINK_OPEN) + str(o["titel"])
	uit.append(blok)
	return uit


static func speler_teksten() -> Array[String]:
	var uit: Array[String] = [NAAM, OPTIE, VRAAG, TERUG, KOP_OPDRACHTEN, ZIN_DICHT, ZIN_LATER, TAB_HOOFD, TAB_ZIJ, ZIJ_LEEG]
	for z in ZIJ:
		uit.append(str(z["npc"]))
		uit.append(str(z["titel"]))
	for s in STATUS_TEKST.values():
		uit.append(str(s))
	for a in AKTES:
		uit.append(titel(str(a["id"])))
		for k in ["echo_klaar", "echo_open"]:
			if a.has(k):
				uit.append(str(a[k]))
		for o in a["opdrachten"]:
			uit.append(str(o["titel"]))
	return uit
