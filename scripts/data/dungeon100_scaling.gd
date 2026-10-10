extends RefCounted
## Task #4 "Monsterschaal en buit" voor de dungeon van 100 verdiepingen (zie HANDOFF_DUNGEON100_SCHAAL.md).
## Alleen PURE, statische functies (geen scène, geen autoload nodig): los te testen met
## scripts/tests/dungeon100_schaal_tests.gd. De huidige verdieping is GameState.dungeon100_floor
## (1..100, 0 = niet in de dungeon); battle.gd, dungeon_chest.gd en map_monster.gd roepen dit alleen
## aan als die > 0 is. Bij verdieping 0 verandert er dus NIETS aan bestaand gedrag.
## Alle getallen hieronder zijn VOORLOPIG (nog niet gebalanceerd met een simulatie).
## (preload i.p.v. class_name, zoals scripts/equipment.gd)

const GameData := preload("res://scripts/data/game_data.gd")

const MAX_FLOOR := 100
## Elke 10e verdieping (10, 20, ... 100) is een baasverdieping; 100 is de eindbaas.
const BOSS_INTERVAL := 10
## Buitniveau (1..5): elke 20 verdiepingen een niveau hoger.
const TIER_INTERVAL := 20
const MAX_TIER := 5

# ---------------------------------------------------------------- schaalcurves
## n = verdieping - 1 (verdieping 1 = de basiswaarden van de vijand, ongewijzigd).
## HP     = basis x (1 + 0,10n + 0,0015n^2) + 2n
## ATK    = basis x (1 + 0,03n) + 0,8n          (mag idem, +0,5n)
## DEF    = basis x (1 + 0,03n) + 0,5n          (mdef idem)
## SPD    = basis + 0,1n
## EXP    = basis x (1 + 0,10n + 0,006n^2)      (verdieping 100: ~70x; levels volgen exp_for_level)
## GOUD   = basis x (1 + 0,10n + 0,002n^2)
const HP_LIN := 0.10
const HP_QUAD := 0.0015
const HP_FLAT := 2.0
const ATK_MULT := 0.03
const ATK_FLAT := 0.8
const DEF_MULT := 0.03
const DEF_FLAT := 0.5
const MAG_FLAT := 0.5
const AGI_FLAT := 0.1
const EXP_LIN := 0.10
const EXP_QUAD := 0.006
const GOLD_LIN := 0.10
const GOLD_QUAD := 0.002

# ---------------------------------------------------------------- bazen
## Basis-stats van een baas (de curves hierboven worden er eerst op losgelaten); het sprite, de
## naam en de skills komen van de gekozen vijand (BOSSES). Daarna de bazen-vermenigvuldigers.
const BOSS_BASE := {"max_hp": 120, "atk": 24, "def": 14, "agi": 8, "mag": 12, "mdef": 10, "exp": 60, "gold": 40}
const BOSS_MULT := {"max_hp": 2.5, "atk": 1.25, "def": 1.2, "mag": 1.2, "mdef": 1.2, "exp": 5.0, "gold": 5.0}
## De eindbaas (verdieping 100) krijgt hier nog bovenop.
const FINAL_MULT := {"max_hp": 1.3, "atk": 1.15, "def": 1.1, "mag": 1.15, "mdef": 1.1, "exp": 3.0, "gold": 3.0}
## Baas per 10e verdieping. "enemy" = bestaande vijand uit game_data.gd (sprite + skills, nog
## PLACEHOLDER-art: geen eigen art per baas), "name" = naam in het gevecht (max. ~20 tekens).
const BOSSES := {
	10: {"enemy": "papiergeest", "name": "Bladzijdenwachter"},
	20: {"enemy": "glitchmot", "name": "Glitchkoningin"},
	30: {"enemy": "sporenzwam", "name": "Sporenvorst"},
	40: {"enemy": "wortelkruiper", "name": "Wortelmoeder"},
	50: {"enemy": "mech_wachter", "name": "Wachter-Kolos"},
	60: {"enemy": "mistuil", "name": "Mistheer"},
	70: {"enemy": "mech_wachter", "name": "Zegelwachter"},
	80: {"enemy": "kennis_beest", "name": "Grote Boekengolem"},
	90: {"enemy": "wortelkoning", "name": "Wortelkeizer"},
	100: {"enemy": "kennis_beest", "name": "De Laatste Wachter"},
}
## Extra skill van de eindbaas (bovenop de skills van zijn vijand-sprite).
const FINAL_SKILL := {"name": "Laatste Oordeel", "chance": 0.15, "power": 2.0}
## Skill voor een baas als zijn vijand er geen heeft.
const DEFAULT_BOSS_SKILL := {"name": "Zware Slag", "chance": 0.2, "power": 1.5}
const FLAG_BOSS := "dungeon100_boss:"

