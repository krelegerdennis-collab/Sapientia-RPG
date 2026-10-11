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
		"name": "Dennis", "class": "Krijger", "accent": "", "equip_type": "krijger",
		"level": 1, "exp": 0,
		"max_hp": 42, "max_mp": 0, "atk": 14, "def": 8, "agi": 9, "mag": 2, "mdef": 4,
		"spells": [],
		"growth": {"max_hp": 9, "max_mp": 0, "atk": 3, "def": 2, "agi": 1, "mag": 0, "mdef": 1},
	},
	{
		"id": "noor", "battle_sprite": "res://assets/sprites/battle/noor.png",
		# v0.17: dorp-/overworld-loopsheet van RPG ART (art_helden_dorp_v14, 48x96, zelfde indeling als player.png)
		"field_sprite": "res://assets/sprites/noor_dorp.png",
		"name": "Noor", "class": "Magiër", "accent": "magenta", "equip_type": "magier",
		"level": 1, "exp": 0,
		"max_hp": 28, "max_mp": 18, "atk": 7, "def": 5, "agi": 11, "mag": 10, "mdef": 8,
		"spells": ["vuur", "bliksem"],
		"growth": {"max_hp": 5, "max_mp": 4, "atk": 1, "def": 1, "agi": 2, "mag": 2, "mdef": 2},
	},
	{
		"id": "lotte", "battle_sprite": "res://assets/sprites/battle/lotte.png",
		"name": "Lotte", "class": "Priester", "accent": "cyaan", "equip_type": "priester",
		"level": 1, "exp": 0,
		"max_hp": 32, "max_mp": 14, "atk": 9, "def": 6, "agi": 7, "mag": 7, "mdef": 9,
		"spells": ["genees"],
		"growth": {"max_hp": 6, "max_mp": 3, "atk": 2, "def": 1, "agi": 1, "mag": 2, "mdef": 2},
	},
]

