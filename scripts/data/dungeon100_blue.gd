extends RefCounted
## HET GESIMULEERDE ARCHIEF: Blauwe Kisten en Mimics in de Diepe Grot (Dungeon100), zie
## HANDOFF_DUNGEON100_BLUECHEST.md. Alleen PURE, statische functies + constanten (geen scène,
## geen autoload): los te testen met scripts/tests/dungeon100_blauw_tests.gd.
##
## LORE (voorstel, wacht op Dennis; botst niet met docs/lore/CANON.md): de Diepe Grot is geen echte grot
## maar een trainingsomgeving van de Oude Mensheid, een simulatie binnen een Archief die de Zwarte Stroom
## van Sapientia heeft aangetast. Wie valt wordt 'teruggezet': levels en spullen van de run verdwijnen,
## want ze bestonden alleen in de simulatie. Een BLAUWE KIST is een databank die de simulatie
## overleeft: wat erin zit is permanent.
##
## Regels:
##   - elke kist op een verdieping is deterministisch (run-seed + verdieping + kist-id) gewoon,
##     BLAUW (BLUE_CHANCE) of een MIMIC (MIMIC_CHANCE). Eén worp per kist, dus de kansen tellen op.
##   - baaskisten zijn nooit blauw of Mimic.
##   - Blauwe buit = ÉÉN uitrustingsstuk (een niveau boven de gewone kisten), nooit goud of drank:
##     alleen uitrusting kan permanent zijn zonder dat je het 'opgebruikt'.
##   - Mimic: kistbuit zoals gewoon, maar met MIMIC_GOLD_MULT x het goud, ná een gevecht.

const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")

const KIND_NORMAL := "normaal"
const KIND_BLUE := "blauw"
const KIND_MIMIC := "mimic"

const BLUE_CHANCE := 0.05
const MIMIC_CHANCE := 0.08
const MIMIC_GOLD_MULT := 2.0
const MIMIC_ENEMY := "mimic"
## Warp-kristal: buit van de eindbaas (verdieping 100), sleutel-voorwerp in GameData.KEY_ITEMS.
const WARP_ITEM := "warp"
const WARP_FLOOR := 100
## Blauwe tint voor kist, items en inventaris (placeholder: geen eigen sprite, zie tools/placeholders_v17.txt).
const BLUE_TINT := Color(0.45, 0.7, 1.35)


static func _rng(run_seed: int, floor_nr: int, chest_id: String, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%d|%s|%s" % [run_seed, floor_nr, chest_id, salt])
	return rng


## De ene worp (0..1) van een kist: dezelfde invoer geeft altijd dezelfde uitkomst.
static func roll(run_seed: int, floor_nr: int, chest_id: String) -> float:
	return _rng(run_seed, floor_nr, chest_id, "soort").randf()


## Soort kist: KIND_NORMAL, KIND_BLUE of KIND_MIMIC. Buiten de kerker (floor_nr <= 0) en bij
## een baaskist altijd gewoon.
static func kind_for(run_seed: int, floor_nr: int, chest_id: String, boss := false) -> String:
	if floor_nr <= 0 or boss:
		return KIND_NORMAL
	var r := roll(run_seed, floor_nr, chest_id)
	if r < BLUE_CHANCE:
		return KIND_BLUE
	if r < BLUE_CHANCE + MIMIC_CHANCE:
		return KIND_MIMIC
	return KIND_NORMAL


## Permanente buit van een Blauwe Kist: {"tier", "items": [{"item", "n": 1}], "gold": 0, "blue": true}.
static func blue_loot(run_seed: int, floor_nr: int, chest_id: String) -> Dictionary:
	var f := Scaling.clamp_floor(floor_nr)
	var tier := mini(Scaling.MAX_TIER, Scaling.tier_for_floor(f) + 1)
	var rng := _rng(run_seed, f, chest_id, "buit")
	var kind: String = Scaling.GEAR_KINDS[rng.randi_range(0, Scaling.GEAR_KINDS.size() - 1)]
	return {"tier": tier, "items": [{"item": Scaling.gear_id(kind, tier), "n": 1}], "gold": 0, "blue": true}


## Is dit een uitrustingsstuk dat een Blauwe Kist kan geven? (voor de tests en de opslag-opschoning)
static func is_blue_item(id: String) -> bool:
	for kind in Scaling.GEAR_KINDS:
		for t in range(1, Scaling.MAX_TIER + 1):
			if Scaling.gear_id(kind, t) == id:
				return true
	return false


## Buit van een Mimic-kist: de gewone kistbuit met extra goud.
static func mimic_loot(loot: Dictionary) -> Dictionary:
	var out: Dictionary = loot.duplicate(true)
	out["gold"] = int(round(float(out.get("gold", 0)) * MIMIC_GOLD_MULT))
	out["mimic"] = true
	return out


## Het Kistdata-record (zoals Dungeon100Scaling.chest_entry) met "kind", en voor een Blauwe Kist de
## permanente buit (en voor een Mimic de extra goud) al ingevuld. 'boss' = baaskist: altijd gewoon.
static func chest_entry(run_seed: int, floor_nr: int, id: String, tile: Vector2i, rng, boss := false) -> Dictionary:
	var e := Scaling.chest_entry(floor_nr, id, tile, rng, boss)
	var kind := kind_for(run_seed, floor_nr, id, boss)
	e["kind"] = kind
	match kind:
		KIND_BLUE:
			var loot := blue_loot(run_seed, floor_nr, id)
			e["loot"] = loot
			e["item"] = loot["items"][0]["item"]
			e["n"] = 1
		KIND_MIMIC:
			e["loot"] = mimic_loot(e["loot"])
	return e


## Buit van de eindbaas (verdieping 100) + het Warp-kristal; andere bazen: ongewijzigd.
static func with_warp(loot: Dictionary, floor_nr: int) -> Dictionary:
	if floor_nr != WARP_FLOOR:
		return loot
	var out: Dictionary = loot.duplicate(true)
	var items: Array = out.get("items", [])
	items.append({"item": WARP_ITEM, "n": 1})
	out["items"] = items
	return out
