extends RefCounted
## v0.11 VERHAAL: de proloog "De Wacht van de Wachter" (docs: story/PROLOOG.md, scène 1 en 2).
## v0.16 (wens Dennis): tutorial korter: de 3 zegels/runen bij de bosrand zijn weg (objecten, events,
## tekst, tests); nieuw: Opa geeft een Leerling-mantel en je kunt pas verder als hij AAN is
## (MENU > Uitrusting; stap UITRUSTING, MENU_CLOSED hieronder).
## Update 5: intro sneller. De wakker-cutscene (het enige verplichte event vóór het
## eerste vrije moment) is weg. Ochtenddialoog korter. Vroege toon-keuze (intro_keuze)
## met hetzelfde vervolg. TODO(verhaal) staat bij ingekorte tekst en bij die keuze.
## Alles wat er in het verhaal gebeurt staat HIER als data; scripts/story.gd voert het uit.
##
## Voortgang = GameState.story_step (getal) + GameState.story_flags (namen). Beide gaan mee
## in de save. Een nieuwe scène toevoegen = nieuwe STEP, events en triggers hieronder.
##
## EVENT = lijst van varianten {"if": voorwaarde, "do": [commando's]}. De EERSTE variant
## waarvan de voorwaarde klopt wordt uitgevoerd. "do": "default" = doe wat het object
## normaal doet (bv. een uitgang: gewoon naar de andere map).
## Een object (NPC, deur, uitgang, StoryObject) roept zijn event aan met 'event' en
## optioneel 'event_arg' ({arg} in tekst/flags wordt daardoor vervangen, bv. kist_{arg}).
##
## VOORWAARDE (alles moet kloppen; {} = altijd):
##   "step": n  "step_lt": n  "step_ge": n  "flags": [..] (allemaal gezet)
##   "not_flags": [..] (minstens één NIET gezet)
##   "item": id  "not_item": id
##   "equipped": id  "not_equipped": id   (v0.16: de hoofdheld draagt dit stuk wel/niet)
##   "unique_open": id   (uniek monster nog niet verslagen of gevangen)
##   "codex_room": true  (de Codex heeft nog een vrije pagina)
##
## COMMANDO'S (["naam", argumenten...]):
##   ["say", spreker, [regels]]          tekstvak ({naam} = spelernaam), wacht tot dicht
##   ["choice", vraag, [opties], [event per optie], spreker]   kies en spring naar dat event
##   ["walk", wie, richting, tiles]      wie = "player" of een node onder Objects
##   ["face", wie, richting]             ["place", wie, [x, y], richting]
##   ["show", wie] / ["hide", wie]       ["frame", wie, n] (frame van een StoryObject)
##   ["shake", sec, sterkte]             scherm schudt (wacht niet)
##   ["flash", "#kleur", sec]            witte (of gekleurde) flits (wacht)
##   ["window_glow", sec]                magisch licht door de ramen (wacht niet)
##   ["fade_out", sec] / ["fade_in", sec]  ["tint", "day"|"evening"|"night", sec]
##   ["wait", sec]                       ["after", sec, event]  (later, als de speler vrij is)
##   ["lock", naam] / ["unlock", naam]   deur/uitgang op slot (= flag "locked:naam")
##   ["flag", naam] / ["unflag", naam]   ["step", n]
##   ["give", item, n] / ["take", item, n] / ["weapon", id]
##   ["if", voorwaarde, [dan], [anders]] ["jump", event] (stopt hier) / ["run", event]
##   ["refresh"]                         objecten opnieuw tonen/verbergen volgens hun show_if
##   ["battle", [vijanden], {"tutorial": true, "enemy_hp": n, "after": event}]
##   ["map", "huis"|"buiten"|pad, spawn, after_event]  (v0.13: ook een volledig pad, bv. ARCHIEF)
##   ["card", tekst, sec]                groot zwart scherm met tekst ("Wordt vervolgd")
##   v0.17:
##   ["join", held, {"level": n | "level_from": held, "level_delta": d, "gear": [stukken]}]
##                                       held sluit zich aan (GameState.join_member), bv. Noor
##   ["glitch", sec]                     één glitch-flits van de CRT-laag (ook buiten de dungeons)
##   ["heal"]                            HP en MP van de hele groep vol (herberg)
##   ["molen_zang"]                      scène: de molen draait en zingt zacht (geen extra dialoog)
##   ["molen"]                           molen van Gerrit: rusten, meel (1x per bezoek), opslaan, party wisselen
##   ["zang"]                            scène: de molen draait, zacht gezang (eenmalig, bij het zaad)
##   Spreker "{naam}" = de held zelf (ballon wijst naar de speler).
##   MAP_ENTER "map" mag ook een volledig scènepad zijn (Esdoorn, Donker Woud).

