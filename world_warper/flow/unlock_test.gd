extends RefCounted
## Zuivere checks voor de World Warper-unlock. Geen autoload, geen scène.
## Elke functie geeft de fouten terug (leeg = goed).

const Unlock := preload("res://world_warper/flow/unlock.gd")

## Andere bewaker dan verdieping 2: de Golem (archief_golemhal / golem).
const ANDERE_BEWAKER := "bewaker:archief_golemhal/golem"


static func lege_flags() -> PackedStringArray:
	var fouten: PackedStringArray = PackedStringArray()
	if Unlock.should_unlock({}):
		fouten.append("lege flags mogen niet unlocken")
	return fouten


static func alleen_bewaker() -> PackedStringArray:
	var flags := {Unlock.BEWAKER_VLAG: true}
	var fouten: PackedStringArray = PackedStringArray()
	if not Unlock.should_unlock(flags):
		fouten.append("alleen de bewaker-vlag moet unlocken")
	if flags.has(Unlock.UNLOCK_VLAG):
		fouten.append("de pure check mag world_warper_unlocked niet zelf zetten")
	return fouten


static func al_open() -> PackedStringArray:
	var flags := {Unlock.UNLOCK_VLAG: true}
	var fouten: PackedStringArray = PackedStringArray()
	if not flags.has(Unlock.UNLOCK_VLAG):
		fouten.append("world_warper_unlocked hoort al open te zijn")
	if not Unlock.should_unlock(flags):
		fouten.append("een al gezette unlock-vlag hoort open te blijven")
	if flags.has(Unlock.BEWAKER_VLAG):
		fouten.append("al open hoort de bewaker-vlag niet te eisen")
	return fouten


static func andere_bewaker() -> PackedStringArray:
	var flags := {ANDERE_BEWAKER: true}
	var fouten: PackedStringArray = PackedStringArray()
	if Unlock.should_unlock(flags):
		fouten.append("een andere bewaker-vlag mag niet unlocken")
	if flags.has(Unlock.UNLOCK_VLAG):
		fouten.append("een andere bewaker mag de unlock-vlag niet zetten")
	return fouten
