extends RefCounted
## Quest Log (v0.25): opdrachten en ECHO's zinnen per act uit res://data/quests.json.
## Puur data + regels: alles werkt op (story_flags, story_step, voortgang), zonder GameState,
## zodat de headless suite het kan naspelen. GameState houdt de voortgang bij (save: "quests").
##
## Voortgang = {quest_id: {"steps": [stap-ids], "done": bool}}. Eenmaal klaar blijft klaar.
## Een stap is klaar als hij in de voortgang staat, of zijn 'flag' gezet is, of story_step >= 'step'.
## Een stap met 'event' wordt klaar zodra Story dat event afrondt (on_event).
## Een opdracht is klaar via 'done_flag' of 'done_step'; zonder die velden als alle stappen klaar zijn.

const JSON_PATH := "res://data/quests.json"
const HOOFD := "main"
const ZIJ := "side"

## Status van een act (ids; zelfde als world_warper/data/echo_questlog.gd)
const KLAAR := "klaar"      # alle hoofdopdrachten gedaan
const OPEN := "open"        # speelbaar, nog niet klaar
const DICHT := "dicht"      # er is inhoud, maar de vorige act is nog niet klaar
const LATER := "later"      # nog geen inhoud in de game

## Speler-tekst: schermtitel ECHO; pausemenu/tutorial blijven "Quest Log" (menutest).
const TITEL := "ECHO"
const MENU_KNOP := "Quest Log"
const TAB_ACTIEF := "Active"
const TAB_KLAAR := "Done"
const LEEG_ACTIEF := "No active quests."
const LEEG_KLAAR := "No completed quests yet."
const ZIJ_LABEL := "Side quest"
const NIET_GESTART := "Not started yet."
const OBJECTIVE_LABEL := "Current objective:"
const VINK_KLAAR := "[x] "
const VINK_OPEN := "[ ] "

static var DATA: Dictionary = _laad()


static func _laad() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	if d is Dictionary and d.get("acts") is Array and d.get("quests") is Array:
		return d
	push_error("quests.json ontbreekt of is ongeldig")
	return {"acts": [], "quests": []}


# ---------------------------------------------------------------- data
static func acts() -> Array:
	return DATA["acts"]


static func act_ids() -> Array:
	return acts().map(func(a): return str(a["id"]))


static func act(id: String) -> Dictionary:
	for a in acts():
		if str(a["id"]) == id:
			return a
	return {}


## "Act 1: The First Archive"
static func act_kop(id: String) -> String:
	var a := act(id)
	return "Act %d: %s" % [int(a.get("number", 0)), str(a.get("archive", ""))]


static func quests() -> Array:
	return DATA["quests"]


static func quest(id: String) -> Dictionary:
	for q in quests():
		if str(q["id"]) == id:
			return q
	return {}


## Opdrachten van een act in de volgorde van het bestand; soort "" = alle, anders HOOFD of ZIJ.
static func in_act(act_id: String, soort := "") -> Array:
	return quests().filter(func(q): return str(q["act"]) == act_id and (soort == "" or str(q.get("type", HOOFD)) == soort))


static func is_zij(q: Dictionary) -> bool:
	return str(q.get("type", HOOFD)) == ZIJ


# ---------------------------------------------------------------- regels
static func _rec(voortgang: Dictionary, qid: String) -> Dictionary:
	var r = voortgang.get(qid, {})
	return r if r is Dictionary else {}


## Klaar zonder de opdracht zelf mee te tellen (voortgang, vlag of verhaalstap).
static func _stap_eigen(q: Dictionary, s: Dictionary, flags: Dictionary, stap: int, voortgang: Dictionary) -> bool:
	var gedaan = _rec(voortgang, str(q["id"])).get("steps", [])
	if gedaan is Array and gedaan.has(str(s["id"])):
		return true
	if s.has("flag") and flags.has(str(s["flag"])):
		return true
	return s.has("step") and stap >= int(s["step"])


static func stap_klaar(q: Dictionary, s: Dictionary, flags: Dictionary, stap: int, voortgang := {}) -> bool:
	return quest_klaar(q, flags, stap, voortgang) or _stap_eigen(q, s, flags, stap, voortgang)


