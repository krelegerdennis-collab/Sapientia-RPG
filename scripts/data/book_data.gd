extends RefCounted
## v0.11 BOEKPUNTEN: gloeiende boeken op een lessenaar (scripts/book_point.gd, scenes/book_point.tscn).
## Eén object, het 'type' kiest de regel hieronder. Een nieuw soort boek = een nieuwe regel.
##   texture : 64x16 = 4 frames van 16x16 naast elkaar (RPG ART), speelt in een lus
##   aura    : kleur van de pulserende gloed (additief, in code gemaakt)
##   hp / mp : vult de HP / MP van de hele party helemaal aan
##   line    : tekst die je eerst ziet (leeg = geen)
##   save    : daarna de vraag 'Voortgang opslaan?' (Ja/Nee)
## save = in dorpen/huizen; hp en mp zijn bedoeld voor dungeons.

const TYPES := {
	"save": {
		"texture": "res://assets/sprites/save_book.png",
		"aura": Color("3ff0ff"),
		"hp": true, "mp": true,   # v0.12 (Dennis): opslagboek vult HP én MP
		"line": "Een warme gloed herstelt je krachten en je geest.",
		"save": true,
		"question": "Het boek gloeit zacht. Voortgang opslaan?",
	},
	# v0.14: opslagboek van de bibliotheek (Eerste Archief, 4C) = zelfde als "save", eigen plaatje
	# van RPG ART (staat op de runenring, zonder verschuiving)
	"save_bibliotheek": {
		"texture": "res://assets/sprites/savepunt_bibliotheek.png",
		"aura": Color("3ff0ff"),
		"hp": true, "mp": true,
		"line": "Een warme gloed herstelt je krachten en je geest.",
		"save": true,
		"question": "Het boek gloeit zacht. Voortgang opslaan?",
	},
	"mp": {
		"texture": "res://assets/sprites/mp_book.png",
		"aura": Color("3fff7a"),
		"hp": false, "mp": true,
		"line": "Je geest raakt helder. MP hersteld.",
		"save": false,
	},
	"hp": {
		"texture": "res://assets/sprites/hp_book.png",
		"aura": Color("ff3f4f"),
		"hp": true, "mp": false,
		"line": "Je wonden sluiten zich. HP hersteld.",
		"save": false,
	},
}