const HOUSE := "res://scenes/maps/huis_wilgendal.tscn"
const OUTSIDE := "res://scenes/maps/wilgendal.tscn"
## v0.13: eerste kamer van De Vergeten Archieven (dungeon, scripts/data/dungeon_rooms.gd)
const ARCHIEF := "res://scenes/maps/archief_ingang.tscn"
const MAPS := {"huis": HOUSE, "buiten": OUTSIDE}
## v0.17 Esdoorn (het dorp van Noor) en het Donker Woud
const ESDOORN := "res://scenes/maps/esdoorn.tscn"
const ESDOORN_NOOR_HUIS := "res://scenes/maps/esdoorn_huis_noor.tscn"
const ESDOORN_HERBERG := "res://scenes/maps/esdoorn_herberg.tscn"
const WOUD_INGANG := "res://scenes/maps/woud_rand.tscn"
const WOUD_BAAS := "res://scenes/maps/woud_open_plek.tscn"
## Vlag van de verslagen Golem (DungeonRoom.guard_flag): pas daarna is Esdoorn open.
const GOLEM_FLAG := "bewaker:archief_golemhal/golem"
## Vlag van de verslagen Wortelkoning.
const WORTELKONING_FLAG := "bewaker:woud_open_plek/baas"
## Het Zingende Graan (na noor_lid). Dialoog is de canon, letterlijk.
const GERRIT := "Garrett the Miller"
const FLAG_GRAAN := "quest_zingend_graan"
const FLAG_ZAAD := "zingend_zaad"
const FLAG_GRAAN_KLAAR := "zingend_graan_klaar"
const ITEM_ZAAD := "zingend_zaad"
const ITEM_MEEL := "zingend_meel"
const QUOTE_GRAAN_BEZOEK := "Oh, a visitor. Sit down, lad. Or stay standing — doesn't matter. The mill doesn't turn anymore anyway."
const QUOTE_GRAAN_WIND := "It used to sing. When I ground grain, it sang. Now I only hear the wind. And the wind doesn't sing, it whispers."
const QUOTE_GRAAN_VRAAG := "What happened?"
const QUOTE_GRAAN_OP := "The grain is gone. Not the ordinary grain — I still have that. The SINGING grain. It only grows where light and shadow touch. In the Dark Wood, at the edge of the mist."
const QUOTE_GRAAN_OUD := "I'm too old to go. My legs won't carry me anymore. But you... you look like someone who still goes places."
const QUOTE_GRAAN_ZOEK := "Find the Singing Seed. It grows where the mist lifts and the first sun breaks through. Bring it back, and my mill will sing again."
const QUOTE_GRAAN_VOORZICHTIG := "And lad — be careful. The forest doesn't like haste."
const QUOTE_GRAAN_WACHT := "No hurry. The mill will wait. So will I."
const QUOTE_GRAAN_ZONDER := "Not found yet? No worries. The forest can't be forced."
const QUOTE_GRAAN_ZAAD := "Let me see it. ...Yes. Yes, this is it. It's already singing, hear that? Softly. It's waiting for the mill."
const QUOTE_GRAAN_DANK := "Thank you, lad. The mill sings again. Take some flour for the road — and if you ever come back, the door is always open."
## Ja neemt de opdracht aan. Nee (ook de B-knop) is weglopen: de opdracht blijft uit.
const KEUZE_GRAAN_JA := "Yes"
const KEUZE_GRAAN_NEE := "No"
## Zangscène, meteen na QUOTE_GRAAN_ZAAD. Geen nieuwe zin: de wieken gaan draaien en er klinkt zacht gezang.
const MOLEN_NODE := "MolenWieken"
const MOLEN_ZANG_SEC := 2.4
const MOLEN_ZANG := [
	{"hz": 262.0, "t": 0.0, "d": 0.42},
	{"hz": 330.0, "t": 0.48, "d": 0.42},
	{"hz": 392.0, "t": 0.96, "d": 0.5},
	{"hz": 330.0, "t": 1.52, "d": 0.4},
	{"hz": 262.0, "t": 1.98, "d": 0.42},
]

## Stappen van de proloog
const START := 0          # nieuw spel: wakker worden in bed
const WAKKER := 10        # oude saves: wakker, Opa buiten. Update 5 zet deze stap niet meer.
const UITRUSTING := 15    # v0.16: mantel van Opa gekregen; verder pas als hij AAN is (MENU > Uitrusting)
const TAKEN := 20         # opdracht gekregen: water en kist (v0.16: de 3 zegels/runen zijn weg)
const LES := 30           # alle taken klaar: zwaardles + oefengevecht
const AVOND := 40         # scène 2: avond, lezen, de flits (alleen tijdens de cutscene)
const OPGESLOTEN := 50    # Opa is weg, de deur zit op slot
const NACHT := 60         # Opa achterna: deur open, nacht, Archieven open
                          # v0.13: vanaf hier zijn de Archieven (eerste dungeonkamer) EN de
                          # wereldkaart open, zodat je op de telefoon verder kunt spelen
const KLAAR := 100        # proloog voorbij (scène 3/4 komen later)
## v0.17 Esdoorn + Donker Woud (na de Golem; de stap is informatief, de poorten werken met vlaggen)
const NOOR_KWIJT := 110   # Noor ontmoet en door het woud meegenomen: opdracht 'Red Noor' loopt
const NOOR_GERED := 120   # Wortelkoning verslagen, Noor zit in de groep

## Namen van de stappen (debug / autotest / field menu)
const STEP_NAMES := {0: "start", 10: "wakker", 15: "uitrusting", 20: "taken", 30: "les", 40: "avond",
	50: "opgesloten", 60: "nacht", 100: "klaar", 110: "noor_kwijt", 120: "noor_gered"}

## v0.17 OPDRACHTEN (veldmenu: regel 'Opdracht' onder de groep zolang start_flag wel en done_flag niet
## gezet is). Story.active_quest() geeft de titel.
const QUESTS := [
	{"id": "noor", "title": "Save Vesper from the Dark Wood", "start_flag": "quest_noor", "done_flag": "noor_gered"},
	{"id": "zingend_graan", "title": "The Singing Grain", "start_flag": FLAG_GRAAN, "done_flag": FLAG_GRAAN_KLAAR},
]
## v0.17 TODO(verhaal): deze events hebben PLACEHOLDER-tekst (kort, Nederlands). Dennis schrijft het
## echte verhaal; de opbouw (wie loopt waar, vlaggen, ballonnen) kan blijven.
const TODO_STORY := ["noor_ontmoeting", "noor_bevrijd", "noor_woud", "marit", "bram", "jens", "tobias",
	"ilse", "herbergier", "naar_esdoorn", "woud_ingang", "marit_boeken", "naar_leven"]

const SPEAKER := "Old Man"

## Kleur van het licht per stap (CanvasModulate op de proloog-maps).
const TINTS := {
	"day": Color(1, 1, 1),
	"evening": Color(0.62, 0.52, 0.66),
	"night": Color(0.30, 0.34, 0.56),
}
const TINT_RULES := [
	{"if": {"step_ge": AVOND, "step_lt": NACHT}, "tint": "evening"},
	{"if": {"step_ge": NACHT, "step_lt": KLAAR}, "tint": "night"},
]