static func quest_klaar(q: Dictionary, flags: Dictionary, stap: int, voortgang := {}) -> bool:
	if q.is_empty():
		return false
	if bool(_rec(voortgang, str(q["id"])).get("done", false)):
		return true
	if str(q.get("done_flag", "")) != "":
		return flags.has(str(q["done_flag"]))
	if q.has("done_step"):
		return stap >= int(q["done_step"])
	var lijst: Array = q.get("steps", [])
	return not lijst.is_empty() and lijst.all(func(s): return _stap_eigen(q, s, flags, stap, voortgang))


## Gestart: geen startvlag, de startvlag staat, of er is al een stap (of de opdracht) klaar.
static func quest_gestart(q: Dictionary, flags: Dictionary, stap: int, voortgang := {}) -> bool:
	if quest_klaar(q, flags, stap, voortgang):
		return true
	var sf := str(q.get("start_flag", ""))
	if sf == "" or flags.has(sf):
		return true
	return (q.get("steps", []) as Array).any(func(s): return _stap_eigen(q, s, flags, stap, voortgang))


## Zijopdracht: heeft de speler de NPC al gesproken? (oude save met de startvlag telt ook)
static func zij_gesproken(q: Dictionary, flags: Dictionary, stap: int, voortgang := {}) -> bool:
	if str(q.get("spoken_flag", "")) != "" and flags.has(str(q["spoken_flag"])):
		return true
	return str(q.get("start_flag", "")) != "" and quest_gestart(q, flags, stap, voortgang)


static func akte_status(act_id: String, flags: Dictionary, stap: int, voortgang := {}) -> String:
	var lijst := in_act(act_id, HOOFD)
	if lijst.is_empty():
		return LATER
	if lijst.all(func(q): return quest_klaar(q, flags, stap, voortgang)):
		return KLAAR
	var i := act_ids().find(act_id)
	if i > 0 and akte_status(str(act_ids()[i - 1]), flags, stap, voortgang) != KLAAR:
		return DICHT
	return OPEN


## De act waar de speler nu is: de laatste act met inhoud die open of klaar is (anders Act 1).
static func huidige_akte(flags: Dictionary, stap: int, voortgang := {}) -> String:
	var uit := str(act_ids()[0]) if not acts().is_empty() else ""
	for id in act_ids():
		var st := akte_status(str(id), flags, stap, voortgang)
		if st == OPEN or st == KLAAR:
			uit = str(id)
	return uit


## ECHO's zinnen bij een act (één set per act).
static func echo_dialoog(act_id: String) -> Array[String]:
	var uit: Array[String] = []
	for r in act(act_id).get("echo_dialogue", []):
		uit.append(str(r))
	return uit


## Wat het scherm toont: een act die nog dicht is of nog geen inhoud heeft, telt niet mee.
static func akte_zichtbaar(act_id: String, flags: Dictionary, stap: int, voortgang := {}) -> bool:
	var st := akte_status(act_id, flags, stap, voortgang)
	return st == OPEN or st == KLAAR


## Opdrachten voor een tab ("actief" of "klaar") binnen één act.
## Actief: gestart en niet klaar. Een zijopdracht staat er ook als de NPC nog niet gesproken is
## (dan toont het scherm alleen de naam, grijs). Klaar: alles wat klaar is.
static func voor_tab(act_id: String, tab: String, flags: Dictionary, stap: int, voortgang := {}) -> Array:
	if not akte_zichtbaar(act_id, flags, stap, voortgang):
		return []
	var uit: Array = []
	for q in in_act(act_id):
		var klaar := quest_klaar(q, flags, stap, voortgang)
		if tab == "klaar":
			if klaar:
				uit.append(q)
		elif not klaar and (is_zij(q) or quest_gestart(q, flags, stap, voortgang)):
			uit.append(q)
	return uit


## Regel in de lijst: de titel, of (zijopdracht, NPC nog niet gesproken) de naam van de NPC.
static func regel(q: Dictionary, flags: Dictionary, stap: int, voortgang := {}) -> String:
	if is_zij(q) and not zij_gesproken(q, flags, stap, voortgang):
		return str(q.get("npc", q["title"]))
	return str(q["title"])


## Eerste open stap (leeg als klaar of nog niet gestart bij een zijopdracht).
static func huidige_doel(q: Dictionary, flags: Dictionary, stap: int, voortgang := {}) -> String:
	if quest_klaar(q, flags, stap, voortgang):
		return ""
	if is_zij(q) and not zij_gesproken(q, flags, stap, voortgang):
		return ""
	for s in q.get("steps", []):
		if not stap_klaar(q, s, flags, stap, voortgang):
			return str(s["text"])
	return ""


