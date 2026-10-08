extends RefCounted
## De Codex (Kernfragment stap 2): monsters inschrijven met een 'Leeg Boek' en als
## bondgenoot laten meevechten (zoals de capsule-monsters in Lufia 2).
##
## ALLES WAT JE MOET AANPASSEN STAAT HIER (data-gedreven). Een nieuwe soort toevoegen =
## alleen een regel in SPECIES (geen code). Zie HANDOFF_CODEX.md, 'Nieuwe soort'.
##
## Een soort hergebruikt de vijand uit GameData.ENEMIES (naam, vooraanzicht "sprite", rug-sprite
## "sprite_back", basis-stats). Hier staat alleen wat de Codex extra nodig heeft:
##   "enemy"        (VERPLICHT) id in GameData.ENEMIES; basis-stats = de gewone stats van die
##                  vijand (niet de baas-stats), op level 1
##   "name"         naam in de Codex (standaard de naam van de vijand)
##   "element"      element van de soort (voor fusie later; standaard "neutraal")
##   "type"         soortgroep (voor fusie later; standaard "monster")
##   "fusion_tags"  lijst met labels voor fusie later (standaard [])
##   "growth"       groei per level {"max_hp", "max_mp", "atk", "def", "agi"} (standaard DEFAULT_GROWTH)
##   "learn"        {level: [skill-id, ...]} vaardigheden uit SKILLS die hij op dat level leert
##                  (standaard {1: ["klauw"]})
##   "ai"           gedrag in het gevecht (zie DEFAULT_AI)
##   (rug-sprite: NIET hier, maar "sprite_back" in GameData.ENEMIES (afspraak Forge v17): bestand
##                  <id>_rug.png op hetzelfde canvas/anker als het vooraanzicht, voeten op rij H-7.
##                  Ontbreekt het veld of het bestand, dan tekent de code een plaatsvervanger: het
##                  vooraanzicht gespiegeld en donkerder.)
##   "ally_scale"   grootte als bondgenoot t.o.v. 1:1 (standaard 1.0 = zoals de helden: schaal 0,5 van
##                  de 2x-art, 1 art-pixel = 1 fijne pixel). Grote monsters kleiner, bv. 0.75.
##   "fx_scale"     grootte van het inschrijf-effect op dit monster (standaard 1.0; groot monster 2.0)
##   "capture_rate" vermenigvuldiger op de vangkans (standaard 1.0; sterke monsters lager)
##   "capturable"   false = nooit te vangen (bv. een soort die alleen als baas bestaat)
## Bazen (een gevecht met GameState.pending_boss) zijn NOOIT te vangen, ook al staat de soort hier.

const GameData := preload("res://scripts/data/game_data.gd")

## Het item (staat in GameData.ITEMS en in START_INVENTORY).
const BOOK_ITEM := "leeg_boek"
## Max. aantal pagina's in de Codex. Vol = het boek wordt niet gebruikt (melding).
const MAX_PAGES := 12

## ---- Vangkans ----
## kans = clamp(CAPTURE_MIN + CAPTURE_SCALE * (1 - hp/max_hp)^CAPTURE_POWER, 0, CAPTURE_MAX) x capture_rate
## Volle HP: 2%. Halve HP: ±35%. Kwart HP: ±62%. Bijna dood (1 HP): ±85-90%. Nooit meer dan 95%.
const CAPTURE_MIN := 0.02
const CAPTURE_SCALE := 0.93
const CAPTURE_POWER := 1.5
const CAPTURE_MAX := 0.95