## Wat er gebeurt als je een map binnenkomt (in volgorde; alle passende worden gedaan).
const MAP_ENTER := [
	{"map": "huis", "if": {"step": AVOND}, "event": "catastrofe"},
	{"map": "huis", "if": {"step": OPGESLOTEN}, "event": "opgesloten_timer"},
	# v0.17 eerste keer in Esdoorn (na de Golem): Noor ontmoeten, ze wordt het woud in gesleurd
	{"map": ESDOORN, "if": {"flags": [GOLEM_FLAG], "not_flags": ["noor_ontmoet"]}, "event": "noor_ontmoeting"},
	{"map": "res://scenes/maps/leven_ingang.tscn", "if": {"not_flags": ["archief2_keten"]}, "event": "archief2_keten"},
	# v0.17 terug op de open plek na de winst op de Wortelkoning: Noor is vrij en sluit zich aan
	{"map": WOUD_BAAS, "if": {"flags": [WORTELKONING_FLAG], "not_flags": ["noor_gered"]}, "event": "noor_bevrijd"},
]

## Taken van scène 1 (v0.16 korter: de 3 zegels/runen aanraken is helemaal weg, wens Dennis)
const TASK_FLAGS := ["water_klaar", "kist_open"]
## v0.16 Uitrusting-tutorial: dit stuk geeft Opa, en pas als de hoofdheld het draagt gaat het verder.
const TUTORIAL_ARMOR := "leerling_mantel"

## v0.16 Na het sluiten van het veldmenu (map.gd): eerste passende regel loopt (de 'gedwongen'
## uitrusting-check van de tutorial: mantel aan -> Opa gaat verder).
const MENU_CLOSED := [
	{"if": {"step": UITRUSTING, "equipped": TUTORIAL_ARMOR}, "event": "mantel_aan"},
]

## Tutorial na de eerste overwinning op de Inktwurm: Classic/Action-schakelaar en de Quest Log.
## Vlagnaam NIET wijzigen: RPG CODE hangt hier later de vang-tutorial aan.
const TUTORIAL_INKTWURM := "tutorial_na_inktwurm"
const TUTORIAL_INKTWURM_FLAG := "tutorial_na_inktwurm_gezien"
const TUT_NEXT := "Next"
const TUT_SKIP := "Skip"
## Max. 2 korte regels per pagina (384x216); rechtsonder staan Next/Skip, dus de regels kort houden.
const TUT_INKT_PAGES := [
	"The Ink Worm is dealt with!\nTwo quick tips before you go on.",
	"MENU > Settings > Battle Style:\nClassic is turn-based, Action is real time.",
	"The switch works at once, even mid-room.\nBosses always stay turn-based.",
	"MENU > Quest Log lists your quests and steps.\nLost? Check the Active tab.",
]
## Uniek monster weg (GameState.unique_mark: verslagen of gevangen) -> dit event, één keer.
## Story speelt het zodra de speler weer vrij is (Classic: terug op de kaart, Action: in de kamer).
const AFTER_UNIQUE := {"inktwurm": TUTORIAL_INKTWURM}
## Oude saves waarin dit unieke monster al weg is: de vlag meteen als 'gezien' zetten (GameState.apply_state).
const UNIQUE_SEEN_FLAGS := {"inktwurm": TUTORIAL_INKTWURM_FLAG}

## Vang-tutorial (Codex), direct na de Inktwurm-tutorial. Speelt eenmalig zodra de speler in de Golemhal
## vrij is (FREE_EVENTS), ook als de eerste tutorial overgeslagen is. Max. 2 korte regels per pagina.
const TUTORIAL_CODEX := "tutorial_codex_vangen"
const TUTORIAL_CODEX_FLAG := "tutorial_codex_vangen_gezien"
const TUT_CODEX_PAGES := [
	"Blank Books can catch monsters.\nA caught monster joins your Codex.",
	"Classic: in battle pick Codex > Capture,\nthen choose the target.",
	"Action: tap the Codex button or use the Ring.\nThe same rules as in Classic apply.",
	"Bosses can't be caught. A hurt monster\nis easier to catch.",
]
## De Inktwurm moet in de Codex staan (gevangen) voordat de Golemhal weer open gaat. De vlag blijft staan,
## ook als de pagina later wordt gefuseerd (GameState.codex_add / _codex_inktwurm_sync).
const CODEX_INKTWURM_FLAG := "inktwurm_in_codex"
## Soort (CodexData) -> vlag die GameState.codex_add zet zodra die soort in de Codex komt.
const CODEX_SPECIES_FLAGS := {"inktwurm": CODEX_INKTWURM_FLAG}
const GOLEMHAL := "res://scenes/maps/archief_golemhal.tscn"
const GOLEMHAL_EXIT := "golemhal_uitgang"
## Events die starten zodra de speler op die kaart vrij is (Story._free_event), zonder opslag: de vlaggen
## bepalen alles. Rij: {"map": scènepad, "if": voorwaarde, "event": id}.
const FREE_EVENTS := [
	{"map": GOLEMHAL, "if": {"flags": [TUTORIAL_INKTWURM_FLAG], "not_flags": [TUTORIAL_CODEX_FLAG]},
		"event": TUTORIAL_CODEX},
]

