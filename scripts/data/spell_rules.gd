extends RefCounted
## Wie welke spreuk mag leren, en tot welke grade de winkel gaat.
## Dennis: geen shop-magie (alleen kernkrachten). Grade 4 nooit in de winkel.
## De canon-lijst staat in scripts/data/spells.gd.

const GameData := preload("res://scripts/data/game_data.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")

## Hoogste grade per element. Ontbreekt het element, dan is de spreuk verboden.
const CAP := {
	"dennis": {},
	"noor": {"vuur": 4, "natuur": 4, "bliksem": 4, "licht": 1},
	"lotte": {"licht": 4, "ijs": 4},
	"kael": {"bliksem": 4},
	"orion": {},
}


static func max_grade(hero_id: String, element: String) -> int:
	var row = CAP.get(hero_id, {})
	if not (row is Dictionary):
		return 0
	return int((row as Dictionary).get(element, 0))


static func can_learn(hero_id: String, spell_id: String) -> bool:
	if not GameData.SPELLS.has(spell_id):
		return false
	var sp: Dictionary = GameData.SPELLS[spell_id]
	var grade := int(sp.get("grade", 1))
	return grade >= 1 and grade <= max_grade(hero_id, str(sp.get("element", "")))


## Act 1 = grade 1. Grade 4 is nooit te koop (mini met 3).
static func shop_max_grade(act: int) -> int:
	return mini(maxi(act, 1), 3)


static func in_shop(spell_id: String, act: int) -> bool:
	if not GameData.SPELLS.has(spell_id):
		return false
	var sp: Dictionary = GameData.SPELLS[spell_id]
	if sp.get("shop", true) == false:
		return false
	var grade := int(sp.get("grade", 1))
	return grade >= 1 and grade <= shop_max_grade(act)


## Onderkant op level 1 staat in power. Daarna power_per_level per level erboven.
## Zonder power_per_level blijft de oude formule (power + 2 × level).
static func power_at(spell: Dictionary, level: int) -> float:
	var power := float(spell.get("power", 0))
	if not spell.has("power_per_level"):
		return power + 2.0 * float(level)
	return power + float(spell["power_per_level"]) * float(maxi(0, level - 1))


## Schade- of heal-factor van het element. Zonder doel telt bliksem-tegen-metaal niet mee.
static func factor(spell: Dictionary, caster_id: String, target: Dictionary) -> float:
	var kind := str(spell.get("type", ""))
	var el := str(spell.get("element", ""))
	if kind in ["heal", "hot", "revive"]:
		if el == "licht" and caster_id == "lotte":
			return 1.3
		if el == "licht" and caster_id == "noor":
			return 0.8
		return 1.0
	if kind != "damage":
		return 1.0
	match el:
		"vuur":
			return 1.1
		"natuur":
			return 1.05
		"ijs":
			return 0.9
		"bliksem":
			return 1.15 if is_metal(target) else 1.0
		_:
			return 1.0


## Lotte's licht versterkt een buff met 20%.
static func buff_factor(spell: Dictionary, caster_id: String) -> float:
	if str(spell.get("element", "")) == "licht" and caster_id == "lotte":
		return 1.2
	return 1.0


## Kans dat bliksem (verlamming) of ijs (bevriezing) een beurt laat overslaan (was: altijd).
## Goedgekeurd door Dennis (20 okt 2026), na de gevechtssimulator (docs/BATTLE_BALANCE_REPORT.md).
const STUN_CHANCE := 0.30
## true = bazen worden nooit verlamd/bevroren. Standaard false: de 30% geldt ook voor bazen.
## (De simulator kan true proberen met --stun-boss-immune; dat verandert de standaard niet.)
const STUN_BOSS_IMMUNE := false


## Valt de verlamming/bevriezing van 'fx' (uit on_hit) echt? roll = randf() van het gevecht
## (0..1), zodat een geseede run (simulator, tests) altijd hetzelfde uitkomt.
## chance < 0 = de kans uit fx (STUN_CHANCE); de simulator kan een andere kans meegeven.
static func stun_lands(fx: Dictionary, target_is_boss: bool, roll: float, boss_immune := STUN_BOSS_IMMUNE, chance := -1.0) -> bool:
	if int(fx.get("skip", 0)) <= 0:
		return false
	if target_is_boss and boss_immune:
		return false
	return roll < (chance if chance >= 0.0 else float(fx.get("skip_chance", STUN_CHANCE)))


## Brand, vergif, verlamming of bevriezing na een schade-treffer. {} = geen.
## Verlamming/bevriezing heeft "skip_chance" (STUN_CHANCE): zie stun_lands().
static func on_hit(spell: Dictionary) -> Dictionary:
	if str(spell.get("type", "")) != "damage":
		return {}
	match str(spell.get("element", "")):
		"vuur", "natuur":
			return {"dot_pct": 0.05, "dot_turns": 3}
		"bliksem":
			return {"skip": 1, "skip_reden": "verlamming", "skip_chance": STUN_CHANCE}
		"ijs":
			return {"skip": 1, "skip_reden": "bevriezing", "skip_chance": STUN_CHANCE}
		_:
			return {}


static func is_metal(target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var stats: Dictionary = target.get("s", {}) if target.get("s") is Dictionary else target
	if str(stats.get("element", "")) == "metaal" or str(stats.get("materiaal", "")) == "metaal":
		return true
	var id := str(target.get("id", stats.get("id", "")))
	if CodexData.SPECIES.has(id):
		return str(CodexData.SPECIES[id].get("element", "")) == "metaal"
	return false


static func block_reason(hero: Dictionary, spell_id: String) -> String:
	if can_learn(str(hero.get("id", "")), spell_id):
		return ""
	if str(hero.get("id", "")) == "dennis":
		return "Dax leert geen magie."
	return "%s cannot learn this spell." % str(hero.get("name", "This hero"))
