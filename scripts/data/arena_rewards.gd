extends RefCounted
## Beloning per wave van het Colosseum. Data, geen gevechtslogica (akkoord Dennis 25-11).
## Geen kill-XP/goud in de hal: alleen deze milestone-regels + tokens.

const WAVE_COUNT := 5

const HP_PERCENT := 30
## Fractie van max_hp na wipe-terugkeer (1.0 = vol HP). Design Dennis 25-11.
const ARENA_WIPE_REVIVE_HP_PCT := 1.0
const TOKEN_CAP := 150
const WAVES := {
	1: {"xp": 15, "tokens": 5},
	2: {"xp": 18, "tokens": 6},
	3: {"xp": 22, "tokens": 8},
	4: {"xp": 28, "tokens": 10},
	5: {"xp": 35, "tokens": 12},
}


static func token_cap() -> int:
	return TOKEN_CAP


static func hp_percent() -> int:
	return HP_PERCENT


static func for_wave(n: int) -> Dictionary:
	var row = WAVES.get(n, {})
	return (row as Dictionary).duplicate(true) if row is Dictionary else {}


## Na wipe + 'Back to the lobby': iedereen op 0 weer op (geen dode party op de kaart).
static func revive_after_wipe() -> void:
	var pct: float = ARENA_WIPE_REVIVE_HP_PCT
	for raw in GameState.party:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var hero: Dictionary = raw
		if int(hero.get("hp", 0)) > 0:
			continue
		var mx := maxi(1, int(hero.get("max_hp", 1)))
		hero["hp"] = maxi(1, int(ceil(float(mx) * pct)))


## Tussen waves: een deel van de max-HP terug, alleen wie nog staat.
## Iemand op 0 blijft liggen; die gebruikt de bestaande revive.
static func restore_between_waves() -> void:
	var pct := HP_PERCENT
	for raw in GameState.party:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var hero: Dictionary = raw
		var hp := int(hero.get("hp", 0))
		if hp <= 0:
			continue
		var mx := maxi(1, int(hero.get("max_hp", 1)))
		var gain := int(float(mx) * float(pct) / 100.0)
		hero["hp"] = mini(mx, hp + gain)