const EVENTS := {
	# ------------------------------------------------------------ scène 1: ochtend
	# Update 5: geen wakker-cutscene. Spawn "bed" staat op (2,3), naast het bedmeubel
	# (de bed-tile zelf blokkeert lopen). De speler is daar meteen vrij.
	# TODO(verhaal): ochtendtekst ingekort. Canon-beats blijven: naam, Wachtershuis, Opa,
	# en dat de Archieven dicht blijven tot het zegel breekt (dat laatste staat nog in scène 2).
	"opa": [
		# v0.16 uitrusting-tutorial, Update 5: eerst een toon-keuze, daarna de mantel
		{"if": {"step_lt": UITRUSTING}, "do": [
			["jump", "intro_keuze"],
		]},
		{"if": {"step": UITRUSTING, "equipped": TUTORIAL_ARMOR}, "do": [["jump", "mantel_aan"]]},
		# mantel weggegooid? Dan krijg je een nieuwe (anders zit je vast)
		{"if": {"step": UITRUSTING, "not_item": TUTORIAL_ARMOR}, "do": [
			["give", TUTORIAL_ARMOR, 1],
			["say", SPEAKER, ["Lost your cloak? Here, a new one. MENU > Equipment > Armor."]],
			["face", "OudeMan", "up"],
		]},
		{"if": {"step": UITRUSTING}, "do": [
			["say", SPEAKER, ["Put that cloak on first, {naam}. MENU > Equipment > Armor."]],
			["face", "OudeMan", "up"],
		]},
		{"if": {"item": "emmer_water"}, "do": [
			["take", "emmer_water", 1],
			["say", SPEAKER, ["Thank you, {naam}. Set it down here."]],
			["flag", "water_klaar"],
			["if", {"flags": TASK_FLAGS}, [["step", LES], ["jump", "les"]], [["face", "OudeMan", "up"]]],
		]},
		{"if": {"step": TAKEN}, "do": [
			["if", {"not_flags": ["water_klaar"]}, [["say", SPEAKER, ["The water, {naam}. The well is left of the house."]]]],
			["if", {"not_flags": ["kist_open"]}, [["say", SPEAKER, ["Herbs are in the chest beside the house. Take them."]]]],
			["face", "OudeMan", "up"],
		]},
		{"if": {"step": LES}, "do": [["jump", "les"]]},
		{"do": [["say", SPEAKER, ["..."]]]},
	],

	# TODO(verhaal): vroege keuze. Elke optie zet alleen een toon-vlag en springt naar
	# opa_mantel (zelfde vervolg). Een echte vertakking zou de canon wijzigen.
	# Het event "keuze" (Blijven / Opa achterna) blijft de nacht-beat; dat hergebruiken
	# we hier niet, want dat is een lus tot je Opa achterna gaat.
	"intro_keuze": [{"do": [
		["choice", "What do you say, {naam}?", ["Good morning, Grandpa.", "Why do the Archives stay closed?"], ["intro_toon_groet", "intro_toon_archief"], SPEAKER],
	]}],
	"intro_toon_groet": [{"do": [
		["flag", "toon_groet"],
		["jump", "opa_mantel"],
	]}],
	"intro_toon_archief": [{"do": [
		["flag", "toon_archief"],
		["jump", "opa_mantel"],
	]}],

	# TODO(verhaal): groet en menu in twee korte vakken (passen in de lage ballon).
	# De herhaalde tutorialregel is weg.
	"opa_mantel": [{"do": [
		["say", SPEAKER, ["Good morning, {naam}. It's cold in the Warden's House."]],
		["say", SPEAKER, ["Put on this cloak: MENU > Equipment > Armor."]],
		["give", TUTORIAL_ARMOR, 1],
		["say", "", ["{naam} receives an Apprentice Cloak! Then close the menu."]],
		["step", UITRUSTING],
		["face", "OudeMan", "up"],
	]}],

	# v0.16: de mantel is aan (na het sluiten van het menu, of als je Opa weer aanspreekt).
	# TODO(verhaal): de taken niet twee keer uitleggen.
	"mantel_aan": [{"do": [
		["say", SPEAKER, ["That suits you, {naam}. Fetch water from the well and herbs from the chest beside the house. Today feels different."]],
		["step", TAKEN],
		["face", "OudeMan", "up"],
	]}],

	"taken_check": [
		{"if": {"step": TAKEN, "flags": TASK_FLAGS}, "do": [
			["step", LES],
			["say", "", ["(All the chores are done. Go back to Grandpa.)"]],
		]},
		{"do": []},
	],

	"les": [{"do": [
		["say", SPEAKER, ["Good. All done.", "Sometimes you have to defend yourself, boy, even if I hope you never need to."]],
		["weapon", "kort_zwaard"],
		["say", "", ["{naam} receives a Short Sword!"]],
		["say", SPEAKER, ["Look, there in the grass. A Moss Slime. Show me what you can do."]],
		["battle", ["mosslijm"], {"tutorial": true, "enemy_hp": 30, "after": "na_les"}],
	]}],

	"na_les": [{"do": [
		["face", "OudeMan", "down"],
		["say", SPEAKER, ["Not bad, {naam}. Not bad.", "Come on, the sun is already setting. Inside."]],
		["step", AVOND],
		["map", "huis", "lezen", ""],
	]}],

	"put": [
		{"if": {"step": UITRUSTING}, "do": [["say", "", ["Grandpa is waiting. Put on the cloak first: MENU > Equipment."]]]},
		{"if": {"item": "emmer_water"}, "do": [["say", "", ["The bucket is already full. Take it to Grandpa."]]]},
		{"if": {"step": TAKEN, "not_flags": ["water_klaar"]}, "do": [
			["say", "", ["{naam} lowers the bucket into the well...", "{naam} got a bucket of water!"]],
			["give", "emmer_water", 1],
		]},
		{"do": [["say", "", ["An old stone well. The water is cold and clear."]]]},
	],

	# v0.13: ruïne-stukken rond de ingang van de Archieven (RPG ART, tools/build_maps.gd RUIN_PIECES)
	"ruine": [{"do": [["say", "", ["Broken pieces of old walls. There used to be more here than just an entrance."]]]}],

	"kist": [
		{"if": {"flags": ["kist_open"]}, "do": [["say", "", ["The chest is empty."]]]},
		{"if": {"step": UITRUSTING}, "do": [["say", "", ["Put on Grandpa's cloak first: MENU > Equipment."]]]},
		{"do": [
			["flag", "kist_open"],
			["refresh"],
			["give", "kruid", 3],
			["say", "", ["{naam} opens the chest.", "{naam} receives 3x Healing Herb!"]],
			["run", "taken_check"],
		]},
	],

	"schilderij": [
		{"if": {"flags": ["schilderij_weg"]}, "do": [["say", "", ["The painting hangs crooked. Behind it is an empty hook... Grandpa's sword used to hang here."]]]},
		{"do": [["say", "", ["An old painting of the woods. Grandpa looks at it often, when he thinks no one sees."]]]},
	],

	"pad_wereld": [
		{"if": {"step_lt": AVOND}, "do": [
			["say", SPEAKER, ["Where are you going? Not today, {naam}. Stay near the house."]],
			["walk", "player", "up", 1],
		]},
		{"if": {"step_lt": NACHT}, "do": [
			["say", "", ["The path into the valley is dark... No. Find Grandpa first!"]],
			["walk", "player", "up", 1],
		]},
		# v0.13: na de proloog-scènes is het pad open (wereldkaart; daar is ook een ingang
		# van de Archieven, de trap)
		{"do": "default"},
	],

	"archief_ingang": [
		{"if": {"step_lt": NACHT}, "do": [
			["say", "", ["Thick vines and heavy stones block an old entrance.", "Grandpa always says: 'You never go in there.'"]],
		]},
		# v0.13: de eerste keer (scène 3 begint): tekst, daarna de eerste dungeonkamer in
		{"if": {"not_flags": ["archief_gezien"]}, "do": [["jump", "archief_binnen"]]},
		{"do": [
			["say", "", ["The entrance of the Forgotten Archives. Pink light flickers in the deep."]],
			["map", ARCHIEF, "ingang", ""],
		]},
	],

	"archief_binnen": [{"do": [
		["say", "", ["The vines are torn. Pink light flickers deep in the corridors.", "Somewhere far off, Grandpa's voice echoes...", "{naam} takes a deep breath and steps inside."]],
		["flag", "archief_gezien"],
		["map", ARCHIEF, "ingang", ""],
	]}],

	# ------------------------------------------------------------ scène 2: de catastrofe
	"catastrofe": [{"do": [
		["say", "", ["It's evening. {naam} is reading one of Grandpa's old books.", "\"...and the Wardens sealed the Archives, so that no one would ever wake again...\""]],
		["shake", 2.2, 4.0],
		["flash", "#ffffff", 0.7],
		["window_glow", 5.0],
		["face", "player", "up"],
		["say", "", ["The ground shakes! A deafening bang, and a blinding flash from the direction of the Archives.", "Pink and blue light pours through the windows."]],
		["face", "OudeMan", "up"],
		["face", "OudeMan", "down"],
		["say", SPEAKER, ["No... the seal! It's too soon! {naam}, stay here! Lock the doors behind me and don't follow, no matter what you hear!"]],
		["walk", "OudeMan", "up", 1],
		["walk", "OudeMan", "left", 3],
		["face", "OudeMan", "up"],
		["flag", "schilderij_weg"],
		["refresh"],
		["say", "", ["Grandpa pulls an old, rusted sword out from behind the painting!"]],
		["walk", "OudeMan", "down", 5],
		["walk", "OudeMan", "left", 2],
		["walk", "OudeMan", "down", 1],
		["hide", "OudeMan"],
		["lock", "HuisDeur"],
		["say", "", ["The door slams shut. A key turns in the lock."]],
		["step", OPGESLOTEN],
		["refresh"],
		["after", 2.0, "schreeuw"],
	]}],

	"opgesloten_timer": [{"do": [["after", 2.0, "schreeuw"]]}],

	"huis_uit": [
		{"if": {"flags": ["locked:HuisDeur"]}, "do": [
			["say", "", ["The door is locked. Grandpa said I had to stay here."]],
			["walk", "player", "up", 1],
		]},
		{"do": "default"},
	],

	"schreeuw": [{"do": [
		["shake", 1.6, 3.0],
		["say", "", ["The earth shakes again...", "A shout in the distance. Grandpa!"]],
		["jump", "keuze"],
	]}],

	"keuze": [{"do": [
		["choice", "What do you do?", ["Stay", "Follow Grandpa"], ["blijven", "achterna"], ""],
	]}],

	"blijven": [{"do": [
		["say", "", ["{naam} stays inside, like Grandpa said..."]],
		["wait", 0.3],
		["shake", 1.2, 2.5],
		["say", "", ["Another shock. The rumble comes from the Archives."]],
		["jump", "keuze"],
	]}],

	"achterna": [{"do": [
		["say", "", ["No. Grandpa needs you!", "{naam} throws their full weight against the door... The lock bursts open!"]],
		["unlock", "HuisDeur"],
		["step", NACHT],
		["tint", "night", 1.2],
		["say", "", ["Night has fallen. The light comes from the Archives, beside the house."]],
	]}],

	# ============================================================ v0.17 ESDOORN + DONKER WOUD
	# TODO(verhaal): tekst hieronder is placeholder (zie TODO_STORY), behalve Het Zingende Graan.
	# --- poorten op de wereldkaart
	"naar_esdoorn": [
		{"if": {"not_flags": [GOLEM_FLAG]}, "do": [
			["say", "", ["Beyond the hills lies a village: Mapleton.", "But first you have to find out what is happening in the Forgotten Archives."]],
		]},
		{"do": "default"},
	],
	# TODO(verhaal): de kas gaat open op de bestaande golem-vlag van het Eerste Archief.
	# Waarom die kern op een tweede signaal reageert, staat nog open. Geen nieuwe beat.
	"naar_leven": [
		{"if": {"not_flags": [GOLEM_FLAG]}, "do": [
			["say", "", ["An overgrown greenhouse. The vines are sealed shut.", "Clear the First Archive first."]],
			["walk", "player", "up", 1],
		]},
		{"do": "default"},
	],

	# Bouwplaats voor de berggrot-tunnel. Dicht tot noor_lid (Noor in de party).
	"bouwplaats_voorman": [
		{"if": {"not_flags": ["noor_lid"]}, "do": [
			["say", "Foreman Henrik", ["Hold it right there. This tunnel isn't safe yet.", "The rock keeps shifting. Nobody goes in until we've shored it up.", "Come back later. Maybe with someone who can handle a few sparks."]],
		]},
		{"do": [
			["say", "Foreman Henrik", ["The supports are in. The tunnel's open.", "It runs right through the mountain. Watch your step in there."]],
		]},
	],
	"bouwplaats_werker": [
		{"if": {"not_flags": ["noor_lid"]}, "do": [
			["say", "Worker Sunny", ["Mind the cart! We're hauling rubble out all day.", "Something keeps cracking deep inside. Like it's growing back."]],
		]},
		{"do": [
			["say", "Worker Sunny", ["Finally done. My back is killing me.", "Funny thing: past the tunnel, there's a greenhouse. Nobody planted it."]],
		]},
	],
	"bouwplaats_hek": [
		{"if": {"not_flags": ["noor_lid"]}, "do": [
			["say", "", ["A barrier blocks the tunnel. DANGER - FALLING ROCK."]],
		]},
		{"do": "default"},
	],
	"woud_ingang": [
		{"if": {"not_flags": ["quest_noor"]}, "do": [
			["say", "", ["The Dark Wood. Between the black trunks hangs mist that flickers like a broken screen.", "You don't go in there without a reason."]],
		]},
		{"do": "default"},
	],
	# Waarom Archief 1 naar Archief 2 wijst. Eenmalig, bij de kas-ingang.
	"archief2_keten": [{"do": [
		["say", "", [
			"The Old Humanity made the six Archives as a chain.",
			"Each core activates the next. Not an invitation: a distress signal.",
			"The First Archive sent: Someone is inside. The Second Archive answered first.",
			"Sapientia manipulated that signal.",
			"You think you are following. Sapientia is leading you.",
		]],
		["flag", "archief2_keten"],
	]}],

	# --- de ontmoeting (eenmalig, MAP_ENTER; vlag noor_ontmoet)
	"noor_ontmoeting": [{"do": [
		["place", "player", [24, 30], "up"],   # 1.4x-kaart (48x34): zuidpad, Vesper op (24,19)
		["wait", 0.3],
		["walk", "player", "up", 8],
		["walk", "Vesper", "down", 1],
		["say", "Vesper", ["Hey! I don't know you. Did you come from over the hills? Nobody lives out there."]],
		["walk", "player", "up", 1],
		["say", "{naam}", ["I'm {naam}. I live with the Old Man, by the Archives. He sent me here."]],
		["say", "Vesper", ["I'm Vesper. The village calls me 'that girl with the sparks'.", "Watch."]],
		["flash", "#ff3ad0", 0.25],
		["say", "", ["Pink sparks dance between her fingers... and hitch, like a picture that sticks."]],
		["say", "Vesper", ["They've done that lately. And at night the woods whisper my name."]],
		["shake", 1.2, 2.5],
		["glitch", 0.4],
		["say", "", ["The ground splits open! Black roots full of flickering pink marks shoot up."]],
		["show", "WortelGreep"],
		["hide", "Vesper"],
		["say", "Vesper", ["They're... they're pulling me! {naam}!"]],
		["glitch", 0.5],
		["flash", "#ff3ad0", 0.5],
		["hide", "WortelGreep"],
		["shake", 0.8, 1.5],
		["say", "", ["When the light pulls away, Vesper is gone.", "A trail of torn earth runs west... toward the Dark Wood."]],
		["walk", "Marit", "down", 3],
		["walk", "Marit", "left", 2],
		["face", "Marit", "left"],
		["face", "player", "right"],
		["say", "Marigold", ["Vesper! No... the Dark Wood took her!", "You there, you have a sword. Please, save her!", "The wood lies west of the village."]],
		["flag", "noor_ontmoet"],
		["flag", "quest_noor"],
		["step", NOOR_KWIJT],
		["say", "", ["New quest: Save Vesper from the Dark Wood"]],
		["run", "marit_boeken"],
	]}],
	# v0.17 Codex: Marit geeft 3 Lege Boeken (eenmalig; ook via een gesprek met haar als de ontmoeting
	# al eerder gezien is, bv. een oude save). Geen winkel nog; 2 extra in kisten van het Donker Woud.
	"marit_boeken": [
		{"if": {"not_flags": ["marit_boeken"]}, "do": [
			["say", "Marigold", ["Wait! Take these. Blank books from my grandfather's archive.", "Vesper always said monsters fit inside them. I never believed it... but maybe they'll help you."]],
			["give", "leeg_boek", 3],
			["flag", "marit_boeken"],
			["say", "", ["You receive 3x Blank Book!"]],
		]},
		{"do": []},
	],

	# --- dorpelingen (hints over het donkere bos)
	"marit": [
		{"if": {"flags": ["noor_ontmoet"], "not_flags": ["marit_boeken"]}, "do": [["run", "marit_boeken"]]},
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Marigold", ["You really brought her back! Mapleton will never forget this."]]]},
		{"if": {"flags": ["quest_noor"]}, "do": [["say", "Marigold", ["The Dark Wood lies west of the village. Bring Vesper back, please!"]]]},
		{"do": [["say", "Marigold", ["Good day, traveler."]]]},
	],
	"bram": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Old Bramwell", ["The mist is lifting. For the first time in months I hear birds again."]]]},
		{"do": [["say", "Old Bramwell", ["We used to pick berries there. Now the trees hum like beehives.", "Stare at the mist too long and you see marks that don't belong."]]]},
	],
	"jens": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Jensen", ["Vesper's back! Will she make sparks again? Please?"]]]},
		{"do": [["say", "Jensen", ["Mama says the mushrooms in the wood glow at night.", "And that they can sneeze. Really!"]]]},
	],
	"tobias": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Tobias", ["The water is clear again. Strange, isn't it? As if the wood was sick."]]]},
		{"do": [["say", "Tobias", ["Since the roots crawl under the village, I only catch black fish.", "Those fish hitch. They swim... and then jump a little bit back."]]]},
	],
	"esdoorn_put": [{"do": [["say", "", ["An old well. Deep down, something pink flickers in the water."]]]}],
	"ilse": [
		{"if": {"flags": ["noor_gered"], "not_flags": ["ilse_thee"]}, "do": [
			["say", "Elise", ["You saved my Vesper. She wants to go with you. I can see it on her.", "Take good care of her. And take this tea, for the road."]],
			["give", "kruidenthee", 3],
			["flag", "ilse_thee"],
			["say", "", ["You receive 3x Herbal Tea!"]],
		]},
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Elise", ["Take good care of her, {naam}."]]]},
		{"if": {"flags": ["quest_noor"]}, "do": [["say", "Elise", ["My Vesper... She had those sparks for weeks. I should have seen it.", "Bring her back. Please."]]]},
		{"do": [["say", "Elise", ["Vesper is outside, on the square. As always."]]]},
	],
	"herbergier": [{"do": [
		["choice", "Do you want to rest here? (free)", ["Yes", "No"], ["herberg_rust", "herberg_nee"], "Innkeeper Walt"],
	]}],
	"herberg_rust": [{"do": [
		["fade_out", 0.4],
		["heal"],
		["wait", 0.6],
		["fade_in", 0.4],
		["say", "Innkeeper Walt", ["Sleep well? The save book is on the lectern, if you want to write."]],
		["say", "", ["The party's HP and MP are restored."]],
	]}],
	"herberg_nee": [{"do": [["say", "Innkeeper Walt", ["That's fine. Come back when you're tired."]]]}],

	# --- het Donker Woud
	"cocon": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "", ["The empty cocoon. The roots are grey and withered."]]]},
		{"do": [["say", "", ["Vesper! She hangs unconscious in a cocoon of roots.", "The Root King has to go first."]]]},
	],
	"noor_bevrijd": [{"do": [
		["place", "player", [13, 6], "up"],
		["wait", 0.4],
		["shake", 0.8, 2.0],
		["glitch", 0.3],
		["flash", "#ff3ad0", 0.4],
		["say", "", ["The Root King collapses. His roots shrivel into grey dust...", "...and the cocoon tears open!"]],
		["flag", "noor_gered"],
		["refresh"],
		["walk", "Vesper", "down", 1],
		["say", "Vesper", ["...{naam}? You're that boy from the square.", "I heard you fighting, through the roots. As if it came from very far away."]],
		["say", "{naam}", ["You're free. It's over."]],
		["say", "Vesper", ["No. Those roots whispered about the Archives. About a Warden.", "I'm coming with you. I want to know what's happening to my sparks."]],
		["join", "noor", {"level_from": "dennis", "level_delta": -1, "gear": ["eiken_staf", "reisgewaad"]}],
		["give", "wambuis", 1],
		["flag", "noor_lid"],
		["step", NOOR_GERED],
		["refresh"],
		["say", "", ["Vesper joins the party!", "She gives you a Padded Jerkin from Mapleton.", "Quest complete: Save Vesper from the Dark Wood"]],
	]}],
	"noor_woud": [{"do": [["say", "Vesper", ["Let's go, {naam}."]]]}],

	# Het Zingende Graan. Canon-dialoog. Dicht zonder noor_lid.
	# Eerste keer: bezoek, de vraag, dan Ja (opdracht aan) of Nee (weglopen, later nog mogelijk).
	# Zonder zaad: één zin. Met zaad: herkenning, de molen draait en zingt zacht, daarna de molen.
	# Daarna de afsluitende zin en opnieuw de molen.
	"gerrit": [
		{"if": {"not_flags": ["noor_lid"]}, "do": []},
		{"if": {"flags": [FLAG_GRAAN_KLAAR]}, "do": [
			["flag", "gesproken_gerrit"],   # Quest Log > Side: naam wordt opdracht
			["say", GERRIT, [QUOTE_GRAAN_DANK]],
			["molen"],
		]},
		{"if": {"flags": ["noor_lid", FLAG_ZAAD], "not_flags": [FLAG_GRAAN_KLAAR]}, "do": [
			["flag", "gesproken_gerrit"],   # Quest Log > Side: naam wordt opdracht
			["take", ITEM_ZAAD, 1],
			["flag", FLAG_GRAAN_KLAAR],
			["say", GERRIT, [QUOTE_GRAAN_ZAAD]],
			["molen_zang"],
			["zang"],
			["molen"],
		]},
		{"if": {"flags": ["noor_lid", FLAG_GRAAN], "not_flags": [FLAG_ZAAD]}, "do": [
			["flag", "gesproken_gerrit"],   # Quest Log > Side: naam wordt opdracht
			["say", GERRIT, [QUOTE_GRAAN_ZONDER]],
		]},
		{"if": {"flags": ["noor_lid"], "not_flags": [FLAG_GRAAN]}, "do": [
			["flag", "gesproken_gerrit"],   # Quest Log > Side: naam wordt opdracht
			["say", GERRIT, [QUOTE_GRAAN_BEZOEK, QUOTE_GRAAN_WIND]],
			["say", "{naam}", [QUOTE_GRAAN_VRAAG]],
			["say", GERRIT, [QUOTE_GRAAN_OP]],
			["choice", QUOTE_GRAAN_OUD, [KEUZE_GRAAN_JA, KEUZE_GRAAN_NEE], ["gerrit_ja", "gerrit_weigert"], GERRIT],
		]},
	],
	"gerrit_ja": [{"do": [
		["flag", FLAG_GRAAN],
		["say", GERRIT, [QUOTE_GRAAN_ZOEK, QUOTE_GRAAN_VOORZICHTIG]],
	]}],
	"gerrit_weigert": [{"do": [
		["say", GERRIT, [QUOTE_GRAAN_WACHT]],
	]}],
	"zingend_zaad": [
		{"if": {"flags": [FLAG_GRAAN], "not_flags": [FLAG_ZAAD]}, "do": [
			["battle", ["woudgeest", "woudgeest"], {"after": "zingend_zaad_na"}],
		]},
		{"do": []},
	],
	"zingend_zaad_na": [{"do": [
		["give", ITEM_ZAAD, 1],
		["flag", FLAG_ZAAD],
		["refresh"],
		["say", "", ["You find Singing Seed."]],
	]}],
	# Tutorial na de Inktwurm (eenmalig, zie AFTER_UNIQUE). De vlag gaat er als eerste op: ook wie
	# halverwege overslaat of het spel afsluit krijgt hem nooit opnieuw. Elke pagina: Next / Skip.
	TUTORIAL_INKTWURM: [
		{"if": {"not_flags": [TUTORIAL_INKTWURM_FLAG]}, "do": [
			["flag", TUTORIAL_INKTWURM_FLAG],
			["choice", TUT_INKT_PAGES[0], [TUT_NEXT, TUT_SKIP], [TUTORIAL_INKTWURM + "_2", ""], ""],
		]},
		{"do": []},
	],
	TUTORIAL_INKTWURM + "_2": [{"do": [
		["choice", TUT_INKT_PAGES[1], [TUT_NEXT, TUT_SKIP], [TUTORIAL_INKTWURM + "_3", ""], ""],
	]}],
	TUTORIAL_INKTWURM + "_3": [{"do": [
		["choice", TUT_INKT_PAGES[2], [TUT_NEXT, TUT_SKIP], [TUTORIAL_INKTWURM + "_4", ""], ""],
	]}],
	TUTORIAL_INKTWURM + "_4": [{"do": [
		["say", "", [TUT_INKT_PAGES[3]]],
	]}],
	# Vang-tutorial: zelfde opzet als hierboven (vlag eerst, Next/Skip per pagina).
	TUTORIAL_CODEX: [
		{"if": {"not_flags": [TUTORIAL_CODEX_FLAG]}, "do": [
			["flag", TUTORIAL_CODEX_FLAG],
			["choice", TUT_CODEX_PAGES[0], [TUT_NEXT, TUT_SKIP], [TUTORIAL_CODEX + "_2", ""], ""],
		]},
		{"do": []},
	],
	TUTORIAL_CODEX + "_2": [{"do": [
		["choice", TUT_CODEX_PAGES[1], [TUT_NEXT, TUT_SKIP], [TUTORIAL_CODEX + "_3", ""], ""],
	]}],
	TUTORIAL_CODEX + "_3": [{"do": [
		["choice", TUT_CODEX_PAGES[2], [TUT_NEXT, TUT_SKIP], [TUTORIAL_CODEX + "_4", ""], ""],
	]}],
	TUTORIAL_CODEX + "_4": [{"do": [
		["say", "", [TUT_CODEX_PAGES[3]]],
	]}],
	# Uitgang van de Golemhal: na de Golem op slot tot de Inktwurm in de Codex staat. Geen val: is de
	# Inktwurm al weg (verslagen) of is de Codex vol, dan kan hij niet meer ingeschreven worden en gaat
	# de deur gewoon open. Zonder Leeg Boek krijg je er één.
	GOLEMHAL_EXIT: [
		{"if": {"flags": [GOLEM_FLAG], "not_flags": [CODEX_INKTWURM_FLAG], "unique_open": "inktwurm",
				"codex_room": true, "not_item": "leeg_boek"}, "do": [
			["give", "leeg_boek", 1],
			["say", "", ["Loose pages block the exit.", "You find a Blank Book among them.",
					"Write the Ink Worm into the Codex to pass."]],
			["walk", "player", "up", 1],
		]},
		{"if": {"flags": [GOLEM_FLAG, "inktwurm_kast_open"], "not_flags": [CODEX_INKTWURM_FLAG],
				"unique_open": "inktwurm", "codex_room": true}, "do": [
			["say", "", ["Loose pages block the exit.", "Write the Ink Worm into the Codex to pass."]],
			["walk", "player", "up", 1],
		]},
		{"if": {"flags": [GOLEM_FLAG], "not_flags": [CODEX_INKTWURM_FLAG], "unique_open": "inktwurm",
				"codex_room": true}, "do": [
			["say", "", ["Loose pages block the exit.", "Something rustles in the cabinet on the right.",
					"Core Power might tear the parchment."]],
			["walk", "player", "up", 1],
		]},
		{"do": "default"},
	],
}


