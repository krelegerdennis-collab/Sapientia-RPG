extends RefCounted
## Blauwe-kistuitrusting van de Diepe Grot, per grade.
## Staat NIET in GameData.EQUIPMENT (die lijst blijft 84 stukken voor het verhaal).
## TODO(design): alle statcijfers, affix-waarden en de grensverdiepingen (hogere grade
## bezit de grens: 20 = grade 2, 50 = grade 3, 80 = grade 4) zijn een conservatieve
## invulling. Dennis heeft de echte cijfers nog niet vastgelegd.
## TODO(design): toekomstige helden krijgen nog geen eigen G4-wapen of set.

const SCROLLS: Array[String] = ["spreuk_inferno", "spreuk_oerwoud", "spreuk_donderslag", "spreuk_aureool", "spreuk_ijskern"]

const ITEMS := {
	# Grade 1, verdieping 1-19. Geen affix.
	"bg_g1_zwaard": {"name": "Grofzwaard", "slot": "wapen", "atk": 6, "grade": 1, "min_floor": 1, "wie": ["krijger"], "affixen": []},
	"bg_g1_staf": {"name": "Takkenstaf", "slot": "wapen", "mag": 6, "grade": 1, "min_floor": 1, "wie": ["magier", "priester"], "affixen": []},
	"bg_g1_helm": {"name": "Leren Kap (grot)", "slot": "helm", "def": 3, "grade": 1, "min_floor": 1, "affixen": []},
	"bg_g1_harnas": {"name": "Leren Jas", "slot": "harnas", "def": 4, "grade": 1, "min_floor": 1, "affixen": []},
	"bg_g1_benen": {"name": "Leren Broek", "slot": "benen", "def": 3, "grade": 1, "min_floor": 10, "affixen": []},
	"bg_g1_laarzen": {"name": "Leren Laarzen", "slot": "laarzen", "agi": 1, "grade": 1, "min_floor": 10, "affixen": []},
	# Grade 2, verdieping 20-49. Geen affix. Stap op 35 = floor-gate binnen de band.
	"bg_g2_zwaard": {"name": "Diepzwaard", "slot": "wapen", "atk": 12, "grade": 2, "min_floor": 20, "wie": ["krijger"], "affixen": []},
	"bg_g2_staf": {"name": "Diepstaf", "slot": "wapen", "mag": 12, "grade": 2, "min_floor": 20, "wie": ["magier", "priester"], "affixen": []},
	"bg_g2_helm": {"name": "Bronzen Kap", "slot": "helm", "def": 6, "grade": 2, "min_floor": 20, "affixen": []},
	"bg_g2_harnas": {"name": "Bronzen Jas", "slot": "harnas", "def": 8, "grade": 2, "min_floor": 35, "affixen": []},
	"bg_g2_benen": {"name": "Bronzen Broek", "slot": "benen", "def": 6, "grade": 2, "min_floor": 35, "affixen": []},
	"bg_g2_laarzen": {"name": "Bronzen Laarzen", "slot": "laarzen", "agi": 2, "grade": 2, "min_floor": 35, "affixen": []},
	# Grade 3, verdieping 50-79. Eén vaste affix per stuk.
	"bg_g3_zwaard": {"name": "Kloofzwaard", "slot": "wapen", "atk": 20, "grade": 3, "min_floor": 50, "wie": ["krijger"],
		"affixen": [{"id": "snee", "stat": "atk", "n": 4, "naam": "Snee"}]},
	"bg_g3_staf": {"name": "Kloofstaf", "slot": "wapen", "mag": 20, "grade": 3, "min_floor": 50, "wie": ["magier", "priester"],
		"affixen": [{"id": "vonk", "stat": "mag", "n": 4, "naam": "Vonk"}]},
	"bg_g3_helm": {"name": "Kloofhelm", "slot": "helm", "def": 10, "grade": 3, "min_floor": 50,
		"affixen": [{"id": "wand", "stat": "def", "n": 4, "naam": "Wand"}]},
	"bg_g3_harnas": {"name": "Kloofjas", "slot": "harnas", "def": 14, "grade": 3, "min_floor": 65,
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 4, "naam": "Sluier"}]},
	"bg_g3_benen": {"name": "Kloofbroek", "slot": "benen", "def": 10, "grade": 3, "min_floor": 65,
		"affixen": [{"id": "wand", "stat": "def", "n": 4, "naam": "Wand"}]},
	"bg_g3_laarzen": {"name": "Klooflaarzen", "slot": "laarzen", "agi": 3, "grade": 3, "min_floor": 65,
		"affixen": [{"id": "pas", "stat": "agi", "n": 4, "naam": "Pas"}]},
	# Grade 4 wapens, alleen vanaf verdieping 80. Uniek per bestaande held.
	"bg_g4_superzwaard": {"name": "Superzwaard", "slot": "wapen", "atk": 32, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "element": "fysiek",
		"affixen": [{"id": "snee", "stat": "atk", "n": 6, "naam": "Snee"}, {"id": "wand", "stat": "def", "n": 4, "naam": "Wand"}]},
	"bg_g4_staf_noor": {"name": "Staf van Noor", "slot": "wapen", "mag": 32, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Groei"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Sluier"}]},
	"bg_g4_staf_lotte": {"name": "Staf van Lotte", "slot": "wapen", "mag": 28, "mdef": 6, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "element": "licht",
		"affixen": [{"id": "glans", "stat": "mag", "n": 6, "naam": "Glans"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Sluier"}]},
	# Grade 4 sets. Vier delen, niet mixen (set_id).
	"bg_g4_plated_helm": {"name": "Platenhelm", "slot": "helm", "def": 16, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "set_id": "plated",
		"affixen": [{"id": "wand", "stat": "def", "n": 6, "naam": "Wand"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Sluier"}]},
	"bg_g4_plated_harnas": {"name": "Platenharnas", "slot": "harnas", "def": 22, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "set_id": "plated",
		"affixen": [{"id": "wand", "stat": "def", "n": 6, "naam": "Wand"}, {"id": "snee", "stat": "atk", "n": 4, "naam": "Snee"}]},
	"bg_g4_plated_benen": {"name": "Platenbroek", "slot": "benen", "def": 14, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "set_id": "plated",
		"affixen": [{"id": "wand", "stat": "def", "n": 6, "naam": "Wand"}, {"id": "last", "stat": "agi", "n": -1, "naam": "Last"}]},
	"bg_g4_plated_laarzen": {"name": "Platenlaarzen", "slot": "laarzen", "def": 10, "grade": 4, "min_floor": 80,
		"wie": ["krijger"], "set_id": "plated",
		"affixen": [{"id": "wand", "stat": "def", "n": 6, "naam": "Wand"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Pas"}]},
	"bg_g4_robes_helm": {"name": "Lichtkap", "slot": "helm", "mdef": 12, "mag": 6, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "set_id": "robes_lotte",
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Sluier"}, {"id": "glans", "stat": "mag", "n": 4, "naam": "Glans"}]},
	"bg_g4_robes_harnas": {"name": "Lichtgewaad", "slot": "harnas", "mdef": 16, "mag": 8, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "set_id": "robes_lotte",
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Sluier"}, {"id": "glans", "stat": "mag", "n": 4, "naam": "Glans"}]},
	"bg_g4_robes_benen": {"name": "Lichtbroek", "slot": "benen", "mdef": 10, "mag": 4, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "set_id": "robes_lotte",
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Sluier"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Pas"}]},
	"bg_g4_robes_laarzen": {"name": "Lichtlaarzen", "slot": "laarzen", "mdef": 8, "agi": 2, "grade": 4, "min_floor": 80,
		"wie": ["priester"], "set_id": "robes_lotte",
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Sluier"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Pas"}]},
	"bg_g4_natuur_helm": {"name": "Natuurkap", "slot": "helm", "mdef": 12, "mag": 6, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "set_id": "robes_noor", "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Groei"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Sluier"}]},
	"bg_g4_natuur_harnas": {"name": "Natuurgewaad", "slot": "harnas", "mdef": 16, "mag": 8, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "set_id": "robes_noor", "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Groei"}, {"id": "sluier", "stat": "mdef", "n": 4, "naam": "Sluier"}]},
	"bg_g4_natuur_benen": {"name": "Natuurbroek", "slot": "benen", "mdef": 10, "mag": 4, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "set_id": "robes_noor", "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Groei"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Pas"}]},
	"bg_g4_natuur_laarzen": {"name": "Natuurlaarzen", "slot": "laarzen", "mdef": 8, "agi": 2, "grade": 4, "min_floor": 80,
		"wie": ["magier"], "set_id": "robes_noor", "element": "natuur",
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Groei"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Pas"}]},
	# Grade 4 accessoires: niet class-gebonden, wel in de G4-buit, vaste affixen.
	"bg_g4_ring_kracht": {"name": "Ring van Kracht", "slot": "accessoire", "atk": 8, "grade": 4, "min_floor": 80,
		"affixen": [{"id": "snee", "stat": "atk", "n": 6, "naam": "Snee"}, {"id": "pas", "stat": "agi", "n": 4, "naam": "Pas"}]},
	"bg_g4_ring_wil": {"name": "Ring van Wil", "slot": "accessoire", "mdef": 8, "grade": 4, "min_floor": 80,
		"affixen": [{"id": "sluier", "stat": "mdef", "n": 6, "naam": "Sluier"}, {"id": "glans", "stat": "mag", "n": 4, "naam": "Glans"}]},
	"bg_g4_amulet": {"name": "Amulet van de Grot", "slot": "accessoire", "mag": 8, "grade": 4, "min_floor": 80,
		"affixen": [{"id": "groei", "stat": "mag", "n": 6, "naam": "Groei"}, {"id": "wand", "stat": "def", "n": 4, "naam": "Wand"}]},
}


static func has_item(id: String) -> bool:
	return ITEMS.has(id)


static func item(id: String) -> Dictionary:
	var it = ITEMS.get(id, {})
	return (it as Dictionary).duplicate(true) if it is Dictionary else {}


static func is_scroll(id: String) -> bool:
	return id in SCROLLS


## TODO(design): grens hoort bij de hogere grade (20/50/80).
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