## ---- Art (RPG ART; laadt automatisch als het bestand er is, anders plaatsvervangers) ----
const BOOK_ICON := "res://assets/ui/icons/leeg_boek.png"            # 16x16
const INSCRIBE_EFFECT := "res://assets/fx/inschrijf.png"            # 4 frames van 48x48 naast elkaar (192x48)
const INSCRIBE_FRAMES := 4
const INSCRIBE_FRAME_TIME := 0.1      # s per frame, NIET loopen (LEESMIJ van RPG ART)
## Voeten van een monster-sprite (voor- en rugaanzicht): (breedte/2, hoogte - FEET_FROM_BOTTOM)
## in art-pixels, midden van de grondschaduw (LEESMIJ van RPG ART).
const FEET_FROM_BOTTOM := 6
## Bondgenoot: zelfde schaal als de helden (2x-art op 0,5), maal "ally_scale".
const ALLY_ART_SCALE := 0.5

## Standaardwaarden (een soort mag alles weglaten behalve "enemy").
const DEFAULT_GROWTH := {"max_hp": 4, "max_mp": 0, "atk": 2, "def": 1, "agi": 1}
const DEFAULT_LEARN := {1: ["klauw"]}
## "skill_chance"  kans per beurt dat hij een vaardigheid gebruikt i.p.v. gewoon aan te vallen
## "heal_below"    genezen (als hij een heal-vaardigheid kent) zodra een held/hijzelf onder dit deel van zijn HP zit
## "target"        welke vijand hij aanvalt: "zwakste" (laagste HP), "sterkste" (hoogste HP) of "willekeurig"
const DEFAULT_AI := {"skill_chance": 0.35, "heal_below": 0.35, "target": "willekeurig"}

## Vaardigheden van Codex-monsters (alleen voor bondgenoten; vijanden houden hun eigen "skills").
##   "type": "damage" = één vijand, ATK x power - DEF/2 (zoals een gewone klap)
##           "all"    = alle vijanden, ATK x power - DEF/2
##           "heal"   = één bondgenoot (held of hijzelf), power + 2 x level HP
##           "guard"  = schild omhoog (DEF x def_mult, deze en de volgende ronde)
##   "mp" = kosten (0 = gratis); "element" = alleen informatie (fusie later)
const SKILLS := {
	"klauw":        {"name": "Klauw",        "type": "damage", "power": 1.2, "mp": 0},
	"slijmklodder": {"name": "Slijmklodder", "type": "damage", "power": 1.35, "mp": 0, "element": "natuur"},
	"mosheling":    {"name": "Mosheling",    "type": "heal",   "power": 10,  "mp": 0, "element": "natuur"},
	"bijtsprong":   {"name": "Bijtsprong",   "type": "damage", "power": 1.5, "mp": 0},
	"fluisterblad": {"name": "Fluisterblad", "type": "damage", "power": 1.3, "mp": 0, "element": "inkt"},
	"papierstorm":  {"name": "Papierstorm",  "type": "all",    "power": 0.8, "mp": 0, "element": "inkt"},
	"ruisvleugel":  {"name": "Ruisvleugel",  "type": "damage", "power": 1.5, "mp": 0, "element": "ruis"},
	"stoorsignaal": {"name": "Stoorsignaal", "type": "all",    "power": 0.7, "mp": 0, "element": "ruis"},
	"schild_omhoog": {"name": "Schild omhoog", "type": "guard", "def_mult": 2.0, "mp": 0},
	"zegelslag":    {"name": "Zegelslag",    "type": "damage", "power": 1.4, "mp": 0, "element": "metaal"},
	"boekenhamer":  {"name": "Boekenhamer",  "type": "damage", "power": 1.5, "mp": 0, "element": "kennis"},
	"kennisgolf":   {"name": "Kennisgolf",   "type": "all",    "power": 0.9, "mp": 0, "element": "kennis"},
	# v0.17 Donker Woud
	"wortelgreep":  {"name": "Wortelgreep",  "type": "damage", "power": 1.3, "mp": 0, "element": "natuur"},
	"doornhaag":    {"name": "Doornhaag",    "type": "all",    "power": 0.8, "mp": 0, "element": "natuur"},
	"mistkreet":    {"name": "Mistkreet",    "type": "damage", "power": 1.25, "mp": 0, "element": "mist"},
	"mistsluier":   {"name": "Mistsluier",   "type": "all",    "power": 0.75, "mp": 0, "element": "mist"},
	"sporenwolk":   {"name": "Sporenwolk",   "type": "all",    "power": 0.8, "mp": 0, "element": "natuur"},
	"zwamkuur":     {"name": "Zwamkuur",     "type": "heal",   "power": 14,  "mp": 0, "element": "natuur"},
}