# ---------------------------------------------------------------- buit
## Genees-items per buitniveau (index 0 = niveau 1).
const POTIONS := [
	["drankje", "toverwater"],
	["drankje", "kruid", "sterk_drankje"],
	["sterk_drankje", "toverwater", "toverbrouwsel"],
	["sterk_drankje", "toverbrouwsel", "elixer"],
	["elixer", "toverbrouwsel", "elixer"],
]
## Aantal genees-items per kist (min, max) per buitniveau.
const POTION_COUNT := [[1, 2], [1, 3], [2, 3], [2, 4], [3, 5]]
## Uitrusting per soort en niveau (niveau 1 = bestaande stukken, 2-5 = d100_* in game_data.gd).
const GEAR := {
	"zwaard": ["kort_zwaard", "d100_zwaard_2", "d100_zwaard_3", "d100_zwaard_4", "d100_zwaard_5"],
	"staf": ["eiken_staf", "d100_staf_2", "d100_staf_3", "d100_staf_4", "d100_staf_5"],
	"schild": ["houten_schild", "d100_schild_2", "d100_schild_3", "d100_schild_4", "d100_schild_5"],
	"helm": ["leren_kap", "d100_helm_2", "d100_helm_3", "d100_helm_4", "d100_helm_5"],
	"harnas": ["leren_harnas", "d100_harnas_2", "d100_harnas_3", "d100_harnas_4", "d100_harnas_5"],
	"ring": ["bladwijzer", "d100_ring_2", "d100_ring_3", "d100_ring_4", "d100_ring_5"],
}
## Volgorde van GEAR-soorten (vaste volgorde: dezelfde seed geeft dezelfde buit).
const GEAR_KINDS := ["zwaard", "staf", "schild", "helm", "harnas", "ring"]
## Kans op een uitrustingsstuk in een gewone kist: 15% op verdieping 1, +0,25% per verdieping (40% op 100).
const CHEST_GEAR_BASE := 0.15
const CHEST_GEAR_PER_FLOOR := 0.0025
## Kans dat het stuk uit een gewone kist een niveau lager is (afwisseling).
const CHEST_LOWER_TIER_CHANCE := 0.3
## Kistgoud = (10 + 4f + 0,2f^2) x 0,8..1,2. Baasbuit: x BOSS_GOLD_MULT.
const CHEST_GOLD_BASE := 10.0
const CHEST_GOLD_LIN := 4.0
const CHEST_GOLD_QUAD := 0.2
const BOSS_GOLD_MULT := 6.0
## Een leeg boek (Codex) komt vanaf buitniveau 2 soms mee.
const BOOK_CHANCE := 0.1
const BOOK_ID := "leeg_boek"


# ---------------------------------------------------------------- verdiepingen
static func clamp_floor(floor_nr: int) -> int:
	return clampi(floor_nr, 0, MAX_FLOOR)


## Baasverdieping = 10, 20, ... 100.
static func is_boss_floor(floor_nr: int) -> bool:
	return floor_nr >= BOSS_INTERVAL and floor_nr <= MAX_FLOOR and floor_nr % BOSS_INTERVAL == 0


static func is_final_floor(floor_nr: int) -> bool:
	return floor_nr == MAX_FLOOR


## Volgnummer van de baas: 1 (verdieping 10) .. 10 (verdieping 100); 0 = geen baasverdieping.
@warning_ignore("integer_division")
static func boss_index(floor_nr: int) -> int:
	return floor_nr / BOSS_INTERVAL if is_boss_floor(floor_nr) else 0


## Alle baasverdiepingen: [10, 20, ..., 100].
static func boss_floors() -> Array:
	var out := []
	var f := BOSS_INTERVAL
	while f <= MAX_FLOOR:
		out.append(f)
		f += BOSS_INTERVAL
	return out


