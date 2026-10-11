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
		"naam": "Wachtershuis, het Eerste Archief, Esdoorn en het Donker Woud",
		"verwacht": "Beginnersset en Leerling-mantel. Vonkzwaard uit de archiefkist. Noor sluit aan na de Wortelkoning (niveau van Dennis min 1) met Eiken Staf en Reisgewaad. Wambuis, Kruidenthee en de Gloeiende Inktfles zijn dan te vinden.",
	},
	{
		"act": 2, "min": 14, "max": 19,
		"naam": "Het Tweede Archief, de Vooruitgang",
		"verwacht": "Smidse-uitrusting: Ketelkling, Schrootplaat, Werkmantel, Stemvork. Lotte hoort in deze band aan te sluiten; haar plek is nog niet gebouwd.",
	},
	{
		"act": 3, "min": 20, "max": 25,
		"naam": "Het Derde Archief, de Magie",
		"verwacht": "Tempel-uitrusting: Ankerkling, Zweefstaf, Gebedsstaf, Wolkgewaad. Bron is de Zwevende Tempel en Isolde.",
	},
	{
		"act": 4, "min": 26, "max": 31,
		"naam": "Het Vierde Archief, het Leven",
		"verwacht": "Laboratorium: Incisie, Levensstaf, Chitineharnas, Antiserum Nul. Hier hoort de onthulling dat Dennis proefpersoon H-6 is.",
	},
	{
		"act": 5, "min": 32, "max": 36,
		"naam": "Het Vijfde Archief, de Kosmos",
		"verwacht": "Sterrenuitrusting: Perihelium, Astrostaf, Lichtstaf, Maanharnas. Bron is het observatorium en Perihelia.",
	},
	{
		"act": 6, "min": 37, "max": 40,
		"naam": "Het Zesde Archief, het Hart",
		"verwacht": "Eindspullen: Memoria, Hartvuurstaf, Hartpsalm, Tranenpantser, Hartmantel, Harttraan. Sterker dan de zegel-set uit de 100 verdiepingen.",
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
	"wambuis": "Noor geeft hem bij het aansluiten, in de tas.",
	"kruidenthee": "Ilse in Esdoorn, eenmalig nadat Noor gered is.",
	"gloeiende_inktfles": "Kast van de Inktwurm in de Golemhal, eenmalig bij het openen.",
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
