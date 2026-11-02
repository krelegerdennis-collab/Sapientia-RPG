class_name WorldWarperUnlock
extends RefCounted
## Unlock van de World Warper, puur op een vlaggen-dictionary.
## Geen autoload en geen scènes, zodat een test GameState niet nodig heeft.
##
## Trigger is De Genezer, einde Archief 2 (kamer archief_2_v4_genezer, monster genezer).
## De bewaker van verdieping 2 van het Eerste Archief opent de hub niet.

## Zelfde string als GameState.try_unlock_world_warper.
const BEWAKER_VLAG := "bewaker:archief_2_v4_genezer/genezer"
const UNLOCK_VLAG := "world_warper_unlocked"


## Zelfde regel als GameState.try_unlock_world_warper, zonder te schrijven:
## al open, of De Genezer én canon-scène 3 (dreiging) gezien.
static func should_unlock(flags: Dictionary) -> bool:
	if flags.has(UNLOCK_VLAG):
		return true
	if not flags.has(BEWAKER_VLAG):
		return false
	return flags.has(CANON_DREIGING)


const CANON_DREIGING := "ww_canon_dreiging_gezien"
