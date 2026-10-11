class_name WorldWarperUnlock
extends RefCounted
## Unlock van de World Warper, puur op een vlaggen-dictionary.
## Geen autoload en geen scènes, zodat een test GameState niet nodig heeft.
##
## TODO(design): trigger is de bewaker van verdieping 2 van het Eerste Archief
## (bewaker:archief_v2_trapzaal/m2). Dit is NIET het Archief van Leven uit TODO.md;
## dat archief bestaat niet. Geen afhankelijkheid van code die nog gebouwd moet worden.

## Zelfde string als GameState.try_unlock_world_warper.
const BEWAKER_VLAG := "bewaker:archief_v2_trapzaal/m2"
const UNLOCK_VLAG := "world_warper_unlocked"


## Zelfde regel als GameState.try_unlock_world_warper, zonder te schrijven:
## al open, of de bewaker-vlag staat aan. Anders dicht.
static func should_unlock(flags: Dictionary) -> bool:
	if flags.has(UNLOCK_VLAG):
		return true
	return flags.has(BEWAKER_VLAG)
