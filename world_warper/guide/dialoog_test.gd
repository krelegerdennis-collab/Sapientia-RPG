class_name WorldWarperDialoogTest
extends RefCounted
## Pure controles op de gids-dialoog. Geen boom, geen Dialog, geen save.
## Roep fouten() aan: lege array = in orde.

const Dialoog := preload("res://world_warper/guide/dialoog.gd")

const VERWACHT_IDS: Array[String] = ["welkom", "warp", "gesloten", "hanger"]

const NL: Array[String] = [
	"de", "het", "een", "ik", "je", "jij", "van", "naar", "niet", "bij",
	"deze", "dit", "dat", "als", "mij", "tot", "voor", "met", "dan",
	"ook", "maar", "wij", "hij", "zij", "hun", "te", "om",
	"wel", "geen", "nog", "er", "ben", "wordt", "worden", "hebt", "heeft",
	"hier", "daar", "waar", "hoe", "wat", "wie", "mijn", "jouw",
]

const ENGELS_UI: Array[String] = [
	"start", "locked", "quest", "welcome", "press", "continue", "cancel",
	"loading", "error", "save", "load", "menu", "exit", "back", "next",
	"yes", "no", "skip", "close", "guide", "hello",
]

const VERBODEN_SUB: Array[String] = ["h-6", "proefpersoon"]


static func geslaagd() -> bool:
	return fouten().is_empty()


static func fouten() -> Array:
	var uit: Array = []
	_check_volgorde(uit)
	_check_tekst(uit)
	_check_inhoud(uit)
	_check_hint(uit)
	return uit


static func _check_volgorde(fouten: Array) -> void:
	var stappen: Array = Dialoog.steps()
	if stappen.size() != VERWACHT_IDS.size():
		fouten.append("verwacht %d stappen, kreeg %d" % [VERWACHT_IDS.size(), stappen.size()])
		return
	var gezet := {}
	var vorige := -1
	for i in stappen.size():
		var stap: Dictionary = stappen[i]
		if str(stap.get("id", "")) != VERWACHT_IDS[i]:
			fouten.append("stap %d heeft id %s" % [i, str(stap.get("id", ""))])
		var verwacht_vlag := Dialoog.flag_for(i)
		if str(stap.get("flag", "")) != verwacht_vlag:
			fouten.append("stap %d heeft vlag %s" % [i, str(stap.get("flag", ""))])
		var idx := int(Dialoog.step_index(gezet))
		if idx != i:
			fouten.append("index is %d, verwacht %d" % [idx, i])
		if idx <= vorige:
			fouten.append("index loopt niet op bij stap %d" % i)
		vorige = idx
		gezet[verwacht_vlag] = true
	var eind := int(Dialoog.step_index(gezet))
	if eind != stappen.size():
		fouten.append("na alle vlaggen is de index %d" % eind)
	if eind <= vorige:
		fouten.append("eindindex loopt niet op")
	if int(Dialoog.step_index({"world_warper_guide_step": 3})) != 0:
		fouten.append("een int op world_warper_guide_step telt mee")
	var later := {}
	later[Dialoog.flag_for(2)] = true
	if int(Dialoog.step_index(later)) != 0:
		fouten.append("een latere vlag slaat stappen over")
	var onecht := {}
	onecht[Dialoog.flag_for(0)] = false
	if int(Dialoog.step_index(onecht)) != 0:
		fouten.append("false telt als gezet")
	var getal := {}
	getal[Dialoog.flag_for(0)] = 1
	if int(Dialoog.step_index(getal)) != 0:
		fouten.append("een getal telt als gezet")


