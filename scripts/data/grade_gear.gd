extends RefCounted
## Blauwe-kistuitrusting van de Diepe Grot, per grade.
## Staat NIET in GameData.EQUIPMENT (het verhaal blijft 84 stukken; de Simulatie-ring is het 85e, geen kistloot).
## Bevestigd: statcijfers, affix-waarden en de grensverdiepingen (hogere grade
## bezit de grens: 20 = grade 2, 50 = grade 3, 80 = grade 4).
## TODO(design): toekomstige helden krijgen nog geen eigen G4-wapen of set.

## Eén rol per canon-spreuk met grade 4 (scripts/data/spells.gd). Alleen in deze pool,
## en pick stopt ze pas bij grade 4 (verdieping 80+). Niet de oude vijf rol-ids.
const SCROLLS: Array[String] = [
	"spreuk_g4_zonneslag", "spreuk_g4_apocalyps", "spreuk_g4_dageraad", "spreuk_g4_zuiverende_vlam",
	"spreuk_g4_zielenbloei", "spreuk_g4_oerbos", "spreuk_g4_moeder_aarde", "spreuk_g4_wildgroei",
	"spreuk_g4_hemelval", "spreuk_g4_donderslag", "spreuk_g4_stormheer", "spreuk_g4_zuiverende_donder",
	"spreuk_g4_wederopstanding", "spreuk_g4_heilige_straal", "spreuk_g4_aureool", "spreuk_g4_zegen_der_goden",
	"spreuk_g4_eeuwige_winter", "spreuk_g4_absolute_nul", "spreuk_g4_ijskern", "spreuk_g4_sneeuwkoningin",
]
## Oude rol-ids. Blijven opzoekbaar voor een save of test, maar niet meer in de grade-4-pool.
const LEGACY_SCROLLS: Array[String] = ["spreuk_inferno", "spreuk_oerwoud", "spreuk_donderslag", "spreuk_aureool", "spreuk_ijskern"]

