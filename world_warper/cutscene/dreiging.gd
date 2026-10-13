class_name WorldWarperDreiging
extends RefCounted
## Eerste bezoek aan de World Warper: Hanger-activatie en de dreiging van Sapientia.
## De Hanger is de Sleutel. Roze is de Stroom. Sapientia is de Zwarte Stroom.
## Geen identiteitsonthulling in spelertekst.

const FLAG := "world_warper_intro_seen"

## TODO(design): de zinnen zijn voorlopig. De beats zijn vast, de formulering niet.
## Volgorde: 1 paarse stilte, 2 paarse Hanger, 3 Zwarte Stroom (geen speech), 4 herstel.
## beat_at() hoort bij die volgorde: regel 0 = beat 1, regel 1 = beat 2,
## de laatste regel = beat 4, alles daartussen = beat 3.


static func should_play(flags: Dictionary) -> bool:
	return not flags.has(FLAG)


static func lines() -> Array[String]:
	var out: Array[String] = []
	out.append("The hall is purple. It is quiet.")
	out.append("The Hanger grows warm. The Stream glows pink.")
	out.append("The hologram stutters. The Black Stream is here for a moment.")
	out.append("Sapientia knows the Key is here.")
	out.append("The light returns. The hub stays open. The other rooms stay closed.")
	return out


## 1 paars, 2 paarse Hanger-gloed, 3 zwarte flikkering, 4 herstel. De Stroom in de zin blijft roze.
static func beat_at(line_index: int) -> int:
	var n := lines().size()
	if line_index <= 0:
		return 1
	if line_index == 1 and line_index < n - 1:
		return 2
	if line_index >= n - 1:
		return 4
	return 3