## Buitniveau 1..5 van een verdieping (0 buiten de dungeon). 1-20 = 1, 21-40 = 2, ... 81-100 = 5.
@warning_ignore("integer_division")
static func tier_for_floor(floor_nr: int) -> int:
	if floor_nr <= 0:
		return 0
	return clampi(1 + (clamp_floor(floor_nr) - 1) / TIER_INTERVAL, 1, MAX_TIER)


## Naam van de vlag in GameState.story_flags die gezet wordt als de baas van deze verdieping
## verslagen is (de generator kan er mee bepalen of de baas terugkomt).
static func boss_flag(floor_nr: int) -> String:
	return FLAG_BOSS + str(floor_nr)


static func boss_defeated(floor_nr: int, flags: Dictionary) -> bool:
	return flags.has(boss_flag(floor_nr))


# ---------------------------------------------------------------- monsterstats
static func _n(floor_nr: int) -> float:
	return float(clamp_floor(floor_nr) - 1)


static func hp_mult(floor_nr: int) -> float:
	var n := _n(floor_nr)
	return 1.0 + HP_LIN * n + HP_QUAD * n * n


static func exp_mult(floor_nr: int) -> float:
	var n := _n(floor_nr)
	return 1.0 + EXP_LIN * n + EXP_QUAD * n * n


static func gold_mult(floor_nr: int) -> float:
	var n := _n(floor_nr)
	return 1.0 + GOLD_LIN * n + GOLD_QUAD * n * n


## Kopie van vijand-data voor deze verdieping. floor_nr <= 0: exact dezelfde data terug (onveranderd).
## Verdieping 1 = basiswaarden. Een baas (data["boss"]) wordt NIET hierdoor geschaald: zie boss_stats().
static func monster_stats(base: Dictionary, floor_nr: int) -> Dictionary:
	if floor_nr <= 0:
		return base
	var f := clamp_floor(floor_nr)
	var n := _n(f)
	var d := base.duplicate(true)
	d["max_hp"] = maxi(1, GameData.round_half_even(float(base["max_hp"]) * hp_mult(f) + HP_FLAT * n))
	d["atk"] = GameData.round_half_even(float(base["atk"]) * (1.0 + ATK_MULT * n) + ATK_FLAT * n)
	d["def"] = GameData.round_half_even(float(base["def"]) * (1.0 + DEF_MULT * n) + DEF_FLAT * n)
	d["agi"] = int(base.get("agi", 0)) + GameData.round_half_even(AGI_FLAT * n)
	if base.has("mag"):
		d["mag"] = GameData.round_half_even(float(base["mag"]) * (1.0 + ATK_MULT * n) + MAG_FLAT * n)
	if base.has("mdef"):
		d["mdef"] = GameData.round_half_even(float(base["mdef"]) * (1.0 + DEF_MULT * n) + DEF_FLAT * n)
	d["exp"] = GameData.round_half_even(float(base.get("exp", 0)) * exp_mult(f))
	d["gold"] = GameData.round_half_even(float(base.get("gold", 0)) * gold_mult(f))
	d["dungeon100_floor"] = f
	return d


# ---------------------------------------------------------------- bazen
## De baas van een baasverdieping: {"floor", "index", "enemy", "name", "final"}; {} als het geen
## baasverdieping is.
static func boss_for_floor(floor_nr: int) -> Dictionary:
	if not is_boss_floor(floor_nr):
		return {}
	var b: Dictionary = BOSSES[floor_nr]
	return {"floor": floor_nr, "index": boss_index(floor_nr), "enemy": str(b["enemy"]), "name": str(b["name"]),
			"final": is_final_floor(floor_nr)}


## Vijand-data voor een baasgevecht op deze verdieping (floor_nr <= 0: data ongewijzigd). De stats komen
## uit BOSS_BASE (curves x bazen-vermenigvuldigers), art/skills uit 'base' (de vijand van de baas,
## een eventueel "boss"-blok en de roze kern van de Golem blijven er buiten: die zijn niet voor deze schaal).
## Geen baasverdieping (bv. een eigen eindbaas van de generator): zelfde formule, naam blijft.
static func boss_stats(base: Dictionary, floor_nr: int) -> Dictionary:
	if floor_nr <= 0:
		return base
	var f := clamp_floor(floor_nr)
	var d := monster_stats(BOSS_BASE, f)
	var out := base.duplicate(true)
	out.erase("boss")
	out.erase("core")
	var final := is_final_floor(f)
	for k in ["max_hp", "atk", "def", "agi", "mag", "mdef", "exp", "gold"]:
		var v := float(d[k])
		v *= float(BOSS_MULT.get(k, 1.0))
		if final:
			v *= float(FINAL_MULT.get(k, 1.0))
		out[k] = GameData.round_half_even(v)
	out["max_hp"] = maxi(1, int(out["max_hp"]))
	var info := boss_for_floor(f)
	if not info.is_empty():
		out["name"] = info["name"]
	var skills: Array = (out.get("skills", []) as Array).duplicate(true)
	if skills.is_empty():
		skills.append(DEFAULT_BOSS_SKILL.duplicate())
	if final:
		skills.append(FINAL_SKILL.duplicate())
	out["skills"] = skills
	out["boss_floor"] = f
	out["dungeon100_floor"] = f
	return out


