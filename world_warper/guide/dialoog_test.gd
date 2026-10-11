class_name WorldWarperDialoogTest
extends RefCounted
## Pure controles op de gids-dialoog. Geen boom, geen Dialog, geen save.
## Roep fouten() aan: lege array = in orde.

const Dialoog := preload("res://world_warper/guide/dialoog.gd")

const VERWACHT_IDS: Array[String] = ["welkom", "warp", "gesloten", "hanger"]

const NL: Array[String] = [
	"de", "het", "een", "ik", "je", "jij", "van", "naar", "niet", "bij",
	"deze", "dit", "dat", "als", "me", "mij", "tot", "voor", "met", "dan",
	"ook", "maar", "ze", "we", "wij", "hij", "zij", "hun", "te", "om",
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
			if not _is_nederlands(tekst):
				fouten.append("geen Nederlandse zin: %s" % tekst)
			for woord in _woorden(tekst):
				if woord in ENGELS_UI:
					fouten.append("Engels UI-woord '%s' in: %s" % [woord, tekst])


static func _check_inhoud(fouten: Array) -> void:
	var stappen: Array = Dialoog.steps()
	if stappen.size() < 4:
		return
	_eist(fouten, stappen[0], ["gids", "echo"])
	_eist(fouten, stappen[1], ["ring", "wereldkaart", "plaats"])
	_eist(fouten, stappen[2], ["kamer", "verhaal"])
	_eist(fouten, stappen[3], ["sleutel", "hanger"])


static func _eist(fouten: Array, stap: Dictionary, woorden: Array) -> void:
	var tekst := ""
	for zin in stap.get("lines", []):
		tekst += " " + str(zin)
	var laag := tekst.to_lower()
	for woord in woorden:
		if not laag.contains(str(woord)):
			fouten.append("stap %s mist '%s'" % [str(stap.get("id", "")), str(woord)])


static func _verboden(fouten: Array, waar: String, tekst: String) -> void:
	var laag := tekst.to_lower()
	for naald in VERBODEN_SUB:
		if laag.contains(naald):
			fouten.append("%s bevat '%s'" % [waar, naald])


static func _is_nederlands(zin: String) -> bool:
	for woord in _woorden(zin):
		if woord in NL:
			return true
	return false


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
