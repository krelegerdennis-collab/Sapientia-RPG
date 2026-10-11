extends RefCounted
class_name PvpRules
## Pure gevechtsregels. De host is de autoriteit; deze functies rekenen alleen.
##
## Fysieke schade: ATK * mult - DEF/2, daarna spreiding ±15% (variance 0.85..1.15).
## Verdedigen halveert daarna, naar beneden afgerond, met een minimum van 1.
## Spreukbedrag: power + 2 * level. Geen spreiding.
## Zelfde formule als het gewone gevecht, hier lokaal gekopieerd.
## Beurtvolgorde: AGI aflopend. Bij gelijke AGI eerst de host, dan de gast,
## en binnen een kant de partij-index. Geen toevals-tiebreak, zodat tests vast liggen.
## Spiegelgevecht (hetzelfde team) is toegestaan.


static func mirror_allowed() -> bool:
	return true


static func teams_ok(host_team: String, guest_team: String) -> bool:
	if not PvpTeams.has_team(host_team) or not PvpTeams.has_team(guest_team):
		return false
	if host_team == guest_team:
		return mirror_allowed()
	return true


static func physical_damage(atk: int, def: int, mult: float, variance: float, defending: bool) -> int:
	var base := float(atk) * mult - float(def) / 2.0
	var dmg := maxi(1, roundi(base * variance))
	if defending:
		dmg = maxi(1, int(float(dmg) / 2.0))
	return dmg


static func roll_variance(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(0.85, 1.15)


static func spell_amount(power: int, level: int) -> int:
	return maxi(1, power + 2 * level)


static func spell_damage(power: int, level: int) -> int:
	return spell_amount(power, level)


static func spell_heal(power: int, level: int) -> int:
	return spell_amount(power, level)


static func turn_order(fighters: Array) -> Array:
	var living: Array = []
	for raw in fighters:
		var fighter: Dictionary = raw
		if int(fighter.get("hp", 0)) > 0:
			living.append(fighter)
	living.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _before(a, b)
	)
	var uids: Array = []
	for raw in living:
		uids.append(str((raw as Dictionary)["uid"]))
	return uids


static func _before(a: Dictionary, b: Dictionary) -> bool:
	var agi_a := int(a["agi"])
	var agi_b := int(b["agi"])
	if agi_a != agi_b:
		return agi_a > agi_b
	var seat_a := 0 if str(a["seat"]) == "host" else 1
	var seat_b := 0 if str(b["seat"]) == "host" else 1
	if seat_a != seat_b:
		return seat_a < seat_b
	return int(a["index"]) < int(b["index"])


static func winner_seat(fighters: Array) -> String:
	var host_up := false
	var guest_up := false
	for raw in fighters:
		var fighter: Dictionary = raw
		if int(fighter.get("hp", 0)) <= 0:
			continue
		if str(fighter.get("seat", "")) == "host":
			host_up = true
		else:
			guest_up = true
	if host_up and not guest_up:
		return "host"
	if guest_up and not host_up:
		return "guest"
	return ""