## De soorten. Volgorde = volgorde in het Codex-scherm (daarna op level).
const SPECIES := {
	"mosslijm": {
		"enemy": "mosslijm", "element": "natuur", "type": "slijm", "fusion_tags": ["mos", "slijm"],
		"growth": {"max_hp": 5, "max_mp": 0, "atk": 2, "def": 1, "agi": 1},
		"learn": {1: ["slijmklodder"], 3: ["mosheling"]},
		"ai": {"skill_chance": 0.35, "heal_below": 0.4, "target": "willekeurig"},
	},
	"moskonijn": {
		"enemy": "moskonijn", "element": "natuur", "type": "dier", "fusion_tags": ["mos", "dier"],
		"growth": {"max_hp": 4, "max_mp": 0, "atk": 2, "def": 1, "agi": 2},
		"learn": {1: ["bijtsprong"]},
		"ai": {"skill_chance": 0.3, "heal_below": 0.0, "target": "zwakste"},
	},
	"papiergeest": {
		"enemy": "papiergeest", "element": "inkt", "type": "geest", "fusion_tags": ["papier", "geest"],
		"growth": {"max_hp": 4, "max_mp": 0, "atk": 2, "def": 1, "agi": 1},
		"learn": {1: ["fluisterblad"], 4: ["papierstorm"]},
		"ai": {"skill_chance": 0.4, "heal_below": 0.0, "target": "willekeurig"},
	},
	"glitchmot": {
		"enemy": "glitchmot", "element": "ruis", "type": "insect", "fusion_tags": ["ruis", "vleugel"],
		"growth": {"max_hp": 3, "max_mp": 0, "atk": 3, "def": 1, "agi": 2},
		"learn": {1: ["ruisvleugel"], 5: ["stoorsignaal"]},
		"ai": {"skill_chance": 0.4, "heal_below": 0.0, "target": "zwakste"},
	},
	"mech_wachter": {
		"enemy": "mech_wachter", "element": "metaal", "type": "construct", "fusion_tags": ["metaal", "archief"],
		"growth": {"max_hp": 6, "max_mp": 0, "atk": 2, "def": 2, "agi": 1},
		"learn": {1: ["zegelslag"], 3: ["schild_omhoog"]},
		"ai": {"skill_chance": 0.3, "heal_below": 0.0, "target": "sterkste"},
		"capture_rate": 0.8,
	},
	"kennis_beest": {
		"enemy": "kennis_beest", "name": "Kennis-Beest", "element": "kennis", "type": "golem",
		"fusion_tags": ["boek", "golem", "kern"],
		"growth": {"max_hp": 7, "max_mp": 1, "atk": 3, "def": 2, "agi": 1},
		"learn": {1: ["boekenhamer"], 6: ["kennisgolf"]},
		"ai": {"skill_chance": 0.3, "heal_below": 0.0, "target": "sterkste"},
		# 182 art-px hoog (Dennis ~156): als bondgenoot 0,75x (LEESMIJ RPG ART); effect 2x
		"ally_scale": 0.75, "fx_scale": 2.0, "capture_rate": 0.6,
	},
	# v0.17 Donker Woud (alleen data; vijand + "sprite_back" staan in GameData.ENEMIES).
	# De Wortelkoning staat hier bewust NIET: hij is alleen baas (bazen zijn nooit te vangen).
	"wortelkruiper": {
		"enemy": "wortelkruiper", "element": "natuur", "type": "plant", "fusion_tags": ["wortel", "woud"],
		"growth": {"max_hp": 6, "max_mp": 0, "atk": 3, "def": 2, "agi": 1},
		"learn": {1: ["wortelgreep"], 5: ["doornhaag"]},
		"ai": {"skill_chance": 0.35, "heal_below": 0.0, "target": "zwakste"},
		"capture_rate": 0.8,
	},
	"mistuil": {
		"enemy": "mistuil", "element": "mist", "type": "vogel", "fusion_tags": ["mist", "vleugel", "papier"],
		"growth": {"max_hp": 4, "max_mp": 1, "atk": 3, "def": 1, "agi": 3},
		"learn": {1: ["mistkreet"], 5: ["mistsluier"]},
		"ai": {"skill_chance": 0.4, "heal_below": 0.0, "target": "willekeurig"},
		"capture_rate": 0.8,
	},
	"sporenzwam": {
		"enemy": "sporenzwam", "element": "natuur", "type": "zwam", "fusion_tags": ["zwam", "woud"],
		"growth": {"max_hp": 7, "max_mp": 0, "atk": 2, "def": 2, "agi": 1},
		"learn": {1: ["sporenwolk"], 4: ["zwamkuur"]},
		"ai": {"skill_chance": 0.35, "heal_below": 0.4, "target": "willekeurig"},
		"capture_rate": 0.8,
	},
}

