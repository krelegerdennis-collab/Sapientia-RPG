extends RefCounted
## Opgeladen zware slag (charge attack), alleen Action (scripts/som/). Ontwerp: docs/combat/charge_attack.md.
## Vasthouden van de aanvalsknop laadt op (2 niveaus), loslaten = zware slag. Geen MP. Dodge annuleert.
## Voor elke actor (bestuurde held, co-op-peer, bondgenoot-AI); tick-gebaseerd, geen toeval, host-autoritatief.
## Alle waarden zijn VOORSTELLEN (Dennis beslist).
##
## Naam: "heavy" i.p.v. "charge", want SomArena.charge is al de wapenmeter.

## Een tap blijft de gewone (keten)slag op het indrukken. Pas na HOLD_START_TICKS vasthouden begint het opladen
## (en het vertragen), zodat een gewone tap niets merkt.
const HOLD_START_TICKS := 12
## Vastgehouden ticks (vanaf het indrukken) voor niveau 1 en 2.
const LEVEL_TICKS: Array[int] = [45, 100]
const MAX_LEVEL := 2
## Schade-multiplier per niveau (index 0 = niveau 1). Bovenop de wapenmeter (SomArena.charge_mult).
const DAMAGE_MULT: Array[float] = [1.4, 2.4]
## Hitstop (ticks dat de vijand bevriest) en knockback (tegels) per niveau.
const HITSTOP_TICKS: Array[int] = [8, 12]
const KNOCKBACK_TILES: Array[int] = [2, 3]
## Loopsnelheid tijdens het opladen (x MOVE_SPEED / ALLY_SPEED / co-op MOVE_SPEED).
const MOVE_MULT := 0.5
## Zware slag staggert altijd (telegraaf breken + knockback).
const ALWAYS_STAGGERS := true
## Kost geen MP en geen stamina.
const MP_COST := 0

## Bondgenoot-AI: na elke finisher van zijn keten laadt hij de volgende slag op tot dit niveau
## (deterministisch: geen toeval, alleen keten-telling).
const ALLY_LEVEL := 1

## TODO RPG ART: placeholder-animatie = de finisher-placeholder (bestaande <held>_attack.png, traag tempo).
const STATES: Array[String] = ["heavy1", "heavy2"]


static func level_for(held_ticks: int) -> int:
	var lv := 0
	for i in LEVEL_TICKS.size():
		if held_ticks >= LEVEL_TICKS[i]:
			lv = i + 1
	return mini(lv, MAX_LEVEL)


static func charging(held_ticks: int) -> bool:
	return held_ticks >= HOLD_START_TICKS


static func damage_mult(level: int) -> float:
	return DAMAGE_MULT[clampi(level, 1, MAX_LEVEL) - 1]


static func hitstop_ticks(level: int) -> int:
	return HITSTOP_TICKS[clampi(level, 1, MAX_LEVEL) - 1]


static func knockback_tiles(level: int) -> int:
	return KNOCKBACK_TILES[clampi(level, 1, MAX_LEVEL) - 1]


static func state_for(level: int) -> String:
	return STATES[clampi(level, 1, MAX_LEVEL) - 1]
