extends RefCounted
## Onthulling van De Spiegel (Archief 4). Alleen deze data: geen verhaalvlag,
## geen wereldkaart, geen gevecht. H-1 t/m H-5 blijven oningevuld.

const SCENE := "res://scenes/story/spiegel_kamer.tscn"
const DEBUG_ARG := "--spiegel"

const WIE_SPIEGEL := "The Mirror"
const WIE_DENNIS := "Dax"
## Na de scène zeggen zij niets. Er is geen regel voor hen.
const ZWIJGEN: Array[String] = ["Vesper", "Seren"]

const KAMER := "A room full of mirrored surfaces."
const WAARHEID := "The Mirror does not fight with force but with truth."
const FEIT_H6 := "Dax is Test Subject H-6."
const FEIT_GEMAAKT := "He was not born but made."
const FEIT_HANGER := "The Pendant belongs to him, and he belongs to the Pendant."
const FEIT_TERUG := "Sapientia wants him back, not defeated."
const WEIGERING := "I am Dax. And that is enough."
const LAATSTE := "You are stronger than the last five. Maybe... you will be the first to make it."
const KERN := "The core of Archief 4 has been absorbed."

## Geen vijand. Bewust geen hp en geen max_hp.
const SPIEGEL := {
	"id": "de_spiegel",
	"naam": "The Mirror",
}

## Volgorde van de scène. "stilte" toont geen tekst. "breekt" hoort bij de weigering.
const BEATS: Array = [
	{"id": "kamer", "wie": "", "tekst": [KAMER]},
	{"id": "waarheid", "wie": "", "tekst": [WAARHEID]},
	{"id": "h6", "wie": WIE_SPIEGEL, "tekst": [FEIT_H6]},
	{"id": "gemaakt", "wie": WIE_SPIEGEL, "tekst": [FEIT_GEMAAKT]},
	{"id": "hanger", "wie": WIE_SPIEGEL, "tekst": [FEIT_HANGER]},
	{"id": "terug", "wie": WIE_SPIEGEL, "tekst": [FEIT_TERUG]},
	{"id": "stilte", "wie": WIE_DENNIS, "stilte": true},
	# Dennis vraagt de zojuist genoemde feiten terug. Alleen een vraagteken erbij.
	{"id": "vragen", "wie": WIE_DENNIS, "vragen": true, "tekst": [
		"Dax is Test Subject H-6?",
		"He was not born but made?",
		"The Pendant belongs to him, and he belongs to the Pendant?",
		"Sapientia wants him back, not defeated?",
	]},
	{"id": "weigering", "wie": WIE_DENNIS, "tekst": [WEIGERING]},
	{"id": "laatste", "wie": WIE_SPIEGEL, "tekst": [LAATSTE]},
	{"id": "na", "wie": "", "tekst": [KERN], "kern": true},
]


static func heeft_gevechts_hp() -> bool:
	return SPIEGEL.has("hp") or SPIEGEL.has("max_hp")


## Alleen de weigering breekt de spiegel. Kracht doet dat niet.
static func breek_door(reden: String) -> bool:
	return reden == "weigering"


static func pas_toe(reden: String, staat: Dictionary) -> Dictionary:
	var uit := staat.duplicate()
	if breek_door(reden):
		uit["gebroken"] = true
		uit["gebroken_door"] = reden
	return uit


static func beat_index(id: String) -> int:
	for i in BEATS.size():
		if str(BEATS[i].get("id", "")) == id:
			return i
	return -1


static func zinnen() -> Array[String]:
	var uit: Array[String] = []
	for beat in BEATS:
		if bool(beat.get("stilte", false)):
			continue
		for regel in beat.get("tekst", []):
			uit.append(str(regel))
	return uit


static func heeft_zin(zin: String) -> bool:
	return zinnen().has(zin)


static func sprekers() -> Array[String]:
	var uit: Array[String] = []
	for beat in BEATS:
		var wie := str(beat.get("wie", ""))
		if wie != "" and not uit.has(wie):
			uit.append(wie)
	return uit


## Speelt de beats af zonder tekstvak en zonder GameState. Kracht breekt niets.
static func speel() -> Dictionary:
	var gebroken := false
	var door := ""
	var kern := false
	var dennis_na: Array[String] = []
	var na_weigering := false
	var noor: Array[String] = []
	var lotte: Array[String] = []
	var warper: Array[String] = []
	for beat in BEATS:
		var id := str(beat.get("id", ""))
		var wie := str(beat.get("wie", ""))
		var tekst: Array = beat.get("tekst", [])
		if id == "world_warper" or bool(beat.get("world_warper", false)):
			for regel in tekst:
				warper.append(str(regel))
		if na_weigering and wie == WIE_DENNIS:
			for regel in tekst:
				dennis_na.append(str(regel))
		if wie == "Vesper":
			for regel in tekst:
				noor.append(str(regel))
		if wie == "Seren":
			for regel in tekst:
				lotte.append(str(regel))
		if breek_door(id):
			gebroken = true
			door = id
			na_weigering = true
		if bool(beat.get("kern", false)):
			kern = true
	var kracht: Dictionary = pas_toe("kracht", {"gebroken": false, "gebroken_door": ""})
	return {
		"gebroken": gebroken,
		"gebroken_door": door,
		"kern_opgenomen": kern,
		"dennis_na_weigering": dennis_na,
		"noor": noor,
		"lotte": lotte,
		"world_warper": warper,
		"kracht_breekt": bool(kracht.get("gebroken", false)),
		"gevechts_hp": heeft_gevechts_hp(),
	}
