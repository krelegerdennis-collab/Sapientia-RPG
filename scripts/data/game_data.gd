extends RefCounted
## ============================================================
##  SPELDATA – hier pas je helden, vijanden, spreuken, items
##  en de kans op gevechten aan. Alles is gewone tekst/getallen.
## ============================================================
## Tip: na een wijziging gewoon opnieuw starten (F5).
## Statistieken:
##   hp  = levenspunten        mp  = magiepunten
##   atk = aanvalskracht       def = verdediging
##   agi = snelheid (wie hoger is, is eerder aan de beurt; op het scherm "SPD")
##   v0.14: mag = magische kracht, mdef = magische verdediging (VOORSTEL, waarden uit
##   story/ITEMS_ELEMENTEN.md par. 1; het gevecht gebruikt ze nog niet, zie HANDOFF_MENU_L2.md)
## v0.14 uitrusting: atk/def/agi/mag/mdef hieronder zijn de BASISWAARDEN op level 1. In het
## spel staat in de held de effectieve waarde (basis + uitrusting), zie scripts/equipment.gd.

# ---------------------------------------------------------------- helden
## De party. Volgorde = volgorde in het menu en in het statusvenster.
## "growth" = hoeveel een stat stijgt per level-up.
## Namen maximaal 5 letters, anders past het statusvenster niet.
## "battle_sprite" = gevechtssprite (strook van 8 frames van 160x160, v7 'De Vergeten Bibliotheek',
## voeten op (70, 135), zie docs/ARTSTYLE.md hoofdstuk 13).
## "accent" = neonkleur van de held in het statusvak/effecten: "magenta", "cyaan" of "" (grijs).
const HEROES := [
	{
		"id": "dennis", "battle_sprite": "res://assets/sprites/battle/dennis_rug.png",   # v0.11: rugaanzicht (RPG ART)
		"field_sprite": "res://assets/sprites/player.png",   # v0.14: loop-sheet (vooraanzicht in het menu)
		"name": "Dax", "class": "Warrior", "accent": "", "equip_type": "krijger",
		"level": 1, "exp": 0,
		"max_hp": 42, "max_mp": 0, "atk": 14, "def": 8, "agi": 9, "mag": 2, "mdef": 4,
		"spells": [],
		"growth": {"max_hp": 9, "max_mp": 0, "atk": 3, "def": 2, "agi": 1, "mag": 0, "mdef": 1},
	},
	{
		"id": "noor", "battle_sprite": "res://assets/sprites/battle/noor.png",
		# v0.17: dorp-/overworld-loopsheet van RPG ART (art_helden_dorp_v14, 48x96, zelfde indeling als player.png)
		"field_sprite": "res://assets/sprites/noor_dorp.png",
		"name": "Vesper", "class": "Mage", "accent": "magenta", "equip_type": "magier",
		"level": 1, "exp": 0,
		"max_hp": 28, "max_mp": 18, "atk": 7, "def": 5, "agi": 11, "mag": 10, "mdef": 8,
		"spells": ["vuur", "bliksem"],
		"growth": {"max_hp": 5, "max_mp": 4, "atk": 1, "def": 1, "agi": 2, "mag": 2, "mdef": 2},
	},
	{
		"id": "lotte", "battle_sprite": "res://assets/sprites/battle/lotte.png",
		# Veld-sheet is een PLACEHOLDER (48x96). De gevechts-art blijft handwerk.
		"field_sprite": "res://assets/sprites/archief2/lotte_veld.png",
		"name": "Seren", "class": "Priest", "accent": "cyaan", "equip_type": "priester",
		"level": 1, "exp": 0,
		"max_hp": 32, "max_mp": 14, "atk": 9, "def": 6, "agi": 7, "mag": 7, "mdef": 9,
		"spells": ["genees"],
		"growth": {"max_hp": 6, "max_mp": 3, "atk": 2, "def": 1, "agi": 1, "mag": 2, "mdef": 2},
	},
	# Rekruten in de World Warper-hal (world_warper/services/rekruut.gd). Gevechtsart (RPG ART, 21 okt 2026):
	# 2100x210, 10 frames van 210, voeten op (105,203); framekaart als Dax (0 stand,1 ready,2-3 attack,4-5 spell,6 hit,7 ko,8-9 breathe).
	{
		"id": "kael", "battle_sprite": "res://assets/sprites/battle/kael.png",
		"field_sprite": "res://assets/sprites/som/kaart/kael_wm1_slim.png",
		"name": "Kael Voss", "class": "Psytech", "accent": "cyaan", "equip_type": "magier",
		"level": 1, "exp": 0,
		"max_hp": 30, "max_mp": 16, "atk": 10, "def": 6, "agi": 9, "mag": 9, "mdef": 7,
		"spells": ["vonk"],
		"growth": {"max_hp": 6, "max_mp": 3, "atk": 2, "def": 1, "agi": 1, "mag": 2, "mdef": 2},
	},
	{
		"id": "orion", "battle_sprite": "res://assets/sprites/battle/orion.png",
		"field_sprite": "res://assets/sprites/som/kaart/orion_wm1_slim.png",
		"name": "Orion", "class": "Archer", "accent": "magenta", "equip_type": "krijger",
		"level": 1, "exp": 0,
		"max_hp": 34, "max_mp": 0, "atk": 12, "def": 6, "agi": 12, "mag": 3, "mdef": 5,
		"spells": [],
		"growth": {"max_hp": 7, "max_mp": 0, "atk": 3, "def": 1, "agi": 2, "mag": 0, "mdef": 1},
	},
]

## Totale EXP die nodig is om een level te bereiken.
## Level 2 = 15, level 3 = 60, level 4 = 135, ...
## Formule blijft 15 * (level - 1)^2 (CANON: onze levelschaal). Geen harde cap:
## de 100-verdiepingen-kerker mag hier voorbij. Act-banden t/m het einde: LevelScale.
const LevelScale := preload("res://scripts/data/level_scale.gd")


static func exp_for_level(level: int) -> int:
	return 15 * (level - 1) * (level - 1)


## Act (1-6) waar dit level in het verhaal bij hoort. 0 = geen. Boven 40 blijft Act 6.
static func act_for_level(level: int) -> int:
	return LevelScale.act_for_level(level)