## Update 5: events die vanzelf starten in het huis op stap START.
## Dat is het stuk vóór het eerste vrije moment. Vóór deze update: ["wakker_worden"].
static func forced_before_free() -> Array:
	var out: Array = []
	for row in MAP_ENTER:
		if str(row.get("map", "")) != "huis":
			continue
		var cond: Dictionary = row.get("if", {})
		if int(cond.get("step", -999)) != START:
			continue
		var flags: Array = cond.get("flags", [])
		var not_flags: Array = cond.get("not_flags", [])
		if not flags.is_empty() or not not_flags.is_empty():
			continue
		out.append(str(row.get("event", "")))
	return out


static func _say_commands(event_id: String) -> int:
	var variants: Array = EVENTS.get(event_id, [])
	if variants.is_empty():
		return 0
	var cmds: Array = variants[0].get("do", [])
	var n := 0
	for raw in cmds:
		if raw is Array and not raw.is_empty() and str(raw[0]) == "say":
			n += 1
	return n


## Verplichte tekstvakken op het standaardpad tot de klusjes (opa_mantel + mantel_aan).
## Vóór Update 5: wakker_worden 1 + opa 4 + mantel_aan 2 = 7.
static func intro_says_before_tasks() -> int:
	return _say_commands("opa_mantel") + _say_commands("mantel_aan")


