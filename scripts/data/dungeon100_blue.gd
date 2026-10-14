extends RefCounted
## HET GESIMULEERDE ARCHIEF: Blauwe Kisten en Mimics in de Diepe Grot (Dungeon100), zie
## HANDOFF_DUNGEON100_BLUECHEST.md. Alleen PURE, statische functies + constanten (geen scène,
## geen autoload): los te testen met scripts/tests/dungeon100_blauw_tests.gd.
##
## De Diepe Grot is een simulatie van Sapientia. Ze meet menselijke doorzettingskracht. Wie verdieping
## 100 haalt is een kandidaat. Dennis en de party zijn niet de eersten en niet de laatsten. Daarom
## level 1, geen uitrusting en geen echt verhaal. Wie valt is de simulatie uit: je staat weer voor de
## ingang. Een BLAUWE KIST is een databank die de run overleeft: wat erin zit is permanent.
##
## Regels:
##   - elke kist op een verdieping is deterministisch (run-seed + verdieping + kist-id) gewoon,
##     BLAUW (BLUE_CHANCE) of een MIMIC (MIMIC_CHANCE). Eén worp per kist, dus de kansen tellen op.
##   - baaskisten zijn nooit blauw of Mimic.
##   - Blauwe buit = ÉÉN uitrustingsstuk (een niveau boven de gewone kisten), nooit goud of drank:
##     alleen uitrusting kan permanent zijn zonder dat je het 'opgebruikt'.
##   - Mimic: kistbuit zoals gewoon, maar met MIMIC_GOLD_MULT x het goud, ná een gevecht.

const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")

const KIND_NORMAL := "normaal"
const KIND_BLUE := "blauw"
const KIND_MIMIC := "mimic"

## Oud: vaste kans per kist. Blijft als constante voor oude code; de kans komt nu per verdieping uit
## BLUE_FLOOR_CHANCE (CANON, TODO.md "Blue chest kans per floor-bracket"): 0-1 blauwe kist per verdieping.
const BLUE_CHANCE := 0.05
## [laatste verdieping van de bracket, kans]. Verdieping 100 heeft geen blauwe kist.
const BLUE_FLOOR_CHANCE := [[10, 0.05], [20, 0.10], [35, 0.15], [50, 0.20], [65, 0.25], [80, 0.30], [95, 0.40], [99, 0.50]]
const MIMIC_CHANCE := 0.10
const MIMIC_GOLD_MULT := 2.0
const MIMIC_ENEMY := "mimic"
## Warp-kristal: sleutel-voorwerp in GameData.KEY_ITEMS. Verdieping 100 heeft geen baas.
## De beloning is een keuze (Codex, Grade 4-wapens of Simulatie-ring): dungeon100_reward.gd.
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


## Kans op één blauwe kist op deze verdieping (normale kamer, floor-bracket-tabel).
static func blue_floor_chance(floor_nr: int) -> float:
	for b in BLUE_FLOOR_CHANCE:
		if floor_nr >= 1 and floor_nr <= int(b[0]):
			return float(b[1])
	return 0.0


## Kamer-type-override (CANON "Overrides per kamer-type"): vast aantal blauwe kisten, of -1 = volg
## de floor-bracket-tabel. CHEST ROOM ("kist") altijd 2; TREASURE ROOM ("schat") 50% kans op 1 (anders 0).
## PUZZLE ROOM: 1 blauwe kist bij succes, de vaste nis-kist van de puzzel (generator, GrotPuzzels); de
## gewone kist-slots daar zijn 0 en krijgen geen extra blauw (override 0).
const BLUE_ROOM_CHEST := 2
const BLUE_TREASURE_CHANCE := 0.5


static func blue_forced_for(run_seed: int, floor_nr: int, layout_type: String) -> int:
	match layout_type:
		"kist":
			return BLUE_ROOM_CHEST
		"schat":
			return 1 if _rng(run_seed, floor_nr, "verdieping", "schatblauw").randf() < BLUE_TREASURE_CHANCE else 0
		"puzzel":
			return 0
	return -1


