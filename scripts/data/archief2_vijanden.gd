extends RefCounted
## Archief 2 (Het Levende Archief): de vijf gewone vijanden (CANON.md besluit 13, PR #51) en het
## gedrag van hun vaardigheden. Data staat in GameData.ENEMIES (vijand) en CodexData (bondgenoot);
## hier alleen de regels, als statische functies op combatant-dictionaries (battle.gd), zodat de
## headless suite (archief2test) ze zonder scène kan naspelen.
##
## Vaardigheid-"type" (vijand: GameData.ENEMIES[..]["skills"], bondgenoot: CodexData.SKILLS):
##   "bind"   schade, daarna slaat het doel 1 beurt over (Rankje / Tendril)
##   "poison" schade, daarna gif: POISON_PCT van max HP per ronde, POISON_TURNS rondes (Sporekop)
##   "charge" charge-aanval: power 2.0 = dubbele schade van een gewone klap (Doornige Loper)
##   "drain"  bijt en heelt zichzelf met DRAIN_PCT van de schade (Bloeiende Schrik)
##   "pull"   schade, en trekt het doel naar zich toe: de volgende aanval van het doel MOET
##            op de trekker (Wortelgeest). Bondgenoot: plus counter (alleen de Wortelgeest).

const IDS := ["rankje", "sporekop", "doornige_loper", "bloeiende_schrik", "wortelgeest"]
## Vangbaar in de Codex (canon): Sporekop, Rankje, Wortelgeest.
const CODEX_IDS := ["sporekop", "rankje", "wortelgeest"]
const ELEMENT := "natuur"

const BIND_TURNS := 1
const SKIP_REDEN_BIND := "binding"
const POISON_PCT := 0.08
const POISON_TURNS := 3
const CHARGE_POWER := 2.0
const DRAIN_PCT := 0.5
## Counter van de Wortelgeest-bondgenoot: gewone klap x COUNTER_POWER, tot het einde van de ronde.
const COUNTER_POWER := 1.0
const COUNTER_TURNS := 1


## Verversen i.p.v. stapelen (#5/#6): bestaat er al een rij met dezelfde waarde voor 'key'
## (buff: "stat", gif: "gif"), dan blijft er één rij over met de hoogste pct en de hoogste
## resterende beurten. Anders komt 'row' erbij.
static func refresh_row(rows: Array, row: Dictionary, key: String) -> void:
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY and r.get(key) == row.get(key):
			r["pct"] = maxf(float(r.get("pct", 0.0)), float(row.get("pct", 0.0)))
			r["turns"] = maxi(int(r.get("turns", 0)), int(row.get("turns", 0)))
			return
	rows.append(row)


## Zet het effect van vaardigheid 'skill' (na de schade 'dmg') op doel 't'. Geeft de melding
## terug ("" = geen melding). 'actor' = wie de vaardigheid gebruikt.
static func apply(actor: Dictionary, t: Dictionary, skill: Dictionary, dmg: int) -> String:
	match str(skill.get("type", "")):
		"bind":
			if int(t["s"]["hp"]) <= 0:
				return ""
			t["skip"] = maxi(int(t.get("skip", 0)), int(skill.get("skip", BIND_TURNS)))
			t["skip_reden"] = SKIP_REDEN_BIND
			return "%s is bound and loses a turn!" % t["name"]
		"poison":
			if int(t["s"]["hp"]) <= 0:
				return ""
			if not t.has("dots"):
				t["dots"] = []
			refresh_row(t["dots"], {"pct": float(skill.get("dot_pct", POISON_PCT)),
					"turns": int(skill.get("dot_turns", POISON_TURNS)), "gif": true}, "gif")
			return "%s is poisoned!" % t["name"]
		"drain":
			if int(actor["s"]["hp"]) <= 0:
				return ""
			var heal := maxi(1, roundi(float(dmg) * float(skill.get("drain", DRAIN_PCT))))
			var room := maxi(0, int(actor["s"]["max_hp"]) - int(actor["s"]["hp"]))
			heal = mini(heal, room)
			actor["s"]["hp"] = int(actor["s"]["hp"]) + heal
			return "%s heals %d HP." % [actor["name"], heal] if heal > 0 else ""
		"pull":
			if int(t["s"]["hp"]) <= 0:
				return ""
			t["pulled_by"] = actor
			t["defending"] = false
			if bool(skill.get("counter", false)):
				actor["counter"] = int(skill.get("counter_turns", COUNTER_TURNS))
			return "%s is pulled toward %s!" % [t["name"], actor["name"]]
	return ""


## Getrokken? Dan moet de volgende aanval op de trekker (zolang die nog leeft). Eenmalig:
## het trekken is daarna weg. null = gewoon doel.
static func pulled_target(actor: Dictionary):
	if not actor.has("pulled_by"):
		return null
	var by = actor["pulled_by"]
	actor.erase("pulled_by")
	if typeof(by) == TYPE_DICTIONARY and int(by.get("s", {}).get("hp", 0)) > 0:
		return by
	return null


## Counter actief op 't' (na een klap van 'attacker')?
static func counters(t: Dictionary, attacker: Dictionary) -> bool:
	return int(t.get("counter", 0)) > 0 and int(t["s"]["hp"]) > 0 and int(attacker["s"]["hp"]) > 0 \
			and bool(t.get("is_hero", false)) != bool(attacker.get("is_hero", false))


## Einde ronde: counter telt af.
static func tick(c: Dictionary) -> void:
	if int(c.get("counter", 0)) > 0:
		c["counter"] = int(c["counter"]) - 1