static func early_choice_spec() -> Dictionary:
	var variants: Array = EVENTS.get("intro_keuze", [])
	if variants.is_empty():
		return {}
	var cmds: Array = variants[0].get("do", [])
	for raw in cmds:
		if raw is Array and raw.size() >= 4 and str(raw[0]) == "choice":
			return {"question": str(raw[1]), "options": raw[2], "targets": raw[3]}
	return {}


## Leeg als het toon-event iets anders doet dan een vlag zetten en springen.
static func _tone_jump(event_id: String) -> String:
	var variants: Array = EVENTS.get(event_id, [])
	if variants.is_empty():
		return ""
	var cmds: Array = variants[0].get("do", [])
	var jump := ""
	for raw in cmds:
		if not (raw is Array) or raw.is_empty():
			return ""
		var op := str(raw[0])
		if op == "jump" and raw.size() >= 2:
			jump = str(raw[1])
		elif op != "flag":
			return ""
	return jump


## True als elke vroege optie (2 of 3) naar hetzelfde vervolg springt.
static func early_choice_same_followup() -> bool:
	var spec := early_choice_spec()
	var targets: Array = spec.get("targets", [])
	if targets.size() < 2 or targets.size() > 3:
		return false
	var dest := ""
	for t in targets:
		var jump := _tone_jump(str(t))
		if jump == "":
			return false
		if dest == "":
			dest = jump
		elif dest != jump:
			return false
	return dest == "opa_mantel"