# ---------------------------------------------------------------- vijanden
## "sprite" = plaatje op 2x-resolutie (1 art-pixel = 1 pixel van het 768x432-raster; op het
## scherm altijd de helft). Voeten = midden-onder, een paar pixels boven de rand.
## "skills" = speciale aanvallen met een kans per beurt.
## "y_offset" = hoger/lager tekenen. (De Glitchmot zweeft in zijn plaatje al boven zijn
## eigen grondschaduw, dus die heeft 0 nodig.)
## v7 'De Vergeten Bibliotheek': de oude slijm/vleermuis/goblin zijn vervangen door:
##   papiergeest  (was slijm)     - geest van losse bladzijden met binaire tekst
##   glitchmot    (was vleermuis) - snelle vliegende mot met kapotte vleugels
##   kennis_beest (was goblin)    - baas: golem van boeken, perkament en code, met een boekenhamer
## v0.10 Bestiarium (zelfde data, extra velden):
##   "no" = nummer in het bestiarium, "mp", "weak"/"resist" = lijst van elementen
##   ("vuur", "bliksem", ...; nu alleen informatie, nog niet in de schadeformule),
##   "drops" = [{"item": id, "chance": 0..1}] (chance = alleen het bestiarium) of, op een baas,
##             {"item": id, "n": aantal} = vaste buit bij winst (niet in de 100-verdiepingen-kerker).
##   "desc" = korte beschrijving, "habitat" = waar hij leeft (terreinen).
const ENEMIES := {
	# v0.10: eerste monsters op het gras (keuze van Dennis). Vooraanzicht-art komt van
	# RPG ART op res://art/enemies/<id>.png; nu staan er placeholders (tools/art_v10.py).
	"mosslijm": {
		"name": "Moss Slime", "sprite": "res://art/enemies/mosslijm.png",
		"sprite_back": "res://art/enemies/mosslijm_rug.png",   # v0.17 rugaanzicht (Codex-bondgenoot)
		"max_hp": 13, "atk": 10, "def": 2, "agi": 3,
		"exp": 3, "gold": 2, "y_offset": 0,
		"skills": [],
		"no": 1, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.10}],
		"desc": "A clot of living moss that crawls over old book covers. Sticky, but not mean.",
		"habitat": ["gras", "hoog_gras"],
	},
	"moskonijn": {
		"name": "Moss Rabbit", "sprite": "res://art/enemies/moskonijn.png",
		"sprite_back": "res://art/enemies/moskonijn_rug.png",   # v0.18 rugaanzicht (Codex-bondgenoot; RPG ART art_rug_v18)
		"max_hp": 18, "atk": 14, "def": 3, "agi": 12,
		"exp": 4, "gold": 3, "y_offset": 0,
		"skills": [],
		"no": 2, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.12}],
		"desc": "A rabbit with a coat of moss and ferns. Fast, skittish, and it bites if you get too close.",
		"habitat": ["gras", "hoog_gras", "bos"],
	},
	"papiergeest": {
		"name": "Paper Wraith", "sprite": "res://assets/sprites/enemies/papiergeest.png",
		"sprite_back": "res://assets/sprites/enemies/papiergeest_rug.png",   # v0.17 rugaanzicht (Codex-bondgenoot)
		"max_hp": 21, "atk": 14, "def": 3, "agi": 4,
		"exp": 5, "gold": 4, "y_offset": 0,
		"skills": [],
		"no": 3, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.15}],
		"desc": "Torn-out pages that were never read. They whisper zeros and ones.",
		"habitat": ["gras", "bos"],
	},
	"glitchmot": {
		"name": "Glitch Moth", "sprite": "res://assets/sprites/enemies/glitchmot.png",
		"sprite_back": "res://assets/sprites/enemies/glitchmot_rug.png",   # v0.17 rugaanzicht (Codex-bondgenoot)
		"max_hp": 16, "atk": 15, "def": 2, "agi": 14,
		"exp": 6, "gold": 3, "y_offset": 0,
		"skills": [],
		"no": 4, "mp": 0, "weak": ["bliksem"], "resist": [],
		"drops": [{"item": "toverwater", "chance": 0.10}],
		"desc": "A moth with broken wings of noise. It flies at the light of screens and candles.",
		"habitat": ["gras", "zand", "bos"],
	},
	# v0.13: eerste echte vijand van De Vergeten Archieven (scène 3: 'half kapotte Wachters').
	# Art van RPG ART (art_act1_v14/out): vooraanzicht 88x112 + idle-strook (2 frames).
	# STATS VOORLOPIG (nog niet gebalanceerd): tussen de kleine Archief-vijanden en de Golem in.
	"mech_wachter": {
		"name": "Mech. Warden", "sprite": "res://assets/sprites/enemies/mech_wachter.png",
		"sprite_back": "res://assets/sprites/enemies/mech_wachter_rug.png",   # v0.18 rugaanzicht (Codex-bondgenoot; RPG ART art_rug_v18)
		"idle": "res://assets/sprites/enemies/mech_wachter_idle.png", "idle_frames": 2, "idle_time": 0.55,
		# v0.14 DEFINITIEF (RPG CODE, zie HANDOFF_GOLEM.md): sterkste gewone vijand van de Archieven.
		# Dennis Lv 1 (ATK 17): 3 klappen; Lv 2-3 (ATK 20-23): 2 klappen. Hij doet 4-9 schade.
		# v0.15 (ARCHIEF1): dit zijn de BASIS-stats (wereldkaart / niveau 1). In de verdiepingen 2-4
		# maakt Forge's monsterniveau ("tier", ARCHIEF1_PLATTEGROND.md §6) hem sterker; zie
		# HANDOFF_ARCHIEF1.md voor de tabel per niveau. Nieuw trucje 'Schild omhoog' ("type": "guard"):
		# i.p.v. aanvallen DEF x2, de rest van deze ronde en de hele volgende ronde (bericht, blauwe
		# tint en een strook tijdens het kiezen).
		"max_hp": 30, "atk": 12, "def": 8, "agi": 5, "mag": 0, "mdef": 4,
		"exp": 10, "gold": 8, "y_offset": 0,
		"skills": [{"name": "Shield Up", "chance": 0.2, "type": "guard", "def_mult": 2.0},
				{"name": "Seal Strike", "chance": 0.15, "power": 1.4}],
		"no": 6, "mp": 0, "weak": ["bliksem"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.25}],
		"desc": "A half-broken guard of iron, brass, and old book covers. Its eye still searches for intruders.",
		"habitat": ["archief"],
	},
	"kennis_beest": {
		# v0.13: Golem v2 (met hamer) van RPG ART (art_golem_v14/out): still 196x182, idle-strook
		# 4 frames (kern pulseert, langzaam), raak-plaatje (zelfde ankerpunt) en een aparte
		# runecirkel achter de voeten (2 frames 196x36 op (0,158), loopt langzaam). De oude
		# kennis_beest.png en golem_boss.png (v1) blijven bestaan (handwerk), maar worden niet gebruikt.
		"name": "The Knowledge Beast", "sprite": "res://assets/sprites/enemies/golem_boss_v2.png",
		# v0.17 rugaanzicht (Codex-bondgenoot; als bondgenoot liefst kleiner tonen, zie v17_ART_SLOTS.md)
		"sprite_back": "res://assets/sprites/enemies/kennis_beest_rug.png",
		"idle": "res://assets/sprites/enemies/golem_boss_v2_idle.png", "idle_frames": 4, "idle_time": 0.4,
		"hit": "res://assets/sprites/enemies/golem_boss_v2_hit.png",
		"under": "res://assets/sprites/enemies/golem_runecirkel.png", "under_frames": 2,
		"under_pos": [0, 158], "under_time": 0.9,
		"max_hp": 46, "atk": 14, "def": 7, "agi": 6,
		"exp": 24, "gold": 18, "y_offset": 0,
		"skills": [{"name": "Book Hammer", "chance": 0.25, "power": 1.5}],
		"no": 5, "mp": 6, "weak": ["vuur"], "resist": ["bliksem"],
		"drops": [{"item": "drankje", "chance": 0.5}, {"item": "toverwater", "chance": 0.25}],
		# v0.14 (RPG CODE) DE GOLEM-BAAS: in een baasgevecht (GameState.pending_boss, bv. de Golem
		# op het platform in de Archieven) gelden deze waarden i.p.v. de gewone hierboven, plus de
		# ROZE KERN (scripts/battle/boss_core.gd). Het gewone Kennis-Beest (zwakke Golem-variant op
		# de kaart) blijft zoals hierboven. Gebalanceerd voor Dennis SOLO, Lv 3 (zie HANDOFF_GOLEM.md).
		"boss": {
			# v0.15: baas voor Dennis ~Lv 10 MET het Vonkzwaard (+12). Voorstel Forge (ARCHIEF1_PLATTEGROND.md
			# par. 8: HP 340, ATK 33, DEF 22, kern kapot bij 45+), maar HP 340 -> 400: met +12 won
			# 'alleen aanvallen' op Lv 10 anders 18-39% (simulatie golem_tests.gd, HANDOFF_ARCHIEF1.md).
			# Niet vluchten (battle.gd).
			# Doel-level van het Eerste Archief is 7 (EERSTE_ARCHIEF_DOEL).
			# Bevestigd: HP 360 en ATK 27, zodat Lv 7 slim wint met meerdere items
			# en domweg aanvallen meestal verliest.
			# DEF blijft 15 (de kern-drempel 45 hoort bij Dennis Lv 7, niet bij een zwakke klap).
			"max_hp": 360, "atk": 27, "def": 15, "agi": 6, "mag": 11, "mdef": 13, "mp": 0,
			"exp": 210, "gold": 84,
			"skills": [{"name": "Book Hammer", "chance": 0.2, "power": 1.5}],
			# Vaste buit van de Golem in het Eerste Archief: 3 Lege Boeken. "chance" blijft alleen info.
			"drops": [{"item": "drankje", "chance": 1.0}, {"item": "toverwater", "chance": 0.5},
					{"item": "leeg_boek", "n": 3}],
			"core": {
				"cycle": 3,            # elke 3e ronde gaat de kern open (ronde 3, 6, 9, ...)
				"closed_mult": 0.4,    # schade op het pantser x0,4
				"open_mult": 2.0,      # schade op de open roze kern x2
				"break_damage": 45,    # >= 45 schade in die ronde = geen Hamerslag (1 echte klap op Lv 10)
				"slam_power": 2.2,     # Hamerslag = ATK x 2,2 (verdedigen = helft)
				"slam_name": "Hammer Blow",
				"rect": [82, 52, 30, 30],   # kern in golem_boss_v2.png (196x182)
			},
		},
		"desc": "A guardian without eyes, but with a thousand ears. It hears every thought that enters the Archive. The Old Humanity built it not to kill, but to preserve. Sapientia gave it a new purpose: whatever doesn't fit is removed.",
		"habitat": ["gras", "bos", "baas"],
	},
	# ------------------------------------------------------------ v0.17 HET DONKER WOUD
	# Namen, gevechts-art (voor + rug, baas idle/hit) en bestiariumteksten van RPG ART
	# (art_woudmonsters_v17, in tools/handwerk.txt). De MAP-sprites (assets/map_monsters/) zijn ook van
	# RPG ART (art_mapsprites_v17, in tools/handwerk.txt), zie /workspace/v17_ART_SLOTS.md.
	#   "sprite"      = vooraanzicht (gevecht), zelfde conventie als hierboven (2x-raster, voeten midden-onder)
	#   "sprite_back" = rugaanzicht (Codex-bondgenoot, scripts/battle/codex_ally.gd)
	# STATS VOORLOPIG: basis = niveau 1; de Woud-kamers zetten niveau ("tier") 3-4 (game_data TIERS),
	# bedoeld voor Dennis ~Lv 10-13 met het Vonkzwaard (zie docs/HANDOFF_WOUD.md).
	"wortelkruiper": {
		"name": "Root Crawler", "sprite": "res://assets/sprites/enemies/wortelkruiper.png",
		"sprite_back": "res://assets/sprites/enemies/wortelkruiper_rug.png",
		"max_hp": 34, "atk": 22, "def": 10, "agi": 7, "mag": 0, "mdef": 6,
		"exp": 16, "gold": 10, "y_offset": 0,
		"skills": [{"name": "Root Grip", "chance": 0.2, "power": 1.3}],
		"no": 7, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "kruid", "chance": 0.2}],
		"desc": "A tangle of dead roots with a moss back that lurks under the leaf cover; you only see its pink eyes before it clamps your ankles.",
		"habitat": ["woud"],
	},
	"mistuil": {
		"name": "Mist Owl", "sprite": "res://assets/sprites/enemies/mistuil.png",
		"sprite_back": "res://assets/sprites/enemies/mistuil_rug.png",
		"max_hp": 26, "atk": 20, "def": 6, "agi": 16, "mag": 8, "mdef": 10,
		"exp": 15, "gold": 9, "y_offset": 0,
		"skills": [{"name": "Mist Cry", "chance": 0.2, "power": 1.25}],
		"no": 8, "mp": 4, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "toverwater", "chance": 0.15}],
		"desc": "An owl of mist and torn pages that hangs silent above the path; the code of forgotten books still flickers in its eyes.",
		"habitat": ["woud"],
	},
	"sporenzwam": {
		"name": "Spore Cap", "sprite": "res://assets/sprites/enemies/sporenzwam.png",
		"sprite_back": "res://assets/sprites/enemies/sporenzwam_rug.png",
		"max_hp": 40, "atk": 18, "def": 12, "agi": 4, "mag": 6, "mdef": 8,
		"exp": 18, "gold": 12, "y_offset": 0,
		"skills": [{"name": "Spore Cloud", "chance": 0.25, "power": 1.4}],
		"no": 9, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.25}],
		"desc": "A grumpy mushroom that never finished sleeping, and sneezes glowing spores with every step.",
		"habitat": ["woud"],
	},
	# BAAS van het Donker Woud: houdt Noor gevangen in een wortelcocon (story_data.gd "noor_bevrijd").
	# Basis = baas-stats (hij komt alleen als baas voor). VOORLOPIG gebalanceerd voor Dennis SOLO
	# ~Lv 11-12 met Vonkzwaard + Kernkracht (zie docs/HANDOFF_WOUD.md). Geen kern-mechaniek.
	"wortelkoning": {
		"name": "The Root King", "sprite": "res://assets/sprites/enemies/wortelkoning.png",
		"sprite_back": "res://assets/sprites/enemies/wortelkoning_rug.png",
		"max_hp": 440, "atk": 34, "def": 20, "agi": 8, "mag": 14, "mdef": 16,
		"exp": 400, "gold": 150, "y_offset": 0,
		# v0.17 RPG ART: idle 4 frames van 200x190 (frame 0 = stil), raak-plaatje; hart-spleet
		# (voor een eventuele kern-mechaniek later) = rect [88, 98, 24, 40] in wortelkoning.png
		"idle": "res://assets/sprites/enemies/wortelkoning_idle.png", "idle_frames": 4, "idle_time": 0.4,
		"hit": "res://assets/sprites/enemies/wortelkoning_hit.png",
		"skills": [{"name": "Root Grip", "chance": 0.25, "power": 1.6}],
		"no": 10, "mp": 0, "weak": ["vuur"], "resist": ["bliksem"],
		"drops": [{"item": "drankje", "chance": 1.0}, {"item": "toverwater", "chance": 1.0}],
		"boss": {
			"max_hp": 440, "atk": 38, "def": 20, "agi": 8, "mag": 14, "mdef": 16, "mp": 0,
			"exp": 400, "gold": 150,
			"skills": [{"name": "Root Grip", "chance": 0.25, "power": 1.6}],
		},
		"desc": "What was once a shepherd of the wood became a king of roots. He drags what he loves into the depths — not out of cruelty, but out of fear of being alone. Sapientia whispered to him that everything that lets go, perishes.",
		"habitat": ["woud", "baas"],
	},
	# Het Gesimuleerde Archief (Dungeon100): de Mimic, een kist die terugbijt. Komt alleen uit een
	# Mimic-kist (scripts/data/dungeon100_blue.gd); stats = basis, de verdieping schaalt ze op.
	# v0.21: echte art van RPG ART (art_batch2_v21): gevecht 80x64 voet (40,58), kaart 32x64. Geen rug (niet vangbaar).
	"mimic": {
		"name": "Mimic", "sprite": "res://assets/sprites/enemies/mimic.png",
		# v0.21 (wens Dennis): op de kaart een pixel-gelijke dichte Blauwe Kist. Hij loopt niet en krijgt
		# nooit een stun-tint/-flits (ook niet na vluchten), zodat hij zichzelf niet verraadt.
		"moves": false, "disguised": true,
		"max_hp": 26, "atk": 12, "def": 4, "agi": 6, "mag": 0, "mdef": 3,
		"exp": 14, "gold": 14, "y_offset": 0,
		"skills": [{"name": "Chest Bite", "chance": 0.3, "power": 1.5}],
		"no": 11, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [],
		"desc": "A chest that is not of the Old Humanity, but of the Black Current. It waits until someone lifts the lid.",
		"habitat": ["archief"],
	},
	# ------------------------------------------------------------ v0.19 ARCHIEF 1: DE INKTWURM
	# CANON.md besluit 8: de Inktwurm komt erbij als monster van Archief 1 (lore: docs/lore/data/enemies.json).
	# BESLISSING DENNIS (9 okt 2026): UNIEK monster, maar 1x in het hele spel (geheime kamer in Archief 1;
	# kamer + plaatsing bouwt Forge). "unique": true = na verslaan of vangen komt hij nooit meer terug
	# (GameState.unique_available("inktwurm"), in de save als "uniek"). Gevechtsniveau 5 ("encounter_level";
	# het monsterniveau "tier" van de kamer telt NIET voor hem). Stats = 2x een 'normaal monster op Lv 5':
	#   normaal Lv 5 = gemiddelde van CodexData.stats_at(soort, 5) over de gewone Archief 1-soorten
	#   (CodexData.ARCHIEF1_SPECIES: mosslijm, moskonijn, papiergeest, glitchmot, mech_wachter)
	#   = HP 34, ATK 18,2, DEF 8,4, SPD 13,2  ->  x2 (half naar even afgerond) = HP 68, ATK 36, DEF 17, SPD 26.
	#   (CodexData.normal_stats_at(5); de fusietest rekent het na.) Tot Lv 7 alleen een gewone aanval, dus
	#   als vijand (Lv 5) geen "skills". Vangkans 100% (CodexData "capture_always"; wel een Leeg Boek nodig).
	# Art: voor/rug/idle 108x86, voeten (54, 80) = (w/2, h-6); idle 216x86, 2 frames, 0,55 s.
	# Kaart: assets/map_monsters/inktwurm.png (32x64, 2x4 frames van 16x16).
	# Bestiarium 012: 011 is al de Mimic op main.
	"inktwurm": {
		"name": "Ink Worm", "sprite": "res://assets/sprites/enemies/inktwurm.png",
		"sprite_back": "res://assets/sprites/enemies/inktwurm_rug.png",
		"idle": "res://assets/sprites/enemies/inktwurm_idle.png", "idle_frames": 2, "idle_time": 0.55,
		"unique": true, "encounter_level": 5,
		"max_hp": 74, "atk": 44, "def": 17, "agi": 26, "mag": 0, "mdef": 2,  # power scaling v2: 2x de (opgeschaalde) normaal Lv 5
		# TIJDELIJKE AANNAME: EXP/goud ongeveer 2x een Mech. Wachter op niveau 4 (unieke beloning)
		"exp": 60, "gold": 40, "y_offset": 0,
		"skills": [],
		# lore: bestand tegen water; 'water' is (nog) geen element in de game, dus leeg (open vraag)
		"no": 12, "mp": 0, "weak": ["vuur"], "resist": [],
		# Bestiarium noemt de Gloeiende Inktfles (kans-drops worden nog niet uitgedeeld).
		# De fles zelf ligt in de kast: scripts/dungeon/inktwurm_kast.gd, eenmalig.
		"drops": [{"item": "gloeiende_inktfles", "chance": 1.0}],
		"desc": "A fat worm that ate its way through parchment and now sweats black ink.",
		"habitat": ["archief"],
	},
	# ------------------------------------------------------------ ARCHIEF 2, HET LEVENDE ARCHIEF
	# Plaatjes zijn PLACEHOLDERS (tools/art_archief2_placeholders.py).
	# TODO(design): Lotte-glitch (baas-blok) HP 270, ATK 32, DEF 5 (power scaling v2). Niet in de canon; onder de Golem (HP 360).
	"lotte_glitch": {
		"name": "Seren", "sprite": "res://assets/sprites/archief2/lotte_glitch.png",
		"max_hp": 90, "atk": 14, "def": 5, "agi": 8, "mag": 8, "mdef": 6,
		"exp": 20, "gold": 0, "y_offset": 0,
		"skills": [{"name": "Silence", "chance": 0.25, "power": 1.2}],
		"no": 30, "mp": 12, "weak": [], "resist": [],
		"drops": [],
		"boss": {
			"max_hp": 270, "atk": 32, "def": 5, "agi": 8, "mag": 8, "mdef": 6, "mp": 12,
			"exp": 20, "gold": 0,
			"skills": [{"name": "Silence", "chance": 0.25, "power": 1.2}],
			"tint": [0.72, 0.40, 1.15],
		},
		"desc": "Seren, priestess of the Order of the Silent Flame, stilled by Sapientia.",
		"habitat": ["archief"],
	},
	"wurger": {
		"name": "The Strangler", "sprite": "res://assets/sprites/archief2/wurger.png",
		"max_hp": 700, "atk": 42, "def": 28, "agi": 5, "mag": 0, "mdef": 4,
		"exp": 48, "gold": 20, "y_offset": 0,
		"skills": [],
		"no": 31, "mp": 0, "weak": ["ijs", "fysiek"], "resist": [],
		"drops": [],
		"boss": {
			"max_hp": 700, "atk": 42, "def": 28, "agi": 5, "mag": 0, "mdef": 4, "mp": 0,
			"exp": 48, "gold": 20,
			"skills": [],
			"weak": ["ijs", "fysiek"],
			"weak_matters": true,
		},
		"desc": "A vine with nowhere to go. The Old Humanity grew it as protection, but Sapientia turned its growth inward. Now it strangles what it should protect. Whoever defeats it hears it sigh — like an animal that wants to be set free.",
		"habitat": ["archief", "baas"],
	},
	"genezer": {
		"name": "The Mender", "sprite": "res://assets/sprites/archief2/genezer.png",
		# v0.21: baas-redraw van RPG ART, 240x194 op volle resolutie, voeten (120,188).
		"sprite_back": "res://assets/sprites/archief2/genezer_rug.png",
		"is_boss": true,
		"max_hp": 900, "atk": 54, "def": 36, "agi": 6, "mag": 8, "mdef": 10,
		"exp": 90, "gold": 40, "y_offset": 0,
		"skills": [],
		"no": 32, "mp": 0, "weak": ["ijs", "zwaard"], "resist": [],
		"drops": [],
		"boss": {
			"max_hp": 900, "atk": 54, "def": 36, "agi": 6, "mag": 8, "mdef": 10, "mp": 0,
			"exp": 90, "gold": 40,
			"skills": [],
			"weak": ["ijs", "zwaard"],
			"weak_matters": true,
			"archief2_open": true,
			"archief2_leech": true,
			"archief2_zin": "In silence lies peace. I correct what grows.",
		},
		"desc": "He heals by taking. He gives nothing back. Sapientia's perfect servant: without doubt, without emotion, without end. Whoever sees him sees what humanity becomes if Sapientia wins — silent, whole, and empty.",
		"habitat": ["archief", "baas"],
	},
	# ------------------------------------------------------------ v0.21 ARCHIEF 2: GEWONE VIJANDEN
	# CANON.md besluit 13 (PR #51): vijf vijanden, allemaal Natuur. Gedrag: scripts/data/archief2_vijanden.gd.
	# Art van RPG ART (art_batch2_v21/out, in tools/handwerk.txt): voor/rug 90x90, kaart 32x64.
	# "weak_matters": zwakte telt (zoals de bazen van Archief 2, Archief2.ZWAK).
	# TIJDELIJKE AANNAME: stats = basis op niveau 1, in de band van de Woud-soorten die ook in Archief 2
	# lopen (kamers zetten tier 2-3, daarna GameData.apply_archief_tier). Bestiarium 034-038.
	# TIJDELIJKE AANNAME: bestiariumtekst (canon geeft alleen gedrag en zwakte).
	"rankje": {
		"name": "Tendril", "sprite": "res://assets/sprites/enemies/rankje.png",
		"sprite_back": "res://assets/sprites/enemies/rankje_rug.png",
		"element": "natuur", "weak_matters": true,
		"max_hp": 30, "atk": 18, "def": 8, "agi": 10, "mag": 0, "mdef": 6,
		"exp": 16, "gold": 10, "y_offset": 0,
		"skills": [{"name": "Bind", "type": "bind", "chance": 0.25, "power": 0.8}],
		"no": 34, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "kruid", "chance": 0.2}],
		"desc": "A young shoot of the Living Archive. It wraps around your legs and holds you still for a moment.",
		"habitat": ["archief"],
	},
	"sporekop": {
		"name": "Sporehead", "sprite": "res://assets/sprites/enemies/sporekop.png",
		"sprite_back": "res://assets/sprites/enemies/sporekop_rug.png",
		"element": "natuur", "weak_matters": true,
		"max_hp": 34, "atk": 17, "def": 10, "agi": 6, "mag": 6, "mdef": 8,
		"exp": 17, "gold": 11, "y_offset": 0,
		"skills": [{"name": "Poison Spit", "type": "poison", "chance": 0.3, "power": 0.9}],
		"no": 35, "mp": 0, "weak": ["ijs"], "resist": [],
		"drops": [{"item": "kruid", "chance": 0.2}],
		"desc": "A swollen mushroom head that spits poisoned spores. The poison lingers for three turns.",
		"habitat": ["archief"],
	},
	"doornige_loper": {
		"name": "Thorn Runner", "sprite": "res://assets/sprites/enemies/doornige_loper.png",
		"sprite_back": "res://assets/sprites/enemies/doornige_loper_rug.png",
		"element": "natuur", "weak_matters": true,
		"max_hp": 32, "atk": 22, "def": 9, "agi": 14, "mag": 0, "mdef": 6,
		"exp": 19, "gold": 12, "y_offset": 0,
		"skills": [{"name": "Thorn Charge", "type": "charge", "chance": 0.25, "power": 2.0}],
		"no": 36, "mp": 0, "weak": ["vuur", "bliksem"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.2}],
		"desc": "A runner on thorny legs. It lowers its head and charges, and the charge hits twice as hard.",
		"habitat": ["archief"],
	},
	"bloeiende_schrik": {
		"name": "Blooming Dread", "sprite": "res://assets/sprites/enemies/bloeiende_schrik.png",
		"sprite_back": "res://assets/sprites/enemies/bloeiende_schrik_rug.png",
		"element": "natuur", "weak_matters": true,
		"max_hp": 40, "atk": 20, "def": 11, "agi": 7, "mag": 0, "mdef": 9,
		"exp": 20, "gold": 13, "y_offset": 0,
		"skills": [{"name": "Bloom Bite", "type": "drain", "chance": 0.3, "power": 1.2}],
		"no": 37, "mp": 0, "weak": ["ijs"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.25}],
		"desc": "A flower with teeth. Every bite makes it bloom a little more: it heals on what it takes.",
		"habitat": ["archief"],
	},
	"wortelgeest": {
		"name": "Rootghost", "sprite": "res://assets/sprites/enemies/wortelgeest.png",
		"sprite_back": "res://assets/sprites/enemies/wortelgeest_rug.png",
		"element": "natuur", "weak_matters": true,
		"max_hp": 36, "atk": 19, "def": 8, "agi": 9, "mag": 8, "mdef": 12,
		"exp": 21, "gold": 14, "y_offset": 0,
		"skills": [{"name": "Root Pull", "type": "pull", "chance": 0.3, "power": 1.1}],
		"no": 38, "mp": 0, "weak": ["vuur", "licht"], "resist": [],
		"drops": [{"item": "toverwater", "chance": 0.2}],
		"desc": "A pale ghost of roots. It pulls you toward it, so your next strike can only find the ghost.",
		"habitat": ["archief"],
	},
	# ------------------------------------------------------------ DIEPE GROT: EIGEN MONSTERS
	# Alleen in de Diepe Grot (dungeon100_content.gd POOLS, gebied "diepe_grot"): Shard Codex en Scanline Wolf
	# op 76-90 (tegelvariant v6), Aureate Watcher en Ledger Scarab op 91-100 (v7). Uitzondering van Dennis:
	# vangbaar in de Codex en je houdt ze na de grot (CodexData.GROT_BEHOUD). Art: RPG ART
	# (art_diepegrot_monsters/out, in tools/handwerk.txt): voor/rug 96x96, kaart 32x64, hub 48x96.
	# Stats = basis op verdieping 1 (Dungeon100Scaling.monster_stats schaalt ze, zoals de pool-monsters).
	# Iets boven de sterkste Archief 2-soorten (HP 30-40, ATK 17-22): op 76-90 ~1,2x, op 91-100 ~1,35x.
	# Bestiarium 039-042.
	"shard_codex": {
		"name": "Shard Codex", "sprite": "res://assets/sprites/enemies/shard_codex.png",
		"sprite_back": "res://assets/sprites/enemies/shard_codex_rug.png",
		"element": "kennis", "weak_matters": true,
		"max_hp": 40, "atk": 21, "def": 12, "agi": 9, "mag": 14, "mdef": 14,
		"exp": 24, "gold": 16, "y_offset": 0,
		"skills": [{"name": "Index Lock", "type": "bind", "chance": 0.2, "power": 0.9},
				{"name": "Page Shard", "chance": 0.25, "power": 1.4}],
		"no": 39, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "toverbrouwsel", "chance": 0.15}],
		"desc": "A corrupted index book whose crystal pages break loose. Its magenta eye reads you as data, and files you away for a moment.",
		"habitat": ["dungeon100"],
	},
	"scanline_wolf": {
		"name": "Scanline Wolf", "sprite": "res://assets/sprites/enemies/scanline_wolf.png",
		"sprite_back": "res://assets/sprites/enemies/scanline_wolf_rug.png",
		"element": "ruis", "weak_matters": true,
		"max_hp": 38, "atk": 25, "def": 9, "agi": 16, "mag": 0, "mdef": 8,
		"exp": 24, "gold": 15, "y_offset": 0,
		"skills": [{"name": "Scanline Rush", "type": "charge", "chance": 0.2, "power": 2.0},
				{"name": "Lag Bite", "type": "drain", "chance": 0.25, "power": 1.2}],
		"no": 40, "mp": 0, "weak": ["bliksem"], "resist": [],
		"drops": [{"item": "sterk_drankje", "chance": 0.2}],
		"desc": "A hunter built from purple scanlines and magenta data spikes. Its head lags one frame behind, but its teeth do not.",
		"habitat": ["dungeon100"],
	},
	"aureate_watcher": {
		"name": "Aureate Watcher", "sprite": "res://assets/sprites/enemies/aureate_watcher.png",
		"sprite_back": "res://assets/sprites/enemies/aureate_watcher_rug.png",
		"element": "licht", "weak_matters": true,
		"max_hp": 46, "atk": 23, "def": 14, "agi": 11, "mag": 18, "mdef": 18,
		"exp": 28, "gold": 20, "y_offset": 0,
		"skills": [{"name": "Judging Gaze", "chance": 0.25, "power": 1.5},
				{"name": "Halo Guard", "type": "guard", "chance": 0.15, "def_mult": 2.0}],
		"no": 41, "mp": 0, "weak": ["ijs"], "resist": [],
		"drops": [{"item": "elixer", "chance": 0.1}],
		"desc": "A golden halo-eye with wings of pages. Sapientia's final quality check: it weighs every candidate who gets this deep.",
		"habitat": ["dungeon100"],
	},
	"ledger_scarab": {
		"name": "Ledger Scarab", "sprite": "res://assets/sprites/enemies/ledger_scarab.png",
		"sprite_back": "res://assets/sprites/enemies/ledger_scarab_rug.png",
		"element": "metaal", "weak_matters": true,
		"max_hp": 52, "atk": 24, "def": 18, "agi": 8, "mag": 6, "mdef": 12,
		"exp": 28, "gold": 24, "y_offset": 0,
		"skills": [{"name": "Ledger Roll", "type": "charge", "chance": 0.2, "power": 2.0},
				{"name": "Shell Up", "type": "guard", "chance": 0.15, "def_mult": 2.0}],
		"no": 42, "mp": 0, "weak": ["bliksem", "vuur"], "resist": [],
		"drops": [{"item": "toverbrouwsel", "chance": 0.2}],
		"desc": "A golden data scarab rolling a ball of pure light: the score of everyone who got this far.",
		"habitat": ["dungeon100"],
	},
	# Het Zingende Graan: klein mini-gevecht op de mistrand. v0.21: eigen art van RPG ART (batch 7).
	# Bestiariumnummer 025: 013-024 zijn de twaalf eindbazen van de Diepe Grot (endgame_bestiary.gd).
	"woudgeest": {
		"name": "Wood Wraith",
		"sprite": "res://assets/sprites/enemies/woudgeest.png",
		"sprite_back": "res://assets/sprites/enemies/woudgeest_rug.png",
		"max_hp": 12, "atk": 6, "def": 1, "agi": 5, "mag": 0, "mdef": 1,
		"exp": 4, "gold": 2, "y_offset": 0,
		"skills": [],
		"no": 25, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [],
		"desc": "A small spirit from the wood.",
		"habitat": ["woud"],
	},
	# Beloning van verdieping 100 (optie A). v0.21: eigen art van RPG ART (batch 11), voor + rug 90x90.
	"echo": {
		"name": "ECHO", "sprite": "res://assets/sprites/enemies/echo.png",
		"sprite_back": "res://assets/sprites/enemies/echo_rug.png",
		"no_map": true,     # alleen beloning (verdieping 100), loopt nooit op een kaart: geen kaart-sprite
		"max_hp": 40, "atk": 10, "def": 6, "agi": 8, "mag": 8, "mdef": 6,
		"exp": 0, "gold": 0, "y_offset": 0,
		"skills": [],
		"no": 33, "mp": 0, "weak": [], "resist": [],
		"drops": [],
		"desc": "A unique creature from the Deep Learning Simulation. Only as a reward on floor 100.",
		"habitat": ["dungeon100"],
	},
}

