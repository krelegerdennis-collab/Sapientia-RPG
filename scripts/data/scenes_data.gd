extends RefCounted
## v0.22 Veldmenu > Scenes (Dennis): alle cutscenes van het spel om opnieuw te bekijken.
## Data-gedreven: een nieuwe cutscene = een regel hier (+ een 'kind' in scripts/ui/scenes_screen.gd).
##   id     : vaste sleutel (gaat mee in de save, GameState.scenes_seen)
##   title  : spelertekst (Engels)
##   flag   : bestaande verhaalvlag die de cutscene zelf zet; daarmee worden oude saves gemigreerd
##            (vlag gezet = gezien) en telt een cutscene als 'gezien' zodra hij gespeeld is
##   kind   : hoe het scherm hem afspeelt
## Alleen echte, op zichzelf staande cutscenes. Verhaal-events uit story_data.gd horen hier niet bij:
## die zetten vlaggen, geven spullen, starten gevechten of wisselen van map en zijn dus niet veilig te herhalen.

const WORLDMAP_FLAG := "cutscene_wereldkaart_gezien"     # = WorldmapCutscene.FLAG
const HANGER_FLAG := "world_warper_intro_seen"           # = WorldWarperDreiging.FLAG
## v0.23 World Warper-canonscènes (#73, CANON.md punt 17); vlaggen = WorldWarperCanon.FLAG_*
const CANON_GENEZER_FLAG := "ww_canon_genezer_gezien"
const CANON_HANGER_FLAG := "ww_canon_hanger_gezien"
const CANON_DREIGING_FLAG := "ww_canon_dreiging_gezien"
const LOCKED_TITLE := "???"

const SCENES := [
	{"id": "wereldkaart", "title": "Into the Wide World", "flag": WORLDMAP_FLAG, "kind": "worldmap"},
	{"id": "hanger", "title": "The Pendant Awakens", "flag": HANGER_FLAG, "kind": "hanger"},
	{"id": "ww_warper", "title": "The World Warper", "flag": CANON_GENEZER_FLAG, "kind": "genezer"},
	{"id": "ww_hanger", "title": "The Pendant", "flag": CANON_HANGER_FLAG, "kind": "hanger"},
	{"id": "ww_sapientia", "title": "Sapientia", "flag": CANON_DREIGING_FLAG, "kind": "sapientia"},
]


static func ids() -> Array:
	return SCENES.map(func(s): return str(s["id"]))


static func scene(id: String) -> Dictionary:
	for s in SCENES:
		if str(s["id"]) == id:
			return s
	return {}


## Bron met eigen (lege) story_flags, zodat de Hanger-scène opnieuw speelt zonder het echte verhaal te raken.
class FlagBron extends Node:
	var story_flags := {}
