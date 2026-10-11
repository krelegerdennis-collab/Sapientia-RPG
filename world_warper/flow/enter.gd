class_name WorldWarperEnter
extends RefCounted
## Binnenkomst van de World Warper-hub.
## Niet aanroepen vanuit een autoload. Geen registratie in project.godot.
## De hub-scène wordt niet gepreload: een andere taak levert het bestand.

const Unlock := preload("res://world_warper/flow/unlock.gd")

const HUB_SCENE := "res://world_warper/maps/exterieur.tscn"
const HUB_SPAWN := "ingang"


## Zelfde regel als de unlock, op een meegegeven dictionary (geen autoload).
static func can_enter(flags: Dictionary) -> bool:
	return Unlock.should_unlock(flags)


## Probeert te unlocken. Lukt dat, dan wissel naar de hub en geef true. Anders false.
func enter() -> bool:
	GameState.try_unlock_world_warper()
	if GameState.world_warper_is_unlocked():
		GameState.change_map(HUB_SCENE, HUB_SPAWN)
		return true
	return false
