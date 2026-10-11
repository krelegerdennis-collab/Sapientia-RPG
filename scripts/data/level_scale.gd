extends RefCounted
## Act-banden en uitrustingslijnen t/m het einde.
## De EXP-formule blijft GameData.exp_for_level: 15 * (level - 1)^2 (CANON: onze levelschaal).
## Er is geen harde cap. De 100-verdiepingen-kerker gebruikt dezelfde formule en mag voorbij 40.
##
## Aanname (8 okt 2026, CANON/BOTSINGEN tegenover docs/lore/data/items.json):
## De worldbuilder zette Archief 1 op L1-5 en het einde op L34-40. In het spel is de Golem
## al gebalanceerd op ±Lv 10 (Vonkzwaard) en het Donker Woud op Lv 10-13. Act 1 houdt die
## band (1-13). Act 2-6 verdelen de rest tot 40, het eindlevel uit de lore. Het verhaal
## volgt Verhaal_Act2_tot_6.md waar CANON.md dat toelaat (Wachters Brons, Isolde, Osk,
## Perihelia; geen Ewout, geen Brandwijk, Noor blijft uit Esdoorn).
## Lotte's plek is nog vrij (CANON). Haar spullen staan op Act 2, klaar voor als ze aansluit.

const VERHAAL_MAX := 40

## act, min, max (inclusief), naam, wat de speler dan ongeveer draagt.
const ACTS := [
	{
		"act": 1, "min": 1, "max": 13,
		"naam": "Warden's House, the First Archive, Mapleton and the Dark Wood",
		"verwacht": "Starter set and Apprentice Cloak. Spark Sword from the archive chest. Noor joins after the Root King (Dennis's level minus 1) with Oak Staff and Travel Robe. Padded Jerkin, Herbal Tea and Glowing Ink can be found then.",
	},
	{
		"act": 2, "min": 14, "max": 19,
		"naam": "The Second Archive, Progress",
		"verwacht": "Forge gear: Kettle Blade, Scrap Plate, Work Cloak, Tuning Fork. Lotte is meant to join in this band; her place is not built yet.",
	},
	{
		"act": 3, "min": 20, "max": 25,
		"naam": "The Third Archive, Magic",
		"verwacht": "Temple gear: Anchor Blade, Hover Staff, Prayer Staff, Cloud Robe. The source is the Floating Temple and Isolde.",
	},
	{
		"act": 4, "min": 26, "max": 31,
		"naam": "The Fourth Archive, Life",
		"verwacht": "Laboratory: Incision, Life Staff, Chitin Armor, Antiserum Zero. This is where Dennis is revealed as test subject H-6.",
	},
	{
		"act": 5, "min": 32, "max": 36,
		"naam": "The Fifth Archive, Cosmos",
		"verwacht": "Star gear: Perihelion, Astrolabe Staff, Light Staff, Moon Armor. The source is the observatory and Perihelia.",
	},
	{
		"act": 6, "min": 37, "max": 40,
		"naam": "The Sixth Archive, the Heart",
		"verwacht": "Endgame gear: Memoria, Heartfire Staff, Heart Psalm, Tearplate, Heart Cloak, Heart Tear. Stronger than the seal set from the Hundred Floors.",
	},
]

## "type" = equip_type voor STRONGEST_WEIGHTS. "vak" leeg = genees-item (score = HP + MP).
## Volgorde = van vroeg naar laat. Een later stuk moet strikt sterker zijn.
## eiken_staf en leren_kap openen twee lijnen (Noor/Lotte, krijger/stroom).
const LIJNEN := {
	"zwaard": {"type": "krijger", "vak": "wapen", "ids": [
		"kort_zwaard", "vonkzwaard", "ketelkling", "ankerkling", "incisie", "perihelium", "memoria"]},
	"staf_noor": {"type": "magier", "vak": "wapen", "ids": [
		"eiken_staf", "rookstaf", "zweefstaf", "glazenstaf", "astrostaf", "hartvuurstaf"]},
	"staf_lotte": {"type": "priester", "vak": "wapen", "ids": [
		"eiken_staf", "stemvork", "gebedsstaf", "levensstaf", "lichtstaf", "hartpsalm"]},
	"schild": {"type": "krijger", "vak": "schild", "ids": [
		"houten_schild", "kaftschild", "ketelschild", "ankerschild", "kweekschild", "maanschild", "hartschild"]},
	"helm_krijger": {"type": "krijger", "vak": "helm", "ids": [
		"leren_kap", "ijzeren_helm", "ketelhelm", "tempelhelm", "kweekhelm", "sterrenhelm", "zouthelm"]},
	"helm_stroom": {"type": "magier", "vak": "helm", "ids": [
		"leren_kap", "rookkap", "windkap", "glashelm", "sterrenkap", "traankap"]},
	"harnas_krijger": {"type": "krijger", "vak": "harnas", "ids": [
		"leren_harnas", "malienkolder", "schrootplaat", "tempelplaat", "chitineharnas", "maanharnas", "tranenpantser"]},
	"harnas_stroom": {"type": "magier", "vak": "harnas", "ids": [
		"reisgewaad", "wambuis", "werkmantel", "wolkgewaad", "labmantel", "sterrenmantel", "hartmantel"]},
	"ring": {"type": "standaard", "vak": "accessoire", "ids": [
		"bladwijzer", "koperring", "stroomring", "levensring", "sterrenring", "hartring"]},
	"drank": {"type": "", "vak": "", "ids": [
		"kruid", "drankje", "gloeiende_inktfles", "kruidenthee", "smeerolie", "windwater",
		"stroomdrank", "antiserum_nul", "regeneratie", "sterrenelixer", "herinnering", "harttraan"]},
}

## Stukken die in twee lijnen mogen staan (gedeelde beginset).
const GEDEELD := ["eiken_staf", "leren_kap"]

## Eind van een verhaallijn moet de zegel-set van de 100 verdiepingen voorbij (zelfde vak).
const VOORBIJ_ARCHIEF := {
	"zwaard": "d100_zwaard_5",
	"staf_noor": "d100_staf_5",
	"staf_lotte": "d100_staf_5",
	"schild": "d100_schild_5",
	"helm_krijger": "d100_helm_5",
	"helm_stroom": "d100_helm_5",
	"harnas_krijger": "d100_harnas_5",
	"harnas_stroom": "d100_harnas_5",
	"ring": "d100_ring_5",
}

## Al in het spel te vinden (niet alleen data). De rest van de nieuwe catalogus wacht op Act 2-6.
const NU_TE_VINDEN := {
	"wambuis": "Noor gives it when she joins, into the bag.",
	"kruidenthee": "Ilse in Mapleton, once, after Noor is saved.",
	"gloeiende_inktfles": "The Ink Worm's cabinet in Golem Hall, once, when it opens.",
}


static func act_for_level(level: int) -> int:
	if level < 1:
		return 0
	for b in ACTS:
		if level >= int(b["min"]) and level <= int(b["max"]):
			return int(b["act"])
	if level > VERHAAL_MAX:
		return int(ACTS[ACTS.size() - 1]["act"])
	return 0


static func band(act: int) -> Dictionary:
	for b in ACTS:
		if int(b["act"]) == act:
			return b
	return {}


static func lijn_ids(naam: String) -> Array:
	var l: Dictionary = LIJNEN.get(naam, {})
	var ids = l.get("ids", [])
	return ids if ids is Array else []
