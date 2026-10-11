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
	{"id": "noor", "title": "Save Noor from the Dark Wood", "start_flag": "quest_noor", "done_flag": "noor_gered"},
]
## v0.17 TODO(verhaal): deze events hebben PLACEHOLDER-tekst (kort, Nederlands). Dennis schrijft het
## echte verhaal; de opbouw (wie loopt waar, vlaggen, ballonnen) kan blijven.
const TODO_STORY := ["noor_ontmoeting", "noor_bevrijd", "noor_woud", "marit", "bram", "jens", "tobias",
	"ilse", "herbergier", "naar_esdoorn", "woud_ingang", "marit_boeken"]

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
		["say", "", ["{naam} wakes up. Grandpa is already up, and surely outside again..."]],
		["walk", "player", "right", 1],
		["face", "player", "down"],
		["step", WAKKER],
	]}],

	"opa": [
		# v0.16 uitrusting-tutorial: eerst de mantel, pas daarna de klusjes
		{"if": {"step_lt": UITRUSTING}, "do": [
			["say", SPEAKER, ["Good morning, {naam}. It's cold today. Here, put this cloak on."]],
			["give", TUTORIAL_ARMOR, 1],
			["say", "", ["{naam} receives an Apprentice Cloak!"]],
			["step", UITRUSTING],
			["say", SPEAKER, ["Open the MENU at the top right and choose Equipment. Put the cloak in Armor."]],
			["say", "", ["(Tutorial: MENU > Equipment > Equip > Armor > Apprentice Cloak.)", "(Close the menu after that, and it continues.)"]],
			["face", "OudeMan", "up"],
		]},
		{"if": {"step": UITRUSTING, "equipped": TUTORIAL_ARMOR}, "do": [["jump", "mantel_aan"]]},
		# mantel weggegooid? Dan krijg je een nieuwe (anders zit je vast)
		{"if": {"step": UITRUSTING, "not_item": TUTORIAL_ARMOR}, "do": [
			["give", TUTORIAL_ARMOR, 1],
			["say", SPEAKER, ["Lost your cloak? Here, another one. MENU > Equipment > Armor."]],
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

	# v0.16: de mantel is aan (na het sluiten van het menu, of als je Opa weer aanspreekt)
	"mantel_aan": [{"do": [
		["say", SPEAKER, ["It suits you. That will keep you warm.", "{naam}... fetch some water from the well. And take the herbs from the chest beside the house. Today feels... different."]],
		["say", "", ["(Tasks: draw water from the well and open the chest beside the house.)"]],
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
		{"if": {"step": UITRUSTING}, "do": [["say", "", ["Grandpa is waiting. Put the cloak on first: MENU > Equipment."]]]},
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
		["wait", 0.8],
		["say", "", ["It's evening. {naam} is reading one of Grandpa's old books.", "\"...and the Wardens sealed the Archives, so that no one would ever wake again...\""]],
		["wait", 0.6],
		["shake", 2.2, 4.0],
		["wait", 0.5],
		["flash", "#ffffff", 0.7],
		["window_glow", 5.0],
		["face", "player", "up"],
		["say", "", ["The ground shakes! A deafening bang, and a blinding flash from the direction of the Archives.", "Pink and blue light pours through the windows."]],
		["face", "OudeMan", "up"],
		["wait", 0.4],
		["face", "OudeMan", "down"],
		["say", SPEAKER, ["No... the seal! It's too soon! {naam}, stay here! Lock the doors behind me and don't follow, no matter what you hear!"]],
		["walk", "OudeMan", "up", 1],
		["walk", "OudeMan", "left", 3],
		["face", "OudeMan", "up"],
		["wait", 0.3],
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
		["after", 6.0, "schreeuw"],
	]}],

	"opgesloten_timer": [{"do": [["after", 5.0, "schreeuw"]]}],

	"huis_uit": [
		{"if": {"flags": ["locked:HuisDeur"]}, "do": [
			["say", "", ["The door is locked. Grandpa said I had to stay here."]],
			["walk", "player", "up", 1],
		]},
		{"do": "default"},
	],

	"schreeuw": [{"do": [
		["shake", 1.6, 3.0],
		["wait", 0.6],
		["say", "", ["The earth shakes again...", "A shout in the distance. Grandpa!"]],
		["jump", "keuze"],
	]}],

	"keuze": [{"do": [
		["choice", "What do you do?", ["Stay", "Follow Grandpa"], ["blijven", "achterna"], ""],
	]}],

	"blijven": [{"do": [
		["say", "", ["{naam} stays inside, like Grandpa said..."]],
		["wait", 2.5],
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
	# TODO(verhaal): ALLE tekst hieronder is placeholder (zie TODO_STORY). Kort gehouden.
	# --- poorten op de wereldkaart
	"naar_esdoorn": [
		{"if": {"not_flags": [GOLEM_FLAG]}, "do": [
			["say", "", ["Beyond the hills lies a village: Mapleton.", "But first you have to find out what is happening in the Forgotten Archives."]],
		]},
		{"do": "default"},
	],
	"woud_ingang": [
		{"if": {"not_flags": ["quest_noor"]}, "do": [
			["say", "", ["The Dark Wood. Between the black trunks hangs mist that flickers like a broken screen.", "You don't go in there without a reason."]],
		]},
		{"do": "default"},
	],

	# --- de ontmoeting (eenmalig, MAP_ENTER; vlag noor_ontmoet)
	"noor_ontmoeting": [{"do": [
		["place", "player", [16, 21], "up"],
		["wait", 0.3],
		["walk", "player", "up", 3],
		["walk", "Noor", "down", 1],
		["say", "Noor", ["Hey! I don't know you. Did you come from over the hills? Nobody lives out there."]],
		["walk", "player", "up", 1],
		["say", "{naam}", ["I'm {naam}. I live with the Old Man, by the Archives. He sent me here."]],
		["say", "Noor", ["I'm Noor. The village calls me 'that girl with the sparks'.", "Watch."]],
		["flash", "#ff3ad0", 0.25],
		["say", "", ["Pink sparks dance between her fingers... and hitch, like a picture that sticks."]],
		["say", "Noor", ["They've done that lately. And at night the woods whisper my name."]],
		["shake", 1.2, 2.5],
		["glitch", 0.4],
		["say", "", ["The ground splits open! Black roots full of flickering pink marks shoot up."]],
		["show", "WortelGreep"],
		["hide", "Noor"],
		["say", "Noor", ["They're... they're pulling me! {naam}!"]],
		["glitch", 0.5],
		["flash", "#ff3ad0", 0.5],
		["hide", "WortelGreep"],
		["shake", 0.8, 1.5],
		["say", "", ["When the light pulls away, Noor is gone.", "A trail of torn earth runs west... toward the Dark Wood."]],
		["walk", "Marit", "down", 3],
		["walk", "Marit", "left", 2],
		["face", "Marit", "left"],
		["face", "player", "right"],
		["say", "Marit", ["Noor! No... the Dark Wood took her!", "You there, you have a sword. Please, save her!", "The wood lies west of the village."]],
		["flag", "noor_ontmoet"],
		["flag", "quest_noor"],
		["step", NOOR_KWIJT],
		["say", "", ["New quest: Save Noor from the Dark Wood"]],
		["run", "marit_boeken"],
	]}],
	# v0.17 Codex: Marit geeft 3 Lege Boeken (eenmalig; ook via een gesprek met haar als de ontmoeting
	# al eerder gezien is, bv. een oude save). Geen winkel nog; 2 extra in kisten van het Donker Woud.
	"marit_boeken": [
		{"if": {"not_flags": ["marit_boeken"]}, "do": [
			["say", "Marit", ["Wait! Take these. Blank books from my grandfather's archive.", "Noor always said monsters fit inside them. I never believed it... but maybe they'll help you."]],
			["give", "leeg_boek", 3],
			["flag", "marit_boeken"],
			["say", "", ["You receive 3x Blank Book!"]],
		]},
		{"do": []},
	],

	# --- dorpelingen (hints over het donkere bos)
	"marit": [
		{"if": {"flags": ["noor_ontmoet"], "not_flags": ["marit_boeken"]}, "do": [["run", "marit_boeken"]]},
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Marit", ["You really brought her back! Mapleton will never forget this."]]]},
		{"if": {"flags": ["quest_noor"]}, "do": [["say", "Marit", ["The Dark Wood lies west of the village. Bring Noor back, please!"]]]},
		{"do": [["say", "Marit", ["Good day, traveler."]]]},
	],
	"bram": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Old Bram", ["The mist is lifting. For the first time in months I hear birds again."]]]},
		{"do": [["say", "Old Bram", ["We used to pick berries there. Now the trees hum like beehives.", "Stare at the mist too long and you see marks that don't belong."]]]},
	],
	"jens": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Jens", ["Noor's back! Will she make sparks again? Please?"]]]},
		{"do": [["say", "Jens", ["Mama says the mushrooms in the wood glow at night.", "And that they can sneeze. Really!"]]]},
	],
	"tobias": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Tobias", ["The water is clear again. Strange, isn't it? As if the wood was sick."]]]},
		{"do": [["say", "Tobias", ["Since the roots crawl under the village, I only catch black fish.", "Those fish hitch. They swim... and then jump a little bit back."]]]},
	],
	"esdoorn_put": [{"do": [["say", "", ["An old well. Deep down, something pink flickers in the water."]]]}],
	"ilse": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "Ilse", ["You saved my Noor. She wants to go with you. I can see it on her.", "Take good care of her, {naam}."]]]},
		{"if": {"flags": ["quest_noor"]}, "do": [["say", "Ilse", ["My Noor... She had those sparks for weeks. I should have seen it.", "Bring her back. Please."]]]},
		{"do": [["say", "Ilse", ["Noor is outside, on the square. As always."]]]},
	],
	"herbergier": [{"do": [
		["choice", "Do you want to rest here? (free)", ["Yes", "No"], ["herberg_rust", "herberg_nee"], "Innkeeper Wout"],
	]}],
	"herberg_rust": [{"do": [
		["fade_out", 0.4],
		["heal"],
		["wait", 0.6],
		["fade_in", 0.4],
		["say", "Innkeeper Wout", ["Sleep well? The save book is on the lectern, if you want to write."]],
		["say", "", ["The party's HP and MP are restored."]],
	]}],
	"herberg_nee": [{"do": [["say", "Innkeeper Wout", ["That's fine. Come back when you're tired."]]]}],

	# --- het Donker Woud
	"cocon": [
		{"if": {"flags": ["noor_gered"]}, "do": [["say", "", ["The empty cocoon. The roots are grey and withered."]]]},
		{"do": [["say", "", ["Noor! She hangs unconscious in a cocoon of roots.", "The Root King has to go first."]]]},
	],
	"noor_bevrijd": [{"do": [
		["place", "player", [9, 6], "up"],
		["wait", 0.4],
		["shake", 0.8, 2.0],
		["glitch", 0.3],
		["flash", "#ff3ad0", 0.4],
		["say", "", ["The Root King collapses. His roots shrivel into grey dust...", "...and the cocoon tears open!"]],
		["flag", "noor_gered"],
		["refresh"],
		["walk", "Noor", "down", 1],
		["say", "Noor", ["...{naam}? You're that boy from the square.", "I heard you fighting, through the roots. As if it came from very far away."]],
		["say", "{naam}", ["You're free. It's over."]],
		["say", "Noor", ["No. Those roots whispered about the Archives. About a Warden.", "I'm coming with you. I want to know what's happening to my sparks."]],
		["join", "noor", {"level_from": "dennis", "level_delta": -1, "gear": ["eiken_staf", "reisgewaad"]}],
		["flag", "noor_lid"],
		["step", NOOR_GERED],
		["refresh"],
		["say", "", ["Noor joins the party!", "Quest complete: Save Noor from the Dark Wood"]],
	]}],
	"noor_woud": [{"do": [["say", "Noor", ["Let's go, {naam}."]]]}],
}