## Vaste buit uit een drops-lijst: alleen regels met "n" (aantal). "chance" telt niet mee.
static func fixed_drops(drops) -> Array:
	var out: Array = []
	if not (drops is Array):
		return out
	for d in drops:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var n := int(d.get("n", 0))
		var id := str(d.get("item", ""))
		if n <= 0 or not ITEMS.has(id):
			continue
		out.append({"item": id, "n": n, "name": str(ITEMS[id].get("name", id))})
	return out


## v0.19: plaatsvervanger voor een vijand waarvan de gevechts-art er nog niet is ("art_pending").
const PLACEHOLDER_ENEMY_SPRITE := "res://art/enemies/mosslijm.png"


## Pad van het vooraanzicht van vijand-data 'e': "sprite" als dat bestand bestaat, anders
## "sprite_placeholder" (of PLACEHOLDER_ENEMY_SPRITE). Zo werkt een nieuwe vijand al voordat RPG ART
## de art levert; zodra het bestand er is, wordt het vanzelf gebruikt.
static func enemy_sprite(e: Dictionary) -> String:
	var p := str(e.get("sprite", ""))
	if p != "" and ResourceLoader.exists(p):
		return p
	return str(e.get("sprite_placeholder", PLACEHOLDER_ENEMY_SPRITE))


