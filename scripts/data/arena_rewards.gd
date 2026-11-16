extends RefCounted
## Beloning per wave van het Colosseum. Data, geen gevechtslogica.
## Wave 5 schaalt per run in SomArenaData (RPG COMBAT), niet hier.
## Het token-plafond stopt eindeloos grinden tot Dennis het getal vastzet.

const WAVE_COUNT := 5

# PLACEHOLDER (Dennis approves balance)
const HP_PERCENT := 25
# PLACEHOLDER (Dennis approves balance)
const TOKEN_CAP := 200
# PLACEHOLDER (Dennis approves balance)
const WAVES := {
	1: {"xp": 8, "tokens": 4},
	2: {"xp": 12, "tokens": 6},
	3: {"xp": 16, "tokens": 8},
	4: {"xp": 20, "tokens": 10},
	5: {"xp": 28, "tokens": 14},
}


static func token_cap() -> int:
	return TOKEN_CAP


static func hp_percent() -> int:
	return HP_PERCENT


static func for_wave(n: int) -> Dictionary:
	var row = WAVES.get(n, {})
	return (row as Dictionary).duplicate(true) if row is Dictionary else {}


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
