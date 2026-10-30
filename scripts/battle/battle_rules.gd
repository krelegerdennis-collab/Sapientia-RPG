extends RefCounted
## Pure hulplogica voor battle.gd (geen nodes, geen randf, geen awaits).
## Uit battle.gd gehaald bij de refactor; gedrag is identiek.

const Archief2Vijanden := preload("res://scripts/data/archief2_vijanden.gd")


## Berichtregel (met %s voor de naam) voor een actor die een beurt overslaat.
static func skip_text(reden: String) -> String:
	if reden == Archief2Vijanden.SKIP_REDEN_BIND:
		return "%s is bound and skips a turn."
	if reden == "verlamming":
		return "%s is paralyzed and skips a turn."
	return "%s is frozen and skips a turn."


## Doel voor een Feniksveer: het gekozen doel als dat KO is, anders de eerste KO-held (of null).
static func revive_target(target, heroes: Array):
	if target != null and int(target["s"]["hp"]) <= 0:
		return target
	for h in heroes:
		if int(h["s"]["hp"]) <= 0:
			return h
	return null


## Tegengif: gif-dots en binden weghalen (past de combatant in-place aan).
static func cure_ailments(t: Dictionary) -> void:
	if t.has("dots"):
		t["dots"] = (t["dots"] as Array).filter(func(d): return not bool(d.get("gif", false)))
	if str(t.get("skip_reden", "")) == Archief2Vijanden.SKIP_REDEN_BIND:
		t["skip"] = 0