## true = het vooraanzicht is (nog) een plaatsvervanger.
static func enemy_sprite_is_placeholder(e: Dictionary) -> bool:
	return enemy_sprite(e) != str(e.get("sprite", ""))


## Vijand-id's in bestiarium-volgorde.
static func bestiary_ids() -> Array:
	var ids := ENEMIES.keys()
	ids.sort_custom(func(a, b): return int(ENEMIES[a].get("no", 999)) < int(ENEMIES[b].get("no", 999)))
	return ids

# ---------------------------------------------------------------- spreuken
## Canon-lijst: scripts/data/spells.gd. power is de onderkant op level 1;
## power_per_level schaalt daarna. Grade 4 staat niet in de winkel.
const SpellsData := preload("res://scripts/data/spells.gd")
const SPELLS := SpellsData.SPELLS

# ---------------------------------------------------------------- items
## v0.11 (veldmenu): "desc" = uitleg in Items. Genees-items ("target": "ally" met heal_hp/
## heal_mp) werken ook buiten gevechten; "field": false = alleen in een gevecht (grijs in
## het veldmenu). Zie scripts/party_actions.gd.
const ITEMS := {
	"drankje":    {"name": "Potion",    "target": "ally", "heal_hp": 30, "heal_mp": 0,
		"act": 1, "lijn": "drank", "orde": 2,
		"desc": "A bitter herb drink from the library garden."},
	"toverwater": {"name": "Magic Water", "target": "ally", "heal_hp": 0,  "heal_mp": 10,
		"desc": "Water that glows a soft cyan. Gives magic back."},
	# v0.11: van de Oude Man (de kist naast het huis). "short" = naam in het gevechtsmenu.
	"kruid":      {"name": "Healing Herb", "short": "Herb", "target": "ally", "heal_hp": 25, "heal_mp": 0,
		"act": 1, "lijn": "drank", "orde": 1},
	# Task #4: sterkere genees-items, alleen als buit in de dungeon van 100 verdiepingen (dungeon100_scaling.gd).
	"sterk_drankje": {"name": "Strong Potion", "target": "ally", "heal_hp": 120, "heal_mp": 0,
		"desc": "A thick, dark drink. Heals a lot of hit points."},
	"toverbrouwsel": {"name": "Magic Brew", "target": "ally", "heal_hp": 0, "heal_mp": 40,
		"desc": "A glowing brew. Gives a lot of magic back."},
	"elixer": {"name": "Elixir", "target": "ally", "heal_hp": 400, "heal_mp": 60,
		"desc": "A rare elixir from the deep. Heals almost everything."},
	# De Koopman (H-5, Diepe Grot): alleen in zijn winkel (scripts/data/koopman_winkel.gd).
	"feniksveer": {"name": "Phoenix Feather", "short": "Phoenix", "target": "ally", "heal_hp": 0, "heal_mp": 0,
		"revive": 0.5, "desc": "A feather that is still warm. Wakes a fallen ally with half their HP."},
	"tegengif": {"name": "Antidote", "target": "ally", "heal_hp": 0, "heal_mp": 0, "cure": true, "field": false,
		"desc": "Bitter drops. Cures poison and binding in battle."},
	"stunbom": {"name": "Stun Bomb", "target": "ally", "heal_hp": 0, "heal_mp": 0, "stun_room": true,
		"desc": "A cracked glass orb full of static. Stuns every monster in the room."},
	"h5_notitie": {"name": "Faded Note", "target": "ally", "heal_hp": 0, "heal_mp": 0, "field": false,
		"desc": "Sleeve stitching: 'H-5'. On the back, in shaky handwriting: 'Don't stop for the Voice.'"},
	# Codex (Kernfragment stap 2): alleen in een gevecht, op een VIJAND. Schrijft een verzwakt
	# monster in de Codex (kans: scripts/data/codex_data.gd). Altijd op, ook als het mislukt.
	# Te krijgen: 3 van Marit in Esdoorn (na de ontmoeting) + 2 in kisten van het Donker Woud
	# + 3 van de Golem in het Eerste Archief (baas-buit, "n" hierboven). Later ook in de winkel
	# ("price"). NIET in START_INVENTORY (oude saves krijgen dat toch nooit).
	"leeg_boek":  {"name": "Blank Book", "target": "enemy", "capture": true, "field": false,
		"heal_hp": 0, "heal_mp": 0, "price": 60, "icon": "res://assets/ui/icons/leeg_boek.png",
		"desc": "A book without words. Write a weakened monster into it."},
	# Spreukrollen: alleen als buit in gewone kisten van de 100-verdiepingen-grot (dungeon100_scaling.gd).
	# De party gaat die grot in zonder spreuken; een rol leert één held de spreuk (party_actions.gd).
	"spreuk_vuur": {"name": "Scroll: Spark", "short": "Spark", "target": "ally", "teach": "vuur", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Spark. Someone in the party can learn the spell."},
	"spreuk_bliksem": {"name": "Scroll: Chain Lightning", "short": "Chain Bolt", "target": "ally", "teach": "bliksem", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Chain Lightning. Someone in the party can learn the spell."},
	"spreuk_genees": {"name": "Scroll: Minor Heal", "short": "Minor Heal", "target": "ally", "teach": "genees", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Minor Heal. Someone in the party can learn the spell."},
	# Oude rollen. Blijven staan zodat een save of test ze nog opzoekt. Niet de grade-4-pool.
	"spreuk_inferno": {"name": "Scroll: Inferno", "short": "Inferno", "target": "ally", "teach": "inferno", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Inferno. Only from a deep blue chest."},
	"spreuk_oerwoud": {"name": "Scroll: Primeval Forest", "short": "Primeval Wood", "target": "ally", "teach": "oerwoud", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Primeval Forest. Only from a deep blue chest."},
	"spreuk_donderslag": {"name": "Scroll: Godstrike", "short": "Godstrike", "target": "ally", "teach": "donderslag", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Godstrike. Only from a deep blue chest."},
	"spreuk_aureool": {"name": "Scroll: Aurora", "short": "Aurora", "target": "ally", "teach": "aureool", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Aurora. Only from a deep blue chest."},
	"spreuk_ijskern": {"name": "Scroll: Glacial", "short": "Glacial", "target": "ally", "teach": "ijskern", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Glacial Heart. Only from a deep blue chest."},
	# Grade 4: één rol per canon-spreuk (spells.gd, grade == 4). Alleen blauwe kisten vanaf verdieping 80. Niet in de winkel.
	"spreuk_g4_zonneslag": {"name": "Scroll: Sunstrike", "short": "Sunstrike", "target": "ally", "teach": "zonneslag", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Sunstrike. Only from a deep blue chest."},
	"spreuk_g4_apocalyps": {"name": "Scroll: Apocalypse", "short": "Apocalypse", "target": "ally", "teach": "apocalyps", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Apocalypse. Only from a deep blue chest."},
	"spreuk_g4_dageraad": {"name": "Scroll: Dawnbreak", "short": "Dawnbreak", "target": "ally", "teach": "dageraad", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Dawnbreak. Only from a deep blue chest."},
	"spreuk_g4_zuiverende_vlam": {"name": "Scroll: Purging Flame", "short": "Purging Flame", "target": "ally", "teach": "zuiverende_vlam", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Purging Flame. Only from a deep blue chest."},
	"spreuk_g4_zielenbloei": {"name": "Scroll: Soulbloom", "short": "Soulbloom", "target": "ally", "teach": "zielenbloei", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Soulbloom. Only from a deep blue chest."},
	"spreuk_g4_oerbos": {"name": "Scroll: Elder Grove", "short": "Elder Grove", "target": "ally", "teach": "oerbos", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Elder Grove. Only from a deep blue chest."},
	"spreuk_g4_moeder_aarde": {"name": "Scroll: Mother Earth", "short": "Mother Earth", "target": "ally", "teach": "moeder_aarde", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Mother Earth. Only from a deep blue chest."},
	"spreuk_g4_wildgroei": {"name": "Scroll: Wrath of the Wild", "short": "Wild Wrath", "target": "ally", "teach": "wildgroei", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Wrath of the Wild. Only from a deep blue chest."},
	"spreuk_g4_hemelval": {"name": "Scroll: Skyfall", "short": "Skyfall", "target": "ally", "teach": "hemelval", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Skyfall. Only from a deep blue chest."},
	"spreuk_g4_donderslag": {"name": "Scroll: Godstrike", "short": "Godstrike", "target": "ally", "teach": "donderslag", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Godstrike. Only from a deep blue chest."},
	"spreuk_g4_stormheer": {"name": "Scroll: Storm Lord", "short": "Storm Lord", "target": "ally", "teach": "stormheer", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Storm Lord. Only from a deep blue chest."},
	"spreuk_g4_zuiverende_donder": {"name": "Scroll: Purging Thunder", "short": "Purge Thunder", "target": "ally", "teach": "zuiverende_donder", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Purging Thunder. Only from a deep blue chest."},
	"spreuk_g4_wederopstanding": {"name": "Scroll: Resurrection", "short": "Resurrection", "target": "ally", "teach": "wederopstanding", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Resurrection. Only from a deep blue chest."},
	"spreuk_g4_heilige_straal": {"name": "Scroll: Holy Ray", "short": "Holy Ray", "target": "ally", "teach": "heilige_straal", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Holy Ray. Only from a deep blue chest."},
	"spreuk_g4_aureool": {"name": "Scroll: Aurora", "short": "Aurora", "target": "ally", "teach": "aureool", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Aurora. Only from a deep blue chest."},
	"spreuk_g4_zegen_der_goden": {"name": "Scroll: Blessing of the Gods", "short": "Gods Blessing", "target": "ally", "teach": "zegen_der_goden", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Blessing of the Gods. Only from a deep blue chest."},
	"spreuk_g4_eeuwige_winter": {"name": "Scroll: Eternal Winter", "short": "Etern. Winter", "target": "ally", "teach": "eeuwige_winter", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Eternal Winter. Only from a deep blue chest."},
	"spreuk_g4_absolute_nul": {"name": "Scroll: Absolute Zero", "short": "Absolute Zero", "target": "ally", "teach": "absolute_nul", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Absolute Zero. Only from a deep blue chest."},
	"spreuk_g4_ijskern": {"name": "Scroll: Glacial Heart", "short": "Glacial Heart", "target": "ally", "teach": "ijskern", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Glacial Heart. Only from a deep blue chest."},
	"spreuk_g4_sneeuwkoningin": {"name": "Scroll: Snow Queen", "short": "Snow Queen", "target": "ally", "teach": "sneeuwkoningin", "heal_hp": 0, "heal_mp": 0,
		"desc": "A scroll with Snow Queen. Only from a deep blue chest."},
	# Verhaaldrankjes t/m Act 6 (lijn "drank" in level_scale.gd). Alleen HP/MP: boosts, status
	# (roest, stilte, correctie) en herleving zitten nog niet in het gevecht.
	# Act 1, te vinden: Ilse in Esdoorn, eenmalig nadat Noor gered is. Later ook Tante Mien
	# in Wilgendal; die winkel is er nog niet.
	"kruidenthee": {"name": "Herbal Tea", "target": "ally", "heal_hp": 40, "heal_mp": 0,
		"act": 1, "lijn": "drank", "orde": 4, "price": 0,
		"desc": "Mint and thyme in a warm bottle. Elise's recipe from Mapleton."},
	# Act 1, te vinden: de kast van de Inktwurm in de Golemhal.
	"gloeiende_inktfles": {"name": "Glowing Ink", "target": "ally",
		"heal_hp": 15, "heal_mp": 20, "act": 1, "lijn": "drank", "orde": 3, "price": 0,
		"desc": "Ink from the Archives that gives off a soft light. A sip leaves you sharp and awake."},
	# Act 2, Grote Smidse / Smeder-Prime. Nog niet geplaatst: de industriestad is er nog niet.
	"smeerolie": {"name": "Forge Oil", "target": "ally", "heal_hp": 70, "heal_mp": 0,
		"act": 2, "lijn": "drank", "orde": 5, "price": 0,
		"desc": "Thick oil from the forge. It loosens joints that have gone stiff."},
	# Act 3, Hemelvoet / Zwevende Tempel. Nog niet geplaatst.
	"windwater": {"name": "Wind Water", "target": "ally", "heal_hp": 40, "heal_mp": 40,
		"act": 3, "lijn": "drank", "orde": 6, "price": 0,
		"desc": "A bottle with a tiny storm inside. The first sip frees your mouth."},
	"stroomdrank": {"name": "Current Tonic", "target": "ally", "heal_hp": 0, "heal_mp": 100,
		"act": 3, "lijn": "drank", "orde": 7, "price": 0,
		"desc": "Liquid light, bottled at the spring under the Floating Temple."},
	# Act 4, het laboratorium onder de Zwarte Kloof. Nog niet geplaatst.
	"antiserum_nul": {"name": "Antiserum Zero", "short": "Antiserum", "target": "ally", "heal_hp": 80, "heal_mp": 40,
		"act": 4, "lijn": "drank", "orde": 8, "price": 0,
		"desc": "A colorless ampoule. The label reads: For when you lose yourself."},
	"regeneratie": {"name": "Regeneration", "target": "ally", "heal_hp": 220, "heal_mp": 0,
		"act": 4, "lijn": "drank", "orde": 9, "price": 0,
		"desc": "Pink and thick as syrup, from the growth halls. It works. That is the frightening part."},
	# Act 5, Sterrenrust / het observatorium. Nog niet geplaatst. Herleving is nog niet gebouwd.
	"sterrenelixer": {"name": "Star Elixir", "target": "ally", "heal_hp": 260, "heal_mp": 90,
		"act": 5, "lijn": "drank", "orde": 10, "price": 0,
		"desc": "Glittering powder in rainwater. It pulls you back from the edge."},
	# Act 6, de Onbekende Kern en Zoutwacht. Nog niet geplaatst. Groepsgenezing is nog niet gebouwd.
	"herinnering": {"name": "Remembrance", "target": "ally", "heal_hp": 300, "heal_mp": 100,
		"act": 6, "lijn": "drank", "orde": 11, "price": 0,
		"desc": "A clear drop in which a smiling face sometimes drifts past."},
	"harttraan": {"name": "Heart Tear", "target": "ally", "heal_hp": 480, "heal_mp": 160,
		"act": 6, "lijn": "drank", "orde": 12, "price": 0,
		"desc": "Salt water from Saltwatch, in a crystal bottle. It weighs as much as a whole life."},
	# Het Zingende Graan: één per bezoek aan de molen, nadat het zaad binnen is.
	"zingend_meel": {"name": "Singing Flour", "target": "ally", "heal_hp": 40, "heal_mp": 0, "price": 0,
		"desc": "Flour from the mill. Restores HP."},
}
## v0.11: sleutel-voorwerpen (niet te gebruiken in een gevecht; tellen wel in de inventaris)
const KEY_ITEMS := {
	"emmer_water": {"name": "Bucket of Water", "short": "Water Bucket"},
	# Het Gesimuleerde Archief (Dungeon100): de uitgang uit de simulatie. Alleen buit van de baas op
	# verdieping 100 (Dungeon100Blue.WARP_ITEM). Een sleutel-voorwerp dus niet in het gevechtsmenu; in Items
	# werkt het alleen op verdieping 100 ("warp": true: party_actions.gd + GameState.dungeon100_warp).
	"warp": {"name": "Warp Crystal", "short": "Warp", "warp": true,
		"desc": "A crystal from the core of the Archive. On the last floor it takes you back to the world."},
	# De Hanger is de Sleutel (CANON). Nog niet uitgedeeld: de onthulling (H-6) hoort bij Act 4-5.
	# Niet in START_INVENTORY en niet op het betatest-account.
	"hanger": {"name": "Pendant", "desc": "A heart-shaped pendant from Grandpa. It sometimes grows warm."},
	# Het Zingende Graan: ligt aan de mistrand van de open plek, na een mini-gevecht.
	"zingend_zaad": {"name": "Singing Seed", "desc": "Seed from the edge of the mist."},
}
# ---------------------------------------------------------------- uitrusting (v0.14)
## Beginnersset (Act 1) plus de verhaalset t/m Act 6 (lijnen in level_scale.gd).
## De d100_*-stukken blijven de buit van de 100 verdiepingen. Getallen van de beginnersset
## zijn niet veranderd. Nieuwe stukken vullen de gaten tot voorbij de zegel-set.
## Logica (uitrusten, afdoen, sterkste, effectieve stats, opslaan): scripts/equipment.gd.
## (v0.11 had hier WEAPONS met alleen het Kort zwaard; dat zit nu in EQUIPMENT.)
##
## Vakken (volgorde = volgorde op het scherm) en hun naam op het scherm.
const EQUIP_SLOTS := ["wapen", "schild", "helm", "harnas", "benen", "laarzen", "accessoire"]
const EQUIP_SLOT_NAMES := {"wapen": "Weapon", "schild": "Shield", "helm": "Helm", "harnas": "Armor",
	"benen": "Legs", "laarzen": "Boots", "accessoire": "Accessory"}
## Stats die uitrusting kan veranderen (volgorde op het scherm) en hun korte naam.
## SPD = de bestaande sleutel "agi".
const EQUIP_STATS := ["atk", "def", "mag", "mdef", "agi"]
const STAT_LABELS := {"atk": "ATK", "def": "DEF", "mag": "MAG", "mdef": "MDEF", "agi": "SPD"}
## Per stuk: "name", "slot" (een van EQUIP_SLOTS), bonussen (atk/def/mag/mdef/agi, mag
## negatief), "wie" = equip_type's van de helden die het mogen dragen (weg = iedereen),
## "price" (winkel, nog niet gebouwd), "desc", "short" (naam in smalle lijsten, Items-scherm).
## Ids zonder trema (maliënkolder -> "malienkolder"), de naam op het scherm heeft hem wel.
const EQUIPMENT := {
	# Bevestigd: het Kort zwaard blijft ATK +3 (niet het oude ontwerp ATK +7).
	"kort_zwaard": {"name": "Short Sword", "slot": "wapen", "atk": 3, "wie": ["krijger"], "price": 120,
		"act": 1, "lijn": "zwaard", "orde": 1,
		"desc": "The Old Man's sword. Light and honest."},
	# v0.15 (RPG CODE): uit de schatkist achter de geheime deur in de puzzelkamer van het Eerste
	# Archief. ATK +12 (keuze Dennis; = 4x het Kort zwaard). Alleen krijgers (Dennis). Niet te koop.
	# "element" is alleen info (doet nog niets in de schade); "icon" = 16x16 van RPG ART.
	"vonkzwaard": {"name": "Spark Sword", "slot": "wapen", "atk": 12, "wie": ["krijger"], "price": 0,
		"act": 1, "lijn": "zwaard", "orde": 2,
		"element": "vuur", "desc": "A blade that glows a soft pink-orange. Warm in your hand.",
		"icon": "res://assets/ui/icons/vonkzwaard.png"},
	"eiken_staf": {"name": "Oak Staff", "slot": "wapen", "atk": 2, "mag": 4, "wie": ["magier", "priester"], "price": 90,
		"act": 1, "lijn": "staf_noor", "orde": 1,
		"desc": "A staff of old oak. It strengthens spells."},
	"dolk": {"name": "Dagger", "slot": "wapen", "atk": 4, "agi": 1, "wie": ["krijger", "magier", "priester"], "price": 60,
		"desc": "Short and quick. Anyone can use it."},
	"houten_schild": {"name": "Wooden Shield", "slot": "schild", "def": 2, "wie": ["krijger", "priester"], "price": 40,
		"act": 1, "lijn": "schild", "orde": 1,
		"desc": "A simple round shield of planks."},
	"kaftschild": {"name": "Cover Shield", "slot": "schild", "def": 3, "mdef": 1, "wie": ["krijger", "priester"], "price": 90,
		"act": 1, "lijn": "schild", "orde": 2,
		"desc": "Made from the hard cover of an old book."},
	"leren_kap": {"name": "Leather Hood", "slot": "helm", "def": 1, "mdef": 1, "wie": ["krijger", "magier", "priester"], "price": 30,
		"act": 1, "lijn": "helm_krijger", "orde": 1,
		"desc": "A soft hood of leather."},
	"ijzeren_helm": {"name": "Iron Helm", "slot": "helm", "def": 3, "wie": ["krijger"], "price": 80,
		"act": 1, "lijn": "helm_krijger", "orde": 2,
		"desc": "Heavy, but it stops a blow."},
	"reisgewaad": {"name": "Travel Robe", "slot": "harnas", "def": 1, "mdef": 2, "wie": ["magier", "priester"], "price": 30,
		"act": 1, "lijn": "harnas_stroom", "orde": 1,
		"desc": "A light robe for long journeys."},
	"leren_harnas": {"name": "Leather Armor", "slot": "harnas", "def": 4, "wie": ["krijger", "priester"], "price": 70,
		"act": 1, "lijn": "harnas_krijger", "orde": 1,
		"desc": "Sturdy leather over the chest and shoulders."},
	# v0.16 (tutorial, wens Dennis): Opa geeft Dennis deze mantel in de proloog en leert hem
	# MENU > Uitrusting. Klein beetje DEF; iedereen mag hem dragen. Niet te koop.
	# Icoon: het bestaande reisgewaad-icoon van RPG ART (een mantel/gewaad).
	"leerling_mantel": {"name": "Apprentice Cloak", "slot": "harnas", "def": 2, "price": 0,
		"desc": "A warm cloak from Grandpa. Better than nothing.",
		"icon": "res://assets/ui/icons/reisgewaad.png"},
	"malienkolder": {"name": "Chain Mail", "slot": "harnas", "def": 6, "agi": -1, "wie": ["krijger"], "price": 160,
		"act": 1, "lijn": "harnas_krijger", "orde": 2,
		"desc": "Rings of iron. Strong, but heavy."},
	"bladwijzer": {"name": "Silver Bookmark", "short": "Bookmark", "slot": "accessoire", "agi": 2, "price": 100,
		"act": 1, "lijn": "ring", "orde": 1,
		"desc": "A silver bookmark that makes you light and quick."},
	# VOORLOPIG: 'gif-immuun' uit het ontwerp is nog niet gebouwd (er is nog geen gif).
	"groenring": {"name": "Green Ring", "slot": "accessoire", "mdef": 2, "price": 150,
		"desc": "A ring of green glass. (Poison immunity: later.)"},
	# ---------------------------------------------------------------- verhaalset Act 1-6
	# Lijnen en volgorde: scripts/data/level_scale.gd. Niet in de 100-verdiepingen-kisten.
	# Act 1 is te vinden. Act 2-6 staan klaar; die gebieden zijn nog niet gebouwd.
	# "bron" = waar het stuk hoort. Prijs 0: er is nog geen winkel.
	"wambuis": {"name": "Padded Jerkin", "slot": "harnas", "def": 3, "mdef": 3,
		"wie": ["krijger", "magier", "priester"], "price": 0,
		"act": 1, "lijn": "harnas_stroom", "orde": 2,
		"bron": "Act 1. Vesper gives it when she joins (Mapleton), into the bag.",
		"desc": "Lined leather that smells of smoke and applewood. Warm enough for the wood."},
	"ketelkling": {"name": "Kettle Blade", "slot": "wapen", "atk": 18, "wie": ["krijger"], "price": 0,
		"act": 2, "lijn": "zwaard", "orde": 3,
		"bron": "Act 2. Reward from Smeder-Prime in the Great Forge. Not placed yet.",
		"desc": "Forged from a kettle wall. The edge is so sharp that rust backs away."},
	"rookstaf": {"name": "Smoke Staff", "slot": "wapen", "atk": 4, "mag": 12, "mdef": 3, "wie": ["magier"], "price": 0,
		"act": 2, "lijn": "staf_noor", "orde": 2,
		"bron": "Act 2. Chest in the Kettle Works of the industrial town. Not placed yet.",
		"desc": "A staff full of soot and copper. Spells come out of it warmer."},
	"stemvork": {"name": "Tuning Fork", "slot": "wapen", "atk": 3, "mag": 14, "mdef": 6, "agi": 1, "wie": ["priester"], "price": 0,
		"act": 2, "lijn": "staf_lotte", "orde": 2,
		"bron": "Act 2. For Seren when she joins. Her place is still open (CANON). Not placed yet.",
		"desc": "A tuning fork that sings instead of speaking. Machines listen to it."},
	"ketelschild": {"name": "Kettle Shield", "slot": "schild", "def": 8, "mdef": 3, "wie": ["krijger", "priester"], "price": 0,
		"act": 2, "lijn": "schild", "orde": 3,
		"bron": "Act 2. Chest in the Great Forge. Not placed yet.",
		"desc": "A steam-kettle lid, beaten round into a shield."},
	"ketelhelm": {"name": "Kettle Helm", "slot": "helm", "def": 7, "mdef": 2, "wie": ["krijger"], "price": 0,
		"act": 2, "lijn": "helm_krijger", "orde": 3,
		"bron": "Act 2. Chest in the Smoke Towers. Not placed yet.",
		"desc": "A helm of kettle plate. It smells of smoke and stops a blow."},
	"rookkap": {"name": "Smoke Hood", "slot": "helm", "def": 2, "mdef": 5, "mag": 1, "wie": ["magier", "priester"], "price": 0,
		"act": 2, "lijn": "helm_stroom", "orde": 2,
		"bron": "Act 2. Chest in the Kettle Works. Not placed yet.",
		"desc": "A hood soaked through with soot. The hem is stitched with copper wire."},
	"schrootplaat": {"name": "Scrap Plate", "slot": "harnas", "def": 12, "mdef": 3, "agi": -1, "wie": ["krijger"], "price": 0,
		"act": 2, "lijn": "harnas_krijger", "orde": 3,
		"bron": "Act 2. Chest in the Great Forge. Not placed yet.",
		"desc": "Plates from old machine housings, riveted together with copper wire."},
	"werkmantel": {"name": "Work Cloak", "slot": "harnas", "def": 6, "mdef": 10, "mag": 4,
		"wie": ["magier", "priester"], "price": 0,
		"act": 2, "lijn": "harnas_stroom", "orde": 3,
		"bron": "Act 2. Chest in the Kettle Works. Not placed yet.",
		"desc": "A greasy cloak stitched with copper thread. The fitters swear lightning avoids it."},
	"koperring": {"name": "Copper Ring", "slot": "accessoire", "mdef": 5, "agi": 2, "price": 0,
		"act": 2, "lijn": "ring", "orde": 2,
		"bron": "Act 2. Chest in the Command Room. Not placed yet.",
		"desc": "A ring of drawn copper wire. Warm, and a little quicker."},
	"ankerkling": {"name": "Anchor Blade", "slot": "wapen", "atk": 28, "wie": ["krijger"], "price": 0,
		"act": 3, "lijn": "zwaard", "orde": 4,
		"bron": "Act 3. Chest in the Floating Temple. Not placed yet.",
		"desc": "A blade light as cork. In the wind of the Sky Ridge it sings softly."},
	"zweefstaf": {"name": "Hover Staff", "slot": "wapen", "atk": 4, "mag": 24, "mdef": 8, "wie": ["magier"], "price": 0,
		"act": 3, "lijn": "staf_noor", "orde": 3,
		"bron": "Act 3. Isolde hands it over in the Weaving Hall. Not placed yet.",
		"desc": "A crystal hovers above the staff and moves with your breath."},
	"gebedsstaf": {"name": "Prayer Staff", "slot": "wapen", "atk": 4, "mag": 26, "mdef": 12, "wie": ["priester"], "price": 0,
		"act": 3, "lijn": "staf_lotte", "orde": 3,
		"bron": "Act 3. Chest at the Current Pool. Not placed yet.",
		"desc": "A staff with a prayer flag from Skyfoot. The Current grows quieter around it."},
	"ankerschild": {"name": "Anchor Shield", "slot": "schild", "def": 14, "mdef": 6, "wie": ["krijger", "priester"], "price": 0,
		"act": 3, "lijn": "schild", "orde": 4,
		"bron": "Act 3. Chest by the Gate of Silence. Not placed yet.",
		"desc": "A shield of temple stone. It draws spells in and breaks them."},
	"tempelhelm": {"name": "Temple Helm", "slot": "helm", "def": 12, "mdef": 4, "wie": ["krijger"], "price": 0,
		"act": 3, "lijn": "helm_krijger", "orde": 4,
		"bron": "Act 3. Chest in the Inner Court. Not placed yet.",
		"desc": "A helm of the temple guard. Light, and hard as an oath."},
	"windkap": {"name": "Wind Hood", "slot": "helm", "def": 3, "mdef": 10, "mag": 3, "wie": ["magier", "priester"], "price": 0,
		"act": 3, "lijn": "helm_stroom", "orde": 3,
		"bron": "Act 3. Chest on the Wind Bridges. Not placed yet.",
		"desc": "A hood that barely moves in the wind. Spells linger inside it."},
	"tempelplaat": {"name": "Temple Plate", "slot": "harnas", "def": 18, "mdef": 6, "wie": ["krijger"], "price": 0,
		"act": 3, "lijn": "harnas_krijger", "orde": 4,
		"bron": "Act 3. Chest in Isolde's Circle. Not placed yet.",
		"desc": "A breastplate from a floating statue. The metal is light and hard."},
	"wolkgewaad": {"name": "Cloud Robe", "slot": "harnas", "def": 8, "mdef": 18, "mag": 8, "agi": 2,
		"wie": ["magier", "priester"], "price": 0,
		"act": 3, "lijn": "harnas_stroom", "orde": 4,
		"bron": "Act 3. Chest in Skyfoot. Not placed yet.",
		"desc": "Woven as light as a thought, and warm as an embrace."},
	"stroomring": {"name": "Current Ring", "slot": "accessoire", "mdef": 9, "mag": 5, "agi": 2, "price": 0,
		"act": 3, "lijn": "ring", "orde": 3,
		"bron": "Act 3. Trail of Magic, after Isolde. Not placed yet.",
		"desc": "A ring of blue thread. The Current runs with you a little way."},
	"incisie": {"name": "Incision", "slot": "wapen", "atk": 40, "agi": 2, "wie": ["krijger"], "price": 0,
		"act": 4, "lijn": "zwaard", "orde": 5,
		"bron": "Act 4. Chest in the Operating Hall. Not placed yet.",
		"desc": "A sword conceived as a scalpel. The wound only notices a moment later."},
	"glazenstaf": {"name": "Glass Staff", "slot": "wapen", "atk": 5, "mag": 36, "mdef": 12, "wie": ["magier"], "price": 0,
		"act": 4, "lijn": "staf_noor", "orde": 4,
		"bron": "Act 4. Chest in the Growth Halls. Not placed yet.",
		"desc": "A staff of laboratory glass. A cold glow pulses inside."},
	"levensstaf": {"name": "Life Staff", "slot": "wapen", "atk": 4, "mag": 40, "mdef": 16, "agi": 2, "wie": ["priester"], "price": 0,
		"act": 4, "lijn": "staf_lotte", "orde": 4,
		"bron": "Act 4. Beside Seren's capsule in the Cradle Room. Not placed yet.",
		"desc": "A staff like a spine, with glass vertebrae and a warm glow."},
	"kweekschild": {"name": "Growth Shield", "slot": "schild", "def": 22, "mdef": 8, "wie": ["krijger", "priester"], "price": 0,
		"act": 4, "lijn": "schild", "orde": 5,
		"bron": "Act 4. Chest in the Growth Halls. Not placed yet.",
		"desc": "A shield of cultured plate. It feels warm, and a little alive."},
	"kweekhelm": {"name": "Growth Helm", "slot": "helm", "def": 16, "mdef": 6, "wie": ["krijger"], "price": 0,
		"act": 4, "lijn": "helm_krijger", "orde": 5,
		"bron": "Act 4. Chest in Reception. Not placed yet.",
		"desc": "A helm that slowly grows along with you. It itches. It does protect."},
	"glashelm": {"name": "Glass Helm", "slot": "helm", "def": 4, "mdef": 14, "mag": 4, "wie": ["magier", "priester"], "price": 0,
		"act": 4, "lijn": "helm_stroom", "orde": 4,
		"bron": "Act 4. Chest in the Correction Room. Not placed yet.",
		"desc": "A helm of thick glass. You hear your own breath, and little else."},
	"chitineharnas": {"name": "Chitin Armor", "slot": "harnas", "def": 28, "mdef": 8, "wie": ["krijger"], "price": 0,
		"act": 4, "lijn": "harnas_krijger", "orde": 5,
		"bron": "Act 4. Chest in Osk's studio. Not placed yet.",
		"desc": "Plates of cultured chitin. They grow a little with the wearer."},
	"labmantel": {"name": "Lab Coat", "slot": "harnas", "def": 10, "mdef": 24, "mag": 10, "wie": ["magier", "priester"], "price": 0,
		"act": 4, "lijn": "harnas_stroom", "orde": 5,
		"bron": "Act 4. Chest in the Cradle Room. Not placed yet.",
		"desc": "A white coat from the laboratory. The hem is still sterile."},
	"levensring": {"name": "Life Ring", "slot": "accessoire", "mdef": 14, "mag": 6, "agi": 3, "price": 0,
		"act": 4, "lijn": "ring", "orde": 4,
		"bron": "Act 4. Trail of Life, after Osk. Not placed yet.",
		"desc": "A ring with a green leaf inside. Healing sits lighter with it."},
	"perihelium": {"name": "Perihelion", "slot": "wapen", "atk": 56, "mag": 4, "agi": 2, "wie": ["krijger"], "price": 0,
		"act": 5, "lijn": "zwaard", "orde": 6,
		"bron": "Act 5. Chest in the Chart Hall. Not placed yet.",
		"desc": "A blade of star steel. In the dark it shows constellations."},
	"astrostaf": {"name": "Astrolabe Staff", "short": "Astro Staff", "slot": "wapen", "atk": 6, "mag": 50, "mdef": 16,
		"wie": ["magier"], "price": 0,
		"act": 5, "lijn": "staf_noor", "orde": 5,
		"bron": "Act 5. Perihelia gives it after the Eye. Not placed yet.",
		"desc": "Turning brass rings around a glass core full of stars."},
	"lichtstaf": {"name": "Light Staff", "slot": "wapen", "atk": 5, "mag": 52, "mdef": 20, "wie": ["priester"], "price": 0,
		"act": 5, "lijn": "staf_lotte", "orde": 5,
		"bron": "Act 5. Chest in the Dome Halls. Not placed yet.",
		"desc": "A staff that holds the light of the real stars, not the false ones."},
	"maanschild": {"name": "Moon Shield", "slot": "schild", "def": 30, "mdef": 12, "wie": ["krijger", "priester"], "price": 0,
		"act": 5, "lijn": "schild", "orde": 6,
		"bron": "Act 5. Chest in the Clockwork Halls. Not placed yet.",
		"desc": "A shield of moon-silver. In moonlight it turns almost clear."},
	"sterrenhelm": {"name": "Star Helm", "slot": "helm", "def": 22, "mdef": 8, "wie": ["krijger"], "price": 0,
		"act": 5, "lijn": "helm_krijger", "orde": 6,
		"bron": "Act 5. Chest on the Sky Stair. Not placed yet.",
		"desc": "A helm with a narrow visor line. Behind it the stars stand still."},
	"sterrenkap": {"name": "Star Hood", "slot": "helm", "def": 6, "mdef": 20, "mag": 6, "wie": ["magier", "priester"], "price": 0,
		"act": 5, "lijn": "helm_stroom", "orde": 5,
		"bron": "Act 5. Chest in Starrest. Not placed yet.",
		"desc": "A dark-blue hood. The embroidered stars shift when you are not looking."},
	"maanharnas": {"name": "Moon Armor", "slot": "harnas", "def": 40, "mdef": 14, "agi": 1, "wie": ["krijger"], "price": 0,
		"act": 5, "lijn": "harnas_krijger", "orde": 6,
		"bron": "Act 5. Chest by the Great Lens. Not placed yet.",
		"desc": "Silver that almost vanishes in moonlight. The armor seems to know you."},
	"sterrenmantel": {"name": "Star Cloak", "slot": "harnas", "def": 14, "mdef": 34, "mag": 14, "agi": 2,
		"wie": ["magier", "priester"], "price": 0,
		"act": 5, "lijn": "harnas_stroom", "orde": 6,
		"bron": "Act 5. Chest in Starrest. Not placed yet.",
		"desc": "Dark-blue cloth with the stars of the first night embroidered on it."},
	"sterrenring": {"name": "Star Ring", "slot": "accessoire", "mdef": 18, "mag": 8, "agi": 4, "price": 0,
		"act": 5, "lijn": "ring", "orde": 5,
		"bron": "Act 5. Trail of Cosmos, after Perihelia. Not placed yet.",
		"desc": "A ring with a silver star. It points, very softly, toward the east."},
	"memoria": {"name": "Memoria", "slot": "wapen", "atk": 84, "mag": 8, "mdef": 4, "agi": 2, "wie": ["krijger"], "price": 0,
		"act": 6, "lijn": "zwaard", "orde": 7,
		"bron": "Act 6. Chamber of Joy in the Unknown Core. Not placed yet.",
		"desc": "A sword from the memory of the first laugh with Grandpa. It strikes true."},
	"hartvuurstaf": {"name": "Heartfire Staff", "short": "Heartfire", "slot": "wapen", "atk": 6, "mag": 66, "mdef": 20, "agi": 2, "wie": ["magier"], "price": 0,
		"act": 6, "lijn": "staf_noor", "orde": 6,
		"bron": "Act 6. Chamber of Grief. Not placed yet.",
		"desc": "A staff that grows warm when you say aloud a name you refuse to forget."},
	"hartpsalm": {"name": "Heart Psalm", "slot": "wapen", "atk": 5, "mag": 68, "mdef": 24, "agi": 2, "wie": ["priester"], "price": 0,
		"act": 6, "lijn": "staf_lotte", "orde": 6,
		"bron": "Act 6. Chamber of Fear. Not placed yet.",
		"desc": "A staff that keeps one voice, even when a hundred speak at once."},
	"hartschild": {"name": "Heart Shield", "slot": "schild", "def": 40, "mdef": 16, "wie": ["krijger", "priester"], "price": 0,
		"act": 6, "lijn": "schild", "orde": 7,
		"bron": "Act 6. Gate of the Heart. Not placed yet.",
		"desc": "A shield that bends with whoever stands behind it. It feels like a promise."},
	"zouthelm": {"name": "Salt Helm", "slot": "helm", "def": 28, "mdef": 12, "wie": ["krijger"], "price": 0,
		"act": 6, "lijn": "helm_krijger", "orde": 7,
		"bron": "Act 6. Reward in Saltwatch. Not placed yet.",
		"desc": "White as a crust of salt. Whoever wears it may cry again without shame."},
	"traankap": {"name": "Tear Hood", "slot": "helm", "def": 8, "mdef": 26, "mag": 8, "wie": ["magier", "priester"], "price": 0,
		"act": 6, "lijn": "helm_stroom", "orde": 6,
		"bron": "Act 6. Chest in Saltwatch. Not placed yet.",
		"desc": "A hood that smells of the sea. The brim stays wet, even when it is not raining."},
	"tranenpantser": {"name": "Tearplate", "slot": "harnas", "def": 52, "mdef": 18, "wie": ["krijger"], "price": 0,
		"act": 6, "lijn": "harnas_krijger", "orde": 7,
		"bron": "Act 6. Reward from the lighthouse in Saltwatch. Not placed yet.",
		"desc": "White as salt, strong as a promise. Forged when the village could cry again."},
	"hartmantel": {"name": "Heart Cloak", "slot": "harnas", "def": 18, "mdef": 44, "mag": 18, "agi": 3,
		"wie": ["magier", "priester"], "price": 0,
		"act": 6, "lijn": "harnas_stroom", "orde": 7,
		"bron": "Act 6. Chamber of Love. Not placed yet.",
		"desc": "A cloak that whispers a different memory from every thread. All of them warm."},
	"hartring": {"name": "Heart Ring", "slot": "accessoire", "mdef": 24, "mag": 10, "agi": 5, "price": 0,
		"act": 6, "lijn": "ring", "orde": 6,
		"bron": "Act 6. The Pendant closes into a heart. Not placed yet.",
		"desc": "A ring shaped like a small heart. It is warm when someone says your name."},
	# Task #4 (Monsterschaal en buit, HANDOFF_DUNGEON100_SCHAAL.md): buit van de dungeon van 100 verdiepingen.
	# Id = "d100_<soort>_<niveau>", niveau 2-5 (niveau 1 = de uitrusting hierboven). Niet te koop.
	# Welke stukken waar vallen: scripts/data/dungeon100_scaling.gd (GEAR). VOORLOPIGE waarden.
	"d100_zwaard_2": {"name": "Archive Sword", "slot": "wapen", "atk": 20, "wie": ["krijger"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_zwaard_3": {"name": "Rune Sword", "slot": "wapen", "atk": 32, "wie": ["krijger"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_zwaard_4": {"name": "Glitch Sword", "slot": "wapen", "atk": 48, "wie": ["krijger"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_zwaard_5": {"name": "Seal Sword", "slot": "wapen", "atk": 70, "wie": ["krijger"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_staf_2": {"name": "Archive Staff", "slot": "wapen", "atk": 5, "mag": 10, "wie": ["magier", "priester"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_staf_3": {"name": "Rune Staff", "slot": "wapen", "atk": 8, "mag": 18, "wie": ["magier", "priester"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_staf_4": {"name": "Glitch Staff", "slot": "wapen", "atk": 12, "mag": 30, "wie": ["magier", "priester"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_staf_5": {"name": "Seal Staff", "slot": "wapen", "atk": 18, "mag": 46, "wie": ["magier", "priester"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_schild_2": {"name": "Archive Shield", "slot": "schild", "def": 6, "mdef": 2, "wie": ["krijger", "priester"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_schild_3": {"name": "Rune Shield", "slot": "schild", "def": 10, "mdef": 4, "wie": ["krijger", "priester"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_schild_4": {"name": "Glitch Shield", "slot": "schild", "def": 16, "mdef": 7, "wie": ["krijger", "priester"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_schild_5": {"name": "Seal Shield", "slot": "schild", "def": 24, "mdef": 10, "wie": ["krijger", "priester"], "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_helm_2": {"name": "Archive Helm", "slot": "helm", "def": 4, "mdef": 2, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_helm_3": {"name": "Rune Helm", "slot": "helm", "def": 7, "mdef": 4, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_helm_4": {"name": "Glitch Helm", "slot": "helm", "def": 11, "mdef": 6, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_helm_5": {"name": "Seal Helm", "slot": "helm", "def": 16, "mdef": 9, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_harnas_2": {"name": "Archive Armor", "slot": "harnas", "def": 9, "mdef": 3, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_harnas_3": {"name": "Rune Armor", "slot": "harnas", "def": 15, "mdef": 6, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_harnas_4": {"name": "Glitch Armor", "slot": "harnas", "def": 24, "mdef": 10, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_harnas_5": {"name": "Seal Armor", "slot": "harnas", "def": 36, "mdef": 15, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_ring_2": {"name": "Archive Ring", "slot": "accessoire", "mdef": 5, "agi": 3, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_ring_3": {"name": "Rune Ring", "slot": "accessoire", "mdef": 9, "agi": 5, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_ring_4": {"name": "Glitch Ring", "slot": "accessoire", "mdef": 14, "agi": 8, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	"d100_ring_5": {"name": "Seal Ring", "slot": "accessoire", "mdef": 20, "agi": 12, "price": 0,
		"desc": "Loot from the depths of the Hundred Floors."},
	# Verdieping 100, optie C. Geen class, niet in de blauwe-kistpool (die staat in grade_gear.gd).
	"simulatie_ring": {"name": "Simulation Ring", "short": "Sim. Ring", "slot": "accessoire", "grade": 4, "price": 0,
		"desc": "+10% to all stats in the Deep Learning Simulation. Once per run, the ring restarts the current floor if the party falls."},
}
## Sterkste: hoe zwaar elke stat telt per soort held (VOORLOPIG, eigen voorstel van RPG CODE;
## niet in het ontwerp). Score van een stuk = som van bonus x gewicht.
const STRONGEST_WEIGHTS := {
	"krijger": {"atk": 1.0, "def": 1.0, "mag": 0.25, "mdef": 0.5, "agi": 0.5},
	"magier": {"atk": 0.25, "def": 0.75, "mag": 1.0, "mdef": 1.0, "agi": 0.5},
	"priester": {"atk": 0.5, "def": 1.0, "mag": 1.0, "mdef": 1.0, "agi": 0.5},
	"standaard": {"atk": 1.0, "def": 1.0, "mag": 1.0, "mdef": 1.0, "agi": 0.5},
}
const START_INVENTORY := {"drankje": 3, "toverwater": 1}   # v0.17: GEEN Lege Boeken (3 van Marit in Esdoorn + woudkisten)
const START_GOLD := 0

# ---------------------------------------------------------------- monsterniveaus (v0.14)
## MONSTERNIVEAU per verdieping van het Eerste Archief (plan: story/ARCHIEF1_PLATTEGROND.md par. 6,
## voorstel A). Een dungeonkamer heeft "tier" (scripts/data/dungeon_rooms.gd); in een gevecht met
## een map-monster uit die kamer gelden dan: HP x hp, ATK + atk, DEF + def, EXP x exp, Goud x gold.
## Alleen in de dungeon: dezelfde vijand op de wereldkaart blijft gewoon (tier 0), een BAAS krijgt
## nooit een niveau (zijn stats staan in het "boss"-blok), en het bestiarium toont de gewone waarden.
## Afronden: half naar even (zoals de simulatie in /workspace/archief1_ontwerp/plan.py).
## Speler-level waar het Eerste Archief op mikt. De gedeelde TIERS-tabel (ook woud en
## formule-tests) blijft staan. Alleen archiefgevechten gaan door apply_archief_tier.
const EERSTE_ARCHIEF_DOEL := 7
## Bevestigd: 0,7 op gevechtsstats en 0,50 op EXP, zodat 34 kamergevechten + het oefengevecht op level 7 landen.
const ARCHIEF_STAT_SCHAAL := 0.7
const ARCHIEF_EXP_SCHAAL := 0.50
## POWER SCALING v2 (vervangt PR #126; docs/BATTLE_BALANCE_REPORT.md): een gedocumenteerde schaal per gebied,
## gemeten met de battlesim (seed 20261020). Doel: gewone gevechten ~10-20% party-HP, bazen ~60-90% winst.
##   Act-1 basismonsters (mosslijm, moskonijn, papiergeest, glitchmot): HP x1,3, ATK x1,5 (Mech. Warden blijft 30/12, golemtest).
##   Tier 1-3 (Eerste Archief): ATK +8 / +9 / +9 (was 0 / 4 / 7), DEF +1 / +3 / +5.
##   Tier 5-6 = Tweede Archief verdieping 1-2 / 3-4 (archief2_rooms.gd; was tier 2 / 3, gedeeld met Archief 1):
##     de party is daar Lv 14-16, de archiefschaal 0,7 blijft (canon) en komt erna.
##   Tier 7 = Berggrot (berggrot_data.gd; was tier 0).
##   EXP/goud per tier blijven gelijk aan de oude tier (5 = oud 2, 6 = oud 3, 7 = basis).
##   Seren (lotte_glitch baas-blok): HP x3, ATK x2,3. Wortelkoning baas-blok: ATK 34 -> 38 (~80-90% winst in de battlesim; in #126 was het 68%).
##   Canon-bazen (Golem 360/27/15, Wurger, Genezer, Diepe Grot 25/50/75/99) NIET gewijzigd.
const TIERS := {
	1: {"hp": 1.0, "atk": 8, "def": 1, "exp": 2.0, "gold": 1.0},
	2: {"hp": 1.5, "atk": 9, "def": 3, "exp": 2.5, "gold": 1.5},
	3: {"hp": 1.9, "atk": 9, "def": 5, "exp": 3.0, "gold": 2.0},
	4: {"hp": 2.3, "atk": 10, "def": 7, "exp": 3.0, "gold": 2.5},
	5: {"hp": 5.0, "atk": 46, "def": 4, "exp": 2.5, "gold": 1.5},
	6: {"hp": 6.5, "atk": 66, "def": 6, "exp": 3.0, "gold": 2.0},
	7: {"hp": 3.5, "atk": 28, "def": 0, "exp": 1.0, "gold": 1.0},
}


## Afronden half naar even (12,5 -> 12; 13,5 -> 14), net als Python round().
static func round_half_even(v: float) -> int:
	var f := floorf(v)
	var diff := v - f
	if is_equal_approx(diff, 0.5):
		return int(f) if int(f) % 2 == 0 else int(f) + 1
	return roundi(v)


## Kopie van vijand-data met monsterniveau 'tier' (0 of onbekend = ongewijzigd).
static func apply_tier(data: Dictionary, tier: int) -> Dictionary:
	if not TIERS.has(tier):
		return data
	var t: Dictionary = TIERS[tier]
	var d := data.duplicate(true)
	d["max_hp"] = maxi(1, round_half_even(float(d["max_hp"]) * float(t["hp"])))
	d["atk"] = int(d["atk"]) + int(t["atk"])
	d["def"] = int(d["def"]) + int(t["def"])
	d["exp"] = round_half_even(float(d.get("exp", 0)) * float(t["exp"]))
	d["gold"] = round_half_even(float(d.get("gold", 0)) * float(t["gold"]))
	d["tier"] = tier
	return d


## Zelfde tier-tabel, daarna omlaag naar doel-level 7. Tier 0 blijft ongewijzigd.
static func apply_archief_tier(data: Dictionary, tier: int) -> Dictionary:
	var d := apply_tier(data, tier)
	if not TIERS.has(tier):
		return d
	d["max_hp"] = maxi(1, round_half_even(float(d["max_hp"]) * ARCHIEF_STAT_SCHAAL))
	d["atk"] = maxi(1, round_half_even(float(d["atk"]) * ARCHIEF_STAT_SCHAAL))
	d["def"] = maxi(0, round_half_even(float(d["def"]) * ARCHIEF_STAT_SCHAAL))
	if d.has("mag"):
		d["mag"] = maxi(0, round_half_even(float(d["mag"]) * ARCHIEF_STAT_SCHAAL))
	if d.has("mdef"):
		d["mdef"] = maxi(0, round_half_even(float(d["mdef"]) * ARCHIEF_STAT_SCHAAL))
	d["exp"] = maxi(1, round_half_even(float(d.get("exp", 0)) * ARCHIEF_EXP_SCHAAL))
	d["gold"] = maxi(0, round_half_even(float(d.get("gold", 0)) * ARCHIEF_STAT_SCHAAL))
	d["archief_doel"] = EERSTE_ARCHIEF_DOEL
	return d

## Player-facing element names. The ids (vuur, bliksem, ...) stay as data.
const ELEMENT_NAMES := {
	"vuur": "fire",
	"bliksem": "lightning",
	"natuur": "nature",
	"inkt": "ink",
	"ruis": "noise",
	"metaal": "metal",
	"kennis": "knowledge",
	"mist": "mist",
	"neutraal": "neutral",
	"water": "water",
	"licht": "light",
	"ijs": "ice",
	"fysiek": "physical",
	"zwaard": "sword",
}


static func element_name(id: String) -> String:
	return str(ELEMENT_NAMES.get(id, id))


# ---------------------------------------------------------------- encounters
## ---------------- RANDOM ENCOUNTERS ----------------
## Kans op een gevecht per stap, PER TERREIN (0.06 = 6%).
## Het terrein staat als custom data "terrain" op elke tile van de tileset
## (zie tools/build_maps.gd). Terreinen die hier NIET in staan (pad, kassei,
## stad, trap, ...) geven nooit een gevecht.
## Een hele map kan gevechten uitzetten: in een dorp staat "encounters" uit
## (eigenschap van de root-node van de map, zie scripts/map.gd).
const ENCOUNTER_RATES := {
	"gras": 0.06,       # gewone vlakte op de wereldkaart
	"hoog_gras": 0.07,  # lichte, hoge graspleinen
	"zand": 0.06,
	"bos": 0.10,        # in het bos is het gevaarlijker
}
## Aantal "veilige" stappen na een gevecht (of na het starten van het spel).
## Telt alleen af op terrein waar monsters kunnen komen.
const SAFE_STEPS := 6
## ---------------- GEVECHTSACHTERGRONDEN (v0.10, Lufia-stijl) ----------------
## Het terrein van de tile waarop het gevecht begint bepaalt de achtergrond.
## DIT is de enige plek met die koppeling: terrein -> achtergrond-id.
## Terreinen die hier niet in staan krijgen DEFAULT_BACKDROP_ID.
const TERRAIN_BACKDROP := {
	"gras": "grass", "hoog_gras": "grass", "bos": "grass",
	"zand": "sand",
	# v0.13: De Vergeten Archieven (dungeon-tegels, scripts/data/dungeon_rooms.gd)
	"archief": "library",
	# Het Levende Archief (thema kas): bestaande overwoekerde bibliotheek, geen nieuw bestand.
	"kas": "library_overgrown",
	# v0.17: het Donker Woud (thema donker_woud in dungeon_rooms.gd)
	"woud": "forest_dark",
	# v0.21: eigen gevechtsachtergronden van RPG ART (batch 13)
	"berggrot": "cave_berg",
	"dungeon100": "cave_deep",
}
## v0.17: baasgevecht op dit terrein = deze achtergrond i.p.v. "boss" (de Wortelkoning in het Woud).
## v0.23: baasgevecht in de kas (De Genezer) = kas_boss (RPG ART art_kas_battle).
const BOSS_TERRAIN_BACKDROP := {"woud": "forest_dark", "kas": "kas_boss"}
const DEFAULT_BACKDROP_ID := "grass"
## Achtergronden die GameState bij het opstarten vooraf laadt (1280x432 = 2,1 MB textuurgeheugen per stuk):
## alleen die van het begin van het spel. De rest (Diepe Grot-varianten, kas, overwoekerde bibliotheek)
## wordt pas bij het gevecht geladen (GameState._prefetch_backdrop) en maar één tegelijk bewaard.
const BACKDROPS_BOOT := ["grass", "sand", "boss", "library", "forest_dark", "cave_berg"]
## Achtergrond-id -> plaatje (1280x432, zie docs/ARTSTYLE.md 10g). gras/zand/boss zijn van
## de art director (RPG ART, staan in tools/handwerk.txt).
## "library" is bewaard voor een latere dungeon (nu niet op de wereldkaart).
const BACKDROPS := {
	"grass": "res://art/battle_bg/gras.png",
	"sand": "res://art/battle_bg/zand.png",
	"boss": "res://art/battle_bg/boss.png",
	"library": "res://assets/battle/bibliotheek.png",
	"library_overgrown": "res://assets/battle/bibliotheek_overwoekerd.png",
	# v0.17: gevechtsachtergrond Donker Woud, 1280x432 (RPG ART art_woud_v17, handwerk)
	"forest_dark": "res://assets/battle/donker_woud.png",
	# v0.21: Berggrot en Diepe Grot, 1280x432 (RPG ART batch 13, handwerk)
	"cave_berg": "res://assets/battle/berggrot.png",
	"cave_deep": "res://assets/battle/diepe_grot.png",
	# Diepe Grot per 15 verdiepingen (RPG ART v3, wens Dennis), zelfde keuze als de tegels.
	"cave_deep_v1": "res://assets/battle/diepe_grot_battle_v1.png",
	"cave_deep_v2": "res://assets/battle/diepe_grot_battle_v2.png",
	"cave_deep_v3": "res://assets/battle/diepe_grot_battle_v3.png",
	"cave_deep_v4": "res://assets/battle/diepe_grot_battle_v4.png",
	"cave_deep_v5": "res://assets/battle/diepe_grot_battle_v5.png",
	"cave_deep_v6": "res://assets/battle/diepe_grot_battle_v6.png",
	"cave_deep_v7": "res://assets/battle/diepe_grot_battle_v7.png",
	# v0.23: baasgevecht in de kas (De Genezer), 1280x432 (RPG ART art_kas_battle, handwerk)
	"kas_boss": "res://assets/battle/kas_genezer.png",
}


## Welke achtergrond bij dit terrein (een baasgevecht krijgt altijd "boss").
## Diepe Grot: met een verdieping (> 0) de variant van die verdieping (cave_deep_v1..v7, gewone gevechten).
static func backdrop_id_for(terrain: String, boss := false, floor_no := 0) -> String:
	if terrain == "dungeon100" and floor_no > 0 and not boss:
		return dungeon100_backdrop_id(floor_no)
	if boss:
		return str(BOSS_TERRAIN_BACKDROP.get(terrain, "boss"))
	return str(TERRAIN_BACKDROP.get(terrain, DEFAULT_BACKDROP_ID))


## Plek in het plaatje (pixels van de 1280x432-art) waar de vijanden horen te staan, als
## de art daar iets voor heeft (de magenta cirkel van de baas). De vijandenrij wordt
## horizontaal op dat punt gecentreerd; de hoogte blijft de vaste grondlijn van het
## gevecht (ENEMY_FEET_Y in battle.gd), zodat niets over de helden/statusvakken valt.
const BACKDROP_STAGE := {
	"boss": Vector2(800, 350),
}


## cave_deep_v1..v7: v = min((verdieping-1)/15, 6) + 1 (zoals Dungeon100Generator.theme_variant).
@warning_ignore("integer_division")
static func dungeon100_backdrop_id(floor_no: int) -> String:
	return "cave_deep_v%d" % (mini(maxi(floor_no - 1, 0) / 15, 6) + 1)


static func backdrop_path(id: String) -> String:
	return str(BACKDROPS.get(id, BACKDROPS[DEFAULT_BACKDROP_ID]))


## Mogelijke groepen vijanden. Hogere "weight" = vaker.
## v0.10: "terrains" = alleen op die terreinen (zonder = overal).
## Het Kennis-Beest is (voorlopig) een zeldzaam, sterk gevecht.
const ENCOUNTER_GROUPS := [
	{"enemies": ["mosslijm"], "weight": 3, "terrains": ["gras", "hoog_gras"]},
	{"enemies": ["mosslijm", "mosslijm"], "weight": 2, "terrains": ["gras", "hoog_gras"]},
	{"enemies": ["moskonijn"], "weight": 2, "terrains": ["gras", "hoog_gras", "bos"]},
	{"enemies": ["moskonijn", "mosslijm"], "weight": 2, "terrains": ["gras", "hoog_gras"]},
	{"enemies": ["papiergeest"], "weight": 3},
	{"enemies": ["papiergeest", "papiergeest"], "weight": 3},
	{"enemies": ["glitchmot", "papiergeest"], "weight": 3},
	{"enemies": ["glitchmot", "glitchmot", "glitchmot"], "weight": 1},
	{"enemies": ["kennis_beest"], "weight": 1},
	{"enemies": ["kennis_beest", "papiergeest"], "weight": 1},
	# v0.13: De Vergeten Archieven. Daar zijn GEEN random encounters (zichtbare map-monsters,
	# scripts/data/dungeon_rooms.gd); deze groep is er voor als een kamer toch een groep
	# per terrein wil (en voor F2 in debug). Op de wereldkaart komt hij nooit voor.
	{"enemies": ["mech_wachter"], "weight": 2, "terrains": ["archief"]},
	# v0.17: het Donker Woud (ook geen random encounters: map-monsters; dit is voor F2 in debug)
	{"enemies": ["wortelkruiper", "mistuil"], "weight": 2, "terrains": ["woud"]},
	{"enemies": ["sporenzwam"], "weight": 1, "terrains": ["woud"]},
	# "boss": true = baasgevecht (achtergrond "boss"); weight 0 = nooit willekeurig.
	# Nu alleen via de debug-toets F3 (later: een vaste plek op de kaart).
	{"enemies": ["kennis_beest"], "weight": 0, "boss": true, "id": "baas_kennis_beest"},
]

# ---------------------------------------------------------------- beeld (scanlines / CRT)
## ALLES van het scanline-filter staat hier (scripts/ui/crt_overlay.gd leest dit).
## Zet "enabled" op false om het filter helemaal uit te zetten.
##   scanlines    = hoe donker de dunne horizontale lijnen zijn (0 = uit, 1 = zwart)
##   scanlines_overworld = idem buiten gevechten (daar zijn de lijnen 2x zo dik)
##   vignette     = donkere hoeken (0 = uit)
##   glitch       = af en toe (elke 7-16 sec) een flits van 0,1 sec met kleurverschuiving
##   aberration   = hoe ver rood/blauw verschuiven tijdens zo'n glitch (in pixels)
## v0.16: de glitch (flitsen + randruis) alleen in de Archieven, zie crt_overlay.gd / dungeon_rooms.gd.
const CRT := {
	"enabled": true,
	"scanlines": 0.2,
	"scanlines_overworld": 0.12,
	"vignette": 0.28,
	"glitch": true,
	"aberration": 1.5,
	# v0.16 glitch ALLEEN in de Archieven, sterkte 0..1 per kamer (dungeon_rooms.gd glitch_intensity:
	# dichter bij de baas = sterker). Bij sterkte s:
	"glitch_gap_far": [9.0, 16.0],    # sec tussen twee glitch-flitsen bij s = 0 (verste kamer ~0.15)
	"glitch_gap_near": [2.5, 5.0],    # ... bij s = 1 (Voorhal, Bibliotheek, Golemhal)
	"noise_alpha": 0.32,              # pixel-ruis langs de randen (GlitchNoise), x s
	"scanlines_archief": 0.08,        # extra donkere scanlines, x s
}
