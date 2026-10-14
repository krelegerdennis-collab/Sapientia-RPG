class_name WorldWarperDialoog
extends RefCounted
## Dialoog van de AI-gids in de World Warper-hub. Alleen data.
## Dialog.show_lines toont de regels; dat schrijft geen story-event.
##
## story_flags bewaart alleen true-sleutels: game_state.gd schrijft
## story_flags.keys() weg en zet bij laden elke sleutel op true.
## Daarom één sleutel per bereikte stap, geen int op één sleutel.

const ID := "gids"

## Canon-naam. De bonus-lore (digitale echo van een onderzoeker) blijft een latere onthulling.
const NAAM := "ECHO"

const FLAG_VOORVOEGSEL := "world_warper_guide_"

## Zelfde sleutel als het join-event noor_bevrijd in story_data.gd.
const FLAG_NOOR_LID := "noor_lid"
## Zelfde sleutel als StoryData.GOLEM_FLAG.
const FLAG_GOLEM := "bewaker:archief_golemhal/golem"
## Zelfde sleutel als WorldWarperUnlock.BEWAKER_VLAG.
const FLAG_GENEZER := "bewaker:archief_2_v4_genezer/genezer"


static func flag_for(index: int) -> String:
	return FLAG_VOORVOEGSEL + str(index)


static func steps() -> Array:
	# TODO(design): zinnen zelf geformuleerd; Dennis bepaalt de definitieve tekst.
	return [
		{
			"id": "welkom",
			"flag": flag_for(0),
			"lines": [
				"I am ECHO. I am the guide of this hub.",
				"Ask me if you don't know the way.",
			],
		},
		{
			"id": "warp",
			"flag": flag_for(1),
			"lines": [
				"The ring takes you to the open world map.",
				"Then you arrive at a place.",
			],
		},
		{
			"id": "gesloten",
			"flag": flag_for(2),
			"lines": [
				"ECHO's Room is open. The Deep Learning Simulation begins there.",
				"The story opens the other rooms.",
			],
		},
		{
			"id": "hanger",
			"flag": flag_for(3),
			"lines": [
				"The Key reacted when you arrived.",
				"The Pendant is the Key.",
			],
		},
	]


## Eerste stap waarvan de vlag nog niet true is. Na de laatste stap: steps().size().
static func step_index(flags: Dictionary) -> int:
	var alle := steps()
	var i := 0
	while i < alle.size():
		var stap: Dictionary = alle[i]
		if not _vlag_aan(flags, str(stap.get("flag", ""))):
			return i
		i += 1
	return i


static func _vlag_aan(flags: Dictionary, sleutel: String) -> bool:
	if sleutel == "":
		return false
	# Alleen de bool true telt. Een int (1) mag niet met true vergeleken worden:
	# Godot weigert die operand en de stap zou dan niet betrouwbaar zijn.
	var waarde: Variant = flags.get(sleutel, false)
	return waarde is bool and (waarde as bool)


## Volgende bestemming die al in het spel bestaat. Geen nieuw verhaal.
## Volgorde: Noor, Golem van het Eerste Archief, De Genezer, anders de warp-ring.
static func hint_lines(flags: Dictionary, bezocht: Array = []) -> Array:
	if not _vlag_aan(flags, FLAG_NOOR_LID):
		return [
			"Vesper hasn't joined yet.",
			"Look for her in the Dark Wood.",
		]
	if not _vlag_aan(flags, FLAG_GOLEM):
		return [
			"The Golem of the First Archive still stands.",
			"Go to the First Archive.",
		]
	if not _vlag_aan(flags, FLAG_GENEZER):
		return [
			"The Mender still stands in the greenhouse of the Living Archive.",
			"Go through the Hollow Mountain.",
		]
	var plek := _wm1_plek(bezocht)
	if plek == "":
		return [
			"The warp ring takes you to world 1.",
			"Choose a place you have already visited.",
		]
	return [
		"The warp ring takes you to %s." % plek,
		"You have already visited that place on world 1.",
	]


## Staptekst. Welkom en hanger krijgen de hint erbij. Na de laatste stap alleen de hint.
static func regels_voor(index: int, flags: Dictionary, bezocht: Array = []) -> Array:
	var hint: Array = hint_lines(flags, bezocht)
	var alle := steps()
	if index < 0 or index >= alle.size():
		return hint
	var stap: Dictionary = alle[index]
	var regels: Array = []
	for zin in stap.get("lines", []):
		regels.append(str(zin))
	var id := str(stap.get("id", ""))
	if id == "welkom" or id == "hanger":
		regels.append_array(hint)
	return regels


## Laatst bezochte plek op wereld 1. Leeg als er geen open plek bij zit.
## load() en niet preload: destinations.gd noemt GameState, en de dialoogtest
## wordt geparsed vóór de autoloads.
static func _wm1_plek(bezocht: Array) -> String:
	var bestemmingen: GDScript = load("res://world_warper/warp/destinations.gd") as GDScript
	if bestemmingen == null:
		return ""
	var gekozen := ""
	var laatst := -1
	var plaatsen: Array = bestemmingen.places(str(bestemmingen.WM1))
	for place in plaatsen:
		if not (place is Dictionary):
			continue
		var plek: Dictionary = place
		if not bool(bestemmingen.is_place_open(plek, bezocht)):
			continue
		var path := str(plek.get("path", ""))
		var gezien := -1
		var i := 0
		for pad in bezocht:
			if str(pad) == path:
				gezien = i
			i += 1
		if gezien > laatst:
			laatst = gezien
			gekozen = str(plek.get("label", ""))
	return gekozen