## Velden van een pagina (één ingeschreven monster; gaat zo de save in):
##   "uid"      unieke id per gevangen exemplaar ("codex_0001"; nooit hergebruikt -> fusie later)
##   "species"  soort-id (sleutel in SPECIES)
##   "name", "level", "exp", "hp", "mp", "max_hp", "max_mp", "atk", "def", "agi"
##   "skills"   geleerde vaardigheden (ids in SKILLS)
##   "element", "type", "fusion_tags"  (kopie van de soort, voor fusie later)
##   "fusion"   {"generation": 0, "parents": []}  (fusie later: 1+ = gefuseerd, parents = uids)
##   "caught"   {"tier": monsterniveau bij het vangen, "play_time": seconden}
const PAGE_STATS := ["max_hp", "max_mp", "atk", "def", "agi"]


# ---------------------------------------------------------------- opzoeken
static func has_species(id: String) -> bool:
	return SPECIES.has(id) and GameData.ENEMIES.has(str(SPECIES[id].get("enemy", "")))


## Soort met alle standaardwaarden ingevuld ({} als hij niet bestaat).
static func species(id: String) -> Dictionary:
	if not has_species(id):
		return {}
	return species_from(id, SPECIES[id])


## Zelfde, voor een losse data-regel 'raw' (ook gebruikt door de codextest om te bewijzen dat
## een nieuwe soort met alleen {"enemy": ...} werkt).
static func species_from(id: String, raw: Dictionary) -> Dictionary:
	if not GameData.ENEMIES.has(str(raw.get("enemy", ""))):
		return {}
	var s: Dictionary = raw.duplicate(true)
	var e: Dictionary = GameData.ENEMIES[str(s["enemy"])]
	if not s.has("name"):
		s["name"] = str(e["name"])
	for k in [["element", "neutraal"], ["type", "monster"], ["fusion_tags", []], ["growth", DEFAULT_GROWTH],
			["learn", DEFAULT_LEARN], ["ally_scale", 1.0], ["fx_scale", 1.0], ["capture_rate", 1.0], ["capturable", true]]:
		if not s.has(k[0]):
			s[k[0]] = k[1].duplicate(true) if (k[1] is Dictionary or k[1] is Array) else k[1]
	var ai: Dictionary = DEFAULT_AI.duplicate(true)
	ai.merge(s.get("ai", {}), true)
	s["ai"] = ai
	s["back"] = str(e.get("sprite_back", ""))     # "" = plaatsvervanger
	s["front"] = str(e["sprite"])
	return s


