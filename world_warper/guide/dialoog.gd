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


static func flag_for(index: int) -> String:
	return FLAG_VOORVOEGSEL + str(index)


static func steps() -> Array:
	# TODO(design): zinnen zelf geformuleerd; Dennis bepaalt de definitieve tekst.
	return [
		{
			"id": "welkom",
			"flag": flag_for(0),
			"lines": [
				"Ik ben ECHO. Ik ben de gids van deze hub.",
				"Vraag het me als je de weg niet weet.",
			],
		},
		{
			"id": "warp",
			"flag": flag_for(1),
			"lines": [
				"De ring brengt je naar de open wereldkaart.",
				"Daarna kom je bij een plaats.",
			],
		},
		{
			"id": "gesloten",
			"flag": flag_for(2),
			"lines": [
				"De verdere kamers blijven dicht.",
				"Het verhaal geeft ze vrij.",
			],
		},
		{
			"id": "hanger",
			"flag": flag_for(3),
			"lines": [
				"De Sleutel reageerde bij je aankomst.",
				"De Hanger is de Sleutel.",
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