## Welke kisten (index 0..chest_count-1) op deze verdieping blauw zijn. Normale kamer: met kans
## blue_floor_chance() precies één, anders geen. 'forced' >= 0 = vast aantal (kamer-type-override,
## bv. Chest Room 2), begrensd op chest_count. Deterministisch per (seed, verdieping).
static func blue_indices(run_seed: int, floor_nr: int, chest_count: int, forced := -1) -> Array:
	var out: Array = []
	if floor_nr <= 0 or chest_count <= 0:
		return out
	var rng := _rng(run_seed, floor_nr, "verdieping", "blauwkans")
	var n := 0
	if forced >= 0:
		n = mini(forced, chest_count)
	elif rng.randf() < blue_floor_chance(floor_nr):
		n = 1
	var idx: Array = range(chest_count)
	for i in n:
		var k := rng.randi_range(i, chest_count - 1)
		var tmp = idx[i]
		idx[i] = idx[k]
		idx[k] = tmp
		out.append(int(idx[i]))
	out.sort()
	return out


## Soort kist: KIND_NORMAL, KIND_BLUE of KIND_MIMIC. Buiten de kerker (floor_nr <= 0) en bij
## een baaskist altijd gewoon. Blauw alleen als de verdieping die kist aanwees ('blue', zie
## blue_indices); anders is een kist met kans MIMIC_CHANCE een Mimic.
static func kind_for(run_seed: int, floor_nr: int, chest_id: String, boss := false, blue := false) -> String:
	if floor_nr <= 0 or boss:
		return KIND_NORMAL
	if blue:
		return KIND_BLUE
	if roll(run_seed, floor_nr, chest_id) < MIMIC_CHANCE:
		return KIND_MIMIC
	return KIND_NORMAL


## Verdeling van een Blauwe Kist per grade (CANON, TODO.md "Loot ratio consumables vs. equipment"):
## [consumables, equipment, accessoires, goud, leeg] in procenten. Index 0 = G1.
const BLUE_RATIO := [
	[40, 15, 5, 30, 10],
	[30, 25, 10, 25, 10],
	[20, 30, 20, 20, 10],
	[15, 35, 25, 15, 10],
]
const BLUE_KINDS := ["consumable", "equipment", "accessoire", "goud", "leeg"]
## Blauwe consumables: sterker dan een gewone kist (elixers mogen), aantal schaalt met de grade.
const BLUE_CONSUMABLES := [["sterk_drankje", "toverwater"], ["sterk_drankje", "toverbrouwsel"],
		["toverbrouwsel", "elixer"], ["elixer"]]
const BLUE_CONSUMABLE_COUNT := [[1, 2], [2, 2], [2, 3], [2, 4]]
## Blauw goud = kistgoud van de verdieping x deze factor.
const BLUE_GOLD_MULT := 3.0


## Soort blauwe buit voor grade g (1-4) bij worp r (0..1).
static func blue_kind_for_roll(grade: int, r: float) -> String:
	var row: Array = BLUE_RATIO[clampi(grade, 1, 4) - 1]
	var acc := 0.0
	for i in row.size():
		acc += float(row[i]) / 100.0
		if r < acc:
			return BLUE_KINDS[i]
	return BLUE_KINDS[BLUE_KINDS.size() - 1]


## Accessoire uit een Blauwe Kist: grade 4 de G4-accessoires, daaronder de ring-lijn een niveau boven
## de gewone kisten (Dungeon100Scaling.GEAR "ring").
static func _accessory(run_seed: int, floor_nr: int, chest_id: String, grade: int) -> String:
	var rng := _rng(run_seed, floor_nr, chest_id, "accessoire")
	if grade >= 4:
		var pool: Array[String] = []
		for id in GradeGear.ITEMS:
			if str(GradeGear.ITEMS[id].get("slot", "")) == "accessoire":
				pool.append(str(id))
		if not pool.is_empty():
			return pool[rng.randi_range(0, pool.size() - 1)]
	var t := mini(Scaling.MAX_TIER, Scaling.tier_for_floor(floor_nr) + 1)
	return Scaling.gear_id("ring", t)


