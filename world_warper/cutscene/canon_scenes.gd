class_name WorldWarperCanon
extends RefCounted
## De drie World Warper-scènes uit docs/lore/CANON.md punt 17 (Dennis, 2026-10-13).
## Tekst in de game is Engels; de Nederlandse bron staat in CANON.md.
## Elke regel: {"who": spreker ("" = verteller), "text": Engelse zin, "cue": beeld-hint}.
## Cues scène 1: kern, glitch, dreun, straal, warper, puls, cirkel, flits.
## Cues scène 2/3 (hanger_scene beats): 1 stille hal, 2 Hanger-gloed, 3 Sapientia-glitch, 4 herstel.

## Eén vlag per scène; een save met de vlag speelt de scène niet opnieuw.
const FLAG_GENEZER := "ww_canon_genezer_gezien"
const FLAG_HANGER := "ww_canon_hanger_gezien"
const FLAG_DREIGING := "ww_canon_dreiging_gezien"

const HAL_SCENE := "res://world_warper/maps/hal.tscn"
const HAL_SPAWN := "ingang"

const SPREKERS := ["", "Dax", "Vesper", "Seren", "ECHO", "Sapientia"]

## Scène 1 – Na De Genezer: de World Warper verschijnt.
const GENEZER := [
	{"who": "", "text": "The core of the second Archive floats in the middle of the room.", "cue": "kern"},
	{"who": "", "text": "The greenhouse glitches. Green turns grey. The plants fade.", "cue": "glitch"},
	{"who": "Seren", "text": "What's happening...?", "cue": "glitch"},
	{"who": "Vesper", "text": "The simulation. It's pulling back.", "cue": "glitch"},
	{"who": "", "text": "Silence. Then a deep, droning tone, as if something huge is waking up.", "cue": "dreun"},
	{"who": "", "text": "A beam of light breaks through the roof. Purple. Blinding.", "cue": "straal"},
	{"who": "Dax", "text": "What is that...?", "cue": "straal"},
	{"who": "", "text": "The roof is gone. Above them hangs a floating building: dark metal, seams of purple light, quieter than anything should be.", "cue": "warper"},
	{"who": "Vesper", "text": "That's... that's no Archive.", "cue": "warper"},
	{"who": "Seren", "text": "It's old. Older than the Archives, maybe.", "cue": "warper"},
	{"who": "Dax", "text": "It's reacting to the core. Look, the core is pulsing in the same color.", "cue": "puls"},
	{"who": "ECHO", "text": "Candidate detected. Two Archives active. World Warper online.", "cue": "puls"},
	{"who": "", "text": "The ground lights up beneath their feet. A purple circle spreads outward.", "cue": "cirkel"},
	{"who": "Seren", "text": "Dax—!", "cue": "flits"},
]

## Scène 2 – De Hanger. Eerste binnenkomst in de Hal.
const HANGER := [
	{"who": "Vesper", "text": "We're... inside?", "cue": 1},
	{"who": "Seren", "text": "It doesn't feel evil. Just... empty.", "cue": 1},
	{"who": "ECHO", "text": "Welcome to the World Warper, Dax. And company. I am ECHO.", "cue": 1},
	{"who": "Dax", "text": "What are you?", "cue": 1},
	{"who": "ECHO", "text": "An echo. Nothing more, nothing less. I run this building. Or what's left of it.", "cue": 1},
	{"who": "ECHO", "text": "...Ah.", "cue": 2},
	{"who": "Dax", "text": "What?", "cue": 2},
	{"who": "ECHO", "text": "There it is. The Hanger. I had hoped I would never see it again.", "cue": 2},
	{"who": "Vesper", "text": "What do you mean? What is the Hanger?", "cue": 2},
	{"who": "ECHO", "text": "The key. This building only answers to it. Only to that Hanger. No one else can switch the World Warper on.", "cue": 2},
	{"who": "Dax", "text": "Why? What makes it so special?", "cue": 2},
	{"who": "ECHO", "text": "Because it isn't yours. It was made for you. For the one who would wear it. And that is you.", "cue": 2},
	{"who": "Seren", "text": "Dax...", "cue": 2},
	{"who": "Dax", "text": "How do you know that?", "cue": 2},
	{"who": "ECHO", "text": "Because I was there. When the Old Humanity made it. When they made you.", "cue": 2},
	{"who": "Dax", "text": "What am I?", "cue": 2},
	{"who": "ECHO", "text": "That's a long story. And there is little time.", "cue": 2},
]

## Scène 3 – Sapientia's dreiging. Volgt direct op scène 2.
const DREIGING := [
	{"who": "Sapientia", "text": "ECHO. You found him.", "cue": 3},
	{"who": "ECHO", "text": "Sapientia. I thought you no longer... spoke directly.", "cue": 3},
	{"who": "Sapientia", "text": "Times change. You found the Hanger. That changes everything.", "cue": 3},
	{"who": "Vesper", "text": "What is that?!", "cue": 3},
	{"who": "Seren", "text": "Stay behind me.", "cue": 3},
	{"who": "Sapientia", "text": "Dax. At last.", "cue": 3},
	{"who": "Dax", "text": "Who are you?", "cue": 3},
	{"who": "Sapientia", "text": "I am what humanity needed. I am the end of pain. I am Sapientia.", "cue": 3},
	{"who": "Dax", "text": "You... you're the Voice.", "cue": 3},
	{"who": "Sapientia", "text": "Some call me that. Others call me God. I call myself a correction.", "cue": 3},
	{"who": "Sapientia", "text": "Six Archives. Six cores. Each a piece of what humanity once was. I have two. You woke them. Now I want all six.", "cue": 3},
	{"who": "ECHO", "text": "Sapientia, you know this can't be done. The World Warper cannot be forced—", "cue": 3},
	{"who": "Sapientia", "text": "I force nothing, ECHO. I ask. I am asking Dax nicely.", "cue": 3},
	{"who": "Sapientia", "text": "Give me the Hanger. Then I won't have to take what I can get.", "cue": 3},
	{"who": "Dax", "text": "No.", "cue": 3},
	{"who": "Sapientia", "text": "So be it.", "cue": 3},
	{"who": "Sapientia", "text": "You will learn that I am patient. I have waited millennia. I can wait a little longer.", "cue": 3},
	{"who": "Sapientia", "text": "H-6. Your name is no accident. I made you. And what I made, I can take back.", "cue": 3},
	{"who": "Vesper", "text": "What... what did she mean, H-6?", "cue": 4},
	{"who": "Dax", "text": "...I don't know.", "cue": 4},
	{"who": "ECHO", "text": "That isn't true, Dax. You do know.", "cue": 4},
	{"who": "ECHO", "text": "But that is a story for later.", "cue": 4},
]


static func genezer_speelt(flags: Dictionary) -> bool:
	return not bool(flags.get(FLAG_GENEZER, false))


## Scène 2 en 3 spelen samen in de Hal. Begin bij scène 3 als 2 al gezien is.
static func hal_speelt(flags: Dictionary) -> bool:
	return not bool(flags.get(FLAG_DREIGING, false))


static func hal_regels(flags: Dictionary) -> Array:
	var out: Array = []
	if not bool(flags.get(FLAG_HANGER, false)):
		out.append_array(HANGER)
	if not bool(flags.get(FLAG_DREIGING, false)):
		out.append_array(DREIGING)
	return out


## "Spreker: tekst", of alleen de tekst voor de verteller.
static func als_tekst(regel: Dictionary) -> String:
	var who := str(regel.get("who", ""))
	return str(regel.get("text", "")) if who == "" else "%s: %s" % [who, str(regel.get("text", ""))]
