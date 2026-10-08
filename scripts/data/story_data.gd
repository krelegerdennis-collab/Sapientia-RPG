extends RefCounted
## v0.11 VERHAAL: de proloog "De Wacht van de Wachter" (docs: story/PROLOOG.md, scène 1 en 2).
## v0.16 (wens Dennis): tutorial korter: de 3 zegels/runen bij de bosrand zijn weg (objecten, events,
## tekst, tests); nieuw: Opa geeft een Leerling-mantel en je kunt pas verder als hij AAN is
## (MENU > Uitrusting; stap UITRUSTING, MENU_CLOSED hieronder).
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

## Stappen van de proloog
const START := 0          # nieuw spel: wakker worden in bed
const WAKKER := 10        # wakker, Opa staat buiten
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
	{"id": "noor", "title": "Red Noor uit het Donker Woud", "start_flag": "quest_noor", "done_flag": "noor_gered"},
]
## v0.17 TODO(verhaal): deze events hebben PLACEHOLDER-tekst (kort, Nederlands). Dennis schrijft het
## echte verhaal; de opbouw (wie loopt waar, vlaggen, ballonnen) kan blijven.
const TODO_STORY := ["noor_ontmoeting", "noor_bevrijd", "noor_woud", "marit", "bram", "jens", "tobias",
	"ilse", "herbergier", "naar_esdoorn", "woud_ingang", "marit_boeken"]

const SPEAKER := "Oude Man"

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
	{"map": "huis", "if": {"step": START}, "event": "wakker_worden"},
	{"map": "huis", "if": {"step": AVOND}, "event": "catastrofe"},
	{"map": "huis", "if": {"step": OPGESLOTEN}, "event": "opgesloten_timer"},
	# v0.17 eerste keer in Esdoorn (na de Golem): Noor ontmoeten, ze wordt het woud in gesleurd
	{"map": ESDOORN, "if": {"flags": [GOLEM_FLAG], "not_flags": ["noor_ontmoet"]}, "event": "noor_ontmoeting"},
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