## Buit van een Blauwe Kist: {"tier", "grade", "items": [{"item", "n"}], "gold", "blue": true, "kind"}.
## Eén deterministische worp kiest de soort uit BLUE_RATIO van de grade van de verdieping.
## Items zijn permanent (databank); goud gaat bij het run-goud.
static func blue_loot(run_seed: int, floor_nr: int, chest_id: String) -> Dictionary:
	var f := Scaling.clamp_floor(floor_nr)
	var gate := 99 if f >= 100 else f
	var grade := GradeGear.grade_for_floor(gate)
	var kind := blue_kind_for_roll(grade, _rng(run_seed, floor_nr, chest_id, "blauwsoort").randf())
	var items: Array = []
	var gold := 0
	match kind:
		"consumable":
			var rng := _rng(run_seed, floor_nr, chest_id, "consumable")
			var pool: Array = BLUE_CONSUMABLES[grade - 1]
			var cnt: Array = BLUE_CONSUMABLE_COUNT[grade - 1]
			items.append({"item": str(pool[rng.randi_range(0, pool.size() - 1)]), "n": rng.randi_range(int(cnt[0]), int(cnt[1]))})
		"equipment":
			items.append({"item": GradeGear.pick(run_seed, f, chest_id), "n": 1})
		"accessoire":
			items.append({"item": _accessory(run_seed, f, chest_id, grade), "n": 1})
		"goud":
			var rng2 := _rng(run_seed, floor_nr, chest_id, "goud")
			gold = int(round(Scaling.chest_gold_base(f) * BLUE_GOLD_MULT * rng2.randf_range(0.9, 1.1)))
	return {"tier": grade, "grade": grade, "items": items, "gold": gold, "blue": true, "kind": kind}


## Alleen het uitrustingsstuk dat een Blauwe Kist op deze plek zou geven (voor code en tests die
## altijd een stuk nodig hebben, zoals de oude één-stuk-regel).
static func blue_gear(run_seed: int, floor_nr: int, chest_id: String) -> String:
	return GradeGear.pick(run_seed, Scaling.clamp_floor(floor_nr), chest_id)


## Is dit een uitrustingsstuk dat een Blauwe Kist kan geven? (voor de tests en de opslag-opschoning)
## Oude d100_*-stukken blijven blauw (saves van voor de grades). Nieuwe grade-stukken en G4-rollen ook.
## Oude rol-ids blijven blauw zodat een save ze nog vindt; ze zitten niet meer in de grade-4-pool.
static func is_blue_item(id: String) -> bool:
	if GradeGear.has_item(id) or GradeGear.is_scroll(id) or GradeGear.is_legacy_scroll(id):
		return true
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
static func chest_entry(run_seed: int, floor_nr: int, id: String, tile: Vector2i, rng, boss := false, blue := false) -> Dictionary:
	var e := Scaling.chest_entry(floor_nr, id, tile, rng, boss)
	var kind := kind_for(run_seed, floor_nr, id, boss, blue)
	e["kind"] = kind
	match kind:
		KIND_BLUE:
			var loot := blue_loot(run_seed, floor_nr, id)
			e["loot"] = loot
			if not (loot["items"] as Array).is_empty():
				e["item"] = loot["items"][0]["item"]
				e["n"] = int(loot["items"][0]["n"])
		KIND_MIMIC:
			e["loot"] = mimic_loot(e["loot"])
	return e


## Verdieping 100: het Warp-kristal erbij. Er is geen baas die het dropt; aankomst legt het in de tas.
## De keuze van de beloning gebeurt pas als het kristal gebruikt wordt.
static func with_warp(loot: Dictionary, floor_nr: int) -> Dictionary:
	if floor_nr != WARP_FLOOR:
		return loot
	var out: Dictionary = loot.duplicate(true)
	var items: Array = out.get("items", [])
	items.append({"item": WARP_ITEM, "n": 1})
	out["items"] = items
	return out