## Totale EXP die nodig is om een level te bereiken.
## Level 2 = 15, level 3 = 60, level 4 = 135, ...
static func exp_for_level(level: int) -> int:
	return 15 * (level - 1) * (level - 1)

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
		"name": "Mosslijm", "sprite": "res://art/enemies/mosslijm.png",
		"sprite_back": "res://art/enemies/mosslijm_rug.png",   # v0.17 rugaanzicht (Codex-bondgenoot)
		"max_hp": 10, "atk": 7, "def": 2, "agi": 3,
		"exp": 3, "gold": 2, "y_offset": 0,
		"skills": [],
		"no": 1, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.10}],
		"desc": "Een klodder levend mos die over oude boekbanden kruipt. Kleverig, maar niet gemeen.",
		"habitat": ["gras", "hoog_gras"],
	},
	"moskonijn": {
		"name": "Moskonijn", "sprite": "res://art/enemies/moskonijn.png",
		"sprite_back": "res://art/enemies/moskonijn_rug.png",   # v0.18 rugaanzicht (Codex-bondgenoot; RPG ART art_rug_v18)
		"max_hp": 14, "atk": 9, "def": 3, "agi": 12,
		"exp": 4, "gold": 3, "y_offset": 0,
		"skills": [],
		"no": 2, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.12}],
		"desc": "Een konijn met een vacht van mos en varens. Snel, schichtig en bijt als je te dichtbij komt.",
		"habitat": ["gras", "hoog_gras", "bos"],
	},
	"papiergeest": {
		"name": "Papiergeest", "sprite": "res://assets/sprites/enemies/papiergeest.png",
		"sprite_back": "res://assets/sprites/enemies/papiergeest_rug.png",   # v0.17 rugaanzicht (Codex-bondgenoot)
		"max_hp": 16, "atk": 9, "def": 3, "agi": 4,
		"exp": 5, "gold": 4, "y_offset": 0,
		"skills": [],
		"no": 3, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.15}],
		"desc": "Losgescheurde bladzijden die nooit gelezen zijn. Ze fluisteren nullen en enen.",
		"habitat": ["gras", "bos"],
	},
	"glitchmot": {
		"name": "Glitchmot", "sprite": "res://assets/sprites/enemies/glitchmot.png",
		"sprite_back": "res://assets/sprites/enemies/glitchmot_rug.png",   # v0.17 rugaanzicht (Codex-bondgenoot)
		"max_hp": 12, "atk": 10, "def": 2, "agi": 14,
		"exp": 6, "gold": 3, "y_offset": 0,
		"skills": [],
		"no": 4, "mp": 0, "weak": ["bliksem"], "resist": [],
		"drops": [{"item": "toverwater", "chance": 0.10}],
		"desc": "Een mot met kapotte vleugels van ruis. Vliegt op het licht van schermen en kaarsen.",
		"habitat": ["gras", "zand", "bos"],
	},
	# v0.13: eerste echte vijand van De Vergeten Archieven (scène 3: 'half kapotte Wachters').
	# Art van RPG ART (art_act1_v14/out): vooraanzicht 88x112 + idle-strook (2 frames).
	# STATS VOORLOPIG (nog niet gebalanceerd): tussen de kleine Archief-vijanden en de Golem in.
	"mech_wachter": {
		"name": "Mech. Wachter", "sprite": "res://assets/sprites/enemies/mech_wachter.png",
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
		"skills": [{"name": "Schild omhoog", "chance": 0.2, "type": "guard", "def_mult": 2.0},
				{"name": "Zegelslag", "chance": 0.15, "power": 1.4}],
		"no": 6, "mp": 0, "weak": ["bliksem"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.25}],
		"desc": "Een half kapotte bewaker van ijzer, messing en oude boekbanden. Zijn oog zoekt nog steeds naar indringers.",
		"habitat": ["archief"],
	},
	"kennis_beest": {
		# v0.13: Golem v2 (met hamer) van RPG ART (art_golem_v14/out): still 196x182, idle-strook
		# 4 frames (kern pulseert, langzaam), raak-plaatje (zelfde ankerpunt) en een aparte
		# runecirkel achter de voeten (2 frames 196x36 op (0,158), loopt langzaam). De oude
		# kennis_beest.png en golem_boss.png (v1) blijven bestaan (handwerk), maar worden niet gebruikt.
		"name": "Het Kennis-Beest", "sprite": "res://assets/sprites/enemies/golem_boss_v2.png",
		# v0.17 rugaanzicht (Codex-bondgenoot; als bondgenoot liefst kleiner tonen, zie v17_ART_SLOTS.md)
		"sprite_back": "res://assets/sprites/enemies/kennis_beest_rug.png",
		"idle": "res://assets/sprites/enemies/golem_boss_v2_idle.png", "idle_frames": 4, "idle_time": 0.4,
		"hit": "res://assets/sprites/enemies/golem_boss_v2_hit.png",
		"under": "res://assets/sprites/enemies/golem_runecirkel.png", "under_frames": 2,
		"under_pos": [0, 158], "under_time": 0.9,
		"max_hp": 46, "atk": 14, "def": 7, "agi": 6,
		"exp": 24, "gold": 18, "y_offset": 0,
		"skills": [{"name": "Boekenhamer", "chance": 0.25, "power": 1.5}],
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
			"max_hp": 400, "atk": 33, "def": 22, "agi": 6, "mag": 16, "mdef": 18, "mp": 0,
			"exp": 300, "gold": 120,
			"skills": [{"name": "Boekenhamer", "chance": 0.2, "power": 1.5}],
			# Vaste buit van de Golem in het Eerste Archief: 3 Lege Boeken. "chance" blijft alleen info.
			"drops": [{"item": "drankje", "chance": 1.0}, {"item": "toverwater", "chance": 0.5},
					{"item": "leeg_boek", "n": 3}],
			"core": {
				"cycle": 3,            # elke 3e ronde gaat de kern open (ronde 3, 6, 9, ...)
				"closed_mult": 0.4,    # schade op het pantser x0,4
				"open_mult": 2.0,      # schade op de open roze kern x2
				"break_damage": 45,    # >= 45 schade in die ronde = geen Hamerslag (1 echte klap op Lv 10)
				"slam_power": 2.2,     # Hamerslag = ATK x 2,2 (verdedigen = helft)
				"slam_name": "Hamerslag",
				"rect": [82, 52, 30, 30],   # kern in golem_boss_v2.png (196x182)
			},
		},
		"desc": "Golem van boeken, perkament en code. Bewaakt kennis die niemand meer mag lezen.",
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
		"name": "Wortelkruiper", "sprite": "res://assets/sprites/enemies/wortelkruiper.png",
		"sprite_back": "res://assets/sprites/enemies/wortelkruiper_rug.png",
		"max_hp": 34, "atk": 22, "def": 10, "agi": 7, "mag": 0, "mdef": 6,
		"exp": 16, "gold": 10, "y_offset": 0,
		"skills": [{"name": "Wortelgreep", "chance": 0.2, "power": 1.3}],
		"no": 7, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "kruid", "chance": 0.2}],
		"desc": "Een kluwen dode wortels met een mosrug dat onder het bladerdek loert; je ziet alleen zijn roze ogen voor hij in je enkels knijpt.",
		"habitat": ["woud"],
	},
	"mistuil": {
		"name": "Mistuil", "sprite": "res://assets/sprites/enemies/mistuil.png",
		"sprite_back": "res://assets/sprites/enemies/mistuil_rug.png",
		"max_hp": 26, "atk": 20, "def": 6, "agi": 16, "mag": 8, "mdef": 10,
		"exp": 15, "gold": 9, "y_offset": 0,
		"skills": [{"name": "Mistkreet", "chance": 0.2, "power": 1.25}],
		"no": 8, "mp": 4, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "toverwater", "chance": 0.15}],
		"desc": "Een uil van mist en gescheurde bladzijden die zonder geluid boven het pad zweeft; in zijn ogen flikkert nog de code van vergeten boeken.",
		"habitat": ["woud"],
	},
	"sporenzwam": {
		"name": "Sporenzwam", "sprite": "res://assets/sprites/enemies/sporenzwam.png",
		"sprite_back": "res://assets/sprites/enemies/sporenzwam_rug.png",
		"max_hp": 40, "atk": 18, "def": 12, "agi": 4, "mag": 6, "mdef": 8,
		"exp": 18, "gold": 12, "y_offset": 0,
		"skills": [{"name": "Sporenwolk", "chance": 0.25, "power": 1.4}],
		"no": 9, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.25}],
		"desc": "Een chagrijnige paddenstoel die nooit is uitgeslapen en bij elke stap gloeiende sporen uitniest.",
		"habitat": ["woud"],
	},
	# BAAS van het Donker Woud: houdt Noor gevangen in een wortelcocon (story_data.gd "noor_bevrijd").
	# Basis = baas-stats (hij komt alleen als baas voor). VOORLOPIG gebalanceerd voor Dennis SOLO
	# ~Lv 11-12 met Vonkzwaard + Kernkracht (zie docs/HANDOFF_WOUD.md). Geen kern-mechaniek.
	"wortelkoning": {
		"name": "De Wortelkoning", "sprite": "res://assets/sprites/enemies/wortelkoning.png",
		"sprite_back": "res://assets/sprites/enemies/wortelkoning_rug.png",
		"max_hp": 440, "atk": 34, "def": 20, "agi": 8, "mag": 14, "mdef": 16,
		"exp": 400, "gold": 150, "y_offset": 0,
		# v0.17 RPG ART: idle 4 frames van 200x190 (frame 0 = stil), raak-plaatje; hart-spleet
		# (voor een eventuele kern-mechaniek later) = rect [88, 98, 24, 40] in wortelkoning.png
		"idle": "res://assets/sprites/enemies/wortelkoning_idle.png", "idle_frames": 4, "idle_time": 0.4,
		"hit": "res://assets/sprites/enemies/wortelkoning_hit.png",
		"skills": [{"name": "Wortelgreep", "chance": 0.25, "power": 1.6}],
		"no": 10, "mp": 0, "weak": ["vuur"], "resist": ["bliksem"],
		"drops": [{"item": "drankje", "chance": 1.0}, {"item": "toverwater", "chance": 1.0}],
		"boss": {
			"max_hp": 440, "atk": 34, "def": 20, "agi": 8, "mag": 14, "mdef": 16, "mp": 0,
			"exp": 400, "gold": 150,
			"skills": [{"name": "Wortelgreep", "chance": 0.25, "power": 1.6}],
		},
		"desc": "De oude koning van het Donker Woud: een dode boom met een glitchend hart, die alles wat leeft in zijn wortels wil vangen.",
		"habitat": ["woud", "baas"],
	},
	# Het Gesimuleerde Archief (Dungeon100): de Mimic, een kist die terugbijt. Komt alleen uit een
	# Mimic-kist (scripts/data/dungeon100_blue.gd); stats = basis, de verdieping schaalt ze op.
	# Plaatje is een PLACEHOLDER (tools/art_mimic_placeholder.py).
	"mimic": {
		"name": "Mimic", "sprite": "res://assets/sprites/enemies/mimic.png",
		"max_hp": 26, "atk": 12, "def": 4, "agi": 6, "mag": 0, "mdef": 3,
		"exp": 14, "gold": 14, "y_offset": 0,
		"skills": [{"name": "Kistbeet", "chance": 0.3, "power": 1.5}],
		"no": 11, "mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [],
		"desc": "Een kist die niet van de Oude Mensheid is, maar van de Zwarte Stroom. Hij wacht tot iemand de deksel optilt.",
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
		"name": "Inktwurm", "sprite": "res://assets/sprites/enemies/inktwurm.png",
		"sprite_back": "res://assets/sprites/enemies/inktwurm_rug.png",
		"idle": "res://assets/sprites/enemies/inktwurm_idle.png", "idle_frames": 2, "idle_time": 0.55,
		"unique": true, "encounter_level": 5,
		"max_hp": 68, "atk": 36, "def": 17, "agi": 26, "mag": 0, "mdef": 2,
		# TIJDELIJKE AANNAME: EXP/goud ongeveer 2x een Mech. Wachter op niveau 4 (unieke beloning)
		"exp": 60, "gold": 40, "y_offset": 0,
		"skills": [],
		# lore: bestand tegen water; 'water' is (nog) geen element in de game, dus leeg (open vraag)
		"no": 12, "mp": 0, "weak": ["vuur"], "resist": [],
		# lore: Gloeiende Inktfles; dat item bestaat nog niet -> Toverwater (= Bladzijde van Inkt) als plaatshouder
		"drops": [{"item": "toverwater", "chance": 1.0}],
		"desc": "Een vette worm die zich door perkament heeft gegeten en nu zwarte inkt zweet.",
		"habitat": ["archief"],
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
## target: "enemy" (één vijand), "all_enemies" (alle vijanden) of "ally" (één held)
## type:   "damage" (schade) of "heal" (genezen)
## Effect = power + 2 x level van de gebruiker (+/- 10% geluk).
const SPELLS := {
	"vuur":    {"name": "Vuur",    "mp": 4, "target": "enemy",       "type": "damage", "power": 14},
	"bliksem": {"name": "Bliksem", "mp": 7, "target": "all_enemies", "type": "damage", "power": 9},
	"genees":  {"name": "Genees",  "mp": 3, "target": "ally",        "type": "heal",   "power": 22},
}

# ---------------------------------------------------------------- items
## v0.11 (veldmenu): "desc" = uitleg in Items. Genees-items ("target": "ally" met heal_hp/
## heal_mp) werken ook buiten gevechten; "field": false = alleen in een gevecht (grijs in
## het veldmenu). Zie scripts/party_actions.gd.
const ITEMS := {
	"drankje":    {"name": "Drankje",    "target": "ally", "heal_hp": 30, "heal_mp": 0,
		"desc": "Bitter kruidendrankje uit de bibliotheektuin."},
	"toverwater": {"name": "Toverwater", "target": "ally", "heal_hp": 0,  "heal_mp": 10,
		"desc": "Water dat zacht cyaan oplicht. Geeft magie terug."},
	# v0.11: van de Oude Man (de kist naast het huis). "short" = naam in het gevechtsmenu.
	"kruid":      {"name": "Geneeskrachtig kruid", "short": "Kruid", "target": "ally", "heal_hp": 25, "heal_mp": 0},
	# Task #4: sterkere genees-items, alleen als buit in de dungeon van 100 verdiepingen (dungeon100_scaling.gd).
	"sterk_drankje": {"name": "Sterk Drankje", "target": "ally", "heal_hp": 120, "heal_mp": 0,
		"desc": "Dik, donker drankje. Geneest veel levenspunten."},
	"toverbrouwsel": {"name": "Toverbrouwsel", "target": "ally", "heal_hp": 0, "heal_mp": 40,
		"desc": "Gloeiend brouwsel. Geeft veel magie terug."},
	"elixer": {"name": "Elixer", "target": "ally", "heal_hp": 400, "heal_mp": 60,
		"desc": "Een zeldzaam elixer uit de diepte. Geneest bijna alles."},
	# Codex (Kernfragment stap 2): alleen in een gevecht, op een VIJAND. Schrijft een verzwakt
	# monster in de Codex (kans: scripts/data/codex_data.gd). Altijd op, ook als het mislukt.
	# Te krijgen: 3 van Marit in Esdoorn (na de ontmoeting) + 2 in kisten van het Donker Woud
	# + 3 van de Golem in het Eerste Archief (baas-buit, "n" hierboven). Later ook in de winkel
	# ("price"). NIET in START_INVENTORY (oude saves krijgen dat toch nooit).
	"leeg_boek":  {"name": "Leeg Boek", "target": "enemy", "capture": true, "field": false,
		"heal_hp": 0, "heal_mp": 0, "price": 60, "icon": "res://assets/ui/icons/leeg_boek.png",
		"desc": "Een boek zonder woorden. Schrijf er een verzwakt monster in."},
}
## v0.11: sleutel-voorwerpen (niet te gebruiken in een gevecht; tellen wel in de inventaris)
const KEY_ITEMS := {
	"emmer_water": {"name": "Emmer water"},
	# Het Gesimuleerde Archief (Dungeon100): de uitgang uit de simulatie. Alleen buit van de baas op
	# verdieping 100 (Dungeon100Blue.WARP_ITEM). Een sleutel-voorwerp dus niet in het gevechtsmenu; in Items
	# werkt het alleen op verdieping 100 ("warp": true: party_actions.gd + GameState.dungeon100_warp).
	"warp": {"name": "Warp-kristal", "short": "Warp", "warp": true,
		"desc": "Een kristal uit de kern van het Archief. Op de laatste verdieping brengt het je terug naar de wereld."},
}
# ---------------------------------------------------------------- uitrusting (v0.14)
## !! VOORSTEL / VOORLOPIG !!  Uit story/ITEMS_ELEMENTEN.md (par. 4, 'Beginnersset'), wacht nog
## op Dennis. Alle getallen zijn startwaarden. Alleen de beginnersset staat erin.
## Logica (uitrusten, afdoen, sterkste, effectieve stats, opslaan): scripts/equipment.gd.
## (v0.11 had hier WEAPONS met alleen het Kort zwaard; dat zit nu in EQUIPMENT.)
##
## Vakken (volgorde = volgorde op het scherm) en hun naam op het scherm.
const EQUIP_SLOTS := ["wapen", "schild", "helm", "harnas", "accessoire"]
const EQUIP_SLOT_NAMES := {"wapen": "Wapen", "schild": "Schild", "helm": "Helm", "harnas": "Harnas", "accessoire": "Accessoire"}
## Stats die uitrusting kan veranderen (volgorde op het scherm) en hun korte naam.
## SPD = de bestaande sleutel "agi".
const EQUIP_STATS := ["atk", "def", "mag", "mdef", "agi"]
const STAT_LABELS := {"atk": "ATK", "def": "DEF", "mag": "MAG", "mdef": "MDEF", "agi": "SPD"}
## Per stuk: "name", "slot" (een van EQUIP_SLOTS), bonussen (atk/def/mag/mdef/agi, mag
## negatief), "wie" = equip_type's van de helden die het mogen dragen (weg = iedereen),
## "price" (winkel, nog niet gebouwd), "desc", "short" (naam in smalle lijsten, Items-scherm).
## Ids zonder trema (maliënkolder -> "malienkolder"), de naam op het scherm heeft hem wel.
const EQUIPMENT := {
	# VOORLOPIG: in het spel (v0.11 zwaardles) is het Kort zwaard ATK +3. Het ontwerp zegt
	# Kort Zwaard ATK +7 (winkel, 120) en een apart Roestig Zwaard ATK +3 als startwapen.
	# Zolang Dennis dat niet besloten heeft blijft het zoals in het spel: ATK +3.
	"kort_zwaard": {"name": "Kort zwaard", "slot": "wapen", "atk": 3, "wie": ["krijger"], "price": 120,
		"desc": "Het zwaard van de Oude Man. Licht en eerlijk."},
	# v0.15 (RPG CODE): uit de schatkist achter de geheime deur in de puzzelkamer van het Eerste
	# Archief. ATK +12 (keuze Dennis; = 4x het Kort zwaard). Alleen krijgers (Dennis). Niet te koop.
	# "element" is alleen info (doet nog niets in de schade); "icon" = 16x16 van RPG ART.
	"vonkzwaard": {"name": "Vonkzwaard", "slot": "wapen", "atk": 12, "wie": ["krijger"], "price": 0,
		"element": "vuur", "desc": "Een kling die zacht roze-oranje gloeit. Warm in je hand.",
		"icon": "res://assets/ui/icons/vonkzwaard.png"},
	"eiken_staf": {"name": "Eiken Staf", "slot": "wapen", "atk": 2, "mag": 4, "wie": ["magier", "priester"], "price": 90,
		"desc": "Een staf van oud eikenhout. Versterkt spreuken."},
	"dolk": {"name": "Dolk", "slot": "wapen", "atk": 4, "agi": 1, "wie": ["krijger", "magier", "priester"], "price": 60,
		"desc": "Kort en snel. Iedereen kan hem gebruiken."},
	"houten_schild": {"name": "Houten Schild", "slot": "schild", "def": 2, "wie": ["krijger", "priester"], "price": 40,
		"desc": "Een eenvoudig rond schild van planken."},
	"kaftschild": {"name": "Kaftschild", "slot": "schild", "def": 3, "mdef": 1, "wie": ["krijger", "priester"], "price": 90,
		"desc": "Gemaakt van de harde kaft van een oud boek."},
	"leren_kap": {"name": "Leren Kap", "slot": "helm", "def": 1, "mdef": 1, "wie": ["krijger", "magier", "priester"], "price": 30,
		"desc": "Een zachte kap van leer."},
	"ijzeren_helm": {"name": "IJzeren Helm", "slot": "helm", "def": 3, "wie": ["krijger"], "price": 80,
		"desc": "Zwaar, maar houdt een klap tegen."},
	"reisgewaad": {"name": "Reisgewaad", "slot": "harnas", "def": 1, "mdef": 2, "wie": ["magier", "priester"], "price": 30,
		"desc": "Een licht gewaad voor lange tochten."},
	"leren_harnas": {"name": "Leren Harnas", "slot": "harnas", "def": 4, "wie": ["krijger", "priester"], "price": 70,
		"desc": "Stevig leer over de borst en schouders."},
	# v0.16 (tutorial, wens Dennis): Opa geeft Dennis deze mantel in de proloog en leert hem
	# MENU > Uitrusting. Klein beetje DEF; iedereen mag hem dragen. Niet te koop.
	# Icoon: het bestaande reisgewaad-icoon van RPG ART (een mantel/gewaad).
	"leerling_mantel": {"name": "Leerling-mantel", "slot": "harnas", "def": 2, "price": 0,
		"desc": "Een warme mantel van Opa. Beter dan niets.",
		"icon": "res://assets/ui/icons/reisgewaad.png"},
	"malienkolder": {"name": "Maliënkolder", "slot": "harnas", "def": 6, "agi": -1, "wie": ["krijger"], "price": 160,
		"desc": "Ringen van ijzer. Sterk, maar zwaar."},
	"bladwijzer": {"name": "Zilveren Bladwijzer", "short": "Bladwijzer", "slot": "accessoire", "agi": 2, "price": 100,
		"desc": "Een zilveren bladwijzer die licht en snel maakt."},
	# VOORLOPIG: 'gif-immuun' uit het ontwerp is nog niet gebouwd (er is nog geen gif).
	"groenring": {"name": "Groene Ring", "slot": "accessoire", "mdef": 2, "price": 150,
		"desc": "Een ring van groen glas. (Gif-immuun: komt later.)"},
	# Task #4 (Monsterschaal en buit, HANDOFF_DUNGEON100_SCHAAL.md): buit van de dungeon van 100 verdiepingen.
	# Id = "d100_<soort>_<niveau>", niveau 2-5 (niveau 1 = de uitrusting hierboven). Niet te koop.
	# Welke stukken waar vallen: scripts/data/dungeon100_scaling.gd (GEAR). VOORLOPIGE waarden.
	"d100_zwaard_2": {"name": "Archiefzwaard", "slot": "wapen", "atk": 20, "wie": ["krijger"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_zwaard_3": {"name": "Runenzwaard", "slot": "wapen", "atk": 32, "wie": ["krijger"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_zwaard_4": {"name": "Glitchzwaard", "slot": "wapen", "atk": 48, "wie": ["krijger"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_zwaard_5": {"name": "Zegelzwaard", "slot": "wapen", "atk": 70, "wie": ["krijger"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_staf_2": {"name": "Archiefstaf", "slot": "wapen", "atk": 5, "mag": 10, "wie": ["magier", "priester"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_staf_3": {"name": "Runenstaf", "slot": "wapen", "atk": 8, "mag": 18, "wie": ["magier", "priester"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_staf_4": {"name": "Glitchstaf", "slot": "wapen", "atk": 12, "mag": 30, "wie": ["magier", "priester"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_staf_5": {"name": "Zegelstaf", "slot": "wapen", "atk": 18, "mag": 46, "wie": ["magier", "priester"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_schild_2": {"name": "Archiefschild", "slot": "schild", "def": 6, "mdef": 2, "wie": ["krijger", "priester"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_schild_3": {"name": "Runenschild", "slot": "schild", "def": 10, "mdef": 4, "wie": ["krijger", "priester"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_schild_4": {"name": "Glitchschild", "slot": "schild", "def": 16, "mdef": 7, "wie": ["krijger", "priester"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_schild_5": {"name": "Zegelschild", "slot": "schild", "def": 24, "mdef": 10, "wie": ["krijger", "priester"], "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_helm_2": {"name": "Archiefhelm", "slot": "helm", "def": 4, "mdef": 2, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_helm_3": {"name": "Runenhelm", "slot": "helm", "def": 7, "mdef": 4, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_helm_4": {"name": "Glitchhelm", "slot": "helm", "def": 11, "mdef": 6, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_helm_5": {"name": "Zegelhelm", "slot": "helm", "def": 16, "mdef": 9, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_harnas_2": {"name": "Archiefharnas", "slot": "harnas", "def": 9, "mdef": 3, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_harnas_3": {"name": "Runenharnas", "slot": "harnas", "def": 15, "mdef": 6, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_harnas_4": {"name": "Glitchharnas", "slot": "harnas", "def": 24, "mdef": 10, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_harnas_5": {"name": "Zegelharnas", "slot": "harnas", "def": 36, "mdef": 15, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_ring_2": {"name": "Archiefring", "slot": "accessoire", "mdef": 5, "agi": 3, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_ring_3": {"name": "Runenring", "slot": "accessoire", "mdef": 9, "agi": 5, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_ring_4": {"name": "Glitchring", "slot": "accessoire", "mdef": 14, "agi": 8, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
	"d100_ring_5": {"name": "Zegelring", "slot": "accessoire", "mdef": 20, "agi": 12, "price": 0,
		"desc": "Buit uit de diepte van de Honderd Verdiepingen."},
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
const TIERS := {
	1: {"hp": 1.0, "atk": 0, "def": 0, "exp": 2.0, "gold": 1.0},
	2: {"hp": 1.5, "atk": 4, "def": 3, "exp": 2.5, "gold": 1.5},
	3: {"hp": 1.9, "atk": 7, "def": 5, "exp": 3.0, "gold": 2.0},
	4: {"hp": 2.3, "atk": 10, "def": 7, "exp": 3.0, "gold": 2.5},
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
	# v0.17: het Donker Woud (thema donker_woud in dungeon_rooms.gd)
	"woud": "forest_dark",
}
## v0.17: baasgevecht op dit terrein = deze achtergrond i.p.v. "boss" (de Wortelkoning in het Woud).
const BOSS_TERRAIN_BACKDROP := {"woud": "forest_dark"}
const DEFAULT_BACKDROP_ID := "grass"
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
}


## Welke achtergrond bij dit terrein (een baasgevecht krijgt altijd "boss").
static func backdrop_id_for(terrain: String, boss := false) -> String:
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
