extends RefCounted
class_name PvpCharacters
## Gekopieerde momentopname van de drie helden op level 1, plus groei per level.
## Formule (vastgelegd voor PvP): stat = basis_L1 + groei * (level - 1).
## Geldt voor max_hp, max_mp, atk, def, agi, mag en mdef.
## TODO(design): teams herzien zodra er meer main characters zijn.


const HEROES := {
	"dennis": {
		"id": "dennis",
		"name": "Dennis",
		"equip_type": "krijger",
		"color": "c8c8d0",
		"max_hp": 42, "max_mp": 0, "atk": 14, "def": 8, "agi": 9, "mag": 2, "mdef": 4,
		"spells": [],
		"growth": {"max_hp": 9, "max_mp": 0, "atk": 3, "def": 2, "agi": 1, "mag": 0, "mdef": 1},
	},
	"noor": {
		"id": "noor",
		"name": "Noor",
		"equip_type": "magier",
		"color": "e040a0",
		"max_hp": 28, "max_mp": 18, "atk": 7, "def": 5, "agi": 11, "mag": 10, "mdef": 8,
		"spells": ["vuur", "bliksem"],
		"growth": {"max_hp": 5, "max_mp": 4, "atk": 1, "def": 1, "agi": 2, "mag": 2, "mdef": 2},
	},
	"lotte": {
		"id": "lotte",
		"name": "Lotte",
		"equip_type": "priester",
		"color": "40d0e0",
		"max_hp": 32, "max_mp": 14, "atk": 9, "def": 6, "agi": 7, "mag": 7, "mdef": 9,
		"spells": ["genees"],
		"growth": {"max_hp": 6, "max_mp": 3, "atk": 2, "def": 1, "agi": 1, "mag": 2, "mdef": 2},
	},
}

const STATS: Array[String] = ["max_hp", "max_mp", "atk", "def", "agi", "mag", "mdef"]


static func has_character(id: String) -> bool:
	return HEROES.has(id)


static func stat_at(base_l1: int, growth: int, level: int) -> int:
	return base_l1 + growth * (maxi(1, level) - 1)


static func scaled(id: String, level: int) -> Dictionary:
	var src: Dictionary = HEROES[id]
	var growth: Dictionary = src["growth"]
	var lv := maxi(1, level)
	var out := {
		"id": id,
		"name": str(src["name"]),
		"equip_type": str(src["equip_type"]),
		"color": str(src["color"]),
		"level": lv,
		"spells": (src["spells"] as Array).duplicate(),
	}
	for stat in STATS:
		out[stat] = stat_at(int(src[stat]), int(growth[stat]), lv)
	return out


static func color_of(id: String) -> Color:
	if not HEROES.has(id):
		return Color(0.5, 0.5, 0.5)
	return Color.html(str(HEROES[id]["color"]))