const ITEMS := {
	# Grade 1, verdieping 1-19. Geen affix.
	"bg_g1_zwaard": {"name": "Rough Sword", "slot": "wapen", "atk": 6, "grade": 1, "min_floor": 1, "wie": ["krijger"], "affixen": []},
	"bg_g1_staf": {"name": "Branch Staff", "slot": "wapen", "mag": 6, "grade": 1, "min_floor": 1, "wie": ["magier", "priester"], "affixen": []},
	"bg_g1_helm": {"name": "Cave Leather Hood", "slot": "helm", "def": 3, "grade": 1, "min_floor": 1, "affixen": []},
	"bg_g1_harnas": {"name": "Leather Coat", "slot": "harnas", "def": 4, "grade": 1, "min_floor": 1, "affixen": []},
	"bg_g1_benen": {"name": "Leather Greaves", "slot": "benen", "def": 3, "grade": 1, "min_floor": 10, "affixen": []},
	"bg_g1_laarzen": {"name": "Leather Boots", "slot": "laarzen", "agi": 1, "grade": 1, "min_floor": 10, "affixen": []},
	# Grade 2, verdieping 20-49. Geen affix. Stap op 35 = floor-gate binnen de band.
	"bg_g2_zwaard": {"name": "Deep Sword", "slot": "wapen", "atk": 12, "grade": 2, "min_floor": 20, "wie": ["krijger"], "affixen": []},
	"bg_g2_staf": {"name": "Deep Staff", "slot": "wapen", "mag": 12, "grade": 2, "min_floor": 20, "wie": ["magier", "priester"], "affixen": []},
	"bg_g2_helm": {"name": "Bronze Hood", "slot": "helm", "def": 6, "grade": 2, "min_floor": 20, "affixen": []},
	"bg_g2_harnas": {"name": "Bronze Coat", "slot": "harnas", "def": 8, "grade": 2, "min_floor": 35, "affixen": []},
	"bg_g2_benen": {"name": "Bronze Greaves", "slot": "benen", "def": 6, "grade": 2, "min_floor": 35, "affixen": []},
	"bg_g2_laarzen": {"name": "Bronze Boots", "slot": "laarzen", "agi": 2, "grade": 2, "min_floor": 35, "affixen": []},
	# Grade 3, verdieping 50-79. Eén vaste affix per stuk.
	"bg_g3_zwaard": {"name": "Rift Sword", "slot": "wapen", "atk": 20, "grade": 3, "min_floor": 50, "wie": ["krijger"],
		"affixen": [{"id": "snee", "stat": "atk", "n": 4, "naam": "Edge"}]},
	"bg_g3_staf": {"name": "Rift Staff", "slot": "wapen", "mag": 20, "grade": 3, "min_floor": 50, "wie": ["magier", "priester"],
		"affixen": [{"id": "vonk", "stat": "mag", "n": 4, "naam": "Spark"}]},
	"bg_g3_helm": {"name": "Rift Helm", "slot": "helm", "def": 10, "grade": 3, "min_floor": 50,
		"affixen": [{"id": "wand", "stat": "def", "n": 4, "naam": "Wall"}]},
	"bg_g3_harnas": {"name": "Rift Coat", "slot": "harnas", "def": 14, "grade": 3, "min_floor": 65,
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 4, "naam": "Veil"}]},
	"bg_g3_benen": {"name": "Rift Greaves", "slot": "benen", "def": 10, "grade": 3, "min_floor": 65,
		"affixen": [{"id": "wand", "stat": "def", "n": 4, "naam": "Wall"}]},
	"bg_g3_laarzen": {"name": "Rift Boots", "slot": "laarzen", "agi": 3, "grade": 3, "min_floor": 65,
		"affixen": [{"id": "pas", "stat": "agi", "n": 4, "naam": "Stride"}]},
	# Grade 4 wapens, alleen vanaf verdieping 80. Uniek per bestaande held.
	"bg_g4_superzwaard": {"name": "Super Sword", "slot": "wapen", "atk": 32, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "element": "fysiek",
		"affixen": [{"id": "snee", "stat": "atk", "n": 6, "naam": "Edge"}, {"id": "wand", "stat": "def", "n": 4, "naam": "Wall"}]},
	"bg_g4_staf_noor": {"name": "Vesper's Staff", "slot": "wapen", "mag": 32, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Growth"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Veil"}]},
	"bg_g4_staf_lotte": {"name": "Seren's Staff", "slot": "wapen", "mag": 28, "mdef": 6, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "element": "licht",
		"affixen": [{"id": "glans", "stat": "mag", "n": 6, "naam": "Gleam"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Veil"}]},
	# Grade 4 sets. Vier delen, niet mixen (set_id).
	"bg_g4_plated_helm": {"name": "Plate Helm", "slot": "helm", "def": 16, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "set_id": "plated",
		"affixen": [{"id": "wand", "stat": "def", "n": 6, "naam": "Wall"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Veil"}]},
	"bg_g4_plated_harnas": {"name": "Plate Armor", "slot": "harnas", "def": 22, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "set_id": "plated",
		"affixen": [{"id": "wand", "stat": "def", "n": 6, "naam": "Wall"}, {"id": "snee", "stat": "atk", "n": 4, "naam": "Edge"}]},
	"bg_g4_plated_benen": {"name": "Plate Greaves", "slot": "benen", "def": 14, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "set_id": "plated",
		"affixen": [{"id": "wand", "stat": "def", "n": 6, "naam": "Wall"}, {"id": "last", "stat": "agi", "n": -1, "naam": "Burden"}]},
	"bg_g4_plated_laarzen": {"name": "Plate Boots", "slot": "laarzen", "def": 10, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "set_id": "plated",
		"affixen": [{"id": "wand", "stat": "def", "n": 6, "naam": "Wall"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Stride"}]},
	"bg_g4_robes_helm": {"name": "Light Hood", "slot": "helm", "mdef": 12, "mag": 6, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "set_id": "robes_lotte",
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Veil"}, {"id": "glans", "stat": "mag", "n": 4, "naam": "Gleam"}]},
	"bg_g4_robes_harnas": {"name": "Light Robe", "slot": "harnas", "mdef": 16, "mag": 8, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "set_id": "robes_lotte",
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Veil"}, {"id": "glans", "stat": "mag", "n": 4, "naam": "Gleam"}]},
	"bg_g4_robes_benen": {"name": "Light Greaves", "slot": "benen", "mdef": 10, "mag": 4, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "set_id": "robes_lotte",
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Veil"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Stride"}]},
	"bg_g4_robes_laarzen": {"name": "Light Boots", "slot": "laarzen", "mdef": 8, "agi": 2, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "set_id": "robes_lotte",
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Veil"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Stride"}]},
	"bg_g4_natuur_helm": {"name": "Nature Hood", "slot": "helm", "mdef": 12, "mag": 6, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "set_id": "robes_noor", "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Growth"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Veil"}]},
	"bg_g4_natuur_harnas": {"name": "Nature Robe", "slot": "harnas", "mdef": 16, "mag": 8, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "set_id": "robes_noor", "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Growth"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Veil"}]},
	"bg_g4_natuur_benen": {"name": "Nature Greaves", "slot": "benen", "mdef": 10, "mag": 4, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "set_id": "robes_noor", "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Growth"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Stride"}]},
	"bg_g4_natuur_laarzen": {"name": "Nature Boots", "slot": "laarzen", "mdef": 8, "agi": 2, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "set_id": "robes_noor", "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Growth"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Stride"}]},
	# Grade 4 accessoires: niet class-gebonden, wel in de G4-buit, vaste affixen.
	"bg_g4_ring_kracht": {"name": "Ring of Strength", "slot": "accessoire", "atk": 8, "grade": 4, "min_floor": 80,
		"affixen": [{"id": "snee", "stat": "atk", "n": 6, "naam": "Edge"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Stride"}]},
	"bg_g4_ring_wil": {"name": "Ring of Will", "slot": "accessoire", "mdef": 8, "grade": 4, "min_floor": 80,
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Veil"}, {"id": "glans", "stat": "mag", "n": 4, "naam": "Gleam"}]},
	"bg_g4_amulet": {"name": "Cave Amulet", "slot": "accessoire", "mag": 8, "grade": 4, "min_floor": 80,
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Growth"}, {"id": "wand", "stat": "def", "n": 4, "naam": "Wall"}]},
}


static func has_item(id: String) -> bool:
	return ITEMS.has(id)


static func item(id: String) -> Dictionary:
	var it = ITEMS.get(id, {})
	return (it as Dictionary).duplicate(true) if it is Dictionary else {}


static func is_scroll(id: String) -> bool:
	return id in SCROLLS


static func is_legacy_scroll(id: String) -> bool:
	return id in LEGACY_SCROLLS


## Bevestigd: grens hoort bij de hogere grade (20/50/80).
static func grade_for_floor(floor_nr: int) -> int:
	if floor_nr < 1:
		return 0
	if floor_nr < 20:
		return 1
	if floor_nr < 50:
		return 2
	if floor_nr < 80:
		return 3
	return 4


static func affix_count(id: String) -> int:
	var ax = item(id).get("affixen", [])
	return (ax as Array).size() if ax is Array else 0


## Deterministische keus. Verdieping 100 (baas, normaal geen blauwe kist) gebruikt de band van 99.
static func pick(run_seed: int, floor_nr: int, chest_id: String) -> String:
	var gate := floor_nr
	if floor_nr >= 100:
		gate = 99
	elif floor_nr < 1:
		gate = 1
	var grade := grade_for_floor(gate)
	var pool: Array[String] = []
	for id in ITEMS:
		var it: Dictionary = ITEMS[id]
		if int(it.get("grade", 0)) == grade and int(it.get("min_floor", 1)) <= gate:
			pool.append(str(id))
	if grade == 4:
		for id in SCROLLS:
			pool.append(id)
	if pool.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%d|%s|grade" % [run_seed, floor_nr, chest_id])
	return pool[rng.randi_range(0, pool.size() - 1)]