## Wat battle.gd per vijand aanroept: de data voor dit gevecht. floor_nr <= 0 = ongewijzigd.
## 'boss' = baasgevecht (GameState.pending_boss).
static func battle_enemy(data: Dictionary, floor_nr: int, boss: bool) -> Dictionary:
	if floor_nr <= 0:
		return data
	return boss_stats(data, floor_nr) if boss else monster_stats(data, floor_nr)


# ---------------------------------------------------------------- buit
## Eén genees-item of uitrustingsstuk is {"item": id, "n": aantal}. Een buitlijst is
## {"tier": 1..5, "items": [...], "gold": int, "boss": bool}.
static func gear_id(kind: String, tier: int) -> String:
	if not GEAR.has(kind):
		return ""
	return str(GEAR[kind][clampi(tier, 1, MAX_TIER) - 1])


static func gear_kinds() -> Array:
	return GEAR_KINDS.duplicate()


static func chest_gold_base(floor_nr: int) -> float:
	var f := float(clamp_floor(floor_nr))
	return CHEST_GOLD_BASE + CHEST_GOLD_LIN * f + CHEST_GOLD_QUAD * f * f


static func gear_chance(floor_nr: int) -> float:
	return CHEST_GEAR_BASE + CHEST_GEAR_PER_FLOOR * float(clamp_floor(floor_nr))


## Buit van een gewone kist op deze verdieping. 'rng' = RandomNumberGenerator (of iets met
## randf() / randi_range()): zelfde seed = zelfde buit. Altijd minstens 1 genees-item + goud;
## uitrusting met kans gear_chance(). floor_nr <= 0: lege buit. boss = true: baaskist (boss_loot()).
static func chest_loot(floor_nr: int, rng, boss := false) -> Dictionary:
	if floor_nr <= 0:
		return {"tier": 0, "items": [], "gold": 0, "boss": false}
	if boss:
		return boss_loot(floor_nr, rng)
	var f := clamp_floor(floor_nr)
	var tier := tier_for_floor(f)
	var items: Array = [_potion(tier, rng)]
	if rng.randf() < gear_chance(f):
		var gt := tier
		if tier > 1 and rng.randf() < CHEST_LOWER_TIER_CHANCE:
			gt = tier - 1
		items.append({"item": gear_id(GEAR_KINDS[rng.randi_range(0, GEAR_KINDS.size() - 1)], gt), "n": 1})
	if tier >= 2 and rng.randf() < BOOK_CHANCE:
		items.append({"item": BOOK_ID, "n": 1})
	var gold := GameData.round_half_even(chest_gold_base(f) * rng.randf_range(0.8, 1.2))
	return {"tier": tier, "items": items, "gold": gold, "boss": false}


## Gegarandeerde buit na een baas: veel goud, een uitrustingsstuk van een niveau BOVEN de gewone
## kisten (max. 5), 3 genees-items. Eindbaas (100): van elke soort uitrusting niveau 5, 5 elixers
## en vijfmaal zo veel goud als een gewone baas.
static func boss_loot(floor_nr: int, rng) -> Dictionary:
	if floor_nr <= 0:
		return {"tier": 0, "items": [], "gold": 0, "boss": false}
	var f := clamp_floor(floor_nr)
	var tier := tier_for_floor(f)
	var gear_tier := mini(MAX_TIER, tier + 1)
	var items: Array = []
	var pot: Dictionary = _potion(tier, rng)
	pot["n"] = int(pot["n"]) + 2
	items.append(pot)
	var gold_mult_boss := BOSS_GOLD_MULT
	if is_final_floor(f):
		for kind in GEAR_KINDS:
			items.append({"item": gear_id(kind, MAX_TIER), "n": 1})
		items.append({"item": "elixer", "n": 5})
		gold_mult_boss *= 5.0
	else:
		items.append({"item": gear_id(GEAR_KINDS[rng.randi_range(0, GEAR_KINDS.size() - 1)], gear_tier), "n": 1})
	var gold := GameData.round_half_even(chest_gold_base(f) * rng.randf_range(0.9, 1.1) * gold_mult_boss)
	return {"tier": gear_tier, "items": items, "gold": gold, "boss": true}