## Welke soort hoort bij vijand-id 'enemy_id'? "" = geen (niet te vangen).
static func species_for_enemy(enemy_id: String) -> String:
	if has_species(enemy_id) and str(SPECIES[enemy_id]["enemy"]) == enemy_id:
		return enemy_id
	for id in SPECIES:
		if str(SPECIES[id].get("enemy", "")) == enemy_id and has_species(id):
			return id
	return ""


## Basis-stats op level 1 = de gewone stats van de vijand (niet de baas-stats).
static func base_stats(id: String) -> Dictionary:
	var e: Dictionary = GameData.ENEMIES[str(SPECIES[id]["enemy"])]
	return {"max_hp": int(e["max_hp"]), "max_mp": int(e.get("mp", 0)), "atk": int(e["atk"]),
			"def": int(e["def"]), "agi": int(e["agi"])}


## Stats op 'level': basis + groei x (level - 1).
static func stats_at(id: String, level: int) -> Dictionary:
	var b := base_stats(id)
	var g: Dictionary = species(id)["growth"]
	var out := {}
	for k in PAGE_STATS:
		out[k] = int(b[k]) + int(g.get(k, 0)) * maxi(0, level - 1)
	return out


## Alle vaardigheden die soort 'id' kent op 'level' (in leer-volgorde).
static func skills_at(id: String, level: int) -> Array:
	var learn: Dictionary = species(id)["learn"]
	var lvls: Array = learn.keys()
	lvls.sort()
	var out: Array = []
	for l in lvls:
		if int(l) <= level:
			for sk in learn[l]:
				if SKILLS.has(str(sk)) and not out.has(str(sk)):
					out.append(str(sk))
	return out


static func skill(id: String) -> Dictionary:
	return SKILLS.get(id, {})


# ---------------------------------------------------------------- vangen
## Vangkans (0..1) voor een monster met 'hp' van 'max_hp'. 'boss' = altijd 0.
static func capture_chance(species_id: String, hp: int, max_hp: int, boss := false) -> float:
	if boss or not has_species(species_id) or not bool(species(species_id)["capturable"]):
		return 0.0
	var missing := 1.0 - clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	var c := clampf(CAPTURE_MIN + CAPTURE_SCALE * pow(missing, CAPTURE_POWER), 0.0, CAPTURE_MAX)
	return c * float(species(species_id)["capture_rate"])


## Level van een net gevangen monster: het monsterniveau van de verdieping (tier), minimaal 1.
static func capture_level(tier: int) -> int:
	return maxi(1, tier)


# ---------------------------------------------------------------- pagina's
## Nieuwe pagina (volle HP/MP). 'uid' komt van GameState (uniek per exemplaar).
static func make_page(species_id: String, level: int, uid: String) -> Dictionary:
	var sp := species(species_id)
	level = maxi(1, level)
	var page := {"uid": uid, "species": species_id, "name": str(sp["name"]), "level": level,
			"exp": GameData.exp_for_level(level)}
	page.merge(stats_at(species_id, level), true)
	page["hp"] = page["max_hp"]
	page["mp"] = page["max_mp"]
	page["skills"] = skills_at(species_id, level)
	page["element"] = str(sp["element"])
	page["type"] = str(sp["type"])
	page["fusion_tags"] = (sp["fusion_tags"] as Array).duplicate()
	page["fusion"] = {"generation": 0, "parents": []}
	page["caught"] = {}
	return page


