extends RefCounted
class_name PvpLoadouts
## Uitrusting per modus, gekopieerd als platte bonussen.
## Vroeg: startset. Dennis: kort zwaard. Noor: eiken staf + reisgewaad.
## Lotte (priester) draagt dezelfde staf en hetzelfde gewaad.
## Midden en hoog: kleine subset, totalen inclusief de vaste affix.
## TODO(design): de exacte stukken voor grade 1-2 en grade 3-4 zijn nog niet vast.


const GEAR := {
	"kort_zwaard": {"name": "Kort zwaard", "slot": "wapen", "atk": 3, "wie": ["krijger"]},
	"eiken_staf": {"name": "Eiken staf", "slot": "wapen", "atk": 2, "mag": 4, "wie": ["magier", "priester"]},
	"reisgewaad": {"name": "Reisgewaad", "slot": "harnas", "def": 1, "mdef": 2, "wie": ["magier", "priester"]},
	# Grade 1-2 (midden). Bron-ids ter referentie, cijfers gekopieerd.
	"bg_g1_staf": {"name": "Takkenstaf", "slot": "wapen", "mag": 6, "wie": ["magier", "priester"]},
	"bg_g1_harnas": {"name": "Leren Jas", "slot": "harnas", "def": 4, "wie": ["krijger", "magier", "priester"]},
	"bg_g2_zwaard": {"name": "Diepzwaard", "slot": "wapen", "atk": 12, "wie": ["krijger"]},
	"bg_g2_staf": {"name": "Diepstaf", "slot": "wapen", "mag": 12, "wie": ["magier", "priester"]},
	"bg_g2_helm": {"name": "Bronzen Kap", "slot": "helm", "def": 6, "wie": ["krijger", "magier", "priester"]},
	"bg_g2_harnas": {"name": "Bronzen Jas", "slot": "harnas", "def": 8, "wie": ["krijger", "magier", "priester"]},
	# Grade 3-4 (hoog). Affix al opgeteld: Superzwaard 32+6 aanval en +4 verdediging,
	# Kloofhelm 10+4, Staf van Noor 32+6 magie en +4 mdef, Staf van Lotte 28+6 magie en 6+4 mdef,
	# Platenharnas 22+6 verdediging, Natuurkap 12 mdef + 6+6 magie, Lichtkap 12+6 mdef en 6+4 magie.
	"bg_g4_superzwaard": {"name": "Superzwaard", "slot": "wapen", "atk": 38, "def": 4, "wie": ["krijger"]},
	"bg_g3_helm": {"name": "Kloofhelm", "slot": "helm", "def": 14, "wie": ["krijger", "magier", "priester"]},
	"bg_g4_plated_harnas": {"name": "Platenharnas", "slot": "harnas", "def": 28, "wie": ["krijger"]},
	"bg_g4_staf_noor": {"name": "Staf van Noor", "slot": "wapen", "mag": 38, "mdef": 4, "wie": ["magier"]},
	"bg_g4_natuur_helm": {"name": "Natuurkap", "slot": "helm", "mag": 12, "mdef": 12, "wie": ["magier"]},
	"bg_g4_staf_lotte": {"name": "Staf van Lotte", "slot": "wapen", "mag": 34, "mdef": 10, "wie": ["priester"]},
	"bg_g4_robes_helm": {"name": "Lichtkap", "slot": "helm", "mag": 10, "mdef": 18, "wie": ["priester"]},
}

const BY_MODE := {
	"early": {
		"krijger": ["kort_zwaard"],
		"magier": ["eiken_staf", "reisgewaad"],
		"priester": ["eiken_staf", "reisgewaad"],
	},
	"mid": {
		"krijger": ["bg_g2_zwaard", "bg_g2_helm", "bg_g1_harnas"],
		"magier": ["bg_g2_staf", "bg_g2_helm"],
		"priester": ["bg_g1_staf", "bg_g2_harnas"],
	},
	"high": {
		"krijger": ["bg_g4_superzwaard", "bg_g3_helm", "bg_g4_plated_harnas"],
		"magier": ["bg_g4_staf_noor", "bg_g4_natuur_helm"],
		"priester": ["bg_g4_staf_lotte", "bg_g4_robes_helm"],
	},
}

const BONUS_STATS: Array[String] = ["atk", "def", "mag", "mdef", "agi"]


static func gear_ids(equip_type: String, mode_id: String) -> Array:
	var table: Dictionary = BY_MODE["early"]
	if BY_MODE.has(mode_id):
		table = BY_MODE[mode_id]
	if not table.has(equip_type):
		return []
	return (table[equip_type] as Array).duplicate()


static func bonuses(equip_type: String, mode_id: String) -> Dictionary:
	var total := {"atk": 0, "def": 0, "mag": 0, "mdef": 0, "agi": 0}
	for raw in gear_ids(equip_type, mode_id):
		var id := str(raw)
		if not GEAR.has(id):
			continue
		var piece: Dictionary = GEAR[id]
		for stat in BONUS_STATS:
			total[stat] = int(total[stat]) + int(piece.get(stat, 0))
	return total
