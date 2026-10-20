extends RefCounted
## Puzzelkamers als DATA (zie docs/PUZZELS.md). Eén kamer = een ASCII-plattegrond + legenda.
##
## Vaste tekens (altijd hetzelfde, hoeven niet in "objects"):
##   '#' muur   (de bouwer kiest zelf de tegel: bovenrand/muurtop, muurvoorkant, zijmuur)
##   '.' vloer
##   'E' ingang (deur in de rand). Je verschijnt op de tegel ernaast (binnenkant) en kijkt
##       de kamer in. Erop stappen = terug naar "entrance" (map + spawn).
##   'X' uitgang (deur in de rand): naar "exit" (map + spawn) of alleen een bericht ("lines").
##   'B' vaste boekenkast (decor, massief, niet te duwen). De muur erboven wordt de bovenkant
##       van de kast, dus er moet een '#' boven staan.
##   '~' spleet: massief tot een groei-plaat (type grow, gap) volgroeid is. Binnen de kamer.
## Alle andere tekens staan in "objects": {teken: {type, id, ...}}, elk teken precies 1x:
##   block  duwbare boekenkast                       {"type": "block", "id": "kast_a"}
##   plate  drukplaat; "heavy": true = alleen een kast drukt hem in (de speler niet)
##   lever  hendel (A ervoor = om); "on": begintoestand (standaard false)
##   gate   poort; "needs": [ids van platen/hendels/poorten], "mode": "all" of "any",
##          "invert": true = open als de voorwaarde NIET klopt, "latch": true = blijft voor
##          altijd open zodra hij één keer open ging (ook na herstellen/terugkomen)
##   reset  herstelsteen (A ervoor = 'De kamer herstellen?')
## v0.15 (ARCHIEF1, zie HANDOFF_ARCHIEF1.md):
##   ','     verborgen vloer: de nis achter een geheime deur (ziet eruit als muur tot de deur open is)
##   book    los boek in een kast (A = terugduwen, eenmalig); geeft een signaal. Moet een '#'
##           boven zich hebben (het is een kast van 2 tiles hoog). "lines" / "pressed_lines" optioneel.
##   secret  geheime deur in de achterwand (ziet eruit als een kast met een kier). Als een poort:
##           "needs", "mode", "invert"; vergrendelt ALTIJD (blijft open). Boven en onder moet een
##           doorgang zijn (bv. ',' erboven, '.' eronder). "hint" (A op de dichte deur) en
##           "open_lines" (als hij opengaat) optioneel.
##   grow    groei-plaat {"needs": [ids], "stages": 2 of 3, "gap": true}. A = één stadium
##           (zaad, scheut, volgroeid). Needs eerst (bv. een hendel). Alleen het laatste
##           stadium opent de '~'-spleet en blijft open. "wait_lines" / "lines" /
##           "open_lines" / "done_lines" optioneel. "dungeon_set" op de kamer haalt hem
##           uit de glitch-graaf van een ander archief (standaard "archief").
##   chest   schatkist {"item": id uit ITEMS/EQUIPMENT, "n": aantal (standaard 1), "flag": story-vlag
##           (optioneel, standaard "kist:<id>" zoals de gewone dungeonkisten)}. Eenmalig per spel (de vlag gaat
##           mee in de save). "lines" / "empty_lines" optioneel.
## v0.15 (KERN, zie HANDOFF_KERN.md):
##   block  + "heavy": true = ZWARE kast: alleen te duwen met de wereldvaardigheid "zware_blokken"
##          (kernfragment Golemkern; ander vermogen: "ability": id). Zonder: hint ("hint" optioneel).
## Ids zijn uniek binnen een kamer; een signaal heet net als het object dat het geeft.
##
## v0.14 (Eerste Archief, puzzelkamer 3B):
##   hook   HAAKJE / PLACEHOLDER voor een component van RPG CODE (geheime deur, runeplaat,
##          schatkist). {"type": "hook", "hook": soort, "id", "solid": true/false, ...}. De rest
##          van de velden is al de data van zijn component; als die er is wordt de regel
##          "type": "hook" -> "type": "secret" / "plate" / "chest" (zie docs/HANDOFF_ARCHIEF1.md).
##          PuzzleLogic: massief als "solid", geen signaal; kasten kunnen er niet op als hij massief is.
##          PuzzleRoom: maakt het plaatsvervangende object uit PuzzleRoom.HOOK_SCRIPTS.
##   Kamer-velden: "style": "dungeon" = dungeontegels (scripts/data/dungeon_rooms.gd) i.p.v.
##          binnen.png; het beeld komt dan uit "look" (zelfde maat als "layout", tekens van
##          DungeonRooms.LEGEND, ' ' = leegte) en de botsing uit de layout. 'B' wordt dan de vaste
##          kast assets/puzzle/kast_vast.png. "spawns" {naam: [x, y, richting]} = extra spawnpunten.
##          "dek" {"rect": [x, y, b, h], "tiles": [[x, y, tegel], ...]} = afdekking (leegte + muur)
##          over een verborgen deel van de kamer tot PuzzleRoom.reveal_hidden_area() (de schatkamer).
##          E/X mogen ook binnenin de kaart staan (in een muur met precies 1 open buur).