static func _check_tekst(fouten: Array) -> void:
	if str(Dialoog.ID) != "gids":
		fouten.append("interne id is niet gids")
	if str(Dialoog.NAAM) != "ECHO":
		fouten.append("zichtbare naam is niet ECHO")
	if str(Dialoog.NAAM) == "IVA":
		fouten.append("zichtbare naam is nog IVA")
	_verboden(fouten, "naam", str(Dialoog.NAAM))
	for stap in Dialoog.steps():
		var regels = stap.get("lines", [])
		if not (regels is Array) or (regels as Array).is_empty():
			fouten.append("stap %s heeft geen zinnen" % str(stap.get("id", "")))
			continue
		for zin in regels:
			var tekst := str(zin)
			if tekst.strip_edges() == "":
				fouten.append("lege zin in stap %s" % str(stap.get("id", "")))
				continue
			_verboden(fouten, str(stap.get("id", "")), tekst)
			if _is_nederlands(tekst):
				fouten.append("Nederlandse zin (speltekst is Engels): %s" % tekst)


static func _check_inhoud(fouten: Array) -> void:
	var stappen: Array = Dialoog.steps()
	if stappen.size() < 4:
		return
	_eist(fouten, stappen[0], ["guide", "echo"])
	_eist(fouten, stappen[1], ["ring", "world map", "place"])
	_eist(fouten, stappen[2], ["room", "story"])
	_eist(fouten, stappen[3], ["key", "hanger"])


static func _eist(fouten: Array, stap: Dictionary, woorden: Array) -> void:
	var tekst := ""
	for zin in stap.get("lines", []):
		tekst += " " + str(zin)
	var laag := tekst.to_lower()
	for woord in woorden:
		if not laag.contains(str(woord)):
			fouten.append("stap %s mist '%s'" % [str(stap.get("id", "")), str(woord)])


static func _check_hint(fouten: Array) -> void:
	# load() en niet preload: story_data is groot, en de kamer-test laadt dit
	# script terwijl GameState de wereldkaart al op de achtergrond inleest.
	var story: GDScript = load("res://scripts/data/story_data.gd") as GDScript
	var unlock: GDScript = load("res://world_warper/flow/unlock.gd") as GDScript
	if story == null or unlock == null:
		fouten.append("vlag-bronnen laden niet")
		return
	if str(Dialoog.FLAG_NOOR_LID) != "noor_lid":
		fouten.append("Noor-vlag is niet noor_lid")
	if str(Dialoog.FLAG_GOLEM) != str(story.GOLEM_FLAG):
		fouten.append("Golem-vlag wijkt af van de bewaker")
	if str(Dialoog.FLAG_GENEZER) != str(unlock.BEWAKER_VLAG):
		fouten.append("Genezer-vlag wijkt af van de bewaker")
	var leeg := {}
	_hint_eis(fouten, "zonder vlag", Dialoog.hint_lines(leeg),
			["donker woud"],
			["eerste archief", "genezer", "warp ring", "berggrot"])
	var alleen_golem := {Dialoog.FLAG_GOLEM: true}
	_hint_eis(fouten, "golem zonder noor", Dialoog.hint_lines(alleen_golem),
			["donker woud"], ["eerste archief"])
	var getal := {Dialoog.FLAG_NOOR_LID: 1}
	_hint_eis(fouten, "getal telt niet als noor", Dialoog.hint_lines(getal),
			["donker woud"], ["eerste archief"])
	var noor := {Dialoog.FLAG_NOOR_LID: true}
	_hint_eis(fouten, "na noor", Dialoog.hint_lines(noor),
			["eerste archief", "golem"],
			["donker woud", "genezer", "warp ring", "berggrot"])
	var golem := {Dialoog.FLAG_NOOR_LID: true, Dialoog.FLAG_GOLEM: true}
	_hint_eis(fouten, "na golem", Dialoog.hint_lines(golem),
			["genezer", "greenhouse", "archief 2", "berggrot"],
			["donker woud", "eerste archief", "warp ring"])
	var klaar := {
		Dialoog.FLAG_NOOR_LID: true,
		Dialoog.FLAG_GOLEM: true,
		Dialoog.FLAG_GENEZER: true,
	}
	_hint_eis(fouten, "na genezer zonder bezoek", Dialoog.hint_lines(klaar, []),
			["warp ring", "world 1", "visited"],
			["donker woud", "genezer", "wilgendal", "esdoorn", "world map", "berggrot"])
	var bestemmingen: GDScript = load("res://world_warper/warp/destinations.gd") as GDScript
	if bestemmingen == null:
		fouten.append("warp-bestemmingen laden niet")
		return
	var esdoorn_eerst: Array = [str(bestemmingen.ESDOORN_PATH), str(bestemmingen.WILGENDAL_PATH)]
	_hint_eis(fouten, "laatst bezocht op wereld 1", Dialoog.hint_lines(klaar, esdoorn_eerst),
			["warp ring", "wilgendal", "world 1"],
			["esdoorn", "world map", "genezer", "donker woud"])
	var vreemd: Array = ["res://scenes/maps/archief_2_v1_entree.tscn"]
	_hint_eis(fouten, "kas is geen wereld-1-plek", Dialoog.hint_lines(klaar, vreemd),
			["warp ring", "visited"],
			["wilgendal", "esdoorn", "world map", "greenhouse"])
	var welkom: Array = Dialoog.regels_voor(0, leeg)
	_hint_eis(fouten, "welkom met hint", welkom, ["echo", "guide", "donker woud"], ["iva"])
	var warp: Array = Dialoog.regels_voor(1, leeg)
	_hint_eis(fouten, "warp zonder hint", warp, ["ring", "world map"], ["donker woud"])
	var hanger: Array = Dialoog.regels_voor(3, leeg)
	_hint_eis(fouten, "hanger met hint", hanger, ["hanger", "key", "donker woud"], ["iva"])
	var na: Array = Dialoog.regels_voor(Dialoog.steps().size(), noor)
	_hint_eis(fouten, "na de stappen alleen de hint", na, ["eerste archief"], ["echo", "hanger", "donker woud"])