## De opdracht rechts in het scherm: (zijopdracht-regel), omschrijving, stappen met [x]/[ ].
static func detail_regels(q: Dictionary, flags: Dictionary, stap: int, voortgang := {}) -> Array[String]:
	var uit: Array[String] = []
	if is_zij(q):
		uit.append("%s - %s" % [ZIJ_LABEL, str(q.get("npc", ""))])
		if not zij_gesproken(q, flags, stap, voortgang):
			uit.append(NIET_GESTART)
			return uit
	uit.append(str(q.get("description", "")))
	for s in q.get("steps", []):
		uit.append((VINK_KLAAR if stap_klaar(q, s, flags, stap, voortgang) else VINK_OPEN) + str(s["text"]))
	return uit


# ---------------------------------------------------------------- voortgang
## Legt alles vast wat nu klaar is (vlaggen/verhaalstap). true = er is iets veranderd.
static func sync(voortgang: Dictionary, flags: Dictionary, stap: int) -> bool:
	var veranderd := false
	for q in quests():
		var qid := str(q["id"])
		var r := _rec(voortgang, qid).duplicate(true)
		var gedaan: Array = r.get("steps", []) if r.get("steps") is Array else []
		for s in q.get("steps", []):
			var sid := str(s["id"])
			if not gedaan.has(sid) and _stap_eigen(q, s, flags, stap, voortgang):
				gedaan.append(sid)
		var klaar := quest_klaar(q, flags, stap, voortgang)
		if gedaan.is_empty() and not klaar:
			continue
		var nieuw := {"steps": gedaan, "done": klaar}
		if nieuw != voortgang.get(qid):
			voortgang[qid] = nieuw
			veranderd = true
	return veranderd


## Story heeft 'event_id' afgerond: stappen met dat event worden klaar, daarna sync.
## Geeft de opdrachten terug waar een stap bij kwam ("quest_id/stap_id").
static func on_event(voortgang: Dictionary, event_id: String, flags: Dictionary, stap: int) -> Array[String]:
	var uit: Array[String] = []
	for q in quests():
		var qid := str(q["id"])
		for s in q.get("steps", []):
			if str(s.get("event", "")) != event_id or event_id == "":
				continue
			var r := _rec(voortgang, qid).duplicate(true)
			var gedaan: Array = r.get("steps", []) if r.get("steps") is Array else []
			if gedaan.has(str(s["id"])):
				continue
			gedaan.append(str(s["id"]))
			voortgang[qid] = {"steps": gedaan, "done": bool(r.get("done", false))}
			uit.append("%s/%s" % [qid, str(s["id"])])
	sync(voortgang, flags, stap)
	return uit


## Voortgang uit een save (oude saves: geen veld -> {}). Onbekende opdrachten/stappen vallen weg.
static func van_save(raw) -> Dictionary:
	var uit := {}
	if not (raw is Dictionary):
		return uit
	for qid in raw:
		var q := quest(str(qid))
		var r = raw[qid]
		if q.is_empty() or not (r is Dictionary):
			continue
		var geldig: Array = (q.get("steps", []) as Array).map(func(s): return str(s["id"]))
		var gedaan: Array = []
		if r.get("steps") is Array:
			for sid in r["steps"]:
				if geldig.has(str(sid)) and not gedaan.has(str(sid)):
					gedaan.append(str(sid))
		var klaar = r.get("done", false)
		uit[str(qid)] = {"steps": gedaan, "done": klaar is bool and klaar}
	return uit


static func speler_teksten() -> Array[String]:
	var uit: Array[String] = [TITEL, MENU_KNOP, TAB_ACTIEF, TAB_KLAAR, LEEG_ACTIEF, LEEG_KLAAR, ZIJ_LABEL, NIET_GESTART,
			OBJECTIVE_LABEL]
	for a in acts():
		uit.append(act_kop(str(a["id"])))
		uit.append(str(a.get("theme", "")))
		for k in ["echo_done", "echo_open"]:
			if a.has(k):
				uit.append(str(a[k]))
		uit.append_array(echo_dialoog(str(a["id"])))
	for q in quests():
		uit.append(str(q["title"]))
		uit.append(str(q.get("description", "")))
		if q.has("npc"):
			uit.append(str(q["npc"]))
		for s in q.get("steps", []):
			uit.append(str(s["text"]))
	return uit