const EVENTS := {
	# ------------------------------------------------------------ scène 1: ochtend
	"wakker_worden": [{"do": [
		["place", "player", [1, 3], "down"],
		["wait", 0.8],
		["say", "", ["{naam} wordt wakker. Opa is al op en staat vast weer buiten..."]],
		["walk", "player", "right", 1],
		["face", "player", "down"],
		["step", WAKKER],
	]}],

	"opa": [
		# v0.16 uitrusting-tutorial: eerst de mantel, pas daarna de klusjes
		{"if": {"step_lt": UITRUSTING}, "do": [
			["say", SPEAKER, ["Goedemorgen, {naam}. Het is koud vandaag. Hier, trek deze mantel aan."]],
			["give", TUTORIAL_ARMOR, 1],
			["say", "", ["{naam} krijgt een Leerling-mantel!"]],
			["step", UITRUSTING],
			["say", SPEAKER, ["Open het MENU rechtsboven en kies Uitrusting. Daar zet je de mantel bij Harnas."]],
			["say", "", ["(Tutorial: MENU > Uitrusting > Uitrusten > Harnas > Leerling-mantel.)", "(Sluit daarna het menu, dan gaat het verder.)"]],
			["face", "OudeMan", "up"],
		]},
		{"if": {"step": UITRUSTING, "equipped": TUTORIAL_ARMOR}, "do": [["jump", "mantel_aan"]]},
		# mantel weggegooid? Dan krijg je een nieuwe (anders zit je vast)
		{"if": {"step": UITRUSTING, "not_item": TUTORIAL_ARMOR}, "do": [
			["give", TUTORIAL_ARMOR, 1],
			["say", SPEAKER, ["Je mantel kwijt? Hier, nog eentje. MENU > Uitrusting > Harnas."]],
			["face", "OudeMan", "up"],
		]},
		{"if": {"step": UITRUSTING}, "do": [
			["say", SPEAKER, ["Eerst die mantel aan, {naam}. MENU > Uitrusting > Harnas."]],
			["face", "OudeMan", "up"],
		]},
		{"if": {"item": "emmer_water"}, "do": [
			["take", "emmer_water", 1],
			["say", SPEAKER, ["Dank je, {naam}. Zet hem maar hier neer."]],
			["flag", "water_klaar"],
			["if", {"flags": TASK_FLAGS}, [["step", LES], ["jump", "les"]], [["face", "OudeMan", "up"]]],
		]},
		{"if": {"step": TAKEN}, "do": [
			["if", {"not_flags": ["water_klaar"]}, [["say", SPEAKER, ["Het water, {naam}. De put staat links van het huis."]]]],
			["if", {"not_flags": ["kist_open"]}, [["say", SPEAKER, ["In de kist naast het huis liggen kruiden. Neem ze mee."]]]],
			["face", "OudeMan", "up"],
		]},
		{"if": {"step": LES}, "do": [["jump", "les"]]},
		{"do": [["say", SPEAKER, ["..."]]]},
	],

	# v0.16: de mantel is aan (na het sluiten van het menu, of als je Opa weer aanspreekt)
	"mantel_aan": [{"do": [
		["say", SPEAKER, ["Staat je goed. Zo blijf je warm.", "{naam}... haal wat water uit de put. En pak de kruiden uit de kist naast het huis. Vandaag voelt... anders."]],
		["say", "", ["(Taken: water uit de put halen en de kist naast het huis openen.)"]],
		["step", TAKEN],
		["face", "OudeMan", "up"],
	]}],

	"taken_check": [
		{"if": {"step": TAKEN, "flags": TASK_FLAGS}, "do": [
			["step", LES],
			["say", "", ["(Alle klusjes zijn gedaan. Ga terug naar Opa.)"]],
		]},
		{"do": []},
	],

	"les": [{"do": [
		["say", SPEAKER, ["Goed zo. Alles gedaan.", "Soms moet je je verdedigen, jongen, ook al hoop ik dat je het nooit nodig zult hebben."]],
		["weapon", "kort_zwaard"],
		["say", "", ["{naam} krijgt een Kort zwaard!"]],
		["say", SPEAKER, ["Kijk, daar in het gras. Een Mosslijm. Laat maar eens zien wat je kunt."]],
		["battle", ["mosslijm"], {"tutorial": true, "enemy_hp": 30, "after": "na_les"}],
	]}],

	"na_les": [{"do": [
		["face", "OudeMan", "down"],
		["say", SPEAKER, ["Niet slecht, {naam}. Niet slecht.", "Kom, de zon gaat al onder. Naar binnen."]],
		["step", AVOND],
		["map", "huis", "lezen", ""],
	]}],

	"put": [
		{"if": {"step": UITRUSTING}, "do": [["say", "", ["Opa wacht. Eerst de mantel aantrekken: MENU > Uitrusting."]]]},
		{"if": {"item": "emmer_water"}, "do": [["say", "", ["De emmer is al vol. Breng hem naar Opa."]]]},
		{"if": {"step": TAKEN, "not_flags": ["water_klaar"]}, "do": [
			["say", "", ["{naam} laat de emmer in de put zakken...", "{naam} heeft een emmer water!"]],
			["give", "emmer_water", 1],
		]},
		{"do": [["say", "", ["Een oude stenen put. Het water is koud en helder."]]]},
	],

	# v0.13: ruïne-stukken rond de ingang van de Archieven (RPG ART, tools/build_maps.gd RUIN_PIECES)
	"ruine": [{"do": [["say", "", ["Brokstukken van oude muren. Hier stond ooit meer dan alleen een ingang."]]]}],

	"kist": [
		{"if": {"flags": ["kist_open"]}, "do": [["say", "", ["De kist is leeg."]]]},
		{"if": {"step": UITRUSTING}, "do": [["say", "", ["Eerst de mantel van Opa aantrekken: MENU > Uitrusting."]]]},
		{"do": [
			["flag", "kist_open"],
			["refresh"],
			["give", "kruid", 3],
			["say", "", ["{naam} opent de kist.", "{naam} krijgt 3x Geneeskrachtig kruid!"]],
			["run", "taken_check"],
		]},
	],

	"schilderij": [
		{"if": {"flags": ["schilderij_weg"]}, "do": [["say", "", ["Het schilderij hangt scheef. Erachter zit een lege haak... hier hing Opa's zwaard."]]]},
		{"do": [["say", "", ["Een oud schilderij van het bos. Opa kijkt er vaak naar als hij denkt dat niemand het ziet."]]]},
	],

	"pad_wereld": [
		{"if": {"step_lt": AVOND}, "do": [
			["say", SPEAKER, ["Waar ga jij heen? Niet vandaag, {naam}. Blijf in de buurt van het huis."]],
			["walk", "player", "up", 1],
		]},
		{"if": {"step_lt": NACHT}, "do": [
			["say", "", ["Het pad naar de vallei ligt er donker bij... Nee. Eerst Opa vinden!"]],
			["walk", "player", "up", 1],
		]},
		# v0.13: na de proloog-scènes is het pad open (wereldkaart; daar is ook een ingang
		# van de Archieven, de trap)
		{"do": "default"},
	],

	"archief_ingang": [
		{"if": {"step_lt": NACHT}, "do": [
			["say", "", ["Dichte ranken en zware stenen versperren een oude ingang.", "Opa zegt altijd: 'Daar ga je nooit naar binnen.'"]],
		]},
		# v0.13: de eerste keer (scène 3 begint): tekst, daarna de eerste dungeonkamer in
		{"if": {"not_flags": ["archief_gezien"]}, "do": [["jump", "archief_binnen"]]},
		{"do": [
			["say", "", ["De ingang van De Vergeten Archieven. Roze licht flakkert in de diepte."]],
			["map", ARCHIEF, "ingang", ""],
		]},
	],

	"archief_binnen": [{"do": [
		["say", "", ["De ranken zijn verscheurd. Roze licht flakkert diep in de gangen.", "Ergens ver weg galmt Opa's stem...", "{naam} haalt diep adem en stapt naar binnen."]],
		["flag", "archief_gezien"],
		["map", ARCHIEF, "ingang", ""],
	]}],

	# ------------------------------------------------------------ scène 2: de catastrofe
	"catastrofe": [{"do": [
		["wait", 0.8],
		["say", "", ["Het is avond. {naam} leest in een oud boek van Opa.", "\"...en de Wachters sloten de Archieven, opdat niemand ooit nog zou ontwaken...\""]],
		["wait", 0.6],
		["shake", 2.2, 4.0],
		["wait", 0.5],
		["flash", "#ffffff", 0.7],
		["window_glow", 5.0],
		["face", "player", "up"],
		["say", "", ["De grond schudt! Een oorverdovende knal, en een verblindende flits uit de richting van de Archieven.", "Roze en blauw licht stroomt door de ramen."]],
		["face", "OudeMan", "up"],
		["wait", 0.4],
		["face", "OudeMan", "down"],
		["say", SPEAKER, ["Nee... het zegel! Het is te vroeg! {naam}, blijf hier! Sluit de deuren achter me en kom me niet achterna, wat je ook hoort!"]],
		["walk", "OudeMan", "up", 1],
		["walk", "OudeMan", "left", 3],
		["face", "OudeMan", "up"],
		["wait", 0.3],
		["flag", "schilderij_weg"],
		["refresh"],
		["say", "", ["Opa grijpt een oud, verroest zwaard achter het schilderij vandaan!"]],
		["walk", "OudeMan", "down", 5],
		["walk", "OudeMan", "left", 2],
		["walk", "OudeMan", "down", 1],
		["hide", "OudeMan"],
		["lock", "HuisDeur"],
		["say", "", ["De deur slaat dicht. Een sleutel draait om in het slot."]],
		["step", OPGESLOTEN],
		["refresh"],
		["after", 6.0, "schreeuw"],
	]}],

	"opgesloten_timer": [{"do": [["after", 5.0, "schreeuw"]]}],

	"huis_uit": [
		{"if": {"flags": ["locked:HuisDeur"]}, "do": [
			["say", "", ["De deur zit op slot. Opa zei dat ik hier moest blijven."]],
			["walk", "player", "up", 1],
		]},
		{"do": "default"},
	],

	"schreeuw": [{"do": [
		["shake", 1.6, 3.0],
		["wait", 0.6],
		["say", "", ["De aarde schudt opnieuw...", "In de verte klinkt een schreeuw. Opa!"]],
		["jump", "keuze"],
	]}],

	"keuze": [{"do": [
		["choice", "Wat doe je?", ["Blijven", "Opa achterna"], ["blijven", "achterna"], ""],
	]}],

	"blijven": [{"do": [
		["say", "", ["{naam} blijft binnen, zoals Opa zei..."]],
		["wait", 2.5],
		["shake", 1.2, 2.5],
		["say", "", ["Weer een schok. Het gerommel komt van de Archieven."]],
		["jump", "keuze"],
	]}],

	"achterna": [{"do": [
		["say", "", ["Nee. Opa heeft je nodig!", "{naam} gooit zich met volle kracht tegen de deur... Het slot springt open!"]],
		["unlock", "HuisDeur"],
		["step", NACHT],
		["tint", "night", 1.2],
		["say", "", ["Het is nacht geworden. Het licht komt van de Archieven, naast het huis."]],
	]}],

	# ============================================================ v0.17 ESDOORN + DONKER WOUD
	# TODO(verhaal): ALLE tekst hieronder is placeholder (zie TODO_STORY). Kort gehouden.
	# --- poorten op de wereldkaart
	"naar_esdoorn": [
		{"if": {"not_flags": [GOLEM_FLAG]}, "do": [
			["say", "", ["Achter de heuvels ligt een dorpje: Esdoorn.", "Maar eerst moet je weten wat er in De Vergeten Archieven gebeurt."]],
		]},
		{"do": "default"},
	],
	"woud_ingang": [
		{"if": {"not_flags": ["quest_noor"]}, "do": [
			["say", "", ["Het Donker Woud. Tussen de zwarte stammen hangt mist die flikkert als een kapot scherm.", "Zonder reden ga je daar niet naar binnen."]],
		]},
		{"do": "default"},
	],

	# --- de ontmoeting (eenmalig, MAP_ENTER; vlag noor_ontmoet)
	"noor_ontmoeting": [{"do": [
		["place", "player", [16, 21], "up"],
		["wait", 0.3],
		["walk", "player", "up", 3],
		["walk", "Noor", "down", 1],
		["say", "Noor", ["He! Jou ken ik niet. Kom jij van over de heuvels? Daar woont toch niemand?"]],
		["walk", "player", "up", 1],
		["say", "{naam}", ["Ik ben {naam}. Ik woon bij de Oude Man, bij de Archieven. Hij stuurde me hierheen."]],
		["say", "Noor", ["Ik ben Noor. Het dorp noemt me 'dat meisje met de vonken'.", "Kijk maar."]],
		["flash", "#ff3ad0", 0.25],
		["say", "", ["Roze vonken dansen tussen haar vingers... en haperen, als een beeld dat vastloopt."]],
		["say", "Noor", ["Dat doen ze sinds kort. En 's nachts fluistert het bos mijn naam."]],
		["shake", 1.2, 2.5],
		["glitch", 0.4],
		["say", "", ["De grond scheurt open! Zwarte wortels vol flikkerende roze tekens schieten omhoog."]],
		["show", "WortelGreep"],
		["hide", "Noor"],
		["say", "Noor", ["Ze... ze trekken aan me! {naam}!"]],
		["glitch", 0.5],
		["flash", "#ff3ad0", 0.5],
		["hide", "WortelGreep"],
		["shake", 0.8, 1.5],
		["say", "", ["Als het licht wegtrekt, is Noor verdwenen.", "Een spoor van omgewoelde aarde loopt naar het westen... naar het Donker Woud."]],
		["walk", "Marit", "down", 3],
		["walk", "Marit", "left", 2],
		["face", "Marit", "left"],
		["face", "player", "right"],
		["say", "Marit", ["Noor! Nee... het Donker Woud heeft haar gehaald!", "Jij daar, jij hebt een zwaard. Alsjeblieft, red haar!", "Het woud ligt ten westen van het dorp."]],
		["flag", "noor_ontmoet"],
		["flag", "quest_noor"],
		["step", NOOR_KWIJT],
		["say", "", ["Nieuwe opdracht: Red Noor uit het Donker Woud"]],
		["run", "marit_boeken"],
	]}],
	# v0.17 Codex: Marit geeft 3 Lege Boeken (eenmalig; ook via een gesprek met haar als de ontmoeting
	# al eerder gezien is, bv. een oude save). Geen winkel nog; 2 extra in kisten van het Donker Woud.
	"marit_boeken": [
		{"if": {"not_flags": ["marit_boeken"]}, "do": [
			["say", "Marit", ["Wacht! Neem deze mee. Lege boeken uit het archief van mijn grootvader.", "Noor zei altijd dat er monsters in passen. Ik heb het nooit geloofd... maar misschien helpen ze je."]],
			["give", "leeg_boek", 3],
			["flag", "marit_boeken"],
			["say", "", ["Je krijgt 3x Leeg Boek!"]],
		]},
		{"do": []},
	],

	# --- dorpelingen (hints over het donkere bos)
	"marit": [
		{"if": {"flags": ["noor_ontmoet"], "not_flags": ["marit_boeken"]}, "do": [["run", "marit_boeken"]]},
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Marit", ["Je hebt haar echt teruggehaald! Esdoorn zal je dit nooit vergeten."]]]},
		{"if": {"flags": ["quest_noor"]}, "do": [["say", "Marit", ["Het Donker Woud ligt ten westen van het dorp. Breng Noor terug, alsjeblieft!"]]]},
		{"do": [["say", "Marit", ["Goedendag, reiziger."]]]},
	],
	"bram": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Oude Bram", ["De mist trekt op. Voor het eerst in maanden hoor ik weer vogels."]]]},
		{"do": [["say", "Oude Bram", ["Vroeger plukten we daar bessen. Nu staan de bomen te zoemen als bijenkorven.", "Wie te lang naar de mist kijkt, ziet tekens die er niet horen."]]]},
	],
	"jens": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Jens", ["Noor is terug! Laat ze nog eens vonken maken? Alsjeblieft?"]]]},
		{"do": [["say", "Jens", ["Mama zegt dat de paddenstoelen in het woud 's nachts lichtgeven.", "En dat ze kunnen niezen. Echt waar!"]]]},
	],
	"tobias": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Tobias", ["Het water is weer helder. Raar, hè? Alsof het woud ziek was."]]]},
		{"do": [["say", "Tobias", ["Sinds de wortels onder het dorp door kruipen, vang ik alleen nog zwarte vissen.", "Die vissen haperen. Ze zwemmen... en springen dan een stukje terug."]]]},
	],
	"esdoorn_put": [{"do": [["say", "", ["Een oude put. Diep beneden flikkert iets roze in het water."]]]}],
	"ilse": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Ilse", ["Je hebt mijn Noor gered. Ze wil met je mee, dat zie ik aan haar.", "Pas goed op haar, {naam}."]]]},
		{"if": {"flags": ["quest_noor"]}, "do": [["say", "Ilse", ["Mijn Noor... Ze had al weken van die vonken. Ik had het moeten zien.", "Breng haar terug. Alsjeblieft."]]]},
		{"do": [["say", "Ilse", ["Noor is buiten, op het plein. Zoals altijd."]]]},
	],
	"herbergier": [{"do": [
		["choice", "Wil je hier uitrusten? (gratis)", ["Ja", "Nee"], ["herberg_rust", "herberg_nee"], "Waard Wout"],
	]}],
	"herberg_rust": [{"do": [
		["fade_out", 0.4],
		["heal"],
		["wait", 0.6],
		["fade_in", 0.4],
		["say", "Waard Wout", ["Goed geslapen? Het opslagboek ligt op de lessenaar, als je wilt schrijven."]],
		["say", "", ["HP en MP van de groep zijn hersteld."]],
	]}],
	"herberg_nee": [{"do": [["say", "Waard Wout", ["Ook goed. Kom terug als je moe bent."]]]}],

	# --- het Donker Woud
	"cocon": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "", ["De lege cocon. De wortels zijn grijs en verdord."]]]},
		{"do": [["say", "", ["Noor! Ze hangt bewusteloos in een cocon van wortels.", "Eerst moet de Wortelkoning weg."]]]},
	],
	"noor_bevrijd": [{"do": [
		["place", "player", [9, 6], "up"],
		["wait", 0.4],
		["shake", 0.8, 2.0],
		["glitch", 0.3],
		["flash", "#ff3ad0", 0.4],
		["say", "", ["De Wortelkoning stort in. Zijn wortels verschrompelen tot grijs stof...", "...en de cocon scheurt open!"]],
		["flag", "noor_gered"],
		["refresh"],
		["walk", "Noor", "down", 1],
		["say", "Noor", ["...{naam}? Jij bent die jongen van het plein.", "Ik hoorde je vechten, door de wortels heen. Alsof het van heel ver kwam."]],
		["say", "{naam}", ["Je bent vrij. Het is voorbij."]],
		["say", "Noor", ["Nee. Die wortels fluisterden over de Archieven. Over een Wachter.", "Ik ga met je mee. Ik wil weten wat er met mijn vonken gebeurt."]],
		["join", "noor", {"level_from": "dennis", "level_delta": -1, "gear": ["eiken_staf", "reisgewaad"]}],
		["flag", "noor_lid"],
		["step", NOOR_GERED],
		["refresh"],
		["say", "", ["Noor sluit zich aan bij de groep!", "Opdracht voltooid: Red Noor uit het Donker Woud"]],
	]}],
	"noor_woud": [{"do": [["say", "Noor", ["Laten we gaan, {naam}."]]]}],
}