static func _potion(tier: int, rng) -> Dictionary:
	var t := clampi(tier, 1, MAX_TIER)
	var pool: Array = POTIONS[t - 1]
	var cnt: Array = POTION_COUNT[t - 1]
	return {"item": str(pool[rng.randi_range(0, pool.size() - 1)]), "n": rng.randi_range(int(cnt[0]), int(cnt[1]))}


## Buit in de tas leggen (items in 'inventory': id -> aantal). Geeft het goud terug: de aanroeper
## telt dat bij GameState.gold op (zo blijft dit pure data-logica).
static func grant_loot(loot: Dictionary, inventory: Dictionary) -> int:
	for it in loot.get("items", []):
		var id := str(it["item"])
		inventory[id] = int(inventory.get(id, 0)) + int(it.get("n", 1))
	return int(loot.get("gold", 0))


static func item_name(id: String) -> String:
	if GameData.ITEMS.has(id):
		return str(GameData.ITEMS[id]["name"])
	if GameData.EQUIPMENT.has(id):
		return str(GameData.EQUIPMENT[id]["name"])
	return id


## Eén regel per onderdeel (Nederlands): ["2x Drankje", "Archiefzwaard", "120 goud"].
static func loot_lines(loot: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	for it in loot.get("items", []):
		var n := int(it.get("n", 1))
		var nm := item_name(str(it["item"]))
		parts.append(nm if n == 1 else "%dx %s" % [n, nm])
	var gold := int(loot.get("gold", 0))
	if gold > 0:
		parts.append("%d goud" % gold)
	return parts


## Alles op één regel: "2x Drankje, Archiefzwaard, 120 goud".
static func loot_text(loot: Dictionary) -> String:
	return ", ".join(loot_lines(loot))


# ---------------------------------------------------------------- spawn-gegevens
## Dictionaries in het formaat van scripts/data/dungeon_rooms.gd, voor de kamer-/vloergenerator
## (die geeft de verdieping mee). MapMonster/DungeonChest lezen "floor" (valt terug op
## GameState.dungeon100_floor).
## Gewoon monster: {"id", "enemy", "tile", "moves", "floor"}.
static func monster_entry(enemy_id: String, floor_nr: int, tile: Vector2i, id := "") -> Dictionary:
	return {"id": id if id != "" else "d100_%d_%s_%d_%d" % [floor_nr, enemy_id, tile.x, tile.y],
			"enemy": enemy_id, "tile": [tile.x, tile.y], "moves": true, "floor": floor_nr}


## Baas van een baasverdieping (zoals monster_entry, + "boss": true; staat stil, 1x1 tile tenzij de aanroeper "size" toevoegt).
## Geen baasverdieping: {}.
static func boss_entry(floor_nr: int, tile: Vector2i) -> Dictionary:
	var b := boss_for_floor(floor_nr)
	if b.is_empty():
		return {}
	return {"id": "d100_baas_%d" % floor_nr, "enemy": b["enemy"], "group": [b["enemy"]], "tile": [tile.x, tile.y],
			"moves": false, "boss": true, "floor": floor_nr}


## Kist in het formaat van dungeon_rooms.gd "chests", met vooraf gerolde buit ("loot", "gold").
## "item"/"n" = het eerste voorwerp (voor code die alleen die twee kent).
static func chest_entry(floor_nr: int, id: String, tile: Vector2i, rng, boss := false) -> Dictionary:
	var loot := chest_loot(floor_nr, rng, boss)
	var items: Array = loot["items"]
	var first: Dictionary = items[0] if not items.is_empty() else {"item": "drankje", "n": 1}
	return {"id": id, "tile": [tile.x, tile.y], "item": first["item"], "n": first["n"],
			"loot": loot, "floor": floor_nr}