const ROOMS := {
	# Testkamer voor De Vergeten Archieven (scène 3): alles samen in één kleine puzzel.
	# Oplossing: kast_b 2x omlaag op plaat q -> poort 2 gaat open -> door poort 2 naar hendel h
	# (A) -> terug -> kast_a 2x naar rechts en 3x omhoog op plaat p -> poort 1 gaat open en
	# blijft open (latch) -> naar de uitgang X.
	# Beide platen zijn ZWAAR: anders kon je met één kast en jezelf op een plaat de grendelpoort
	# openen (zie docs/PUZZELS.md, 'Waarom zwaar?').
	# v0.15 (RPG CODE) DEMO / TEST van de ZWARE KAST (kernfragment 'Zware blokken duwen'): niet in
	# de verhaalroute, alleen voor --kerntest (en F4-achtige debug). Oplossing: zware kast z 2x naar
	# rechts op de zware plaat p -> poort 1 open (blijft open) -> X. Zonder de Golemkern: hint.
	"kern_demo": {
		"name": "Core Room (demo heavy cabinet)",
		"layout": [
			"####X####",
			"####1####",
			"#.......#",
			"#..z.p..#",
			"#.......#",
			"#r......#",
			"####E####",
		],
		"objects": {
			"z": {"type": "block", "id": "kast_zwaar", "heavy": true},
			"p": {"type": "plate", "id": "plaat_p", "heavy": true},
			"1": {"type": "gate", "id": "poort_1", "needs": ["plaat_p"], "mode": "all", "latch": true},
			"r": {"type": "reset", "id": "herstelsteen"},
		},
		"entrance": {"map": "res://scenes/maps/huis_wilgendal.tscn", "spawn": "binnen"},
		"exit": {"lines": ["It's quiet behind the gate.", "(Demo: a real room can go here later.)"]},
	},
	"archief_test": {
		"name": "Forgotten Archives - Test Room",
		"layout": [
			"#######X######",
			"#######1######",
			"#BB......BB#h#",
			"#....p.....#.#",
			"#..........#2#",
			"#............#",
			"#..a......b..#",
			"#............#",
			"#.........q..#",
			"#r...........#",
			"####E#########",
		],
		"objects": {
			"a": {"type": "block", "id": "kast_a"},
			"b": {"type": "block", "id": "kast_b"},
			"p": {"type": "plate", "id": "plaat_p", "heavy": true},
			"q": {"type": "plate", "id": "plaat_q", "heavy": true},
			"h": {"type": "lever", "id": "hendel_h", "on": false},
			"1": {"type": "gate", "id": "poort_1", "needs": ["plaat_p", "plaat_q", "hendel_h"],
					"mode": "all", "latch": true},
			"2": {"type": "gate", "id": "poort_2", "needs": ["plaat_q"], "mode": "any"},
			"r": {"type": "reset", "id": "herstelsteen"},
		},
		"entrance": {"map": "res://scenes/maps/huis_wilgendal.tscn", "spawn": "binnen"},
		"exit": {"lines": ["Behind the gate lies a dark corridor full of dust and loose pages.",
				"(The rest of the Forgotten Archives comes later.)"]},
	},
	# v0.14 PUZZELKAMER 3B van het Eerste Archief (plan: story/ARCHIEF1_PLATTEGROND.md par. 4.1),
	# dungeontegels. De onderste 13 rijen = de puzzelkamer (de testkamer, 4 breder en 1 hoger);
	# daarboven, op DEZELFDE map, de geheime SCHATKAMER achter de geheime deur G (16,8) in de
	# achterwand: beide deurtegels (16,7) en (16,8) zijn beloopbaar als de deur open is, en (16,6)
	# is de doorgang in de onderrand van de schatkamer.
	# Oplossing hoofdpuzzel (zoals de testkamer): kast b 2x omlaag op q -> poort 2 open -> hendel
	# h -> kast a 2x rechts en 3x omhoog op p -> poort 1 open (latch) -> X (8,7) naar 3C.
	# Geheime deur (pas na poort 1): kast c 1x rechts, 6x omhoog op de runeplaat s (15,9).
	# v0.15: G, s en T zijn de echte componenten van RPG CODE (geheime deur, runeplaat, schatkist
	# met het Vonkzwaard); de schatkamer wordt zichtbaar via reveal_hidden_area() ("dek").
	"archief_puzzel": {
		"name": "Forgotten Archives - Puzzle Room",
		"style": "dungeon",
		"layout": [
			"##################",
			"##################",
			"##################",
			"##########...T...#",
			"##########.......#",
			"##########.......#",
			"################.#",
			"########X#######.#",
			"########1#######G#",
			"#BB.......BB#h#s.#",
			"#.....p.....#.#..#",
			"#...........#2#..#",
			"#................#",
			"#...a......b.....#",
			"#................#",
			"#..........q..c..#",
			"#r...............#",
			"#................#",
			"#####E############",
		],
		"look": [
			"         a-------b",
			"         <LFFFFFR>",
			"         <lfffffr>",
			"         <Zsususs>",
			"         <S......>",
			"         <S...*..>",
			"a--------c_____(U)",
			"<LFFMFFFAFFFGFFFR>",
			"<lffmfffnfffgfffr>",
			"<Zssssssssss5s5us>",
			"<S..........F.F..>",
			"<S..........f.f..>",
			"<S.........w.....>",
			"<S...............>",
			"<S......p........>",
			"<S...............>",
			"<S...........x...>",
			"<S...............>",
			"c___(U)__________d",
		],
		"objects": {
			"a": {"type": "block", "id": "kast_a"},
			"b": {"type": "block", "id": "kast_b"},
			"c": {"type": "block", "id": "kast_c"},
			"p": {"type": "plate", "id": "plaat_p", "heavy": true},
			"q": {"type": "plate", "id": "plaat_q", "heavy": true},
			"h": {"type": "lever", "id": "hendel_h", "on": false},
			"1": {"type": "gate", "id": "poort_1", "needs": ["plaat_p", "plaat_q", "hendel_h"],
					"mode": "all", "latch": true},
			"2": {"type": "gate", "id": "poort_2", "needs": ["plaat_q"], "mode": "any"},
			"r": {"type": "reset", "id": "herstelsteen"},
			# ---- v0.15 RPG CODE: de haakjes van Forge zijn nu echte componenten (type secret/plate/chest;
			# "hook"/"solid" blijven staan als documentatie). Zie HANDOFF_ARCHIEF1.md. ----
			# geheime deur in de achterwand (16x32: deze tile + de tile erboven); placeholder = dicht
			"G": {"type": "secret", "hook": "geheime_deur", "id": "geheime_deur", "solid": true,
					"needs": ["plaat_s", "poort_1"], "mode": "all", "latch": true, "style": "geheim",
					"hint": ["A thin pink crack sits in the wall...", "Something drafts behind the stones."],
					"open_lines": ["A heavy scrape sounds behind the wall..."]},
			# verborgen zware drukplaat (ziet eruit als runentegel 11); placeholder = alleen het plaatje
			"s": {"type": "plate", "hook": "runeplaat", "id": "plaat_s", "solid": false, "heavy": true, "hidden": true},
			# schatkist met het Vonkzwaard (eenmalig); placeholder = dichte kist, massief
			"T": {"type": "chest", "hook": "schatkist", "id": "kist_vonkzwaard", "solid": true,
					"item": "vonkzwaard", "n": 1, "flag": "kist_vonkzwaard",
					"lines": ["{naam} opens the chest...", "{naam} finds the Spark Sword!",
							"ATK +12. Equip: Menu > Equipment > Weapon."]},
		},
		"spawns": {"uit_x": [8, 9, "down"]},
		"dek": {"rect": [9, 0, 9, 6], "tiles": [[9, 6, 23], [10, 6, 23], [11, 6, 23], [12, 6, 23], [13, 6, 23],
				[14, 6, 23], [15, 6, 23], [16, 6, 23], [17, 6, 27]]},
		"entrance": {"map": "res://scenes/maps/archief_v3_zuilenhal.tscn", "spawn": "boog"},
		"exit": {"map": "res://scenes/maps/archief_v3_gang.tscn", "spawn": "zuid"},
	},
	# Verdieping 1, Het Levende Archief. Tutorial: hendel, daarna de plaat drie stadia.
	# De spleet is de volle breedte, dus er is geen omweg. TODO(design): verdieping 2-4 niet hier.
	"leven_v1_plaat": {
		"name": "The Living Archive - Growth Plate",
		"style": "dungeon",
		"theme": "kas",
		"dungeon_set": "leven",
		"legend": {"V": 13},
		"layout": [
			"##########X##########",
			"#...................#",
			"#~~~~~~~~~~~~~~~~~~~#",
			"#.........g.........#",
			"#.....h.............#",
			"#...................#",
			"#...................#",
			"#...................#",
			"#...................#",
			"#...................#",
			"#...................#",
			"#...................#",
			"#...................#",
			"#...................#",
			"##########E##########",
		],
		"look": [
			"a---------n---------b",
			"<S..................>",
			"<VVVVVVVVVVVVVVVVVVV>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"<S..................>",
			"c________(E)________d",
		],
		"objects": {
			"h": {"type": "lever", "id": "hendel_kas", "on": false},
			"g": {"type": "grow", "id": "groei_brug", "needs": ["hendel_kas"], "stages": 3, "gap": true,
					"wait_lines": ["The plate does nothing.", "The lever first."],
					"lines": ["The plate grows."],
					"open_lines": ["The vines close into a path."],
					"done_lines": ["The path is already there."]},
		},
		"entrance": {"map": "res://scenes/maps/leven_ingang.tscn", "spawn": "boog"},
		"spawns": {"noord": [10, 1, "down"]},
		"exit": {"map": "res://scenes/maps/archief_2_v2_gang.tscn", "spawn": "zuid"},
	},
	# Verdieping 3. Kast uit Archief 1, hendel, en pas dan de groei-plaat.
	# Heenweg vanaf de ketting-platen. Terug vanaf de tegen-platen slaat deze kamer over.
	"leven_v3_combi": {
		"name": "Cabinet and Lever",
		"style": "dungeon",
		"theme": "kas",
		"dungeon_set": "leven",
		"legend": {"V": 13},
		"layout": [
			"#######X#######",
			"#.............#",
			"#~~~~~~~~~~~~~#",
			"#......g......#",
			"#.............#",
			"#...h..a.p....#",
			"#.............#",
			"#.............#",
			"#.............#",
			"#.............#",
			"#######E#######",
		],
		"look": [
			"a------n------b",
			"<S............>",
			"<VVVVVVVVVVVVV>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"c_____(E)_____d",
		],
		"objects": {
			"h": {"type": "lever", "id": "hendel_combi", "on": false},
			"a": {"type": "block", "id": "kast_combi"},
			"p": {"type": "plate", "id": "plaat_kast", "heavy": true},
			"g": {"type": "grow", "id": "groei_combi", "needs": ["hendel_combi", "plaat_kast"], "stages": 3, "gap": true,
					"wait_lines": ["The plate does nothing.", "Pull the lever and push the cabinet onto the plate."],
					"lines": ["The plate grows."],
					"open_lines": ["The vines close into a path."],
					"done_lines": ["The path is already there."]},
		},
		"entrance": {"map": "res://scenes/maps/archief_2_v3_ketting.tscn", "spawn": "noord"},
		"exit": {"map": "res://scenes/maps/archief_2_v3_tegen.tscn", "spawn": "zuid"},
	},
}
