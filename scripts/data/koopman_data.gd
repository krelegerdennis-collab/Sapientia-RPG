extends RefCounted
## DE KOOPMAN (H-5), handelaar in de Diepe Grot. CANON §12 (docs/lore/CANON.md, "Beslissingen
## 13 okt 2026", PR #51): vorige proefpersoon, 2-3 jaar voor Dennis, haalde verdieping 100 niet,
## is zijn naam vergeten en noemt zichzelf "de Koopman" (EN: "the Merchant"). Drie fases:
##   bezoek 1-3  vaag en afstandelijk
##   bezoek 4-7  (na de H-6-onthulling) herkent Dennis, vertelt fragmenten
##   bezoek 8+   (of na Archief 5) vertelt de waarheid en geeft "H-5's Token"
##               (+10% stats tegen dienaren van Sapientia)
## Een BEZOEK = de eerste keer praten op een koopmanverdieping van een run (zelfde verdieping in
## dezelfde run telt één keer). Teller + token staan in de save (GameState.koopman_*).
## WM1 (content-lock H13, besluit Dennis 24 okt 2026): de Archief 4-lore is uit de fragmentregels gehaald
## ("Archive 4" en de regel "I came out of there too ... H-5"); die hoort bij een latere wereld.
## Tekst in de game is Engels; ids en commentaar Nederlands.

const NAAM := "the Merchant"
const SPRITE := preload("res://assets/sprites/npc/koopman_veld.png")
const TOKEN_ID := "h5_token"
const TOKEN_NAAM := "H-5's Token"
const TOKEN_BONUS := 0.10

const FASE_VAAG := 1
const FASE_FRAGMENT := 2
const FASE_WAARHEID := 3

## Grenzen uit CANON §12.
const FRAGMENT_VANAF := 4
const WAARHEID_VANAF := 8

## Regels per fase. Binnenkomst/vertrek uit TODO.md (Merchant Room, canon), vertaald.
const REGELS := {
	FASE_VAAG: [
		"Well, well. A new candidate. I've seen you on the walls, did you know? The Cave shows everything... to whoever keeps looking.",
		"My name? Gone. The Cave took it. Call me the Merchant, everyone does.",
		"Don't ask what's below. I sell. That's all I do down here.",
	],
	FASE_FRAGMENT: [
		"You again. No... wait. That pendant. That face.",
		"There were four before me. None of them reached the bottom. Neither did I.",
		"The Cave is not a dungeon. It's a filter. Keep that to yourself... she listens.",
	],
	FASE_WAARHEID: [
		"Sit. I'm done being afraid of her. You deserve the truth, H-6.",
		"I reached the deep floors and stopped. I listened to the Voice. The simulation didn't kill me. It kept me.",
		"Sapientia is waiting for 'the right one'. I wasn't. Your grandfather knew that when he met me.",
		"I'm ashamed I failed. But here, selling, I found something like peace.",
	],
}
const TOKEN_REGELS: Array[String] = [
	"Take this. It's all that's left of who I was.",
	"Received H-5's Token! (+10% stats against Sapientia's servants)",
]
const VERTREK := "If you hear the Voice, don't stand still. I did."

## EINDE (CANON 12, optie A; besluit Dennis 14 okt 2026). Bij de nederlaag van Sapientia (Archief 6)
## lost de simulatie op en verdwijnt H-5 glimlachend. Archief 6 bestaat nog niet: de verhaalscène daar
## roept KoopmanData.einde(GameState.story_flags) aan en toont de regels met spreker NAAM.
## Daarna staat er geen Koopman meer in de Grot (FLAG_RUST).
const FLAG_SAPIENTIA_VERSLAGEN := "sapientia_verslagen"
const FLAG_RUST := "h5_rust"
const AFSCHEID := "Thank you. Finally, rest."


## Fase bij een bezoekteller (1 = eerste bezoek). Na Archief 5 meteen de waarheid (CANON §12).
static func fase(bezoeken: int, na_archief5 := false) -> int:
	if na_archief5 or bezoeken >= WAARHEID_VANAF:
		return FASE_WAARHEID
	if bezoeken >= FRAGMENT_VANAF:
		return FASE_FRAGMENT
	return FASE_VAAG


## Regels voor een gesprek: fase-regels, bij fase 3 eenmalig de token, daarna vertrek.
static func gesprek(bezoeken: int, heeft_token: bool, na_archief5 := false) -> Array[String]:
	var f := fase(bezoeken, na_archief5)
	var uit: Array[String] = []
	for r in REGELS[f]:
		uit.append(str(r))
	if f == FASE_WAARHEID and not heeft_token:
		uit.append_array(TOKEN_REGELS)
	uit.append(VERTREK)
	return uit


## Sleutel van één bezoek: run + verdieping.
static func bezoek_sleutel(run_seed: int, floor_no: int) -> String:
	return "%d_%d" % [run_seed, floor_no]


## Statfactor van de token voor een held. Dienaren van Sapientia = alle vijanden in de Archieven
## en de Diepe Grot (TIJDELIJKE AANNAME: elk echt gevecht; oefengevechten en PvP niet).
static func token_factor(heeft_token: bool, tegen_dienaren: bool) -> float:
	return 1.0 + TOKEN_BONUS if heeft_token and tegen_dienaren else 1.0


## Haak voor Archief 6: zet de vlaggen en geeft de afscheidsregel (één keer; daarna []).
static func einde(flags: Dictionary) -> Array[String]:
	flags[FLAG_SAPIENTIA_VERSLAGEN] = true
	if bool(flags.get(FLAG_RUST, false)):
		return []
	flags[FLAG_RUST] = true
	return [AFSCHEID]


## Is H-5 verdwenen? (dan zet de Grot geen Koopman meer neer)
static func verdwenen(flags: Dictionary) -> bool:
	return bool(flags.get(FLAG_RUST, false)) or bool(flags.get(FLAG_SAPIENTIA_VERSLAGEN, false))
