class_name WorldWarperDreiging
extends RefCounted
## Eerste bezoek aan de Hal: canon-scène 2 (De Hanger) en 3 (Sapientia's dreiging).
## Tekst: world_warper/cutscene/canon_scenes.gd (CANON.md punt 17).
## Paars = Oude Mensheid / World Warper / ECHO. Roze glitch = Sapientia (de Zwarte Stroom).

const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")

## Oude vlag blijft voor oude saves en tests; zet de Hal-scène na afloop ook.
const FLAG := "world_warper_intro_seen"

## CS-11 (The Pendant): filmpje vervangt deze ECHO-regels uit canon HANGER zodra cutscene_cs11_gezien staat.
const CS11_ECHO_SKIP: Array[String] = [
	"Welcome to the World Warper, Dax. And company. I am ECHO.",
	"There it is. The Pendant. I had hoped I would never see it again.",
	"The key. This building only answers to it. Only to that Pendant. No one else can switch the World Warper on.",
	"That's a long story. And there is little time.",
]


## Speelt tot scène 3 gezien is (canon-vlag). Oude saves met alleen FLAG zien de canon alsnog.
static func should_play(flags: Dictionary) -> bool:
	return Canon.hal_speelt(flags)


static func regels(flags: Dictionary = {}) -> Array:
	return Canon.hal_regels(flags)


static func lines(flags: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var film := GameState.story_flags.has("cutscene_cs11_gezien")
	for r in regels(flags):
		var text := str(r.get("text", ""))
		if film and CS11_ECHO_SKIP.has(text):
			continue
		out.append(Canon.als_tekst(r))
	return out


## 1 stille hal, 2 paarse Hanger-gloed, 3 roze Sapientia-glitch, 4 herstel.
## line_index telt gefilterde regels (zelfde filter als lines()).
static func beat_at(line_index: int, flags: Dictionary = {}) -> int:
	var rs := regels(flags)
	if rs.is_empty():
		return 1
	var film := GameState.story_flags.has("cutscene_cs11_gezien")
	var kept: Array = []
	for r in rs:
		var text := str(r.get("text", ""))
		if film and CS11_ECHO_SKIP.has(text):
			continue
		kept.append(r)
	if kept.is_empty():
		return 1
	var i := clampi(line_index, 0, kept.size() - 1)
	return int(kept[i].get("cue", 1))


## Laatste index van scène 2 in deze reeks (-1 als scène 2 al gezien is).
static func einde_hanger(flags: Dictionary = {}) -> int:
	if bool(flags.get(Canon.FLAG_HANGER, false)):
		return -1
	var count := 0
	var film := GameState.story_flags.has("cutscene_cs11_gezien")
	for r in Canon.HANGER:
		var text := str(r.get("text", ""))
		if film and CS11_ECHO_SKIP.has(text):
			continue
		count += 1
	return count - 1 if count > 0 else -1