static func _hint_eis(fouten: Array, waar: String, regels: Array, moet: Array, niet: Array) -> void:
	if regels.is_empty():
		fouten.append("%s heeft geen zinnen" % waar)
		return
	var tekst := ""
	for zin in regels:
		var regel := str(zin)
		tekst += " " + regel
		if regel.strip_edges() == "":
			fouten.append("lege hintzin in %s" % waar)
			continue
		_verboden(fouten, waar, regel)
		if _is_nederlands(regel):
			fouten.append("Nederlandse hint (speltekst is Engels): %s" % regel)
		var laag := regel.to_lower()
		for naald in ["h-1", "h-2", "h-3", "h-4", "h-5", "spiegel", "onderzoeker", "worldmap", "iva"]:
			if laag.contains(naald):
				fouten.append("%s bevat '%s'" % [waar, naald])
	var geheel := tekst.to_lower()
	for woord in moet:
		if not geheel.contains(str(woord)):
			fouten.append("%s mist '%s'" % [waar, str(woord)])
	for woord in niet:
		if geheel.contains(str(woord)):
			fouten.append("%s noemt '%s'" % [waar, str(woord)])


static func _verboden(fouten: Array, waar: String, tekst: String) -> void:
	var laag := tekst.to_lower()
	for naald in VERBODEN_SUB:
		if laag.contains(naald):
			fouten.append("%s bevat '%s'" % [waar, naald])


## Speltekst is Engels (AGENTS.md). Eigennamen als "De Genezer" of "Donker Woud" mogen:
## pas bij twee verschillende Nederlandse woorden telt een zin als Nederlands.
static func _is_nederlands(zin: String) -> bool:
	var gezien := {}
	for woord in _woorden(zin):
		if woord in NL:
			gezien[woord] = true
	return gezien.size() >= 2


static func _woorden(zin: String) -> Array:
	var laag := zin.to_lower()
	var huidig := ""
	var uit: Array = []
	var i := 0
	while i < laag.length():
		var teken := laag.substr(i, 1)
		if _is_letter(teken):
			huidig += teken
		elif huidig != "":
			uit.append(huidig)
			huidig = ""
		i += 1
	if huidig != "":
		uit.append(huidig)
	return uit


static func _is_letter(teken: String) -> bool:
	if teken == "":
		return false
	var code := teken.unicode_at(0)
	if code >= 97 and code <= 122:
		return true
	return teken in ["é", "ë", "ï", "ö", "ü", "á", "à", "è", "ê", "ó", "ú", "í", "ç"]
