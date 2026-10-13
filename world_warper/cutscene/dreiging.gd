class_name WorldWarperDreiging
extends RefCounted
## Eerste bezoek aan de Hal: canon-scène 2 (De Hanger) en 3 (Sapientia's dreiging).
## Tekst: world_warper/cutscene/canon_scenes.gd (CANON.md punt 17).
## Paars = Oude Mensheid / World Warper / ECHO. Roze glitch = Sapientia (de Zwarte Stroom).

const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")

## Oude vlag blijft voor oude saves en tests; zet de Hal-scène na afloop ook.
const FLAG := "world_warper_intro_seen"


## Speelt tot scène 3 gezien is (canon-vlag). Oude saves met alleen FLAG zien de canon alsnog.
static func should_play(flags: Dictionary) -> bool:
	return Canon.hal_speelt(flags)


static func regels(flags: Dictionary = {}) -> Array:
	return Canon.hal_regels(flags)


static func lines(flags: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	for r in regels(flags):
		out.append(Canon.als_tekst(r))
	return out


## 1 stille hal, 2 paarse Hanger-gloed, 3 roze Sapientia-glitch, 4 herstel.
static func beat_at(line_index: int, flags: Dictionary = {}) -> int:
	var rs := regels(flags)
	if rs.is_empty():
		return 1
	var i := clampi(line_index, 0, rs.size() - 1)
	return int(rs[i].get("cue", 1))


## Laatste index van scène 2 in deze reeks (-1 als scène 2 al gezien is).
static func einde_hanger(flags: Dictionary = {}) -> int:
	if bool(flags.get(Canon.FLAG_HANGER, false)):
		return -1
	return Canon.HANGER.size() - 1