## Pagina uit een save herstellen (ontbrekende/kapotte velden -> standaardwaarden). {} = ongeldig.
static func clean_page(raw) -> Dictionary:
	if not (raw is Dictionary) or not has_species(str(raw.get("species", ""))) or str(raw.get("uid", "")) == "":
		return {}
	var lv = raw.get("level", 1)
	var level := clampi(int(lv) if (lv is int or lv is float) else 1, 1, 99)
	var page := make_page(str(raw["species"]), level, str(raw["uid"]))
	for k in ["exp", "hp", "mp"] + PAGE_STATS:
		var v = raw.get(k)
		if v is int or v is float:
			page[k] = int(v)
	page["exp"] = maxi(page["exp"], GameData.exp_for_level(level))
	page["hp"] = clampi(page["hp"], 0, page["max_hp"])
	page["mp"] = clampi(page["mp"], 0, page["max_mp"])
	if raw.get("skills") is Array:
		var sk: Array = (raw["skills"] as Array).map(func(x): return str(x)).filter(func(x): return SKILLS.has(x))
		for x in skills_at(page["species"], level):
			if not sk.has(x):
				sk.append(x)
		page["skills"] = sk
	if raw.get("fusion") is Dictionary:
		page["fusion"] = (raw["fusion"] as Dictionary).duplicate(true)
	if raw.get("caught") is Dictionary:
		page["caught"] = (raw["caught"] as Dictionary).duplicate(true)
	if raw.get("name") is String and str(raw["name"]) != "":
		page["name"] = str(raw["name"])
	return page


## EXP geven aan een pagina; geeft berichten terug (level-ups en nieuwe vaardigheden).
static func give_exp(page: Dictionary, amount: int) -> Array[String]:
	var msgs: Array[String] = []
	page["exp"] = int(page["exp"]) + maxi(0, amount)
	var g: Dictionary = species(str(page["species"]))["growth"]
	while int(page["exp"]) >= GameData.exp_for_level(int(page["level"]) + 1) and int(page["level"]) < 99:
		page["level"] = int(page["level"]) + 1
		for k in PAGE_STATS:
			page[k] = int(page[k]) + int(g.get(k, 0))
		page["hp"] = int(page["hp"]) + int(g.get("max_hp", 0))
		page["mp"] = int(page["mp"]) + int(g.get("max_mp", 0))
		msgs.append("%s is nu level %d!" % [page["name"], page["level"]])
		for sk in skills_at(str(page["species"]), int(page["level"])):
			if not (page["skills"] as Array).has(sk):
				page["skills"].append(sk)
				msgs.append("%s leert %s!" % [page["name"], SKILLS[sk]["name"]])
	return msgs


# ---------------------------------------------------------------- controle (codextest)
## Lijst met fouten in de data ([] = alles goed).
static func validate() -> Array[String]:
	var errs: Array[String] = []
	if not GameData.ITEMS.has(BOOK_ITEM):
		errs.append("item %s ontbreekt in GameData.ITEMS" % BOOK_ITEM)
	for id in SPECIES:
		var raw: Dictionary = SPECIES[id]
		if not GameData.ENEMIES.has(str(raw.get("enemy", ""))):
			errs.append("%s: 'enemy' bestaat niet in ENEMIES" % id)
			continue
		var s := species(id)
		for k in PAGE_STATS:
			if not (s["growth"].get(k, 0) is int) or int(s["growth"].get(k, 0)) < 0:
				errs.append("%s: groei %s ongeldig" % [id, k])
		if skills_at(id, 1).is_empty():
			errs.append("%s: kent op level 1 geen vaardigheid" % id)
		for l in s["learn"]:
			for sk in s["learn"][l]:
				if not SKILLS.has(str(sk)):
					errs.append("%s: onbekende vaardigheid %s" % [id, sk])
		if not (str(s["ai"]["target"]) in ["zwakste", "sterkste", "willekeurig"]):
			errs.append("%s: ai.target ongeldig" % id)
		if not ResourceLoader.exists(str(s["front"])):
			errs.append("%s: vooraanzicht %s bestaat niet" % [id, s["front"]])
	for sk in SKILLS:
		if not (str(SKILLS[sk].get("type", "")) in ["damage", "all", "heal", "guard"]):
			errs.append("vaardigheid %s: type ongeldig" % sk)
	return errs
